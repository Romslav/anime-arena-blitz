-- DataStore.server.lua | Anime Arena: Blitz
-- Production хранение данных игрока (Валютный Треугольник v2):
--   • Валюты:  coins (фарм), gems (твёрдая), mastery shards (per-hero)
--   • Ранг:    E→D→C→B→A→S→SS→SSS (RP), gems за ранг-ап (один раз)
--   • Герои:   heroes[heroId] — masteryXP/Level/Shards, awakeningNodes, FX, prestige
--   • Статистика: wins, winStreak, totalMatches, sssCount, highestStyle
--   • Battle Pass, WishingWell pity (persistent)
--   • _G.DataStore — публичный API

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes         = ReplicatedStorage:WaitForChild("Remotes")
local rRankUpdate     = Remotes:WaitForChild("RankUpdate",     10)
local rUpdateHUD      = Remotes:WaitForChild("UpdateHUD",      10)
local rGemsUpdate     = Remotes:WaitForChild("GemsUpdate",     10)
local rRankUpGems     = Remotes:WaitForChild("RankUpGems",     10)
local rMasteryLevelUp = Remotes:WaitForChild("MasteryLevelUp", 10)
local rMasteryShards  = Remotes:WaitForChild("MasteryShardUpdate", 10)
local rShowNotif      = Remotes:WaitForChild("ShowNotification", 10)

-- ============================================================
-- ДАТАСТОРЕС
-- ============================================================

local STORE_KEY = "AnimeArenav4_"
local IS_STUDIO = game:GetService("RunService"):IsStudio()

local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("AnimeArenaBlitz_v4")
end)
if not storeOk then
	warn("[DataStore] DataStore unavailable (Studio without API access). Using in-memory fallback.")
	store = nil
end

-- ============================================================
-- РАНГОВАЯ СИСТЕМА (включая SSS)
-- ============================================================

local RANK_THRESHOLDS = {
	{ rank = "SSS", min = 8000 },
	{ rank = "SS",  min = 5000 },
	{ rank = "S",   min = 3000 },
	{ rank = "A",   min = 1800 },
	{ rank = "B",   min = 1000 },
	{ rank = "C",   min = 500  },
	{ rank = "D",   min = 200  },
	{ rank = "E",   min = 0    },
}

-- Gems за первое пересечение порога ранга
local GEM_REWARDS_RANK = {
	D   = 30,
	C   = 50,
	B   = 75,
	A   = 110,
	S   = 150,
	SS  = 200,
	SSS = 300,
}

local function getRankFromRP(rp)
	for _, t in ipairs(RANK_THRESHOLDS) do
		if rp >= t.min then return t.rank end
	end
	return "E"
end

-- ============================================================
-- МАСТЕРСТВО: ПОРОГИ УРОВНЕЙ И ШАРДЫ
-- ============================================================

local MASTERY_LEVEL_XP = {
	[1]=100, [2]=200, [3]=350, [4]=500,
	[5]=700, [6]=950, [7]=1250, [8]=1600, [9]=2000, [10]=2500,
}

local SHARDS_PER_LEVEL = {
	[1]=20,  [2]=30,  [3]=40,  [4]=50,  [5]=75,
	[6]=80,  [7]=90,  [8]=100, [9]=125, [10]=200,
}

local MASTERY_MAX_LEVEL = 10

-- ============================================================
-- HERO FX SHOP (траты Mastery Shards)
-- ============================================================

local HERO_FX_SHOP = {
	aura_basic   = { cost = 50,  requiredLevel = 2  },
	trail        = { cost = 100, requiredLevel = 4  },
	aura_crimson = { cost = 200, requiredLevel = 6  },
	hit_sparks   = { cost = 150, requiredLevel = 5  },
	prestige_fx  = { cost = 500, requiredLevel = 10 },
}

-- ============================================================
-- ДЕФОЛТНЫЕ ДАННЫЕ
-- ============================================================

local CURRENT_SEASON = "S1"

--- Пустой объект героя — создаётся при первом получении
local function defaultHeroEntry()
	return {
		masteryXP      = 0,
		masteryLevel   = 0,
		masteryShards  = 0,
		prestigeCount  = 0,
		totalMatches   = 0,
		awakeningNodes = {},   -- { "blade_1"=true, ... }
		passiveSlots   = {},   -- { [1]=nil, [2]=nil, [3]=nil }
		unlockedFX     = {},   -- { "aura_basic"=true, ... }
		activeFX       = {     -- текущие надетые эффекты
			aura  = nil,
			trail = nil,
			hit   = nil,
			entry = nil,
		},
	}
