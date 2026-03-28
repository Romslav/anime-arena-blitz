-- ArenaMasterVFX.client.lua | Anime Arena: Blitz
-- Client-side effects for "The Stoic Sensei" Arena Master NPC:
--   * Proximity-based red eye glow (activates when player lingers nearby)
--   * Aura intensity flare on player approach
--   * Sword aura client-side shimmer particles
--   * Floating red kanji additional particle overlay
--   * Live portrait ViewportFrame for lobby menu
-- Does NOT replicate anything — all effects are purely visual, client-only.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local CFG = require(ReplicatedStorage:WaitForChild("ArenaMasterConfig"))
local COL = CFG.Colors
local A   = CFG.Anim
local PI  = math.pi

-- ============================================================
-- WAIT FOR MODEL
-- ============================================================

local function getSenseiModel()
	local lobby = workspace:WaitForChild("Lobby", 30)
	if not lobby then return nil end
	local npcs = lobby:WaitForChild("NPCs", 10)
	if not npcs then return nil end
	return npcs:WaitForChild(CFG.NPC_MODEL_NAME, 20)
end

-- ============================================================
-- PORTRAIT GUI (appears alongside LobbyUI)
-- ============================================================

local portraitGui = Instance.new("ScreenGui")
portraitGui.Name           = "SenseiPortraitUI"
portraitGui.ResetOnSpawn   = false
portraitGui.DisplayOrder   = 44
portraitGui.IgnoreGuiInset = true
portraitGui.Enabled        = false
portraitGui.Parent         = PlayerGui

local portraitFrame = Instance.new("Frame")
portraitFrame.Name              = "PortraitFrame"
portraitFrame.Size              = UDim2.new(0, 180, 0, 220)
portraitFrame.Position          = UDim2.new(0, 16, 0.5, -260)
portraitFrame.BackgroundColor3  = Color3.fromRGB(10, 4, 4)
portraitFrame.BorderSizePixel   = 0
portraitFrame.ZIndex            = 44
portraitFrame.Parent            = portraitGui

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = portraitFrame

	local s = Instance.new("UIStroke")
	s.Color     = COL.RedGlow
	s.Thickness = 2.5
	s.Parent    = portraitFrame
end

local viewport = Instance.new("ViewportFrame")
viewport.Name             = "SenseiViewport"
viewport.Size             = UDim2.new(1, -8, 1, -50)
viewport.Position         = UDim2.new(0, 4, 0, 4)
viewport.BackgroundColor3 = Color3.fromRGB(5, 2, 2)
viewport.BorderSizePixel  = 0
viewport.LightColor       = Color3.fromRGB(255, 200, 180)
viewport.LightDirection   = Vector3.new(-0.5, -0.8, -0.6)
viewport.Ambient          = Color3.fromRGB(100, 30, 20)
viewport.ZIndex           = 45
viewport.Parent           = portraitFrame

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = viewport
end

local vpCamera = Instance.new("Camera")
vpCamera.FieldOfView = 40
vpCamera.Parent      = viewport
viewport.CurrentCamera = vpCamera

local senseiLbl = Instance.new("TextLabel")
senseiLbl.Name              = "SenseiLabel"
senseiLbl.Size              = UDim2.new(1, 0, 0, 42)
senseiLbl.Position          = UDim2.new(0, 0, 1, -44)
senseiLbl.BackgroundColor3  = Color3.fromRGB(20, 5, 5)
senseiLbl.BackgroundTransparency = 0.3
senseiLbl.BorderSizePixel   = 0
senseiLbl.TextColor3        = COL.Gold
senseiLbl.Font              = Enum.Font.GothamBold
senseiLbl.TextSize          = 14
senseiLbl.Text              = "МАСТЕР АРЕН  |  SSS"
senseiLbl.TextXAlignment    = Enum.TextXAlignment.Center
senseiLbl.ZIndex            = 46
senseiLbl.Parent            = portraitFrame

