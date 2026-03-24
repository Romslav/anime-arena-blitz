-- LobbyUI.client.lua | Anime Arena: Blitz
-- Production главное меню лобби:
--   • Брендинг + слоган в аниме-стиле
--   • Выбор режима: Normal / OneHit / Ranked
--   • Очередь поиска (анимация доточечения + таймер)
--   • Панель профиля: ранг, RP, монеты
--   • Таблица лидерборда (top-5 по RP)
--   • Анимация входа + плавающий фон иероглифов

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local rJoinQueue   = Remotes:WaitForChild("JoinQueue",    10)
local rLeaveQueue  = Remotes:WaitForChild("LeaveQueue",   10)
local rMatchFound  = Remotes:WaitForChild("MatchFound",   10)
local rQueueStatus = Remotes:WaitForChild("QueueStatus",  10)
local rRoundStart  = Remotes:WaitForChild("RoundStart",   10)
local rRankUpdate  = Remotes:WaitForChild("RankUpdate",   10)

-- ============================================================
-- КОНСТАНТЫ
-- ============================================================

local RANK_COLORS = {
	E  = Color3.fromRGB(120, 120, 120),
	D  = Color3.fromRGB(160, 110, 60),
	C  = Color3.fromRGB(60,  190, 80),
	B  = Color3.fromRGB(60,  140, 240),
	A  = Color3.fromRGB(170, 80,  255),
	S  = Color3.fromRGB(255, 180, 30),
	SS = Color3.fromRGB(255, 80,  80),
}

local MODE_DATA = {
	{
		id      = "Normal",
		label   = "NORMAL",
		jp      = "通常",
		desc    = "Classic 1v1 · 180s · HP-based win",
		color   = Color3.fromRGB(40, 120, 220),
		icon    = "⚔️",
	},
	{
		id      = "OneHit",
		label   = "ONE HIT",
		jp      = "一撃",
		desc    = "Instant kill · first to 15K · 3s respawn",
		color   = Color3.fromRGB(210, 50,  30),
		icon    = "⚡",
	},
	{
		id      = "Ranked",
		label   = "RANKED",
		jp      = "ランク",
		desc    = "Competitive · RP gains/losses · E→SS",
		color   = Color3.fromRGB(200, 160, 30),
		icon    = "👑",
	},
}

-- ============================================================
-- ФАБРИКА GUI
-- ============================================================

local function Fr(parent, size, pos, bg, alpha, zi, rnd)
	local f = Instance.new("Frame")
	f.Size = size;  f.Position = pos
	f.BackgroundColor3 = bg or Color3.new()
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	if zi  then f.ZIndex = zi end
	if rnd then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, rnd)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local function Lbl(parent, size, pos, txt, col, fs, bold, zi, align)
	local l = Instance.new("TextLabel")
	l.Size = size; l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = txt; l.TextColor3 = col or Color3.new(1,1,1)
	l.TextSize = fs or 14
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextScaled = false
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	if zi then l.ZIndex = zi end
	l.Parent = parent
	return l
end

local function Btn(parent, size, pos, txt, bg, col, zi, rnd)
	local b = Instance.new("TextButton")
	b.Size = size; b.Position = pos
	b.BackgroundColor3 = bg or Color3.fromRGB(40,40,80)
	b.BackgroundTransparency = 0
	b.Text = txt; b.TextColor3 = col or Color3.new(1,1,1)
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.BorderSizePixel = 0
	if zi  then b.ZIndex = zi end
	if rnd then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, rnd)
		c.Parent = b
	end
	b.Parent = parent
	return b
end

local function Stroke(parent, col, thickness)
	local s = Instance.new("UIStroke")
	s.Color = col or Color3.fromRGB(255,200,50)
	s.Thickness = thickness or 2
	s.Parent = parent
	return s
end

-- ============================================================
-- ГЛАВНЫЙ ScreenGui
-- ============================================================

local gui = Instance.new("ScreenGui")
gui.Name            = "LobbyUI"
gui.ResetOnSpawn    = false
gui.DisplayOrder    = 10
gui.IgnoreGuiInset  = true
gui.Enabled         = true
gui.Parent          = PlayerGui

-- Тёмный фоновый градиент
local bg = Fr(gui, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
	Color3.fromRGB(6,4,14), 0, 1)
