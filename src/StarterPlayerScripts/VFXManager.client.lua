-- VFXManager.client.lua | Anime Arena: Blitz
-- DISABLED — FIX-2/3: этот LocalScript дублировал слушатель UpdateEffect,
-- вызывая двойной статус-VFX (Highlight + BillboardGui появлялись дважды).
--
-- Вся логика статусных и скилл-VFX теперь централизована:
--   • SkillVFXController.client.lua  — единственный LocalScript-слушатель ремоутов
--   • VFXManager.lua (ModuleScript)  — вся реализация эффектов (require из SkillVFXController)
--
-- Этот файл оставлен пустым чтобы не сломать Rojo-маппинг.
print("[VFXManager.client] DISABLED — VFX handled by SkillVFXController + VFXManager module")
