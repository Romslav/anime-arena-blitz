-- SkillSystem.server.lua | Anime Arena: Blitz
-- DEPRECATED: Скиллы перенесены в SkillHandlers.lua + CombatSystem.server.lua
-- Этот файл не содержит логики и не слушает UseSkill Remote.
-- Хранится для обратной совместимости.

-- Публичный API для старых ссылок: проксируем на CombatSystem
task.defer(function()
	local ok = false
	for _ = 1, 20 do
		if _G.CombatSystem then ok = true; break end
		task.wait(0.5)
	end
	if ok then
		_G.SkillSystem = {
			AddUltCharge  = function(userId, amount)
				-- управляется через CombatSystem
			end,
			GetUltCharge  = function(userId)
				local s = _G.CombatSystem.getState(userId)
				return s and s.ultCharge or 0
			end,
			ResetUltCharge = function(userId) end,
		}
		print("[SkillSystem] Proxied to CombatSystem ✓")
	else
		warn("[SkillSystem] CombatSystem not found!")
	end
end)
