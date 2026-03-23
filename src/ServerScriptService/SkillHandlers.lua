-- SkillHandlers.lua | Anime Arena: Blitz
-- Полная логика скиллов всех 12 героев.
-- Слоты: Q (скилл 1), E (скилл 2), F (скилл 3), R (ульт)
-- API: SkillHandlers[heroId][slot](player, targetPos, api)
--   api.dealDamage(attacker, victim, amount, dmgType)
--   api.getState(userId) → combatState
--   api.fireTo(player, remote, ...)  — server→client

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatusEffects = require(script.Parent.StatusEffects)

local SkillHandlers = {}

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================

--- FIX #5: безопасно получить UserId для бота или реального игрока
local function getUID(p)
	if type(p) == "table" and p._isBot then
		return _G.TestBot and _G.TestBot.getUserId and _G.TestBot.getUserId() or nil
	end
	if typeof(p) == "Instance" and p:IsA("Player") then
		return p.UserId
	end
	return nil
end

--- Вернуть HumanoidRootPart участника (работает для бота и игрока)
local function getHRP(p)
	if type(p) == "table" and p._isBot then
		local m = _G.TestBot and _G.TestBot.getModel and _G.TestBot.getModel()
		return m and m:FindFirstChild("HumanoidRootPart")
	end
	local char = p.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

--- Все участники матча в радиусе (включая бота)
local function inRange(origin, range, excludeUserId, matchId, api)
	local targets = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == excludeUserId then continue end
		local state = api.getState(p.UserId)
		if not state or not state.alive then continue end
		if matchId and state.matchId ~= matchId then continue end
		local hrp = getHRP(p)
		if hrp and (hrp.Position - origin).Magnitude <= range then
			table.insert(targets, p)
		end
	end
	if _G.TestBot then
		local botId = _G.TestBot.getUserId and _G.TestBot.getUserId() or -1
		if botId ~= excludeUserId then
			local state = api.getState(botId)
			if state and state.alive and (not matchId or state.matchId == matchId) then
				local hrp = getHRP(_G.TestBot.getProxy and _G.TestBot.getProxy())
				if hrp and (hrp.Position - origin).Magnitude <= range then
					table.insert(targets, _G.TestBot.getProxy())
				end
			end
		end
	end
	return targets
end

--- Ближайший участник (включая бота)
local function nearest(player, range, matchId, api)
	local pId = getUID(player)
	local origin
	if type(player) == "table" and player._isBot then
		local hrp = getHRP(player)
		if not hrp then return nil end
		origin = hrp.Position
	else
		local char = player.Character
		if not char then return nil end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return nil end
		origin = hrp.Position
	end
	local best, bestDist = nil, math.huge
	for _, t in ipairs(inRange(origin, range, pId, matchId, api)) do
		local tHRP = getHRP(t)
		if tHRP then
			local d = (tHRP.Position - origin).Magnitude
			if d < bestDist then bestDist = d; best = t end
		end
	end
	return best
end

--- Телепортировать за спину цели
local function teleportBehind(attacker, target)
	local tHRP = getHRP(target)
	local aHRP = getHRP(attacker)
	if not tHRP or not aHRP then return end
	aHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 2.5)
end

--- Отбросить персонажа вверх
local function launch(target, height)
	local hrp = getHRP(target)
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.new(
			hrp.AssemblyLinearVelocity.X,
			height or 60,
			hrp.AssemblyLinearVelocity.Z
		)
	end
end

-- ============================================================
-- 1. FLAME RONIN  — Bruiser / Урон / Обычный
-- ============================================================

SkillHandlers.FlameRonin = {
	Q = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local hrp = char.HumanoidRootPart
		hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 14
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(hrp.Position, 7, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 10, "Normal")
			StatusEffects.ApplyBurn(tId, 3, 2)
		end
	end,
	E = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 9, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 12, "Normal")
			launch(t, 55)
			StatusEffects.ApplyStun(tId, 0.6)
		end
	end,
	F = function(player, targetPos, api)
		StatusEffects.ApplyShield(player.UserId, 30, 3)
		StatusEffects.ApplyBuff(player.UserId, "DamageBoost", 1.3, 4)
	end,
	R = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 16, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 38, "Ultimate")
			StatusEffects.ApplyBurn(tId, 6, 4)
			launch(t, 40)
		end
	end,
}

-- ============================================================
-- 2. VOID ASSASSIN — Assassin / Легендарный
-- ============================================================

