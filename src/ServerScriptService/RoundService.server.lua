-- RoundService.server.lua | Anime Arena: Blitz Mode
-- Production round phase manager: Waiting → Preparation → Battle → Conclusion
-- Integrates with GameManager, CombatSystem, GameModeModifiers, MatchmakingService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundStart       = Remotes:WaitForChild("RoundStart")
local RoundEnd         = Remotes:WaitForChild("RoundEnd")
local RoundTimer       = Remotes:WaitForChild("RoundTimer")
local RoundStateChanged= Remotes:WaitForChild("RoundStateChanged")  -- FIX: загружаем заранее
local UpdateHUD        = Remotes:WaitForChild("UpdateHUD")
local ShowKillFeed     = Remotes:WaitForChild("ShowKillFeed")
local MatchFound       = Remotes:WaitForChild("MatchFound")
local ShowNotification = Remotes:WaitForChild("ShowNotification")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- ============================================================
-- CONSTANTS
-- ============================================================

local PHASE = {
	WAITING     = "Waiting",
	PREPARATION = "Preparation",
	BATTLE      = "Battle",
	CONCLUSION  = "Conclusion",
}

local PHASE_DURATIONS = {
	Waiting     = 0,   -- dynamic, until players ready
	Preparation = 10,  -- 10s countdown before battle
	Battle      = Config.ROUND_DURATION and Config.ROUND_DURATION["Normal"] or 180,
	Conclusion  = 7,   -- 7s results screen
}

local COUNTDOWN_NOTIFICATIONS = { 10, 5, 3, 2, 1 }

-- ============================================================
-- STATE
-- ============================================================

local RoundService = {}
_G.RoundService = RoundService

-- Active rounds: { [roundId] = roundData }
local activeRounds = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function getGameManager()
	return _G.GameManager
end

local function getCombatSystem()
	return _G.CombatSystem
end

local function getGameModeModifiers()
	return _G.GameModeModifiers
end

local function getCharacterService()
	return _G.CharacterService
end

-- Получить имя участника (работает и для бота)
local function getParticipantName(p)
	if type(p) == "table" and p._isBot then return p.Name end
	return p.Name
end

-- Файр только настоящим игрокам (бот пропускает)
local function fireAllPlayers(remote, round, ...)
	for _, p in ipairs(round.players) do
		local isBot = type(p) == "table" and p._isBot
		if not isBot and p and p.Parent then
			remote:FireClient(p, ...)
		end
	end
end

-- Подсчитываем живых участников (бот тоже считается)
local function countAlivePlayers(round)
	local Combat = getCombatSystem()
	local alive = {}
	for _, p in ipairs(round.players) do
		local isBot = type(p) == "table" and p._isBot
		if isBot then
			-- Бот: спрашиваем через _G.TestBot
			if _G.TestBot and _G.TestBot.isAlive() then
				table.insert(alive, p)
			end
		elseif p and p.Parent then
			local state = Combat and Combat.getState(p.UserId)
			if state and state.alive then
				table.insert(alive, p)
			end
		end
	end
	return alive
end

-- Лидер по HP% (бот тоже участвует)
local function getLeaderByHealth(round)
	local Combat = getCombatSystem()
	local bestPlayer = nil
	local bestHpPct = -1

	for _, p in ipairs(round.players) do
		local isBot = type(p) == "table" and p._isBot
		local hpPct = -1

		if isBot then
			if _G.TestBot and _G.TestBot.isAlive() then
				hpPct = _G.TestBot.getHpPct and _G.TestBot.getHpPct() or 0.5
			end
		elseif p and p.Parent then
			local state = Combat and Combat.getState(p.UserId)
			if state and state.alive and state.maxHp > 0 then
				hpPct = state.hp / state.maxHp
			end
		end

		if hpPct > bestHpPct then
			bestHpPct = hpPct
			bestPlayer = p
		end
	end
	return bestPlayer
end

-- ============================================================
-- PHASE: PREPARATION
-- ============================================================

-- BUG-D/C FIX: вспомогательная функция разморозки игроков — вынесена отдельно
-- чтобы вызывать и при нормальном переходе и при досрочной отмене
local function unfreezeRoundPlayers(round)
	for _, p in ipairs(round.players) do
		local isBot = type(p) == "table" and p._isBot
		if isBot then continue end
		if not p or not p.Parent then continue end
		local char = p.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if not hum then continue end
		-- BUG-D FIX: берём скорость из heroData, а не из state.speed
		-- state.speed может быть nil если initPlayer ещё не отработал
		local Combat  = getCombatSystem()
		local CharSvc = getCharacterService()
		local spd     = 16
		if Combat then
			local state = Combat.getState(p.UserId)
			if state and state.speed and state.speed > 0 then
				spd = state.speed
			end
		end
		if spd == 16 and CharSvc then
			local heroData = CharSvc.GetSelectedHero(p.UserId)
			if heroData and heroData.speed then spd = heroData.speed end
		end
		hum.WalkSpeed = spd
		hum.JumpPower = 50
	end
