-- MerchantNPCBuilder.server.lua | Anime Arena: Blitz
-- Builds the full visual body of "The Shrewd Merchant" NPC at runtime.
-- Architecture:
--   1. Waits for workspace.Lobby.NPCs.Trader model (created by default.project.json)
--   2. Populates it with all Parts (body, jacket, accessories, counter, FX)
--   3. Starts server-side animation loops (orb orbit, hologram flicker, neon pulse)
--   4. NPCService then adds ProximityPrompt on top (runs independently)
-- All animations are server-driven → auto-replicate to all clients.
-- Exports: _G.MerchantNPCBuilder (table with model ref, parts table)

local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CFG = require(ReplicatedStorage:WaitForChild("MerchantConfig"))
local C   = CFG.Colors
local S   = CFG.Sizes
local O   = CFG.Offsets
local A   = CFG.Anim
local PI  = math.pi

-- ============================================================
-- HELPERS
-- ============================================================

--- Creates a Part and parents it to the model.
--- @param model       Model  Parent model
--- @param name        string Part name (shown in Explorer)
--- @param cf          CFrame Absolute CFrame (set after parent so HRP exists)
--- @param size        Vector3
--- @param color       Color3
--- @param material    Enum.Material
--- @param shape       Enum.PartType? (defaults to Block)
--- @param transparency number? (defaults to 0)
--- @param castShadow  boolean? (defaults to false for perf)
local function mkPart(model, name, cf, size, color, material, shape, transparency, castShadow)
	local p        = Instance.new("Part")
	p.Name         = name
	p.Size         = size
	p.Color        = color
	p.Material     = material or Enum.Material.SmoothPlastic
	p.Shape        = shape or Enum.PartType.Block
	p.Transparency = transparency or 0
	p.Anchored     = true
	p.CanCollide   = false
	p.CastShadow   = castShadow or false
	p.CFrame       = cf
	p.Parent       = model
	return p
end

--- Shorthand: sphere part
local function mkSphere(model, name, cf, size, color, material, transparency)
	return mkPart(model, name, cf, size, color, material, Enum.PartType.Ball, transparency)
end

--- Shorthand: cylinder part (oriented Y-axis)
local function mkCylinder(model, name, cf, size, color, material, transparency)
	return mkPart(model, name, cf, size, color, material, Enum.PartType.Cylinder, transparency)
end

--- Adds a PointLight child to a part (for ambient neon glow)
local function addLight(part, color, brightness, range)
	local l           = Instance.new("PointLight")
	l.Color           = color
	l.Brightness      = brightness or 2
	l.Range           = range or 8
	l.Shadows         = false
	l.Parent          = part
	return l
end

--- Applies a tint-only UICorner-style attribute so MerchantVFX can identify
--- neon parts for pulse effects.
local function tagNeon(part)
	part:SetAttribute("IsNeon", true)
end

-- ============================================================
-- WAIT FOR TRADER MODEL
-- ============================================================

local function waitForTrader()
	local lobby = workspace:WaitForChild("Lobby", 30)
	if not lobby then
		error("[MerchantNPCBuilder] workspace.Lobby not found within 30s")
	end
	local npcs = lobby:WaitForChild("NPCs", 10)
	if not npcs then
		error("[MerchantNPCBuilder] workspace.Lobby.NPCs not found")
	end
	local model = npcs:WaitForChild(CFG.NPC_MODEL_NAME, 10)
	if not model then
		error("[MerchantNPCBuilder] Trader model not found in NPCs folder")
	end
	return model
end

-- ============================================================
-- BUILD CHARACTER
-- ============================================================

