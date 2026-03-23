-- VFXManager.lua | Anime Arena: Blitz
-- Централизованный клиентский VFX менеджер:
--   • Ауры статусов (Burn/Stun/Slow/Shield)
--   • Highlight попадания через Highlight instance
--   • PointLight ауры героев
--   • Particle-база для 12 героев
--   • 3D звук (placeholder ID)
-- API: VFXManager.PlaySkillVFX(userId, slot, heroId, targetPos)
--      VFXManager.PlayStatusVFX(character, effectType, isActive)
--      VFXManager.PlayHitVFX(position, heroColor)

local Players    = game:GetService("Players")
local Debris     = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local VFXManager = {}

-- ============================================================
-- ЦВЕТА ГЕРОЕВ (экспортируются через VFXManager.HERO_COLOR)
-- ============================================================

local HERO_COLOR = {
	FlameRonin    = Color3.fromRGB(255,  80,  30),
	VoidAssassin  = Color3.fromRGB(140,  40, 200),
	ThunderMonk   = Color3.fromRGB( 80, 170, 255),
	IronTitan     = Color3.fromRGB(180, 180, 180),
	ScarletArcher = Color3.fromRGB(220,  50,  80),
	EclipseHero   = Color3.fromRGB( 80,  50, 160),
	StormDancer   = Color3.fromRGB(120, 220, 255),
	BloodSage     = Color3.fromRGB(200,  20,  20),
	CrystalGuard  = Color3.fromRGB(100, 200, 230),
	ShadowTwin    = Color3.fromRGB( 60,  60,  90),
	NeonBlitz     = Color3.fromRGB(  0, 240, 200),
	JadeSentinel  = Color3.fromRGB( 50, 180,  80),
}

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ
-- ============================================================

local function getCharacter(userId)
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character
end

local function getHRP(userId)
	local c = getCharacter(userId)
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function anchorPart(pos, size, color, transparency, parent)
	local p = Instance.new("Part")
	p.Anchored     = true
	p.CanCollide   = false
	p.CastShadow   = false
	p.Size         = size  or Vector3.one
	p.CFrame       = CFrame.new(pos)
	p.Color        = color or Color3.new(1,1,1)
	p.Transparency = transparency or 1
	p.Parent       = parent or workspace
	return p
end

