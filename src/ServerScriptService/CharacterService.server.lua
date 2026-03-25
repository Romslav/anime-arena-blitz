-- CharacterService.server.lua | Anime Arena: Blitz
-- Управляет выбором героя, спавном, применением статов и GameMode модификаторов.
-- Публичный API: _G.CharacterService
-- НЕ является ModuleScript — не использует return для экспорта.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage:WaitForChild("Characters"))
local Remotes    = ReplicatedStorage:WaitForChild("Remotes")

local rSelectHero       = Remotes:WaitForChild("SelectHero")
local rHeroSelected     = Remotes:WaitForChild("HeroSelected")
local rCharacterSpawned = Remotes:WaitForChild("CharacterSpawned")
local rSelectStarter    = Remotes:WaitForChild("SelectStarter")
local rShowStarter      = Remotes:WaitForChild("ShowStarterSelection")
local rHeroUnlocked     = Remotes:WaitForChild("HeroUnlocked")
local rShowNotification = Remotes:WaitForChild("ShowNotification")

-- ============================================================
-- НОРМАЛИЗАЦИЯ ID (snake_case → PascalCase)
-- ============================================================

local HERO_ID_MAP = {
	flame_ronin     = "FlameRonin",
	void_assassin   = "VoidAssassin",
	thunder_monk    = "ThunderMonk",
	iron_titan      = "IronTitan",
	scarlet_archer  = "ScarletArcher",
	eclipse_hero    = "EclipseHero",
	storm_dancer    = "StormDancer",
	blood_sage      = "BloodSage",
	crystal_guard   = "CrystalGuard",
	shadow_twin     = "ShadowTwin",
	neon_blitz      = "NeonBlitz",
	jade_sentinel   = "JadeSentinel",
}

-- ============================================================
-- ФОЛЛБЕК для героев, не описанных в Characters.lua
-- ============================================================

