-- UltimateVFX.client.lua | Anime Arena: Blitz
-- Обрабатывает Remote UltimateVFX — показывает эффекты ультимэйтов с затемнением экрана.
-- FIX #8: файл создан, чтобы Remote UltimateVFX не уходил в пустоту.
-- Данные: (userId, heroId, originPos)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local UltimateVFX  = Remotes:WaitForChild("UltimateVFX", 10)
if not UltimateVFX then
	warn("[UltimateVFX] Remote 'UltimateVFX' not found")
	return
end

-- ============================================================
-- Цвета ульт по герою
-- ============================================================

local ULT_COLORS = {
	FlameRonin    = { primary = Color3.fromRGB(255, 60,  0),   secondary = Color3.fromRGB(255, 200, 0)   },
	VoidAssassin  = { primary = Color3.fromRGB(120, 20,  200), secondary = Color3.fromRGB(200, 80,  255)  },
	ThunderMonk   = { primary = Color3.fromRGB(80,  170, 255), secondary = Color3.fromRGB(255, 255, 80)   },
	IronTitan     = { primary = Color3.fromRGB(160, 160, 160), secondary = Color3.fromRGB(255, 220, 100)  },
	ScarletArcher = { primary = Color3.fromRGB(220, 40,  60),  secondary = Color3.fromRGB(255, 150, 100)  },
	EclipseHero   = { primary = Color3.fromRGB(60,  30,  140), secondary = Color3.fromRGB(200, 100, 255)  },
	StormDancer   = { primary = Color3.fromRGB(100, 220, 255), secondary = Color3.fromRGB(255, 255, 255)  },
	BloodSage     = { primary = Color3.fromRGB(200, 10,  10),  secondary = Color3.fromRGB(255, 80,  80)   },
	CrystalGuard  = { primary = Color3.fromRGB(100, 200, 230), secondary = Color3.fromRGB(200, 240, 255)  },
	ShadowTwin    = { primary = Color3.fromRGB(50,  50,  70),  secondary = Color3.fromRGB(160, 120, 200)  },
	NeonBlitz     = { primary = Color3.fromRGB(0,   255, 180), secondary = Color3.fromRGB(0,   200, 255)  },
	JadeSentinel  = { primary = Color3.fromRGB(80,  200, 100), secondary = Color3.fromRGB(200, 255, 180)  },
	_default      = { primary = Color3.fromRGB(255, 220, 50),  secondary = Color3.fromRGB(255, 255, 255)  },
}

-- ============================================================
-- Затемнение экрана (только для локального игрока)
-- ============================================================

local function flashScreen(color, duration)
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end

	local sg = Instance.new("ScreenGui")
	sg.Name = "_UltFlash"
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 100
	sg.ResetOnSpawn = false
	sg.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = sg

	-- Быстрое затемнение → исчезновение
	TweenService:Create(frame, TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()

	Debris:AddItem(sg, (duration or 0.6) + 0.1)
end

-- ============================================================
-- Большое кольцо в ворлдспейсе
-- ============================================================

local function spawnUltRing(origin, colors)
	-- Внешнее кольцо
	local outer = Instance.new("Part")
	outer.Anchored     = true
	outer.CanCollide   = false
	outer.CastShadow   = false
	outer.Size         = Vector3.new(2, 0.4, 2)
	outer.Shape        = Enum.PartType.Cylinder
	outer.CFrame       = CFrame.new(origin + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	outer.Color        = colors.primary
	outer.Material     = Enum.Material.Neon
	outer.Transparency = 0.2
	outer.Parent       = workspace

	-- Внутреннее кольцо
	local inner = Instance.new("Part")
	inner.Anchored     = true
	inner.CanCollide   = false
	inner.CastShadow   = false
	inner.Size         = Vector3.new(1, 0.6, 1)
	inner.Shape        = Enum.PartType.Cylinder
	inner.CFrame       = CFrame.new(origin + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	inner.Color        = colors.secondary
	inner.Material     = Enum.Material.Neon
	inner.Transparency = 0.0
	inner.Parent       = workspace

	-- Анимация: расширение + исчезновение
	TweenService:Create(outer, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size        = Vector3.new(36, 0.2, 36),
		Transparency = 1,
	}):Play()
	TweenService:Create(inner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size        = Vector3.new(20, 0.4, 20),
		Transparency = 0.85,
	}):Play()

	Debris:AddItem(outer, 0.85)
	Debris:AddItem(inner, 0.85)
end

-- ============================================================
-- Текстовое уведомление с названием ульты (только для локального)
-- ============================================================

local ULT_NAMES = {
	FlameRonin    = "🔥 PHOENIX CUT!",
	VoidAssassin  = "🖤 SILENT EXECUTION!",
	ThunderMonk   = "⚡ HEAVENLY JUDGMENT!",
	IronTitan     = "💥 TITAN FALL!",
	ScarletArcher = "🎯 STORM OF ARROWS!",
	EclipseHero   = "🌑 TOTAL ECLIPSE!",
	StormDancer   = "🌪️ CYCLONE FURY!",
	BloodSage     = "🩸 BLOOD MOON!",
	CrystalGuard  = "❄️ CRYSTAL FORTRESS!",
	ShadowTwin    = "👥 DARK MIRROR!",
	NeonBlitz     = "⚡ NEON OVERDRIVE!",
	JadeSentinel  = "🟢 JADE WRATH!",
}

local function showUltLabel(heroId, color)
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end

	local sg = Instance.new("ScreenGui")
	sg.Name = "_UltLabel"
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 101
	sg.ResetOnSpawn = false
	sg.Parent = playerGui

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(0.7, 0, 0.12, 0)
	lbl.Position           = UDim2.new(0.15, 0, 0.38, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = ULT_NAMES[heroId] or (heroId .. " ULTIMATE!")
	lbl.TextColor3         = color
	lbl.TextScaled         = true
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextTransparency   = 0
	lbl.Parent             = sg
	do
		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(0, 0, 0)
		s.Thickness = 3
		s.Parent = lbl
	end

	-- Появление → задержка → исчезновение
	task.delay(0.7, function()
		if lbl.Parent then
			TweenService:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
	Debris:AddItem(sg, 1.2)
end

-- ============================================================
-- Обработка события
-- ============================================================

UltimateVFX.OnClientEvent:Connect(function(userId, heroId, originPos)
	local colors = ULT_COLORS[heroId] or ULT_COLORS._default

	-- Определяем позицию
	local origin = originPos
	if not origin then
		local player = Players:GetPlayerByUserId(userId)
		if player and player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then origin = hrp.Position end
		end
	end

	-- Кольцо в ворлдспейсе
	if origin then
		spawnUltRing(origin, colors)
	end

	-- Только для локального игрока: мигание + название ульты
	if userId == LocalPlayer.UserId then
		flashScreen(colors.primary, 0.5)
		task.delay(0.05, function()
			showUltLabel(heroId, colors.secondary)
		end)
	end
end)

print("[UltimateVFX] Initialized ✓")