end

local function runPreparation(round)
	round.phase = PHASE.PREPARATION
	local duration = PHASE_DURATIONS.Preparation

	-- Заморозить игроков (боты пропускаются)
	for _, p in ipairs(round.players) do
		local isBot = type(p) == "table" and p._isBot
		if isBot then continue end
		if not p or not p.Parent then continue end
		local char = p.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		end
	end

	fireAllPlayers(RoundStateChanged, round, "Preparation")
	fireAllPlayers(ShowNotification, round, "⚔️ GET READY!", "phase_banner")

	local timeLeft = duration
	while timeLeft > 0 and activeRounds[round.id] and round.phase == PHASE.PREPARATION do
		fireAllPlayers(RoundTimer, round, timeLeft, "preparation")
		if timeLeft <= 3 then
			fireAllPlayers(ShowNotification, round, tostring(timeLeft), "countdown_big")
		end
		task.wait(1)
		timeLeft -= 1
	end

	-- BUG-C FIX: размораживаем всегда — и при нормальном завершении, и при досрочной отмене
	unfreezeRoundPlayers(round)

	if not activeRounds[round.id] then return end

	fireAllPlayers(ShowNotification, round, "FIGHT!", "fight_banner")
end

-- ============================================================
-- PHASE: BATTLE
-- ============================================================

local function runBattle(round)
	round.phase = PHASE.BATTLE

	local Modifiers = getGameModeModifiers()
	local battleDuration = PHASE_DURATIONS.Battle

	-- Применяем длительность согласно режиму
	if Modifiers and Modifiers.GetBattleDuration then
		battleDuration = Modifiers.GetBattleDuration(round.mode) or battleDuration
	elseif Config.ROUND_DURATION then
		battleDuration = Config.ROUND_DURATION[round.mode] or battleDuration
	end

	round.battleStartTick = tick()
	round.battleDuration  = battleDuration

	-- FIX: RoundStart шлём с правильными аргументами по контракту Remotes.lua:
	-- (leftHeroId, leftName, rightHeroId, rightName, mode)
	-- Для 2 игроков — явные left/right; для 1 (vs бот) — единственный игрок слева.
	local CharSvc = getCharacterService()

	local function getParticipantHeroAndName(p)
		local isBot = type(p) == "table" and p._isBot
		if isBot then
			local heroId = (_G.TestBot and _G.TestBot.getHeroId and _G.TestBot.getHeroId()) or "FlameRonin"
			local name   = (_G.TestBot and _G.TestBot.getName  and _G.TestBot.getName())   or "[BOT]"
			return heroId, name
		end
		local heroId = "FlameRonin"
		if CharSvc and CharSvc.GetSelectedHero then
			local hd = CharSvc.GetSelectedHero(p.UserId)
			if hd then heroId = hd.id or heroId end
		end
		return heroId, p.Name
	end

	-- Собираем участников (только реальные игроки + бот)
	local left  = round.players[1]
	local right = round.players[2]

	local leftHeroId,  leftName  = getParticipantHeroAndName(left)
	local rightHeroId, rightName = right
		and getParticipantHeroAndName(right)
		or  leftHeroId, leftName   -- зеркало если один участник

	-- Шлём каждому игроку (боты пропускаются)
	for _, p in ipairs(round.players) do
		local isBot = type(p) == "table" and p._isBot
		if not isBot and p and p.Parent then
			RoundStart:FireClient(p, leftHeroId, leftName, rightHeroId, rightName, round.mode)
		end
	end

	-- FIX: RoundStateChanged уже объявлен наверху — FindFirstChild убран
	fireAllPlayers(RoundStateChanged, round, "Battle")

	local timeLeft = battleDuration
	while timeLeft > 0 and activeRounds[round.id] and round.phase == PHASE.BATTLE do
		-- BUG-F FIX: фильтруем бота — p.Parent=true (булево) проходило проверку и крашало FireClient
		for _, p in ipairs(round.players) do
			local isBot = type(p) == "table" and p._isBot
			if isBot then continue end
			if not p or not p.Parent then continue end
			RoundTimer:FireClient(p, timeLeft)
			UpdateHUD:FireClient(p, { timer = timeLeft })
		end

		-- Проверка победы по выбыванию (не OneHit режим)
		local Mods = getGameModeModifiers()
		if not (Mods and Mods.IsOneHitMode and Mods.IsOneHitMode(round.mode)) then
			local alive = countAlivePlayers(round)
			if #alive <= 1 then
				local winner = alive[1] or nil
				RoundService.EndRound(round.id, winner and winner.UserId or nil, "elimination")
				return
			end
		end

		task.wait(1)
		timeLeft -= 1
	end

	-- Время вышло — победитель по HP%
	if activeRounds[round.id] and round.phase == PHASE.BATTLE then
		local leader = getLeaderByHealth(round)
		RoundService.EndRound(round.id, leader and leader.UserId or nil, "timeout")
	end
