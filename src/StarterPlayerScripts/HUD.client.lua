-- HUD.client.lua | Anime Arena: Blitz
-- FIX-1: HUD скрыт в лобби, появляется по RoundStart / RoundStateChanged("Battle")
-- FIX-2: Таймер ZIndex=8 (не перекрывает лого)
-- FIX-3: 4 раздельных слоя уведомлений — надписи не накладываются
--   • notifyToast   — мелкие системные ("Бот подключается...", info/warning)
--   • phaseBanner   — "GET READY!" — под таймером, серый
--   • fightBanner   — "FIGHT!" — центр экрана, крупно, зелёный
--   • countdownBig  — 3..2..1 — центр, ещё крупнее
-- FIX-4: респавн оверлей скрывается по PlayerRespawned

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local rTakeDamage    = Remotes:WaitForChild("TakeDamage",          10)
local rUpdateHP      = Remotes:WaitForChild("UpdateHP",            10)
local rHeal          = Remotes:WaitForChild("Heal",                10)
local rUpdateHUD     = Remotes:WaitForChild("UpdateHUD",           10)
local rRoundTimer    = Remotes:WaitForChild("RoundTimer",          10)
local rRoundStart    = Remotes:WaitForChild("RoundStart",          10)
local rRoundEnd      = Remotes:WaitForChild("RoundEnd",            10)
local rRoundState    = Remotes:WaitForChild("RoundStateChanged",   10)
local rPlayerDied    = Remotes:WaitForChild("PlayerDied",          10)
local rPlayerRespawn = Remotes:WaitForChild("PlayerRespawned",     10)
local rSkillResult   = Remotes:WaitForChild("SkillResult",         10)
local rUltCharge     = Remotes:WaitForChild("UltCharge",           10)
local rChargeUlt     = Remotes:WaitForChild("ChargeUlt",           10)
local rKillFeed      = Remotes:WaitForChild("ShowKillFeed",        10)
local rNotify        = Remotes:WaitForChild("ShowNotification",    10)

-- ============================================================
-- STATE
-- ============================================================

local currentHP   = 100
local maxHP       = 100
local ultCharge   = 0
local skillCDs    = { Q=0, E=0, F=0, R=0 }
local skillMaxCDs = { Q=8, E=12, F=16, R=30 }
local killFeedEntries = {}
local inBattle    = false

-- ============================================================
-- GUI ROOT
-- ============================================================

local gui = Instance.new("ScreenGui")
gui.Name           = "HUD"
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 15
gui.IgnoreGuiInset = true
gui.Enabled        = true
gui.Parent         = PlayerGui

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end
local function stroke(p, col, th)
	local s = Instance.new("UIStroke")
	s.Color = col
	s.Thickness = th or 1.5
	s.Parent = p
end
local function tween(inst, t, props, style)
	return TweenService:Create(inst,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props)
end

-- ============================================================
-- HP BAR
-- ============================================================

-- LAYOUT (снизу вверх, отступ 10px от края):
--   skillPanel  : h=72  → Y = 1, -82   (10px от низа)
--   ultContainer: h=18  → Y = 1, -108  (8px зазор)
--   hpContainer : h=40  → Y = 1, -156  (8px зазор)

local hpContainer = Instance.new("Frame")
hpContainer.Size             = UDim2.new(0, 360, 0, 40)
hpContainer.Position         = UDim2.new(0.5, -180, 1, -156)
hpContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 24)
hpContainer.BorderSizePixel  = 0
hpContainer.Visible          = false
hpContainer.Parent           = gui
corner(hpContainer, 10)
stroke(hpContainer, Color3.fromRGB(40, 40, 70), 1.5)

-- FIX: бар HP опущен вниз чтобы не перекрывался с текстом
local hpTrack = Instance.new("Frame")
hpTrack.Size             = UDim2.new(1, -12, 0, 12)
hpTrack.Position         = UDim2.new(0, 6, 1, -16)
hpTrack.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
hpTrack.BorderSizePixel  = 0
hpTrack.Parent           = hpContainer
corner(hpTrack, 5)

local hpFill = Instance.new("Frame")
hpFill.Size             = UDim2.new(1, 0, 1, 0)
hpFill.BackgroundColor3 = Color3.fromRGB(80, 210, 80)
hpFill.BorderSizePixel  = 0
hpFill.Parent           = hpTrack
corner(hpFill, 5)

