-- DataStore.server.lua | Anime Arena: Blitz
-- Production хранение данных игрока:
--   • Основные: rank, rp, coins, wins, losses, heroPlays
--   • Battle Pass: level, xp, seasonId, freeClaims, premiumClaims
--   • Безопасное сохранение (очередь + защита от потери данных)
--   • Автосохранение при выходе + BindToClose
--   • Отправка данных профиля в LobbyUI после загрузки
--   • _G.DataStore — публичный API

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local rRankUpdate  = Remotes:WaitForChild("RankUpdate",  10)
local rUpdateHUD   = Remotes:WaitForChild("UpdateHUD",   10)

-- ============================================================
-- ДАТАСТОРЕС
-- ============================================================

local STORE_KEY  = "AnimeArenav4_"
local IS_STUDIO  = game:GetService("RunService"):IsStudio()

-- В Studio без публикации DataStore недоступен.
-- Используем заглушку — данные хранятся только в памяти до закрытия.
local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("AnimeArenaBlitz_v4")
end)
if not storeOk then
	warn("[DataStore] DataStore unavailable (Studio without API access). Using in-memory fallback.")
	store = nil
end

-- ============================================================
-- РАНГОВАЯ СИСТЕМА
-- ============================================================

local RANK_THRESHOLDS = {
	{ rank = "SS", min = 5000 },
	{ rank = "S",  min = 3500 },
	{ rank = "A",  min = 2000 },
	{ rank = "B",  min = 1000 },
	{ rank = "C",  min = 500  },
	{ rank = "D",  min = 200  },
	{ rank = "E",  min = 0    },
}

local function getRankFromRP(rp)
	for _, t in ipairs(RANK_THRESHOLDS) do
		if rp >= t.min then return t.rank end
	end
	return "E"
end

-- ============================================================
-- ДЕФОЛТНЫЕ ДАННЫЕ
-- ============================================================

local CURRENT_SEASON = "S1"

local function defaultData()
	return {
		-- Основные
		rp      = 0,
		rank    = "E",
		coins   = 100,    -- стартовые монеты
		wins    = 0,
		losses  = 0,
		heroPlays = {},   -- [heroId] = count
		-- Battle Pass
		bp = {
			seasonId     = CURRENT_SEASON,
			level        = 0,
			xp           = 0,
			premium      = false,
			freeClaims   = {},   -- [level] = true
			premiumClaims= {},
		},
	}
end

-- ============================================================
-- КЕШ (в памяти)
-- ============================================================

local playerData = {}   -- [userId] = data
local saveQueue  = {}   -- [userId] = true — нужно сохранить

-- ============================================================
-- ЗАГРУЗКА ДАННЫХ
-- ============================================================

local function loadData(player)
	local uid = player.UserId
	local key = STORE_KEY .. uid

	local success, data = false, nil
	if store then
		success, data = pcall(function()
			return store:GetAsync(key)
		end)
		if not success then
			warn("[DataStore] Load failed for", player.Name, "| using defaults")
			data = nil
		end
	else
		if IS_STUDIO then
			print("[DataStore] Studio mode — using default data for", player.Name)
		end
	end

	if type(data) ~= "table" then
		data = defaultData()
	end

	-- Мерж с дефолтами (новые поля не будут nil у старых аккаунтов)
	local def = defaultData()
	for k, v in pairs(def) do
		if data[k] == nil then data[k] = v end
	end
	if data.bp == nil then data.bp = def.bp end
	for k, v in pairs(def.bp) do
		if data.bp[k] == nil then data.bp[k] = v end
	end

	-- Пересчитываем ранг на основе RP
	data.rank = getRankFromRP(data.rp)

	playerData[uid] = data
	print(string.format("[DataStore] Loaded %s | Rank:%s | RP:%d | Coins:%d",
		player.Name, data.rank, data.rp, data.coins))

	-- Отправляем данные в HUD и LobbyUI
	task.delay(1, function()
		if not player or not player.Parent then return end
		rUpdateHUD:FireClient(player, {
			rank   = data.rank,
			rp     = data.rp,
			coins  = data.coins,
			wins   = data.wins,
			losses = data.losses,
			bpLevel = data.bp.level,
		})
	end)
end

-- ============================================================
-- СОХРАНЕНИЕ ДАННЫХ
-- ============================================================

