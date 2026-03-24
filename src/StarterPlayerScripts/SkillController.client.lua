-- SkillController.client.lua | Anime Arena: Blitz
-- Клиентский контроллер скиллов и движения.
--
-- ИСПРАВЛЕНИЯ:
--   FIX-1  RoundStart парсится правильно (leftHeroId, leftName, rightHeroId, rightName, mode)
--   FIX-2  Heartbeat-таймер вместо task.delay для сброса стана/рута — нет race-condition
--   FIX-3  Raycast фильтрует своего персонажа — targetPos попадает в цель, а не под ноги
--   FIX-4  Дублирующий "local BINDS" удалён, таблица объявлена один раз
--   FIX-5  WalkSpeed/JumpPower восстанавливается при снятии стана, смерти, респавне

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- FIX: ждём инициализации ClientManager (разделяемый _G.ClientState)
-- Порядок запуска LocalScript-ов не гарантирован, ClientState может ещё не существовать
task.defer(function()
	local timeout = 10
	local waited  = 0
	while not _G.ClientState and waited < timeout do
		task.wait(0.1)
		waited = waited + 0.1
	end
	if not _G.ClientState then
		warn("[SkillController] _G.ClientState not found after ", timeout, "s — using defaults")
		_G.ClientState = { heroSpeed = 16 }
	end
end)

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local rUseSkill      = Remotes:WaitForChild("UseSkill",          10)
local rM1Attack      = Remotes:WaitForChild("M1Attack",          10)
local rSkillResult   = Remotes:WaitForChild("SkillResult",       10)
local rRoundStart    = Remotes:WaitForChild("RoundStart",        10)
local rRoundEnd      = Remotes:WaitForChild("RoundEnd",          10)
local rRoundState    = Remotes:WaitForChild("RoundStateChanged", 10)
local rPlayerDied    = Remotes:WaitForChild("PlayerDied",        10)
local rPlayerRespawn = Remotes:WaitForChild("PlayerRespawned",   10)
local rStatusEffect  = Remotes:WaitForChild("UpdateEffect",      10)

-- ============================================================
-- STATE
-- ============================================================

local canUseSkills = false
local isAlive      = false  -- FIX: false до начала раунда, иначе M1 работает в лобби
local isStunned    = false
local isRooted     = false
local lastM1       = 0
local M1_COOLDOWN  = 0.55

-- FIX-2: метки времени вместо task.delay
local stunExpireAt = 0
local rootExpireAt = 0

local localCDs   = { Q = 0, E = 0, F = 0, R = 0 }
local CD_DEBOUNCE = 0.12

-- FIX-4: единственное объявление BINDS
local BINDS = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.F] = "F",
	[Enum.KeyCode.R] = "R",
}

-- ============================================================
-- УТИЛИТЫ
-- ============================================================

local function getHeroSpeed()
	return (_G.ClientState and _G.ClientState.heroSpeed) or 16
end

local function restoreMovement(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.WalkSpeed = getHeroSpeed()
	hum.JumpPower = 50
end

-- FIX-3: Raycast исключает своего персонажа
local function getMouseWorldPos()
	local mouse   = LocalPlayer:GetMouse()
	local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local char = LocalPlayer.Character
	if char then
		params.FilterDescendantsInstances = { char }
	end

	local hit = workspace:Raycast(unitRay.Origin, unitRay.Direction * 600, params)
	if hit then return hit.Position end

	-- Фоллбэк: горизонтальная плоскость на высоте игрока
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local planeY = hrp and hrp.Position.Y or 0
	local dY = unitRay.Direction.Y
	if math.abs(dY) > 0.0001 then
		local t = (planeY - unitRay.Origin.Y) / dY
		if t > 0 then return unitRay.Origin + unitRay.Direction * t end
	end
	return unitRay.Origin + unitRay.Direction * 80
end

-- ============================================================
-- FIX-2: Heartbeat снимает стан/рут ровно по истечении времени
-- ============================================================

RunService.Heartbeat:Connect(function()
	local now  = tick()
	local char = LocalPlayer.Character

	if isStunned and now >= stunExpireAt then
		isStunned = false
		if not isRooted then restoreMovement(char) end
	end

	if isRooted and now >= rootExpireAt then
		isRooted = false
		if not isStunned then restoreMovement(char) end
	end
end)

-- ============================================================
-- FIX-5: блокировка/разблокировка движения
-- ============================================================

local function applyBlock(effectType, duration)
	local char = LocalPlayer.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if effectType == "Stun" then
		isStunned    = true
		stunExpireAt = tick() + (duration or 1)
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	elseif effectType == "Root" then
		isRooted     = true
		rootExpireAt = tick() + (duration or 1)
		hum.WalkSpeed = 0
	end
end

local function removeBlock(effectType)
	local char = LocalPlayer.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if effectType == "Stun" then
		isStunned    = false
		stunExpireAt = 0
		if not isRooted then restoreMovement(char) end
	elseif effectType == "Root" then
		isRooted     = false
		rootExpireAt = 0
		if not isStunned then restoreMovement(char) end
	end
end

-- ============================================================
-- ВВОД СКИЛЛОВ
-- ============================================================

local function tryUseSkill(slot)
	if not canUseSkills then return end
	if not isAlive      then return end
	if isStunned        then return end
	if tick() - (localCDs[slot] or 0) < CD_DEBOUNCE then return end
	localCDs[slot] = tick()
	rUseSkill:FireServer(slot, getMouseWorldPos())
end

local function tryM1()
	if not canUseSkills then return end
	if not isAlive      then return end
	if isStunned        then return end
	local now = tick()
	if now - lastM1 < M1_COOLDOWN then return end
	lastM1 = now
	rM1Attack:FireServer(getMouseWorldPos())
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local slot = BINDS[input.KeyCode]
	if slot then
		tryUseSkill(slot)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		tryM1()
	end
end)

