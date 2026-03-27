-- HUD.client.lua | Anime Arena: Blitz
-- Production HUD:
--   • HP-бар + Ult-заряд (левый нижний угол)
--   • Таймер раунда (верх-центр)
--   • Валютная панель: Coins / Gems / Mastery Shards (верх-правый)
--   • Stylish! виджет: ранг + анимации (центр-низ)
--     - SSS: экранный шейк + смена цвета + оверлей
--   • Mastery Level-Up попап (центр)
--   • Respawn-оверлей с отсчётом
--   • Kill Feed (правый верх)
--   • Система уведомлений (центр-верх)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local Camera       = workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ── Remotes ──────────────────────────────────────────────────
local rUpdateHUD      = Remotes:WaitForChild("UpdateHUD",           10)
local rUpdateHP       = Remotes:WaitForChild("UpdateHP",            10)
local rTakeDamage     = Remotes:WaitForChild("TakeDamage",          10)
local rPlayerDied     = Remotes:WaitForChild("PlayerDied",          10)
local rPlayerRespawn  = Remotes:WaitForChild("PlayerRespawned",     10)
local rUltCharge      = Remotes:WaitForChild("UltCharge",           10)
local rChargeUlt      = Remotes:WaitForChild("ChargeUlt",           10)
local rRoundTimer     = Remotes:WaitForChild("RoundTimer",          10)
local rRoundState     = Remotes:WaitForChild("RoundStateChanged",   10)
local rStyleRankUp    = Remotes:WaitForChild("StyleRankUp",         10)
local rShowNotif      = Remotes:WaitForChild("ShowNotification",    10)
local rShowKillFeed   = Remotes:WaitForChild("ShowKillFeed",        10)
local rGemsUpdate     = Remotes:WaitForChild("GemsUpdate",          10)
local rMasteryLevelUp = Remotes:WaitForChild("MasteryLevelUp",      10)
local rMasteryShards  = Remotes:WaitForChild("MasteryShardUpdate",  10)
local rRankUpGems     = Remotes:WaitForChild("RankUpGems",          10)
local rRankUpdate     = Remotes:WaitForChild("RankUpdate",          10)
local rRoundEnd       = Remotes:WaitForChild("RoundEnd",            10)
local rRoundStart     = Remotes:WaitForChild("RoundStart",          10)

-- ============================================================
-- КОНСТАНТЫ
-- ============================================================

local STYLE_COLORS = {
	D   = Color3.fromRGB(160, 160, 160),
	C   = Color3.fromRGB(80,  200, 120),
	B   = Color3.fromRGB(60,  160, 255),
	A   = Color3.fromRGB(180, 80,  255),
	S   = Color3.fromRGB(255, 200, 30),
	SS  = Color3.fromRGB(255, 120, 30),
	SSS = Color3.fromRGB(255, 50,  50),
}

local RANK_COLORS = {
	E   = Color3.fromRGB(120, 120, 120),
	D   = Color3.fromRGB(160, 110, 60),
	C   = Color3.fromRGB(60,  190, 80),
	B   = Color3.fromRGB(60,  140, 240),
	A   = Color3.fromRGB(170, 80,  255),
	S   = Color3.fromRGB(255, 180, 30),
	SS  = Color3.fromRGB(255, 80,  80),
	SSS = Color3.fromRGB(255, 30,  30),
}

local HP_COLOR_HIGH   = Color3.fromRGB(60,  210, 100)
local HP_COLOR_MID    = Color3.fromRGB(235, 200, 30)
local HP_COLOR_LOW    = Color3.fromRGB(230, 50,  50)
local ULT_COLOR       = Color3.fromRGB(200, 100, 255)
local COIN_COLOR      = Color3.fromRGB(255, 200, 40)
local GEM_COLOR       = Color3.fromRGB(60,  200, 255)
local SHARD_COLOR     = Color3.fromRGB(255, 100, 200)

-- ============================================================
-- GUI ROOT
-- ============================================================

local gui = Instance.new("ScreenGui")
gui.Name           = "HUD"
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 10
gui.IgnoreGuiInset = true
gui.Parent         = PlayerGui

-- ============================================================
-- HELPERS
-- ============================================================

