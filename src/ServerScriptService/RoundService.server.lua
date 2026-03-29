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
local ReturnToLobby    = Remotes:WaitForChild("ReturnToLobby")   -- возврат из матча в лобби

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
-- АРЕНА: Изолированная зона далеко от лобби.
-- Координаты Y=5, Z=-5000 — недоступно пешком из лобби.
-- Пол арены создаётся программно при первом запуске.
-- ============================================================

local ARENA_CENTER = Vector3.new(0, 5, -5000)

local ARENA_SPAWN_POSITIONS = {
	-- Позиция #1: левый боец (лицом к правому)
	CFrame.lookAt(ARENA_CENTER + Vector3.new(-15, 0, 0), ARENA_CENTER + Vector3.new(15, 0, 0)),
	-- Позиция #2: правый боец (лицом к левому)
	CFrame.lookAt(ARENA_CENTER + Vector3.new( 15, 0, 0), ARENA_CENTER + Vector3.new(-15, 0, 0)),
}

-- Создаём пол арены один раз при первом использовании
local arenaCreated = false
local function ensureArenaExists()
	if arenaCreated then return end
	arenaCreated = true

	local floor = Instance.new("Part")
	floor.Name         = "ArenaFloor"
	floor.Size         = Vector3.new(80, 1, 80)
	floor.Position     = ARENA_CENTER - Vector3.new(0, 2, 0) -- чуть ниже спавна
	floor.Anchored     = true
	floor.CanCollide   = true
	floor.Color        = Color3.fromRGB(20, 20, 30)
	floor.Material     = Enum.Material.SmoothPlastic
	floor.TopSurface   = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.CastShadow   = false
	floor.Parent       = workspace

	-- Невидимые стены (барьеры) чтобы не улететь с арены
	for _, data in ipairs({
		{Vector3.new(80, 20, 1), Vector3.new(0, 8, 40)},
		{Vector3.new(80, 20, 1), Vector3.new(0, 8, -40)},
		{Vector3.new(1, 20, 80), Vector3.new(40, 8, 0)},
		{Vector3.new(1, 20, 80), Vector3.new(-40, 8, 0)},
	}) do
		local wall = Instance.new("Part")
		wall.Size         = data[1]
		wall.Position     = ARENA_CENTER + data[2] - Vector3.new(0, 2, 0)
		wall.Anchored     = true
		wall.CanCollide   = true
		wall.Transparency = 1
		wall.Parent       = workspace
	end

	print("[RoundService] Arena created at Z=-5000 with barriers")
end

--- Телепортировать участников раунда на арену
local function teleportToArena(round)
	ensureArenaExists()

	for i, p in ipairs(round.players) do
		local isBotPlayer = type(p) == "table" and p._isBot
		if isBotPlayer then
			-- Бот: телепортируем через TestBot API
			if _G.TestBot and _G.TestBot.teleport then
				local cf = ARENA_SPAWN_POSITIONS[i] or ARENA_SPAWN_POSITIONS[1]
				pcall(_G.TestBot.teleport, cf)
			end
		elseif p and p.Parent then
			local char = p.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local cf = ARENA_SPAWN_POSITIONS[i] or ARENA_SPAWN_POSITIONS[1]
				hrp.CFrame = cf
				print(string.format("[RoundService] Teleported %s to Arena pos #%d (Z=-5000)", p.Name, i))
			end
		end
	end
