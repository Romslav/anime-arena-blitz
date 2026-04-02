-- CharacterService.server.lua | Anime Arena: Blitz
-- Управляет выбором героя, спавном, применением статов и GameMode модификаторов.
-- Публичный API: _G.CharacterService
-- НЕ является ModuleScript — не использует return для экспорта.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService     = game:GetService("InsertService")

local Characters = require(ReplicatedStorage:WaitForChild("Characters"))
local Remotes    = ReplicatedStorage:WaitForChild("Remotes")

local rSelectHero       = Remotes:WaitForChild("SelectHero")
local rHeroSelected     = Remotes:WaitForChild("HeroSelected")
local rCharacterSpawned = Remotes:WaitForChild("CharacterSpawned")
local rSelectStarter    = Remotes:WaitForChild("SelectStarter")
local rShowStarter      = Remotes:WaitForChild("ShowStarterSelection")
local rHeroUnlocked     = Remotes:WaitForChild("HeroUnlocked")
local rShowNotification = Remotes:WaitForChild("ShowNotification")

-- ============================================================
-- НОРМАЛИЗАЦИЯ ID (snake_case → PascalCase)
-- ============================================================

local HERO_ID_MAP = {
	flame_ronin     = "FlameRonin",
	void_assassin   = "VoidAssassin",
	thunder_monk    = "ThunderMonk",
	iron_titan      = "IronTitan",
	scarlet_archer  = "ScarletArcher",
	eclipse_hero    = "EclipseHero",
	storm_dancer    = "StormDancer",
	blood_sage      = "BloodSage",
	crystal_guard   = "CrystalGuard",
	shadow_twin     = "ShadowTwin",
	neon_blitz      = "NeonBlitz",
	jade_sentinel   = "JadeSentinel",
}

-- ============================================================
-- ФОЛЛБЕК для героев, не описанных в Characters.lua
-- ============================================================

local FALLBACK_STATS = {
	IronTitan = {
		id="IronTitan", name="Iron Titan", role="Tank", rarity="Rare",
		hp=260, m1Damage=15, speed=12,
		skills = {
			{name="Iron Slam",    damage=12, cooldown=8,  type="AoE",     anim="rbxassetid://0"},
			{name="Shield Wall",  damage=0,  cooldown=12, type="Defense", anim="rbxassetid://0"},
			{name="Ground Quake", damage=18, cooldown=15, type="AoE",     anim="rbxassetid://0"},
		},
		ultimate = {name="Titan Fall",       damage=45, cooldown=70, anim="rbxassetid://0"},
		passive  = "Blocks 15% damage from front",
	},
	ScarletArcher = {
		id="ScarletArcher", name="Scarlet Archer", role="Ranged", rarity="Rare",
		hp=140, m1Damage=24, speed=15,
		skills = {
			{name="Arrow Rain",    damage=14, cooldown=9, type="AoE",    anim="rbxassetid://0"},
			{name="Piercing Shot", damage=20, cooldown=8, type="Linear", anim="rbxassetid://0"},
			{name="Evasion Roll",  damage=0,  cooldown=7, type="Dodge",  anim="rbxassetid://0"},
		},
		ultimate = {name="Storm of Arrows",  damage=38, cooldown=55, anim="rbxassetid://0"},
		passive  = "Headshots deal +30% damage",
	},
	EclipseHero = {
		id="EclipseHero", name="Eclipse Hero", role="Assassin", rarity="Legendary",
		hp=150, m1Damage=26, speed=18,
		skills = {
			{name="Eclipse Slash", damage=15, cooldown=7,  type="Burst",    anim="rbxassetid://0"},
			{name="Lunar Phase",   damage=10, cooldown=9,  type="Teleport", anim="rbxassetid://0"},
			{name="Dark Veil",     damage=0,  cooldown=12, type="Stealth",  anim="rbxassetid://0"},
		},
		ultimate = {name="Total Eclipse",    damage=44, cooldown=60, anim="rbxassetid://0"},
		passive  = "Crit chance +25% from behind",
	},
	StormDancer = {
		id="StormDancer", name="Storm Dancer", role="Skirmisher", rarity="Common",
		hp=145, m1Damage=23, speed=19,
		skills = {
			{name="Tempest Step", damage=8,  cooldown=6,  type="Dash",  anim="rbxassetid://0"},
			{name="Wind Spiral",  damage=12, cooldown=8,  type="AoE",   anim="rbxassetid://0"},
			{name="Gale Parry",   damage=0,  cooldown=10, type="Parry", anim="rbxassetid://0"},
		},
		ultimate = {name="Cyclone Fury",     damage=36, cooldown=55, anim="rbxassetid://0"},
		passive  = "Hits build Storm stacks for speed boost",
	},
	BloodSage = {
		id="BloodSage", name="Blood Sage", role="Mage", rarity="Legendary",
		hp=120, m1Damage=30, speed=14,
		skills = {
			{name="Bloodbolt",     damage=18, cooldown=7,  type="Projectile", anim="rbxassetid://0"},
			{name="Crimson Bind",  damage=6,  cooldown=10, type="Root",       anim="rbxassetid://0"},
			{name="Sanguine Burst",damage=22, cooldown=14, type="AoE",        anim="rbxassetid://0"},
		},
		ultimate = {name="Blood Moon",       damage=50, cooldown=65, anim="rbxassetid://0"},
		passive  = "Drains 5 HP per hit",
	},
	CrystalGuard = {
		id="CrystalGuard", name="Crystal Guard", role="Tank", rarity="Rare",
		hp=240, m1Damage=14, speed=13,
		skills = {
			{name="Crystal Spike", damage=10, cooldown=7,  type="AoE",    anim="rbxassetid://0"},
			{name="Prism Barrier", damage=0,  cooldown=12, type="Shield", anim="rbxassetid://0"},
			{name="Shatter Rush",  damage=16, cooldown=10, type="Dash",   anim="rbxassetid://0"},
		},
		ultimate = {name="Crystal Fortress", damage=30, cooldown=70, anim="rbxassetid://0"},
		passive  = "Crystal shards reduce incoming damage",
	},
	ShadowTwin = {
		id="ShadowTwin", name="Shadow Twin", role="Support", rarity="Epic",
		hp=155, m1Damage=25, speed=17,
		skills = {
			{name="Twin Lash",    damage=12, cooldown=6,  type="Burst",    anim="rbxassetid://0"},
			{name="Shadow Clone", damage=0,  cooldown=15, type="Clone",    anim="rbxassetid://0"},
			{name="Mist Step",    damage=0,  cooldown=8,  type="Teleport", anim="rbxassetid://0"},
		},
		ultimate = {name="Dark Mirror",      damage=35, cooldown=60, anim="rbxassetid://0"},
		passive  = "Clone deals 50% damage",
	},
	NeonBlitz = {
		id="NeonBlitz", name="Neon Blitz", role="Ranged", rarity="Epic",
		hp=135, m1Damage=27, speed=16,
		skills = {
			{name="Neon Burst",   damage=16, cooldown=7,  type="Projectile", anim="rbxassetid://0"},
			{name="Circuit Dash", damage=0,  cooldown=6,  type="Dash",       anim="rbxassetid://0"},
			{name="Overload",     damage=20, cooldown=12, type="AoE",        anim="rbxassetid://0"},
		},
		ultimate = {name="Neon Overdrive",   damage=42, cooldown=58, anim="rbxassetid://0"},
		passive  = "Every 4th hit fires a neon pulse",
	},
	JadeSentinel = {
		id="JadeSentinel", name="Jade Sentinel", role="Duelist", rarity="Rare",
		hp=200, m1Damage=18, speed=15,
		skills = {
			{name="Jade Strike",   damage=14, cooldown=7,  type="Burst", anim="rbxassetid://0"},
			{name="Sentinel Step", damage=0,  cooldown=6,  type="Dodge", anim="rbxassetid://0"},
			{name="Earthen Crush", damage=18, cooldown=11, type="AoE",   anim="rbxassetid://0"},
		},
		ultimate = {name="Jade Wrath",       damage=38, cooldown=60, anim="rbxassetid://0"},
		passive  = "Perfect parry resets a skill cooldown",
	},
}

