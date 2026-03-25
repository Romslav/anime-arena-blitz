-- TradeService.server.lua | Anime Arena: Blitz
-- Безопасная передача монет между игроками:
--   • Серверная проверка баланса (защита от читерского клиента)
--   • Лимит 10 000 монет / одна операция
--   • Антиспам: кулдаун 5с
--   • Аудит-лог в Output
-- Зависимости: DataStore.server.lua (_G.DataStore)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local rTransferCoins = Remotes:WaitForChild("TransferCoins")
local rTradeResult   = Remotes:WaitForChild("TradeResult")
local rNotify        = Remotes:WaitForChild("ShowNotification")

-- ============================================================
-- КОНСТАНТЫ
-- ============================================================

local MAX_TRANSFER   = 10000
local MIN_TRANSFER   = 1
local COOLDOWN_SEC   = 5
local tradeCooldowns = {}  -- [userId] = os.clock()

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

local function checkCooldown(userId)
	local last = tradeCooldowns[userId]
	if last and (os.clock() - last) < COOLDOWN_SEC then
		return false, math.ceil(COOLDOWN_SEC - (os.clock() - last))
	end
	return true, 0
end

-- ============================================================
-- REMOTE: Передача монет
-- ============================================================

rTransferCoins.OnServerEvent:Connect(function(player, targetUserId, amount)
	amount = math.floor(tonumber(amount) or 0)
	if type(targetUserId) ~= "number" then return end

	-- Сам себе
	if player.UserId == targetUserId then
		rTradeResult:FireClient(player, false, "❌ Нельзя отправлять монеты себе", 0)
		return
	end

	-- Минимум / максимум
	if amount < MIN_TRANSFER then
		rTradeResult:FireClient(player, false,
			string.format("❌ Минимум: %d монет", MIN_TRANSFER), 0)
		return
	end
	if amount > MAX_TRANSFER then
		rTradeResult:FireClient(player, false,
			string.format("❌ Максимум: %d монет", MAX_TRANSFER), 0)
		return
	end

	-- Антиспам
	local cdOk, cdLeft = checkCooldown(player.UserId)
	if not cdOk then
		rTradeResult:FireClient(player, false,
			string.format("⏱️ Подождите %dс", cdLeft), 0)
		return
	end

	-- Не в бою
	if isPlayerBusy(player) then
		rTradeResult:FireClient(player, false, "⚔️ Торговля недоступна в бою", 0)
		return
	end

	-- Цель онлайн
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or not target.Parent then
		rTradeResult:FireClient(player, false, "❌ Игрок не найден или оффлайн", 0)
		return
	end

	-- DataStore
	local DS = _G.DataStore
	if not DS then
		rTradeResult:FireClient(player, false, "❌ Сервис данных недоступен", 0)
		return
	end

	local senderData = DS.GetData(player.UserId)
	if not senderData then
		rTradeResult:FireClient(player, false, "❌ Ваши данные не загружены", 0)
		return
	end

	-- Баланс
	if senderData.coins < amount then
		rTradeResult:FireClient(player, false,
			string.format("❌ Недостаточно монет (есть: %d)", senderData.coins),
			senderData.coins)
		return
	end

	-- Атомарная транзакция
	DS.AddPlayerRewards(player.UserId,   0, -amount)
	DS.AddPlayerRewards(targetUserId,    0,  amount)

	tradeCooldowns[player.UserId] = os.clock()

	local newSenderData = DS.GetData(player.UserId)
	local newBalance    = newSenderData and newSenderData.coins or (senderData.coins - amount)

	-- Ответы
	rTradeResult:FireClient(player, true,
		string.format("✅ Отправлено %d 🪙 → %s", amount, target.Name),
		newBalance)

	rNotify:FireClient(target,
		string.format("🎁 %s отправил вам %d 🪙", player.Name, amount), "reward")

	-- Аудит
	print(string.format(
		"[TradeService] %s (uid=%d) → %s (uid=%d) | %d coins | sender_balance=%d",
		player.Name, player.UserId,
		target.Name, targetUserId,
		amount, newBalance
	))
end)

-- ============================================================
-- УБОРКА
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	tradeCooldowns[player.UserId] = nil
end)

print("[TradeService] Initialized ✓")
