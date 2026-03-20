# Anime Arena: Blitz Mode

> Roblox anime-arena s bystrymi raundami 1-3 minuty, 12 geroyami i rangami E-SS

## O proekte

- **Rezhimy**: Blitz, Ranked, One Hit, Tournament, Casual
- **Geroi**: 12 personazhey (Common -> Mythic)
- **Rangi**: E, D, C, B, A, S, SS
- **Monetizatsiya**: kosmetika, battle pass, VIP
- **Instrument**: Rojo (GitHub -> Roblox Studio)

## Struktura proekta

```
anime-arena-blitz/
|-- default.project.json       # Rojo konfig
|-- src/
|   |-- ServerScriptService/
|   |   |-- GameManager.server.lua    # Glavnyy server menedzher
|   |   `-- RoundSystem.server.lua    # Sistema raundov i ranga
|   |-- ReplicatedStorage/
|   |   |-- Config.lua                # Obshchiy konfig igry
|   |   |-- Characters.lua            # Vse 12 geroev: staty + navyki
|   |   `-- Remotes.lua               # Spisk RemoteEvent/Function
|   |-- StarterPlayerScripts/
|   |   `-- ClientManager.client.lua  # Klientskiy input + events
|   |-- StarterGui/                   # (v razrabotke) UI
|   `-- StarterCharacterScripts/      # (v razrabotke) Personazh
`-- .gitignore
```

## Ustanovka i zapusk cherez Rojo

### Trebovaniya
- [Rojo](https://rojo.space/) 7.x
- Roblox Studio
- Git

### Shagi

**1. Kloniruem repozitoriy**
```bash
git clone https://github.com/Romslav/anime-arena-blitz.git
cd anime-arena-blitz
```

**2. Ustanavlivaem Rojo plugin v Studio**
- Skachayte plugin s https://rojo.space
- Ustanovite v Roblox Studio (Plugins -> Manage Plugins)

**3. Zapuskaem Rojo server**
```bash
rojo serve default.project.json
```

**4. Podklyuchaem v Studio**
- Otkroyte Roblox Studio
- Plugins -> Rojo -> Connect
- Ukazhite `localhost:34872`
- Vse fayly iz `src/` sinkhroniziruyutsya avtomaticheski

**5. Razrabotka**
- Redaktiruyte `.lua` fayly v lyubom redaktore (VS Code, Neovim, i t.d.)
- Rojo avtomaticheski obnovlyaet Studio pri sohranenii

## Geroi (alfa roster)

| Geroy | Rol | HP | Slozhnost | Redkost |
|---|---|---:|---|---|
| Flame Ronin | Bruiser | 120 | Easy | Common |
| Void Assassin | Assassin | 95 | Hard | Legendary |
| Thunder Monk | Controller | 110 | Medium | Rare |
| Iron Titan | Tank | 140 | Easy | Epic |
| Scarlet Archer | Ranged | 100 | Medium | Rare |
| Eclipse Hero | ModeHero | 115 | Hard | Mythic |
| Frost Duelist | Bruiser | 118 | Medium | Common |
| Star Blade | Assassin | 96 | Hard | Epic |
| Serpent Priest | Controller | 108 | Medium | Epic |
| Stone Colossus | Tank | 138 | Easy | Legendary |
| Wind Striker | Ranged | 102 | Medium | Rare |
| Nova Emperor | ModeHero | 112 | Hard | Mythic |

## Keybinds (po umolchaniyu)

| Klavisha | Deystvie |
|---|---|
| M1 (LMB) | Ataka / kombo |
| Q | Skill 1 |
| E | Skill 2 |
| R | Skill 3 |
| F | Ultimate |
| Shift | Dodge |

## Sistema rangov matcha

| Ochki | Rang |
|---:|---|
| 95-100 | SS |
| 85-94 | S |
| 70-84 | A |
| 55-69 | B |
| 40-54 | C |
| 25-39 | D |
| 0-24 | E |

## Roadmap

- [ ] v0.1 - MVP: 6 geroev, 1 karta, Blitz + Ranked rezhimy
- [ ] v0.2 - Tournament rezhim, leaderboard, 3 karty
- [ ] v0.3 - Battle Pass, seasons, kosmetika
- [ ] v1.0 - Polnyy reliz: 12 geroev, klan sistema, eventy

## Versiya

`0.1.0-alpha`
