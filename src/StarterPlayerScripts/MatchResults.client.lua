-- MatchResults.client.lua | Anime Arena: Blitz
-- Production экран результатов матча:
--   • Баннер ПОБЕДА / ПОРАЖЕНИЕ / НИЧЬЯ (анимация pop-in)
--   • MVP золотая подсветка
--   • KDA / Damage / режим для каждого игрока
--   • +RP / +Coins с анимацией счётчика
--   • Аниме-стиль: кинематические полосы + частицы
--   • Триггер: ShowMatchResults Remote

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local rShowResults = Remotes:WaitForChild("ShowMatchResults",  10)
local rRoundEnd    = Remotes:WaitForChild("RoundEnd",          10)
local rRankUpdate  = Remotes:WaitForChild("RankUpdate",        10)

-- ============================================================
-- GUI ROOT
-- ============================================================

local gui = Instance.new("ScreenGui")
gui.Name            = "MatchResults"
gui.ResetOnSpawn    = false
gui.DisplayOrder    = 50
gui.IgnoreGuiInset  = true
gui.Enabled         = false
gui.Parent          = PlayerGui

-- BUG-4.2 FIX: Увеличена непрозрачность оверлея (было 0.45 → 0.2).
-- Старое значение пропускало слишком много фона, текст плохо читался.
local overlay = Instance.new("Frame")
overlay.Size                   = UDim2.new(1,0,1,0)
overlay.BackgroundColor3       = Color3.fromRGB(0,0,0)
overlay.BackgroundTransparency = 0.2
overlay.BorderSizePixel        = 0
overlay.Parent                 = gui

-- Кинематические полосы
local topBar = Instance.new("Frame")
topBar.Size             = UDim2.new(1,0,0,0)
topBar.BackgroundColor3 = Color3.fromRGB(0,0,0)
topBar.BorderSizePixel  = 0
topBar.ZIndex           = 60
topBar.Parent           = gui

local botBar = Instance.new("Frame")
botBar.Size             = UDim2.new(1,0,0,0)
botBar.Position         = UDim2.new(0,0,1,0)
botBar.BackgroundColor3 = Color3.fromRGB(0,0,0)
botBar.BorderSizePixel  = 0
botBar.ZIndex           = 60
botBar.Parent           = gui

-- Центральный контейнер
local card = Instance.new("Frame")
card.Size             = UDim2.new(0,560,0,480)
card.Position         = UDim2.new(0.5,-280,0.5,-240)
card.BackgroundColor3 = Color3.fromRGB(10,10,20)
card.BorderSizePixel  = 0
card.Parent           = gui
local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0,14); cr.Parent = card
local cs = Instance.new("UIStroke"); cs.Color = Color3.fromRGB(50,50,90); cs.Thickness = 2; cs.Parent = card

-- Цветной акцент сверху
local accentBar = Instance.new("Frame")
accentBar.Size             = UDim2.new(1,0,0,5)
accentBar.BackgroundColor3 = Color3.fromRGB(255,180,0)
accentBar.BorderSizePixel  = 0
accentBar.ZIndex           = 2
accentBar.Parent           = card
local acr2 = Instance.new("UICorner"); acr2.CornerRadius = UDim.new(0,4); acr2.Parent = accentBar

-- Баннер результата
local resultBanner = Instance.new("TextLabel")
resultBanner.Size                  = UDim2.new(1,0,0,64)
resultBanner.Position              = UDim2.new(0,0,0,14)
resultBanner.BackgroundTransparency = 1
resultBanner.Text                  = "VICTORY"
resultBanner.TextSize              = 48
resultBanner.TextColor3            = Color3.fromRGB(255,220,60)
resultBanner.Font                  = Enum.Font.GothamBold
resultBanner.TextXAlignment        = Enum.TextXAlignment.Center
resultBanner.ZIndex                = 3
resultBanner.Parent                = card
local rbs = Instance.new("UIStroke"); rbs.Color = Color3.fromRGB(120,80,0); rbs.Thickness = 3; rbs.Parent = resultBanner

