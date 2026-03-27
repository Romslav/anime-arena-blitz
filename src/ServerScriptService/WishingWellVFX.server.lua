-- WishingWellVFX.server.lua | Anime Arena: Blitz  [v2 — полная перепись]
-- VFX-движок Колодца Желаний:
--   • 4 кольца вихря: Y=90°/s, X/Z=±45°/s, sin-пульсация прозрачности
--   • Магический круг: медленное вращение трёх слоёв (Inner/Mid/Outer)
--   • Орбитальные искры: плавный полёт по эллипсу с бобом
--   • PointLight-пульсация: Brightness ~sin(t)*range
--   • Реакция на дроп по редкости: цвет, скорость, стражи, SkyBeam
--   • Proximity rune-glow: руны светлеют когда игрок ближе 12 стадов
--   • ParticleEmitter в VFX_Center с настраиваемыми пресетами
--   • Публичный API: _G.WishingWellVFX.PlayDrop(rarity)

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- КОНФИГ
-- ============================================================

local CFG = {
	-- Вихрь (покой)
	VORTEX_BASE_SPEED_Y  = 90,    -- °/s для Ring1
	VORTEX_SPEED_MULTI   = {1, -0.7, 1.3, -0.5}, -- множители для 4 колец
	VORTEX_SIN_FREQ      = 1.8,   -- частота пульсации прозрачности
	VORTEX_ALPHA_MIN     = 0.40,
	VORTEX_ALPHA_MAX     = 0.70,

	-- Магический круг
	CIRCLE_SPEEDS        = { Inner = 12, Mid = -7, Outer = 4 }, -- °/s

	-- Искры
	SPARK_ORBIT_SPEED    = 0.6,   -- rad/s (базовая)
	SPARK_BOB_AMP        = 0.35,  -- стадов вверх-вниз

	-- Свет в центре
	LIGHT_BRIGHTNESS_MIN = 1.6,
	LIGHT_BRIGHTNESS_MAX = 2.8,
	LIGHT_SIN_FREQ       = 0.9,

	-- Proximity rune glow
	RUNE_GLOW_DIST       = 12,    -- стадов
	RUNE_GLOW_COLOR_FAR  = Color3.fromRGB(100, 0, 200),
	RUNE_GLOW_COLOR_NEAR = Color3.fromRGB(200, 120, 255),
	RUNE_CHECK_INTERVAL  = 0.4,   -- сек между проверками

	-- Summon burst
	SUMMON_SPEED_BOOST   = 5,     -- × базовой скорости
	SUMMON_BOOST_DUR     = 3,     -- сек

	-- Legendary
	LEG_SKY_ALPHA        = 0.15,
	LEG_EYE_COLOR        = Color3.fromRGB(255, 200, 0),
	LEG_SHAKE_AMP        = 0.12,  -- стадов
	LEG_SHAKE_STEPS      = 18,
	LEG_LIGHT_BOOST      = 6,
}

local RARITY_COLORS = {
	Common    = Color3.fromRGB(160, 160, 160),
	Rare      = Color3.fromRGB(60,  120, 240),
	Epic      = Color3.fromRGB(160, 50,  220),
	Legendary = Color3.fromRGB(255, 180, 0),
}

-- ============================================================
-- ПОИСК МОДЕЛИ
-- ============================================================

local function waitForWell()
	-- Если Setup ещё не закончил стилизацию — ждём
	for _ = 1, 40 do
		local lobby = workspace:FindFirstChild("Lobby")
		if lobby and lobby:FindFirstChild("WishingWell") then
			return lobby:FindFirstChild("WishingWell")
		end
		task.wait(1.5)
	end
	return nil
end

-- ============================================================
-- MAIN
-- ============================================================