local function label(parent, text, size, color, weight, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size                   = UDim2.new(1, 0, 1, 0)
	l.Text                   = text or ""
	l.TextColor3             = color or Color3.new(1, 1, 1)
	l.TextSize               = size or 16
	l.Font                   = weight or Enum.Font.GothamBold
	l.TextXAlignment         = align or Enum.TextXAlignment.Center
	l.TextYAlignment         = Enum.TextYAlignment.Center
	l.Parent                 = parent
	return l
end

local function frame(parent, size, pos, bg, alpha, zi, radius)
	local f = Instance.new("Frame")
	f.Size                   = size
	f.Position               = pos
	f.BackgroundColor3       = bg or Color3.new(0, 0, 0)
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel        = 0
	if zi     then f.ZIndex = zi end
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local function tween(obj, goal, t, style, dir)
	return TweenService:Create(obj,
		TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal)
end

-- ============================================================
-- ВАЛЮТНАЯ ПАНЕЛЬ (верх-правый угол)
-- ============================================================

local currencyPanel = frame(gui,
	UDim2.new(0, 240, 0, 80),
	UDim2.new(1, -250, 0, 10),
	Color3.fromRGB(10, 10, 15), 0.35, 20, 12)

-- Монеты
local coinsRow = frame(currencyPanel,
	UDim2.new(1, -12, 0, 22),
	UDim2.new(0, 6, 0, 6),
	Color3.new(), 1, 21)

local coinsIcon = Instance.new("TextLabel")
coinsIcon.Size                   = UDim2.new(0, 22, 1, 0)
coinsIcon.BackgroundTransparency = 1
coinsIcon.Text                   = "🪙"
coinsIcon.TextSize               = 16
coinsIcon.Font                   = Enum.Font.GothamBold
coinsIcon.Parent                 = coinsRow

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Size                   = UDim2.new(1, -24, 1, 0)
coinsLabel.Position               = UDim2.new(0, 24, 0, 0)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text                   = "0"
coinsLabel.TextColor3             = COIN_COLOR
coinsLabel.TextSize               = 15
coinsLabel.Font                   = Enum.Font.GothamBold
coinsLabel.TextXAlignment         = Enum.TextXAlignment.Left
coinsLabel.Parent                 = coinsRow

-- Гемы
local gemsRow = frame(currencyPanel,
	UDim2.new(1, -12, 0, 22),
	UDim2.new(0, 6, 0, 30),
	Color3.new(), 1, 21)

local gemsIcon = Instance.new("TextLabel")
gemsIcon.Size                   = UDim2.new(0, 22, 1, 0)
gemsIcon.BackgroundTransparency = 1
gemsIcon.Text                   = "💎"
gemsIcon.TextSize               = 16
gemsIcon.Font                   = Enum.Font.GothamBold
gemsIcon.Parent                 = gemsRow

local gemsLabel = Instance.new("TextLabel")
gemsLabel.Size                   = UDim2.new(1, -24, 1, 0)
gemsLabel.Position               = UDim2.new(0, 24, 0, 0)
gemsLabel.BackgroundTransparency = 1
gemsLabel.Text                   = "0"
gemsLabel.TextColor3             = GEM_COLOR
gemsLabel.TextSize               = 15
gemsLabel.Font                   = Enum.Font.GothamBold
gemsLabel.TextXAlignment         = Enum.TextXAlignment.Left
gemsLabel.Parent                 = gemsRow

-- Mastery Shards (для текущего героя)
local shardsRow = frame(currencyPanel,
	UDim2.new(1, -12, 0, 22),
	UDim2.new(0, 6, 0, 54),
	Color3.new(), 1, 21)

local shardsIcon = Instance.new("TextLabel")
shardsIcon.Size                   = UDim2.new(0, 22, 1, 0)
shardsIcon.BackgroundTransparency = 1
shardsIcon.Text                   = "✨"
shardsIcon.TextSize               = 16
shardsIcon.Font                   = Enum.Font.GothamBold
shardsIcon.Parent                 = shardsRow

local shardsLabel = Instance.new("TextLabel")
shardsLabel.Size                   = UDim2.new(1, -24, 1, 0)
shardsLabel.Position               = UDim2.new(0, 24, 0, 0)
shardsLabel.BackgroundTransparency = 1
shardsLabel.Text                   = "— Shards"
shardsLabel.TextColor3             = SHARD_COLOR
shardsLabel.TextSize               = 15
shardsLabel.Font                   = Enum.Font.GothamBold
shardsLabel.TextXAlignment         = Enum.TextXAlignment.Left
shardsLabel.Parent                 = shardsRow

-- Скрываем панель вне матча
currencyPanel.Visible = false

-- ============================================================
-- HP И ULT БЛОК (левый нижний угол)
-- ============================================================

local combatHUD = frame(gui,
	UDim2.new(0, 300, 0, 90),
	UDim2.new(0, 16, 1, -110),
	Color3.fromRGB(8, 8, 12), 0.4, 15, 10)
combatHUD.Visible = false

-- Имя героя
local heroNameLabel = label(combatHUD, "FLAME RONIN", 13,
	Color3.fromRGB(200, 200, 200), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
heroNameLabel.Size     = UDim2.new(1, -10, 0, 16)
heroNameLabel.Position = UDim2.new(0, 8, 0, 4)

-- HP фон
local hpBg = frame(combatHUD,
	UDim2.new(1, -16, 0, 18),
	UDim2.new(0, 8, 0, 24),
	Color3.fromRGB(30, 10, 10), 0, 16, 4)

-- HP заполнение
local hpFill = frame(hpBg,
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	HP_COLOR_HIGH, 0, 17, 4)

-- HP текст
local hpText = label(hpBg, "100 / 100", 12,
	Color3.new(1, 1, 1), Enum.Font.GothamBold)
hpText.ZIndex = 18

-- ULT фон
local ultBg = frame(combatHUD,
	UDim2.new(1, -16, 0, 10),
	UDim2.new(0, 8, 0, 48),
	Color3.fromRGB(20, 10, 30), 0, 16, 3)

-- ULT заполнение
local ultFill = frame(ultBg,
	UDim2.new(0, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	ULT_COLOR, 0, 17, 3)

-- ULT текст
local ultText = label(combatHUD, "ULT 0%", 11,
	Color3.fromRGB(200, 140, 255), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
ultText.Size     = UDim2.new(0.5, 0, 0, 14)
ultText.Position = UDim2.new(0, 8, 0, 62)

-- ULT READY индикатор
local ultReady = label(combatHUD, "[ R ] READY!", 12,
	Color3.fromRGB(200, 100, 255), Enum.Font.GothamBold)
ultReady.Size     = UDim2.new(0.5, 0, 0, 14)
ultReady.Position = UDim2.new(0.5, 0, 0, 62)
ultReady.Visible  = false

-- ============================================================
-- ТАЙМЕР (верх-центр)
-- ============================================================

local timerFrame = frame(gui,
	UDim2.new(0, 100, 0, 42),
	UDim2.new(0.5, -50, 0, 8),
	Color3.fromRGB(8, 8, 12), 0.45, 20, 8)
timerFrame.Visible = false

local timerLabel = label(timerFrame, "3:00", 24,
	Color3.new(1, 1, 1), Enum.Font.GothamBold)
timerLabel.ZIndex = 21

-- ============================================================
-- STYLISH! ВИДЖЕТ (центр-низ)
-- ============================================================

local styleFrame = frame(gui,
	UDim2.new(0, 200, 0, 60),
	UDim2.new(0.5, -100, 1, -180),
	Color3.new(0, 0, 0), 1, 25)
styleFrame.Visible = false

-- Фон (появляется при ранге ≥ B)
local styleBg = frame(styleFrame,
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(10, 10, 20), 0.5, 25, 8)
styleBg.BackgroundTransparency = 1

-- Ранг
local styleRankLabel = label(styleFrame, "D", 36,
	STYLE_COLORS.D, Enum.Font.GothamBlack)
styleRankLabel.Size     = UDim2.new(0, 60, 1, 0)
styleRankLabel.Position = UDim2.new(0, 0, 0, 0)
styleRankLabel.ZIndex   = 26

-- "STYLISH!" подпись
local stylishLabel = label(styleFrame, "STYLISH!", 14,
	Color3.new(1, 1, 1), Enum.Font.GothamBold)
stylishLabel.Size     = UDim2.new(1, -60, 0, 20)
stylishLabel.Position = UDim2.new(0, 62, 0, 6)
stylishLabel.ZIndex   = 26

-- Счёт стиля
local styleScoreLabel = label(styleFrame, "0 pts", 12,
	Color3.fromRGB(180, 180, 180), Enum.Font.Gotham)
styleScoreLabel.Size     = UDim2.new(1, -60, 0, 18)
styleScoreLabel.Position = UDim2.new(0, 62, 0, 28)
styleScoreLabel.ZIndex   = 26

-- SSS экранный оверлей (flash)
local sssOverlay = frame(gui,
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(255, 30, 30), 1, 30)
sssOverlay.Visible = false

-- ============================================================
-- MASTERY LEVEL-UP ПОПАП (центр)
-- ============================================================

local masteryPopup = frame(gui,
	UDim2.new(0, 340, 0, 80),
	UDim2.new(0.5, -170, 0.4, 0),
	Color3.fromRGB(10, 8, 20), 0.2, 40, 12)
masteryPopup.Visible = false

local masteryGlow = frame(masteryPopup,
	UDim2.new(1, 4, 1, 4),
	UDim2.new(0, -2, 0, -2),
	Color3.fromRGB(180, 80, 255), 0.7, 39, 14)

local masteryTitle = label(masteryPopup, "MASTERY UP!", 20,
	Color3.fromRGB(200, 120, 255), Enum.Font.GothamBlack)
masteryTitle.Size     = UDim2.new(1, 0, 0.5, 0)
masteryTitle.ZIndex   = 41

local masteryDetail = label(masteryPopup, "", 14,
	Color3.fromRGB(255, 180, 255), Enum.Font.GothamBold)
masteryDetail.Size     = UDim2.new(1, 0, 0.5, 0)
masteryDetail.Position = UDim2.new(0, 0, 0.5, 0)
masteryDetail.ZIndex   = 41

-- ============================================================
-- GEMS REWARD ПОПАП (центр-верх)
-- ============================================================

local gemsPopup = frame(gui,
	UDim2.new(0, 280, 0, 52),
	UDim2.new(0.5, -140, 0, 70),
	Color3.fromRGB(0, 20, 40), 0.2, 45, 10)
gemsPopup.Visible = false

local gemsPopupLabel = label(gemsPopup, "", 18,
	GEM_COLOR, Enum.Font.GothamBlack)
gemsPopupLabel.ZIndex = 46

-- ============================================================
-- RESPAWN ОВЕРЛЕЙ
-- ============================================================

local respawnOverlay = frame(gui,
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.new(0, 0, 0), 0.7, 50)
respawnOverlay.Visible = false

local respawnLabel = label(respawnOverlay, "YOU DIED", 40,
	Color3.fromRGB(220, 50, 50), Enum.Font.GothamBlack)
respawnLabel.Size     = UDim2.new(1, 0, 0, 50)
respawnLabel.Position = UDim2.new(0, 0, 0.4, -30)
respawnLabel.ZIndex   = 51

local respawnTimer = label(respawnOverlay, "Respawning in 5...", 22,
	Color3.new(1, 1, 1), Enum.Font.GothamBold)
respawnTimer.Size     = UDim2.new(1, 0, 0, 30)
respawnTimer.Position = UDim2.new(0, 0, 0.4, 30)
respawnTimer.ZIndex   = 51

-- ============================================================
-- KILL FEED (правый верх)
-- ============================================================

local killFeedFrame = frame(gui,
	UDim2.new(0, 260, 0, 140),
	UDim2.new(1, -270, 0, 100),
	Color3.new(), 1, 35)

local killFeedEntries = {}
local MAX_KILLFEED = 5

local function addKillFeedEntry(text, color)
	-- Сдвигаем старые вниз
	for i = MAX_KILLFEED, 2, -1 do
		if killFeedEntries[i - 1] then
			killFeedEntries[i] = killFeedEntries[i - 1]
			killFeedEntries[i].Position = UDim2.new(0, 0, 0, (i - 1) * 26)
		end
	end

	local entry = Instance.new("TextLabel")
	entry.Size                   = UDim2.new(1, 0, 0, 22)
	entry.Position               = UDim2.new(0, 0, 0, 0)
	entry.BackgroundColor3       = Color3.fromRGB(10, 10, 15)
	entry.BackgroundTransparency = 0.4
	entry.BorderSizePixel        = 0
	entry.Text                   = text
	entry.TextColor3             = color or Color3.new(1, 1, 1)
	entry.TextSize               = 12
	entry.Font                   = Enum.Font.GothamBold
	entry.TextXAlignment         = Enum.TextXAlignment.Right
	entry.ZIndex                 = 36
	entry.Parent                 = killFeedFrame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = entry

	killFeedEntries[1] = entry

	-- Фейд-аут через 4 секунды
	task.delay(4, function()
		if entry and entry.Parent then
			tween(entry, { BackgroundTransparency = 1, TextTransparency = 1 }, 0.5):Play()
			task.delay(0.5, function()
				if entry and entry.Parent then entry:Destroy() end
			end)
		end
	end)
end

-- ============================================================
-- УВЕДОМЛЕНИЯ
-- ============================================================

local notifFrame = frame(gui,
	UDim2.new(0, 360, 0, 50),
	UDim2.new(0.5, -180, 0, 120),
	Color3.new(0, 0, 0), 1, 60)
notifFrame.Visible = false

local notifLabel = label(notifFrame, "", 16,
	Color3.new(1, 1, 1), Enum.Font.GothamBold)
notifLabel.ZIndex  = 61

local notifQueue    = {}
local notifShowing  = false

local NOTIF_COLORS = {
	unlock       = Color3.fromRGB(60, 220, 255),
	rank_gems    = Color3.fromRGB(60, 200, 255),
	mastery      = Color3.fromRGB(200, 120, 255),
	mastery_up   = Color3.fromRGB(220, 100, 255),
	legendary    = Color3.fromRGB(255, 200, 30),
	fight_banner = Color3.fromRGB(255, 80, 80),
	phase_banner = Color3.fromRGB(200, 200, 200),
	default      = Color3.fromRGB(255, 255, 255),
}

local function showNextNotif()
	if notifShowing or #notifQueue == 0 then return end
	notifShowing = true

	local item = table.remove(notifQueue, 1)
	local colorType = type(item.colorOrType) == "string"
		and NOTIF_COLORS[item.colorOrType]
		or (type(item.colorOrType) == "userdata" and item.colorOrType)
		or NOTIF_COLORS.default

	notifLabel.Text       = item.message
	notifLabel.TextColor3 = colorType
	notifFrame.Visible    = true
	notifFrame.BackgroundTransparency = 1

	tween(notifFrame, { BackgroundTransparency = 0.35 }, 0.15):Play()
	task.wait(0.15)

	task.delay(2.2, function()
		tween(notifFrame, { BackgroundTransparency = 1 }, 0.3):Play()
		task.delay(0.3, function()
			notifFrame.Visible = false
			notifShowing = false
			showNextNotif()
		end)
	end)
end

rShowNotif.OnClientEvent:Connect(function(message, colorOrType)
	table.insert(notifQueue, { message = tostring(message), colorOrType = colorOrType })
	showNextNotif()
end)

-- ============================================================
-- СОСТОЯНИЕ
-- ============================================================

local currentHP    = 100
local currentMaxHP = 100
local currentUlt   = 0
local inMatch      = false
local currentShards = 0
local currentHeroId = nil

-- ============================================================
-- HP-ЛОГИКА
-- ============================================================

local function updateHP(hp, maxHp)
	currentHP    = hp
	currentMaxHP = maxHp
	local ratio  = maxHp > 0 and math.max(0, hp / maxHp) or 0

	tween(hpFill, { Size = UDim2.new(ratio, 0, 1, 0) }, 0.12):Play()
	hpText.Text = string.format("%d / %d", math.floor(hp), math.floor(maxHp))

	local col
	if ratio > 0.5 then
		col = HP_COLOR_HIGH
	elseif ratio > 0.25 then
		col = HP_COLOR_MID
	else
		col = HP_COLOR_LOW
	end
	tween(hpFill, { BackgroundColor3 = col }, 0.2):Play()
end

local function updateUlt(charge)
	currentUlt = charge
	local ratio = math.max(0, math.min(1, charge / 100))
	tween(ultFill, { Size = UDim2.new(ratio, 0, 1, 0) }, 0.15):Play()
	ultText.Text    = string.format("ULT %d%%", math.floor(charge))
	ultReady.Visible = charge >= 100

	if charge >= 100 then
		-- Пульс-анимация
		tween(ultFill, { BackgroundColor3 = Color3.fromRGB(255, 150, 255) }, 0.3):Play()
		task.delay(0.3, function()
			tween(ultFill, { BackgroundColor3 = ULT_COLOR }, 0.3):Play()
		end)
	end
end

-- ============================================================
-- СТИЛЬ
-- ============================================================

local currentStyleRank = "D"
local styleAutoHideTask

local function hideStyleWidget()
	tween(styleFrame, { Position = UDim2.new(0.5, -100, 1, -160) }, 0.3):Play()
	tween(styleBg,    { BackgroundTransparency = 1 }, 0.3):Play()
end

local function showStyleWidget(rank, score)
	if rank == "D" then
		hideStyleWidget()
		return
	end

	local col = STYLE_COLORS[rank] or Color3.new(1,1,1)
	styleFrame.Visible     = true
	styleRankLabel.Text       = rank
	styleRankLabel.TextColor3 = col
	styleScoreLabel.Text      = score and (tostring(math.floor(score)) .. " pts") or ""

	-- Анимация pop-in
	styleFrame.Position = UDim2.new(0.5, -100, 1, -155)
	tween(styleFrame, { Position = UDim2.new(0.5, -100, 1, -180) }, 0.2,
		Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
	tween(styleBg, { BackgroundTransparency = 0.5 }, 0.2):Play()
	styleBg.BackgroundColor3 = col

	-- SSS: экранный шейк + оверлей
	if rank == "SSS" then
		sssOverlay.Visible              = true
		sssOverlay.BackgroundTransparency = 0.85
		tween(sssOverlay, { BackgroundTransparency = 1 }, 0.6):Play()
		task.delay(0.6, function() sssOverlay.Visible = false end)

		-- Шейк камеры
		task.spawn(function()
			local originalCFrame = Camera.CFrame
			for i = 1, 6 do
				local offset = CFrame.new(
					math.random(-3, 3) * 0.05,
					math.random(-3, 3) * 0.05,
					0)
				Camera.CFrame = Camera.CFrame * offset
				task.wait(0.03)
			end
		end)
	end

	-- Авто-скрытие через 3 секунды без активности
	if styleAutoHideTask then
		task.cancel(styleAutoHideTask)
	end
	styleAutoHideTask = task.delay(3, hideStyleWidget)
end

rStyleRankUp.OnClientEvent:Connect(function(rank, score)
	if rank ~= currentStyleRank then
		currentStyleRank = rank
		if inMatch then
			showStyleWidget(rank, score)
		end
	end
end)

-- ============================================================
-- ТАЙМЕР
-- ============================================================

rRoundTimer.OnClientEvent:Connect(function(seconds)
	timerFrame.Visible = true
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	timerLabel.Text = string.format("%d:%02d", mins, secs)

	-- Красный при < 30 секунд
	if seconds <= 30 then
		timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	else
		timerLabel.TextColor3 = Color3.new(1, 1, 1)
	end
end)

-- ============================================================
-- ФАЗЫ РАУНДА
-- ============================================================

rRoundState.OnClientEvent:Connect(function(phase)
	if phase == "Battle" then
		inMatch        = true
		combatHUD.Visible     = true
		timerFrame.Visible    = true
		currencyPanel.Visible = true
		currentStyleRank      = "D"
	elseif phase == "Conclusion" then
		inMatch = false
		timerFrame.Visible = false
		hideStyleWidget()
		task.delay(1.5, function()
			combatHUD.Visible = false
		end)
	elseif phase == "Preparation" then
		currencyPanel.Visible = true
	end
end)

rRoundStart.OnClientEvent:Connect(function()
	-- Сброс при старте нового раунда
	currentStyleRank = "D"
	hideStyleWidget()
	styleFrame.Visible = false
end)

rRoundEnd.OnClientEvent:Connect(function(resultData)
	timerFrame.Visible = false
	inMatch = false

	-- Обновляем shards из наград, если есть
	if resultData and resultData.rewards then
		-- masteryXP отображается отдельно через MasteryLevelUp
	end
end)

-- ============================================================
-- HP / ULT ИВЕНТЫ
-- ============================================================

rUpdateHP.OnClientEvent:Connect(function(hp, maxHp)
	updateHP(hp, maxHp)
end)

rTakeDamage.OnClientEvent:Connect(function(newHP, maxHP, amount)
	updateHP(newHP, maxHP)

	-- Красный флеш при уроне
	local flash = frame(gui,
		UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0),
		Color3.fromRGB(200, 0, 0), 0.8, 55)
	flash.Visible = true
	tween(flash, { BackgroundTransparency = 1 }, 0.25):Play()
	task.delay(0.25, function()
		if flash and flash.Parent then flash:Destroy() end
	end)
end)

rUltCharge.OnClientEvent:Connect(function(charge) updateUlt(charge) end)
rChargeUlt.OnClientEvent:Connect(function(charge) updateUlt(charge) end)

-- ============================================================
-- UpdateHUD — универсальный апдейт
-- ============================================================

rUpdateHUD.OnClientEvent:Connect(function(data)
	if not data then return end

	if data.hp ~= nil and data.maxHp ~= nil then
		updateHP(data.hp, data.maxHp)
	end
	if data.ultCharge ~= nil then
		updateUlt(data.ultCharge)
	end
	if data.coins ~= nil then
		coinsLabel.Text = tostring(math.floor(data.coins))
	end
	if data.gems ~= nil then
		gemsLabel.Text = tostring(math.floor(data.gems))
	end
	if data.rank ~= nil then
		-- Обновляем индикатор ранга в UI (можно дополнить)
	end

	-- Показываем панель если данные пришли
	currencyPanel.Visible = true
end)

-- ============================================================
-- СМЕРТЬ / РЕСПАВН
-- ============================================================

rPlayerDied.OnClientEvent:Connect(function(victimId, killerId, respawnTime)
	local localId = LocalPlayer.UserId
	if victimId ~= localId then
		-- Kill feed: кто-то убит
		local victimName = "Player#" .. victimId
		local killerName = killerId and killerId ~= 0 and ("Player#" .. killerId) or "?"
		local vPlayer = Players:GetPlayerByUserId(victimId)
		local kPlayer = Players:GetPlayerByUserId(killerId)
		if vPlayer then victimName = vPlayer.Name end
		if kPlayer then killerName = kPlayer.Name end
		addKillFeedEntry(string.format("💀 %s → %s", killerName, victimName),
			Color3.fromRGB(255, 150, 150))
		return
	end

	-- Я умер
	respawnOverlay.Visible = true
	local timeLeft = respawnTime or 5
	respawnTimer.Text = string.format("Respawning in %d...", timeLeft)

	task.spawn(function()
		while timeLeft > 0 and respawnOverlay.Visible do
			task.wait(1)
			timeLeft -= 1
			respawnTimer.Text = timeLeft > 0
				and string.format("Respawning in %d...", timeLeft)
				or "Respawning..."
		end
	end)
end)

rPlayerRespawn.OnClientEvent:Connect(function()
	respawnOverlay.Visible = false
	updateHP(currentMaxHP, currentMaxHP)
	updateUlt(0)
	currentStyleRank = "D"
end)

-- ============================================================
-- KILL FEED ивент
-- ============================================================

rShowKillFeed.OnClientEvent:Connect(function(killerName, victimName)
	addKillFeedEntry(string.format("⚔️ %s  →  %s", killerName, victimName),
		Color3.fromRGB(255, 200, 100))
end)

-- ============================================================
-- GEMS ИВЕНТЫ
-- ============================================================

rGemsUpdate.OnClientEvent:Connect(function(newAmount, delta, reason)
	gemsLabel.Text = tostring(math.floor(newAmount or 0))

	-- Анимация +delta если прибавляем
	if delta and delta > 0 then
		tween(gemsLabel, { TextColor3 = Color3.fromRGB(150, 255, 255) }, 0.15):Play()
		task.delay(0.15, function()
			tween(gemsLabel, { TextColor3 = GEM_COLOR }, 0.3):Play()
		end)
	end
end)

rRankUpGems.OnClientEvent:Connect(function(rank, gemsAmount)
	gemsPopupLabel.Text = string.format("🏆 Rank %s! + %d 💎", rank, gemsAmount)
	gemsPopup.Visible   = true

	local rankCol = RANK_COLORS[rank] or Color3.new(1, 1, 1)
	gemsPopupLabel.TextColor3 = rankCol

	gemsPopup.Position = UDim2.new(0.5, -140, 0, 60)
	tween(gemsPopup, { Position = UDim2.new(0.5, -140, 0, 70) }, 0.3,
		Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()

	task.delay(3, function()
		if gemsPopup then
			tween(gemsPopup, { Position = UDim2.new(0.5, -140, 0, 50) }, 0.25):Play()
			task.delay(0.25, function()
				if gemsPopup then gemsPopup.Visible = false end
			end)
		end
	end)
end)

-- ============================================================
-- MASTERY ИВЕНТЫ
-- ============================================================

rMasteryLevelUp.OnClientEvent:Connect(function(heroId, newLevel, shardsEarned)
	currentHeroId = heroId

	masteryTitle.Text = string.format("✨ %s  LV %d", heroId, newLevel)
	masteryDetail.Text = string.format("+ %d Mastery Shards", shardsEarned)

	masteryPopup.Visible  = true
	masteryPopup.Position = UDim2.new(0.5, -170, 0.4, 20)

	tween(masteryPopup, { Position = UDim2.new(0.5, -170, 0.4, 0) }, 0.35,
		Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
	tween(masteryGlow, { BackgroundTransparency = 0.3 }, 0.2):Play()

	task.delay(3.5, function()
		if masteryPopup then
			tween(masteryPopup, { Position = UDim2.new(0.5, -170, 0.4, -20) }, 0.25):Play()
			tween(masteryGlow, { BackgroundTransparency = 1 }, 0.25):Play()
			task.delay(0.25, function()
				if masteryPopup then masteryPopup.Visible = false end
			end)
		end
	end)
end)

rMasteryShards.OnClientEvent:Connect(function(heroId, newShards, delta)
	currentHeroId   = heroId
	currentShards   = newShards
	shardsLabel.Text = string.format("%d ✨", math.floor(newShards))
	currencyPanel.Visible = true

	-- Мигание при изменении
	if delta and delta > 0 then
		tween(shardsLabel, { TextColor3 = Color3.fromRGB(255, 180, 255) }, 0.15):Play()
		task.delay(0.15, function()
			tween(shardsLabel, { TextColor3 = SHARD_COLOR }, 0.3):Play()
		end)
	end
end)

-- ============================================================
-- RANK UPDATE
-- ============================================================

rRankUpdate.OnClientEvent:Connect(function(oldRank, newRank, newRP)
	-- Флеш ранга при повышении
	if oldRank ~= newRank then
		local col = RANK_COLORS[newRank] or Color3.new(1, 1, 1)
		local flash = frame(gui,
			UDim2.new(1, 0, 1, 0),
			UDim2.new(0, 0, 0, 0),
			col, 0.9, 70)

		local rankFlashLabel = label(flash,
			string.format("RANK UP!  %s → %s", oldRank, newRank),
			28, col, Enum.Font.GothamBlack)
		rankFlashLabel.ZIndex = 71

		tween(flash, { BackgroundTransparency = 1 }, 0.8):Play()
		task.delay(0.8, function()
			if flash and flash.Parent then flash:Destroy() end
		end)
	end
end)

-- ============================================================
-- ФИНАЛЬНАЯ ИНИЦИАЛИЗАЦИЯ
-- ============================================================

-- Запрашиваем данные при загрузке
task.delay(2, function()
	local rGetUserData = Remotes:FindFirstChild("GetUserData")
	if rGetUserData then
		local ok, data = pcall(function()
			return rGetUserData:InvokeServer()
		end)
		if ok and data then
			if data.coins ~= nil then
				coinsLabel.Text = tostring(math.floor(data.coins))
			end
			if data.gems ~= nil then
				gemsLabel.Text = tostring(math.floor(data.gems))
			end
			currencyPanel.Visible = true
		end
	end
end)

print("[HUD] Initialized ✓ — Currency Triangle (Coins / Gems / Mastery Shards)")
