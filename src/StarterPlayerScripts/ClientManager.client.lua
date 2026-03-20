-- ClientManager.client.lua | Anime Arena: Blitz Mode
-- Main client manager: input, events, state

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("AnimeArena")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = Shared:WaitForChild("Remotes")

local ClientState = {
    Hero = nil,
    UltCharge = 0,
    Stats = {
        damageDealt = 0, damageTaken = 0,
        dodges = 0, parries = 0, combos = 0,
    }
}

local KEYBINDS = {
    Skill1   = Enum.KeyCode.Q,
    Skill2   = Enum.KeyCode.E,
    Skill3   = Enum.KeyCode.R,
    Ultimate = Enum.KeyCode.F,
    Dodge    = Enum.KeyCode.LeftShift,
}

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    for skillName, keyCode in pairs(KEYBINDS) do
        if input.KeyCode == keyCode then
            Remotes.UseSkill:FireServer(skillName, ClientState.Hero)
            break
        end
    end
end)

Remotes.RoundStart.OnClientEvent:Connect(function(data)
    ClientState.CurrentRound = data
    print("[Client] Round Start - Mode:", data and data.mode or "?")
end)

Remotes.RoundEnd.OnClientEvent:Connect(function(results)
    local myResult = results[tostring(LocalPlayer.UserId)]
    if myResult then
        print("[Client] Round End - Score:", myResult.score, "Rank:", myResult.rank)
    end
end)

Remotes.UltCharge.OnClientEvent:Connect(function(charge)
    ClientState.UltCharge = charge
end)

Remotes.TakeDamage.OnClientEvent:Connect(function(amount)
    ClientState.Stats.damageTaken += amount
end)

print("[ClientManager] Ready -", LocalPlayer.Name)