local function makeParticles(parent, col, rate, speed, lifetime, size)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.new(1,1,1)),
		ColorSequenceKeypoint.new(0.3, col),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(30,30,30)),
	})
	e.LightEmission  = 0.8
	e.LightInfluence = 0.1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   size  or 0.5),
		NumberSequenceKeypoint.new(0.5, (size or 0.5)*0.6),
		NumberSequenceKeypoint.new(1,   0),
	})
	e.Speed       = NumberRange.new(speed or 8, (speed or 8)*2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime    = NumberRange.new(lifetime or 0.3, (lifetime or 0.3)*2)
	e.Rate        = rate or 20
	e.RotSpeed    = NumberRange.new(-180, 180)
	e.Enabled     = false
	e.Parent      = parent
	return e
end

local function makeLight(parent, col, brightness, range)
	local l = Instance.new("PointLight")
	l.Color      = col        or Color3.new(1,1,1)
	l.Brightness = brightness or 2
	l.Range      = range      or 14
	l.Parent     = parent
	return l
end

local function makeHighlight(char, fill, outline, fillAlpha, outlineAlpha)
	local h = Instance.new("Highlight")
	h.FillColor          = fill or Color3.new(1,1,1)
	h.OutlineColor       = outline or Color3.new(1,1,1)
	h.FillTransparency   = fillAlpha   or 0.5
	h.OutlineTransparency = outlineAlpha or 0
	h.Adornee            = char
	h.Parent             = char
	return h
end

-- ============================================================
-- STATUS VFX
-- ============================================================

local activeStatusVFX = {}  -- [userId][effectType] = { instances }

function VFXManager.PlayStatusVFX(userId, effectType, isActive, duration)
	local char = getCharacter(userId)
	if not char then return end

	if not activeStatusVFX[userId] then activeStatusVFX[userId] = {} end

	-- Убираем старые
	local existing = activeStatusVFX[userId][effectType]
	if existing then
		for _, inst in ipairs(existing) do
			if inst and inst.Parent then inst:Destroy() end
		end
		activeStatusVFX[userId][effectType] = nil
	end

	if not isActive then return end

	local created = {}

	if effectType == "Burn" then
		local hl = makeHighlight(char, Color3.fromRGB(255,100,0), Color3.fromRGB(255,60,0), 0.6, 0.3)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local light
		if hrp then
			light = makeLight(hrp, Color3.fromRGB(255,120,0), 1.5, 12)
			table.insert(created, light)
		end
		table.insert(created, hl)

	elseif effectType == "Stun" then
		local hl = makeHighlight(char, Color3.fromRGB(255,230,50), Color3.fromRGB(255,200,0), 0.5, 0.2)
		table.insert(created, hl)
		-- Звёздочки над головой
		local head = char:FindFirstChild("Head")
		if head then
			local bb = Instance.new("BillboardGui")
			bb.Size       = UDim2.new(0,60,0,24)
			bb.StudsOffset = Vector3.new(0,2,0)
			bb.Adornee     = head
			bb.Parent      = char
			local lbl = Instance.new("TextLabel")
			lbl.Size                  = UDim2.new(1,0,1,0)
			lbl.BackgroundTransparency = 1
			lbl.Text                  = "★★★"
			lbl.TextScaled            = true
			lbl.TextColor3            = Color3.fromRGB(255,220,0)
			lbl.Font                  = Enum.Font.GothamBold
			lbl.Parent                = bb
			table.insert(created, bb)
		end

	elseif effectType == "Slow" then
		local hl = makeHighlight(char, Color3.fromRGB(100,150,255), Color3.fromRGB(60,100,200), 0.6, 0.4)
		table.insert(created, hl)

	elseif effectType == "Shield" then
		local hl = makeHighlight(char, Color3.fromRGB(180,220,255), Color3.fromRGB(100,180,255), 0.3, 0.1)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local l = makeLight(hrp, Color3.fromRGB(120,180,255), 1, 10)
			table.insert(created, l)
		end
		table.insert(created, hl)

	elseif effectType == "VoidMarked" then
		local hl = makeHighlight(char, Color3.fromRGB(160,0,200), Color3.fromRGB(100,0,150), 0.5, 0.2)
		table.insert(created, hl)
	end

	activeStatusVFX[userId][effectType] = created

	if duration then
		task.delay(duration, function()
			VFXManager.PlayStatusVFX(userId, effectType, false)
		end)
	end
end

-- Очистка при смерти
function VFXManager.ClearStatusVFX(userId)
	if not activeStatusVFX[userId] then return end
	for _, list in pairs(activeStatusVFX[userId]) do
		for _, inst in ipairs(list) do
			if inst and inst.Parent then inst:Destroy() end
		end
	end
	activeStatusVFX[userId] = {}
end

-- ============================================================
-- HIT VFX (используется HitEffects, но можно вызывать напрямую)
-- ============================================================

function VFXManager.PlayHitVFX(position, heroColor, dmgType)
	local col = heroColor or Color3.fromRGB(255,200,50)
	local anchor = anchorPart(position, Vector3.one * 0.1, col, 1)

	local emit = makeParticles(anchor, col,
		0,
		dmgType == "Ultimate" and 18 or 10,
		0.35,
		dmgType == "Ultimate" and 0.55 or 0.3
	)
	emit.Enabled = false
	emit:Emit(dmgType == "Ultimate" and 30 or 16)

	if dmgType == "Ultimate" or dmgType == "Crit" then
		local l = makeLight(anchor, col, dmgType == "Ultimate" and 3 or 1.5, 18)
		TweenService:Create(l, TweenInfo.new(0.3), { Brightness = 0, Range = 0 }):Play()
	end

	Debris:AddItem(anchor, 0.8)
end

-- ============================================================
-- SKILL VFX для всех 12 героев
-- ============================================================

local SkillVFXDefs = {}

-- Генератор стандартного VFX для слота
local function defaultVFX(userId, slot, targetPos, col, burstCount, lightBright, duration)
	local hrp = getHRP(userId)
	if not hrp then return end
	local pos = targetPos or hrp.Position

	local anchor = anchorPart(pos, Vector3.one * 0.1, col, 1)
	local emit    = makeParticles(anchor, col, 0, 12, 0.4, 0.45)
	emit:Emit(burstCount or 20)

	if lightBright and lightBright > 0 then
		local l = makeLight(anchor, col, lightBright, 16)
		TweenService:Create(l, TweenInfo.new(duration or 0.4), { Brightness = 0 }):Play()
	end
	Debris:AddItem(anchor, (duration or 0.4) + 0.3)
end

-- Трейл для рывка
local function dashTrail(userId, col)
	local char = getCharacter(userId)
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local a0 = Instance.new("Attachment"); a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -2.5, 0)
	a1.Parent   = hrp

	local trail = Instance.new("Trail")
	trail.Attachment0  = a0
	trail.Attachment1  = a1
	trail.Color        = ColorSequence.new(col, Color3.fromRGB(255,255,255))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1) })
	trail.Lifetime     = 0.3
	trail.MinLength    = 0
	trail.LightEmission = 0.6
	trail.Parent       = hrp

	task.delay(0.4, function()
		if trail.Parent then trail:Destroy() end
		if a0.Parent    then a0:Destroy() end
		if a1.Parent    then a1:Destroy() end
	end)
end

-- Аура ульты
local function ultAura(userId, col, duration)
	local char = getCharacter(userId)
	if not char then return end

	local hl = makeHighlight(char, col, col, 0.15, 0)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local light
	if hrp then
		light = makeLight(hrp, col, 4, 24)
		TweenService:Create(light, TweenInfo.new(duration or 1.2, Enum.EasingStyle.Quad), {
			Brightness = 0
		}):Play()
	end
	task.delay(duration or 1.2, function()
		if hl.Parent    then hl:Destroy()    end
		if light and light.Parent then light:Destroy() end
	end)
