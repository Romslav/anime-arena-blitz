-- MerchantVFX.client.lua | Anime Arena: Blitz
-- Client-side effects for The Shrewd Merchant NPC:
--   • Proximity wink animation (when player gets close)
--   • Live portrait ViewportFrame that appears alongside TradeUI
--   • Dynamic PointLight pulsing on the local client (zero server load)
--   • Merchant speech bubble (idle flavor text cycling)
--   • Shoe sole neon trail particles
-- Listens to: OpenTradePanel (shows portrait), proximity detection
-- Does NOT replicate anything — all effects are purely visual, client-only.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local CFG = require(ReplicatedStorage:WaitForChild("MerchantConfig"))
local C   = CFG.Colors
local A   = CFG.Anim
local PI  = math.pi

-- ============================================================
-- WAIT FOR TRADER MODEL
-- ============================================================

local function getTraderModel()
	local lobby = workspace:WaitForChild("Lobby", 30)
	if not lobby then return nil end
	local npcs = lobby:WaitForChild("NPCs", 10)
	if not npcs then return nil end
	return npcs:WaitForChild(CFG.NPC_MODEL_NAME, 20)
end

-- ============================================================
-- PORTRAIT GUI  (appears when TradeUI opens)
-- ============================================================

-- Root ScreenGui for portrait (separate from TradeUI so z-order is clean)
local portraitGui = Instance.new("ScreenGui")
portraitGui.Name           = "MerchantPortraitUI"
portraitGui.ResetOnSpawn   = false
portraitGui.DisplayOrder   = 46   -- above TradeUI (45) but below notifications
portraitGui.IgnoreGuiInset = true
portraitGui.Enabled        = false
portraitGui.Parent         = PlayerGui

-- Outer frame with cyberpunk border
local portraitFrame = Instance.new("Frame")
portraitFrame.Name              = "PortraitFrame"
portraitFrame.Size              = CFG.Portrait.Size
portraitFrame.Position          = CFG.Portrait.Position
portraitFrame.BackgroundColor3  = Color3.fromRGB(6, 4, 18)
portraitFrame.BorderSizePixel   = 0
portraitFrame.ZIndex            = 46
portraitFrame.Parent            = portraitGui

do -- Corner radius + neon stroke
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = portraitFrame

	local s = Instance.new("UIStroke")
	s.Color     = C.NeonPurple
	s.Thickness = 2.5
	s.Parent    = portraitFrame
end

-- ViewportFrame — renders the live 3D merchant portrait
local viewport = Instance.new("ViewportFrame")
viewport.Name             = "MerchantViewport"
viewport.Size             = UDim2.new(1, -8, 1, -50)
viewport.Position         = UDim2.new(0, 4, 0, 4)
viewport.BackgroundColor3 = Color3.fromRGB(8, 5, 22)
viewport.BorderSizePixel  = 0
viewport.LightColor       = Color3.fromRGB(200, 190, 255)
viewport.LightDirection   = Vector3.new(-0.5, -0.8, -0.6)
viewport.Ambient          = Color3.fromRGB(80, 50, 150)
viewport.ZIndex           = 47
viewport.Parent           = portraitFrame

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = viewport
end

-- Camera for the viewport
local vpCamera = Instance.new("Camera")
vpCamera.FieldOfView = 40
vpCamera.Parent      = viewport
viewport.CurrentCamera = vpCamera

-- "MERCHANT" label at bottom of portrait
local merchantLbl = Instance.new("TextLabel")
merchantLbl.Name              = "MerchantLabel"
merchantLbl.Size              = UDim2.new(1, 0, 0, 42)
merchantLbl.Position          = UDim2.new(0, 0, 1, -44)
merchantLbl.BackgroundColor3  = Color3.fromRGB(20, 10, 45)
merchantLbl.BackgroundTransparency = 0.3
merchantLbl.BorderSizePixel   = 0
merchantLbl.TextColor3        = C.NeonYellow
merchantLbl.Font              = Enum.Font.GothamBold
merchantLbl.TextSize          = 15
merchantLbl.Text              = "🪙  ТОН ТОРГОВЕЦ"
merchantLbl.TextXAlignment    = Enum.TextXAlignment.Center
merchantLbl.ZIndex            = 48
merchantLbl.Parent            = portraitFrame

do -- Rounded top edge on label
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = merchantLbl
end

