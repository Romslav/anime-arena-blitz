-- HeroSelector.server.lua
-- Серверная логика выбора героя

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SelectHero = Remotes:WaitForChild("SelectHero")
local HeroSelected = Remotes:WaitForChild("HeroSelected")

-- База героев (12 персонажей)
-- Храним оба формата ID для поиска по любому из них
local HEROES = {
	{ id = "flame_ronin",     pascalId = "FlameRonin",    name = "Flame Ronin",     hp = 180, dmg = 22, role = "Duelist",     rarity = "Rare"      },
	{ id = "void_assassin",   pascalId = "VoidAssassin",   name = "Void Assassin",   hp = 130, dmg = 28, role = "Assassin",    rarity = "Epic"      },
	{ id = "thunder_monk",    pascalId = "ThunderMonk",    name = "Thunder Monk",    hp = 160, dmg = 20, role = "Skirmisher",  rarity = "Rare"      },
	{ id = "iron_titan",      pascalId = "IronTitan",      name = "Iron Titan",      hp = 260, dmg = 15, role = "Tank",        rarity = "Epic"      },
	{ id = "scarlet_archer",  pascalId = "ScarletArcher",  name = "Scarlet Archer",  hp = 140, dmg = 24, role = "Ranged",      rarity = "Uncommon"  },
	{ id = "eclipse_hero",    pascalId = "EclipseHero",    name = "Eclipse Hero",    hp = 150, dmg = 26, role = "Assassin",    rarity = "Legendary" },
	{ id = "storm_dancer",    pascalId = "StormDancer",    name = "Storm Dancer",    hp = 145, dmg = 23, role = "Skirmisher",  rarity = "Rare"      },
	{ id = "blood_sage",      pascalId = "BloodSage",      name = "Blood Sage",      hp = 120, dmg = 30, role = "Mage",        rarity = "Epic"      },
	{ id = "crystal_guard",   pascalId = "CrystalGuard",   name = "Crystal Guard",   hp = 240, dmg = 14, role = "Tank",        rarity = "Uncommon"  },
	{ id = "shadow_twin",     pascalId = "ShadowTwin",     name = "Shadow Twin",     hp = 155, dmg = 25, role = "Support",     rarity = "Rare"      },
	{ id = "neon_blitz",      pascalId = "NeonBlitz",      name = "Neon Blitz",      hp = 135, dmg = 27, role = "Ranged",      rarity = "Epic"      },
	{ id = "jade_sentinel",   pascalId = "JadeSentinel",   name = "Jade Sentinel",   hp = 200, dmg = 18, role = "Duelist",     rarity = "Uncommon"  },
}

-- Сохраняем выбранных героев игроков
local selectedHeroes = {}

-- FIX: принимаем оба формата:
--   snake_case  — "flame_ronin"  (старые ссылки)
--   PascalCase  — "FlameRonin"   (клиент HeroSelector.client.lua)
local function getHeroById(id)
	for _, h in ipairs(HEROES) do
		if h.id == id or h.pascalId == id then return h end
	end
	return nil
end

-- Обработка выбора героя от клиента
SelectHero.OnServerEvent:Connect(function(player, heroId)
	if type(heroId) ~= "string" then
		warn("[HeroSelector] Invalid heroId from", player.Name, ":", heroId)
		return
	end

	local hero = getHeroById(heroId)
	if not hero then
		warn("[HeroSelector] Unknown hero '", heroId, "' from", player.Name)
		return
	end

	selectedHeroes[player.UserId] = hero
	print(string.format("[HeroSelector] %s selected %s (id=%s)", player.Name, hero.name, hero.pascalId))

	-- Оповещаем всех клиентов
	HeroSelected:FireAllClients(player.UserId, hero)

	-- FIX: просим CharacterService заспавнить героя с полными статами из Characters.lua
	-- (если CharacterService не подписан на SelectHero самостоятельно)
	task.defer(function()
		local CharSvc = _G.CharacterService
		if not CharSvc then return end
		-- Избегаем двойной инициализации — если герой уже зарегистрирован, пропускаем
		if CharSvc.GetSelectedHero and CharSvc.GetSelectedHero(player.UserId) then return end
		local fullData = CharSvc.GetHeroData and CharSvc.GetHeroData(hero.pascalId)
		if fullData and CharSvc.SpawnWithHero then
			CharSvc.SpawnWithHero(player, fullData)
		end
	end)
end)

-- Очистка при выходе
Players.PlayerRemoving:Connect(function(player)
	selectedHeroes[player.UserId] = nil
end)

-- Публичное API через _G для доступа из GameManager
_G.HeroSelector = {
	getSelected = function(userId)
		return selectedHeroes[userId]
	end,
	-- FIX: setSelected — позволяет CharacterService синхронизировать выбор сюда
	setSelected = function(userId, heroData)
		selectedHeroes[userId] = heroData
	end,
	getAllHeroes = function()
		return HEROES
	end,
}
