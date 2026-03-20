-- Config.lua | Anime Arena: Blitz Mode | Shared config

local Config = {}

Config.VERSION = "0.1.0-alpha"
Config.GAME_NAME = "Anime Arena: Blitz Mode"

Config.MODES = {
    BLITZ      = "Blitz",
    RANKED     = "Ranked",
    ONE_HIT    = "OneHit",
    TOURNAMENT = "Tournament",
    CASUAL     = "Casual",
}

Config.ROUND_DURATION = {
    Blitz      = 180,
    Ranked     = 180,
    OneHit     = 90,
    Tournament = 180,
    Casual     = 180,
}

Config.MATCH_RANKS = {"E", "D", "C", "B", "A", "S", "SS"}

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
    WIN_COINS   = 50,
    LOSE_COINS  = 15,
    SS_BONUS    = 30,
    S_BONUS     = 20,
    A_BONUS     = 10,
    WIN_RATING  = 25,
    LOSE_RATING = -15,
}

Config.HEROES = {
    "FlameRonin", "VoidAssassin", "ThunderMonk",
    "IronTitan", "ScarletArcher", "EclipseHero",
    "FrostDuelist", "StarBlade", "SerpentPriest",
    "StoneColossus", "WindStriker", "NovaEmperor",
}

Config.HERO_RARITY = {
    FlameRonin    = "Common",
    FrostDuelist  = "Common",
    ThunderMonk   = "Rare",
    WindStriker   = "Rare",
    ScarletArcher = "Rare",
    IronTitan     = "Epic",
    SerpentPriest = "Epic",
    StarBlade     = "Epic",
    VoidAssassin  = "Legendary",
    StoneColossus = "Legendary",
    EclipseHero   = "Mythic",
    NovaEmperor   = "Mythic",
}

return Config
