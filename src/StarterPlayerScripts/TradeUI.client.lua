-- TradeUI.client.lua | Anime Arena: Blitz
-- UI торговли монетами:
--   • Список онлайн-игроков для выбора получателя
--   • Поле ввода суммы
--   • Отправка через TransferCoins → ответ TradeResult
--   • Открывается через OpenTradePanel (NPC «Торговец»)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local rOpenTrade     = Remotes:WaitForChild("OpenTradePanel")
local rTransferCoins = Remotes:WaitForChild("TransferCoins")
local rTradeResult   = Remotes:WaitForChild("TradeResult")

-- ============================================================
-- GUI
-- ============================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "TradeUI"
screenGui.ResetOnSpawn   = false
screenGui.DisplayOrder   = 45
screenGui.IgnoreGuiInset = true
screenGui.Enabled        = false
screenGui.Parent         = PlayerGui

-- Затемнение фона
local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.BorderSizePixel = 0
overlay.Text = ""
overlay.ZIndex = 40
overlay.Parent = screenGui

-- Основная панель
local panel = Instance.new("Frame")
panel.Size     = UDim2.new(0, 380, 0, 300)
panel.Position = UDim2.new(0.5, -190, 0.5, -150)
panel.BackgroundColor3 = Color3.fromRGB(12, 8, 26)
panel.BorderSizePixel  = 0
panel.ZIndex = 41
panel.Parent = screenGui
do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 16); c.Parent = panel
	local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255, 210, 60)
	s.Thickness = 2; s.Parent = panel
end

-- Заголовок
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -16, 0, 34)
titleLbl.Position = UDim2.new(0, 8, 0, 10)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3 = Color3.fromRGB(255, 210, 60)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 22
titleLbl.Text = "🪙  ПЕРЕДАТЬ МОНЕТЫ"
titleLbl.TextXAlignment = Enum.TextXAlignment.Center
titleLbl.ZIndex = 42
titleLbl.Parent = panel

-- Лейбл: Кому
local targetTitleLbl = Instance.new("TextLabel")
targetTitleLbl.Size = UDim2.new(1, -24, 0, 20)
targetTitleLbl.Position = UDim2.new(0, 12, 0, 54)
targetTitleLbl.BackgroundTransparency = 1
targetTitleLbl.TextColor3 = Color3.fromRGB(180, 180, 210)
targetTitleLbl.Font = Enum.Font.GothamBold
targetTitleLbl.TextSize = 13
targetTitleLbl.Text = "Кому:"
targetTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
targetTitleLbl.ZIndex = 42
targetTitleLbl.Parent = panel

-- Список игроков
local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Size = UDim2.new(1, -24, 0, 90)
playerListFrame.Position = UDim2.new(0, 12, 0, 76)
playerListFrame.BackgroundColor3 = Color3.fromRGB(20, 14, 40)
playerListFrame.BorderSizePixel = 0
playerListFrame.ScrollBarThickness = 4
playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
playerListFrame.ZIndex = 42
playerListFrame.Parent = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = playerListFrame end
do
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.Name
	l.Padding   = UDim.new(0, 4)
	l.Parent    = playerListFrame
end

-- Лейбл: Сумма
local amountTitleLbl = Instance.new("TextLabel")
amountTitleLbl.Size = UDim2.new(1, -24, 0, 20)
amountTitleLbl.Position = UDim2.new(0, 12, 0, 178)
amountTitleLbl.BackgroundTransparency = 1
amountTitleLbl.TextColor3 = Color3.fromRGB(180, 180, 210)
amountTitleLbl.Font = Enum.Font.GothamBold
amountTitleLbl.TextSize = 13
amountTitleLbl.Text = "Сумма (монет):"
amountTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
amountTitleLbl.ZIndex = 42
amountTitleLbl.Parent = panel

-- Поле ввода
local amountBox = Instance.new("TextBox")
amountBox.Size     = UDim2.new(1, -24, 0, 38)
amountBox.Position = UDim2.new(0, 12, 0, 200)
amountBox.BackgroundColor3 = Color3.fromRGB(24, 18, 48)
amountBox.TextColor3 = Color3.fromRGB(255, 240, 180)
amountBox.Font = Enum.Font.GothamBold
amountBox.TextSize = 18
amountBox.PlaceholderText = "Введите сумму..."
amountBox.PlaceholderColor3 = Color3.fromRGB(100, 90, 130)
amountBox.ClearTextOnFocus = false
amountBox.Text = ""
amountBox.BorderSizePixel = 0
amountBox.ZIndex = 42
amountBox.Parent = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = amountBox end

