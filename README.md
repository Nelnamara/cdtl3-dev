# CooldownTimeline 3 (CDTL3)

> **WoW:** Retail 12.1 (Midnight) · Classic Era · TBC Anniversary · MoP Classic · **World of Warcraft: Forever** · **Maintainer:** Nelnamara · **Original V2 author:** cliffclive · **Original author:** Vreenak (US-Remulos)

CooldownTimeline tracks your ability cooldowns as moving icons along a timeline bar. As a cooldown expires it slides toward a "ready" zone; when it comes off cooldown, a configurable alert plays. It also tracks item cooldowns, your buffs and debuffs, internal cooldowns, and optional GCD / health / power / swing tracking on the lane itself, with optional Masque skinning.

---

## Features

- **Visual cooldown timeline** — icons slide along a lane toward a "ready" marker as their cooldowns count down; optional bar frames show the same cooldowns as countdown bars
- **Auto-detection** — spells, items, buffs and debuffs are discovered as you use them; no manual setup required
- **Three lanes, three bar frames, three ready frames** — send each category (or individual spell) where you want it
- **Buff and debuff tracking** — your own buffs/debuffs counting down on a lane or bar
- **Ready alerts** — sound, flash and highlight when something comes off cooldown
- **Internal cooldown (ICD) and custom cooldowns** — add anything not auto-detected, including aura-triggered custom timers
- **Shared cooldown handling** — optionally tracks abilities that lock each other out
- **Lane tracking** — GCD, health, class power, combo points, mana/energy ticks, swing timers drawn on the lane bar
- **Masque support** — skins all cooldown icons through Masque if installed
- **LibSharedMedia-3.0** — fonts, textures, sounds and borders from any SharedMedia pack
- **Minimap button** — left-click opens settings, right-click toggles frame lock, drag to reposition
- **One movable settings window** — every panel is a tab; per-character or shared profiles

---

## Requirements

