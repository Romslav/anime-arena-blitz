-- HitEffects.client.lua | Anime Arena: Blitz
-- Production: Screen Shake, Red Vignette, Character Flash,
--             Sparks, Low-HP Heartbeat, Death Blackout
-- Триггеры: TakeDamage, PlayerDied
-- Public API: _G.HitEffects.OnHit / OnDeath / WhiteOut / ScreenShake

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local rTakeDamage    = Remotes:WaitForChild("TakeDamage",    10)
local rPlayerDied    = Remotes:WaitForChild("PlayerDied",    10)
local rSkillUsed     = Remotes:WaitForChild("SkillUsed",     10)
local rUpdateEffect  = Remotes:WaitForChild("UpdateEffect",  10)  -- Hit-confirm искры

-- ============================================================
-- GUI
-- ============================================================

local function makeGui(name, order)
	local g = Instance.new("ScreenGui")
	g.Name           = name
	g.ResetOnSpawn   = false
	g.DisplayOrder   = order
	g.IgnoreGuiInset = true
	g.Parent         = PlayerGui
	return g
end

local function makeFrame(parent, col, zi, alpha)
	local f = Instance.new("Frame")
	f.Size                     = UDim2.new(1, 0, 1, 0)
	f.BackgroundColor3         = col
	f.BackgroundTransparency   = alpha or 1
	f.BorderSizePixel          = 0
	f.ZIndex                   = zi or 1
	f.Parent                   = parent
	return f
end

local function makeImage(parent, img, col, zi)
	local lbl = Instance.new("ImageLabel")
	lbl.Size                   = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Image                  = img
	lbl.ImageColor3            = col
	lbl.ImageTransparency      = 1
	lbl.ScaleType              = Enum.ScaleType.Stretch
	lbl.ZIndex                 = zi or 1
	lbl.Parent                 = parent
	return lbl
end

local hitGui = makeGui("HitEffects", 30)

-- Красная виньетка
local vignette   = makeImage(hitGui, "rbxassetid://1049219073",
	Color3.fromRGB(220, 30, 30), 5)
-- Белый флэш
local whiteFlash = makeFrame(hitGui, Color3.fromRGB(255, 255, 255), 6)
-- Чёрный флэш (смерть)
local darkFlash  = makeFrame(hitGui, Color3.fromRGB(0, 0, 0), 7)
-- Low-HP пульсация
local heartbeat  = makeImage(hitGui, "rbxassetid://1049219073",
	Color3.fromRGB(180, 0, 0), 4)
-- Жёлтый flash при крите
local critFlash  = makeFrame(hitGui, Color3.fromRGB(255, 200, 0), 6)

-- ============================================================
-- STATE
-- ============================================================

local shakeMag   = 0
local shakeDecay = 0
local shakeOn    = false

local currentHP = 100
local maxHP     = 100
local hbThread  = nil   -- heartbeat coroutine

-- ============================================================
-- SCREEN SHAKE  (через CFrame.Angles, без сдвига позиции)
-- ============================================================

local function screenShake(mag, duration)
	mag       = math.clamp(mag, 0.04, 1.4)
	shakeMag  = mag
	shakeDecay = mag / math.max(duration, 0.05)
	shakeOn   = true
end

RunService.RenderStepped:Connect(function(dt)
	if not shakeOn then return end
	shakeMag = math.max(0, shakeMag - shakeDecay * dt)
	if shakeMag < 0.001 then shakeOn = false; return end
	local rx = (math.random() - 0.5) * 2 * shakeMag
	local ry = (math.random() - 0.5) * 2 * shakeMag
	Camera.CFrame = Camera.CFrame * CFrame.Angles(rx, ry, 0)
end)

-- ============================================================
-- VIGNETTE FLASH
-- ============================================================