-- FIX: текст HP внутри контейнера (не вылезает за его границы)
local hpText = Instance.new("TextLabel")
hpText.Size                   = UDim2.new(1, -12, 0, 16)
hpText.Position               = UDim2.new(0, 6, 0, 3)
hpText.BackgroundTransparency = 1
hpText.Text                   = "100 / 100"
hpText.TextSize               = 12
hpText.TextColor3             = Color3.new(1, 1, 1)
hpText.Font                   = Enum.Font.GothamBold
hpText.TextXAlignment         = Enum.TextXAlignment.Center
hpText.Parent                 = hpContainer

-- ============================================================
-- ULT BAR
-- ============================================================

local ultContainer = Instance.new("Frame")
ultContainer.Size             = UDim2.new(0, 360, 0, 18)
ultContainer.Position         = UDim2.new(0.5, -180, 1, -108)
ultContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 24)
ultContainer.BorderSizePixel  = 0
ultContainer.Visible          = false
ultContainer.Parent           = gui
corner(ultContainer, 6)
stroke(ultContainer, Color3.fromRGB(60, 40, 20), 1.5)

local ultTrack = Instance.new("Frame")
ultTrack.Size             = UDim2.new(1, -10, 0, 8)
ultTrack.Position         = UDim2.new(0, 5, 0.5, -4)
ultTrack.BackgroundColor3 = Color3.fromRGB(25, 20, 10)
ultTrack.BorderSizePixel  = 0
ultTrack.Parent           = ultContainer
corner(ultTrack, 4)

local ultFill = Instance.new("Frame")
ultFill.Size             = UDim2.new(0, 0, 1, 0)
ultFill.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
ultFill.BorderSizePixel  = 0
ultFill.Parent           = ultTrack
corner(ultFill, 4)

local ultLabel = Instance.new("TextLabel")
ultLabel.Size                   = UDim2.new(0, 40, 1, 0)
ultLabel.Position               = UDim2.new(1, -44, 0, 0)
ultLabel.BackgroundTransparency = 1
ultLabel.Text                   = "0%"
ultLabel.TextSize               = 11
ultLabel.TextColor3             = Color3.fromRGB(255, 200, 80)
ultLabel.Font                   = Enum.Font.GothamBold
ultLabel.TextXAlignment         = Enum.TextXAlignment.Right
ultLabel.Parent                 = ultContainer

-- ============================================================
-- SKILL PANEL Q / E / F / R
-- ============================================================

local SLOTS = { "Q", "E", "F", "R" }
local SLOT_COLORS = {
	Q = Color3.fromRGB(80,  160, 255),
	E = Color3.fromRGB(80,  220, 80),
	F = Color3.fromRGB(255, 160, 40),
	R = Color3.fromRGB(255, 60,  60),
}

local skillFrames = {}

local skillPanel = Instance.new("Frame")
skillPanel.Size                   = UDim2.new(0, 300, 0, 72)
skillPanel.Position               = UDim2.new(0.5, -150, 1, -82)
skillPanel.BackgroundTransparency = 1
skillPanel.Visible                = false
skillPanel.Parent                 = gui

local spLayout = Instance.new("UIListLayout")
spLayout.FillDirection       = Enum.FillDirection.Horizontal
spLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
spLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
spLayout.Padding             = UDim.new(0, 6)
spLayout.Parent              = skillPanel

