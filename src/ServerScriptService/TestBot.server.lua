-- TestBot.server.lua | Anime Arena: Blitz
-- Полностью переписан — production версия
-- • R6-тело бота (человечек: Head, Torso, Arms, Legs + Humanoid)
-- • АИ: преследование → M1 в диапазоне → скиллы Q/E/F/R через SkillHandlers → dodge
-- • Урон/смерть через CombatSystem.dealDamage
-- • Полная интеграция с RoundService через botProxy (_isBot=true)
-- • Запускается только через MatchmakingService (не автозапуск)

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

-- ============================================================
-- КОНФИГ
-- ============================================================

local BOT_CONFIG = {
	DIFFICULTY   = "Normal",   -- "Easy" | "Normal" | "Hard"
	HERO_ID      = nil,        -- nil = рандом
	RESPAWN_TIME = 5,
	BOT_USER_ID  = -1,
	BOT_NAME     = "[BOT] Rival",
}

local DIFFICULTY_PARAMS = {
	-- FIX: reaction увеличен, m1Range уменьшен — бот больше не бьёт сквозь стены
	Easy   = { reaction=2.0, aggression=0.25, dodgeChance=0.08, m1Range=5, skillChance=0.15, strafeRange=8  },
	Normal = { reaction=1.2, aggression=0.50, dodgeChance=0.25, m1Range=6, skillChance=0.35, strafeRange=10 },
	Hard   = { reaction=0.5, aggression=0.80, dodgeChance=0.50, m1Range=7, skillChance=0.65, strafeRange=12 },
}

local HERO_LIST = {
	"FlameRonin","VoidAssassin","ThunderMonk",
	"IronTitan", "ScarletArcher","EclipseHero",
	"StormDancer","BloodSage",  "CrystalGuard",
	"ShadowTwin","NeonBlitz",   "JadeSentinel",
}

-- ============================================================
-- СОСТОЯНИЕ
-- ============================================================

local botModel   = nil
local botAlive   = false
local botHeroId  = nil
local botHeroData= nil
local botMatchId = "bot_match"
local botHP      = 100
local botMaxHP   = 100
local botCDs     = { Q=0, E=0, F=0, R=0 }
local botUltCharge = 0
local botLastM1  = 0
local hpFillPart = nil   -- Frame полоски HP

-- botProxy — объект-заглушка для round.players + SkillHandlers + CombatSystem
local botProxy = {
	_isBot = true,
	UserId = BOT_CONFIG.BOT_USER_ID,
	Name   = BOT_CONFIG.BOT_NAME,
	Parent = true,
}

-- ============================================================
-- ЖДЕМ СИСТЕМЫ
-- ============================================================

local CombatSystem  = nil
local SkillHandlers = nil
local Characters    = nil

task.defer(function()
	for _ = 1, 60 do
		if _G.CombatSystem then break end
		task.wait(0.5)
	end
	CombatSystem  = _G.CombatSystem
	SkillHandlers = require(script.Parent.SkillHandlers)
	Characters    = require(ReplicatedStorage:WaitForChild("Characters"))
	if not CombatSystem then
		warn("[TestBot] CombatSystem not found")
	end
end)

-- ============================================================
-- R6 ТЕЛО БОТА
-- ============================================================