-- MVP бюдж
local mvpBadge = Instance.new("TextLabel")
mvpBadge.Size                  = UDim2.new(0,120,0,28)
mvpBadge.Position              = UDim2.new(0.5,-60,0,82)
mvpBadge.BackgroundColor3      = Color3.fromRGB(200,150,0)
mvpBadge.Text                  = "★ MVP"
mvpBadge.TextSize              = 15
mvpBadge.TextColor3            = Color3.new(1,1,1)
mvpBadge.Font                  = Enum.Font.GothamBold
mvpBadge.TextXAlignment        = Enum.TextXAlignment.Center
mvpBadge.ZIndex                = 3
mvpBadge.Visible               = false
mvpBadge.Parent                = card
local mbc = Instance.new("UICorner"); mbc.CornerRadius = UDim.new(0,6); mbc.Parent = mvpBadge

-- Разделитель
local divider = Instance.new("Frame")
divider.Size             = UDim2.new(0.88,0,0,1)
divider.Position         = UDim2.new(0.06,0,0,118)
divider.BackgroundColor3 = Color3.fromRGB(40,40,70)
divider.BorderSizePixel  = 0
divider.Parent           = card

-- Статистика игроков (scroll frame для многих)
local statsScroll = Instance.new("ScrollingFrame")
statsScroll.Size             = UDim2.new(0.88,0,0,190)
statsScroll.Position         = UDim2.new(0.06,0,0,126)
statsScroll.BackgroundTransparency = 1
statsScroll.ScrollBarThickness = 3
statsScroll.ScrollBarImageColor3 = Color3.fromRGB(80,80,120)
statsScroll.CanvasSize       = UDim2.new(0,0,0,0)
statsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
statsScroll.BorderSizePixel  = 0
statsScroll.ZIndex           = 3
statsScroll.Parent           = card
local sl = Instance.new("UIListLayout")
sl.SortOrder = Enum.SortOrder.LayoutOrder
sl.Padding   = UDim.new(0,4)
sl.Parent    = statsScroll

-- Реварды
local rewardsFrame = Instance.new("Frame")
rewardsFrame.Size             = UDim2.new(0.88,0,0,64)
rewardsFrame.Position         = UDim2.new(0.06,0,0,326)
rewardsFrame.BackgroundColor3 = Color3.fromRGB(18,18,34)
rewardsFrame.BorderSizePixel  = 0
rewardsFrame.ZIndex           = 3
rewardsFrame.Parent           = card
local rfc = Instance.new("UICorner"); rfc.CornerRadius = UDim.new(0,10); rfc.Parent = rewardsFrame

local rpLbl = Instance.new("TextLabel")
rpLbl.Size                  = UDim2.new(0.5,0,1,0)
rpLbl.BackgroundTransparency = 1
rpLbl.Text                  = "+0 RP"
rpLbl.TextSize              = 22
rpLbl.TextColor3            = Color3.fromRGB(80,200,255)
rpLbl.Font                  = Enum.Font.GothamBold
rpLbl.TextXAlignment        = Enum.TextXAlignment.Center
rpLbl.ZIndex                = 4
rpLbl.Parent                = rewardsFrame

-- BUG-4.2 FIX: Заменён emoji 💰 на текстовый " Coins" — emoji
-- могли не рендериться на всех платформах и сбивали выравнивание.
local coinsLbl = Instance.new("TextLabel")
coinsLbl.Size                  = UDim2.new(0.5,0,1,0)
coinsLbl.Position              = UDim2.new(0.5,0,0,0)
coinsLbl.BackgroundTransparency = 1
coinsLbl.Text                  = "+0 Coins"
coinsLbl.TextSize              = 22
coinsLbl.TextColor3            = Color3.fromRGB(255,200,50)
coinsLbl.Font                  = Enum.Font.GothamBold
coinsLbl.TextXAlignment        = Enum.TextXAlignment.Center
coinsLbl.ZIndex                = 4
coinsLbl.Parent                = rewardsFrame