-- ============================================================
-- REMOTE HANDLERS
-- ============================================================

-- FIX-1: правильный порядок аргументов RoundStart
rRoundStart.OnClientEvent:Connect(function(leftHeroId, leftName, rightHeroId, rightName, mode)
	canUseSkills = true
	isAlive      = true
	isStunned    = false
	isRooted     = false
	stunExpireAt = 0
	rootExpireAt = 0
	restoreMovement(LocalPlayer.Character)
	print("[SkillController] RoundStart → skills ENABLED | mode:", mode)
end)

rRoundEnd.OnClientEvent:Connect(function()
	canUseSkills = false
	print("[SkillController] RoundEnd → skills DISABLED")
end)

rRoundState.OnClientEvent:Connect(function(phase)
	-- FIX: Preparation не сбрасывает canUseSkills — его уже выставил RoundStart
	-- Только Battle включает, Conclusion/Waiting выключает
	if phase == "Battle" then
		canUseSkills = true
		isAlive      = true
		isStunned    = false
		isRooted     = false
		stunExpireAt = 0
		rootExpireAt = 0
		restoreMovement(LocalPlayer.Character)
	elseif phase == "Conclusion" or phase == "Waiting" then
		canUseSkills = false
	end
	print("[SkillController] Phase:", phase, "→ canUseSkills:", canUseSkills)
end)

rSkillResult.OnClientEvent:Connect(function(slot, success)
	-- FIX: сбрасываем локальный дебаунс при успехе (не при отказе)
	-- CD-время приходит из HUD через rSkillResult c cdTime — здесь только сбрасываем debounce
	if success then
		localCDs[slot] = 0  -- разрешаем слот сразу (истинный CD хранит HUD)
	end
end)

rPlayerDied.OnClientEvent:Connect(function(victimId)
	if victimId ~= LocalPlayer.UserId then return end
	isAlive      = false
	isStunned    = false
	isRooted     = false
	stunExpireAt = 0
	rootExpireAt = 0
	-- FIX-5: разблокируем Humanoid чтобы не застрять
	restoreMovement(LocalPlayer.Character)
end)

-- BUG-G FIX: фильтруем по userId — FireAllClients передаёт его первым аргументом
-- Без фильтра — чужой респавн восстанавливал isAlive=true у всех
-- (isAlive=true у игрока, который ещё не респавнулся — мертвый мог атаковать)
rPlayerRespawn.OnClientEvent:Connect(function(respawnedUserId)
	if respawnedUserId ~= LocalPlayer.UserId then return end
	isAlive      = true
	isStunned    = false
	isRooted     = false
	stunExpireAt = 0
	rootExpireAt = 0
	restoreMovement(LocalPlayer.Character)
end)

rStatusEffect.OnClientEvent:Connect(function(effectType, isActive, duration)
	if effectType == "Stun" or effectType == "Root" then
		if isActive then
			applyBlock(effectType, duration)
		else
			removeBlock(effectType)
		end

	elseif effectType == "Slow" then
		local char = LocalPlayer.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			if isActive then
				hum.WalkSpeed = getHeroSpeed() * 0.5
			else
				if not isStunned and not isRooted then
					hum.WalkSpeed = getHeroSpeed()
				end
			end
		end
	end
end)

-- Алиас MatchStart (GameManager)
local rMatchStart = Remotes:FindFirstChild("MatchStart")
if rMatchStart then
	rMatchStart.OnClientEvent:Connect(function(mode)
		canUseSkills = true
		isAlive      = true
		isStunned    = false
		isRooted     = false
		stunExpireAt = 0
		rootExpireAt = 0
		restoreMovement(LocalPlayer.Character)
		print("[SkillController] MatchStart → skills ENABLED | mode:", mode)
	end)
end

-- FIX: сброс при спавне/респавне — восстанавливаем isAlive и canUseSkills
LocalPlayer.CharacterAdded:Connect(function(char)
	isStunned    = false
	isRooted     = false
	stunExpireAt = 0
	rootExpireAt = 0
	-- FIX: если были в бою — возрождаемся снова живым
	if canUseSkills then
		isAlive = true
	end
	local hum = char:WaitForChild("Humanoid", 5)
	if not hum then return end
	-- FIX: ждём полной инициализации перед выставкой скорости
	task.wait(0.3)
	if not isStunned and not isRooted then
		hum.WalkSpeed = getHeroSpeed()
		hum.JumpPower = 50
	end
end)

print("[SkillController] Initialized ✓")
