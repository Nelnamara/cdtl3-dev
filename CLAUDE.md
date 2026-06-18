# CDTL3 (Cooldown Timeline 3) — CLAUDE.md

Tracks cooldowns as icons along a timeline. **Continuation** of Cooldown Timeline
(original by Vreenak, v2 rewrite by cliffclive), patched for **Midnight 12.x** and
continued by Nelnamara. Repo folder is `cdtl3-dev`; the deployed AddOn folder is
**`CooldownTimeline3`**. AceAddon-based.

## ⚠️ Internal name is "CDTL2" — do NOT rename
The AceAddon object, AceDB, and AceConfig keys are all `"CDTL2"`:
`CDTL2 = LibStub("AceAddon-3.0"):NewAddon("CDTL2", ...)`, `AceDB:New("CDTL2DB")`,
`RegisterOptionsTable("CDTL2", ...)`, `AceConfigDialog:Open("CDTL2")`.
Renaming these breaks saved data + options. Only **display strings** were rebranded to "CDTL3" (panel title, changelog, prints).

## Files
- `CDTL3.lua` — AceAddon: `OnInitialize`/`OnEnable`/`ChatCommand`, minimap button. (`CDTL2.version`, `CDTL2.discordlink` near top.)
- `Options.lua` — AceConfig options tables + `GetChangeLog()` (root options `name = "CDTL3"`).
- `Helpers.lua`, `Data.lua`, `Media.lua`, `Holders.lua`, `Lanes.lua`, `BarFrames.lua`, `Ready.lua`, `Cooldown.lua`. `Libs/` = Ace3 + LibSharedMedia.

## Multi-version TOCs (all must agree on SavedVariables)
`CooldownTimeline3_Mainline.toc` (Interface 120007), `_Mists` (50503 = MoP Classic),
`_TBC` (20505), `_Vanilla` (11508). **`## SavedVariables: CDTL2DB` in ALL of them** —
the Classic TOCs once said `CDTL3DB`, which silently wiped Classic profiles. Keep them matching the Lua (`CDTL2DB`).

## Midnight gotchas
- `Settings.OpenToCategory("CDTL2")` (string) **errors** on Midnight — use `LibStub("AceConfigDialog-3.0"):Open("CDTL2")` (the slash + minimap button do this).
- **Cooldown values are SECRET when tainted.** `C_Spell.GetSpellCooldown(id).startTime`/`.duration` can be *read* without error, but **comparing or doing arithmetic on them throws** ("attempt to compare a secret number value"). In `Helpers.lua:GetSpellCooldown` the `duration > 0` check is done **inside** the `pcall`; on failure it falls back to event-tracked cast time + `GetSpellBaseCooldown` (static, non-secret). Never compare/use these outside the protected closure (this was the v3.0.4 fix — Lane view spammed 167× before).
- IconTexture → `Media\icon-128.png`; minimap button texture → `Media\minimap.png`.

## Slash
`/cdtl3` · `/cooldowntimeline3` (primary) · `/cdtl2`, `/cooldowntimeline2` (legacy aliases). Subcommands: `lock`/`unlock`, `test`, `debug`.

## Build / release / deploy
- BigWigs packager on **`v*` tag push** (multi-TOC single package). CurseForge secret: **`CURSFORGE_API_KEY`** (misspelled, leave as-is).
- Local test (retail): copy to `D:\World of Warcraft\_retail_\Interface\AddOns\CooldownTimeline3\`.
- Current version: **3.0.4** (TOCs + `CDTL2.version`). v3.0.4 = the secret-cooldown crash fix; committed + pushed, **tag `v3.0.4` once verified in-game** (Lane view clean, no error).

## Conventions
- **Never** append a `Co-Authored-By` trailer to commits. Tabs for indentation (match the existing file).