do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = senseiLbl
end

local divider = Instance.new("Frame")
divider.Size              = UDim2.new(1, 0, 0, 2)
divider.Position          = UDim2.new(0, 0, 1, -46)
divider.BackgroundColor3  = COL.RedGlow
divider.BorderSizePixel   = 0
divider.ZIndex            = 46
divider.Parent            = portraitFrame

-- ============================================================
-- FLAVOR TEXT (sensei quotes)
-- ============================================================

local FLAVORS = {
	"Ты пришёл биться — или стоять?",
	"Арена не терпит слабых.",
	"Покажи мне свой стиль.",
	"Ранг — это не число. Это путь.",
	"Слова не ранят. Клинок — ранит.",
	"Сила без контроля — ничто.",
	"Каждый удар должен быть последним.",
	"Ты ещё дышишь. Значит, не сражался.",
}

local speechBubble = Instance.new("Frame")
speechBubble.Name              = "SpeechBubble"
speechBubble.Size              = UDim2.new(1, 10, 0, 0)
speechBubble.Position          = UDim2.new(-0.03, 0, -0.28, 0)
speechBubble.AutomaticSize     = Enum.AutomaticSize.Y
speechBubble.BackgroundColor3  = Color3.fromRGB(20, 5, 5)
speechBubble.BackgroundTransparency = 0.1
speechBubble.BorderSizePixel   = 0
speechBubble.ZIndex            = 50
speechBubble.Visible           = false
speechBubble.Parent            = portraitFrame

do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = speechBubble
	local s = Instance.new("UIStroke"); s.Color = COL.RedGlow; s.Thickness = 1.5; s.Parent = speechBubble
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft   = UDim.new(0, 8)
	pad.PaddingRight  = UDim.new(0, 8)
	pad.PaddingTop    = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = speechBubble
end

local speechText = Instance.new("TextLabel")
speechText.Name              = "SpeechText"
speechText.Size              = UDim2.new(1, 0, 0, 0)
speechText.AutomaticSize     = Enum.AutomaticSize.Y
speechText.BackgroundTransparency = 1
speechText.TextColor3        = Color3.fromRGB(255, 200, 180)
speechText.Font              = Enum.Font.Gotham
speechText.TextSize          = 13
speechText.TextWrapped       = true
speechText.Text              = FLAVORS[1]
speechText.TextXAlignment    = Enum.TextXAlignment.Left
speechText.ZIndex            = 51
speechText.Parent            = speechBubble

-- ============================================================
-- PORTRAIT POPULATION
-- ============================================================

local portraitClone = nil

local function populateViewport(senseiModel)
	if portraitClone then portraitClone:Destroy() end

	portraitClone = senseiModel:Clone()
	portraitClone.Name = "SenseiPortraitClone"

	for _, desc in ipairs(portraitClone:GetDescendants()) do
		if desc:IsA("PointLight") or desc:IsA("ParticleEmitter") then
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

	local hrp = portraitClone:FindFirstChild("HumanoidRootPart")
	if hrp then
		local facePos = hrp.CFrame * CFrame.new(0, 3.2, -5)
		local lookAt  = hrp.CFrame * CFrame.new(0, 3.2, 0)
		vpCamera.CFrame = CFrame.lookAt(facePos.Position, lookAt.Position)
	end
end

-- ============================================================
-- SHOW / HIDE PORTRAIT
-- ============================================================

local isPortraitOpen = false

