-- AwakeningTreeService.server.lua | Anime Arena: Blitz
-- Серверная логика Awakening Tree:
--   • BuyNode — купить узел за Mastery Shards (валидация веток и уровня)
--   • ResetTree — сброс всех узлов (200 Shards + 50% возврат)
--   • PrestigeHero — Prestige (сброс mastery до 0, 50% shards, +1 prestige)
--   • GetTree — отправить клиенту текущее дерево героя
--   • ApplyEffects — применить эффекты при входе в бой
--   • _G.AwakeningTreeService — публичный API

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AwakeningTree = require(ReplicatedStorage:WaitForChild("AwakeningTree"))

local Remotes               = ReplicatedStorage:WaitForChild("Remotes")
local rBuyNode              = Remotes:WaitForChild("BuyAwakeningNode",     10)
local rResetTree            = Remotes:WaitForChild("ResetAwakeningTree",   10)
local rPrestige             = Remotes:WaitForChild("PrestigeHero",         10)
local rGetTree              = Remotes:WaitForChild("GetAwakeningTree",     10)
local rNodeUnlocked         = Remotes:WaitForChild("AwakeningNodeUnlocked",10)
local rShowNotif            = Remotes:WaitForChild("ShowNotification",     10)
local rMasteryShards        = Remotes:WaitForChild("MasteryShardUpdate",   10)

-- ============================================================
-- HELPERS
-- ============================================================

local function getDS()
	return _G.DataStore
end

local function getHeroData(userId, heroId)
	local ds = getDS()
	if not ds then return nil end
	local data = ds.GetData(userId)
	if not data then return nil end
	if not data.heroes or not data.heroes[heroId] then return nil end
	return data.heroes[heroId]
end

local function notifyShards(player, heroId, hero)
	if not player or not player.Parent then return end
	pcall(function()
		rMasteryShards:FireClient(player, heroId, hero.masteryShards, 0)
	end)
end

-- ============================================================
-- PUBLIC API
-- ============================================================

local Service = {}
_G.AwakeningTreeService = Service

--- Покупка узла. Возвращает success, error.
function Service.BuyNode(userId, heroId, nodeId)
	local ds = getDS()
	if not ds then return false, "no_datastore" end

	local data = ds.GetData(userId)
	if not data then return false, "no_data" end

	local hero = data.heroes and data.heroes[heroId]
	if not hero then return false, "hero_locked" end

	-- Находим узел в определениях
	local heroDef = AwakeningTree.Heroes[heroId]
	if not heroDef then return false, "unknown_hero" end

	local nodeDef = nil
	for _, n in ipairs(heroDef) do
		if n.id == nodeId then nodeDef = n; break end
	end
	if not nodeDef then return false, "unknown_node" end

	-- Уже куплен?
	if hero.awakeningNodes and hero.awakeningNodes[nodeId] then
		return false, "already_owned"
	end

	-- Валидация правил комбинирования веток
	local ownedNodes = hero.awakeningNodes or {}
	local ok, reason = AwakeningTree.CanBuyNode(heroId, nodeId, ownedNodes, hero.masteryLevel or 0)
	if not ok then return false, reason end

	-- Проверка шардов
	if (hero.masteryShards or 0) < nodeDef.cost then
		return false, string.format("need_%d_shards", nodeDef.cost)
	end

	-- Покупка!
	hero.masteryShards = hero.masteryShards - nodeDef.cost
	if not hero.awakeningNodes then hero.awakeningNodes = {} end
	hero.awakeningNodes[nodeId] = true

	-- Сохранение
	data._saveQueue = true -- Маркер для DataStore
	-- Прямой доступ к saveQueue через пометку данных
	local playerObj = Players:GetPlayerByUserId(userId)
	if ds.SetField then
		-- Явно помечаем для сохранения
		ds.SetField(userId, "heroes", data.heroes)
	end

	-- Уведомления
	if playerObj then
		pcall(function()
			rNodeUnlocked:FireClient(playerObj, heroId, nodeId, nodeDef.name, nodeDef.desc)
		end)
		pcall(function()
			rShowNotif:FireClient(playerObj,
				string.format("🌸 %s: %s", heroId, nodeDef.name), "mastery_up")
		end)
		notifyShards(playerObj, heroId, hero)
	end

	print(string.format("[AwakeningTree] %d bought %s.%s (-%d shards)",
		userId, heroId, nodeId, nodeDef.cost))

	return true, "ok"
end

