-- MerchantConfig.lua | Anime Arena: Blitz
-- Shared configuration for The Shrewd Merchant NPC.
-- Used by: MerchantNPCBuilder (server), MerchantVFX (client).
-- DO NOT require() on hot paths — module is cached after first load.

local MerchantConfig = {}

-- ============================================================
-- IDENTITY
-- ============================================================
MerchantConfig.NPC_MODEL_NAME = "Trader"   -- Name in workspace.Lobby.NPCs

-- ============================================================
-- COLOR PALETTE
-- ============================================================
local C = Color3.fromRGB

MerchantConfig.Colors = {
	-- Body
	Skin          = C(242, 200, 160),
	SkinShade     = C(220, 175, 135),

	-- Hair
	HairPlatinum  = C(235, 235, 240),
	HairPurple    = C(128, 0,   230),   -- Neon material

	-- Clothing
	BlackTech     = C(14,  12,  22),    -- Turtleneck, base layer
	BomberPurple  = C(68,  20,  178),   -- Jacket primary
	BomberSheen   = C(20,  130, 200),   -- Jacket secondary (iridescent edge)
	CargoDark     = C(12,  12,  18),    -- Cargo pants

	-- Shoes
	ShoeBlack     = C(18,  18,  24),
	ShoeGlowPurple= C(140, 0,   255),   -- Neon material

	-- Neon accents
	NeonYellow    = C(255, 228, 0),     -- ¥ symbol glow (Neon material)
	NeonPurple    = C(160, 0,   255),   -- Neon material
	NeonCyan      = C(0,   220, 255),   -- Hologram, bracelet (Neon material)
	NeonGold      = C(255, 200, 30),    -- Gold chains, earring (Neon material)

	-- Metal
	Chrome        = C(210, 210, 220),
	Gold          = C(255, 195, 25),

	-- FX
	OrbCore       = C(210, 80,  255),   -- Neon material
	OrbGlow       = C(170, 40,  220),

	-- Counter / Environment
	CounterBase   = C(18,  18,  32),
	CounterTop    = C(28,  28,  48),
	CounterNeon1  = C(140, 0,   255),   -- Neon material
	CounterNeon2  = C(0,   200, 255),   -- Neon material
	NeonBox       = C(10,  10,  22),

	-- Face
	EyePurple     = C(140, 40,  240),   -- Neon material
	MouthColor    = C(80,  20,  20),
}

-- ============================================================
-- PART SIZES  (studs: Width, Height, Depth)
-- ============================================================
local V3 = Vector3.new

MerchantConfig.Sizes = {
	HRP            = V3(2,   2,   1),    -- Invisible root, anchored

	Head           = V3(2.2, 2.2, 1.8),
	Neck           = V3(0.7, 0.5, 0.7),

	UpperTorso     = V3(2.5, 2.4, 1.5),  -- Black turtleneck base
	JacketBody     = V3(3.0, 2.6, 1.8),  -- Oversized bomber (wider than torso)
	LowerTorso     = V3(2.2, 0.9, 1.5),  -- Hips
	Belt           = V3(2.3, 0.25,1.6),

	-- Arms (jacket sleeves)
	UpperArm       = V3(1.1, 1.9, 1.1),
	Forearm        = V3(1.0, 1.8, 1.0),
	Hand           = V3(0.85,0.8, 0.65),

	-- Legs
	Thigh          = V3(1.0, 2.0, 1.0),
	Shin           = V3(0.9, 2.0, 0.9),
	Foot           = V3(1.0, 0.75,1.5),  -- Chunky sneaker
	SoleGlow       = V3(0.95,0.12,1.45),

	-- Hair
	HairMain       = V3(2.3, 1.0, 1.4),
	HairTop        = V3(2.1, 0.55,1.0),
	HairSide       = V3(0.5, 1.1, 0.9),
	HairStreak     = V3(0.3, 0.9, 0.6),

	-- Face
	Eye            = V3(0.45,0.3, 0.12),
	Eyebrow        = V3(0.5, 0.12,0.1),
	Mouth          = V3(0.6, 0.2, 0.1),

	-- Neon Yen (chest, per piece)
	YenHBar        = V3(0.85,0.14,0.1),  -- Horizontal bar
	YenVBar        = V3(0.14,0.65,0.1),  -- Vertical bar
	YenArm         = V3(0.14,0.6, 0.1),  -- Diagonal Y arm

	-- Accessories
	ChainRing      = V3(0.95,0.95,0.12),  -- Torus approximated as thin cyl
	Pendant        = V3(0.28,0.28,0.08),
	GemPendant     = V3(0.2, 0.22,0.2),
	Earring        = V3(0.2, 0.2, 0.08),
	Bracelet       = V3(0.62,0.62,0.22),

	-- Hologram plane
	HologramPanel  = V3(1.2, 0.9, 0.06),

	-- Orb
	OrbInner       = V3(0.5, 0.5, 0.5),
	OrbOuter       = V3(0.8, 0.8, 0.8),

	-- Counter
	CounterBody    = V3(3.0, 2.8, 1.6),
	CounterTop     = V3(3.1, 0.22,1.7),
	CounterStrip   = V3(3.0, 0.1, 0.1),
	CounterDisplay = V3(2.0, 1.2, 0.08),
}

