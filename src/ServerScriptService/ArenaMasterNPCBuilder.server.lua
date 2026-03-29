-- ArenaMasterNPCBuilder.server.lua | Anime Arena: Blitz
-- Builds the full visual body of "The Stoic Sensei" NPC at runtime.
-- Architecture:
--   1. Waits for workspace.Lobby.NPCs.ArenasMaster model
--   2. Populates it with all Parts (body, kimono, armor, sword, FX)
--   3. Starts server-side animation loops (breath sway, sword aura pulse)
--   4. NPCService adds ProximityPrompt on top
-- All animations are server-driven -> auto-replicate to all clients.
-- Exports: _G.ArenaMasterNPCBuilder

local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CFG = require(ReplicatedStorage:WaitForChild("ArenaMasterConfig"))
local COL = CFG.Colors
local SZ  = CFG.Sizes
local OFF = CFG.Offsets
local A   = CFG.Anim
local PI  = math.pi

-- ============================================================
-- HELPERS
-- ============================================================

local function mkPart(model, name, cf, size, color, material, shape, transparency)
	local p        = Instance.new("Part")
	p.Name         = name
	p.Size         = size
	p.Color        = color
	p.Material     = material or Enum.Material.SmoothPlastic
	p.Shape        = shape or Enum.PartType.Block
	p.Transparency = transparency or 0
	p.Anchored     = true
	p.CanCollide   = false
	p.CastShadow   = false
	p.CFrame       = cf
	p.Parent       = model
	return p
end

local function mkSphere(model, name, cf, size, color, material, transparency)
	return mkPart(model, name, cf, size, color, material, Enum.PartType.Ball, transparency)
end

local function mkCylinder(model, name, cf, size, color, material, transparency)
	return mkPart(model, name, cf, size, color, material, Enum.PartType.Cylinder, transparency)
end

local function addLight(part, color, brightness, range)
	local l       = Instance.new("PointLight")
	l.Color       = color
	l.Brightness  = brightness or 2
	l.Range       = range or 8
	l.Shadows     = false
	l.Parent      = part
	return l
end

local function tagFX(part, tag)
	part:SetAttribute(tag, true)
end

-- ============================================================
-- WAIT FOR MODEL
-- ============================================================

-- BUG-3.2 FIX: Увеличены таймауты ожидания и добавлен retry-цикл.
-- Модель может появиться с задержкой если Rojo синхронизируется медленно.
local function waitForModel()
	local lobby
	for attempt = 1, 20 do
		lobby = workspace:FindFirstChild("Lobby")
		if lobby then break end
		warn("[ArenaMasterNPCBuilder] Waiting for workspace.Lobby... attempt " .. attempt)
		task.wait(2)
	end
	if not lobby then
		warn("[ArenaMasterNPCBuilder] workspace.Lobby not found after 40s — skipping build")
		return nil
	end

	local npcs = lobby:WaitForChild("NPCs", 15)
	if not npcs then
		warn("[ArenaMasterNPCBuilder] workspace.Lobby.NPCs not found — skipping build")
		return nil
	end

	local model = npcs:WaitForChild(CFG.NPC_MODEL_NAME, 15)
	if not model then
		warn("[ArenaMasterNPCBuilder] Model '" .. CFG.NPC_MODEL_NAME .. "' not found — skipping build")
		return nil
	end

	-- Ждём HumanoidRootPart (Rojo может создать модель раньше детей)
	local hrp = model:WaitForChild("HumanoidRootPart", 10)
	if not hrp then
		warn("[ArenaMasterNPCBuilder] HumanoidRootPart not found in model — skipping build")
		return nil
	end

	return model
end

-- ============================================================
-- BUILD CHARACTER
-- ============================================================