do
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(14, 8,  30)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6,  4,  14)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(10, 2,  20)),
	})
	g.Rotation = 135
	g.Parent = bg
end

-- ============================================================
-- ЗАГОЛОВОК
-- ============================================================

local header = Fr(gui, UDim2.new(1,0,0,80), UDim2.new(0,0,0,0),
	Color3.fromRGB(8,5,20), 0, 5)
do
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 5, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(6,  2, 12)),
	})
	g.Rotation = 90
	g.Parent = header
end
Stroke(header, Color3.fromRGB(140, 60, 255), 1.5)

-- Титул на японском
local jpTitle = Lbl(header,
	UDim2.new(0,200,1,0), UDim2.new(0,16,0,0),
	"アニメアリーナ", Color3.fromRGB(200,100,255), 13, false, 6,
	Enum.TextXAlignment.Left)

local mainTitle = Lbl(header,
	UDim2.new(0,400,1,0), UDim2.new(0.5,-200,0,0),
	"ANIME ARENA", Color3.fromRGB(255,240,255), 32, true, 6)
Stroke(mainTitle, Color3.fromRGB(160,60,255), 2)

local subTitle = Lbl(header,
	UDim2.new(0,300,0,22), UDim2.new(0.5,-150,0,44),
	"B L I T Z", Color3.fromRGB(220,160,255), 18, true, 6)

-- Инфо сервера
local serverInfo = Lbl(header,
	UDim2.new(0,220,1,0), UDim2.new(1,-230,0,0),
	"Server: ...", Color3.fromRGB(140,140,160), 11, false, 6,
	Enum.TextXAlignment.Right)

