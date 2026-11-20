# tests

Regression suite for CDTL3. Not packaged (`.pkgmeta` ignores `tools`).

Each harness loads the real addon files, in TOC order, into a Lua VM (fengari) under
stubbed WoW APIs (`wow.lua`), then drives logins, casts, auras and frames and checks the
result. Nothing here mocks the addon's own code.

## Run

Needs Node 18 or later and the fengari copy in `tools/spell-list-check`:

```
cd tools/spell-list-check && npm install && cd ../..
bash tools/tests/runall.sh                # the repo's working tree
R=/path/to/other/copy bash tools/tests/runall.sh   # another copy of the addon
```

Every line should read `RESULT … total lua errors 0` or `RESULT … fails=0 lua errors=0`.
A failing check prints a `FAIL` line.

One harness by hand: `node tools/tests/run.js <addon folder> <interface> tools/tests/<harness>.lua <toc file> [class]`.

## Files

- `wow.lua`: the stubbed client (frames, events, spells, auras, secret values on
  retail-API clients, time via `Advance(seconds)`).
- `smoke.lua`: loads a whole TOC with the real Ace3 and runs login, casts, frames and every
  options tab.
- `data.lua`: the built-in spell lists the real `GetCharacterData` builds per client.
- `readers.lua`: the cooldown and aura readers, with and without secret values.
- `cooldown3.lua`: cooldown frames, lanes, items and the Filters bulk controls.
- `events.lua`: pet casts, ranked casts, the combat log gate and runes.
- `fixes.lua`: checks for the fixes of each release.
- `combattimers.lua`: CombatTimers.lua with faked timer, curve, text binding and Cooldown Manager APIs
  (`full`), or inert where the APIs are missing.
- `rtengine.lua`: the 12 Nov red team fixes to cooldowns and Ready frames (a switched-off lane keeps its bars,
  an early reset shows in Ready, Highlight Duration, Pinned Hide Time, a switched-off Ready frame, a new item
  while its cooldown is hidden); `combattimers.lua` holds the combat timers ones (held feeds, per-frame garbage).
- `fixes3013.lua`, `release310.lua`: checks for those releases (3.1.0: the welcome notice and the
  combat timers defaults).