- Any supported client (see [Client support](#client-support)) — all libraries are embedded, no dependencies
- [Masque](https://www.curseforge.com/wow/addons/masque) *(optional)* — skins cooldown icons

---

## Installation

Install via the CurseForge or Wago app, or extract the release zip into your client's AddOns folder as a folder named exactly **`CooldownTimeline3`** (it should contain `CDTL3.lua`, the `.toc` files and the `Libs`/`Media` folders):

| Client | AddOns folder |
|---|---|
| Retail (Midnight) | `World of Warcraft\_retail_\Interface\AddOns\` |
| Classic Era | `World of Warcraft\_classic_era_\Interface\AddOns\` |
| TBC Anniversary | `World of Warcraft\_anniversary_\Interface\AddOns\` |
| MoP Classic | `World of Warcraft\_classic_\Interface\AddOns\` |
| World of Warcraft: Forever (beta) | `World of Warcraft\_classic_beta_\Interface\AddOns\` |

A GitHub source zip unpacks as `cdtl3-dev-<branch>` and won't show up in the AddOns list until the folder is renamed to `CooldownTimeline3`. New addons are only picked up on a full client restart, not `/reload`. On first run the frames appear unlocked in the center — drag them into place, then `/cdtl3 lock`.

---

## Usage

Type `/cdtl3` to open the settings window. Cooldowns appear as you use abilities and items; buffs and debuffs appear as they land on you. Everything detected is listed under **Filters**, where you can enable, ignore, pin or highlight it and choose its lane, bar frame and ready frame. Long cooldowns and buffs are auto-**ignored** above a per-category threshold (Filters → Defaults → Ignore Threshold) — untick *Ignored* on an entry to show it.

### Slash Commands

Primary command is `/cdtl3` (or `/cooldowntimeline3`). The old `/cdtl2` / `/cooldowntimeline2` remain as legacy aliases.

- **`/cdtl3`** — Open the settings window (movable; every panel is a tab)
- **`/cdtl3 lanes`** / **`ready`** / **`bars`** / **`filters`** / **`profiles`** — Jump straight to that tab
- **`/cdtl3 lock`** / **`/cdtl3 unlock`** — Toggle frame lock (enable/disable dragging)
- **`/cdtl3 test`** — Toggle test mode (fills the frames with sample icons)
- **`/cdtl3 debug`** — Toggle debug mode (debug frame + chat diagnostics)
- **`/cdtl3 auras`** — Print every buff/debuff on you as CDTL3 sees it: readable or hidden by the game, saved or not, ignored, which lane, and whether it's assigned to your character. Use this first if a buff won't show up

### Settings Window

- **Global / Colors** — when CDTL3 is active (always / in group / in instance), class and spell-school colors
- **Lanes** — size, position, direction, icon style, lane tracking (GCD, health, power, swing…)
- **Ready** — sound, flash and duration for ready alerts
- **Bar Frames** — bar texture, size, text and Dynamic Color
- **Filters** — every detected spell, item, buff and debuff, with per-entry settings; **Custom** for your own cooldowns and aura triggers
- **Profiles** — AceDB profiles for per-character or shared configs
- **Import/Export** — share a profile as a string

---

## Client support

One package covers every client; they all share the same saved settings (`CDTL3DB`).

| | Retail (Midnight 12.1) | Classic Era / TBC Anniversary / MoP Classic | World of Warcraft: Forever |
|---|---|---|---|
| Spell & item cooldowns | ✓ | ✓ | ✓ |
| Your buffs / debuffs | ✓ | ✓ | ✓ |
| Debuffs you put on enemies | depends on combat log access | ✓ | ✗ (no combat log for addons) |
| Swing timers | depends on combat log access | ✓ | ✗ (no combat log for addons) |
| Lane health / power tracking | ✓ | ✓ | ✓ |

**Secret values.** On Midnight and Forever the game hides ("makes secret") many numbers from addons — cooldown timings, health and power, and aura details during combat, encounters, Mythic+ and PvP. CDTL3 never does math on a hidden value: cooldowns fall back to tracked cast times, health/power go straight into the lane bar (which can display hidden values), and a buff that becomes unreadable keeps counting down from its last known time instead of disappearing. Buffs gained or recast while hidden are picked up when combat ends.

**World of Warcraft: Forever** runs the modern retail engine but reports a vanilla-era interface number (`16001`). CDTL3 detects it by that number, uses the retail code paths there, and uses the vanilla-era spell data. It loads its own `CooldownTimeline3_Camelot.toc`, with a plain `CooldownTimeline3.toc` as a fallback in case Blizzard renames the Forever suffix before launch.

---

## Known Issues

- **Forever:** debuffs on enemies and swing timers need the combat log, which Forever closes to addons
- **Midnight / Forever:** buffs gained or recast in combat appear (or update) only after combat ends; the GCD tracker and cooldowns of spells with no cooldown of their own are estimated while timings are hidden
- **Midnight:** the game reports a spell's *base* cooldown, not the talent-reduced one — use **Custom CD Time** on the spell (Filters) to enter the real value
- **Forever beta:** the debug frame's *Reload* button may be blocked by the client — type `/reload` instead
- Some proc ICDs aren't in the built-in data — add them as custom cooldowns
- The frames may briefly appear at 0,0 on a first-ever login before their position saves — drag them into place and `/reload` once

---

## Changelog

### v3.0.8
- **World of Warcraft: Forever support** — Forever reports a vanilla-era interface number (`16001`) but runs the modern Midnight-era API, so the old version check sent it down the Classic code paths and called functions Forever doesn't have (`GetSpellInfo`, `GetSpellCooldown`, `UnitAura`, the old spellbook API). CDTL3 now detects Forever by its interface number and uses the retail API paths while keeping the vanilla-era spell data. Ships a `_Camelot` TOC (the Forever client doesn't fall back to `_Mainline`) plus a plain `CooldownTimeline3.toc` fallback
- **Combat log registration can't break detection** — it's only registered where the client provides it, and a refusal no longer aborts registering the other cooldown events. The combat log is closed to addons on Forever
- **Updated the bundled Ace3 libraries to r1403** — the old copy called globals newer clients removed (`SetDesaturation`) and passed a boolean as tooltip alpha, which errored in the options window on Forever and will on WoW 12.1.5
- **Item/spellbook lookups ready for 12.1.5** — `GetItemSpell`/`GetItemInfoInstant` (removed in 12.1.5) and `IsSpellKnown`/`IsSpellKnownOrOverridesKnown` (deprecation-only since 11.2) now go through wrappers that use `C_Item`/`C_SpellBook` when the old globals are gone; the action-button glow highlight falls back to the border highlight where the glow API is missing
- **Buff/debuff detection without the combat log** — buffs and debuffs on you (and custom aura triggers) were only discovered through the combat log, which Forever closes to addons, so e.g. Mark of the Wild never appeared under Buffs. They're now also picked up from `UNIT_AURA`: newly added auras, recasts of a buff you already have (an aura *update*), and buffs already on you at login, `/reload` or zoning (a *full* update). Auras that are secret (in combat, encounters, M+, PvP) are skipped. Debuffs you apply to enemies and the swing timer still need the combat log
- **Secret-value hardening for lanes, items and auras** — on Forever (and Midnight while restricted) player health/power, attack speed, item cooldowns and even the `UNIT_AURA` payload can be secret. Lane HEALTH / CLASS_POWER / COMBO_POINTS tracking now feeds secret values straight to the status bar (which accepts them) instead of dividing them; swing timers show a full bar, the mana/energy tick estimate pauses, item cooldowns keep counting down from their last readable value, and text tags show `?` when a value is secret
- **Fixed detected buffs/debuffs missing from the Filters list** — a buff seen at login, before the character was known, was saved without an owner and never listed for anyone (Mark of the Wild showed `yours=false` in `/cdtl3 auras`). Saved entries are now claimed for your character whenever the aura is seen again, and the login scan waits until the character is known
- **Fixed the debug frame's Options button** — it still used `Settings.OpenToCategory("CDTL3")`, which errors on Midnight and Forever; it now opens the CDTL3 window like `/cdtl3`
- **New `/cdtl3 auras`** — prints every buff/debuff on you as CDTL3 sees it (or that it's hidden/secret), whether it's saved, ignored and assigned to you, plus whether aura events are arriving — for troubleshooting buff detection
- **Fixed an options error in Filters** — with `<< Select >>` (no entry) chosen in a Filters list, the Custom CD Time fields looked up settings that don't exist and errored (`Options.lua: attempt to index local 's'`); they now stay hidden until a real entry is selected
- **Fixed buffs/debuffs recording spell ID 0 on Classic clients** — a typo in the Classic aura reader dropped the spell ID
- TOCs bumped: MoP Classic `50504`, TBC Anniversary `20506`, Classic Era `11509`

### v3.0.7
- **All settings now live in one movable window** — `/cdtl3` opens the full configuration with every panel (Lanes, Ready, Bar Frames, Filters, Profiles) as a tab. Previously the standalone window showed only a fraction of the settings; the rest were buried in Blizzard's unmovable Settings frame — including the lane and bar color/texture options many users never found. Blizzard's AddOns entry is now just a launcher button
- **New slash shortcuts** — `/cdtl3 lanes | ready | bars | filters | profiles` jump straight to a tab
- **New: Dynamic Color for cooldown bars** — the bar blends from a warning color into a ready color over its final seconds (Bar Frames → Bars → Dynamic Color; off by default)
- **New: Spell School Color for bars** — the toggle existed in the engine but was never exposed in options
- **Midnight 12.1 (Curse of Ula'tek) compatibility** — aura tracking (buffs/debuffs/offensives) now reads aura data inside a protected call, so 12.1's secret-aura rules no longer cause error spam in combat, Mythic+, or PvP; tracking degrades gracefully while auras are secret
- **Fixed aura-triggered entries recording spell ID 0** — a long-standing bug inherited from CDTL2
- TOC bumped to Interface 120100

### v3.0.6
- **Fixed the manual "Custom CD Time" override** — it was being silently overwritten every frame by the game's live cooldown duration, which on Midnight reports the *base* cooldown (talent reductions stripped out). Custom values never took effect. The override now reliably drives the timeline, so you can correct talent-reduced cooldowns the game reports at base duration (e.g. Bestial Wrath showing 90s instead of the talented 30s) — toggle **Custom CD Time** on the spell in Filters and enter the real value

### v3.0.5
- **Fixed the checkerboard minimap button & AddOns-list icon on Midnight** — PNG textures render as the missing-texture checkerboard on 12.0.x; CDTL3 now ships `.tga` versions (`minimap.tga`, `icon-128.tga`)

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

<details>
<summary>Planned</summary>

- **Drop the legacy `CDTL2DB` declaration** — once users have migrated, remove it from the TOCs
- **Improved spell detection** — catch more proc ICDs automatically
- **Compact mode** — smaller single-row layout option
- **Per-lane layout swap** — quick switch between setups (raid ST vs M+ AoE)

</details>

---

## Feature Requests

<details>
<summary>How to request</summary>

Open an issue on [GitHub](https://github.com/Nelnamara/cdtl3-dev/issues) or leave a CurseForge comment — include your class/spec and the spell or behavior you'd like.

</details>

---

## Credits

- **Original addon** — Vreenak (US-Remulos)
- **V2 rewrite** — cliffclive
- **Midnight patch & CDTL3 continuation** — Nelnamara

---

## License

Personal use. Credits to original authors above.