-- Кнопки
local sendBtn = Instance.new("TextButton")
sendBtn.Size     = UDim2.new(0, 168, 0, 40)
sendBtn.Position = UDim2.new(0, 12, 0, 250)
sendBtn.BackgroundColor3 = Color3.fromRGB(200, 160, 30)
sendBtn.TextColor3 = Color3.new(0, 0, 0)
sendBtn.Font = Enum.Font.GothamBold
sendBtn.TextSize = 16
sendBtn.Text = "💸 Отправить"
sendBtn.BorderSizePixel = 0
sendBtn.ZIndex = 42
sendBtn.Parent = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = sendBtn end

local closeBtn = Instance.new("TextButton")
closeBtn.Size     = UDim2.new(0, 168, 0, 40)
closeBtn.Position = UDim2.new(0, 200, 0, 250)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Text = "✖ Закрыть"
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 42
closeBtn.Parent = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = closeBtn end

-- ============================================================
-- СОСТОЯНИЕ
-- ============================================================

local selectedUserId   = nil
local selectedUserName = nil
local playerButtons    = {}

local function setStatus(msg, col)
	amountTitleLbl.Text       = msg
	amountTitleLbl.TextColor3 = col or Color3.fromRGB(180, 180, 210)
end

local function refreshPlayerList()
	for _, btn in pairs(playerButtons) do btn:Destroy() end
	playerButtons  = {}
	selectedUserId = nil

	local count = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p == LocalPlayer then continue end
		count += 1

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -8, 0, 30)
		btn.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
		btn.TextColor3 = Color3.fromRGB(220, 220, 255)
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 14
		btn.Text = p.Name
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.BorderSizePixel = 0
		btn.ZIndex = 43
		btn.Name = tostring(p.UserId)
		do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = btn end
		do
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 8)
			pad.Parent = btn
		end
		btn.Parent = playerListFrame
		table.insert(playerButtons, btn)

		local uid = p.UserId
		local uname = p.Name
		btn.MouseButton1Click:Connect(function()
			for _, b in pairs(playerButtons) do
				b.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
			end
			btn.BackgroundColor3 = Color3.fromRGB(80, 50, 160)
			selectedUserId   = uid
			selectedUserName = uname
		end)
	end

	playerListFrame.CanvasSize = UDim2.new(0, 0, 0, count * 34)
end

-- ============================================================
-- ОТКРЫТЬ / ЗАКРЫТЬ
-- ============================================================

local function openUI()
	refreshPlayerList()
	amountBox.Text = ""
	setStatus("Сумма (монет):")
	screenGui.Enabled = true
	TweenService:Create(panel,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -190, 0.5, -150) }):Play()
end

local function closeUI()
	TweenService:Create(panel,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, -190, 1, 20) }):Play()
	task.delay(0.25, function() screenGui.Enabled = false end)
end

rOpenTrade.OnClientEvent:Connect(openUI)
overlay.MouseButton1Click:Connect(closeUI)
closeBtn.MouseButton1Click:Connect(closeUI)

-- ============================================================
-- ОТПРАВКА
-- ============================================================

sendBtn.MouseButton1Click:Connect(function()
	if not selectedUserId then
		setStatus("❌ Выберите игрока из списка", Color3.fromRGB(255, 80, 80))
		return
	end

	local amount = tonumber(amountBox.Text)
	if not amount or amount < 1 then
		setStatus("❌ Введите корректную сумму", Color3.fromRGB(255, 80, 80))
		return
	end

	sendBtn.Active = false
	sendBtn.BackgroundTransparency = 0.5
	setStatus("⏳ Отправка...", Color3.fromRGB(200, 200, 200))

	rTransferCoins:FireServer(selectedUserId, amount)
end)

-- ============================================================
-- ОТВЕТ СЕРВЕРА
-- ============================================================

rTradeResult.OnClientEvent:Connect(function(success, message, newBalance)
	sendBtn.Active = true
	sendBtn.BackgroundTransparency = 0

	if success then
		setStatus(message, Color3.fromRGB(80, 220, 80))
		amountBox.Text = ""
		task.delay(2.5, function()
			setStatus("Сумма (монет):")
		end)
	else
		setStatus(message, Color3.fromRGB(255, 80, 80))
		task.delay(3, function()
			setStatus("Сумма (монет):")
		end)
	end
end)

print("[TradeUI] Initialized ✓")
