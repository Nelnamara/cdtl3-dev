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
- `lint.js`: Lua 5.1 parse and global-write scan (`node lint.js <addon folder> <files…>`; needs
  `luaparse`).
