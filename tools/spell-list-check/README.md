# spell-list-check

Checks the built-in spell lists in `Data.lua` against each client's game data, so they can
be re-verified after every patch. Not packaged (`.pkgmeta` ignores `tools`).

For each client in `builds.json` it:

1. loads the addon's real `Data.lua` and `Helpers.lua` in a Lua VM (fengari) with that
   client's interface number and runs the real `CDTL3:GetCharacterData()` for every class
   the client has. It checks exactly what the addon loads in game, version gates and the
   WoW: Forever changes included. (A harness that fills the lists by hand missed the 3.0.10
   bug; keep running the real code.)
2. downloads the build's DB2 tables from wago.tools into `cache/<build>/` (git-ignored,
   downloaded once per build).
3. prints, per client:
   - **missing IDs**: listed spell IDs the game does not have;
   - **name mismatches**: list `name` differs from `SpellName.Name_lang` (the addon also
     looks spells up by English name);
   - **bCD mismatches**: list `bCD` differs from max(`RecoveryTime`, `CategoryRecoveryTime`)
     in `SpellCooldowns` (difficulty 0), in milliseconds;
   - **oaf mismatches**: list `oaf` differs from bit `0x02000000` of
     `SpellMisc.Attributes_0`, the "cooldown starts when the effect ends" flag;
   - **on-event spells not listed**: class, pet and racial spells (skill lines, talents,
     specialization spells, PvP talents) that carry that bit, are not passive and have a
     cooldown over 3 s, but are not in that class's list with `oaf = true`.

Exit code: 0 when everything matches, 1 when anything is reported, 2 on an error.

## Run

Needs Node 18 or later.

```
cd tools/spell-list-check
npm install
node check.js                  # every client
node check.js forever mop      # only these clients (keys from builds.json)
node check.js --src <folder>   # check another copy of the addon
node check.js --refresh        # download the tables again
```

## After a patch

1. Set the client's `interface` and `build` in `builds.json`. The build is the full
   version string wago.tools uses, e.g. `1.60.1.70707` (see https://wago.tools/builds).
2. Run `node check.js <client>`.
3. Fix what it reports in `Data.lua`:
   - Classic Era and TBC: the entries in the `tocversion < 20000` / `< 30000` branches.
   - WoW: Forever loads the Classic lists, which stay Era's. Its differences go in
     `private.foreverChanges` (drop, rename, cooldown, `oaf = false`) and its own spells in
     `private.GetForeverData`.
   - MoP Classic and retail list only the spells whose cooldown starts on an event, in the
     `tocversion < 60000` and retail branches. Do not import whole class lists there.

## Notes

- The bit has held as the signal on all five builds. A spell that was redesigned loses it
  (Forever's Elemental Mastery, MoP and retail Shadowmeld), and the list must follow the
  game.
- Era, TBC and Forever have no Death Knights, so `builds.json` checks that class only
  from MoP up.
- Racials are not filtered by race in the addon; the tool checks each one once.
- A spell with the bit but a cooldown of 3 s or less is not reported as missing, because the
  addon ignores such cooldowns by default. Retail Stealth (2 s) is listed anyway, with its
  real cooldown.
