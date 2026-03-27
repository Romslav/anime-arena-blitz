-- AwakeningTree.lua | Anime Arena: Blitz
-- Полная система Awakening Tree для всех 12 героев.
-- Shared-модуль: используется и сервером (валидация, покупка) и клиентом (UI).
--
-- Каждый герой имеет 3 ветки по 5 узлов.
-- Узлы открываются по Mastery Level (ключ) и покупаются за Mastery Shards (цена).
--
-- Эффекты описываются data-driven:
--   { type="stat",     stat="m1Damage",   op="mult", value=1.08  }
--   { type="stat",     stat="hp",         op="add",  value=15    }
--   { type="cooldown", skill="Q",         op="add",  value=-1    }
--   { type="cooldown", skill="R",         op="mult", value=0.85  }
--   { type="ability",  skill="Q", param="damage", op="add", value=3 }
--   { type="ability",  skill="Q", param="radius", op="mult", value=1.2 }
--   { type="passive",  key="phoenix_rebirth", params={...}        }
--
-- Правила комбинирования:
--   Mastery 1–4:  только узлы ОДНОЙ ветки
--   Mastery 5:    один узел из второй ветки (первые 2 ноды)
--   Mastery 7:    две ветки параллельно
--   Mastery 9:    один LV9 passive из третьей ветки
--   Prestige:     сброс → 50% Shards → счётчик +1; P5 → перманентный пассив

local AwakeningTree = {}

-- ============================================================
-- ПРАВИЛА КОМБИНИРОВАНИЯ ВЕТОК
-- ============================================================

--- Проверяет, можно ли купить узел nodeId при текущем наборе купленных узлов.
--- @param heroId string
--- @param nodeId string — ID нового узла
--- @param ownedNodes table — { [nodeId]=true, ... }
--- @param masteryLevel number
--- @return boolean, string — ok, errorReason
function AwakeningTree.CanBuyNode(heroId, nodeId, ownedNodes, masteryLevel)
	local heroDef = AwakeningTree.Heroes[heroId]
	if not heroDef then return false, "unknown_hero" end

	local nodeDef = nil
	for _, node in ipairs(heroDef) do
		if node.id == nodeId then nodeDef = node; break end
	end
	if not nodeDef then return false, "unknown_node" end

	-- Уже куплен
	if ownedNodes[nodeId] then return false, "already_owned" end

	-- Проверка уровня мастерства
	if masteryLevel < nodeDef.lvReq then
		return false, string.format("need_mastery_%d", nodeDef.lvReq)
	end

	-- Проверка порядка в ветке: нужно иметь предыдущий узел той же ветки
	local myBranch = nodeDef.branch
	local myOrder  = nodeDef.order or 1
	if myOrder > 1 then
		-- Ищем предыдущий узел в той же ветке
		local prevFound = false
		for _, n in ipairs(heroDef) do
			if n.branch == myBranch and n.order == myOrder - 1 then
				if ownedNodes[n.id] then
					prevFound = true
				end
				break
			end
		end
		if not prevFound then
			return false, "need_previous_node"
		end
	end

	-- Собираем информацию о ветках
	local branchCounts = {} -- [branch] = count of owned nodes
	for _, n in ipairs(heroDef) do
		if ownedNodes[n.id] then
			branchCounts[n.branch] = (branchCounts[n.branch] or 0) + 1
		end
	end
	-- Также считаем новый узел
	branchCounts[myBranch] = (branchCounts[myBranch] or 0) + 1

	-- Сколько веток задействовано (с новым узлом)
	local usedBranches = {}
	for branch, count in pairs(branchCounts) do
		if count > 0 then
			table.insert(usedBranches, { branch = branch, count = count })
		end
	end
	local numBranches = #usedBranches

	-- Ранняя игра (Mastery < 5): только одна ветка
	if masteryLevel < 5 and numBranches > 1 then
		return false, "one_branch_until_mastery_5"
	end

	-- Mastery 5–6: одна основная + один узел (order 1 или 2) из второй ветки
	if masteryLevel >= 5 and masteryLevel < 7 and numBranches > 2 then
		return false, "max_two_branches_at_mastery_5"
	end
	if masteryLevel >= 5 and masteryLevel < 7 and numBranches == 2 then
		-- Найти «вторую» ветку — та с меньшим количеством узлов
		table.sort(usedBranches, function(a, b) return a.count > b.count end)
		local secondary = usedBranches[2]
		-- Второстепенная ветка: максимум 1 узел, и это должен быть order 1 или 2
		if secondary.count > 1 then
			return false, "secondary_branch_max_1_node_before_mastery_7"
		end
		-- Новый узел — он из вторичной ветки?
		if myBranch == secondary.branch then
			if myOrder > 2 then
				return false, "secondary_branch_only_first_2_nodes_before_mastery_7"
			end
		end
	end

	-- Mastery 7–8: две ветки полностью, третья закрыта
	if masteryLevel >= 7 and masteryLevel < 9 and numBranches > 2 then
		return false, "max_two_branches_before_mastery_9"
	end

	-- Mastery 9+: третья ветка: только один LV9 passive (order 5)
	if masteryLevel >= 9 and numBranches == 3 then
		-- Найти третью ветку (минимум узлов)
		table.sort(usedBranches, function(a, b) return a.count > b.count end)
		local tertiary = usedBranches[3]
		if tertiary.count > 1 then
			return false, "third_branch_only_one_lv9_passive"
		end
		if myBranch == tertiary.branch and myOrder ~= 5 then
			return false, "third_branch_only_lv9_passive_node"
		end
	end

	return true, "ok"
end

--- Подсчитать стоимость сброса (200 shards) и возврат (50% вложенных)
function AwakeningTree.CalcResetRefund(heroId, ownedNodes)
	local heroDef = AwakeningTree.Heroes[heroId]
	if not heroDef then return 0 end
	local totalSpent = 0
	for _, node in ipairs(heroDef) do
		if ownedNodes[node.id] then
			totalSpent = totalSpent + node.cost
		end
	end
	return math.floor(totalSpent * 0.5)
end

local RESET_COST = 200

function AwakeningTree.GetResetCost()
	return RESET_COST
end

--- Собирает все эффекты активных узлов для применения в бою
function AwakeningTree.CollectEffects(heroId, ownedNodes)
	local heroDef = AwakeningTree.Heroes[heroId]
	if not heroDef then return {} end
	local effects = {}
	for _, node in ipairs(heroDef) do
		if ownedNodes[node.id] and node.effects then
			for _, eff in ipairs(node.effects) do
				table.insert(effects, eff)
			end
		end
	end
	return effects
end

--- Получить список веток героя
function AwakeningTree.GetBranches(heroId)
	local heroDef = AwakeningTree.Heroes[heroId]
	if not heroDef then return {} end
	local seen = {}
	local branches = {}
	for _, node in ipairs(heroDef) do
		if not seen[node.branch] then
			seen[node.branch] = true
			table.insert(branches, node.branch)
		end
	end
	return branches
end

-- ============================================================
-- PRESTIGE 5 ПАССИВКИ (перманентные, не сбрасываются)
-- ============================================================

