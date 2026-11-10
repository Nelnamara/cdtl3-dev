# Combat timers test build 2: spec

Repo `cdtl3-dev`, branch **`combat-timers`** (checked out). Build 1 is in and walked by the owner on
WoW: Forever: 14 of 15 lines pass (see "Test build 1: the owner's walk" in `cooldown-manager-scope.md`).
Read `CLAUDE.md`, then `combat-timers-spec.md` (the module, its API, the hard rule on hidden values and
its "As built" notes), then `CombatTimers.lua`. Build 2 is six small changes. Out of combat and on Classic
clients nothing else may change.

**Hard rule (unchanged):** a value that may be hidden (secret) is only handed to a widget. Never compare
it (`==` included), do arithmetic on it, concatenate it or `tostring` it. The test stub's secrets throw on
`<`, arithmetic and concat but not on `==`, so check `==` by reading your code.

**File ownership** (two builders work in the same folder at the same time):
- Lane A: `CombatTimers.lua`, `Cooldown.lua`, `tools/tests/*`.
- Lane B: `Options.lua` only.
Neither commits, pushes, tags or switches branch. No AI/assistant attribution anywhere. In-game text in
plain, short English. Tabs for indentation.

## Lane A (engine)

### A1. Countdown text in combat matches CDTL3's style
Today a riding spell's `[cd.time]`-only text uses a duration text binding with
`C_StringUtil.CreateSecondsFormatter()`; in game it reads "59sec" (the `OneLetter` abbreviation call
didn't take). CDTL3's own format is `CDTL3:GetReadableTime` (`Helpers.lua`): over 60 s "m:ss", 10–60 s
whole seconds ("59"), under 10 s one decimal ("9.4").
- Find the closest the client allows, from Blizzard's generated API docs on the Forever branch
  (`gh api "repos/Gethe/wow-ui-source/contents/Interface/AddOns/Blizzard_APIDocumentationGenerated/<file>?ref=forever" -H "Accept: application/vnd.github.raw"`;
  list the folder first; look at `DurationTextBinding*`, `DurationUtil*`, anything named for numeric or
  seconds formatters and `StringUtil*`; some copies are in
  `C:\Users\gwilkins\AppData\Local\Temp\claude\b834c9d6881b9734\039f7620-32bb-4d25-93e7-e9cc776f3de5\scratchpad\cdmsrc\`).
  `DurationTextBinding:SetTextFormat({ formatString, components = { { property, formatter } } })` and the
  seconds formatter's options are the places to look. Ground enum names in the docs, not memory.
- Target order of preference: exactly CDTL3's style; else whole seconds with no unit under a minute and
  "m:ss" above; else the shortest unit form the formatter has ("59s", "1m 33s").
- Every formatter call stays in a pcall and falls back to what build 1 does. Say in your report exactly
  which form you expect in game and why, and which calls are unproven there.

### A2. Dimmed text on estimated buffs
While the module is enabled and auras are hidden (`CDTL3:AurasAreSecret()`), a buff or debuff cooldown
that is **not** riding (no Tracked Bars feed) is an estimate: draw its icon and bar texts at alpha 0.55.
Back to 1 the moment it rides or auras are readable. Add `CT:Estimated(f)` and apply it in
`private.UpdateText` (`Cooldown.lua`), setting the FontString's alpha only when it changes. Spells and
items are not dimmed.

### A3. Split (Time) lanes hold their shape in combat for Tracked Bars buffs
Build 1 puts a mirrored buff on a straight line over `splitAbs.max` on a SPLIT_ABS lane, because a curve
can't take a hidden value from addon code. A piecewise-linear map needs no curve: chain one StatusBar per
segment.
- Knots: `(0, 0)`, each active `(sNv, sNp)` for N = 1..count, `(max, 1)` from `lane.mode.splitAbs`. If the
  values or positions are not strictly increasing, keep build 1's straight line.
- Segment k covers values `[a, b]` and positions `[pa, pb]`: a transparent StatusBar of length
  `(pb - pa) * len` (`len` = lane width minus icon size, as the rider), `SetMinMaxValues(a, b)`,
  `SetValue(feed.value)`. A StatusBar clamps, so below `a` it is empty and above `b` full.
- Segment 1 is anchored to the lane like the rider. Segment k+1 is anchored (same anchor point) to the
  **fill edge** of segment k (its status bar texture's opposite edge, as the icon is today). The icon is
  anchored to the fill edge of the last segment. The sum of the fills is the split position.
- Same orientation, reverse fill and vertical handling as the rider; segments are created lazily, hidden
  on leaving, and re-laid out when the lane's settings change.
- Only for `ct.kind == "buff"` on SPLIT_ABS. SPLIT (%) keeps the straight line (its split points are
  fractions of a hidden total). Spells keep their curves.
- Nested anchoring to a fill fed a hidden value is unproven in game: any error goes through
  `private.Fail` as now, and the report says so.

### Tests
Extend `tools/tests/combattimers.lua`: the chained segments reproduce `CDTL3.CalcSplitPosition(v, max, s)`
(sum of each segment's clamped fill fraction times its share of the lane) for counts 1–3 at many values,
including below the first knot and at the max; non-increasing knots fall back to the straight line;
a mirrored buff on a SPLIT_ABS lane anchors to the last segment's fill; `CT:Estimated` is true for an
unfed buff while auras are hidden and false when it rides, out of combat, for spells and when the module
is off; the text alpha follows it; the text format path falls back cleanly when the formatter calls
fail. Run `bash tools/tests/runall.sh` and the lint (`tools/tests/README.md`): every RESULT line 0 fails
and 0 Lua errors, lint clean.

## Lane B (`Options.lua`)

### B1. Longer times on the lane sliders
The owner's rule (2026-11-10): **a slider must reach every value the setting can hold and show the saved
value.** No soft limit below the real one: today the Max Time slider stops at 180 (`softMax`), a larger
typed number is saved but the slider just sits at its end, which hides the real value.
- Lane › General › **Max Time** (`maxTime`, about line 4267): drop `softMax`; set a hard `max = 3600`;
  keep `softMin = 10` and `bigStep = 1`. Description: "How many seconds the lane represents (up to 3600,
  an hour). Type a number in the box for an exact value."
- Split (Time) values (`saSplit1Value`, `saSplit2Value`, `saSplit3Value`, about line 4610 on): `max` 360
  → 3600 (hard, no `softMax`), `min = 1`, `bigStep = 1`. Their descriptions say "percentage"; make them
  "How many seconds from the end split N sits at (up to 3600)."
- Split (%) values are untouched.
- A saved Max Time above 3600 (typed in an older build) must not error the options window: the getter
  returns `math.min(value, 3600)` for display; the saved value is left alone until the user changes it.

### B2. One-click long buffs scale
In the same General section, right after Mode: an `execute` button **"Long buffs scale"**, description:
"Sets this lane to Split (Time) over 60 minutes. The last 30 seconds, 30 seconds to 2 minutes and 2 to 10
minutes each get a quarter of the lane; 10 to 60 minutes share the last quarter. Hide Long Timers is
turned off for it." It sets `lane.mode.type = "SPLIT_ABS"` and in `lane.mode.splitAbs`: `max = 3600`,
`hideTimeSurplus = false`, `count = 3`, `s1v = 30`, `s1p = 0.25`, `s2v = 120`, `s2p = 0.5`, `s3v = 600`,
`s3p = 0.75`; then `CDTL3:RefreshLane(i)`. Write into the existing tables (AceDB keeps only non-default
values; never replace the `splitAbs` table).

### B3. Unticking Ignored shows an active buff at once
Filters › the **Ignored** toggle's setter (about line 3675). When `val` is false and `t` is `buffs` or
`debuffs`, and `CDTL3.db.profile.global[t]["enabled"]`:
- read `CDTL3:AuraExists("player", <saved entry's name>)` (nil while auras are hidden: then do nothing);
- if the aura is up: an existing cooldown frame (`GetExistingCooldown`) is sent to its lane and bar frame
  (`CDTL3:SendToLane`, `CDTL3:SendToBarFrame`); otherwise create one the way `CDTL3:OnPlayerAuraApplied`
  does (`CDTL3:CreateCooldown(CDTL3:GetUID(), t, s)` with the saved entry `s`).
Ticking Ignored, other types, and the "<< Add New >>" custom case behave as now.

Lane B checks its work with the lint's parse of `Options.lua` and by re-reading its diff
(`git diff -- Options.lua`, run from the repo folder); it does not run `runall.sh`.

## Report back (each lane, under 250 words)
Files changed; test and lint results (Lane A: the count of RESULT lines, all clean or which aren't);
anything you could not build as written and what you did instead; what the owner's in-game walk must
check because it can't be proven here.