end

local function defaultData()
	return {
		-- ВАЛЮТЫ
		coins = 100,
		gems  = 0,

		-- РАНГ И RP
		rp               = 0,
		rank             = "E",
		claimedRankRewards = {},   -- { D=true, C=true, ... } — anti-dupe для gem-выдачи

		-- СТАТИСТИКА
		stats = {
			totalWins          = 0,
			totalMatches       = 0,
			totalDamageDealt   = 0,
			sssCount           = 0,
			highestStyle       = "D",
			currentWinStreak   = 0,
			bestWinStreak      = 0,
		},

		-- HEROES — per-hero прогрессия
		heroes = {},   -- { ["FlameRonin"] = defaultHeroEntry(), ... }

		-- BATTLE PASS
		bp = {
			seasonId      = CURRENT_SEASON,
			level         = 0,
			xp            = 0,
			premium       = false,
			freeClaims    = {},
			premiumClaims = {},
		},

		-- WISHING WELL
		wishingWell = {
			totalPulls   = 0,
			pityNormal   = 0,
			pityEpic     = 0,
		},

		-- ОНБОРДИНГ
		isFirstTime = true,

		-- УСТАРЕВШИЕ ПОЛЯ (только для миграции — не используются в новом коде)
		wins      = 0,
		losses    = 0,
		heroPlays = {},
		mastery   = {},
		unlockedHeroes = {},
	}
end

-- ============================================================
-- КЕШ
-- ============================================================

local playerData = {}
local saveQueue  = {}

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ
-- ============================================================

--- Инициализировать запись героя, если её ещё нет
local function ensureHeroEntry(data, heroId)
	if type(data.heroes) ~= "table" then data.heroes = {} end
	if not data.heroes[heroId] then
		data.heroes[heroId] = defaultHeroEntry()
	end
	-- Гарантируем все поля (обратная совместимость)
	local h = data.heroes[heroId]
	local def = defaultHeroEntry()
	for k, v in pairs(def) do
		if h[k] == nil then h[k] = v end
	end
	return data.heroes[heroId]
end

--- Проверить, разблокирован ли герой
local function isHeroUnlocked(data, heroId)
	-- Новая структура
	if data.heroes and data.heroes[heroId] then return true end
	-- Устаревшая структура (миграция)
	if data.unlockedHeroes and table.find(data.unlockedHeroes, heroId) then return true end
	return false
end

-- ============================================================
-- ЗАГРУЗКА + МИГРАЦИЯ
-- ============================================================

local function migrateData(data)
	-- 1. Мерж полей defaultData
	local def = defaultData()
	for k, v in pairs(def) do
		if data[k] == nil then data[k] = v end
	end
	-- 2. Мерж bp
	if type(data.bp) ~= "table" then data.bp = def.bp end
	for k, v in pairs(def.bp) do
		if data.bp[k] == nil then data.bp[k] = v end
	end
	-- 3. Мерж stats
	if type(data.stats) ~= "table" then data.stats = def.stats end
	for k, v in pairs(def.stats) do
		if data.stats[k] == nil then data.stats[k] = v end
	end
	-- 4. Мерж wishingWell
	if type(data.wishingWell) ~= "table" then data.wishingWell = def.wishingWell end
	for k, v in pairs(def.wishingWell) do
		if data.wishingWell[k] == nil then data.wishingWell[k] = v end
	end
	-- 5. Гарантируем heroes таблицу
	if type(data.heroes) ~= "table" then data.heroes = {} end
	-- 6. Миграция старых unlockedHeroes → heroes
	if type(data.unlockedHeroes) == "table" then
		for _, heroId in ipairs(data.unlockedHeroes) do
			if not data.heroes[heroId] then
				data.heroes[heroId] = defaultHeroEntry()
				-- Перенести старые mastery xp/level
				if type(data.mastery) == "table" and data.mastery[heroId] then
					local old = data.mastery[heroId]
					data.heroes[heroId].masteryXP    = old.xp    or 0
					data.heroes[heroId].masteryLevel = old.level or 0
				end
			end
		end
	end
	-- 7. claimedRankRewards
	if type(data.claimedRankRewards) ~= "table" then data.claimedRankRewards = {} end
	-- 8. Пересчитываем ранг
	data.rank = getRankFromRP(data.rp)
	return data
