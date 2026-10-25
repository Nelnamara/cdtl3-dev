# Scope: keeping timers moving while values are secret (Midnight 12.x / WoW: Forever)

Status: **scoped, not started.** Written 2026-10-07 against the Blizzard API docs for
Retail 12.1.0 (build 69933) and WoW: Forever 1.60.1 (build 70245). Items marked
*unverified* must be proven in-game before anything is built on them.

## The problem today

In combat (and encounters, M+, PvP) the game hides cooldown timings, aura data, unit
power and item cooldowns from addons as "secret values". CDTL3 copes by falling back:

| What | Today, while secret |
|---|---|
| Spell cooldowns | Own cast-time tracking + base cooldown (talent reductions are missed; Custom CD Time fixes per spell) |
| Charges | Fall back to 0 charges |
| Item cooldowns | Not refreshed until the value is readable again |
| Buffs / debuffs on you | Lost: `AuraExists` returns "unknown" and the icon holds its last state |
| Text tags (`[p.hp]` …) | Show `?` |

## What Blizzard now provides

Addons may *pipe* secret values into certain widgets but never read them back. The pieces
that matter (all present on Retail **and** Forever):

- **Duration objects**: `C_Spell.GetSpellCooldownDuration(spell, ignoreGCD)` and
  `C_Spell.GetSpellChargeDuration(spell)` return a duration that holds the real (secret)
  cooldown, callable from addon code. `SpellCooldownInfo.isActive` / `isOnGCD` are never
  secret, so "is it on cooldown" is always known.
- **Widgets that accept them**:
  - `StatusBar:SetTimerDuration(dur, interpolation, RemainingTime)` animates a bar natively.
  - `StatusBar:SetValue(secret)` works too.
  - `Cooldown:SetCooldownFromDurationObject(dur)` draws icon swipes.
  - `C_DurationUtil.CreateDurationTextBinding()` keeps a FontString counting down by itself.
- **Curves**: `C_CurveUtil.CreateCurve()` maps the secret remaining time through a
  piecewise function natively. That covers CDTL3's split lanes and colour ramps.
- **Whitelists**: `C_Secrets.GetSpellCooldownSecrecy(spell)` and
  `GetSpellAuraSecrecy(spell)` report `NeverSecret`, `AlwaysSecret` or
  `ContextuallySecret` per spell.

The hard limit: `SetPoint`, `SetWidth` and `Cooldown:SetCooldown` refuse secrets from
addons. **The only way to turn a secret time into a position on screen is a StatusBar's
fill.** So a moving icon has to *ride* a transparent StatusBar by being anchored to the edge
of its fill texture.

## Feasibility

| Feature | Verdict | How |
|---|---|---|
| Linear lane icons (spells) | **Feasible** *(depends on test 1)* | Transparent StatusBar per icon across the lane; icon anchored to the fill edge; `SetValue(dur:GetRemainingDuration())` (fixed-scale) or `SetTimerDuration` (fraction-of-own-CD) |
| Split lanes | **Feasible** *(test 2)* | One curve per lane from the split points; `SetValue(dur:EvaluateRemainingDuration(curve))` |
| Countdown text on icons/bars | **Feasible** | Duration text binding + Blizzard seconds formatter; custom mm:ss arithmetic is not possible |
| Bar frames | **Feasible** | `SetTimerDuration` / `SetValue`; spark rides the fill edge; Dynamic Color via a colour curve *(unverified)* |
| Icon swipes | **Feasible** | `SetCooldownFromDurationObject` |
| Talented cooldown lengths | **Likely fixed for free** | The duration carries the server's real cooldown, so the base-CD problem may vanish in combat. Custom CD Time can't be applied to a secret duration (decide: native wins in combat) |
| Charges | **Feasible** | `GetSpellChargeDuration` |
| Item cooldowns | **Not possible** | No duration API for items; keep current behaviour |
| Buffs, Blizzard-whitelisted | **Feasible** | Spell-ID lookups still work for `NeverSecret` auras; check the secrecy once per spell |
| Buffs, everything else | **Not possible exactly** | Aura lists, instance IDs and payloads are all secret. Two fallbacks below |
| Buffs, estimated | Feasible | Own cast seen → non-secret duration from the last readable length. Misses haste, pandemic, extensions, early removal |
| Buffs, exact but display-only | Possible, fragile | Blizzard's `CustomAuraContainerTemplate` can drive *our* bar/text/swipe with the real duration, but only inside its slot frame, locked in combat, fraction-of-duration only. Not mixable with lane icons |

