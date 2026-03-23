-- RespawnHandler.server.lua | Anime Arena: Blitz
-- FIX-1: убран двойной LoadCharacter (SpawnWithMode тоже звал его)
-- FIX-2: state.alive восстанавливается через CombatSystem.revivePlayer
-- FIX-3: PlayerRespawned стреляет только после полной загрузки персонажа
-- FIX-4: RegisterPlayer вызывается из RoundService.StartRound правильно

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local rPlayerDied       = Remotes:WaitForChild("PlayerDied")
local rPlayerRespawned  = Remotes:WaitForChild("PlayerRespawned")
local rShowNotif        = Remotes:WaitForChild("ShowNotification")
local rUpdateHP         = Remotes:WaitForChild("UpdateHP")

-- playerMatchData[userId] = { matchId, mode }
local playerMatchData = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function getModifiers()    return _G.GameModeModifiers end
local function getCharSvc()      return _G.CharacterService  end
local function getCombat()       return _G.CombatSystem      end

-- ============================================================
-- CORE: обработка смерти одного игрока
-- ============================================================

local function onCharacterDeath(player)
	local matchData = playerMatchData[player.UserId]
	if not matchData then return end

	local Mods    = getModifiers()
	local CharSvc = getCharSvc()
	local Combat  = getCombat()

	-- Время респавна из режима
	local respawnTime = 5
	if Mods and Mods.GetRespawnTime then
		local ok, t = pcall(Mods.GetRespawnTime, matchData.mode)
		if ok and type(t) == "number" then respawnTime = t end
	end

	print(string.format("[RespawnHandler] %s died. Respawn in %ds (mode: %s)",
		player.Name, respawnTime, matchData.mode))

	task.wait(respawnTime)

	-- Игрок мог выйти за время ожидания
	if not player or not player.Parent then return end

	-- BUG-A FIX: CharacterAdded:Wait() может дедлокнуть если спавн произошёл
	-- быстрее чем мы успели подписаться. Используем Promise-паттерн:
	-- подписываемся ДО LoadCharacter, чтобы гарантированно поймать событие.
	local newChar = nil
	local charConn
	charConn = player.CharacterAdded:Connect(function(c)
		newChar = c
		charConn:Disconnect()
	end)

	player:LoadCharacter()

	-- Ждём до 10 секунд (не блокируем если что-то пошло не так)
	local waited = 0
	while not newChar and waited < 10 do
		task.wait(0.05)
		waited += 0.05
	end

	if not newChar then
		warn("[RespawnHandler] Character never added for", player.Name)
		if charConn then charConn:Disconnect() end
		return
	end

	local char = newChar
	local hum  = char:WaitForChild("Humanoid", 5)
	if not hum then
		warn("[RespawnHandler] Humanoid not found for", player.Name)
		return
	end

	-- Дожидаемся пока CharacterService.applyToChar отработает (0.15s wait)
	task.wait(0.2)

	-- Применяем статы героя (страховка если CharacterService не успел)
	if CharSvc then
		local heroData = CharSvc.GetSelectedHero(player.UserId)
		if heroData then
			CharSvc.ApplyStats(char, heroData)
			if Mods and Mods.ApplyToPlayer then
				pcall(Mods.ApplyToPlayer, player, heroData, matchData.mode)
			end
		end
	end

	-- Восстанавливаем alive + hp в CombatSystem
	if Combat then
		if Combat.revivePlayer then
			Combat.revivePlayer(player.UserId)
		else
			local state = Combat.getState and Combat.getState(player.UserId)
			if state then
				state.alive = true
				state.hp    = state.maxHp
			end
		end
		local state = Combat.getState and Combat.getState(player.UserId)
		if state then
			rUpdateHP:FireClient(player, state.hp, state.maxHp)
		end
	end

	-- BUG-B FIX: только ОДИН FireAllClients — клиент фильтрует по userId сам
	-- Убираем дублирующий FireClient(player)
	rPlayerRespawned:FireAllClients(player.UserId)

	print(string.format("[RespawnHandler] %s respawned", player.Name))
end

-- ============================================================
-- ПОДКЛЮЧЕНИЕ К ПЕРСОНАЖУ
-- ============================================================

local function setupPlayerRespawn(player)
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if not humanoid then return end
		humanoid.Died:Connect(function()
			onCharacterDeath(player)
		end)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- ============================================================
-- PUBLIC API
-- ============================================================

local RespawnHandler = {}
_G.RespawnHandler = RespawnHandler

function RespawnHandler.RegisterPlayer(userId, matchId, mode)
	playerMatchData[userId] = { matchId = matchId, mode = mode or "Normal" }
end

function RespawnHandler.UnregisterPlayer(userId)
	playerMatchData[userId] = nil
end

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ============================================================

Players.PlayerAdded:Connect(setupPlayerRespawn)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerRespawn(player)
end

Players.PlayerRemoving:Connect(function(player)
	RespawnHandler.UnregisterPlayer(player.UserId)
end)

print("[RespawnHandler] Initialized ✓")