-- ============================================================
-- СОСТОЯНИЕ
-- ============================================================

local selectedHeroes = {}  -- [userId] = heroData
local shownStarterSelection = {} -- [userId] = true while onboarding picker was already shown

local CharacterService = {}
_G.CharacterService = CharacterService

-- ============================================================
-- FLAME RONIN VISUAL PRESET
-- ============================================================

local RONIN_SKIN_TONE = Color3.fromRGB(246, 214, 178)
local RONIN_DEFAULT_FACE_TEXTURE_ID = "rbxassetid://129135364950196"
local RONIN_KIMONO_ASSET_ID = 126531938676202
local RONIN_KATANA_ASSET_ID = 8579129440
-- FBX head orientation fix: imported mesh's "down" axis points backward in Roblox.
-- Rotate +90° around X so shoulders sit under the chin instead of behind the head.
local RONIN_HEAD_ALIGN_CF = CFrame.Angles(math.rad(90), 0, 0)
local RONIN_FACE_COLORS = {
	EyeWhite   = Color3.fromRGB(247, 238, 224),
	EyeLine    = Color3.fromRGB(40, 32, 28),
	NoseShade  = Color3.fromRGB(186, 143, 112),
	MouthLine  = Color3.fromRGB(66, 49, 41),
	CheekShade = Color3.fromRGB(208, 165, 132),
}
local RONIN_PALETTE = {
	CoalBlack   = Color3.fromRGB(62, 62, 68),
	CoalGray    = Color3.fromRGB(88, 88, 96),
	Scarlet     = Color3.fromRGB(198, 34, 28),
	Amber       = Color3.fromRGB(255, 136, 34),
	Gold        = Color3.fromRGB(198, 150, 68),
	HairWhite   = Color3.fromRGB(244, 244, 245),
	BladeDark   = Color3.fromRGB(56, 23, 20),
	BladeGlow   = Color3.fromRGB(255, 112, 34),
	EyeGlow     = Color3.fromRGB(255, 170, 70),
}

local RONIN_ASSET_CACHE = {} -- [assetId:number] = Model clone

local TOKENS_HAIR = { "hair", "bang", "fringe", "temple" }
local TOKENS_KATANA = { "katana", "sword", "blade", "tsuka", "hilt", "sheath", "scabbard" }
local TOKENS_BLADE = { "blade", "edge" }
local TOKENS_HANDLE = { "handle", "hilt", "tsuka", "grip" }
local TOKENS_KIMONO = { "kimono", "robe", "cloth", "sleeve", "obi", "coat", "torso", "upper", "lower" }
-- Tuned so katana sits along the back plane and above the coat surface.
local RONIN_KATANA_BACK_ATTACHMENT_CF =
	CFrame.new(0.0, 0.42, 0.62) * CFrame.Angles(math.rad(180), math.rad(92), math.rad(-28))

local RONIN_SKIN_PARTS = {
	Head = true, UpperTorso = true, LowerTorso = true, Torso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, ["Left Arm"] = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true, ["Right Arm"] = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, ["Left Leg"] = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true, ["Right Leg"] = true,
}

local function clearDefaultFace(head)
	if not head then return end
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("Decal") and (child.Name == "face" or string.find(string.lower(child.Name), "face", 1, true)) then
			child:Destroy()
		end
	end
end

