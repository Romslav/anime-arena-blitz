-- SkillVFX.client.lua | Anime Arena: Blitz
-- DISABLED — FIX-2/3: этот LocalScript дублировал слушатель SkillVFX-ремоута,
-- вызывая двойной скилл-VFX (партиклы + ring создавались дважды).
--
-- SkillVFX-ремоут обрабатывается в SkillVFXController.client.lua,
-- который вызывает VFXManager.PlaySkillVFX() — более богатые партиклы + trail для рывков.
--
-- Этот файл оставлен пустым чтобы не сломать Rojo-маппинг.
print("[SkillVFX.client] DISABLED — VFX handled by SkillVFXController + VFXManager module")
