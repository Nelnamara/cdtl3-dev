# luals-check

The WoW API code check that addon reviewers run: Ketho's
[WoW API](https://github.com/Ketho/vscode-wow-api) definitions loaded into the Lua language
server (LuaLS), run from the command line with the settings the VS Code extension applies.
Not packaged (`.pkgmeta` ignores `tools`).

## Setup (once per machine)

- LuaLS: a release from https://github.com/LuaLS/lua-language-server. This PC has 3.18.2 at
  `C:\Users\gwilkins\.local\lua-language-server` (else set `LUALS` to the exe).
- Ketho's definitions and the extension's name lists, in `C:\Users\gwilkins\.local\wow-api-annotations`
  (else set `WOW_API_ANNOTATIONS`):

```
git clone --depth 1 --filter=blob:none --sparse https://github.com/Ketho/vscode-wow-api.git vscode-wow-api
git -C vscode-wow-api sparse-checkout set Annotations
mkdir data
for f in globals globalapi deprecated flavor; do
  gh api -H "Accept: application/vnd.github.raw" "repos/Ketho/vscode-wow-api/contents/src/data/$f.ts" > "data/$f.ts"
done
```

`git -C vscode-wow-api pull` and fetching the four files again picks up Ketho's updates.

## Run

```
python tools/luals-check/run.py                         # this repo
python tools/luals-check/run.py ../CooldownCollaborator # any addon folder
python tools/luals-check/run.py --hints                 # list the hints too
python tools/luals-check/run.py --codes need-check-nil  # only some checks
```

It skips `Libs`, `tools`, `dist`, `docs`, `.claude` and `.github`. LuaLS takes about 30 s per
pass, and there are two passes. The second marks as known the UI globals the extension
auto-defines (names in its globals list that aren't API functions). Warnings are what VS Code's
Problems list shows. Hints (trailing spaces, unused callback arguments) only show as faded
text.

## Known noise (checked 17 Nov 2026)

Ketho's definitions follow Retail, so these warnings are expected and are not bugs:

- `undefined-global` for Classic-only calls (`GetSpellInfo`, `UnitAura`, `GetSpellCharges`,
  `CombatLogGetCurrentEventInfo`, the old spellbook calls, `BOOKTYPE_SPELL`). Each one sits in
  a Classic branch or behind an existence check. `data/flavor.ts` shows which game types have
  each function (bits 0x1 Retail, 0x2 MoP, 0x4 TBC, 0x8 Era; Forever isn't covered).
- `undefined-global` for our own named frames (`CDTL3_Lane_1`, `CDTL3_Ready_1_MF`, …), the old
  `CDTL2DB`, and `AceGUIWidgetLSMlists` (from the skipped Libs).
- `deprecated` on the `CDTL3.Compat` / `CC.Compat` shims and the overlay glow. Each is
  guarded, with the current call as the fallback.
- `undefined-field` on AceGUI widget methods, and on new Midnight calls the definitions don't
  have yet (they run in pcalls).
- `duplicate-set-field`: the deliberate wrappers (Profiles.lua `OnInitialize` and
  `RefreshConfig`, ResourceBars.lua `RefreshLane`, ReadyBoard.lua `RefreshReady`, …).
- `param-type-mismatch` on `SetAllPoints(true)`, `SetParent` of a BackdropTemplate frame and
  `LSM:Fetch` results: typing quirks, not wrong calls.
- `need-check-nil` where the checker can't see a table is always there: AceDB fills
  `CDTL3.db.global` and `.profile` from the defaults, `Profiles.lua` `P.Store(true)` always
  returns a table, and the combat log always gives an aura type. About 20 more come from the
  per-mode `if` chains left in Cooldown.lua (bar settings) and Lanes.lua (text settings).
- `redundant-parameter` on `TaxiGetNodeSlot` (Flights.lua) and `missing-parameter` on
  `IsSpellKnown`: the definitions list the wrong argument count (the game's taxi call takes
  three, and `IsSpellKnown`'s pet-spell flag is optional).
- `cast-local-type`: a local reused for another type (a string that becomes a number). Style,
  not a bug.

To check whether a function exists on a client, look in the per-client dumps in
Ketho/BlizzardInterfaceResources (branches `live`, `forever`, `classic` = MoP,
`classic_anniversary` = TBC, `classic_era`). Deprecated wrappers such as `SendChatMessage` are
in Blizzard's `Blizzard_Deprecated*` addons (Gethe/wow-ui-source), which load while the
`loadDeprecationFallbacks` CVar is on. It defaults to on, Forever included.