AwakeningTree.Prestige5 = {
	FlameRonin    = { key = "undying_flame",       desc = "Phoenix Cut при убийстве: +30 HP + x2 следующий M1" },
	VoidAssassin  = { key = "void_convergence",    desc = "Silent Execution при убийстве: сброс ВСЕХ кулдаунов" },
	ThunderMonk   = { key = "eye_of_the_storm",    desc = "Heavenly Judgment создаёт шаровую молнию на 5с (5 урона/0.5с)" },
	IronTitan     = { key = "unstoppable_force",   desc = "Titan Fall даёт 3с полной неуязвимости" },
	ScarletArcher = { key = "crimson_last_stand",   desc = "При HP<20%: ульта мгновенный кулдаун + x1.5 урона (1 раз)" },
	EclipseHero   = { key = "eternal_eclipse",     desc = "Dark Veil активируется пассивно при бездействии 3с" },
	StormDancer   = { key = "eye_of_the_cyclone",  desc = "Cyclone Fury зона: +3 стака/сек + Speed 30% (5с)" },
	BloodSage     = { key = "crimson_apotheosis",  desc = "Blood Moon при убийстве: +50 HP + сброс всех CD" },
	CrystalGuard  = { key = "living_crystal",      desc = "Crystal Stacks → 30% рефлект следующего удара" },
	ShadowTwin    = { key = "perfect_reflection",  desc = "Клон рефлектит 50% атак 3с" },
	NeonBlitz     = { key = "system_overload",     desc = "Overdrive при Mega Pulse: x2 урон + электрополе 4с" },
	JadeSentinel  = { key = "jade_enlightenment",  desc = "Perfect Parry всегда сбрасывает Jade Strike, x2.5 урона" },
}

-- ============================================================
-- ОПРЕДЕЛЕНИЯ УЗЛОВ ДЛЯ ВСЕХ 12 ГЕРОЕВ
-- ============================================================
-- Порядок полей: id, branch, order (1–5), lvReq, cost, name, desc, effects

AwakeningTree.Heroes = {}

-- ────────────────────────────────────────────────────────────
-- 1. FLAME RONIN
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.FlameRonin = {
	-- ПУТЬ КЛИНКА
	{ id="blade_1", branch="blade", order=1, lvReq=1, cost=20,
	  name="Горящий Клинок", desc="M1 урон +8%",
	  effects={ {type="stat", stat="m1Damage", op="mult", value=1.08} } },
	{ id="blade_2", branch="blade", order=2, lvReq=3, cost=40,
	  name="Огненная Печать", desc="Каждый 5-й M1: +15 урона + Burn 2с",
	  effects={ {type="passive", key="flame_strike_5th", params={extraDmg=15, burnDur=2}} } },
	{ id="blade_3", branch="blade", order=3, lvReq=5, cost=75,
	  name="Раскалённый Рывок", desc="Flame Dash: урон +3, кулдаун -1с",
	  effects={ {type="ability", skill="E", param="damage", op="add", value=3},
	            {type="cooldown", skill="E", op="add", value=-1} } },
	{ id="blade_4", branch="blade", order=4, lvReq=7, cost=90,
	  name="Финишер Инферно", desc="M1 комбо-финишер: Burn 3с (3 урона/тик)",
	  effects={ {type="passive", key="combo_finisher_burn", params={burnDur=3, burnDmg=3}} } },
	{ id="blade_5", branch="blade", order=5, lvReq=9, cost=125,
	  name="Власть над Пеплом", desc="PASSIVE: Пока враг горит — M1 +20%",
	  effects={ {type="passive", key="burn_bonus_m1", params={mult=1.20}} } },

	-- ПУТЬ ФЕНИКСА
	{ id="phoenix_1", branch="phoenix", order=1, lvReq=1, cost=20,
	  name="Долгий Ожог", desc="Burn длительность +1с",
	  effects={ {type="passive", key="burn_duration_bonus", params={bonus=1}} } },
	{ id="phoenix_2", branch="phoenix", order=2, lvReq=3, cost=40,
	  name="Жгучая Кровь", desc="Burn урон +1/тик",
	  effects={ {type="passive", key="burn_damage_bonus", params={bonus=1}} } },
	{ id="phoenix_3", branch="phoenix", order=3, lvReq=5, cost=75,
	  name="Пламенный Подъём", desc="Rising Slash по горящей цели: +25% урона",
	  effects={ {type="passive", key="rising_slash_burn_bonus", params={mult=1.25}} } },
	{ id="phoenix_4", branch="phoenix", order=4, lvReq=7, cost=90,
	  name="Пепельное Возрождение", desc="Phoenix Cut CD -8с. При активации: снимает Burn + 15 HP",
	  effects={ {type="cooldown", skill="R", op="add", value=-8},
	            {type="passive", key="phoenix_cut_heal", params={heal=15, cleanseBurn=true}} } },
	{ id="phoenix_5", branch="phoenix", order=5, lvReq=9, cost=125,
	  name="Феникс Не Умирает", desc="PASSIVE: 0 HP → Phoenix Rebirth: 1 HP + 3с неуязвимости (1 раз/матч)",
	  effects={ {type="passive", key="phoenix_rebirth", params={invulnDur=3}} } },

	-- ПУТЬ СТРАЖА
	{ id="guard_1", branch="guard", order=1, lvReq=1, cost=20,
	  name="Закалённое Тело", desc="HP +15",
	  effects={ {type="stat", stat="hp", op="add", value=15} } },
	{ id="guard_2", branch="guard", order=2, lvReq=3, cost=40,
	  name="Отражающее Пламя", desc="Burn Guard: следующие 2 атаки врага поджигают его",
	  effects={ {type="passive", key="burn_guard_reflect", params={charges=2, burnDur=2}} } },
	{ id="guard_3", branch="guard", order=3, lvReq=5, cost=75,
	  name="Инстинкт Воина", desc="При уроне >20 за удар — мгновенно +4 HP",
	  effects={ {type="passive", key="damage_threshold_heal", params={threshold=20, heal=4}} } },
	{ id="guard_4", branch="guard", order=4, lvReq=7, cost=90,
	  name="Быстрый Страж", desc="Burn Guard CD -3с",
	  effects={ {type="cooldown", skill="F", op="add", value=-3} } },
	{ id="guard_5", branch="guard", order=5, lvReq=9, cost=125,
	  name="Аура Живого Огня", desc="PASSIVE: Пока сам горит — Speed +2",
	  effects={ {type="passive", key="self_burn_speed", params={speedBonus=2}} } },
}