task.spawn(function()
	task.wait(1)
	serverInfo.Text = string.format("Players: %d | Region: EU", #Players:GetPlayers())
end)

-- ============================================================
-- ПАНЕЛЬ ПРОФИЛЯ (top-left)
-- ============================================================

local profilePanel = Fr(gui,
	UDim2.new(0,220,0,130),
	UDim2.new(0,16,0,96),
	Color3.fromRGB(12,8,28), 0, 6, 10)
Stroke(profilePanel, Color3.fromRGB(80,40,160), 1.5)

local pName = Lbl(profilePanel,
	UDim2.new(1,-10,0,24), UDim2.new(0,8,0,8),
	LocalPlayer.Name, Color3.fromRGB(240,240,255), 16, true, 7,
	Enum.TextXAlignment.Left)

local pRankLabel = Lbl(profilePanel,
	UDim2.new(0,80,0,34), UDim2.new(0,8,0,34),
	"E", Color3.fromRGB(120,120,120), 30, true, 7)

local pRPLabel = Lbl(profilePanel,
	UDim2.new(0,120,0,20), UDim2.new(0,60,0,36),
	"0 RP", Color3.fromRGB(180,180,200), 13, false, 7,
	Enum.TextXAlignment.Left)

local pCoinsLabel = Lbl(profilePanel,
	UDim2.new(0,120,0,20), UDim2.new(0,60,0,56),
	"🪙 0", Color3.fromRGB(255,210,60), 13, false, 7,
	Enum.TextXAlignment.Left)

local pWinsLabel = Lbl(profilePanel,
	UDim2.new(1,-10,0,18), UDim2.new(0,8,0,84),
	"Wins: 0", Color3.fromRGB(120,200,120), 12, false, 7,
	Enum.TextXAlignment.Left)

local pLossesLabel = Lbl(profilePanel,
	UDim2.new(1,-10,0,18), UDim2.new(0,8,0,104),
	"Losses: 0", Color3.fromRGB(200,100,100), 12, false, 7,
	Enum.TextXAlignment.Left)

-- ============================================================
-- СЕЛЕКТОР РЕЖИМА (center)
-- ============================================================

local modeContainer = Fr(gui,
	UDim2.new(0,560,0,260),
	UDim2.new(0.5,-280,0.5,-170),
	Color3.fromRGB(0,0,0), 1, 5)

local modeTitle = Lbl(modeContainer,
	UDim2.new(1,0,0,28), UDim2.new(0,0,0,0),
	"SELECT MODE", Color3.fromRGB(200,160,255), 16, true, 6)

local modeCards = {}
local selectedMode = "Normal"

for i, mData in ipairs(MODE_DATA) do
	local x = (i - 1) * 190
	local card = Fr(modeContainer,
		UDim2.new(0,174,0,210),
		UDim2.new(0, x, 0, 36),
		Color3.fromRGB(14,10,30), 0, 6, 12)
	Stroke(card, Color3.fromRGB(60,40,100), 1.5)

	-- Иконка
	Lbl(card, UDim2.new(1,0,0,44), UDim2.new(0,0,0,8),
		mData.icon, Color3.new(1,1,1), 36, true, 7)

	-- Название
	local nameLbl = Lbl(card, UDim2.new(1,-8,0,24), UDim2.new(0,4,0,56),
		mData.label, mData.color, 18, true, 7)
	Stroke(nameLbl, Color3.fromRGB(20,10,40), 2)

	-- Японский
	Lbl(card, UDim2.new(1,-8,0,18), UDim2.new(0,4,0,82),
		mData.jp, Color3.fromRGB(160,120,200), 12, false, 7)

	-- Описание
	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(1,-12,0,52)
	descLbl.Position = UDim2.new(0,6,0,104)
	descLbl.BackgroundTransparency = 1
	descLbl.Text = mData.desc
	descLbl.TextColor3 = Color3.fromRGB(160,150,180)
	descLbl.TextSize = 11
	descLbl.Font = Enum.Font.Gotham
	descLbl.TextWrapped = true
	descLbl.TextXAlignment = Enum.TextXAlignment.Center
	descLbl.ZIndex = 7
	descLbl.Parent = card

	-- Кнопка выбора
	local selBtn = Btn(card,
		UDim2.new(1,-16,0,30), UDim2.new(0,8,1,-38),
		"SELECT", mData.color, Color3.new(1,1,1), 8, 8)

	-- Hover
	selBtn.MouseEnter:Connect(function()
		TweenService:Create(card,
			TweenInfo.new(0.12),
			{ BackgroundColor3 = Color3.fromRGB(20,14,44) }):Play()
	end)
	selBtn.MouseLeave:Connect(function()
		if selectedMode ~= mData.id then
			TweenService:Create(card,
				TweenInfo.new(0.12),
				{ BackgroundColor3 = Color3.fromRGB(14,10,30) }):Play()
		end
	end)

	modeCards[mData.id] = { card = card, stroke = card:FindFirstChildWhichIsA("UIStroke"), color = mData.color }

	local capturedMode = mData.id
	selBtn.Activated:Connect(function()
		selectedMode = capturedMode
		-- Подсветка выбранной карты
		for mId, mc in pairs(modeCards) do
			if mId == capturedMode then
				TweenService:Create(mc.card, TweenInfo.new(0.15),
					{ BackgroundColor3 = Color3.fromRGB(22,16,48) }):Play()
				mc.stroke.Color     = mc.color
				mc.stroke.Thickness = 2.5
			else
				TweenService:Create(mc.card, TweenInfo.new(0.15),
					{ BackgroundColor3 = Color3.fromRGB(14,10,30) }):Play()
				mc.stroke.Color     = Color3.fromRGB(60,40,100)
				mc.stroke.Thickness = 1.5
			end
		end
	end)
end

-- ============================================================
-- КНОПКА PLAY / CANCEL (center-bottom)
-- ============================================================

local playArea = Fr(gui,
	UDim2.new(0,320,0,100),
	UDim2.new(0.5,-160,1,-130),
	Color3.new(), 1, 6)

local playBtn = Btn(playArea,
	UDim2.new(1,0,0,56),
	UDim2.new(0,0,0,0),
	"▶ FIND MATCH",
	Color3.fromRGB(30,160,60),
	Color3.new(1,1,1), 7, 10)
do
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 200, 80)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 130, 50)),
	})
	g.Rotation = 90
	g.Parent = playBtn
end
Stroke(playBtn, Color3.fromRGB(60, 255, 100), 2)

local cancelBtn = Btn(playArea,
	UDim2.new(1,0,0,32),
	UDim2.new(0,0,0,62),
	"✕ CANCEL",
	Color3.fromRGB(80,20,20),
	Color3.fromRGB(255,160,160), 7, 8)
cancelBtn.Visible = false

-- ============================================================
-- СТАТУС ОЧЕРЕДИ
-- ============================================================

local queuePanel = Fr(gui,
	UDim2.new(0,360,0,80),
	UDim2.new(0.5,-180,1,-200),
	Color3.fromRGB(10,10,30), 0.2, 10, 10)