local function applyRoninSkinTone(character)
	for _, inst in ipairs(character:GetDescendants()) do
		if inst:IsA("BasePart") then
			if RONIN_SKIN_PARTS[inst.Name] or inst.Name == "RoninCustomHead" then
				inst.Color = RONIN_SKIN_TONE
			end
		end
	end

	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = RONIN_SKIN_TONE
		bodyColors.TorsoColor3 = RONIN_SKIN_TONE
		bodyColors.LeftArmColor3 = RONIN_SKIN_TONE
		bodyColors.RightArmColor3 = RONIN_SKIN_TONE
		bodyColors.LeftLegColor3 = RONIN_SKIN_TONE
		bodyColors.RightLegColor3 = RONIN_SKIN_TONE
	end
end

local function removeRoninFaceRig(character)
	for _, inst in ipairs(character:GetDescendants()) do
		if inst.Name == "RoninFaceRig" or string.sub(inst.Name, 1, 10) == "RoninFace_" then
			inst:Destroy()
		end
	end
end

local function pickRoninHeadAsset(roninAssets)
	if not roninAssets then return nil end

	local preferredNames = {
		"RoninHead", "FlameRoninHead", "Ronin_Head", "HeadMesh", "Head",
	}
	for _, name in ipairs(preferredNames) do
		local obj = roninAssets:FindFirstChild(name)
		if obj and (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Accessory")) then
			return obj
		end
	end

	for _, obj in ipairs(roninAssets:GetChildren()) do
		local n = string.lower(obj.Name)
		if string.find(n, "head", 1, true) and (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Accessory")) then
			return obj
		end
	end

	return nil
end

local function weldToHead(part, head)
	if not (part and head) then return end
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
end

local function attachRoninCustomHead(character, roninAssets, hum)
	local head = character:FindFirstChild("Head")
	if not head then return nil end

	local oldCustom = character:FindFirstChild("RoninCustomHead")
	if oldCustom then oldCustom:Destroy() end

	clearDefaultFace(head)
	head.Transparency = 1

	local asset = pickRoninHeadAsset(roninAssets)
	if not asset then
		-- Fallback: keep Roblox head visible if custom asset missing.
		head.Transparency = 0
		return head
	end

	local customHead = nil
	local clone = asset:Clone()
	local targetCF = head.CFrame * RONIN_HEAD_ALIGN_CF

	if clone:IsA("Accessory") then
		if hum then
			hum:AddAccessory(clone)
			local handle = clone:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				customHead = handle
			end
		else
			clone:Destroy()
		end
	elseif clone:IsA("Model") then
		clone.Name = "RoninCustomHead"
		clone.Parent = character
		local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
		if primary then
			clone:PivotTo(targetCF)
			for _, p in ipairs(clone:GetDescendants()) do
				if p:IsA("BasePart") then
					weldToHead(p, head)
				end
			end
			customHead = primary
		end
	elseif clone:IsA("BasePart") then
		clone.Name = "RoninCustomHead"
		clone.CFrame = targetCF
		clone.Parent = character
		weldToHead(clone, head)
		customHead = clone
	end

	if customHead and customHead:IsA("BasePart") then
		customHead.Name = "RoninCustomHead"
		customHead.Color = RONIN_SKIN_TONE
		return customHead
	end

	head.Transparency = 0
	return head
end

local function addFacePart(faceRig, faceBasePart, name, size, offsetCF, color, transparency)
	local p = Instance.new("Part")
	p.Name = "RoninFace_" .. name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Anchored = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = faceBasePart.CFrame * offsetCF
	p.Parent = faceRig

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = faceBasePart
	weld.Part1 = p
	weld.Parent = p
end

local function tryApplyFaceTexture(faceBasePart, roninAssets)
	if not faceBasePart then return false end

	local faceTextureId = nil
	if roninAssets then
		local byName = roninAssets:FindFirstChild("FlameRoninFace")
		if byName and byName:IsA("Decal") and byName.Texture ~= "" then
			faceTextureId = byName.Texture
		end

		if not faceTextureId then
			local anyFaceDecal = nil
			for _, obj in ipairs(roninAssets:GetChildren()) do
				if obj:IsA("Decal") and string.find(string.lower(obj.Name), "face", 1, true) and obj.Texture ~= "" then
					anyFaceDecal = obj
					break
				end
			end
			if anyFaceDecal then
				faceTextureId = anyFaceDecal.Texture
			end
		end

		if not faceTextureId then
			local faceTextureValue = roninAssets:FindFirstChild("FaceTextureId")
			if faceTextureValue and faceTextureValue:IsA("StringValue") and faceTextureValue.Value ~= "" then
				faceTextureId = faceTextureValue.Value
			end
		end
	end

	if not faceTextureId then
		faceTextureId = RONIN_DEFAULT_FACE_TEXTURE_ID
	end

	if not faceTextureId then
		return false
	end

	clearDefaultFace(faceBasePart)
	local decal = Instance.new("Decal")
	decal.Name = "face"
	decal.Face = Enum.NormalId.Front
	decal.Texture = faceTextureId
	decal.Parent = faceBasePart
	return true
end

local function applyRoninFace(faceBasePart, roninAssets)
	if not (faceBasePart and faceBasePart:IsA("BasePart")) then return end
	removeRoninFaceRig(faceBasePart.Parent)
	tryApplyFaceTexture(faceBasePart, roninAssets)
end

local function resolveRoninFaceBase(character)
	if not character then return nil end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Decal") and d.Name == "face" and d.Parent and d.Parent:IsA("BasePart") then
			return d.Parent
		end
	end
	return character:FindFirstChild("RoninCustomHead") or character:FindFirstChild("Head")
end

local function hasToken(name, tokens)
	local low = string.lower(name or "")
	for _, tok in ipairs(tokens) do
		if string.find(low, tok, 1, true) then
			return true
		end
	end
	return false
end

local function hasNamedAncestor(inst, tokens)
	local p = inst and inst.Parent
	while p do
		if hasToken(p.Name, tokens) then
			return true
		end
		p = p.Parent
	end
	return false
end

local function findFirstDescendant(root, predicate)
	if not root then return nil end
	for _, d in ipairs(root:GetDescendants()) do
		if predicate(d) then
			return d
		end
	end
	return nil
end

local function stripScripts(root)
	if not root then return end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		end
	end
end

local function normalizeAccessoryLook(accessory, clearTextures)
	if not accessory then return end
	stripScripts(accessory)

	-- Проверяем: это Layered Clothing? (есть WrapLayer в Handle)
	-- Если да — SurfaceAppearance с PBR не трогаем, она нужна для текстур кимоно.
	local isLayeredClothing = false
	local handle = accessory:FindFirstChild("Handle")
	if handle and handle:FindFirstChildOfClass("WrapLayer") then
		isLayeredClothing = true
	end

	for _, d in ipairs(accessory:GetDescendants()) do
		if d:IsA("SurfaceAppearance") then
			if not isLayeredClothing then
				-- Обычные аксессуары (не Layered Clothing) — удаляем SurfaceAppearance
				d:Destroy()
			end
			-- Layered Clothing: SurfaceAppearance с PBR сохраняем
		elseif d:IsA("SpecialMesh") then
			if clearTextures then
				d.TextureId = ""
			end
			d.VertexColor = Vector3.new(1, 1, 1)
		elseif d:IsA("MeshPart") and clearTextures and not isLayeredClothing then
			d.TextureID = ""
		end
	end
end

local function findAccessoryInFolder(folder, tokens, exactName)
	if not folder then return nil end
	if exactName then
		local direct = folder:FindFirstChild(exactName)
		if direct and direct:IsA("Accessory") then
			return direct
		end
	end

	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("Accessory") and hasToken(obj.Name, tokens) then
			return obj
		end
	end
	return nil
end

local function getAssetContainerClone(assetId)
	local cached = RONIN_ASSET_CACHE[assetId]
	if cached then
		return cached:Clone()
	end

	local ok, container = pcall(InsertService.LoadAsset, InsertService, assetId)
	if not ok or not container then
		warn(string.format("[RoninVisual] Failed to load asset %s: %s", tostring(assetId), tostring(container)))
		return nil
	end

	container.Archivable = true
	RONIN_ASSET_CACHE[assetId] = container:Clone()
	return container
end

local function clearRoninFX(character)
	for _, d in ipairs(character:GetDescendants()) do
		if string.sub(d.Name, 1, 8) == "RoninFX_" then
			d:Destroy()
		end
	end
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accessory") and string.sub(item.Name, 1, 8) == "RoninFX_" then
			item:Destroy()
		end
	end
end

local function removeBaseClothing(character)
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("Jacket") or item:IsA("Sweater") then
			item:Destroy()
		end
	end
end

local function weldModelToPart(model, basePart, targetCF)
	if not (model and basePart) then return end
	model:PivotTo(targetCF)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Name = "RoninFX_Weld"
			w.Part0 = basePart
			w.Part1 = p
			w.Parent = p
		end
	end
end

local function applyKimonoAsset(character, hum, roninAssets)
	if not (hum and roninAssets) then return false end

	-- ── ПРИОРИТЕТ 1: Layered Clothing Accessory ──
	-- Ищем Accessory у которого Handle (MeshPart) содержит WrapLayer.
	-- PBR текстуры заданы прямо в Studio на SurfaceAppearance — скрипт не трогает их.
	-- Roblox запрещает писать ContentId (ColorMap и др.) из ServerScript.
	for _, obj in ipairs(roninAssets:GetChildren()) do
		if obj:IsA("Accessory") then
			local handle = obj:FindFirstChild("Handle")
			if handle and handle:IsA("MeshPart") then
				local wrapLayer = handle:FindFirstChildOfClass("WrapLayer")
				if wrapLayer then
					local clone = obj:Clone()
					clone.Name = "RoninFX_KimonoAccessory"
					hum:AddAccessory(clone)
					print("[RoninMorph] Applied Layered Clothing kimono:", obj.Name)
					return true
				end
			end
		end
	end

	-- ── ПРИОРИТЕТ 2: Fallback — Model с Shirt/Pants внутри (старый Judo kimono) ──
	for _, obj in ipairs(roninAssets:GetChildren()) do
		if obj:IsA("Model") and hasToken(string.lower(obj.Name), TOKENS_KIMONO) then
			local shirt = obj:FindFirstChildOfClass("Shirt", true)
			local pants  = obj:FindFirstChildOfClass("Pants",  true)
			local applied = false
			if shirt then
				local s = shirt:Clone(); s.Name = "RoninFX_KimonoShirt"; s.Parent = character
				applied = true
			end
			if pants then
				local p = pants:Clone(); p.Name = "RoninFX_KimonoPants"; p.Parent = character
				applied = true
			end
			if applied then
				print("[RoninMorph] Applied kimono (Shirt/Pants) from Model:", obj.Name)
				return true
			end
		end
	end

	-- ── ПРИОРИТЕТ 3: Последний резерв — загрузка по Asset ID ──
	local container = getAssetContainerClone(RONIN_KIMONO_ASSET_ID)
	if not container then
		local shirt = Instance.new("Shirt")
		shirt.Name = "RoninFX_KimonoShirt"
		shirt.ShirtTemplate = "rbxassetid://" .. tostring(RONIN_KIMONO_ASSET_ID)
		shirt.Parent = character
		warn("[RoninMorph] Fallback: applied kimono by ShirtTemplate ID")
		return true
	end

	local acc = findFirstDescendant(container, function(d) return d:IsA("Accessory") end)
	if acc and hum then
		acc = acc:Clone(); acc.Name = "RoninFX_KimonoAccessory"
		hum:AddAccessory(acc)
		container:Destroy(); return true
	end
	local shirt = findFirstDescendant(container, function(d) return d:IsA("Shirt") end)
	if shirt then
		local c = shirt:Clone(); c.Name = "RoninFX_KimonoShirt"; c.Parent = character
	end
	local pants = findFirstDescendant(container, function(d) return d:IsA("Pants") end)
	if pants then
		local c = pants:Clone(); c.Name = "RoninFX_KimonoPants"; c.Parent = character
	end
	container:Destroy()
	return true
end

local function applyKatanaAsset(character, hum, roninAssets)
	local localKatana = findAccessoryInFolder(roninAssets, TOKENS_KATANA, "Katana")
	if localKatana and hum then
		local clone = localKatana:Clone()
		normalizeAccessoryLook(clone, true)
		clone.Name = "RoninFX_KatanaAccessory"
		local handle = clone:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local att = handle:FindFirstChild("BodyBackAttachment")
					or handle:FindFirstChildOfClass("Attachment")
					or Instance.new("Attachment")
				att.Name = "BodyBackAttachment"
				att.CFrame = RONIN_KATANA_BACK_ATTACHMENT_CF
				att.Parent = handle
			end
		hum:AddAccessory(clone)
		return true
	end

	local container = getAssetContainerClone(RONIN_KATANA_ASSET_ID)
	if not container then return false end

	local applied = false
	local katanaAccessory = findFirstDescendant(container, function(d)
		return d:IsA("Accessory") and hasToken(d.Name, TOKENS_KATANA)
	end) or findFirstDescendant(container, function(d) return d:IsA("Accessory") end)

	if katanaAccessory and hum then
		local clone = katanaAccessory:Clone()
		normalizeAccessoryLook(clone, true)
		clone.Name = "RoninFX_KatanaAccessory"
		local handle = clone:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local att = handle:FindFirstChild("BodyBackAttachment")
					or handle:FindFirstChildOfClass("Attachment")
					or Instance.new("Attachment")
				att.Name = "BodyBackAttachment"
				att.CFrame = RONIN_KATANA_BACK_ATTACHMENT_CF
				att.Parent = handle
			end
		hum:AddAccessory(clone)
		applied = true
	end

	if not applied then
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		local katanaModel = findFirstDescendant(container, function(d)
			return d:IsA("Model") and hasToken(d.Name, TOKENS_KATANA) and d:FindFirstChildWhichIsA("BasePart") ~= nil
		end) or findFirstDescendant(container, function(d)
			return d:IsA("Model") and d:FindFirstChildWhichIsA("BasePart") ~= nil
		end)
			if katanaModel and torso then
				katanaModel = katanaModel:Clone()
				katanaModel.Name = "RoninFX_KatanaModel"
				katanaModel.Parent = character
					local targetCF = torso.CFrame * CFrame.new(0.0, 0.42, 0.62) * CFrame.Angles(math.rad(180), math.rad(92), math.rad(-28))
				weldModelToPart(katanaModel, torso, targetCF)
				applied = true
			end
		end

	container:Destroy()
	return applied
end

local function isLikelyHairPart(part)
	if not (part and part:IsA("BasePart")) then return false end
	if hasToken(part.Name, TOKENS_HAIR) or hasNamedAncestor(part, TOKENS_HAIR) then
		return true
	end

	local p = part.Parent
	while p do
		if p:IsA("Accessory") then
			if hasToken(p.Name, TOKENS_KATANA) or hasToken(p.Name, TOKENS_KIMONO) or hasToken(p.Name, { "head" }) then
				return false
			end
			local att = p:FindFirstChild("HairAttachment", true) or p:FindFirstChild("HatAttachment", true)
			if att then
				return true
			end
			break
		end
		p = p.Parent
	end
	return false
end

local function isHeadMountedAccessory(accessory, character)
	if not (accessory and accessory:IsA("Accessory")) then return false end
	if hasToken(accessory.Name, TOKENS_KATANA) or hasToken(accessory.Name, TOKENS_KIMONO) then
		return false
	end

	local directHeadAttach =
		accessory:FindFirstChild("HairAttachment", true)
		or accessory:FindFirstChild("HatAttachment", true)
		or accessory:FindFirstChild("FaceFrontAttachment", true)
		or accessory:FindFirstChild("ForeheadCenterAttachment", true)
	if directHeadAttach then
		return true
	end

	local handle = accessory:FindFirstChild("Handle")
	local head = character and character:FindFirstChild("Head")
	if handle and head and handle:IsA("BasePart") and head:IsA("BasePart") then
		local delta = handle.Position - head.Position
		if delta.Magnitude <= 2.2 and delta.Y >= -1.0 then
			return true
		end
	end

	return hasToken(accessory.Name, TOKENS_HAIR) or hasToken(accessory.Name, { "roninheadaccessory", "head" })
end

local function isHairAccessory(accessory, character)
	if not (accessory and accessory:IsA("Accessory")) then return false end
	if hasToken(accessory.Name, TOKENS_KATANA) or hasToken(accessory.Name, TOKENS_KIMONO) then
		return false
	end
	if hasToken(accessory.Name, { "head", "roninhead" }) then
		return false
	end

	if accessory:FindFirstChild("HairAttachment", true) then
		return true
	end
	if hasToken(accessory.Name, TOKENS_HAIR) then
		return true
	end
	return isHeadMountedAccessory(accessory, character)
end

local function isPartInHeadAccessory(part, character)
	local p = part and part.Parent
	while p do
		if p:IsA("Accessory") then
			return isHeadMountedAccessory(p, character)
		end
		p = p.Parent
	end
	return false
end

local function isPartInAccessoryByTokens(part, tokens)
	local p = part and part.Parent
	while p do
		if p:IsA("Accessory") then
			return hasToken(p.Name, tokens)
		end
		p = p.Parent
	end
	return false
end

local function styleRoninHair(character)
	-- First pass: explicit accessory-based recolor (handles generic names like "Accessory")
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accessory") and isHeadMountedAccessory(item, character) then
			for _, d in ipairs(item:GetDescendants()) do
				if d:IsA("BasePart") then
					local sx, sy, sz = d.Size.X, d.Size.Y, d.Size.Z
					local tinyCube =
						(sx < 0.32 and sy < 0.32 and sz < 0.32)
						and (math.abs(sx - sy) < 0.08)
						and (math.abs(sy - sz) < 0.08)
					if tinyCube and not isLikelyHairPart(d) then
						d.Transparency = 1
						d.CanCollide = false
						d.CanTouch = false
						d.CanQuery = false
						continue
					end

					d.Transparency = 0
					d.Color = RONIN_PALETTE.HairWhite
					d.Material = Enum.Material.SmoothPlastic
					d.Reflectance = 0.03
					if d:IsA("MeshPart") then
						d.TextureID = ""
					elseif d:IsA("Part") then
						local sm = d:FindFirstChildOfClass("SpecialMesh")
						if sm then
							sm.TextureId = ""
							sm.VertexColor = Vector3.new(1, 1, 1)
						end
					end
				end
			end
		end
	end

	-- Second pass: catch any loose head-hair parts
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") and (isLikelyHairPart(d) or isPartInHeadAccessory(d, character)) then
			local sx, sy, sz = d.Size.X, d.Size.Y, d.Size.Z
			local tinyCube =
				(sx < 0.32 and sy < 0.32 and sz < 0.32)
				and (math.abs(sx - sy) < 0.08)
				and (math.abs(sy - sz) < 0.08)
			if tinyCube and not isLikelyHairPart(d) then
				d.Transparency = 1
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				continue
			end

			d.Transparency = 0
			d.Color = RONIN_PALETTE.HairWhite
			d.Material = Enum.Material.SmoothPlastic
			d.Reflectance = 0.03
			if d:IsA("MeshPart") then
				d.TextureID = ""
			elseif d:IsA("Part") then
				local sm = d:FindFirstChildOfClass("SpecialMesh")
				if sm then
					sm.TextureId = ""
					sm.VertexColor = Vector3.new(1, 1, 1)
				end
			end
		end
	end
end

local function styleRoninClothes(character)
	-- Intentionally disabled: clothing should be authored via real assets/textures,
	-- not overridden by runtime recolor scripts.
	_ = character
end

local function addWeldedPart(parent, basePart, name, size, offsetCF, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = "RoninFX_" .. name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Anchored = false
	p.Massless = true
	p.CFrame = basePart.CFrame * offsetCF
	p.Parent = parent

	local w = Instance.new("WeldConstraint")
	w.Name = "RoninFX_Weld"
	w.Part0 = basePart
	w.Part1 = p
	w.Parent = p
	return p
end

local function addRoninKimonoFX(character)
	-- Intentionally disabled: kimono visuals should come from authored texture/mesh assets.
	_ = character
end

local function addRoninEmberFX(character)
	-- Disabled intentionally: random embers looked like visual noise near the character.
	-- Smoldering feel is now driven by localized scorch smoke in addRoninKimonoFX.
	_ = character
end

local function addRoninEyeGlow(character, faceBasePart)
	-- Intentionally disabled: eye look should come from face texture/decal authored asset.
	_ = character
	_ = faceBasePart
end

local function styleRoninKatana(character)
	-- Intentionally disabled: katana visual FX should come from authored asset, not runtime VFX.
	_ = character
end

local function applyFlameRoninVisualStyle(character, roninAssets)
	if not character or not character.Parent then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	clearRoninFX(character)
	removeBaseClothing(character)

	applyKimonoAsset(character, hum, roninAssets)
	-- Примечание: PBR (SurfaceAppearance) работает только с Layered Clothing (MeshPart Handle).
	-- Judo kimono использует Shirt/Pants — PBR текстуры применяются через ShirtTemplate в Studio.
	applyKatanaAsset(character, hum, roninAssets)

	styleRoninHair(character)
	applyRoninSkinTone(character)
	print("[RoninVisual] Applied style | Asset-driven mode (no scripted eye/clothing FX)")
end

local function reapplyRoninCoreLook(character, roninAssets)
	if not (character and character.Parent) then return end
	styleRoninHair(character)
	applyRoninSkinTone(character)
	local faceBase = resolveRoninFaceBase(character)
	applyRoninFace(faceBase, roninAssets)
end

-- ============================================================
-- ПУБЛИЧНЫЙ API
-- ============================================================

--- Получить данные героя (Characters.lua → fallback → FlameRonin)
function CharacterService.GetHeroData(heroId)
	local normalizedId = HERO_ID_MAP[heroId] or heroId
	local data = Characters[normalizedId] or FALLBACK_STATS[normalizedId]
	if not data then
		warn(string.format("[CharacterService] Unknown heroId '%s' (normalized: '%s') — using FlameRonin",
			tostring(heroId), tostring(normalizedId)))
		return Characters.FlameRonin
	end
	return data
end

--- Получить выбранного героя игрока
function CharacterService.GetSelectedHero(userId)
	return selectedHeroes[userId]
end

--- Применить статы героя к персонажу
function CharacterService.ApplyStats(character, heroData)
	if not character or not heroData then return end

	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = heroData.hp or 100
		hum.Health    = hum.MaxHealth
		hum.WalkSpeed = heroData.speed or 16
	end

	-- Проверяем, что это наш Ронин
	print("[ApplyStats] heroData.id =", heroData.id)
	if heroData.id == "FlameRonin" or heroData.id == "flame_ronin" then
		-- 1) Удаляем старые аксессуары, чтобы не было наложений
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Accessory") then
				item:Destroy()
			end
		end

		-- 2) Подключаем кастомную голову + лицо + тон кожи
		local roninAssets = ReplicatedStorage:FindFirstChild("RoninAssets")
		print("[RoninMorph] RoninAssets found:", roninAssets ~= nil)
		local renderHead = attachRoninCustomHead(character, roninAssets, hum)
		applyRoninFace(renderHead, roninAssets)
		applyRoninSkinTone(character)

		-- 3) Надеваем волосы/оружие из RoninAssets (кроме head-ассетов)
		if roninAssets and hum then
			print("[RoninMorph] Assets count:", #roninAssets:GetChildren())
			for _, asset in ipairs(roninAssets:GetChildren()) do
				print("[RoninMorph] Asset:", asset.Name, "| Class:", asset.ClassName)
				local lowerName = string.lower(asset.Name)
				if string.find(lowerName, "head", 1, true) then
					print("[RoninMorph] Skip head asset (already handled):", asset.Name)
					continue
				end
				if hasToken(lowerName, TOKENS_KATANA) or hasToken(lowerName, TOKENS_KIMONO) then
					print("[RoninMorph] Skip local style asset (handled by ID visual pipeline):", asset.Name)
					continue
				end
				local clone = asset:Clone()
				if clone:IsA("Accessory") then
					normalizeAccessoryLook(clone, true)
					print("[RoninMorph] Adding Accessory:", clone.Name)
					-- Катана крепится на спину, всё остальное — стандартно
						if clone.Name == "Katana" then
							local handle = clone:FindFirstChild("Handle")
							if handle then
								local att = handle:FindFirstChildOfClass("Attachment")
								if att then
									att.Name = "BodyBackAttachment"
									att.CFrame = RONIN_KATANA_BACK_ATTACHMENT_CF
								end
							end
						end
					hum:AddAccessory(clone)
				elseif clone:IsA("Model") then
					print("[RoninMorph] Parenting Model:", clone.Name)
					clone.Parent = character
				else
					print("[RoninMorph] Unknown type, skipping:", clone.ClassName)
				end
			end
		end

		-- 4) Финальная стилизация Smoldering Flame Ronin
		task.defer(function()
			if character and character.Parent then
				applyFlameRoninVisualStyle(character, roninAssets)
				-- Re-apply face decal on top in case imported accessories changed head parts.
				local finalHead = resolveRoninFaceBase(character)
				applyRoninFace(finalHead, roninAssets)
				-- Late passes: layered accessories / appearance can override look shortly after spawn.
				for _, t in ipairs({ 0.2, 0.6, 1.2, 2.0 }) do
					task.delay(t, function()
						reapplyRoninCoreLook(character, roninAssets)
					end)
				end
			end
		end)
	end

	-- Стандартный тег героя
	local tag = character:FindFirstChild("HeroTag") or Instance.new("StringValue", character)
	tag.Name = "HeroTag"
	tag.Value = heroData.id
