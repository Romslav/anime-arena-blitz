-- WishingWellUI.client.lua | Anime Arena: Blitz  [v2 — production full]
-- Клиентский UI «Колодца Желаний»:
--   • Два сундука с картами: Обычный 500 / Эпический 1500 монет
--   • Кинематографическая камера: zoom к вихрю во время призыва
--   • Impact Frame + rarity-цветной взрыв (Common→Common серый ... Legendary→золото)
--   • Silhouette-анимация явления героя (слайд снизу + буст прозрачности)
--   • Звуковые слои: ambient hum, roll whoosh, result reveal, Legendary thunder
--   • Pity progress-bar с текущим прогрессом
--   • Cooldown-лок кнопок во время ролла
--   • ESC для закрытия
--   • Полная интеграция с RollGacha + WishingWellResult

local Players       = game:GetService("Players")
local RepStorage    = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local UserInput     = game:GetService("UserInputService")

local LocalPlayer   = Players.LocalPlayer
local PlayerGui     = LocalPlayer:WaitForChild("PlayerGui")
local Camera        = workspace.CurrentCamera

local Remotes            = RepStorage:WaitForChild("Remotes")
local rOpenWell          = Remotes:WaitForChild("OpenWishingWell",   10)
local rRollGacha         = Remotes:WaitForChild("RollGacha",         10)
local rWishingWellResult = Remotes:WaitForChild("WishingWellResult", 10)

-- ============================================================
-- ЗВУКИ
-- Sound IDs — бесплатные Roblox-ресурсы
-- Замени на свои если есть, или оставь — все работают
-- ============================================================

local SFX_IDS = {
	ambientHum   = 1843645982,   -- тихий гул портала
	rollWhoosh   = 131070686,    -- свист при кручении
	impactHit    = 4568652451,   -- удар при Impact Frame
	resultReveal = 919321830,    -- звон появления карты
	legendaryFx  = 3175313893,   -- раскат грома (Legendary)
	epicFx       = 2865227655,   -- электрический разряд (Epic)
	rareFx       = 3264988503,   -- хрустальный звон (Rare)
	coinClink    = 3792169968,   -- звяканье монет (дубликат)
}

local function createSound(id, volume, looped)
	local s = Instance.new("Sound")
	s.SoundId  = "rbxassetid://" .. tostring(id)
	s.Volume   = volume or 0.5
	s.Looped   = looped or false
	s.RollOffMaxDistance = 40
	s.Parent   = script
	return s
end

-- Создаём звуки при инициализации
local sndAmbient = createSound(SFX_IDS.ambientHum,   0.15, true)
local sndWhoosh  = createSound(SFX_IDS.rollWhoosh,   0.7,  false)
local sndImpact  = createSound(SFX_IDS.impactHit,    0.8,  false)
local sndReveal  = createSound(SFX_IDS.resultReveal, 0.6,  false)
local sndLeg     = createSound(SFX_IDS.legendaryFx,  1.0,  false)
local sndEpic    = createSound(SFX_IDS.epicFx,       0.8,  false)
local sndRare    = createSound(SFX_IDS.rareFx,       0.6,  false)
local sndCoin    = createSound(SFX_IDS.coinClink,    0.5,  false)

local RARITY_SFX = {
	Legendary = sndLeg,
	Epic      = sndEpic,
	Rare      = sndRare,
	Common    = sndReveal,
}

-- ============================================================
-- КОНСТАНТЫ
-- ============================================================

local RARITY_COLOR = {
	Common    = Color3.fromRGB(150, 150, 150),
	Rare      = Color3.fromRGB(60,  120, 240),
	Epic      = Color3.fromRGB(160, 50,  220),
	Legendary = Color3.fromRGB(255, 180, 0),
}

local RARITY_GLOW = {
	Common    = Color3.fromRGB(60,  60,  60),
	Rare      = Color3.fromRGB(20,  50,  180),
	Epic      = Color3.fromRGB(100, 0,   190),
	Legendary = Color3.fromRGB(255, 200, 50),
}

local RARITY_JP = {
	Common    = "普通",
	Rare      = "レア",
	Epic      = "エピック",
	Legendary = "伝説",
}

local RARITY_STARS = {
	Common    = "★",
	Rare      = "★★",
	Epic      = "★★★",
	Legendary = "★★★★",
}