--- Сброс дерева. Стоит 200 Shards, возвращает 50% вложенных.
function Service.ResetTree(userId, heroId)
	local ds = getDS()
	if not ds then return false, "no_datastore" end

	local data = ds.GetData(userId)
	if not data then return false, "no_data" end

	local hero = data.heroes and data.heroes[heroId]
	if not hero then return false, "hero_locked" end

	local ownedNodes = hero.awakeningNodes or {}
	-- Есть ли что сбрасывать?
	local nodeCount = 0
	for _ in pairs(ownedNodes) do nodeCount += 1 end
	if nodeCount == 0 then return false, "tree_empty" end

	local RESET_COST = AwakeningTree.GetResetCost()
	if (hero.masteryShards or 0) < RESET_COST then
		return false, string.format("need_%d_shards", RESET_COST)
	end

	local refund = AwakeningTree.CalcResetRefund(heroId, ownedNodes)

	hero.masteryShards  = hero.masteryShards - RESET_COST + refund
	hero.awakeningNodes = {}
	hero.passiveSlots   = {}

	if ds.SetField then
		ds.SetField(userId, "heroes", data.heroes)
	end

	local playerObj = Players:GetPlayerByUserId(userId)
	if playerObj then
		pcall(function()
			rShowNotif:FireClient(playerObj,
				string.format("🔄 %s: Дерево сброшено! +%d шардов возврат", heroId, refund), "mastery")
		end)
		notifyShards(playerObj, heroId, hero)
	end

	print(string.format("[AwakeningTree] %d reset %s tree (-%d cost, +%d refund)",
		userId, heroId, RESET_COST, refund))

	return true, refund
end

--- Prestige героя. Требует Mastery Level 10.
function Service.PrestigeHero(userId, heroId)
	local ds = getDS()
	if not ds then return false, "no_datastore" end

	local data = ds.GetData(userId)
	if not data then return false, "no_data" end

	local hero = data.heroes and data.heroes[heroId]
	if not hero then return false, "hero_locked" end

	if (hero.masteryLevel or 0) < 10 then
		return false, "need_mastery_10"
	end

	local maxPrestige = 5
	if (hero.prestigeCount or 0) >= maxPrestige then
		return false, "max_prestige_reached"
	end

	-- Подсчитать 50% шардов из дерева
	local ownedNodes = hero.awakeningNodes or {}
	local refund = AwakeningTree.CalcResetRefund(heroId, ownedNodes)

	-- Сброс
	hero.masteryXP      = 0
	hero.masteryLevel   = 0
	hero.masteryShards  = math.floor((hero.masteryShards or 0) * 0.5) + refund
	hero.awakeningNodes = {}
	hero.passiveSlots   = {}
	hero.prestigeCount  = (hero.prestigeCount or 0) + 1
	-- unlockedFX не сбрасываются

	-- P5: перманентный пассив (записываем отдельно)
	if hero.prestigeCount == 5 then
		local p5 = AwakeningTree.Prestige5[heroId]
		if p5 then
			if not hero.unlockedFX then hero.unlockedFX = {} end
			hero.unlockedFX["prestige_5_passive"] = true
		end
	end

	if ds.SetField then
		ds.SetField(userId, "heroes", data.heroes)
	end

	local playerObj = Players:GetPlayerByUserId(userId)
	if playerObj then
		local pc = hero.prestigeCount
		pcall(function()
			rShowNotif:FireClient(playerObj,
				string.format("🏆 %s Prestige %d! Дерево сброшено, начинай путь заново", heroId, pc),
				"legendary")
		end)
		notifyShards(playerObj, heroId, hero)
	end

	print(string.format("[AwakeningTree] %d prestige %s → P%d",
		userId, heroId, hero.prestigeCount))

	return true, hero.prestigeCount
end

--- Собирает все активные эффекты для применения в бою.
--- Вызывается из CombatSystem.initPlayer или RoundService.
--- @return table — массив эффектов {type, stat, op, value, ...}
function Service.GetActiveEffects(userId, heroId)
	local ds = getDS()
	if not ds then return {} end

	local data = ds.GetData(userId)
	if not data then return {} end

	local hero = data.heroes and data.heroes[heroId]
	if not hero then return {} end

	local ownedNodes = hero.awakeningNodes or {}
	local effects = AwakeningTree.CollectEffects(heroId, ownedNodes)

	-- P5 перманентный пассив
	if (hero.prestigeCount or 0) >= 5 then
		local p5 = AwakeningTree.Prestige5[heroId]
		if p5 then
			table.insert(effects, { type = "passive", key = p5.key, params = { prestige5 = true } })
		end
	end

	-- Prestige бонусы (P1–P4)
	local pc = hero.prestigeCount or 0
	if pc >= 1 then
		-- P1: +1 passive slot
		table.insert(effects, { type = "passive", key = "prestige_passive_slot_3" })
	end
	-- P2–P4: косметические, не боевые

	return effects
