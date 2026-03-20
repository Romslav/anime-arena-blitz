-- init.server.lua
-- Инициализация RemoteEvents и RemoteFunctions для Anime Arena: Blitz Mode

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

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
makeRemote("UpdateTimer")
makeRemote("UpdateScoreboard")

-- Rank
makeRemote("ShowRankScreen")
makeRemote("RequestRematch")

print("[AnimeArena] Remotes initialized:", #Remotes:GetChildren())