end

--- Спавнить с героем (базовый)
--- BUG-FIX: disconnect предыдущего коннекта, не накапливаем бесконечные коннекты
local spawnConnections = {}  -- [userId] = RBXScriptConnection

local function disconnectSpawnConn(userId)
	if spawnConnections[userId] then
		spawnConnections[userId]:Disconnect()
		spawnConnections[userId] = nil
	end
end

function CharacterService.SpawnWithHero(player, heroData)
	if not player or not heroData then return end
	selectedHeroes[player.UserId] = heroData
	disconnectSpawnConn(player.UserId)  -- BUG-FIX: убираем старый коннект

	local function applyToChar(character)
		task.wait(0.15)
		if not character or not character.Parent then return end
		CharacterService.ApplyStats(character, heroData)
		rCharacterSpawned:FireAllClients(player.UserId, heroData.id, heroData.name)
		-- FIX: НЕ вызываем CombatSystem.initPlayer здесь —
		-- это делает RoundService.StartRound с правильным matchId и mode.
		-- Двойной initPlayer перезаписывал состояние игрока matchId="default",
		-- из-за чего M1/скиллы тихо игнорировались (участники не совпадали по matchId).
	end

	-- BUG-FIX: НЕ вызываем LoadCharacter сами — RespawnHandler делает это
	-- Просто применяем к текущему персонажу если он уже есть
	if player.Character then
		task.spawn(applyToChar, player.Character)
	end
	spawnConnections[player.UserId] = player.CharacterAdded:Connect(applyToChar)
