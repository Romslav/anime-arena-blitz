-- CombatSystem.server.lua | Anime Arena: Blitz
-- Боевая система: урон, смерть, скиллы Q/E/F/R, кулдауны, статусы, UltCharge
-- Использует SkillHandlers[heroId].GetHandler(heroId)[slot](player, targetPos, api)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local StatusEffects = require(script.Parent.StatusEffects)
local SkillHandlers = require(script.Parent.SkillHandlers)
local Characters    = require(ReplicatedStorage:WaitForChild("Characters"))

local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local rUseSkill         = Remotes:WaitForChild("UseSkill")
local rM1Attack         = Remotes:WaitForChild("M1Attack")
local rTakeDamage       = Remotes:WaitForChild("TakeDamage")
local rUpdateHP         = Remotes:WaitForChild("UpdateHP")
local rHeal             = Remotes:WaitForChild("Heal")
local rPlayerDied       = Remotes:WaitForChild("PlayerDied")
local rSkillResult      = Remotes:WaitForChild("SkillResult")
local rSkillUsed        = Remotes:WaitForChild("SkillUsed")
local rUltCharge        = Remotes:WaitForChild("UltCharge")
local rChargeUlt        = Remotes:WaitForChild("ChargeUlt")
local rUpdateEffect     = Remotes:WaitForChild("UpdateEffect")
local rUpdateHUD        = Remotes:WaitForChild("UpdateHUD")
local rUpdateSkillCDs   = Remotes:WaitForChild("UpdateSkillCooldowns")
local rStyleRankUp      = Remotes:FindFirstChild("StyleRankUp")

-- ============================================================
-- СОСТОЯНИЕ
-- ============================================================

-- matchState[userId] = {
--   hp, maxHp, heroId, alive, kills, deaths, damage,
--   matchId, mode, speed, ultCharge, lastM1,
--   styleScore, lastHitTime, styleRank  -- Stylish! система
-- }
local matchState = {}
local cooldowns  = {}  -- cooldowns[userId][slot] = lastUsedTick
local m1Combo    = {}  -- m1Combo[userId] = количество попаданий M1 в этом раунде (для пассивок)

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ
-- ============================================================

local function getModifiers()
	return _G.GameModeModifiers
end

local function getGameManager()
	return _G.GameManager
end

local function getRoundService()
	return _G.RoundService
end

local function fireHUD(player, data)
	local ok, err = pcall(function() rUpdateHUD:FireClient(player, data) end)
	if not ok then warn("[Combat] HUD fire error:", err) end
end

-- ============================================================
-- БОТ — утилиты
-- ============================================================

-- Бот: прокси-объект с _isBot=true вместо Player
local function isBot(p)
	return type(p) == "table" and p._isBot == true
end

local function isRealPlayer(p)
	return not isBot(p) and typeof(p) == "Instance" and p:IsA("Player")
end

--- Безопасно получить UserId для любого участника (бот или игрок)
--- @param p Player | BotProxy
--- @return number | nil
local function getUserId(p)
	if isBot(p) then
		return _G.TestBot and _G.TestBot.getUserId and _G.TestBot.getUserId() or nil
	end
	if isRealPlayer(p) then
		return p.UserId
	end
	return nil
end

-- ============================================================
-- УРОН / СМЕРТЬ
-- ============================================================

local function notifyDamage(attacker, victim, amount, dmgType)
	local victimId = getUserId(victim)
	if not victimId then return end
	local vState = matchState[victimId]
	if not vState then return end

	if isRealPlayer(victim) then
		rTakeDamage:FireClient(victim, vState.hp, vState.maxHp, amount, dmgType,
			attacker and getUserId(attacker) or 0)
		fireHUD(victim, { hp = vState.hp, maxHp = vState.maxHp })
	else
		-- Бот: синхронизируем hp через _G.TestBot
		if _G.TestBot and _G.TestBot.syncHp then
			_G.TestBot.syncHp(vState.hp, vState.maxHp)
		end
	end

	-- Hit-confirm: искры на экране атакующего в точке попадания
	-- (rTakeDamage летит жертве, атакующий без этого ничего не видит)
	if isRealPlayer(attacker) then
		local victimChar = isBot(victim)
			and (_G.TestBot and _G.TestBot.getModel and _G.TestBot.getModel())
			or (isRealPlayer(victim) and victim.Character)
		local victimHRP = victimChar and victimChar:FindFirstChild("HumanoidRootPart")
		if victimHRP then
			pcall(function()
				rUpdateEffect:FireClient(attacker, "hit_spark", victimHRP.Position, dmgType)
			end)
		end
	end

	-- Ульта-заряд атакующему (только реальным)
	if isRealPlayer(attacker) then
		local aState = matchState[attacker.UserId]
		if aState then
			local mods = getModifiers()
			local chargeRate = 1
			if mods and mods.GetUltChargeRate and attacker.Character then
				local ok, r = pcall(mods.GetUltChargeRate, attacker.Character)
				if ok then chargeRate = r end
			end
			local baseGain = dmgType == "Ultimate" and 8 or 3
			aState.ultCharge = math.min(100, aState.ultCharge + baseGain * chargeRate)
			rUltCharge:FireClient(attacker, aState.ultCharge)
			rChargeUlt:FireClient(attacker, aState.ultCharge)
			fireHUD(attacker, { ultCharge = aState.ultCharge })
		end
	end
