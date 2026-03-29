-- ArenaMasterConfig.lua | Anime Arena: Blitz
-- Shared configuration for "The Stoic Sensei" Arena Master NPC.
-- Used by: ArenaMasterNPCBuilder (server), ArenaMasterVFX (client).

local ArenaMasterConfig = {}

-- ============================================================
-- IDENTITY
-- ============================================================
ArenaMasterConfig.NPC_MODEL_NAME = "ArenasMaster"

-- ============================================================
-- COLOR PALETTE
-- ============================================================
local C = Color3.fromRGB

ArenaMasterConfig.Colors = {
	-- Body
	Skin           = C(184, 143, 112),
	SkinShade      = C(158, 117, 87),

	-- Hair
	HairBlack      = C(13, 13, 20),
	HairGrey       = C(102, 102, 107),

	-- Kimono / Dogi
	Dogi           = C(10, 10, 31),
	DogiWorn       = C(15, 15, 36),

	-- Obsidian Armor
	Obsidian       = C(5, 5, 8),

	-- Obi Belt
	ObiBelt        = C(5, 5, 5),

	-- Gold (kanji, embroidery)
	Gold           = C(217, 166, 33),
	GoldGlow       = C(217, 166, 33),     -- Neon material

	-- Red FX
	RedGlow        = C(204, 13, 13),       -- Neon material (eyes, sword aura)
	RedAura        = C(153, 5, 5),         -- ParticleEmitter tint

	-- Scar
	Scar           = C(140, 97, 82),

	-- Hakama
	Hakama         = C(8, 8, 15),

	-- Haori
	Haori          = C(13, 13, 26),

	-- Metal (bracers)
	DarkMetal      = C(20, 20, 26),
	MetalSpike     = C(31, 31, 36),

	-- Feet
	Waraji         = C(46, 31, 15),
	Tabi           = C(230, 224, 217),
	MetalSole      = C(20, 20, 26),

	-- Sword
	Sheath         = C(8, 8, 10),
	SwordWrap      = C(38, 5, 5),
	Tsuba          = C(26, 20, 5),

	-- Face
	EyeWhite       = C(242, 242, 242),
	EyeIris        = C(38, 31, 26),
	Mouth          = C(115, 56, 46),

	-- Rank plate
	RankPlate      = C(31, 26, 15),

	-- Lightning symbol
	Lightning      = C(242, 217, 51),      -- Neon material
}

-- ============================================================
-- PART SIZES (studs: Width, Height, Depth)
-- ============================================================
local V3 = Vector3.new

ArenaMasterConfig.Sizes = {
	HRP            = V3(2, 2, 1),

	Head           = V3(1.8, 1.8, 1.7),
	Neck           = V3(0.45, 0.35, 0.45),

	-- Torso
	UpperTorso     = V3(2.8, 1.5, 1.5),
	LowerTorso     = V3(2.2, 0.7, 1.3),

	-- Kimono collar
	Collar         = V3(0.5, 1.0, 0.1),

	-- Pauldron
	Pauldron       = V3(0.7, 0.45, 1.1),
	PauldronEdge   = V3(0.5, 0.12, 0.25),
	PauldronGlow   = V3(0.55, 0.35, 0.04),

	-- Obi
	Obi            = V3(2.3, 0.45, 1.4),
	ObiKnot        = V3(0.5, 0.4, 0.35),
	ObiKanji       = V3(0.08, 0.3, 0.04),

	-- Rank plate
	RankPlate      = V3(0.4, 0.55, 0.08),
	SSSMark        = V3(0.04, 0.35, 0.04),

	-- Arms
	UpperArm       = V3(0.65, 0.9, 0.6),
	Forearm        = V3(0.6, 0.8, 0.55),
	Hand           = V3(0.35, 0.25, 0.35),

	-- Bracer
	Bracer         = V3(0.7, 0.5, 0.65),
	Spike          = V3(0.08, 0.08, 0.2),

	-- Legs
	Thigh          = V3(0.9, 1.0, 0.85),
	Shin           = V3(0.8, 1.1, 0.75),

	-- Feet
	Tabi           = V3(0.55, 0.25, 0.65),
	Waraji         = V3(0.6, 0.12, 0.75),
	MetalSole      = V3(0.62, 0.06, 0.78),

	-- Sword
	Sheath         = V3(0.18, 2.2, 0.18),
	SheathTip      = V3(0.2, 0.12, 0.2),
	Tsuba          = V3(0.25, 0.06, 0.25),
	Handle         = V3(0.14, 0.55, 0.14),
	HandleWrap     = V3(0.16, 0.06, 0.04),
	Pommel         = V3(0.16, 0.08, 0.16),
	SwordAura      = V3(0.35, 2.3, 0.35),

	-- Hair
	HairMain       = V3(1.85, 0.5, 1.75),
	HairSpike      = V3(0.35, 0.25, 0.5),
	HairSide       = V3(0.25, 0.8, 1.3),
	HairBack       = V3(1.6, 0.9, 0.3),
	Temple         = V3(0.22, 0.45, 0.55),
	GreyStreak     = V3(0.2, 0.15, 0.3),

	-- Face
	Eye            = V3(0.38, 0.18, 0.08),
	EyeIris        = V3(0.2, 0.16, 0.04),
	Eyebrow        = V3(0.45, 0.08, 0.1),
	Mouth          = V3(0.35, 0.06, 0.06),
	Nose           = V3(0.18, 0.22, 0.12),
	Scar           = V3(0.06, 0.5, 0.06),
	Wrinkle        = V3(0.6, 0.03, 0.04),
	EyeGlow        = V3(0.42, 0.22, 0.12),

	-- Haori
	HaoriBack      = V3(2.9, 2.5, 0.2),
	HaoriSide      = V3(0.5, 2.0, 0.8),
	HaoriCollar    = V3(0.3, 0.5, 0.7),

	-- Kanji strokes
	KanjiH         = V3(0.7, 0.06, 0.04),
	KanjiV         = V3(0.06, 0.35, 0.04),
	KanjiDot       = V3(0.08, 0.08, 0.04),
	LightningBolt  = V3(0.15, 0.12, 0.04),

	-- Red aura particles
	RedKanji       = V3(0.15, 0.18, 0.02),
	-- BUG-3.3 FIX: Увеличена высота ауры с 0.15 до 1.2 стадов.
	-- Старое значение давало плоский диск; теперь — объёмное облако.
	RedMistBase    = V3(4.0, 1.2, 4.0),
}