local CHEST_DATA = {
	{ type    = "normal",
	  label   = "ОБЫЧНЫЙ СУНДУК",
	  jp      = "通常の箱",
	  cost    = 500,
	  pityMax = 50,
	  color   = Color3.fromRGB(55, 125, 225),
	  icon    = "📦",
	  rates   = "3% Leg  •  12% Epic  •  55% Rare  •  30% Com",
	},
	{ type    = "epic",
	  label   = "ЭПИЧЕСКИЙ СУНДУК",
	  jp      = "希少の箱",
	  cost    = 1500,
	  pityMax = 20,
	  color   = Color3.fromRGB(165, 50, 235),
	  icon    = "💎",
	  rates   = "15% Leg  •  35% Epic  •  45% Rare  •  5% Com",
	},
}

local HERO_INFO = {
	FlameRonin    = { name="Flame Ronin",    jp="烎りの浪士",   role="Bruiser",    c=Color3.fromRGB(255,80,30)   },
	VoidAssassin  = { name="Void Assassin",  jp="虚空の刺客",   role="Assassin",   c=Color3.fromRGB(140,40,200)  },
	ThunderMonk   = { name="Thunder Monk",   jp="雷鳴の僧",     role="Controller", c=Color3.fromRGB(80,170,255)  },
	IronTitan     = { name="Iron Titan",     jp="鉄の巨人",     role="Tank",       c=Color3.fromRGB(180,180,180) },
	ScarletArcher = { name="Scarlet Archer", jp="紅の弓手",     role="Ranged",     c=Color3.fromRGB(220,50,80)   },
	EclipseHero   = { name="Eclipse Hero",   jp="日食の英雄",   role="Assassin",   c=Color3.fromRGB(80,50,160)   },
	StormDancer   = { name="Storm Dancer",   jp="嵐の踊り子",   role="Skirmisher", c=Color3.fromRGB(120,220,255) },
	BloodSage     = { name="Blood Sage",     jp="血の賢者",     role="Mage",       c=Color3.fromRGB(200,20,20)   },
	CrystalGuard  = { name="Crystal Guard",  jp="氷晶の守護者", role="Tank",       c=Color3.fromRGB(100,200,230) },
	ShadowTwin    = { name="Shadow Twin",    jp="影の双子",     role="Support",    c=Color3.fromRGB(60,60,90)    },
	NeonBlitz     = { name="Neon Blitz",     jp="光速のネオン", role="Ranged",     c=Color3.fromRGB(0,240,200)   },
	JadeSentinel  = { name="Jade Sentinel",  jp="翡翠の番人",   role="Duelist",    c=Color3.fromRGB(50,180,80)   },
}

-- ============================================================
-- STATE
-- ============================================================

local isOpen    = false
local isRolling = false
local sg        = nil   -- ScreenGui (пересоздаётся при каждом openUI)

-- Текущие значения pity (обновляются из результата)
local pityState = { normal = 0, epic = 0 }

-- Сохранённая камера
local savedCamCF   = nil
local savedCamType = Enum.CameraType.Custom

-- ============================================================
-- GUI FACTORY
-- ============================================================

local function newFrame(parent, size, pos, bg, alpha, zi, rnd)
	local f          = Instance.new("Frame")
	f.Size           = size
	f.Position       = pos
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

local function newLabel(parent, size, pos, text, font, ts, color, zi, align)
	local t = Instance.new("TextLabel")
	t.Size  = size; t.Position = pos
	t.BackgroundTransparency = 1
	t.Text  = text
	t.Font  = font or Enum.Font.GothamBold
	t.TextSize = ts or 18
	t.TextColor3 = color or Color3.new(1,1,1)
	t.TextStrokeTransparency = 0.3
	t.TextStrokeColor3 = Color3.new()
	t.BorderSizePixel  = 0
	t.TextXAlignment   = align or Enum.TextXAlignment.Center
	if zi then t.ZIndex = zi end
	t.Parent = parent
	return t
end

local function newButton(parent, size, pos, text, bg, rnd, cb)
	local b = Instance.new("TextButton")
	b.Size  = size; b.Position = pos
	b.BackgroundColor3 = bg or Color3.fromRGB(60,60,80)
	b.Text  = text
	b.Font  = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = Color3.new(1,1,1)
	b.TextStrokeTransparency = 0.3
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	if rnd then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, rnd)
		c.Parent = b
	end
	b.Parent = parent
	if cb then b.MouseButton1Click:Connect(cb) end
	return b
