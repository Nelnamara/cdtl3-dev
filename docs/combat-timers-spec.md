# Combat timers test build: spec

Repo `C:\Users\gwilkins\source\repos\cdtl3-dev`, branch **`combat-timers`** (already checked out, cut from
`cdm-probe`). WoW addon CDTL3 (Lua 5.1, tabs for indentation). Read the repo `CLAUDE.md` first, then
`docs/cooldown-manager-scope.md` (sections "Probe results" and "Experimental build: combat timers") and
`docs/secret-timers-scope.md` ("Phase 1 scope (decided 2026-10-25)").

Goal: on clients that hide cooldown and aura values from addons in combat (Retail 12.x and WoW: Forever,
`CDTL3.retailAPI`), keep CDTL3's spell icons sliding and bars draining **with the game's exact timer**, and
give buffs the player put in Blizzard's Cooldown Manager **Tracked Bars** an exact timer too. Out of combat,
and on Classic clients, nothing changes.

## What two in-game probe runs proved (Forever 1.60.1, addon code, in combat)

`Probe.lua` on this branch holds working code for every call below; reuse its patterns.
- `C_Spell.GetSpellCooldownDuration(id)` returns a duration object every time in combat (values secret).
  A **new object** comes back on each fetch: re-fetch on `SPELL_UPDATE_COOLDOWN` / `SPELL_UPDATE_CHARGES`.
- `C_Spell.GetSpellCooldown(id)` fields `isActive` and `isOnGCD` are readable in combat.
- `C_Secrets.ShouldSpellCooldownBeSecret(id)` / `ShouldCooldownsBeSecret()` / `ShouldAurasBeSecret()` return readable booleans.
- From addon code in combat, all OK: `StatusBar:SetMinMaxValues(0, secret)`, `StatusBar:SetValue(secret)`,
  `SetValue(dur:GetRemainingDuration())`, `SetValue(dur:EvaluateRemainingDuration(curve))` (curve built with
  `C_CurveUtil.CreateCurve()` + `AddPoint` out of combat), `C_DurationUtil.CreateDurationTextBinding()` +
  `SetDuration(dur)`, `dur:GetTotalDuration()` (returns secret).
- Post-hooks (`hooksecurefunc`) on each `BuffBarCooldownViewer` item's `.Bar` `SetMinMaxValues` / `SetValue`
  receive Blizzard's secret buff duration and remaining time every frame while the buff is active, and
  copying them into our own StatusBar works (1683 of 1683). No blocked / forbidden actions.
- `C_UnitAuras.GetAuraDuration` / `GetAuraDataByAuraInstanceID` **fail** in combat from addon code: never use them.
- Frame positions read back **secret** while a frame is anchored to a fill fed a secret value.