local function buildMerchant(model)
	-- Ensure HRP exists (created by project.json stub)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then
		hrp        = Instance.new("Part")
		hrp.Name   = "HumanoidRootPart"
		hrp.Size   = S.HRP
		hrp.Anchored    = true
		hrp.CanCollide  = false
		hrp.Transparency = 1
		hrp.CFrame = CFrame.new(0, 0, 0)
		hrp.Parent = model
	else
		hrp.Size        = S.HRP
		hrp.Transparency = 1
		hrp.CanCollide  = false
	end

	-- Parts table (name → Part) exported for animation & client VFX
	local parts = {}

	-- Helper: build part relative to HRP current CFrame
	local function p(name, offsetCF, size, color, material, shape, trans)
		local part = mkPart(model, name, hrp.CFrame * offsetCF, size, color, material, shape, trans)
		parts[name] = part
		return part
	end
	local function ps(name, offsetCF, size, color, material, trans)
		local part = mkSphere(model, name, hrp.CFrame * offsetCF, size, color, material, trans)
		parts[name] = part
		return part
	end
	local function pc(name, offsetCF, size, color, material, trans)
		local part = mkCylinder(model, name, hrp.CFrame * offsetCF, size, color, material, trans)
		parts[name] = part
		return part
	end

	-- -------------------------------------------------------
	-- BODY — Skin & Base Layers
	-- -------------------------------------------------------
	local head = p("Head", O.Head, S.Head, C.Skin, Enum.Material.SmoothPlastic)

	-- Ears (subtle bumps on sides of head)
	p("EarR", O.Head * CFrame.new( 1.15, -0.1, 0), Vector3.new(0.22,0.35,0.22), C.SkinShade)
	p("EarL", O.Head * CFrame.new(-1.15,-0.1, 0), Vector3.new(0.22,0.35,0.22), C.SkinShade)

	p("Neck",       O.Neck,       S.Neck,      C.BlackTech, Enum.Material.SmoothPlastic)
	p("UpperTorso", O.UpperTorso, S.UpperTorso,C.BlackTech, Enum.Material.SmoothPlastic)
	p("LowerTorso", O.LowerTorso, S.LowerTorso,C.CargoDark, Enum.Material.SmoothPlastic)
	p("Belt",       O.Belt,       S.Belt,       C.Chrome,   Enum.Material.Metal)

	-- -------------------------------------------------------
	-- JACKET — Oversized iridescent bomber
	-- -------------------------------------------------------
	local jacket = p("JacketBody", O.JacketBody, S.JacketBody, C.BomberPurple,
		Enum.Material.SmoothPlastic)
	jacket.Reflectance = 0.12

	-- Lapels (front opening of jacket — slightly different shade)
	local lapelR = p("LapelR", O.JacketBody * CFrame.new( 0.7,-0.2,-0.92)*CFrame.Angles(0,0, 0.22),
		Vector3.new(0.55,1.6,0.15), C.BomberSheen, Enum.Material.SmoothPlastic)
	lapelR.Reflectance = 0.2
	local lapelL = p("LapelL", O.JacketBody * CFrame.new(-0.7,-0.2,-0.92)*CFrame.Angles(0,0,-0.22),
		Vector3.new(0.55,1.6,0.15), C.BomberSheen, Enum.Material.SmoothPlastic)
	lapelL.Reflectance = 0.2

	-- -------------------------------------------------------
	-- ARMS — Jacket sleeves
	-- -------------------------------------------------------
	p("RUpperArm", O.RUpperArm, S.UpperArm, C.BomberPurple)
	p("RForearm",  O.RForearm,  S.Forearm,  C.BomberPurple)
	p("RHand",     O.RHand,     S.Hand,     C.Skin)

	local lUpperArm = p("LUpperArm", O.LUpperArm, S.UpperArm, C.BomberPurple)
	p("LForearm",  O.LForearm,  S.Forearm,  C.BomberPurple)
	p("LHand",     O.LHand,     S.Hand,     C.Skin)

	-- -------------------------------------------------------
	-- LEGS — Techwear cargo
	-- -------------------------------------------------------
	p("RThigh", O.RThigh, S.Thigh, C.CargoDark)
	p("RShin",  O.RShin,  S.Shin,  C.CargoDark)
	p("LThigh", O.LThigh, S.Thigh, C.CargoDark)
	p("LShin",  O.LShin,  S.Shin,  C.CargoDark)

	-- Cargo pockets (right thigh)
	p("RPocket",  O.RThigh * CFrame.new(-0.55, 0.2, 0), Vector3.new(0.82,0.7,0.14),
		C.CargoDark * 0.85, Enum.Material.SmoothPlastic)
	p("LPocket",  O.LThigh * CFrame.new( 0.55, 0.2, 0), Vector3.new(0.82,0.7,0.14),
		C.CargoDark * 0.85)

	-- Nylon strap/fastener details
	p("StrapR",O.RThigh * CFrame.new(-0.5,-0.7, 0), Vector3.new(0.08,0.45,0.08), C.Chrome, Enum.Material.Metal)
	p("StrapL",O.LThigh * CFrame.new( 0.5,-0.7, 0), Vector3.new(0.08,0.45,0.08), C.Chrome, Enum.Material.Metal)

	-- -------------------------------------------------------
	-- SHOES — Chunky future sneakers
	-- -------------------------------------------------------
	p("RFoot",     O.RFoot,     S.Foot,     C.ShoeBlack)
	p("LFoot",     O.LFoot,     S.Foot,     C.ShoeBlack)

	-- Neon sole glow strips
	local rSole = p("RSoleGlow", O.RSoleGlow, S.SoleGlow, C.ShoeGlowPurple, Enum.Material.Neon)
	local lSole = p("LSoleGlow", O.LSoleGlow, S.SoleGlow, C.ShoeGlowPurple, Enum.Material.Neon)
	tagNeon(rSole); tagNeon(lSole)
	addLight(rSole, C.NeonPurple, 1.5, 5)
	addLight(lSole, C.NeonPurple, 1.5, 5)

	-- -------------------------------------------------------
	-- HAIR — Platinum base + purple streaks
	-- -------------------------------------------------------
	p("HairMain",    O.HairMain,    S.HairMain,   C.HairPlatinum, Enum.Material.SmoothPlastic)
	p("HairTop",     O.HairTop,     S.HairTop,    C.HairPlatinum)
	p("HairSideR",   O.HairSideR,   S.HairSide,   C.HairPlatinum)
	p("HairSideL",   O.HairSideL,   S.HairSide,   C.HairPlatinum)

	-- Purple streaks (neon material for subtle glow)
	local streakR = p("HairStreakR", O.HairStreakR, S.HairStreak, C.HairPurple, Enum.Material.Neon)
	local streakL = p("HairStreakL", O.HairStreakL, S.HairStreak, C.HairPurple, Enum.Material.Neon)
	tagNeon(streakR); tagNeon(streakL)

	-- -------------------------------------------------------
	-- FACE — Eyes, eyebrows, smirk
	-- -------------------------------------------------------
	-- Right eye open, left eye slightly squinted (smirk)
	local eyeR = p("EyeR", O.EyeR,
		S.Eye, C.EyePurple, Enum.Material.Neon)
	local eyeL = p("EyeL", O.EyeL,
		Vector3.new(S.Eye.X, S.Eye.Y * 0.6, S.Eye.Z) -- squinted = shorter
		, C.EyePurple, Enum.Material.Neon)
	tagNeon(eyeR); tagNeon(eyeL)

	-- Eye highlights (white sparkle)
	p("EyeHighR", O.EyeR * CFrame.new(-0.12,-0.06,-0.07),
		Vector3.new(0.14,0.14,0.05), Color3.new(1,1,1))
	p("EyeHighL", O.EyeL * CFrame.new( 0.12,-0.04,-0.07),
		Vector3.new(0.1, 0.1, 0.05), Color3.new(1,1,1))

	-- Eyebrows (angled — right arched up, left slightly furrowed = smirk)
	p("EyebrowR", O.EyebrowR, S.Eyebrow, C.HairPlatinum)
	p("EyebrowL", O.EyebrowL, S.Eyebrow, C.HairPlatinum)

	-- Smirk (rotated slightly, offset to right side of face)
	p("Mouth", O.Mouth, S.Mouth, C.MouthColor)

	-- -------------------------------------------------------
	-- NEON YEN SYMBOL — Chest (front)
	-- -------------------------------------------------------
	local function neonYen(prefix, h1CF, h2CF, vertCF, armRCF, armLCF, scale)
		scale = scale or 1
		local ys  = Vector3.new(S.YenHBar.X * scale, S.YenHBar.Y, S.YenHBar.Z)
		local yv  = Vector3.new(S.YenVBar.X, S.YenVBar.Y * scale, S.YenVBar.Z)
		local ya  = Vector3.new(S.YenArm.X,  S.YenArm.Y * scale,  S.YenArm.Z)

		local parts_ = {}
		local function yn(suffix, cf, size)
			local pt = p(prefix..suffix, cf, size, C.NeonYellow, Enum.Material.Neon)
			tagNeon(pt)
			table.insert(parts_, pt)
			return pt
		end
		yn("_H1",   h1CF,   ys)
		yn("_H2",   h2CF,   ys)
		yn("_Vert", vertCF, yv)
		yn("_ArmR", armRCF, ya)
		yn("_ArmL", armLCF, ya)
		-- Add light to vertical bar
		addLight(parts_[3], C.NeonYellow, 2, 6)
		return parts_
	end

	-- Chest Yen
	neonYen("Yen", O.YenH1, O.YenH2, O.YenVert, O.YenArmR, O.YenArmL, 1)

	-- Back Yen (large decal, 1.6x scale)
	local backParts = neonYen("YenBack",
		O.YenBackH1, O.YenBackH2, O.YenBackVert, O.YenBackArmR, O.YenBackArmL, 1.6)
	addLight(backParts[1], C.NeonYellow, 3, 8)  -- extra glow on back

	-- -------------------------------------------------------
	-- SLEEVE PATCH "NEO-YEN" branding
	-- -------------------------------------------------------
	-- Right sleeve dark patch + cyan glow border
	p("SleeveR_BG", O.RForearm * CFrame.new(0,-0.1,-0.53),
		Vector3.new(0.7,0.5,0.08), Color3.fromRGB(10,10,25))
	local slGlowR = p("SleeveR_Glow", O.RForearm * CFrame.new(0,-0.1,-0.535),
		Vector3.new(0.72,0.52,0.06), C.NeonCyan, Enum.Material.Neon, nil, 0.4)
	tagNeon(slGlowR)

	-- Left sleeve
	p("SleeveL_BG", O.LForearm * CFrame.new(0,-0.1,-0.52),
		Vector3.new(0.7,0.5,0.08), Color3.fromRGB(10,10,25))
	local slGlowL = p("SleeveL_Glow", O.LForearm * CFrame.new(0,-0.1,-0.525),
		Vector3.new(0.72,0.52,0.06), C.NeonCyan, Enum.Material.Neon, nil, 0.4)
	tagNeon(slGlowL)

	-- -------------------------------------------------------
	-- CHAINS — Layered metal necklaces
	-- -------------------------------------------------------
	for i = 1, 4 do
		local yOff = {1.88, 1.65, 1.42, 1.18}
		local col  = (i == 4) and C.Gold or C.Chrome
		local mat  = (i == 4) and Enum.Material.Metal or Enum.Material.Metal
		-- Thin rings approximated with flat cylinders
		local chainCF = hrp.CFrame * CFrame.new(0, yOff[i], -0.3)
			* CFrame.Angles(0, 0, PI/2)  -- rotate cylinder to lay flat
		local ring = mkCylinder(model, "Chain"..i, chainCF,
			Vector3.new(0.12, 1.9 - i * 0.04, 0.12), col, mat)
		parts["Chain"..i] = ring
	end

	-- Pendant: Japanese coin (Mon)
	pc("Pendant",  O.Pendant,    Vector3.new(0.1,0.32,0.32), C.Gold, Enum.Material.Metal)
	-- Coin hole
	p("PendantHole", O.Pendant,  Vector3.new(0.12,0.14,0.14), C.BlackTech)

	-- Cyber-gem pendant (cyan)
	local gem = ps("CyberGem", O.GemPendant, S.GemPendant,
		C.NeonCyan, Enum.Material.Neon, 0.05)
	tagNeon(gem)
	addLight(gem, C.NeonCyan, 1.5, 4)

	-- -------------------------------------------------------
	-- EARRING — Yen coin in left ear
	-- -------------------------------------------------------
	local earring = pc("Earring", O.Earring, Vector3.new(0.08,0.22,0.22),
		C.NeonGold, Enum.Material.Neon)
	tagNeon(earring)
	-- Earring hole
	p("EarringHole", O.Earring, Vector3.new(0.1,0.1,0.1), C.BlackTech)

	-- -------------------------------------------------------
	-- SMART BRACELET — Left wrist
	-- -------------------------------------------------------
	pc("Bracelet",     O.Bracelet,     S.Bracelet, C.Chrome, Enum.Material.Metal)
	local bracGlow = pc("BraceletGlow", O.BraceletGlow,
		Vector3.new(S.Bracelet.X * 1.05, S.Bracelet.Y * 1.05, 0.12),
		C.NeonCyan, Enum.Material.Neon, nil, 0.25)
	tagNeon(bracGlow)
	addLight(bracGlow, C.NeonCyan, 2, 5)

	-- -------------------------------------------------------
	-- HOLOGRAM PANEL — Projected from bracelet (left side)
	-- -------------------------------------------------------
	local holo = p("Hologram", O.Hologram, S.HologramPanel,
		C.NeonCyan, Enum.Material.Neon, nil, 0.55)
	tagNeon(holo)

	-- Hologram "data lines" (3 thin horizontal bars)
	for i = 1, 3 do
		local rowCF = O.Hologram * CFrame.new(0, 0.28 - i * 0.2, -0.04)
		local row = p("HoloRow"..i, rowCF,
			Vector3.new(S.HologramPanel.X * 0.85, 0.06, 0.04),
			C.NeonCyan, Enum.Material.Neon, nil, 0.3)
		tagNeon(row)
	end

	-- -------------------------------------------------------
	-- CURRENCY ORB — Animated (see animation section below)
	-- -------------------------------------------------------
	-- Inner core (bright sphere)
	local orbInner = ps("OrbInner", hrp.CFrame * O.OrbCenter,
		S.OrbInner, C.OrbCore, Enum.Material.Neon, 0.0)
	tagNeon(orbInner)
	addLight(orbInner, C.OrbCore, 4, 7)

	-- Outer glow shell (semi-transparent)
	local orbOuter = ps("OrbOuter", hrp.CFrame * O.OrbCenter,
		S.OrbOuter, C.OrbGlow, Enum.Material.Neon, 0.5)
	tagNeon(orbOuter)

	-- Yen symbol on orb face (tiny flat piece)
	p("OrbYen", hrp.CFrame * O.OrbCenter * CFrame.new(0, 0, -0.27),
		Vector3.new(0.28, 0.28, 0.06), C.NeonYellow, Enum.Material.Neon)

	-- -------------------------------------------------------
	-- COUNTER / PRИЛАВОК (to the right of NPC)
	-- -------------------------------------------------------
	local ctrBody = p("CounterBody", O.CounterBody, S.CounterBody,
		C.CounterBase, Enum.Material.SmoothPlastic)
	ctrBody.Reflectance = 0.04

	local ctrTop = p("CounterTop", O.CounterTop, S.CounterTop,
		C.CounterTop, Enum.Material.Glass)
	ctrTop.Reflectance = 0.3

	-- Neon edge strips on counter front face
	for i = 1, 3 do
		local strips = {O.CounterStrip1, O.CounterStrip2, O.CounterStrip3}
		local col    = (i % 2 == 0) and C.NeonCyan or C.CounterNeon1
		local strip  = p("CtrStrip"..i, strips[i], S.CounterStrip, col, Enum.Material.Neon)
		tagNeon(strip)
		addLight(strip, col, 1.5, 4)
	end

	-- Holographic display on counter face
	local ctrHolo = p("CounterHolo", O.CounterDisplay, S.CounterDisplay,
		C.NeonCyan, Enum.Material.Neon, nil, 0.5)
	tagNeon(ctrHolo)

	-- "Trading" text glow bar on counter
	p("CounterSignBar", O.CounterDisplay * CFrame.new(0,-0.7,-0.01),
		Vector3.new(1.8, 0.18, 0.06), C.NeonYellow, Enum.Material.Neon)

	-- -------------------------------------------------------
	-- DECORATIVE NEON BOXES  (behind NPC)
	-- -------------------------------------------------------
	local boxColors = {C.NeonPurple, C.NeonCyan, C.NeonYellow}
	for i, bcol in ipairs(boxColors) do
		local boxOff = O.NeonBox1 * CFrame.new(0, (i - 1) * 2.2, 0)
		local box = p("NeonBox"..i, boxOff,
			Vector3.new(2.0, 2.0, 2.0), C.NeonBox, Enum.Material.SmoothPlastic)

		-- Neon trim strips on visible faces
		local edgeCF = boxOff * CFrame.new(0, 0.85, -1.0)
		local edge = p("NeonBoxEdge"..i, edgeCF,
			Vector3.new(1.9, 0.12, 0.08), bcol, Enum.Material.Neon)
		tagNeon(edge)
		addLight(edge, bcol, 2, 5)
	end

	-- -------------------------------------------------------
	-- NEON SIGN above counter: "¥ ショップ" label
	-- -------------------------------------------------------
	p("ShopSignBG",   O.CounterTop * CFrame.new(0, 1.6, -0.92),
		Vector3.new(2.4, 0.7, 0.1), Color3.fromRGB(8,8,16))
	local signNeon = p("ShopSignNeon", O.CounterTop * CFrame.new(0, 1.62, -0.96),
		Vector3.new(2.42, 0.72, 0.06), C.NeonYellow, Enum.Material.Neon, nil, 0.2)
	tagNeon(signNeon)
	addLight(signNeon, C.NeonYellow, 3, 8)

	-- -------------------------------------------------------
	-- Name "eyelid" for wink animation (toggled by client VFX)
	-- -------------------------------------------------------
	-- A part that slides down to "close" the left eye
	local winkLid = p("WinkLid", O.EyeL * CFrame.new(0, 0.22, 0),
		Vector3.new(S.Eye.X + 0.05, 0.08, S.Eye.Z + 0.02),
		C.Skin, Enum.Material.SmoothPlastic)
	winkLid:SetAttribute("IsWinkLid", true)  -- Client finds it via attribute

	print(string.format("[MerchantNPCBuilder] Built %d parts", #model:GetDescendants()))
	return parts
end

-- ============================================================
-- SERVER ANIMATIONS (replicate to all clients automatically)
-- ============================================================

local function startAnimations(model, parts)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local orbInner  = parts["OrbInner"]
	local orbOuter  = parts["OrbOuter"]
	local orbYen    = parts["OrbYen"]
	local hologram  = parts["Hologram"]
	local ctrHolo   = parts["CounterHolo"]
	local ctrDisplay = parts["CounterDisplay"] -- may be nil

	-- Collect all neon parts for pulse
	local neonParts = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") and desc:GetAttribute("IsNeon") then
			table.insert(neonParts, desc)
		end
	end

	-- -------------------------------------------------------
	-- 1. ORB ORBIT + FLOAT (Heartbeat loop, no TweenService)
	-- -------------------------------------------------------
	task.spawn(function()
		while model and model.Parent do
			local t         = tick()
			local hrpCF     = hrp.CFrame
			local centerCF  = hrpCF * O.OrbCenter

			local angle     = t * A.OrbOrbitSpeed
			local bobY      = math.sin(t * A.OrbBobSpeed) * A.OrbBobAmplitude

			-- Orbit offset in XZ plane, tilted for visual flair
			local orbitCF = centerCF
				* CFrame.Angles(A.OrbTiltAngle, angle, 0)
				* CFrame.new(A.OrbOrbitRadius, bobY, 0)

			if orbInner then orbInner.CFrame = orbitCF end
			if orbOuter then orbOuter.CFrame = orbitCF end
			if orbYen   then
				orbYen.CFrame = orbitCF * CFrame.new(0, 0, -0.28)
					* CFrame.Angles(0, -angle * 0.8, 0)
			end

			RunService.Heartbeat:Wait()
		end
	end)

	-- -------------------------------------------------------
	-- 2. HOLOGRAM FLICKER  (TweenService loop)
	-- -------------------------------------------------------
	local function holoFlicker(part)
		if not part then return end
		task.spawn(function()
			while part and part.Parent do
				-- Random target transparency in flicker range
				local target = A.HoloFlickerMin
					+ math.random() * (A.HoloFlickerMax - A.HoloFlickerMin)
				local duration = 0.08 + math.random() * 0.15
				local tw = TweenService:Create(part,
					TweenInfo.new(duration, Enum.EasingStyle.Linear),
					{Transparency = target})
				tw:Play()
				tw.Completed:Wait()
				-- Occasional "glitch" — full transparency flash
				if math.random() < 0.08 then
					part.Transparency = 0.9
					task.wait(0.04)
				end
			end
		end)
	end
	holoFlicker(hologram)
	holoFlicker(ctrHolo)
	-- Flicker hologram data rows too
	for i = 1, 3 do
		holoFlicker(parts["HoloRow"..i])
	end

	-- -------------------------------------------------------
	-- 3. NEON PULSE — slow "breathing" brightness
	-- -------------------------------------------------------
	task.spawn(function()
		-- We use a shared sine wave and offset each part slightly
		while model and model.Parent do
			local t    = tick()
			local wave = (math.sin(t * A.NeonPulseSpeed * math.pi) + 1) * 0.5
			local trans = A.NeonPulseMin + wave * (A.NeonPulseMax - A.NeonPulseMin)
			for _, np in ipairs(neonParts) do
				if np and np.Parent
					and not np:GetAttribute("NoNeonPulse")   -- skip orb (has its own anim)
					and np.Name ~= "OrbInner"
					and np.Name ~= "OrbOuter"
					and np.Transparency <= A.HoloFlickerMax + 0.05 -- skip holo (has flicker)
					and np.Name:sub(1, 4) ~= "Holo"
					and np.Name ~= "CounterHolo"
				then
					-- Only pulse non-holo neon
					np.Transparency = trans
				end
			end
			task.wait(1 / 30)  -- 30 Hz is plenty for pulse
		end
	end)

	-- -------------------------------------------------------
	-- 4. COUNTER SIGN SCROLL animation (CounterSignBar neon blink)
	-- -------------------------------------------------------
	local signBar = model:FindFirstChild("CounterSignBar")
	if signBar then
		task.spawn(function()
			while signBar and signBar.Parent do
				local t = tick()
				-- Breathing pulse at faster rate than main neon
				local wave = (math.sin(t * 2.5 * math.pi) + 1) * 0.5
				signBar.Transparency = wave * 0.15
				task.wait(1/20)
			end
		end)
	end

	-- -------------------------------------------------------
	-- 5. IDLE BODY SWAY — subtle left-right rock of jacket
	-- -------------------------------------------------------
	local jacketPart = model:FindFirstChild("JacketBody")
	if jacketPart then
		local baseOffset = O.JacketBody
		task.spawn(function()
			while jacketPart and jacketPart.Parent do
				local t = tick()
				local sway = math.sin(t * A.SwaySpeed * math.pi) * A.SwayAmplitude
				jacketPart.CFrame = hrp.CFrame * baseOffset
					* CFrame.new(sway, 0, 0)
					* CFrame.Angles(0, 0, sway * 0.03)
				task.wait(1/30)
			end
		end)
	end

	-- -------------------------------------------------------
	-- 6. ORB INNER LIGHT PULSE (PointLight intensity)
	-- -------------------------------------------------------
	if orbInner then
		local orbLight = orbInner:FindFirstChildOfClass("PointLight")
		if orbLight then
			task.spawn(function()
				while orbLight and orbLight.Parent do
					local t = tick()
					local pulse = 3.5 + math.sin(t * 2.2 * math.pi) * 1.5
					orbLight.Brightness = pulse
					task.wait(1/20)
				end
			end)
		end
	end

	-- -------------------------------------------------------
	-- 7. NEON BOX EDGE COLOR CYCLE (slow hue shift)
	-- -------------------------------------------------------
	local boxColors = {C.NeonPurple, C.NeonCyan, C.NeonYellow}
	task.spawn(function()
		while model and model.Parent do
			local t = tick()
			for i = 1, 3 do
				local edge = model:FindFirstChild("NeonBoxEdge"..i)
				if edge then
					-- Cycle through neon colors with time offset per box
					local phase  = (t * 0.25 + i * 0.33) % 1
					local colIdx = math.floor(phase * 3) + 1
					-- Smooth blend between two colors
					local a = boxColors[colIdx] or C.NeonPurple
					local b = boxColors[(colIdx % 3) + 1]
					local f = (phase * 3) % 1
					edge.Color = a:Lerp(b, f)
				end
			end
			task.wait(0.05)
		end
	end)

	print("[MerchantNPCBuilder] All animations started ✓")
end

-- ============================================================
-- MAIN ENTRY POINT
-- ============================================================

local Builder = {}
_G.MerchantNPCBuilder = Builder

task.spawn(function()
	local ok, model = pcall(waitForTrader)
	if not ok then
		warn("[MerchantNPCBuilder] " .. tostring(model))
		return
	end

	-- Check if already built (hot-reload guard)
	if model:FindFirstChild("JacketBody") then
		print("[MerchantNPCBuilder] Model already built, skipping.")
		return
	end

	-- Remove old Humanoid if present (we don't need it for a static NPC)
	-- but keep it so NPCService can find it without errors
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed       = 0
		hum.JumpPower       = 0
		hum.PlatformStand   = true
		hum.AutoJumpEnabled = false
	end

	print("[MerchantNPCBuilder] Building Shrewd Merchant body...")

	local parts = buildMerchant(model)
	Builder.Model = model
	Builder.Parts = parts

	-- Wait a frame for NPCService to finish PivotTo, then start anims
	task.wait(0.5)
	startAnimations(model, parts)

	print("[MerchantNPCBuilder] ✅ The Shrewd Merchant is ready for business!")
end)

return Builder
