// Lists the Blizzard sounds that exist in every client (SoundKitEntry from wago.tools, cached next to the
// spell tables) with their community-listfile paths, for docs/sounds-shortlist.md and Media.lua.
//   node sounds.js <listfile.csv> [kitID,kitID,...]   no kit list: every kit under sound/interface/ with 1 file
// Needs the tables in cache/<build>/SoundKitEntry.csv (see the README; same URL pattern as the spell tables).
const fs = require('fs');
const path = require('path');
const builds = require('./builds.json').clients;

function rows(file) {
	const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
	const head = lines.shift().split(',');
	return lines.filter(Boolean).map((l) => {
		const c = l.split(',');
		const o = {};
		head.forEach((h, i) => (o[h] = c[i]));
		return o;
	});
}

const perBuild = builds.map((b) => {
	const files = new Map(); // FileDataID -> Set(SoundKitID)
	const kitSize = new Map();
	for (const r of rows(path.join(__dirname, "cache", b.build, "SoundKitEntry.csv"))) {
		const f = Number(r.FileDataID), k = Number(r.SoundKitID);
		if (!files.has(f)) files.set(f, new Set());
		files.get(f).add(k);
		kitSize.set(k, (kitSize.get(k) || 0) + 1);
	}
	return { key: b.key, files, kitSize };
});

const names = new Map();
for (const l of fs.readFileSync(process.argv[2], 'utf8').split(/\r?\n/)) {
	const i = l.indexOf(';');
	if (i > 0) names.set(Number(l.slice(0, i)), l.slice(i + 1));
}

// argv[3] "ids:1,2,3" lists just those file IDs instead.
// every file in all five builds' SoundKitEntry whose listfile path matches the pattern (argv[3], default: alert-like names)
const ids = (process.argv[3] || '').startsWith('ids:') ? process.argv[3].slice(4).split(',').map(Number) : null;
const re = new RegExp(!ids && process.argv[3] || 'ready|raid|warn|quest|level|alarm|chime|bell|gong|horn|ping|toast|ding|alert|complete|achiev|invite|reveal|queue|countdown|whistle|tick|alarm|shimmer|zap|spark|cast|bloom', 'i');
const out = [];
for (const [f, p] of names) {
	if (ids ? !ids.includes(f) : (!/^sound\/(interface|spells|doodad)\//i.test(p) || !re.test(p))) continue;
	if (!perBuild.every((b) => b.files.has(f))) continue;
	const kits = perBuild.map((b) => [...b.files.get(f)].sort((x, y) => x - y));
	out.push({ f, p, kits: kits.map((k, i) => perBuild[i].key + ':' + k.join('/')).join(' ') });
}
out.sort((a, b) => a.p.localeCompare(b.p));
for (const o of out) console.log([o.f, o.p, o.kits].join('\t'));