local function buildR6Body(heroId, spawnCF)
	local c3 = Color3.fromRGB
	local skinColor  = BrickColor.new("Light orange")
	local shirtColor = c3(60, 80, 180)
	local pantsColor = c3(40, 40, 80)

	local model = Instance.new("Model")
	model.Name = BOT_CONFIG.BOT_NAME

	-- Вспомогательная функция создания Part
	local function mkPart(name, size, color, cf, anchor)
		local p = Instance.new("Part")
		p.Name        = name
		p.Size        = size
		p.BrickColor  = color or skinColor
		p.CFrame      = cf or spawnCF
		p.Anchored    = anchor or false
		p.CanCollide  = (name == "HumanoidRootPart" or name == "Torso")
		p.CastShadow  = true
		p.Parent      = model
		return p
	end

	-- Основные части R6
	local hrp   = mkPart("HumanoidRootPart", Vector3.new(2,2,1),   BrickColor.new("Medium stone grey"), spawnCF)
	hrp.Transparency = 1

	local torso = mkPart("Torso",  Vector3.new(2,2,1),   BrickColor.new("Bright blue"),    spawnCF * CFrame.new(0,0,0))
	torso.BrickColor = BrickColor.new("Bright blue")

	local head  = mkPart("Head",   Vector3.new(2,1,1),   skinColor,  spawnCF * CFrame.new(0, 1.5, 0))
	local lArm  = mkPart("Left Arm",  Vector3.new(1,2,1),BrickColor.new("Bright blue"), spawnCF * CFrame.new(-1.5,0,0))
	local rArm  = mkPart("Right Arm", Vector3.new(1,2,1),BrickColor.new("Bright blue"), spawnCF * CFrame.new(1.5, 0,0))
	local lLeg  = mkPart("Left Leg",  Vector3.new(1,2,1),BrickColor.new("Dark blue"),   spawnCF * CFrame.new(-0.5,-2,0))
	local rLeg  = mkPart("Right Leg", Vector3.new(1,2,1),BrickColor.new("Dark blue"),   spawnCF * CFrame.new(0.5, -2,0))

	-- Связки (все к HRP)
	local function weld(a, b, c0, c1)
		local m = Instance.new("Motor6D")
		m.Part0  = a
		m.Part1  = b
		m.C0     = c0 or CFrame.new()
		m.C1     = c1 or CFrame.new()
		m.Parent = a
		return m
	end

	-- HRP → Torso
	weld(hrp,  torso, CFrame.new(0,0,0), CFrame.new(0,0,0))
	-- Torso → Head
	weld(torso, head,  CFrame.new(0,1,0),  CFrame.new(0,-0.5,0))
	-- Torso → Arms
	weld(torso, lArm,  CFrame.new(-1.5,0,0), CFrame.new(0,0,0))
	weld(torso, rArm,  CFrame.new(1.5, 0,0), CFrame.new(0,0,0))
	-- Torso → Legs
	weld(torso, lLeg,  CFrame.new(-0.5,-1,0), CFrame.new(0,1,0))
	weld(torso, rLeg,  CFrame.new(0.5, -1,0), CFrame.new(0,1,0))

	-- Лицо (глаза)
	local face = Instance.new("Decal")
	face.Face    = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent  = head

	-- Billboard с именем
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 220, 0, 55)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.Adornee = hrp; bb.AlwaysOnTop = false; bb.Parent = hrp

	local lbl = Instance.new("TextLabel", bb)
	lbl.Size = UDim2.new(1,0,0.6,0)
	lbl.BackgroundTransparency = 1
	lbl.Text = string.format("%s [%s]", BOT_CONFIG.BOT_NAME, heroId)
	lbl.TextColor3 = Color3.fromRGB(255,80,80)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true

	-- HP бар
	local hpGui = Instance.new("BillboardGui")
	hpGui.Name = "HPBar"
	hpGui.Size = UDim2.new(0, 160, 0, 12)
	hpGui.StudsOffset = Vector3.new(0, 2.6, 0)
	hpGui.Adornee = hrp; hpGui.Parent = hrp

	local bg = Instance.new("Frame", hpGui)
	bg.Size = UDim2.new(1,0,1,0)
	bg.BackgroundColor3 = Color3.fromRGB(50,0,0)
	bg.BorderSizePixel = 0

	local fill = Instance.new("Frame", bg)
	fill.Name = "Fill"
	fill.Size = UDim2.new(1,0,1,0)
	fill.BackgroundColor3 = Color3.fromRGB(220,50,50)
	fill.BorderSizePixel = 0
	hpFillPart = fill

	-- Humanoid
	local hum = Instance.new("Humanoid", model)
	hum.MaxHealth = botMaxHP
	hum.Health    = botMaxHP
	hum.WalkSpeed = (botHeroData and botHeroData.speed or 16)
	hum.JumpPower = 50
	hum.DisplayName = ""
	hum.NameDisplayDistance = 0
	hum.HealthDisplayDistance = 0

	-- HeroTag для остальных систем
	local tag = Instance.new("StringValue", model)
	tag.Name = "HeroTag"; tag.Value = heroId

	model.PrimaryPart = hrp
	model.Parent = workspace

	-- Синхр Humanoid.Health → botHP
	hum.HealthChanged:Connect(function(hp)
		if not botAlive then return end
		botHP = math.max(0, hp)
		local pct = math.clamp(botHP / botMaxHP, 0, 1)
		if hpFillPart then hpFillPart.Size = UDim2.new(pct,0,1,0) end
	end)

	hum.Died:Connect(function()
		botAlive = false
	end)

	return model, hrp, hum