end

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

	data = migrateData(data)
	playerData[uid] = data

	print(string.format("[DataStore] Loaded %s | Rank:%s | RP:%d | Coins:%d | Gems:%d",
		player.Name, data.rank, data.rp, data.coins, data.gems or 0))

	-- Отправляем данные в HUD и UI
	task.delay(1, function()
		if not player or not player.Parent then return end
		rUpdateHUD:FireClient(player, {
			rank    = data.rank,
			rp      = data.rp,
			coins   = data.coins,
			gems    = data.gems,
			wins    = data.stats.totalWins,
			losses  = (data.stats.totalMatches or 0) - (data.stats.totalWins or 0),
			bpLevel = data.bp.level,
		})
	end)
end

-- ============================================================
-- СОХРАНЕНИЕ
-- ============================================================

local function saveData(player, data)
	if not data then return end
	if not store then
		saveQueue[player.UserId] = nil
		return
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

-- ============================================================
-- COINS
-- ============================================================

--- Добавить монеты (amount может быть отрицательным — SpendCoins)
function DataStore.AddCoins(userId, amount)
	local data = playerData[userId]
	if not data then return end
	data.coins = math.max(0, data.coins + (amount or 0))
	saveQueue[userId] = true
	local player = Players:GetPlayerByUserId(userId)
	if player then
		rUpdateHUD:FireClient(player, { coins = data.coins })
	end
end

--- Потратить монеты. Возвращает true при успехе, false если не хватает.
function DataStore.SpendCoins(userId, amount)
	local data = playerData[userId]
	if not data then return false end
	if data.coins < amount then return false end
	data.coins = data.coins - amount
	saveQueue[userId] = true
	local player = Players:GetPlayerByUserId(userId)
	if player then
		rUpdateHUD:FireClient(player, { coins = data.coins })
	end
	return true
end

-- ============================================================
-- GEMS
-- ============================================================

function DataStore.AddGems(userId, amount, reason)
	local data = playerData[userId]
	if not data then return end
	local delta = amount or 0
	data.gems = math.max(0, data.gems + delta)
	saveQueue[userId] = true
	local player = Players:GetPlayerByUserId(userId)
	if player then
		rUpdateHUD:FireClient(player, { gems = data.gems })
		pcall(function()
			rGemsUpdate:FireClient(player, data.gems, delta, reason or "")
		end)
	end
end

--- Потратить гемы. Возвращает true при успехе.
function DataStore.SpendGems(userId, amount)
	local data = playerData[userId]
	if not data then return false end
	if data.gems < amount then return false end
	data.gems = data.gems - amount
	saveQueue[userId] = true
	local player = Players:GetPlayerByUserId(userId)
	if player then
		rUpdateHUD:FireClient(player, { gems = data.gems })
		pcall(function()
			rGemsUpdate:FireClient(player, data.gems, -amount, "spend")
		end)
	end
	return true
end

-- ============================================================
-- RANK-UP GEMS (один раз за ранг)
-- ============================================================

local function checkRankUpReward(userId, oldRp, newRp)
	local data = playerData[userId]
	if not data then return end

	local oldRank = getRankFromRP(oldRp)
	local newRank = getRankFromRP(newRp)
	if oldRank == newRank then return end

	-- Перебираем все ранги между старым и новым
	for _, t in ipairs(RANK_THRESHOLDS) do
		local r = t.rank
		if r == "E" then continue end  -- E: нет награды
		local gems = GEM_REWARDS_RANK[r]
		if not gems then continue end

		-- Проверяем, что порог пересечён в нужную сторону и не выдавался ещё
		if newRp >= t.min and oldRp < t.min and not data.claimedRankRewards[r] then
			data.claimedRankRewards[r] = true
			DataStore.AddGems(userId, gems, "rank_up")

			local player = Players:GetPlayerByUserId(userId)
			if player then
				pcall(function() rRankUpGems:FireClient(player, r, gems) end)
				pcall(function() rShowNotif:FireClient(player,
					string.format("🏆 Ранг %s! +%d 💎", r, gems), "rank_gems") end)
			end
		end
	end
end

-- ============================================================
-- REWARDS (RP + Coins вместе)
-- ============================================================

