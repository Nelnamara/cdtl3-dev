# CooldownTimeline 3 (CDTL3)

> **WoW:** 12.0.5 (Midnight) · **Maintainer:** Nelnamara · **Original V2 author:** cliffclive · **Original author:** Vreenak (US-Remulos)

CooldownTimeline tracks your ability cooldowns as moving icons along a horizontal timeline bar. As a cooldown expires it slides toward a "ready" zone on the right; when it fires, a configurable alert plays. Supports all spec cooldowns, ICDs, auto-attack swings, and optional Masque skinning.

---

## Screenshots

> *Replace the placeholders below with your own screenshots.*

| Timeline Bar | Config Panel | Ready Alert |
|:---:|:---:|:---:|
| ![Timeline bar showing active cooldowns](docs/screenshot-bar.png) | ![AceConfig options panel](docs/screenshot-config.png) | ![Ready alert firing](docs/screenshot-ready.png) |

---

## Features

- **Visual cooldown timeline** — icons slide along a bar toward a "ready" marker as their cooldowns count down
- **Auto-detection** — discovers spec abilities automatically on login and spec change; no manual setup required
- **Multiple lanes** — separate bars for different cooldown categories (offensive, defensive, etc.)
- **Configurable ready zone** — sound alerts and flash animation when a cooldown comes off cooldown
- **Internal cooldown (ICD) tracking** — tracks proc ICDs alongside regular cooldowns
- **Custom cooldown list** — manually add any spell not auto-detected
- **Shared cooldown support** — optionally hide redundant entries when abilities share a CD
- **Auto-hide** — bar hides when out of combat (configurable)
- **Masque support** — skins all cooldown icons through Masque if installed
- **LibSharedMedia-3.0** — custom fonts, textures, sounds, and borders via LSM
- **AceConfig options panel** — in-game GUI at `/cdtl config` with full profile support

---

## Requirements

| Dependency | Required | Notes |
|---|:---:|---|
| None | — | All libs embedded |
| [Masque](https://www.curseforge.com/wow/addons/masque) | ❌ | Optional — skins cooldown icons |

---

## Installation

1. Download the latest release zip
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
   - The folder should be named **`CooldownTimeline3`**
   - It should contain `CDTL2.lua`, the `.toc` file, and subdirectories
3. Log in and type `/cdtl` to open options, or `/cdtl config`

> **First run:** The bar appears in the center of your screen, unlocked. Drag it to your preferred position, then lock it via `/cdtl lock`.

---

## Usage

### Slash Commands

All commands start with `/cdtl`.

| Command | Description |
|---|---|
| `/cdtl` | Open the options panel |
| `/cdtl config` | Open the options panel |
| `/cdtl lock` | Lock all frames (disable dragging) |
| `/cdtl unlock` | Unlock all frames |
| `/cdtl test` | Toggle test mode (fills bar with sample icons) |
| `/cdtl reset` | Reset bar position to center screen |

### Options Panel

Open with `/cdtl config`. Key settings:

- **Lanes** — configure each lane's size, position, icon scale, and direction
- **Detection** — enable/disable auto-detection; add custom spells by name or spell ID
- **Ready zone** — set sound, flash color, and display duration for ready alerts
- **Appearance** — background, border, bar texture via LibSharedMedia
- **Profiles** — AceDB profiles for per-character or shared configs

### Auto-Detection

On login and spec change, CDTL3 scans your spellbook and builds a cooldown list automatically. You can supplement this with the custom detection list in options, or force-track a spell with its ID.

---

## Known Issues

| Issue | Status |
|---|---|
| Some proc ICDs require manual entry if not in the built-in database | Add via custom detection in options |
| Bar may briefly appear at 0,0 on first ever login before position saves | Drag to position and `/reload` once to persist |
| Masque theming requires Masque to be installed and enabled | Optional dependency — works without it |

---

## Changelog

### v3.0.0 (CDTL3 continuation)
- Renamed project to CooldownTimeline 3 (CDTL3) for continued development
- Updated for Midnight (WoW 12.0.5): SetFont secret-value fix, ba-nil nil-check fixes
- Added GitHub repository and automated release pipeline
- Media paths updated for CooldownTimeline3 folder name

### v2.6r3 (cliffclive)
- Near-complete V2 rewrite by cliffclive
- Multi-lane support, AceConfig options, auto-detection overhaul
- Masque and LibSharedMedia integration
- ICD tracking, shared cooldown handling
- AceDB profiles

### v1.x (Vreenak)
- Original Cooldown Timeline addon
- Basic cooldown icon timeline concept

---

## Roadmap

- [ ] **CDTL3 global variable rename** — migrate internal globals from `CDTL2` to `CDTL3` namespace
- [ ] **SavedVariables migration** — migrate `CDTL2DB` → `CDTL3DB` with import helper
- [ ] **Improved spell detection** — catch more proc ICDs automatically
- [ ] **Compact mode** — smaller single-row layout option
- [ ] **CurseForge / Wago packaging** — automated release pipeline (in progress)

---

## Credits

| Role | Credit |
|---|---|
| Original addon | Vreenak (US-Remulos) |
| V2 rewrite | cliffclive |
| Midnight patch & CDTL3 continuation | Nelnamara |

---

## License

Personal use. Credits to original authors above.
