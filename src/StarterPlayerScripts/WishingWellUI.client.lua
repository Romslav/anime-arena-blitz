-- WishingWellUI.client.lua | Anime Arena: Blitz Mode
-- Полный клиентский интерфейс "Колодец Желаний" (Гача-рулетка)
-- Логика: ProximityPrompt → Попап выбора → Крутка → Reveal-карточка + партиклы + звук

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

local Remotes            = ReplicatedStorage:WaitForChild("Remotes")
local rRollGacha         = Remotes:WaitForChild("RollGacha",         10)
local rWishingWellResult = Remotes:WaitForChild("WishingWellResult", 10)
local rUpdateHUD         = Remotes:WaitForChild("UpdateHUD",         10)

-- ============================================================
-- КОНФИГУРАЦИЯ РЕДКОСТЕЙ
-- ============================================================

local RARITY_CONFIG = {
	Legendary = {
		color      = Color3.fromRGB(255, 215, 0),
		glow       = Color3.fromRGB(255, 180, 0),
		shineColor = Color3.fromRGB(255, 255, 200),
		label      = "✨ ЛЕГЕНДАРНЫЙ",
		soundId    = "rbxassetid://9113533987",  -- Legendary fanfare
		particles  = true,
		bgGrad     = { Color3.fromRGB(80, 50, 0), Color3.fromRGB(30, 15, 0) },
	},
	Epic = {
		color      = Color3.fromRGB(163, 53, 238),
		glow       = Color3.fromRGB(200, 100, 255),
		shineColor = Color3.fromRGB(230, 180, 255),
		label      = "💜 ЭПИЧЕСКИЙ",
		soundId    = "rbxassetid://9113540150",  -- Epic reveal
		particles  = true,
		bgGrad     = { Color3.fromRGB(50, 10, 70), Color3.fromRGB(20, 5, 35) },
	},
	Rare = {
		color      = Color3.fromRGB(41, 128, 255),
		glow       = Color3.fromRGB(80, 160, 255),
		shineColor = Color3.fromRGB(180, 210, 255),
		label      = "💙 РЕДКИЙ",
		soundId    = "rbxassetid://9113546987",  -- Rare chime
		particles  = false,
		bgGrad     = { Color3.fromRGB(10, 30, 70), Color3.fromRGB(5, 15, 40) },
	},
	Common = {
		color      = Color3.fromRGB(180, 180, 180),
		glow       = Color3.fromRGB(200, 200, 200),
		shineColor = Color3.fromRGB(230, 230, 230),
		label      = "⚪ ОБЫЧНЫЙ",
		soundId    = "rbxassetid://9113552000",  -- Common click
		particles  = false,
		bgGrad     = { Color3.fromRGB(30, 30, 30), Color3.fromRGB(15, 15, 15) },
	},
}

-- Красивые отображаемые имена героев
local HERO_DISPLAY = {
	VoidAssassin   = "Void Assassin",
	EclipseHero    = "Eclipse Hero",
	BloodSage      = "Blood Sage",
	ShadowTwin     = "Shadow Twin",
	NeonBlitz      = "Neon Blitz",
	CrystalGuard   = "Crystal Guard",
	ScarletArcher  = "Scarlet Archer",
	JadeSentinel   = "Jade Sentinel",
	StormDancer    = "Storm Dancer",
	FlameRonin     = "Flame Ronin",
	IronTitan      = "Iron Titan",
	ThunderMonk    = "Thunder Monk",
}

local function getHeroDisplayName(heroId)
	return HERO_DISPLAY[heroId] or heroId
end

-- ============================================================
-- СОСТОЯНИЕ
-- ============================================================

local isRolling     = false   -- дебаунс крутки
local isPopupOpen   = false   -- дебаунс попапа
local currentCoins  = 0
local currentNormalPity = 0
local currentEpicPity   = 0

-- ============================================================
-- ЗВУКИ
-- ============================================================

