-- GameManager.server.lua | Anime Arena: Blitz Mode
-- Master match manager: lobby, start, timer, end, rewards, stats

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local MatchStart   = Remotes:WaitForChild("RoundStart")
local MatchEnd     = Remotes:WaitForChild("RoundEnd")
local UpdateTimer  = Remotes:WaitForChild("RoundTimer")
local ShowKillFeed = Remotes:WaitForChild("ShowKillFeed")
local UpdateHUD    = Remotes:WaitForChild("UpdateHUD")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local GameManager = {}
_G.GameManager = GameManager

local activeMatches = {}  -- [matchId] = matchData

-- === Helper: get CombatSystem safely ===
local function getCombatSystem()
	return _G.CombatSystem
end

-- === Helper: get CharacterService safely ===
local function getCharacterService()
	return _G.CharacterService
end

-- === Start Match ===
function GameManager.StartMatch(playerIds, mode)
	local matchId      = "Match_" .. tick()
	local matchPlayers = {}
	local Combat       = getCombatSystem()
	local CharSvc      = getCharacterService()

	for _, uid in pairs(playerIds) do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			table.insert(matchPlayers, p)

			-- Use selected hero or default to FlameRonin
			local heroData
			if CharSvc then
				heroData = CharSvc.GetSelectedHero(uid)
			end
			if not heroData and CharSvc then
				heroData = CharSvc.GetHeroData("FlameRonin")
			end
			if not heroData then
				heroData = { id = "FlameRonin", name = "Flame Ronin", hp = 120, m1Damage = 8, speed = 16 }
			end

			-- Apply stats & init combat
			if CharSvc then
				CharSvc.SpawnWithHero(p, heroData)
			elseif Combat then
				Combat.initPlayer(p, heroData)
			end
		end
	end

	if #matchPlayers == 0 then
		warn("[GameManager] StartMatch called with no valid players")
		return
	end

	activeMatches[matchId] = {
		players   = matchPlayers,
		startTime = tick(),
		duration  = Config.ROUND_DURATION and (Config.ROUND_DURATION[mode] or 180) or 180,
		mode      = mode,
	}

	-- Notify clients match has started
	for _, p in pairs(matchPlayers) do
		MatchStart:FireClient(p, mode)
	end

	-- Run timer loop
	task.spawn(function()
		local match    = activeMatches[matchId]
		local timeLeft = match.duration

		while timeLeft > 0 and activeMatches[matchId] do
			for _, p in pairs(matchPlayers) do
				if p and p.Parent then
					UpdateTimer:FireClient(p, timeLeft)
				end
			end
			task.wait(1)
			timeLeft -= 1
		end

		-- Time up — end match with no winner
		if activeMatches[matchId] then
			GameManager.EndMatch(matchId, nil)
		end
	end)

	print("[GameManager] Match started:", matchId, "| Mode:", mode, "| Players:", #matchPlayers)
end

-- === End Match ===
function GameManager.EndMatch(matchId, winnerId)
	local match = activeMatches[matchId]
	if not match then return end

	local Combat = getCombatSystem()

	-- Collect final stats from CombatSystem
	local finalStats = {}
	local mvpId      = nil
	local maxScore   = -1

	for _, p in pairs(match.players) do
		if p and p.Parent then
			local state = Combat and Combat.getState(p.UserId)
			if state then
				local kills  = state.kills  or 0
				local damage = state.damage or 0
				finalStats[p.UserId] = { kills = kills, damage = damage }
				local score = kills * 100 + damage
				if score > maxScore then
					maxScore = score
					mvpId    = p.UserId
				end
			else
				finalStats[p.UserId] = { kills = 0, damage = 0 }
			end
		end
	end

	local mvpPlayer = mvpId and Players:GetPlayerByUserId(mvpId)
	local mvpName   = mvpPlayer and mvpPlayer.Name or "None"

	-- Calculate per-player rewards
	for _, p in pairs(match.players) do
		if p and p.Parent then
			local isWinner = (winnerId ~= nil and p.UserId == winnerId)
			local isMVP    = (p.UserId == mvpId)

			local rpGain    = isWinner
				and (Config.REWARDS and Config.REWARDS.WIN_RATING  or 30)
				or  (Config.REWARDS and Config.REWARDS.LOSE_RATING or 10)
			local coinsGain = isWinner
				and (Config.REWARDS and Config.REWARDS.WIN_COINS   or 50)
				or  (Config.REWARDS and Config.REWARDS.LOSE_COINS  or 15)

			if isMVP then
				rpGain    = rpGain    + (Config.REWARDS and Config.REWARDS.MVP_BONUS_RP    or 10)
				coinsGain = coinsGain + (Config.REWARDS and Config.REWARDS.MVP_BONUS_COINS or 20)
			end

			local matchData = {
				winnerId  = winnerId or 0,
				stats     = finalStats,
				rewards   = { rp = rpGain, coins = coinsGain },
				mvpName   = mvpName,
				isMVP     = isMVP,
				mode      = match.mode,
			}

			MatchEnd:FireClient(p, matchData)

			-- Save to DataStore
			if _G.DataStore then
				_G.DataStore.AddPlayerRewards(p.UserId, rpGain, coinsGain)
			end
		end
	end

	activeMatches[matchId] = nil
	print("[GameManager] Match ended:", matchId, "| Winner:", winnerId or "none", "| MVP:", mvpName)
end

-- === Kill notification (called by CombatSystem) ===
function GameManager.OnKill(killerUserId, victimUserId, matchId)
	local killer = Players:GetPlayerByUserId(killerUserId)
	local victim = Players:GetPlayerByUserId(victimUserId)
	if not killer or not victim then return end

	-- Broadcast kill feed to all players in the match
	local match = activeMatches[matchId]
	if match then
		for _, p in pairs(match.players) do
			if p and p.Parent then
				ShowKillFeed:FireClient(p, killer.Name, victim.Name)
			end
		end
	end
end

return GameManager