-- ────────────────────────────────────────────────────────────
-- 2. VOID ASSASSIN
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.VoidAssassin = {
	-- ПУТЬ ТЕНИ
	{ id="shadow_1", branch="shadow", order=1, lvReq=1, cost=20,
	  name="Теневой Клинок", desc="Blink Strike урон +2",
	  effects={ {type="ability", skill="Q", param="damage", op="add", value=2} } },
	{ id="shadow_2", branch="shadow", order=2, lvReq=3, cost=40,
	  name="Послесвечение Пустоты", desc="После Blink Strike — 0.5с невидимости",
	  effects={ {type="passive", key="blink_invis", params={dur=0.5}} } },
	{ id="shadow_3", branch="shadow", order=3, lvReq=5, cost=75,
	  name="Призрачный Обман", desc="Shadow Feint: 0.3с невидимости при использовании",
	  effects={ {type="passive", key="feint_invis", params={dur=0.3}} } },
	{ id="shadow_4", branch="shadow", order=4, lvReq=7, cost=90,
	  name="Метка Смерти", desc="Backstab Mark CD -2с",
	  effects={ {type="cooldown", skill="E", op="add", value=-2} } },
	{ id="shadow_5", branch="shadow", order=5, lvReq=9, cost=125,
	  name="Первый Удар", desc="PASSIVE: Первый удар после невидимости — крит +50%",
	  effects={ {type="passive", key="stealth_crit", params={critMult=1.5}} } },

	-- ПУТЬ ПУСТОТЫ
	{ id="void_1", branch="void", order=1, lvReq=1, cost=20,
	  name="Слабость Жертвы", desc="Backstab при HP<40% (было <30%)",
	  effects={ {type="passive", key="backstab_threshold", params={threshold=0.4}} } },
	{ id="void_2", branch="void", order=2, lvReq=3, cost=40,
	  name="Жестокость Пустоты", desc="Backstab бонус +10%",
	  effects={ {type="passive", key="backstab_bonus", params={bonusMult=0.1}} } },
	{ id="void_3", branch="void", order=3, lvReq=5, cost=75,
	  name="Тихая Казнь", desc="Silent Execution CD -8с",
	  effects={ {type="cooldown", skill="R", op="add", value=-8} } },
	{ id="void_4", branch="void", order=4, lvReq=7, cost=90,
	  name="Взрыв Пустоты", desc="После Silent Execution — 2с невидимость + M1 +30%",
	  effects={ {type="passive", key="execution_void_burst", params={invisDur=2, m1Mult=1.3}} } },
	{ id="void_5", branch="void", order=5, lvReq=9, cost=125,
	  name="Инстинкт Убийцы", desc="PASSIVE: Убийство → сброс CD Blink Strike",
	  effects={ {type="passive", key="kill_reset_blink", params={skill="Q"}} } },

	-- ПУТЬ КЛИНКА ПУСТОТЫ
	{ id="vblade_1", branch="vblade", order=1, lvReq=1, cost=20,
	  name="Лёгкие Ноги", desc="Speed +1",
	  effects={ {type="stat", stat="speed", op="add", value=1} } },
	{ id="vblade_2", branch="vblade", order=2, lvReq=3, cost=40,
	  name="Острый Ум", desc="M1 урон +10%",
	  effects={ {type="stat", stat="m1Damage", op="mult", value=1.10} } },
	{ id="vblade_3", branch="vblade", order=3, lvReq=5, cost=75,
	  name="Быстрые Руки", desc="Combo Window +80мс",
	  effects={ {type="stat", stat="comboWindow", op="add", value=80} } },
	{ id="vblade_4", branch="vblade", order=4, lvReq=7, cost=90,
	  name="Засада из Рывка", desc="Backstab Mark после Blink Strike: +20% бонус",
	  effects={ {type="passive", key="blink_backstab_bonus", params={bonusMult=0.2}} } },
	{ id="vblade_5", branch="vblade", order=5, lvReq=9, cost=125,
	  name="Клинок из Тьмы", desc="PASSIVE: Каждые 3 M1 — Void Flash: 6 урона (unblockable)",
	  effects={ {type="passive", key="void_flash", params={every=3, damage=6}} } },
}

-- ────────────────────────────────────────────────────────────
-- 3. THUNDER MONK
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.ThunderMonk = {
	-- ПУТЬ ГРОМА
	{ id="thunder_1", branch="thunder", order=1, lvReq=1, cost=20,
	  name="Оглушительный Удар", desc="Lightning Palm stun +0.1с",
	  effects={ {type="ability", skill="Q", param="stunDur", op="add", value=0.1} } },
	{ id="thunder_2", branch="thunder", order=2, lvReq=3, cost=40,
	  name="Громовое Кольцо", desc="Stun Ring: stun +0.2с, радиус +15%",
	  effects={ {type="ability", skill="E", param="stunDur", op="add", value=0.2},
	            {type="ability", skill="E", param="radius", op="mult", value=1.15} } },
	{ id="thunder_3", branch="thunder", order=3, lvReq=5, cost=75,
	  name="Разряженный Кулак", desc="3-й M1 Lightning Charge: +8 урона",
	  effects={ {type="passive", key="lightning_charge_dmg", params={extraDmg=8}} } },
	{ id="thunder_4", branch="thunder", order=4, lvReq=7, cost=90,
	  name="Окно Уязвимости", desc="При stun: 2с все атаки Monk +15%",
	  effects={ {type="passive", key="stun_vuln_window", params={dur=2, mult=1.15}} } },
	{ id="thunder_5", branch="thunder", order=5, lvReq=9, cost=125,
	  name="Небесная Молния", desc="PASSIVE: Враг под stun → Heavenly Judgment мгновенный каст",
	  effects={ {type="passive", key="instant_ult_on_stunned"} } },

	-- ПУТЬ МОНАХА
	{ id="monk_1", branch="monk", order=1, lvReq=1, cost=20,
	  name="Быстрый Шаг", desc="Step Dash CD -1с",
	  effects={ {type="cooldown", skill="F", op="add", value=-1} } },
	{ id="monk_2", branch="monk", order=2, lvReq=3, cost=40,
	  name="Щит Ветра", desc="Step Dash: 0.5с projectile immunity",
	  effects={ {type="passive", key="dash_proj_immune", params={dur=0.5}} } },
	{ id="monk_3", branch="monk", order=3, lvReq=5, cost=75,
	  name="Громовой Контрудар", desc="После Step Dash: M1 +12 урона",
	  effects={ {type="passive", key="dash_counter", params={extraDmg=12}} } },
	{ id="monk_4", branch="monk", order=4, lvReq=7, cost=90,
	  name="Двойной Шаг", desc="Step Dash: 2 заряда",
	  effects={ {type="ability", skill="F", param="charges", op="add", value=1} } },
	{ id="monk_5", branch="monk", order=5, lvReq=9, cost=125,
	  name="Молниеносный Парри", desc="PASSIVE: Perfect Parry → Lightning Charge без M1",
	  effects={ {type="passive", key="parry_lightning_charge"} } },

	-- ПУТЬ НЕБЕСНОГО СУДЬИ
	{ id="judge_1", branch="judge", order=1, lvReq=1, cost=20,
	  name="Сокращение Суда", desc="Heavenly Judgment CD -5с",
	  effects={ {type="cooldown", skill="R", op="add", value=-5} } },
	{ id="judge_2", branch="judge", order=2, lvReq=3, cost=40,
	  name="Цепная Молния", desc="Lightning Palm: дуга 50% урона по ближайшему",
	  effects={ {type="passive", key="chain_lightning", params={damagePct=0.5}} } },
	{ id="judge_3", branch="judge", order=3, lvReq=5, cost=75,
	  name="Небесный Канал", desc="Ult Charge Rate x1.2",
	  effects={ {type="stat", stat="ultChargeRate", op="mult", value=1.2} } },
	{ id="judge_4", branch="judge", order=4, lvReq=7, cost=90,
	  name="Суд с Оглушением", desc="Heavenly Judgment: stun 0.5с",
	  effects={ {type="passive", key="ult_stun", params={dur=0.5}} } },
	{ id="judge_5", branch="judge", order=5, lvReq=9, cost=125,
	  name="Вечный Шторм", desc="PASSIVE: Каждые 10с пассивно генерируется Lightning Charge",
	  effects={ {type="passive", key="passive_lightning_charge", params={interval=10}} } },
}

