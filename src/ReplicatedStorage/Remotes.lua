-- Remotes.lua | Anime Arena: Blitz
-- Авторитетный справочник всех Remote-объектов игры.
-- НЕ создаёт объекты самостоятельно — это делает RemotesInitializer.server.lua.
-- Используй require(), чтобы получить полный список имён для валидации.

local Remotes = {}

-- ============================================================
-- RemoteEvent-ы  (сервер ↔ клиент)
-- ============================================================

Remotes.EVENTS = {

	-- [ВЫБОР ГЕРОЯ]
	"SelectHero",			-- client  → server : игрок выбрал героя (heroId)
	"HeroSelected",			-- server  → client : подтверждение (heroId)
	"CharacterSpawned",		-- server  → client : герой заспавнен (heroId, mode)

	-- [ПОТОК МАТЧА]
	"MatchStart",			-- server  → client : матч начался (mode)
	"MatchEnd",				-- server  → client : матч закончился (resultData)
	"RoundStart",			-- server  → client : фаза Battle началась (leftHeroId, leftName, rightHeroId, rightName, mode)
	"RoundEnd",				-- server  → client : фаза Battle кончилась (resultData)
	"RoundTimer",			-- server  → client : тик таймера (seconds)
	"RoundStateChanged",	-- server  → client : смена фазы (phase: "Waiting"|"Preparation"|"Battle"|"Conclusion")

	-- [МАТЧМЕЙКИНГ]
	"JoinQueue",			-- client  → server : войти в очередь (mode)
	"LeaveQueue",			-- client  → server : выйти из очереди
	"MatchFound",			-- server  → client : матч найден (matchInfo: {matchId, mode})
	"QueueStatus",			-- server  → client : позиция в очереди (position, total)

	-- [БОЙ — ввод]
	"UseSkill",				-- client  → server : скилл (slot: "Q"|"E"|"F"|"R", mousePos: Vector3)
	"M1Attack",				-- client  → server : базовая атака (mousePos: Vector3)

	-- [БОЙ — фидбек]
	"SkillResult",			-- server  → client : (slot, success, cdTime, reason)
	"SkillUsed",			-- server  → all    : VFX broadcast (userId, slot, heroId, targetPos)
	"TakeDamage",			-- server  → client : (newHP, maxHP, amount, dmgType, attackerUserId)
	"UpdateHP",				-- server  → client : (hp, maxHP)  — резервный канал
	"Heal",					-- server  → client : (amount)
	"PlayerDied",			-- server  → all    : (victimUserId, killerUserId, respawnTime)
	"PlayerRespawned",		-- server  → client : игрок возродился

	-- [УЛЬТ ЗАРЯД]
	"UltCharge",			-- server  → client : (charge: 0..100)
	"ChargeUlt",			-- server  → client : alias для UltCharge

	-- [СТАТУС ЭФФЕКТЫ]
	"UpdateEffect",			-- server  → client : (effectType, isActive, duration)
	"StatusEffectApplied",	-- server  → client : (effectType, duration)
	"StatusEffectRemoved",	-- server  → client : (effectType)

	-- [HUD & UI]
	"UpdateHUD",			-- server  → client : (hudDataTable)
	"UpdateSkillCooldowns",	-- server  → client : ({Q,E,F,R} реальные кулдауны героя при старте матча
	"ShowKillFeed",			-- server  → all    : (killerName, victimName)
	"ShowNotification",		-- server  → client : (message, colorOrType)

	-- [VFX]
	"SkillVFX",				-- server  → all    : (userId, slot, targetPos, extra)
	"UltimateVFX",			-- server  → all    : (userId, heroId)

	-- [РЕЗУЛЬТАТЫ МАТЧА]
	"ShowMatchResults",		-- server  → client : (fullResultData)
	"RankUpdate",			-- server  → client : (oldRank, newRank, newRP)
}

-- ============================================================
-- RemoteFunction-ы
-- ============================================================

Remotes.FUNCTIONS = {
	"GetPlayerData",		-- client  → server : () → {rp, coins, heroId, rank}
	"GetLeaderboard",		-- client  → server : (mode) → [{name, rp, rank}]
}

-- ============================================================
-- УТИЛИТА: проверка соответствия с RemotesInitializer
-- (вызывается из сервера при старте для раннего обнаружения расхождений)
-- ============================================================

function Remotes.Validate(remotesFolder)
	if not remotesFolder then return end
	local missing = {}
	for _, name in ipairs(Remotes.EVENTS) do
		if not remotesFolder:FindFirstChild(name) then
			table.insert(missing, "EVENT:" .. name)
		end
	end
	for _, name in ipairs(Remotes.FUNCTIONS) do
		if not remotesFolder:FindFirstChild(name) then
			table.insert(missing, "FUNC:" .. name)
		end
	end
	if #missing > 0 then
		warn("[Remotes.Validate] Missing remotes:\n  " .. table.concat(missing, "\n  "))
	else
		print(string.format("[Remotes] All %d events + %d functions present ✓",
			#Remotes.EVENTS, #Remotes.FUNCTIONS))
	end
	return #missing == 0
end

return Remotes
