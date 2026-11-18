"""The WoW API code check: Ketho's "WoW API" definitions in the Lua language server
(LuaLS), run from the command line the way the VS Code extension sets it up.

    python tools/luals-check/run.py [addon folder] [--hints] [--codes a,b] [--out DIR]

With no folder it checks this repo. It prints the counts per severity and check, then
every warning (and every hint with --hints) as file:line. Two passes, like the extension:
the second marks as known the UI globals it would auto-define (names in its globals list
that are not API functions). Setup and the known noise: README.md next to this file.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
LUALS = os.environ.get("LUALS", r"C:\Users\gwilkins\.local\lua-language-server\bin\lua-language-server.exe")
ANN = os.environ.get("WOW_API_ANNOTATIONS", r"C:\Users\gwilkins\.local\wow-api-annotations")
SEV = {1: "Error", 2: "Warning", 3: "Info", 4: "Hint"}
IGNORE = ["Libs", "tools", "dist", "docs", ".claude", ".github"]


def args():
    argv = sys.argv[1:]
    opts = {"folder": os.path.dirname(os.path.dirname(HERE)), "hints": False, "codes": None, "out": None}
    i = 0
    while i < len(argv):
        if argv[i] == "--hints":
            opts["hints"] = True
        elif argv[i] == "--codes":
            i += 1
            opts["codes"] = set(argv[i].split(","))
        elif argv[i] == "--out":
            i += 1
            opts["out"] = argv[i]
        else:
            opts["folder"] = argv[i]
        i += 1
    opts["folder"] = os.path.abspath(opts["folder"])
    # one reused folder per addon, so runs leave nothing behind
    opts["out"] = opts["out"] or os.path.join(tempfile.gettempdir(), "luals-check", os.path.basename(opts["folder"]))
    return opts


def names(path, pattern):
    return set(re.findall(pattern, open(path, encoding="utf-8").read(), re.M))


def run(folder, out, globals_):
    os.makedirs(out, exist_ok=True)
    cfg = {
        "runtime.version": "Lua 5.1",
        "runtime.builtin": {k: "disable" for k in
                            ("basic", "debug", "io", "math", "os", "package", "string", "table", "utf8")},
        "workspace.library": [os.path.join(ANN, "vscode-wow-api", "Annotations", "Core")],
        "workspace.ignoreDir": IGNORE,
        "diagnostics.globals": sorted(globals_),
    }
    cfgPath = os.path.join(out, "luarc.json")
    json.dump(cfg, open(cfgPath, "w"), indent=1)
    log = os.path.join(out, "log")
    subprocess.run([LUALS, "--check=" + folder, "--configpath=" + cfgPath, "--checklevel=Hint",
                    "--check_format=json", "--logpath=" + log], capture_output=True)
    path = os.path.join(log, "check.json")
    return json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}


def rows(result):
    for uri, diags in result.items():
        f = urllib.parse.unquote(uri).replace("\\", "/").rsplit("/", 1)[-1]
        for d in diags:
            yield f, d["range"]["start"]["line"] + 1, d["severity"], d["code"], d["message"].replace("\n", " | ")


def main():
    opts = args()
    for p in (LUALS, os.path.join(ANN, "vscode-wow-api", "Annotations", "Core"), os.path.join(ANN, "data", "globals.ts")):
        if not os.path.exists(p):
            sys.exit("missing " + p + " (see tools/luals-check/README.md)")
    known = names(os.path.join(ANN, "data", "globals.ts"), r'^\s*"(.+?)": true')
    api = names(os.path.join(ANN, "data", "globalapi.ts"), r'^\s*"(.+?)": true')

    first = run(opts["folder"], os.path.join(opts["out"], "pass1"), [])
    auto = set()
    for f, line, sev, code, msg in rows(first):
        m = re.search(r"`(.+?)`", msg)
        if code == "undefined-global" and m and m.group(1) in known and m.group(1) not in api:
            auto.add(m.group(1))
    result = run(opts["folder"], os.path.join(opts["out"], "pass2"), auto)

    items = sorted(rows(result))
    counts = Counter((SEV[s], c) for _, _, s, c, _ in items)
    print(f"{opts['folder']}: {len(items)} items", dict(Counter(SEV[s] for _, _, s, _, _ in items)))
    print("UI globals marked known (as the extension does):", ", ".join(sorted(auto)) or "none")
    for (s, c), n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"{n:6}  {s:8} {c}")
    for f, line, sev, code, msg in items:
        if (sev <= 2 or opts["hints"]) and (not opts["codes"] or code in opts["codes"]):
            print(f"{SEV[sev]:7} {code:22} {f}:{line}  {msg[:160]}")
    print("check.json:", os.path.join(opts["out"], "pass2", "log", "check.json"))


if __name__ == "__main__":
    main()
