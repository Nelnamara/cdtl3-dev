# flight-data

Turns Blizzard's flight-path data (wago.tools DB2 tables `TaxiPath` and `TaxiPathNode`) into one small Lua file per client in `FlightData/`. The addon estimates a flight it has not timed yet as the sum of each hop's length divided by taxi speed, plus stop delays.

Clients and builds come from `tools/spell-list-check/builds.json`. No npm dependencies (Node's built-in `fetch`). Tables are cached in `tools/flight-data/cache/<build>/` (git-ignored).

```
node tools/flight-data/build.js                  # all clients, writes FlightData/*.lua
node tools/flight-data/build.js forever retail   # only these client keys
node tools/flight-data/build.js --refresh        # re-download the tables
node tools/flight-data/build.js --check          # regenerate in memory, compare with FlightData/, exit 1 on a difference
```

Run `--check` after each game patch (after bumping the builds in `builds.json`), like spell-list-check.

## Output

`FlightData/Era.lua`, `Forever.lua`, `TBC.lua`, `Mists.lua` (key `mop`), `Retail.lua`:

```lua
CDTL3.flightData = {
	build = "1.60.1.70888",
	paths = {
		["22-25"] = { 4752, 0 },   -- ["from-to"] = { length in yards, stop delay in seconds }
	},
}
```

Keys are `TaxiNodes` IDs, sorted by from then to. A path's points are sorted by `NodeIndex`; length is the sum of 3D distances between consecutive points.

## Findings (checked against the data)

- **Teleport flag**: `TaxiPathNode.Flags` bit `0x1`. The flagged point is the last one before the jump, so the hop **out of** the flagged point is not flown (e.g. path 301, 35-20: flagged point is 68 yd from its predecessor, the next hop is 13685 yd on the same continent). Those hops are skipped. Hops where `ContinentID` changes are skipped too. Other bits seen: `0x2` (a stop; every such point carries a Delay, and no other point does), `0x8`.
- **Delay unit**: seconds. Only `0x2` stop points have one, always 30 or 60, and they sit on the boat and zeppelin paths (the wait at each end). Milliseconds would be meaningless there. The file emits whole seconds.
- Rows with a `0` from or to node are placeholders, not routes, and are ignored (Forever: 14 rows).
- Two `TaxiPath` rows with the same from-to: the shorter one is kept; the script prints each duplicate.
- Odd rows are printed by the script and still emitted where they have points: paths with no points (skipped, none emitted), `from = to` paths (scripted/quest flights, mostly Retail and MoP), and zero-length paths (single-point paths, Retail and MoP).
