-- RoundSystem.server.lua | Anime Arena: Blitz
-- DEPRECATED: Функциональность перенесена в RoundService.server.lua.
-- Этот файл сохранён для обратной совместимости и не содержит логики.
-- Используйте _G.RoundService для запуска раундов.

-- Ожидаем инициализации RoundService
task.defer(function()
	local ok = false
	for _ = 1, 20 do
		if _G.RoundService then ok = true; break end
		task.wait(0.5)
	end
	if ok then
		print("[RoundSystem] → Redirected to RoundService ✓")
	else
		warn("[RoundSystem] RoundService not found after 10s!")
	end
end)
