-- DuelService.server.lua | Anime Arena: Blitz
-- Система дуэлей в открытом лобби:
--   • Вызов игрока (RequestDuel) → всплывашка цели (DuelRequest)
--   • Принять / Отклонить (AcceptDuel / DeclineDuel)
--   • Таймаут 30с; защита от двойных запросов / занятых игроков
-- Публичный API: _G.DuelService

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local rRequestDuel   = Remotes:WaitForChild("RequestDuel")
local rDuelRequest   = Remotes:WaitForChild("DuelRequest")
local rAcceptDuel    = Remotes:WaitForChild("AcceptDuel")
local rDeclineDuel   = Remotes:WaitForChild("DeclineDuel")
local rDuelDeclined  = Remotes:WaitForChild("DuelDeclined")
local rDuelCancelled = Remotes:WaitForChild("DuelCancelled")
local rNotify        = Remotes:WaitForChild("ShowNotification")

-- ============================================================
-- КОНСТАНТЫ
-- ============================================================

local DUEL_TIMEOUT_SEC = 30
local DUEL_MODE        = "Normal"

-- ============================================================
-- СОСТОЯНИЕ
-- pendingDuels[targetUserId] = { requester: Player, timerThread: thread }
-- ============================================================

local pendingDuels = {}

local DuelService  = {}
_G.DuelService     = DuelService

-- ============================================================
-- УТИЛИТЫ
-- ============================================================

local function isPlayerBusy(player)
	if not player or not player.Parent then return true end
	if _G.RoundService then
		local roundId = _G.RoundService.GetPlayerRound(player.UserId)
		if roundId then return true end
	end
	return false
end

local function cancelDuel(targetUserId, reason)
	local pending = pendingDuels[targetUserId]
	if not pending then return end

	if pending.timerThread then
		task.cancel(pending.timerThread)
		pending.timerThread = nil
	end

	local target    = Players:GetPlayerByUserId(targetUserId)
	local requester = pending.requester

	if target and target.Parent then
		rDuelCancelled:FireClient(target, reason or "cancelled")
	end
	if requester and requester.Parent then
		rDuelCancelled:FireClient(requester, reason or "cancelled")
	end

	pendingDuels[targetUserId] = nil
end

-- ============================================================
-- REMOTE: Запросить дуэль
-- ============================================================

rRequestDuel.OnServerEvent:Connect(function(player, targetUserId)
	if type(targetUserId) ~= "number" then return end

	if player.UserId == targetUserId then
		rNotify:FireClient(player, "❌ Нельзя вызвать самого себя", "warning")
		return
	end

	if isPlayerBusy(player) then
		rNotify:FireClient(player, "⚔️ Вы уже в бою", "warning")
		return
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or not target.Parent then
		rNotify:FireClient(player, "❌ Игрок не найден", "warning")
		return
	end

	if isPlayerBusy(target) then
		rNotify:FireClient(player, string.format("⚔️ %s уже в бою", target.Name), "warning")
		return
	end

	-- Если уже есть запрос на эту цель — отменяем старый
	if pendingDuels[targetUserId] then
		cancelDuel(targetUserId, "replaced")
	end

	-- Таймер истечения
	local timerThread = task.delay(DUEL_TIMEOUT_SEC, function()
		if pendingDuels[targetUserId] then
			if player and player.Parent then
				rNotify:FireClient(player,
					string.format("⏱️ %s не ответил на вызов", target.Name), "info")
			end
			cancelDuel(targetUserId, "timeout")
		end
	end)

	pendingDuels[targetUserId] = {
		requester   = player,
		timerThread = timerThread,
	}

	-- Входящий запрос цели
	rDuelRequest:FireClient(target, player.Name, player.UserId, DUEL_TIMEOUT_SEC)
	rNotify:FireClient(player, string.format("⚔️ Вызов отправлен → %s", target.Name), "info")

	print(string.format("[DuelService] %s challenged %s", player.Name, target.Name))
end)

-- ============================================================
-- REMOTE: Принять дуэль
-- ============================================================

rAcceptDuel.OnServerEvent:Connect(function(player, requesterUserId)
	if type(requesterUserId) ~= "number" then return end

	local pending = pendingDuels[player.UserId]
	if not pending then
		rNotify:FireClient(player, "❌ Запрос на дуэль истёк", "warning")
		return
	end

	local requester = pending.requester
	if not requester or not requester.Parent then
		cancelDuel(player.UserId, "requester_left")
		return
	end

	if isPlayerBusy(player) then
		rNotify:FireClient(player, "⚔️ Вы уже в бою", "warning")
		cancelDuel(player.UserId, "target_busy")
		return
	end
	if isPlayerBusy(requester) then
		rNotify:FireClient(player, string.format("⚔️ %s уже в бою", requester.Name), "warning")
		cancelDuel(player.UserId, "requester_busy")
		return
	end

	-- Останавливаем таймер и очищаем запись ДО запуска раунда
	if pending.timerThread then task.cancel(pending.timerThread) end
	pendingDuels[player.UserId] = nil

	-- Гарантируем наличие героя (фоллбэк FlameRonin)
	local function ensureHero(p)
		if not _G.CharacterService then return end
		local heroData = _G.CharacterService.GetSelectedHero(p.UserId)
		if not heroData then
			heroData = _G.CharacterService.GetHeroData("FlameRonin")
			_G.CharacterService.SpawnWithHero(p, heroData)
		end
	end
	ensureHero(requester)
	ensureHero(player)

	task.delay(0.5, function()
		if not requester.Parent or not player.Parent then return end
		if _G.RoundService and _G.RoundService.StartRound then
			local roundId = _G.RoundService.StartRound({requester, player}, DUEL_MODE)
			print(string.format("[DuelService] Duel started: %s vs %s | round=%s",
				requester.Name, player.Name, tostring(roundId)))
		else
			warn("[DuelService] RoundService unavailable!")
			rNotify:FireClient(player,    "❌ Ошибка запуска дуэли", "error")
			rNotify:FireClient(requester, "❌ Ошибка запуска дуэли", "error")
		end
	end)
end)

-- ============================================================
-- REMOTE: Отклонить дуэль
-- ============================================================

rDeclineDuel.OnServerEvent:Connect(function(player, requesterUserId)
	local pending = pendingDuels[player.UserId]
	if not pending then return end

	local requester = pending.requester
	if requester and requester.Parent then
		rDuelDeclined:FireClient(requester, player.Name)
		rNotify:FireClient(requester,
			string.format("❌ %s отклонил вызов", player.Name), "info")
	end

	cancelDuel(player.UserId, "declined")
	print(string.format("[DuelService] %s declined duel from %s",
		player.Name, requester and requester.Name or "unknown"))
end)

-- ============================================================
-- УБОРКА
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	cancelDuel(player.UserId, "player_left")
	for targetUid, pending in pairs(pendingDuels) do
		if pending.requester == player then
			cancelDuel(targetUid, "requester_left")
		end
	end
end)

-- ============================================================
-- ПУБЛИЧНЫЙ API
-- ============================================================

function DuelService.HasPendingDuel(userId)
	return pendingDuels[userId] ~= nil
end

function DuelService.CancelDuel(userId, reason)
	cancelDuel(userId, reason)
end

print("[DuelService] Initialized ✓")
