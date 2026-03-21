-- GameManager.server.lua | Anime Arena: Blitz Mode
-- Главный менеджер матчей: лобби, старт, таймер, конец, выдача RP

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchStart = Remotes:WaitForChild("RoundStart")
local MatchEnd = Remotes:WaitForChild("RoundEnd")
local UpdateTimer = Remotes:WaitForChild("RoundTimer")

local CombatSystem = require(script.Parent.CombatSystem)
local Config = require(ReplicatedStorage.Config)

local GameManager = {}
_G.GameManager = GameManager

local activeMatches = {}

-- === Старт Матча ===

function GameManager.StartMatch(playerIds, mode)
	local matchId = "Match_" .. tick()
	local matchPlayers = {}
	
	for _, uid in pairs(playerIds) do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			table.insert(matchPlayers, p)
			CombatSystem.initPlayer(p, {id = "FlameRonin", hp = 120})
		end
	end
	
	activeMatches[matchId] = {
		players = matchPlayers,
		startTime = tick(),
		duration = Config.ROUND_DURATION[mode] or 180,
		mode = mode,
		stats = {} -- [userId] = {kills, damage}
	}
	
	for _, p in pairs(matchPlayers) do
		MatchStart:FireClient(p, mode)
	end
	
	-- Таймер
	task.spawn(function()
		local match = activeMatches[matchId]
		local timeLeft = match.duration
		while timeLeft > 0 and activeMatches[matchId] do
			for _, p in pairs(matchPlayers) do
				UpdateTimer:FireClient(p, timeLeft)
			end
			task.wait(1)
			timeLeft -= 1
		end
		if activeMatches[matchId] then
			GameManager.EndMatch(matchId, nil)
		end
	end)
end

-- === Конец Матча ===

function GameManager.EndMatch(matchId, winnerId)
	local match = activeMatches[matchId]
	if not match then return end
	
	-- Собираем финальную статистику из CombatSystem
	local finalStats = {}
	local mvpId = nil
	local maxScore = -1
	
	for _, p in pairs(match.players) do
		local combatState = CombatSystem.getState(p.UserId)
		if combatState then
			finalStats[p.UserId] = {
				kills = combatState.kills,
				damage = combatState.damage
			}
			-- Простейший расчет MVP
			local score = combatState.kills * 100 + combatState.damage
			if score > maxScore then
				maxScore = score
				mvpId = p.UserId
			end
		end
	end
	
	local mvpName = mvpId and Players:GetPlayerByUserId(mvpId).Name or "None"
	
	-- Рассчитываем награды
	local rewards = {
		rp = (winnerId ~= nil) and Config.REWARDS.WIN_RATING or 0,
		coins = (winnerId ~= nil) and Config.REWARDS.WIN_COINS or Config.REWARDS.LOSE_COINS
	}
	
	-- Отправляем данные клиентам
	local matchData = {
		winnerId = winnerId or 0,
		stats = finalStats,
		rewards = rewards,
		mvpName = mvpName
	}
	
	for _, p in pairs(match.players) do
		MatchEnd:FireClient(p, matchData)
		-- Сохранение в DataStore (через _G или require)
		if _G.DataStore then
			_G.DataStore.AddPlayerRewards(p.UserId, rewards.rp, rewards.coins)
		end
	end
	
	activeMatches[matchId] = nil
end

return GameManager