local function playSound(soundId)
	if not soundId or soundId == "" then return end
	local s = Instance.new("Sound")
	s.SoundId   = soundId
	s.Volume    = 0.7
	s.RollOffMaxDistance = 0  -- 2D звук
	s.Parent    = SoundService
	s:Play()
	game:GetService("Debris"):AddItem(s, 5)
end

local function playClickSound()
	playSound("rbxassetid://6895079853")
end

local function playSpinSound()
	playSound("rbxassetid://9113500000")
end

-- ============================================================
-- ПОСТРОЕНИЕ UI
-- ============================================================

local function buildUI()
	local existing = playerGui:FindFirstChild("WishingWellUI")
	if existing then existing:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name            = "WishingWellUI"
	screenGui.ResetOnSpawn    = false
	screenGui.IgnoreGuiInset  = true
	screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
	screenGui.Parent          = playerGui

	-- ── Фон блюра ──────────────────────────────────────────────
	local backdrop = Instance.new("Frame")
	backdrop.Name            = "Backdrop"
	backdrop.Size            = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3= Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.ZIndex          = 10
	backdrop.Visible         = false
	backdrop.Parent          = screenGui

	-- ── Главный попап выбора ───────────────────────────────────
	local popup = Instance.new("Frame")
	popup.Name               = "Popup"
	popup.AnchorPoint        = Vector2.new(0.5, 0.5)
	popup.Position           = UDim2.fromScale(0.5, 0.5)
	popup.Size               = UDim2.new(0, 500, 0, 400)
	popup.BackgroundColor3   = Color3.fromRGB(15, 10, 30)
	popup.BorderSizePixel    = 0
	popup.ZIndex             = 11
	popup.Visible            = false
	popup.Parent             = screenGui

	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 18)
	popupCorner.Parent       = popup

	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color     = Color3.fromRGB(255, 215, 0)
	popupStroke.Thickness = 2
	popupStroke.Parent    = popup

	-- Заголовок
	local title = Instance.new("TextLabel")
	title.Name               = "Title"
	title.Size               = UDim2.new(1, -40, 0, 60)
	title.Position           = UDim2.new(0, 20, 0, 15)
	title.BackgroundTransparency = 1
	title.Text               = "🌊  Колодец Желаний"
	title.TextColor3         = Color3.fromRGB(255, 215, 0)
	title.TextScaled         = true
	title.Font               = Enum.Font.GothamBold
	title.ZIndex             = 12
	title.Parent             = popup

	-- Подзаголовок
	local sub = Instance.new("TextLabel")
	sub.Name                 = "Subtitle"
	sub.Size                 = UDim2.new(1, -40, 0, 30)
	sub.Position             = UDim2.new(0, 20, 0, 75)
	sub.BackgroundTransparency = 1
	sub.Text                 = "Выбери тип сундука для крутки"
	sub.TextColor3           = Color3.fromRGB(180, 180, 220)
	sub.TextScaled           = true
	sub.Font                 = Enum.Font.Gotham
	sub.ZIndex               = 12
	sub.Parent               = popup

	-- Монеты игрока
	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name              = "CoinsLabel"
	coinsLabel.Size              = UDim2.new(1, -40, 0, 25)
	coinsLabel.Position          = UDim2.new(0, 20, 0, 105)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Text              = "💰 Монеты: ..."
	coinsLabel.TextColor3        = Color3.fromRGB(255, 230, 100)
	coinsLabel.TextScaled        = true
	coinsLabel.Font              = Enum.Font.Gotham
	coinsLabel.ZIndex            = 12
	coinsLabel.Parent            = popup

	-- Pity строка
	local pityLabel = Instance.new("TextLabel")
	pityLabel.Name               = "PityLabel"
	pityLabel.Size               = UDim2.new(1, -40, 0, 22)
	pityLabel.Position           = UDim2.new(0, 20, 0, 130)
	pityLabel.BackgroundTransparency = 1
	pityLabel.Text               = "🎯 Гарант: Обыч 0/50 · Эпик 0/20"
	pityLabel.TextColor3         = Color3.fromRGB(150, 150, 200)
	pityLabel.TextScaled         = true
	pityLabel.Font               = Enum.Font.Gotham
	pityLabel.ZIndex             = 12
	pityLabel.Parent             = popup

	-- ── Кнопки ─────────────────────────────────────────────────
	local function makeChestButton(name, yPos, mainColor, hoverColor, labelText, costText, desc)
		local btn = Instance.new("TextButton")
		btn.Name              = name
		btn.Size              = UDim2.new(1, -40, 0, 70)
		btn.Position          = UDim2.new(0, 20, 0, yPos)
		btn.BackgroundColor3  = mainColor
		btn.BorderSizePixel   = 0
		btn.Text              = ""
		btn.ZIndex            = 12
		btn.Parent            = popup

		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 12)
		bCorner.Parent       = btn

		local bStroke = Instance.new("UIStroke")
		bStroke.Color     = hoverColor
		bStroke.Thickness = 1.5
		bStroke.Parent    = btn

		local bLabel = Instance.new("TextLabel")
		bLabel.Size              = UDim2.new(0.6, 0, 0.55, 0)
		bLabel.Position          = UDim2.new(0, 15, 0, 5)
		bLabel.BackgroundTransparency = 1
		bLabel.Text              = labelText
		bLabel.TextColor3        = Color3.fromRGB(255, 255, 255)
		bLabel.TextScaled        = true
		bLabel.Font              = Enum.Font.GothamBold
		bLabel.ZIndex            = 13
		bLabel.TextXAlignment    = Enum.TextXAlignment.Left
		bLabel.Parent            = btn

		local bDesc = Instance.new("TextLabel")
		bDesc.Size               = UDim2.new(0.6, 0, 0.4, 0)
		bDesc.Position           = UDim2.new(0, 15, 0.55, 0)
		bDesc.BackgroundTransparency = 1
		bDesc.Text               = desc
		bDesc.TextColor3         = Color3.fromRGB(200, 200, 230)
		bDesc.TextScaled         = true
		bDesc.Font               = Enum.Font.Gotham
		bDesc.ZIndex             = 13
		bDesc.TextXAlignment     = Enum.TextXAlignment.Left
		bDesc.Parent             = btn

		local bCost = Instance.new("TextLabel")
		bCost.Name               = "Cost"
		bCost.Size               = UDim2.new(0.38, 0, 1, 0)
		bCost.Position           = UDim2.new(0.62, 0, 0, 0)
		bCost.BackgroundTransparency = 1
		bCost.Text               = costText
		bCost.TextColor3         = Color3.fromRGB(255, 230, 100)
		bCost.TextScaled         = true
		bCost.Font               = Enum.Font.GothamBold
		bCost.ZIndex             = 13
		bCost.TextXAlignment     = Enum.TextXAlignment.Right
		bCost.Parent             = btn

		-- Hover-анимация
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = hoverColor }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = mainColor }):Play()
		end)

		return btn
	end

	local normalBtn = makeChestButton(
		"NormalBtn", 165,
		Color3.fromRGB(30, 50, 100),
		Color3.fromRGB(50, 80, 160),
		"🎁  Обычный сундук",
		"💰 500",
		"Legendary 3% · Epic 12% · Pity 50"
	)

	local epicBtn = makeChestButton(
		"EpicBtn", 250,
		Color3.fromRGB(60, 20, 90),
		Color3.fromRGB(100, 40, 150),
		"💜  Эпический сундук",
		"💰 1500",
		"Legendary 15% · Epic 35% · Pity 20"
	)

	-- Кнопка закрытия
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name             = "CloseBtn"
	closeBtn.Size             = UDim2.new(0, 36, 0, 36)
	closeBtn.Position         = UDim2.new(1, -46, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.Text             = "✕"
	closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled       = true
	closeBtn.Font             = Enum.Font.GothamBold
	closeBtn.BorderSizePixel  = 0
	closeBtn.ZIndex           = 14
	closeBtn.Parent           = popup

	local ccorn = Instance.new("UICorner")
	ccorn.CornerRadius = UDim.new(0, 8)
	ccorn.Parent       = closeBtn

	-- ── Спиннер ожидания ───────────────────────────────────────
	local spinner = Instance.new("Frame")
	spinner.Name              = "Spinner"
	spinner.AnchorPoint       = Vector2.new(0.5, 0.5)
	spinner.Position          = UDim2.fromScale(0.5, 0.5)
	spinner.Size              = UDim2.new(0, 320, 0, 180)
	spinner.BackgroundColor3  = Color3.fromRGB(10, 8, 20)
	spinner.BorderSizePixel   = 0
	spinner.ZIndex            = 15
	spinner.Visible           = false
	spinner.Parent            = screenGui

	local spCorner = Instance.new("UICorner")
	spCorner.CornerRadius = UDim.new(0, 16)
	spCorner.Parent       = spinner

	local spLabel = Instance.new("TextLabel")
	spLabel.Name              = "Label"
	spLabel.Size              = UDim2.fromScale(1, 0.5)
	spLabel.Position          = UDim2.fromScale(0, 0.1)
	spLabel.BackgroundTransparency = 1
	spLabel.Text              = "🌀 Колодец просыпается..."
	spLabel.TextColor3        = Color3.fromRGB(200, 180, 255)
	spLabel.TextScaled        = true
	spLabel.Font              = Enum.Font.GothamBold
	spLabel.ZIndex            = 16
	spLabel.Parent            = spinner

	local dots = Instance.new("TextLabel")
	dots.Name                 = "Dots"
	dots.Size                 = UDim2.fromScale(1, 0.35)
	dots.Position             = UDim2.fromScale(0, 0.6)
	dots.BackgroundTransparency = 1
	dots.Text                 = "●  ○  ○"
	dots.TextColor3           = Color3.fromRGB(255, 215, 0)
	dots.TextScaled           = true
	dots.Font                 = Enum.Font.GothamBold
	dots.ZIndex               = 16
	dots.Parent               = spinner

	-- ── Reveal-карточка ────────────────────────────────────────
	local revealFrame = Instance.new("Frame")
	revealFrame.Name          = "RevealFrame"
	revealFrame.AnchorPoint   = Vector2.new(0.5, 0.5)
	revealFrame.Position      = UDim2.fromScale(0.5, 0.5)
	revealFrame.Size          = UDim2.new(0, 420, 0, 520)
	revealFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
	revealFrame.BorderSizePixel  = 0
	revealFrame.ZIndex        = 20
	revealFrame.Visible       = false
	revealFrame.Parent        = screenGui

	local revCorner = Instance.new("UICorner")
	revCorner.CornerRadius = UDim.new(0, 20)
	revCorner.Parent       = revealFrame

	local revStroke = Instance.new("UIStroke")
	revStroke.Name        = "RevStroke"
	revStroke.Color       = Color3.fromRGB(255, 215, 0)
	revStroke.Thickness   = 3
	revStroke.Parent      = revealFrame

	-- Иконка героя (Image)
	local heroIcon = Instance.new("ImageLabel")
	heroIcon.Name             = "HeroIcon"
	heroIcon.AnchorPoint      = Vector2.new(0.5, 0)
	heroIcon.Position         = UDim2.new(0.5, 0, 0, 30)
	heroIcon.Size             = UDim2.new(0, 200, 0, 200)
	heroIcon.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
	heroIcon.BorderSizePixel  = 0
	heroIcon.ZIndex           = 21
	heroIcon.Image            = "rbxassetid://0"  -- будет заменён динамически
	heroIcon.Parent           = revealFrame

	local hiCorner = Instance.new("UICorner")
	hiCorner.CornerRadius = UDim.new(0, 100)
	hiCorner.Parent       = heroIcon

	local hiStroke = Instance.new("UIStroke")
	hiStroke.Name     = "HiStroke"
	hiStroke.Color    = Color3.fromRGB(255, 215, 0)
	hiStroke.Thickness = 4
	hiStroke.Parent   = heroIcon

	-- Заглушка-иконка (эмодзи по редкости, пока нет реального Asset)
	local heroEmoji = Instance.new("TextLabel")
	heroEmoji.Name            = "HeroEmoji"
	heroEmoji.Size            = UDim2.fromScale(1, 1)
	heroEmoji.BackgroundTransparency = 1
	heroEmoji.Text            = "⚔️"
	heroEmoji.TextScaled      = true
	heroEmoji.Font            = Enum.Font.GothamBold
	heroEmoji.ZIndex          = 22
	heroEmoji.Parent          = heroIcon

	-- Метка редкости ("✨ ЛЕГЕНДАРНЫЙ" и т.п.)
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name          = "RarityLabel"
	rarityLabel.AnchorPoint   = Vector2.new(0.5, 0)
	rarityLabel.Position      = UDim2.new(0.5, 0, 0, 240)
	rarityLabel.Size          = UDim2.new(1, -20, 0, 45)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text          = "✨ ЛЕГЕНДАРНЫЙ"
	rarityLabel.TextColor3    = Color3.fromRGB(255, 215, 0)
	rarityLabel.TextScaled    = true
	rarityLabel.Font          = Enum.Font.GothamBold
	rarityLabel.ZIndex        = 21
	rarityLabel.Parent        = revealFrame

	-- Имя героя
	local heroName = Instance.new("TextLabel")
	heroName.Name             = "HeroName"
	heroName.AnchorPoint      = Vector2.new(0.5, 0)
	heroName.Position         = UDim2.new(0.5, 0, 0, 290)
	heroName.Size             = UDim2.new(1, -20, 0, 50)
	heroName.BackgroundTransparency = 1
	heroName.Text             = "Void Assassin"
	heroName.TextColor3       = Color3.fromRGB(255, 255, 255)
	heroName.TextScaled       = true
	heroName.Font             = Enum.Font.GothamBold
	heroName.ZIndex           = 21
	heroName.Parent           = revealFrame

	-- Строка дубликата/нового
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name          = "StatusLabel"
	statusLabel.AnchorPoint   = Vector2.new(0.5, 0)
	statusLabel.Position      = UDim2.new(0.5, 0, 0, 345)
	statusLabel.Size          = UDim2.new(1, -20, 0, 35)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text          = "🆕 Новый герой!"
	statusLabel.TextColor3    = Color3.fromRGB(100, 255, 150)
	statusLabel.TextScaled    = true
	statusLabel.Font          = Enum.Font.Gotham
	statusLabel.ZIndex        = 21
	statusLabel.Parent        = revealFrame

	-- Кнопка «Закрыть» на карточке
	local revCloseBtn = Instance.new("TextButton")
	revCloseBtn.Name          = "RevCloseBtn"
	revCloseBtn.AnchorPoint   = Vector2.new(0.5, 0)
	revCloseBtn.Position      = UDim2.new(0.5, 0, 0, 395)
	revCloseBtn.Size          = UDim2.new(0.6, 0, 0, 50)
	revCloseBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
	revCloseBtn.Text          = "Продолжить"
	revCloseBtn.TextColor3    = Color3.fromRGB(255, 255, 255)
	revCloseBtn.TextScaled    = true
	revCloseBtn.Font          = Enum.Font.GothamBold
	revCloseBtn.BorderSizePixel = 0
	revCloseBtn.ZIndex        = 22
	revCloseBtn.Parent        = revealFrame

	local rcCorner = Instance.new("UICorner")
	rcCorner.CornerRadius = UDim.new(0, 12)
	rcCorner.Parent       = revCloseBtn

	-- Партикл-контейнер (будет наполняться звёздами при Legendary/Epic)
	local particlesFrame = Instance.new("Frame")
	particlesFrame.Name       = "ParticlesFrame"
	particlesFrame.Size       = UDim2.fromScale(1, 1)
	particlesFrame.BackgroundTransparency = 1
	particlesFrame.ZIndex     = 19
	particlesFrame.Parent     = screenGui

	return {
		screenGui      = screenGui,
		backdrop       = backdrop,
		popup          = popup,
		coinsLabel     = coinsLabel,
		pityLabel      = pityLabel,
		normalBtn      = normalBtn,
		epicBtn        = epicBtn,
		closeBtn       = closeBtn,
		spinner        = spinner,
		dots           = dots,
		revealFrame    = revealFrame,
		revStroke      = revStroke,
		hiStroke       = hiStroke,
		heroEmoji      = heroEmoji,
		rarityLabel    = rarityLabel,
		heroName       = heroName,
		statusLabel    = statusLabel,
		revCloseBtn    = revCloseBtn,
		particlesFrame = particlesFrame,
	}
end

-- ============================================================
-- ПАРТИКЛЫ (процедурные звёздочки)
-- ============================================================

local function spawnParticles(ui, rarityColor)
	local frame = ui.particlesFrame
	for i = 1, 24 do
		task.spawn(function()
			task.wait(math.random() * 0.6)
			local star = Instance.new("TextLabel")
			star.Size               = UDim2.new(0, 20, 0, 20)
			star.BackgroundTransparency = 1
			star.Text               = "★"
			star.TextColor3         = rarityColor
			star.TextScaled         = true
			star.Font               = Enum.Font.GothamBold
			star.ZIndex             = 19
			star.Position           = UDim2.new(
				math.random() * 0.85 + 0.05, 0,
				math.random() * 0.7 + 0.1,  0
			)
			star.Parent = frame

			-- Анимация вверх + fade
			local startPos = star.Position
			local endPos   = UDim2.new(
				startPos.X.Scale + (math.random() - 0.5) * 0.2,
				0,
				startPos.Y.Scale - math.random() * 0.3,
				0
			)

			TweenService:Create(star, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position          = endPos,
				TextTransparency  = 1,
			}):Play()

			task.delay(1.3, function()
				if star and star.Parent then star:Destroy() end
			end)
		end)
	end
