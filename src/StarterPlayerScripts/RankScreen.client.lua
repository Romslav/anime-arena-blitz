-- RankScreen.client.lua
-- Экран результатов матча: победитель/проигравший, ранг, кнопка рематча

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchEnd       = Remotes:WaitForChild("MatchEnd")
local ShowRankScreen = Remotes:WaitForChild("ShowRankScreen")
local RequestRematch = Remotes:WaitForChild("RequestRematch")

-- Ранговая система
local RANK_THRESHOLDS = {
	{ name = "E",  min = 0,    color = Color3.fromRGB(150, 150, 150) },
	{ name = "D",  min = 100,  color = Color3.fromRGB(100, 180, 100) },
	{ name = "C",  min = 300,  color = Color3.fromRGB(80, 140, 220)  },
	{ name = "B",  min = 600,  color = Color3.fromRGB(160, 80, 220)  },
	{ name = "A",  min = 1000, color = Color3.fromRGB(220, 160, 0)   },
	{ name = "S",  min = 1500, color = Color3.fromRGB(220, 100, 0)   },
	{ name = "SS", min = 2200, color = Color3.fromRGB(220, 40, 40)   },
}

local function getRankData(rp)
	local result = RANK_THRESHOLDS[1]
	for _, r in ipairs(RANK_THRESHOLDS) do
		if rp >= r.min then result = r end
	end
	return result
end

-- Создание GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RankScreenGui"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = PlayerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(5, 5, 15)
bg.BackgroundTransparency = 0.15
bg.Parent = screenGui

-- Заголовок
local resultTitle = Instance.new("TextLabel")
resultTitle.Size = UDim2.new(0.6, 0, 0, 80)
resultTitle.Position = UDim2.new(0.2, 0, 0.08, 0)
resultTitle.BackgroundTransparency = 1
resultTitle.Text = "VICTORY!"
resultTitle.TextColor3 = Color3.fromRGB(255, 200, 0)
resultTitle.TextScaled = true
resultTitle.Font = Enum.Font.GothamBold
resultTitle.Parent = bg

-- Имя игрока
local playerNameLabel = Instance.new("TextLabel")
playerNameLabel.Size = UDim2.new(0.6, 0, 0, 40)
playerNameLabel.Position = UDim2.new(0.2, 0, 0.24, 0)
playerNameLabel.BackgroundTransparency = 1
playerNameLabel.Text = ""
playerNameLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
playerNameLabel.TextScaled = true
playerNameLabel.Font = Enum.Font.Gotham
playerNameLabel.Parent = bg

-- Ранг
local rankPanel = Instance.new("Frame")
rankPanel.Size = UDim2.new(0.25, 0, 0.25, 0)
rankPanel.Position = UDim2.new(0.375, 0, 0.34, 0)
rankPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
rankPanel.Parent = bg

local rankLabel = Instance.new("TextLabel")
rankLabel.Size = UDim2.new(1, 0, 0.6, 0)
rankLabel.BackgroundTransparency = 1
rankLabel.Text = "S"
rankLabel.TextColor3 = Color3.fromRGB(220, 100, 0)
rankLabel.TextScaled = true
rankLabel.Font = Enum.Font.GothamBold
rankLabel.Parent = rankPanel

local rpLabel = Instance.new("TextLabel")
rpLabel.Size = UDim2.new(1, 0, 0.4, 0)
rpLabel.Position = UDim2.new(0, 0, 0.6, 0)
rpLabel.BackgroundTransparency = 1
rpLabel.Text = "+25 RP"
rpLabel.TextColor3 = Color3.fromRGB(100, 220, 100)
rpLabel.TextScaled = true
rpLabel.Font = Enum.Font.Gotham
rpLabel.Parent = rankPanel

-- Статистика
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(0.5, 0, 0.12, 0)
statsLabel.Position = UDim2.new(0.25, 0, 0.63, 0)
statsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
statsLabel.BackgroundTransparency = 0.3
statsLabel.Text = "Kills: 0  |  Damage: 0"
statsLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
statsLabel.TextScaled = true
statsLabel.Font = Enum.Font.Gotham
statsLabel.Parent = bg

-- Кнопка рематч
local rematchBtn = Instance.new("TextButton")
rematchBtn.Size = UDim2.new(0.2, 0, 0.08, 0)
rematchBtn.Position = UDim2.new(0.4, 0, 0.8, 0)
rematchBtn.BackgroundColor3 = Color3.fromRGB(50, 130, 220)
rematchBtn.Text = "REMATCH"
rematchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rematchBtn.TextScaled = true
rematchBtn.Font = Enum.Font.GothamBold
rematchBtn.Parent = bg

rematchBtn.MouseButton1Click:Connect(function()
	RequestRematch:FireServer()
	rematchBtn.Text = "Waiting..."
	rematchBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	rematchBtn.Active = false
end)

-- Обработка конца матча
MatchEnd.OnClientEvent:Connect(function(winnerUserId)
	local isWinner = (winnerUserId == player.UserId)
	if isWinner then
		resultTitle.Text = "VICTORY!"
		resultTitle.TextColor3 = Color3.fromRGB(255, 200, 0)
	else
		resultTitle.Text = "DEFEAT"
		resultTitle.TextColor3 = Color3.fromRGB(200, 60, 60)
	end
	playerNameLabel.Text = player.Name
end)

-- Детальный экран с рангом и статистикой
ShowRankScreen.OnClientEvent:Connect(function(data)
	-- data: { rp, rpChange, kills, damage, isWinner }
	local rankData = getRankData(data.rp or 0)
	rankLabel.Text = rankData.name
	rankLabel.TextColor3 = rankData.color
	local sign = data.rpChange >= 0 and "+" or ""
	rpLabel.Text = sign .. (data.rpChange or 0) .. " RP"
	rpLabel.TextColor3 = data.rpChange >= 0 and Color3.fromRGB(100, 220, 100) or Color3.fromRGB(220, 80, 80)
	statsLabel.Text = "Kills: " .. (data.kills or 0) .. "  |  Damage: " .. (data.damage or 0)
	resultTitle.Text = data.isWinner and "VICTORY!" or "DEFEAT"
	resultTitle.TextColor3 = data.isWinner and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(200, 60, 60)
	playerNameLabel.Text = player.Name
	-- Показываем с анимацией
	screenGui.Enabled = true
	bg.BackgroundTransparency = 1
	TweenService:Create(bg, TweenInfo.new(0.6), { BackgroundTransparency = 0.15 }):Play()
	rematchBtn.Text = "REMATCH"
	rematchBtn.BackgroundColor3 = Color3.fromRGB(50, 130, 220)
	rematchBtn.Active = true
end)