end

--- Спавнить с героем + применить GameMode модификаторы
function CharacterService.SpawnWithMode(player, heroData, gameMode, matchId)
	if not player or not heroData then return end
	selectedHeroes[player.UserId] = heroData
	disconnectSpawnConn(player.UserId)  -- BUG-FIX: убираем старый коннект

	local function applyToChar(character)
		task.wait(0.15)
		if not character or not character.Parent then return end
		CharacterService.ApplyStats(character, heroData)

		if _G.GameModeModifiers and gameMode then
			local ok, err = pcall(_G.GameModeModifiers.ApplyToPlayer, player, gameMode, heroData)
			if not ok then warn("[CharacterService] GameModeModifiers error:", err) end
		end

		rCharacterSpawned:FireAllClients(player.UserId, heroData.id, heroData.name)
		-- FIX: НЕ вызываем CombatSystem.initPlayer здесь —
		-- это делает RoundService.StartRound с правильным matchId и mode.
		-- Если matchId передан (вызов через GameManager.StartMatch), инициализируем.
		if _G.CombatSystem and matchId then
			_G.CombatSystem.initPlayer(player, heroData, matchId, gameMode)
		end
	end

	-- BUG-FIX: НЕ вызываем LoadCharacter сами — только применяем к текущему
	if player.Character then
		task.spawn(applyToChar, player.Character)
	end
	spawnConnections[player.UserId] = player.CharacterAdded:Connect(applyToChar)