function DataStore.AddPlayerRewards(userId, rpGain, coinsGain, isWin)
	local data = playerData[userId]
	if not data then return end

	local oldRank = data.rank
	local oldRp   = data.rp

	data.rp    = math.max(0, data.rp    + (rpGain    or 0))
	data.coins = math.max(0, data.coins + (coinsGain or 0))

	-- Обновляем статистику
	data.stats.totalMatches = (data.stats.totalMatches or 0) + 1
	if isWin == true then
		data.stats.totalWins = (data.stats.totalWins or 0) + 1
		data.stats.currentWinStreak = (data.stats.currentWinStreak or 0) + 1
		if data.stats.currentWinStreak > (data.stats.bestWinStreak or 0) then
			data.stats.bestWinStreak = data.stats.currentWinStreak
		end
		-- Совместимость со старым полем
		data.wins = (data.wins or 0) + 1
	elseif isWin == false then
		data.stats.currentWinStreak = 0
		data.losses = (data.losses or 0) + 1
	end

	local newRank = getRankFromRP(data.rp)
	data.rank = newRank

	saveQueue[userId] = true

	local player = Players:GetPlayerByUserId(userId)
	if player then
		rRankUpdate:FireClient(player, oldRank, newRank, data.rp)
		rUpdateHUD:FireClient(player, {
			rank   = newRank,
			rp     = data.rp,
			coins  = data.coins,
			gems   = data.gems,
			wins   = data.stats.totalWins,
			losses = (data.stats.totalMatches or 0) - (data.stats.totalWins or 0),
		})
	end

	-- Gem-награды за ранг-ап
	checkRankUpReward(userId, oldRp, data.rp)

	-- RP-пороги разблокировки героев
	local RP_UNLOCKS = {
		{ rp = 500,  heroId = "StormDancer"   },
		{ rp = 1200, heroId = "ScarletArcher" },
		{ rp = 3000, heroId = "JadeSentinel"  },
	}
	for _, threshold in ipairs(RP_UNLOCKS) do
		if oldRp < threshold.rp and data.rp >= threshold.rp then
			local unlocked = DataStore.UnlockHero(userId, threshold.heroId)
			if unlocked and player then
				local rUnlocked = Remotes:FindFirstChild("HeroUnlocked")
				if rUnlocked then rUnlocked:FireClient(player, threshold.heroId) end
				pcall(function() rShowNotif:FireClient(player,
					"🔓 НОВЫЙ ГЕРОЙ: " .. threshold.heroId, "unlock") end)
			end
		end
	end
end

-- ============================================================
-- ГЕРОИ — РАЗБЛОКИРОВКА
-- ============================================================

--- Разблокировать героя. Возвращает true если новый, false если дубликат.
function DataStore.UnlockHero(userId, heroId)
	local data = playerData[userId]
	if not data then return false end
	if isHeroUnlocked(data, heroId) then return false end

	ensureHeroEntry(data, heroId)
	-- Совместимость со старыми списком
	if not data.unlockedHeroes then data.unlockedHeroes = {} end
	if not table.find(data.unlockedHeroes, heroId) then
		table.insert(data.unlockedHeroes, heroId)
	end

	saveQueue[userId] = true
	print(string.format("[DataStore] Player %d unlocked hero '%s'", userId, heroId))
	return true
end

function DataStore.IsHeroUnlocked(userId, heroId)
	local data = playerData[userId]
	if not data then return false end
	return isHeroUnlocked(data, heroId)
end

-- ============================================================
-- МАСТЕРСТВО ГЕРОЯ
-- ============================================================