local vigBusy = false
local function flashVignette(intensity, duration, color)
	if vigBusy then return end
	vigBusy = true
	vignette.ImageColor3 = color or Color3.fromRGB(220, 30, 30)
	local peak = math.clamp(1 - intensity * 0.6, 0.15, 0.75)
	TweenService:Create(vignette, TweenInfo.new(0.04), { ImageTransparency = peak }):Play()
	task.delay(duration * 0.25, function()
		TweenService:Create(vignette,
			TweenInfo.new(duration * 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ ImageTransparency = 1 }):Play()
		task.delay(duration, function() vigBusy = false end)
	end)
end

-- ============================================================
-- CHARACTER HIGHLIGHT FLASH
-- ============================================================

local function characterFlash(char, duration, color)
	if not char then return end
	local hl = Instance.new("Highlight")
	hl.FillColor          = color or Color3.fromRGB(255, 255, 255)
	hl.FillTransparency   = 0.1
	hl.OutlineTransparency = 1
	hl.Adornee            = char
	hl.Parent             = char
	TweenService:Create(hl,
		TweenInfo.new(duration, Enum.EasingStyle.Quad),
		{ FillTransparency = 1 }):Play()
	Debris:AddItem(hl, duration + 0.1)
end

-- ============================================================
-- SPARK PARTICLES
-- ============================================================

local function spawnSparks(position, heroColor)
	heroColor = heroColor or Color3.fromRGB(255, 200, 50)
	local anchor = Instance.new("Part")
	anchor.Anchored     = true
	anchor.CanCollide   = false
	anchor.Transparency = 1
	anchor.Size         = Vector3.one
	anchor.CFrame       = CFrame.new(position)
	anchor.Parent       = workspace

	local emit = Instance.new("ParticleEmitter")
	emit.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.4, heroColor),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(40,  40,  40)),
	})
	emit.LightEmission  = 1
	emit.LightInfluence = 0
	emit.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.35),
		NumberSequenceKeypoint.new(0.5, 0.18),
		NumberSequenceKeypoint.new(1,   0),
	})
	emit.Speed       = NumberRange.new(10, 22)
	emit.SpreadAngle = Vector2.new(180, 180)
	emit.Rate        = 0
	emit.Lifetime    = NumberRange.new(0.18, 0.45)
	emit.RotSpeed    = NumberRange.new(-200, 200)
	emit.Rotation    = NumberRange.new(0, 360)
	emit.Enabled     = false
	emit.Parent      = anchor
	emit:Emit(22)
	Debris:AddItem(anchor, 0.8)
end

-- ============================================================
-- LOW-HP HEARTBEAT  (pulse пока HP < 25%)
-- ============================================================

local function stopHeartbeat()
	if hbThread then task.cancel(hbThread); hbThread = nil end
	heartbeat.ImageTransparency = 1
end

local function startHeartbeat()
	if hbThread then return end
	hbThread = task.spawn(function()
		while true do
			local ratio = currentHP / math.max(maxHP, 1)
			if ratio > 0.25 then stopHeartbeat(); return end
			TweenService:Create(heartbeat, TweenInfo.new(0.12),
				{ ImageTransparency = 0.25 }):Play()
			task.wait(0.18)
			TweenService:Create(heartbeat, TweenInfo.new(0.35),
				{ ImageTransparency = 1 }):Play()
			-- Чем ниже HP, тем быстрее пульс
			task.wait(0.3 + ratio * 1.2)
		end
	end)
end

-- ============================================================
-- DEATH EFFECT
-- ============================================================

local function playDeathEffect()
	stopHeartbeat()
	TweenService:Create(darkFlash, TweenInfo.new(0.08),
		{ BackgroundTransparency = 0.05 }):Play()
	task.delay(0.12, function()
		TweenService:Create(darkFlash,
			TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }):Play()
	end)
	screenShake(0.9, 0.55)
	-- Синяя виньетка при смерти
	flashVignette(1, 1.0, Color3.fromRGB(20, 0, 80))
end

