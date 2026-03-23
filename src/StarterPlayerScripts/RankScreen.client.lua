-- RankScreen.client.lua | Anime Arena: Blitz
-- Production экран рангов E → SS:
--   • Полный визуал: иконки, прогресс-бар, цветовой фон
--   • Анимация повышения ранга (поп-ин + флэш + партиклы)
--   • Таблица рангов с порогами RP
--   • Анимация progress bar счётчиком
--   • Триггер: RankUpdate Remote

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local rRankUpdate = Remotes:WaitForChild("RankUpdate", 10)

-- ============================================================
-- ДАННЫЕ РАНГОВ
-- ============================================================

local RANKS = {
	{ name = "E",  minRP = 0,    maxRP = 199,  color = Color3.fromRGB(140,140,140), glow = Color3.fromRGB(180,180,180) },
	{ name = "D",  minRP = 200,  maxRP = 499,  color = Color3.fromRGB(100,160,100), glow = Color3.fromRGB(130,220,130) },
	{ name = "C",  minRP = 500,  maxRP = 999,  color = Color3.fromRGB(60,120,220),  glow = Color3.fromRGB(100,160,255) },
	{ name = "B",  minRP = 1000, maxRP = 1999, color = Color3.fromRGB(160,80,220),  glow = Color3.fromRGB(200,120,255) },
	{ name = "A",  minRP = 2000, maxRP = 3499, color = Color3.fromRGB(220,160,40),  glow = Color3.fromRGB(255,200,80)  },
	{ name = "S",  minRP = 3500, maxRP = 5999, color = Color3.fromRGB(255,120,40),  glow = Color3.fromRGB(255,160,80)  },
	{ name = "SS", minRP = 6000, maxRP = 99999,color = Color3.fromRGB(255,60,60),   glow = Color3.fromRGB(255,120,100) },
}

local function getRankData(rp)
	for i = #RANKS, 1, -1 do
		if rp >= RANKS[i].minRP then return RANKS[i], i end
	end
	return RANKS[1], 1
end

local function getRankProgress(rp, rankData)
	local range = rankData.maxRP - rankData.minRP
	if range <= 0 then return 1 end
	return math.clamp((rp - rankData.minRP) / range, 0, 1)
end

-- ============================================================
-- GUI РАНГА (малый HUD бейдж, всегда виден)
-- ============================================================

local hudGui = Instance.new("ScreenGui")
hudGui.Name            = "RankHUD"
hudGui.ResetOnSpawn    = false
hudGui.DisplayOrder    = 10
hudGui.IgnoreGuiInset  = true
hudGui.Parent          = PlayerGui

local rankBadge = Instance.new("Frame")
rankBadge.Size             = UDim2.new(0,60,0,60)
rankBadge.Position         = UDim2.new(1,-72,0,12)
rankBadge.BackgroundColor3 = Color3.fromRGB(15,15,30)
rankBadge.BorderSizePixel  = 0
rankBadge.Parent           = hudGui
local rbc = Instance.new("UICorner"); rbc.CornerRadius = UDim.new(0,10); rbc.Parent = rankBadge
local rbs2 = Instance.new("UIStroke"); rbs2.Color = Color3.fromRGB(140,140,140); rbs2.Thickness = 2; rbs2.Parent = rankBadge

local rankLbl = Instance.new("TextLabel")
rankLbl.Size                  = UDim2.new(1,0,0.7,0)
rankLbl.BackgroundTransparency = 1
rankLbl.Text                  = "E"
rankLbl.TextSize              = 28
rankLbl.TextColor3            = Color3.fromRGB(140,140,140)
rankLbl.Font                  = Enum.Font.GothamBold
rankLbl.TextXAlignment        = Enum.TextXAlignment.Center
rankLbl.Parent                = rankBadge