From Blizzard's generated API docs (Forever branch; local copies in
`C:\Users\gwilkins\AppData\Local\Temp\claude\b834c9d6881b9734\039f7620-32bb-4d25-93e7-e9cc776f3de5\scratchpad\cdmsrc\`,
or `gh api "repos/Gethe/wow-ui-source/contents/Interface/AddOns/Blizzard_APIDocumentationGenerated/<file>?ref=forever" -H "Accept: application/vnd.github.raw"`):
- `Curve:Evaluate(x)` and `Duration:SetTimeFromStart/SetTimeFromEnd` take secret args **only when untainted**:
  a secret number from the buff mirror can't go through a curve or into a duration object.
- `FontString:SetText` / `SetFormattedText` accept secrets from tainted code.
- StatusBar has no `ClearTimerDuration`: **don't use `SetTimerDuration`**; drive every bar with
  `SetMinMaxValues` + `SetValue`.
- Forever's Blizzard code (`Blizzard_CooldownViewer/CooldownViewer.lua`, local copy in `cdmsrc`):
  `CooldownViewerBuffBarItemMixin:RefreshCooldownInfo` calls `Bar:SetMinMaxValues(0, duration)` +
  `SetValue(remaining)` from OnUpdate **only while the buff is active**, and `SetMinMaxValues(0,0)` +
  `SetValue(0)` once it ends. Edit Mode's Cooldown Manager opacity slider goes no lower than 50%, and its
  "Hidden" setting hides the viewer, which stops that OnUpdate.

**Hard rule:** never compare (`== ~= < <= > >=`), do arithmetic on, concatenate, `tostring`, or branch on a
value that may be secret. Only pass it into a widget. `issecretvalue(v)` (exists on these clients; guard
for nil) is the only test allowed on such values. The test stub's `SECRET` throws on `<`, arithmetic and
concat but not on `==`, so check `==` by reading your code.

## Module API (both builders code against exactly this)

New file **`CombatTimers.lua`**: `CDTL3.CombatTimers = CT` (one local table, `local private = {}` style as
the other files). Loaded in **all six TOCs** right after `Probe.lua`, before `EditMode.lua`.

| Call | Returns / does |
|---|---|
| `CT:Available()` | true only when `CDTL3.retailAPI` and `C_Spell.GetSpellCooldownDuration`, `C_Secrets`, `C_CurveUtil`, `C_DurationUtil` exist |
| `CT:Enabled()` | `Available()` and `CDTL3.db.profile.global.combatTimers.enabled` |
| `CT:SetEnabled(on)` | writes the setting; when turned off, every riding icon/bar returns to normal on the next frame and Blizzard's Tracked Bars get their own opacity back |
| `CT:SetHideBlizzardBars(on)` | writes `global.combatTimers.hideBlizzardBars` and applies it |
| `CT:StatusLine()` | one plain line for chat, e.g. `Combat timers: on (experimental) | riding: 2 spells, 1 buff | Cooldown Manager: on | Tracked Bars: Thorns | Blizzard's Tracked Bars: hidden` (or `Combat timers: not available on this client`) |
| `CT:BuffInTrackedBars(name)` | true if a buff of that name is in the player's current Tracked Bars, false if the Cooldown Manager is on but it isn't, nil when unavailable / Cooldown Manager off |

Saved setting, **already added** to the defaults table in `CDTL3.lua` (`defaults.profile.global`):
`combatTimers = { enabled = true, hideBlizzardBars = true }` (on by default in test builds).

**File ownership** (two builders work in the same folder at the same time, so stay inside your list):
- Lane 1: `CombatTimers.lua` (new), `Cooldown.lua`, `Lanes.lua`, all six `.toc` files, `tools/tests/*`.
  Lane 1 does not edit `CDTL3.lua`, `Options.lua` or `CLAUDE.md`.
- Lane 2: `Options.lua`, `CDTL3.lua` (the `ChatCommand` function only), `CLAUDE.md`.
  Lane 2 does not run `runall.sh` (lane 1's files are mid-edit); it checks its own files with a Lua 5.1
  parse (`NODE_PATH=$(npm root -g) node tools/tests/lint.js`, see `tools/tests/README.md`) and by reading.

## Lane 1 (engine): `CombatTimers.lua`, hooks in `Cooldown.lua` / `Lanes.lua`, defaults, TOCs, tests

### Spells and pet spells ("riding")
A cooldown frame `f` (CDTL3.cooldowns entry, `f.data` = `d`) **rides** while all hold: `CT:Enabled()`;
`d.type` is `spells` or `petspells`; no Custom CD Time (`d.setCustomCD and d.customCDTime` → keeps
today's estimate, the user's override wins); not held by an on-aura-fade hold (`d.oafHeld`); the game hides
that spell's cooldown now (`C_Secrets.ShouldSpellCooldownBeSecret(id) == true` in a pcall, falling back to
`ShouldCooldownsBeSecret()`); and a duration object is held for it. Riding starts the frame it becomes true
and ends the frame it stops (combat ends, setting off, spell finished).

- **Estimate stays:** `CooldownUpdate` keeps computing `d.currentCD` (plain number) exactly as today; all
  existing logic (Ready, stacking sorts by `currentCD`, hideTimeSurplus, Dynamic Color) keeps using it.
