-- DuelUI.client.lua | Anime Arena: Blitz
-- Система UI дуэлей:
--   • Входящий вызов: всплывашка Accept / Decline + таймер
--   • Клик по игроку в 3D мире (рейкаст) → отправка RequestDuel
--   • Индикатор отклонения / отмены

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local camera      = workspace.CurrentCamera

local Remotes        = ReplicatedStorage:WaitForChild("Remotes")
local rRequestDuel   = Remotes:WaitForChild("RequestDuel")
local rDuelRequest   = Remotes:WaitForChild("DuelRequest")
local rAcceptDuel    = Remotes:WaitForChild("AcceptDuel")
local rDeclineDuel   = Remotes:WaitForChild("DeclineDuel")
local rDuelDeclined  = Remotes:WaitForChild("DuelDeclined")
local rDuelCancelled = Remotes:WaitForChild("DuelCancelled")

-- ============================================================
-- GUI
-- ============================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "DuelUI"
screenGui.ResetOnSpawn   = false
screenGui.DisplayOrder   = 50
screenGui.IgnoreGuiInset = true
screenGui.Enabled        = true
screenGui.Parent         = PlayerGui

-- Панель (скрыта под экраном)
local panel = Instance.new("Frame")
panel.Name     = "DuelPanel"
panel.Size     = UDim2.new(0, 360, 0, 170)
panel.Position = UDim2.new(0.5, -180, 1, 20)  -- скрыта
panel.BackgroundColor3 = Color3.fromRGB(14, 8, 30)
panel.BorderSizePixel  = 0
panel.Visible          = false
panel.ZIndex           = 60
panel.Parent           = screenGui
do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 14); c.Parent = panel
	local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255, 80, 80)
	s.Thickness = 2.5; s.Parent = panel
end

local titleLbl = Instance.new("TextLabel")
titleLbl.Size              = UDim2.new(1, -16, 0, 30)
titleLbl.Position          = UDim2.new(0, 8, 0, 10)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3        = Color3.fromRGB(255, 80, 80)
titleLbl.Font              = Enum.Font.GothamBold
titleLbl.TextSize          = 20
titleLbl.Text              = "⚔️  ВЫЗОВ НА ДУЭЛЬ"
titleLbl.TextXAlignment    = Enum.TextXAlignment.Center
titleLbl.ZIndex            = 61
titleLbl.Parent            = panel

local chalLbl = Instance.new("TextLabel")
chalLbl.Size               = UDim2.new(1, -16, 0, 26)
chalLbl.Position           = UDim2.new(0, 8, 0, 44)
chalLbl.BackgroundTransparency = 1
chalLbl.TextColor3         = Color3.fromRGB(220, 220, 255)
chalLbl.Font               = Enum.Font.Gotham
chalLbl.TextSize           = 15
chalLbl.Text               = "Игрок вызывает вас!"
chalLbl.TextXAlignment     = Enum.TextXAlignment.Center
chalLbl.ZIndex             = 61
chalLbl.Parent             = panel

local timerLbl = Instance.new("TextLabel")
timerLbl.Size              = UDim2.new(1, -16, 0, 20)
timerLbl.Position          = UDim2.new(0, 8, 0, 74)
timerLbl.BackgroundTransparency = 1
timerLbl.TextColor3        = Color3.fromRGB(180, 180, 180)
timerLbl.Font              = Enum.Font.Gotham
timerLbl.TextSize          = 13
timerLbl.Text              = "Осталось: 30с"
timerLbl.TextXAlignment    = Enum.TextXAlignment.Center
timerLbl.ZIndex            = 61
timerLbl.Parent            = panel

local acceptBtn = Instance.new("TextButton")
acceptBtn.Size             = UDim2.new(0, 158, 0, 42)
acceptBtn.Position         = UDim2.new(0, 10, 0, 116)
acceptBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 60)
acceptBtn.TextColor3       = Color3.new(1, 1, 1)
acceptBtn.Font             = Enum.Font.GothamBold
acceptBtn.TextSize         = 16
acceptBtn.Text             = "✅ Принять"
acceptBtn.BorderSizePixel  = 0
acceptBtn.ZIndex           = 61
acceptBtn.Parent           = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = acceptBtn end

