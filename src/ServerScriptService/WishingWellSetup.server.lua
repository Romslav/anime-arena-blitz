-- WishingWellSetup.server.lua | Anime Arena: Blitz
-- Модуль автоматической стилизации Колодца Желаний:
--   • Сканирует все BasePart импортированной FBX-модели
--   • Раскрашивает и назначает материалы по категориям (Neon / Basalt / Slate)
--   • Устанавливает Anchored = true, настраивает CanCollide
--   • Создаёт PointLight в центре колодца
--   • BillboardGui «Колодец Желаний» над моделью
--   • PrimaryPart hitbox для ProximityPrompt
-- ЗАПУСКАЕТСЯ ОДИН РАЗ при старте сервера, затем ждёт загрузки модели

local TweenService = game:GetService("TweenService")

-- ============================================================
-- ЦВЕТОВАЯ СХЕМА (легко менять централизованно)
-- ============================================================

local PALETTE = {
	obsidian      = Color3.fromRGB(15,  15,  20),   -- базовый камень
	obsidianCrack = Color3.fromRGB(20,  20,  28),   -- слегка светлее для деталей

	runeBase      = Color3.fromRGB(170, 85,  255),  -- фиолетовые руны
	runeCyan      = Color3.fromRGB(0,   200, 255),  -- циановые акценты

	vortexCyan    = Color3.fromRGB(0,   255, 255),  -- кольца вихря
	vortexPurple  = Color3.fromRGB(160, 0,   255),  -- вихрь — дополнительный

	beamPurple    = Color3.fromRGB(180, 0,   255),  -- столб призыва
	sparkWhite    = Color3.fromRGB(220, 180, 255),  -- искры

	magicCircle   = Color3.fromRGB(100, 0,   220),  -- линии магического круга
	powerLine     = Color3.fromRGB(80,  0,   200),  -- силовые линии

	eyeDefault    = Color3.fromRGB(80,  0,   160),  -- глаза стражей (спокойно)
	rimDefault    = Color3.fromRGB(120, 0,   255),  -- обод колодца

	metalChain    = Color3.fromRGB(60,  55,  70),   -- цепи (тёмный металл)
	pedestalStone = Color3.fromRGB(30,  28,  38),   -- пьедесталы стражей
}

-- ============================================================
-- ПРАВИЛА СТИЛИЗАЦИИ
-- name-pattern → { material, color, transparency, canCollide }
-- Порядок важен: первое совпадение побеждает
-- ============================================================

local STYLE_RULES = {
	-- Вихрь (кольца) — самые яркие неоновые части
	{ pattern = "Vortex_Ring",  mat = Enum.Material.Neon,   color = PALETTE.vortexCyan,   alpha = 0.55, collide = false },

	-- Руны (все виды) — нeoн фиолетовый
	{ pattern = "Rune_",        mat = Enum.Material.Neon,   color = PALETTE.runeBase,     alpha = 0.0,  collide = false },
	{ pattern = "RuneAccent",   mat = Enum.Material.Neon,   color = PALETTE.runeCyan,     alpha = 0.1,  collide = false },

	-- Обод — неон, пульсирует скриптом VFX
	{ pattern = "Rim",          mat = Enum.Material.Neon,   color = PALETTE.rimDefault,   alpha = 0.0,  collide = false },

	-- Луч призыва / энергетический луч
	{ pattern = "SummonBeam",   mat = Enum.Material.Neon,   color = PALETTE.beamPurple,   alpha = 0.85, collide = false },
	{ pattern = "EnergyBeam",   mat = Enum.Material.Neon,   color = PALETTE.beamPurple,   alpha = 0.75, collide = false },
	{ pattern = "SkyBeam",      mat = Enum.Material.Neon,   color = PALETTE.beamPurple,   alpha = 1.0,  collide = false }, -- скрыт до Legendary

	-- Искры
	{ pattern = "Spark_",       mat = Enum.Material.Neon,   color = PALETTE.sparkWhite,   alpha = 0.2,  collide = false },

	-- Магический круг и линии
	{ pattern = "MagicCircle",  mat = Enum.Material.Neon,   color = PALETTE.magicCircle,  alpha = 0.35, collide = false },
	{ pattern = "PowerLine",    mat = Enum.Material.Neon,   color = PALETTE.powerLine,    alpha = 0.4,  collide = false },
	{ pattern = "ArcaneSymbol", mat = Enum.Material.Neon,   color = PALETTE.runeCyan,     alpha = 0.3,  collide = false },

	-- Глаза стражей
	{ pattern = "Eye",          mat = Enum.Material.Neon,   color = PALETTE.eyeDefault,   alpha = 0.0,  collide = false },

	-- Шары на пиллярах (orbs)
	{ pattern = "PillarOrb",    mat = Enum.Material.Neon,   color = PALETTE.vortexPurple, alpha = 0.1,  collide = false },

	-- Цепи — тёмный металл
	{ pattern = "Chain_",       mat = Enum.Material.Metal,  color = PALETTE.metalChain,   alpha = 0.0,  collide = false },

	-- Пьедесталы стражей
	{ pattern = "Sentinel_Left_Pedestal",  mat = Enum.Material.Slate, color = PALETTE.pedestalStone, alpha = 0.0, collide = true },
	{ pattern = "Sentinel_Right_Pedestal", mat = Enum.Material.Slate, color = PALETTE.pedestalStone, alpha = 0.0, collide = true },

	-- Тело стражей
	{ pattern = "Sentinel_",    mat = Enum.Material.Slate,  color = PALETTE.obsidianCrack, alpha = 0.0, collide = false },

	-- Ступени
	{ pattern = "Step_",        mat = Enum.Material.SmoothPlastic, color = PALETTE.obsidian, alpha = 0.0, collide = true },
	{ pattern = "BasePlatform", mat = Enum.Material.Basalt, color = PALETTE.obsidian,     alpha = 0.0,  collide = true },
	{ pattern = "Floor",        mat = Enum.Material.Basalt, color = PALETTE.obsidian,     alpha = 0.0,  collide = true },

	-- Пиллары
	{ pattern = "Pillar_",      mat = Enum.Material.Slate,  color = PALETTE.obsidian,     alpha = 0.0,  collide = true },

	-- По умолчанию — тёмный базальт
	{ pattern = "",             mat = Enum.Material.Basalt,  color = PALETTE.obsidian,     alpha = 0.0,  collide = true },
}

