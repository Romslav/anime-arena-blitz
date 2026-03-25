-- StarterSelectionUI.client.lua | Anime Arena: Blitz
-- ============================================================
-- Экран онбординга: выбор первого героя при первом входе.
-- Реагирует на ShowStarterSelection (FireClient от CharacterService).
-- Закрывается по HeroUnlocked → открывает LobbyUI.
--
-- Продакшн-фичи:
--   • Полноэкранный тёмный оверлей с плавным fade-in / fade-out
--   • Три карточки героев: баннер, эмоджи, роль-бейдж, описание,
--     стат-бары (ATK/DEF/SPD/CTRL), индикатор сложности
--   • Hover-подсветка (glow-обводка + brighten кнопки)
--   • Защита от двойного клика (selectionLocked)
--   • Анимация подтверждения выбора: вспышка + greyscale у остальных
--   • Waiting-лоадер после клика пока сервер не ответит HeroUnlocked
--   • Полная интеграция с LobbyUI через _G.LobbyUI (с fallback)
--   • Декоративные частицы-звёздочки на фоне (RunService loop)
--   • Resize-совместимость (якоря UDim2)
-- ============================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Remotes
local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local rShowStarter   = Remotes:WaitForChild("ShowStarterSelection")
local rSelectStarter = Remotes:WaitForChild("SelectStarter")
local rHeroUnlocked  = Remotes:WaitForChild("HeroUnlocked")

-- ============================================================
-- HERO DATA
-- ============================================================

local HEROES = {
	{
		id         = "FlameRonin",
		name       = "Flame Ronin",
		role       = "ВОИН",
		desc       = "Мастер клинка огня.\nБыстрый, агрессивный, смертоносный.\nИдеален для новичков.",
		primary    = Color3.fromRGB(255, 80,  30),
		secondary  = Color3.fromRGB(180, 40,  10),
		glow       = Color3.fromRGB(255, 160, 60),
		stats      = { ATK = 85, DEF = 50, SPD = 75, CTRL = 40 },
		difficulty = "★★☆☆☆",
		emoji      = "🔥",
	},
	{
		id         = "IronTitan",
		name       = "Iron Titan",
		role       = "ТАНК",
		desc       = "Непробиваемая броня стали.\nЗащищает союзников, держит линию.\nОтличный выбор для контроля.",
		primary    = Color3.fromRGB(160, 160, 190),
		secondary  = Color3.fromRGB(80,  80,  110),
		glow       = Color3.fromRGB(210, 210, 240),
		stats      = { ATK = 55, DEF = 95, SPD = 45, CTRL = 70 },
		difficulty = "★★★☆☆",
		emoji      = "🛡️",
	},
	{
		id         = "ThunderMonk",
		name       = "Thunder Monk",
		role       = "МАГ",
		desc       = "Молнии повинуются его воле.\nДальняя атака и контроль толпы.\nДля опытных игроков.",
		primary    = Color3.fromRGB(80,  170, 255),
		secondary  = Color3.fromRGB(40,  80,  180),
		glow       = Color3.fromRGB(140, 210, 255),
		stats      = { ATK = 90, DEF = 35, SPD = 60, CTRL = 90 },
		difficulty = "★★★★☆",
		emoji      = "⚡",
	},
}

local STAT_COLORS = {
	ATK  = Color3.fromRGB(255, 80,  80),
	DEF  = Color3.fromRGB(80,  180, 255),
	SPD  = Color3.fromRGB(80,  220, 120),
	CTRL = Color3.fromRGB(200, 100, 255),
}

local STAT_ORDER = { "ATK", "DEF", "SPD", "CTRL" }

-- ============================================================
-- HELPERS
-- ============================================================

local function tw(inst, t, props, style, dir)
	return TweenService:Create(inst,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props)
end

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
	return c
end

local function uiStroke(p, col, th)
	local s = Instance.new("UIStroke")
	s.Color     = col or Color3.new(1, 1, 1)
	s.Thickness = th  or 1.5
	s.Parent    = p
	return s
end

local function newLabel(parent, props)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.TextWrapped            = true
	for k, v in pairs(props) do lbl[k] = v end
	lbl.Parent = parent
	return lbl
end

-- ============================================================
-- ROOT GUI  (DisplayOrder 100 — поверх всего)
-- ============================================================

local gui = Instance.new("ScreenGui")
gui.Name          = "StarterSelection"
gui.ResetOnSpawn  = false
gui.DisplayOrder  = 100
gui.Enabled       = false
gui.Parent        = PlayerGui

