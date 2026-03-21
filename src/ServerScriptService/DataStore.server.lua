-- DataStore.server.lua | Anime Arena: Blitz Mode
-- Сохранение и загрузка прогресса игроков: RP, ранг, статистика

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

local playerData = {}
local DEFAULT_DATA = {
	rp = 0,
	coins = 0,
	wins = 0,
	losses = 0,
	kills = 0,
	totalDamage = 0,
}

local DataStoreModule = {}
_G.DataStore = DataStoreModule

-- === ЗАГРУЗКА ДАННЫХ ===

local function loadPlayerData(player)
	local userId = player.UserId
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync(userId)
	end)
	
	if success then
		playerData[userId] = data or table.clone(DEFAULT_DATA)
		print("[DataStore] Loaded data for", player.Name)
	else
		playerData[userId] = table.clone(DEFAULT_DATA)
		warn("[DataStore] Error loading data for", player.Name)
	end
end

-- === СОХРАНЕНИЕ ДАННЫХ ===

local function savePlayerData(player)
	local userId = player.UserId
	if not playerData[userId] then return end
	
	local success, err = pcall(function()
		PlayerDataStore:SetAsync(userId, playerData[userId])
	end)
	
	if not success then
		warn("[DataStore] Error saving data for", player.Name, ":", err)
	end
end

-- === Публичное API ===

function DataStoreModule.AddPlayerRewards(userId, rp, coins)
	if not playerData[userId] then return end
	
	playerData[userId].rp = math.max(0, playerData[userId].rp + rp)
	playerData[userId].coins = playerData[userId].coins + coins
	
	if rp > 0 then
		playerData[userId].wins += 1
	else
		playerData[userId].losses += 1
	end
	
	print("[DataStore] Updated rewards for", userId, ":", rp, "RP,", coins, "Coins")
end

function DataStoreModule.GetPlayerData(userId)
	return playerData[userId]
end

-- Эвенты
Players.PlayerAdded:Connect(loadPlayerData)
Players.PlayerRemoving:Connect(savePlayerData)

return DataStoreModule
