-- Config.lua | Anime Arena: Blitz Mode | Shared config

local Config = {}

Config.VERSION = "0.1.0-alpha"
Config.GAME_NAME = "Anime Arena: Blitz Mode"

Config.MODES = {
	NORMAL     = "Normal",   -- BUG-1 FIX: дефолтный режим для RoundService/TestBot
	BLITZ      = "Blitz",
	RANKED     = "Ranked",
	ONE_HIT    = "OneHit",
	TOURNAMENT = "Tournament",
	CASUAL     = "Casual",
}

Config.ROUND_DURATION = {
	Normal     = 180,  -- BUG-1 FIX: дефолт RoundService.StartRound и TestBot
	Blitz      = 180,
	Ranked     = 180,
	OneHit     = 90,
	Tournament = 180,
	Casual     = 180,
}

Config.MATCH_RANKS = {"E", "D", "C", "B", "A", "S", "SS", "SSS"}

Config.CAREER_RANKS = {
	{name = "Iron",     min = 0,    max = 999},
	{name = "Bronze",   min = 1000, max = 1499},
	{name = "Silver",   min = 1500, max = 1999},
	{name = "Gold",     min = 2000, max = 2499},
	{name = "Platinum", min = 2500, max = 2999},
	{name = "Diamond",  min = 3000, max = 3999},
	{name = "Legend",   min = 4000, max = math.huge},
}

Config.REWARDS = {
	WIN_COINS       = 50,
	LOSE_COINS      = 0,    -- FIX: 0 за поражение — не даём монеты проигравшему
	SS_BONUS        = 30,
	S_BONUS         = 20,
	A_BONUS         = 10,
	WIN_RATING      = 25,
	LOSE_RATING     = -15,  -- FIX: отнимаем RP за поражение
	MVP_BONUS_RP    = 10,
	MVP_BONUS_COINS = 20,
	-- FIX: минимальный урон для ревард — игрок должен нанести хоть что-то
	MIN_DAMAGE_FOR_LOSE_RP = 1,  -- если 0 урона — -15 RP без бонусов
}

Config.HEROES = {
	"FlameRonin",   "VoidAssassin",  "ThunderMonk",
	"IronTitan",    "ScarletArcher", "EclipseHero",
	"StormDancer",  "BloodSage",     "CrystalGuard",
	"ShadowTwin",   "NeonBlitz",     "JadeSentinel",
}

Config.HERO_RARITY = {
	FlameRonin    = "Common",
	StormDancer   = "Common",
	ThunderMonk   = "Rare",
	ScarletArcher = "Rare",
	IronTitan     = "Rare",
	CrystalGuard  = "Rare",
	JadeSentinel  = "Rare",
	ShadowTwin    = "Epic",
	NeonBlitz     = "Epic",
	VoidAssassin  = "Legendary",
	BloodSage     = "Legendary",
	EclipseHero   = "Legendary",
}

return Config