-- ============================================================
-- OFFSETS relative to HRP CFrame
-- HRP is at hip level. X=right, Y=up, Z=forward(-face).
-- Character faces -Z (toward players).
-- ============================================================
local CF  = CFrame.new
local CFA = CFrame.Angles
local PI  = math.pi

ArenaMasterConfig.Offsets = {
	-- Body
	Head           = CF(0, 3.1, 0),
	Neck           = CF(0, 2.05, 0),
	UpperTorso     = CF(0, 1.3, 0),
	LowerTorso     = CF(0, 0.4, 0),

	-- Kimono collar V-shape
	CollarR        = CF(0.35, 1.65, -0.78) * CFA(0, 0, 0.2),
	CollarL        = CF(-0.35, 1.65, -0.78) * CFA(0, 0, -0.2),
	InnerShirt     = CF(0, 1.5, -0.75),

	-- Pauldrons
	PauldronR      = CF(1.55, 1.95, 0) * CFA(0, 0, -0.2),
	PauldronREdge  = CF(1.7, 2.05, -0.35) * CFA(0, 0, -0.3),
	PauldronRGlow  = CF(1.55, 1.95, -0.52),
	PauldronL      = CF(-1.55, 1.95, 0) * CFA(0, 0, 0.2),
	PauldronLEdge  = CF(-1.7, 2.05, -0.35) * CFA(0, 0, 0.3),
	PauldronLGlow  = CF(-1.55, 1.95, -0.52),

	-- Obi Belt
	Obi            = CF(0, 0.05, 0),
	ObiKnot        = CF(0, 0.05, 0.75),
	RankPlate      = CF(0.6, -0.4, -0.75) * CFA(0.05, 0, 0.05),

	-- Arms (crossed pose)
	RUpperArm      = CF(1.55, 1.35, 0),
	RForearm       = CF(0.7, 1.0, -0.5) * CFA(0, 0, 0.7),
	RHand          = CF(0.0, 0.75, -0.55),
	LUpperArm      = CF(-1.55, 1.35, 0),
	LForearm       = CF(-0.7, 0.8, -0.55) * CFA(0, 0, -0.7),
	LHand          = CF(0.0, 0.55, -0.6),

	-- Bracers
	BracerR        = CF(0.85, 1.05, -0.45) * CFA(0, 0, 0.7),
	BracerL        = CF(-0.85, 0.85, -0.5) * CFA(0, 0, -0.7),

	-- Legs (feet on ground)
	RThigh         = CF(0.55, -0.7, 0),
	RShin          = CF(0.55, -1.8, 0),
	RFoot          = CF(0.55, -2.35, -0.05),
	LThigh         = CF(-0.55, -0.7, 0),
	LShin          = CF(-0.55, -1.8, 0),
	LFoot          = CF(-0.55, -2.35, -0.05),

	-- Hair
	HairMain       = CF(0, 4.05, 0.05),
	HairSpikeA     = CF(0.3, 4.15, -0.5) * CFA(0.25, 0.1, 0),
	HairSpikeB     = CF(-0.2, 4.1, -0.55) * CFA(0.3, -0.1, 0),
	HairSpikeC     = CF(0.5, 4.05, -0.3) * CFA(0.15, 0.15, 0.1),
	HairSideR      = CF(0.85, 3.4, 0),
	HairSideL      = CF(-0.85, 3.4, 0),
	HairBack       = CF(0, 3.4, 0.7),
	TempleR        = CF(0.82, 3.2, -0.25),
	TempleL        = CF(-0.82, 3.2, -0.25),
	GreyStreakA     = CF(0.55, 4.0, 0.15),
	GreyStreakB     = CF(-0.4, 4.05, 0.2),

	-- Face
	EyeR           = CF(0.38, 3.2, -0.82),
	EyeL           = CF(-0.38, 3.2, -0.82),
	IrisR          = CF(0.35, 3.18, -0.87),
	IrisL          = CF(-0.35, 3.18, -0.87),
	EyeGlowR       = CF(0.38, 3.2, -0.85),
	EyeGlowL       = CF(-0.38, 3.2, -0.85),
	BrowR          = CF(0.38, 3.38, -0.83) * CFA(0, 0, -0.12),
	BrowL          = CF(-0.38, 3.38, -0.83) * CFA(0, 0, 0.12),
	Scar           = CF(0.38, 3.32, -0.88) * CFA(0.3, 0.15, 0),
	Mouth          = CF(0, 2.78, -0.83),
	Nose           = CF(0, 2.98, -0.88),
	Wrinkle1       = CF(0, 3.5, -0.84),
	Wrinkle2       = CF(0, 3.58, -0.84),

	-- Ears
	EarR           = CF(0.95, 2.95, -0.05),
	EarL           = CF(-0.95, 2.95, -0.05),

	-- Haori
	HaoriBack      = CF(0, 1.0, 0.55) * CFA(0.05, 0, 0),
	HaoriSideR     = CF(1.45, 1.2, 0.3),
	HaoriSideL     = CF(-1.45, 1.2, 0.3),
	HaoriCollarR   = CF(0.4, 2.0, -0.4) * CFA(0, 0, 0.15),
	HaoriCollarL   = CF(-0.4, 2.0, -0.4) * CFA(0, 0, -0.15),

	-- Kanji on back (電光)
	KanjiBackBase  = CF(0, 1.4, 0.76),

	-- Sword
	NodachiSheath  = CF(-0.95, -0.5, 0.2) * CFA(0.15, 0.1, -0.15),
	SheathTip      = CF(-1.05, -1.65, 0.28) * CFA(0.15, 0.1, -0.15),
	Tsuba          = CF(-0.85, 0.55, 0.12) * CFA(0.15, 0.1, -0.15),
	Handle         = CF(-0.8, 0.85, 0.08) * CFA(0.15, 0.1, -0.15),
	Pommel         = CF(-0.75, 1.1, 0.04),
	SwordAura      = CF(-0.95, -0.5, 0.2) * CFA(0.15, 0.1, -0.15),

	-- Red mist at feet
	RedMistBase    = CF(0, -2.4, 0),
}