end

-- ============================================================
-- ПОКАЗАТЬ / СКРЫТЬ ПОПАП
-- ============================================================

local function showPopup(ui)
	if isPopupOpen then return end
	isPopupOpen = true

	ui.backdrop.Visible              = true
	ui.popup.Visible                 = true
	ui.popup.Size                    = UDim2.new(0, 10, 0, 10)
	ui.popup.BackgroundTransparency  = 1
	ui.backdrop.BackgroundTransparency = 1

	-- Обновляем монеты
	ui.coinsLabel.Text = string.format("💰 Монеты: %d", currentCoins)
	ui.pityLabel.Text  = string.format(
		"🎯 Гарант: Обыч %d/50 · Эпик %d/20",
		currentNormalPity, currentEpicPity
	)

	-- Анимация появления
	TweenService:Create(ui.backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(ui.popup, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size                   = UDim2.new(0, 500, 0, 400),
		BackgroundTransparency = 0,
	}):Play()
end

local function hidePopup(ui)
	if not isPopupOpen then return end
	TweenService:Create(ui.backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(ui.popup, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size                   = UDim2.new(0, 10, 0, 10),
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.2, function()
		ui.backdrop.Visible = false
		ui.popup.Visible    = false
		isPopupOpen         = false
	end)
end

-- ============================================================
-- СПИННЕР
-- ============================================================

local spinnerActive = false
local spinnerDotStates = { "●  ○  ○", "○  ●  ○", "○  ○  ●" }
local spinnerDotIdx    = 1

local function showSpinner(ui)
	ui.backdrop.Visible              = true
	ui.backdrop.BackgroundTransparency = 0.55
	ui.spinner.Visible               = true
	ui.spinner.BackgroundTransparency = 1
	ui.spinner.Size                  = UDim2.new(0, 50, 0, 50)

	TweenService:Create(ui.spinner, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 320, 0, 180),
		BackgroundTransparency = 0,
	}):Play()

	spinnerActive = true
	task.spawn(function()
		while spinnerActive do
			spinnerDotIdx = (spinnerDotIdx % 3) + 1
			ui.dots.Text  = spinnerDotStates[spinnerDotIdx]
			task.wait(0.35)
		end
	end)
