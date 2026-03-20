-- HeroSelector.server.lua
-- Серверная логика выбора героя

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SelectHero = Remotes:WaitForChild("SelectHero")
local HeroSelected = Remotes:WaitForChild("HeroSelected")

-- База героев (12 персонажей)
local HEROES = {
	{ id = "flame_ronin",    name = "Flame Ronin",    hp = 180, dmg = 22, role = "Duelist",   rarity = "Rare" },
	{ id = "void_assassin", name = "Void Assassin",  hp = 130, dmg = 28, role = "Assassin",  rarity = "Epic" },
	{ id = "thunder_monk",  name = "Thunder Monk",   hp = 160, dmg = 20, role = "Skirmisher",rarity = "Rare" },
	{ id = "iron_titan",    name = "Iron Titan",     hp = 260, dmg = 15, role = "Tank",      rarity = "Epic" },
	{ id = "scarlet_archer",name = "Scarlet Archer", hp = 140, dmg = 24, role = "Ranged",    rarity = "Uncommon" },
	{ id = "eclipse_hero",  name = "Eclipse Hero",   hp = 150, dmg = 26, role = "Assassin",  rarity = "Legendary" },
	{ id = "storm_dancer",  name = "Storm Dancer",   hp = 145, dmg = 23, role = "Skirmisher",rarity = "Rare" },
	{ id = "blood_sage",    name = "Blood Sage",     hp = 120, dmg = 30, role = "Mage",      rarity = "Epic" },
	{ id = "crystal_guard",  name = "Crystal Guard",  hp = 240, dmg = 14, role = "Tank",     rarity = "Uncommon" },
	{ id = "shadow_twin",   name = "Shadow Twin",    hp = 155, dmg = 25, role = "Support",   rarity = "Rare" },
	{ id = "neon_blitz",    name = "Neon Blitz",     hp = 135, dmg = 27, role = "Ranged",    rarity = "Epic" },
	{ id = "jade_sentinel", name = "Jade Sentinel",  hp = 200, dmg = 18, role = "Duelist",   rarity = "Uncommon" },
}

-- Сохраняем выбранных героев игроков
local selectedHeroes = {}

local function getHeroById(id)
	for _, h in ipairs(HEROES) do
		if h.id == id then return h end
	end
	return nil
end

-- Обработка выбора героя от клиента
SelectHero.OnServerEvent:Connect(function(player, heroId)
	local hero = getHeroById(heroId)
	if not hero then
		warn("[HeroSelector] Unknown hero:", heroId)
		return
	end
	selectedHeroes[player.UserId] = hero
	print("[HeroSelector]", player.Name, "selected", hero.name)
	-- Оповещаем всех игроков
	HeroSelected:FireAllClients(player.UserId, hero)
end)

-- Очистка при выходе
Players.PlayerRemoving:Connect(function(player)
	selectedHeroes[player.UserId] = nil
end)

-- Публичное API для других серверных скриптов
return {
	getSelected = function(userId) return selectedHeroes[userId] end,
	getAllHeroes = function() return HEROES end,
}