## Side effects to design around

- **Icons that ride a bar have secret positions.** Anything that reads icon positions
  would throw while an icon rides; those code paths must skip riding icons or be guarded
  with `issecretvalue`:
  - GROUPED stacking sorts and compares `GetCenter()` (`Lanes.lua` ~467–505);
  - position saving reads `GetPoint` (`Lanes.lua` ~980, `BarFrames.lua` ~349).

  Overlap stacking would be off in combat.
- **Secret flags stick to widgets** until `SetToDefaults()`. Use separate widgets for the
  secret path rather than reusing the normal ones.
- Duration objects may be snapshots: re-fetch on `SPELL_UPDATE_COOLDOWN` /
  `SPELL_UPDATE_CHARGES`.

## Proposed phases

**Phase 0: spike (about 1 session, needs the user in-game).** A hidden `/cdtl3 secrettest`
that, in combat on a dummy, puts one icon on a transparent StatusBar driven by
`GetSpellCooldownDuration` for a chosen spell, and prints `issecretvalue` checks. It answers:

1. Does an icon anchored to the fill edge move when tainted code sets a secret value?
2. Does a scalar curve result feed `SetValue`?
3. Are duration objects snapshots or live?
4. What does the duration report for a talent-reduced cooldown?

Go or no-go for everything below.

**Phase 1: spells on lanes and bars in combat (2–3 sessions).**
- A "secret mode" icon renderer: riding StatusBar per icon; linear, linear-abs and split
  via curves; text bindings; swipes.
- Cooldown.lua chooses it per icon when `C_Secrets.ShouldSpellCooldownBeSecret(id)` is true,
  and returns to the normal path out of combat.
- Stacking is disabled for riding icons.
- Feature-detected (`C_DurationUtil and C_Spell.GetSpellCooldownDuration`), so Classic
  clients are untouched.

**Phase 2: buffs (1–2 sessions).**
- Whitelisted (`NeverSecret`) buffs tracked exactly via spell-ID lookups.
- Others: estimated timers from the player's own cast, marked visibly as estimates (e.g.
  dimmed text).

**Phase 3, optional: exact buff bars.** An "Exact buff bars" frame type built on Blizzard's
AuraContainer. Separate from lanes, linear only, configured out of combat. Only worth it if
users ask after phase 2; the API changed a lot during the 12.1 PTR.

## Recommendation

Run phase 0 first: everything hinges on icons riding a secret-driven StatusBar, which the
docs imply but nobody has confirmed for addon code. If it works, phase 1 is the big win:
spell icons and bars move in combat with the real (talented) cooldown, which also solves the
"Midnight shows base cooldowns" problem. Buffs stay best-effort except Blizzard's
whitelist, and the UI should be honest about that.

Research notes with file/line citations into Blizzard's generated API docs were produced
for this scope (`Blizzard_APIDocumentationGenerated/*` in Gethe/wow-ui-source, `live` and
`forever` branches).

## Phase 1 scope (decided 2026-10-25)

Everything here applies only when the client hides cooldowns (`C_Secrets.ShouldSpellCooldownBeSecret`) and the client has the duration APIs (Retail, Forever). Out of restricted content, and on Classic clients, the current code path is untouched.