--- Начислить Mastery XP за конкретного героя.
--- Автоматически повышает уровень, начисляет Shards, стреляет ивенты клиенту.
--- Возвращает количество повышений уровня (0 если не было).
function DataStore.AddMasteryXP(userId, heroId, amount)
	local data = playerData[userId]
	if not data then return 0 end
	if not isHeroUnlocked(data, heroId) then return 0 end

	local h = ensureHeroEntry(data, heroId)
	h.masteryXP = h.masteryXP + (amount or 0)

	local levelsGained = 0

	while h.masteryLevel < MASTERY_MAX_LEVEL do
		local needed = MASTERY_LEVEL_XP[h.masteryLevel + 1]
		if not needed then break end
		if h.masteryXP < needed then break end

		h.masteryXP    = h.masteryXP - needed
		h.masteryLevel = h.masteryLevel + 1
		levelsGained   = levelsGained + 1

		-- Шарды за уровень
		local shardsEarned = SHARDS_PER_LEVEL[h.masteryLevel] or 0
		h.masteryShards = h.masteryShards + shardsEarned

		print(string.format("[DataStore] Player %d | %s Mastery Lv%d | +%d Shards",
			userId, heroId, h.masteryLevel, shardsEarned))

		-- Уведомляем клиента
		local player = Players:GetPlayerByUserId(userId)
		if player then
			pcall(function()
				rMasteryLevelUp:FireClient(player, heroId, h.masteryLevel, shardsEarned)
			end)
			pcall(function()
				rMasteryShards:FireClient(player, heroId, h.masteryShards, shardsEarned)
			end)
			pcall(function()
				rShowNotif:FireClient(player,
					string.format("⭐ %s Mastery Lv%d! +%d Shards", heroId, h.masteryLevel, shardsEarned),
					"mastery_up")
			end)
		end
	end

	saveQueue[userId] = true
	return levelsGained
end

--- Потратить Mastery Shards на FX героя.
--- Проверяет баланс shards и requiredLevel. Возвращает true при успехе.
function DataStore.SpendMasteryShards(userId, heroId, fxKey)
	local data = playerData[userId]
	if not data then return false, "no_data" end
	if not isHeroUnlocked(data, heroId) then return false, "hero_locked" end

	local fx = HERO_FX_SHOP[fxKey]
	if not fx then return false, "unknown_fx" end

	local h = ensureHeroEntry(data, heroId)
	if h.masteryLevel < fx.requiredLevel then
		return false, string.format("need_level_%d", fx.requiredLevel)
	end
	if h.masteryShards < fx.cost then
		return false, string.format("need_%d_shards", fx.cost)
	end

	h.masteryShards = h.masteryShards - fx.cost
	h.unlockedFX[fxKey] = true
	saveQueue[userId] = true

	local player = Players:GetPlayerByUserId(userId)
	if player then
		pcall(function()
			rMasteryShards:FireClient(player, heroId, h.masteryShards, -fx.cost)
		end)
	end

	return true
end

--- Сбросить Awakening Tree (стоит 200 Shards, 50% Shards возвращаются за ноды).
function DataStore.ResetAwakeningTree(userId, heroId)
	local data = playerData[userId]
	if not data then return false, "no_data" end

	local h = ensureHeroEntry(data, heroId)
	local RESET_COST = 200

	if h.masteryShards < RESET_COST then
		return false, string.format("need_%d_shards", RESET_COST)
	end

	-- Считаем потраченные на ноды шарды (50% возврат)
	-- Упрощённо: возвращаем 50 за каждый активный нод
	local nodeCount = 0
	for _ in pairs(h.awakeningNodes) do nodeCount += 1 end
	local refund = math.floor(nodeCount * 30 * 0.5)  -- ~30 shards avg per node

	h.masteryShards  = h.masteryShards - RESET_COST + refund
	h.awakeningNodes = {}
	h.passiveSlots   = {}
	saveQueue[userId] = true

	return true, refund
end

-- ============================================================
-- МАССТВО: СТАТИСТИКА В БАНДЛ
-- ============================================================

--- Обновить статистику стиля и счётчики
function DataStore.RecordMatchStats(userId, heroId, isWin, styleRank, damageDealt)
	local data = playerData[userId]
	if not data then return end

	local st = data.stats
	st.totalDamageDealt = (st.totalDamageDealt or 0) + (damageDealt or 0)
	if styleRank == "SSS" then
		st.sssCount = (st.sssCount or 0) + 1
	end

	-- Обновляем highestStyle
	local RANK_ORDER = { D=1, C=2, B=3, A=4, S=5, SS=6, SSS=7 }
	local current = RANK_ORDER[styleRank] or 1
	local best    = RANK_ORDER[st.highestStyle or "D"] or 1
	if current > best then
		st.highestStyle = styleRank
	end

	-- Инкрементируем totalMatches героя
	if heroId and isHeroUnlocked(data, heroId) then
		local h = ensureHeroEntry(data, heroId)
		h.totalMatches = (h.totalMatches or 0) + 1
	end

	saveQueue[userId] = true
end

-- ============================================================
-- BATTLE PASS
-- ============================================================

