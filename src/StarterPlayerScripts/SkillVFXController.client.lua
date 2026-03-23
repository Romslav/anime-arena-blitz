-- SkillVFXController.client.lua | Anime Arena: Blitz
-- Слушает SkillUsed / SkillVFX / UltimateVFX / UpdateEffect Remotes
-- и проксирует их в VFXManager для всех 12 героев.
-- Также обрабатывает UltimateVFX: кинематические полосы + whiteout.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local VFXManager = require(script.Parent.VFXManager)

-- Единственный источник цветов — берём из VFXManager, не дублируем
local HERO_COLOR = VFXManager.HERO_COLOR

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local rSkillUsed    = Remotes:WaitForChild("SkillUsed",    10)
local rSkillVFX     = Remotes:WaitForChild("SkillVFX",     10)
local rUltVFX       = Remotes:WaitForChild("UltimateVFX",  10)
local rUpdateEffect = Remotes:WaitForChild("UpdateEffect", 10)
local rStatusApplied = Remotes:WaitForChild("StatusEffectApplied", 10)
local rStatusRemoved = Remotes:WaitForChild("StatusEffectRemoved", 10)
local rPlayerDied   = Remotes:WaitForChild("PlayerDied",   10)

-- ============================================================
-- ULTIMATE VFX GUI (полосы + white flash)
-- ============================================================

local vfxGui = Instance.new("ScreenGui")
vfxGui.Name            = "SkillVFXGui"
vfxGui.ResetOnSpawn    = false
vfxGui.DisplayOrder    = 45
vfxGui.IgnoreGuiInset  = true
vfxGui.Parent          = PlayerGui

local topBar = Instance.new("Frame")
topBar.Size             = UDim2.new(1,0,0,0)
topBar.BackgroundColor3 = Color3.fromRGB(0,0,0)
topBar.BorderSizePixel  = 0
topBar.ZIndex           = 46
topBar.Parent           = vfxGui

local botBar = Instance.new("Frame")
botBar.Size             = UDim2.new(1,0,0,0)
botBar.Position         = UDim2.new(0,0,1,0)
botBar.BackgroundColor3 = Color3.fromRGB(0,0,0)
botBar.BorderSizePixel  = 0
botBar.ZIndex           = 46
botBar.Parent           = vfxGui

local whiteFlash = Instance.new("Frame")
whiteFlash.Size                   = UDim2.new(1,0,1,0)
whiteFlash.BackgroundColor3       = Color3.fromRGB(255,255,255)
whiteFlash.BackgroundTransparency = 1
whiteFlash.BorderSizePixel        = 0
whiteFlash.ZIndex                 = 48
whiteFlash.Parent                 = vfxGui

-- Название скилла (billboard ульты)
local skillNameLbl = Instance.new("TextLabel")
skillNameLbl.Size                  = UDim2.new(1,0,0,50)
skillNameLbl.Position              = UDim2.new(0,0,0.5,-25)
skillNameLbl.BackgroundTransparency = 1
skillNameLbl.Text                  = ""
skillNameLbl.TextSize              = 42
skillNameLbl.TextColor3            = Color3.fromRGB(255,230,60)
skillNameLbl.Font                  = Enum.Font.GothamBold
skillNameLbl.TextXAlignment        = Enum.TextXAlignment.Center
skillNameLbl.TextTransparency      = 1
skillNameLbl.ZIndex                = 49
skillNameLbl.Parent                = vfxGui

-- Ульт-названия по герою
local ULT_NAMES = {
	FlameRonin    = "Phoenix Cut!",
	VoidAssassin  = "Silent Execution!",
	ThunderMonk   = "Heavenly Judgment!",
	IronTitan     = "Titan Fall!",
	ScarletArcher = "Storm of Arrows!",
	EclipseHero   = "Total Eclipse!",
	StormDancer   = "Cyclone Fury!",
	BloodSage     = "Blood Moon!",
	CrystalGuard  = "Crystal Fortress!",
	ShadowTwin    = "Dark Mirror!",
	NeonBlitz     = "Neon Overdrive!",
	JadeSentinel  = "Jade Wrath!",
}

