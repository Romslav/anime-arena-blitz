-- NPCService.server.lua | Anime Arena: Blitz
-- Управляет NPC в лобби:
--   • Мастер Арен  — открыть меню выбора режима (OpenLobbyMenu)
--   • Торговец    — открыть панель торговли (OpenTradePanel)
-- Требует папку workspace.Lobby.NPCs с моделями NPC
-- Публичный API: _G.NPCService

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local rOpenLobby    = Remotes:WaitForChild("OpenLobbyMenu")
local rOpenTrade    = Remotes:WaitForChild("OpenTradePanel")
local rNotify       = Remotes:WaitForChild("ShowNotification")

-- ============================================================
-- КОНФИГУРАЦИЯ NPC
-- Ключ = имя модели в workspace.Lobby.NPCs
-- ============================================================

local NPC_CONFIG = {
	["ArenasMaster"] = {
		actionText   = "Выбрать режим",
		objectText   = "Мастер Арен",
		holdDuration = 0.3,
		nameColor    = Color3.fromRGB(255, 220, 80),
		onTrigger    = function(player)
			if _G.RoundService then
				local roundId = _G.RoundService.GetPlayerRound(player.UserId)
				if roundId then
					rNotify:FireClient(player, "⚔️ Вы уже в бою", "warning")
					return
				end
			end
			rOpenLobby:FireClient(player)
		end,
	},
	["Trader"] = {
		actionText   = "Торговать",
		objectText   = "Торговец",
		holdDuration = 0.5,
		nameColor    = Color3.fromRGB(80, 220, 140),
		onTrigger    = function(player)
			if _G.RoundService then
				local roundId = _G.RoundService.GetPlayerRound(player.UserId)
				if roundId then
					rNotify:FireClient(player, "🚫 Торговля недоступна в бою", "warning")
					return
				end
			end
			rOpenTrade:FireClient(player)
		end,
	},
}

-- Дефолт: неизвестный NPC → поведение как Мастер Арен
local DEFAULT_CONFIG = NPC_CONFIG["ArenasMaster"]

-- ============================================================
-- SETUP NPC
-- ============================================================

local function setupNPC(npcModel)
	local cfg = NPC_CONFIG[npcModel.Name] or DEFAULT_CONFIG

	-- Ждём HumanoidRootPart
	local hrp = npcModel:FindFirstChild("HumanoidRootPart")
			or npcModel:WaitForChild("HumanoidRootPart", 6)
	if not hrp then
		warn(string.format("[NPCService] HumanoidRootPart missing in NPC '%s'", npcModel.Name))
		return
	end

	-- Удаляем старый ProximityPrompt (хот-релоад)
	local old = hrp:FindFirstChildOfClass("ProximityPrompt")
	if old then old:Destroy() end

	-- ProximityPrompt
	local prompt                    = Instance.new("ProximityPrompt")
	prompt.ActionText               = cfg.actionText
	prompt.ObjectText               = cfg.objectText
	prompt.HoldDuration             = cfg.holdDuration
	prompt.MaxActivationDistance    = 8
	prompt.RequiresLineOfSight       = false
	prompt.Parent                   = hrp

	-- Billboard над головой
	local existing = npcModel:FindFirstChild("NPCNameTag")
	if existing then existing:Destroy() end

	local bb              = Instance.new("BillboardGui")
	bb.Name               = "NPCNameTag"
	bb.Size               = UDim2.new(0, 200, 0, 46)
	bb.StudsOffset        = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop        = false
	bb.Adornee            = hrp
	bb.Parent             = npcModel

	local lbl             = Instance.new("TextLabel")
	lbl.Size              = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text              = cfg.objectText
	lbl.TextColor3        = cfg.nameColor or Color3.fromRGB(255, 220, 80)
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3  = Color3.new(0, 0, 0)
	lbl.Font              = Enum.Font.GothamBold
	lbl.TextScaled        = true
	lbl.Parent            = bb

	-- Триггер
	prompt.Triggered:Connect(function(player)
		local ok, err = pcall(cfg.onTrigger, player)
		if not ok then
			warn(string.format("[NPCService] onTrigger error '%s': %s", npcModel.Name, tostring(err)))
		end
	end)

	print(string.format("[NPCService] Registered NPC '%s' as '%s'", npcModel.Name, cfg.objectText))
end

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ============================================================

local NPCService = {}
_G.NPCService   = NPCService

local function initLobbyNPCs()
	-- Ожидаем появления папки Lobby
	local lobbyFolder
	for attempt = 1, 15 do
		lobbyFolder = workspace:FindFirstChild("Lobby")
		if lobbyFolder then break end
		task.wait(2)
	end

	if not lobbyFolder then
		warn("[NPCService] workspace.Lobby not found after 30s — NPCs not initialized.")
		return
	end

	local npcsFolder = lobbyFolder:FindFirstChild("NPCs")
	if not npcsFolder then
		warn("[NPCService] workspace.Lobby.NPCs folder not found.")
		return
	end

	-- Существующие NPC
	for _, npc in ipairs(npcsFolder:GetChildren()) do
		if npc:IsA("Model") then
			task.spawn(setupNPC, npc)
		end
	end

	-- Новые NPC (хот-релоад)
	npcsFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.spawn(setupNPC, child)
		end
	end)

	-- Регистрируем точку спавна лобби из SpawnLocation
	local spawnPart = lobbyFolder:FindFirstChild("SpawnLocation")
				or lobbyFolder:FindFirstChildOfClass("SpawnLocation")
	if spawnPart and _G.CharacterService then
		_G.CharacterService.SetLobbySpawn(spawnPart.CFrame + Vector3.new(0, 3, 0))
		print("[NPCService] Lobby spawn registered from SpawnLocation")
	end

	print("[NPCService] Lobby NPC system initialized ✓")
end

task.spawn(initLobbyNPCs)

-- Спавним новых игроков в лобби после полной загрузки
Players.PlayerAdded:Connect(function(player)
	task.delay(2, function()
		if player and player.Parent and _G.CharacterService then
			_G.CharacterService.SpawnInLobby(player)
		end
	end)
end)

print("[NPCService] Initialized ✓")
