-- HUD.client.lua
-- Игровой интерфейс: HP бар, таймер, абилити, скорборд

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateHP     = Remotes:WaitForChild("UpdateHP")
local UpdateTimer  = Remotes:WaitForChild("UpdateTimer")
local MatchStart   = Remotes:WaitForChild("MatchStart")
local MatchEnd     = Remotes:WaitForChild("MatchEnd")
local UseAbility   = Remotes:WaitForChild("UseAbility")
local PlayerDied   = Remotes:WaitForChild("PlayerDied")

-- Создание ScreenGui
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "HUD"
hudGui.ResetOnSpawn = false
hudGui.Enabled = false
hudGui.Parent = PlayerGui

-- === HP BAR ===
local hpFrame = Instance.new("Frame")
hpFrame.Size = UDim2.new(0.3, 0, 0, 28)
hpFrame.Position = UDim2.new(0.35, 0, 0.88, 0)
hpFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
hpFrame.Parent = hudGui

local hpBar = Instance.new("Frame")
hpBar.Size = UDim2.new(1, 0, 1, 0)
hpBar.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
hpBar.Parent = hpFrame

local hpLabel = Instance.new("TextLabel")
hpLabel.Size = UDim2.new(1, 0, 1, 0)
hpLabel.BackgroundTransparency = 1
hpLabel.Text = "HP: 150 / 150"
hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hpLabel.TextScaled = true
hpLabel.Font = Enum.Font.GothamBold
hpLabel.ZIndex = 2
hpLabel.Parent = hpFrame

-- === TIMER ===
local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(0.1, 0, 0, 50)
timerLabel.Position = UDim2.new(0.45, 0, 0.02, 0)
timerLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
timerLabel.BackgroundTransparency = 0.5
timerLabel.Text = "1:30"
timerLabel.TextColor3 = Color3.fromRGB(255, 230, 0)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Parent = hudGui

-- === ABILITY BUTTONS ===
local abilityFrame = Instance.new("Frame")
abilityFrame.Size = UDim2.new(0.3, 0, 0, 70)
abilityFrame.Position = UDim2.new(0.35, 0, 0.92, 0)
abilityFrame.BackgroundTransparency = 1
abilityFrame.Parent = hudGui

local ABILITIES = { "M1", "Q", "E", "R" }
local abilityBtns = {}

for i, ab in ipairs(ABILITIES) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.22, 0, 1, 0)
	btn.Position = UDim2.new((i-1) * 0.25, 4, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	btn.Text = ab
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.Parent = abilityFrame
	abilityBtns[ab] = btn

	btn.MouseButton1Click:Connect(function()
		UseAbility:FireServer(ab, nil)
	end)
end

-- === SCOREBOARD ===
local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(0.15, 0, 0, 40)
scoreLabel.Position = UDim2.new(0.84, 0, 0.02, 0)
scoreLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
scoreLabel.BackgroundTransparency = 0.5
scoreLabel.Text = "Score: 0"
scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
scoreLabel.TextScaled = true
scoreLabel.Font = Enum.Font.Gotham
scoreLabel.Parent = hudGui

-- === KILL FEED ===
local killFeed = Instance.new("Frame")
killFeed.Size = UDim2.new(0.2, 0, 0.2, 0)
killFeed.Position = UDim2.new(0.78, 0, 0.06, 0)
killFeed.BackgroundTransparency = 1
killFeed.Parent = hudGui

local killLayout = Instance.new("UIListLayout")
killLayout.FillDirection = Enum.FillDirection.Vertical
killLayout.SortOrder = Enum.SortOrder.LayoutOrder
killLayout.Parent = killFeed

local function addKillFeedEntry(text)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 24)
	lbl.BackgroundColor3 = Color3.fromRGB(0,0,0)
	lbl.BackgroundTransparency = 0.6
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Gotham
	lbl.Parent = killFeed
	task.delay(4, function() lbl:Destroy() end)
end

-- === ОБРАБОТКА СОБЫТИЙ ===
MatchStart.OnClientEvent:Connect(function(heroData)
	hudGui.Enabled = true
	if heroData then
		hpLabel.Text = "HP: " .. heroData.hp .. " / " .. heroData.hp
		hpBar.Size = UDim2.new(1, 0, 1, 0)
	end
end)

UpdateHP.OnClientEvent:Connect(function(hp, maxHp)
	local ratio = math.clamp(hp / maxHp, 0, 1)
	TweenService:Create(hpBar, TweenInfo.new(0.2), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
	hpLabel.Text = "HP: " .. math.floor(hp) .. " / " .. maxHp
	-- Цвет HP бара
	if ratio > 0.5 then
		hpBar.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
	elseif ratio > 0.25 then
		hpBar.BackgroundColor3 = Color3.fromRGB(220, 180, 0)
	else
		hpBar.BackgroundColor3 = Color3.fromRGB(220, 60, 40)
	end
end)

UpdateTimer.OnClientEvent:Connect(function(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	timerLabel.Text = string.format("%d:%02d", m, s)
	if seconds <= 10 then
		timerLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
	else
		timerLabel.TextColor3 = Color3.fromRGB(255, 230, 0)
	end
end)

PlayerDied.OnClientEvent:Connect(function(victimId, killerId)
	local victim = Players:GetPlayerByUserId(victimId)
	local killer = Players:GetPlayerByUserId(killerId)
	local vName = victim and victim.Name or "Unknown"
	local kName = killer and killer.Name or "Unknown"
	addKillFeedEntry(kName .. " → " .. vName)
end)

MatchEnd.OnClientEvent:Connect(function()
	hudGui.Enabled = false
end)

-- Клавиатурные шорткаты
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	local key = input.KeyCode
	if key == Enum.KeyCode.Q then
		UseAbility:FireServer("Q", nil)
	elseif key == Enum.KeyCode.E then
		UseAbility:FireServer("E", nil)
	elseif key == Enum.KeyCode.R then
		UseAbility:FireServer("R", nil)
	end
end)