function DataStore.AddBPXP(userId, xpAmount)
	local data = playerData[userId]
	if not data then return end

	local bp = data.bp
	bp.xp = bp.xp + (xpAmount or 0)

	local XP_PER_LEVEL = 500
	while bp.xp >= XP_PER_LEVEL do
		bp.xp    = bp.xp - XP_PER_LEVEL
		bp.level = math.min(bp.level + 1, 100)
	end

	saveQueue[userId] = true
	local player = Players:GetPlayerByUserId(userId)
	if player then
		rUpdateHUD:FireClient(player, { bpLevel = bp.level, bpXP = bp.xp })
	end
end

function DataStore.SetBPPremium(userId, value)
	local data = playerData[userId]
	if not data then return end
	data.bp.premium = value == true
	saveQueue[userId] = true
end

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

-- ============================================================
-- УТИЛИТЫ
-- ============================================================

function DataStore.RecordHeroPlay(userId, heroId)
	local data = playerData[userId]
	if not data or not heroId then return end
	if type(data.heroPlays) ~= "table" then data.heroPlays = {} end
	data.heroPlays[heroId] = (data.heroPlays[heroId] or 0) + 1
	saveQueue[userId] = true
end

function DataStore.SetField(userId, field, value)
	local data = playerData[userId]
	if not data then return end
	data[field] = value
	saveQueue[userId] = true
end

function DataStore.SetFirstTimeDone(userId)
	local data = playerData[userId]
	if not data then return end
	data.isFirstTime = false
	saveQueue[userId] = true
end

-- Обратная совместимость
function DataStore.AddMasteryXPLegacy(userId, heroId, amount)
	return DataStore.AddMasteryXP(userId, heroId, amount)
end

-- ============================================================
-- АВТОСОХРАНЕНИЕ
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

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = playerData[player.UserId]
		if data then saveData(player, data) end
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadData, player)
end

-- ============================================================
-- ЛИДЕРБОРД
-- ============================================================

local rGetLeaderboard = Remotes:FindFirstChild("GetLeaderboard")
if rGetLeaderboard then
	rGetLeaderboard.OnServerInvoke = function(player)
		local sorted = {}
		for uid, pd in pairs(playerData) do
			local p = Players:GetPlayerByUserId(uid)
			table.insert(sorted, {
				name = p and p.Name or "Unknown",
				rp   = pd.rp   or 0,
				rank = pd.rank or "E",
			})
		end
		table.sort(sorted, function(a, b) return a.rp > b.rp end)
		local top5 = {}
		for i = 1, math.min(5, #sorted) do
			top5[i] = sorted[i]
		end
		return top5
	end
end

-- ============================================================
-- REMOTE: GetUserData — полные данные для HeroSelector, UI
-- ============================================================

task.defer(function()
	local rGetUserData = Remotes:FindFirstChild("GetUserData")
	if rGetUserData then
		rGetUserData.OnServerInvoke = function(player)
			local data = playerData[player.UserId]
			if not data then
				return {
					unlockedHeroes = {},
					heroes         = {},
					mastery        = {},
					isFirstTime    = true,
					gems           = 0,
					coins          = 0,
					stats          = {},
				}
			end
			-- Строим список разблокированных героев из новой структуры
			local unlockedList = {}
			for heroId, _ in pairs(data.heroes) do
				table.insert(unlockedList, heroId)
			end
			-- Добавляем из старого списка (если ещё есть)
			if type(data.unlockedHeroes) == "table" then
				for _, heroId in ipairs(data.unlockedHeroes) do
					if not table.find(unlockedList, heroId) then
						table.insert(unlockedList, heroId)
					end
				end
			end
			return {
				rp             = data.rp,
				rank           = data.rank,
				coins          = data.coins,
				gems           = data.gems,
				wins           = data.stats.totalWins,
				losses         = (data.stats.totalMatches or 0) - (data.stats.totalWins or 0),
				unlockedHeroes = unlockedList,
				heroes         = data.heroes,
				mastery        = data.mastery,  -- legacy compat
				isFirstTime    = data.isFirstTime,
				stats          = data.stats,
				bp = {
					level   = data.bp.level,
					xp      = data.bp.xp,
					premium = data.bp.premium,
				},
			}
		end
	end
end)

print("[DataStore] Initialized ✓ — Currency Triangle v2 (Coins/Gems/Mastery Shards)")
return DataStore
