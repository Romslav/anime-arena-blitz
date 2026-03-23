-- RemotesInitializer.server.lua | Anime Arena: Blitz
-- Создаёт ВСЕ RemoteEvent / RemoteFunction из Remotes.lua.
-- Должен запускаться ПЕРВЫМ из всех серверных скриптов
-- (поставь RunContext = Legacy и Priority = 1000 в Studio).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemotesDef        = require(ReplicatedStorage:WaitForChild("Remotes"))

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder      = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end

-- Создаём RemoteEvent-ы
for _, name in ipairs(RemotesDef.EVENTS) do
	if not folder:FindFirstChild(name) then
		local re      = Instance.new("RemoteEvent")
		re.Name       = name
		re.Parent     = folder
	end
end

-- Создаём RemoteFunction-ы
for _, name in ipairs(RemotesDef.FUNCTIONS) do
	if not folder:FindFirstChild(name) then
		local rf      = Instance.new("RemoteFunction")
		rf.Name       = name
		rf.Parent     = folder
	end
end

-- Валидация — ловим расхождения сразу
RemotesDef.Validate(folder)

print(string.format("[RemotesInitializer] Created %d events + %d functions ✓",
	#RemotesDef.EVENTS, #RemotesDef.FUNCTIONS))