local FALLBACK_STATS = {
	IronTitan = {
		id="IronTitan", name="Iron Titan", role="Tank", rarity="Rare",
		hp=260, m1Damage=15, speed=12,
		skills = {
			{name="Iron Slam",    damage=12, cooldown=8,  type="AoE",     anim="rbxassetid://0"},
			{name="Shield Wall",  damage=0,  cooldown=12, type="Defense", anim="rbxassetid://0"},
			{name="Ground Quake", damage=18, cooldown=15, type="AoE",     anim="rbxassetid://0"},
		},
		ultimate = {name="Titan Fall",       damage=45, cooldown=70, anim="rbxassetid://0"},
		passive  = "Blocks 15% damage from front",
	},
	ScarletArcher = {
		id="ScarletArcher", name="Scarlet Archer", role="Ranged", rarity="Rare",
		hp=140, m1Damage=24, speed=15,
		skills = {
			{name="Arrow Rain",    damage=14, cooldown=9, type="AoE",    anim="rbxassetid://0"},
			{name="Piercing Shot", damage=20, cooldown=8, type="Linear", anim="rbxassetid://0"},
			{name="Evasion Roll",  damage=0,  cooldown=7, type="Dodge",  anim="rbxassetid://0"},
		},
		ultimate = {name="Storm of Arrows",  damage=38, cooldown=55, anim="rbxassetid://0"},
		passive  = "Headshots deal +30% damage",
	},
	EclipseHero = {
		id="EclipseHero", name="Eclipse Hero", role="Assassin", rarity="Legendary",
		hp=150, m1Damage=26, speed=18,
		skills = {
			{name="Eclipse Slash", damage=15, cooldown=7,  type="Burst",    anim="rbxassetid://0"},
			{name="Lunar Phase",   damage=10, cooldown=9,  type="Teleport", anim="rbxassetid://0"},
			{name="Dark Veil",     damage=0,  cooldown=12, type="Stealth",  anim="rbxassetid://0"},
		},
		ultimate = {name="Total Eclipse",    damage=44, cooldown=60, anim="rbxassetid://0"},
		passive  = "Crit chance +25% from behind",
	},
	StormDancer = {
		id="StormDancer", name="Storm Dancer", role="Skirmisher", rarity="Common",
		hp=145, m1Damage=23, speed=19,
		skills = {
			{name="Tempest Step", damage=8,  cooldown=6,  type="Dash",  anim="rbxassetid://0"},
			{name="Wind Spiral",  damage=12, cooldown=8,  type="AoE",   anim="rbxassetid://0"},
			{name="Gale Parry",   damage=0,  cooldown=10, type="Parry", anim="rbxassetid://0"},
		},
		ultimate = {name="Cyclone Fury",     damage=36, cooldown=55, anim="rbxassetid://0"},
		passive  = "Hits build Storm stacks for speed boost",
	},
	BloodSage = {
		id="BloodSage", name="Blood Sage", role="Mage", rarity="Legendary",
		hp=120, m1Damage=30, speed=14,
		skills = {
			{name="Bloodbolt",     damage=18, cooldown=7,  type="Projectile", anim="rbxassetid://0"},
			{name="Crimson Bind",  damage=6,  cooldown=10, type="Root",       anim="rbxassetid://0"},
			{name="Sanguine Burst",damage=22, cooldown=14, type="AoE",        anim="rbxassetid://0"},
		},
		ultimate = {name="Blood Moon",       damage=50, cooldown=65, anim="rbxassetid://0"},
		passive  = "Drains 5 HP per hit",
	},
	CrystalGuard = {
		id="CrystalGuard", name="Crystal Guard", role="Tank", rarity="Rare",
		hp=240, m1Damage=14, speed=13,
		skills = {
			{name="Crystal Spike", damage=10, cooldown=7,  type="AoE",    anim="rbxassetid://0"},
			{name="Prism Barrier", damage=0,  cooldown=12, type="Shield", anim="rbxassetid://0"},
			{name="Shatter Rush",  damage=16, cooldown=10, type="Dash",   anim="rbxassetid://0"},
		},
		ultimate = {name="Crystal Fortress", damage=30, cooldown=70, anim="rbxassetid://0"},
		passive  = "Crystal shards reduce incoming damage",
	},
	ShadowTwin = {
		id="ShadowTwin", name="Shadow Twin", role="Support", rarity="Epic",
		hp=155, m1Damage=25, speed=17,
		skills = {
			{name="Twin Lash",    damage=12, cooldown=6,  type="Burst",    anim="rbxassetid://0"},
			{name="Shadow Clone", damage=0,  cooldown=15, type="Clone",    anim="rbxassetid://0"},
			{name="Mist Step",    damage=0,  cooldown=8,  type="Teleport", anim="rbxassetid://0"},
		},
		ultimate = {name="Dark Mirror",      damage=35, cooldown=60, anim="rbxassetid://0"},
		passive  = "Clone deals 50% damage",
	},
	NeonBlitz = {
		id="NeonBlitz", name="Neon Blitz", role="Ranged", rarity="Epic",
		hp=135, m1Damage=27, speed=16,
		skills = {
			{name="Neon Burst",   damage=16, cooldown=7,  type="Projectile", anim="rbxassetid://0"},
			{name="Circuit Dash", damage=0,  cooldown=6,  type="Dash",       anim="rbxassetid://0"},
			{name="Overload",     damage=20, cooldown=12, type="AoE",        anim="rbxassetid://0"},
		},
		ultimate = {name="Neon Overdrive",   damage=42, cooldown=58, anim="rbxassetid://0"},
		passive  = "Every 4th hit fires a neon pulse",
	},
	JadeSentinel = {
		id="JadeSentinel", name="Jade Sentinel", role="Duelist", rarity="Rare",
		hp=200, m1Damage=18, speed=15,
		skills = {
			{name="Jade Strike",   damage=14, cooldown=7,  type="Burst", anim="rbxassetid://0"},
			{name="Sentinel Step", damage=0,  cooldown=6,  type="Dodge", anim="rbxassetid://0"},
			{name="Earthen Crush", damage=18, cooldown=11, type="AoE",   anim="rbxassetid://0"},
		},
		ultimate = {name="Jade Wrath",       damage=38, cooldown=60, anim="rbxassetid://0"},
		passive  = "Perfect parry resets a skill cooldown",
	},
}

-- ============================================================
-- СОСТОЯНИЕ
-- ============================================================

local selectedHeroes = {}  -- [userId] = heroData

local CharacterService = {}
_G.CharacterService = CharacterService

-- ============================================================
-- ПУБЛИЧНЫЙ API
-- ============================================================

--- Получить данные героя (Characters.lua → fallback → FlameRonin)
function CharacterService.GetHeroData(heroId)
	local normalizedId = HERO_ID_MAP[heroId] or heroId
	local data = Characters[normalizedId] or FALLBACK_STATS[normalizedId]
	if not data then
		warn(string.format("[CharacterService] Unknown heroId '%s' (normalized: '%s') — using FlameRonin",
			tostring(heroId), tostring(normalizedId)))
		return Characters.FlameRonin
	end
	return data