local rpHUDLbl = Instance.new("TextLabel")
rpHUDLbl.Size                  = UDim2.new(1,0,0.3,0)
rpHUDLbl.Position              = UDim2.new(0,0,0.7,0)
rpHUDLbl.BackgroundTransparency = 1
rpHUDLbl.Text                  = "0 RP"
rpHUDLbl.TextSize              = 9
rpHUDLbl.TextColor3            = Color3.fromRGB(160,160,200)
rpHUDLbl.Font                  = Enum.Font.Gotham
rpHUDLbl.TextXAlignment        = Enum.TextXAlignment.Center
rpHUDLbl.Parent                = rankBadge

-- ============================================================
-- GUI ПОПАПА ПОВЫШЕНИЯ РАНГА
-- ============================================================

local popGui = Instance.new("ScreenGui")
popGui.Name            = "RankUpScreen"
popGui.ResetOnSpawn    = false
popGui.DisplayOrder    = 55
popGui.IgnoreGuiInset  = true
popGui.Enabled         = false
popGui.Parent          = PlayerGui

-- Фоновая вспышка
local flashBg = Instance.new("Frame")
flashBg.Size                   = UDim2.new(1,0,1,0)
flashBg.BackgroundColor3       = Color3.fromRGB(255,255,255)
flashBg.BackgroundTransparency = 1
flashBg.BorderSizePixel        = 0
flashBg.Parent                 = popGui

-- Центральный контейнер
local popCard = Instance.new("Frame")
popCard.Size             = UDim2.new(0,340,0,260)
popCard.Position         = UDim2.new(0.5,-170,0.5,-130)
popCard.BackgroundColor3 = Color3.fromRGB(8,8,18)
popCard.BorderSizePixel  = 0
popCard.Parent           = popGui
local pcc = Instance.new("UICorner"); pcc.CornerRadius = UDim.new(0,16); pcc.Parent = popCard
local pcs = Instance.new("UIStroke"); pcs.Color = Color3.fromRGB(255,200,0); pcs.Thickness = 3; pcs.Parent = popCard

-- Заголовок
local rankUpTitle = Instance.new("TextLabel")
rankUpTitle.Size                  = UDim2.new(1,0,0,40)
rankUpTitle.Position              = UDim2.new(0,0,0,16)
rankUpTitle.BackgroundTransparency = 1
rankUpTitle.Text                  = "RANK UP!"
rankUpTitle.TextSize              = 32
rankUpTitle.TextColor3            = Color3.fromRGB(255,220,60)
rankUpTitle.Font                  = Enum.Font.GothamBold
rankUpTitle.TextXAlignment        = Enum.TextXAlignment.Center
rankUpTitle.Parent                = popCard
local rus = Instance.new("UIStroke"); rus.Color = Color3.fromRGB(120,80,0); rus.Thickness = 3; rus.Parent = rankUpTitle

-- Стрелка олд → нью
local rankArrow = Instance.new("Frame")
rankArrow.Size             = UDim2.new(0,280,0,80)
rankArrow.Position         = UDim2.new(0.5,-140,0,68)
rankArrow.BackgroundTransparency = 1
rankArrow.Parent           = popCard

local oldRankLbl = Instance.new("TextLabel")
oldRankLbl.Size             = UDim2.new(0.35,0,1,0)
oldRankLbl.BackgroundTransparency = 1
oldRankLbl.Text             = "A"
oldRankLbl.TextSize         = 52
oldRankLbl.TextColor3       = Color3.fromRGB(220,160,40)
oldRankLbl.Font             = Enum.Font.GothamBold
oldRankLbl.TextXAlignment   = Enum.TextXAlignment.Center
oldRankLbl.Parent           = rankArrow

local arrowLbl = Instance.new("TextLabel")
arrowLbl.Size               = UDim2.new(0.3,0,1,0)
arrowLbl.Position           = UDim2.new(0.35,0,0,0)
arrowLbl.BackgroundTransparency = 1
arrowLbl.Text               = "→"
arrowLbl.TextSize           = 40
arrowLbl.TextColor3         = Color3.fromRGB(255,255,255)
arrowLbl.Font               = Enum.Font.GothamBold
arrowLbl.TextXAlignment     = Enum.TextXAlignment.Center
arrowLbl.Parent             = rankArrow

