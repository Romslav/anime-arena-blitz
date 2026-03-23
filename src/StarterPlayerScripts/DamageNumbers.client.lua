-- DamageNumbers.client.lua | Anime Arena: Blitz
-- Production floating damage numbers: Normal / Crit / Ultimate / Heal
-- BillboardGui над персонажем + TweenService анимация pop-in/float/fade
-- Триггер: Remote TakeDamage (targetPlayer, amount, dmgType)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local rTakeDamage = Remotes:WaitForChild("TakeDamage", 10)
local rHeal       = Remotes:FindFirstChild("Heal") or Remotes:WaitForChild("Heal", 3)

-- ============================================================
-- DAMAGE TYPE CONFIG
-- ============================================================

local TYPE_CONFIG = {
	Normal = {
		color     = Color3.fromRGB(255, 255, 255),
		stroke    = Color3.fromRGB(30,  30,  30),
		scale     = 1.0,
		prefix    = "",
		suffix    = "",
		popScale  = 1.35,
		floatY    = 4.5,
		lifetime  = 1.1,
	},
	Crit = {
		color     = Color3.fromRGB(255, 80,  30),
		stroke    = Color3.fromRGB(80,  10,   0),
		scale     = 1.55,
		prefix    = "",
		suffix    = "!",
		popScale  = 1.8,
		floatY    = 6.0,
		lifetime  = 1.3,
	},
	Ultimate = {
		color     = Color3.fromRGB(255, 200, 40),
		stroke    = Color3.fromRGB(100, 60,   0),
		scale     = 2.0,
		prefix    = "",
		suffix    = "!!",
		popScale  = 2.2,
		floatY    = 7.5,
		lifetime  = 1.6,
	},
	Heal = {
		color     = Color3.fromRGB(80,  255, 100),
		stroke    = Color3.fromRGB(10,  60,   20),
		scale     = 0.95,
		prefix    = "+",
		suffix    = "",
		popScale  = 1.25,
		floatY    = 4.0,
		lifetime  = 1.0,
	},
}

-- ============================================================
-- SPAWN DAMAGE NUMBER
-- ============================================================

local BASE_SIZE = 4  -- studs

local function spawnNumber(character, amount, dmgType)
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	dmgType = dmgType or "Normal"
	local cfg = TYPE_CONFIG[dmgType] or TYPE_CONFIG.Normal

	-- Лёгкая случайная оффсет чтобы числа не накладывались
	local randX = (math.random() - 0.5) * 3.5
	local startOffset = Vector3.new(randX, 3.2, 0)

	-- Attachment на HRP
	local att = Instance.new("Attachment")
	att.Position = startOffset
	att.Parent   = hrp

	-- BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Size             = UDim2.new(0, 160, 0, 60)
	bb.StudsOffsetWorldSpace = startOffset
	bb.AlwaysOnTop      = false
	bb.LightInfluence   = 0
	bb.Adornee          = hrp
	bb.Parent           = hrp

	local lbl = Instance.new("TextLabel")
	lbl.Size                = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text                = cfg.prefix .. tostring(math.abs(math.floor(amount))) .. cfg.suffix
	lbl.TextColor3          = cfg.color
	lbl.Font                = Enum.Font.GothamBold
	lbl.TextScaled          = true
	lbl.TextTransparency    = 0
	lbl.Parent              = bb

	-- Stroke (outline)
	local stroke = Instance.new("UIStroke")
	stroke.Color       = cfg.stroke
	stroke.Thickness   = dmgType == "Ultimate" and 4 or 2.5
	stroke.Parent      = lbl

	-- Scale modifier per type
	local baseStuds = BASE_SIZE * cfg.scale
	bb.Size = UDim2.new(0, math.floor(baseStuds * 40), 0, math.floor(baseStuds * 16))

	-- ---- ANIMATION ----
	local totalTime = cfg.lifetime
	local floatY    = cfg.floatY

	-- Phase 1: Pop-in (0 → popScale) за 0.08s
	bb.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(bb, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, math.floor(baseStuds * 40 * cfg.popScale),
						0, math.floor(baseStuds * 16 * cfg.popScale))
	}):Play()
	task.wait(0.08)

	-- Phase 2: Сжатие до нормального размера за 0.1s
	TweenService:Create(bb, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, math.floor(baseStuds * 40),
						0, math.floor(baseStuds * 16))
	}):Play()
	task.wait(0.10)

	-- Phase 3: Float up + fade over remaining time
	local floatTime = totalTime - 0.18
	TweenService:Create(bb, TweenInfo.new(floatTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = startOffset + Vector3.new(randX * 0.2, floatY, 0)
	}):Play()
	task.wait(floatTime * 0.4)

	-- Fade out during final 60% of float
	TweenService:Create(lbl, TweenInfo.new(floatTime * 0.6, Enum.EasingStyle.Quad), {
		TextTransparency = 1
	}):Play()

	Debris:AddItem(bb,  totalTime + 0.2)
	Debris:AddItem(att, totalTime + 0.2)
end

-- ============================================================
-- SPECIAL: ULTIMATE HIT FULL-SCREEN FLASH
-- ============================================================

local PlayerGui  = LocalPlayer:WaitForChild("PlayerGui")

local ultFlashGui = Instance.new("ScreenGui")
ultFlashGui.Name          = "UltFlash"
ultFlashGui.ResetOnSpawn  = false
ultFlashGui.DisplayOrder  = 40
ultFlashGui.IgnoreGuiInset = true
ultFlashGui.Parent        = PlayerGui

local flashFrame = Instance.new("Frame")
flashFrame.Size                   = UDim2.new(1,0,1,0)
flashFrame.BackgroundColor3       = Color3.fromRGB(255,240,100)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel        = 0
flashFrame.Parent                 = ultFlashGui

local function doUltFlash()
	flashFrame.BackgroundTransparency = 0.15
	TweenService:Create(flashFrame,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }):Play()
end

-- ============================================================
-- REMOTE HANDLERS
-- ============================================================

-- TakeDamage приходит как: (newHP, maxHP, amount, dmgType, attackerUserId)
rTakeDamage.OnClientEvent:Connect(function(newHP, maxHP, amount, dmgType, attackerUserId)
	-- Показываем число над персонажем локального игрока
	local char = LocalPlayer.Character
	if not char then return end

	if amount and amount > 0 then
		local resolvedType = dmgType or "Normal"
		task.spawn(spawnNumber, char, amount, resolvedType)
		if resolvedType == "Ultimate" then
			doUltFlash()
		end
	end
end)

-- Heal отдельно
if rHeal then
	rHeal.OnClientEvent:Connect(function(amount)
		local char = LocalPlayer.Character
		if char and amount and amount > 0 then
			task.spawn(spawnNumber, char, amount, "Heal")
		end
	end)
end

-- ============================================================
-- PUBLIC API через _G (для вызова из других скриптов)
-- ============================================================

_G.DamageNumbers = {
	Spawn = spawnNumber,
	UltFlash = doUltFlash,
}

print("[DamageNumbers] Initialized ✓")
