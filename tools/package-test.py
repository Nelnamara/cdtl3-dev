"""Build a test zip of the addon the way the release packager lays it out.

    python tools/package-test.py [out.zip]

Packs the working tree (tracked files plus new, not git-ignored ones) into a
CooldownTimeline3/ folder, leaving out what .pkgmeta's ignore list leaves out.
Default output: dist/CooldownTimeline3-<version>-test.zip (git-ignored).
Zip paths use forward slashes, so it unpacks cleanly on macOS too.
"""
import os
import re
import subprocess
import sys
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = "CooldownTimeline3"


def pkgmeta_ignores():
    ignores, inside = [], False
    with open(os.path.join(REPO, ".pkgmeta"), encoding="utf-8") as f:
        for line in f:
            if re.match(r"^ignore:\s*$", line):
                inside = True
                continue
            if inside:
                m = re.match(r"^\s+-\s+(.+?)\s*$", line)
                if m:
                    ignores.append(m.group(1).strip("/"))
                elif line.strip() and not line.startswith(" "):
                    inside = False
    return ignores


def files_to_pack():
    out = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
        cwd=REPO, capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    ignores = pkgmeta_ignores()
    keep = []
    for path in out:
        if not os.path.isfile(os.path.join(REPO, path)):
            continue  # deleted in the working tree
        if any(path == ig or path.startswith(ig + "/") for ig in ignores):
            continue
        keep.append(path)
    return sorted(keep)


def version():
    with open(os.path.join(REPO, FOLDER + ".toc"), encoding="utf-8") as f:
        m = re.search(r"^## Version:\s*(\S+)", f.read(), re.M)
    return m.group(1) if m else "dev"


def main():
    dest = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        REPO, "dist", "%s-%s-test.zip" % (FOLDER, version()))
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    files = files_to_pack()
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for path in files:
            z.write(os.path.join(REPO, path), FOLDER + "/" + path)
    print("%s: %d files" % (dest, len(files)))


if __name__ == "__main__":
    main()
