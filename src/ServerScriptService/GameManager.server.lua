-- GameManager.server.lua | Anime Arena: Blitz Mode
-- Главный менеджер матчей: лобби, старт, таймер, конец, выдача RP

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchStart = Remotes:WaitForChild("RoundStart")
local MatchEnd = Remotes:WaitForChild("MatchEnd")
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
			CombatSystem.initPlayer(p, {id = "FlameRonin", hp = 120}) -- Временный выбор
		end
	end
	
	activeMatches[matchId] = {
		players = matchPlayers,
		startTime = tick(),
		duration = Config.ROUND_DURATION[mode] or 180,
		mode = mode
	}
	
	-- Уведомляем клиентов
	for _, p in pairs(matchPlayers) do
		MatchStart:FireClient(p, mode)
	end
	
	print("[GameManager] Match started:", matchId, "Mode:", mode)
	
	-- Таймер матча
	task.spawn(function()
		local timeLeft = activeMatches[matchId].duration
		while timeLeft > 0 and activeMatches[matchId] do
			for _, p in pairs(matchPlayers) do
				UpdateTimer:FireClient(p, timeLeft)
			end
			task.wait(1)
			timeLeft -= 1
		end
		
		if activeMatches[matchId] then
			GameManager.EndMatch(matchId, nil) -- Ничья по времени
		end
	end)
end

-- === Конец Матча ===

function GameManager.EndMatch(matchId, winnerId)
	local match = activeMatches[matchId]
	if not match then return end
	
	print("[GameManager] Match ended:", matchId, "Winner:", winnerId or "Draw")
	
	for _, p in pairs(match.players) do
		MatchEnd:FireClient(p, winnerId)
		-- Тут будет логика начисления Rank Points (RP) и Coins через DataStore
	end
	
	activeMatches[matchId] = nil
end

return GameManager