-- Neon horizontal divider above label
local divider = Instance.new("Frame")
divider.Size              = UDim2.new(1, 0, 0, 2)
divider.Position          = UDim2.new(0, 0, 1, -46)
divider.BackgroundColor3  = C.NeonPurple
divider.BorderSizePixel   = 0
divider.ZIndex            = 48
divider.Parent            = portraitFrame

-- ============================================================
-- FLAVOR TEXT BUBBLE (idle speech above portrait)
-- ============================================================

local FLAVORS = {
	"🤑 Лучшие цены — у меня.",
	"¥  Смотри, что есть...",
	"💎 Редкий товар. Только сейчас.",
	"📈 Рынок растёт. Торгуй умно.",
	"👁  Я вижу потенциал в тебе.",
	"⚡ Быстрее думай, быстрее зарабатывай.",
	"🔥 Секретный стокк — только для своих.",
}

local speechBubble = Instance.new("Frame")
speechBubble.Name              = "SpeechBubble"
speechBubble.Size              = UDim2.new(1, 10, 0, 0)  -- auto-sized by text
speechBubble.Position          = UDim2.new(-0.03, 0, -0.28, 0)
speechBubble.AutomaticSize     = Enum.AutomaticSize.Y
speechBubble.BackgroundColor3  = Color3.fromRGB(22, 14, 50)
speechBubble.BackgroundTransparency = 0.1
speechBubble.BorderSizePixel   = 0
speechBubble.ZIndex            = 50
speechBubble.Visible           = false
speechBubble.Parent            = portraitFrame

do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = speechBubble
	local s = Instance.new("UIStroke"); s.Color = C.NeonCyan; s.Thickness = 1.5; s.Parent = speechBubble
	local p = Instance.new("UIPadding")
	p.PaddingLeft   = UDim.new(0,8)
	p.PaddingRight  = UDim.new(0,8)
	p.PaddingTop    = UDim.new(0,6)
	p.PaddingBottom = UDim.new(0,6)
	p.Parent = speechBubble
end

local speechText = Instance.new("TextLabel")
speechText.Name              = "SpeechText"
speechText.Size              = UDim2.new(1, 0, 0, 0)
speechText.AutomaticSize     = Enum.AutomaticSize.Y
speechText.BackgroundTransparency = 1
speechText.TextColor3        = Color3.fromRGB(220, 220, 255)
speechText.Font              = Enum.Font.Gotham
speechText.TextSize          = 13
speechText.TextWrapped       = true
speechText.Text              = FLAVORS[1]
speechText.TextXAlignment    = Enum.TextXAlignment.Left
speechText.ZIndex            = 51
speechText.Parent            = speechBubble

-- ============================================================
-- WINK ANIMATION STATE
-- ============================================================
local isWinking         = false
local lastWinkTime      = 0
local portraitClone     = nil  -- Clone of merchant placed inside ViewportFrame
local portraitEyeL      = nil  -- EyeL clone ref
local portraitWinkLid   = nil  -- WinkLid clone ref

-- ============================================================
-- POPULATE VIEWPORT WITH MERCHANT CLONE
-- ============================================================

local function populateViewport(traderModel)
	if portraitClone then portraitClone:Destroy() end

	-- Clone the full model into viewport
	portraitClone = traderModel:Clone()
	portraitClone.Name = "PortraitClone"

	-- Remove heavy/unneeded children from clone (lights, collision, etc.)
	for _, desc in ipairs(portraitClone:GetDescendants()) do
		if desc:IsA("PointLight") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Anchored   = true
			desc.CanCollide = false
			desc.CastShadow = false
		elseif desc:IsA("ProximityPrompt") or desc:IsA("BillboardGui") then
			desc:Destroy()
		end
	end
	portraitClone.Parent = viewport

	-- Find eye parts for wink
	portraitEyeL    = portraitClone:FindFirstChild("EyeL")
	portraitWinkLid = portraitClone:FindFirstChild("WinkLid")

	-- Position the viewport camera to look at the merchant's face
	local hrp = portraitClone:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Camera is 5 studs in front of the face, slightly above HRP
		local facePos  = hrp.CFrame * CFrame.new(0, 3.2, -5)  -- 5 studs in front of face pos
		local lookAt   = hrp.CFrame * CFrame.new(0, 3.2, 0)   -- looking toward face
		vpCamera.CFrame = CFrame.lookAt(facePos.Position, lookAt.Position)
	end
