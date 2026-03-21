-- StatusEffects.lua | Anime Arena: Blitz Mode
-- Production-ready система статус-эффектов: burn, poison, stun, slow, shield, buffs

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateEffect = Remotes:WaitForChild("UpdateEffect") -- для VFX на клиенте

local StatusEffects = {}

-- Активные эффекты: { [userId] = { [effectId] = {type, duration, tick, data} } }
local activeEffects = {}

-- Типы эффектов
local EFFECT_TYPES = {
	BURN = "Burn",
	POISON = "Poison",
	STUN = "Stun",
	SLOW = "Slow",
	SHIELD = "Shield",
	BUFF_DAMAGE = "BuffDamage",
	BUFF_SPEED = "BuffSpeed",
	ROOT = "Root",
	KNOCKBACK = "Knockback",
	LIFESTEAL = "Lifesteal",
}

StatusEffects.TYPES = EFFECT_TYPES

-- === Применение эффектов ===

-- Базовая функция применения эффекта
local function applyEffect(userId, effectType, duration, data)
	if not activeEffects[userId] then
		activeEffects[userId] = {}
	end
	
	local effectId = effectType .. "_" .. tick()
	activeEffects[userId][effectId] = {
		type = effectType,
		duration = duration,
		startTick = tick(),
		data = data or {},
	}
	
	-- Уведомляем клиент для VFX
	local player = game.Players:GetPlayerByUserId(userId)
	if player then
		UpdateEffect:FireClient(player, effectType, true, duration)
	end
	
	print("[StatusEffects] Applied", effectType, "to user", userId, "for", duration, "sec")
	return effectId
end

-- Удаление эффекта
local function removeEffect(userId, effectId)
	if not activeEffects[userId] or not activeEffects[userId][effectId] then return end
	
	local effectType = activeEffects[userId][effectId].type
	activeEffects[userId][effectId] = nil
	
	-- Уведомляем клиент
	local player = game.Players:GetPlayerByUserId(userId)
	if player then
		UpdateEffect:FireClient(player, effectType, false, 0)
	end
	
	print("[StatusEffects] Removed", effectType, "from user", userId)
end

-- === Публичное API ===

function StatusEffects.ApplyBurn(userId, duration, damagePerTick)
	local data = { damagePerTick = damagePerTick or 2, lastTick = tick() }
	return applyEffect(userId, EFFECT_TYPES.BURN, duration, data)
end

function StatusEffects.ApplyPoison(userId, duration, damagePerTick, maxStacks)
	local existingPoison = StatusEffects.GetEffect(userId, EFFECT_TYPES.POISON)
	
	if existingPoison and maxStacks then
		-- Стакаем яд
		local currentStacks = existingPoison.data.stacks or 1
		if currentStacks < maxStacks then
			existingPoison.data.stacks = currentStacks + 1
			existingPoison.data.damagePerTick = (damagePerTick or 2) * existingPoison.data.stacks
			existingPoison.duration = duration -- обновляем время
			existingPoison.startTick = tick()
			print("[StatusEffects] Poison stacked to", existingPoison.data.stacks)
			return
		end
	end
	
	local data = { damagePerTick = damagePerTick or 2, lastTick = tick(), stacks = 1 }
	return applyEffect(userId, EFFECT_TYPES.POISON, duration, data)
end

function StatusEffects.ApplyStun(userId, duration)
	-- Стан блокирует движение и скиллы
	return applyEffect(userId, EFFECT_TYPES.STUN, duration, {})
end

function StatusEffects.ApplySlow(userId, duration, slowPercent)
	local data = { slowPercent = slowPercent or 0.5 } -- 50% по умолчанию
	return applyEffect(userId, EFFECT_TYPES.SLOW, duration, data)
end

function StatusEffects.ApplyShield(userId, duration, shieldAmount)
	local data = { shieldAmount = shieldAmount, currentShield = shieldAmount }
	return applyEffect(userId, EFFECT_TYPES.SHIELD, duration, data)
end

function StatusEffects.ApplyRoot(userId, duration)
	-- Рут: нельзя двигаться, но можно атаковать
	return applyEffect(userId, EFFECT_TYPES.ROOT, duration, {})
end

function StatusEffects.ApplyBuffDamage(userId, duration, damageMultiplier)
	local data = { multiplier = damageMultiplier or 1.2 }
	return applyEffect(userId, EFFECT_TYPES.BUFF_DAMAGE, duration, data)
end

function StatusEffects.ApplyBuffSpeed(userId, duration, speedMultiplier)
	local data = { multiplier = speedMultiplier or 1.3 }
	return applyEffect(userId, EFFECT_TYPES.BUFF_SPEED, duration, data)
end

-- === Проверка статусов ===