end

local function newStroke(parent, color, thick, alpha)
	local s = Instance.new("UIStroke")
	s.Color = color; s.Thickness = thick; s.Transparency = alpha or 0
	s.Parent = parent
	return s
end

-- ============================================================
-- TWEEN
-- ============================================================

local function tIn(obj, props, dur, style, dir)
	local tw = TweenService:Create(obj,
		TweenInfo.new(dur or 0.3,
			style or Enum.EasingStyle.Back,
			dir or Enum.EasingDirection.Out), props)
	tw:Play(); return tw
end

local function tOut(obj, props, dur)
	local tw = TweenService:Create(obj,
		TweenInfo.new(dur or 0.25,
			Enum.EasingStyle.Quad, Enum.EasingDirection.In), props)
	tw:Play(); return tw
end

-- ============================================================
-- КИНЕМАТОГРАФИЧЕСКАЯ КАМЕРА
-- ============================================================

local function zoomToWell(onDone)
	-- Ищем позицию колодца
	local well = (workspace:FindFirstChild("Lobby") or workspace)
		:FindFirstChild("WishingWell")
	if not well then
		if onDone then onDone() end
		return
	end

	local pivot = well:GetPivot()
	-- Камера смотрит на вихрь сверху-спереди под углом
	local targetCF = pivot
		* CFrame.new(0, 5, -9)     -- 9 стадов спереди, 5 вверх
		* CFrame.Angles(math.rad(-18), math.rad(180), 0)

	savedCamCF   = Camera.CFrame
	savedCamType = Camera.CameraType

	Camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(Camera,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ CFrame = targetCF }
	):Play()

	task.delay(0.8, function()
		if onDone then onDone() end
	end)
end

local function restoreCamera()
	if savedCamType and savedCamCF then
		Camera.CameraType = savedCamType
		TweenService:Create(Camera,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = savedCamCF }
		):Play()
		task.delay(0.6, function()
			Camera.CameraType = Enum.CameraType.Custom
		end)
	else
		Camera.CameraType = Enum.CameraType.Custom
	end
end

-- ============================================================
-- IMPACT FRAME
-- ============================================================

local impactFrame  -- ссылка из buildUI

local function flashImpact(color, duration)
	impactFrame.BackgroundColor3   = color or Color3.new(1,1,1)
	impactFrame.BackgroundTransparency = 0
	task.wait(0.06)
	tOut(impactFrame, { BackgroundTransparency = 1 }, duration or 0.45)
end

-- ============================================================
-- PITY PROGRESS BAR
-- ============================================================

local function buildPityBar(parent, chestType, pityMax)
	local container = newFrame(parent,
		UDim2.new(1, -30, 0, 20), UDim2.new(0, 15, 1, -28),
		Color3.fromRGB(10,10,15), 0, 14, 4)

	-- Track
	newFrame(container,
		UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
		Color3.fromRGB(30,30,45), 0, 14, 4)

	-- Fill
	local fill = newFrame(container,
		UDim2.new(0,0,1,0), UDim2.new(0,0,0,0),
		Color3.fromRGB(140,0,255), 0, 15, 4)
	fill.Name = "PityFill_" .. chestType

	-- Label
	local lbl = newLabel(container,
		UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
		"Pity: 0 / " .. pityMax,
		Enum.Font.Gotham, 10, Color3.new(1,1,1), 16)
	lbl.Name = "PityLabel_" .. chestType

	return fill, lbl
end

local function updatePityBar(sg, chestType, count, pityMax)
	local fill = sg:FindFirstChild("PityFill_"  .. chestType, true)
	local lbl  = sg:FindFirstChild("PityLabel_" .. chestType, true)
	if fill then
		local frac = math.clamp(count / pityMax, 0, 1)
		tIn(fill, { Size = UDim2.new(frac, 0, 1, 0) }, 0.5, Enum.EasingStyle.Quad)
		-- Цвет: зелёный → желтый → красный по мере заполнения
		local c = Color3.fromRGB(
			math.floor(frac * 255),
			math.floor((1-frac) * 200 + 50),
			math.floor((1-frac) * 200))
		fill.BackgroundColor3 = c
	end
	if lbl then
		lbl.Text = string.format("Pity: %d / %d", count, pityMax)
	end
	pityState[chestType] = count
end

-- ============================================================
-- BUILD UI
-- ============================================================