- `flights.lua`: Flights.lua under a stubbed taxi client (map slots, hops, `UnitOnTaxi`), against each
  client's real `FlightData` file: estimate, saved time, hold until landing, speed fit, both hide
  settings, resume after a reload or login, early landing, cut-short flights, straight-line fallback,
  off and Forget; then flights off the taxi map (a chat option, a loss of control): the one route from
  the takeoff point (the druids' 63 → 22 where it exists), learning from the landing point, a wrong
  route corrected, names, reload, each side's Nighthaven point, no position.
- `settings.lua`: settings and saved data (red team of 12 Nov 2026): imports keep the Filters lists a
  string leaves empty and refuse a badly shaped string before writing anything (then a set pass over
  every option and a round trip in each mode), Clear Individual Settings and stale Filters selections,
  the Reset Profile / Copy From confirms, built-in spell data copied before it's saved, the unlock box,
  Custom › Add New (Enabled, Trigger ID) and test mode frames.
- `lanes.lua`: lane fixes from the 12 Nov red team: Grouped stacking checked icon by icon against the
  old code (kept in the file as the reference) over 864 layouts, the secondary marker on vertical lanes
  and on a hidden GCD, Secondary Tracking from the options, live lane texts, Hide out of combat by
  frame number, Override Autohide on an empty lane, whole Split Counts, Edit Mode ranges.
- `api.lua`: the public messages (`CDTL3_TimerStarted/Ready/Ended` received by a separate AceEvent listener: fields,
  hidden times nil, Ready still firing, a move is not a start, a failing listener harmless), `CDTL3.API` (copies,
  hidden times, lanes by number and name) and `/cdtl3 help`.
- `show.lua`: show, sound and first steps (feature panel of 12 Nov 2026, cards 1, 7, 11, 12, 16): a
  spell's own Ready sound, Flash when ready, Say its name when ready (with and without text to speech),
  Mute ready sounds and the Play sound buttons; Show per lane, bar frame and ready frame (Always, Only
  in combat, Boss fights only from the encounter events, boss1 or the game's in-progress flag, Dim
  instead of hide) against Hide out of combat, test mode and unlock; Preview with sample icons and
  the minimap Shift-click; the unlock box's move-then-lock wording until the first lock; the first
  counted flight's one chat line.
- `filtercards.lua`: the Filters cards of the 12 Nov feature panel: each entry's reason line and Show
  anyway, the once-only auto-ignore note, Hide spells I don't know, Only for this spec (MoP and Retail),
  My spells and Show only the ticked spells, Pull from Cooldown Manager (Retail and Forever, with just
  enough of the Cooldown Manager faked).
- `share.lua`: sharing and media (feature panel of 12 Nov 2026, cards 34 and 40): `!CDTL3:2!` exports
  naming the client and CDTL3 version, a round trip of every export kind and of each lane's Copy this
  lane string, older strings importing exactly as before, the import preview (counts, Cancel, a string
  from another client, spells this client doesn't have), Into a new profile, refused strings, imported
  Filters entries listed for the importing character on a shared Default profile, the "(missing)" note
  on every font / bar texture / sound dropdown with CDTL3's media fallbacks, CDTL3's own media in
  LibSharedMedia, and Masque groups per timer type (a stub Masque).
- `diag.lua`: diagnostics and performance (feature panel cards 35, 36, 38): Diagnostics.lua in every TOC, the
  failure log fed by each hidden-value read (counts, repeats on one line, the last 200 kept, nothing printed or
  hidden), `/cdtl3 log` and `/cdtl3 report` (each part, no hidden value or GUID, a broken part), the Update rate
  (Full slides every frame where the formula says; 30 and 15 a second slide, fill and redo texts less often)
  with Ready and its sound on the same frame at every rate, Pause while hidden, and `/cdtl3 perf`. `show` as the
  last argument prints a sample report. `combattimers.lua` checks a riding icon at 15 a second.
- `anchors.lua`: Anchor to (feature panel card 21): Screen placed as before, the player frame, the Cooldown
  Manager and a frame by name with side and offsets, the other frame only read (a recording proxy), a missing
  frame waiting then anchoring (timer, ADDON_LOADED), unusable frames falling back, unlock-and-drag and Edit Mode
  setting the offset with screen and layout positions kept, the options, Copy Settings, a profile switch.
- `profiles.lua`: Profiles tab extras (card 39): the profile a new character starts on, shared Filters entries
  (round trips, other profiles joining and getting them back, Copy From, Reset Profile and imports while shared, a
  logout saving each table once, a reload), profiles by zone and with spec profiles, a deleted profile.
- `slots.lua`: `CDTL3:SlotSettings` / `CDTL3:SlotFrame` give lane, bar frame and Ready frame 1 to 3, and nil for
  anything else (0, 4, nil, the string "1"); `SlotOfParent` / `SlotParent`, and where every timer goes for
  every slot number (frame made, not made, switched off).
- The 17 Nov 2026 copied-code cleanup added three tests and two diff tools. Each shared piece is checked
  against what the copies did:
  - `cdparts.lua`: Cooldown.lua's unlock box, icon and bar texts 1 to 3, the split-lane stretches (against
    the old blocks, kept in the test as the reference) and the spell countdown. With `dump` it prints
    every frame call (DUMP lines) to diff two copies of the addon.
  - `dedupe.lua`: the Paladin lockouts, IconFx Ring / RingShow (also Group.lua's Burst strip) and the
    debug and unlock boxes' panel.
  - `framedump.lua`: every object under the lanes, bar frames and ready frames after creation, refreshes,
    stacking in every direction and the lane texts in every mode, as DUMP lines.
  - `defaultsdump.lua` (every default setting) and `optionsdump.lua` (the whole options tree, every
    setter's effect, the saved settings) are diff tools, not tests: dump the old and the new code and
    diff. How to run each is in its header.
- The `/cdtl3 probe` test build and its `probe.lua` harness live on branch `cdm-probe`.
- `lint.js`: Lua 5.1 parse and global-write scan (`node lint.js <addon folder> <files…>`; needs
  `luaparse`).