end

--- Получить выбранного героя игрока
function CharacterService.GetSelectedHero(userId)
	return selectedHeroes[userId]
end

--- Применить статы героя к персонажу
function CharacterService.ApplyStats(character, heroData)
	if not character or not heroData then return end

	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = heroData.hp or 100
		hum.Health    = hum.MaxHealth
		hum.WalkSpeed = heroData.speed or 16
	end

	local tag = character:FindFirstChild("HeroTag")
	if not tag then
		tag        = Instance.new("StringValue")
		tag.Name   = "HeroTag"
		tag.Parent = character
	end
	tag.Value = heroData.id
end

--- Спавнить с героем (базовый)
--- BUG-FIX: disconnect предыдущего коннекта, не накапливаем бесконечные коннекты
local spawnConnections = {}  -- [userId] = RBXScriptConnection

local function disconnectSpawnConn(userId)
	if spawnConnections[userId] then
		spawnConnections[userId]:Disconnect()
		spawnConnections[userId] = nil
	end
end

function CharacterService.SpawnWithHero(player, heroData)
	if not player or not heroData then return end
	selectedHeroes[player.UserId] = heroData
	disconnectSpawnConn(player.UserId)  -- BUG-FIX: убираем старый коннект

	local function applyToChar(character)
		task.wait(0.15)
		if not character or not character.Parent then return end
		CharacterService.ApplyStats(character, heroData)
		rCharacterSpawned:FireAllClients(player.UserId, heroData.id, heroData.name)
		-- FIX: НЕ вызываем CombatSystem.initPlayer здесь —
		-- это делает RoundService.StartRound с правильным matchId и mode.
		-- Двойной initPlayer перезаписывал состояние игрока matchId="default",
		-- из-за чего M1/скиллы тихо игнорировались (участники не совпадали по matchId).
	end

	-- BUG-FIX: НЕ вызываем LoadCharacter сами — RespawnHandler делает это
	-- Просто применяем к текущему персонажу если он уже есть
	if player.Character then
		task.spawn(applyToChar, player.Character)
	end
	spawnConnections[player.UserId] = player.CharacterAdded:Connect(applyToChar)
end

--- Спавнить с героем + применить GameMode модификаторы
function CharacterService.SpawnWithMode(player, heroData, gameMode, matchId)
	if not player or not heroData then return end
	selectedHeroes[player.UserId] = heroData
	disconnectSpawnConn(player.UserId)  -- BUG-FIX: убираем старый коннект

	local function applyToChar(character)
		task.wait(0.15)
		if not character or not character.Parent then return end
		CharacterService.ApplyStats(character, heroData)

		if _G.GameModeModifiers and gameMode then
			local ok, err = pcall(_G.GameModeModifiers.ApplyToPlayer, player, gameMode, heroData)
			if not ok then warn("[CharacterService] GameModeModifiers error:", err) end
		end

		rCharacterSpawned:FireAllClients(player.UserId, heroData.id, heroData.name)
		-- FIX: НЕ вызываем CombatSystem.initPlayer здесь —
		-- это делает RoundService.StartRound с правильным matchId и mode.
		-- Если matchId передан (вызов через GameManager.StartMatch), инициализируем.
		if _G.CombatSystem and matchId then
			_G.CombatSystem.initPlayer(player, heroData, matchId, gameMode)
		end
	end

	-- BUG-FIX: НЕ вызываем LoadCharacter сами — только применяем к текущему
	if player.Character then
		task.spawn(applyToChar, player.Character)
	end
	spawnConnections[player.UserId] = player.CharacterAdded:Connect(applyToChar)
end

-- ============================================================
-- REMOTE: выбор героя с клиента
-- ============================================================