end

local function dealDamage(attacker, victim, amount, dmgType)
	if not attacker or not victim then return end

	-- FIX #1: безопасно получаем UserId для бота и игрока
	local victimId   = getUserId(victim)
	local attackerId = getUserId(attacker)
	if not victimId then
		warn("[Combat] dealDamage: victim has no UserId", tostring(victim))
		return
	end

	local vState = matchState[victimId]
	if not vState or not vState.alive then return end

	dmgType = dmgType or "Normal"
	local final = amount

	-- 1. Щит из StatusEffects
	final = StatusEffects.ProcessDamageWithShield(victimId, final)
	if final <= 0 then return end

	-- 2. Мультипликатор атакующего + дебаф цели
	if attackerId then
		final = final * StatusEffects.GetDamageMultiplier(attackerId)
	end
	final = final * (StatusEffects.GetDebuffMultiplier
		and StatusEffects.GetDebuffMultiplier(victimId) or 1)

	-- 3. GameModeModifiers
	local Mods = getModifiers()
	if Mods and isRealPlayer(attacker) and attacker.Character then
		local ok, mult = pcall(Mods.GetDamageMultiplier, attacker.Character)
		if ok then final = final * mult end
	end

	final = math.floor(final)
	if final <= 0 then return end

	-- 4. Применяем урон
	if attackerId then
		local aState = matchState[attackerId]
		if aState then aState.damage = aState.damage + final end
	end
	vState.hp = math.max(0, vState.hp - final)

	-- Трекинг для Mastery XP: damageTaken + minHpRatio жертвы
	vState.damageTaken = (vState.damageTaken or 0) + final
	if vState.maxHp > 0 then
		local ratio = vState.hp / vState.maxHp
		if ratio < (vState.minHpRatio or 1.0) then
			vState.minHpRatio = ratio
		end
	end

	-- ============================================================
	-- STYLISH! — ранг стиля атакующего
	-- ============================================================
	if isRealPlayer(attacker) and rStyleRankUp then
		local aState = matchState[attacker.UserId]
		if aState then
			local now = tick()
			local gap = now - (aState.lastHitTime or 0)
			-- Комбо < 2.5с: очки накапливаются; долгий перерыв: частично сгорают
			if gap < 2.5 then
				aState.styleScore = (aState.styleScore or 0) + final
			else
				aState.styleScore = math.max(0, (aState.styleScore or 0) * 0.4 + final)
			end
			aState.lastHitTime = now

			local s = aState.styleScore
			local rank = s > 500 and "SSS"
				       or s > 350 and "SS"
				       or s > 200 and "S"
				       or s > 100 and "A"
				       or s > 50  and "B"
				       or s > 20  and "C" or "D"

			-- Отправляем только при смене ранга (экономия трафика)
			if rank ~= (aState.styleRank or "D") then
				aState.styleRank = rank
				pcall(function()
					rStyleRankUp:FireClient(attacker, rank, math.floor(s))
				end)
			end
		end
	end

	-- Сброс стиля жертвы (получила урон)
	if isRealPlayer(victim) and rStyleRankUp then
		local vStyleState = matchState[victim.UserId]
		if vStyleState and (vStyleState.styleRank or "D") ~= "D" then
			vStyleState.styleScore = 0
			vStyleState.styleRank  = "D"
			pcall(function()
				rStyleRankUp:FireClient(victim, "D", 0)
			end)
		end
	end

	notifyDamage(attacker, victim, final, dmgType)

	-- HitStop: замираем на 80мс — удары ощущаются тяжёлыми
	if isRealPlayer(victim) and victim.Character then
		local hum = victim.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			local origSpeed = hum.WalkSpeed
			hum.WalkSpeed = 0
			task.delay(0.08, function()
				if hum and hum.Parent then hum.WalkSpeed = origSpeed end
			end)
		end
	elseif isBot(victim) then
		local botModel = _G.TestBot and _G.TestBot.getModel and _G.TestBot.getModel()
		local hum = botModel and botModel:FindFirstChildOfClass("Humanoid")
		if hum then
			local origSpeed = hum.WalkSpeed
			hum.WalkSpeed = 0
			task.delay(0.08, function()
				if hum and hum.Parent then hum.WalkSpeed = origSpeed end
			end)
		end
	end

	-- 5. Смерть
	if vState.hp <= 0 then
		vState.alive  = false
		vState.deaths = vState.deaths + 1
		if attackerId then
			local aState = matchState[attackerId]
			if aState then
				aState.kills = aState.kills + 1
				-- Action flags: ult_finisher / ability_kill
				if aState.actionFlags then
					if dmgType == "Ultimate" then
						aState.actionFlags.ult_finisher = true
					elseif dmgType ~= "Normal" and dmgType ~= "DoT" then
						aState.actionFlags.ability_kill = true
					end
				end
			end
		end

		-- FIX #2: правильно определяем время респавна из режима матча
		local respawnTime = 5
		local mods2 = getModifiers()
		if mods2 and mods2.GetRespawnTime then
			local matchMode = vState.mode or "Normal"
			local ok, t = pcall(mods2.GetRespawnTime, matchMode)
			if ok and type(t) == "number" then respawnTime = t end
		end

		if isBot(victim) then
			if _G.TestBot and _G.TestBot.onDeath then
				_G.TestBot.onDeath(attacker)
			end
		else
			rPlayerDied:FireAllClients(victimId,
				attackerId or 0, respawnTime)
		end

		StatusEffects.ClearPlayer(victimId)

		local gm = getGameManager()
		if gm and gm.OnKill then
			pcall(gm.OnKill, attackerId, victimId, vState.matchId)
		end
		local rs = getRoundService()
		if rs and rs.OnKill then
			pcall(rs.OnKill, attackerId, victimId, vState.matchId)
		end
	end