-- Полноэкранный фон
local bg = Instance.new("Frame")
bg.Size                  = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3      = Color3.fromRGB(8, 8, 20)
bg.BackgroundTransparency = 1      -- старт: прозрачный, анимируем
bg.BorderSizePixel       = 0
bg.Parent                = gui

-- Декоративные золотые линии сверху и снизу
local function borderLine(yPos)
	local f = Instance.new("Frame")
	f.Size             = UDim2.new(1, 0, 0, 2)
	f.Position         = UDim2.new(0, 0, yPos, 0)
	f.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	f.BackgroundTransparency = 0.3
	f.BorderSizePixel  = 0
	f.ZIndex           = 6
	f.Parent           = bg
	return f
end
borderLine(0)
borderLine(1)   -- bottom: position Y=1 → нижний край

-- ============================================================
-- ФОНОВЫЕ ЧАСТИЦЫ (звёздочки)
-- ============================================================

local STAR_COUNT = 40
local stars = {}

for i = 1, STAR_COUNT do
	local s = Instance.new("Frame")
	s.Size             = UDim2.new(0, math.random(1, 3), 0, math.random(1, 3))
	s.Position         = UDim2.new(math.random(), 0, math.random(), 0)
	s.BackgroundColor3 = Color3.fromRGB(200, 200, 255)
	s.BackgroundTransparency = math.random() * 0.5 + 0.4
	s.BorderSizePixel  = 0
	s.ZIndex           = 2
	s.Parent           = bg
	corner(s, 2)
	stars[i] = { frame = s, speed = math.random() * 0.00008 + 0.00003, offset = math.random() }
end

-- ============================================================
-- ЗАГОЛОВОК
-- ============================================================

local titleFrame = Instance.new("Frame")
titleFrame.Size                  = UDim2.new(1, 0, 0, 110)
titleFrame.Position               = UDim2.new(0, 0, 0, 0)
titleFrame.BackgroundTransparency = 1
titleFrame.ZIndex                 = 5
titleFrame.Parent                 = bg

newLabel(titleFrame, {
	Size          = UDim2.new(1, 0, 0, 58),
	Position      = UDim2.new(0, 0, 0, 20),
	Text          = "ВЫБЕРИТЕ ВАШЕГО ПЕРВОГО ГЕРОЯ",
	TextSize      = 30,
	Font          = Enum.Font.GothamBlack,
	TextColor3    = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.4,
	TextStrokeColor3       = Color3.fromRGB(255, 140, 0),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex        = 6,
})

newLabel(titleFrame, {
	Size          = UDim2.new(0.85, 0, 0, 28),
	Position      = UDim2.new(0.075, 0, 0, 76),
	Text          = "Этот герой начнёт вашу коллекцию. Остальных можно получить в Колодце Желаний.",
	TextSize      = 14,
	Font          = Enum.Font.Gotham,
	TextColor3    = Color3.fromRGB(150, 150, 195),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex        = 6,
})

-- ============================================================
-- КОНТЕЙНЕР КАРТОЧЕК
-- ============================================================

local cardsFrame = Instance.new("Frame")
cardsFrame.Size                  = UDim2.new(0, 870, 0, 430)
cardsFrame.Position               = UDim2.new(0.5, -435, 0.5, -185)
cardsFrame.BackgroundTransparency = 1
cardsFrame.ZIndex                 = 4
cardsFrame.Parent                 = bg

local layout = Instance.new("UIListLayout")
layout.FillDirection      = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment   = Enum.VerticalAlignment.Center
layout.Padding             = UDim.new(0, 22)
layout.Parent              = cardsFrame

-- ============================================================
-- СТАТУС-ЛЕЙБЛ (ожидание ответа сервера)
-- ============================================================

local statusLbl = newLabel(bg, {
	Size          = UDim2.new(1, 0, 0, 32),
	Position      = UDim2.new(0, 0, 1, -42),
	Text          = "",
	TextSize      = 15,
	Font          = Enum.Font.GothamBold,
	TextColor3    = Color3.fromRGB(255, 220, 80),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex        = 8,
})

-- ============================================================
-- СТРОИМ КАРТОЧКУ ГЕРОЯ
-- ============================================================

local selectionLocked = false
local cardObjects     = {}   -- { hero, card, cardStroke, btn }