-- ────────────────────────────────────────────────────────────
-- 4. IRON TITAN
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.IronTitan = {
	-- ПУТЬ НЕСОКРУШИМОГО
	{ id="tank_1", branch="tank", order=1, lvReq=1, cost=20,
	  name="Стальная Плоть", desc="HP +20",
	  effects={ {type="stat", stat="hp", op="add", value=20} } },
	{ id="tank_2", branch="tank", order=2, lvReq=3, cost=40,
	  name="Непробиваемый Фасад", desc="Block снижение +5%",
	  effects={ {type="passive", key="block_reduction_bonus", params={bonus=0.05}} } },
	{ id="tank_3", branch="tank", order=3, lvReq=5, cost=75,
	  name="Абсолютный Щит", desc="Shield Wall поглощает +20%",
	  effects={ {type="ability", skill="F", param="absorption", op="mult", value=1.2} } },
	{ id="tank_4", branch="tank", order=4, lvReq=7, cost=90,
	  name="Железный Великан", desc="HP +30",
	  effects={ {type="stat", stat="hp", op="add", value=30} } },
	{ id="tank_5", branch="tank", order=5, lvReq=9, cost=125,
	  name="Бастион", desc="PASSIVE: HP<50% — входящий урон -10%",
	  effects={ {type="passive", key="bastion", params={hpThreshold=0.5, reduction=0.10}} } },

	-- ПУТЬ РАЗРУШИТЕЛЯ
	{ id="crush_1", branch="crush", order=1, lvReq=1, cost=20,
	  name="Стальной Кулак", desc="Iron Slam урон +3",
	  effects={ {type="ability", skill="Q", param="damage", op="add", value=3} } },
	{ id="crush_2", branch="crush", order=2, lvReq=3, cost=40,
	  name="Сейсмическая Волна", desc="Ground Quake радиус +20%",
	  effects={ {type="ability", skill="E", param="radius", op="mult", value=1.2} } },
	{ id="crush_3", branch="crush", order=3, lvReq=5, cost=75,
	  name="Быстрое Землетрясение", desc="Ground Quake CD -3с",
	  effects={ {type="cooldown", skill="E", op="add", value=-3} } },
	{ id="crush_4", branch="crush", order=4, lvReq=7, cost=90,
	  name="Падение Богов", desc="Titan Fall урон +8",
	  effects={ {type="ability", skill="R", param="damage", op="add", value=8} } },
	{ id="crush_5", branch="crush", order=5, lvReq=9, cost=125,
	  name="Удар Титана", desc="PASSIVE: Каждые 4 M1 — Titan Strike: +30% урона, ломает блок",
	  effects={ {type="passive", key="titan_strike", params={every=4, mult=1.3, breakBlock=true}} } },

	-- ПУТЬ ЯРОСТИ ТИТАНА
	{ id="rage_1", branch="rage", order=1, lvReq=1, cost=20,
	  name="Адреналин Боли", desc="Урон >15 → +5 HP",
	  effects={ {type="passive", key="damage_threshold_heal", params={threshold=15, heal=5}} } },
	{ id="rage_2", branch="rage", order=2, lvReq=3, cost=40,
	  name="Контрудар Под Щитом", desc="Iron Slam во время Shield Wall: x2 урон",
	  effects={ {type="passive", key="slam_during_shield", params={mult=2.0}} } },
	{ id="rage_3", branch="rage", order=3, lvReq=5, cost=75,
	  name="Гнев Медленный", desc="Titan Fall CD -10с",
	  effects={ {type="cooldown", skill="R", op="add", value=-10} } },
	{ id="rage_4", branch="rage", order=4, lvReq=7, cost=90,
	  name="Нарастающая Ярость", desc="Каждый удар: Speed +0.5 (до +1.5)",
	  effects={ {type="passive", key="rage_speed_stacks", params={perHit=0.5, maxStacks=3}} } },
	{ id="rage_5", branch="rage", order=5, lvReq=9, cost=125,
	  name="Берсерк Последней Секунды", desc="PASSIVE: HP<25% — Speed +2",
	  effects={ {type="passive", key="berserk_speed", params={hpThreshold=0.25, speedBonus=2}} } },
}

-- ────────────────────────────────────────────────────────────
-- 5. SCARLET ARCHER
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.ScarletArcher = {
	-- ПУТЬ МЕТКОГО СТРЕЛКА
	{ id="sniper_1", branch="sniper", order=1, lvReq=1, cost=20,
	  name="Пронзающий Наконечник", desc="Piercing Shot урон +3",
	  effects={ {type="ability", skill="Q", param="damage", op="add", value=3} } },
	{ id="sniper_2", branch="sniper", order=2, lvReq=3, cost=40,
	  name="Точный Глаз", desc="Headshot бонус +10%",
	  effects={ {type="passive", key="headshot_bonus", params={bonus=0.10}} } },
	{ id="sniper_3", branch="sniper", order=3, lvReq=5, cost=75,
	  name="Алый Дождь", desc="Arrow Rain урон +4",
	  effects={ {type="ability", skill="E", param="damage", op="add", value=4} } },
	{ id="sniper_4", branch="sniper", order=4, lvReq=7, cost=90,
	  name="Сквозной Выстрел", desc="Piercing Shot пробивает насквозь",
	  effects={ {type="passive", key="piercing_passthrough"} } },
	{ id="sniper_5", branch="sniper", order=5, lvReq=9, cost=125,
	  name="Первый Выстрел", desc="PASSIVE: Первый выстрел раунда — 100% крит",
	  effects={ {type="passive", key="first_shot_crit"} } },

	-- ПУТЬ ОХОТНИЦЫ
	{ id="hunter_1", branch="hunter", order=1, lvReq=1, cost=20,
	  name="Лёгкие Ноги", desc="Evasion Roll CD -1с",
	  effects={ {type="cooldown", skill="F", op="add", value=-1} } },
	{ id="hunter_2", branch="hunter", order=2, lvReq=3, cost=40,
	  name="Двойной Перекат", desc="Evasion Roll: 2 заряда",
	  effects={ {type="ability", skill="F", param="charges", op="add", value=1} } },
	{ id="hunter_3", branch="hunter", order=3, lvReq=5, cost=75,
	  name="Стрела с Дистанции", desc="Выстрел >30 studs: +20% урона",
	  effects={ {type="passive", key="long_shot_bonus", params={distance=30, mult=1.2}} } },
	{ id="hunter_4", branch="hunter", order=4, lvReq=7, cost=90,
	  name="Быстрая Охотница", desc="Speed +1",
	  effects={ {type="stat", stat="speed", op="add", value=1} } },
	{ id="hunter_5", branch="hunter", order=5, lvReq=9, cost=125,
	  name="Выстрел Уклонения", desc="PASSIVE: После Evasion Roll — M1 автоматически Headshot",
	  effects={ {type="passive", key="evasion_headshot"} } },

	-- ПУТЬ АЛОГО ДОЖДЯ
	{ id="rain_1", branch="rain", order=1, lvReq=1, cost=20,
	  name="Скорый Шторм", desc="Storm of Arrows CD -5с",
	  effects={ {type="cooldown", skill="R", op="add", value=-5} } },
	{ id="rain_2", branch="rain", order=2, lvReq=3, cost=40,
	  name="Замедляющий Дождь", desc="Arrow Rain: Slow 1.5с",
	  effects={ {type="passive", key="arrow_rain_slow", params={dur=1.5}} } },
	{ id="rain_3", branch="rain", order=3, lvReq=5, cost=75,
	  name="Широкий Захват", desc="Storm of Arrows площадь +25%",
	  effects={ {type="ability", skill="R", param="radius", op="mult", value=1.25} } },
	{ id="rain_4", branch="rain", order=4, lvReq=7, cost=90,
	  name="Затяжной Шторм", desc="Storm of Arrows длительность +1с",
	  effects={ {type="ability", skill="R", param="duration", op="add", value=1} } },
	{ id="rain_5", branch="rain", order=5, lvReq=9, cost=125,
	  name="Вечный Дождь", desc="PASSIVE: Каждые 6 M1 — мини-Arrow Rain (50%)",
	  effects={ {type="passive", key="auto_arrow_rain", params={every=6, damagePct=0.5}} } },
}

