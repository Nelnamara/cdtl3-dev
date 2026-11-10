# Scope: the Cooldown Manager and exact timers in combat

Status: **two probe runs done on Forever; combat timers test build 1 built 2026-11-09 on branch
`combat-timers` (spec and as-built notes in `combat-timers-spec.md`), waiting for the owner's walk.** Builds on `secret-timers-scope.md` (2026-10-07)
and its Phase 1 plan (2026-10-25, branch `secret-timers`), neither of which was run in game.
Sources: Blizzard's UI source and generated API docs (Gethe/wow-ui-source `live` = Retail 12.1.5
build 70783, `forever` = 1.60.1 build 70862) and the code of addons that already use the
Cooldown Manager. Everything marked *probe* is inferred from source and must be proven in game.

## Today, in combat on Forever and Retail

| What | CDTL3 today |
|---|---|
| Spell cooldowns | Estimated: own cast time + base cooldown (talents and haste missed; Custom CD Time patches it per spell) |
| Charges | Not tracked while hidden |
| Buffs | Frozen until combat ends; 3.0.13 restarts your own recasts as an estimate |
| Items | Frozen until readable |

## What the research found

1. **The Cooldown Manager has no timer API for addons.** It is Blizzard's own untainted code
   reading the same hidden values we can't (`C_Spell.GetSpellCooldown`, `C_UnitAuras.GetUnitAuras`)
   and drawing them with `Cooldown:SetCooldown` and `StatusBar:SetValue`. Its `C_CooldownViewer`
   API only gives **static** information, never secret: the tracked cooldown IDs per category, and
   for each one its spell ID, linked buff spell IDs, `hasAura`, `selfAura`, `charges`, `isKnown`.
   Forever's copy is the same code as Retail's (Forever adds item-category cooldowns).
2. **Exact spell cooldowns don't need the Cooldown Manager.** `C_Spell.GetSpellCooldownDuration`
   and `GetSpellChargeDuration` work from addon code in combat and return timer objects that carry
   the real (talented) duration. `isActive`, `isOnGCD` and `maxCharges` are never hidden. This is
   October's Phase 1 plan.
3. **Hidden values can only be piped, never read.** They go into a StatusBar's fill
   (`SetTimerDuration`, `SetValue`), a cooldown swipe (`SetCooldownFromDurationObject`, which the
   docs mark protected: *probe*) or countdown text (`C_DurationUtil.CreateDurationTextBinding`).
   `SetPoint` and `SetWidth` refuse them, so a sliding icon must be anchored to a bar's fill edge.
   oUF's castbar spark rides a fill driven by `SetTimerDuration`; no addon has done it with hidden
   cooldowns yet (*probe*).
4. **Buffs are the hard part, with two possible routes:**
   - **Cached aura IDs** (*probe*): `C_UnitAuras.GetAuraDuration(unit, auraInstanceID)` returns
     a timer object. Instance IDs are hidden in combat, but a buff you had before the pull keeps
     the ID we saw while it was readable, and our own copy of that number isn't hidden. If the
     call accepts it in combat, refreshes of those buffs become exact, with no Cooldown Manager.
   - **Mirror the Cooldown Manager's buff bars**: ForeverAuras (a WeakAuras fork for Forever)
     post-hooks the Tracked Bars' `SetMinMaxValues` / `SetValue` and copies the hidden values
     into its own bars. Works only for buffs the player tracks in the Cooldown Manager's Tracked
     Bars, with the Cooldown Manager switched on (its frames can be faded out).
5. **Forever's Cooldown Manager is off by default** (Options → Gameplay Enhancements; `/cdm`).
   Beta reports said many classes had few spells in it: *probe* on live Forever.