end

-- ============================================================
-- ИСЦЕЛЕНИЕ
-- ============================================================

local function healPlayer(player, amount)
	local uid = getUserId(player)
	if not uid then return end
	local state = matchState[uid]
	if not state or not state.alive then return end
	local healed = math.min(amount, state.maxHp - state.hp)
	if healed <= 0 then return end
	state.hp = state.hp + healed
	if isRealPlayer(player) then
		rHeal:FireClient(player, healed)
		rUpdateHP:FireClient(player, state.hp, state.maxHp)
		fireHUD(player, { hp = state.hp, maxHp = state.maxHp })
	end
end

-- ============================================================
-- M1 БАЗОВАЯ АТАКА
-- ============================================================

local M1_COOLDOWN = 0.55
local M1_RANGE    = 8
local M1_DAMAGE   = 8

-- Все участники матча (включая бота), исключая excludeUserId
local function getMatchParticipants(excludeUserId, matchId)
	local result = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == excludeUserId then continue end
		local s = matchState[p.UserId]
		if s and s.alive and s.matchId == matchId then
			table.insert(result, p)
		end
	end
	if _G.TestBot then
		local botId = _G.TestBot.getUserId and _G.TestBot.getUserId() or nil
		if botId and botId ~= excludeUserId then
			local s = matchState[botId]
			if s and s.alive and s.matchId == matchId then
				local proxy = _G.TestBot.getProxy and _G.TestBot.getProxy()
				if proxy then table.insert(result, proxy) end
			end
		end
	end
	return result
end