for _, slot in ipairs(SLOTS) do
	local isUlt = (slot == "R")
	local sz    = isUlt and 68 or 60

	local frame = Instance.new("Frame")
	frame.Size             = UDim2.new(0, sz, 0, sz)
	frame.BackgroundColor3 = Color3.fromRGB(12, 12, 24)
	frame.BorderSizePixel  = 0
	frame.Parent           = skillPanel
	corner(frame, isUlt and 10 or 8)
	stroke(frame, SLOT_COLORS[slot], isUlt and 2 or 1.5)

	local keyLbl = Instance.new("TextLabel")
	keyLbl.Size                   = UDim2.new(1, 0, 0, 20)
	keyLbl.BackgroundTransparency = 1
	keyLbl.Text                   = slot
	keyLbl.TextSize               = isUlt and 18 or 15
	keyLbl.TextColor3             = SLOT_COLORS[slot]
	keyLbl.Font                   = Enum.Font.GothamBold
	keyLbl.TextXAlignment         = Enum.TextXAlignment.Center
	keyLbl.Parent                 = frame

	local cdOverlay = Instance.new("Frame")
	cdOverlay.Size                   = UDim2.new(1, 0, 1, 0)
	cdOverlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	cdOverlay.BackgroundTransparency = 1
	cdOverlay.BorderSizePixel        = 0
	cdOverlay.ZIndex                 = 3
	cdOverlay.Parent                 = frame
	corner(cdOverlay, isUlt and 10 or 8)

	local cdText = Instance.new("TextLabel")
	cdText.Size                   = UDim2.new(1, 0, 1, 0)
	cdText.BackgroundTransparency = 1
	cdText.Text                   = ""
	cdText.TextSize               = 15
	cdText.TextColor3             = Color3.new(1, 1, 1)
	cdText.Font                   = Enum.Font.GothamBold
	cdText.TextXAlignment         = Enum.TextXAlignment.Center
	cdText.ZIndex                 = 4
	cdText.Parent                 = cdOverlay

	skillFrames[slot] = { frame = frame, key = keyLbl, overlay = cdOverlay, cdText = cdText }
end

-- ============================================================
-- MATCH TIMER (ZIndex=8, не перекрывает LobbyUI лого)
-- ============================================================

local timerFrame = Instance.new("Frame")
timerFrame.Size             = UDim2.new(0, 110, 0, 42)
timerFrame.Position         = UDim2.new(0.5, -55, 0, 14)
timerFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
timerFrame.BorderSizePixel  = 0
timerFrame.Visible          = false
timerFrame.ZIndex           = 8
timerFrame.Parent           = gui
corner(timerFrame, 10)
stroke(timerFrame, Color3.fromRGB(50, 50, 90), 1.5)

local timerLbl = Instance.new("TextLabel")
timerLbl.Size                   = UDim2.new(1, 0, 1, 0)
timerLbl.BackgroundTransparency = 1
timerLbl.Text                   = "3:00"
timerLbl.TextSize               = 22
timerLbl.TextColor3             = Color3.fromRGB(255, 220, 80)
timerLbl.Font                   = Enum.Font.GothamBold
timerLbl.TextXAlignment         = Enum.TextXAlignment.Center
timerLbl.ZIndex                 = 9
timerLbl.Parent                 = timerFrame

-- Цвет таймера в режиме подготовки (серый)
local TIMER_COLOR_BATTLE = Color3.fromRGB(255, 220, 80)
local TIMER_COLOR_PREP   = Color3.fromRGB(130, 130, 150)
local TIMER_COLOR_LOW    = Color3.fromRGB(255, 80,  60)

-- ============================================================
-- MODE BADGE
-- ============================================================

local modeBadge = Instance.new("Frame")
modeBadge.Size             = UDim2.new(0, 140, 0, 28)
modeBadge.Position         = UDim2.new(0, 14, 0, 14)
modeBadge.BackgroundColor3 = Color3.fromRGB(30, 140, 255)
modeBadge.BorderSizePixel  = 0
modeBadge.Visible          = false
modeBadge.Parent           = gui
corner(modeBadge, 6)

local modeLbl = Instance.new("TextLabel")
modeLbl.Size                   = UDim2.new(1, 0, 1, 0)
modeLbl.BackgroundTransparency = 1
modeLbl.Text                   = "NORMAL MODE"
modeLbl.TextSize               = 12
modeLbl.TextColor3             = Color3.new(1, 1, 1)
modeLbl.Font                   = Enum.Font.GothamBold
modeLbl.TextXAlignment         = Enum.TextXAlignment.Center
modeLbl.Parent                 = modeBadge

-- ============================================================
-- KILL FEED
-- ============================================================

local killFeedFrame = Instance.new("Frame")
killFeedFrame.Size                   = UDim2.new(0, 260, 0, 160)
killFeedFrame.Position               = UDim2.new(1, -274, 0, 14)
killFeedFrame.BackgroundTransparency = 1
killFeedFrame.Visible                = false
killFeedFrame.Parent                 = gui

local kfLayout = Instance.new("UIListLayout")
kfLayout.SortOrder         = Enum.SortOrder.LayoutOrder
kfLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
kfLayout.Padding           = UDim.new(0, 4)
kfLayout.Parent            = killFeedFrame