end

-- ============================================================
-- REMOTE: выбор героя с клиента
-- ============================================================

rSelectHero.OnServerEvent:Connect(function(player, heroId)
	if type(heroId) ~= "string" then
		warn("[CharacterService] Invalid heroId from", player.Name)
		return
	end

	-- АНТИ-ЧИТ: проверяем, открыт ли герой у игрока
	if _G.DataStore then
		local pData = _G.DataStore.GetData(player.UserId)
		if pData and pData.unlockedHeroes and #pData.unlockedHeroes > 0 then
			local normalized = HERO_ID_MAP[heroId] or heroId
			if not table.find(pData.unlockedHeroes, normalized) then
				warn(string.format("[Anti-Cheat] %s попытка выбрать заблокированного героя '%s'",
					player.Name, heroId))
				return
			end
		end
	end

	local heroData = CharacterService.GetHeroData(heroId)
	selectedHeroes[player.UserId] = heroData
	rHeroSelected:FireClient(player, heroData.id, heroData.name)
	CharacterService.SpawnWithHero(player, heroData)

	-- Синхронизуем с HeroSelector.server
	if _G.HeroSelector and _G.HeroSelector.setSelected then
		_G.HeroSelector.setSelected(player.UserId, heroData)
	end

	-- Статистика игр за героя
	if _G.DataStore then
		_G.DataStore.RecordHeroPlay(player.UserId, heroData.id)
	end

	print(string.format("[CharacterService] %s selected: %s", player.Name, heroData.name))
end)

