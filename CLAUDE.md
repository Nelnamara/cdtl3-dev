# CDTL3 (Cooldown Timeline 3) — CLAUDE.md

Tracks cooldowns as icons along a timeline. **Continuation** of Cooldown Timeline
(original by Vreenak, v2 rewrite by cliffclive), patched for **Midnight 12.x** and
continued by Nelnamara. Repo folder is `cdtl3-dev`; the deployed AddOn folder is
**`CooldownTimeline3`**. AceAddon-based.

## Naming: fully `CDTL3` (rename complete)
The object, AceAddon name, AceConfig table keys, frame names, and Masque group are all `CDTL3` now (formerly `CDTL2`). The saved DB is **`CDTL3DB`**, migrated from the old `CDTL2DB` in `OnInitialize`:
`if not CDTL3DB and CDTL2DB then CDTL3DB = CDTL2DB end` (before `AceDB:New("CDTL3DB", ...)`).
The TOCs declare **both** (`## SavedVariables: CDTL3DB CDTL2DB`) so the old global still loads for that one-time migration — drop `CDTL2DB` from the TOC in a future version. The lowercase `/cdtl2` slash stays as a legacy alias. **Do not reintroduce uppercase `CDTL2`** except that TOC migration declaration.

## Files
- `CDTL3.lua` — AceAddon: `OnInitialize` (incl. DB migration)/`OnEnable`/`ChatCommand`, minimap button. (`CDTL3.version`, `CDTL3.discordlink` near top.)
- `Options.lua` — AceConfig options tables + `GetChangeLog()` (root options `name = "CDTL3"`).
- `Helpers.lua`, `Data.lua`, `Media.lua`, `Holders.lua`, `Lanes.lua`, `BarFrames.lua`, `Ready.lua`, `Cooldown.lua`. `Libs/` = Ace3 + LibSharedMedia.