6. **Taint:** other addons broke Blizzard's Cooldown Manager by writing to its frames, moving
   them in combat, or calling Edit Mode setters (QUI issue #263). Post-hooks on item instances
   are safe. CDTL3 would only listen: never move, write to or reconfigure Blizzard's frames.

## What CDTL3 could do

| Item | How | Exact | Needs the Cooldown Manager on |
|---|---|---|---|
| Spell icons slide and bars drain in combat | Rider StatusBar per icon fed by `GetSpellCooldownDuration` (Oct plan) | Yes, talents included | No |
| Charges recharge in combat | `GetSpellChargeDuration` | Yes | No |
| Ready fires on time | `isActive` (never hidden) | Yes | No |
| Countdown text and swipes in combat | Duration text binding; `SetCooldownFromDurationObject` | Yes | No |
| Buffs you had before the pull | Cached instance ID → `GetAuraDuration` | If the probe passes | No |
| Buffs gained in combat | Mirror Tracked Bars | Yes, for buffs tracked there | Yes |
| Import the Cooldown Manager's tracked list into Filters | `C_CooldownViewer` (static) | n/a | No |
| Item cooldowns | No API for items | No | n/a |
| Stacking, sorting by time, number tags | Need maths on hidden values | No | n/a |

## Probe build (one session on a target dummy, Forever first, then Retail)

A read-only `/cdtl3 probe` that changes no settings or tracking and prints a report:

1. **Riding:** an icon on a bar fed a hidden timer moves (October's `/cdtl3 secrettest` rows A–D:
   linear, own-length, split-lane curve, text and swipe).
2. **Spell timer objects:** does `GetSpellCooldownDuration` carry the talented length, and does
   it update live or need re-fetching on `SPELL_UPDATE_COOLDOWN`?
3. **Charges:** `GetSpellChargeDuration` in combat.
4. **Cached aura IDs:** `GetAuraDuration` with an ID cached before the pull, in combat, before
   and after a recast.
5. **Cooldown Manager on Forever:** is it available and on, how many cooldowns and buffs it lists
   per category for the class, which ones.
6. **Mirror:** post-hooks on the Tracked Bars feed a probe bar; no Blizzard Lua errors afterwards.
7. **Swipe:** `SetCooldownFromDurationObject` from addon code in combat.

## After the probe

Each row above becomes go or no-go. Rows 1–3 passing means October's Phase 1 (exact spell icons and
bars in combat) can be built, in its own test build for the Mac. Buffs follow by whichever of rows
4 or 6 passes. Nothing ships without its own test build and the owner's go.

## Probe results

**Run 1, 2026-11-09:** Forever 1.60.1.70862, level 14 Druid in caster form, outdoor mob, about 13 s
in combat. Test spell Nature's Grasp (60 s), buff Thorns. Report:
`docs/probe-results/2026-11-09-forever-druid.txt`. The owner's notes on what the panel showed are
still to come.

| Row | Result |
|---|---|
| 1 Riding | Every call OK in combat (974 frames, 0 errors). Whether the icons visibly moved is the owner's call. Icon positions read back as hidden in combat, and they **stay hidden after combat** (ooc: readable x5 before the pull, hidden x16 after), so Phase 1 can't read its own icon positions once a bar has been fed a hidden value. |
| 2 Spell timer | **Go.** An object every time in combat; `isActive` / `isOnGCD` readable throughout. Talented length not provable here (nothing changes Nature's Grasp at 14; out of combat total = base 60 s). A new object comes back on each fetch, so re-fetch on `SPELL_UPDATE_COOLDOWN` (12 in combat, all objects). |
| 3 Charges | Not testable on this character; Retail. |
| 4 Cached aura IDs | **No-go.** `GetAuraDuration` and `GetAuraDataByAuraInstanceID` fail on every call in combat: "Auras cannot be accessed when secret while tainted". Addon code gets no buff timers in combat by any ID. |
| 5 Cooldown Manager | Available and on. For this Druid: Essential 2, Utility 4, Tracked Buffs 11; **Tracked Bars 0 by default** (0 even counting unlearned). |
| 6 Mirror | Not tested: nothing was in Tracked Bars, so Blizzard drew no bar. Forever's `CooldownViewerBuffBarItemMixin:RefreshCooldownInfo` drives the bar with `SetMinMaxValues(0, duration)` + `SetValue(remaining)` from OnUpdate while active, which is what the probe hooks. Re-run with a buff moved into Tracked Bars. No blocked / forbidden actions. |
| 7 Swipe | **Go.** `SetCooldownFromDurationObject` OK in combat from addon code (18 calls), nothing blocked. |

**Run 2, 2026-11-09:** same character, two fights, about 32 s in combat, with Thorns moved into
Tracked Bars. Report: `docs/probe-results/2026-11-09-forever-druid-run2.txt`.

| Row | Result |
|---|---|
| 1, 2, 7 | Same as run 1 with more data: 2313 frames in combat, 49 cooldown refreshes and 49 swipes, 0 errors. |
| 4 | Same no-go (21 of 21 failed in combat). Also: the cached Thorns ID went dead (`nil` x22) after a recast, so a recast gives a buff a new instance ID. |
| 6 Mirror | **Go.** Blizzard drove the Thorns bar 1683 times in combat (SetMinMaxValues + SetValue every frame) and the copy into row F succeeded on all 1683, 0 failed, no blocked / forbidden actions. |

So far: exact spell cooldowns in combat look buildable (Phase 1), and exact buff timers in combat work
for buffs the player puts in the Cooldown Manager's Tracked Bars (Cooldown Manager on). Both pending
the owner's eyes on whether rows A–D and F visibly moved. 3.0.13's recast estimate stays the fallback
for buffs not in Tracked Bars. Open for a later probe: whether Blizzard's bars still feed the copy
when faded out (the viewer's OnUpdate stops if its frame is hidden, so hiding is not an option;
fading may be), and the Tracked Buff icons' `CooldownFrame_Set` (BuffIcon items, `CooldownViewer.lua`
around line 1425) as a source that needs no move into Tracked Bars.

