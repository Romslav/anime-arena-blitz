-- Remotes.lua | Anime Arena: Blitz Mode
-- List of all RemoteEvent and RemoteFunction names

local Remotes = {}

Remotes.EVENTS = {
    "RoundStart",        -- server -> client
    "RoundEnd",          -- server -> client: results + rank
    "RoundTimer",        -- server -> client: timer update
    "SelectHero",        -- client -> server: hero selection
    "HeroSelected",      -- server -> client: confirm
    "UseSkill",          -- client -> server: skill input
    "SkillUsed",         -- server -> client: skill animation
    "TakeDamage",        -- server -> client: damage taken
    "PlayerDied",        -- server -> client: death event
    "UltCharge",         -- server -> client: ult meter update
    "UpdateStats",       -- server -> client: match stats
    "MatchRank",         -- server -> client: post-match rank
    "ShowNotification",  -- server -> client: UI notification
}

Remotes.FUNCTIONS = {
    "GetPlayerData",
    "GetLeaderboard",
}

return Remotes