rM1Attack.OnServerEvent:Connect(function(player, mousePos)
	local state = matchState[player.UserId]
	if not state or not state.alive then return end
	if StatusEffects.IsStunned(player.UserId) then return end

	local now = tick()
	if now - (state.lastM1 or 0) < M1_COOLDOWN then return end
	state.lastM1 = now

	local char = player.Character
	if not char then return end
	local origin = char.HumanoidRootPart.Position
	local dmg = state.m1Damage or M1_DAMAGE

	for _, p in ipairs(getMatchParticipants(player.UserId, state.matchId)) do
		if not p then continue end
		local pHRP
		if isBot(p) then
			local m = _G.TestBot.getModel and _G.TestBot.getModel()
			pHRP = m and m:FindFirstChild("HumanoidRootPart")
		else
			local pChar = p.Character
			pHRP = pChar and pChar:FindFirstChild("HumanoidRootPart")
		end
		if pHRP and (pHRP.Position - origin).Magnitude <= M1_RANGE then
			dealDamage(player, p, dmg, "Normal")

			local victimId = getUserId(p)

			-- FIX-5: JadeSentinel passive — jadeHits накапливаются на цели (макс 3)
			if state.heroId == "JadeSentinel" then
				local vs = victimId and matchState[victimId]
				if vs then vs.jadeHits = math.min((vs.jadeHits or 0) + 1, 3) end
			end

			-- M1 пассивки героев:
			-- FlameRonin  — каждый 5-й M1 (финишер комбо) поджигает цель
			-- ThunderMonk — каждый 3-й M1 накладывает мини-стан
			-- NeonBlitz   — каждый 4-й M1 стреляет неон-пульс (+8 урона)
			-- BloodSage   — каждый M1 высасывает 5 HP (пассивное лечение)
			local heroId = state.heroId
			m1Combo[player.UserId] = (m1Combo[player.UserId] or 0) + 1
			local combo = m1Combo[player.UserId]

			-- Full combo (5+ ударов подряд) → флаг для Mastery XP
			if combo % 5 == 0 then
				local aflags = state.actionFlags
				if aflags then aflags.performed_full_combo = true end
			end

			if heroId == "FlameRonin" and combo % 5 == 0 then
				if victimId then StatusEffects.ApplyBurn(victimId, 3, 2) end

			elseif heroId == "ThunderMonk" and combo % 3 == 0 then
				if victimId then StatusEffects.ApplyStun(victimId, 0.35) end

			elseif heroId == "NeonBlitz" and combo % 4 == 0 then
				dealDamage(player, p, 8, "Normal")   -- неон-пульс

			elseif heroId == "BloodSage" then
				healPlayer(player, 5)                -- дрейн 5 HP
			end
		end
	end
end)

-- ============================================================
-- СКИЛЛЫ Q / E / F / R
-- ============================================================

local SLOT_CD_DEFAULT = { Q = 8, E = 12, F = 16, R = 30 }

local function getSkillCooldown(heroId, slot)
	local data = Characters[heroId]
	if not data then return SLOT_CD_DEFAULT[slot] or 10 end
	local idx = slot == "Q" and 1 or slot == "E" and 2 or slot == "F" and 3 or nil
	if idx and data.skills and data.skills[idx] then
		return data.skills[idx].cooldown or SLOT_CD_DEFAULT[slot]
	end
	if slot == "R" and data.ultimate then
		return data.ultimate.cooldown or 30
	end
	return SLOT_CD_DEFAULT[slot] or 10
end

--- Вернуть таблицу финальных кулдаунов с учётом режима для отправки на HUD
local function buildSkillCooldownTable(heroId, character)
	local Mods = getModifiers()
	local cdMult = 1
	if Mods and Mods.GetCooldownMultiplier and character then
		local ok, m = pcall(Mods.GetCooldownMultiplier, character)
		if ok then cdMult = m end
	end
	return {
		Q = getSkillCooldown(heroId, "Q") * cdMult,
		E = getSkillCooldown(heroId, "E") * cdMult,
		F = getSkillCooldown(heroId, "F") * cdMult,
		R = getSkillCooldown(heroId, "R") * cdMult,
	}
end