end

-- ============================================================
-- РЕГИСТРАЦИЯ БОТА В CombatSystem
-- ============================================================

local function registerBotInCombat()
	if not CombatSystem then return end
	local state = CombatSystem.getState(BOT_CONFIG.BOT_USER_ID)
	if state then return end  -- уже зарегистрирован

	local fakePlayer = {
		UserId    = BOT_CONFIG.BOT_USER_ID,
		Name      = BOT_CONFIG.BOT_NAME,
		Character = botModel,
		Parent    = Players,
		_isBot    = true,
	}
	CombatSystem.initPlayer(fakePlayer, botHeroData, botMatchId, "Normal")

	-- Синхронизируем HP
	local s = CombatSystem.getState(BOT_CONFIG.BOT_USER_ID)
	if s then
		botHP    = s.hp
		botMaxHP = s.maxHp
		if hpFillPart then hpFillPart.Size = UDim2.new(1,0,1,0) end
	end
end

-- ============================================================
-- РЕГИСТРАЦИЯ ИГРОКА В МАТЧ БОТА
-- ============================================================

local function registerPlayerInBotMatch(player)
	if not CombatSystem then return end
	local CharSvc = _G.CharacterService
	local heroData
	if CharSvc and CharSvc.GetSelectedHero then
		heroData = CharSvc.GetSelectedHero(player.UserId)
	end
	heroData = heroData
		or (Characters and Characters[BOT_CONFIG.HERO_ID or "FlameRonin"])
		or { id="FlameRonin", name="Flame Ronin", hp=120, m1Damage=8, speed=16 }

	local state = CombatSystem.getState(player.UserId)
	if not state then
		CombatSystem.initPlayer(player, heroData, botMatchId, "Normal")
	end
	local s = CombatSystem.getState(player.UserId)
	if s then s.matchId = botMatchId end
end

-- ============================================================
-- СПАВН БОТА
-- ============================================================

