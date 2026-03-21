-- HUD.client.lua | Anime Arena: Blitz Mode
-- Production HUD: HP bar, skills cooldowns, ult charge, timer, kill feed, respawn countdown

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateHP        = Remotes:WaitForChild("UpdateHP")
local UpdateHUD       = Remotes:WaitForChild("UpdateHUD")
local UltCharge       = Remotes:WaitForChild("UltCharge")
local UpdateTimer     = Remotes:WaitForChild("RoundTimer")
local ShowKillFeed    = Remotes:WaitForChild("ShowKillFeed")
local ShowNotification= Remotes:WaitForChild("ShowNotification")
local TakeDamage      = Remotes:WaitForChild("TakeDamage")
local PlayerDied      = Remotes:WaitForChild("PlayerDied")

-- === Create ScreenGui ===
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "HUD"
hudGui.ResetOnSpawn = false
hudGui.Enabled = false  -- enable on match start
hudGui.Parent = PlayerGui

local function makeFrame(parent, size, position, bg, transparency)
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = position
	f.BackgroundColor3 = bg
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function makeText(parent, size, position, text, color, scaled)
	local t = Instance.new("TextLabel")
	t.Size = size
	t.Position = position
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = scaled or false
	t.Font = Enum.Font.GothamBold
	t.BackgroundTransparency = 1
	t.Parent = parent
	return t
end

-- === HP Bar (bottom center) ===
local hpBg = makeFrame(hudGui, UDim2.new(0.3, 0, 0, 30), UDim2.new(0.35, 0, 0.88, 0), Color3.fromRGB(30, 30, 40), 0.3)
local hpBar = makeFrame(hpBg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(220, 50, 50), 0)
local hpText = makeText(hpBg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "100 / 100", Color3.fromRGB(255, 255, 255), true)

-- === Skills Cooldowns (bottom right) ===
local skillsFrame = makeFrame(hudGui, UDim2.new(0.25, 0, 0.12, 0), UDim2.new(0.74, 0, 0.82, 0), Color3.fromRGB(20, 20, 30), 0.5)
local skillSlots = {}
for i = 1, 4 do  -- 3 skills + 1 ult
	local slot = makeFrame(skillsFrame, UDim2.new(0.22, 0, 0.7, 0), UDim2.new(0.02 + (i-1)*0.24, 0, 0.15, 0), Color3.fromRGB(60, 60, 80), 0.2)
	local cd = makeText(slot, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "", Color3.fromRGB(255, 255, 100), true)
	local overlay = makeFrame(slot, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(0, 0, 0), 0.7)
	overlay.Visible = false
	skillSlots[i] = { slot = slot, cd = cd, overlay = overlay }
end

-- === Ult Charge (top skill slot) ===
local ultChargeBg = makeFrame(hudGui, UDim2.new(0.18, 0, 0, 8), UDim2.new(0.76, 0, 0.77, 0), Color3.fromRGB(30, 30, 40), 0.4)
local ultChargeBar = makeFrame(ultChargeBg, UDim2.new(0, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(255, 200, 0), 0)
local ultText = makeText(ultChargeBg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "ULT 0%", Color3.fromRGB(255, 255, 255), true)

-- === Timer (top center) ===
local timerLabel = makeText(hudGui, UDim2.new(0.15, 0, 0, 50), UDim2.new(0.425, 0, 0.02, 0), "3:00", Color3.fromRGB(255, 255, 255), true)

-- === Kill Feed (top right) ===
local killFeedFrame = makeFrame(hudGui, UDim2.new(0.3, 0, 0.4, 0), UDim2.new(0.69, 0, 0.05, 0), Color3.fromRGB(0, 0, 0), 0.8)
local killFeedList = Instance.new("UIListLayout")
killFeedList.SortOrder = Enum.SortOrder.LayoutOrder
killFeedList.Padding = UDim.new(0, 4)
killFeedList.Parent = killFeedFrame

local function addKillFeedEntry(killer, victim)
	local entry = makeText(killFeedFrame, UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 0), killer .. " eliminated " .. victim, Color3.fromRGB(255, 100, 100), false)
	entry.TextScaled = false
	entry.TextSize = 16
	entry.Font = Enum.Font.Gotham
	task.delay(5, function()
		entry:Destroy()
	end)
