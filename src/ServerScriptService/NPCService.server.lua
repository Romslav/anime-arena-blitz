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
		objectText   = "Мастер Арен「SSS」",
		holdDuration = 0.3,
		nameColor    = Color3.fromRGB(255, 80, 60),
		onTrigger    = function(player)
			if _G.RoundService then
				local roundId = _G.RoundService.GetPlayerRound(player.UserId)
				if roundId then
					rNotify:FireClient(player, "Вы уже в бою", "warning")
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

-- Дефолт: неизвестный NPC -> поведение как Мастер Арен
local DEFAULT_CONFIG = NPC_CONFIG["ArenasMaster"]

-- ============================================================
-- ПОЗИЦИИ NPC В ЛОББИ
-- FIX: Большое расстояние (80 стадов) - NPC больше не сливаются.
--
-- CFrame.lookAt(позиция, куда_смотреть):
--   ArenasMaster: X=-40, Z=12  смотрит на центр (0,5,0)
--   Trader:       X=+40, Z=12  смотрит на центр (0,5,0)
--
-- НАСТРОЙКА ПОД КАРТУ:
--   Измени первый Vector3.new(X, Y, Z) под реальные координаты пола.
--   Y=5 = чуть выше пола, гарантирует что NPC не провалится.
--   Второй Vector3.new(0,5,0) = точка куда смотрит NPC (центр лобби).
-- ============================================================

local NPC_SPAWN_POSITIONS = {
	["ArenasMaster"] = CFrame.lookAt(Vector3.new(-40, 5, 12), Vector3.new(0, 5, 0)),
	["Trader"]       = CFrame.lookAt(Vector3.new( 40, 5, 12), Vector3.new(0, 5, 0)),
}

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

	-- --------------------------------------------------------
	-- ШАГ 1: ЯКОРЬ ВСЕХ ЧАСТЕЙ (синхронно, до PivotTo)
	-- Якорим ДО перемещения - физика не успеет откатить позицию
	-- --------------------------------------------------------
	for _, part in ipairs(npcModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored    = true
			part.Velocity    = Vector3.zero
			part.RotVelocity = Vector3.zero
		end
	end
	hrp.Anchored = true

	-- --------------------------------------------------------
	-- ШАГ 2: НЕЙТРАЛИЗАЦИЯ HUMANOID
	-- Humanoid с WalkSpeed > 0 борется против якоря.
	-- Обнуляем скорость и прыжок - NPC стоит как статуя.
	-- --------------------------------------------------------
	local hum = npcModel:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed       = 0
		hum.JumpPower       = 0
		hum.AutoJumpEnabled = false
		hum.PlatformStand   = true
	end

	-- --------------------------------------------------------
	-- ШАГ 3: ПЕРЕМЕЩЕНИЕ через PivotTo
	-- PivotTo - современный Roblox API, не требует PrimaryPart.
	-- Перемещает ВСЮ модель с сохранением внутренних смещений.
	-- --------------------------------------------------------
	local spawnCF = NPC_SPAWN_POSITIONS[npcModel.Name]
	if spawnCF then
		npcModel:PivotTo(spawnCF)
		print(string.format("[NPCService] '%s' placed at (%.0f, %.0f, %.0f) via PivotTo",
			npcModel.Name,
			spawnCF.Position.X,
			spawnCF.Position.Y,
			spawnCF.Position.Z))
	else
		warn(string.format("[NPCService] No spawn position for '%s' - add to NPC_SPAWN_POSITIONS",
			npcModel.Name))
	end

	-- Удаляем старый ProximityPrompt (хот-релоад)
	local old = hrp:FindFirstChildOfClass("ProximityPrompt")
	if old then old:Destroy() end

	-- ProximityPrompt
	local prompt                 = Instance.new("ProximityPrompt")
	prompt.ActionText            = cfg.actionText
	prompt.ObjectText            = cfg.objectText
	prompt.HoldDuration          = cfg.holdDuration
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight   = false
	prompt.Parent                = hrp

	-- Billboard над головой
	local existing = npcModel:FindFirstChild("NPCNameTag")
	if existing then existing:Destroy() end

	local bb         = Instance.new("BillboardGui")
	bb.Name          = "NPCNameTag"
	bb.Size          = UDim2.new(0, 200, 0, 46)
	bb.StudsOffset   = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop   = false
	bb.Adornee       = hrp
	bb.Parent        = npcModel

	local lbl                    = Instance.new("TextLabel")
	lbl.Size                     = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency   = 1
	lbl.Text                     = cfg.objectText
	lbl.TextColor3               = cfg.nameColor or Color3.fromRGB(255, 220, 80)
	lbl.TextStrokeTransparency   = 0
	lbl.TextStrokeColor3         = Color3.new(0, 0, 0)
	lbl.Font                     = Enum.Font.GothamBold
	lbl.TextScaled               = true
	lbl.Parent                   = bb

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
		warn("[NPCService] workspace.Lobby not found after 30s - NPCs not initialized.")
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
