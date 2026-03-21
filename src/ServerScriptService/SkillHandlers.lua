-- SkillHandlers.lua | Anime Arena: Blitz Mode
-- Логика способностей всех героев

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatusEffects = require(script.Parent.StatusEffects)

local SkillHandlers = {}

-- === Вспомогательные функции ===

local function getCharactersInRange(position, range, excludeUserId)
	local targets = {}
	for _, player in pairs(game.Players:GetPlayers()) do
		if player.UserId ~= excludeUserId and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (player.Character.HumanoidRootPart.Position - position).Magnitude
			if distance <= range then
				table.insert(targets, player)
			end
		end
	end
	return targets
end

-- === Flame Ronin ===

SkillHandlers.FlameRonin = {
	-- Q: Flame Dash
	Q = function(player, combatSystem)
		local character = player.Character
		if not character then return end
		
		-- Логика рывка (VFX на клиенте через SkillUsed)
		local hrp = character.HumanoidRootPart
		local dashDirection = hrp.CFrame.LookVector
		
		-- Наносим урон в пути
		local targets = getCharactersInRange(hrp.Position + dashDirection * 5, 8, player.UserId)
		for _, target in pairs(targets) do
			combatSystem.dealDamage(player, target, 8)
			StatusEffects.ApplyBurn(target.UserId, 3, 2)
		end
	end,
	
	-- E: Rising Slash
	E = function(player, combatSystem)
		local character = player.Character
		if not character then return end
		
		local targets = getCharactersInRange(character.HumanoidRootPart.Position, 10, player.UserId)
		for _, target in pairs(targets) do
			combatSystem.dealDamage(player, target, 10)
			-- Подбрасывание (Launch) - физика на сервере или через статус
			StatusEffects.ApplyStun(target.UserId, 0.5)
		end
	end,
	
	-- R: Phoenix Cut (Ult)
	R = function(player, combatSystem)
		local character = player.Character
		if not character then return end
		
		local targets = getCharactersInRange(character.HumanoidRootPart.Position, 15, player.UserId)
		for _, target in pairs(targets) do
			combatSystem.dealDamage(player, target, 34)
			StatusEffects.ApplyBurn(target.UserId, 5, 4)
		end
	end
}

-- === Void Assassin ===

SkillHandlers.VoidAssassin = {
	-- Q: Blink Strike
	Q = function(player, combatSystem)
		-- Телепорт к цели или вперед + урон
		local character = player.Character
		if not character then return end
		
		local targets = getCharactersInRange(character.HumanoidRootPart.Position, 20, player.UserId)
		if #targets > 0 then
			local target = targets[1]
			-- Телепортация (условно)
			character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
			combatSystem.dealDamage(player, target, 9)
		end
	end,
	
	-- E: Shadow Feint
	E = function(player, combatSystem)
		-- Инвиз или уклонение
		StatusEffects.ApplyBuffSpeed(player.UserId, 2, 1.5)
	end,
	
	-- R: Silent Execution (Ult)
	R = function(player, combatSystem)
		local targets = getCharactersInRange(player.Character.HumanoidRootPart.Position, 10, player.UserId)
		for _, target in pairs(targets) do
			local damage = 40
			local targetState = combatSystem.getState(target.UserId)
			-- Пассивка: +50% если HP < 30%
			if targetState and targetState.hp / targetState.maxHp < 0.3 then
				damage = damage * 1.5
			end
			combatSystem.dealDamage(player, target, damage)
		end
	end
}

-- === Thunder Monk ===

SkillHandlers.ThunderMonk = {
	Q = function(player, combatSystem)
		local targets = getCharactersInRange(player.Character.HumanoidRootPart.Position, 12, player.UserId)
		if #targets > 0 then
			local target = targets[1]
			combatSystem.dealDamage(player, target, 9)
			StatusEffects.ApplyStun(target.UserId, 0.4)
		end
	end,
	
	E = function(player, combatSystem)
		local targets = getCharactersInRange(player.Character.HumanoidRootPart.Position, 15, player.UserId)
		for _, target in pairs(targets) do
			combatSystem.dealDamage(player, target, 4)
			StatusEffects.ApplyStun(target.UserId, 0.6)
		end
	end,
	
	R = function(player, combatSystem)
		local targets = getCharactersInRange(player.Character.HumanoidRootPart.Position, 25, player.UserId)
		for _, target in pairs(targets) do
			combatSystem.dealDamage(player, target, 30)
			StatusEffects.ApplyStun(target.UserId, 1.2)
		end
	end
}

-- === Остальные герои (заглушки для структуры) ===

-- Функция для авто-генерации обработчиков на основе Characters.lua
function SkillHandlers.Init(Characters)
	for heroId, data in pairs(Characters) do
		if not SkillHandlers[heroId] then
			SkillHandlers[heroId] = {
				Q = function(player, combatSystem) 
					print("Executing Q for", heroId)
					-- Базовая логика если нет кастомной
					local skillData = data.skills[1]
					combatSystem.defaultSkillHit(player, skillData)
				end,
				E = function(player, combatSystem) 
					print("Executing E for", heroId)
					local skillData = data.skills[2]
					combatSystem.defaultSkillHit(player, skillData)
				end,
				R = function(player, combatSystem) 
					print("Executing Ult for", heroId)
					combatSystem.defaultSkillHit(player, data.ultimate)
				end
			}
		end
	end
end

return SkillHandlers