## Multi-version TOCs (all must agree on SavedVariables)
`CooldownTimeline3_Mainline.toc` (Interface 120100), `_Mists` (50504 = MoP Classic 5.5.4),
`_TBC` (20506 = TBC Anniversary 2.5.6), `_Vanilla` (11509 = Classic Era 1.15.9), `_Camelot` (16001 = WoW: Forever 1.60.1), and an unsuffixed **`CooldownTimeline3.toc`** (16001) as the Forever fallback. The Forever beta loads `_Camelot.toc` then the plain `.toc` — it does **not** fall back to `_Mainline.toc` (tried in 3.0.8 dev; addon didn't appear in the list). `_Camelot` "may change before launch", hence the plain fallback. The packager reads X-Curse-Project-ID/X-Wago-ID from the unsuffixed TOC first, so keep those in it; BigWigs packager ≥ v2.6.0 maps `16xxx`/`_Camelot` to CurseForge's Forever game version. All six declare **`## SavedVariables: CDTL3DB CDTL2DB`** (CDTL3DB = live, CDTL2DB = legacy kept for the migration). They must stay identical across all six — a mismatch silently wipes that client's profiles (the Classic TOCs once had the wrong name and did exactly that).

## Midnight gotchas
- `Settings.OpenToCategory("CDTL3")` (string) **errors** on Midnight — use `LibStub("AceConfigDialog-3.0"):Open("CDTL3")` (the slash + minimap button do this).
- **Cooldown values are SECRET when tainted.** `C_Spell.GetSpellCooldown(id).startTime`/`.duration` can be *read* without error, but **comparing or doing arithmetic on them throws** ("attempt to compare a secret number value"). Both `Helpers.lua:GetSpellCooldown` **and** `GetSpellCharges` do the comparison **inside** a `pcall` and only return real numbers (GetSpellCooldown falls back to event-tracked cast time + `GetSpellBaseCooldown`; GetSpellCharges falls back to 0s). Never compare/use these outside the protected closure (the GetSpellCooldown form was the v3.0.4 fix — Lane view spammed 167× before; GetSpellCharges was hardened the same way to prevent the twin crash on charge-based CDs).
- **Textures must be `.tga`, not `.png`, on Midnight.** PNGs render as the missing-texture checkerboard on 12.0.x — the addon ships `.tga` and the `.png` files are kept only as source art. IconTexture → `Media\icon-128.tga`; minimap button texture → `Media\minimap.tga`. (v3.0.5 fix.)
- **Midnight reports the *base* cooldown, not the talented one** — `C_Spell.GetSpellCooldown(id).duration` strips talent reductions (e.g. Bestial Wrath shows 90s, not the talented 30s). The per-spell **Custom CD Time** override (Filters) lets users correct this; it must win over the live duration. The v3.0.6 fix stopped the live value from silently overwriting the override every frame.

## WoW: Forever gotchas (3.0.8)
- **Forever = modern Mainline engine + vanilla-era interface number (16xxx).** `CDTL3.isForever` keys off the **16xxx interface band** — `WOW_PROJECT_ID` was Mainline (1) on early beta builds but became **18** in build 70205, so never detect Forever by project ID alone. The old globals (`GetSpellInfo`, `GetSpellCooldown`, `GetSpellCharges`, `UnitAura`, `GetNumSpellTabs`…) are gone, and Midnight secret values apply. So **never gate an API call on `tocversion >= 110000`** — use **`CDTL3.retailAPI`** (CDTL3.lua top; true on retail and Forever). `CDTL3.tocversion` stays for era *content* only (Data.lua spell lists, class-colour pickers, test icons), where Forever correctly behaves as Vanilla. `CDTL3.isForever` for Forever-only exceptions (e.g. SoD `RUNE_UPDATED` doesn't exist there).
- **Combat log is closed to addons on Forever** — `COMBAT_LOG_EVENT_UNFILTERED` is registered only if `CombatLogGetCurrentEventInfo` exists, inside a `pcall`, so a refusal can't abort the rest of `TurnOn`.
- Beta install path (folder name must be exactly `CooldownTimeline3`, not a GitHub zip's `cdtl3-dev-<branch>`): `World of Warcraft\_classic_beta_\Interface\AddOns\CooldownTimeline3\`. Launch is 2026-11-04 — re-check the live interface number then.

## Slash
`/cdtl3` · `/cooldowntimeline3` (primary) · `/cdtl2`, `/cooldowntimeline2` (legacy aliases). Subcommands: `lock`/`unlock`, `test`, `debug`.

## Build / release / deploy
- BigWigs packager on **`v*` tag push** (multi-TOC single package). CurseForge secret: **`CURSFORGE_API_KEY`** (misspelled, leave as-is).
- Local test (retail): copy to `D:\World of Warcraft\_retail_\Interface\AddOns\CooldownTimeline3\`.
- Current version: **3.0.8** (all 6 TOCs + `CDTL3.version`). Recent history: **3.0.4** secret-cooldown crash fixes (GetSpellCooldown + GetSpellCharges) + the full CDTL2→CDTL3 rename with DB migration; **3.0.5** PNG→TGA checkerboard fix (see Midnight gotchas); **3.0.6** fixed the manual **Custom CD Time** override being overwritten by the live (base) cooldown every frame; **3.0.7** unified config window + 12.1 aura secrecy hardening + Dynamic Color (below); **3.0.8** WoW: Forever support (see Forever gotchas).

## Config architecture (3.0.7)
- **All settings live in ONE movable AceConfigDialog window**: `CDTL3:GetFullOptions()` (Options.lua, bottom) = GetMainOptions + the Lanes/Ready/BarFrames/Filters tables + `CDTL3.profile` embedded as tabs (orders 2001–2005, args keys `lanes/ready/barFrames/filters/profiles` — the `/cdtl3 <tab>` slash subcommands SelectGroup on those keys). Registered as `"CDTL3"` in **both** OnInitialize (CDTL3.lua) **and** `RefreshConfig` (Helpers.lua ~1231) — the RefreshConfig re-registration MUST use GetFullOptions or a profile switch strips the tabs.
- **Blizzard's AddOns settings entry is a launcher only** (`"CDTL3Bliz"`, one button → `AceConfigDialog:Open("CDTL3")`), because Blizzard's Settings frame is unmovable. Do NOT re-add child AddToBlizOptions panels — settings hidden there was why users couldn't find the lane/bar color pickers (the 2026-08 CurseForge "add bar colors" request was an access problem, not a missing feature).
- **12.1 aura secrecy**: `AuraExists` (Helpers.lua) does its whole scan + name compare + duration math INSIDE one pcall (same idiom as GetSpellCooldown/GetSpellCharges) and returns nil while auras are secret (combat/encounter/M+/PvP). Aura-triggered tracking degrades gracefully there — that's the best possible without the (display-only) AuraContainer system.
- **Dynamic Color** (off by default): per bar-frame `bar.dynamicColor {enabled, warnTime, warnColor, readyColor}` in defaults (CDTL3.lua ×3); blend applied in `private.UpdateBarDynamicColor` from `private.BarUpdate`; base color resolution factored into `private.GetBarFGColor` (school → class → frame), shared with RefreshBar.

## Conventions
- **Never** append a `Co-Authored-By` trailer to commits. Tabs for indentation (match the existing file).