end

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

	-- ================================================================
	-- BUG-1.3 FIX: Телепортируем участников НА АРЕНУ перед боем.
	-- Бои больше не происходят в лобби — выделенная зона.
	-- ================================================================
	teleportToArena(round)
	task.wait(0.3)  -- дать физике осесть после телепорта

	-- ================================================================
	-- ИСПРАВЛЕНИЕ #1: Отправляем RoundStart (интро "VS") ЗДЕСЬ, в начале
	-- подготовки, а не в runBattle. Фаза остаётся "Preparation" —
	-- бот не атакует пока игрок смотрит заставку.
	-- ================================================================
	do
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

		local left  = round.players[1]
		local right = round.players[2]
		local leftHeroId, leftName = getParticipantHeroAndName(left)
		local rightHeroId, rightName
		if right then
			rightHeroId, rightName = getParticipantHeroAndName(right)
		else
			rightHeroId, rightName = leftHeroId, leftName
		end

		for _, p in ipairs(round.players) do
			local isBot = type(p) == "table" and p._isBot
			if not isBot and p and p.Parent then
				-- Клиент получает интро, пока всё ещё на Preparation
				RoundStart:FireClient(p, leftHeroId, leftName, rightHeroId, rightName, round.mode)
			end
		end
	end

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

	-- ИСПРАВЛЕНИЕ #1: RoundStart уже отправлен в runPreparation — здесь только меняем фазу
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
		-- BUG-4 FIX: заменили IsOneHitMode(character) на IsOneHitModeId(modeId) —
		-- старая версия ждала Instance и крашалась на строке.
		local Mods = getGameModeModifiers()
		if not (Mods and Mods.IsOneHitModeId and Mods.IsOneHitModeId(round.mode)) then
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
-- ВАЛЮТНЫЙ ТРЕУГОЛЬНИК — ТАБЛИЦЫ НАГРАД
-- ============================================================

-- Coins за победу по текущему рангу игрока
local COIN_REWARD_BY_RANK = {
	E=50, D=65, C=80, B=100, A=120, S=150, SS=185, SSS=220,
}

-- Множитель монет от финального Style Rank раунда
local STYLE_COIN_MULTIPLIER = {
	D=1.0, C=1.0, B=1.2, A=1.5, S=1.5, SS=1.75, SSS=2.0,
}

-- Итоговые монеты за матч
local function calcCoinReward(rpRank, styleRank, isWinner)
	local base  = COIN_REWARD_BY_RANK[rpRank]  or 50
	local multi = STYLE_COIN_MULTIPLIER[styleRank] or 1.0
	local result = math.floor(base * multi)
	if not isWinner then result = math.floor(result * 0.3) end
	return result
end

-- Базовые источники Mastery XP за матч (из плана Part 3)
local MASTERY_XP_TABLE = {
	win   = 40,
	loss  = 12,
	draw  = 20,
	style = { D=0, C=0, B=8, A=15, S=20, SS=30, SSS=50 },
	performed_full_combo  = 15,
	perfect_parry         = 10,
	ability_kill          = 12,
	no_damage_taken_round = 25,
	ult_finisher          = 20,
	comeback_win          = 18,
	gacha_duplicate       = 150,
}

-- Полная формула Mastery XP за матч
local function calcMasteryXP(matchData)
	-- matchData: { result, styleRank, matchNumber, actions={}, isPremiumBP, isRanked, streakCount }
	local base        = MASTERY_XP_TABLE[matchData.result or "loss"] or 12
	local styleBonus  = MASTERY_XP_TABLE.style[matchData.styleRank or "D"] or 0

	local actionBonus = 0
	if type(matchData.actions) == "table" then
		for action, earned in pairs(matchData.actions) do
			if earned and MASTERY_XP_TABLE[action] then
				actionBonus = actionBonus + MASTERY_XP_TABLE[action]
			end
		end
	end

	local total = base + styleBonus + actionBonus

	-- Множители (мультипликативно)
	local multiplier = 1.0
	local n = matchData.matchNumber or 99
	if n <= 5  then
		multiplier = multiplier * 2.0
	elseif n <= 20 then
		multiplier = multiplier * 1.5
	end
	if matchData.isPremiumBP then multiplier = multiplier * 1.25 end
	if matchData.isRanked    then multiplier = multiplier * 1.30 end
	local streak = matchData.streakCount or 0
	if streak >= 5 then
		multiplier = multiplier * 1.20
	elseif streak >= 3 then
		multiplier = multiplier * 1.10
	end

	return math.floor(total * multiplier)
end

-- RP изменение по соотношению рангов соперников
local RP_CHANGE = {
	win_vs_lower   = 15,
	win_vs_equal   = 20,
	win_vs_higher  = 28,
	loss_vs_lower  = -22,
	loss_vs_equal  = -15,
	loss_vs_higher = -8,
	draw           = 0,
}

local RANK_ORDER = { E=1, D=2, C=3, B=4, A=5, S=6, SS=7, SSS=8 }