local declineBtn = Instance.new("TextButton")
declineBtn.Size            = UDim2.new(0, 158, 0, 42)
declineBtn.Position        = UDim2.new(0, 192, 0, 116)
declineBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
declineBtn.TextColor3      = Color3.new(1, 1, 1)
declineBtn.Font            = Enum.Font.GothamBold
declineBtn.TextSize        = 16
declineBtn.Text            = "❌ Отклонить"
declineBtn.BorderSizePixel = 0
declineBtn.ZIndex          = 61
declineBtn.Parent          = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = declineBtn end

-- ============================================================
-- ЛОГИКА ПАНЕЛИ
-- ============================================================

local currentRequesterUserId = nil
local countdownThread        = nil

local function showPanel(requesterName, requesterUserId, expireSeconds)
	currentRequesterUserId = requesterUserId
	chalLbl.Text           = string.format("%s вызывает вас на дуэль!", requesterName)
	timerLbl.Text          = string.format("Осталось: %dс", expireSeconds)
	timerLbl.TextColor3    = Color3.fromRGB(180, 180, 180)
	panel.Visible          = true

	TweenService:Create(panel,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -180, 1, -190) }):Play()

	if countdownThread then task.cancel(countdownThread) end
	local timeLeft = expireSeconds
	countdownThread = task.spawn(function()
		while timeLeft > 0 and panel.Visible do
			task.wait(1)
			timeLeft -= 1
			if panel.Visible then
				timerLbl.Text = string.format("Осталось: %dс", timeLeft)
				if timeLeft <= 5 then
					timerLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
				end
			end
		end
	end)
end

local function hidePanel()
	if countdownThread then task.cancel(countdownThread); countdownThread = nil end
	TweenService:Create(panel,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, -180, 1, 20) }):Play()
	task.delay(0.3, function() panel.Visible = false end)
	currentRequesterUserId = nil
end

-- ============================================================
-- СЕРВЕРНЫЕ СОБЫТИЯ
-- ============================================================

rDuelRequest.OnClientEvent:Connect(function(requesterName, requesterUserId, expireSeconds)
	showPanel(requesterName, requesterUserId, expireSeconds or 30)
end)

rDuelDeclined.OnClientEvent:Connect(function(targetName)
	-- Уведомление приходит через ShowNotification с сервера
	print(string.format("[DuelUI] %s declined duel", targetName))
end)

rDuelCancelled.OnClientEvent:Connect(function(reason)
	hidePanel()
end)

acceptBtn.MouseButton1Click:Connect(function()
	if not currentRequesterUserId then return end
	rAcceptDuel:FireServer(currentRequesterUserId)
	hidePanel()
end)

declineBtn.MouseButton1Click:Connect(function()
	if not currentRequesterUserId then return end
	rDeclineDuel:FireServer(currentRequesterUserId)
	hidePanel()
end)

-- ============================================================
-- КЛИК ПО ИГРОКУ В 3D (рейкаст для вызова на дуэль)
-- ============================================================

local MAX_DUEL_DISTANCE = 30
local lastClickTime     = 0
local CLICK_DEBOUNCE    = 0.5

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	-- Дебаунс
	if (os.clock() - lastClickTime) < CLICK_DEBOUNCE then return end

	-- Рейкаст
	local mousePos = UserInputService:GetMouseLocation()
	local unitRay  = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local params   = RaycastParams.new()
	params.FilterDescendantsInstances = { LocalPlayer.Character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 60, params)
	if not result then return end

	-- Находим модель игрока
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if not model then return end

	local targetPlayer = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character == model and p ~= LocalPlayer then
			targetPlayer = p
			break
		end
	end
	if not targetPlayer then return end

	-- Проверяем расстояние
	local myChar = LocalPlayer.Character
	local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local thHRP  = model:FindFirstChild("HumanoidRootPart")
	if myHRP and thHRP then
		if (myHRP.Position - thHRP.Position).Magnitude > MAX_DUEL_DISTANCE then return end
	end

	lastClickTime = os.clock()
	rRequestDuel:FireServer(targetPlayer.UserId)
end)

print("[DuelUI] Initialized ✓")
