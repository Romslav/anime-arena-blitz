-- VFXManager.client.lua | Anime Arena: Blitz
-- Центральный менеджер VFX: порождает Beam, Highlight, BillboardGui-эффекты.
-- Слушает: UpdateEffect (Remote) — остатус-эффекты на персонаже локального игрока.
-- FIX #8: файл создан, чтобы Remote UpdateEffect не уходил в пустоту.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local UpdateEffect = Remotes:WaitForChild("UpdateEffect", 10)
if not UpdateEffect then
	warn("[VFXManager] UpdateEffect remote not found")
	return
end

-- ============================================================
-- Настройки эффектов
-- ============================================================

local EFFECT_CONFIG = {
	Burn = {
		highlightColor  = Color3.fromRGB(255, 80,  20),
		highlightOutline = Color3.fromRGB(255, 160, 0),
		tagText = "🔥",
		tagColor = Color3.fromRGB(255, 100, 0),
	},
	Poison = {
		highlightColor  = Color3.fromRGB(80,  200, 50),
		highlightOutline = Color3.fromRGB(40,  120, 20),
		tagText = "☠️",
		tagColor = Color3.fromRGB(100, 220, 60),
	},
	Stun = {
		highlightColor  = Color3.fromRGB(255, 240, 50),
		highlightOutline = Color3.fromRGB(200, 180, 0),
		tagText = "⚡",
		tagColor = Color3.fromRGB(255, 230, 0),
	},
	Slow = {
		highlightColor  = Color3.fromRGB(80,  120, 255),
		highlightOutline = Color3.fromRGB(40,  60,  200),
		tagText = "❄️",
		tagColor = Color3.fromRGB(100, 160, 255),
	},
	Shield = {
		highlightColor  = Color3.fromRGB(150, 220, 255),
		highlightOutline = Color3.fromRGB(60,  160, 230),
		tagText = "🛡️",
		tagColor = Color3.fromRGB(180, 230, 255),
	},
	Root = {
		highlightColor  = Color3.fromRGB(120, 80,  30),
		highlightOutline = Color3.fromRGB(80,  50,  10),
		tagText = "🌿",
		tagColor = Color3.fromRGB(150, 100, 40),
	},
	BuffDamage = {
		highlightColor  = Color3.fromRGB(255, 100, 180),
		highlightOutline = Color3.fromRGB(200, 40,  120),
		tagText = "⚔️",
		tagColor = Color3.fromRGB(255, 80, 160),
	},
	BuffSpeed = {
		highlightColor  = Color3.fromRGB(100, 255, 200),
		highlightOutline = Color3.fromRGB(0,   200, 140),
		tagText = "💨",
		tagColor = Color3.fromRGB(80, 240, 180),
	},
}

-- ============================================================
-- Состояние: [эффект] = { highlight, billboard, tween }
-- ============================================================

local activeVFX = {}

-- ============================================================
-- Сделать/убрать Highlight
-- ============================================================

local function applyHighlight(character, cfg)
	local hl = character:FindFirstChild("_VFX_Highlight")
	if not hl then
		hl = Instance.new("Highlight")
		hl.Name         = "_VFX_Highlight"
		hl.DepthMode    = Enum.HighlightDepthMode.Occluded
		hl.Parent       = character
	end
	hl.FillColor    = cfg.highlightColor
	hl.OutlineColor = cfg.highlightOutline
	hl.FillTransparency = 0.5
	return hl
end

local function removeHighlight(character)
	local hl = character:FindFirstChild("_VFX_Highlight")
	if hl then hl:Destroy() end
end

-- ============================================================
-- Сделать BillboardGui с эмодзи ("🔥", "⚡" и т.д.)
-- ============================================================

local function spawnTag(character, cfg)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local bb = Instance.new("BillboardGui")
	bb.Size            = UDim2.new(0, 40, 0, 40)
	bb.StudsOffset     = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop     = false
	bb.Name            = "_VFX_Tag"
	bb.Parent          = hrp

	local lbl = Instance.new("TextLabel")
	lbl.Size              = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text              = cfg.tagText
	lbl.TextColor3        = cfg.tagColor
	lbl.TextScaled        = true
	lbl.Font              = Enum.Font.GothamBold
	lbl.TextTransparency  = 0
	lbl.Parent            = bb

	-- Плавное появление
	lbl.TextTransparency = 1
	TweenService:Create(lbl, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	return bb
end

local function removeTag(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local bb = hrp:FindFirstChild("_VFX_Tag")
		if bb then
			-- Плавное исчезновение
			local lbl = bb:FindFirstChildOfClass("TextLabel")
			if lbl then
				local t = TweenService:Create(lbl, TweenInfo.new(0.2), { TextTransparency = 1 })
				t:Play()
				t.Completed:Connect(function() bb:Destroy() end)
			else
				bb:Destroy()
			end
		end
	end
end

-- ============================================================
-- Обработка событий
-- ============================================================

UpdateEffect.OnClientEvent:Connect(function(effectType, active, duration)
	local char = LocalPlayer.Character
	if not char then return end

	local cfg = EFFECT_CONFIG[effectType]
	if not cfg then return end  -- неизвестный эффект — пропускаем

	if active then
		-- Убираем старый VFX если есть
		if activeVFX[effectType] then
			if activeVFX[effectType].tag then removeTag(char) end
		end

		local hl  = applyHighlight(char, cfg)
		local tag = spawnTag(char, cfg)

		activeVFX[effectType] = { highlight = hl, tag = tag }

		-- Авто-чистка по истечению duration
		if duration and duration > 0 then
			task.delay(duration, function()
				if activeVFX[effectType] then
					removeTag(char)
					removeHighlight(char)
					activeVFX[effectType] = nil
				end
			end)
		end
	else
		-- Сервер сказал убрать эффект
		removeTag(char)
		removeHighlight(char)
		activeVFX[effectType] = nil
	end
end)

-- Чистим всё при респавне
LocalPlayer.CharacterRemoving:Connect(function()
	activeVFX = {}
end)

print("[VFXManager] Initialized ✓")