-- ────────────────────────────────────────────────────────────
-- 6. ECLIPSE HERO
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.EclipseHero = {
	-- ПУТЬ ЗАТМЕНИЯ
	{ id="eclipse_1", branch="eclipse", order=1, lvReq=1, cost=20,
	  name="Острый Взгляд", desc="Crit с тыла +5%",
	  effects={ {type="passive", key="back_crit_bonus", params={bonus=0.05}} } },
	{ id="eclipse_2", branch="eclipse", order=2, lvReq=3, cost=40,
	  name="Долгая Тень", desc="Dark Veil CD -2с, длительность +1с",
	  effects={ {type="cooldown", skill="E", op="add", value=-2},
	            {type="ability", skill="E", param="duration", op="add", value=1} } },
	{ id="eclipse_3", branch="eclipse", order=3, lvReq=5, cost=75,
	  name="Удар из Тьмы", desc="Eclipse Slash из Dark Veil: +40% урона",
	  effects={ {type="passive", key="veil_slash_bonus", params={mult=1.4}} } },
	{ id="eclipse_4", branch="eclipse", order=4, lvReq=7, cost=90,
	  name="Послезатмение", desc="После Total Eclipse — Dark Veil на 2с",
	  effects={ {type="passive", key="ult_auto_veil", params={dur=2}} } },
	{ id="eclipse_5", branch="eclipse", order=5, lvReq=9, cost=125,
	  name="Зарядка в Тени", desc="PASSIVE: В Dark Veil ульта заряжается x2",
	  effects={ {type="passive", key="veil_ult_charge", params={mult=2}} } },

	-- ПУТЬ ЛУННОГО КЛИНКА
	{ id="lunar_1", branch="lunar", order=1, lvReq=1, cost=20,
	  name="Лунный Удар", desc="Lunar Phase урон +3",
	  effects={ {type="ability", skill="F", param="damage", op="add", value=3} } },
	{ id="lunar_2", branch="lunar", order=2, lvReq=3, cost=40,
	  name="Скорая Луна", desc="Lunar Phase CD -2с",
	  effects={ {type="cooldown", skill="F", op="add", value=-2} } },
	{ id="lunar_3", branch="lunar", order=3, lvReq=5, cost=75,
	  name="Прыжок за Спину", desc="Lunar Phase телепортирует за спину (мгновенный crit)",
	  effects={ {type="passive", key="lunar_backstab"} } },
	{ id="lunar_4", branch="lunar", order=4, lvReq=7, cost=90,
	  name="Лунный Слэш", desc="Eclipse Slash после Lunar Phase — мгновенный каст",
	  effects={ {type="passive", key="lunar_instant_slash"} } },
	{ id="lunar_5", branch="lunar", order=5, lvReq=9, cost=125,
	  name="Лунное Замедление", desc="PASSIVE: Телепорт → Slow врага 1с (0.5x Speed)",
	  effects={ {type="passive", key="teleport_slow", params={dur=1, slowMult=0.5}} } },

	-- ПУТЬ ХАОСА ЗАТМЕНИЯ
	{ id="chaos_1", branch="chaos", order=1, lvReq=1, cost=20,
	  name="Тёмный M1", desc="M1 урон +8%",
	  effects={ {type="stat", stat="m1Damage", op="mult", value=1.08} } },
	{ id="chaos_2", branch="chaos", order=2, lvReq=3, cost=40,
	  name="Теневой Взрыв", desc="Каждый 4-й M1 — теневой взрыв +10 AoE",
	  effects={ {type="passive", key="shadow_burst", params={every=4, damage=10, radius=5}} } },
	{ id="chaos_3", branch="chaos", order=3, lvReq=5, cost=75,
	  name="Скорый Слэш", desc="Eclipse Slash CD -1с",
	  effects={ {type="cooldown", skill="Q", op="add", value=-1} } },
	{ id="chaos_4", branch="chaos", order=4, lvReq=7, cost=90,
	  name="Тотальный Мрак", desc="Total Eclipse урон +8",
	  effects={ {type="ability", skill="R", param="damage", op="add", value=8} } },
	{ id="chaos_5", branch="chaos", order=5, lvReq=9, cost=125,
	  name="Скорость Тьмы", desc="PASSIVE: Crit → Speed +1.5 на 1.5с (до 2 стаков)",
	  effects={ {type="passive", key="crit_speed_burst", params={speedBonus=1.5, dur=1.5, maxStacks=2}} } },
}

-- ────────────────────────────────────────────────────────────
-- 7. STORM DANCER
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.StormDancer = {
	-- ПУТЬ ВИХРЯ
	{ id="whirl_1", branch="whirl", order=1, lvReq=1, cost=20,
	  name="Ноги Ветра", desc="Speed +1",
	  effects={ {type="stat", stat="speed", op="add", value=1} } },
	{ id="whirl_2", branch="whirl", order=2, lvReq=3, cost=40,
	  name="Длинный Шаг", desc="Tempest Step дальность +3 studs",
	  effects={ {type="ability", skill="F", param="distance", op="add", value=3} } },
	{ id="whirl_3", branch="whirl", order=3, lvReq=5, cost=75,
	  name="Стаки Скорости", desc="Storm Stacks: +1% Speed каждый",
	  effects={ {type="passive", key="stack_speed_pct", params={pct=0.01}} } },
	{ id="whirl_4", branch="whirl", order=4, lvReq=7, cost=90,
	  name="Глаз Шторма", desc="Max Storm Stacks: 8 → 12",
	  effects={ {type="passive", key="max_stacks_increase", params={maxStacks=12}} } },
	{ id="whirl_5", branch="whirl", order=5, lvReq=9, cost=125,
	  name="Взрыв Шторма", desc="PASSIVE: 12 стаков → Burst Mode 2с: Speed x1.5",
	  effects={ {type="passive", key="burst_mode", params={dur=2, speedMult=1.5}} } },

	-- ПУТЬ ШТОРМА
	{ id="storm_1", branch="storm", order=1, lvReq=1, cost=20,
	  name="Штормовой Кулак", desc="M1 урон +6%",
	  effects={ {type="stat", stat="m1Damage", op="mult", value=1.06} } },
	{ id="storm_2", branch="storm", order=2, lvReq=3, cost=40,
	  name="Спираль Силы", desc="5+ стаков: Wind Spiral +30%",
	  effects={ {type="passive", key="stacks_wind_spiral_bonus", params={minStacks=5, mult=1.3}} } },
	{ id="storm_3", branch="storm", order=3, lvReq=5, cost=75,
	  name="Мощь Шторма", desc="Storm Stacks: +1% Ability Power каждый",
	  effects={ {type="passive", key="stack_ability_pct", params={pct=0.01}} } },
	{ id="storm_4", branch="storm", order=4, lvReq=7, cost=90,
	  name="Неистовый Циклон", desc="Cyclone Fury: +2 урона за каждый Storm Stack",
	  effects={ {type="passive", key="cyclone_stack_dmg", params={dmgPerStack=2}} } },
	{ id="storm_5", branch="storm", order=5, lvReq=9, cost=125,
	  name="Финишер Шторма", desc="PASSIVE: M1 финишер при 8+ стаках: -3 стака +20 dmg (unblockable)",
	  effects={ {type="passive", key="storm_finisher", params={minStacks=8, consumeStacks=3, damage=20}} } },

	-- ПУТЬ ПАРИРОВАНИЯ ВЕТРА
	{ id="parry_1", branch="parry", order=1, lvReq=1, cost=20,
	  name="Чуткий Ветер", desc="Gale Parry окно +50мс",
	  effects={ {type="passive", key="parry_window_bonus", params={bonus=50}} } },
	{ id="parry_2", branch="parry", order=2, lvReq=3, cost=40,
	  name="Стаки Парри", desc="Gale Parry → +3 Storm Stacks",
	  effects={ {type="passive", key="parry_stacks", params={stacks=3}} } },
	{ id="parry_3", branch="parry", order=3, lvReq=5, cost=75,
	  name="Быстрый Ответ", desc="Gale Parry CD -2с",
	  effects={ {type="cooldown", skill="E", op="add", value=-2} } },
	{ id="parry_4", branch="parry", order=4, lvReq=7, cost=90,
	  name="Ураганный Ответный Удар", desc="После Gale Parry: M1 +50%",
	  effects={ {type="passive", key="parry_counter_bonus", params={mult=1.5}} } },
	{ id="parry_5", branch="parry", order=5, lvReq=9, cost=125,
	  name="Глаз Совершенства", desc="PASSIVE: Perfect Parry → мгновенно макс Storm Stacks (12)",
	  effects={ {type="passive", key="perfect_parry_max_stacks"} } },
}

