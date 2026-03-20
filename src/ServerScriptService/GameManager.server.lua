-- GameManager.server.lua
-- Anime Arena: Blitz Mode
-- Главный сервер-менеджер игры

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Ожидаем загрузку общих модулей
local Shared = ReplicatedStorage:WaitForChild("AnimeArena")
local Config = require(Shared:WaitForChild("Config"))

-- Remotes
local Remotes = Shared:WaitForChild("Remotes")

-- Состояние игры
local GameState = {
    Mode = "Lobby",       -- Lobby | Blitz | Ranked | OneHit | Tournament
    Players = {},
    Round = 0,
}

-- Инициализация игрока
local function onPlayerAdded(player)
    print("[GameManager] Игрок подключился:", player.Name)
    GameState.Players[player.UserId] = {
        Player = player,
        Hero = nil,
        Rating = 1000,
        MatchRank = "E",
    }
end

local function onPlayerRemoving(player)
    print("[GameManager] Игрок отключился:", player.Name)
    GameState.Players[player.UserId] = nil
end

-- Подключаем события
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Обработка уже подключённых игроков
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

print("[GameManager] Сервер запущен. Версия:", Config.VERSION)
