-- HeroSelector.client.lua | Anime Arena: Blitz
-- Production UI выбора героя:
--   • 12 карточек с ролью, HP, DMG, раритетом, скиллами
--   • Панель деталей выбранного героя
--   • Таймер выбора 25с + автовыбор
--   • Анимация влёта / slide-in карточек
--   • Режимы Normal / OneHit / Ranked — цветная шапка
--   • Интеграция с RemotesInitializer (SelectHero / MatchStart)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local rSelectHero   = Remotes:WaitForChild("SelectHero",    10)
local rHeroSelected = Remotes:WaitForChild("HeroSelected",  10)
local rMatchFound   = Remotes:WaitForChild("MatchFound",    10)
local rMatchStart   = Remotes:WaitForChild("RoundStart",    10)

-- ============================================================
-- ДАННЫЕ ГЕРОЕВ
-- ============================================================

local HEROES = {
	{ id="FlameRonin",    name="Flame Ronin",     jp="烎りの浪士",    rarity="Common",    role="Bruiser",     hp=180, dmg=22, spd=17, color=Color3.fromRGB(255,80,30),   skills={"Flame Dash","Rising Slash","Burn Guard","Phoenix Cut"},         desc="Огненный воин-рывочник. Жёсткий ближний бой + DoT." },
	{ id="VoidAssassin",  name="Void Assassin",   jp="虚空の刺客",    rarity="Legendary", role="Assassin",    hp=130, dmg=28, spd=20, color=Color3.fromRGB(140,40,200),  skills={"Blink Strike","Shadow Feint","Backstab Mark","Silent Execution"},  desc="Телепорт за спину врага. Ульт ×1.6 при <30% HP цели." },
	{ id="ThunderMonk",   name="Thunder Monk",    jp="雷鳴の僧",      rarity="Rare",      role="Controller", hp=160, dmg=20, spd=16, color=Color3.fromRGB(80,170,255),  skills={"Lightning Palm","Stun Ring","Step Dash","Heavenly Judgment"},     desc="Мастер станов. АОЕ молнии держат любого врага." },
	{ id="IronTitan",     name="Iron Titan",      jp="鉄の巨人",      rarity="Rare",      role="Tank",        hp=260, dmg=15, spd=13, color=Color3.fromRGB(180,180,180),skills={"Iron Slam","Shield Wall","Ground Quake","Titan Fall"},            desc="Живая крепость. Щиты и АОЕ контроль пространства." },
	{ id="ScarletArcher", name="Scarlet Archer",  jp="紅の弓手",      rarity="Rare",      role="Ranged",      hp=140, dmg=24, spd=18, color=Color3.fromRGB(220,50,80),   skills={"Arrow Rain","Piercing Shot","Evasion Roll","Storm of Arrows"},    desc="Дальнобойный. Пробивает линию + дождь стрел." },
	{ id="EclipseHero",   name="Eclipse Hero",    jp="日食の英雄",    rarity="Legendary", role="Assassin",    hp=150, dmg=26, spd=19, color=Color3.fromRGB(80,50,160),   skills={"Eclipse Slash","Lunar Phase","Dark Veil","Total Eclipse"},         desc="Тёмный охотник. Слепит + телепорт + массивный АОЕ." },
	{ id="StormDancer",   name="Storm Dancer",    jp="嵐の踊り子",    rarity="Common",    role="Skirmisher",  hp=145, dmg=23, spd=21, color=Color3.fromRGB(120,220,255), skills={"Tempest Step","Wind Spiral","Gale Parry","Cyclone Fury"},         desc="Быстрейший герой. Нокбэки + серия волн атаки." },
	{ id="BloodSage",     name="Blood Sage",      jp="血の賢者",      rarity="Legendary", role="Mage",        hp=120, dmg=30, spd=15, color=Color3.fromRGB(200,20,20),   skills={"Bloodbolt","Crimson Bind","Sanguine Burst","Blood Moon"},          desc="Маг крови. Хилит + путает + дренит HP врагов." },
	{ id="CrystalGuard",  name="Crystal Guard",   jp="氷晶の守護者",  rarity="Rare",      role="Tank",        hp=240, dmg=14, spd=14, color=Color3.fromRGB(100,200,230), skills={"Crystal Spike","Prism Barrier","Shatter Rush","Crystal Fortress"},  desc="Хрустальный страж. Щиты 80HP + рывок с дроблением." },
	{ id="ShadowTwin",    name="Shadow Twin",     jp="影の双子",      rarity="Epic",      role="Support",     hp=155, dmg=25, spd=17, color=Color3.fromRGB(60,60,90),    skills={"Twin Lash","Shadow Clone","Mist Step","Dark Mirror"},               desc="Тень. Двойные атаки + клон + отражение урона." },
	{ id="NeonBlitz",     name="Neon Blitz",      jp="光速のネオン",  rarity="Epic",      role="Ranged",      hp=135, dmg=27, spd=20, color=Color3.fromRGB(0,240,200),   skills={"Neon Burst","Circuit Dash","Overload","Neon Overdrive"},            desc="Электро-стрелок. Молниеносные рывки и AОЕ разряды." },
	{ id="JadeSentinel",  name="Jade Sentinel",   jp="翡翠の番人",    rarity="Rare",      role="Duelist",     hp=170, dmg=21, spd=16, color=Color3.fromRGB(50,180,80),   skills={"Jade Strike","Sentinel Step","Earthen Crush","Jade Wrath"},         desc="Дуэлянт. Стакующийся ульт — чем больше ударов, тем мощнее." },
}