-- ============================================================
-- ANIMATION PARAMETERS
-- ============================================================
ArenaMasterConfig.Anim = {
	-- Sword aura pulse
	SwordAuraPulseSpeed  = 0.6,     -- rad/s breathing
	SwordAuraPulseMin    = 0.55,    -- min transparency
	SwordAuraPulseMax    = 0.85,    -- max transparency

	-- Red eye glow activation
	EyeGlowIdleDelay    = 5.0,      -- seconds of player proximity before glow starts
	EyeGlowFadeIn       = 1.5,      -- seconds to fade in
	EyeGlowFadeOut      = 2.0,      -- seconds to fade out
	EyeGlowMaxBrightness = 6.0,

	-- Floating red kanji particles
	KanjiOrbitSpeed      = 0.15,    -- rad/s (slow)
	KanjiFloatSpeed      = 0.4,     -- vertical sine speed
	KanjiFloatAmplitude  = 0.3,     -- studs
	KanjiCount           = 8,

	-- Red mist / aura
	AuraPulseSpeed       = 0.3,     -- rad/s
	AuraPulseMin         = 0.75,    -- transparency
	AuraPulseMax         = 0.92,
	AuraBreathFlare      = 0.15,    -- extra brightness on "exhale"
	AuraBreathCycle      = 4.0,     -- seconds per breath

	-- Idle body micro-motion (server-side)
	BreathSwaySpeed      = 0.4,     -- rad/s for chest sway
	BreathSwayAmplitude  = 0.008,   -- studs (very subtle)

	-- Proximity prompt
	PromptDistance       = 8,        -- studs
}

return ArenaMasterConfig