end

-- ============================================================
-- WINK ANIMATION (on clone)
-- ============================================================

local function doWink()
	if isWinking then return end
	if not portraitEyeL or not portraitWinkLid then return end

	isWinking = true

	-- Slide WinkLid down over the eye
	local openPos   = portraitWinkLid.CFrame
	local closedPos = openPos * CFrame.new(0, -0.22, 0)

	-- Close
	local tw = TweenService:Create(portraitWinkLid,
		TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{CFrame = closedPos})
	tw:Play()
	tw.Completed:Wait()

	task.wait(A.PortraitWinkDuration)

	-- Open
	local tw2 = TweenService:Create(portraitWinkLid,
		TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{CFrame = openPos})
	tw2:Play()
	tw2.Completed:Wait()

	isWinking = false
	lastWinkTime = tick()
end

-- ============================================================
-- SHOW / HIDE PORTRAIT
-- ============================================================

local isPortraitOpen = false
local portraitTweenIn, portraitTweenOut

local function showPortrait()
	if isPortraitOpen then return end
	isPortraitOpen = true

	portraitGui.Enabled = true

	-- Slide in from left
	portraitFrame.Position = CFG.Portrait.Position - UDim2.new(0.25, 0, 0, 0)
	portraitFrame.BackgroundTransparency = 1

	local tw = TweenService:Create(portraitFrame,
		TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Position                = CFG.Portrait.Position,
			BackgroundTransparency  = 0,
		})
	tw:Play()

	-- Show speech bubble after short delay
	task.delay(0.6, function()
		if isPortraitOpen then
			speechBubble.Visible = true
			-- Cycle flavors while open
			local idx = math.random(1, #FLAVORS)
			speechText.Text = FLAVORS[idx]
		end
	end)

	-- Auto-wink after portrait opens
	task.delay(1.2, function()
		if isPortraitOpen then doWink() end
	end)
end

local function hidePortrait()
	if not isPortraitOpen then return end
	isPortraitOpen = false
	speechBubble.Visible = false

	local tw = TweenService:Create(portraitFrame,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position               = CFG.Portrait.Position - UDim2.new(0.25, 0, 0, 0),
			BackgroundTransparency = 1,
		})
	tw:Play()
	tw.Completed:Wait()
	portraitGui.Enabled = false
end

-- ============================================================
-- PROXIMITY WINK (world-space, watches player distance)
-- ============================================================

local lastWorldWink = 0

local function startProximityWatcher(traderModel)
	local hrp = traderModel:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	RunService.Heartbeat:Connect(function()
		local char = LocalPlayer.Character
		if not char then return end
		local charHRP = char:FindFirstChild("HumanoidRootPart")
		if not charHRP then return end

		local dist = (charHRP.Position - hrp.Position).Magnitude
		local now  = tick()

		-- Wink at the portrait when the player is in range and time has passed
		if dist <= A.WinkDistance
			and now - lastWorldWink >= A.PortraitWinkInterval
			and isPortraitOpen
		then
			lastWorldWink = now
			task.spawn(doWink)
		end
	end)
end

-- ============================================================
-- FLAVOR TEXT CYCLE (while portrait is open)
-- ============================================================

task.spawn(function()
	local idx = 1
	while true do
		task.wait(6)
		if isPortraitOpen then
			idx = (idx % #FLAVORS) + 1
			-- Fade out
			local tw = TweenService:Create(speechText,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad),
				{TextTransparency = 1})
			tw:Play()
			tw.Completed:Wait()
			speechText.Text = FLAVORS[idx]
			-- Fade in
			TweenService:Create(speechText,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad),
				{TextTransparency = 0}):Play()
		end
	end
end)

-- ============================================================
-- PORTRAIT BORDER NEON PULSE (client-only cosmetic)
-- ============================================================

task.spawn(function()
	local stroke = portraitFrame:FindFirstChildOfClass("UIStroke")
	if not stroke then return end

	while true do
		local t     = tick()
		local wave  = (math.sin(t * 1.4 * PI) + 1) * 0.5
		local r     = math.floor(160 + wave * 80)
		local b     = math.floor(255)
		local g     = math.floor(wave * 60)
		stroke.Color = Color3.fromRGB(r, g, b)
		task.wait(1/30)
	end
end)