local RARITY_COLOR = {
	Common    = Color3.fromRGB(160, 160, 160),
	Rare      = Color3.fromRGB(60,  120, 240),
	Epic      = Color3.fromRGB(160, 50,  220),
	Legendary = Color3.fromRGB(255, 165, 0),
}

local MODE_COLOR = {
	Normal  = Color3.fromRGB(30,  140, 255),
	OneHit  = Color3.fromRGB(220, 30,  30),
	Ranked  = Color3.fromRGB(255, 180, 0),
}

local SLOT_LABELS = { "Q", "E", "F", "R" }

-- ============================================================
-- STATE
-- ============================================================

local selectedHero  = HEROES[1]
local confirmed     = false
local timerThread   = nil
local currentMode   = "Normal"
local cardButtons   = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function corner(parent, rad)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, rad or 8)
	c.Parent = parent
	return c
end

local function pad(parent, top, right, bot, left)
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0, top    or 0)
	p.PaddingRight  = UDim.new(0, right  or 0)
	p.PaddingBottom = UDim.new(0, bot    or 0)
	p.PaddingLeft   = UDim.new(0, left   or 0)
	p.Parent = parent
	return p
end

local function stroke(parent, col, thick)
	local s = Instance.new("UIStroke")
	s.Color     = col   or Color3.fromRGB(255,255,255)
	s.Thickness = thick or 1.5
	s.Parent    = parent
	return s
end

local function label(parent, text, size, col, font, xa, ya)
	local l = Instance.new("TextLabel")
	l.Size                  = UDim2.new(1,0,1,0)
	l.BackgroundTransparency = 1
	l.Text                  = text
	l.TextSize              = size  or 14
	l.TextColor3            = col   or Color3.new(1,1,1)
	l.Font                  = font  or Enum.Font.GothamBold
	l.TextXAlignment        = xa    or Enum.TextXAlignment.Left
	l.TextYAlignment        = ya    or Enum.TextYAlignment.Center
	l.Parent                = parent
	return l
end

-- ============================================================
-- КОРНЕВОЙ GUI
-- ============================================================

local gui = Instance.new("ScreenGui")
gui.Name            = "HeroSelector"
gui.ResetOnSpawn    = false
gui.DisplayOrder    = 20
gui.IgnoreGuiInset  = true
gui.Enabled         = false
gui.Parent          = PlayerGui

-- Фон
local bg = Instance.new("Frame")
bg.Size                   = UDim2.new(1,0,1,0)
bg.BackgroundColor3       = Color3.fromRGB(8,8,18)
bg.BackgroundTransparency = 0
bg.Parent = gui

-- Градиентный оверлей сверху
local topGrad = Instance.new("Frame")
topGrad.Size                   = UDim2.new(1,0,0.35,0)
topGrad.BackgroundColor3       = Color3.fromRGB(0,0,0)
topGrad.BackgroundTransparency = 0.4
topGrad.BorderSizePixel        = 0
topGrad.Parent = bg
local tg = Instance.new("UIGradient")
tg.Rotation = 90
tg.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(1, 1),
})
tg.Parent = topGrad