end

-- === Respawn Countdown (center screen) ===
local respawnLabel = makeText(hudGui, UDim2.new(0.3, 0, 0.1, 0), UDim2.new(0.35, 0, 0.45, 0), "", Color3.fromRGB(255, 50, 50), true)
respawnLabel.Visible = false

-- === Update HP ===
local function updateHP(currentHP, maxHP)
	if not maxHP or maxHP == 0 then maxHP = 100 end
	local ratio = math.clamp(currentHP / maxHP, 0, 1)
	hpBar:TweenSize(UDim2.new(ratio, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
	hpText.Text = math.floor(currentHP) .. " / " .. maxHP
end

-- === Update Skill Cooldown ===
local function updateSkillCD(index, cdLeft)
	if not skillSlots[index] then return end
	local s = skillSlots[index]
	if cdLeft > 0 then
		s.cd.Text = math.ceil(cdLeft)
		s.overlay.Visible = true
	else
		s.cd.Text = ""
		s.overlay.Visible = false
	end
end

-- === Update Ult Charge ===
local function updateUlt(charge)
	local pct = math.clamp(charge, 0, 100)
	ultChargeBar:TweenSize(UDim2.new(pct / 100, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
	ultText.Text = "ULT " .. math.floor(pct) .. "%"
end

-- === Update Timer ===
local function updateTimer(seconds)
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	timerLabel.Text = string.format("%d:%02d", mins, secs)
end

-- === Respawn Countdown ===
local function showRespawn(seconds)
	respawnLabel.Visible = true
	for i = seconds, 1, -1 do
		respawnLabel.Text = "Respawning in " .. i
		task.wait(1)
	end
	respawnLabel.Visible = false
end

-- === Remote Event Handlers ===

UpdateHP.OnClientEvent:Connect(function(hp, maxHp)
	updateHP(hp, maxHp)
end)

UpdateHUD.OnClientEvent:Connect(function(data)
	if data.hp and data.maxHP then
		updateHP(data.hp, data.maxHP)
	end
	if data.ultCharge then
		updateUlt(data.ultCharge)
	end
	if data.skills then
		for i, cd in pairs(data.skills) do
			updateSkillCD(i, cd)
		end
	end
end)

UltCharge.OnClientEvent:Connect(function(charge)
	updateUlt(charge)
end)

UpdateTimer.OnClientEvent:Connect(function(seconds)
	updateTimer(seconds)
end)

ShowKillFeed.OnClientEvent:Connect(function(killer, victim)
	addKillFeedEntry(killer, victim)
end)

TakeDamage.OnClientEvent:Connect(function(newHP, maxHP)
	updateHP(newHP, maxHP)
end)

PlayerDied.OnClientEvent:Connect(function(respawnTime)
	if respawnTime and respawnTime > 0 then
		showRespawn(respawnTime)
	end
end)

ShowNotification.OnClientEvent:Connect(function(message)
	local notif = makeText(hudGui, UDim2.new(0.4, 0, 0.08, 0), UDim2.new(0.3, 0, 0.3, 0), message, Color3.fromRGB(255, 255, 100), true)
	notif.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	notif.BackgroundTransparency = 0.3
	task.delay(3, function()
		notif:Destroy()
	end)
end)

-- === Character Health Monitoring (backup) ===
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		updateHP(humanoid.Health, humanoid.MaxHealth)
		humanoid.HealthChanged:Connect(function(hp)
			updateHP(hp, humanoid.MaxHealth)
		end)
	end
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- === Enable HUD on match start ===
local MatchStart = Remotes:WaitForChild("MatchStart")
MatchStart.OnClientEvent:Connect(function()
	hudGui.Enabled = true
end)

local MatchEnd = Remotes:WaitForChild("MatchEnd")
MatchEnd.OnClientEvent:Connect(function()
	hudGui.Enabled = false
end)

print("[HUD] Initialized successfully")
