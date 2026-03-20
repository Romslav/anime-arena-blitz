-- CombatSystem.server.lua
-- Боевая система: обработка атак, HP, смерть, статистика

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UseAbility = Remotes:WaitForChild("UseAbility")
local TakeDamage = Remotes:WaitForChild("TakeDamage")
local PlayerDied = Remotes:WaitForChild("PlayerDied")
local UpdateHP = Remotes:WaitForChild("UpdateHP")
local MatchEnd = Remotes:WaitForChild("MatchEnd")

-- HP игроков в текущем матче
-- { [userId] = { hp = N, maxHp = N, heroId = "...", alive = bool, kills = N, damage = N } }
local matchState = {}

-- Кулдауны способностей: { [userId] = { [abilityName] = tick } }
local cooldowns = {}

local ABILITY_COOLDOWNS = {
	Q = 8,
	E = 12,
	R = 30, -- ульта
}

local function isOnCooldown(userId, ability)
	local cd = cooldowns[userId]
	if not cd then return false end
	local last = cd[ability]
	if not last then return false end
	return (tick() - last) < ABILITY_COOLDOWNS[ability]
end

local function setCooldown(userId, ability)
	if not cooldowns[userId] then cooldowns[userId] = {} end
	cooldowns[userId][ability] = tick()
end

-- Абилити по типу
local ABILITY_DAMAGE = {
	Q = 40,
	E = 65,
	R = 120,
	M1 = 0, -- M1 обрабатывается отдельно
}

-- Инициализация состояния игрока
local function initPlayer(player, heroData)
	local maxHp = heroData and heroData.hp or 150
	matchState[player.UserId] = {
		hp = maxHp,
		maxHp = maxHp,
		heroId = heroData and heroData.id or "unknown",
		alive = true,
		kills = 0,
		damage = 0,
	}
	cooldowns[player.UserId] = {}
	print("[Combat] Init player", player.Name, "HP:", maxHp)
end

-- Нанесение урона
local function dealDamage(attacker, victim, amount)
	local state = matchState[victim.UserId]
	if not state or not state.alive then return end
	
	local attackerState = matchState[attacker.UserId]
	if attackerState then
		attackerState.damage = attackerState.damage + amount
	end
	
	state.hp = math.max(0, state.hp - amount)
	
	-- Обновляем HP на клиенте жертвы
	UpdateHP:FireClient(victim, state.hp, state.maxHp)
	-- И атакующему (feedback)
	UpdateHP:FireClient(attacker, state.hp, state.maxHp)
	
	if state.hp <= 0 then
		state.alive = false
		
		-- Увеличиваем счетчик убийств
		if attackerState then
			attackerState.kills = attackerState.kills + 1
		end
		
		PlayerDied:FireAllClients(victim.UserId, attacker.UserId)
		print("[Combat]", victim.Name, "died, killed by", attacker.Name)
		
		-- Проверяем конец матча
		local aliveCount = 0
		local lastAlive
		for uid, s in pairs(matchState) do
			if s.alive then
				aliveCount += 1
				lastAlive = uid
			end
		end
		
		if aliveCount <= 1 then
			MatchEnd:FireAllClients(lastAlive)
		end
	end
end

-- Обработка использования способности
UseAbility.OnServerEvent:Connect(function(player, abilityType, targetUserId)
	local state = matchState[player.UserId]
	if not state or not state.alive then return end
	
	if abilityType ~= "M1" and isOnCooldown(player.UserId, abilityType) then
		return
	end
	
	if abilityType ~= "M1" then
		setCooldown(player.UserId, abilityType)
	end
	
	local dmg = ABILITY_DAMAGE[abilityType] or 0
	if dmg > 0 and targetUserId then
		local targetPlayer = Players:GetPlayerByUserId(targetUserId)
		if targetPlayer then
			dealDamage(player, targetPlayer, dmg)
		end
	end
end)

-- Очистка
Players.PlayerRemoving:Connect(function(player)
	matchState[player.UserId] = nil
	cooldowns[player.UserId] = nil
end)

-- Публичное API
return {
	initPlayer = initPlayer,
	dealDamage = dealDamage,
	getState = function(uid) return matchState[uid] end,
	getMatchState = function() return matchState end,
	resetMatch = function() matchState = {} cooldowns = {} end,
}