-- ============================================================
-- ШАПКА
-- ============================================================

local header = Instance.new("Frame")
header.Size             = UDim2.new(1,0,0,70)
header.BackgroundColor3 = Color3.fromRGB(15,15,30)
header.BorderSizePixel  = 0
header.Parent           = bg

local headerAccent = Instance.new("Frame")
headerAccent.Size             = UDim2.new(1,0,0,3)
headerAccent.Position         = UDim2.new(0,0,1,-3)
headerAccent.BackgroundColor3 = MODE_COLOR.Normal
headerAccent.BorderSizePixel  = 0
headerAccent.Parent           = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size                  = UDim2.new(0.5,0,1,0)
titleLbl.Position              = UDim2.new(0,24,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                  = "ВЫБОР ГЕРОЯ"
titleLbl.TextSize              = 26
titleLbl.TextColor3            = Color3.new(1,1,1)
titleLbl.Font                  = Enum.Font.GothamBold
titleLbl.TextXAlignment        = Enum.TextXAlignment.Left
titleLbl.Parent                = header

local modeLbl = Instance.new("TextLabel")
modeLbl.Size                   = UDim2.new(0,160,0,34)
modeLbl.Position               = UDim2.new(0.5,-80,0.5,-17)
modeLbl.BackgroundColor3       = MODE_COLOR.Normal
modeLbl.Text                   = "NORMAL MODE"
modeLbl.TextSize               = 13
modeLbl.TextColor3             = Color3.new(1,1,1)
modeLbl.Font                   = Enum.Font.GothamBold
modeLbl.TextXAlignment         = Enum.TextXAlignment.Center
modeLbl.Parent                 = header
corner(modeLbl, 6)

local timerLbl = Instance.new("TextLabel")
timerLbl.Size                  = UDim2.new(0,90,1,0)
timerLbl.Position              = UDim2.new(1,-110,0,0)
timerLbl.BackgroundTransparency = 1
timerLbl.Text                  = "25"
timerLbl.TextSize              = 32
timerLbl.TextColor3            = Color3.fromRGB(255,220,80)
timerLbl.Font                  = Enum.Font.GothamBold
timerLbl.TextXAlignment        = Enum.TextXAlignment.Center
timerLbl.Parent                = header

-- ============================================================
-- ОСНОВНОЙ LAYOUT: cards | details
-- ============================================================

local mainFrame = Instance.new("Frame")
mainFrame.Size             = UDim2.new(1,0,1,-70)
mainFrame.Position         = UDim2.new(0,0,0,70)
mainFrame.BackgroundTransparency = 1
mainFrame.Parent           = bg

-- Левая сетка карточек
local cardsScroll = Instance.new("ScrollingFrame")
cardsScroll.Size             = UDim2.new(0.62,0,1,0)
cardsScroll.BackgroundTransparency = 1
cardsScroll.ScrollBarThickness = 4
cardsScroll.ScrollBarImageColor3 = Color3.fromRGB(80,80,120)
cardsScroll.CanvasSize       = UDim2.new(0,0,0,0)
cardsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
cardsScroll.Parent           = mainFrame
pad(cardsScroll, 16, 12, 16, 16)

local grid = Instance.new("UIGridLayout")
grid.CellSize    = UDim2.new(0,148,0,190)
grid.CellPadding = UDim2.new(0,10,0,10)
grid.SortOrder   = Enum.SortOrder.LayoutOrder
grid.Parent      = cardsScroll

-- Правая панель деталей
local detailPanel = Instance.new("Frame")
detailPanel.Size             = UDim2.new(0.38,-8,1,0)
detailPanel.Position         = UDim2.new(0.62,8,0,0)
detailPanel.BackgroundColor3 = Color3.fromRGB(14,14,28)
detailPanel.BackgroundTransparency = 0.1
detailPanel.Parent           = mainFrame
corner(detailPanel, 12)
pad(detailPanel, 22, 20, 22, 22)

-- Детали: имя героя
local dName = Instance.new("TextLabel")
dName.Size                   = UDim2.new(1,0,0,40)
dName.BackgroundTransparency = 1
dName.Text                   = "Flame Ronin"
dName.TextSize               = 26
dName.TextColor3             = Color3.new(1,1,1)
dName.Font                   = Enum.Font.GothamBold
dName.TextXAlignment         = Enum.TextXAlignment.Left
dName.Parent                 = detailPanel

local dJP = Instance.new("TextLabel")
dJP.Size                     = UDim2.new(1,0,0,22)
dJP.Position                 = UDim2.new(0,0,0,40)
dJP.BackgroundTransparency   = 1
dJP.Text                     = "烎りの浪士"
dJP.TextSize                 = 15
dJP.TextColor3               = Color3.fromRGB(200,180,255)
dJP.Font                     = Enum.Font.Gotham
dJP.TextXAlignment           = Enum.TextXAlignment.Left
dJP.Parent                   = detailPanel

local dRoleRarity = Instance.new("TextLabel")
dRoleRarity.Size                 = UDim2.new(1,0,0,20)
dRoleRarity.Position             = UDim2.new(0,0,0,65)
dRoleRarity.BackgroundTransparency = 1
dRoleRarity.Text                 = "Bruiser  •  Common"
dRoleRarity.TextSize             = 13
dRoleRarity.TextColor3           = Color3.fromRGB(160,160,190)
dRoleRarity.Font                 = Enum.Font.Gotham
dRoleRarity.TextXAlignment       = Enum.TextXAlignment.Left
dRoleRarity.Parent               = detailPanel

-- Разделитель
local divider = Instance.new("Frame")
divider.Size             = UDim2.new(1,0,0,1)
divider.Position         = UDim2.new(0,0,0,94)
divider.BackgroundColor3 = Color3.fromRGB(50,50,80)
divider.BorderSizePixel  = 0
divider.Parent           = detailPanel

-- Статы
local function statBar(yPos, labelText, value, maxVal, col)
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1,0,0,22)
	row.Position         = UDim2.new(0,0,0,yPos)
	row.BackgroundTransparency = 1
	row.Parent           = detailPanel

	local lbl = Instance.new("TextLabel")
	lbl.Size             = UDim2.new(0,70,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text             = labelText
	lbl.TextSize         = 12
	lbl.TextColor3       = Color3.fromRGB(160,160,190)
	lbl.Font             = Enum.Font.Gotham
	lbl.TextXAlignment   = Enum.TextXAlignment.Left
	lbl.Parent           = row

	local track = Instance.new("Frame")
	track.Size           = UDim2.new(1,-80,0,8)
	track.Position       = UDim2.new(0,75,0.5,-4)
	track.BackgroundColor3 = Color3.fromRGB(30,30,50)
	track.Parent         = row
	corner(track, 4)

	local fill = Instance.new("Frame")
	fill.Size            = UDim2.new(math.clamp(value/maxVal,0,1),0,1,0)
	fill.BackgroundColor3 = col or Color3.fromRGB(100,200,100)
	fill.Parent          = track
	corner(fill, 4)

	return fill
end

local fillHP  = statBar(102, "HP",     180, 280, Color3.fromRGB(80,210,80))
local fillDMG = statBar(130, "DMG",    22,  35,  Color3.fromRGB(255,120,40))
local fillSPD = statBar(158, "Скорость",17, 22,  Color3.fromRGB(80,160,255))

-- Описание
local dDesc = Instance.new("TextLabel")
dDesc.Size                   = UDim2.new(1,0,0,54)
dDesc.Position               = UDim2.new(0,0,0,188)
dDesc.BackgroundTransparency = 1
dDesc.Text                   = ""
dDesc.TextSize               = 13
dDesc.TextColor3             = Color3.fromRGB(200,200,220)
dDesc.Font                   = Enum.Font.Gotham
dDesc.TextXAlignment         = Enum.TextXAlignment.Left
dDesc.TextYAlignment         = Enum.TextYAlignment.Top
dDesc.TextWrapped            = true
dDesc.Parent                 = detailPanel

-- Скиллы
local skillsTitle = Instance.new("TextLabel")
skillsTitle.Size                 = UDim2.new(1,0,0,20)
skillsTitle.Position             = UDim2.new(0,0,0,248)
skillsTitle.BackgroundTransparency = 1
skillsTitle.Text                 = "СПОСОБНОСТИ"
skillsTitle.TextSize             = 11
skillsTitle.TextColor3           = Color3.fromRGB(140,140,180)
skillsTitle.Font                 = Enum.Font.GothamBold
skillsTitle.TextXAlignment       = Enum.TextXAlignment.Left
skillsTitle.Parent               = detailPanel

local skillLabels = {}
for i = 1, 4 do
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1,0,0,28)
	row.Position         = UDim2.new(0,0,0,270 + (i-1)*32)
	row.BackgroundColor3 = Color3.fromRGB(22,22,40)
	row.Parent           = detailPanel
	corner(row, 6)
	pad(row, 0, 0, 0, 8)

	local key = Instance.new("TextLabel")
	key.Size             = UDim2.new(0,22,1,0)
	key.BackgroundTransparency = 1
	key.Text             = SLOT_LABELS[i]
	key.TextSize         = 13
	key.TextColor3       = Color3.fromRGB(255,200,80)
	key.Font             = Enum.Font.GothamBold
	key.TextXAlignment   = Enum.TextXAlignment.Center
	key.Parent           = row

	local sName = Instance.new("TextLabel")
	sName.Size             = UDim2.new(1,-28,1,0)
	sName.Position         = UDim2.new(0,28,0,0)
	sName.BackgroundTransparency = 1
	sName.Text             = "—"
	sName.TextSize         = 13
	sName.TextColor3       = Color3.new(1,1,1)
	sName.Font             = Enum.Font.Gotham
	sName.TextXAlignment   = Enum.TextXAlignment.Left
	sName.Parent           = row

	skillLabels[i] = sName