task.spawn(function()
	-- Ждём завершения Setup перед стартом VFX
	for _ = 1, 30 do
		if _G.WishingWellSetupDone then break end
		task.wait(1)
	end

	local well = waitForWell()
	if not well then
		warn("[WishingWellVFX] WishingWell not found — VFX disabled")
		return
	end

	local wellOrigin = well:GetPivot().Position

	-- ========================================================
	-- 1. СБОР ЧАСТЕЙ
	-- ========================================================

	local vortexRings   = {}  -- {part, baseSpeed, dir}
	local magicCircles  = {}  -- {part, speed}
	local sparks        = {}  -- {part, angle, radius, height, speed}
	local rimParts      = {}
	local runeParts     = {}
	local sentinelEyes  = {}
	local skyBeams      = {}
	local coreLight     = nil

	for _, child in ipairs(well:GetDescendants()) do
		if not child:IsA("BasePart") then continue end
		local n = child.Name

		if n:find("Vortex_Ring") then
			local idx = tonumber(n:match("Ring(%d+)")) or 1
			local mult = CFG.VORTEX_SPEED_MULTI[idx] or 1
			table.insert(vortexRings, {
				part      = child,
				baseSpeed = CFG.VORTEX_BASE_SPEED_Y * math.abs(mult),
				dir       = mult >= 0 and 1 or -1,
				axis      = idx % 2 == 0 and "X" or "Y",  -- Ring1&3=Y, Ring2&4=X
			})

		elseif n:find("MagicCircle") then
			local layer = n:match("_(%a+)$") or "Mid"  -- Inner / Mid / Outer
			table.insert(magicCircles, {
				part  = child,
				speed = CFG.CIRCLE_SPEEDS[layer] or 5,
			})

		elseif n:find("Spark_") then
			local pos  = child.Position
			local dist = math.max(math.sqrt(pos.X^2 + pos.Z^2), 0.5)
			table.insert(sparks, {
				part    = child,
				angle   = math.atan2(pos.Z - wellOrigin.Z, pos.X - wellOrigin.X),
				radius  = dist,
				height  = pos.Y,
				speed   = CFG.SPARK_ORBIT_SPEED * (0.7 + math.random() * 0.6),
				dir     = math.random() > 0.5 and 1 or -1,
				phase   = math.random() * math.pi * 2,
			})

		elseif n:find("Rim") then
			table.insert(rimParts, child)

		elseif n:find("Rune_") or n:find("RuneAccent") then
			table.insert(runeParts, child)

		elseif n:find("Eye") then
			table.insert(sentinelEyes, child)

		elseif n:find("SkyBeam") then
			child.Transparency = 1  -- скрыт до Legendary
			table.insert(skyBeams, child)
		end

		-- PointLight в VFX_Center
		if n == "VFX_Center" then
			coreLight = child:FindFirstChild("CoreLight")
		end
	end

	-- Если CoreLight ещё не создан Setup'ом — ищем
	if not coreLight then
		local vc = well:FindFirstChild("VFX_Center")
		if vc then coreLight = vc:FindFirstChildOfClass("PointLight") end
	end

	-- SummonBeam / EnergyBeam
	local summonBeam = well:FindFirstChild("WishingWell_SummonBeam", true)
		or well:FindFirstChild("SummonBeam", true)
	if summonBeam then summonBeam.Transparency = 0.85 end

	print(string.format("[WishingWellVFX] Parts found: %d rings, %d circles, %d sparks, %d runes, %d eyes",
		#vortexRings, #magicCircles, #sparks, #runeParts, #sentinelEyes))

	-- ========================================================
	-- 2. ГЛАВНЫЙ HEARTBEAT: вихрь + круги + искры + свет
	-- ========================================================

	local elapsed       = 0
	local vortexBoost   = 1   -- множитель скорости вихря (1 = покой, 5 = призыв)
	local boostEndTime  = 0

	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt

		-- Сброс буста скорости по времени
		if vortexBoost > 1 and elapsed > boostEndTime then
			vortexBoost = 1
		end

		-- — — ВИХРЬ — —
		local sinAlpha = CFG.VORTEX_ALPHA_MIN
			+ (CFG.VORTEX_ALPHA_MAX - CFG.VORTEX_ALPHA_MIN)
			* (0.5 + 0.5 * math.sin(elapsed * CFG.VORTEX_SIN_FREQ))

		for i, ring in ipairs(vortexRings) do
			local speed = ring.baseSpeed * vortexBoost * ring.dir
			local rad   = math.rad(speed * dt)
			if ring.axis == "Y" then
				ring.part.CFrame = ring.part.CFrame * CFrame.Angles(0, rad, 0)
			else
				ring.part.CFrame = ring.part.CFrame * CFrame.Angles(rad, 0, 0)
			end
			-- Пульсация прозрачности (каждое кольцо чуть сдвинуто по фазе)
			ring.part.Transparency = sinAlpha + 0.05 * math.sin(elapsed * 1.2 + i)
		end

		-- — — МАГИЧЕСКИЙ КРУГ — —
		for _, circle in ipairs(magicCircles) do
			local rad = math.rad(circle.speed * dt)
			circle.part.CFrame = circle.part.CFrame * CFrame.Angles(0, rad, 0)
		end

		-- — — ИСКРЫ — —
		for _, s in ipairs(sparks) do
			s.angle += s.speed * s.dir * dt
			local x = wellOrigin.X + math.cos(s.angle) * s.radius
			local z = wellOrigin.Z + math.sin(s.angle) * s.radius
			local y = s.height + math.sin(elapsed * 1.5 + s.phase) * CFG.SPARK_BOB_AMP
			s.part.Position = Vector3.new(x, y, z)
			-- Пульсация прозрачности искры
			s.part.Transparency = 0.1 + 0.3 * math.abs(math.sin(elapsed * 2.5 + s.phase))
		end

		-- — — СВЕТ — —
		if coreLight then
			coreLight.Brightness = CFG.LIGHT_BRIGHTNESS_MIN
				+ (CFG.LIGHT_BRIGHTNESS_MAX - CFG.LIGHT_BRIGHTNESS_MIN)
				* (0.5 + 0.5 * math.sin(elapsed * CFG.LIGHT_SIN_FREQ))
		end
	end)

	-- ========================================================
	-- 3. ПУЛЬСАЦИЯ ОБОДА (Tween-цикл)
	-- ========================================================

	if #rimParts > 0 then
		local rimColors = {
			Color3.fromRGB(140, 0, 255),
			Color3.fromRGB(0,   160, 255),
			Color3.fromRGB(100, 0,  220),
		}
		local rimIdx = 0
		task.spawn(function()
			while true do
				rimIdx = (rimIdx % #rimColors) + 1
				local target = rimColors[rimIdx]
				for _, rim in ipairs(rimParts) do
					TweenService:Create(rim,
						TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{ Color = target }
					):Play()
				end
				task.wait(2.5)
			end
		end)
	end

	-- ========================================================
	-- 4. PROXIMITY RUNE GLOW
	-- Когда игрок подходит к колодцу — руны светлеют
	-- ========================================================

	if #runeParts > 0 then
		task.spawn(function()
			while true do
				task.wait(CFG.RUNE_CHECK_INTERVAL)

				local closest = math.huge
				for _, plr in ipairs(Players:GetPlayers()) do
					local char = plr.Character
					if char then
						local hrp = char:FindFirstChild("HumanoidRootPart")
						if hrp then
							local dist = (hrp.Position - wellOrigin).Magnitude
							if dist < closest then closest = dist end
						end
					end
				end

				-- Интерполируем цвет рун: далеко = dim, близко = bright
				local t = math.clamp(1 - (closest - 4) / (CFG.RUNE_GLOW_DIST - 4), 0, 1)
				local runeColor = CFG.RUNE_GLOW_COLOR_FAR:Lerp(CFG.RUNE_GLOW_COLOR_NEAR, t)

				for _, rune in ipairs(runeParts) do
					-- Только меняем Color без Tween — быстро и дёшево
					rune.Color = runeColor
				end
			end
		end)
	end

	-- ========================================================
	-- 5. PARTICLEEMITTER В VFX_CENTER
	-- ========================================================

	local vfxCenter = well:FindFirstChild("VFX_Center")
	if vfxCenter then
		local pe = vfxCenter:FindFirstChildOfClass("ParticleEmitter")
		if not pe then
			pe = Instance.new("ParticleEmitter")
			pe.Name             = "VortexParticles"
			pe.Rate             = 12
			pe.Lifetime         = NumberRange.new(0.8, 2.2)
			pe.Speed            = NumberRange.new(3, 9)
			pe.SpreadAngle      = Vector2.new(20, 20)
			pe.EmissionDirection = Enum.NormalId.Top
			pe.RotSpeed         = NumberRange.new(-180, 180)
			pe.Rotation         = NumberRange.new(0, 360)
			pe.Color            = ColorSequence.new({
				ColorSequenceKeypoint.new(0,   Color3.fromRGB(220, 100, 255)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80,  200, 255)),
				ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 255, 255)),
			})
			pe.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0,   0.05),
				NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(1,   0),
			})
			pe.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0,   0.1),
				NumberSequenceKeypoint.new(0.6, 0.4),
				NumberSequenceKeypoint.new(1,   1),
			})
			pe.LightEmission  = 1
			pe.LightInfluence = 0
			pe.LockedToPart   = false
			pe.Parent         = vfxCenter
		end
	end

	-- ========================================================
	-- 6. ПУБЛИЧНЫЙ API: PlayDrop(rarity)
	-- ========================================================

	_G.WishingWellVFX = {

		-- Вызывается из WishingWellService после каждого ролла
		PlayDrop = function(rarity)
			local color = RARITY_COLORS[rarity] or RARITY_COLORS.Common

			-- Вихрь: буст скорости
			vortexBoost  = CFG.SUMMON_SPEED_BOOST
			boostEndTime = elapsed + CFG.SUMMON_BOOST_DUR

			-- Particle burst
			if vfxCenter then
				local pe = vfxCenter:FindFirstChildOfClass("ParticleEmitter")
				if pe then pe:Emit(rarity == "Legendary" and 80 or 30) end
			end

			-- Summon beam вспышка
			if summonBeam then
				summonBeam.Color        = color
				summonBeam.Transparency = 0.2
				TweenService:Create(summonBeam,
					TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = 0.85 }
				):Play()
			end

			-- Цвет вихря меняется на цвет редкости → возвращается
			for _, ring in ipairs(vortexRings) do
				ring.part.Color = color
				task.delay(CFG.SUMMON_BOOST_DUR, function()
					-- Возврат к бирюзе через тween
					TweenService:Create(ring.part,
						TweenInfo.new(1, Enum.EasingStyle.Sine),
						{ Color = Color3.fromRGB(0, 255, 255) }
					):Play()
				end)
			end

			-- ---- LEGENDARY SPECIAL ----
			if rarity == "Legendary" then

				-- Sky beams
				for _, beam in ipairs(skyBeams) do
					beam.Color        = Color3.fromRGB(255, 200, 50)
					beam.Transparency = CFG.LEG_SKY_ALPHA
					TweenService:Create(beam,
						TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Transparency = 1 }
					):Play()
				end

				-- Глаза стражей: золото + micro-shake
				for _, eye in ipairs(sentinelEyes) do
					local origColor = eye.Color
					eye.Color = CFG.LEG_EYE_COLOR
					local origCF = eye.CFrame
					task.spawn(function()
						for _ = 1, CFG.LEG_SHAKE_STEPS do
							local jitter = CFrame.new(
								(math.random() - 0.5) * CFG.LEG_SHAKE_AMP,
								(math.random() - 0.5) * CFG.LEG_SHAKE_AMP * 0.5,
								(math.random() - 0.5) * CFG.LEG_SHAKE_AMP)
							eye.CFrame = origCF * jitter
							task.wait(0.05)
						end
						eye.CFrame = origCF
					end)
					task.delay(4, function()
						TweenService:Create(eye,
							TweenInfo.new(1, Enum.EasingStyle.Sine),
							{ Color = origColor }
						):Play()
					end)
				end

				-- PointLight взрыв
				if coreLight then
					local origBrightness = coreLight.Brightness
					coreLight.Brightness  = origBrightness * CFG.LEG_LIGHT_BOOST
					coreLight.Color       = Color3.fromRGB(255, 200, 50)
					TweenService:Create(coreLight,
						TweenInfo.new(3.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
						{ Brightness = origBrightness, Color = Color3.fromRGB(120, 0, 255) }
					):Play()
				end

			elseif rarity == "Epic" then
				-- Epic: быстрые фиолетовые вспышки на ободе
				task.spawn(function()
					for _ = 1, 4 do
						for _, rim in ipairs(rimParts) do
							rim.Color = Color3.fromRGB(220, 0, 255)
						end
						task.wait(0.15)
						for _, rim in ipairs(rimParts) do
							rim.Color = Color3.fromRGB(60, 0, 140)
						end
						task.wait(0.15)
					end
				end)

			elseif rarity == "Rare" then
				-- Rare: синяя вспышка обода
				for _, rim in ipairs(rimParts) do
					TweenService:Create(rim,
						TweenInfo.new(0.3, Enum.EasingStyle.Quad),
						{ Color = Color3.fromRGB(30, 120, 255) }
					):Play()
				end
				task.delay(1.5, function()
					for _, rim in ipairs(rimParts) do
						TweenService:Create(rim,
							TweenInfo.new(1, Enum.EasingStyle.Sine),
							{ Color = Color3.fromRGB(120, 0, 255) }
						):Play()
					end
				end)
			end
		end,

		-- Утилита для WishingWellInteract: задать скорость вихря извне
		SetVortexBoost = function(mult, duration)
			vortexBoost  = mult
			boostEndTime = elapsed + duration
		end,
	}

	print("[WishingWellVFX] ✓ Full VFX system active")
end)