local function buildSensei(model)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then
		hrp             = Instance.new("Part")
		hrp.Name        = "HumanoidRootPart"
		hrp.Size        = SZ.HRP
		hrp.Anchored    = true
		hrp.CanCollide  = false
		hrp.Transparency = 1
		hrp.CFrame      = CFrame.new(0, 0, 0)
		hrp.Parent      = model
	else
		hrp.Size         = SZ.HRP
		hrp.Transparency = 1
		hrp.CanCollide   = false
	end

	local parts = {}

	local function p(name, offsetCF, size, color, material, shape, trans)
		local part = mkPart(model, name, hrp.CFrame * offsetCF, size, color, material, shape, trans)
		parts[name] = part
		return part
	end
	local function ps(name, offsetCF, size, color, material, trans)
		local part = mkSphere(model, name, hrp.CFrame * offsetCF, size, color, material, trans)
		parts[name] = part
		return part
	end

	-- -------------------------------------------------------
	-- HEAD
	-- -------------------------------------------------------
	p("Head", OFF.Head, SZ.Head, COL.Skin)
	p("EarR", OFF.EarR, Vector3.new(0.2, 0.35, 0.3), COL.SkinShade)
	p("EarL", OFF.EarL, Vector3.new(0.2, 0.35, 0.3), COL.SkinShade)
	p("Neck", OFF.Neck, SZ.Neck, COL.Skin)

	-- -------------------------------------------------------
	-- FACE
	-- -------------------------------------------------------
	p("EyeWhiteR", OFF.EyeR, SZ.Eye, COL.EyeWhite)
	p("EyeWhiteL", OFF.EyeL, SZ.Eye, COL.EyeWhite)
	p("IrisR", OFF.IrisR, SZ.EyeIris, COL.EyeIris)
	p("IrisL", OFF.IrisL, SZ.EyeIris, COL.EyeIris)

	-- Red eye glow (hidden by default, activated by client VFX)
	local eyeGlowR = ps("EyeGlowR", OFF.EyeGlowR, SZ.EyeGlow, COL.RedGlow, Enum.Material.Neon, 1)
	local eyeGlowL = ps("EyeGlowL", OFF.EyeGlowL, SZ.EyeGlow, COL.RedGlow, Enum.Material.Neon, 1)
	tagFX(eyeGlowR, "IsEyeGlow")
	tagFX(eyeGlowL, "IsEyeGlow")
	addLight(eyeGlowR, COL.RedGlow, 0, 4)
	addLight(eyeGlowL, COL.RedGlow, 0, 4)

	-- Eyebrows (thick, stern, angled inward)
	p("BrowR", OFF.BrowR, SZ.Eyebrow, COL.HairBlack)
	p("BrowL", OFF.BrowL, SZ.Eyebrow, COL.HairBlack)

	-- Scar across right eyebrow
	p("Scar", OFF.Scar, SZ.Scar, COL.Scar)

	-- Mouth (stern thin line)
	p("Mouth", OFF.Mouth, SZ.Mouth, COL.Mouth)

	-- Nose
	p("Nose", OFF.Nose, SZ.Nose, COL.SkinShade)

	-- Wrinkles (surov morshchiny)
	p("Wrinkle1", OFF.Wrinkle1, SZ.Wrinkle, COL.SkinShade)
	p("Wrinkle2", OFF.Wrinkle2, Vector3.new(0.5, 0.03, 0.04), COL.SkinShade)

	-- -------------------------------------------------------
	-- HAIR (short, messy black + grey temples)
	-- -------------------------------------------------------
	p("HairMain", OFF.HairMain, SZ.HairMain, COL.HairBlack)
	p("HairSpikeA", OFF.HairSpikeA, SZ.HairSpike, COL.HairBlack)
	p("HairSpikeB", OFF.HairSpikeB, Vector3.new(0.3, 0.2, 0.45), COL.HairBlack)
	p("HairSpikeC", OFF.HairSpikeC, Vector3.new(0.25, 0.2, 0.4), COL.HairBlack)
	p("HairSideR", OFF.HairSideR, SZ.HairSide, COL.HairBlack)
	p("HairSideL", OFF.HairSideL, SZ.HairSide, COL.HairBlack)
	p("HairBack", OFF.HairBack, SZ.HairBack, COL.HairBlack)

	-- Grey temples ("salt & pepper")
	p("TempleR", OFF.TempleR, SZ.Temple, COL.HairGrey)
	p("TempleL", OFF.TempleL, SZ.Temple, COL.HairGrey)
	p("GreyStreakA", OFF.GreyStreakA, SZ.GreyStreak, COL.HairGrey)
	p("GreyStreakB", OFF.GreyStreakB, Vector3.new(0.15, 0.12, 0.25), COL.HairGrey)

	-- -------------------------------------------------------
	-- TORSO (dark kimono/dogi)
	-- -------------------------------------------------------
	p("UpperTorso", OFF.UpperTorso, SZ.UpperTorso, COL.Dogi)
	p("LowerTorso", OFF.LowerTorso, SZ.LowerTorso, COL.Dogi)

	-- Kimono collar (V-shape opening)
	p("CollarR", OFF.CollarR, SZ.Collar, COL.Dogi)
	p("CollarL", OFF.CollarL, SZ.Collar, COL.Dogi)
	p("InnerShirt", OFF.InnerShirt, Vector3.new(0.5, 0.8, 0.06), COL.SkinShade)

	-- Fabric folds
	for i = 0, 2 do
		p("FabricFold" .. i, OFF.UpperTorso * CFrame.new(0.3 - i * 0.3, -0.22, -0.72),
			Vector3.new(0.06, 0.6, 0.08), COL.DogiWorn)
	end

	-- -------------------------------------------------------
	-- OBSIDIAN PAULDRONS
	-- -------------------------------------------------------
	local pr = p("PauldronR", OFF.PauldronR, SZ.Pauldron, COL.Obsidian)
	pr.Reflectance = 0.3
	p("PauldronREdge", OFF.PauldronREdge, SZ.PauldronEdge, COL.Obsidian)
	local prGlow = p("PauldronRGlow", OFF.PauldronRGlow, SZ.PauldronGlow, COL.RedGlow, Enum.Material.Neon)
	tagFX(prGlow, "IsPauldronGlow")

	local pl = p("PauldronL", OFF.PauldronL, SZ.Pauldron, COL.Obsidian)
	pl.Reflectance = 0.3
	p("PauldronLEdge", OFF.PauldronLEdge, SZ.PauldronEdge, COL.Obsidian)
	local plGlow = p("PauldronLGlow", OFF.PauldronLGlow, SZ.PauldronGlow, COL.RedGlow, Enum.Material.Neon)
	tagFX(plGlow, "IsPauldronGlow")

	-- -------------------------------------------------------
	-- OBI BELT + GOLD KANJI + RANK PLATE
	-- -------------------------------------------------------
	p("Obi", OFF.Obi, SZ.Obi, COL.ObiBelt)

	-- Gold kanji embroidery on obi
	for i = 0, 4 do
		local kanjiPart = p("ObiKanji" .. i,
			OFF.Obi * CFrame.new(-0.7 + i * 0.35, 0, -0.72),
			SZ.ObiKanji, COL.GoldGlow, Enum.Material.Neon)
		tagFX(kanjiPart, "IsGoldKanji")
	end

	p("ObiKnot", OFF.ObiKnot, SZ.ObiKnot, COL.ObiBelt)

	-- SSS RANK plate
	p("RankPlate", OFF.RankPlate, SZ.RankPlate, COL.RankPlate, Enum.Material.Metal)
	for i = 0, 2 do
		local sss = p("SSSMark" .. i,
			OFF.RankPlate * CFrame.new(-0.1 + i * 0.1, 0, -0.05),
			SZ.SSSMark, COL.GoldGlow, Enum.Material.Neon)
		tagFX(sss, "IsGoldKanji")
	end

	-- -------------------------------------------------------
	-- ARMS (crossed on chest — stoic pose)
	-- -------------------------------------------------------
	p("RUpperArm", OFF.RUpperArm, SZ.UpperArm, COL.Dogi)
	p("RForearm", OFF.RForearm, SZ.Forearm, COL.Dogi)
	p("RHand", OFF.RHand, SZ.Hand, COL.Skin)

	p("LUpperArm", OFF.LUpperArm, SZ.UpperArm, COL.Dogi)
	p("LForearm", OFF.LForearm, SZ.Forearm, COL.Dogi)
	p("LHand", OFF.LHand, SZ.Hand, COL.Skin)

	-- -------------------------------------------------------
	-- SPIKED BRACERS
	-- -------------------------------------------------------
	p("BracerR", OFF.BracerR, SZ.Bracer, COL.DarkMetal, Enum.Material.Metal)
	for i = 0, 2 do
		p("SpikeR" .. i,
			OFF.BracerR * CFrame.new(0.1 - i * 0.15, -0.15, 0),
			SZ.Spike, COL.MetalSpike, Enum.Material.Metal)
	end

	p("BracerL", OFF.BracerL, SZ.Bracer, COL.DarkMetal, Enum.Material.Metal)
	for i = 0, 2 do
		p("SpikeL" .. i,
			OFF.BracerL * CFrame.new(-0.1 + i * 0.15, -0.15, 0),
			SZ.Spike, COL.MetalSpike, Enum.Material.Metal)
	end

	-- -------------------------------------------------------
	-- HAORI CLOAK
	-- -------------------------------------------------------
	p("HaoriBack", OFF.HaoriBack, SZ.HaoriBack, COL.Haori)
	p("HaoriSideR", OFF.HaoriSideR, SZ.HaoriSide, COL.Haori)
	p("HaoriSideL", OFF.HaoriSideL, SZ.HaoriSide, COL.Haori)
	p("HaoriCollarR", OFF.HaoriCollarR, SZ.HaoriCollar, COL.Haori)
	p("HaoriCollarL", OFF.HaoriCollarL, SZ.HaoriCollar, COL.Haori)

	-- -------------------------------------------------------
	-- GOLD KANJI ON BACK: 電光 (Lightning/Blitz) + ⚡
	-- -------------------------------------------------------
	local backBase = OFF.KanjiBackBase

	-- 電 (Den - Electric) - upper
	local function kanjiStroke(suffix, dx, dy, sizeOverride)
		local strokePart = p("KanjiDen_" .. suffix,
			backBase * CFrame.new(dx, dy, 0),
			sizeOverride or SZ.KanjiH, COL.GoldGlow, Enum.Material.Neon)
		tagFX(strokePart, "IsGoldKanji")
		return strokePart
	end

	kanjiStroke("H1", 0, 0.6)                                      -- top bar
	kanjiStroke("VL", -0.3, 0.4, SZ.KanjiV)                       -- left vert
	kanjiStroke("VR", 0.3, 0.4, SZ.KanjiV)                        -- right vert
	kanjiStroke("H2", 0, 0.25, Vector3.new(0.65, 0.06, 0.04))     -- mid bar
	kanjiStroke("D1", -0.15, 0.35, SZ.KanjiDot)                   -- rain dot L
	kanjiStroke("D2", 0.15, 0.35, SZ.KanjiDot)                    -- rain dot R
	kanjiStroke("H3", 0, 0.05, Vector3.new(0.55, 0.06, 0.04))    -- bottom bar
	kanjiStroke("VC", 0, -0.1, SZ.KanjiV)                          -- center vert
	kanjiStroke("L1", -0.15, -0.25, Vector3.new(0.06, 0.15, 0.04)) -- leg L
	kanjiStroke("L2", 0.15, -0.25, Vector3.new(0.06, 0.15, 0.04))  -- leg R

	-- 光 (Ko - Light) - lower
	kanjiStroke("Ko_H1", 0, -0.5, Vector3.new(0.5, 0.06, 0.04))
	kanjiStroke("Ko_V1", 0, -0.7, SZ.KanjiV)
	kanjiStroke("Ko_DL", -0.2, -0.9, Vector3.new(0.06, 0.2, 0.04))
	kanjiStroke("Ko_DR", 0.2, -0.9, Vector3.new(0.06, 0.2, 0.04))
	kanjiStroke("Ko_FL", -0.25, -1.05, Vector3.new(0.15, 0.06, 0.04))
	kanjiStroke("Ko_FR", 0.25, -1.05, Vector3.new(0.15, 0.06, 0.04))

	-- Lightning bolt ⚡ below kanji
	local boltParts = {
		{0.05, -1.25, 0.3},
		{0.0, -1.38, -0.2},
		{-0.05, -1.5, 0.3},
		{-0.1, -1.62, -0.2},
	}
	for i, bp in ipairs(boltParts) do
		local bolt = p("LightningBolt" .. i,
			backBase * CFrame.new(bp[1], bp[2], 0)
				* CFrame.Angles(0, 0, bp[3]),
			SZ.LightningBolt, COL.Lightning, Enum.Material.Neon)
		tagFX(bolt, "IsLightning")
		if i == 1 then addLight(bolt, COL.Lightning, 3, 6) end
	end

	-- -------------------------------------------------------
	-- HAKAMA PANTS
	-- -------------------------------------------------------
	p("RThigh", OFF.RThigh, SZ.Thigh, COL.Hakama)
	p("RShin", OFF.RShin, SZ.Shin, COL.Hakama)
	p("LThigh", OFF.LThigh, SZ.Thigh, COL.Hakama)
	p("LShin", OFF.LShin, SZ.Shin, COL.Hakama)

	-- Hakama pleats
	for side = -1, 1, 2 do
		local prefix = side > 0 and "R" or "L"
		local sx = side * 0.55
		for i = 0, 2 do
			p("HakamaFold_" .. prefix .. "_" .. i,
				CFrame.new(sx + (i - 1) * 0.15, 0, 0) * OFF.RShin * CFrame.new(0, 0, -0.42),
				Vector3.new(0.04, 1.8, 0.04), COL.Hakama)
		end
	end

	-- -------------------------------------------------------
	-- FEET (Waraji + Tabi + Metal sole)
	-- -------------------------------------------------------
	for _, side in ipairs({"R", "L"}) do
		local footOff = side == "R" and OFF.RFoot or OFF.LFoot
		p(side .. "Tabi", footOff, SZ.Tabi, COL.Tabi)
		p(side .. "Waraji", footOff * CFrame.new(0, -0.07, 0), SZ.Waraji, COL.Waraji)
		p(side .. "SoleMetal", footOff * CFrame.new(0, -0.15, 0), SZ.MetalSole, COL.MetalSole, Enum.Material.Metal)
		-- Waraji straps
		p(side .. "WarajiStrap1", footOff * CFrame.new(0, 0, -0.2),
			Vector3.new(0.45, 0.15, 0.04), COL.Waraji)
		p(side .. "WarajiStrap2", footOff * CFrame.new(0, 0.05, -0.1),
			Vector3.new(0.04, 0.12, 0.15), COL.Waraji)
	end

	-- -------------------------------------------------------
	-- NODACHI (huge katana at left hip)
	-- -------------------------------------------------------
	p("NodachiSheath", OFF.NodachiSheath, SZ.Sheath, COL.Sheath)
	p("SheathTip", OFF.SheathTip, SZ.SheathTip, COL.DarkMetal, Enum.Material.Metal)
	mkCylinder(model, "Tsuba", hrp.CFrame * OFF.Tsuba, SZ.Tsuba, COL.Tsuba, Enum.Material.Metal)
	parts["Tsuba"] = model:FindFirstChild("Tsuba")

	p("NodachiHandle", OFF.Handle, SZ.Handle, COL.SwordWrap)
	-- Diamond wrap pattern
	for i = 0, 3 do
		p("HandleWrap" .. i,
			OFF.Handle * CFrame.new(0, -0.15 + i * 0.12, 0)
				* CFrame.Angles(0, (i % 2 == 0) and 0.4 or -0.4, 0),
			SZ.HandleWrap, COL.Gold, Enum.Material.Metal)
	end
	p("Pommel", OFF.Pommel, SZ.Pommel, COL.DarkMetal, Enum.Material.Metal)

	-- Sword red aura (pulsing, semi-transparent)
	local swordAura = p("SwordAura", OFF.SwordAura, SZ.SwordAura, COL.RedGlow, Enum.Material.Neon, nil, 0.7)
	tagFX(swordAura, "IsSwordAura")
	addLight(swordAura, COL.RedGlow, 2, 5)

	-- -------------------------------------------------------
	-- RED FLOATING KANJI PARTICLES (around body)
	-- -------------------------------------------------------
	math.randomseed(42)
	for i = 1, A.KanjiCount do
		local angle = i * (PI * 2 / A.KanjiCount)
		local radius = 1.8 + (math.random() - 0.5) * 0.6
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local y = -0.5 + math.random() * 3.5

		local kanjiParticle = p("RedKanji" .. i,
			CFrame.new(x, y, z) * hrp.CFrame:Inverse() * hrp.CFrame,
			Vector3.new(0.12 + math.random() * 0.08, 0.15 + math.random() * 0.1, 0.02),
			COL.RedAura, Enum.Material.Neon, nil, 0.5)
		-- Store initial orbit data
		kanjiParticle:SetAttribute("OrbitAngle", angle)
		kanjiParticle:SetAttribute("OrbitRadius", radius)
		kanjiParticle:SetAttribute("OrbitY", y)
		tagFX(kanjiParticle, "IsRedKanji")
	end

	-- Red mist at feet
	local mist = p("RedMistBase", OFF.RedMistBase, SZ.RedMistBase, COL.RedAura, Enum.Material.Neon, nil, 0.8)
	tagFX(mist, "IsRedMist")
	addLight(mist, COL.RedGlow, 1, 4)

	-- -------------------------------------------------------
	-- PARTICLE EMITTER for continuous red aura (attached to HRP)
	-- -------------------------------------------------------
	local auraEmitter          = Instance.new("ParticleEmitter")
	auraEmitter.Name           = "RedAuraEmitter"
	auraEmitter.Color          = ColorSequence.new(COL.RedGlow, COL.RedAura)
	-- BUG-3.3 FIX: Увеличены размеры частиц для объёмной 3D ауры
	-- (было 0.2→0.8→0, стало 0.5→1.8→0 — более заметно)
	auraEmitter.Size           = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	auraEmitter.Transparency   = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.3, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	auraEmitter.Lifetime       = NumberRange.new(1.5, 3.0)
	auraEmitter.Rate           = 8
	auraEmitter.Speed          = NumberRange.new(0.1, 0.4)
	auraEmitter.SpreadAngle    = Vector2.new(180, 180)
	auraEmitter.RotSpeed       = NumberRange.new(-30, 30)
	auraEmitter.LightEmission  = 0.6
	auraEmitter.Parent         = hrp

	-- Sword trail effect (ParticleEmitter on sheath)
	local swordEmitter          = Instance.new("ParticleEmitter")
	swordEmitter.Name           = "SwordAuraEmitter"
	swordEmitter.Color          = ColorSequence.new(COL.RedGlow)
	swordEmitter.Size           = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	swordEmitter.Transparency   = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	swordEmitter.Lifetime       = NumberRange.new(0.8, 1.5)
	swordEmitter.Rate           = 12
	swordEmitter.Speed          = NumberRange.new(0.05, 0.2)
	swordEmitter.SpreadAngle    = Vector2.new(60, 60)
	swordEmitter.LightEmission  = 0.8
	swordEmitter.Parent         = parts["NodachiSheath"]

	print(string.format("[ArenaMasterNPCBuilder] Built %d parts", #model:GetDescendants()))
	return parts
end

-- ============================================================
-- SERVER ANIMATIONS
-- ============================================================

local function startAnimations(model, parts)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- -------------------------------------------------------
	-- 1. SWORD AURA PULSE
	-- -------------------------------------------------------
	local swordAura = parts["SwordAura"]
	if swordAura then
		task.spawn(function()
			local auraLight = swordAura:FindFirstChildOfClass("PointLight")
			while swordAura and swordAura.Parent do
				local t    = tick()
				local wave = (math.sin(t * A.SwordAuraPulseSpeed * PI) + 1) * 0.5
				swordAura.Transparency = A.SwordAuraPulseMin + wave * (A.SwordAuraPulseMax - A.SwordAuraPulseMin)
				if auraLight then
					auraLight.Brightness = 1 + wave * 2
				end
				task.wait(1 / 20)
			end
		end)
	end

	-- -------------------------------------------------------
	-- 2. FLOATING RED KANJI ORBIT
	-- -------------------------------------------------------
	task.spawn(function()
		while model and model.Parent do
			local t = tick()
			for i = 1, A.KanjiCount do
				local kp = model:FindFirstChild("RedKanji" .. i)
				if kp then
					local baseAngle  = kp:GetAttribute("OrbitAngle") or 0
					local radius     = kp:GetAttribute("OrbitRadius") or 1.8
					local baseY      = kp:GetAttribute("OrbitY") or 1.0

					local angle = baseAngle + t * A.KanjiOrbitSpeed
					local x = math.cos(angle) * radius
					local z = math.sin(angle) * radius
					local y = baseY + math.sin(t * A.KanjiFloatSpeed + i) * A.KanjiFloatAmplitude

					kp.CFrame = hrp.CFrame * CFrame.new(x, y, z)
						* CFrame.Angles(0, -angle, 0)
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)

	-- -------------------------------------------------------
	-- 3. RED MIST AURA PULSE
	-- -------------------------------------------------------
	local mist = parts["RedMistBase"]
	if mist then
		task.spawn(function()
			while mist and mist.Parent do
				local t = tick()
				local breathPhase = (t % A.AuraBreathCycle) / A.AuraBreathCycle
				local wave = (math.sin(t * A.AuraPulseSpeed * PI) + 1) * 0.5
				local baseTrans = A.AuraPulseMin + wave * (A.AuraPulseMax - A.AuraPulseMin)

				-- Slight flare on "exhale" (breath phase ~0.5)
				local breathFlare = math.max(0, math.sin(breathPhase * PI * 2)) * A.AuraBreathFlare
				mist.Transparency = math.clamp(baseTrans - breathFlare, 0.5, 0.95)

				task.wait(1 / 15)
			end
		end)
	end

	-- -------------------------------------------------------
	-- 4. GOLD KANJI SUBTLE GLOW PULSE
	-- -------------------------------------------------------
	task.spawn(function()
		local goldParts = {}
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("BasePart") and desc:GetAttribute("IsGoldKanji") then
				table.insert(goldParts, desc)
			end
		end
		while model and model.Parent do
			local t    = tick()
			local wave = (math.sin(t * 0.8 * PI) + 1) * 0.5
			local trans = wave * 0.15  -- subtle 0..0.15
			for _, gp in ipairs(goldParts) do
				if gp and gp.Parent then
					gp.Transparency = trans
				end
			end
			task.wait(1 / 20)
		end
	end)

	-- -------------------------------------------------------
	-- 5. SUBTLE BREATH SWAY (haori movement)
	-- -------------------------------------------------------
	local haoriBack = parts["HaoriBack"]
	if haoriBack then
		local baseOffset = OFF.HaoriBack
		task.spawn(function()
			while haoriBack and haoriBack.Parent do
				local t = tick()
				local sway = math.sin(t * A.BreathSwaySpeed * PI) * A.BreathSwayAmplitude
				haoriBack.CFrame = hrp.CFrame * baseOffset
					* CFrame.new(sway, 0, 0)
					* CFrame.Angles(0, 0, sway * 0.02)
				task.wait(1 / 30)
			end
		end)
	end

	-- -------------------------------------------------------
	-- 6. PAULDRON GLOW PULSE
	-- -------------------------------------------------------
	task.spawn(function()
		local glowParts = {}
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("BasePart") and desc:GetAttribute("IsPauldronGlow") then
				table.insert(glowParts, desc)
			end
		end
		while model and model.Parent do
			local t    = tick()
			local wave = (math.sin(t * 1.2 * PI) + 1) * 0.5
			local trans = 0.3 + wave * 0.4
			for _, gp in ipairs(glowParts) do
				if gp and gp.Parent then
					gp.Transparency = trans
				end
			end
			task.wait(1 / 20)
		end
	end)

	print("[ArenaMasterNPCBuilder] All animations started")
end

-- ============================================================
-- MAIN ENTRY POINT
-- ============================================================

local Builder = {}
_G.ArenaMasterNPCBuilder = Builder

task.spawn(function()
	-- BUG-3.2 FIX: waitForModel теперь возвращает nil вместо error
	local ok, model = pcall(waitForModel)
	if not ok then
		warn("[ArenaMasterNPCBuilder] pcall error: " .. tostring(model))
		return
	end
	if not model then
		warn("[ArenaMasterNPCBuilder] Model not available — NPC will not be built.")
		return
	end

	-- Hot-reload guard
	if model:FindFirstChild("UpperTorso") then
		print("[ArenaMasterNPCBuilder] Model already built, skipping.")
		return
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed       = 0
		hum.JumpPower       = 0
		hum.PlatformStand   = true
		hum.AutoJumpEnabled = false
	end

	print("[ArenaMasterNPCBuilder] Building The Stoic Sensei body...")

	local parts = buildSensei(model)
	Builder.Model = model
	Builder.Parts = parts

	task.wait(0.5)
	startAnimations(model, parts)

	print("[ArenaMasterNPCBuilder] The Stoic Sensei stands ready.")
end)

return Builder