-- ============================================================
-- ОНБОРДИНГ: первый выбор стартового героя
-- ============================================================

local STARTER_HEROES = { "FlameRonin", "IronTitan", "ThunderMonk" }

local function shouldShowStarterSelection(pData)
	if type(pData) ~= "table" then
		return false
	end

	if pData.isFirstTime == true then
		return true
	end

	-- Fallback for partially migrated profiles: no first-time flag, no heroes yet.
	if type(pData.heroes) == "table" and next(pData.heroes) ~= nil then
		return false
	end
	if type(pData.unlockedHeroes) == "table" and #pData.unlockedHeroes > 0 then
		return false
	end

	return false
end

local function tryShowStarterSelection(player)
	if not player or not player.Parent then return end
	if shownStarterSelection[player.UserId] then return end

	local timeoutAt = os.clock() + 15
	while player.Parent and os.clock() < timeoutAt do
		local dataStore = _G.DataStore
		if dataStore and dataStore.GetData then
			local pData = dataStore.GetData(player.UserId)
			if pData then
				if shouldShowStarterSelection(pData) then
					shownStarterSelection[player.UserId] = true
					rShowStarter:FireClient(player)
				end
				return
			end
		end
		task.wait(0.5)
	end
end

-- При первом входе игрока отправляем ShowStarterSelection
Players.PlayerAdded:Connect(function(player)
	task.spawn(tryShowStarterSelection, player)
end)

