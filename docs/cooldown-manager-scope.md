# Scope: the Cooldown Manager and exact timers in combat

Status: **scoped 2026-11-09; probe run 1 done on Forever (see Probe results at the end).** Builds on `secret-timers-scope.md` (2026-10-07)
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

So far: exact spell cooldowns in combat look buildable (Phase 1), pending the owner's eyes on rows A–D.
Buffs in combat can come only from copying the Cooldown Manager, and only for buffs the player has
put in Tracked Bars; 3.0.13's recast estimate stays the fallback for everything else. If the bar
copy fails or Tracked Bars prove too awkward, a second probe could hook the Tracked Buff icons'
`CooldownFrame_Set` (BuffIcon items, `CooldownViewer.lua` around line 1425), which show by default.
