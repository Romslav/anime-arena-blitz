-- CharacterService.server.lua | Anime Arena: Blitz Mode
-- Handles hero selection, character spawning, stat application, and loadout validation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Characters = require(ReplicatedStorage:WaitForChild("Characters"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- === Remote Setup ===
local SelectHero = Remotes:WaitForChild("SelectHero")
local HeroSelectedConfirm = Remotes:WaitForChild("HeroSelected")
local CharacterSpawned = Remotes:WaitForChild("CharacterSpawned")

-- === ID Normalization Map (snake_case -> PascalCase) ===
local HERO_ID_MAP = {
    flame_ronin     = "FlameRonin",
    void_assassin   = "VoidAssassin",
    thunder_monk    = "ThunderMonk",
    iron_titan      = "IronTitan",
    scarlet_archer  = "ScarletArcher",
    eclipse_hero    = "EclipseHero",
    storm_dancer    = "StormDancer",
    blood_sage      = "BloodSage",
    crystal_guard   = "CrystalGuard",
    shadow_twin     = "ShadowTwin",
    neon_blitz      = "NeonBlitz",
    jade_sentinel   = "JadeSentinel",
}

-- Fallback definitions for heroes not yet in Characters.lua
local FALLBACK_STATS = {
    IronTitan    = { id="IronTitan",    name="Iron Titan",    role="Tank",        hp=260, m1Damage=15, speed=12,
        skills = {
            {name="Iron Slam",    damage=12, cooldown=8,  type="AoE",     anim="rbxassetid://0"},
            {name="Shield Wall",  damage=0,  cooldown=12, type="Defense", anim="rbxassetid://0"},
            {name="Ground Quake", damage=18, cooldown=15, type="AoE",     anim="rbxassetid://0"},
        },
        ultimate = {name="Titan Fall", damage=45, cooldown=70, anim="rbxassetid://0"},
        passive  = "Blocks 15% damage from front", rarity="Rare" },
    ScarletArcher = { id="ScarletArcher", name="Scarlet Archer", role="Ranged", hp=140, m1Damage=24, speed=15,
        skills = {
            {name="Arrow Rain",   damage=14, cooldown=9,  type="AoE",    anim="rbxassetid://0"},
            {name="Piercing Shot",damage=20, cooldown=8,  type="Linear", anim="rbxassetid://0"},
            {name="Evasion Roll", damage=0,  cooldown=7,  type="Dodge",  anim="rbxassetid://0"},
        },
        ultimate = {name="Storm of Arrows", damage=38, cooldown=55, anim="rbxassetid://0"},
        passive  = "Headshots deal +30% damage", rarity="Rare" },
    EclipseHero  = { id="EclipseHero",  name="Eclipse Hero",  role="Assassin",    hp=150, m1Damage=26, speed=18,
        skills = {
            {name="Eclipse Slash",damage=15, cooldown=7,  type="Burst",    anim="rbxassetid://0"},
            {name="Lunar Phase",  damage=10, cooldown=9,  type="Teleport", anim="rbxassetid://0"},
            {name="Dark Veil",    damage=0,  cooldown=12, type="Stealth",  anim="rbxassetid://0"},
        },
        ultimate = {name="Total Eclipse", damage=44, cooldown=60, anim="rbxassetid://0"},
        passive  = "Crit chance +25% from behind", rarity="Legendary" },
    StormDancer  = { id="StormDancer",  name="Storm Dancer",  role="Skirmisher",  hp=145, m1Damage=23, speed=19,
        skills = {
            {name="Tempest Step", damage=8,  cooldown=6,  type="Dash",  anim="rbxassetid://0"},
            {name="Wind Spiral",  damage=12, cooldown=8,  type="AoE",   anim="rbxassetid://0"},
            {name="Gale Parry",   damage=0,  cooldown=10, type="Parry", anim="rbxassetid://0"},
        },
        ultimate = {name="Cyclone Fury", damage=36, cooldown=55, anim="rbxassetid://0"},
        passive  = "Hits build Storm stacks for speed boost", rarity="Common" },
    BloodSage    = { id="BloodSage",    name="Blood Sage",    role="Mage",        hp=120, m1Damage=30, speed=14,
        skills = {
            {name="Bloodbolt",    damage=18, cooldown=7,  type="Projectile", anim="rbxassetid://0"},
            {name="Crimson Bind", damage=6,  cooldown=10, type="Root",       anim="rbxassetid://0"},
            {name="Sanguine Burst",damage=22,cooldown=14, type="AoE",        anim="rbxassetid://0"},
        },
        ultimate = {name="Blood Moon", damage=50, cooldown=65, anim="rbxassetid://0"},
        passive  = "Drains 5HP per hit", rarity="Legendary" },
    CrystalGuard = { id="CrystalGuard", name="Crystal Guard", role="Tank",        hp=240, m1Damage=14, speed=13,
        skills = {
            {name="Crystal Spike",damage=10, cooldown=7,  type="AoE",     anim="rbxassetid://0"},
            {name="Prism Barrier",damage=0,  cooldown=12, type="Shield",   anim="rbxassetid://0"},
            {name="Shatter Rush", damage=16, cooldown=10, type="Dash",     anim="rbxassetid://0"},
        },
        ultimate = {name="Crystal Fortress", damage=30, cooldown=70, anim="rbxassetid://0"},
        passive  = "Crystal shards reduce incoming damage", rarity="Rare" },
    ShadowTwin   = { id="ShadowTwin",   name="Shadow Twin",   role="Support",     hp=155, m1Damage=25, speed=17,
        skills = {
            {name="Twin Lash",    damage=12, cooldown=6,  type="Burst",      anim="rbxassetid://0"},
            {name="Shadow Clone", damage=0,  cooldown=15, type="Clone",      anim="rbxassetid://0"},
            {name="Mist Step",    damage=0,  cooldown=8,  type="Teleport",   anim="rbxassetid://0"},
        },
        ultimate = {name="Dark Mirror", damage=35, cooldown=60, anim="rbxassetid://0"},
        passive  = "Clone deals 50% damage", rarity="Epic" },
    NeonBlitz    = { id="NeonBlitz",    name="Neon Blitz",    role="Ranged",      hp=135, m1Damage=27, speed=16,
        skills = {
            {name="Neon Burst",   damage=16, cooldown=7,  type="Projectile", anim="rbxassetid://0"},
            {name="Circuit Dash", damage=0,  cooldown=6,  type="Dash",       anim="rbxassetid://0"},
            {name="Overload",     damage=20, cooldown=12, type="AoE",        anim="rbxassetid://0"},
        },
        ultimate = {name="Neon Overdrive", damage=42, cooldown=58, anim="rbxassetid://0"},
        passive  = "Every 4th hit fires a neon pulse", rarity="Epic" },
    JadeSentinel = { id="JadeSentinel", name="Jade Sentinel", role="Duelist",     hp=200, m1Damage=18, speed=15,
        skills = {
            {name="Jade Strike",  damage=14, cooldown=7,  type="Burst",   anim="rbxassetid://0"},
            {name="Sentinel Step",damage=0,  cooldown=6,  type="Dodge",   anim="rbxassetid://0"},
            {name="Earthen Crush",damage=18, cooldown=11, type="AoE",     anim="rbxassetid://0"},
        },
        ultimate = {name="Jade Wrath", damage=38, cooldown=60, anim="rbxassetid://0"},
        passive  = "Perfect parry resets a skill cooldown", rarity="Rare" },
}

-- === State ===
local selectedHeroes = {}  -- [userId] = heroData
local CharacterService = {}
_G.CharacterService = CharacterService

-- === Get Hero Data (from Characters.lua or fallback) ===
function CharacterService.GetHeroData(heroId)
    -- Accept both snake_case and PascalCase
    local normalizedId = HERO_ID_MAP[heroId] or heroId
    local data = Characters[normalizedId] or FALLBACK_STATS[normalizedId]
    if not data then
        warn("[CharacterService] Unknown hero ID: " .. tostring(heroId) .. " (normalized: " .. tostring(normalizedId) .. ")")
        return Characters.FlameRonin  -- safe fallback
    end
    return data
end

-- === Get selected hero for a player ===
function CharacterService.GetSelectedHero(userId)
    return selectedHeroes[userId]
end

-- === Apply hero stats to character model ===
function CharacterService.ApplyStats(character, heroData)
    if not character or not heroData then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.MaxHealth = heroData.hp
        humanoid.Health    = heroData.hp
        if humanoid.WalkSpeed ~= nil then
            humanoid.WalkSpeed = heroData.speed or 16
        end
    end

    -- Tag character with hero identity for combat lookups
    local tag = character:FindFirstChild("HeroTag")
    if not tag then
        tag = Instance.new("StringValue")
        tag.Name = "HeroTag"
        tag.Parent = character
    end
    tag.Value = heroData.id
end

-- === Spawn player with selected hero ===
function CharacterService.SpawnWithHero(player, heroData)
    if not player or not heroData then return end

    -- Store selection
    selectedHeroes[player.UserId] = heroData

    -- Apply stats after character loads/respawns
    local function onCharacterAdded(character)
        task.wait(0.1)  -- let character initialize
        CharacterService.ApplyStats(character, heroData)

        -- Notify all clients about this hero spawn
        CharacterSpawned:FireAllClients(player.UserId, heroData.id, heroData.name)

        -- Initialize in CombatSystem
        if _G.CombatSystem then
            _G.CombatSystem.initPlayer(player, heroData)
        end
    end

    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end

-- === Remote: Client selects hero ===
SelectHero.OnServerEvent:Connect(function(player, heroId)
    if type(heroId) ~= "string" then
        warn("[CharacterService] Invalid heroId from " .. player.Name)
        return
    end

    local heroData = CharacterService.GetHeroData(heroId)
    selectedHeroes[player.UserId] = heroData

    -- Confirm back to client
    HeroSelectedConfirm:FireClient(player, heroData.id, heroData.name)

    print("[CharacterService] " .. player.Name .. " selected hero: " .. heroData.name)
end)

-- === Cleanup on player leave ===
Players.PlayerRemoving:Connect(function(player)
    selectedHeroes[player.UserId] = nil
end)

return CharacterService


-- === Apply Game Mode to Player (for OneHit Mode integration) ===
function CharacterService.SpawnWithMode(player, heroData, gameMode)
	if not player or not heroData then return end

	-- Store selection
	selectedHeroes[player.UserId] = heroData

	local function onCharacterAdded(character)
		task.wait(0.1)
		
		-- Apply base hero stats
		CharacterService.ApplyStats(character, heroData)

		-- Apply game mode modifiers (OneHit, Normal, etc.)
		if _G.GameModeModifiers and gameMode then
			_G.GameModeModifiers.ApplyToPlayer(player, gameMode, heroData)
		end

		-- Notify clients
		CharacterSpawned:FireAllClients(player.UserId, heroData.id, heroData.name)

		-- Init CombatSystem
		if _G.CombatSystem then
			_G.CombatSystem.initPlayer(player, heroData)
		end
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end