rSelectStarter.OnServerEvent:Connect(function(player, heroId)
	if type(heroId) ~= "string" then return end
	local normalizedHeroId = HERO_ID_MAP[heroId] or heroId

	-- Проверяем: только стартовые герои допустимы
	if not table.find(STARTER_HEROES, normalizedHeroId) then
		warn(string.format("[CharacterService] %s попытка недопустимого стартера '%s'", player.Name, heroId))
		return
	end

	if not _G.DataStore then return end
	local pData = _G.DataStore.GetData(player.UserId)
	if not pData then return end
	if not pData.isFirstTime then return end  -- защита от повторного вызова

	_G.DataStore.UnlockHero(player.UserId, normalizedHeroId)
	_G.DataStore.SetFirstTimeDone(player.UserId)

	local heroData = CharacterService.GetHeroData(normalizedHeroId)
	selectedHeroes[player.UserId] = heroData
	shownStarterSelection[player.UserId] = nil
	CharacterService.SpawnWithHero(player, heroData)
	if _G.HeroSelector and _G.HeroSelector.setSelected then
		_G.HeroSelector.setSelected(player.UserId, heroData)
	end

	rHeroUnlocked:FireClient(player, normalizedHeroId)
	rShowNotification:FireClient(player,
		"🎉 Добро пожаловать! Ваш первый герой разблокирован!", "success")
	print(string.format("[CharacterService] %s выбрал стартера: %s", player.Name, normalizedHeroId))
end)

-- ============================================================
-- ЛОББИ — МИРНЫЙ СПАВН
-- ============================================================

-- Координаты точки спавна в лобби (переопределить под карту)
local LOBBY_SPAWN_CF = CFrame.new(0, 10, 0)

--- Спавнить игрока в нейтральной зоне лобби без героя и боевых тегов.
--- Вызывается при первом входе и при возврате из матча.
---@param player Player
---@param spawnCF CFrame|nil  — переопределить позицию спавна (опционально)
function CharacterService.SpawnInLobby(player, spawnCF)
	if not player or not player.Parent then return end

	-- Отключаем старый коннект, чтобы не накапливать
	disconnectSpawnConn(player.UserId)
	selectedHeroes[player.UserId] = nil

	-- Перезапускаем персонажа
	local ok, err = pcall(function() player:LoadCharacter() end)
	if not ok then
		warn("[CharacterService] LoadCharacter failed for", player.Name, ":", err)
		return
	end

	-- Ждём появления персонажа
	local char = player.Character or player.CharacterAdded:Wait()

	task.wait(0.2)  -- дать физике осесть
	if not char or not char.Parent then return end

	-- Телепортируем
	local cf = spawnCF or LOBBY_SPAWN_CF
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CFrame = cf end

	-- Убираем боевые теги
	local tag = char:FindFirstChild("HeroTag")
	if tag then tag:Destroy() end

	-- Стандартные параметры мирного состояния
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = 100
		hum.Health    = 100
		hum.WalkSpeed = 16
		hum.JumpPower = 50
	end

	print(string.format("[CharacterService] %s spawned in Lobby (peaceful)", player.Name))
end

--- Задать координаты точки спавна лобби (вызывается из NPCService при инициализации)
---@param cf CFrame
function CharacterService.SetLobbySpawn(cf)
	LOBBY_SPAWN_CF = cf
end

-- ============================================================
-- УБОРКА
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	disconnectSpawnConn(player.UserId)
	selectedHeroes[player.UserId] = nil
	shownStarterSelection[player.UserId] = nil
end)

print("[CharacterService] Initialized ✓")