-- Кнопка продолжить
local continueBtn = Instance.new("TextButton")
continueBtn.Size             = UDim2.new(0.5,0,0,44)
continueBtn.Position         = UDim2.new(0.25,0,0,400)
continueBtn.BackgroundColor3 = Color3.fromRGB(40,140,255)
continueBtn.Text             = "ПРОДОЛЖИТЬ"
continueBtn.TextSize         = 16
continueBtn.TextColor3       = Color3.new(1,1,1)
continueBtn.Font             = Enum.Font.GothamBold
continueBtn.ZIndex           = 3
continueBtn.Parent           = card
local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0,10); cbc.Parent = continueBtn
local cbs = Instance.new("UIStroke"); cbs.Color = Color3.fromRGB(80,180,255); cbs.Thickness = 2; cbs.Parent = continueBtn

-- ============================================================
-- ШАБЛОН СТРОКИ ИГРОКА
-- ============================================================

local function buildPlayerRow(pData, isLocal, isMVP, layoutOrder)
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1,0,0,40)
	row.BackgroundColor3 = isLocal
		and Color3.fromRGB(22,34,56)
		or  Color3.fromRGB(16,16,30)
	row.BorderSizePixel  = 0
	row.LayoutOrder      = layoutOrder or 0
	row.ZIndex           = 4
	row.Parent           = statsScroll
	local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0,7); rc.Parent = row

	if isLocal then
		local rs2 = Instance.new("UIStroke")
		rs2.Color = Color3.fromRGB(40,100,200); rs2.Thickness = 1.5; rs2.Parent = row
	end

	local function cell(xPct, wPct, text, col, align)
		local l = Instance.new("TextLabel")
		l.Size             = UDim2.new(wPct,0,1,0)
		l.Position         = UDim2.new(xPct,0,0,0)
		l.BackgroundTransparency = 1
		l.Text             = text
		l.TextSize         = 13
		l.TextColor3       = col or Color3.new(1,1,1)
		l.Font             = Enum.Font.GothamBold
		l.TextXAlignment   = align or Enum.TextXAlignment.Center
		l.ZIndex           = 5
		l.Parent           = row
		return l
	end

	-- MVP звёздочка
	local nameText = (isMVP and "★ " or "") .. (pData.name or "?")
	cell(0.01, 0.34, nameText, isMVP and Color3.fromRGB(255,210,60) or
		(isLocal and Color3.fromRGB(120,180,255) or Color3.new(1,1,1)),
		Enum.TextXAlignment.Left)

	cell(0.36, 0.15, tostring(pData.kills  or 0),  Color3.fromRGB(255,120,120))
	cell(0.52, 0.15, tostring(pData.deaths or 0),  Color3.fromRGB(160,160,200))
	cell(0.68, 0.18, tostring(pData.damage or 0),  Color3.fromRGB(255,160,60))
	cell(0.87, 0.12, pData.heroId or "—", Color3.fromRGB(140,140,190), Enum.TextXAlignment.Right)

	return row
end

local function buildHeader()
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1,0,0,22)
	row.BackgroundTransparency = 1
	row.LayoutOrder      = -1
	row.ZIndex           = 4
	row.Parent           = statsScroll

	local function hcell(xPct, wPct, text)
		local l = Instance.new("TextLabel")
		l.Size             = UDim2.new(wPct,0,1,0)
		l.Position         = UDim2.new(xPct,0,0,0)
		l.BackgroundTransparency = 1
		l.Text             = text
		l.TextSize         = 11
		l.TextColor3       = Color3.fromRGB(120,120,160)
		l.Font             = Enum.Font.GothamBold
		l.TextXAlignment   = Enum.TextXAlignment.Center
		l.ZIndex           = 5
		l.Parent           = row
	end

	hcell(0.01, 0.34, "ИГРОК")
	hcell(0.36, 0.15, "КИЛЛЫ")
	hcell(0.52, 0.15, "СМЕРТИ")
	hcell(0.68, 0.18, "УРОН")
	hcell(0.87, 0.12, "ГЕРОЙ")
end

-- ============================================================
-- АНИМАЦИЯ СЧЁТЧИКА
-- ============================================================