-- ────────────────────────────────────────────────────────────
-- 8. BLOOD SAGE
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.BloodSage = {
	-- ПУТЬ АЛОЙ МАГИИ
	{ id="magic_1", branch="magic", order=1, lvReq=1, cost=20,
	  name="Кровавый Болт", desc="Bloodbolt урон +3",
	  effects={ {type="ability", skill="Q", param="damage", op="add", value=3} } },
	{ id="magic_2", branch="magic", order=2, lvReq=3, cost=40,
	  name="Кровоточащая Цепь", desc="Crimson Bind: корень + Bleed 2/тик 3с",
	  effects={ {type="passive", key="bind_bleed", params={dmg=2, dur=3}} } },
	{ id="magic_3", branch="magic", order=3, lvReq=5, cost=75,
	  name="Вспышка Крови", desc="Sanguine Burst урон +4",
	  effects={ {type="ability", skill="E", param="damage", op="add", value=4} } },
	{ id="magic_4", branch="magic", order=4, lvReq=7, cost=90,
	  name="Пронзающая Кровь", desc="Bloodbolt пробивает насквозь",
	  effects={ {type="passive", key="bloodbolt_passthrough"} } },
	{ id="magic_5", branch="magic", order=5, lvReq=9, cost=125,
	  name="Кровавый Всплеск", desc="PASSIVE: Каждые 3 способности — Blood Surge: +50% урон",
	  effects={ {type="passive", key="blood_surge", params={every=3, mult=1.5}} } },

	-- ПУТЬ ВАМПИРА
	{ id="vamp_1", branch="vamp", order=1, lvReq=1, cost=20,
	  name="Глубокий Дрейн", desc="Drain +2 HP/hit",
	  effects={ {type="passive", key="drain_bonus", params={bonus=2}} } },
	{ id="vamp_2", branch="vamp", order=2, lvReq=3, cost=40,
	  name="Способность Вампира", desc="Drain от способностей тоже",
	  effects={ {type="passive", key="ability_drain"} } },
	{ id="vamp_3", branch="vamp", order=3, lvReq=5, cost=75,
	  name="Перекормленный", desc="HP>150 → все способности +10%",
	  effects={ {type="passive", key="overfed", params={hpThreshold=150, mult=1.10}} } },
	{ id="vamp_4", branch="vamp", order=4, lvReq=7, cost=90,
	  name="Кровавая Луна", desc="Blood Moon при активации: +20 HP",
	  effects={ {type="passive", key="blood_moon_heal", params={heal=20}} } },
	{ id="vamp_5", branch="vamp", order=5, lvReq=9, cost=125,
	  name="Отчаянное Питание", desc="PASSIVE: HP<30% → Drain x2",
	  effects={ {type="passive", key="desperation_drain", params={hpThreshold=0.3, mult=2}} } },

	-- ПУТЬ КРОВАВОГО РИТУАЛА
	{ id="ritual_1", branch="ritual", order=1, lvReq=1, cost=20,
	  name="Ритуальный Обмен", desc="Трать 10 HP → +5% ульты (без CD)",
	  effects={ {type="passive", key="ritual_exchange", params={hpCost=10, ultPct=0.05}} } },
	{ id="ritual_2", branch="ritual", order=2, lvReq=3, cost=40,
	  name="Жертва Ради Силы", desc="Sanguine Burst при HP<50%: +40%",
	  effects={ {type="passive", key="low_hp_burst_bonus", params={hpThreshold=0.5, mult=1.4}} } },
	{ id="ritual_3", branch="ritual", order=3, lvReq=5, cost=75,
	  name="Скорое Затмение", desc="Blood Moon CD -10с",
	  effects={ {type="cooldown", skill="R", op="add", value=-10} } },
	{ id="ritual_4", branch="ritual", order=4, lvReq=7, cost=90,
	  name="Кровавые Узы", desc="Crimson Bind CD -2с, Bleed стакается x2",
	  effects={ {type="cooldown", skill="F", op="add", value=-2},
	            {type="passive", key="bind_double_bleed"} } },
	{ id="ritual_5", branch="ritual", order=5, lvReq=9, cost=125,
	  name="Пир Победителя", desc="PASSIVE: Убийство → +25 HP (Blood Feast)",
	  effects={ {type="passive", key="kill_heal", params={heal=25}} } },
}

