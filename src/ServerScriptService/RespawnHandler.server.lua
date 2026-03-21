-- RespawnHandler.server.lua
-- Управляет респавном с учетом игрового режима

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayerDied = Remotes:WaitForChild("PlayerDied")

local playerMatchData = {} -- [userId] = { matchId, mode }

-- === Получение систем ===
local function getGameModeModifiers()
	return _G.GameModeModifiers
end

local function getCharacterService()
	return _G.CharacterService
end

local function getCombatSystem()
	return _G.CombatSystem
end

-- === Обработка смерти ===
local function onCharacterDeath(player)
	local matchData = playerMatchData[player.UserId]
	if not matchData then return end
	
	local Modifiers = getGameModeModifiers()
	local CharSvc = getCharacterService()
	local Combat = getCombatSystem()
	
	-- Получаем время респавна из режима или дефолтное 5 сек
	local respawnTime = 5
	if Modifiers and matchData.mode then
		respawnTime = Modifiers.GetRespawnTime(matchData.mode)
	end
	
	print("[RespawnHandler]", player.Name, "died. Respawning in", respawnTime, "seconds")
	
	-- Ожидание и респавн
	task.wait(respawnTime)
	
	if player and player.Parent then
		-- Респавн player.Character
		player:LoadCharacter()
		
		-- Восстанавливаем статы с учетом режима
		task.wait(0.1) -- Небольшая задержка, чтобы character загрузился
		
		if CharSvc then
			local heroData = CharSvc.GetSelectedHero(player.UserId)
			if heroData and CharSvc.SpawnWithMode then
				CharSvc.SpawnWithMode(player, heroData, matchData.mode)
			elseif heroData and CharSvc.ApplyStats then
				CharSvc.ApplyStats(player.Character, heroData)
			end
		end
		
		if Combat then
			local state = Combat.getState(player.UserId)
			if state then
				state.alive = true
				state.hp = state.maxHp
			end
		end
	end
end

-- === Подключение к игроку ===
local function setupPlayerRespawn(player)
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			onCharacterDeath(player)
		end)
	end
	
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- === API ===
local RespawnHandler = {}

function RespawnHandler.RegisterPlayer(userId, matchId, mode)
	playerMatchData[userId] = { matchId = matchId, mode = mode }
end

function RespawnHandler.UnregisterPlayer(userId)
	playerMatchData[userId] = nil
end

-- === Инициализация ===
Players.PlayerAdded:Connect(setupPlayerRespawn)
for _, player in pairs(Players:GetPlayers()) do
	setupPlayerRespawn(player)
end

Players.PlayerRemoving:Connect(function(player)
	RespawnHandler.UnregisterPlayer(player.UserId)
end)

_G.RespawnHandler = RespawnHandler

return RespawnHandler