local cinBusy = false
local function playCinematicBars(duration, heroColor)
	if cinBusy then return end
	cinBusy = true

	-- Строки влетают
	TweenService:Create(topBar, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
		Size = UDim2.new(1,0,0,56)
	}):Play()
	TweenService:Create(botBar, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
		Size     = UDim2.new(1,0,0,56),
		Position = UDim2.new(0,0,1,-56)
	}):Play()

	task.delay(0.22, function()
		-- Белая вспышка
		TweenService:Create(whiteFlash, TweenInfo.new(0.06), {
			BackgroundTransparency = 0.1
		}):Play()
		task.delay(0.1, function()
			TweenService:Create(whiteFlash, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
				BackgroundTransparency = 1
			}):Play()
		end)
	end)

	task.delay(0.3, function()
		-- Текст скилла
		skillNameLbl.TextColor3   = heroColor or Color3.fromRGB(255,230,60)
		skillNameLbl.Position     = UDim2.new(-0.4,0,0.5,-25)
		skillNameLbl.TextTransparency = 0
		TweenService:Create(skillNameLbl, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0,0,0.5,-25)
		}):Play()
	end)

	task.delay(duration - 0.4, function()
		-- Текст улетает
		TweenService:Create(skillNameLbl, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position         = UDim2.new(0.4,0,0.5,-25),
			TextTransparency = 1
		}):Play()
		-- Строки уезжают
		TweenService:Create(topBar, TweenInfo.new(0.2), { Size = UDim2.new(1,0,0,0) }):Play()
		TweenService:Create(botBar, TweenInfo.new(0.2), {
			Size     = UDim2.new(1,0,0,0),
			Position = UDim2.new(0,0,1,0)
		}):Play()
		task.delay(0.25, function() cinBusy = false end)
	end)
end

-- ============================================================
-- REMOTE HANDLERS
-- ============================================================

-- SkillUsed: server → all — (userId, slot, heroId, targetPos)
rSkillUsed.OnClientEvent:Connect(function(userId, slot, heroId, targetPos)
	VFXManager.PlaySkillVFX(userId, slot, heroId, targetPos)
end)

-- SkillVFX: алиас (userId, slot, targetPos, extra)
rSkillVFX.OnClientEvent:Connect(function(userId, slot, targetPos, extra)
	local heroId = extra and extra.heroId
		or (function()
			-- попытка взять heroId из CombatSystem
			if _G.CombatSystem then
				local s = _G.CombatSystem.getState(userId)
				return s and s.heroId
			end
		end)()
	if heroId then
		VFXManager.PlaySkillVFX(userId, slot, heroId, targetPos)
	end
end)

-- UltimateVFX: server → all — (userId, heroId)
rUltVFX.OnClientEvent:Connect(function(userId, heroId)
	local isLocal = (userId == LocalPlayer.UserId)
	local col = HERO_COLOR[heroId] or Color3.fromRGB(255,220,60)

	if isLocal then
		skillNameLbl.Text = ULT_NAMES[heroId] or (heroId .. " Ultimate!")
		playCinematicBars(1.8, col)
	end

	VFXManager.PlayUltVFX(userId, heroId)
end)

-- UpdateEffect: server → client — (effectType, isActive, duration)
rUpdateEffect.OnClientEvent:Connect(function(effectType, isActive, duration)
	-- Всегда относится к локальному игроку
	VFXManager.PlayStatusVFX(LocalPlayer.UserId, effectType, isActive, duration)
end)

-- StatusEffectApplied: (effectType, duration)
rStatusApplied.OnClientEvent:Connect(function(effectType, duration)
	VFXManager.PlayStatusVFX(LocalPlayer.UserId, effectType, true, duration)
end)

-- StatusEffectRemoved: (effectType)
rStatusRemoved.OnClientEvent:Connect(function(effectType)
	VFXManager.PlayStatusVFX(LocalPlayer.UserId, effectType, false)
end)

-- Очистка VFX при смерти
rPlayerDied.OnClientEvent:Connect(function(victimId)
	VFXManager.ClearStatusVFX(victimId)
end)

print("[SkillVFXController] Initialized ✓  | HERO_COLOR source: VFXManager.HERO_COLOR")