end

-- Кнопка Выбрать
local confirmBtn = Instance.new("TextButton")
confirmBtn.Size             = UDim2.new(1,0,0,48)
confirmBtn.Position         = UDim2.new(0,0,1,-58)
confirmBtn.BackgroundColor3 = Color3.fromRGB(255,80,30)
confirmBtn.Text             = "ВЫБРАТЬ"
confirmBtn.TextSize         = 18
confirmBtn.TextColor3       = Color3.new(1,1,1)
confirmBtn.Font             = Enum.Font.GothamBold
confirmBtn.Parent           = detailPanel
corner(confirmBtn, 10)
stroke(confirmBtn, Color3.fromRGB(255,130,60), 2)

-- ============================================================
-- КАРТОЧКИ ГЕРОЕВ
-- ============================================================

local function buildCard(hero, idx)
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(0,148,0,190)
	card.BackgroundColor3 = Color3.fromRGB(18,18,34)
	card.LayoutOrder      = idx
	card.Parent           = cardsScroll
	corner(card, 10)
	local cardStroke = stroke(card, Color3.fromRGB(40,40,60), 1.5)

	-- Цветная полоска сверху
	local topBar = Instance.new("Frame")
	topBar.Size             = UDim2.new(1,0,0,4)
	topBar.BackgroundColor3 = hero.color
	topBar.BorderSizePixel  = 0
	topBar.Parent           = card
	corner(topBar, 4)

	-- Раритет
	local rarLbl = Instance.new("TextLabel")
	rarLbl.Size             = UDim2.new(1,-12,0,18)
	rarLbl.Position         = UDim2.new(0,6,0,8)
	rarLbl.BackgroundTransparency = 1
	rarLbl.Text             = hero.rarity:upper()
	rarLbl.TextSize         = 10
	rarLbl.TextColor3       = RARITY_COLOR[hero.rarity] or Color3.new(1,1,1)
	rarLbl.Font             = Enum.Font.GothamBold
	rarLbl.TextXAlignment   = Enum.TextXAlignment.Right
	rarLbl.Parent           = card

	-- Японское имя (декор)
	local jpLbl = Instance.new("TextLabel")
	jpLbl.Size             = UDim2.new(1,-12,0,28)
	jpLbl.Position         = UDim2.new(0,6,0,24)
	jpLbl.BackgroundTransparency = 1
	jpLbl.Text             = hero.jp
	jpLbl.TextSize         = 16
	jpLbl.TextColor3       = hero.color
	jpLbl.Font             = Enum.Font.GothamBold
	jpLbl.TextXAlignment   = Enum.TextXAlignment.Left
	jpLbl.Parent           = card

	-- Имя
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size             = UDim2.new(1,-12,0,22)
	nameLbl.Position         = UDim2.new(0,6,0,52)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text             = hero.name
	nameLbl.TextSize         = 14
	nameLbl.TextColor3       = Color3.new(1,1,1)
	nameLbl.Font             = Enum.Font.GothamBold
	nameLbl.TextXAlignment   = Enum.TextXAlignment.Left
	nameLbl.Parent           = card

	-- Роль
	local roleLbl = Instance.new("TextLabel")
	roleLbl.Size             = UDim2.new(1,-12,0,16)
	roleLbl.Position         = UDim2.new(0,6,0,74)
	roleLbl.BackgroundTransparency = 1
	roleLbl.Text             = hero.role
	roleLbl.TextSize         = 11
	roleLbl.TextColor3       = Color3.fromRGB(160,160,200)
	roleLbl.Font             = Enum.Font.Gotham
	roleLbl.TextXAlignment   = Enum.TextXAlignment.Left
	roleLbl.Parent           = card

	-- Мини-статы
	local function miniStat(yp, icon, val)
		local f = Instance.new("TextLabel")
		f.Size             = UDim2.new(0.5,-6,0,16)
		f.Position         = UDim2.new(yp > 105 and 0.5 or 0, yp > 105 and 3 or 6, 0, yp)
		f.BackgroundTransparency = 1
		f.Text             = icon .. " " .. val
		f.TextSize         = 11
		f.TextColor3       = Color3.fromRGB(200,200,220)
		f.Font             = Enum.Font.Gotham
		f.TextXAlignment   = Enum.TextXAlignment.Left
		f.Parent           = card
	end
	miniStat(96,  "❤", hero.hp)
	miniStat(96,  "⚔", hero.dmg)  -- правая колонка
	miniStat(112, "💨", hero.spd)

	-- Кнопка-детектор
	local btn = Instance.new("TextButton")
	btn.Size                   = UDim2.new(1,0,1,0)
	btn.BackgroundTransparency = 1
	btn.Text                   = ""
	btn.Parent                 = card

	cardButtons[idx] = { card = card, stroke = cardStroke, hero = hero }

	btn.MouseButton1Click:Connect(function()
		if confirmed then return end
		selectHero(hero)
	end)

	btn.MouseEnter:Connect(function()
		if confirmed then return end
		if selectedHero ~= hero then
			TweenService:Create(card, TweenInfo.new(0.12), {
				BackgroundColor3 = Color3.fromRGB(28,28,50)
			}):Play()
		end
	end)

	btn.MouseLeave:Connect(function()
		if confirmed then return end
		if selectedHero ~= hero then
			TweenService:Create(card, TweenInfo.new(0.12), {
				BackgroundColor3 = Color3.fromRGB(18,18,34)
			}):Play()
		end
	end)

	return card