-- ============================================================
-- OFFSETS relative to HRP CFrame (studs)
-- HRP is at hip level. X=right, Y=up, Z=forward(-face)
-- Character faces -Z (toward camera / players).
-- ============================================================
local CF  = CFrame.new
local CFA = CFrame.Angles
local PI  = math.pi

MerchantConfig.Offsets = {
	-- Body
	Head           = CF(0,    3.2,  0),
	Neck           = CF(0,    2.25, 0),
	UpperTorso     = CF(0,    0.9,  0),
	JacketBody     = CF(0,    0.95, 0.05),
	LowerTorso     = CF(0,   -0.5,  0),
	Belt           = CF(0,   -0.88, 0.05),

	-- Arms (character's right = +X when facing -Z)
	RUpperArm      = CF( 2.1,  0.7,  0),
	RForearm       = CF( 2.05,-0.9,  0.05),
	RHand          = CF( 2.0, -2.6,  0.1),

	-- Left arm raised slightly (holds orb)
	LUpperArm      = CF(-2.1,  0.85, 0)  * CFA(0, 0, 0.18),
	LForearm       = CF(-2.05,-0.75, 0.1) * CFA(0.25, 0, 0),
	LHand          = CF(-2.0, -2.35, 0.18) * CFA(0.4, 0, 0),

	-- Legs
	RThigh         = CF( 0.55,-1.8,  0),
	RShin          = CF( 0.55,-3.7,  0),
	RFoot          = CF( 0.55,-5.2,  0.25),
	RSoleGlow      = CF( 0.55,-5.55, 0.25),

	LThigh         = CF(-0.55,-1.8,  0),
	LShin          = CF(-0.55,-3.7,  0),
	LFoot          = CF(-0.55,-5.2,  0.25),
	LSoleGlow      = CF(-0.55,-5.55, 0.25),

	-- Hair
	HairMain       = CF(0,    4.6,  -0.25) * CFA(0.15, 0, 0),
	HairTop        = CF(0.15, 5.0,  -0.3)  * CFA(0.25, 0, -0.08),
	HairSideR      = CF( 1.15,3.9,  -0.2),
	HairSideL      = CF(-1.15,3.9,  -0.2),
	HairStreakR    = CF( 0.55,4.8,  -0.28),
	HairStreakL    = CF(-0.35,4.9,  -0.3),

	-- Face (front face -Z of head)
	EyeR           = CF( 0.4, 3.15,-0.95),
	EyeL           = CF(-0.4, 3.05,-0.95),  -- slightly lower (squinted)
	EyebrowR       = CF( 0.4, 3.45,-0.93) * CFA(0, 0, -0.15),
	EyebrowL       = CF(-0.4, 3.55,-0.93) * CFA(0, 0,  0.22),
	Mouth          = CF( 0.12,2.7, -0.93) * CFA(0, 0, -0.18),
	Earring        = CF(-1.15,3.05,-0.1),

	-- Yen chest (front of jacket)
	YenH1          = CF(0,    1.3, -0.93),
	YenH2          = CF(0,    0.95,-0.93),
	YenVert        = CF(0,    0.55,-0.93),
	YenArmR        = CF( 0.28,1.75,-0.93) * CFA(0, 0, -0.52),
	YenArmL        = CF(-0.28,1.75,-0.93) * CFA(0, 0,  0.52),

	-- Yen back (large neon decal on jacket back)
	YenBackH1      = CF(0,    1.4,  0.95),
	YenBackH2      = CF(0,    0.95, 0.95),
	YenBackVert    = CF(0,    0.5,  0.95),
	YenBackArmR    = CF( 0.42,1.95, 0.95) * CFA(0, 0, -0.5),
	YenBackArmL    = CF(-0.42,1.95, 0.95) * CFA(0, 0,  0.5),

	-- Chains (rings approximated, stacked)
	Chain1         = CF(0,    1.88,-0.3),
	Chain2         = CF(0,    1.65,-0.3),
	Chain3         = CF(0,    1.42,-0.3),
	ChainGold      = CF(0,    1.18,-0.3),
	Pendant        = CF( 0.22,0.85,-0.8),
	GemPendant     = CF(-0.28,0.72,-0.8),

	-- Smart bracelet (left wrist)
	Bracelet       = CF(-2.02,-2.0, 0.12),
	BraceletGlow   = CF(-2.02,-2.0, 0.12),

	-- Hologram panel (left of body, projected from bracelet)
	Hologram       = CF(-2.8, 0.35, 0.0) * CFA(0, 0.3, 0),

	-- Orb orbit center (near left hand palm, above it)
	OrbCenter      = CF(-2.0, -1.8, 0.2),  -- base pivot; animated offset applied on top

	-- Counter (to the right of NPC, character's right is +X)
	CounterBody    = CF( 3.8,  -1.5, 0.3),
	CounterTop     = CF( 3.8,  -0.08,0.3),
	CounterStrip1  = CF( 3.8,  -0.9, -0.82),
	CounterStrip2  = CF( 3.8,  -1.4, -0.82),
	CounterStrip3  = CF( 3.8,  -1.9, -0.82),
	CounterDisplay = CF( 3.8,  -0.6, -0.86),

	-- Neon boxes (behind NPC, +Z direction)
	NeonBox1       = CF( 2.4,  -2.5,  2.2),
	NeonBox2       = CF( 2.4,  -0.55, 2.2),
}

-- ============================================================
-- ANIMATION PARAMETERS
-- ============================================================
MerchantConfig.Anim = {
	-- Orb
	OrbOrbitSpeed    = 1.2,    -- rad/s
	OrbOrbitRadius   = 0.55,   -- studs from orbit center
	OrbBobSpeed      = 1.8,    -- rad/s (vertical sine wave)
	OrbBobAmplitude  = 0.25,   -- studs
	OrbTiltAngle     = 0.3,    -- radians

	-- Hologram flicker
	HoloFlickerMin   = 0.35,   -- min transparency
	HoloFlickerMax   = 0.72,   -- max transparency
	HoloFlickerSpeed = 3.2,    -- cycles/sec (irregular effect)

	-- Neon pulse (all neon-material parts)
	NeonPulseSpeed   = 0.9,    -- slow breathing
	NeonPulseMin     = 0.0,    -- no transparency at brightest
	NeonPulseMax     = 0.25,   -- slightly dimmer at lowest

	-- Idle body sway
	SwayAmplitude    = 0.04,   -- studs
	SwaySpeed        = 0.55,   -- rad/s

	-- Proximity wink distance
	WinkDistance     = 14,     -- studs

	-- Portrait flip
	PortraitWinkInterval = 5,  -- seconds between winks
	PortraitWinkDuration = 0.3,-- seconds wink stays closed
}

-- ============================================================
-- PORTRAIT VIEWPORT CONFIG
-- ============================================================
MerchantConfig.Portrait = {
	Size     = UDim2.new(0, 180, 0, 220),
	Position = UDim2.new(0, 16, 0.5, -260),  -- Left of trade panel
	CamOffset= CFrame.new(0, 1.8, 5) * CFrame.Angles(0, math.pi, 0),  -- Look at face
}

return MerchantConfig