local function addKillFeedEntry(killer, victim)
	local row = Instance.new("Frame")
	row.Size                   = UDim2.new(1, 0, 0, 26)
	row.BackgroundColor3       = Color3.fromRGB(10, 10, 20)
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel        = 0
	row.LayoutOrder            = #killFeedEntries
	row.Parent                 = killFeedFrame
	corner(row, 5)
	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, -8, 1, 0)
	lbl.Position               = UDim2.new(0, 4, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = killer .. "  →  " .. victim
	lbl.TextSize               = 12
	lbl.TextColor3             = Color3.new(1, 1, 1)
	lbl.Font                   = Enum.Font.GothamBold
	lbl.TextXAlignment         = Enum.TextXAlignment.Right
	lbl.Parent                 = row
	table.insert(killFeedEntries, row)
	task.delay(4, function()
		if not row.Parent then return end
		tween(row, 0.4, { BackgroundTransparency = 1 }):Play()
		tween(lbl, 0.4, { TextTransparency = 1 }):Play()
		task.delay(0.45, function()
			local idx = table.find(killFeedEntries, row)
			if idx then table.remove(killFeedEntries, idx) end
			row:Destroy()
		end)
	end)
end

-- ============================================================
-- RESPAWN OVERLAY
-- ============================================================

local respawnOverlay = Instance.new("Frame")
respawnOverlay.Size                   = UDim2.new(1, 0, 1, 0)
respawnOverlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
respawnOverlay.BackgroundTransparency = 1
respawnOverlay.ZIndex                 = 40
respawnOverlay.Visible                = false
respawnOverlay.Parent                 = gui

local respawnLbl = Instance.new("TextLabel")
respawnLbl.Size                   = UDim2.new(1, 0, 0, 80)
respawnLbl.Position               = UDim2.new(0, 0, 0.5, -40)
respawnLbl.BackgroundTransparency = 1
respawnLbl.Text                   = "Возрождение через 5..."
respawnLbl.TextSize               = 34
respawnLbl.TextColor3             = Color3.new(1, 1, 1)
respawnLbl.Font                   = Enum.Font.GothamBold
respawnLbl.TextXAlignment         = Enum.TextXAlignment.Center
respawnLbl.ZIndex                 = 41
respawnLbl.Parent                 = respawnOverlay

local respawnThread = nil

-- ============================================================
-- NOTIFICATION LAYERS (FIX-3: 4 раздельных слоя)
-- ============================================================

-- Слой 1: маленький toast вверху (системные сообщения: "Бот подключается", предупреждения)
local notifyToast = Instance.new("TextLabel")
notifyToast.Size                   = UDim2.new(0, 380, 0, 36)
notifyToast.Position               = UDim2.new(0.5, -190, 0, 70)  -- под таймером
notifyToast.BackgroundColor3       = Color3.fromRGB(14, 14, 28)
notifyToast.BackgroundTransparency = 1
notifyToast.Text                   = ""
notifyToast.TextSize               = 14
notifyToast.TextColor3             = Color3.new(1, 1, 1)
notifyToast.Font                   = Enum.Font.GothamBold
notifyToast.TextXAlignment         = Enum.TextXAlignment.Center
notifyToast.BorderSizePixel        = 0
notifyToast.ZIndex                 = 20
notifyToast.Parent                 = gui
corner(notifyToast, 8)

-- Слой 2: баннер фазы "GET READY!" — центр экрана под отсчётом
local phaseBanner = Instance.new("TextLabel")
phaseBanner.Size                   = UDim2.new(0, 500, 0, 60)
phaseBanner.Position               = UDim2.new(0.5, -250, 0.38, 0)
phaseBanner.BackgroundColor3       = Color3.fromRGB(10, 10, 20)
phaseBanner.BackgroundTransparency = 1
phaseBanner.Text                   = ""
phaseBanner.TextSize               = 32
phaseBanner.TextColor3             = Color3.fromRGB(180, 180, 210)
phaseBanner.Font                   = Enum.Font.GothamBold
phaseBanner.TextXAlignment         = Enum.TextXAlignment.Center
phaseBanner.BorderSizePixel        = 0
phaseBanner.ZIndex                 = 25
phaseBanner.Parent                 = gui

-- Слой 3: FIGHT! — крупно, центр, зелёный
local fightBanner = Instance.new("TextLabel")
fightBanner.Size                   = UDim2.new(0, 500, 0, 80)
fightBanner.Position               = UDim2.new(0.5, -250, 0.36, 0)
fightBanner.BackgroundTransparency = 1
fightBanner.Text                   = ""
fightBanner.TextSize               = 72
fightBanner.TextColor3             = Color3.fromRGB(80, 255, 120)
fightBanner.Font                   = Enum.Font.GothamBold
fightBanner.TextXAlignment         = Enum.TextXAlignment.Center
fightBanner.TextStrokeTransparency = 0.4
fightBanner.TextStrokeColor3       = Color3.fromRGB(0, 80, 0)
fightBanner.BorderSizePixel        = 0
fightBanner.ZIndex                 = 26
fightBanner.Parent                 = gui

-- Слой 4: 3..2..1 — ещё крупнее, центр, жёлтый
local countdownBig = Instance.new("TextLabel")
countdownBig.Size                   = UDim2.new(0, 200, 0, 120)
countdownBig.Position               = UDim2.new(0.5, -100, 0.33, 0)
countdownBig.BackgroundTransparency = 1
countdownBig.Text                   = ""
countdownBig.TextSize               = 100
countdownBig.TextColor3             = Color3.fromRGB(255, 220, 60)
countdownBig.Font                   = Enum.Font.GothamBold
countdownBig.TextXAlignment         = Enum.TextXAlignment.Center
countdownBig.TextStrokeTransparency = 0.3
countdownBig.TextStrokeColor3       = Color3.fromRGB(120, 80, 0)
countdownBig.BorderSizePixel        = 0
countdownBig.ZIndex                 = 27
countdownBig.Parent                 = gui

-- ============================================================
-- NOTIFICATION HELPERS
-- ============================================================

local toastThread = nil
local function showToast(msg, col)
	if toastThread then task.cancel(toastThread) end
	notifyToast.Text       = msg
	notifyToast.TextColor3 = col or Color3.new(1, 1, 1)
	tween(notifyToast, 0.15, { BackgroundTransparency = 0.15 }):Play()
	toastThread = task.delay(2.5, function()
		tween(notifyToast, 0.4, { BackgroundTransparency = 1 }):Play()
		task.delay(0.45, function() notifyToast.Text = "" end)
	end)
end

local function showPhaseBanner(msg)
	phaseBanner.Text         = msg
	phaseBanner.TextTransparency = 1
	tween(phaseBanner, 0.25, { TextTransparency = 0 }):Play()
	task.delay(2.5, function()
		tween(phaseBanner, 0.5, { TextTransparency = 1 }):Play()
		task.delay(0.55, function() phaseBanner.Text = "" end)
	end)
end

local function showFightBanner()
	fightBanner.Text            = "FIGHT!"
	fightBanner.TextTransparency = 1
	fightBanner.Size            = UDim2.new(0, 300, 0, 80)
	-- Взрыв — появляется быстро, улетает с масштабом
	tween(fightBanner, 0.12, {
		TextTransparency = 0,
		Size = UDim2.new(0, 500, 0, 80),
	}, Enum.EasingStyle.Back):Play()
	task.delay(1.0, function()
		tween(fightBanner, 0.35, { TextTransparency = 1 }):Play()
		task.delay(0.4, function() fightBanner.Text = "" end)
	end)
end

local cdbigThread = nil
local function showCountdownBig(num)
	if cdbigThread then task.cancel(cdbigThread) end
	countdownBig.Text            = tostring(num)
	countdownBig.TextTransparency = 0
	countdownBig.Size            = UDim2.new(0, 120, 0, 120)
	tween(countdownBig, 0.8, {
		Size             = UDim2.new(0, 200, 0, 120),
		TextTransparency = 1,
	}, Enum.EasingStyle.Quad):Play()
	cdbigThread = task.delay(0.85, function() countdownBig.Text = "" end)
end

-- ============================================================
-- HP UPDATE
-- ============================================================

local function updateHP(hp, mhp)
	hp  = math.max(0, hp  or currentHP)
	mhp = math.max(1, mhp or maxHP)
	currentHP = hp
	maxHP     = mhp
	local pct = hp / mhp
	local col
	if pct > 0.5 then
		col = Color3.fromRGB(80, 210, 80)
	elseif pct > 0.25 then
		col = Color3.fromRGB(255, 160, 40)
	else
		col = Color3.fromRGB(220, 50, 50)
	end
	tween(hpFill, 0.18, {
		Size             = UDim2.new(pct, 0, 1, 0),
		BackgroundColor3 = col,
	}):Play()
	hpText.Text = string.format("%d / %d", math.ceil(hp), mhp)
end

-- ============================================================
-- SHOW / HIDE HUD
-- ============================================================

local function showHUD(mode)
	inBattle             = true
	hpContainer.Visible  = true
	ultContainer.Visible = true
	skillPanel.Visible   = true
	timerFrame.Visible   = true
	killFeedFrame.Visible = true
	modeBadge.Visible    = true
	if mode then
		modeLbl.Text = (mode:upper()) .. " MODE"
		if mode == "OneHit" then
			modeBadge.BackgroundColor3 = Color3.fromRGB(210, 50, 30)
		elseif mode == "Ranked" then
			modeBadge.BackgroundColor3 = Color3.fromRGB(200, 160, 30)
		else
			modeBadge.BackgroundColor3 = Color3.fromRGB(30, 140, 255)
		end
	end
end

local function hideHUD()
	inBattle              = false
	hpContainer.Visible   = false
	ultContainer.Visible  = false
	skillPanel.Visible    = false
	timerFrame.Visible    = false
	killFeedFrame.Visible = false
	modeBadge.Visible     = false
	respawnOverlay.Visible = false
	-- Очищаем все баннеры
	phaseBanner.Text   = ""
	fightBanner.Text   = ""
	countdownBig.Text  = ""
	notifyToast.Text   = ""
end

-- ============================================================
-- COOLDOWN TICK
-- ============================================================

RunService.Heartbeat:Connect(function()
	if not inBattle then return end
	local now = tick()
	for _, slot in ipairs(SLOTS) do
		local sf = skillFrames[slot]
		if not sf then continue end
		local remaining = math.max(0, skillCDs[slot] - now)
		if remaining > 0 then
			sf.cdText.Text                    = string.format("%.1f", remaining)
			sf.overlay.BackgroundTransparency = 0.5
		else
			sf.cdText.Text                    = ""
			sf.overlay.BackgroundTransparency = 1
		end
	end
end)

-- ============================================================
-- REMOTE HANDLERS
-- ============================================================

rRoundStart.OnClientEvent:Connect(function(leftHeroId, leftName, rightHeroId, rightName, mode)
	-- ИСПРАВЛЕНИЕ #3: принудительный сброс кулдаунов и ульта при старте интро
	-- skillCDs не обнулялись между матчами — каждый новый бой начинается с чистыми скиллами
	for _, slot in ipairs(SLOTS) do
		skillCDs[slot] = 0
	end
	ultCharge = 0
	tween(ultFill, 0.2, { Size = UDim2.new(0, 0, 1, 0) }):Play()
	ultLabel.Text = "0%"
	updateHP(maxHP, maxHP)
	showHUD(mode)
end)

rRoundState.OnClientEvent:Connect(function(phase)
	if phase == "Battle" then
		showHUD()
		timerLbl.TextColor3 = TIMER_COLOR_BATTLE
	elseif phase == "Preparation" then
		-- Таймер в режиме Preparation — показываем, но серым
		timerFrame.Visible  = true
		timerLbl.TextColor3 = TIMER_COLOR_PREP
		-- Скиллы заблокированы в SkillController
	elseif phase == "Conclusion" or phase == "Waiting" then
		task.delay(4, hideHUD)
	end
end)

rRoundEnd.OnClientEvent:Connect(function(resultData)
	-- FIX: показываем результат боя если есть данные, затем скрываем HUD
	if type(resultData) == "table" and resultData.winnerName then
		local msg = resultData.winnerName == LocalPlayer.Name
			and "🏆 Победа!"
			or  "💀 Поражение"
		if resultData.winnerId == 0 then msg = "⏱️ Ничья" end
		showToast(msg, Color3.fromRGB(255, 220, 80))
	end
	task.delay(4, hideHUD)
end)

rTakeDamage.OnClientEvent:Connect(function(hp, mhp)
	updateHP(hp, mhp)
end)

rUpdateHP.OnClientEvent:Connect(function(hp, mhp)
	updateHP(hp, mhp)
end)

rHeal.OnClientEvent:Connect(function(amount)
	updateHP(currentHP + amount, maxHP)
end)

rRoundTimer.OnClientEvent:Connect(function(seconds, timerMode)
	if type(seconds) ~= "number" then return end
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	timerLbl.Text = string.format("%d:%02d", m, s)
	if timerMode == "preparation" then
		timerLbl.TextColor3 = TIMER_COLOR_PREP
	elseif seconds <= 30 then
		timerLbl.TextColor3 = TIMER_COLOR_LOW
	else
		timerLbl.TextColor3 = TIMER_COLOR_BATTLE
	end
end)

rUpdateHUD.OnClientEvent:Connect(function(data)
	if not data then return end
	if data.hp then updateHP(data.hp, data.maxHp or maxHP) end
	if data.timer then
		local m = math.floor(data.timer / 60)
		local s = data.timer % 60
		timerLbl.Text = string.format("%d:%02d", m, s)
	end
end)

rSkillResult.OnClientEvent:Connect(function(slot, success, cdTime)
	if success and cdTime and skillFrames[slot] then
		skillCDs[slot] = tick() + cdTime
	end
end)

rUltCharge.OnClientEvent:Connect(function(charge)
	ultCharge = math.clamp(charge or 0, 0, 100)
	tween(ultFill, 0.2, { Size = UDim2.new(ultCharge / 100, 0, 1, 0) }):Play()
	ultLabel.Text = math.floor(ultCharge) .. "%"
end)

rChargeUlt.OnClientEvent:Connect(function(charge)
	ultCharge = math.clamp(charge or 0, 0, 100)
	tween(ultFill, 0.2, { Size = UDim2.new(ultCharge / 100, 0, 1, 0) }):Play()
	ultLabel.Text = math.floor(ultCharge) .. "%"
end)

rKillFeed.OnClientEvent:Connect(function(killer, victim)
	addKillFeedEntry(killer, victim)
end)

rPlayerDied.OnClientEvent:Connect(function(victimId, attackerId, respawnTime)
	if victimId ~= LocalPlayer.UserId then return end
	local t = respawnTime or 5
	respawnOverlay.Visible = true
	tween(respawnOverlay, 0.3, { BackgroundTransparency = 0.55 }):Play()
	if respawnThread then task.cancel(respawnThread) end
	respawnThread = task.spawn(function()
		while t > 0 do
			respawnLbl.Text = "Возрождение через " .. t .. "..."
			task.wait(1)
			t = t - 1
		end
		respawnLbl.Text = "Возрождаемся..."
	end)
end)

-- FIX-4: скрываем respawn overlay, сбрасываем таймер и HP
rPlayerRespawn.OnClientEvent:Connect(function()
	if respawnThread then task.cancel(respawnThread); respawnThread = nil end
	tween(respawnOverlay, 0.3, { BackgroundTransparency = 1 }):Play()
	task.delay(0.35, function() respawnOverlay.Visible = false end)
	-- FIX: сбрасываем кулдауны скиллов после респавна
	for _, slot in ipairs(SLOTS) do
		skillCDs[slot] = 0
	end
	ultCharge = 0
	tween(ultFill, 0.2, { Size = UDim2.new(0, 0, 1, 0) }):Play()
	ultLabel.Text = "0%"
	updateHP(maxHP, maxHP)
end)

rNotify.OnClientEvent:Connect(function(msg, msgType)
	if msgType == "phase_banner" then
		showPhaseBanner(msg)
	elseif msgType == "fight_banner" then
		showFightBanner()
	elseif msgType == "countdown_big" then
		local n = tonumber(msg)
		if n then showCountdownBig(n) end
	elseif msgType == "battle_start" then
		showToast(msg, Color3.fromRGB(80, 255, 120))
	elseif msgType == "warning" then
		showToast(msg, Color3.fromRGB(255, 180, 40))
	elseif msgType == "info" then
		showToast(msg, Color3.fromRGB(120, 180, 255))
	elseif msgType == "countdown" then
		showToast(msg, Color3.fromRGB(255, 220, 60))
	else
		showToast(msg, Color3.new(1, 1, 1))
	end
end)

print("[HUD] Initialized ✓ (hidden until RoundStart)")
