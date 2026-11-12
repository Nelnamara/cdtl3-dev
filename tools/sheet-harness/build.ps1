# Builds local test pages for the db-backed sheets: the stand-in db (stub.html), sample rows
# (seed-*.html) and the page itself, in one file you can open in a browser with no claude.ai sign-in.
#   powershell -File tools\sheet-harness\build.ps1
# Then open tools\sheet-harness\out\walk.html or review.html. window.__seed(collection, docs) adds
# rows (a layout change), window.__get(collection, id) reads one back.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $here)
$out = Join-Path $here "out"
New-Item -ItemType Directory -Force $out | Out-Null
$head = "<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>"
$stub = Get-Content (Join-Path $here "stub.html") -Raw -Encoding utf8
$utf8 = New-Object Text.UTF8Encoding $false
$pages = @(
	@{ name = "walk.html"; seed = "seed-walk.html"; page = "tools\walk-sheet\index.html" },
	@{ name = "review.html"; seed = "seed-review.html"; page = "tools\review-list\index.html" }
)
foreach ($p in $pages) {
	$seed = Get-Content (Join-Path $here $p.seed) -Raw -Encoding utf8
	$page = Get-Content (Join-Path $root $p.page) -Raw -Encoding utf8
	[IO.File]::WriteAllText((Join-Path $out $p.name), $head + $stub + $seed + $page, $utf8)
	Write-Output ("built " + $p.name)
}