-- ============================================================
-- PUBLIC API
-- ============================================================

local HitEffects = {}
_G.HitEffects = HitEffects

function HitEffects.OnHit(position, damagePct, heroColor, dmgType)
	dmgType = dmgType or "Normal"
	local isUlt  = dmgType == "Ultimate"
	local isCrit = dmgType == "Crit"

	-- Shake
	screenShake(
		math.clamp(damagePct * (isUlt and 2.0 or 1.2), 0.1, isUlt and 1.0 or 0.5),
		isUlt and 0.55 or 0.22
	)

	-- Vignette
	flashVignette(damagePct, isUlt and 0.7 or 0.35,
		isCrit and Color3.fromRGB(255, 150, 0) or nil)

	-- Crit yellow flash
	if isCrit or isUlt then
		critFlash.BackgroundColor3 = isUlt
			and Color3.fromRGB(255, 240, 80)
			or  Color3.fromRGB(255, 180, 30)
		TweenService:Create(critFlash, TweenInfo.new(0.04),
			{ BackgroundTransparency = isUlt and 0.55 or 0.72 }):Play()
		task.delay(0.06, function()
			TweenService:Create(critFlash,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad),
				{ BackgroundTransparency = 1 }):Play()
		end)
	end

	-- Character flash + sparks
	local char = LocalPlayer.Character
	if char then
		characterFlash(char, isUlt and 0.18 or 0.1)
		spawnSparks(position or (char.HumanoidRootPart and char.HumanoidRootPart.Position) or Vector3.zero, heroColor)
	end
end

function HitEffects.OnDeath()
	playDeathEffect()
end

function HitEffects.WhiteOut(duration)
	TweenService:Create(whiteFlash, TweenInfo.new(0.04),
		{ BackgroundTransparency = 0 }):Play()
	task.delay(duration or 0.5, function()
		TweenService:Create(whiteFlash,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad),
			{ BackgroundTransparency = 1 }):Play()
	end)
end

function HitEffects.ScreenShake(mag, dur)
	screenShake(mag, dur)
end

-- ============================================================
-- REMOTE HANDLERS
-- ============================================================

-- TakeDamage: (newHP, maxHP, amount, dmgType, attackerUserId)
rTakeDamage.OnClientEvent:Connect(function(newHP, mhp, amount, dmgType, attackerUserId)
	currentHP = newHP or currentHP
	maxHP     = mhp    or maxHP

	local dmg = amount or 0
	if dmg <= 0 then return end

	local pct  = dmg / math.max(maxHP, 1)
	local char = LocalPlayer.Character
	local pos  = char and char:FindFirstChild("HumanoidRootPart")
		and char.HumanoidRootPart.Position or Vector3.zero

	HitEffects.OnHit(pos, pct, nil, dmgType)

	if (currentHP / math.max(maxHP, 1)) <= 0.25 then
		startHeartbeat()
	else
		stopHeartbeat()
	end
end)

rPlayerDied.OnClientEvent:Connect(function(victimId, killerUserId, respawnTime)
	if victimId == LocalPlayer.UserId then
		playDeathEffect()
	end
end)

-- ИСПРАВЛЕНИЕ: Hit-confirm — искры на экране атакующего при попадании
-- Без этого: rTakeDamage летит только жертве, атакующий видел пустой экран
-- Теперь: искры в точке попадания + легкий шейк экрана
rUpdateEffect.OnClientEvent:Connect(function(effectType, position, dmgType)
	if effectType ~= "hit_spark" then return end
	local heroColor = Color3.fromRGB(255, 220, 60)  -- золотой цвет по умолчанию
	if dmgType == "Ultimate" then
		heroColor = Color3.fromRGB(200, 80, 255)     -- фиолетовый для ульт
	end
	spawnSparks(position, heroColor)
	-- Лёгкий шейк при попадании — даёт ощущение контакта
	screenShake(dmgType == "Ultimate" and 0.18 or 0.07, 0.12)
end)

