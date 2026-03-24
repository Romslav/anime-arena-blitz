-- GameModeModifiers.lua | Anime Arena: Blitz Mode
-- Game mode modifier system: One Hit Mode, Low Gravity, Speed Mode, etc.
-- Applies stat changes, special rules, and visual effects per mode

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameModeModifiers = {}
_G.GameModeModifiers = GameModeModifiers

-- ============================================================
-- MODE DEFINITIONS
-- ============================================================

local MODES = {
	-- === ONE HIT MODE ===
	OneHit = {
		id = "OneHit",
		name = "⚡ ONE HIT MODE",
		description = "1 HP. Instant kills. Pure skill.",
		color = Color3.fromRGB(255, 50, 50),

		stats = {
			hp = 1,
			speedMultiplier = 1.5,
			damageMultiplier = 999,
			cooldownMultiplier = 0.5,
			respawnTime = 3,
			ultChargeRate = 2.0,
		},

		rules = {
			disableDefensiveSkills = true,
			instantKillOnHit = true,
			showHitIndicator = true,
			enableKillStreaks = true,
			maxKillStreak = 10,
		},

		rewards = {
			rpMultiplier = 1.5,
			coinsMultiplier = 1.3,
		},

		match = {
			duration = 120,
			minPlayers = 2,
			maxPlayers = 8,
			firstTo = 15,
		},
	},

	-- === NORMAL MODE (baseline) ===
	Normal = {
		id = "Normal",
		name = "⚔️ NORMAL MODE",
		description = "Standard battle. Balanced gameplay.",
		color = Color3.fromRGB(100, 200, 255),

		stats = {
			hp = nil,
			speedMultiplier = 1.0,
			damageMultiplier = 1.0,
			cooldownMultiplier = 1.0,
			respawnTime = 5,
			ultChargeRate = 1.0,
		},

		rules = {
			disableDefensiveSkills = false,
			instantKillOnHit = false,
			showHitIndicator = false,
			enableKillStreaks = false,
		},

		rewards = {
			rpMultiplier = 1.0,
			coinsMultiplier = 1.0,
		},

		match = {
			duration = 180,
			minPlayers = 2,
			maxPlayers = 6,
			firstTo = nil,
		},
	},
}

-- ============================================================
-- API: Get Mode Configuration
-- ============================================================
function GameModeModifiers.GetMode(modeId)
	return MODES[modeId] or MODES.Normal
end

function GameModeModifiers.GetAllModes()
	return MODES
end

-- ============================================================
-- API: Apply Mode to Player
-- ============================================================
function GameModeModifiers.ApplyToPlayer(player, modeId, heroData)
	local mode = GameModeModifiers.GetMode(modeId)
	if not mode then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local maxHP = mode.stats.hp or heroData.hp or 100
	humanoid.MaxHealth = maxHP
	humanoid.Health = maxHP

	local baseSpeed = heroData.speed or 16
	humanoid.WalkSpeed = baseSpeed * mode.stats.speedMultiplier

	local modeTag = character:FindFirstChild("GameModeTag")
	if not modeTag then
		modeTag = Instance.new("StringValue")
		modeTag.Name = "GameModeTag"
		modeTag.Parent = character
	end
	modeTag.Value = modeId

	local modData = character:FindFirstChild("ModeModifiers")
	if not modData then
		modData = Instance.new("Folder")
		modData.Name = "ModeModifiers"
		modData.Parent = character
	end

	local dmgMult = Instance.new("NumberValue")
	dmgMult.Name = "DamageMultiplier"
	dmgMult.Value = mode.stats.damageMultiplier
	dmgMult.Parent = modData

	local cdMult = Instance.new("NumberValue")
	cdMult.Name = "CooldownMultiplier"
	cdMult.Value = mode.stats.cooldownMultiplier
	cdMult.Parent = modData

	local ultMult = Instance.new("NumberValue")
	ultMult.Name = "UltChargeRate"
	ultMult.Value = mode.stats.ultChargeRate
	ultMult.Parent = modData

	print("[GameModeModifiers] Applied", mode.name, "to", player.Name, "| HP:", maxHP, "Speed:", humanoid.WalkSpeed)
end

-- ============================================================
-- API: Get Damage Multiplier for Mode
-- ============================================================
function GameModeModifiers.GetDamageMultiplier(character)
	if not character then return 1 end
	local modData = character:FindFirstChild("ModeModifiers")
	if not modData then return 1 end
	local dmgMult = modData:FindFirstChild("DamageMultiplier")
	return dmgMult and dmgMult.Value or 1
end

-- ============================================================
-- API: Get Cooldown Multiplier
-- ============================================================
function GameModeModifiers.GetCooldownMultiplier(character)
	if not character then return 1 end
	local modData = character:FindFirstChild("ModeModifiers")
	if not modData then return 1 end
	local cdMult = modData:FindFirstChild("CooldownMultiplier")
	return cdMult and cdMult.Value or 1
end

-- ============================================================
-- API: Get Ult Charge Rate
-- ============================================================
function GameModeModifiers.GetUltChargeRate(character)
	if not character then return 1 end
	local modData = character:FindFirstChild("ModeModifiers")
	if not modData then return 1 end
	local ultRate = modData:FindFirstChild("UltChargeRate")
	return ultRate and ultRate.Value or 1
end

-- ============================================================
-- API: Check if Mode is One Hit
-- ============================================================
function GameModeModifiers.IsOneHitMode(character)
	if not character then return false end
	local modeTag = character:FindFirstChild("GameModeTag")
	return modeTag and modeTag.Value == "OneHit"
end

-- BUG-4 FIX: версия для RoundService, который передаёт round.mode (строку)
function GameModeModifiers.IsOneHitModeId(modeId)
	return modeId == "OneHit"
end

-- BUG-5 FIX: RoundService через Modifiers.GetBattleDuration(round.mode)
function GameModeModifiers.GetBattleDuration(modeId)
	local mode = GameModeModifiers.GetMode(modeId)
	return mode and mode.match and mode.match.duration or 180
end

-- BUG-6 FIX: CombatSystem.initPlayer вызывает Mods.ModifyHP(mode, maxHp)
function GameModeModifiers.ModifyHP(modeId, baseHp)
	local mode = GameModeModifiers.GetMode(modeId)
	if mode and mode.stats and mode.stats.hp then
		return mode.stats.hp
	end
	return baseHp
end

-- ============================================================
-- API: Get Respawn Time for Mode
-- ============================================================
function GameModeModifiers.GetRespawnTime(modeId)
	local mode = GameModeModifiers.GetMode(modeId)
	return mode.stats.respawnTime or 5
end

-- ============================================================
-- API: Calculate Rewards with Mode Multiplier
-- ============================================================
function GameModeModifiers.CalculateRewards(modeId, baseRP, baseCoins)
	local mode = GameModeModifiers.GetMode(modeId)
	local rp = math.floor(baseRP * mode.rewards.rpMultiplier)
	local coins = math.floor(baseCoins * mode.rewards.coinsMultiplier)
	return rp, coins
end

-- ============================================================
-- API: Check Win Condition (for kill-based modes)
-- ============================================================
function GameModeModifiers.CheckWinCondition(modeId, kills)
	local mode = GameModeModifiers.GetMode(modeId)
	if mode.match.firstTo and kills >= mode.match.firstTo then
		return true
	end
	return false
end

return GameModeModifiers