## Experimental build: combat timers (scope 2026-11-09)

Builds on October's Phase 1 scope (`secret-timers-scope.md`, decided 2026-10-25) with what the two
probe runs settled. One test build, branch `combat-timers` cut from `cdm-probe`, walked on Forever
first (the owner's Druid), then Retail for charges.

| Item | How | Settled by |
|---|---|---|
| Spell and pet cooldown icons move on lanes in combat | A transparent rider StatusBar per icon; the icon anchors to its fill edge. LINEAR_ABS / LINEAR: `SetMinMaxValues` + `SetValue(dur:GetRemainingDuration())`. SPLIT / SPLIT_ABS: a curve per lane with knots sampled from `private.CalcSplitPosition` (`Cooldown.lua`), fed through `EvaluateRemainingDuration` | probe rows A–C |
| Bar frames drain | `SetTimerDuration(dur, Immediate, RemainingTime)` | row B |
| Countdown text | Duration text binding where the template is a single time tag; mixed templates keep the estimate | row D |
| Swipes | `SetCooldownFromDurationObject` | section 7 |
| Ready on time | `isActive` (never hidden) | section 2 |
| Real cooldown length | The timer object is the game's own cooldown. Spells with Custom CD Time keep today's estimate (the user's override wins) | Oct decision |
| Re-fetch | A new object comes back on each fetch: re-fetch on `SPELL_UPDATE_COOLDOWN` / `SPELL_UPDATE_CHARGES` | section 2 |
| Charges | `GetSpellChargeDuration` | not proven yet: Retail walk |
| Exact buffs in combat | Post-hooks on each `BuffBarCooldownViewer` item's `.Bar` `SetMinMaxValues` / `SetValue` (the probe's mirror). Item cooldownID → spellID and linkedSpellIDs (static, never hidden) → CDTL3's buff entries; the copied values drive that buff's rider bar or bar frame | section 6 |
| Buff start and end in combat | Check in the build: a post-hook on the item's `OnActiveStateChanged` / `SetIsActive` and whether `IsActive()` / `IsShown()` read back. Fallback: 3.0.13's cast restart and UNIT_AURA timing | open |
| Other buffs | 3.0.13's recast estimate, text dimmed while it is an estimate | Oct decision |
| Blizzard's Tracked Bars on screen | Forever's Edit Mode fades them to 50% at most (`EditModeSettingDisplayInfo.lua`, Opacity min 50), and "Hidden" hides the viewer, which stops the OnUpdate that feeds the copy. Option "Hide Blizzard's Tracked Bars" sets the viewer's alpha to 0, out of combat only; on by default in the test build. It is the one write to a Blizzard frame: the walk checks for Blizzard errors and blocked actions, and it goes if there are any | source |
| Setup hint | Each buff's options say whether it is in Tracked Bars (exact in combat) or not ("add it in /cdm") | — |
| Off switch | Global tab "Combat timers (experimental)" and `/cdtl3 combattimers on` / `off`; on by default only in test builds. Feature-detected (`C_DurationUtil`, `C_Spell.GetSpellCooldownDuration`), so Classic clients are untouched | Oct decision |
| Diagnostics | `/cdtl3 probe` stays; a "combat timers" line in `/cdtl3 debug` | — |
| Limits in combat | GROUPED stacking and position saving skip riding icons, so they may overlap until combat ends. Icon positions stay hidden while anchored to a rider (probe), so icons re-anchor to their normal points on leaving combat; check that positions read back after that. hideTimeSurplus icons pin at the far end | probe row 1, Oct |
| Not doing | Item cooldowns (no API); number tags and sorting by time in combat (need maths on hidden values) | Oct |

## Test build 1: the owner's walk (2026-11-09, Forever, level 14 Druid)

Walk `2026-11-09-combat-timers` on the CDTL3 Walk Sheet: **14 of 15 pass.**

- Pass in combat: Nature's Grasp's icon slides for the whole cooldown; its countdown text counts
  (it reads "59sec"); Ready lands when the spell lights up on the action bar; Thorns' icon (Tracked
  Bars) keeps sliding and jumps back on a recast; `/cdtl3 combattimers` shows riding with no errors.
