-- SkillVFX.client.lua | Anime Arena: Blitz
-- Обрабатывает Remote SkillVFX — показывает визуальные эффекты скиллов.
-- FIX #8: файл создан, чтобы Remote SkillVFX не уходил в пустоту.
-- Данные: (userId, heroId, skillSlot, originPos, targetPos)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local Remotes  = ReplicatedStorage:WaitForChild("Remotes")
local SkillVFX = Remotes:WaitForChild("SkillVFX", 10)
if not SkillVFX then
	warn("[SkillVFX] Remote 'SkillVFX' not found")
	return
end

-- ============================================================
-- Настройки эффектов по герою
-- ============================================================

local VFX_PRESETS = {
	FlameRonin = {
		Q = { color = Color3.fromRGB(255, 90,  10),  shape = "ring",   size = 7  },
		E = { color = Color3.fromRGB(255, 150, 50),  shape = "burst",  size = 5  },
		F = { color = Color3.fromRGB(255, 200, 80),  shape = "shield", size = 4  },
		R = { color = Color3.fromRGB(255, 50,  0),   shape = "ring",   size = 16 },
	},
	VoidAssassin = {
		Q = { color = Color3.fromRGB(140, 40,  220),  shape = "blink",  size = 4  },
		E = { color = Color3.fromRGB(100, 20,  160),  shape = "fade",   size = 3  },
		F = { color = Color3.fromRGB(200, 80,  255),  shape = "mark",   size = 5  },
		R = { color = Color3.fromRGB(80,  0,   180),  shape = "burst",  size = 12 },
	},
	ThunderMonk = {
		Q = { color = Color3.fromRGB(80,  170, 255),  shape = "beam",   size = 6  },
		E = { color = Color3.fromRGB(50,  130, 255),  shape = "ring",   size = 14 },
		F = { color = Color3.fromRGB(180, 220, 255),  shape = "dash",   size = 3  },
		R = { color = Color3.fromRGB(255, 255, 100),  shape = "burst",  size = 26 },
	},
	-- Фоллбэк для остальных героев
	_default = {
		Q = { color = Color3.fromRGB(200, 200, 200), shape = "burst", size = 5  },
		E = { color = Color3.fromRGB(180, 180, 220), shape = "ring",  size = 8  },
		F = { color = Color3.fromRGB(220, 180, 255), shape = "burst", size = 4  },
		R = { color = Color3.fromRGB(255, 220, 50),  shape = "burst", size = 16 },
	},
}

-- ============================================================
-- Общая функция создания Part-эффекта (простые частицы)
-- ============================================================

local function spawnVFXPart(origin, cfg, lifetime)
	lifetime = lifetime or 0.5

	local part = Instance.new("Part")
	part.Anchored       = true
	part.CanCollide     = false
	part.CastShadow     = false
	part.Size           = Vector3.new(cfg.size, 0.3, cfg.size)
	part.Shape          = Enum.PartType.Cylinder
	part.CFrame         = CFrame.new(origin) * CFrame.Angles(0, 0, math.pi / 2)
	part.Color          = cfg.color
	part.Material       = Enum.Material.Neon
	part.Transparency   = 0.3
	part.Parent         = workspace

	-- Быстрое появление → исчезновение
	TweenService:Create(part, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(cfg.size * 1.6, 0.1, cfg.size * 1.6),
	}):Play()

	Debris:AddItem(part, lifetime + 0.05)
	return part
end

-- ============================================================
-- Обработка события
-- ============================================================

SkillVFX.OnClientEvent:Connect(function(userId, heroId, skillSlot, originPos, targetPos)
	-- Определяем точку отрисовки
	local origin = originPos
	if not origin then
		-- если не передана, берём от персонажа
		local player = Players:GetPlayerByUserId(userId)
		if player and player.Character then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then origin = hrp.Position end
		end
	end
	if not origin then return end

	-- Получаем пресет для героя
	local heroPresets = VFX_PRESETS[heroId] or VFX_PRESETS._default
	local cfg = heroPresets[skillSlot] or VFX_PRESETS._default[skillSlot]
	if not cfg then return end

	spawnVFXPart(origin, cfg, 0.45)
end)

print("[SkillVFX] Initialized ✓")
