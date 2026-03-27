-- WishingWellService.server.lua | Anime Arena: Blitz
-- Гача-система "Колодец Желаний":
--   • Обычный сундук (500 монет): Legendary 3%, Epic 12%, Rare 55%, Common 30%
--   • Эпический сундук (1500 монет): Legendary 15%, Epic 35%, Rare 45%, Common 5%
--   • Pity-система: гарант Legendary после 50/20 крутов
--   • Дубликат: компенсация монетами, предпочтение неоткрытым героям
--   • Legendary броадкаст: все в игре видят, кому повезло
--   • Публичный API: RollGacha (RemoteFunction)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes            = ReplicatedStorage:WaitForChild("Remotes")
local rRollGacha         = Remotes:WaitForChild("RollGacha",          10)
local rWishingWellResult = Remotes:WaitForChild("WishingWellResult",  10)
local rShowNotification  = Remotes:WaitForChild("ShowNotification",   10)
local rUpdateHUD         = Remotes:WaitForChild("UpdateHUD",          10)

-- ============================================================
-- КОНФИГУРАЦИЯ
-- ============================================================

local CHEST_CONFIG = {
	normal = {
		cost  = 500,
		pity  = 50,
		weights = {
			{ rarity = "Legendary", weight = 3  },
			{ rarity = "Epic",      weight = 12 },
			{ rarity = "Rare",      weight = 55 },
			{ rarity = "Common",    weight = 30 },
		},
	},
	epic = {
		cost  = 1500,
		pity  = 20,
		weights = {
			{ rarity = "Legendary", weight = 15 },
			{ rarity = "Epic",      weight = 35 },
			{ rarity = "Rare",      weight = 45 },
			{ rarity = "Common",    weight = 5  },
		},
	},
}

-- Пулы героев по редкости (НЕ включают стартовых: FlameRonin, IronTitan, ThunderMonk)
local HERO_POOLS = {
	Legendary = { "VoidAssassin", "EclipseHero", "BloodSage"    },
	Epic      = { "ShadowTwin",   "NeonBlitz"                    },
	Rare      = { "CrystalGuard", "ScarletArcher", "JadeSentinel" },
	Common    = { "StormDancer"                                   },
}

-- Компенсация за дубликат (монеты)
local DUPE_COMPENSATION = {
	Legendary = 800,
	Epic      = 400,
	Rare      = 150,
	Common    = 50,
}

-- ============================================================
-- ПИТИ-СЧЕТЧИКИ (в памяти; сбрасываются при выходе)
-- ============================================================

local pityCounters = {}  -- [userId] = { normal=N, epic=N }

local function getPity(userId)
	pityCounters[userId] = pityCounters[userId] or { normal = 0, epic = 0 }
	return pityCounters[userId]
end

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ
-- ============================================================

local function rollRarity(weights, forceLegendary)
	if forceLegendary then return "Legendary" end
	local total = 0
	for _, w in ipairs(weights) do total += w.weight end
	local roll, cum = math.random(1, total), 0
	for _, w in ipairs(weights) do
		cum += w.weight
		if roll <= cum then return w.rarity end
	end
	return "Common"
end

-- Выбираем героя: предпочитаем тех, которых нет; если все есть — дубликат
local function pickHero(rarity, unlockedHeroes)
	local pool   = HERO_POOLS[rarity] or HERO_POOLS.Rare
	local unowned = {}
	for _, hid in ipairs(pool) do
		if not table.find(unlockedHeroes, hid) then
			table.insert(unowned, hid)
		end
	end
	local src = (#unowned > 0) and unowned or pool
	return src[math.random(1, #src)]
end

-- ============================================================
-- ОБРАБОТЧИК RollGacha
-- ============================================================

rRollGacha.OnServerInvoke = function(player, chestType)
	chestType = (chestType == "epic") and "epic" or "normal"
	local cfg = CHEST_CONFIG[chestType]

	-- Защита от nil DataStore
	if not _G.DataStore then
		return { success = false, message = "Сервер не готов. Попробуйте позже." }
	end
	local pData = _G.DataStore.GetData(player.UserId)
	if not pData then
		return { success = false, message = "Данные не загружены. Повторите позже." }
	end

	-- Проверка баланса
	if pData.coins < cfg.cost then
		return {
			success = false,
			message = string.format("Недостаточно монет! Нужно %d, есть %d.", cfg.cost, pData.coins)
		}
	end

	-- Снимаем монеты
	_G.DataStore.AddPlayerRewards(player.UserId, 0, -cfg.cost)

	-- Пити + роскошь
	local pity = getPity(player.UserId)
	pity[chestType] += 1
	local forceLegendary = (pity[chestType] >= cfg.pity)
	local rarity = rollRarity(cfg.weights, forceLegendary)
	if forceLegendary then pity[chestType] = 0 end

	-- Выбираем героя
	local heroId = pickHero(rarity, pData.unlockedHeroes)
	local isDuplicate = table.find(pData.unlockedHeroes, heroId) ~= nil
	local compensation = 0

	if isDuplicate then
		-- Компенсация за дубликат
		compensation = DUPE_COMPENSATION[rarity] or 50
		_G.DataStore.AddPlayerRewards(player.UserId, 0, compensation)
	else
		-- Разблокируем героя
		_G.DataStore.UnlockHero(player.UserId, heroId)

		-- Legendary броадкаст: все в игре видят дроп!
		if rarity == "Legendary" then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player then
					pcall(function()
						rShowNotification:FireClient(p,
							string.format("✨ %s выбил LEGENDARY героя %s из Колодца!",
								player.Name, heroId), "legendary")
					end)
				end
			end
		end
	end

	-- Обновляем HUD монет
	local fresh = _G.DataStore.GetData(player.UserId)
	if fresh then
		pcall(function() rUpdateHUD:FireClient(player, { coins = fresh.coins }) end)
	end

	local result = {
		success      = true,
		isDuplicate  = isDuplicate,
		heroId       = heroId,
		rarity       = rarity,
		compensation = compensation,
		pityCount    = pity[chestType],
		pityMax      = cfg.pity,
	}

	-- Отправляем клиенту для анимации
	pcall(function() rWishingWellResult:FireClient(player, result) end)

	-- Триггерим VFX колодца (вихрь, лучи, стражи)
	if _G.WishingWellVFX and _G.WishingWellVFX.PlayDrop then
		pcall(_G.WishingWellVFX.PlayDrop, rarity)
	end

	print(string.format(
		"[WishingWell] %s | %s сундук → %s [%s] | дубл=%s | пити=%d/%d",
		player.Name, chestType, heroId, rarity,
		tostring(isDuplicate), pity[chestType], cfg.pity
	))

	return result
end

-- ============================================================
-- УБОРКА
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	pityCounters[player.UserId] = nil
end)

print("[WishingWellService] Initialized ✓")