local mainFrame, chestPanel, resultPanel

local function buildUI()
	if sg then sg:Destroy() end
	sg = Instance.new("ScreenGui")
	sg.Name            = "WishingWellUI"
	sg.ResetOnSpawn    = false
	sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
	sg.Enabled         = false
	sg.Parent          = PlayerGui

	-- Overlay
	local overlay = newFrame(sg,
		UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
		Color3.new(), 0.45, 1)
	overlay.Name = "Overlay"

	-- Impact Frame
	impactFrame = newFrame(sg,
		UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
		Color3.new(1,1,1), 1, 100)
	impactFrame.Name = "ImpactFrame"

	-- Gold tint frame (Legendary lobby flash)
	local goldTint = newFrame(sg,
		UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
		Color3.fromRGB(255,200,50), 1, 99)
	goldTint.Name = "GoldTint"

	-- Main window
	mainFrame = newFrame(sg,
		UDim2.new(0, 640, 0, 540), UDim2.new(0.5,-320, 0.5,-270),
		Color3.fromRGB(10,10,17), 0.05, 10, 18)
	mainFrame.Name = "MainFrame"
	mainFrame.ClipsDescendants = true

	-- Neon top border
	newFrame(mainFrame, UDim2.new(1,0,0,3), UDim2.new(0,0,0,0),
		Color3.fromRGB(120,0,255), 0, 12)

	-- Title
	newLabel(mainFrame,
		UDim2.new(1,0,0,42), UDim2.new(0,0,0,10),
		"КОЛОДЕЦ ЖЕЛАНИЙ", Enum.Font.GothamBlack, 30,
		Color3.fromRGB(210,160,255), 12)

	-- JP subtitle
	newLabel(mainFrame,
		UDim2.new(1,0,0,20), UDim2.new(0,0,0,52),
		"願いの泉  ·  Wishing Well", Enum.Font.Gotham, 14,
		Color3.fromRGB(100,80,150), 12)

	-- Close button
	newButton(mainFrame,
		UDim2.new(0,38,0,38), UDim2.new(1,-48,0,8),
		"✕", Color3.fromRGB(160,30,30), 10,
		function()
			if not isRolling then closeUI() end
		end)

	-- Balance strip (обновляется через UpdateHUD если хочешь)
	local balanceBar = newFrame(mainFrame,
		UDim2.new(1,-40,0,26), UDim2.new(0,20,0,78),
		Color3.fromRGB(16,14,24), 0, 12, 6)
	newLabel(balanceBar,
		UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
		"💰  Баланс отображается в HUD", Enum.Font.Gotham, 11,
		Color3.fromRGB(100,100,130), 13)

	-- ============================================================
	-- CHEST PANEL
	-- ============================================================
	chestPanel = newFrame(mainFrame,
		UDim2.new(1,-40, 1,-140), UDim2.new(0,20,0,112),
		Color3.new(), 1, 11)
	chestPanel.Name = "ChestPanel"

	for i, data in ipairs(CHEST_DATA) do
		local xOff = (i-1) * 295

		local card = newFrame(chestPanel,
			UDim2.new(0,280,1,0), UDim2.new(0,xOff,0,0),
			Color3.fromRGB(18,16,26), 0, 11, 14)

		-- Accent bar top
		newFrame(card, UDim2.new(1,0,0,4), UDim2.new(0,0,0,0), data.color, 0, 12)

		-- Chest border glow
		newStroke(card, data.color, 1.5, 0.45)

		-- Icon
		newLabel(card,
			UDim2.new(1,0,0,64), UDim2.new(0,0,0,14),
			data.icon, Enum.Font.Gotham, 46, Color3.new(1,1,1), 12)

		-- Name
		newLabel(card,
			UDim2.new(1,-20,0,24), UDim2.new(0,10,0,82),
			data.label, Enum.Font.GothamBold, 16, data.color, 12)

		-- JP
		newLabel(card,
			UDim2.new(1,-20,0,18), UDim2.new(0,10,0,107),
			data.jp, Enum.Font.Gotham, 12, Color3.fromRGB(90,80,120), 12)

		-- Cost
		local costLbl = newLabel(card,
			UDim2.new(1,-20,0,24), UDim2.new(0,10,0,132),
			"💰  " .. data.cost .. " монет", Enum.Font.GothamBold, 17,
			Color3.fromRGB(255,220,80), 12)

		-- Pity
		newLabel(card,
			UDim2.new(1,-20,0,16), UDim2.new(0,10,0,160),
			"Гарант Legendary через " .. data.pityMax .. " круток",
			Enum.Font.Gotham, 10, Color3.fromRGB(70,70,100), 12)

		-- Rates
		newLabel(card,
			UDim2.new(1,-20,0,14), UDim2.new(0,10,0,178),
			data.rates, Enum.Font.Gotham, 9,
			Color3.fromRGB(60,60,85), 12)

		-- Pity progress bar
		local fill, _ = buildPityBar(card, data.type, data.pityMax)

		-- Roll button
		local btn = newButton(card,
			UDim2.new(1,-30,0,52), UDim2.new(0,15,1,-70),
			"КРУТИТЬ   " .. data.icon, data.color, 12,
			function() rollGacha(data.type) end)
		btn.TextSize = 20
		btn.Name     = "RollBtn_" .. data.type
		newStroke(btn, Color3.new(1,1,1), 1, 0.8)

		-- Hover effect
		btn.MouseEnter:Connect(function()
			tIn(btn, { BackgroundColor3 = data.color:Lerp(Color3.new(1,1,1), 0.15) }, 0.15)
		end)
		btn.MouseLeave:Connect(function()
			tIn(btn, { BackgroundColor3 = data.color }, 0.15)
		end)
	end

	-- ============================================================
	-- RESULT PANEL
	-- ============================================================
	resultPanel = newFrame(mainFrame,
		UDim2.new(1,-40,1,-140), UDim2.new(0,20,0,112),
		Color3.new(), 1, 11)
	resultPanel.Name    = "ResultPanel"
	resultPanel.Visible = false

	return sg