end

--- Применяет stat-эффекты к таблице heroData перед боем.
--- Модифицирует heroData in-place (hp, m1Damage, speed и т.д.)
function Service.ApplyStatEffects(heroData, effects)
	if not heroData or not effects then return heroData end

	for _, eff in ipairs(effects) do
		if eff.type == "stat" then
			local stat = eff.stat
			local val  = heroData[stat]
			if val ~= nil then
				if eff.op == "add" then
					heroData[stat] = val + eff.value
				elseif eff.op == "mult" then
					heroData[stat] = val * eff.value
				end
			end
		end
	end

	-- Округляем HP
	if heroData.hp then
		heroData.hp = math.floor(heroData.hp)
	end

	return heroData
end

--- Применяет cooldown-эффекты. Возвращает модифицированную таблицу кулдаунов.
--- @param baseCooldowns table — { Q=8, E=12, F=16, R=30 }
--- @param effects table
function Service.ApplyCooldownEffects(baseCooldowns, effects)
	if not baseCooldowns or not effects then return baseCooldowns end

	local cds = {}
	for k, v in pairs(baseCooldowns) do cds[k] = v end

	for _, eff in ipairs(effects) do
		if eff.type == "cooldown" and eff.skill and cds[eff.skill] then
			if eff.op == "add" then
				cds[eff.skill] = math.max(0.5, cds[eff.skill] + eff.value)
			elseif eff.op == "mult" then
				cds[eff.skill] = math.max(0.5, cds[eff.skill] * eff.value)
			end
		end
	end

	return cds
end

--- Собирает все passive-ключи для быстрого поиска в бою.
--- @return table — { ["phoenix_rebirth"] = {params...}, ... }
function Service.CollectPassives(effects)
	local passives = {}
	for _, eff in ipairs(effects) do
		if eff.type == "passive" then
			passives[eff.key] = eff.params or {}
		end
	end
	return passives
end

-- ============================================================
-- REMOTES
-- ============================================================

-- BuyAwakeningNode: client → server
if rBuyNode then
	rBuyNode.OnServerEvent:Connect(function(player, heroId, nodeId)
		if type(heroId) ~= "string" or type(nodeId) ~= "string" then return end
		local ok, reason = Service.BuyNode(player.UserId, heroId, nodeId)
		if not ok then
			pcall(function()
				rShowNotif:FireClient(player,
					"⚠️ Не удалось купить узел: " .. tostring(reason), "default")
			end)
		end
	end)
end

-- ResetAwakeningTree: client → server
if rResetTree then
	rResetTree.OnServerEvent:Connect(function(player, heroId)
		if type(heroId) ~= "string" then return end
		local ok, reason = Service.ResetTree(player.UserId, heroId)
		if not ok then
			pcall(function()
				rShowNotif:FireClient(player,
					"⚠️ Не удалось сбросить дерево: " .. tostring(reason), "default")
			end)
		end
	end)
end

-- PrestigeHero: client → server
if rPrestige then
	rPrestige.OnServerEvent:Connect(function(player, heroId)
		if type(heroId) ~= "string" then return end
		local ok, reason = Service.PrestigeHero(player.UserId, heroId)
		if not ok then
			pcall(function()
				rShowNotif:FireClient(player,
					"⚠️ Prestige: " .. tostring(reason), "default")
			end)
		end
	end)
end

-- GetAwakeningTree: client → server (RemoteFunction)
if rGetTree then
	rGetTree.OnServerInvoke = function(player, heroId)
		if type(heroId) ~= "string" then return nil end

		local ds = getDS()
		if not ds then return nil end
		local data = ds.GetData(player.UserId)
		if not data then return nil end

		local hero = data.heroes and data.heroes[heroId]
		if not hero then return { nodes = {}, shards = 0, level = 0, prestige = 0 } end

		return {
			nodes    = hero.awakeningNodes or {},
			shards   = hero.masteryShards  or 0,
			level    = hero.masteryLevel   or 0,
			prestige = hero.prestigeCount  or 0,
		}
	end
end

print("[AwakeningTreeService] Initialized ✓ — 12 heroes, buy/reset/prestige/effects")
