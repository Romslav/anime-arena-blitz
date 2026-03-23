-- BattleIntro.client.lua | Anime Arena: Blitz
-- Production VS intro: cinematic bars, hero cards, VS glow, BATTLE START, kanji rain
-- Триггер: RoundStart (heroId левого, имя левого, heroId правого, имя правого, mode)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local Debris            = game:GetService("Debris")  -- FIX #6: local, не глобальная

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local rRoundStart = Remotes:WaitForChild("RoundStart", 10)

-- ============================================================
-- DATA
-- ============================================================

local HERO_DATA = {
	FlameRonin    = { jp = "烎りの浪士",     en = "FLAME RONIN",    color = Color3.fromRGB(255,  80,  30) },
	VoidAssassin  = { jp = "虚空の刺客",     en = "VOID ASSASSIN",  color = Color3.fromRGB(140,  40, 200) },
	ThunderMonk   = { jp = "雷鳴の僧",       en = "THUNDER MONK",   color = Color3.fromRGB( 80, 170, 255) },
	IronTitan     = { jp = "鉄の巨人",       en = "IRON TITAN",     color = Color3.fromRGB(180, 180, 180) },
	ScarletArcher = { jp = "紅の弓手",       en = "SCARLET ARCHER", color = Color3.fromRGB(220,  50,  80) },
	EclipseHero   = { jp = "日食の英雄",     en = "ECLIPSE HERO",   color = Color3.fromRGB( 80,  50, 160) },
	StormDancer   = { jp = "嵐の踊り子",   en = "STORM DANCER",   color = Color3.fromRGB(120, 220, 255) },
	BloodSage     = { jp = "血の賢者",       en = "BLOOD SAGE",     color = Color3.fromRGB(200,  20,  20) },
	CrystalGuard  = { jp = "氷晶の守護者", en = "CRYSTAL GUARD",  color = Color3.fromRGB(100, 200, 230) },
	ShadowTwin    = { jp = "影の双子",       en = "SHADOW TWIN",    color = Color3.fromRGB( 60,  60,  80) },
	NeonBlitz     = { jp = "電光の戦士",     en = "NEON BLITZ",     color = Color3.fromRGB(  0, 255, 180) },
	JadeSentinel  = { jp = "翡翠の番人",     en = "JADE SENTINEL",  color = Color3.fromRGB( 80, 200, 100) },
}

local KANJI_POOL = { "厌","闘","刀","力","勇","闘志","神","魂","天","巧","戦","恐" }

-- ============================================================
-- HELPERS
-- ============================================================

local function tw(inst, t, props, style, dir)
	return TweenService:Create(inst,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props)
end

local function makeFr(parent, size, pos, bg, alpha, zi)
	local f = Instance.new("Frame")
	f.Size = size; f.Position = pos
	f.BackgroundColor3 = bg; f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel = 0
	if zi then f.ZIndex = zi end
	f.Parent = parent
	return f
end

local function makeLabel(parent, size, pos, txt, col, zi, font)
	local t = Instance.new("TextLabel")
	t.Size = size; t.Position = pos
	t.Text = txt; t.TextColor3 = col
	t.TextScaled = true
	t.Font = font or Enum.Font.GothamBold
	t.BackgroundTransparency = 1
	if zi then t.ZIndex = zi end
	t.Parent = parent
	return t
end

-- ============================================================
-- GUI STRUCTURE
-- ============================================================

local gui = Instance.new("ScreenGui")
gui.Name             = "BattleIntro"
gui.ResetOnSpawn     = false
gui.DisplayOrder     = 50
gui.IgnoreGuiInset   = true
gui.Enabled          = false
gui.Parent           = PlayerGui

-- Root overlay
local root = makeFr(gui, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
	Color3.fromRGB(0,0,0), 1, 1)

-- Cinematic bars
local barTop = makeFr(root, UDim2.new(1,0,0.16,0), UDim2.new(0,0,-0.16,0),
	Color3.fromRGB(4,4,10), 0, 2)
local barBot = makeFr(root, UDim2.new(1,0,0.16,0), UDim2.new(0,0,1,0),
	Color3.fromRGB(4,4,10), 0, 2)

-- Kanji decorations
local kanjiLabels = {}
for i = 1, 8 do
	local lbl = makeLabel(root,
		UDim2.new(0.055, 0, 0.1, 0),
		UDim2.new(0.05 + (i-1) * 0.11, 0, 0.2 + ((i % 3) * 0.18), 0),
		KANJI_POOL[i] or "魂",
		Color3.fromRGB(255, 200, 50), 1, Enum.Font.GothamBold)
	lbl.TextTransparency = 1
	table.insert(kanjiLabels, lbl)
end

