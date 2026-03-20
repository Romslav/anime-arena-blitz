-- GameManager.server.lua
-- Главный менеджер матчей: лобби, старт, таймер, конец, выдача RP

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchStart     = Remotes:WaitForChild("MatchStart")
local MatchEnd       = Remotes:WaitForChild("MatchEnd")
local UpdateTimer    = Remotes:WaitForChild("UpdateTimer")
local ShowRankScreen = Remotes:WaitForChild("ShowRankScreen")
local RequestRematch = Remotes:WaitForChild("RequestRematch")

-- Подключаем другие модули
local HeroSelector = require(ServerScriptService:WaitForChild("HeroSelector.server"))
local CombatSystem = require(ServerScriptService:WaitForChild("CombatSystem.server"))
local DataStore = require(ServerScriptService:WaitForChild("DataStore.server"))

-- НАСТРОЙКИ МАТЧА
local MATCH_DURATION = 90  -- 1:30 секунд
local MIN_PLAYERS = 2      -- минимум игроков для старта
local LOBBY_WAIT = 10      -- ожидание в лобби (секунды)

-- Состояние
local GameState = {
	mode = "Lobby",        -- Lobby | InMatch | PostMatch
	currentRound = 0,
	matchPlayers = {},     -- { player1, player2, ... }
	matchTimer = 0,
	rematchRequests = {},  -- { [userId] = true }
}

local timerThread = nil

-- === ФУНКЦИИ МАТЧА ===

local function resetMatch()
	CombatSystem.resetMatch()
	GameState.matchPlayers = {}
	GameState.matchTimer = 0
	GameState.rematchRequests = {}
	if timerThread then
		task.cancel(timerThread)
		timerThread = nil
	end
end

local function startMatch(playersList)
	if #playersList < MIN_PLAYERS then
		warn("[GameManager] Not enough players:", #playersList)
		return
	end

	print("[GameManager] Starting match with", #playersList, "players")
	GameState.mode = "InMatch"
	GameState.matchPlayers = playersList
	GameState.matchTimer = MATCH_DURATION

	-- Инициализация HP каждого игрока на основе выбранного героя
	for _, player in ipairs(playersList) do
		local heroData = HeroSelector.getSelected(player.UserId)
		if heroData then
			CombatSystem.initPlayer(player, heroData)
			-- Отправляем событие старта клиенту
			MatchStart:FireClient(player, heroData)
		end
	end

	-- Запускаем таймер
	timerThread = task.spawn(function()
		while GameState.matchTimer > 0 do
			task.wait(1)
			GameState.matchTimer -= 1
			-- Отправляем таймер всем игрокам
			for _, p in ipairs(playersList) do
				UpdateTimer:FireClient(p, GameState.matchTimer)
			end
		end
		-- Время вышло
		endMatch("timeout")
	end)
end

local function endMatch(reason)
	print("[GameManager] Match ended:", reason)
	GameState.mode = "PostMatch"

	-- Определяем победителя
	local winnerId = nil
	local maxHp = -1
	for _, player in ipairs(GameState.matchPlayers) do
		local state = CombatSystem.getState(player.UserId)
		if state and state.alive and state.hp > maxHp then
			maxHp = state.hp
			winnerId = player.UserId
		end
	end

	-- Отправляем событие конца матча
	MatchEnd:FireAllClients(winnerId)

	-- Выдаём RP и показываем экран рангов
	task.wait(2)
	for _, player in ipairs(GameState.matchPlayers) do
		local isWinner = (player.UserId == winnerId)
		local rpChange = isWinner and 25 or -15
		if isWinner then
			DataStore.recordWin(player.UserId)
		else
			DataStore.recordLoss(player.UserId)
		endange)
		local data = {
			rp = newRpDataStore.getRP(player.UserId)
			rpChange = rpChange,
			kills = 0,  -- TODO: трекать реальные киллы
			damage = 0, -- TODO: трекать урон
			isWinner = isWinner,
		}
		ShowRankScreen:FireClient(player, data)
	end

	-- Переходим в лобби через 10 сек
	task.wait(10)
	resetMatch()
	GameState.mode = "Lobby"
	print("[GameManager] Back to Lobby")
end

-- === ЛОББИ СИСТЕМА ===

local function tryStartMatch()
	if GameState.mode ~= "Lobby" then return end

	local activePlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		-- Проверяем что игрок выбрал героя
		if HeroSelector.getSelected(player.UserId) then
			table.insert(activePlayers, player)
		end
	end

	if #activePlayers >= MIN_PLAYERS then
		print("[GameManager] Starting match in", LOBBY_WAIT, "seconds...")
		task.wait(LOBBY_WAIT)
		startMatch(activePlayers)
	end
end

-- Авто-проверка лобби каждые 5 секунд
task.spawn(function()
	while true do
		task.wait(5)
		if GameState.mode == "Lobby" then
			tryStartMatch()
		end
	end
end)

-- === REMATCH СИСТЕМА ===

RequestRematch.OnServerEvent:Connect(function(player)
	if GameState.mode ~= "PostMatch" then return end
	GameState.rematchRequests[player.UserId] = true
	print("[GameManager] Rematch requested by", player.Name)

	-- Проверяем все ли согласны
	local allReady = true
	for _, p in ipairs(GameState.matchPlayers) do
		if not GameState.rematchRequests[p.UserId] then
			allReady = false
			break
		end
	end

	if allReady then
		print("[GameManager] All players ready for rematch!")
		resetMatch()
		task.wait(2)
		startMatch(GameState.matchPlayers)
	end
end)

-- === СОБЫТИЯ ИГРОКОВ ===

Players.PlayerAdded:Connect(function(player)
	print("[GameManager] Player joined:", player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
	print("[GameManager] Player left:", player.Name)
	-- Если игрок был в матче — завершаем матч
	for i, p in ipairs(GameState.matchPlayers) do
		if p.UserId == player.UserId then
			table.remove(GameState.matchPlayers, i)
			if #GameState.matchPlayers < MIN_PLAYERS and GameState.mode == "InMatch" then
				endMatch("player_left")
			end
			break
		end
	end
end)

print("[GameManager] Initialized. Waiting for players...")