local function animateCounter(label, targetVal, prefix, suffix, duration)
	prefix  = prefix  or ""
	suffix  = suffix  or ""
	duration = duration or 0.9
	local startTime = tick()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local pct     = math.min(elapsed / duration, 1)
		-- ease out cubic
		pct = 1 - (1 - pct)^3
		local current = math.floor(targetVal * pct)
		label.Text = prefix .. tostring(current) .. suffix
		if elapsed >= duration then
			label.Text = prefix .. tostring(targetVal) .. suffix
			conn:Disconnect()
		end
	end)
end

-- ============================================================
-- ПАРТИКЛЫ ПОБЕДЫ
-- ============================================================

local winParticles = {}

local function spawnConfetti()
	for _ = 1, 18 do
		local dot = Instance.new("Frame")
		dot.Size             = UDim2.new(0, math.random(6,14), 0, math.random(6,14))
		dot.Position         = UDim2.new(math.random() * 0.8 + 0.1, 0, -0.05, 0)
		dot.BackgroundColor3 = Color3.fromHSV(math.random(), 0.9, 1)
		dot.BorderSizePixel  = 0
		dot.ZIndex           = 55
		dot.Rotation         = math.random(0, 360)
		dot.Parent           = gui
		local cr2 = Instance.new("UICorner"); cr2.CornerRadius = UDim.new(0,3); cr2.Parent = dot

		local targetY = 1.1 + math.random() * 0.2
		local dur     = 1.2 + math.random() * 0.8
		TweenService:Create(dot, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(dot.Position.X.Scale + (math.random()-0.5)*0.2, 0, targetY, 0),
			Rotation = dot.Rotation + math.random(-180,180),
			BackgroundTransparency = 0.3,
		}):Play()
		table.insert(winParticles, dot)
		task.delay(dur + 0.1, function() if dot.Parent then dot:Destroy() end end)
	end
end

-- ============================================================
-- ОСНОВНАЯ ПОКАЗОВСКАя ФУНКЦИЯ
-- ============================================================

local function showResults(data)
	-- data = {
	--   winnerId, winnerName, stats = {[userId]={name,kills,deaths,damage,heroId}},
	--   rewards = {rp, coins}, mvpName, isMVP, mode, reason
	-- }

	local isWinner = (data.winnerId == LocalPlayer.UserId)
	local isDraw   = (data.winnerId == 0 or data.winnerId == nil)

	-- Очищаем старые строки
	for _, child in ipairs(statsScroll:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	gui.Enabled = true

	-- Полосы
	TweenService:Create(topBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Size = UDim2.new(1,0,0,70)
	}):Play()
	TweenService:Create(botBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Size = UDim2.new(1,0,0,70),
		Position = UDim2.new(0,0,1,-70)
	}):Play()

	-- Баннер
	if isDraw then
		resultBanner.Text       = "НИЧЬЯ"
		resultBanner.TextColor3 = Color3.fromRGB(180,180,220)
		accentBar.BackgroundColor3 = Color3.fromRGB(100,100,180)
		continueBtn.BackgroundColor3 = Color3.fromRGB(80,80,160)
	elseif isWinner then
		resultBanner.Text       = "ПОБЕДА!"
		resultBanner.TextColor3 = Color3.fromRGB(255,220,60)
		accentBar.BackgroundColor3 = Color3.fromRGB(255,180,0)
		continueBtn.BackgroundColor3 = Color3.fromRGB(40,140,255)
		task.spawn(function()
			for _ = 1, 3 do spawnConfetti(); task.wait(0.4) end
		end)
	else
		resultBanner.Text       = "ПОРАЖЕНИЕ"
		resultBanner.TextColor3 = Color3.fromRGB(220,80,60)
		accentBar.BackgroundColor3 = Color3.fromRGB(200,50,50)
		continueBtn.BackgroundColor3 = Color3.fromRGB(160,40,40)
	end

	-- Анимация баннера
	card.Position = UDim2.new(0.5,-280, 1.2, 0)
	card.Size     = UDim2.new(0,0,0,0)
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size     = UDim2.new(0,560,0,480),
		Position = UDim2.new(0.5,-280, 0.5,-240)
	}):Play()

	-- MVP
	local mvpId = data.mvpName
	mvpBadge.Visible = (data.isMVP == true)

	-- BUG-4.2 FIX: Золотое свечение вокруг карточки для MVP
	local mvpGlow = card:FindFirstChild("MVPGlow")
	if mvpGlow then mvpGlow:Destroy() end
	if data.isMVP then
		local glow = Instance.new("UIStroke")
		glow.Name         = "MVPGlow"
		glow.Color        = Color3.fromRGB(255, 200, 30)
		glow.Thickness    = 3
		glow.Transparency = 0.2
		glow.Parent       = card
		-- Пульсация золотого свечения
		task.spawn(function()
			while gui.Enabled and glow and glow.Parent do
				TweenService:Create(glow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Transparency = 0.6
				}):Play()
				task.wait(0.6)
				TweenService:Create(glow, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Transparency = 0.1
				}):Play()
				task.wait(0.6)
			end
		end)
	end

	-- Строки статистики
	task.delay(0.25, function()
		buildHeader()
		local order = 0
		for userId, pData in pairs(data.stats or {}) do
			local isLocal = (tonumber(userId) == LocalPlayer.UserId)
			local isMVP   = (pData.name == data.mvpName)
			order += 1
			buildPlayerRow(pData, isLocal, isMVP, order)
		end
	end)

	-- Реварды с анимацией
	local rewards = data.rewards or { rp = 0, coins = 0 }
	task.delay(0.5, function()
		animateCounter(rpLbl,    rewards.rp    or 0, "+", " RP")
		-- BUG-4.2 FIX: " Coins" вместо emoji " 💰"
		animateCounter(coinsLbl, rewards.coins or 0, "+", " Coins")
	end)
