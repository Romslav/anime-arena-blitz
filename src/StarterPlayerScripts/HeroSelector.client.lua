-- HeroSelector.client.lua
-- GUI выбора героя перед началом матча

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SelectHero  = Remotes:WaitForChild("SelectHero")
local HeroSelected = Remotes:WaitForChild("HeroSelected")
local MatchStart  = Remotes:WaitForChild("MatchStart")

-- Герои (12 персонажей)
local HEROES = {
	{ id = "flame_ronin",    name = "Flame Ronin",    hp = 180, dmg = 22, role = "Duelist",   color = Color3.fromRGB(220, 80, 40)  },
	{ id = "void_assassin", name = "Void Assassin",  hp = 130, dmg = 28, role = "Assassin",  color = Color3.fromRGB(100, 40, 180) },
	{ id = "thunder_monk",  name = "Thunder Monk",   hp = 160, dmg = 20, role = "Skirmisher",color = Color3.fromRGB(80, 160, 220) },
	{ id = "iron_titan",    name = "Iron Titan",     hp = 260, dmg = 15, role = "Tank",      color = Color3.fromRGB(120, 120, 140) },
	{ id = "scarlet_archer",name = "Scarlet Archer", hp = 140, dmg = 24, role = "Ranged",    color = Color3.fromRGB(200, 50, 80)  },
	{ id = "eclipse_hero",  name = "Eclipse Hero",   hp = 150, dmg = 26, role = "Assassin",  color = Color3.fromRGB(40, 20, 60)   },
	{ id = "storm_dancer",  name = "Storm Dancer",   hp = 145, dmg = 23, role = "Skirmisher",color = Color3.fromRGB(60, 200, 180) },
	{ id = "blood_sage",    name = "Blood Sage",     hp = 120, dmg = 30, role = "Mage",      color = Color3.fromRGB(180, 20, 20)  },
	{ id = "crystal_guard", name = "Crystal Guard",  hp = 240, dmg = 14, role = "Tank",      color = Color3.fromRGB(160, 220, 240) },
	{ id = "shadow_twin",   name = "Shadow Twin",    hp = 155, dmg = 25, role = "Support",   color = Color3.fromRGB(80, 80, 100)  },
	{ id = "neon_blitz",    name = "Neon Blitz",     hp = 135, dmg = 27, role = "Ranged",    color = Color3.fromRGB(40, 220, 120) },
	{ id = "jade_sentinel", name = "Jade Sentinel",  hp = 200, dmg = 18, role = "Duelist",   color = Color3.fromRGB(60, 160, 80)  },
}

local selectedHero = nil

-- Создание GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HeroSelectorGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
bg.BackgroundTransparency = 0.1
bg.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 60)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.Text = "CHOOSE YOUR HERO"
title.TextColor3 = Color3.fromRGB(255, 200, 0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = bg

local grid = Instance.new("Frame")
grid.Size = UDim2.new(0.9, 0, 0.6, 0)
grid.Position = UDim2.new(0.05, 0, 0.12, 0)
grid.BackgroundTransparency = 1
grid.Parent = bg

local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(0, 140, 0, 160)
layout.CellPadding = UDim2.new(0, 12, 0, 12)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

local infoPanel = Instance.new("Frame")
infoPanel.Size = UDim2.new(0.5, 0, 0.18, 0)
infoPanel.Position = UDim2.new(0.05, 0, 0.76, 0)
infoPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
infoPanel.BackgroundTransparency = 0.3
infoPanel.Parent = bg

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -10, 1, -10)
infoLabel.Position = UDim2.new(0, 5, 0, 5)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Hover a hero to see stats"
infoLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
infoLabel.TextScaled = true
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = infoPanel

local confirmBtn = Instance.new("TextButton")
confirmBtn.Size = UDim2.new(0.2, 0, 0.1, 0)
confirmBtn.Position = UDim2.new(0.75, 0, 0.84, 0)
confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
confirmBtn.Text = "CONFIRM"
confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
confirmBtn.TextScaled = true
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.Active = false
confirmBtn.AutoButtonColor = false
confirmBtn.Parent = bg

-- Создание карточек героев
for i, hero in ipairs(HEROES) do
	local card = Instance.new("TextButton")
	card.LayoutOrder = i
	card.BackgroundColor3 = hero.color
	card.BackgroundTransparency = 0.2
	card.Text = ""
	card.AutoButtonColor = false
	card.Parent = grid

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.35, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.65, 0)
	nameLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.BackgroundTransparency = 0.4
	nameLabel.Text = hero.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = card

	local roleLabel = Instance.new("TextLabel")
	roleLabel.Size = UDim2.new(1, 0, 0.2, 0)
	roleLabel.Position = UDim2.new(0, 0, 0, 0)
	roleLabel.BackgroundTransparency = 1
	roleLabel.Text = "[" .. hero.role .. "]"
	roleLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
	roleLabel.TextScaled = true
	roleLabel.Font = Enum.Font.Gotham
	roleLabel.Parent = card

	-- Наведение
	card.MouseEnter:Connect(function()
		infoLabel.Text = hero.name .. "  |  HP: " .. hero.hp .. "  DMG: " .. hero.dmg .. "  Role: " .. hero.role
	end)

	-- Клик
	card.MouseButton1Click:Connect(function()
		selectedHero = hero
		-- Сбрасываем подсветку всех
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("TextButton") then
				c.BackgroundTransparency = 0.2
			end
		end
		card.BackgroundTransparency = 0
		confirmBtn.Active = true
		confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 220, 80)
		infoLabel.Text = "Selected: " .. hero.name
	end)
end

-- Подтверждение выбора
confirmBtn.MouseButton1Click:Connect(function()
	if not selectedHero then return end
	SelectHero:FireServer(selectedHero.id)
	-- Закрываем GUI
	TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
	task.delay(0.6, function()
		screenGui:Destroy()
	end)
end)

-- Скрыть GUI после начала матча
MatchStart.OnClientEvent:Connect(function()
	if screenGui.Parent then
		screenGui:Destroy()
	end
end)