| Build | Item | How |
|---|---|---|
| **Test build 1** | Spell + pet cooldown icons keep moving on lanes | A transparent "rider" StatusBar per icon along the lane; the icon is anchored to its fill edge instead of a computed offset |
| Test build 1 | All four lane modes | LINEAR_ABS: `SetMinMaxValues(0, max)` + `SetValue(dur:GetRemainingDuration())`. LINEAR: the same, with total = min(base CD, max) from CDTL3's own non-secret base CD. SPLIT / SPLIT_ABS: a curve per lane whose knots are the split points, sampled from `CalcSplitPosition` so it reproduces today's mapping exactly; fed through `EvaluateRemainingDuration` / `EvaluateRemainingPercent` |
| Test build 1 | Bar-frame bars drain in combat | `SetTimerDuration(dur, Immediate, RemainingTime)` on the bar; needs no icon riding, so it works even if riding fails |
| Test build 1 | Charges | `C_Spell.GetSpellChargeDuration` instead of the cooldown duration when the spell has charges |
| Test build 1 | Ready on time | `SpellCooldownInfo.isActive` is never secret: icon goes to Ready when it turns false, not on the estimate |
| Test build 1 | Diagnostics | `/cdtl3 secrettest` panel and report, plus a "combat timers" line in `/cdtl3 debug` |
| Test build 2 | Countdown text in combat | Duration text binding on icon/bar texts whose template is a single time tag; mixed templates keep today's estimate |
| Test build 2 | Swipe on icons | `Cooldown:SetCooldownFromDurationObject` |
| Test build 2 | Exact whitelisted buffs | `C_Secrets.GetSpellAuraSecrecy(id) == NeverSecret` → `C_UnitAuras.GetPlayerAuraBySpellID` keeps working; check once per spell |
| Test build 2 | Estimated other buffs, marked | Own-cast estimate with dimmed text so it's visibly an estimate |
| Not doing | Item cooldowns | No duration API for items |
| Not doing | Exact non-whitelisted buffs | Aura list, IDs and payload are secret; AuraContainer is display-only, linear-only and locked in combat |
| Not doing | Number tags, stacking, sorting by time | Need maths/comparisons on hidden values |

Decisions:
- **Custom CD Time vs the game's duration in combat**: a spell with Custom CD Time set keeps today's estimate path (the user's override wins, as everywhere else); all others use the game's duration, which already carries talent reductions.
- **hideTimeSurplus** (hide while remaining > lane max) can't be tested in combat; riding icons are pinned at the far end instead (the bar clamps). Revisit with a step curve driving alpha if test build 1 shows `SetAlpha` takes a curve result.
- **Stacking**: icons in riding mode are skipped by GROUPED stacking (`Lanes.lua` `GetCenter()` comparisons) and by position saving; they may overlap until combat ends.
- **Off switch**: Global tab → "Combat timers (experimental)" plus `/cdtl3 combattimers on|off`; on by default only in test builds.

## Test build 1 plan

Branch `secret-timers`. One build answers the spike questions and tries the real thing, so it needs one in-game session, not two.

1. **New `SecretTimers.lua`** (loaded after Cooldown.lua, all TOCs, feature-detected): restriction tracking (`PLAYER_REGEN_*`, `ENCOUNTER_START/END`, `ADDON_RESTRICTION_STATE_CHANGED`), a per-spell duration cache refreshed on cast and `SPELL_UPDATE_COOLDOWN`, the rider bars, the per-lane curves, and enter/leave transitions (leaving restores normal positioning on the next frame, so there's no jump).
2. **Hooks into existing code** (small, guarded): `private.IconUpdate` asks SecretTimers whether an icon is riding and skips its `SetPoint` if so; `private.BarUpdate` likewise for bars; Lanes.lua stacking and position-saving skip riding icons; Ready transition reads `isActive` while riding.
3. **Harness tests** before the build: curve knots reproduce `CalcSplitPosition` for every split setting; riding switches on/off with the restriction state; no maths on (stubbed) secret values anywhere in the path.
4. **In-game test (Retail first, then Forever)**, target dummy, one lane per mode:
   - Out of combat: nothing changes from 3.0.10.
   - In combat: icons slide, bars drain, charges recharge, Ready fires when the spell is actually ready, no Lua errors.
   - Leaving combat: icons don't jump.
   - A talent-reduced cooldown shows its real length in combat.
   - `/cdtl3 secrettest report` and `/cdtl3 debug` output pasted back.
5. **Go / no-go**: if icons don't ride (spike Q1), keep bars + Ready-on-time + charges and drop lane riding; if curve results don't feed `SetValue` (Q2), split lanes fall back to linear while restricted.
