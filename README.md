# CooldownTimeline 3 (CDTL3)

> **WoW:** 12.0.7 (Midnight) · **Maintainer:** Nelnamara · **Original V2 author:** cliffclive · **Original author:** Vreenak (US-Remulos)

CooldownTimeline tracks your ability cooldowns as moving icons along a horizontal timeline bar. As a cooldown expires it slides toward a "ready" zone on the right; when it fires, a configurable alert plays. Supports all spec cooldowns, ICDs, auto-attack swings, and optional Masque skinning.

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
- **Minimap button** — left-click opens settings, right-click toggles frame lock, drag to reposition
- **AceConfig options panel** — full in-game GUI with profile support

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
   - It should contain `CDTL3.lua`, the `.toc` files, and subdirectories
3. Log in and type `/cdtl3` to open options

> **First run:** The bar appears in the center of your screen, unlocked. Drag it to your preferred position, then lock it via `/cdtl3 lock`.

---

## Usage

### Slash Commands

Primary command is `/cdtl3` (or `/cooldowntimeline3`). The old `/cdtl2` / `/cooldowntimeline2` remain as legacy aliases so long-time users' muscle memory still works.

| Command | Description |
|---|---|
| `/cdtl3` | Open the options panel |
| `/cdtl3 lock` / `/cdtl3 unlock` | Toggle frame lock (enable/disable dragging) |
| `/cdtl3 test` | Toggle test mode (fills the bar with sample icons) |
| `/cdtl3 debug` | Toggle the debug frame |

### Options Panel

Open with `/cdtl3` or the minimap button. Key sections:

- **Lanes** — configure each lane's size, position, icon scale, and direction
- **Bars** — bar texture, dimensions, and ready marker
- **Ready** — sound, flash color, and display duration for ready alerts
- **Filters** — choose what to track or hide
- **Profiles** — AceDB profiles for per-character or shared configs

### Auto-Detection

On login and spec change, CDTL3 scans your spellbook and builds a cooldown list automatically. You can supplement this with the custom detection list in options, or force-track a spell by ID.

---

## Known Issues

| Issue | Status |
|---|---|
| Some proc ICDs require manual entry if not in the built-in database | Add via custom detection in options |
| Bar may briefly appear at 0,0 on first ever login before position saves | Drag to position and `/reload` once to persist |
| Masque theming requires Masque to be installed and enabled | Optional dependency — works without it |

---

## Changelog

### v3.0.4
- **Fixed secret-value crashes (Midnight 12.0.7)** — `C_Spell.GetSpellCooldown`/`GetSpellCharges` timing fields are secret when execution is tainted; comparing them threw "attempt to compare a secret number value" and spammed the Lane view. Both now compare *inside* a `pcall` and fall back to event-tracked cast time on failure
- **Completed the CDTL2 → CDTL3 rename** — object, AceAddon name, AceConfig keys, frame names, and Masque group are all `CDTL3` now. The saved DB migrates `CDTL2DB → CDTL3DB` automatically on first load, so existing profiles carry over
- Added `/cdtl3` + `/cooldowntimeline3` slash commands (`/cdtl2` kept as a legacy alias)

### v3.0.3
- Minimap button and AddOns-list icon (new artwork, standard 24px)
- Rebranded remaining CDTL2 labels to CDTL3

### v3.0.2
- **Fixed MoP Classic profile wipe** — the Classic TOCs declared the wrong SavedVariables name, silently wiping profiles; all TOCs now agree
- Fixed an `OpenToCategory` error on Midnight by opening options through `AceConfigDialog:Open`
- Unified Classic TOC versions

### v3.0.1
- 12.0.7 compatibility patch; guarded `SetFont` asset/height

### v3.0.0 (CDTL3 continuation)
- Renamed project to CooldownTimeline 3 (CDTL3) for continued development
- Updated for Midnight: SetFont secret-value fix, nil-check fixes
- Added GitHub repository and automated release pipeline (CurseForge + Wago)

### v2.6r3 (cliffclive)
- Near-complete V2 rewrite: multi-lane support, AceConfig options, auto-detection overhaul, Masque + LibSharedMedia integration, ICD tracking, shared cooldown handling, AceDB profiles

### v1.x (Vreenak)
- Original Cooldown Timeline addon — the cooldown-icon timeline concept

---

## Roadmap

- [ ] **Drop the legacy `CDTL2DB` declaration** — once users have migrated, remove it from the TOCs
- [ ] **Improved spell detection** — catch more proc ICDs automatically
- [ ] **Compact mode** — smaller single-row layout option
- [ ] **Per-lane layout swap** — quick switch between setups (raid ST vs M+ AoE)

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