-- Gold divider line
local divider = makeFr(root, UDim2.new(0,3,0.62,0), UDim2.new(0.5,-1.5,0.19,0),
	Color3.fromRGB(255, 220, 50), 1, 4)

-- ============================================================
-- HERO CARDS
-- ============================================================

local function buildCard(side)
	local isLeft = (side == "left")
	local offscreen = isLeft
		and UDim2.new(-0.52, 0, 0.18, 0)
		or  UDim2.new(1.06,  0, 0.18, 0)

	local card = makeFr(root,
		UDim2.new(0.46, 0, 0.62, 0),
		offscreen, Color3.fromRGB(0,0,0), 1, 3)

	-- Gradient tint
	local grad = Instance.new("UIGradient")
	grad.Color     = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(20,20,35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 16)),
	})
	grad.Rotation  = isLeft and 90 or 270
	grad.Parent    = card

	-- Accent bar (vertical stripe at the inner edge)
	local accentX = isLeft and UDim2.new(1,-3,0,0) or UDim2.new(0,0,0,0)
	local accent  = makeFr(card, UDim2.new(0,3,1,0), accentX,
		Color3.fromRGB(255,255,255), 0, 5)

	-- Japanese name
	local jpLbl = makeLabel(card,
		UDim2.new(0.92,0,0.32,0),
		isLeft and UDim2.new(0.04,0,0.06,0) or UDim2.new(0.04,0,0.06,0),
		"", Color3.fromRGB(255,255,255), 5)
	jpLbl.TextXAlignment = isLeft and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right

	-- English name
	local enLbl = makeLabel(card,
		UDim2.new(0.92,0,0.16,0),
		isLeft and UDim2.new(0.04,0,0.36,0) or UDim2.new(0.04,0,0.36,0),
		"", Color3.fromRGB(210,210,210), 5, Enum.Font.Gotham)
	enLbl.TextXAlignment = isLeft and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right

	-- Rarity/type badge
	local badgeBg = makeFr(card, UDim2.new(0,100,0,26),
		isLeft and UDim2.new(0.04,0,0.56,0) or UDim2.new(0.56,0,0.56,0),
		Color3.fromRGB(30,30,50), 0.3, 5)
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = badgeBg end
	local badgeLbl = makeLabel(badgeBg,
		UDim2.new(1,-8,1,0), UDim2.new(0,4,0,0),
		"", Color3.fromRGB(255,220,80), 6, Enum.Font.Gotham)

	-- Player name
	local pLbl = makeLabel(card,
		UDim2.new(0.92,0,0.12,0),
		isLeft and UDim2.new(0.04,0,0.74,0) or UDim2.new(0.04,0,0.74,0),
		"", Color3.fromRGB(160,160,180), 5, Enum.Font.Gotham)
	pLbl.TextXAlignment = isLeft and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right

	return {
		card     = card,
		accent   = accent,
		jpLbl    = jpLbl,
		enLbl    = enLbl,
		badgeLbl = badgeLbl,
		pLbl     = pLbl,
		side     = side,
		offscreen = offscreen,
		onscreen = isLeft and UDim2.new(0.02,0,0.18,0) or UDim2.new(0.52,0,0.18,0),
	}
end

local leftCard  = buildCard("left")
local rightCard = buildCard("right")

-- VS label
local vsLabel = makeLabel(root,
	UDim2.new(0.1,0,0.16,0), UDim2.new(0.45,0,0.42,0),
	"VS", Color3.fromRGB(255,220,50), 6)
vsLabel.TextTransparency = 1
do
	local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(160,110,0); s.Thickness = 3; s.Parent = vsLabel
end

-- BATTLE START label
local fightLabel = makeLabel(root,
	UDim2.new(0.72,0,0.18,0), UDim2.new(0.14,0,0.38,0),
	"", Color3.fromRGB(255,255,255), 7)
fightLabel.TextTransparency = 1
do
	local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(200,40,40); s.Thickness = 5; s.Parent = fightLabel
end

-- ============================================================
-- FILL CARD DATA
-- ============================================================

local function fillCard(cardData, heroId, playerName)
	local data  = HERO_DATA[heroId] or { jp = heroId, en = heroId, color = Color3.fromRGB(200,200,200) }
	cardData.jpLbl.Text    = data.jp
	cardData.enLbl.Text    = data.en
	cardData.pLbl.Text     = playerName or "Player"
	cardData.badgeLbl.Text = heroId
	cardData.accent.BackgroundColor3 = data.color
end

-- ============================================================
-- SOUNDS
-- ============================================================