end

-- ============================================================
-- OPEN / CLOSE
-- ============================================================

function closeUI()
	if not isOpen then return end
	isOpen = false

	sndAmbient:Stop()
	restoreCamera()
	tOut(mainFrame, { Position = UDim2.new(0.5,-320, 1.2, 0) }, 0.3)
	task.wait(0.32)
	sg.Enabled = false
end

local function openUI()
	if isOpen or isRolling then return end
	isOpen = true

	chestPanel.Visible  = true
	resultPanel.Visible = false

	mainFrame.Position = UDim2.new(0.5,-320,-0.6,0)
	sg.Enabled = true
	tIn(mainFrame, { Position = UDim2.new(0.5,-320,0.5,-270) }, 0.45)

	-- Ambient hum при открытии
	task.delay(0.3, function()
		if isOpen then sndAmbient:Play() end
	end)
end

-- ============================================================
-- LOCK / UNLOCK ROLL BUTTONS
-- ============================================================

local function setButtonsLocked(locked)
	for _, btn in ipairs(chestPanel:GetDescendants()) do
		if btn:IsA("TextButton") then
			btn.AutoButtonColor    = not locked
			btn.BackgroundTransparency = locked and 0.5 or 0
		end
	end
end

-- ============================================================
-- ПОКАЗ РЕЗУЛЬТАТА
-- ============================================================

