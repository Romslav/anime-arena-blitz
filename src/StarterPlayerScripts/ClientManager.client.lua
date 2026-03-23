-- ClientManager.client.lua | Anime Arena: Blitz
-- Главный клиентский оркестратор:
--   • Инициализация всех клиентских систем
--   • Хранит heroId / matchMode / matchId локально
--   • Ретранслирует SkillUsed чужих игроков в VFXManager
--   • Слот F полностью поддерживается

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Ожидаем все Remote-ы прежде чем слушать
local rCharacterSpawned = Remotes:WaitForChild("CharacterSpawned", 10)
local rMatchStart       = Remotes:WaitForChild("MatchStart",       10)
local rMatchEnd         = Remotes:WaitForChild("MatchEnd",         10)
local rRoundStart       = Remotes:WaitForChild("RoundStart",       10)
local rRoundEnd         = Remotes:WaitForChild("RoundEnd",         10)
local rSkillUsed        = Remotes:WaitForChild("SkillUsed",        10)
local rPlayerDied       = Remotes:WaitForChild("PlayerDied",       10)
local rPlayerRespawn    = Remotes:WaitForChild("PlayerRespawned",  10)
local rMatchFound       = Remotes:WaitForChild("MatchFound",       10)
local rQueueStatus      = Remotes:WaitForChild("QueueStatus",      10)

-- ============================================================
-- СОСТОЯНИЕ КЛИЕНТА
-- ============================================================

local ClientState = {
	heroId    = nil,
	matchId   = nil,
	matchMode = nil,
	inMatch   = false,
	inQueue   = false,
	heroSpeed = 16,  -- FIX: базовая скорость героя — читается в SkillController для сброса WalkSpeed
}

_G.ClientState = ClientState

-- ============================================================
-- VFXManager (ленивая загрузка)
-- ============================================================

local VFXManager
task.defer(function()
	-- VFXManager — LocalScript Module в той же папке
	local ok, m = pcall(require, script.Parent:WaitForChild("VFXManager", 8))
	if ok then
		VFXManager = m
		print("[ClientManager] VFXManager loaded")
	else
		warn("[ClientManager] VFXManager not found:", m)
	end
end)

-- ============================================================
-- CHARACTER SPAWNED
-- ============================================================

rCharacterSpawned.OnClientEvent:Connect(function(userId, heroId, heroName)
	ClientState.heroId = heroId
	-- Извлекаем скорость из персонажа (после того как CharacterService.ApplyStats её выставил)
	task.delay(0.3, function()
		local char = LocalPlayer.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			ClientState.heroSpeed = hum.WalkSpeed
		end
	end)
	print(string.format("[ClientManager] Spawned as %s (%s)", tostring(heroId), tostring(heroName)))
end)

-- ============================================================
-- MATCH FLOW
-- ============================================================

rMatchFound.OnClientEvent:Connect(function(matchInfo)
	ClientState.matchId   = matchInfo and matchInfo.matchId
	ClientState.matchMode = matchInfo and matchInfo.mode
	ClientState.inQueue   = false
	print(string.format("[ClientManager] Match found: %s [%s]",
		tostring(ClientState.matchId),
		tostring(ClientState.matchMode)))
end)

rMatchStart.OnClientEvent:Connect(function(mode)
	ClientState.inMatch   = true
	ClientState.matchMode = mode or ClientState.matchMode
end)

rMatchEnd.OnClientEvent:Connect(function(resultData)
	ClientState.inMatch = false
	ClientState.matchId = nil
end)

rRoundStart.OnClientEvent:Connect(function(mode, roundId)
	ClientState.inMatch = true
end)

rRoundEnd.OnClientEvent:Connect(function()
	-- inMatch остаётся true до MatchEnd
end)

rQueueStatus.OnClientEvent:Connect(function(position, total)
	ClientState.inQueue = true
end)

-- ============================================================
-- SKILL BROADCAST (чужие игроки)
-- ============================================================

rSkillUsed.OnClientEvent:Connect(function(userId, slot, heroId, targetPos)
	-- Свои скиллы VFX обрабатывает SkillVFXController
	-- ClientManager обрабатывает только чужих
	if userId == LocalPlayer.UserId then return end
	if VFXManager then
		VFXManager.PlaySkillVFX(userId, slot, heroId or "FlameRonin", targetPos)
	end
end)

-- ============================================================
-- DEATH / RESPAWN
-- ============================================================

rPlayerDied.OnClientEvent:Connect(function(victimId, killerId, respawnTime)
	if VFXManager then
		VFXManager.ClearStatusVFX(victimId)
	end
end)

rPlayerRespawn.OnClientEvent:Connect(function()
	-- HUD обрабатывает сам
	ClientState.inMatch = ClientState.inMatch  -- no-op, для ясности
end)

-- ============================================================
-- PUBLIC API
-- ============================================================

_G.ClientManager = {
	GetState = function() return ClientState end,
	GetHeroId = function() return ClientState.heroId end,
	GetMode   = function() return ClientState.matchMode end,
	IsInMatch = function() return ClientState.inMatch end,
}

print("[ClientManager] Initialized ✓")
