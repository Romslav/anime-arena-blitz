-- Characters.lua | Anime Arena: Blitz Mode
-- All 12 heroes: full stats, skills, ultimate, passive, rarity
-- Single source of truth shared by server and client

local Characters = {}

-- ============================================================
-- 1. FLAME RONIN | Bruiser | Common
-- ============================================================
Characters.FlameRonin = {
	id = "FlameRonin", name = "Flame Ronin", role = "Bruiser",
	hp = 120, m1Damage = 8, speed = 16,
	skills = {
		{name="Flame Dash",   damage=8,  cooldown=6,  type="Dash",    anim="rbxassetid://0"},
		{name="Rising Slash", damage=10, cooldown=8,  type="Launch",  anim="rbxassetid://0"},
		{name="Burn Guard",   damage=0,  cooldown=10, type="Defense", anim="rbxassetid://0"},
	},
	ultimate = {name="Phoenix Cut",       damage=34, cooldown=50, anim="rbxassetid://0"},
	passive  = "Burns enemy on M1 combo finisher",
	rarity   = "Common",
}

-- ============================================================
-- 2. VOID ASSASSIN | Assassin | Legendary
-- ============================================================
Characters.VoidAssassin = {
	id = "VoidAssassin", name = "Void Assassin", role = "Assassin",
	hp = 95, m1Damage = 6, speed = 20,
	skills = {
		{name="Blink Strike",  damage=9,  cooldown=7,  type="Teleport", anim="rbxassetid://0"},
		{name="Shadow Feint",  damage=0,  cooldown=8,  type="Feint",    anim="rbxassetid://0"},
		{name="Backstab Mark", damage=14, cooldown=10, type="Burst",    anim="rbxassetid://0"},
	},
	ultimate = {name="Silent Execution",  damage=40, cooldown=55, anim="rbxassetid://0"},
	passive  = "Backstab +50% damage if enemy HP < 30%",
	rarity   = "Legendary",
}

-- ============================================================
-- 3. THUNDER MONK | Controller | Rare
-- ============================================================
Characters.ThunderMonk = {
	id = "ThunderMonk", name = "Thunder Monk", role = "Controller",
	hp = 110, m1Damage = 7, speed = 17,
	skills = {
		{name="Lightning Palm", damage=9, cooldown=6,  stun=0.4, type="Stun", anim="rbxassetid://0"},
		{name="Stun Ring",      damage=4, cooldown=12, stun=0.6, type="AoE",  anim="rbxassetid://0"},
		{name="Step Dash",      damage=0, cooldown=5,            type="Dodge",anim="rbxassetid://0"},
	},
	ultimate = {name="Heavenly Judgment", damage=30, cooldown=60, anim="rbxassetid://0"},
	passive  = "Every 3rd M1 adds lightning charge",
	rarity   = "Rare",
}

-- ============================================================
-- 4. IRON TITAN | Tank | Rare
-- ============================================================
Characters.IronTitan = {
	id = "IronTitan", name = "Iron Titan", role = "Tank",
	hp = 260, m1Damage = 15, speed = 12,
	skills = {
		{name="Iron Slam",    damage=12, cooldown=8,  type="AoE",     anim="rbxassetid://0"},
		{name="Shield Wall",  damage=0,  cooldown=12, type="Defense", anim="rbxassetid://0"},
		{name="Ground Quake", damage=18, cooldown=15, type="AoE",     anim="rbxassetid://0"},
	},
	ultimate = {name="Titan Fall",        damage=45, cooldown=70, anim="rbxassetid://0"},
	passive  = "Blocks 15% damage from front",
	rarity   = "Rare",
}

-- ============================================================
-- 5. SCARLET ARCHER | Ranged | Rare
-- ============================================================
Characters.ScarletArcher = {
	id = "ScarletArcher", name = "Scarlet Archer", role = "Ranged",
	hp = 140, m1Damage = 24, speed = 15,
	skills = {
		{name="Arrow Rain",    damage=14, cooldown=9, type="AoE",    anim="rbxassetid://0"},
		{name="Piercing Shot", damage=20, cooldown=8, type="Linear", anim="rbxassetid://0"},
		{name="Evasion Roll",  damage=0,  cooldown=7, type="Dodge",  anim="rbxassetid://0"},
	},
	ultimate = {name="Storm of Arrows",   damage=38, cooldown=55, anim="rbxassetid://0"},
	passive  = "Headshots deal +30% damage",
	rarity   = "Rare",
}

-- ============================================================
-- 6. ECLIPSE HERO | Assassin | Legendary
-- ============================================================
Characters.EclipseHero = {
	id = "EclipseHero", name = "Eclipse Hero", role = "Assassin",
	hp = 150, m1Damage = 26, speed = 18,
	skills = {
		{name="Eclipse Slash", damage=15, cooldown=7,  type="Burst",    anim="rbxassetid://0"},
		{name="Lunar Phase",   damage=10, cooldown=9,  type="Teleport", anim="rbxassetid://0"},
		{name="Dark Veil",     damage=0,  cooldown=12, type="Stealth",  anim="rbxassetid://0"},
	},
	ultimate = {name="Total Eclipse",     damage=44, cooldown=60, anim="rbxassetid://0"},
	passive  = "Crit chance +25% from behind",
	rarity   = "Legendary",
}

