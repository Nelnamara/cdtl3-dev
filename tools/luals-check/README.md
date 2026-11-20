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

## The bar: 0 warnings (since 17 Nov 2026)

Both CDTL3 and CooldownCollaborator show no warnings. Ketho's definitions follow Retail, so some lines are
right on purpose and still raise one. Each of those carries its reason in a comment and the marker
`---@diagnostic disable-next-line: <code>` directly above it (never a file-wide disable). The kinds:

- `undefined-global`: Classic-only calls inside a Classic branch or behind an existence check
  (`GetSpellInfo`, `GetSpellCharges`, `CombatLogGetCurrentEventInfo`, the old spellbook calls,
  `BOOKTYPE_SPELL`, `UnitAura`); the saved-variable globals (`CDTL3DB`, `CDTL2DB`); `AceGUIWidgetLSMlists`
  from the skipped Libs.
- `deprecated`: the `CDTL3.Compat` / `CC.Compat` shims and the old chat and glow fallbacks, each with the
  current call first.
- `duplicate-set-field`: the deliberate wrappers (Profiles.lua `OnInitialize` and `RefreshConfig`,
  ResourceBars.lua `RefreshLane`, ReadyBoard.lua `RefreshReady`, ...).
- `param-type-mismatch`, `redundant-parameter`, `missing-parameter`: definitions gaps
  (`SetAllPoints(true)`, `TaxiGetNodeSlot`'s three arguments, `LSM:Fetch` results).

A new warning is worth a look before it is marked: the one real bug the first run found (Request Rez
calling `IsRaidLeader`, which no client has) was an `undefined-global`. To find markers that no longer
cover a warning, blank them in a copy, run the check once, and see which next lines stay quiet.

The hints left (about 800 in CDTL3, 1 in CooldownCollaborator) are unused callback parameters
(AceConfig `info`, event arguments), kept on purpose because they show what each callback receives.

## Copied code and code-change proof

- `python tools/luals-check/dupes.py [addon folder] [--min N]` lists runs of N+ identical code lines
  (default 8; indentation, blank lines and comments ignored) and every place each starts. CDTL3's
  Data.lua spell rows and FlightData, and Collaborator's Data_*.lua tables, are data. Keep the rest at none
  (17 Nov 2026: CDTL3's one run is three settings tabs' 8-line opening, plain layout).
- `bash tools/luals-check/same-code.sh <git ref> <files>` compiles each file now and at the ref with Lua
  5.1's luac, drops line numbers and memory addresses, and compares the instructions: SAME means only
  comments, type notes or layout changed. (`luac -s` alone differs as soon as a line moves.)

To check whether a function exists on a client, look in the per-client dumps in
Ketho/BlizzardInterfaceResources (branches `live`, `forever`, `classic` = MoP,
`classic_anniversary` = TBC, `classic_era`). Deprecated wrappers such as `SendChatMessage` are
in Blizzard's `Blizzard_Deprecated*` addons (Gethe/wow-ui-source), which load while the
`loadDeprecationFallbacks` CVar is on. It defaults to on, Forever included.
