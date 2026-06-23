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
`CooldownTimeline3_Mainline.toc` (Interface 120007), `_Mists` (50503 = MoP Classic),
`_TBC` (20505), `_Vanilla` (11508). All declare **`## SavedVariables: CDTL3DB CDTL2DB`** (CDTL3DB = live, CDTL2DB = legacy kept for the migration). They must stay identical across all four — a mismatch silently wipes that client's profiles (the Classic TOCs once had the wrong name and did exactly that).

## Midnight gotchas
- `Settings.OpenToCategory("CDTL3")` (string) **errors** on Midnight — use `LibStub("AceConfigDialog-3.0"):Open("CDTL3")` (the slash + minimap button do this).
- **Cooldown values are SECRET when tainted.** `C_Spell.GetSpellCooldown(id).startTime`/`.duration` can be *read* without error, but **comparing or doing arithmetic on them throws** ("attempt to compare a secret number value"). Both `Helpers.lua:GetSpellCooldown` **and** `GetSpellCharges` do the comparison **inside** a `pcall` and only return real numbers (GetSpellCooldown falls back to event-tracked cast time + `GetSpellBaseCooldown`; GetSpellCharges falls back to 0s). Never compare/use these outside the protected closure (the GetSpellCooldown form was the v3.0.4 fix — Lane view spammed 167× before; GetSpellCharges was hardened the same way to prevent the twin crash on charge-based CDs).
- **Textures must be `.tga`, not `.png`, on Midnight.** PNGs render as the missing-texture checkerboard on 12.0.x — the addon ships `.tga` and the `.png` files are kept only as source art. IconTexture → `Media\icon-128.tga`; minimap button texture → `Media\minimap.tga`. (v3.0.5 fix.)
- **Midnight reports the *base* cooldown, not the talented one** — `C_Spell.GetSpellCooldown(id).duration` strips talent reductions (e.g. Bestial Wrath shows 90s, not the talented 30s). The per-spell **Custom CD Time** override (Filters) lets users correct this; it must win over the live duration. The v3.0.6 fix stopped the live value from silently overwriting the override every frame.

## Slash
`/cdtl3` · `/cooldowntimeline3` (primary) · `/cdtl2`, `/cooldowntimeline2` (legacy aliases). Subcommands: `lock`/`unlock`, `test`, `debug`.

## Build / release / deploy
- BigWigs packager on **`v*` tag push** (multi-TOC single package). CurseForge secret: **`CURSFORGE_API_KEY`** (misspelled, leave as-is).
- Local test (retail): copy to `D:\World of Warcraft\_retail_\Interface\AddOns\CooldownTimeline3\`.
- Current version: **3.0.6** (TOCs + `CDTL3.version`), released. Recent history: **3.0.4** secret-cooldown crash fixes (GetSpellCooldown + GetSpellCharges) + the full CDTL2→CDTL3 rename with DB migration; **3.0.5** PNG→TGA checkerboard fix (see Midnight gotchas); **3.0.6** fixed the manual **Custom CD Time** override being overwritten by the live (base) cooldown every frame.

## Conventions
- **Never** append a `Co-Authored-By` trailer to commits. Tabs for indentation (match the existing file).