end

-- ============================================================
-- ЗАКРЫТЬ
-- ============================================================

local function closeResults()
	TweenService:Create(topBar, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Size = UDim2.new(1,0,0,0)
	}):Play()
	TweenService:Create(botBar, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Size     = UDim2.new(1,0,0,0),
		Position = UDim2.new(0,0,1,0)
	}):Play()
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size     = UDim2.new(0,0,0,0),
		Position = UDim2.new(0.5,0, 1.5,0)
	}):Play()
	task.delay(0.4, function()
		gui.Enabled = false
		-- Убираем остатки конфетти
		for _, p in ipairs(winParticles) do
			if p and p.Parent then p:Destroy() end
		end
		table.clear(winParticles)

		-- FIX: возвращаем в лобби после нажатия ПРОДОЛЖИТЬ
		-- 1. Сбрасываем состояние матча
		if _G.ClientState then
			_G.ClientState.inMatch   = false
			_G.ClientState.matchId   = nil
			_G.ClientState.matchMode = nil
		end
		-- 2. Скрываем HUD
		local hudGui = LocalPlayer.PlayerGui:FindFirstChild("HUD")
		if hudGui then hudGui.Enabled = false end
		-- 3. Показываем лобби (с анимацией)
		if _G.LobbyUI then
			_G.LobbyUI.Show()
		else
			local lobbyGui = LocalPlayer.PlayerGui:FindFirstChild("LobbyUI")
			if lobbyGui then lobbyGui.Enabled = true end
		end
		-- 4. Запрашиваем сервер вернуть персонажа в лобби (через LeaveQueue Remote)
		local rLeave = ReplicatedStorage:FindFirstChild("Remotes")
			and ReplicatedStorage.Remotes:FindFirstChild("LeaveQueue")
		if rLeave then rLeave:FireServer() end
	end)
end

continueBtn.MouseButton1Click:Connect(closeResults)

-- ============================================================
-- REMOTE HANDLERS
-- ============================================================

-- Основной канал (ShowMatchResults)
rShowResults.OnClientEvent:Connect(function(data)
	showResults(data)
end)

-- Запасной канал (RoundEnd — если ShowMatchResults не пришёл)
rRoundEnd.OnClientEvent:Connect(function(data)
	if type(data) == "table" and data.stats then
		showResults(data)
	end
end)

-- PUBLIC API
_G.MatchResults = {
	Show  = showResults,
	Close = closeResults,
}

print("[MatchResults] Initialized ✓")
