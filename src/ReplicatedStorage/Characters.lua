-- Characters.lua | Anime Arena: Blitz Mode
-- All 12 heroes: stats, skills, balance data

local Characters = {}

Characters.FlameRonin = {
    name = "Flame Ronin", role = "Bruiser",
    hp = 120, m1Damage = 8, speed = 16,
    skills = {
        {name="Flame Dash",   damage=8,  cooldown=6,  type="Dash"},
        {name="Rising Slash", damage=10, cooldown=8,  type="Launch"},
        {name="Burn Guard",   damage=0,  cooldown=10, type="Defense"},
    },
    ultimate = {name="Phoenix Cut", damage=34, cooldown=50},
    passive = "Burns enemy on M1 combo finisher",
    rarity = "Common",
}

Characters.VoidAssassin = {
    name = "Void Assassin", role = "Assassin",
    hp = 95, m1Damage = 6, speed = 20,
    skills = {
        {name="Blink Strike",  damage=9,  cooldown=7,  type="Teleport"},
        {name="Shadow Feint",  damage=0,  cooldown=8,  type="Feint"},
        {name="Backstab Mark", damage=14, cooldown=10, type="Burst"},
    },
    ultimate = {name="Silent Execution", damage=40, cooldown=55},
    passive = "Backstab +50% damage if enemy HP < 30%",
    rarity = "Legendary",
}

Characters.ThunderMonk = {
    name = "Thunder Monk", role = "Controller",
    hp = 110, m1Damage = 7, speed = 17,
    skills = {
        {name="Lightning Palm", damage=9, cooldown=6,  stun=0.4, type="Stun"},
        {name="Stun Ring",      damage=4, cooldown=12, stun=0.6, type="AoE"},
        {name="Step Dash",      damage=0, cooldown=5,  type="Dodge"},
    },
    ultimate = {name="Heavenly Judgment", damage=30, cooldown=60},
    passive = "Every 3rd M1 adds lightning charge",
    rarity = "Rare",
}

Characters.IronTitan = {
    name = "Iron Titan", role = "Tank",
    hp = 140, m1Damage = 6, speed = 14,
    skills = {
        {name="Guard Wall",  damage=0,  cooldown=10, type="Shield"},
        {name="Body Slam",   damage=11, cooldown=9,  type="Slam"},
        {name="Taunt Pulse", damage=0,  cooldown=11, type="Debuff"},
    },
    ultimate = {name="Fortress Break", damage=32, cooldown=60},
    passive = "Reflects 15% damage while Guard Wall active",
    rarity = "Epic",
}

Characters.ScarletArcher = {
    name = "Scarlet Archer", role = "Ranged",
    hp = 100, m1Damage = 5, speed = 16,
    skills = {
        {name="Piercing Shot", damage=10, cooldown=6,  type="Projectile"},
        {name="Trap Arrow",    damage=6,  cooldown=10, type="Trap"},
        {name="Quick Step",    damage=0,  cooldown=5,  type="Dodge"},
    },
    ultimate = {name="Crimson Rain", damage=38, cooldown=55},
    passive = "Piercing Shot ignores shields",
    rarity = "Rare",
}

Characters.EclipseHero = {
    name = "Eclipse Hero", role = "ModeHero",
    hp = 115, m1Damage = 7, speed = 16,
    skills = {
        {name="Charge Mode",  damage=0,  cooldown=8,  type="Charge"},
        {name="Dark Slash",   damage=11, cooldown=7,  type="Slash"},
        {name="Drain Strike", damage=8,  cooldown=11, type="Lifesteal"},
    },
    ultimate = {name="Eclipse Ascension", damage=42, cooldown=65},
    passive = "+5% damage per 30 sec in match",
    rarity = "Mythic",
}

Characters.FrostDuelist = {
    name = "Frost Duelist", role = "Bruiser",
    hp = 118, m1Damage = 8, speed = 15,
    skills = {
        {name="Ice Cut",       damage=9, cooldown=6,  slow=0.3, type="Slow"},
        {name="Freeze Dash",   damage=7, cooldown=9,  type="Dash"},
        {name="Shatter Guard", damage=0, cooldown=10, type="Parry"},
    },
    ultimate = {name="Absolute Zero", damage=33, cooldown=55},
    passive = "Parry window +20% on Shatter Guard",
    rarity = "Common",
}

Characters.StarBlade = {
    name = "Star Blade", role = "Assassin",
    hp = 96, m1Damage = 6, speed = 21,
    skills = {
        {name="Star Blink",  damage=8,  cooldown=6, type="Blink"},
        {name="Triple Stab", damage=12, cooldown=9, type="Burst"},
        {name="Vanish Step", damage=0,  cooldown=7, type="Vanish"},
    },
    ultimate = {name="Cosmic Sever", damage=41, cooldown=58},
    passive = "Triple Stab crits if all 3 hits land",
    rarity = "Epic",
}

Characters.SerpentPriest = {
    name = "Serpent Priest", role = "Controller",
    hp = 108, m1Damage = 6, speed = 15,
    skills = {
        {name="Poison Seal",  damage=4, cooldown=8,  dot=2,   type="Poison"},
        {name="Serpent Bind", damage=0, cooldown=11, stun=0.7, type="Root"},
        {name="Curse Wave",   damage=7, cooldown=10, type="Debuff"},
    },
    ultimate = {name="Venom Shrine", damage=36, cooldown=60},
    passive = "Poisons stack up to 3x",
    rarity = "Epic",
}

Characters.StoneColossus = {
    name = "Stone Colossus", role = "Tank",
    hp = 138, m1Damage = 7, speed = 13,
    skills = {
        {name="Earth Guard", damage=0,  cooldown=9, type="Guard"},
        {name="Quake Punch", damage=10, cooldown=8, type="AoE"},
        {name="Rock Shift",  damage=0,  cooldown=6, type="Dash"},
    },
    ultimate = {name="World Ender", damage=35, cooldown=62},
    passive = "Immune to knockback while Earth Guard active",
    rarity = "Legendary",
}

Characters.WindStriker = {
    name = "Wind Striker", role = "Ranged",
    hp = 102, m1Damage = 5, speed = 19,
    skills = {
        {name="Wind Shot",    damage=9, cooldown=6, type="Projectile"},
        {name="Aerial Reset", damage=0, cooldown=8, type="Jump"},
        {name="Gust Step",    damage=0, cooldown=5, type="Dash"},
    },
    ultimate = {name="Tempest Spiral", damage=37, cooldown=58},
    passive = "Wind Shot knocks back on crit",
    rarity = "Rare",
}

Characters.NovaEmperor = {
    name = "Nova Emperor", role = "ModeHero",
    hp = 112, m1Damage = 7, speed = 17,
    skills = {
        {name="Solar Charge",  damage=0,  cooldown=8,  type="Charge"},
        {name="Flare Dash",    damage=10, cooldown=7,  type="Dash"},
        {name="Radiant Burst", damage=12, cooldown=10, type="Burst"},
    },
    ultimate = {name="Supernova Crown", damage=45, cooldown=70},
    passive = "Solar stacks boost all skill damage",
    rarity = "Mythic",
}

return Characters
