-- VFXManager.lua | Anime Arena: Blitz Mode
-- Клиентская система эффектов: частицы, звуки, анимации

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFXManager = {}

-- === Настройки эффектов ===
local EFFECT_COLORS = {
	Burn = Color3.fromRGB(255, 100, 0),
	Poison = Color3.fromRGB(100, 255, 0),
	Stun = Color3.fromRGB(255, 255, 0),
	Slow = Color3.fromRGB(0, 200, 255),
	Shield = Color3.fromRGB(255, 255, 255),
}

-- Хранилище активных эффектов на персонажах: { [userId] = { [effectType] = Instance } }
local activeVFX = {}

-- === Функции визуализации ===

function VFXManager.PlaySkillVFX(userId, skillKey, heroId)
	local player = game.Players:GetPlayerByUserId(userId)
	if not player or not player.Character then return end
	
	local char = player.Character
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	print("[VFX] Playing skill VFX for", heroId, skillKey)
	
	-- Логика специфичных эффектов героев
	if heroId == "FlameRonin" then
		if skillKey == "Q" then
			VFXManager.CreateTrail(hrp, EFFECT_COLORS.Burn, 0.5)
		elseif skillKey == "R" then
			VFXManager.CreateExplosion(hrp.Position, 15, EFFECT_COLORS.Burn)
		end
	elseif heroId == "ThunderMonk" then
		VFXManager.CreateLightning(hrp.Position, 10)
	end
	
	-- Универсальный звук
	VFXManager.PlaySound("Skill_" .. skillKey, hrp.Position)
end

function VFXManager.UpdateStatusEffect(userId, effectType, isActive, duration)
	local player = game.Players:GetPlayerByUserId(userId)
	if not player or not player.Character then return end
	
	if not activeVFX[userId] then activeVFX[userId] = {} end
	
	if isActive then
		-- Если эффект уже есть, удаляем старый
		if activeVFX[userId][effectType] then
			activeVFX[userId][effectType]:Destroy()
		end
		
		-- Создаем новый визуальный эффект (Highlight или Aura)
		local highlight = Instance.new("Highlight")
		highlight.Name = "Effect_" .. effectType
		highlight.FillColor = EFFECT_COLORS[effectType] or Color3.new(1,1,1)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0
		highlight.Adornee = player.Character
		highlight.Parent = player.Character
		
		activeVFX[userId][effectType] = highlight
		
		-- Авто-удаление через duration (если пришло)
		if duration and duration > 0 then
			task.delay(duration, function()
				if highlight and highlight.Parent then
					highlight:Destroy()
				end
			end)
		end
	else
		-- Удаляем эффект принудительно
		if activeVFX[userId][effectType] then
			activeVFX[userId][effectType]:Destroy()
			activeVFX[userId][effectType] = nil
		end
	end
end

-- === Вспомогательные VFX ===

function VFXManager.CreateTrail(part, color, duration)
	local attachment0 = Instance.new("Attachment", part)
	local attachment1 = Instance.new("Attachment", part)
	attachment1.Position = Vector3.new(0, 5, 0)
	
	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Color = ColorSequence.new(color)
	trail.Lifetime = 0.3
	trail.Parent = part
	
	task.delay(duration, function()
		trail.Enabled = false
		task.wait(0.5)
		trail:Destroy()
		attachment0:Destroy()
		attachment1:Destroy()
	end)
end

function VFXManager.CreateExplosion(position, radius, color)
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(1, 1, 1)
	sphere.Position = position
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.Color = color
	sphere.Material = Enum.Material.Neon
	sphere.Transparency = 0.5
	sphere.Parent = workspace
	
	local tween = TweenService:Create(sphere, TweenInfo.new(0.5), {
		Size = Vector3.new(radius, radius, radius),
		Transparency = 1
	})
	tween:Play()
	tween.Completed:Connect(function() sphere:Destroy() end)
end

function VFXManager.CreateLightning(position, range)
	-- Простая имитация молнии
	VFXManager.CreateExplosion(position, range, EFFECT_COLORS.Stun)
end

function VFXManager.PlaySound(soundName, position)
	-- В продакшене тут берется звук из SoundService по имени
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://0" -- Заменится на реальные ID в Config
	sound.Volume = 0.5
	if position then
		local attachment = Instance.new("Attachment", workspace.Terrain)
		attachment.Position = position
		sound.Parent = attachment
		sound.Ended:Connect(function() attachment:Destroy() end)
	else
		sound.Parent = game.SoundService
		sound.Ended:Connect(function() sound:Destroy() end)
	end
	sound:Play()
end

return VFXManager