- **Ready on time:** while riding, read `C_Spell.GetSpellCooldown(id)` (pcall; on `SPELL_UPDATE_COOLDOWN`
  and at most every 0.2 s): `isActive == false`, or `isOnGCD == true`, → set `d.currentCD = 0` (the normal
  path sends it to Ready). If the estimate reaches ≤ 0.1 while `isActive` is still true and not GCD, hold
  `d.currentCD` at 0.1.
- **Charges:** when `C_Spell.GetSpellCharges(id).maxCharges > 1` (never secret; pcall), use
  `C_Spell.GetSpellChargeDuration(id)` for the rider instead of the cooldown duration.
- **Lane icons:** one transparent rider StatusBar per icon, created lazily, parented to the lane frame the
  icon is in (re-anchor if it moves lanes). Geometry copies `private.IconUpdate`'s math
  (`Cooldown.lua` ~1504): rider length = `s.width - s.icons.size`, thickness 1, anchored to the lane at
  the same anchor IconUpdate uses (LEFT; RIGHT when reversed; BOTTOM vertical; TOP vertical reversed);
  orientation HORIZONTAL/VERTICAL; `SetReverseFill(true)` when reversed; fill texture fully transparent.
  Icon: `ClearAllPoints()` then `SetPoint(anchor, rider:GetStatusBarTexture(), opposite, x, y)` where
  opposite is RIGHT/LEFT/TOP/BOTTOM for LEFT/RIGHT/BOTTOM/TOP, offset = `ic.yOffset + ic.sOffset` on the
  cross axis. In `IconUpdate`, a riding icon calls the module instead of its ClearAllPoints/SetPoint block;
  the rest of IconUpdate (valid flags, text, tooltip, strata) runs as now.