local function saveData(player, data)
	if not data then return end
	if not store then
		saveQueue[player.UserId] = nil
		return  -- Studio fallback: no persistent save
	end
	local uid = player.UserId
	local key = STORE_KEY .. uid

	local success, err = pcall(function()
		store:SetAsync(key, data)
	end)

	if success then
		saveQueue[uid] = nil
		print("[DataStore] Saved", player.Name)
	else
		warn("[DataStore] Save failed for", player.Name, "|", err)
	end
end

-- ============================================================
-- ПУБЛИЧНЫЙ API
-- ============================================================

local DataStore = {}
_G.DataStore = DataStore

function DataStore.GetData(userId)
	return playerData[userId]
end

--- Начислить RP + Coins и обновить ранг
function DataStore.AddPlayerRewards(userId, rpGain, coinsGain, isWin)
	local data = playerData[userId]
	if not data then return end

	local oldRank = data.rank

	data.rp    = math.max(0, data.rp    + (rpGain    or 0))
	data.coins = math.max(0, data.coins + (coinsGain or 0))

	if isWin ~= nil then
		if isWin then data.wins   = data.wins   + 1
		else           data.losses = data.losses + 1
		end
	end

	local newRank = getRankFromRP(data.rp)
	data.rank = newRank

	saveQueue[userId] = true

	local player = Players:GetPlayerByUserId(userId)
	if player then
		-- Уведомляем клиента о новом ранге
		rRankUpdate:FireClient(player, oldRank, newRank, data.rp)
		-- Обновляем HUD
		rUpdateHUD:FireClient(player, {
			rank   = newRank,
			rp     = data.rp,
			coins  = data.coins,
			wins   = data.wins,
			losses = data.losses,
		})
	end
end

--- Добавить Battle Pass XP
function DataStore.AddBPXP(userId, xpAmount)
	local data = playerData[userId]
	if not data then return end

	local bp = data.bp
	bp.xp = bp.xp + (xpAmount or 0)

	-- XP на уровень: каждый уровень = 500 XP
	local XP_PER_LEVEL = 500
	while bp.xp >= XP_PER_LEVEL do
		bp.xp   = bp.xp - XP_PER_LEVEL
		bp.level = math.min(bp.level + 1, 100)
	end

	saveQueue[userId] = true

	local player = Players:GetPlayerByUserId(userId)
	if player then
		rUpdateHUD:FireClient(player, { bpLevel = bp.level, bpXP = bp.xp })
	end
end

--- Установить премиум BP
function DataStore.SetBPPremium(userId, value)
	local data = playerData[userId]
	if not data then return end
	data.bp.premium = value == true
	saveQueue[userId] = true
end

--- Получить награду BP уровня
function DataStore.ClaimBPReward(userId, level, isPremium)
	local data = playerData[userId]
	if not data then return false end
	local bp = data.bp
	if bp.level < level then return false end

	if isPremium then
		if not bp.premium then return false end
		if bp.premiumClaims[tostring(level)] then return false end
		bp.premiumClaims[tostring(level)] = true
	else
		if bp.freeClaims[tostring(level)] then return false end
		bp.freeClaims[tostring(level)] = true
	end

	saveQueue[userId] = true
	return true
end

--- Статистика усе героя
function DataStore.RecordHeroPlay(userId, heroId)
	local data = playerData[userId]
	if not data then return end
	if not heroId then return end
	data.heroPlays[heroId] = (data.heroPlays[heroId] or 0) + 1
	saveQueue[userId] = true
end

--- Прямое изменение поля
function DataStore.SetField(userId, field, value)
	local data = playerData[userId]
	if not data then return end
	data[field] = value
	saveQueue[userId] = true
end

-- ============================================================
-- АВТОСОХРАНЕНИЕ (каждые 60 секунд)
-- ============================================================

task.spawn(function()
	while true do
		task.wait(60)
		for uid, _ in pairs(saveQueue) do
			local player = Players:GetPlayerByUserId(uid)
			local data   = playerData[uid]
			if player and data then
				task.spawn(saveData, player, data)
			end
		end
	end
end)

-- ============================================================
-- СОБЫТИЯ ИГРОКОВ
-- ============================================================

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadData, player)
end)

Players.PlayerRemoving:Connect(function(player)
	local uid  = player.UserId
	local data = playerData[uid]
	if data then
		saveData(player, data)
		playerData[uid] = nil
		saveQueue[uid]  = nil
	end
end)

-- Сохраняем всех перед закрытием сервера
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = playerData[player.UserId]
		if data then saveData(player, data) end
	end
end)

-- Загрузка данных для уже вошедших
-- (если DataStore загрузился поздно)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadData, player)
end

print("[DataStore] Initialized ✓")
return DataStore