-- ============================================================
-- LOCAL PARTICLE EFFECTS: Orb sparkles (seen only by local player)
-- These use SelectionBox / PointLight tweaking on the CLIENT side
-- to layer additional visual richness without server cost.
-- ============================================================

local function addLocalOrbEffects(traderModel)
	local orbInner = traderModel:FindFirstChild("OrbInner")
	if not orbInner then return end

	-- Client-side extra point light that pulses differently per client
	local localLight = Instance.new("PointLight")
	localLight.Color      = Color3.fromRGB(200, 80, 255)
	localLight.Brightness = 5
	localLight.Range      = 9
	localLight.Shadows    = false
	localLight.Parent     = orbInner

	-- Random flicker (different per client for interesting variance)
	task.spawn(function()
		while orbInner and orbInner.Parent do
			local t = tick()
			local flicker = 4.5 + math.sin(t * 7.3) * 1.2
				+ math.sin(t * 13.7) * 0.6  -- two sine waves = irregular
			localLight.Brightness = flicker
			task.wait(1/20)
		end
	end)
end

-- ============================================================
-- SHOE SOLE LOCAL SPARKLE TRAIL (particle simulation via parts)
-- ============================================================

local function addSoleSparkle(traderModel)
	local soles = {
		traderModel:FindFirstChild("RSoleGlow"),
		traderModel:FindFirstChild("LSoleGlow"),
	}

	for _, sole in ipairs(soles) do
		if not sole then continue end

		-- Spawn tiny neon sparkle Parts that fade and float up
		-- This is purely client-side for performance
		task.spawn(function()
			while sole and sole.Parent do
				task.wait(0.3 + math.random() * 0.4)

				local spark = Instance.new("Part")
				spark.Size          = Vector3.new(0.08, 0.08, 0.08)
				spark.Shape         = Enum.PartType.Ball
				spark.Material      = Enum.Material.Neon
				spark.Color         = Color3.fromRGB(140, 0, 255)
				spark.Transparency  = 0
				spark.Anchored      = true
				spark.CanCollide    = false
				spark.CastShadow    = false
				spark.CFrame        = sole.CFrame * CFrame.new(
					(math.random() - 0.5) * 0.8,
					0,
					(math.random() - 0.5) * 1.2)
				spark.Parent        = workspace

				-- Float up and fade
				local targetCF = spark.CFrame * CFrame.new(0, 0.8 + math.random() * 0.6, 0)
				TweenService:Create(spark,
					TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{CFrame = targetCF, Transparency = 1}):Play()
				game:GetService("Debris"):AddItem(spark, 1)
			end
		end)
	end
end

-- ============================================================
-- CONNECT TO TRADE UI OPEN / CLOSE EVENTS
-- ============================================================

local Remotes    = ReplicatedStorage:WaitForChild("Remotes")
local rOpenTrade = Remotes:WaitForChild("OpenTradePanel")

-- Listen for OpenTradePanel to show portrait
rOpenTrade.OnClientEvent:Connect(showPortrait)

-- Listen for TradeUI closing — when TradeUI hides its ScreenGui, hide portrait too
-- We poll the TradeUI ScreenGui enabled state since it doesn't have a close remote
task.spawn(function()
	local tradeGui = PlayerGui:WaitForChild("TradeUI", 15)
	if not tradeGui then return end

	tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not tradeGui.Enabled then
			hidePortrait()
		end
	end)
end)

-- ============================================================
-- INITIALISE
-- ============================================================

task.spawn(function()
	-- Wait for the Trader model to be fully built by MerchantNPCBuilder
	local traderModel = getTraderModel()
	if not traderModel then
		warn("[MerchantVFX] Could not find Trader model")
		return
	end

	-- Wait until JacketBody exists (builder is done)
	local jacket = traderModel:WaitForChild("JacketBody", 20)
	if not jacket then
		warn("[MerchantVFX] JacketBody not found — MerchantNPCBuilder may not have run")
		return
	end

	print("[MerchantVFX] Trader model found, initialising client effects...")

	-- Populate portrait viewport with a clone of the merchant
	populateViewport(traderModel)

	-- Start proximity watcher for world-space winks
	startProximityWatcher(traderModel)

	-- Add local-only orb sparkle light
	addLocalOrbEffects(traderModel)

	-- Add shoe sole sparkle trail
	addSoleSparkle(traderModel)

	print("[MerchantVFX] ✅ Client effects active")
end)