function StatusEffects.IsStunned(userId)
	return StatusEffects.HasEffect(userId, EFFECT_TYPES.STUN)
end

function StatusEffects.IsRooted(userId)
	return StatusEffects.HasEffect(userId, EFFECT_TYPES.ROOT)
end

function StatusEffects.IsSlowed(userId)
	return StatusEffects.HasEffect(userId, EFFECT_TYPES.SLOW)
end

function StatusEffects.HasShield(userId)
	return StatusEffects.HasEffect(userId, EFFECT_TYPES.SHIELD)
end

function StatusEffects.HasEffect(userId, effectType)
	if not activeEffects[userId] then return false end
	
	for _, effect in pairs(activeEffects[userId]) do
		if effect.type == effectType then
			return true
		end
	end
	return false
end

function StatusEffects.GetEffect(userId, effectType)
	if not activeEffects[userId] then return nil end
	
	for effectId, effect in pairs(activeEffects[userId]) do
		if effect.type == effectType then
			return effect
		end
	end
	return nil
end

-- Получить все активные эффекты игрока
function StatusEffects.GetAllEffects(userId)
	return activeEffects[userId] or {}
end

-- === Обработка урона через щит ===

function StatusEffects.ProcessDamageWithShield(userId, incomingDamage)
	local shieldEffect = StatusEffects.GetEffect(userId, EFFECT_TYPES.SHIELD)
	
	if not shieldEffect then
		return incomingDamage -- нет щита, полный урон
	end
	
	local currentShield = shieldEffect.data.currentShield
	
	if currentShield >= incomingDamage then
		-- Щит поглощает весь урон
		shieldEffect.data.currentShield = currentShield - incomingDamage
		print("[StatusEffects] Shield absorbed", incomingDamage, "damage, remaining:", shieldEffect.data.currentShield)
		return 0
	else
		-- Щит сломан, остаток урона проходит
		local remainingDamage = incomingDamage - currentShield
		shieldEffect.data.currentShield = 0
		print("[StatusEffects] Shield broken! Remaining damage:", remainingDamage)
		
		-- Удаляем щит
		for effectId, effect in pairs(activeEffects[userId]) do
			if effect.type == EFFECT_TYPES.SHIELD then
				removeEffect(userId, effectId)
				break
			end
		end
		
		return remainingDamage
	end
end

-- === Модификаторы урона и скорости ===

function StatusEffects.GetDamageMultiplier(userId)
	local multiplier = 1.0
	
	for _, effect in pairs(StatusEffects.GetAllEffects(userId)) do
		if effect.type == EFFECT_TYPES.BUFF_DAMAGE then
			multiplier = multiplier * effect.data.multiplier
		end
	end
	
	return multiplier
end

function StatusEffects.GetSpeedMultiplier(userId)
	local multiplier = 1.0
	
	for _, effect in pairs(StatusEffects.GetAllEffects(userId)) do
		if effect.type == EFFECT_TYPES.SLOW then
			multiplier = multiplier * (1 - effect.data.slowPercent)
		elseif effect.type == EFFECT_TYPES.BUFF_SPEED then
			multiplier = multiplier * effect.data.multiplier
		end
	end
	
	return multiplier
end

-- === Очистка при выходе игрока ===

function StatusEffects.ClearPlayer(userId)
	activeEffects[userId] = nil
	print("[StatusEffects] Cleared all effects for user", userId)
end

-- === Heartbeat: обработка DoT (damage over time) и истечения времени ===

local lastUpdate = tick()
RunService.Heartbeat:Connect(function()
	local now = tick()
	local dt = now - lastUpdate
	
	if dt < 0.1 then return end -- обновляем раз в 0.1 сек
	lastUpdate = now
	
	for userId, effects in pairs(activeEffects) do
		for effectId, effect in pairs(effects) do
			-- Проверка истечения времени
			if now - effect.startTick >= effect.duration then
				removeEffect(userId, effectId)
			else
				-- DoT обработка
				if effect.type == EFFECT_TYPES.BURN or effect.type == EFFECT_TYPES.POISON then
					if now - effect.data.lastTick >= 1.0 then -- тик раз в секунду
						effect.data.lastTick = now
						
						-- Вызываем урон (должно быть подключено из CombatSystem)
						local CombatSystem = require(script.Parent.CombatSystem)
						local player = game.Players:GetPlayerByUserId(userId)
						if player and CombatSystem.dealDamageToPlayer then
							CombatSystem.dealDamageToPlayer(userId, effect.data.damagePerTick, "DoT")
							print("[StatusEffects]", effect.type, "dealt", effect.data.damagePerTick, "damage to", userId)
						end
					end
				end
			end
		end
	end
end)

print("[StatusEffects] System initialized")

return StatusEffects
