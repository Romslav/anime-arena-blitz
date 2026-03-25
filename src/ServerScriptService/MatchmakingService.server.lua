-- MatchmakingService.server.lua | Anime Arena: Blitz
-- Очередь матчмейкинга:
--   • Игрок входит в очередь (JoinQueue)
--   • Если нашлось 2 игрока — стартуем матч
--   • Если игрок один дольше BOT_WAIT_TIME — подключается бот и стартует матч
--   • Отправляет обратный отсчёт QueueStatus (+ оставшееся время до бота)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- КОНФИГ
-- ============================================================

local BOT_WAIT_TIME    = 30   -- секунд до подключения бота
local HERO_SELECT_TIME = 25   -- секунд на выбор героя (=таймер в HeroSelector.client)

-- ============================================================
-- REMOTES
-- ============================================================

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local rJoinQueue    = Remotes:WaitForChild("JoinQueue")
local rLeaveQueue   = Remotes:WaitForChild("LeaveQueue")
local rMatchFound   = Remotes:WaitForChild("MatchFound")
local rQueueStatus  = Remotes:WaitForChild("QueueStatus")
local rShowNotif    = Remotes:WaitForChild("ShowNotification")
local rRoundState   = Remotes:WaitForChild("RoundStateChanged")

-- ============================================================
-- СОСТОЯНИЕ
-- ============================================================

-- queue[userId] = { player, joinTime, mode }
local queue = {}

local MatchmakingService = {}
_G.MatchmakingService = MatchmakingService

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ
-- ============================================================

local function queueCount()
	local n = 0
	for _ in pairs(queue) do n = n + 1 end
	return n
end

-- FIX: broadcastQueueStatus не перезаписывает текст бот-таймера —
-- вместо этого таймер очереди сам шлёт QueueStatus, broadcastQueueStatus удаляем
local function broadcastQueueStatus()
	local count = queueCount()
	for uid, entry in pairs(queue) do
		local waited = math.floor(tick() - entry.joinTime)
		local botIn  = math.max(0, BOT_WAIT_TIME - waited)
		rQueueStatus:FireClient(entry.player, 1, count, botIn)
	end
end

local function removeFromQueue(userId)
	queue[userId] = nil
end

-- ============================================================
-- ЗАПУСК МАТЧА (человек vs человек)
-- ============================================================

local function startMatch(playerA, playerB, mode)
	removeFromQueue(playerA.UserId)
	removeFromQueue(playerB.UserId)

	local matchId = string.format("match_%d", math.floor(tick()))

	-- Шлём MatchFound — клиенты откроют HeroSelector
	for _, p in ipairs({ playerA, playerB }) do
		if p and p.Parent then
			rMatchFound:FireClient(p, { matchId = matchId, mode = mode or "Normal" })
		end
	end

	-- FIX: ждём выбора героев (поллинг) или истечения таймера,
	-- ТОЛЬКО ПОТОМ запускаем раунд
	task.spawn(function()
		-- Ждём инициализации RoundService
		for _ = 1, 10 do
			if _G.RoundService then break end
			task.wait(0.5)
		end

		-- Поллинг: оба выбрали героя — или вышел таймер
		local waited = 0
		while waited < HERO_SELECT_TIME do
			task.wait(1)
			waited += 1
			if not playerA.Parent or not playerB.Parent then return end
			-- ИСПРАВЛЕНИЕ #1: ждём подтверждения от CharacterService (не HeroSelector)
			-- Race condition: HeroSelector пишет мгновенно, CharacterService — с подтверждением
			local cs   = _G.CharacterService
			local selA = cs and cs.GetSelectedHero(playerA.UserId)
			local selB = cs and cs.GetSelectedHero(playerB.UserId)
			if selA and selB then
				print(string.format("[Matchmaking] Both heroes confirmed by CharacterService after %ds", waited))
				break
			end
		end

		if playerA.Parent and playerB.Parent and _G.RoundService then
			_G.RoundService.StartRound({ playerA, playerB }, mode or "Normal")
		end
	end)

	print(string.format("[Matchmaking] Match found: %s vs %s (mode: %s) — waiting up to %ds for hero selection",
		playerA.Name, playerB.Name, mode or "Normal", HERO_SELECT_TIME))