queuePanel.Visible = false
Stroke(queuePanel, Color3.fromRGB(80,80,200), 1.5)

local queueTitle = Lbl(queuePanel,
	UDim2.new(1,0,0,22), UDim2.new(0,0,0,6),
	"SEARCHING FOR MATCH", Color3.fromRGB(160,200,255), 13, true, 11)

local queueTimer = Lbl(queuePanel,
	UDim2.new(1,0,0,22), UDim2.new(0,0,0,28),
	"0:00", Color3.fromRGB(220,220,255), 18, true, 11)

local queueDots = Lbl(queuePanel,
	UDim2.new(1,0,0,18), UDim2.new(0,0,0,52),
	"", Color3.fromRGB(100,100,160), 12, false, 11)

-- Анимация точек×ожидания
local dotsThread = nil
local function startDots()
	if dotsThread then return end
	local frames = { ".", "..", "...", "" }
	local i = 1
	dotsThread = task.spawn(function()
		while true do
			queueDots.Text = "Searching" .. frames[i]
			i = i % #frames + 1
			task.wait(0.45)
		end
	end)
end
local function stopDots()
	if dotsThread then task.cancel(dotsThread); dotsThread = nil end
	queueDots.Text = ""
end

-- ============================================================
-- ЛИДЕРБОРД (right panel)
-- ============================================================

local lbPanel = Fr(gui,
	UDim2.new(0,200,0,240),
	UDim2.new(1,-216,0,96),
	Color3.fromRGB(10,8,24), 0, 6, 10)
Stroke(lbPanel, Color3.fromRGB(60,40,100), 1.5)

Lbl(lbPanel, UDim2.new(1,0,0,22), UDim2.new(0,0,0,6),
	"TOP PLAYERS", Color3.fromRGB(255,200,50), 13, true, 7)

local lbRows = {}
for r = 1, 5 do
	local row = Fr(lbPanel,
		UDim2.new(1,-10,0,34), UDim2.new(0,5,0,28 + (r-1)*38),
		Color3.fromRGB(16,12,32), 0, 7, 6)

	Lbl(row, UDim2.new(0,20,1,0), UDim2.new(0,4,0,0),
		tostring(r) .. ".", Color3.fromRGB(140,120,180), 11, true, 8,
		Enum.TextXAlignment.Left)

	local nameLb = Lbl(row, UDim2.new(0,110,1,0), UDim2.new(0,26,0,0),
		"---", Color3.fromRGB(200,200,220), 12, false, 8,
		Enum.TextXAlignment.Left)

	local rankLb = Lbl(row, UDim2.new(0,28,1,0), UDim2.new(1,-32,0,0),
		"E", Color3.fromRGB(120,120,120), 13, true, 8,
		Enum.TextXAlignment.Right)

	table.insert(lbRows, { name = nameLb, rank = rankLb })
end

-- ============================================================
-- СОСТОЯНИЕ
-- ============================================================

local inQueue    = false
local queueStart = 0
local queueTimerThread = nil

-- ============================================================
-- АНИМАЦИЯ ВХОДА
-- ============================================================

local function animateIn()
	local items = { header, profilePanel, modeContainer, playArea, lbPanel }
	for i, item in ipairs(items) do
		item.Position = item.Position + UDim2.new(0, 0, 0, 40)
		item.BackgroundTransparency = 1
		task.delay((i - 1) * 0.06, function()
			TweenService:Create(item, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = item.Position - UDim2.new(0, 0, 0, 40),
				BackgroundTransparency = i == 1 and 0 or
					(item == modeContainer and 1 or 0),
			}):Play()
		end)
	end
end

task.delay(0.1, animateIn)

-- ============================================================
-- PLAY / CANCEL
-- ============================================================

local function enterQueue()
	if inQueue then return end
	inQueue    = true
	queueStart = tick()

	playBtn.Visible    = false
	cancelBtn.Visible  = true
	queuePanel.Visible = true
	startDots()

	-- Таймер
	if queueTimerThread then task.cancel(queueTimerThread) end
	queueTimerThread = task.spawn(function()
		while inQueue do
			local elapsed = math.floor(tick() - queueStart)
			local m = math.floor(elapsed / 60)
			local s = elapsed % 60
			queueTimer.Text = string.format("%d:%02d", m, s)
			task.wait(1)
		end
	end)

	rJoinQueue:FireServer(selectedMode)