end

-- ============================================================
-- ОБНОВЛЕНИЕ ДЕТАЛЕЙ
-- ============================================================

local function updateDetails(hero)
	dName.Text           = hero.name
	dJP.Text             = hero.jp
	dRoleRarity.Text     = hero.role .. "  •  " .. hero.rarity
	dRoleRarity.TextColor3 = RARITY_COLOR[hero.rarity] or Color3.fromRGB(160,160,200)
	dDesc.Text           = hero.desc

	-- Статы
	TweenService:Create(fillHP,  TweenInfo.new(0.25), { Size = UDim2.new(math.clamp(hero.hp/280,0,1),0,1,0) }):Play()
	TweenService:Create(fillDMG, TweenInfo.new(0.25), { Size = UDim2.new(math.clamp(hero.dmg/35,0,1),0,1,0) }):Play()
	TweenService:Create(fillSPD, TweenInfo.new(0.25), { Size = UDim2.new(math.clamp(hero.spd/22,0,1),0,1,0) }):Play()

	for i, lbl in ipairs(skillLabels) do
		lbl.Text = hero.skills[i] or "—"
	end

	confirmBtn.BackgroundColor3 = hero.color
end

function selectHero(hero)
	selectedHero = hero
	updateDetails(hero)

	-- Подсветка карточки
	for _, entry in ipairs(cardButtons) do
		local isSelected = (entry.hero == hero)
		TweenService:Create(entry.card, TweenInfo.new(0.15), {
			BackgroundColor3 = isSelected and Color3.fromRGB(28,24,50) or Color3.fromRGB(18,18,34)
		}):Play()
		entry.stroke.Color     = isSelected and hero.color     or Color3.fromRGB(40,40,60)
		entry.stroke.Thickness = isSelected and 2.5 or 1.5
	end