local function playIntroSFX(sfxId, vol, pitch)
	local snd = Instance.new("Sound")
	snd.SoundId       = sfxId or "rbxassetid://9119713951"
	snd.Volume        = vol or 0.8
	snd.PlaybackSpeed = pitch or 1
	snd.Parent        = SoundService
	snd:Play()
	snd.Ended:Connect(function() snd:Destroy() end)
end

-- ============================================================
-- MAIN SEQUENCE (3.5s total)
-- ============================================================

local function playIntro(leftHeroId, leftName, rightHeroId, rightName, mode)
	fillCard(leftCard,  leftHeroId  or "FlameRonin",   leftName  or "Player 1")
	fillCard(rightCard, rightHeroId or "VoidAssassin",  rightName or "Player 2")

	gui.Enabled = true

	-- 0.0s — Cinematic bars slide in
	tw(barTop, 0.28, { Position = UDim2.new(0,0,0,0) }):Play()
	tw(barBot, 0.28, { Position = UDim2.new(0,0,0.84,0) }):Play()
	task.wait(0.18)

	-- Kanji burst
	for i, lbl in ipairs(kanjiLabels) do
		task.spawn(function()
			task.wait(math.random() * 0.25)
			tw(lbl, 0.22, { TextTransparency = 0.55 }):Play()
			task.wait(0.3 + math.random() * 0.35)
			tw(lbl, 0.4, { TextTransparency = 1 }):Play()
		end)
	end
	task.wait(0.12)

	-- 0.3s — Hero cards slide in (left then right, staggered)
	playIntroSFX(nil, 0.9, 0.95)
	tw(leftCard.card,  0.38, { Position = leftCard.onscreen  }, Enum.EasingStyle.Back):Play()
	task.wait(0.06)
	tw(rightCard.card, 0.38, { Position = rightCard.onscreen }, Enum.EasingStyle.Back):Play()
	task.wait(0.42)

	-- 0.76s — Divider line reveals
	tw(divider, 0.18, { BackgroundTransparency = 0 }):Play()
	task.wait(0.05)

	-- VS fades in
	tw(vsLabel, 0.22, { TextTransparency = 0 }, Enum.EasingStyle.Back):Play()
	task.wait(0.8)

	-- 1.56s — One Hit Mode badge if applicable
	if mode == "OneHit" then
		local badge = Instance.new("TextLabel")
		badge.Size               = UDim2.new(0,200,0,36)
		badge.Position           = UDim2.new(0.5,-100,0.08,0)
		badge.BackgroundColor3   = Color3.fromRGB(220,40,40)
		badge.BackgroundTransparency = 0.2
		badge.Text               = "⚡ ONE HIT MODE"
		badge.TextColor3         = Color3.fromRGB(255,255,255)
		badge.Font               = Enum.Font.GothamBold
		badge.TextScaled         = true
		badge.BorderSizePixel    = 0
		badge.ZIndex             = 8
		badge.Parent             = root
		do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = badge end
		Debris:AddItem(badge, 2.5)  -- FIX #6: используем уже объявленный local Debris
		task.wait(0.3)
	end

	-- Cards fly away
	tw(leftCard.card,  0.3, { Position = leftCard.offscreen  }):Play()
	tw(rightCard.card, 0.3, { Position = rightCard.offscreen }):Play()
	tw(vsLabel,        0.2, { TextTransparency = 1 }):Play()
	tw(divider,        0.15, { BackgroundTransparency = 1 }):Play()
	task.wait(0.32)

	-- BATTLE START!
	fightLabel.Text = mode == "OneHit" and "⚡ ONE HIT MODE!" or "BATTLE START!"
	tw(fightLabel, 0.18, { TextTransparency = 0 }, Enum.EasingStyle.Back):Play()
	playIntroSFX(nil, 1, 1.1)
	task.wait(0.65)

	-- Label pulses out
	tw(fightLabel, 0.35, { TextTransparency = 1, TextSize = 999 }):Play()
	task.wait(0.35)

	-- Bars retract
	tw(barTop, 0.22, { Position = UDim2.new(0,0,-0.16,0) }):Play()
	tw(barBot, 0.22, { Position = UDim2.new(0,0,1,0) }):Play()
	task.wait(0.25)

	gui.Enabled = false

	-- Сброс позиций для повторного воспроизведения
	leftCard.card.Position  = leftCard.offscreen
	rightCard.card.Position = rightCard.offscreen
	fightLabel.TextTransparency = 1
	fightLabel.Text = ""
end

-- ============================================================
-- TRIGGER
-- ============================================================

rRoundStart.OnClientEvent:Connect(function(leftHeroId, leftName, rightHeroId, rightName, mode)
	task.spawn(playIntro, leftHeroId, leftName, rightHeroId, rightName, mode)
end)

print("[BattleIntro] Initialized ✓")