-- ============================================================
-- ВСПОМОГАТЕЛЬНАЯ: найти правило по имени
-- ============================================================

local function getStyle(name)
	for _, rule in ipairs(STYLE_RULES) do
		if rule.pattern == "" or name:find(rule.pattern, 1, true) then
			return rule
		end
	end
	return STYLE_RULES[#STYLE_RULES]
end

-- ============================================================
-- СТИЛИЗАЦИЯ МОДЕЛИ
-- ============================================================

local function stylizeModel(well)
	local count = { neon = 0, basalt = 0, other = 0 }

	for _, part in ipairs(well:GetDescendants()) do
		if not part:IsA("BasePart") then continue end

		-- Обязательно: якорь для всех деталей
		part.Anchored    = true
		part.CastShadow  = false   -- Оптимизация: декоративные части без теней

		local rule = getStyle(part.Name)

		part.Material     = rule.mat
		part.Color        = rule.color
		part.Transparency = rule.alpha
		part.CanCollide   = rule.collide

		if rule.mat == Enum.Material.Neon then
			count.neon += 1
		elseif rule.mat == Enum.Material.Basalt or rule.mat == Enum.Material.Slate then
			count.basalt += 1
		else
			count.other += 1
		end
	end

	print(string.format("[WishingWellSetup] Styled: %d neon, %d stone, %d other parts",
		count.neon, count.basalt, count.other))
end

-- ============================================================
-- СОЗДАНИЕ HITBOX + PRIMARYPART
-- ============================================================

local function setupHitbox(well)
	-- Проверяем, есть ли уже hitbox
	local existing = well:FindFirstChild("HitBox")
	if existing then return existing end

	-- Создаём невидимый хитбокс в центре модели
	local hitbox = Instance.new("Part")
	hitbox.Name          = "HitBox"
	hitbox.Size          = Vector3.new(8, 6, 8)   -- Охватывает всю ширину колодца
	hitbox.Transparency  = 1
	hitbox.Anchored      = true
	hitbox.CanCollide    = false
	hitbox.CastShadow    = false
	hitbox.CFrame        = well:GetPivot()
	hitbox.Parent        = well

	-- Назначаем PrimaryPart
	well.PrimaryPart = hitbox

	print("[WishingWellSetup] HitBox created + PrimaryPart set")
	return hitbox
end

-- ============================================================
-- POINTLIGHT В ЦЕНТРЕ КОЛОДЦА
-- (подсвечивает персонажа снизу — кинематографичный эффект)
-- ============================================================

local function setupCoreLight(well)
	-- Ищем существующий VFX_Center
	local vfxCenter = well:FindFirstChild("VFX_Center")
	if not vfxCenter then
		vfxCenter = Instance.new("Part")
		vfxCenter.Name         = "VFX_Center"
		vfxCenter.Size         = Vector3.new(0.5, 0.5, 0.5)
		vfxCenter.Transparency = 1
		vfxCenter.Anchored     = true
		vfxCenter.CanCollide   = false
		vfxCenter.CastShadow   = false
		vfxCenter.CFrame       = well:GetPivot() + Vector3.new(0, 1.5, 0)
		vfxCenter.Parent       = well
	end

	-- Удаляем старый свет (хот-релоад)
	local old = vfxCenter:FindFirstChildOfClass("PointLight")
	if old then old:Destroy() end

	-- Основной свет (постоянный, мягкий фиолетовый)
	local coreLight           = Instance.new("PointLight")
	coreLight.Name            = "CoreLight"
	coreLight.Color           = Color3.fromRGB(120, 0, 255)
	coreLight.Brightness      = 2
	coreLight.Range           = 15
	coreLight.Shadows         = false  -- Тени от point light = дорого
	coreLight.Parent          = vfxCenter

	-- Второй свет — широкий слабый для пола
	local floorLight          = Instance.new("PointLight")
	floorLight.Name           = "FloorLight"
	floorLight.Color          = Color3.fromRGB(60, 0, 140)
	floorLight.Brightness     = 0.8
	floorLight.Range          = 22
	floorLight.Shadows        = false
	floorLight.Parent         = vfxCenter

	print("[WishingWellSetup] CoreLight + FloorLight created")
	return coreLight
end

-- ============================================================
-- BILLBOARD GUI НАД КОЛОДЦЕМ
-- ============================================================

local function setupBillboard(well)
	-- Удаляем старый (хот-релоад)
	local old = well:FindFirstChild("WellNameTag")
	if old then old:Destroy() end

	-- Ищем высшую точку модели для StudsOffset
	local topPart = well:FindFirstChild("VFX_Center") or well:FindFirstChildWhichIsA("BasePart")
	if not topPart then return end

	local bb          = Instance.new("BillboardGui")
	bb.Name           = "WellNameTag"
	bb.Size           = UDim2.new(0, 280, 0, 60)
	bb.StudsOffset    = Vector3.new(0, 8, 0)   -- 8 стадов над центром
	bb.AlwaysOnTop    = false
	bb.Adornee        = topPart
	bb.MaxDistance    = 30
	bb.Parent         = well

	-- Фон
	local bg             = Instance.new("Frame")
	bg.Size              = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3  = Color3.fromRGB(8, 6, 14)
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel   = 0
	bg.Parent            = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius  = UDim.new(0, 8)
	corner.Parent        = bg

	-- Неоновый бордер
	local stroke = Instance.new("UIStroke")
	stroke.Color       = Color3.fromRGB(140, 0, 255)
	stroke.Thickness   = 1.5
	stroke.Transparency = 0.2
	stroke.Parent      = bg

	-- Иконка
	local icon           = Instance.new("TextLabel")
	icon.Size            = UDim2.new(0, 40, 1, 0)
	icon.Position        = UDim2.new(0, 5, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text            = "✨"
	icon.Font            = Enum.Font.Gotham
	icon.TextSize        = 22
	icon.TextColor3      = Color3.new(1, 1, 1)
	icon.Parent          = bg

	-- Главный текст
	local lbl            = Instance.new("TextLabel")
	lbl.Size             = UDim2.new(1, -50, 0.55, 0)
	lbl.Position         = UDim2.new(0, 45, 0, 4)
	lbl.BackgroundTransparency = 1
	lbl.Text             = "КОЛОДЕЦ ЖЕЛАНИЙ"
	lbl.Font             = Enum.Font.GothamBlack
	lbl.TextSize         = 15
	lbl.TextColor3       = Color3.fromRGB(200, 160, 255)
	lbl.TextStrokeTransparency = 0.3
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	lbl.Parent           = bg

	-- Японский субтайтл
	local jp             = Instance.new("TextLabel")
	jp.Size              = UDim2.new(1, -50, 0.4, 0)
	jp.Position          = UDim2.new(0, 45, 0.58, 0)
	jp.BackgroundTransparency = 1
	jp.Text              = "願いの泉  •  500 монет"
	jp.Font              = Enum.Font.Gotham
	jp.TextSize          = 10
	jp.TextColor3        = Color3.fromRGB(100, 80, 140)
	jp.Parent            = bg

	print("[WishingWellSetup] BillboardGui created")
end

-- ============================================================
-- ЖДЁМ МОДЕЛЬ И ЗАПУСКАЕМ СТИЛИЗАЦИЮ
-- ============================================================

local function waitAndSetup()
	local well

	for attempt = 1, 30 do
		local lobby = workspace:FindFirstChild("Lobby")
		if lobby then
			well = lobby:FindFirstChild("WishingWell")
			if well then break end
		end
		task.wait(2)
	end

	if not well then
		warn("[WishingWellSetup] WishingWell not found after 60s. Skipping setup.")
		return
	end

	-- Небольшая пауза чтобы все descendants точно загрузились
	task.wait(0.5)

	stylizeModel(well)
	setupHitbox(well)
	setupCoreLight(well)
	setupBillboard(well)

	-- Сообщаем другим модулям что стилизация завершена
	_G.WishingWellSetupDone = true

	print("[WishingWellSetup] ✓ Full stylization complete!")
end

task.spawn(waitAndSetup)