end

-- ============================================================
-- PHASE: CONCLUSION
-- ============================================================

local function runConclusion(round, winnerId, reason)
	round.phase = PHASE.CONCLUSION

	local Combat = getCombatSystem()
	local Modifiers = getGameModeModifiers()

	-- Собираем финальную статистику
	local finalStats = {}
	local mvpId = nil
	local maxScore = -1

	for _, p in ipairs(round.players) do
		if p and p.Parent then
			local state = Combat and Combat.getState(p.UserId)
			local kills   = (state and state.kills)  or 0
			local damage  = (state and state.damage) or 0
			local deaths  = (state and state.deaths) or 0
			finalStats[p.UserId] = {
				name   = p.Name,
				kills  = kills,
				deaths = deaths,
				damage = math.floor(damage),
				hermId = (state and state.heroId) or "Unknown",
			}
			local score = kills * 100 + damage
			if score > maxScore then
				maxScore = score
				mvpId = p.UserId
			end
		end
	end

	-- Имя по UserId (работает для бота с userId=-1)
	local function getNameById(uid)
		if not uid then return nil end
		if uid == -1 then return _G.TestBot and _G.TestBot.getName and _G.TestBot.getName() or "[BOT]" end
		local p = Players:GetPlayerByUserId(uid)
		return p and p.Name or ("Player#"..uid)
	end

	local mvpName = getNameById(mvpId) or "None"
	local winnerName = getNameById(winnerId) or "Draw"

	-- Считаем награды по игроку
	for _, p in ipairs(round.players) do
		if p and p.Parent then
			local isWinner = (winnerId ~= nil and p.UserId == winnerId)
			local isMVP    = (p.UserId == mvpId)

			local rpGain    = isWinner
				and (Config.REWARDS and Config.REWARDS.WIN_RATING or 30)
				or  (Config.REWARDS and Config.REWARDS.LOSE_RATING or 10)
			local coinsGain = isWinner
				and (Config.REWARDS and Config.REWARDS.WIN_COINS or 50)
				or  (Config.REWARDS and Config.REWARDS.LOSE_COINS or 15)

			if isMVP then
				rpGain    = rpGain    + (Config.REWARDS and Config.REWARDS.MVP_BONUS_RP    or 10)
				coinsGain = coinsGain + (Config.REWARDS and Config.REWARDS.MVP_BONUS_COINS or 20)
			end

			if Modifiers and Modifiers.CalculateRewards then
				rpGain, coinsGain = Modifiers.CalculateRewards(round.mode, rpGain, coinsGain)
			end

			local resultData = {
				winnerId   = winnerId or 0,
				winnerName = winnerName,
				stats      = finalStats,
				rewards    = { rp = math.floor(rpGain), coins = math.floor(coinsGain) },
				mvpName    = mvpName,
				isMVP      = isMVP,
				mode       = round.mode,
				reason     = reason or "normal",
			}

			RoundEnd:FireClient(p, resultData)

			-- Сохраняем в DataStore
			if _G.DataStore and _G.DataStore.AddPlayerRewards then
				_G.DataStore.AddPlayerRewards(p.UserId, rpGain, coinsGain)
			end
		end
	end

	print(string.format(
		"[RoundService] Round %s concluded | Winner: %s | Mode: %s | Reason: %s",
		round.id, winnerName, round.mode, reason or "normal"
	))

	task.wait(PHASE_DURATIONS.Conclusion)
	activeRounds[round.id] = nil
end

-- ============================================================
-- PUBLIC API
-- ============================================================