rUseSkill.OnServerEvent:Connect(function(player, slot, targetPos)
	local state = matchState[player.UserId]
	if not state or not state.alive then
		rSkillResult:FireClient(player, slot, false, 0, "dead")
		return
	end

	if StatusEffects.IsStunned(player.UserId) then
		rSkillResult:FireClient(player, slot, false, 0, "stunned")
		return
	end

	if slot == "R" and state.ultCharge < 100 then
		rSkillResult:FireClient(player, slot, false, 0, "ult_not_ready")
		return
	end

	local cdTable  = cooldowns[player.UserId] or {}
	local lastUsed = cdTable[slot] or 0

	-- Используем модифицированные кулдауны (с учётом Awakening Tree), если есть
	local finalCd
	if state.modifiedCooldowns and state.modifiedCooldowns[slot] then
		finalCd = state.modifiedCooldowns[slot]
	else
		local baseCd = getSkillCooldown(state.heroId, slot)
		finalCd = baseCd
		local Mods = getModifiers()
		if Mods and Mods.GetCooldownMultiplier and player.Character then
			local ok, mult = pcall(Mods.GetCooldownMultiplier, player.Character)
			if ok then finalCd = finalCd * mult end
		end
	end

	local elapsed = tick() - lastUsed
	if elapsed < finalCd then
		rSkillResult:FireClient(player, slot, false, finalCd - elapsed, "cooldown")
		return
	end

	cdTable[slot] = tick()
	cooldowns[player.UserId] = cdTable

	if slot == "R" then
		state.ultCharge = 0
		rUltCharge:FireClient(player, 0)
		rChargeUlt:FireClient(player, 0)
		fireHUD(player, { ultCharge = 0 })
	end

	rSkillUsed:FireAllClients(player.UserId, slot, state.heroId, targetPos)

	local api = {
		dealDamage = dealDamage,
		heal       = healPlayer,
		getState   = function(uid) return matchState[uid] end,
		fireTo     = function(p, remote, ...) remote:FireClient(p, ...) end,
	}

	local handler = SkillHandlers.GetHandler(state.heroId)
	if handler and handler[slot] then
		local ok2, err = pcall(handler[slot], player, targetPos, api)
		if not ok2 then
			warn(string.format("[Combat] Skill %s.%s error: %s",
				state.heroId, slot, tostring(err)))
		end
	end

	rSkillResult:FireClient(player, slot, true, finalCd, "ok")
end)

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ / СБРОС
-- ============================================================

local CombatSystem = {}
_G.CombatSystem = CombatSystem

--- Инициализирует боевое состояние игрока и разсылает HUD + UpdateSkillCooldowns
--- @param player    Player
--- @param heroData  table   — данные из Characters.lua
--- @param matchId   string  — идентификатор раунда
--- @param mode      string  — "Normal" | "OneHit" | "Ranked"
function CombatSystem.initPlayer(player, heroData, matchId, mode)
	local maxHp = heroData and heroData.hp or 100
	mode = mode or "Normal"
	local heroId = heroData and heroData.id or "FlameRonin"

	-- Awakening Tree: применяем stat-эффекты (HP, m1Damage, speed и т.д.)
	local awakeningEffects = {}
	local awakeningPassives = {}
	local ATS = _G.AwakeningTreeService
	if ATS and isRealPlayer(player) then
		local ok2, eff = pcall(ATS.GetActiveEffects, player.UserId, heroId)
		if ok2 and eff then
			awakeningEffects = eff
			-- Применяем stat-эффекты к копии heroData чтобы не мутировать оригинал
			local modifiedData = {}
			if heroData then
				for k, v in pairs(heroData) do modifiedData[k] = v end
			end
			ATS.ApplyStatEffects(modifiedData, awakeningEffects)
			maxHp = modifiedData.hp or maxHp
			heroData = modifiedData
			-- Собираем пассивки для быстрого доступа в бою
			awakeningPassives = ATS.CollectPassives(awakeningEffects)
		end
	end

	local Mods = getModifiers()
	if Mods and Mods.ModifyHP then
		local ok, newHp = pcall(Mods.ModifyHP, mode, maxHp)
		if ok and type(newHp) == "number" then maxHp = newHp end
	end

	matchState[player.UserId] = {
		hp         = maxHp,
		maxHp      = maxHp,
		heroId     = heroId,
		alive      = true,
		kills      = 0,
		deaths     = 0,
		damage     = 0,
		matchId    = matchId or "default",
		mode       = mode,
		speed      = heroData and heroData.speed or 16,
		ultCharge  = 0,
		lastM1     = 0,
		-- Stylish!
		styleScore  = 0,
		lastHitTime = 0,
		styleRank   = "D",
		-- Action tracking (для расчёта Mastery XP в RoundService)
		damageTaken        = 0,
		minHpRatio         = 1.0,
		actionFlags = {
			performed_full_combo  = false,
			perfect_parry         = false,
			ability_kill          = false,
			no_damage_taken_round = false,
			ult_finisher          = false,
			comeback_win          = false,
		},
		-- Awakening Tree
		awakeningEffects  = awakeningEffects,
		awakeningPassives = awakeningPassives,
		m1Damage          = heroData and heroData.m1Damage or M1_DAMAGE,
	}
	cooldowns[player.UserId] = {}
	StatusEffects.ClearPlayer(player.UserId)

	-- Первоначальный HUD
	fireHUD(player, { hp = maxHp, maxHp = maxHp, ultCharge = 0 })

	-- Awakening Tree: применяем cooldown-эффекты поверх базовых кулдаунов героя
	local cdTable = buildSkillCooldownTable(heroId, player.Character)
	if ATS and #awakeningEffects > 0 then
		cdTable = ATS.ApplyCooldownEffects(cdTable, awakeningEffects)
	end
	-- Сохраняем финальные кулдауны в matchState для использования в skill handler
	matchState[player.UserId].modifiedCooldowns = cdTable
	local ok, err = pcall(function()
		rUpdateSkillCDs:FireClient(player, cdTable)
	end)
	if not ok then warn("[Combat] UpdateSkillCooldowns fire error:", err) end