local function calcRPChange(isWinner, isDraw, playerRank, opponentRank)
	if isDraw then return RP_CHANGE.draw end
	local myOrder  = RANK_ORDER[playerRank]   or 1
	local oppOrder = RANK_ORDER[opponentRank] or 1
	if isWinner then
		if myOrder > oppOrder  then return RP_CHANGE.win_vs_lower
		elseif myOrder < oppOrder then return RP_CHANGE.win_vs_higher
		else return RP_CHANGE.win_vs_equal end
	else
		if myOrder > oppOrder  then return RP_CHANGE.loss_vs_lower
		elseif myOrder < oppOrder then return RP_CHANGE.loss_vs_higher
		else return RP_CHANGE.loss_vs_equal end
	end
end

-- ============================================================
-- PHASE: CONCLUSION
-- ============================================================

local function runConclusion(round, winnerId, reason)
	round.phase = PHASE.CONCLUSION

	local Combat    = getCombatSystem()
	local Modifiers = getGameModeModifiers()
	local isDraw    = (winnerId == nil or winnerId == 0)
	local isRanked  = (round.mode == "Ranked")

	-- ── Собираем финальную статистику ──────────────────────────
	local finalStats = {}
	local mvpId      = nil
	local maxScore   = -1

	-- Определяем ранги всех участников (для RP-расчёта)
	local playerRanks = {}  -- [userId] = rank string
	for _, p in ipairs(round.players) do
		local isBot = type(p) == "table" and p._isBot
		if not isBot and p and p.Parent then
			local data = _G.DataStore and _G.DataStore.GetData(p.UserId)
			playerRanks[p.UserId] = data and data.rank or "E"
		end
	end

	-- Ранг оппонента (в матче 1v1 — единственный противник)
	local function getOpponentRank(myUserId)
		for uid, rank in pairs(playerRanks) do
			if uid ~= myUserId then return rank end
		end
		return "E"  -- бот или нет оппонента
	end

	for _, p in ipairs(round.players) do
		local isBot = type(p) == "table" and p._isBot
		if isBot then continue end
		if not p or not p.Parent then continue end
		local state  = Combat and Combat.getState(p.UserId)
		local kills  = (state and state.kills)  or 0
		local damage = (state and state.damage) or 0
		local deaths = (state and state.deaths) or 0
		finalStats[p.UserId] = {
			name      = p.Name,
			kills     = kills,
			deaths    = deaths,
			damage    = math.floor(damage),
			heroId    = (state and state.heroId) or "Unknown",
			styleRank = (state and state.styleRank) or "D",
		}
		local score = kills * 100 + damage
		if score > maxScore then
			maxScore = score
			mvpId    = p.UserId
		end
	end

	local function getNameById(uid)
		if not uid then return nil end
		if uid == -1 then return _G.TestBot and _G.TestBot.getName and _G.TestBot.getName() or "[BOT]" end
		local p = Players:GetPlayerByUserId(uid)
		return p and p.Name or ("Player#"..uid)
	end

	local mvpName    = getNameById(mvpId) or "None"
	local winnerName = getNameById(winnerId) or "Draw"

	-- ── Награды и Mastery XP для каждого игрока ────────────────
	for _, p in ipairs(round.players) do
		local isBot = type(p) == "table" and p._isBot
		if isBot then continue end
		if not p or not p.Parent then continue end

		local uid      = p.UserId
		local isWinner = not isDraw and uid == winnerId
		local isMVP    = (uid == mvpId)

		local state    = Combat and Combat.getState(uid)
		local styleRank = (state and state.styleRank) or "D"
		local heroId    = (state and state.heroId)    or "FlameRonin"

		-- Данные игрока для расчётов
		local pData        = _G.DataStore and _G.DataStore.GetData(uid)
		local playerRank   = (pData and pData.rank) or "E"
		local opponentRank = getOpponentRank(uid)
		local isPremiumBP  = pData and pData.bp and pData.bp.premium or false
		local winStreak    = (pData and pData.stats and pData.stats.currentWinStreak) or 0

		-- matchNumber для героя (сколько матчей сыграно ДО этого)
		local heroEntry    = pData and pData.heroes and pData.heroes[heroId]
		local matchNumber  = (heroEntry and heroEntry.totalMatches or 0)

		-- ── RP ──────────────────────────────────────────────────
		local rpGain = 0
		if isDraw then
			rpGain = RP_CHANGE.draw
		else
			rpGain = calcRPChange(isWinner, false, playerRank, opponentRank)
		end

		-- MVP бонус RP
		if isMVP then
			rpGain = rpGain + (Config.REWARDS and Config.REWARDS.MVP_BONUS_RP or 10)
		end

		-- GameModeModifiers
		local coinsRaw = calcCoinReward(playerRank, styleRank, isWinner)
		if isMVP then
			coinsRaw = coinsRaw + (Config.REWARDS and Config.REWARDS.MVP_BONUS_COINS or 20)
		end
		if Modifiers and Modifiers.CalculateRewards then
			rpGain, coinsRaw = Modifiers.CalculateRewards(round.mode, rpGain, coinsRaw)
		end

		-- ── Mastery XP ──────────────────────────────────────────
		local actions = {}
		if Combat and Combat.GetMatchActions then
			actions = Combat.GetMatchActions(uid, isWinner)
		end

		local masteryXP = calcMasteryXP({
			result       = isDraw and "draw" or (isWinner and "win" or "loss"),
			styleRank    = styleRank,
			matchNumber  = matchNumber,
			actions      = actions,
			isPremiumBP  = isPremiumBP,
			isRanked     = isRanked,
			streakCount  = isWinner and winStreak or 0,
		})

		-- ── Применяем награды ───────────────────────────────────
		if _G.DataStore then
			-- Монеты и RP (также обновляет статистику wins/losses/streak)
			_G.DataStore.AddPlayerRewards(uid, rpGain, coinsRaw, isWinner)
			-- Mastery XP
			_G.DataStore.AddMasteryXP(uid, heroId, masteryXP)
			-- Обновляем статистику матча
			_G.DataStore.RecordMatchStats(uid, heroId, isWinner, styleRank,
				(state and state.damage) or 0)
		end

		-- ── Отправляем результат клиенту ────────────────────────
		local resultData = {
			winnerId   = winnerId or 0,
			winnerName = winnerName,
			stats      = finalStats,
			rewards    = {
				rp          = math.floor(rpGain),
				coins       = math.floor(coinsRaw),
				masteryXP   = masteryXP,
				styleRank   = styleRank,
			},
			mvpName    = mvpName,
			isMVP      = isMVP,
			mode       = round.mode,
			reason     = reason or "normal",
		}
		RoundEnd:FireClient(p, resultData)
	end

	print(string.format(
		"[RoundService] Round %s concluded | Winner: %s | Mode: %s | Reason: %s",
		round.id, winnerName, round.mode, reason or "normal"
	))

	task.wait(PHASE_DURATIONS.Conclusion)

	-- ── Возврат игроков в лобби ──────────────────────────────────
	for _, p in ipairs(round.players) do
		local isBot = type(p) == "table" and p._isBot
		if isBot then
			if _G.TestBot then
				task.spawn(function() _G.TestBot.despawn() end)
			end
		elseif p and p.Parent then
			-- Сигнал клиенту: запустить fade-out анимацию
			ReturnToLobby:FireClient(p)
			-- Серверный ресет через 1.5s (после клиентского fade)
			task.delay(1.5, function()
				if p and p.Parent and _G.CharacterService then
					_G.CharacterService.SpawnInLobby(p)
				end
			end)
		end
	end

	activeRounds[round.id] = nil
	print(string.format("[RoundService] Round %s cleared → players returned to Lobby", round.id))
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
			-- BUG-3 FIX: аргументы были перепутаны.
			-- Подпись ApplyToPlayer: (player, modeId, heroData)
			Modifiers.ApplyToPlayer(p, mode, heroData)
			end

			-- FIX: применяем статы героя на персонаже до initPlayer,
			-- чтобы WalkSpeed был выставлен правильно с самого начала
			if CharSvc and CharSvc.ApplyStats and p.Character then
			CharSvc.ApplyStats(p.Character, heroData)
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

		-- ИСПРАВЛЕНИЕ #3: Строгая проверка перед запуском боя.
		-- Если игрок умер во время Preparation, фаза стала Conclusion — не запускаем runBattle.
		if not activeRounds[roundId] or round.phase ~= PHASE.PREPARATION then return end

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