- **Rider values per lane mode** (every frame while riding; `T` = duration object, `max` = the mode's max):
  - LINEAR_ABS: `SetMinMaxValues(0, max)`; `SetValue(T:GetRemainingDuration())`.
  - LINEAR: if `d.baseCD > max` → as LINEAR_ABS; else `SetMinMaxValues(0, T:GetTotalDuration())` +
    `SetValue(T:GetRemainingDuration())` (fraction of the real length).
  - SPLIT_ABS: one curve per lane, x = remaining seconds, knots at 0, each active `sNv` (count 1–3), and
    `max`, y = `private.CalcSplitPosition(x, max, s)` (export it or copy the call; it is piecewise linear so
    knots reproduce it exactly); linear curve type set explicitly; `SetMinMaxValues(0, 1)`;
    `SetValue(T:EvaluateRemainingDuration(curve))`.
  - SPLIT: if `d.baseCD > s.mode.split.max` → seconds curve over total = split max (x knots at
    `sNv/100*max`, y = `CalcSplitPosition(x, max, s)`), via `EvaluateRemainingDuration`; else a percent
    curve (check in the API docs whether `EvaluateRemainingPercent` takes 0–1 or 0–100; knots at `sNv`
    scaled to match, y = `CalcSplitPosition(fraction, 1, s)`) via `EvaluateRemainingPercent`. If that
    method is missing, use the seconds curve with total `min(d.baseCD, max)`.
  - Curves are built out of combat and rebuilt when lane settings change (cache by a key of the settings).
- **Bar frames:** in `private.BarUpdate` (`Cooldown.lua` ~941), a riding cooldown's bar gets
  `ba.bar:SetMinMaxValues(0, T:GetTotalDuration())` + `SetValue(T:GetRemainingDuration())` instead of
  `SetValue(iconPercent)`; the SHORTEN transition is skipped while riding. On leaving, restore the bar's
  normal min/max (find what `RefreshBar` sets) before the next `SetValue(iconPercent)`. Confirm by grep that
  nothing reads `ba.bar:GetValue()`.
- **Countdown text:** an icon or bar text whose template is exactly one `[cd.time]` tag (whitespace
  trimmed) gets a duration text binding while riding (lazy, one per FontString; formatting as close to
  `CDTL3:GetReadableTime` as the binding's formatter options allow; read `DurationTextBinding*` docs).
  Disable it on leaving so `private.UpdateText` owns the FontString again. Mixed templates keep the estimate.
- **Leaving:** hide the rider, disable bindings, restore bar min/max, set `f.updateCount = 0` so the next
  poll re-reads the (now readable) cooldown; the normal IconUpdate SetPoint path re-anchors the icon.
- **Stacking:** `private.CalcStacking` GROUPED (`Lanes.lua` ~467–505) compares `GetCenter()`: leave riding
  icons (`ic.ctRiding`) out of the GROUPED sort/compare (they get `stack = 1`, `sOffset = 0`), and if any
  remaining `GetCenter()` read is secret (pcall + `issecretvalue`), skip GROUPED for that pass. OFFSET and
  plain styles sort by `currentCD` and are fine.

### Buffs from the Cooldown Manager's Tracked Bars ("mirror")
- Active when `CT:Enabled()`, `C_CooldownViewer.IsCooldownViewerAvailable()` and CVar
  `cooldownViewerEnabled` is "1", and `BuffBarCooldownViewer` exists. Recheck on login, `CVAR_UPDATE`, and
  out of combat every few seconds until the viewer exists.
- Hooks exactly like `Probe.lua`'s mirror: `hooksecurefunc` on the viewer's `OnAcquireItemFrame` (if the
  method exists) and on every existing item frame's `.Bar` `SetMinMaxValues` / `SetValue`, each bar hooked
  once (hooks can't be removed: they return at once while the module is off). In the hook store, per item,
  the latest `max` and `value` and `GetTime()` of the update. Never read or compare them.
- Item → buff: `item:GetCooldownID()` (pcall; ignore if secret or nil) →
  `C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)` → `spellID` and `linkedSpellIDs` (static) →
  names via `C_Spell.GetSpellName` (cache). CDTL3 frames with `d.type == "buffs"` whose `d.name` matches
  ride from that item. `CT:BuffInTrackedBars(name)` reads the same mapping over the viewer's current
  item frames (`GetItemFrames` if present, else children).
- A buff frame rides while auras are secret (`CDTL3:AurasAreSecret()`), the module is on, and its feed
  updated within the last 0.5 s. Rider values: LINEAR and SPLIT → `SetMinMaxValues(0, feed.max)`;
  LINEAR_ABS → `(0, linearAbs.max)`; SPLIT_ABS → `(0, splitAbs.max)`; then `SetValue(feed.value)`. Split
  lanes therefore show mirrored buffs on a straight line (curves can't take a secret from addon code).
  Bar frames: `ba.bar:SetMinMaxValues(0, feed.max)` + `SetValue(feed.value)`.
- Start and end in combat: a fresh feed for a mapped buff whose frame isn't on a lane (holding/ready)
  starts it with `CDTL3:SendToLane(f)` / `SendToBarFrame(f)` and `d.currentCD = d.baseCD` (estimate, as
  3.0.13's recast restart does); the feed going stale (no update for 0.5 s) while riding ends it
  (`d.currentCD = 0`). A recast restarts the estimate through 3.0.13's `RestartBuffFromCast` as today.
- Text: a `[cd.time]`-only template on a riding buff gets `FontString:SetFormattedText("%.0f", feed.value)`
  each frame; mixed templates keep the estimate.
- **Hide Blizzard's Tracked Bars** (`hideBlizzardBars`, while the module is on): `BuffBarCooldownViewer:SetAlpha(0)`,
  applied out of combat (defer to `PLAYER_REGEN_ENABLED` if `InCombatLockdown()`), and re-applied after
  Edit Mode resets it (post-hook the viewer's `UpdateSystemSettingOpacity` if it exists). Turning it off
  restores Blizzard's own opacity (`viewer:UpdateSystemSettingOpacity()` in a pcall, else `SetAlpha(1)`).
  Never `Hide()` it, never move it, never call Edit Mode or Cooldown Manager setters. This is the only
  write to a Blizzard frame.

### Events
The module uses its own event frame (do not edit `TurnOn`/`TurnOff`): `PLAYER_REGEN_DISABLED/ENABLED`,
`SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_CHARGES`, `CVAR_UPDATE`, `PLAYER_ENTERING_WORLD`. Register only when
`CT:Available()`. Everything runs inside pcalls so a failure can never break CDTL3's normal update path; a
failing frame stops riding (falls back to the estimate) rather than erroring every frame.

### Tests (`tools/tests/`)
- New `combattimers.lua` harness (see `probe.lua` for how to fake the timer APIs on top of `wow.lua`):
  inert where the APIs are missing; split-lane curve knots reproduce `CalcSplitPosition` at many sample
  points for counts 1–3, SPLIT (both branches) and SPLIT_ABS; in combat a cast spell's icon rides (anchored
  to its rider's fill) with no secret arithmetic/compare errors; Ready fires when `isActive` turns false and
  is held while it stays true; Custom CD Time spells don't ride; leaving combat re-anchors the icon to the
  lane; GROUPED stacking with a riding icon doesn't throw; bar frames take the duration and get their
  min/max back; the mirror feeds a mapped buff, starts it in combat, ends it when stale, ignores unmapped
  items; hideBlizzardBars sets alpha 0 and restores; setting off stops all riding.
- Add stubs to `wow.lua` only where needed (keep existing tests green). Add the new runs to `runall.sh`
  (Forever `_Camelot` and `_Mainline` full; Vanilla/TBC/Mists inert).
- Run `bash tools/tests/runall.sh` (needs `tools/spell-list-check/node_modules`; already installed) and
  `NODE_PATH=$(npm root -g) node tools/tests/lint.js` (or how `tools/tests/README.md` says). Every RESULT
  line must show 0 fails and 0 Lua errors; lint clean (only `CDTL3`, `CDTL3DB` global writes).

## Lane 2 (settings and slash): `Options.lua`, `CDTL3.lua` `ChatCommand` only, `CLAUDE.md`
- Global tab: a toggle **"Combat timers (experimental)"** (`global.combatTimers.enabled`, via
  `CT:SetEnabled`) with a short description: "Keeps spell cooldowns moving in combat with the game's own
  timer, and gives buffs in Blizzard's Cooldown Manager Tracked Bars an exact timer. Other buffs keep an
  estimate." Below it **"Hide Blizzard's Tracked Bars"** (`CT:SetHideBlizzardBars`), disabled while the
  first is off, description: "Blizzard's bars must stay on to feed CDTL3; this makes them invisible."
  Show both only when `CT:Available()`. Follow the existing option-table style (find the Global tab in
  `GetMainOptions`).
- Filters, buff entries only: a description line from `CT:BuffInTrackedBars(name)`: true → "Exact in combat:
  this buff is in the Cooldown Manager's Tracked Bars."; false → "Estimated in combat. For an exact timer,
  add it to Tracked Bars in the Cooldown Manager (/cdm)."; nil → hidden.
- Slash in `CDTL3:ChatCommand`: `/cdtl3 combattimers` prints `CT:StatusLine()`; `combattimers on` / `off`
  call `CT:SetEnabled` and print the line. Guard every use with `local CT = CDTL3.CombatTimers` and
  `CT and CT:Available()`; on a client without it print "Combat timers: not available on this client".
- `CLAUDE.md`: a Files entry for `CombatTimers.lua` (branch `combat-timers`, test build) and the slash
  subcommand in the Slash section, in the file's existing style.

## Rules for both lanes
- Edit only the files your lane lists. Don't commit, push, tag, or touch other branches.
- No AI/assistant attribution anywhere (code comments, text, docs).
- In-game and option text: plain English, short.
- Comments: short, plain, only where they help a future reader.
- Stop when your lane's deliverable is done and checked. Report back: files changed, test/lint results
  (the actual RESULT lines summary), and anything you could not do or had to decide, in under 300 words.
