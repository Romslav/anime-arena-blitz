# 🗡️ Мастер Арены (Arena Master NPC) — Полная Инструкция Интеграции в Roblox Studio

Это подробное руководство по добавлению The Stoic Sensei в ваш игровой мир.

---

## 📋 Содержание
1. [Краткий обзор](#краткий-обзор)
2. [Синхронизация с Rojo](#синхронизация-с-rojo)
3. [Проверка в Studio](#проверка-в-studio)
4. [Файлы и структура](#файлы-и-структура)
5. [Что происходит при запуске](#что-происходит-при-запуске)
6. [Настройка и кастомизация](#настройка-и-кастомизация)
7. [Решение проблем](#решение-проблем)

---

## Краткий обзор

**Мастер Арены** — это NPC №2 в проекте Anime Arena: Blitz. Это серьёзный персонаж-сенсей, стоящий слева в лобби напротив Торговца.

### Главные компоненты:

| Компонент | Файл | Назначение |
|-----------|------|-----------|
| **Config** | `ReplicatedStorage/ArenaMasterConfig.lua` | Цвета, размеры, параметры анимаций |
| **Builder** | `ServerScriptService/ArenaMasterNPCBuilder.server.lua` | Создаёт тело из 100+ частей на сервере |
| **VFX** | `StarterPlayerScripts/ArenaMasterVFX.client.lua` | Клиентские эффекты (красные глаза, аура) |
| **Model Stub** | `default.project.json` | Заготовка модели в Workspace.Lobby.NPCs |
| **3D Модель** | `exports/npc/ArenaMaster/ArenaMaster.fbx` | Для справки (опционально) |

---

## Синхронизация с Rojo

### Шаг 1: Убедитесь, что Rojo запущен

```bash
# В папке проекта:
cd /Users/romanov.vyacheslav/Documents/anime-arena-blitz
rojo serve
```

Должно вывести:
```
🔗 Rojo server running at http://localhost:34872/
Serving /path/to/anime-arena-blitz
```

### Шаг 2: Подключите Rojo плагин в Roblox Studio

1. Откройте **Roblox Studio** (ваш game place)
2. Найдите **Rojo плагин** в Plugins → Rojo → **Sync**
3. Должно появиться окно "Rojo Connected"

**ВАЖНО:** Если плагина нет → скачайте его с [rojo.space/docs](https://rojo.space/docs/installation/)

### Шаг 3: Проверьте синхронизацию файлов

В Studio:

```
Workspace
└── Lobby
    └── NPCs
        ├── ArenasMaster (пустой Model)
        └── Trader (пустой Model)

ReplicatedStorage
├── ArenaMasterConfig (ModuleScript)
├── MerchantConfig (ModuleScript)
└── Remotes (Folder с RemoteEvent/Function)

ServerScriptService
├── ArenaMasterNPCBuilder (Script)
├── MerchantNPCBuilder (Script)
└── ... (остальные системные скрипты)

StarterPlayer/StarterPlayerScripts
├── ArenaMasterVFX (LocalScript)
├── MerchantVFX (LocalScript)
└── ... (остальные клиентские скрипты)
```

✅ **Если видите все файлы → Rojo работает корректно**

---

## Проверка в Studio

### Вариант A: Play Solo (локально)

1. Нажмите **▶ Play** (F5)
2. Выжидайте ~5 секунд загрузки (серверные скрипты инициализируются)
3. Лобби загрузится → вы спавнитесь в центре
4. **Слева** (на координатах ≈ X=-40, Z=12) вы должны увидеть:

```
┌──────────────────────────────────────────┐
│                                          │
│    [Торговец]         [Мастер Арены]    │
│     (справа)              (слева)        │
│                  [Спавн]                 │
│                (центр)                   │
└──────────────────────────────────────────┘
```

### Вариант B: Team Test

1. **File** → **Publish to Roblox as...** (если нужно)
2. Откройте в браузере Roblox
3. Запустите место (может занять дольше)

---

## Файлы и структура

### Конфиг-файл: `ArenaMasterConfig.lua`

```lua
ArenaMasterConfig.NPC_MODEL_NAME = "ArenasMaster"  -- Имя модели в Workspace.Lobby.NPCs
ArenaMasterConfig.Colors = { ... }                 -- 26 материалов (цвета)
ArenaMasterConfig.Sizes = { ... }                  -- Размеры частей
ArenaMasterConfig.Offsets = { ... }                -- Позиции частей (относительно HRP)
ArenaMasterConfig.Anim = { ... }                   -- Параметры анимаций
```

**Используется:**
- `ArenaMasterNPCBuilder` (сервер) — при создании тела
- `ArenaMasterVFX` (клиент) — для цветов и параметров VFX

### Builder: `ArenaMasterNPCBuilder.server.lua`

```
Запускается автоматически при старте сервера.

1. Ждёт появления workspace.Lobby.NPCs.ArenasMaster
2. Создаёт ~100 частей (голова, тело, броня, меч, эффекты)
3. Назначает материалы из Config
4. Стартует серверные анимации:
   - Пульсация ауры меча (красная)
   - Орбита плавающих каллиграфических иероглифов
   - Дыхание красной мистики у ног
   - Мерцание золотых иероглифов на оби и спине
   - Движение хаори (плаща)

5. Экспортирует сам себя в _G.ArenaMasterNPCBuilder (для отладки)
```

**Результат:** Полностью собранный 3D персонаж, видный всем игрокам

### VFX: `ArenaMasterVFX.client.lua`

```
Запускается на КАЖДОМ КЛИЕНТЕ отдельно.

1. Ждёт появления модели в workspace.Lobby.NPCs.ArenasMaster
2. Создаёт ПОРТРЕТ в ScreenGui (ViewportFrame с 3D клоном)
3. Стартует клиентские эффекты:
   - Красные глаза светятся при приближении (delay 5s)
   - Усиление ауры мистики при близости
   - Искры меча (ParticleEmitter)
   - Портрет показывает цитаты сенсея

4. Привязывает к OpenLobbyMenu событию (показ/скрытие портрета)
```

**Результат:** Каждый клиент видит свои эффекты (красные глаза светят лично ему)

---

## Что происходит при запуске

### На сервере (примерно в течение 1-2 секунд):

```
[ArenaMasterNPCBuilder] Building The Stoic Sensei body...
[ArenaMasterNPCBuilder] Built 137 parts
[ArenaMasterNPCBuilder] All animations started ✓
[ArenaMasterNPCBuilder] The Stoic Sensei stands ready.
```

### На клиентах (примерно в течение 2-3 секунд):

```
[ArenaMasterVFX] Sensei model found, initialising client effects...
[ArenaMasterVFX] Client effects active
```

### В лобби:

1. Персонаж появляется слева (статичная поза — скрещённые руки)
2. Вокруг него пульсирует красная аура
3. При приближении → красные глаза начинают тлеть (5-секундный delay)
4. Меч излучает красный свет
5. Над ним табличка "Мастер Арен「SSS」" (красного цвета)
6. Нажимаете кнопку взаимодействия → открывается меню выбора режима
7. При открытии меню → портрет (3D лицо) появляется слева + цитата

---

## Настройка и кастомизация

### Измените цвет глаз:

```lua
-- ArenaMasterConfig.lua, строка ~50
RedGlow = C(204, 13, 13),  -- Измените RGB значения
```

### Измените позицию в лобби:

```lua
-- NPCService.server.lua, строка ~74
NPC_SPAWN_POSITIONS = {
    ["ArenasMaster"] = CFrame.lookAt(
        Vector3.new(-40, 5, 12),     -- X, Y, Z (NEW POSITION)
        Vector3.new(0, 5, 0)         -- Куда смотрит
    ),
    ...
}
```

### Измените скорость анимаций:

```lua
-- ArenaMasterConfig.lua, строка ~150+
ArenaMasterConfig.Anim = {
    SwordAuraPulseSpeed  = 0.6,     -- Увеличьте для быстрой пульсации
    EyeGlowIdleDelay    = 5.0,      -- Сколько секунд ждать перед свечением глаз
    KanjiOrbitSpeed      = 0.15,    -- Скорость вращения иероглифов
    ...
}
```

### Добавьте больше цитат:

```lua
-- ArenaMasterVFX.client.lua, строка ~82
local FLAVORS = {
    "Твоя цитата здесь",
    "Ещё цитата",
    ...
}
```

---

## Решение проблем

### ❌ Мастер Арены не появляется в лобби

**Решение 1:** Проверьте логи сервера (Output в Studio)
```
Если видите: "[ArenaMasterNPCBuilder] workspace.Lobby not found"
→ Убедитесь, что Workspace.Lobby существует в вашей карте
```

**Решение 2:** Перезагрузите Studio
```
1. Закройте место
2. Откройте заново
3. Повторно подключитесь к Rojo (Sync)
```

**Решение 3:** Проверьте default.project.json
```
Должна быть строка:
"ArenasMaster": {
  "$className": "Model",
  ...
}
```

### ❌ Красные глаза не светятся

**Проверьте:**
1. Приближитесь к Мастеру на **< 12 стадов** (PromptDistance * 1.5)
2. **Подождите 5 секунд** (EyeGlowIdleDelay)
3. Проверьте Output → должно быть "Client effects active"

### ❌ Портрет не показывается

**Решение:**
```lua
-- ArenaMasterVFX.client.lua, строка ~320
-- Убедитесь, что это событие подключено:
rOpenLobby.OnClientEvent:Connect(showPortrait)
```

### ❌ Скрипты не синхронизируются из Rojo

**Действия:**
1. Посмотрите в консоли браузера (F12) → сообщения об ошибках
2. Переподключитесь: Plugins → Rojo → **Disconnect** → **Sync**
3. Перезагрузите место (F5)

### ❌ Аура мистики не видна

**Проверьте:**
1. Графика выставлена на **Средне/Высоко** (красные неоновые эффекты требуют материалов)
2. ParticleEmitter включён (в Explorer → HumanoidRootPart → RedAuraEmitter → Enabled: true)
3. Проверьте, что сервер запустил ArenaMasterNPCBuilder (Output → "All animations started")

---

## 🚀 Финальная проверка перед боевым использованием

Запустите эту тестовую последовательность:

1. **Откройте место** (F5)
2. **Выжидайте загрузку** (скрипты должны напечатать логи)
3. **Подойдите к Мастеру** (слева в лобби)
   - ✅ Видите красную ауру вокруг?
   - ✅ Над ним табличка "Мастер Арен"?
4. **Стойте рядом 5+ секунд**
   - ✅ Красные глаза начинают светить?
5. **Нажмите на кнопку взаимодействия**
   - ✅ Открывается меню выбора режима?
   - ✅ Слева появляется 3D портрет?
6. **Закройте меню**
   - ✅ Портрет исчезает?

**Если всё работает → Мастер Арены готов к боям! ⚔️**

---

## 📚 Дополнительная информация

### Структура части (Part):
```lua
Part.Name = "PauldronR"                    -- Уникальное имя
Part.Size = Vector3.new(0.7, 0.45, 1.1)   -- Размер (ширина, высота, глубина)
Part.Color = Color3.fromRGB(5, 5, 8)       -- Цвет RGB
Part.Material = Enum.Material.Metal        -- Материал
Part.Transparency = 0                      -- Прозрачность (0=непрозрачно, 1=невидимо)
Part.Anchored = true                       -- Закреплено (не падает)
Part.CFrame = CFrame...                    -- Позиция и ориентация
```

### Поддерживаемые материалы:
- `Enum.Material.SmoothPlastic` — гладкий пластик (кимоно, броня)
- `Enum.Material.Metal` — металл (наручи, меч)
- `Enum.Material.Neon` — свечение (красные эффекты, золотые иероглифы)

### ParticleEmitter (частицы):
```lua
ParticleEmitter.Rate = 8                   -- Сколько частиц в секунду
ParticleEmitter.Lifetime = NumberRange.new(1.5, 3.0)  -- Сколько живёт частица
ParticleEmitter.Speed = NumberRange.new(0.1, 0.4)     -- Скорость разлёта
ParticleEmitter.Color = ColorSequence.new(color1, color2)  -- Переход цветов
```

---

## 🎬 Скрины и демонстрация

Модель Мастера Арены экспортирована в:
```
exports/npc/ArenaMaster/ArenaMaster.fbx       (497 KB — сама модель)
exports/npc/ArenaMaster/ArenaMaster.blend     (197 KB — исходник Blender)
```

Можете открыть `.blend` в Blender для просмотра анимаций:
1. Откройте `ArenaMaster.blend`
2. Нажмите **Spacebar** → Play (проигрывание анимации)
3. Animation Editor показывает дыхание (120 кадров)

---

## ✅ Готово!

Теперь у вас есть **The Stoic Sensei** — полностью готовый к боевому использованию NPC Мастер Арены с:
- ✅ Тёмным кимоно и обсидиановой броней
- ✅ Нодати мечом с красной аурой
- ✅ Золотыми иероглифами на спине
- ✅ Красным свечением при приближении
- ✅ Живым 3D портретом в лобби
- ✅ Серверными и клиентскими эффектами
- ✅ Полной интеграцией в игровую систему

**Успешного развития! ⚔️✨**