end

local function hideSpinner(ui)
	spinnerActive = false
	TweenService:Create(ui.spinner, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	task.delay(0.2, function()
		ui.spinner.Visible = false
		ui.backdrop.BackgroundTransparency = 0.55
	end)
end

-- ============================================================
-- REVEAL-КАРТОЧКА
-- ============================================================

local function showReveal(ui, result)
	local cfg = RARITY_CONFIG[result.rarity] or RARITY_CONFIG.Common

	-- Настраиваем цвета карточки
	ui.revStroke.Color    = cfg.color
	ui.hiStroke.Color     = cfg.color
	ui.rarityLabel.Text   = cfg.label
	ui.rarityLabel.TextColor3 = cfg.color
	ui.heroName.Text      = getHeroDisplayName(result.heroId)

	-- Эмодзи по редкости
	local emojiMap = { Legendary = "⚡", Epic = "💜", Rare = "💙", Common = "⚪" }
	ui.heroEmoji.Text     = emojiMap[result.rarity] or "⚔️"
	ui.heroEmoji.TextColor3 = cfg.shineColor

	-- Статус: новый или дублкат
	if result.isDuplicate then
		ui.statusLabel.Text      = string.format("♻️ Дубликат! +%d 💰 монет", result.compensation)
		ui.statusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
	else
		ui.statusLabel.Text      = "🆕 Новый герой разблокирован!"
		ui.statusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
	end

	-- Показываем backdrop + карточку
	ui.backdrop.Visible              = true
	ui.backdrop.BackgroundTransparency = 0.3
	ui.revealFrame.Visible           = true
	ui.revealFrame.Size              = UDim2.new(0, 50, 0, 50)
	ui.revealFrame.BackgroundTransparency = 1

	TweenService:Create(ui.revealFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 420, 0, 480),
		BackgroundTransparency = 0,
	}):Play()

	-- Звук
	playSound(cfg.soundId)

	-- Партиклы для Legendary и Epic
	if cfg.particles then
		spawnParticles(ui, cfg.glow)
		if result.rarity == "Legendary" then
			-- Дополнительный золотой пульс на карточке
			task.spawn(function()
				for _ = 1, 3 do
					TweenService:Create(ui.revStroke, TweenInfo.new(0.3), { Thickness = 6 }):Play()
					task.wait(0.3)
					TweenService:Create(ui.revStroke, TweenInfo.new(0.3), { Thickness = 3 }):Play()
					task.wait(0.3)
				end
			end)
		end
	end

	-- Обновляем pity в попапе для следующего открытия
	if result.pityCount then
		if result.pityMax == 50 then
			currentNormalPity = result.pityCount
		elseif result.pityMax == 20 then
			currentEpicPity = result.pityCount
		end
	end
