#!/bin/bash
# Runs every harness against the addon (default: this repo; set R=<folder> for another copy). Prints RESULT and FAIL lines only.
R=${R:-$(cd "$(dirname "$0")/../.." && pwd -W)}
T=$(dirname "$0")
run() { timeout 300 node $T/run.js $R "$@" 2>&1 | grep -E "^RESULT|FAIL" ; }
for s in "120105 CooldownTimeline3_Mainline.toc MAGE" "120105 CooldownTimeline3_Mainline.toc DEATHKNIGHT" "16001 CooldownTimeline3_Camelot.toc PALADIN" "16001 CooldownTimeline3.toc HUNTER" "11509 CooldownTimeline3_Vanilla.toc ROGUE" "20506 CooldownTimeline3_TBC.toc SHAMAN" "50504 CooldownTimeline3_Mists.toc DEATHKNIGHT"; do set -- $s; run $1 $T/smoke.lua $2 $3; done
for s in "11509 CooldownTimeline3_Vanilla.toc" "16001 CooldownTimeline3_Camelot.toc" "20506 CooldownTimeline3_TBC.toc" "50504 CooldownTimeline3_Mists.toc" "120105 CooldownTimeline3_Mainline.toc"; do set -- $s; run $1 $T/data.lua $2; run $1 $T/readers.lua $2; run $1 $T/cooldown3.lua $2; run $1 $T/fixes.lua $2; run $1 $T/fixes3013.lua $2; done
for s in "16001 CooldownTimeline3_Camelot.toc HUNTER" "120105 CooldownTimeline3_Mainline.toc HUNTER" "120105 CooldownTimeline3_Mainline.toc DEATHKNIGHT" "50504 CooldownTimeline3_Mists.toc DEATHKNIGHT" "11509 CooldownTimeline3_Vanilla.toc WARLOCK" "20506 CooldownTimeline3_TBC.toc HUNTER"; do set -- $s; run $1 $T/events.lua $2 $3; done
for s in "11509 CooldownTimeline3_Vanilla.toc" "20506 CooldownTimeline3_TBC.toc" "50504 CooldownTimeline3_Mists.toc"; do set -- $s; run $1 $T/combattimers.lua $2; done
for s in "16001 CooldownTimeline3_Camelot.toc" "120105 CooldownTimeline3_Mainline.toc"; do set -- $s; run $1 $T/combattimers.lua $2 full; done
for s in "16001 CooldownTimeline3_Camelot.toc" "16001 CooldownTimeline3.toc" "120105 CooldownTimeline3_Mainline.toc" "11509 CooldownTimeline3_Vanilla.toc" "20506 CooldownTimeline3_TBC.toc" "50504 CooldownTimeline3_Mists.toc"; do set -- $s; run $1 $T/release310.lua $2; done
