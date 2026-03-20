-- DataStore.server.lua
-- Сохранение и загрузка прогресса игроков: RP, ранг, статистика

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

-- Кэш данных в памяти (чтобы не спамить DataStore)
local playerData = {}  -- { [userId] = { rp, wins, losses, kills, totalDamage } }

-- Дефолтные данные нового игрока
local DEFAULT_DATA = {
	rp = 0,
	wins = 0,
	losses = 0,
	kills = 0,
	totalDamage = 0,
}

-- === ЗАГРУЗКА ДАННЫХ ===

local function loadPlayerData(player)
	local userId = player.UserId
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync("Player_" .. userId)
	end)

	if success and data then
		playerData[userId] = data
		print("[DataStore] Loaded data for", player.Name, "| RP:", data.rp)
	else
		-- Новый игрок
		playerData[userId] = {
			rp = DEFAULT_DATA.rp,
			wins = DEFAULT_DATA.wins,
			losses = DEFAULT_DATA.losses,
			kills = DEFAULT_DATA.kills,
			totalDamage = DEFAULT_DATA.totalDamage,
		}
		print("[DataStore] New player:", player.Name, "| Starting RP:", DEFAULT_DATA.rp)
	end
end

-- === СОХРАНЕНИЕ ДАННЫХ ===

local function savePlayerData(player)
	local userId = player.UserId
	local data = playerData[userId]
	if not data then return end

	local success, err = pcall(function()
		PlayerDataStore:SetAsync("Player_" .. userId, data)
	end)

	if success then
		print("[DataStore] Saved data for", player.Name, "| RP:", data.rp)
	else
		warn("[DataStore] Failed to save data for", player.Name, "Error:", err)
	end
end

-- === ПУБЛИЧНОЕ API ===

local DataStoreModule = {}

-- Получить данные игрока
function DataStoreModule.getData(userId)
	return playerData[userId]
end

-- Получить RP
function DataStoreModule.getRP(userId)
	local data = playerData[userId]
	return data and data.rp or 0
end

-- Добавить RP (может быть отрицательным)
function DataStoreModule.addRP(userId, amount)
	local data = playerData[userId]
	if data then
		data.rp = math.max(0, data.rp + amount)
		return data.rp
	end
	return 0
end

-- Зарегистрировать победу
function DataStoreModule.recordWin(userId)
	local data = playerData[userId]
	if data then
		data.wins += 1
	end
end

-- Зарегистрировать поражение
function DataStoreModule.recordLoss(userId)
	local data = playerData[userId]
	if data then
		data.losses += 1
	end
end

-- Добавить киллы
function DataStoreModule.addKills(userId, count)
	local data = playerData[userId]
	if data then
		data.kills += count
	end
end

-- Добавить урон
function DataStoreModule.addDamage(userId, amount)
	local data = playerData[userId]
	if data then
		data.totalDamage += amount
	end
end

-- Получить ранг по RP
function DataStoreModule.getRank(rp)
	if rp >= 2200 then return "SS"
	elseif rp >= 1500 then return "S"
	elseif rp >= 1000 then return "A"
	elseif rp >= 600 then return "B"
	elseif rp >= 300 then return "C"
	elseif rp >= 100 then return "D"
	else return "E"
	end
end

-- === СОБЫТИЯ ИГРОКОВ ===

Players.PlayerAdded:Connect(function(player)
	loadPlayerData(player)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	playerData[player.UserId] = nil
end)

-- Авто-сохранение каждые 5 минут
task.spawn(function()
	while true do
		task.wait(300) -- 5 минут
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayerData(player)
		end
		print("[DataStore] Auto-save completed")
	end
end)

-- Загружаем данные для уже подключённых игроков (если скрипт перезагружен)
for _, player in ipairs(Players:GetPlayers()) do
	loadPlayerData(player)
end

print("[DataStore] Initialized")

return DataStoreModule