SkillHandlers.VoidAssassin = {
	Q = function(player, targetPos, api)
		local state = api.getState(player.UserId)
		local target = nearest(player, 22, state and state.matchId, api)
		if not target then return end
		teleportBehind(player, target)
		api.dealDamage(player, target, 14, "Normal")
	end,
	E = function(player, targetPos, api)
		StatusEffects.ApplyBuffSpeed(player.UserId, 2.0, 2.5)
		local char = player.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then part.Transparency = 0.85 end
			end
			task.delay(2.5, function()
				if not char.Parent then return end
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
						part.Transparency = 0
					end
				end
			end)
		end
	end,
	F = function(player, targetPos, api)
		local state = api.getState(player.UserId)
		local target = nearest(player, 18, state and state.matchId, api)
		if not target then return end
		local tId = getUID(target)
		if not tId then return end
		StatusEffects.ApplyDebuff(tId, "VoidMarked", 1.4, 5)
		api.dealDamage(player, target, 8, "Normal")
	end,
	R = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 12, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			local tState = api.getState(tId)
			local dmg = 44
			if tState and tState.maxHp > 0 and (tState.hp / tState.maxHp) < 0.3 then
				dmg = dmg * 1.6
			end
			api.dealDamage(player, t, dmg, "Ultimate")
			StatusEffects.ApplySlow(tId, 0.5, 3)
		end
	end,
}

-- ============================================================
-- 3. THUNDER MONK — Controller / Редкий
-- ============================================================

SkillHandlers.ThunderMonk = {
	Q = function(player, targetPos, api)
		local state = api.getState(player.UserId)
		local target = nearest(player, 14, state and state.matchId, api)
		if not target then return end
		local tId = getUID(target)
		if not tId then return end
		api.dealDamage(player, target, 11, "Normal")
		StatusEffects.ApplyStun(tId, 0.9)
	end,
	E = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 14, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 7, "Normal")
			StatusEffects.ApplyStun(tId, 1.1)
		end
	end,
	F = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local hrp = char.HumanoidRootPart
		hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 12
		StatusEffects.ApplyBuff(player.UserId, "UltChargeBoost", 2.0, 3)
	end,
	R = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 26, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 32, "Ultimate")
			StatusEffects.ApplyStun(tId, 1.8)
		end
	end,
}

-- ============================================================
-- 4. IRON TITAN — Tank / Редкий
-- ============================================================

SkillHandlers.IronTitan = {
	Q = function(player, targetPos, api)
		local state = api.getState(player.UserId)
		local target = nearest(player, 10, state and state.matchId, api)
		if not target then return end
		api.dealDamage(player, target, 14, "Normal")
		launch(target, 45)
	end,
	E = function(player, targetPos, api)
		StatusEffects.ApplyShield(player.UserId, 60, 5)
		StatusEffects.ApplyBuff(player.UserId, "DamageReduction", 0.5, 5)
	end,
	F = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 12, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 9, "Normal")
			StatusEffects.ApplySlow(tId, 0.45, 3)
		end
	end,
	R = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 20, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 42, "Ultimate")
			StatusEffects.ApplyStun(tId, 1.5)
			StatusEffects.ApplySlow(tId, 0.4, 4)
		end
	end,
}

-- ============================================================
-- 5. SCARLET ARCHER — Ranged / Редкий
-- ============================================================

SkillHandlers.ScarletArcher = {
	Q = function(player, targetPos, api)
		if not targetPos then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(targetPos, 10, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 9, "Normal")
			StatusEffects.ApplySlow(tId, 0.55, 2)
		end
	end,
	E = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 40, player.UserId, state and state.matchId, api)) do
			api.dealDamage(player, t, 13, "Normal")
		end
	end,
	F = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local hrp = char.HumanoidRootPart
		hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * -10
		StatusEffects.ApplyBuff(player.UserId, "DamageReduction", 0.6, 1.5)
	end,
	R = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 35, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 28, "Ultimate")
			StatusEffects.ApplyBurn(tId, 4, 5)
			StatusEffects.ApplySlow(tId, 0.5, 4)
		end
	end,
}

-- ============================================================
-- 6. ECLIPSE HERO — Assassin / Легендарный
-- ============================================================