end

-- ============================================================
-- ОПРЕДЕЛЕНИЯ VFX ПО ГЕРОЮ
-- Формат: function(userId, targetPos)
-- ============================================================

SkillVFXDefs.FlameRonin = {
	Q = function(userId, targetPos)
		dashTrail(userId, HERO_COLOR.FlameRonin)
		defaultVFX(userId, "Q", targetPos, HERO_COLOR.FlameRonin, 18, 2.5, 0.4)
	end,
	E = function(userId, targetPos)
		defaultVFX(userId, "E", getHRP(userId) and getHRP(userId).Position, HERO_COLOR.FlameRonin, 25, 3, 0.5)
	end,
	F = function(userId, targetPos)
		local char = getCharacter(userId)
		if char then makeHighlight(char, HERO_COLOR.FlameRonin, Color3.fromRGB(255,200,80), 0.2, 0)
			Debris:AddItem(char:FindFirstChildOfClass("Highlight"), 3) end
	end,
	R = function(userId, targetPos)
		ultAura(userId, HERO_COLOR.FlameRonin, 1.5)
		defaultVFX(userId, "R", getHRP(userId) and getHRP(userId).Position, HERO_COLOR.FlameRonin, 50, 5, 1.2)
	end,
}

SkillVFXDefs.VoidAssassin = {
	Q = function(userId, targetPos)
		dashTrail(userId, HERO_COLOR.VoidAssassin)
		defaultVFX(userId, "Q", targetPos, HERO_COLOR.VoidAssassin, 12, 2, 0.3)
	end,
	E = function(userId, targetPos)
		local char = getCharacter(userId)
		if char then
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
					TweenService:Create(p, TweenInfo.new(0.1), { Transparency = 0.85 }):Play()
				end
			end
		end
	end,
	F = function(userId, targetPos)
		defaultVFX(userId, "F", targetPos, HERO_COLOR.VoidAssassin, 14, 1.5, 0.4)
	end,
	R = function(userId, targetPos)
		ultAura(userId, HERO_COLOR.VoidAssassin, 1.0)
		defaultVFX(userId, "R", getHRP(userId) and getHRP(userId).Position, HERO_COLOR.VoidAssassin, 40, 4, 1.0)
	end,
}

SkillVFXDefs.ThunderMonk = {
	Q = function(userId, targetPos)
		defaultVFX(userId, "Q", targetPos, HERO_COLOR.ThunderMonk, 20, 3, 0.35)
	end,
	E = function(userId, targetPos)
		local pos = getHRP(userId) and getHRP(userId).Position
		defaultVFX(userId, "E", pos, HERO_COLOR.ThunderMonk, 30, 3.5, 0.5)
	end,
	F = function(userId, targetPos)
		dashTrail(userId, HERO_COLOR.ThunderMonk)
	end,
	R = function(userId, targetPos)
		ultAura(userId, HERO_COLOR.ThunderMonk, 1.8)
		defaultVFX(userId, "R", getHRP(userId) and getHRP(userId).Position, HERO_COLOR.ThunderMonk, 60, 6, 1.5)
	end,
}

-- Генерический VFX для остальных 9 героев
local remainingHeroes = {
	"IronTitan", "ScarletArcher", "EclipseHero", "StormDancer",
	"BloodSage", "CrystalGuard", "ShadowTwin", "NeonBlitz", "JadeSentinel"
}

for _, heroId in ipairs(remainingHeroes) do
	local col = HERO_COLOR[heroId] or Color3.new(1,1,1)
	SkillVFXDefs[heroId] = {
		Q = function(userId, targetPos)
			defaultVFX(userId, "Q", targetPos or (getHRP(userId) and getHRP(userId).Position), col, 15, 2, 0.35)
		end,
		E = function(userId, targetPos)
			defaultVFX(userId, "E", getHRP(userId) and getHRP(userId).Position, col, 22, 2.5, 0.45)
		end,
		F = function(userId, targetPos)
			dashTrail(userId, col)
			defaultVFX(userId, "F", getHRP(userId) and getHRP(userId).Position, col, 10, 1.5, 0.3)
		end,
		R = function(userId, targetPos)
			ultAura(userId, col, 1.2)
			defaultVFX(userId, "R", getHRP(userId) and getHRP(userId).Position, col, 45, 5, 1.0)
		end,
	}
end

-- ============================================================
-- ПУБЛИЧНЫЙ API
-- ============================================================

function VFXManager.PlaySkillVFX(userId, slot, heroId, targetPos)
	local def = SkillVFXDefs[heroId]
	if def and def[slot] then
		local ok, err = pcall(def[slot], userId, targetPos)
		if not ok then
			warn(string.format("[VFXManager] %s.%s error: %s", heroId, slot, tostring(err)))
		end
	end
end

function VFXManager.PlayUltVFX(userId, heroId)
	VFXManager.PlaySkillVFX(userId, "R", heroId, nil)
end

-- Экспортируем таблицу цветов — единственный источник правды
VFXManager.HERO_COLOR = HERO_COLOR

return VFXManager
