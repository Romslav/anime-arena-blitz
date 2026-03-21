-- RemotesInitializer.server.lua | Anime Arena: Blitz Mode
-- Creates all RemoteEvents and RemoteFunctions used across the game

local ReplicatedStorage = game:GetService("ReplicatedStorage")
print("[INIT] Starting RemoteEvents initialization...")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
print("[INIT] Found Remotes folder:", Remotes)

local function makeRemote(name, isFunction)
	local r
	if isFunction then
		r = Instance.new("RemoteFunction")
	else
		r = Instance.new("RemoteEvent")
	end
	r.Name = name
	r.Parent = Remotes
	return r
end

-- === HeroSelector ===
makeRemote("SelectHero")         -- client -> server: player picks hero
makeRemote("HeroSelected")       -- server -> client: confirm hero selection
makeRemote("CharacterSpawned")   -- server -> all:    notify hero identity on spawn

-- === Game Flow ===
makeRemote("RoundStart")         -- server -> client: match begins, sends mode
makeRemote("RoundEnd")           -- server -> client: match ends, sends results
makeRemote("RoundTimer")         -- server -> client: countdown tick
makeRemote("MatchStart")         -- server -> client: alias for MatchStart (HeroSelector compatibility)

-- === Combat ===
makeRemote("UseSkill")           -- client -> server: activate skill by index
makeRemote("UseUltimate")        -- client -> server: activate ultimate
makeRemote("M1Attack")           -- client -> server: basic attack
makeRemote("TakeDamage")         -- server -> client: health update notification
makeRemote("ChargeUlt")          -- server -> client: ult charge update
makeRemote("UltCharge")          -- server -> client: ult charge (alias)

-- === Skills / VFX ===
makeRemote("SkillVFX")           -- server -> all:    broadcast skill VFX to clients
makeRemote("StatusEffectApplied")-- server -> client: notify status effect applied
makeRemote("StatusEffectRemoved")-- server -> client: notify status effect removed

-- === Matchmaking ===
makeRemote("JoinQueue")          -- client -> server: enter matchmaking
makeRemote("LeaveQueue")         -- client -> server: exit matchmaking
makeRemote("MatchFound")         -- server -> client: match is ready

-- === UI / HUD ===
makeRemote("UpdateHUD")          -- server -> client: push HP/ult/timer data
makeRemote("ShowKillFeed")       -- server -> all:    kill feed entry
makeRemote("ShowNotification")   -- server -> client: in-game toast message

print("[INIT] All remotes initialized successfully.")