SkillHandlers.EclipseHero = {
	Q = function(player, targetPos, api)
		local state = api.getState(player.UserId)
		local target = nearest(player, 12, state and state.matchId, api)
		if not target then return end
		local tId = getUID(target)
		if not tId then return end
		api.dealDamage(player, target, 13, "Normal")
		StatusEffects.ApplyDebuff(tId, "Blind", 1.0, 1.5)
	end,
	E = function(player, targetPos, api)
		local state = api.getState(player.UserId)
		local target = nearest(player, 20, state and state.matchId, api)
		if target then teleportBehind(player, target) end
		StatusEffects.ApplyBuff(player.UserId, "DamageBoost", 1.5, 3)
	end,
	F = function(player, targetPos, api)
		StatusEffects.ApplyBuffSpeed(player.UserId, 1.8, 3)
		local char = player.Character
		if char then
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") then p.Transparency = 0.9 end
			end
			task.delay(3, function()
				if not char.Parent then return end
				for _, p in ipairs(char:GetDescendants()) do
					if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
						p.Transparency = 0
					end
				end
			end)
		end
	end,
	R = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 18, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 46, "Ultimate")
			StatusEffects.ApplyDebuff(tId, "Blind", 1.0, 3)
		end
	end,
}

-- ============================================================
-- 7. STORM DANCER — Skirmisher / Обычный
-- ============================================================

SkillHandlers.StormDancer = {
	Q = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local hrp = char.HumanoidRootPart
		hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 16
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(hrp.Position, 6, player.UserId, state and state.matchId, api)) do
			api.dealDamage(player, t, 10, "Normal")
		end
	end,
	E = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local origin = char.HumanoidRootPart.Position
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(origin, 13, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 8, "Normal")
			-- Knockback — отбрасываем от центра
			local tHRP = getHRP(t)
			if tHRP then
				local dir = (tHRP.Position - origin).Unit
				tHRP.AssemblyLinearVelocity = dir * 55 + Vector3.new(0, 20, 0)
			end
		end
	end,
	F = function(player, targetPos, api)
		StatusEffects.ApplyBuffSpeed(player.UserId, 1.6, 3)
		StatusEffects.ApplyBuff(player.UserId, "DamageBoost", 1.2, 3)
	end,
	R = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 20, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 30, "Ultimate")
			StatusEffects.ApplySlow(tId, 0.5, 3)
			StatusEffects.ApplyBurn(tId, 3, 2)
		end
	end,
}

-- ============================================================
-- 8. BLOOD SAGE — Mage / Легендарный
-- ============================================================

SkillHandlers.BloodSage = {
	Q = function(player, targetPos, api)
		local state = api.getState(player.UserId)
		local target = nearest(player, 30, state and state.matchId, api)
		if not target then return end
		api.dealDamage(player, target, 16, "Normal")
		api.heal(player, 6)
	end,
	E = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 12, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 10, "Normal")
			StatusEffects.ApplyRoot(tId, 1.5)
		end
	end,
	F = function(player, targetPos, api)
		local pState = api.getState(player.UserId)
		local sacrificeHp = pState and math.floor(pState.hp * 0.15) or 10
		api.heal(player, -sacrificeHp)  -- "урон" самому себе через heal с отрицательным числом
		StatusEffects.ApplyBuff(player.UserId, "DamageBoost", 1.6, 5)
	end,
	R = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 22, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 48, "Ultimate")
			StatusEffects.ApplyBurn(tId, 5, 4)
			api.heal(player, 15)
		end
	end,
}

-- ============================================================
-- 9. CRYSTAL GUARD — Tank / Редкий
-- ============================================================

SkillHandlers.CrystalGuard = {
	Q = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 9, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 12, "Normal")
			StatusEffects.ApplySlow(tId, 0.4, 2)
		end
	end,
	E = function(player, targetPos, api)
		StatusEffects.ApplyShield(player.UserId, 80, 6)
	end,
	F = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local hrp = char.HumanoidRootPart
		hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 12
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(hrp.Position, 6, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 15, "Normal")
			StatusEffects.ApplyStun(tId, 0.7)
		end
	end,
	R = function(player, targetPos, api)
		StatusEffects.ApplyShield(player.UserId, 120, 8)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 14, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 36, "Ultimate")
			StatusEffects.ApplySlow(tId, 0.35, 5)
		end
	end,
}

-- ============================================================
-- 10. SHADOW TWIN — Support / Эпический
-- ============================================================

