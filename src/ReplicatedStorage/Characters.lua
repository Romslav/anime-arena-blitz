-- Characters.lua | Anime Arena: Blitz Mode
-- All 12 heroes: stats, skills, balance data

local Characters = {}

Characters.FlameRonin = {
	id = "FlameRonin",
	name = "Flame Ronin", role = "Bruiser",
	hp = 120, m1Damage = 8, speed = 16,
	skills = {
		{name="Flame Dash", damage=8, cooldown=6, type="Dash", anim="rbxassetid://0"},
		{name="Rising Slash", damage=10, cooldown=8, type="Launch", anim="rbxassetid://0"},
		{name="Burn Guard", damage=0, cooldown=10, type="Defense", anim="rbxassetid://0"},
	},
	ultimate = {name="Phoenix Cut", damage=34, cooldown=50, anim="rbxassetid://0"},
	passive = "Burns enemy on M1 combo finisher",
	rarity = "Common",
}

Characters.VoidAssassin = {
	id = "VoidAssassin",
	name = "Void Assassin", role = "Assassin",
	hp = 95, m1Damage = 6, speed = 20,
	skills = {
		{name="Blink Strike", damage=9, cooldown=7, type="Teleport", anim="rbxassetid://0"},
		{name="Shadow Feint", damage=0, cooldown=8, type="Feint", anim="rbxassetid://0"},
		{name="Backstab Mark", damage=14, cooldown=10, type="Burst", anim="rbxassetid://0"},
	},
	ultimate = {name="Silent Execution", damage=40, cooldown=55, anim="rbxassetid://0"},
	passive = "Backstab +50% damage if enemy HP < 30%",
	rarity = "Legendary",
}

Characters.ThunderMonk = {
	id = "ThunderMonk",
	name = "Thunder Monk", role = "Controller",
	hp = 110, m1Damage = 7, speed = 17,
	skills = {
		{name="Lightning Palm", damage=9, cooldown=6, stun=0.4, type="Stun", anim="rbxassetid://0"},
		{name="Stun Ring", damage=4, cooldown=12, stun=0.6, type="AoE", anim="rbxassetid://0"},
		{name="Step Dash", damage=0, cooldown=5, type="Dodge", anim="rbxassetid://0"},
	},
	ultimate = {name="Heavenly Judgment", damage=30, cooldown=60, anim="rbxassetid://0"},
	passive = "Every 3rd M1 adds lightning charge",
	rarity = "Rare",
}

-- [Остальные 9 героев по аналогии будут добавлены в Characters.lua]

return Characters