- Pass around it: the status line, both Global toggles, the Filters hint, Blizzard's Tracked Bars
  hidden and back with `combattimers off`, no jump on leaving combat, no Lua errors or blocked actions.
- Fail, line 12 (bar frame): "Nature's Grasp does not work in a bar but other spells do." Not the
  build: bar frames default to "Transition bars" (`transition.hideTransitioned`), which hides a bar
  once the cooldown is under the lane's Max Time (`BarUpdate`, `CalcTransitionIndicator`), and
  Nature's Grasp's 60 s never exceeds the default 120 s. So a bar draining from the game's timer is
  **still unproven in game**; retest line `2026-11-10-bar-frame-retest-01` is on the sheet.

Still open after this walk:
- Countdown text format: the seconds formatter's short-unit setting didn't take ("59sec"); look for a
  format that matches CDTL3's ("59", "1:33") through the binding's `SetTextFormat`.
- In the scope but not in build 1: dimmed text on estimated buffs. (Swipes: CDTL3's icons have no
  swipe to drive, so there was nothing to build.)
- Charges, and the whole walk, on Retail.
- Blizzard's Tracked Bars stay invisible in Edit Mode while hidden.

## Test build 2: the owner's walk (2026-11-10, Forever, same Druid)

Walk `2026-11-10-combat-timers-2`: **all 10 checks pass**, and the bar-frame retest from build 1 passes
(a bar frame's bar drains from the game's timer in combat). Spec and as-built notes:
`combat-timers-build2-spec.md`.

- Proven in game by this walk: a spell's countdown text in combat reads like CDTL3's normal text;
  a Tracked Bars buff on a Split (Time) lane keeps its place when combat starts and ends (the chain of
  segment bars works, an empty fill included); estimated buffs dim in combat and come back after;
  the sliders reach 3600 / 7200 and show the saved value; "Long buffs scale"; unticking Ignored shows
  an active buff at once. No Lua errors, no blocked actions, no module errors.
- His call on the Tracked Bars buff text ("542" exact seconds, or CDTL3's "9:02" from the estimate):
  **Change.** Build 3 (same day): `CT:OwnsText` leaves buffs alone, so their text is CDTL3's own; the
  icon and bar stay exact.
- He didn't note which text formatter was picked (line 7 asked); it passed as CDTL3's style.

Still open: charges and the whole walk on Retail; Blizzard's Tracked Bars invisible in Edit Mode while
hidden; 35 other sliders with soft limits; how this ships (version, and whether it is on by default).

**After the build 2 walk (same evening):** "none of the bar frames seem to be working now with
transition checked or unchecked; lanes and ready frames are fine". Traced in `private.BarUpdate`
(`Cooldown.lua`): a bar's `valid` flag was set back to true only while "Transition bars" was on and
the cooldown was above the lane's Max Time, so a bar the option had hidden stayed hidden after
unticking it (until a /reload), and so did the bar of an entry that was ignored and un-ignored. The
walk had raised his lanes' Max Time to 3600, which puts every cooldown under the transition point.
An old bug, not from the combat timers code. Fixed in build 3: with the option off (or no lane) a
hidden bar of an enabled, not-ignored cooldown is shown again. With the option on and a lane Max Time
of 3600, bars for anything shorter than an hour still hide: that is what the option does.
