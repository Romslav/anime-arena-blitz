-- init.server.lua
-- Инициализация RemoteEvents и RemoteFunctions для Anime Arena: Blitz Mode

local ReplicatedStorage = game:GetService("ReplicatedStorage")
print("[INIT] Starting RemoteEvents initialization...")

-- Используем существующую папку Remotes из Rojo конфигурации
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

-- HeroSelector
makeRemote("SelectHero")
makeRemote("HeroSelected")

-- Combat
makeRemote("UseAbility")
makeRemote("TakeDamage")
makeRemote("PlayerDied")
makeRemote("UpdateHP")

-- Match
makeRemote("MatchStart")
makeRemote("MatchEnd")
makeRemote("RoundStart")
makeRemote("RoundEndRoundStart")
makeRemote("UpdateTimer")
makeRemote("UpdateScoreboard")

-- Rank
makeRemote("ShowRankScreen")
makeRemote("RequestRematch")

print("[INIT] All RemoteEvents created successfully!")
print("[INIT] Remotes folder:", Remotes)
print("[INIT] Remotes children:", Remotes:GetChildren())

print("[AnimeArena] Remotes initialized:", #Remotes:GetChildren())