local newRankLbl = Instance.new("TextLabel")
newRankLbl.Size             = UDim2.new(0.35,0,1,0)
newRankLbl.Position         = UDim2.new(0.65,0,0,0)
newRankLbl.BackgroundTransparency = 1
newRankLbl.Text             = "S"
newRankLbl.TextSize         = 52
newRankLbl.TextColor3       = Color3.fromRGB(255,120,40)
newRankLbl.Font             = Enum.Font.GothamBold
newRankLbl.TextXAlignment   = Enum.TextXAlignment.Center
newRankLbl.Parent           = rankArrow

-- Прогресс нового ранга
local progressTrack = Instance.new("Frame")
progressTrack.Size             = UDim2.new(0.82,0,0,10)
progressTrack.Position         = UDim2.new(0.09,0,0,160)
progressTrack.BackgroundColor3 = Color3.fromRGB(25,25,45)
progressTrack.BorderSizePixel  = 0
progressTrack.Parent           = popCard
local ptc = Instance.new("UICorner"); ptc.CornerRadius = UDim.new(0,5); ptc.Parent = progressTrack

local progressFill = Instance.new("Frame")
progressFill.Size             = UDim2.new(0,0,1,0)
progressFill.BackgroundColor3 = Color3.fromRGB(255,180,0)
progressFill.BorderSizePixel  = 0
progressFill.Parent           = progressTrack
local pfc = Instance.new("UICorner"); pfc.CornerRadius = UDim.new(0,5); pfc.Parent = progressFill

local progressLbl = Instance.new("TextLabel")
progressLbl.Size                   = UDim2.new(1,0,0,20)
progressLbl.Position               = UDim2.new(0,0,0,174)
progressLbl.BackgroundTransparency = 1
progressLbl.Text                   = "0 / 200 RP"
progressLbl.TextSize               = 13
progressLbl.TextColor3             = Color3.fromRGB(200,200,220)
progressLbl.Font                   = Enum.Font.Gotham
progressLbl.TextXAlignment         = Enum.TextXAlignment.Center
progressLbl.Parent                 = popCard

local newRPLbl = Instance.new("TextLabel")
newRPLbl.Size                   = UDim2.new(1,0,0,24)
newRPLbl.Position               = UDim2.new(0,0,0,200)
newRPLbl.BackgroundTransparency = 1
newRPLbl.Text                   = "0 RP total"
newRPLbl.TextSize               = 15
newRPLbl.TextColor3             = Color3.fromRGB(255,200,80)
newRPLbl.Font                   = Enum.Font.GothamBold
newRPLbl.TextXAlignment         = Enum.TextXAlignment.Center
newRPLbl.Parent                 = popCard

-- Конфетти повышения
local function rankUpParticles(col)
	for _ = 1, 24 do
		local dot = Instance.new("Frame")
		dot.Size             = UDim2.new(0, math.random(5,12), 0, math.random(5,12))
		dot.Position         = UDim2.new(math.random()*0.6+0.2, 0, 0.4, 0)
		dot.BackgroundColor3 = col or Color3.fromRGB(255,200,0)
		dot.BorderSizePixel  = 0
		dot.ZIndex           = 60
		dot.Rotation         = math.random(0,360)
		dot.Parent           = popGui
		local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0,3); dc.Parent = dot
		TweenService:Create(dot, TweenInfo.new(0.9 + math.random()*0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(dot.Position.X.Scale + (math.random()-0.5)*0.4, 0,
				dot.Position.Y.Scale - 0.4 - math.random()*0.3, 0),
			BackgroundTransparency = 1,
			Rotation = dot.Rotation + math.random(-270,270),
		}):Play()
		task.delay(1.5, function() if dot.Parent then dot:Destroy() end end)
	end
end

