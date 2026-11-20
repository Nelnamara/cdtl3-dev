#!/usr/bin/env bash
# Proves an edit changed no code: compiles each file as it is now and as it was at a git ref
# with Lua 5.1's luac, lists the instructions, drops line numbers and memory addresses, and
# compares. Comments, type notes, blank lines and moved lines give SAME; any code change
# gives DIFFERS (with the diff). Run from the repo root:
#   bash tools/luals-check/same-code.sh <ref> <file.lua> [more files]
# LUAC overrides the compiler path.
LUAC="${LUAC:-/c/Program Files (x86)/Lua/5.1/luac.exe}"
ref="$1"; shift
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
status=0
listing() { "$LUAC" -s -l -p "$1" | sed -E 's/<[^>]*>/<>/; s/ at [0-9A-Fa-fx]+\)/)/; s/; [0-9A-Fa-f]{8}$//; s/\[[0-9-]+\]//'; }
for f in "$@"; do
	if ! git show "$ref:$f" > "$tmp/old.lua" 2>/dev/null; then echo "NEW      $f"; continue; fi
	listing "$tmp/old.lua" > "$tmp/old.lst" || { echo "BROKEN   $f (at $ref)"; status=1; continue; }
	listing "$f" > "$tmp/new.lst" || { echo "BROKEN   $f"; status=1; continue; }
	if diff -q "$tmp/old.lst" "$tmp/new.lst" > /dev/null; then echo "SAME     $f"
	else echo "DIFFERS  $f"; diff "$tmp/old.lst" "$tmp/new.lst" | head -20; status=1; fi
done
exit $status