end

-- ============================================================
-- ПОДТВЕРЖДЕНИЕ ВЫБОРА
-- ============================================================

local function confirmHero()
	if confirmed then return end
	confirmed = true
	if timerThread then task.cancel(timerThread) end

	-- Анимация кнопки
	TweenService:Create(confirmBtn, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
		Size = UDim2.new(1,0,0,52)
	}):Play()
	confirmBtn.Text = "✓  ВЫБРАНО"

	rSelectHero:FireServer(selectedHero.id)
end

confirmBtn.MouseButton1Click:Connect(confirmHero)

-- ============================================================
-- ТАЙМЕР
-- ============================================================

local function startTimer(seconds)
	if timerThread then task.cancel(timerThread) end
	timerThread = task.spawn(function()
		local t = seconds
		while t > 0 do
			timerLbl.Text = tostring(t)
			timerLbl.TextColor3 = t <= 5
				and Color3.fromRGB(255,60,60)
				or  Color3.fromRGB(255,220,80)
			if t <= 5 then
				TweenService:Create(timerLbl, TweenInfo.new(0.08, Enum.EasingStyle.Back), {
					TextSize = 42
				}):Play()
				task.delay(0.15, function()
					TweenService:Create(timerLbl, TweenInfo.new(0.15), {
						TextSize = 32
					}):Play()
				end)
			end
			task.wait(1)
			t -= 1
		end
		-- Автовыбор
		if not confirmed then confirmHero() end
	end)