rSelectHero.OnServerEvent:Connect(function(player, heroId)
	if type(heroId) ~= "string" then
		warn("[CharacterService] Invalid heroId from", player.Name)
		return
	end

	-- АНТИ-ЧИТ: проверяем, открыт ли герой у игрока
	if _G.DataStore then
		local pData = _G.DataStore.GetData(player.UserId)
		if pData and pData.unlockedHeroes and #pData.unlockedHeroes > 0 then
			local normalized = HERO_ID_MAP[heroId] or heroId
			if not table.find(pData.unlockedHeroes, normalized) then
				warn(string.format("[Anti-Cheat] %s попытка выбрать заблокированного героя '%s'",
					player.Name, heroId))
				return
			end
		end
	end

	local heroData = CharacterService.GetHeroData(heroId)
	selectedHeroes[player.UserId] = heroData
	rHeroSelected:FireClient(player, heroData.id, heroData.name)

	-- Синхронизуем с HeroSelector.server
	if _G.HeroSelector and _G.HeroSelector.setSelected then
		_G.HeroSelector.setSelected(player.UserId, heroData)
	end

	-- Статистика игр за героя
	if _G.DataStore then
		_G.DataStore.RecordHeroPlay(player.UserId, heroData.id)
	end

	print(string.format("[CharacterService] %s selected: %s", player.Name, heroData.name))
end)

-- ============================================================
-- ОНБОРДИНГ: первый выбор стартового героя
-- ============================================================

local STARTER_HEROES = { "FlameRonin", "IronTitan", "ThunderMonk" }

-- При первом входе игрока отправляем ShowStarterSelection
Players.PlayerAdded:Connect(function(player)
	task.delay(3, function()
		if not player or not player.Parent then return end
		if not _G.DataStore then return end
		local pData = _G.DataStore.GetData(player.UserId)
		if pData and pData.isFirstTime == true then
			rShowStarter:FireClient(player)
		end
	end)
end)

rSelectStarter.OnServerEvent:Connect(function(player, heroId)
	if type(heroId) ~= "string" then return end

	-- Проверяем: только стартовые герои допустимы
	if not table.find(STARTER_HEROES, heroId) then
		warn(string.format("[CharacterService] %s попытка недопустимого стартера '%s'", player.Name, heroId))
		return
	end

	if not _G.DataStore then return end
	local pData = _G.DataStore.GetData(player.UserId)
	if not pData then return end
	if not pData.isFirstTime then return end  -- защита от повторного вызова

	_G.DataStore.UnlockHero(player.UserId, heroId)
	_G.DataStore.SetFirstTimeDone(player.UserId)

	rHeroUnlocked:FireClient(player, heroId)
	rShowNotification:FireClient(player,
		"🎉 Добро пожаловать! Ваш первый герой разблокирован!", "success")
	print(string.format("[CharacterService] %s выбрал стартера: %s", player.Name, heroId))
end)

-- ============================================================
-- ЛОББИ — МИРНЫЙ СПАВН
-- ============================================================

-- Координаты точки спавна в лобби (переопределить под карту)
local LOBBY_SPAWN_CF = CFrame.new(0, 10, 0)

--- Спавнить игрока в нейтральной зоне лобби без героя и боевых тегов.
--- Вызывается при первом входе и при возврате из матча.
---@param player Player
---@param spawnCF CFrame|nil  — переопределить позицию спавна (опционально)
function CharacterService.SpawnInLobby(player, spawnCF)
	if not player or not player.Parent then return end

	-- Отключаем старый коннект, чтобы не накапливать
	disconnectSpawnConn(player.UserId)
	selectedHeroes[player.UserId] = nil

	-- Перезапускаем персонажа
	local ok, err = pcall(function() player:LoadCharacter() end)
	if not ok then
		warn("[CharacterService] LoadCharacter failed for", player.Name, ":", err)
		return
	end

	-- Ждём появления персонажа
	local char = player.Character or player.CharacterAdded:Wait()

	task.wait(0.2)  -- дать физике осесть
	if not char or not char.Parent then return end

	-- Телепортируем
	local cf = spawnCF or LOBBY_SPAWN_CF
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CFrame = cf end

	-- Убираем боевые теги
	local tag = char:FindFirstChild("HeroTag")
	if tag then tag:Destroy() end

	-- Стандартные параметры мирного состояния
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = 100
		hum.Health    = 100
		hum.WalkSpeed = 16
		hum.JumpPower = 50
	end

	print(string.format("[CharacterService] %s spawned in Lobby (peaceful)", player.Name))
end

--- Задать координаты точки спавна лобби (вызывается из NPCService при инициализации)
---@param cf CFrame
function CharacterService.SetLobbySpawn(cf)
	LOBBY_SPAWN_CF = cf
end

-- ============================================================
-- УБОРКА
-- ============================================================

Players.PlayerRemoving:Connect(function(player)
	disconnectSpawnConn(player.UserId)
	selectedHeroes[player.UserId] = nil
end)

print("[CharacterService] Initialized ✓")