-- ============================================================
-- ОБНОВЛЕНИЕ HUD БЕЙДЖА
-- ============================================================

local function updateHUDBadge(rp, animated)
	local rankData = getRankData(rp)
	rankLbl.Text       = rankData.name
	rankLbl.TextColor3 = rankData.color
	rpHUDLbl.Text      = rp .. " RP"
	rbs2.Color         = rankData.color

	if animated then
		TweenService:Create(rankBadge, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
			Size = UDim2.new(0,72,0,72)
		}):Play()
		task.delay(0.2, function()
			TweenService:Create(rankBadge, TweenInfo.new(0.15), {
				Size = UDim2.new(0,60,0,60)
			}):Play()
		end)
	end
end

-- ============================================================
-- ПОПАП ПОВЫШЕНИЯ
-- ============================================================

local function showRankUp(oldRank, newRank, newRP)
	popGui.Enabled = true

	local newData = getRankData(newRP)
	local oldData
	for _, r in ipairs(RANKS) do
		if r.name == oldRank then oldData = r; break end
	end
	oldData = oldData or RANKS[1]

	oldRankLbl.Text       = oldRank
	oldRankLbl.TextColor3 = oldData.color
	newRankLbl.Text       = newRank
	newRankLbl.TextColor3 = newData.color
	newRPLbl.Text         = tostring(newRP) .. " RP total"
	pcs.Color             = newData.color

	-- Анимация поп-ин
	popCard.Size     = UDim2.new(0,0,0,0)
	popCard.Position = UDim2.new(0.5,0,0.5,0)
	flashBg.BackgroundTransparency = 0.3

	TweenService:Create(flashBg, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1
	}):Play()
	TweenService:Create(popCard, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size     = UDim2.new(0,340,0,260),
		Position = UDim2.new(0.5,-170,0.5,-130)
	}):Play()

	-- Анимация progress bar
	progressFill.Size = UDim2.new(0,0,1,0)
	local prog = getRankProgress(newRP, newData)
	task.delay(0.5, function()
		TweenService:Create(progressFill,
			TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(prog,0,1,0)
			}):Play()
		progressFill.BackgroundColor3 = newData.color
		progressLbl.Text = tostring(newRP) .. " / " .. tostring(newData.maxRP) .. " RP"
	end)

	-- Партиклы
	task.delay(0.35, function()
		rankUpParticles(newData.glow)
	end)

	-- Автозакрытие
	task.delay(5, function()
		TweenService:Create(popCard, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size     = UDim2.new(0,0,0,0),
			Position = UDim2.new(0.5,0,0.5,0)
		}):Play()
		task.delay(0.35, function() popGui.Enabled = false end)
	end)
end

-- ============================================================
-- ТАБЛИЦА РАНГОВ (ДОП БОКоВАЯ ПАНЕЛЬ, открывается через API)
-- ============================================================

local tableGui = Instance.new("ScreenGui")
tableGui.Name            = "RankTable"
tableGui.ResetOnSpawn    = false
tableGui.DisplayOrder    = 8
tableGui.IgnoreGuiInset  = true
tableGui.Enabled         = false
tableGui.Parent          = PlayerGui

local tableCard = Instance.new("Frame")
tableCard.Size             = UDim2.new(0,320,0,360)
tableCard.Position         = UDim2.new(0.5,-160,0.5,-180)
tableCard.BackgroundColor3 = Color3.fromRGB(10,10,20)
tableCard.BorderSizePixel  = 0
tableCard.Parent           = tableGui
local tcc = Instance.new("UICorner"); tcc.CornerRadius = UDim.new(0,14); tcc.Parent = tableCard
local tcs = Instance.new("UIStroke"); tcs.Color = Color3.fromRGB(60,60,100); tcs.Thickness = 2; tcs.Parent = tableCard