-- ────────────────────────────────────────────────────────────
-- 9. CRYSTAL GUARD
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.CrystalGuard = {
	-- ПУТЬ КРИСТАЛЬНОЙ БРОНИ
	{ id="armor_1", branch="armor", order=1, lvReq=1, cost=20,
	  name="Кристальная Кожа", desc="Crystal Shards снижение +3%",
	  effects={ {type="passive", key="shard_reduction_bonus", params={bonus=0.03}} } },
	{ id="armor_2", branch="armor", order=2, lvReq=3, cost=40,
	  name="Укреплённый Барьер", desc="Prism Barrier поглощает +25%",
	  effects={ {type="ability", skill="E", param="absorption", op="mult", value=1.25} } },
	{ id="armor_3", branch="armor", order=3, lvReq=5, cost=75,
	  name="Быстрый Барьер", desc="Prism Barrier CD -2с",
	  effects={ {type="cooldown", skill="E", op="add", value=-2} } },
	{ id="armor_4", branch="armor", order=4, lvReq=7, cost=90,
	  name="Взрыв Осколков", desc="При разрушении Barrier: 10 AoE урона (8 studs)",
	  effects={ {type="passive", key="barrier_explode", params={damage=10, radius=8}} } },
	{ id="armor_5", branch="armor", order=5, lvReq=9, cost=125,
	  name="Инстинкт Выживания", desc="PASSIVE: HP<40% → Prism Barrier автоматически (1 раз/матч)",
	  effects={ {type="passive", key="auto_barrier", params={hpThreshold=0.4}} } },

	-- ПУТЬ КРИСТАЛЬНОГО ОТМЩЕНИЯ
	{ id="revenge_1", branch="revenge", order=1, lvReq=1, cost=20,
	  name="Острые Осколки", desc="Crystal Spike урон +3",
	  effects={ {type="ability", skill="Q", param="damage", op="add", value=3} } },
	{ id="revenge_2", branch="revenge", order=2, lvReq=3, cost=40,
	  name="Автоматический Шип", desc="Каждые 3 удара → Crystal Spike 5 урона (бесплатно)",
	  effects={ {type="passive", key="auto_spike", params={every=3, damage=5}} } },
	{ id="revenge_3", branch="revenge", order=3, lvReq=5, cost=75,
	  name="Сокрушающий Рывок", desc="Shatter Rush урон +4",
	  effects={ {type="ability", skill="F", param="damage", op="add", value=4} } },
	{ id="revenge_4", branch="revenge", order=4, lvReq=7, cost=90,
	  name="Кристальный Ответ", desc="Урон >20 → бесплатный Crystal Spike",
	  effects={ {type="passive", key="damage_auto_spike", params={threshold=20}} } },
	{ id="revenge_5", branch="revenge", order=5, lvReq=9, cost=125,
	  name="Зеркало Боли", desc="PASSIVE: 15% полученного урона → рефлект (макс 8)",
	  effects={ {type="passive", key="damage_reflect", params={pct=0.15, maxDmg=8}} } },

	-- ПУТЬ СТРАЖА ЗЕМЛИ
	{ id="earth_1", branch="earth", order=1, lvReq=1, cost=20,
	  name="Каменное Тело", desc="HP +20",
	  effects={ {type="stat", stat="hp", op="add", value=20} } },
	{ id="earth_2", branch="earth", order=2, lvReq=3, cost=40,
	  name="Скорая Крепость", desc="Crystal Fortress CD -8с",
	  effects={ {type="cooldown", skill="R", op="add", value=-8} } },
	{ id="earth_3", branch="earth", order=3, lvReq=5, cost=75,
	  name="Кристальная Зона", desc="Crystal Fortress: Slow 20% врагам внутри",
	  effects={ {type="passive", key="fortress_slow", params={slowPct=0.20}} } },
	{ id="earth_4", branch="earth", order=4, lvReq=7, cost=90,
	  name="Большое Тело", desc="HP +25",
	  effects={ {type="stat", stat="hp", op="add", value=25} } },
	{ id="earth_5", branch="earth", order=5, lvReq=9, cost=125,
	  name="Неуязвимый Каст", desc="PASSIVE: Crystal Fortress → 1.5с неуязвимости",
	  effects={ {type="passive", key="fortress_invuln", params={dur=1.5}} } },
}

-- ────────────────────────────────────────────────────────────
-- 10. SHADOW TWIN
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.ShadowTwin = {
	-- ПУТЬ КЛОНА
	{ id="clone_1", branch="clone", order=1, lvReq=1, cost=20,
	  name="Сильный Клон", desc="Shadow Clone урон: 50% → 60%",
	  effects={ {type="passive", key="clone_damage_pct", params={pct=0.60}} } },
	{ id="clone_2", branch="clone", order=2, lvReq=3, cost=40,
	  name="Живучий Клон", desc="Shadow Clone HP +40%",
	  effects={ {type="ability", skill="Q", param="cloneHp", op="mult", value=1.4} } },
	{ id="clone_3", branch="clone", order=3, lvReq=5, cost=75,
	  name="Быстрый Клон", desc="Shadow Clone CD -3с",
	  effects={ {type="cooldown", skill="Q", op="add", value=-3} } },
	{ id="clone_4", branch="clone", order=4, lvReq=7, cost=90,
	  name="Смерть Клона", desc="При смерти клона: 15 AoE урона",
	  effects={ {type="passive", key="clone_death_explode", params={damage=15}} } },
	{ id="clone_5", branch="clone", order=5, lvReq=9, cost=125,
	  name="Умный Клон", desc="PASSIVE: Клон копирует последнюю способность (1 раз)",
	  effects={ {type="passive", key="smart_clone"} } },

	-- ПУТЬ ДВОЙНИКА
	{ id="double_1", branch="double", order=1, lvReq=1, cost=20,
	  name="Туманный Шаг", desc="Mist Step дальность +5 studs",
	  effects={ {type="ability", skill="F", param="distance", op="add", value=5} } },
	{ id="double_2", branch="double", order=2, lvReq=3, cost=40,
	  name="Исчезновение", desc="Mist Step: 0.5с невидимость",
	  effects={ {type="passive", key="mist_invis", params={dur=0.5}} } },
	{ id="double_3", branch="double", order=3, lvReq=5, cost=75,
	  name="Двойной Удар", desc="Twin Lash при живом клоне — с двух позиций",
	  effects={ {type="passive", key="twin_lash_dual"} } },
	{ id="double_4", branch="double", order=4, lvReq=7, cost=90,
	  name="Ловушка Клона", desc="Shadow Clone на позиции врага (дезориентация)",
	  effects={ {type="passive", key="clone_on_enemy"} } },
	{ id="double_5", branch="double", order=5, lvReq=9, cost=125,
	  name="Щит Отвлечения", desc="PASSIVE: Враг атакует клон → Twin -20% урона",
	  effects={ {type="passive", key="distraction_shield", params={reduction=0.20}} } },

	-- ПУТЬ ТЁМНОГО ЗЕРКАЛА
	{ id="mirror_1", branch="mirror", order=1, lvReq=1, cost=20,
	  name="Скорое Зеркало", desc="Dark Mirror CD -5с",
	  effects={ {type="cooldown", skill="R", op="add", value=-5} } },
	{ id="mirror_2", branch="mirror", order=2, lvReq=3, cost=40,
	  name="Двойное Зеркало", desc="Dark Mirror: 2 клона",
	  effects={ {type="passive", key="double_mirror_clones"} } },
	{ id="mirror_3", branch="mirror", order=3, lvReq=5, cost=75,
	  name="Тёмный Удар", desc="M1 урон +8%",
	  effects={ {type="stat", stat="m1Damage", op="mult", value=1.08} } },
	{ id="mirror_4", branch="mirror", order=4, lvReq=7, cost=90,
	  name="Ослепляющее Зеркало", desc="Dark Mirror: 1.5с stun рядом",
	  effects={ {type="passive", key="mirror_stun", params={dur=1.5}} } },
	{ id="mirror_5", branch="mirror", order=5, lvReq=9, cost=125,
	  name="Стиль Двойника", desc="PASSIVE: Пока жив клон — Style Decay x0.7",
	  effects={ {type="passive", key="clone_style_decay", params={mult=0.7}} } },
}