end

-- ============================================================
-- ЗАПУСК МАТЧА ПРОТИВ БОТА
-- ============================================================

local function startBotMatch(player, mode)
	removeFromQueue(player.UserId)

	rMatchFound:FireClient(player, { matchId = "bot_match", mode = mode or "Normal", isBot = true })
	rShowNotif:FireClient(player, "🤖 Оппонент не найден. Подключаем бота...", "warning")

	-- FIX: ждём выбора героя (поллинг), только потом стартуем бот-матч
	task.spawn(function()
		local waited = 0
		while waited < HERO_SELECT_TIME do
			task.wait(1)
			waited += 1
			if not player.Parent then return end
			-- ИСПРАВЛЕНИЕ #1: ждём CharacterService, а не HeroSelector
			local cs = _G.CharacterService
			if cs and cs.GetSelectedHero(player.UserId) then
				print(string.format("[Matchmaking] Hero confirmed by CharacterService after %ds, starting bot match", waited))
				break
			end
		end

		for _ = 1, 20 do
			if _G.TestBot then break end
			task.wait(0.5)
		end
		if player.Parent and _G.TestBot and _G.TestBot.forceStart then
			_G.TestBot.forceStart(player, mode)
		end
	end)

	print(string.format("[Matchmaking] Bot match queued for %s (mode: %s) — waiting up to %ds for hero selection",
		player.Name, mode or "Normal", HERO_SELECT_TIME))
end

-- ============================================================
-- PUBLIC API
-- ============================================================

function MatchmakingService.JoinQueue(player, mode)
	if queue[player.UserId] then return end  -- уже в очереди

	queue[player.UserId] = {
		player   = player,
		joinTime = tick(),
		mode     = mode or "Normal",
	}

	print(string.format("[Matchmaking] %s joined queue (mode: %s, queue size: %d)",
		player.Name, mode or "Normal", queueCount()))

	-- Сразу проверяем: есть ли другой игрок
	for uid, entry in pairs(queue) do
		if uid ~= player.UserId and entry.mode == (mode or "Normal") then
			startMatch(player, entry.player, mode)
			return
		end
	end

	-- FIX: единственный таймер шлёт QueueStatus, broadcastQueueStatus больше не перезаписывает текст
	task.spawn(function()
		local waited = 0
		while waited < BOT_WAIT_TIME do
			task.wait(1)
			waited = waited + 1

			if not queue[player.UserId] then return end

			-- Нашёлся другой игрок — матч уже запущен
			for uid, entry in pairs(queue) do
				if uid ~= player.UserId and entry.mode == (mode or "Normal") then
					return
				end
			end

			-- FIX: только этот таймер пишет QueueStatus — нет конфликта с broadcastQueueStatus
			local botIn = BOT_WAIT_TIME - waited
			if player and player.Parent then
				rQueueStatus:FireClient(player, 1, 1, botIn)
				if botIn == 10 then
					rShowNotif:FireClient(player, "⏳ Ищем игрока... Бот подключится через 10с", "info")
				elseif botIn == 5 then
					rShowNotif:FireClient(player, "⏳ Бот подключается через 5...", "warning")
				end
			end
		end

		if queue[player.UserId] then
			startBotMatch(player, mode)
		end
	end)
end

function MatchmakingService.LeaveQueue(player)
	if queue[player.UserId] then
		queue[player.UserId] = nil
		print(string.format("[Matchmaking] %s left queue", player.Name))
	end
end

-- ============================================================
-- REMOTES
-- ============================================================

rJoinQueue.OnServerEvent:Connect(function(player, mode)
	MatchmakingService.JoinQueue(player, mode)
end)

rLeaveQueue.OnServerEvent:Connect(function(player)
	MatchmakingService.LeaveQueue(player)
end)

-- ============================================================
-- УБОРКА
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.LeaveQueue(player)
end)

-- ============================================================
-- ТАЙМЕР: броадкаст очереди каждую секунду
-- ============================================================

task.spawn(function()
	while true do
		task.wait(1)
		if queueCount() > 0 then
			broadcastQueueStatus()
		end
	end
end)

print(string.format(
	"[MatchmakingService] Initialized ✓ | Bot wait time: %ds",
	BOT_WAIT_TIME
))
