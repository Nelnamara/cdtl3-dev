"""Finds copied code: runs of the same lines (ignoring indentation, blank lines and comments) that
appear more than once across an addon's Lua files. Libs, Locales, tools, dist and docs are skipped.

    python tools/luals-check/dupes.py [addon folder] [--min N]

--min is the shortest run reported (default 8 lines). Each result lists the run's length and every
place it starts (file:line), longest first; overlapping runs are merged.
"""
import os
import re
import sys
from collections import defaultdict

SKIP = {"Libs", "Locales", "tools", "dist", "docs", ".git", ".github", ".claude"}


def lua_files(root):
    for dirpath, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP]
        for f in sorted(files):
            if f.endswith(".lua"):
                yield os.path.join(dirpath, f)


def code_lines(path):
    """(original line number, normalized text) for each line that holds code."""
    out, in_block = [], False
    for n, raw in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
        line = raw.strip()
        if in_block:
            if "]]" in line:
                in_block = False
            continue
        if line.startswith("--[[") or line.startswith("--[=["):
            in_block = "]]" not in line
            continue
        line = re.sub(r"\s*--.*$", "", line) if not re.search(r"[\"'].*--", line) else line
        line = re.sub(r"\s+", " ", line)
        if line and line not in ("end", "else", "end)", "}", "},", "end,"):
            out.append((n, line))
    return out


def main():
    argv = sys.argv[1:]
    min_len = 8
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    i = 0
    while i < len(argv):
        if argv[i] == "--min":
            i += 1
            min_len = int(argv[i])
        else:
            root = argv[i]
        i += 1
    files = {os.path.relpath(p, root).replace("\\", "/"): code_lines(p) for p in lua_files(root)}
    seen = defaultdict(list)  # window text -> [(file, index)]
    for f, lines in files.items():
        for k in range(len(lines) - min_len + 1):
            seen["\n".join(t for _, t in lines[k:k + min_len])].append((f, k))
    # grow each repeated window into the longest run shared by all its places
    runs = {}
    for places in seen.values():
        if len(places) < 2:
            continue
        length = min_len
        while True:
            nxt = set()
            for f, k in places:
                lines = files[f]
                nxt.add(lines[k + length][1] if k + length < len(lines) else None)
            if len(nxt) != 1 or None in nxt:
                break
            length += 1
        key = tuple(sorted(places))
        if runs.get(key, 0) < length:
            runs[key] = length
    # drop runs that sit inside a longer run at the same places
    kept = []
    for places, length in sorted(runs.items(), key=lambda kv: -kv[1]):
        inside = any(
            len(p2) == len(places) and all(f1 == f2 and k2 <= k1 and k1 + length <= k2 + l2
                                           for (f1, k1), (f2, k2) in zip(places, p2))
            for p2, l2 in kept)
        if not inside:
            kept.append((places, length))
    total = 0
    for places, length in kept:
        where = ", ".join(f"{f}:{files[f][k][0]}" for f, k in places)
        print(f"{length:4} lines x{len(places)}  {where}")
        total += length * (len(places) - 1)
    print(f"{len(kept)} repeated runs of {min_len}+ lines; {total} lines could go")


if __name__ == "__main__":
    main()