local function showPortrait()
	if isPortraitOpen then return end
	isPortraitOpen = true

	portraitGui.Enabled = true

	portraitFrame.Position = UDim2.new(0, 16, 0.5, -260) - UDim2.new(0.25, 0, 0, 0)
	portraitFrame.BackgroundTransparency = 1

	TweenService:Create(portraitFrame,
		TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Position               = UDim2.new(0, 16, 0.5, -260),
			BackgroundTransparency = 0,
		}):Play()

	task.delay(0.6, function()
		if isPortraitOpen then
			speechBubble.Visible = true
			speechText.Text = FLAVORS[math.random(1, #FLAVORS)]
		end
	end)
end

local function hidePortrait()
	if not isPortraitOpen then return end
	isPortraitOpen = false
	speechBubble.Visible = false

	local tw = TweenService:Create(portraitFrame,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position               = UDim2.new(0, 16, 0.5, -260) - UDim2.new(0.25, 0, 0, 0),
			BackgroundTransparency = 1,
		})
	tw:Play()
	tw.Completed:Wait()
	portraitGui.Enabled = false
end

-- ============================================================
-- RED EYE GLOW — Proximity-based (activates when player lingers)
-- ============================================================

local function startEyeGlowEffect(senseiModel)
	local eyeGlowParts = {}
	local eyeLights    = {}

	for _, desc in ipairs(senseiModel:GetDescendants()) do
		if desc:IsA("BasePart") and desc:GetAttribute("IsEyeGlow") then
			table.insert(eyeGlowParts, desc)
			local light = desc:FindFirstChildOfClass("PointLight")
			if light then table.insert(eyeLights, light) end
		end
	end

	if #eyeGlowParts == 0 then return end

	local hrp = senseiModel:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local proximityTimer = 0
	local isGlowing      = false
	local glowIntensity  = 0  -- 0..1

	RunService.Heartbeat:Connect(function(dt)
		local char = LocalPlayer.Character
		if not char then return end
		local charHRP = char:FindFirstChild("HumanoidRootPart")
		if not charHRP then return end

		local dist = (charHRP.Position - hrp.Position).Magnitude

		if dist <= A.PromptDistance * 1.5 then
			proximityTimer = proximityTimer + dt
		else
			proximityTimer = math.max(0, proximityTimer - dt * 2)
		end

		-- Activate glow after delay
		if proximityTimer >= A.EyeGlowIdleDelay and not isGlowing then
			isGlowing = true
		end

		-- Fade glow in/out
		if isGlowing then
			glowIntensity = math.min(1, glowIntensity + dt / A.EyeGlowFadeIn)
		end
		if proximityTimer < A.EyeGlowIdleDelay * 0.5 and isGlowing then
			glowIntensity = math.max(0, glowIntensity - dt / A.EyeGlowFadeOut)
			if glowIntensity <= 0 then
				isGlowing = false
			end
		end

		-- Apply
		local trans = 1 - glowIntensity
		local brightness = glowIntensity * A.EyeGlowMaxBrightness

		-- Add subtle flicker when fully glowing
		if glowIntensity > 0.8 then
			local flicker = math.sin(tick() * 8) * 0.05
			trans = trans + flicker
			brightness = brightness + flicker * 2
		end

		for _, glow in ipairs(eyeGlowParts) do
			glow.Transparency = math.clamp(trans, 0, 1)
		end
		for _, light in ipairs(eyeLights) do
			light.Brightness = math.max(0, brightness)
		end
	end)
end

-- ============================================================
-- SWORD SHIMMER PARTICLES (client-only sparks)
-- ============================================================

local function startSwordShimmer(senseiModel)
	local sheath = senseiModel:FindFirstChild("NodachiSheath")
	if not sheath then return end

	task.spawn(function()
		while sheath and sheath.Parent do
			task.wait(0.4 + math.random() * 0.5)

			local spark = Instance.new("Part")
			spark.Size         = Vector3.new(0.06, 0.06, 0.06)
			spark.Shape        = Enum.PartType.Ball
			spark.Material     = Enum.Material.Neon
			spark.Color        = COL.RedGlow
			spark.Transparency = 0.2
			spark.Anchored     = true
			spark.CanCollide   = false
			spark.CastShadow   = false
			spark.CFrame       = sheath.CFrame * CFrame.new(
				(math.random() - 0.5) * 0.3,
				(math.random() - 0.5) * 2.0,
				(math.random() - 0.5) * 0.3)
			spark.Parent       = workspace

			local targetCF = spark.CFrame * CFrame.new(
				(math.random() - 0.5) * 0.5,
				0.5 + math.random() * 0.4,
				(math.random() - 0.5) * 0.5)

			TweenService:Create(spark,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{CFrame = targetCF, Transparency = 1}):Play()

			game:GetService("Debris"):AddItem(spark, 0.8)
		end
	end)
end

-- ============================================================
-- AURA INTENSIFICATION on approach
-- ============================================================

local function startAuraIntensification(senseiModel)
	local hrp = senseiModel:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local emitter = hrp:FindFirstChild("RedAuraEmitter")
	if not emitter then return end

	local baseRate = emitter.Rate

	RunService.Heartbeat:Connect(function()
		local char = LocalPlayer.Character
		if not char then return end
		local charHRP = char:FindFirstChild("HumanoidRootPart")
		if not charHRP then return end

		local dist = (charHRP.Position - hrp.Position).Magnitude
		-- Closer = more particles (up to 3x base rate)
		local factor = math.clamp(1 - (dist - 5) / 20, 0, 1)
		emitter.Rate = baseRate + baseRate * factor * 2
	end)
end

-- ============================================================
-- PORTRAIT BORDER PULSE
-- ============================================================

task.spawn(function()
	local stroke = portraitFrame:FindFirstChildOfClass("UIStroke")
	if not stroke then return end

	while true do
		local t    = tick()
		local wave = (math.sin(t * 1.0 * PI) + 1) * 0.5
		local r    = math.floor(180 + wave * 75)
		local g    = math.floor(wave * 20)
		local b    = math.floor(10 + wave * 20)
		stroke.Color = Color3.fromRGB(r, g, b)
		task.wait(1 / 30)
	end
end)

-- ============================================================
-- FLAVOR TEXT CYCLE
-- ============================================================

task.spawn(function()
	local idx = 1
	while true do
		task.wait(7)
		if isPortraitOpen then
			idx = (idx % #FLAVORS) + 1
			local tw = TweenService:Create(speechText,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad),
				{TextTransparency = 1})
			tw:Play()
			tw.Completed:Wait()
			speechText.Text = FLAVORS[idx]
			TweenService:Create(speechText,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad),
				{TextTransparency = 0}):Play()
		end
	end
end)

