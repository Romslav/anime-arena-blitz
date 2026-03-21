-- RoundSystem.server.lua
-- Anime Arena: Blitz Mode
-- Sistema raundov i ocenka ranga

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--local Shared = ReplicatedStorage:WaitForChild("AnimeArena")
--local Config = require(Shared:WaitForChild("Config"))
--local Remotes = Shared:WaitForChild("Remotes")

local RANK_THRESHOLDS = {
    {min = 95, rank = "SS"},
    {min = 85, rank = "S"},
    {min = 70, rank = "A"},
    {min = 55, rank = "B"},
    {min = 40, rank = "C"},
    {min = 25, rank = "D"},
    {min = 0,  rank = "E"},
}

local function calculateMatchRank(score)
    for _, threshold in ipairs(RANK_THRESHOLDS) do
        if score >= threshold.min then
            return threshold.rank
        end
    end
    return "E"
end

local function calculateScore(stats)
    local score = 0
    if stats.won then score = score + 30 end
    score = score + math.min(stats.damageDealt / 10, 20)
    score = score + math.min(stats.dodges * 2, 10)
    score = score + math.min(stats.parries * 3, 15)
    score = score + math.min(stats.combos * 2, 10)
    if stats.timeLeft > 60 then score = score + 5 end
    score = score - math.min(stats.damageTaken / 20, 10)
    return math.clamp(math.floor(score), 0, 100)
end

local function endRound(playerStats)
    local results = {}
    for userId, stats in pairs(playerStats) do
        local score = calculateScore(stats)
        local rank = calculateMatchRank(score)
        results[userId] = { score = score, rank = rank }
        print("[RoundSystem] Player", userId, "-> Score:", score, "| Rank:", rank)
    end
    Remotes.RoundEnd:FireAllClients(results)
    return results
end

print("[RoundSystem] Loaded")