end

-- FIX-6: revivePlayer был объявлен 5 раз подряд — удаляем дубликаты, оставляем 1
function CombatSystem.revivePlayer(userId)
	return CombatSystem.resetPlayer(userId)
end

function CombatSystem.resetPlayer(userId)
	local state = matchState[userId]
	if not state then return end
	state.alive      = true
	state.hp         = state.maxHp
	state.ultCharge  = 0
	state.jadeHits   = 0    -- сброс пассивки JadeSentinel при респавне
	m1Combo[userId]  = 0    -- сброс M1-комбо при респавне
	state.styleScore  = 0   -- сброс Stylish! при респавне
	state.lastHitTime = 0
	state.styleRank   = "D"
	-- НЕ сбрасываем actionFlags, damageTaken, minHpRatio — они за весь матч
	StatusEffects.ClearPlayer(userId)
	cooldowns[userId] = {}
	local p = Players:GetPlayerByUserId(userId)
	if p then
		fireHUD(p, { hp = state.maxHp, maxHp = state.maxHp, ultCharge = 0 })
		local cdTable = buildSkillCooldownTable(state.heroId, p.Character)
		pcall(function() rUpdateSkillCDs:FireClient(p, cdTable) end)
	end
end

function CombatSystem.getState(userId)
	return matchState[userId]
end

--- Применить урон DoT от сервера (жертва = "сама себя")
function CombatSystem.dealDamageToPlayer(userId, amount, reason)
	local victim = Players:GetPlayerByUserId(userId)
	if not victim then return end
	dealDamage(victim, victim, amount, reason or "DoT")
end

-- BUG-2 FIX: TestBot.server.lua вызывает _G.CombatSystem.applyDamage(att, vic, amount, dmgType).
-- dealDamage — локальная функция, снаружи недоступна.
-- Экспортируем её как публичный метод CombatSystem.
CombatSystem.applyDamage = dealDamage

--- Записать выполненное действие в бою (для внешних систем: скилл-хендлеры, парри)
--- actionKey: "perfect_parry" | "ability_kill" | "ult_finisher" | "performed_full_combo" | ...
function CombatSystem.RecordAction(userId, actionKey)
	local state = matchState[userId]
	if not state or not state.actionFlags then return end
	state.actionFlags[actionKey] = true
end

--- Получить итоговые флаги действий и статистику для расчёта Mastery XP
--- Вычисляет comeback_win и no_damage_taken_round здесь (зависят от финального HP)
function CombatSystem.GetMatchActions(userId, isWinner)
	local state = matchState[userId]
	if not state then return {} end

	local flags = {}
	if state.actionFlags then
		for k, v in pairs(state.actionFlags) do
			flags[k] = v
		end
	end

	-- Финальные вычисляемые флаги
	flags.no_damage_taken_round = (state.damageTaken or 0) == 0
	flags.comeback_win = isWinner and (state.minHpRatio or 1.0) < 0.2

	return flags
end

-- ============================================================
-- УБОРКА
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	matchState[player.UserId] = nil
	cooldowns[player.UserId]  = nil
	m1Combo[player.UserId]    = nil
	StatusEffects.ClearPlayer(player.UserId)
end)

-- ============================================================
-- МАСТЕРСТВО за стиль по итогам матча
-- ============================================================

-- AwardStyleMastery оставлен для обратной совместимости.
-- Полный расчёт Mastery XP теперь делает RoundService через CalcMasteryXP.
function CombatSystem.AwardStyleMastery(userId)
	-- no-op: логика перенесена в RoundService.runConclusion
end

print("[CombatSystem] Initialized ✓")