-- ============================================================
-- CONNECT TO LOBBY UI EVENTS
-- ============================================================

local Remotes    = ReplicatedStorage:WaitForChild("Remotes")
local rOpenLobby = Remotes:WaitForChild("OpenLobbyMenu")

rOpenLobby.OnClientEvent:Connect(showPortrait)

-- Hide portrait when LobbyUI closes
task.spawn(function()
	local lobbyGui = PlayerGui:WaitForChild("LobbyUI", 15)
	if not lobbyGui then return end

	lobbyGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not lobbyGui.Enabled then
			hidePortrait()
		end
	end)
end)

-- ============================================================
-- INITIALISE
-- ============================================================

task.spawn(function()
	local senseiModel = getSenseiModel()
	if not senseiModel then
		warn("[ArenaMasterVFX] Could not find ArenasMaster model")
		return
	end

	-- Wait until builder has finished
	local torso = senseiModel:WaitForChild("UpperTorso", 20)
	if not torso then
		warn("[ArenaMasterVFX] UpperTorso not found — builder may not have run")
		return
	end

	print("[ArenaMasterVFX] Sensei model found, initialising client effects...")

	populateViewport(senseiModel)
	startEyeGlowEffect(senseiModel)
	startSwordShimmer(senseiModel)
	startAuraIntensification(senseiModel)

	print("[ArenaMasterVFX] Client effects active")
end)