-- ============================================================
-- 7. STORM DANCER | Skirmisher | Common
-- ============================================================
Characters.StormDancer = {
	id = "StormDancer", name = "Storm Dancer", role = "Skirmisher",
	hp = 145, m1Damage = 23, speed = 19,
	skills = {
		{name="Tempest Step", damage=8,  cooldown=6,  type="Dash",  anim="rbxassetid://0"},
		{name="Wind Spiral",  damage=12, cooldown=8,  type="AoE",   anim="rbxassetid://0"},
		{name="Gale Parry",   damage=0,  cooldown=10, type="Parry", anim="rbxassetid://0"},
	},
	ultimate = {name="Cyclone Fury",      damage=36, cooldown=55, anim="rbxassetid://0"},
	passive  = "Hits build Storm stacks for speed boost",
	rarity   = "Common",
}

-- ============================================================
-- 8. BLOOD SAGE | Mage | Legendary
-- ============================================================
Characters.BloodSage = {
	id = "BloodSage", name = "Blood Sage", role = "Mage",
	hp = 120, m1Damage = 30, speed = 14,
	skills = {
		{name="Bloodbolt",     damage=18, cooldown=7,  type="Projectile", anim="rbxassetid://0"},
		{name="Crimson Bind",  damage=6,  cooldown=10, type="Root",       anim="rbxassetid://0"},
		{name="Sanguine Burst",damage=22, cooldown=14, type="AoE",        anim="rbxassetid://0"},
	},
	ultimate = {name="Blood Moon",        damage=50, cooldown=65, anim="rbxassetid://0"},
	passive  = "Drains 5HP per hit",
	rarity   = "Legendary",
}

-- ============================================================
-- 9. CRYSTAL GUARD | Tank | Rare
-- ============================================================
Characters.CrystalGuard = {
	id = "CrystalGuard", name = "Crystal Guard", role = "Tank",
	hp = 240, m1Damage = 14, speed = 13,
	skills = {
		{name="Crystal Spike", damage=10, cooldown=7,  type="AoE",    anim="rbxassetid://0"},
		{name="Prism Barrier", damage=0,  cooldown=12, type="Shield", anim="rbxassetid://0"},
		{name="Shatter Rush",  damage=16, cooldown=10, type="Dash",   anim="rbxassetid://0"},
	},
	ultimate = {name="Crystal Fortress", damage=30, cooldown=70, anim="rbxassetid://0"},
	passive  = "Crystal shards reduce incoming damage",
	rarity   = "Rare",
}

-- ============================================================
-- 10. SHADOW TWIN | Support | Epic
-- ============================================================
Characters.ShadowTwin = {
	id = "ShadowTwin", name = "Shadow Twin", role = "Support",
	hp = 155, m1Damage = 25, speed = 17,
	skills = {
		{name="Twin Lash",    damage=12, cooldown=6,  type="Burst",    anim="rbxassetid://0"},
		{name="Shadow Clone", damage=0,  cooldown=15, type="Clone",    anim="rbxassetid://0"},
		{name="Mist Step",    damage=0,  cooldown=8,  type="Teleport", anim="rbxassetid://0"},
	},
	ultimate = {name="Dark Mirror",      damage=35, cooldown=60, anim="rbxassetid://0"},
	passive  = "Clone deals 50% damage",
	rarity   = "Epic",
}

-- ============================================================
-- 11. NEON BLITZ | Ranged | Epic
-- ============================================================
Characters.NeonBlitz = {
	id = "NeonBlitz", name = "Neon Blitz", role = "Ranged",
	hp = 135, m1Damage = 27, speed = 16,
	skills = {
		{name="Neon Burst",   damage=16, cooldown=7,  type="Projectile", anim="rbxassetid://0"},
		{name="Circuit Dash", damage=0,  cooldown=6,  type="Dash",       anim="rbxassetid://0"},
		{name="Overload",     damage=20, cooldown=12, type="AoE",        anim="rbxassetid://0"},
	},
	ultimate = {name="Neon Overdrive",   damage=42, cooldown=58, anim="rbxassetid://0"},
	passive  = "Every 4th hit fires a neon pulse",
	rarity   = "Epic",
}

-- ============================================================
-- 12. JADE SENTINEL | Duelist | Rare
-- ============================================================
Characters.JadeSentinel = {
	id = "JadeSentinel", name = "Jade Sentinel", role = "Duelist",
	hp = 200, m1Damage = 18, speed = 15,
	skills = {
		{name="Jade Strike",   damage=14, cooldown=7,  type="Burst", anim="rbxassetid://0"},
		{name="Sentinel Step", damage=0,  cooldown=6,  type="Dodge", anim="rbxassetid://0"},
		{name="Earthen Crush", damage=18, cooldown=11, type="AoE",   anim="rbxassetid://0"},
	},
	ultimate = {name="Jade Wrath",        damage=38, cooldown=60, anim="rbxassetid://0"},
	passive  = "Perfect parry resets a skill cooldown",
	rarity   = "Rare",
}

return Characters