--- Запустить новый раунд
--- @param playerList table  — массив Player объектов
--- @param mode       string — "Normal" | "OneHit" | "Ranked"
function RoundService.StartRound(playerList, mode)
	assert(type(playerList) == "table" and #playerList >= 1, "[RoundService] playerList must be non-empty")
	mode = mode or "Normal"

	local roundId = string.format("Round_%d_%s", math.floor(tick()), mode)
	local round = {
		id      = roundId,
		mode    = mode,
		players = playerList,
		phase   = PHASE.WAITING,
		startTick = tick(),
	}
	activeRounds[roundId] = round

	print(string.format("[RoundService] Starting round %s | Mode: %s | Players: %d",
		roundId, mode, #playerList))

	-- Инициализируем боевые состояния участников
	local Combat = getCombatSystem()
	local CharSvc = getCharacterService()
	local Modifiers = getGameModeModifiers()

	for _, p in ipairs(playerList) do
		local isBot = type(p) == "table" and p._isBot
		if isBot then
			-- Бот уже зарегистрирован в CombatSystem через TestBot.forceStart
			-- Просто сообщаем боту matchId раунда
			if _G.TestBot and _G.TestBot.setMatchId then
				_G.TestBot.setMatchId(roundId)
			end
		elseif p and p.Parent then
			local heroData
			if CharSvc and CharSvc.GetSelectedHero then
				heroData = CharSvc.GetSelectedHero(p.UserId)
			end
			heroData = heroData or { id = "FlameRonin", name = "Flame Ronin", hp = 120, m1Damage = 8, speed = 16 }

			if Modifiers and Modifiers.ApplyToPlayer then
				Modifiers.ApplyToPlayer(p, heroData, mode)
			end

			if Combat and Combat.initPlayer then
				-- BUG-E FIX: передаём mode четвёртым аргументом
				-- Без mode — state.mode = nil, respawnTime не находился
				Combat.initPlayer(p, heroData, roundId, mode)
			end
		end
	end

	-- FIX: RegisterPlayer в RespawnHandler до запуска фаз
	if _G.RespawnHandler then
		for _, p in ipairs(playerList) do
			local isBot = type(p) == "table" and p._isBot
			if not isBot and p and p.Parent then
				_G.RespawnHandler.RegisterPlayer(p.UserId, roundId, mode)
			end
		end
	end

	-- Запускаем фазы асинхронно
	task.spawn(function()
		-- 1. Подготовка
		runPreparation(round)
		if not activeRounds[roundId] then return end

		-- 2. Бой
		runBattle(round)
		-- runConclusion вызывается изнутри EndRound
	end)

	return roundId
end

--- Завершить раунд принудительно (вызывается из CombatSystem или GameManager)
--- @param roundId  string
--- @param winnerId number|nil  — UserId победителя (nil = ничья)
--- @param reason   string|nil — причина: "elimination", "timeout", "killimit", "forfeit"
function RoundService.EndRound(roundId, winnerId, reason)
	local round = activeRounds[roundId]
	if not round then
		warn("[RoundService] EndRound called for unknown round:", roundId)
		return
	end

	-- Предотвращаем двойное завершение
	if round.phase == PHASE.CONCLUSION then return end

	round.phase = PHASE.CONCLUSION -- немедленно меняем фазу чтобы остановить battle loop

	-- Запускаем conclusion асинхронно
	task.spawn(function()
		runConclusion(round, winnerId, reason)
	end)
end

--- Получить текущую фазу раунда
function RoundService.GetPhase(roundId)
	local round = activeRounds[roundId]
	return round and round.phase or nil
end

--- Получить данные раунда
function RoundService.GetRound(roundId)
	return activeRounds[roundId]
end

--- Получить все активные раунды
function RoundService.GetActiveRounds()
	return activeRounds
end

--- Получить roundId игрока (если он в матче)
function RoundService.GetPlayerRound(userId)
	for roundId, round in pairs(activeRounds) do
		for _, p in ipairs(round.players) do
			if p and p.UserId == userId then
				return roundId, round
			end
		end
	end
	return nil, nil
end

--- Форфейт (игрок вышел из игры)
function RoundService.ForfeitPlayer(userId)
	local roundId, round = RoundService.GetPlayerRound(userId)
	if not round then return end

	if round.phase ~= PHASE.BATTLE then return end

	-- Убираем выбывшего
	local remaining = {}
	for _, p in ipairs(round.players) do
		if p and p.UserId ~= userId and p.Parent then
			table.insert(remaining, p)
		end
	end

	if #remaining == 1 then
		RoundService.EndRound(roundId, remaining[1].UserId, "forfeit")
	elseif #remaining == 0 then
		RoundService.EndRound(roundId, nil, "forfeit")
	end
end

-- Автоматический форфейт при выходе игрока
Players.PlayerRemoving:Connect(function(player)
	RoundService.ForfeitPlayer(player.UserId)
end)

print("[RoundService] Initialized ✓ — Phase system: Waiting → Preparation → Battle → Conclusion")