end

local function hideReveal(ui)
	TweenService:Create(ui.revealFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 50, 0, 50),
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(ui.backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	task.delay(0.25, function()
		ui.revealFrame.Visible = false
		ui.backdrop.Visible    = false
		isRolling              = false
	end)
end

-- ============================================================
-- КРУТКА
-- ============================================================

local function doRoll(ui, chestType)
	if isRolling then return end
	isRolling = true

	-- Скрываем попап, показываем спиннер
	hidePopup(ui)
	task.wait(0.2)

	playSpinSound()
	showSpinner(ui)

	-- Вызываем сервер (InvokeServer блокирует до ответа)
	local result
	local ok, err = pcall(function()
		result = rRollGacha:InvokeServer(chestType)
	end)

	hideSpinner(ui)

	if not ok or not result then
		isRolling = false
		warn("[WishingWellUI] Ошибка InvokeServer:", err)
		-- Показываем попап снова с сообщением об ошибке
		task.spawn(function()
			task.wait(0.2)
			showPopup(ui)
		end)
		return
	end

	if not result.success then
		isRolling = false
		warn("[WishingWellUI] Сервер отказал:", result.message)
		-- Выводим причину отказа в popup
		task.spawn(function()
			task.wait(0.2)
			showPopup(ui)
			ui.coinsLabel.Text = "❌ " .. (result.message or "Ошибка")
		end)
		return
	end

	-- Обновляем монеты локально
	currentCoins = math.max(0, currentCoins - (chestType == "epic" and 1500 or 500))

	-- reveal уже готов (сервер сам отправил rWishingWellResult → showReveal)
	-- но на случай задержки сигнала — показываем из result напрямую
	task.wait(0.1)
	if ui.revealFrame.Visible == false then
		showReveal(ui, result)
	end
end

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ============================================================

local ui = buildUI()

-- Слушаем rWishingWellResult (приходит с сервера)
rWishingWellResult.OnClientEvent:Connect(function(result)
	-- Если reveal ещё не показан — показываем
	if not ui.revealFrame.Visible then
		if ui.spinner.Visible then hideSpinner(ui) end
		showReveal(ui, result)
	end
end)

-- Слушаем UpdateHUD для синхронизации монет
rUpdateHUD.OnClientEvent:Connect(function(data)
	if data and data.coins then
		currentCoins = data.coins
		if ui.coinsLabel then
			ui.coinsLabel.Text = string.format("💰 Монеты: %d", currentCoins)
		end
	end
end)

-- Кнопки попапа
ui.normalBtn.Activated:Connect(function()
	playClickSound()
	doRoll(ui, "normal")
end)

ui.epicBtn.Activated:Connect(function()
	playClickSound()
	doRoll(ui, "epic")
end)

ui.closeBtn.Activated:Connect(function()
	playClickSound()
	hidePopup(ui)
end)

ui.revCloseBtn.Activated:Connect(function()
	playClickSound()
	hideReveal(ui)
end)

-- ESC закрывает всё
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if ui.revealFrame.Visible then
			hideReveal(ui)
		elseif isPopupOpen then
			hidePopup(ui)
		end
	end
end)