local function spawnBot()
	if not Characters then return end

	-- Выбираем героя
	botHeroId = BOT_CONFIG.HERO_ID
	if not botHeroId or not Characters[botHeroId] then
		botHeroId = HERO_LIST[math.random(1, #HERO_LIST)]
	end
	botHeroData = Characters[botHeroId]
	botMaxHP    = botHeroData and botHeroData.hp or 100
	botHP       = botMaxHP
	botCDs      = { Q=0, E=0, F=0, R=0 }
	botUltCharge = 0

	-- Позиция спавна
	local spawnCF = CFrame.new(20, 5, 0)
	local pList = Players:GetPlayers()
	if #pList > 0 and pList[1].Character then
		local pHRP = pList[1].Character:FindFirstChild("HumanoidRootPart")
		if pHRP then
			spawnCF = CFrame.new(pHRP.Position + Vector3.new(25, 0, 0))
		end
	end

	local model, hrp, hum = buildR6Body(botHeroId, spawnCF)
	botModel = model
	botAlive = true

	task.defer(registerBotInCombat)

	print(string.format("[TestBot] Spawned R6 bot: %s (%s) HP=%d diff=%s",
		BOT_CONFIG.BOT_NAME, botHeroId, botMaxHP, BOT_CONFIG.DIFFICULTY))
end

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ AI
-- ============================================================

local function getBotHRP()
	return botModel and botModel:FindFirstChild("HumanoidRootPart")
end

local function getBotHum()
	return botModel and botModel:FindFirstChildOfClass("Humanoid")
end

local function findTarget()
	local hrp = getBotHRP()
	if not hrp then return nil, math.huge end
	local best, bestDist = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if not p.Character then continue end
		local pHRP = p.Character:FindFirstChild("HumanoidRootPart")
		if not pHRP then continue end
		local s = CombatSystem and CombatSystem.getState(p.UserId)
		if not s or not s.alive then continue end
		if s.matchId ~= botMatchId then continue end
		local d = (pHRP.Position - hrp.Position).Magnitude
		if d < bestDist then bestDist = d; best = p end
	end
	return best, bestDist
end

-- API-обёртка для SkillHandlers
local function makeSkillAPI()
	return {
		dealDamage = function(attacker, victim, amount, dmgType)
			if not CombatSystem then return end
			-- Когда бот атакует игрока — передаём botProxy вместо fakePlayer
			local att = (type(attacker) == "table" and attacker._isBot) and botProxy or attacker
			-- victim тоже может быть botProxy
			local vic = (type(victim) == "table" and victim._isBot) and botProxy or victim
			-- Вызываем внутреннюю dealDamage через _G.CombatSystem
			if _G.CombatSystem and _G.CombatSystem.applyDamage then
				_G.CombatSystem.applyDamage(att, vic, amount, dmgType)
			else
				-- fallback: наносим урон напрямую
				if vic._isBot then
					botHP = math.max(0, botHP - math.floor(amount))
					local s = CombatSystem.getState(BOT_CONFIG.BOT_USER_ID)
					if s then s.hp = botHP; if botHP <= 0 then s.alive = false end end
					if hpFillPart then hpFillPart.Size = UDim2.new(math.clamp(botHP/botMaxHP,0,1),0,1,0) end
				end
			end
		end,
		getState   = function(uid) return CombatSystem and CombatSystem.getState(uid) end,
		heal       = function() end,
		fireTo     = function() end,
	}
end

-- ============================================================
-- АТАКА БОТА
-- ============================================================

local function botDoM1(target, dist)
	if not target or not target.Character then return end
	if not CombatSystem then return end
	local diff = DIFFICULTY_PARAMS[BOT_CONFIG.DIFFICULTY] or DIFFICULTY_PARAMS.Normal
	if dist > diff.m1Range then return end

	local now = tick()
	if now - botLastM1 < 0.6 then return end
	botLastM1 = now

	local vState = CombatSystem.getState(target.UserId)
	if not vState or not vState.alive then return end

	local dmg = (botHeroData and botHeroData.m1Damage or 8)
	-- Через dealDamage CombatSystem (учитывает щиты, статусы, HUD)
	local ok, err = pcall(function()
		-- Доступ к internal dealDamage через applyDamage API
		if _G.CombatSystem.applyDamage then
			_G.CombatSystem.applyDamage(botProxy, target, dmg, "Normal")
		else
			-- Фоллбек: наносим урон напрямую через dealDamageToPlayer
			if _G.CombatSystem.dealDamageToPlayer then
				_G.CombatSystem.dealDamageToPlayer(target.UserId, dmg, "Normal")
			end
		end
	end)
	if not ok then warn("[TestBot] M1 error:", err) end
end

local function botUseSkill(target, slot)
	if not SkillHandlers or not botHeroId then return end
	if not CombatSystem then return end

	local heroData = Characters and Characters[botHeroId]
	if not heroData then return end

	-- Проверяем кулдаун
	local now = tick()
	if now - (botCDs[slot] or 0) < (botCDs[slot .. "_cd"] or 8) then return end

	-- Кулдаун из Characters
	local cd = 8
	local idx = slot == "Q" and 1 or slot == "E" and 2 or slot == "F" and 3 or nil
	if idx and heroData.skills and heroData.skills[idx] then
		cd = heroData.skills[idx].cooldown or cd
	elseif slot == "R" then
		cd = (heroData.ultimate and heroData.ultimate.cooldown) or 30
	end

	-- Ульт — проверяем заряд
	if slot == "R" and botUltCharge < 100 then return end

	botCDs[slot]           = now
	botCDs[slot .. "_cd"]  = cd
	if slot == "R" then botUltCharge = 0 end

	local handler = SkillHandlers.GetHandler(botHeroId)
	if not handler or not handler[slot] then return end

	-- targetPos = позиция цели
	local targetPos
	if target and target.Character then
		local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
		targetPos = tHRP and tHRP.Position
	end

	local api = makeSkillAPI()
	local ok, err = pcall(handler[slot], botProxy, targetPos, api)
	if not ok then warn(string.format("[TestBot] Skill %s.%s error: %s", botHeroId, slot, tostring(err))) end

	-- Накапливаем ульт за скилл
	botUltCharge = math.min(100, botUltCharge + 5)
end

-- ============================================================
-- AI ЦИКЛ
-- ============================================================

local AI_TICK   = 0.1
local aiTimer   = 0
local SLOTS     = { "Q", "E", "F", "R" }

RunService.Heartbeat:Connect(function(dt)
	if not botAlive or not botModel then return end
	aiTimer = aiTimer - dt
	if aiTimer > 0 then return end
	aiTimer = AI_TICK

	local hrp = getBotHRP()
	local hum = getBotHum()
	if not hrp or not hum or hum.Health <= 0 then
		botAlive = false
		return
	end

	local diff   = DIFFICULTY_PARAMS[BOT_CONFIG.DIFFICULTY] or DIFFICULTY_PARAMS.Normal
	local target, dist = findTarget()
	if not target then return end

	-- Ульт заряд из matchState
	local bs = CombatSystem and CombatSystem.getState(BOT_CONFIG.BOT_USER_ID)
	if bs then botUltCharge = bs.ultCharge or botUltCharge end

	-- 1. Додж при низком HP
	if botHP < botMaxHP * 0.25 and math.random() < diff.dodgeChance then
		local tHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if tHRP then
			local away  = (hrp.Position - tHRP.Position).Unit
			local side  = Vector3.new(-away.Z, 0, away.X)
			local dir   = math.random() > 0.5 and side or -side
			hum:MoveTo(hrp.Position + dir * diff.strafeRange)
		end
		return
	end

	-- 2. Движение к цели
	if dist > diff.m1Range then
		hum:MoveTo(target.Character.HumanoidRootPart.Position)
	end

	-- 3. Скиллы (с вероятностью, через SkillHandlers)
	if math.random() < diff.skillChance then
		-- Сначала пробуем ульт
		if botUltCharge >= 100 then
			botUseSkill(target, "R")
		else
			-- Рандомный скилл
			local idx = math.random(1, 3)
			botUseSkill(target, SLOTS[idx])
		end
	end

	-- 4. M1 в диапазоне
	if dist <= diff.m1Range + 1 then
		task.delay(diff.reaction, function()
			if botAlive then botDoM1(target, dist) end
		end)
	end
end)

-- ============================================================
-- M1 ИГРОКА ПО БОТУ
-- (M1Attack remote прилетает с клиента — проверяем попадание в бота)
-- Патч в CombatSystem.M1Attack уже делает это через getMatchParticipants
-- Этот блок оставлен для страховки
-- ============================================================

-- ============================================================
-- СМЕРТЬ БОТА
-- ============================================================

local function onBotDeath(attacker)
	if not botAlive then return end
	botAlive = false

	-- Синхронизируем Humanoid
	local hum = getBotHum()
	if hum then hum.Health = 0 end

	-- Обновляем статус в CombatSystem
	if CombatSystem then
		local s = CombatSystem.getState(BOT_CONFIG.BOT_USER_ID)
		if s then
			s.alive  = false
			s.deaths = s.deaths + 1
		end
		if attacker and not (type(attacker)=="table" and attacker._isBot) then
			local aState = CombatSystem.getState(attacker.UserId)
			if aState then aState.kills = aState.kills + 1 end
		end
	end

	-- Уведомляем клиентов
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if Remotes then
		local rDied = Remotes:FindFirstChild("PlayerDied")
		if rDied then
			rDied:FireAllClients(
				BOT_CONFIG.BOT_USER_ID,
				attacker and attacker.UserId or 0,
				BOT_CONFIG.RESPAWN_TIME
			)
		end
	end

	-- Удаляем модель
	if botModel then
		botModel:Destroy()
		botModel = nil
	end
	print(string.format("[TestBot] Bot killed by %s",
		attacker and (type(attacker)=="table" and attacker.Name or attacker.Name) or "unknown"))

	-- Респавн
	task.delay(BOT_CONFIG.RESPAWN_TIME, function()
		if #Players:GetPlayers() > 0 then
			spawnBot()
		end
	end)
end

-- ============================================================
-- СИНХРОНИЗАЦИЯ HP (вызывается из CombatSystem)
-- ============================================================

local function syncBotHp(hp, maxHp)
	botHP    = math.max(0, hp)
	botMaxHP = maxHp or botMaxHP
	local pct = math.clamp(botHP / botMaxHP, 0, 1)
	if hpFillPart then hpFillPart.Size = UDim2.new(pct, 0, 1, 0) end
	-- Синхр Humanoid
	local hum = getBotHum()
	if hum then hum.Health = botHP end
end

-- ============================================================
-- forceStart (вызывается из MatchmakingService после 30с)
-- ============================================================

local function forceStartBotMatch(player, mode)
	if not player or not player.Parent then return end

	task.spawn(function()
		-- Ждём CombatSystem
		for _ = 1, 20 do
			if CombatSystem then break end
			task.wait(0.5)
		end
		CombatSystem = _G.CombatSystem
		if not CombatSystem then
			warn("[TestBot] CombatSystem not ready")
			return
		end

		-- Регистрируем игрока
		registerPlayerInBotMatch(player)

		-- Спавним бота
		if not botModel then spawnBot() end

		-- Ждём регистрации бота в CombatSystem
		for _ = 1, 15 do
			if CombatSystem.getState(BOT_CONFIG.BOT_USER_ID) then break end
			task.wait(0.3)
		end

		-- Запуск раунда с botProxy в списке
		for _ = 1, 10 do
			if _G.RoundService then break end
			task.wait(0.5)
		end
		if _G.RoundService then
			_G.RoundService.StartRound({ player, botProxy }, mode or "Normal")
		end

		print(string.format("[TestBot] forceStart complete: %s vs bot (%s)",
			player.Name, botHeroId or "?"))
	end)
end

-- ============================================================
-- УБОРКА
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	task.defer(function()
		if #Players:GetPlayers() == 0 then
			if botModel then botModel:Destroy(); botModel = nil end
			botAlive = false
		end
	end)
end)

-- ============================================================
-- PUBLIC API (_G.TestBot)
-- ============================================================

_G.TestBot = {
	-- Основное
	forceStart  = forceStartBotMatch,
	getProxy    = function() return botProxy end,
	getModel    = function() return botModel end,
	getUserId   = function() return BOT_CONFIG.BOT_USER_ID end,
	isAlive     = function() return botAlive end,
	getName     = function() return BOT_CONFIG.BOT_NAME end,
	-- HP
	getHpPct    = function()
		if botMaxHP <= 0 then return 0 end
		return math.clamp(botHP / botMaxHP, 0, 1)
	end,
	syncHp      = syncBotHp,
	-- События
	onDeath     = onBotDeath,
	-- matchId
	setMatchId  = function(id)
		botMatchId = id
		if CombatSystem then
			local s = CombatSystem.getState(BOT_CONFIG.BOT_USER_ID)
			if s then s.matchId = id end
		end
	end,
}

print(string.format(
	"[TestBot] Loaded ✓ | Difficulty: %s | Hero: %s",
	BOT_CONFIG.DIFFICULTY, BOT_CONFIG.HERO_ID or "random"
))
