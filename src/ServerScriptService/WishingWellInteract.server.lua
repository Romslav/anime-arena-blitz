-- WishingWellInteract.server.lua | Anime Arena: Blitz  [v2 — чистая версия]
-- Взаимодействие игрока с Колодцем Желаний:
--   • ProximityPrompt: ActionText / ObjectText / HoldDuration
--   • Охрана от двойного открытия (per-player cooldown 5s)
--   • Блокировка во время боя
--   • Отправка RemoteEvent OpenWishingWell → клиент
-- Вращение вихря и VFX-реакция делегированы WishingWellVFX.server.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes          = ReplicatedStorage:WaitForChild("Remotes")
local rOpenWishingWell = Remotes:WaitForChild("OpenWishingWell",  10)
local rNotify          = Remotes:WaitForChild("ShowNotification", 10)

-- ============================================================
-- COOLDOWN (защита от спама)
-- ============================================================

local OPEN_COOLDOWN = 5  -- секунд между открытиями UI
local lastOpen = {}      -- [userId] = tick()

local function canOpen(player)
	local last = lastOpen[player.UserId]
	return not last or (tick() - last) >= OPEN_COOLDOWN
end

Players.PlayerRemoving:Connect(function(p)
	lastOpen[p.UserId] = nil
end)

-- ============================================================
-- ПОИСК МОДЕЛИ
-- ============================================================

local function waitForWell()
	for _ = 1, 30 do
		local lobby = workspace:FindFirstChild("Lobby")
		if lobby then
			local well = lobby:FindFirstChild("WishingWell")
			if well then return well end
		end
		task.wait(2)
	end
	warn("[WishingWellInteract] WishingWell not found")
	return nil
end

-- ============================================================
-- SETUP PROXIMITYPROMPT
-- ============================================================

local function setupPrompt(well)
	-- Ждём PrimaryPart (создаётся Setup.server.lua)
	local promptParent
	for _ = 1, 15 do
		promptParent = well.PrimaryPart
			or well:FindFirstChild("HitBox")
			or well:FindFirstChild("PrimaryPart")
		if promptParent then break end
		task.wait(1)
	end

	if not promptParent then
		-- Запасной вариант: любой BasePart
		promptParent = well:FindFirstChildWhichIsA("BasePart")
	end

	if not promptParent then
		warn("[WishingWellInteract] No BasePart for ProximityPrompt — skipping")
		return
	end

	-- Хот-релоад: убираем старый промпт
	local old = promptParent:FindFirstChildOfClass("ProximityPrompt")
	if old then old:Destroy() end

	local prompt                 = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Испытать удачу"
	prompt.ObjectText            = "Колодец Желаний"
	prompt.HoldDuration          = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight   = false
	prompt.ClickablePrompt       = true
	prompt.KeyboardKeyCode       = Enum.KeyCode.F
	prompt.GamepadKeyCode        = Enum.KeyCode.ButtonX
	prompt.Parent                = promptParent

	prompt.Triggered:Connect(function(player)
		-- 1. Бой-блок
		if _G.RoundService then
			if _G.RoundService.GetPlayerRound(player.UserId) then
				rNotify:FireClient(player, "⚔️ Колодец недоступен в бою", "warning")
				return
			end
		end

		-- 2. Cooldown-блок
		if not canOpen(player) then
			local rem = math.ceil(OPEN_COOLDOWN - (tick() - (lastOpen[player.UserId] or 0)))
			rNotify:FireClient(player,
				string.format("⏳ Колодец перезаряжается... %dс", rem), "info")
			return
		end

		lastOpen[player.UserId] = tick()

		-- 3. Открываем UI на клиенте
		rOpenWishingWell:FireClient(player)
	end)

	print("[WishingWellInteract] ProximityPrompt active on", promptParent.Name)
end

-- ============================================================
-- INIT
-- ============================================================

task.spawn(function()
	local well = waitForWell()
	if not well then return end

	setupPrompt(well)
	print("[WishingWellInteract] ✓ Initialized")
end)