local function buildStatBar(parent, label, value, yOffset)
	local row = Instance.new("Frame")
	row.Size                  = UDim2.new(1, -22, 0, 14)
	row.Position               = UDim2.new(0, 11, 0, yOffset)
	row.BackgroundTransparency = 1
	row.ZIndex                 = 7
	row.Parent                 = parent

	-- Название стата
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size                   = UDim2.new(0, 36, 1, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text                   = label
	nameLbl.TextSize               = 11
	nameLbl.Font                   = Enum.Font.GothamBold
	nameLbl.TextColor3             = STAT_COLORS[label]
	nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
	nameLbl.ZIndex                 = 8
	nameLbl.Parent                 = row

	-- Трек
	local track = Instance.new("Frame")
	track.Size             = UDim2.new(1, -42, 0, 7)
	track.Position          = UDim2.new(0, 42, 0.5, -3)
	track.BackgroundColor3 = Color3.fromRGB(18, 18, 38)
	track.BorderSizePixel  = 0
	track.ZIndex           = 8
	track.Parent           = row
	corner(track, 3)

	-- Заполнение
	local fill = Instance.new("Frame")
	fill.Size             = UDim2.new(value / 100, 0, 1, 0)
	fill.BackgroundColor3 = STAT_COLORS[label]
	fill.BorderSizePixel  = 0
	fill.ZIndex           = 9
	fill.Parent           = track
	corner(fill, 3)

	-- Значение
	local valLbl = Instance.new("TextLabel")
	valLbl.Size                   = UDim2.new(0, 28, 1, 0)
	valLbl.Position               = UDim2.new(1, -28, 0, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.Text                   = tostring(value)
	valLbl.TextSize               = 10
	valLbl.Font                   = Enum.Font.GothamBold
	valLbl.TextColor3             = Color3.fromRGB(210, 210, 230)
	valLbl.TextXAlignment         = Enum.TextXAlignment.Right
	valLbl.ZIndex                 = 10
	valLbl.Parent                 = row
end

local function buildHeroCard(hero, idx)
	-- ── Основная карточка ──────────────────────────────────
	local card = Instance.new("Frame")
	card.Name             = hero.id
	card.Size             = UDim2.new(0, 262, 0, 430)
	card.BackgroundColor3 = Color3.fromRGB(14, 14, 28)
	card.BorderSizePixel  = 0
	card.ZIndex           = 5
	card.LayoutOrder      = idx
	card.Parent           = cardsFrame
	corner(card, 16)
	local cardStroke = uiStroke(card, hero.secondary, 2)

	-- ── Цветной баннер сверху ─────────────────────────────
	local banner = Instance.new("Frame")
	banner.Size             = UDim2.new(1, 0, 0, 105)
	banner.BackgroundColor3 = hero.primary
	banner.BorderSizePixel  = 0
	banner.ZIndex           = 6
	banner.Parent           = card
	corner(banner, 16)

	-- Закрываем нижние скруглённые углы баннера прямоугольной плашкой
	local bannerFloor = Instance.new("Frame")
	bannerFloor.Size             = UDim2.new(1, 0, 0, 24)
	bannerFloor.Position          = UDim2.new(0, 0, 1, -24)
	bannerFloor.BackgroundColor3 = hero.primary
	bannerFloor.BorderSizePixel  = 0
	bannerFloor.ZIndex           = 6
	bannerFloor.Parent           = banner

	-- Эмоджи персонажа
	local emojiLbl = Instance.new("TextLabel")
	emojiLbl.Size                   = UDim2.new(1, 0, 1, 0)
	emojiLbl.BackgroundTransparency = 1
	emojiLbl.Text                   = hero.emoji
	emojiLbl.TextSize               = 52
	emojiLbl.Font                   = Enum.Font.GothamBlack
	emojiLbl.TextXAlignment         = Enum.TextXAlignment.Center
	emojiLbl.TextYAlignment         = Enum.TextYAlignment.Center
	emojiLbl.ZIndex                 = 7
	emojiLbl.Parent                 = banner

	-- ── Имя ───────────────────────────────────────────────
	newLabel(card, {
		Size          = UDim2.new(1, -16, 0, 28),
		Position      = UDim2.new(0, 8, 0, 108),
		Text          = hero.name,
		TextSize      = 20,
		Font          = Enum.Font.GothamBlack,
		TextColor3    = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex        = 7,
	})

	-- ── Роль-бейдж ────────────────────────────────────────
	local roleBadge = Instance.new("Frame")
	roleBadge.Size             = UDim2.new(0, 78, 0, 22)
	roleBadge.Position          = UDim2.new(0.5, -39, 0, 139)
	roleBadge.BackgroundColor3 = hero.primary
	roleBadge.BorderSizePixel  = 0
	roleBadge.ZIndex           = 7
	roleBadge.Parent           = card
	corner(roleBadge, 5)

	newLabel(roleBadge, {
		Size          = UDim2.new(1, 0, 1, 0),
		Text          = hero.role,
		TextSize      = 11,
		Font          = Enum.Font.GothamBold,
		TextColor3    = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex        = 8,
	})

	-- ── Описание ──────────────────────────────────────────
	newLabel(card, {
		Size          = UDim2.new(1, -20, 0, 70),
		Position      = UDim2.new(0, 10, 0, 167),
		Text          = hero.desc,
		TextSize      = 12,
		Font          = Enum.Font.Gotham,
		TextColor3    = Color3.fromRGB(170, 170, 205),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex        = 7,
	})

	-- ── Разделитель ───────────────────────────────────────
	local divider = Instance.new("Frame")
	divider.Size             = UDim2.new(1, -30, 0, 1)
	divider.Position          = UDim2.new(0, 15, 0, 242)
	divider.BackgroundColor3 = hero.primary
	divider.BackgroundTransparency = 0.55
	divider.BorderSizePixel  = 0
	divider.ZIndex           = 7
	divider.Parent           = card

	-- ── Стат-бары ─────────────────────────────────────────
	for i, statKey in ipairs(STAT_ORDER) do
		buildStatBar(card, statKey, hero.stats[statKey], 248 + (i - 1) * 20)
	end

	-- ── Сложность ─────────────────────────────────────────
	newLabel(card, {
		Size          = UDim2.new(1, -20, 0, 18),
		Position      = UDim2.new(0, 10, 0, 334),
		Text          = "Сложность: " .. hero.difficulty,
		TextSize      = 11,
		Font          = Enum.Font.GothamBold,
		TextColor3    = Color3.fromRGB(255, 220, 80),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex        = 7,
	})

	-- ── Кнопка ВЫБРАТЬ ────────────────────────────────────
	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(1, -24, 0, 46)
	btn.Position          = UDim2.new(0, 12, 1, -58)
	btn.BackgroundColor3 = hero.primary
	btn.BorderSizePixel  = 0
	btn.Text             = "ВЫБРАТЬ"
	btn.TextSize         = 16
	btn.Font             = Enum.Font.GothamBlack
	btn.TextColor3       = Color3.new(1, 1, 1)
	btn.ZIndex           = 8
	btn.AutoButtonColor  = false
	btn.Parent           = card
	corner(btn, 10)
	local btnStroke = uiStroke(btn, hero.glow, 1.5)

	-- ── Hover-эффекты ─────────────────────────────────────
	btn.MouseEnter:Connect(function()
		if selectionLocked then return end
		tw(card,      0.16, { BackgroundColor3 = Color3.fromRGB(20, 20, 44) }):Play()
		tw(cardStroke,0.16, { Color = hero.glow, Thickness = 3 }):Play()
		tw(btn,       0.16, { BackgroundColor3 = hero.glow }):Play()
		tw(btnStroke, 0.16, { Thickness = 2 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		if selectionLocked then return end
		tw(card,      0.16, { BackgroundColor3 = Color3.fromRGB(14, 14, 28) }):Play()
		tw(cardStroke,0.16, { Color = hero.secondary, Thickness = 2 }):Play()
		tw(btn,       0.16, { BackgroundColor3 = hero.primary }):Play()
		tw(btnStroke, 0.16, { Thickness = 1.5 }):Play()
	end)

	-- ── Клик: выбор героя ─────────────────────────────────
	btn.MouseButton1Click:Connect(function()
		if selectionLocked then return end
		selectionLocked = true

		-- Вспышка выбранной карточки
		tw(card, 0.10, { BackgroundColor3 = hero.glow }):Play()
		task.delay(0.11, function()
			tw(card, 0.28, { BackgroundColor3 = Color3.fromRGB(14, 14, 28) }):Play()
		end)
		tw(cardStroke, 0.15, { Color = hero.glow, Thickness = 4 }):Play()

		-- Greyscale на остальных
		for _, co in ipairs(cardObjects) do
			if co.hero.id ~= hero.id then
				tw(co.card,      0.3,  { BackgroundTransparency = 0.65 }):Play()
				tw(co.cardStroke,0.3,  { Color = Color3.fromRGB(40, 40, 60), Thickness = 1 }):Play()
				co.btn.Interactable = false
				tw(co.btn, 0.3, { BackgroundColor3 = Color3.fromRGB(40, 40, 60) }):Play()
			end
		end

		btn.Text        = "✓ ВЫБРАНО!"
		btn.Interactable = false

		-- Статус-лейбл
		statusLbl.Text = "Открываем героя, подождите..."
		tw(statusLbl, 0.3, { TextTransparency = 0 }):Play()

		-- Отправляем на сервер
		rSelectStarter:FireServer(hero.id)
	end)

	cardObjects[idx] = { hero = hero, card = card, cardStroke = cardStroke, btn = btn }
end

for i, heroData in ipairs(HEROES) do
	buildHeroCard(heroData, i)
end

-- ============================================================
-- АНИМАЦИЯ ПОЯВЛЕНИЯ
-- ============================================================

local function showUI()
	gui.Enabled       = true
	selectionLocked   = false
	statusLbl.Text    = ""
	statusLbl.TextTransparency = 1

	-- Сброс карточек
	for _, co in ipairs(cardObjects) do
		co.card.BackgroundTransparency  = 0
		co.card.BackgroundColor3        = Color3.fromRGB(14, 14, 28)
		co.cardStroke.Color             = co.hero.secondary
		co.cardStroke.Thickness         = 2
		co.btn.Interactable             = true
		co.btn.Text                     = "ВЫБРАТЬ"
		co.btn.BackgroundColor3         = co.hero.primary
	end

	-- Fade-in фон
	bg.BackgroundTransparency = 1
	tw(bg, 0.5, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine):Play()

	-- Карточки вылетают снизу с задержкой
	for i, co in ipairs(cardObjects) do
		co.card.Position = UDim2.new(co.card.Position.X.Scale,
			co.card.Position.X.Offset,
			co.card.Position.Y.Scale,
			co.card.Position.Y.Offset + 80)
		co.card.BackgroundTransparency = 1
		task.delay((i - 1) * 0.09 + 0.25, function()
			tw(co.card, 0.45, {
				Position = UDim2.new(
					co.card.Position.X.Scale,
					co.card.Position.X.Offset,
					co.card.Position.Y.Scale,
					co.card.Position.Y.Offset - 80),
				BackgroundTransparency = 0,
			}, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
		end)
	end
end

-- ============================================================
-- АНИМАЦИЯ ЗАКРЫТИЯ → открываем LobbyUI
-- ============================================================

local function hideUI(heroId)
	statusLbl.Text = "🎉 " .. (heroId or "") .. " разблокирован!"
	tw(statusLbl, 0.2, { TextTransparency = 0 }):Play()

	task.delay(1.0, function()
		-- Fade-out
		tw(bg, 0.55, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine):Play()
		task.delay(0.6, function()
			gui.Enabled = false

			-- Открываем лобби: поддерживаем _G.LobbyUI.Show() и прямой поиск ScreenGui
			local opened = false

			-- Способ 1: _G.LobbyUI (если LobbyUI.client.lua экспортирует модуль)
			if type(_G.LobbyUI) == "table" and type(_G.LobbyUI.Show) == "function" then
				_G.LobbyUI.Show()
				opened = true
			end

			-- Способ 2: ищем ScreenGui «LobbyUI» в PlayerGui (fallback)
			if not opened then
				local lobbyGui = PlayerGui:FindFirstChild("LobbyUI")
				if lobbyGui and lobbyGui:IsA("ScreenGui") then
					lobbyGui.Enabled = true
					opened = true
				end
			end

			if not opened then
				warn("[StarterSelectionUI] Не удалось открыть LobbyUI — проверь экспорт _G.LobbyUI")
			end
		end)
	end)
end

-- ============================================================
-- REMOTE-ОБРАБОТЧИКИ
-- ============================================================

rShowStarter.OnClientEvent:Connect(function()
	-- Скрываем любые другие UI (лобби, HUD) на время онбординга
	local lobbyGui = PlayerGui:FindFirstChild("LobbyUI")
	if lobbyGui then lobbyGui.Enabled = false end

	local hudGui = PlayerGui:FindFirstChild("HUD")
	if hudGui then hudGui.Enabled = false end

	showUI()
end)

rHeroUnlocked.OnClientEvent:Connect(function(heroId)
	-- Срабатывает только если наш экран активен
	if not gui.Enabled then return end
	hideUI(heroId)
end)

-- ============================================================
-- ФОНОВАЯ АНИМАЦИЯ ЗВЁЗДОЧЕК
-- ============================================================

RunService.Heartbeat:Connect(function(dt)
	if not gui.Enabled then return end
	for _, s in ipairs(stars) do
		local newY = (s.frame.Position.Y.Scale + s.speed * dt * 60) % 1
		s.frame.Position = UDim2.new(s.frame.Position.X.Scale, 0, newY, 0)
	end
end)

-- ============================================================

print("[StarterSelectionUI] Initialized ✓")
