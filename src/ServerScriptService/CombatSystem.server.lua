-- CombatSystem.server.lua
-- Боевая система: обработка атак, HP, смерть, статусы, режимы

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatusEffects = require(script.Parent.StatusEffects)
local SkillHandlers = require(script.Parent.SkillHandlers)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UseSkill = Remotes:WaitForChild("UseSkill")
local TakeDamage = Remotes:WaitForChild("TakeDamage")
local PlayerDied = Remotes:WaitForChild("PlayerDied")
local UpdateHP = Remotes:WaitForChild("UpdateHP")
local MatchEnd = Remotes:WaitForChild("MatchEnd")
local SkillUsed = Remotes:WaitForChild("SkillUsed")

local matchState = {}
local cooldowns = {}

-- Инициализация SkillHandlers
local Characters = require(ReplicatedStorage:WaitForChild("Characters"))
SkillHandlers.Init(Characters)

-- === Хелперы: получаем системы ===
local function getGameManager()
	return _G.GameManager
end

local function getGameModeModifiers()
	return _G.GameModeModifiers
end

-- === Логика боя ===
local function dealDamage(attacker, victim, amount, reason)
	local state = matchState[victim.UserId]
	if not state or not state.alive then return end
	
	-- Учитываем щиты из StatusEffects
	local finalDamage = StatusEffects.ProcessDamageWithShield(victim.UserId, amount)
	if finalDamage <= 0 then return end
	
	-- Модификаторы атакующего
	local attackerMultiplier = StatusEffects.GetDamageMultiplier(attacker.UserId)
	finalDamage = finalDamage * attackerMultiplier
	
	-- GameModeModifiers damage multiplier
	local modifiers = getGameModeModifiers()
	if modifiers and attacker.Character then
		local dmgMult = modifiers.GetDamageMultiplier(attacker.Character)
		finalDamage = finalDamage * dmgMult
	end
	
	local attackerState = matchState[attacker.UserId]
	if attackerState then
		attackerState.damage = attackerState.damage + finalDamage
	end
	
	state.hp = math.max(0, state.hp - finalDamage)
	
	-- Обновление UI
	UpdateHP:FireClient(victim, state.hp, state.maxHp)
	UpdateHP:FireClient(attacker, state.hp, state.maxHp)
	
	if state.hp <= 0 then
		state.alive = false
		if attackerState then
			attackerState.kills = attackerState.kills + 1
		end
		PlayerDied:FireAllClients(victim.UserId, attacker.UserId)
		StatusEffects.ClearPlayer(victim.UserId)
		
		-- Вызов GameManager.OnKill для kill feed и проверки win condition
		local gm = getGameManager()
		if gm and gm.OnKill then
			gm.OnKill(attacker.UserId, victim.UserId, state.matchId)
		end
		
		-- Проверка победы (fallback для Normal-режима без kill limit)
		local alivePlayers = {}
		for uid, s in pairs(matchState) do
			if s.alive and s.matchId == state.matchId then 
				table.insert(alivePlayers, uid) 
			end
		end
		if #alivePlayers <= 1 then
			MatchEnd:FireAllClients(alivePlayers[1] or 0)
		end
	end
end

-- Публичный метод для StatusEffects (DoT)
local CombatSystem = {}

function CombatSystem.dealDamageToPlayer(userId, amount, reason)
	local victim = Players:GetPlayerByUserId(userId)
	if not victim then return end
	
	-- Для DoT атакующим считается сама система или последний ударивший (упростим до системы)
	dealDamage(victim, victim, amount, reason) 
end

-- === Обработка скиллов ===
UseSkill.OnServerEvent:Connect(function(player, skillKey)
	local state = matchState[player.UserId]
	if not state or not state.alive then return end
	
	-- Проверка стана
	if StatusEffects.IsStunned(player.UserId) then
		print("[Combat]", player.Name, "is stunned and cannot use skills")
		return
	end
	
	-- Проверка кулдауна
	local heroData = Characters[state.heroId]
	if not heroData then return end
	
	local cdTable = cooldowns[player.UserId] or {}
	local lastUsed = cdTable[skillKey] or 0
	
	local skillInfo = nil
	if skillKey == "Q" then skillInfo = heroData.skills[1]
	elseif skillKey == "E" then skillInfo = heroData.skills[2]
	elseif skillKey == "R" then skillInfo = heroData.ultimate end
	
	if not skillInfo then return end
	
	-- GameModeModifiers cooldown multiplier
	local cooldownTime = skillInfo.cooldown
	local modifiers = getGameModeModifiers()
	if modifiers and player.Character then
		local cdMult = modifiers.GetCooldownMultiplier(player.Character)
		cooldownTime = cooldownTime * cdMult
	end
	
	if tick() - lastUsed < cooldownTime then
		return
	end
	
	-- Выполнение скилла
	cdTable[skillKey] = tick()
	cooldowns[player.UserId] = cdTable
	
	-- Визуализация для всех
	SkillUsed:FireAllClients(player.UserId, skillKey)
	
	-- Логика из SkillHandlers
	local handler = SkillHandlers[state.heroId]
	if handler and handler[skillKey] then
		handler[skillKey](player, {
			dealDamage = dealDamage,
			getState = function(uid) return matchState[uid] end
		})
	end
end)

-- Вспомогательный метод для дефолтных скиллов
function CombatSystem.defaultSkillHit(player, skillData)
	-- Простая реализация хитбокса перед игроком
	local character = player.Character
	if not character then return end
	
	local hrp = character.HumanoidRootPart
	local region = hrp.CFrame * CFrame.new(0, 0, -5)
	
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			local dist = (otherPlayer.Character.HumanoidRootPart.Position - region.Position).Magnitude
			if dist < 7 then
				dealDamage(player, otherPlayer, skillData.damage or 10)
			end
		end
	end
end

-- === Системные функции ===
function CombatSystem.initPlayer(player, heroData, matchId)
	local maxHp = heroData and heroData.hp or 100
	matchState[player.UserId] = {
		hp = maxHp,
		maxHp = maxHp,
		heroId = heroData and heroData.id or "FlameRonin",
		alive = true,
		kills = 0,
		damage = 0,
		matchId = matchId or "default",
	}
	cooldowns[player.UserId] = {}
	StatusEffects.ClearPlayer(player.UserId)
end

function CombatSystem.getState(userId)
	return matchState[userId]
end

Players.PlayerRemoving:Connect(function(player)
	matchState[player.UserId] = nil
	cooldowns[player.UserId] = nil
	StatusEffects.ClearPlayer(player.UserId)
end)

_G.CombatSystem = CombatSystem

return CombatSystem