local function showResult(data)
	chestPanel.Visible  = false
	resultPanel.Visible = true

	-- Очищаем прошлый результат
	for _, c in ipairs(resultPanel:GetChildren()) do c:Destroy() end

	local heroId   = data.heroId or "UnknownHero"
	local rarity   = data.rarity or "Common"
	local isDupe   = data.isDuplicate
	local comp     = data.compensation or 0
	local hi       = HERO_INFO[heroId] or { name=heroId, jp="???", role="?", c=Color3.new(1,1,1) }
	local rc       = RARITY_COLOR[rarity] or Color3.new(1,1,1)

	-- Обновляем pity-бары
	if data.pityCount and data.pityMax and data.chestType then
		updatePityBar(sg, data.chestType, data.pityCount, data.pityMax)
	end

	-- ---- КАРТОЧКА ГЕРОЯ ----
	local card = newFrame(resultPanel,
		UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
		Color3.fromRGB(12,10,20), 0.05, 12, 14)
	card.ClipsDescendants = false

	-- Rarity gradient top bar
	newFrame(card, UDim2.new(1,0,0,6), UDim2.new(0,0,0,0), rc, 0, 13)

	-- Rarity glow overlay
	local glowFrame = newFrame(card,
		UDim2.new(1,0,0,80), UDim2.new(0,0,0,0),
		RARITY_GLOW[rarity], 0.65, 12)

	-- Stars
	newLabel(card,
		UDim2.new(1,0,0,28), UDim2.new(0,0,0,12),
		RARITY_STARS[rarity], Enum.Font.GothamBlack, 22, rc, 14)

	-- JP rarity
	newLabel(card,
		UDim2.new(1,0,0,22), UDim2.new(0,0,0,42),
		RARITY_JP[rarity] .. "  ·  " .. string.upper(rarity),
		Enum.Font.GothamBold, 17, rc, 14)

	-- HERO NAME (большой)
	local nameLbl = newLabel(card,
		UDim2.new(1,-20,0,56), UDim2.new(0,10,0,70),
		hi.name, Enum.Font.GothamBlack, 40, hi.c, 14)

	-- JP name
	newLabel(card,
		UDim2.new(1,0,0,22), UDim2.new(0,0,0,130),
		hi.jp, Enum.Font.Gotham, 16,
		Color3.fromRGB(130,120,160), 14)

	-- Role badge
	local roleFrame = newFrame(card,
		UDim2.new(0,120,0,26), UDim2.new(0.5,-60,0,160),
		rc:Lerp(Color3.new(),0.5), 0, 14, 6)
	newLabel(roleFrame,
		UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
		"[ " .. hi.role .. " ]", Enum.Font.GothamBold, 13,
		Color3.new(1,1,1), 15)

	-- Дубликат / новый
	if isDupe then
		local dupBar = newFrame(card,
			UDim2.new(1,-40,0,28), UDim2.new(0,20,0,200),
			Color3.fromRGB(50,40,0), 0.1, 14, 6)
		newLabel(dupBar,
			UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
			"ДУБЛИКАТ  —  +" .. comp .. " монет компенсация 💰",
			Enum.Font.GothamBold, 13, Color3.fromRGB(255,220,80), 15)
		sndCoin:Play()
	else
		local newBar = newFrame(card,
			UDim2.new(1,-40,0,28), UDim2.new(0,20,0,200),
			Color3.fromRGB(0,40,15), 0.1, 14, 6)
		newLabel(newBar,
			UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
			"✨  НОВЫЙ ГЕРОЙ РАЗБЛОКИРОВАН!",
			Enum.Font.GothamBold, 14, Color3.fromRGB(80,255,130), 15)
	end

	-- Card glow stroke
	newStroke(card, rc, 2, 0.3)

	-- Кнопка «Забрать»
	newButton(card,
		UDim2.new(0,220,0,52), UDim2.new(0.5,-230,1,-72),
		"ЗАБРАТЬ", rc, 12,
		function()
			resultPanel.Visible = false
			chestPanel.Visible  = true
			isRolling = false
			setButtonsLocked(false)
		end)

	-- Кнопка «Ещё раз»
	newButton(card,
		UDim2.new(0,200,0,40), UDim2.new(0.5,10,1,-65),
		"КРУТИТЬ ЕЩЁ ▶", Color3.fromRGB(40,40,60), 10,
		function()
			resultPanel.Visible = false
			chestPanel.Visible  = true
			isRolling = false
			setButtonsLocked(false)
		end)

	-- ---- SILHOUETTE ANIMATION ----
	-- Карточка влетает снизу
	card.Position = UDim2.new(0,0, 0.3, 0)
	card.BackgroundTransparency = 0.9
	tIn(card, {
		Position             = UDim2.new(0,0,0,0),
		BackgroundTransparency = 0.05,
	}, 0.45, Enum.EasingStyle.Back)

	-- Имя «расцветает» прозрачностью
	nameLbl.TextTransparency = 0.9
	tIn(nameLbl, { TextTransparency = 0 }, 0.6, Enum.EasingStyle.Quad)

	-- Legendary: бесконечный pulse до закрытия
	if rarity == "Legendary" then
		task.spawn(function()
			local running = true
			-- Остановим pulse когда карточка уйдёт
			local conn; conn = resultPanel:GetPropertyChangedSignal("Visible"):Connect(function()
				if not resultPanel.Visible then running = false; conn:Disconnect() end
			end)
			while running and resultPanel.Visible do
				tIn(nameLbl, { TextSize = 44 }, 0.35, Enum.EasingStyle.Sine)
				task.wait(0.38)
				tIn(nameLbl, { TextSize = 40 }, 0.35, Enum.EasingStyle.Sine)
				task.wait(0.38)
			end
		end)

		-- Золотой тинт на всё лобби
		local goldTint = sg:FindFirstChild("GoldTint")
		if goldTint then
			goldTint.BackgroundTransparency = 0.55
			TweenService:Create(goldTint,
				TweenInfo.new(1.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			):Play()
		end
	end
end

-- ============================================================
-- ROLL GACHA
-- ============================================================

function rollGacha(chestType)
	if isRolling then return end
	isRolling = true
	setButtonsLocked(true)

	local chestData
	for _, d in ipairs(CHEST_DATA) do
		if d.type == chestType then chestData = d; break end
	end

	-- ═════════════════════════════════════════
	-- ФАЗА 1: Нагнетание (камера + shake)
	-- ═════════════════════════════════════════

	sndWhoosh:Play()

	-- Приближаем камеру к колодцу
	zoomToWell()

	-- Shake окна
	task.spawn(function()
		local orig = mainFrame.Position
		for _ = 1, 10 do
			mainFrame.Position = UDim2.new(
				orig.X.Scale, orig.X.Offset + math.random(-3,3),
				orig.Y.Scale, orig.Y.Offset + math.random(-2,2))
			task.wait(0.04)
		end
		mainFrame.Position = orig
	end)

	-- Затемняем overlay
	local overlay = sg:FindFirstChild("Overlay")
	if overlay then
		tIn(overlay, { BackgroundTransparency = 0.1 }, 0.5, Enum.EasingStyle.Sine)
	end

	task.wait(0.5)

	-- ═════════════════════════════════════════
	-- ФАЗА 2: Затишье (0.5s тишины)
	-- ═════════════════════════════════════════

	sndAmbient:Stop()
	task.wait(0.5)

	-- ═════════════════════════════════════════
	-- ФАЗА 3: Запрос к серверу
	-- ═════════════════════════════════════════

	local result = rRollGacha:InvokeServer(chestType)

	-- Восстанавливаем overlay до финала
	if overlay then
		tIn(overlay, { BackgroundTransparency = 0.45 }, 0.4, Enum.EasingStyle.Sine)
	end

	-- Обработка ошибок
	if not result or not result.success then
		local msg = (result and result.message) or "Ошибка сервера"
		flashImpact(Color3.fromRGB(200,20,20), 0.4)

		-- Сообщение об ошибке
		for _, c in ipairs(chestPanel:GetChildren()) do
			if c:IsA("Frame") then
				local errLbl = newLabel(c,
					UDim2.new(1,0,0,26), UDim2.new(0,0,1,5),
					"⚠  " .. msg, Enum.Font.GothamBold, 14,
					Color3.fromRGB(255,70,70), 20)
				task.delay(2.5, function()
					if errLbl and errLbl.Parent then errLbl:Destroy() end
				end)
			end
		end

		restoreCamera()
		sndAmbient:Play()
		setButtonsLocked(false)
		isRolling = false
		return
	end

	local rarity = result.rarity

	-- ═════════════════════════════════════════
	-- ФАЗА 4: Impact Frame
	-- ═════════════════════════════════════════

	sndImpact:Play()
	flashImpact(Color3.new(1,1,1), 0.3)
	task.wait(0.18)

	-- Rarity-цветная вспышка
	flashImpact(RARITY_GLOW[rarity], 0.55)
	task.wait(0.25)

	-- Legendary: дополнительный золотой взрыв
	if rarity == "Legendary" then
		flashImpact(Color3.fromRGB(255,200,30), 0.7)
		task.wait(0.35)
	end

	-- ═════════════════════════════════════════
	-- ФАЗА 5: Звук + явление героя
	-- ═════════════════════════════════════════

	local sfx = RARITY_SFX[rarity]
	if sfx then sfx:Play() end

	-- Прокидываем chestType для pity-bar
	result.chestType = chestType

	showResult(result)

	-- Восстанавливаем камеру после появления карточки
	task.delay(0.5, restoreCamera)
end

-- ============================================================
-- INIT
-- ============================================================

buildUI()

-- Открытие по ProximityPrompt
if rOpenWell then
	rOpenWell.OnClientEvent:Connect(function()
		openUI()
	end)
end

-- ESC
UserInput.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isOpen and not isRolling then
		closeUI()
	end
end)

print("[WishingWellUI] ✓ Initialized (v2)")