end

-- ============================================================
-- ОТКРЫТЬ / ЗАКРЫТЬ GUI
-- ============================================================

local function openSelector(mode)
	mode = mode or "Normal"
	currentMode = mode
	confirmed = false
	confirmBtn.Text = "ВЫБРАТЬ"

	-- Режим
	local mc = MODE_COLOR[mode] or MODE_COLOR.Normal
	modeLbl.Text = (mode == "OneHit" and "⚡ ONE HIT MODE" or
		mode == "Ranked"  and "🏆 RANKED MODE"  or "NORMAL MODE")
	modeLbl.BackgroundColor3  = mc
	headerAccent.BackgroundColor3 = mc

	gui.Enabled = true

	-- Анимация: карточки влетают снизу
	for _, entry in ipairs(cardButtons) do
		entry.card.Position = UDim2.new(entry.card.Position.X.Scale,
			entry.card.Position.X.Offset,
			entry.card.Position.Y.Scale,
			entry.card.Position.Y.Offset + 60)
		entry.card.BackgroundTransparency = 1
		local delay = ((_ - 1) * 0.025)
		task.delay(delay, function()
			TweenService:Create(entry.card, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
				Position = UDim2.new(entry.card.Position.X.Scale,
					entry.card.Position.X.Offset,
					entry.card.Position.Y.Scale,
					entry.card.Position.Y.Offset - 60)
			}):Play()
		end)
	end

	selectHero(HEROES[1])
	startTimer(25)
end

local function closeSelector()
	if timerThread then task.cancel(timerThread) end
	TweenService:Create(bg, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1
	}):Play()
	task.delay(0.4, function() gui.Enabled = false end)
end

-- ============================================================
-- СТРОИМ КАРТОЧКИ
-- ============================================================

for i, hero in ipairs(HEROES) do
	buildCard(hero, i)
end
updateDetails(HEROES[1])

-- ============================================================
-- REMOTE HANDLERS
-- ============================================================

rMatchFound.OnClientEvent:Connect(function(matchInfo)
	local mode = (type(matchInfo) == "table" and matchInfo.mode) or matchInfo or "Normal"
	openSelector(mode)
end)

rHeroSelected.OnClientEvent:Connect(function(heroId, success)
	if success then
		closeSelector()
	end
end)

rMatchStart.OnClientEvent:Connect(function()
	closeSelector()
end)

print("[HeroSelector] Initialized ✓")