-- ============================================================
-- BUG-2.2 FIX: SKILL VFX — визуал при использовании способностей.
-- Сервер шлёт rSkillUsed(userId, slot, heroId, targetPos) всем клиентам.
-- Без этого: скиллы срабатывали тихо, без визуальной обратной связи.
-- ============================================================

local SKILL_COLORS = {
	Q = Color3.fromRGB(255, 130, 50),   -- оранжевый
	E = Color3.fromRGB(60,  180, 255),  -- синий
	F = Color3.fromRGB(200, 80,  255),  -- фиолетовый (ульт)
	R = Color3.fromRGB(255, 40,  40),   -- красный (ульт R)
}

rSkillUsed.OnClientEvent:Connect(function(userId, slot, heroId, targetPos)
	-- Визуализируем способность для всех клиентов
	local caster = Players:GetPlayerByUserId(userId)
	if not caster then return end

	local casterChar = caster.Character
	local casterHRP  = casterChar and casterChar:FindFirstChild("HumanoidRootPart")
	if not casterHRP then return end

	local skillColor = SKILL_COLORS[slot] or Color3.fromRGB(255, 220, 60)
	local isUlt      = (slot == "R" or slot == "F")

	-- Искры на кастере
	spawnSparks(casterHRP.Position, skillColor)

	-- Вспышка на кастере (Highlight)
	characterFlash(casterChar, isUlt and 0.25 or 0.12, skillColor)

	-- Экранный шейк для ультов (если кастер — мы или мы рядом)
	if isUlt then
		local localChar = LocalPlayer.Character
		local localHRP  = localChar and localChar:FindFirstChild("HumanoidRootPart")
		if localHRP then
			local dist = (localHRP.Position - casterHRP.Position).Magnitude
			if dist < 50 then  -- ощущаем ульт в радиусе 50 стадов
				local intensity = math.clamp(1 - dist / 50, 0.05, 0.35)
				screenShake(intensity, 0.3)
			end
		end
	end

	-- Если скилл нацелен на позицию — искры в точке попадания
	if targetPos and typeof(targetPos) == "Vector3" then
		task.delay(0.15, function()
			spawnSparks(targetPos, skillColor)
		end)
	end
end)

-- ============================================================
-- BUG-2.3 FIX: Сброс ВСЕХ эффектов при завершении раунда.
-- Без этого: darkFlash / vignette / heartbeat могли «застрять»
-- если игрок умер в последнюю секунду боя.
-- ============================================================

local function resetAllEffects()
	stopHeartbeat()
	darkFlash.BackgroundTransparency  = 1
	whiteFlash.BackgroundTransparency = 1
	vignette.ImageTransparency        = 1
	heartbeat.ImageTransparency       = 1
	critFlash.BackgroundTransparency  = 1
	vigBusy   = false
	shakeOn   = false
	shakeMag  = 0
	currentHP = 100
	maxHP     = 100
end

HitEffects.Reset = resetAllEffects

local rRoundEndHE    = Remotes:FindFirstChild("RoundEnd")
	or Remotes:WaitForChild("RoundEnd", 10)
local rReturnLobbyHE = Remotes:FindFirstChild("ReturnToLobby")
	or Remotes:WaitForChild("ReturnToLobby", 10)
local rPlayerRespawnHE = Remotes:FindFirstChild("PlayerRespawned")
	or Remotes:WaitForChild("PlayerRespawned", 10)

if rRoundEndHE then
	rRoundEndHE.OnClientEvent:Connect(function()
		resetAllEffects()
	end)
end

if rReturnLobbyHE then
	rReturnLobbyHE.OnClientEvent:Connect(function()
		resetAllEffects()
	end)
end

if rPlayerRespawnHE then
	rPlayerRespawnHE.OnClientEvent:Connect(function()
		resetAllEffects()
	end)
end

print("[HitEffects] Initialized ✓")