local tableTitle = Instance.new("TextLabel")
tableTitle.Size                  = UDim2.new(1,0,0,44)
tableTitle.BackgroundTransparency = 1
tableTitle.Text                  = "РАНГОВАЯ СИСТЕМА"
tableTitle.TextSize              = 18
tableTitle.TextColor3            = Color3.new(1,1,1)
tableTitle.Font                  = Enum.Font.GothamBold
tableTitle.TextXAlignment        = Enum.TextXAlignment.Center
tableTitle.Parent                = tableCard

local rankList = Instance.new("Frame")
rankList.Size             = UDim2.new(0.9,0,1,-60)
rankList.Position         = UDim2.new(0.05,0,0,50)
rankList.BackgroundTransparency = 1
rankList.Parent           = tableCard
local rl = Instance.new("UIListLayout")
rl.SortOrder = Enum.SortOrder.LayoutOrder
rl.Padding   = UDim.new(0,4)
rl.Parent    = rankList

local closeTableBtn = Instance.new("TextButton")
closeTableBtn.Size             = UDim2.new(0.6,0,0,36)
closeTableBtn.Position         = UDim2.new(0.2,0,1,-48)
closeTableBtn.BackgroundColor3 = Color3.fromRGB(40,40,70)
closeTableBtn.Text             = "ЗАКРЫТЬ"
closeTableBtn.TextSize         = 14
closeTableBtn.TextColor3       = Color3.new(1,1,1)
closeTableBtn.Font             = Enum.Font.GothamBold
closeTableBtn.Parent           = tableCard
local ctbc = Instance.new("UICorner"); ctbc.CornerRadius = UDim.new(0,8); ctbc.Parent = closeTableBtn

closeTableBtn.MouseButton1Click:Connect(function()
	tableGui.Enabled = false
end)

-- Строим строки
for i, r in ipairs(RANKS) do
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1,0,0,34)
	row.BackgroundColor3 = Color3.fromRGB(16,16,30)
	row.BorderSizePixel  = 0
	row.LayoutOrder      = i
	row.Parent           = rankList
	local rc2 = Instance.new("UICorner"); rc2.CornerRadius = UDim.new(0,6); rc2.Parent = row

	local rnl = Instance.new("TextLabel")
	rnl.Size             = UDim2.new(0.18,0,1,0)
	rnl.BackgroundTransparency = 1
	rnl.Text             = r.name
	rnl.TextSize         = 20
	rnl.TextColor3       = r.color
	rnl.Font             = Enum.Font.GothamBold
	rnl.TextXAlignment   = Enum.TextXAlignment.Center
	rnl.Parent           = row

	local rpl = Instance.new("TextLabel")
	rpl.Size             = UDim2.new(0.82,0,1,0)
	rpl.Position         = UDim2.new(0.18,0,0,0)
	rpl.BackgroundTransparency = 1
	rpl.Text             = tostring(r.minRP) .. (r.name == "SS" and "+ RP" or " – " .. tostring(r.maxRP) .. " RP")
	rpl.TextSize         = 13
	rpl.TextColor3       = Color3.fromRGB(180,180,210)
	rpl.Font             = Enum.Font.Gotham
	rpl.TextXAlignment   = Enum.TextXAlignment.Left
	rpl.Parent           = row
end

-- ============================================================
-- REMOTE HANDLER
-- ============================================================

rRankUpdate.OnClientEvent:Connect(function(oldRank, newRank, newRP)
	updateHUDBadge(newRP, true)
	if oldRank ~= newRank then
		showRankUp(oldRank, newRank, newRP)
	end
end)

-- ============================================================
-- PUBLIC API
-- ============================================================

_G.RankScreen = {
	UpdateBadge = updateHUDBadge,
	ShowRankUp  = showRankUp,
	OpenTable   = function() tableGui.Enabled = true end,
}

-- Начальный RP из DataStore через API
task.defer(function()
	if _G.DataStore and _G.DataStore.GetRP then
		local rp = _G.DataStore.GetRP(LocalPlayer.UserId) or 0
		updateHUDBadge(rp, false)
	end
end)

print("[RankScreen] Initialized ✓")