-- ============================================================
-- PROXIMITY PROMPT — детект физической модели в мире
-- ============================================================
-- Ищем модель с именем "WishingWell" в Workspace
-- Модель должна иметь Part с именем "WellBase" и ProximityPrompt внутри
-- (либо мы создаём ProximityPrompt динамически)

local function attachToWishingWell(wellModel)
	local base = wellModel:FindFirstChild("WellBase")
			or wellModel:FindFirstChild("Base")
			or wellModel:FindFirstChildWhichIsA("BasePart")
	if not base then return end

	-- Удаляем старый ProximityPrompt если есть
	local existing = base:FindFirstChildOfClass("ProximityPrompt")
	if existing then existing:Destroy() end

	local pp = Instance.new("ProximityPrompt")
	pp.ObjectText    = "🌊 Колодец Желаний"
	pp.ActionText    = "Открыть"
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.HoldDuration  = 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight   = false
	pp.Parent        = base

	pp.Triggered:Connect(function()
		if isRolling then return end
		showPopup(ui)
	end)

	print("[WishingWellUI] ProximityPrompt прикреплён к", wellModel:GetFullName())
end

-- Ищем сразу и при появлении
local function scanForWell(parent)
	for _, obj in ipairs(parent:GetChildren()) do
		if obj.Name == "WishingWell" and obj:IsA("Model") then
			attachToWishingWell(obj)
		end
	end
end

scanForWell(workspace)
workspace.DescendantAdded:Connect(function(obj)
	if obj.Name == "WishingWell" and obj:IsA("Model") then
		attachToWishingWell(obj)
	end
end)

-- ── Fallback: открыть попап кнопкой в лобби-меню если модели нет ────────
-- Если LobbyUI имеет кнопку "WishingWellBtn" — коннектимся к ней
task.delay(3, function()
	local lobbyUi = playerGui:FindFirstChild("LobbyUI")
	if not lobbyUi then return end
	local wellBtn = lobbyUi:FindFirstChild("WishingWellBtn", true)
	if wellBtn and wellBtn:IsA("GuiButton") then
		wellBtn.Activated:Connect(function()
			if not isRolling then
				showPopup(ui)
			end
		end)
		print("[WishingWellUI] Fallback: коннект к LobbyUI.WishingWellBtn")
	end
end)

print("[WishingWellUI] Initialized ✓ — ProximityPrompt + полный UI готов")