-- ────────────────────────────────────────────────────────────
-- 11. NEON BLITZ
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.NeonBlitz = {
	-- ПУТЬ НЕОН РАЗРЯДА
	{ id="neon_1", branch="neon", order=1, lvReq=1, cost=20,
	  name="Усиленный Neon", desc="Neon Burst урон +3",
	  effects={ {type="ability", skill="Q", param="damage", op="add", value=3} } },
	{ id="neon_2", branch="neon", order=2, lvReq=3, cost=40,
	  name="Электрический Пульс", desc="4-й удар: Neon Pulse +5 урона",
	  effects={ {type="passive", key="neon_pulse_bonus", params={extraDmg=5}} } },
	{ id="neon_3", branch="neon", order=3, lvReq=5, cost=75,
	  name="Перегрузка AoE", desc="Overload урон +4",
	  effects={ {type="ability", skill="E", param="damage", op="add", value=4} } },
	{ id="neon_4", branch="neon", order=4, lvReq=7, cost=90,
	  name="Электрический Ожог", desc="Neon Burst: Electric 1/тик 2с",
	  effects={ {type="passive", key="neon_burn", params={dmg=1, dur=2}} } },
	{ id="neon_5", branch="neon", order=5, lvReq=9, cost=125,
	  name="Mega Pulse", desc="PASSIVE: Каждые 8 ударов — +25 AoE (unblockable)",
	  effects={ {type="passive", key="mega_pulse", params={every=8, damage=25}} } },

	-- ПУТЬ СХЕМЫ
	{ id="circuit_1", branch="circuit", order=1, lvReq=1, cost=20,
	  name="Быстрая Схема", desc="Circuit Dash CD -1с",
	  effects={ {type="cooldown", skill="F", op="add", value=-1} } },
	{ id="circuit_2", branch="circuit", order=2, lvReq=3, cost=40,
	  name="Двойная Схема", desc="Circuit Dash: 2 заряда",
	  effects={ {type="ability", skill="F", param="charges", op="add", value=1} } },
	{ id="circuit_3", branch="circuit", order=3, lvReq=5, cost=75,
	  name="Заряженный Выстрел", desc="После Circuit Dash: Neon Burst +50%",
	  effects={ {type="passive", key="dash_charged_shot", params={mult=1.5}} } },
	{ id="circuit_4", branch="circuit", order=4, lvReq=7, cost=90,
	  name="Электрические Ноги", desc="Speed +1",
	  effects={ {type="stat", stat="speed", op="add", value=1} } },
	{ id="circuit_5", branch="circuit", order=5, lvReq=9, cost=125,
	  name="Замкнутая Цепь", desc="PASSIVE: 2 Circuit Dash подряд → 12 AoE",
	  effects={ {type="passive", key="closed_circuit", params={damage=12}} } },

	-- ПУТЬ ПЕРЕГРУЗКИ
	{ id="overload_1", branch="overload", order=1, lvReq=1, cost=20,
	  name="Скорая Перегрузка", desc="Neon Overdrive CD -5с",
	  effects={ {type="cooldown", skill="R", op="add", value=-5} } },
	{ id="overload_2", branch="overload", order=2, lvReq=3, cost=40,
	  name="Широкая Волна", desc="Overload радиус +25%",
	  effects={ {type="ability", skill="E", param="radius", op="mult", value=1.25} } },
	{ id="overload_3", branch="overload", order=3, lvReq=5, cost=75,
	  name="Электрическое Замедление", desc="Neon Overdrive: Slow 30% 2с",
	  effects={ {type="passive", key="overdrive_slow", params={slowPct=0.3, dur=2}} } },
	{ id="overload_4", branch="overload", order=4, lvReq=7, cost=90,
	  name="Overdrive++", desc="Neon Overdrive урон +8",
	  effects={ {type="ability", skill="R", param="damage", op="add", value=8} } },
	{ id="overload_5", branch="overload", order=5, lvReq=9, cost=125,
	  name="Режим Оверклок", desc="PASSIVE: Overdrive → 3с все CD -50%",
	  effects={ {type="passive", key="overclock", params={dur=3, cdMult=0.5}} } },
}

-- ────────────────────────────────────────────────────────────
-- 12. JADE SENTINEL
-- ────────────────────────────────────────────────────────────
AwakeningTree.Heroes.JadeSentinel = {
	-- ПУТЬ КЛИНКА НЕФРИТА
	{ id="jade_1", branch="jade", order=1, lvReq=1, cost=20,
	  name="Нефритовая Заточка", desc="M1 урон +7%",
	  effects={ {type="stat", stat="m1Damage", op="mult", value=1.07} } },
	{ id="jade_2", branch="jade", order=2, lvReq=3, cost=40,
	  name="Скорый Удар", desc="Jade Strike CD -1с, урон +2",
	  effects={ {type="cooldown", skill="Q", op="add", value=-1},
	            {type="ability", skill="Q", param="damage", op="add", value=2} } },
	{ id="jade_3", branch="jade", order=3, lvReq=5, cost=75,
	  name="Сейсмический Буфф", desc="После Earthen Crush: 2с M1 +25%",
	  effects={ {type="passive", key="earthen_m1_buff", params={dur=2, mult=1.25}} } },
	{ id="jade_4", branch="jade", order=4, lvReq=7, cost=90,
	  name="Скорый Гнев", desc="Jade Wrath CD -5с",
	  effects={ {type="cooldown", skill="R", op="add", value=-5} } },
	{ id="jade_5", branch="jade", order=5, lvReq=9, cost=125,
	  name="Серия Правосудия", desc="PASSIVE: 3 M1 без урона → финал +35%",
	  effects={ {type="passive", key="justice_series", params={hits=3, mult=1.35}} } },

	-- ПУТЬ СТРАЖА НЕФРИТА
	{ id="sentinel_1", branch="sentinel", order=1, lvReq=1, cost=20,
	  name="Широкое Окно", desc="Perfect Parry окно +60мс",
	  effects={ {type="passive", key="parry_window_bonus", params={bonus=60}} } },
	{ id="sentinel_2", branch="sentinel", order=2, lvReq=3, cost=40,
	  name="Нефритовый Ответ", desc="Perfect Parry → бесплатный Jade Strike",
	  effects={ {type="passive", key="parry_free_jade_strike"} } },
	{ id="sentinel_3", branch="sentinel", order=3, lvReq=5, cost=75,
	  name="Быстрая Реакция", desc="Perfect Parry сбрасывает кратчайший CD",
	  effects={ {type="passive", key="parry_cd_reset_shortest"} } },
	{ id="sentinel_4", branch="sentinel", order=4, lvReq=7, cost=90,
	  name="Серия Парри", desc="3 Perfect Parry → Jade Strike x2 урона",
	  effects={ {type="passive", key="parry_series_bonus", params={count=3, mult=2.0}} } },
	{ id="sentinel_5", branch="sentinel", order=5, lvReq=9, cost=125,
	  name="Последний Шанс", desc="PASSIVE: Perfect Parry при HP<30% → +12 HP",
	  effects={ {type="passive", key="parry_emergency_heal", params={hpThreshold=0.3, heal=12}} } },

	-- ПУТЬ ЗЕМЛИ
	{ id="ground_1", branch="ground", order=1, lvReq=1, cost=20,
	  name="Широкая Земля", desc="Earthen Crush радиус +20%",
	  effects={ {type="ability", skill="E", param="radius", op="mult", value=1.2} } },
	{ id="ground_2", branch="ground", order=2, lvReq=3, cost=40,
	  name="Землетрясение", desc="Earthen Crush: Slow 25% 1.5с",
	  effects={ {type="passive", key="earthen_slow", params={slowPct=0.25, dur=1.5}} } },
	{ id="ground_3", branch="ground", order=3, lvReq=5, cost=75,
	  name="Двойной Шаг", desc="Sentinel Step: 2 заряда",
	  effects={ {type="ability", skill="F", param="charges", op="add", value=1} } },
	{ id="ground_4", branch="ground", order=4, lvReq=7, cost=90,
	  name="Быстрая Земля", desc="Earthen Crush CD -2с",
	  effects={ {type="cooldown", skill="E", op="add", value=-2} } },
	{ id="ground_5", branch="ground", order=5, lvReq=9, cost=125,
	  name="Пульс Земли", desc="PASSIVE: Каждые 15с — 5 урона + Slow AoE (7 studs)",
	  effects={ {type="passive", key="earth_pulse", params={interval=15, damage=5, radius=7}} } },
}

print("[AwakeningTree] Loaded — 12 heroes, 180 nodes total")
return AwakeningTree