end

local function leaveQueue()
	if not inQueue then return end
	inQueue = false
	if queueTimerThread then task.cancel(queueTimerThread); queueTimerThread = nil end
	stopDots()

	playBtn.Visible    = true
	cancelBtn.Visible  = false
	queuePanel.Visible = false
	queueTimer.Text    = "0:00"

	rLeaveQueue:FireServer()
end

playBtn.Activated:Connect(enterQueue)
cancelBtn.Activated:Connect(leaveQueue)

-- ============================================================
-- СКРЫТЬ ЛОББИ С АНИМАЦИЕЙ
-- ============================================================

local LobbyUI = {}
_G.LobbyUI = LobbyUI

function LobbyUI.Hide()
	if not gui.Enabled then return end
	local items = { header, profilePanel, modeContainer, playArea, lbPanel, queuePanel }
	for i, item in ipairs(items) do
		task.delay((i - 1) * 0.04, function()
			TweenService:Create(item,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ BackgroundTransparency = 1 }):Play()
		end)
	end
	task.delay(0.35, function() gui.Enabled = false end)
end

function LobbyUI.Show()
	gui.Enabled = true
	inQueue = false
	playBtn.Visible   = true
	cancelBtn.Visible = false
	queuePanel.Visible = false
	animateIn()
end

function LobbyUI.UpdateProfile(data)
	-- data = { rank, rp, coins, wins, losses }
	if data.rank then
		pRankLabel.Text       = data.rank
		pRankLabel.TextColor3 = RANK_COLORS[data.rank] or Color3.new(1,1,1)
	end
	if data.rp     then pRPLabel.Text     = data.rp     .. " RP"  end
	if data.coins  then pCoinsLabel.Text  = "🪙 " .. data.coins   end
	if data.wins   then pWinsLabel.Text   = "Wins: "   .. data.wins   end
	if data.losses then pLossesLabel.Text = "Losses: " .. data.losses end
end

function LobbyUI.UpdateLeaderboard(entries)
	-- entries = array of { name, rank }
	for i, row in ipairs(lbRows) do
		local e = entries and entries[i]
		if e then
			row.name.Text       = e.name or "---"
			row.rank.Text       = e.rank or "E"
			row.rank.TextColor3 = RANK_COLORS[e.rank] or Color3.new(1,1,1)
		else
			row.name.Text = "---"
			row.rank.Text = "E"
		end
	end
end

-- ============================================================
-- REMOTE HANDLERS
-- ============================================================

-- Матч найден — скрываем лобби
rMatchFound.OnClientEvent:Connect(function(matchInfo)
	inQueue = false
	if queueTimerThread then task.cancel(queueTimerThread) end
	stopDots()
	-- Вспышка «Матч найден!»
	queueTitle.Text = "MATCH FOUND!"
	queueTimer.Text = ""
	task.delay(1.2, LobbyUI.Hide)
end)

-- Начало раунда
rRoundStart.OnClientEvent:Connect(function(mode, roundId)
	LobbyUI.Hide()
end)

-- Ранг обновился
rRankUpdate.OnClientEvent:Connect(function(oldRank, newRank, newRP)
	pRankLabel.Text       = newRank or "E"
	pRankLabel.TextColor3 = RANK_COLORS[newRank] or Color3.new(1,1,1)
	pRPLabel.Text         = tostring(newRP or 0) .. " RP"
end)

-- Статус очереди -- FIX: botIn параметр + русский текст
rQueueStatus.OnClientEvent:Connect(function(position, total, botIn)
	if botIn and botIn > 0 then
		queueDots.Text = string.format("Бот войдёт через %dс", botIn)
	elseif botIn == 0 then
		queueDots.Text = "Подключаем бота..."
	else
		queueDots.Text = string.format("Очередь: #%d из %d", position, total)
	end
end)

-- FIX: Матч найден — русская надпись
rMatchFound.OnClientEvent:Connect(function(matchInfo)
	inQueue = false
	if queueTimerThread then task.cancel(queueTimerThread) end
	stopDots()
	queueTitle.Text = "МАТЧ НАЙДЕН!"
	queueTimer.Text = ""
	task.delay(1.2, LobbyUI.Hide)
end)

print("[LobbyUI] Initialized ✓")
