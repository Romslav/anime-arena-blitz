-- ClientManager.client.lua | Anime Arena: Blitz Mode
-- Main client manager: input, events, state

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local VFXManager = require(script.Parent:WaitForChild("VFXManager"))

local ClientState = {
	Hero = "FlameRonin", -- Default for testing
	UltCharge = 0,
	IsStunned = false,
}

local KEYBINDS = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
}

-- === Обработка Ввода ===

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	
	local skillKey = KEYBINDS[input.KeyCode]
	if skillKey then
		-- Отправляем запрос на сервер
		Remotes.UseSkill:FireServer(skillKey)
		print("[Client] Requested skill:", skillKey)
	end
end)

-- === Обработка Событий от Сервера ===

-- Визуализация использования скиллов (своих и чужих)
Remotes.SkillUsed.OnClientEvent:Connect(function(userId, skillKey)
	-- Тут мы могли бы получить heroId игрока из общей таблицы или атрибутов
	-- Для MVP предположим, что мы знаем героев (или добавим в эвент позже)
	VFXManager.PlaySkillVFX(userId, skillKey, "FlameRonin") 
end)

-- Визуализация статус-эффектов (Burn, Stun и т.д.)
Remotes.UpdateEffect.OnClientEvent:Connect(function(effectType, isActive, duration)
	VFXManager.UpdateStatusEffect(LocalPlayer.UserId, effectType, isActive, duration)
	
	if effectType == "Stun" then
		ClientState.IsStunned = isActive
	end
end)

-- Обновление HP (в HUD)
Remotes.UpdateHP.OnClientEvent:Connect(function(currentHp, maxHp)
	-- Вызов функции HUD
	local HUD = require(script.Parent:WaitForChild("HUD"))
	if HUD and HUD.UpdateHP then
		HUD.UpdateHP(currentHp, maxHp)
	end
end)

-- Уведомления
Remotes.ShowNotification.OnClientEvent:Connect(function(message, color)
	print("[Notification]", message)
	-- Логика UI уведомления
end)

print("[ClientManager] Initialized")