SkillHandlers.ShadowTwin = {
	Q = function(player, targetPos, api)
		local state = api.getState(player.UserId)
		local target = nearest(player, 11, state and state.matchId, api)
		if not target then return end
		api.dealDamage(player, target, 8, "Normal")
		task.delay(0.3, function()
			local t2 = nearest(player, 11, state and state.matchId, api)
			if t2 then api.dealDamage(player, t2, 8, "Normal") end
		end)
	end,
	E = function(player, targetPos, api)
		StatusEffects.ApplyBuff(player.UserId, "CloneActive", 1.0, 5)
		StatusEffects.ApplyBuff(player.UserId, "DamageBoost", 1.25, 5)
	end,
	F = function(player, targetPos, api)
		local char = player.Character
		if char then
			local hrp = char.HumanoidRootPart
			hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 18
		end
		api.heal(player, 20)
	end,
	R = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 16, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			local tState = api.getState(tId)
			local mirrorDmg = tState and (tState.maxHp - tState.hp) * 0.4 or 30
			api.dealDamage(player, t, math.max(mirrorDmg, 25), "Ultimate")
		end
	end,
}

-- ============================================================
-- 11. NEON BLITZ — Ranged / Эпический
-- ============================================================

SkillHandlers.NeonBlitz = {
	Q = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 14, player.UserId, state and state.matchId, api)) do
			api.dealDamage(player, t, 11, "Normal")
		end
	end,
	E = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local hrp = char.HumanoidRootPart
		hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 20
		StatusEffects.ApplyBuff(player.UserId, "DamageBoost", 1.2, 2)
	end,
	F = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 10, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 9, "Normal")
			StatusEffects.ApplyStun(tId, 0.8)
		end
	end,
	R = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 22, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 34, "Ultimate")
			StatusEffects.ApplyStun(tId, 1.0)
		end
		StatusEffects.ApplyBuffSpeed(player.UserId, 1.5, 4)
	end,
}

-- ============================================================
-- 12. JADE SENTINEL — Duelist / Редкий
-- ============================================================

SkillHandlers.JadeSentinel = {
	Q = function(player, targetPos, api)
		local state = api.getState(player.UserId)
		local target = nearest(player, 11, state and state.matchId, api)
		if not target then return end
		local tId = getUID(target)
		if not tId then return end
		api.dealDamage(player, target, 13, "Normal")
		StatusEffects.ApplySlow(tId, 0.5, 2)
	end,
	E = function(player, targetPos, api)
		StatusEffects.ApplyBuff(player.UserId, "Parry", 1.0, 1.5)
		StatusEffects.ApplyShield(player.UserId, 25, 1.5)
	end,
	F = function(player, targetPos, api)
		local char = player.Character
		if not char then return end
		local state = api.getState(player.UserId)
		for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 11, player.UserId, state and state.matchId, api)) do
			local tId = getUID(t)
			if not tId then continue end
			api.dealDamage(player, t, 14, "Normal")
			StatusEffects.ApplySlow(tId, 0.45, 2)
		end
	end,
	R = function(player, targetPos, api)
		local state = api.getState(player.UserId)
		local target = nearest(player, 13, state and state.matchId, api)
		if not target then return end
		local tId = getUID(target)
		if not tId then return end
		local tState = api.getState(tId)
		local dmg = 40
		if tState and tState.jadeHits and tState.jadeHits > 0 then
			dmg = dmg * (1 + math.min(tState.jadeHits, 3) * 0.2)
		end
		api.dealDamage(player, target, dmg, "Ultimate")
		StatusEffects.ApplyStun(tId, 1.2)
		if tState then tState.jadeHits = 0 end
	end,
}

-- ============================================================
-- FALLBACK для героев без реализации
-- ============================================================

function SkillHandlers.GetHandler(heroId)
	if SkillHandlers[heroId] then
		return SkillHandlers[heroId]
	end
	return {
		Q = function(player, targetPos, api)
			local state = api.getState(player.UserId)
			local target = nearest(player, 12, state and state.matchId, api)
			if target then api.dealDamage(player, target, 10, "Normal") end
		end,
		E = function(player, targetPos, api)
			local char = player.Character
			if not char then return end
			local state = api.getState(player.UserId)
			for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 10, player.UserId, state and state.matchId, api)) do
				api.dealDamage(player, t, 8, "Normal")
			end
		end,
		F = function(player, targetPos, api)
			StatusEffects.ApplyShield(player.UserId, 20, 3)
		end,
		R = function(player, targetPos, api)
			local char = player.Character
			if not char then return end
			local state = api.getState(player.UserId)
			for _, t in ipairs(inRange(char.HumanoidRootPart.Position, 18, player.UserId, state and state.matchId, api)) do
				api.dealDamage(player, t, 35, "Ultimate")
			end
		end,
	}
end

return SkillHandlers
