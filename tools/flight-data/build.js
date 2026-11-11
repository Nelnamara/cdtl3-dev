#!/usr/bin/env node
// Builds FlightData/<Client>.lua from wago.tools DB2 tables TaxiPath and TaxiPathNode.
//
//   node tools/flight-data/build.js                 all clients
//   node tools/flight-data/build.js forever retail  only these client keys
//   node tools/flight-data/build.js --refresh       re-download the tables
//   node tools/flight-data/build.js --check         regenerate in memory, compare with FlightData/, exit 1 on a difference
//
// Clients and builds come from tools/spell-list-check/builds.json. No npm dependencies.
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const CACHE = path.join(__dirname, 'cache');
const OUT_DIR = path.join(ROOT, 'FlightData');
const CLIENTS = JSON.parse(fs.readFileSync(path.join(ROOT, 'tools', 'spell-list-check', 'builds.json'), 'utf8')).clients;
const FILE_NAMES = { era: 'Era', forever: 'Forever', tbc: 'TBC', mop: 'Mists', retail: 'Retail' };
const TABLES = ['TaxiPath', 'TaxiPathNode'];

// TaxiPathNode.Flags: 0x1 = teleport. The flagged point is the last one before the jump, so the hop OUT of it (to the next point) is not flown.
const FLAG_TELEPORT = 1;
// TaxiPathNode.Delay is in seconds (verified against the data, see README).

const args = process.argv.slice(2);
const refresh = args.includes('--refresh');
const check = args.includes('--check');
const wanted = args.filter((a) => !a.startsWith('--'));
for (const a of args) {
	if (a.startsWith('--') && a !== '--refresh' && a !== '--check') {
		console.error('unknown option ' + a);
		process.exit(2);
	}
}
for (const k of wanted) {
	if (!CLIENTS.some((c) => c.key === k)) {
		console.error('unknown client "' + k + '"; builds.json has: ' + CLIENTS.map((c) => c.key).join(', '));
		process.exit(2);
	}
}

// ---------- wago.tools tables ----------
async function fetchTables(build, tables) {
	const dir = path.join(CACHE, build);
	fs.mkdirSync(dir, { recursive: true });
	for (const t of tables) {
		const file = path.join(dir, t + '.csv');
		if (fs.existsSync(file) && !refresh) continue;
		const url = 'https://wago.tools/db2/' + t + '/csv?build=' + encodeURIComponent(build);
		process.stderr.write('downloading ' + t + ' (' + build + ')\n');
		const res = await fetch(url);
		if (!res.ok || !(res.headers.get('content-type') || '').includes('csv')) {
			throw new Error('wago.tools returned ' + res.status + ' for ' + url);
		}
		fs.writeFileSync(file + '.part', Buffer.from(await res.arrayBuffer()));
		fs.renameSync(file + '.part', file);
	}
	return dir;
}

// RFC 4180 rows (quoted fields may hold commas, quotes and newlines), one callback per row
function parseCSV(text, onRow) {
	const n = text.length;
	let i = text.charCodeAt(0) === 0xFEFF ? 1 : 0;
	let row = [];
	while (i < n) {
		if (text.charCodeAt(i) === 34) {
			let out = '';
			let j = i + 1;
			for (;;) {
				const q = text.indexOf('"', j);
				if (q < 0) throw new Error('unterminated quoted field');
				out += text.slice(j, q);
				if (text.charCodeAt(q + 1) === 34) {
					out += '"';
					j = q + 2;
				} else {
					j = q + 1;
					break;
				}
			}
			row.push(out);
			i = j;
		} else {
			let j = i;
			while (j < n) {
				const c = text.charCodeAt(j);
				if (c === 44 || c === 10 || c === 13) break;
				j++;
			}
			row.push(text.slice(i, j));
			i = j;
		}
		if (text.charCodeAt(i) === 44) {
			i++;
		} else {
			if (text.charCodeAt(i) === 13) i++;
			if (text.charCodeAt(i) === 10) i++;
			onRow(row);
			row = [];
		}
	}
}

// rows as objects keyed by header name
function readTable(dir, table) {
	const text = fs.readFileSync(path.join(dir, table + '.csv'), 'utf8');
	let head = null;
	const rows = [];
	parseCSV(text, (r) => {
		if (!head) {
			head = r;
			return;
		}
		if (r.length === 1 && r[0] === '') return;
		const o = {};
		for (let i = 0; i < head.length; i++) o[head[i]] = r[i];
		rows.push(o);
	});
	if (!head) throw new Error(table + '.csv is empty');
	for (const need of table === 'TaxiPath' ? ['ID', 'FromTaxiNode', 'ToTaxiNode'] : ['Loc_0', 'Loc_1', 'Loc_2', 'PathID', 'NodeIndex', 'ContinentID', 'Flags', 'Delay']) {
		if (!(need in rows[0])) throw new Error(table + '.csv has no column ' + need + ' (columns: ' + head.join(', ') + ')');
	}
	return rows;
}

// ---------- compute ----------
function compute(dir) {
	const paths = readTable(dir, 'TaxiPath');
	const nodes = readTable(dir, 'TaxiPathNode');
	const byPath = new Map();
	for (const n of nodes) {
		const id = Number(n.PathID);
		if (!byPath.has(id)) byPath.set(id, []);
		byPath.get(id).push({
			x: Number(n.Loc_0), y: Number(n.Loc_1), z: Number(n.Loc_2),
			idx: Number(n.NodeIndex), cont: Number(n.ContinentID),
			flags: Number(n.Flags), delay: Number(n.Delay),
		});
	}
	const best = new Map(); // "from-to" -> { from, to, len, delay, id }
	const notes = { noPoints: [], onePoint: [], zeroLength: [], duplicates: [], unnamed: 0, selfRoute: [], teleportHops: 0, contHops: 0 };
	for (const p of paths) {
		const id = Number(p.ID), from = Number(p.FromTaxiNode), to = Number(p.ToTaxiNode);
		if (from === 0 || to === 0) {
			notes.unnamed++; // placeholder rows (0-0 etc.), not flight-point routes
			continue;
		}
		const pts = (byPath.get(id) || []).slice().sort((a, b) => a.idx - b.idx);
		if (pts.length === 0) {
			notes.noPoints.push(id + ' (' + from + '-' + to + ')');
			continue;
		}
		if (pts.length === 1) notes.onePoint.push(id + ' (' + from + '-' + to + ')');
		let len = 0, delay = 0;
		for (let i = 0; i < pts.length; i++) {
			delay += pts[i].delay;
			if (i === 0) continue;
			const a = pts[i - 1], b = pts[i];
			if (a.cont !== b.cont) {
				notes.contHops++;
				continue;
			}
			if (a.flags & FLAG_TELEPORT) {
				notes.teleportHops++;
				continue;
			}
			len += Math.hypot(b.x - a.x, b.y - a.y, b.z - a.z);
		}
		if (from === to) notes.selfRoute.push(id + ' (' + from + ')');
		if (len === 0) notes.zeroLength.push(id + ' (' + from + '-' + to + ')');
		const key = from + '-' + to;
		const entry = { from, to, len, delay, id };
		const old = best.get(key);
		if (old) {
			notes.duplicates.push(key + ': paths ' + old.id + ' (' + Math.round(old.len) + ' yd) and ' + id + ' (' + Math.round(len) + ' yd), kept ' + (len < old.len ? id : old.id));
			if (len < old.len) best.set(key, entry);
		} else {
			best.set(key, entry);
		}
	}
	const list = [...best.values()].sort((a, b) => a.from - b.from || a.to - b.to);
	return { list, notes };
}

function render(client, list) {
	const lines = [
		'-- Flight route data for ' + client.name + ', build ' + client.build + '.',
		'-- Generated by tools/flight-data from wago.tools DB2 tables TaxiPath and TaxiPathNode. Do not edit by hand.',
		'-- paths["from-to"] = { length in yards, stop delay in seconds } (TaxiNodes IDs)',
		'CDTL3.flightData = {',
		'\tbuild = "' + client.build + '",',
		'\tpaths = {',
	];
	for (const e of list) lines.push('\t\t["' + e.from + '-' + e.to + '"] = { ' + Math.round(e.len) + ', ' + Math.round(e.delay) + ' },');
	lines.push('\t},', '}', '');
	return lines.join('\n');
}

function stats(list) {
	const l = list.map((e) => Math.round(e.len)).sort((a, b) => a - b);
	if (!l.length) return 'no routes';
	const mid = l.length % 2 ? l[(l.length - 1) / 2] : Math.round((l[l.length / 2 - 1] + l[l.length / 2]) / 2);
	return 'min ' + l[0] + ' / median ' + mid + ' / max ' + l[l.length - 1] + ' yd';
}

async function main() {
	const clients = CLIENTS.filter((c) => !wanted.length || wanted.includes(c.key));
	let differ = 0;
	for (const client of clients) {
		const file = FILE_NAMES[client.key];
		if (!file) throw new Error('no output file name for client ' + client.key);
		const dir = await fetchTables(client.build, TABLES);
		const { list, notes } = compute(dir);
		const text = render(client, list);
		const target = path.join(OUT_DIR, file + '.lua');
		console.log(client.key + ' (' + client.build + '): ' + list.length + ' routes, ' + notes.duplicates.length + ' duplicates, ' + Buffer.byteLength(text) + ' bytes, ' + stats(list));
		for (const [label, arr] of [['no points', notes.noPoints], ['single point', notes.onePoint], ['from = to', notes.selfRoute], ['zero length', notes.zeroLength], ['duplicate', notes.duplicates]]) {
			if (arr.length) console.log('  ' + label + ' (' + arr.length + '): ' + arr.join('; '));
		}
		console.log('  skipped hops: ' + notes.teleportHops + ' teleport, ' + notes.contHops + ' continent change, ' + notes.unnamed + ' rows with a 0 endpoint ignored');
		if (check) {
			const old = fs.existsSync(target) ? fs.readFileSync(target, 'utf8') : null;
			if (old === null) {
				console.log('  DIFF: ' + path.relative(ROOT, target) + ' is missing');
				differ++;
			} else if (old !== text) {
				differ++;
				const a = old.split('\n'), b = text.split('\n');
				const sa = new Set(a), sb = new Set(b);
				const gone = a.filter((x) => !sb.has(x)), added = b.filter((x) => !sa.has(x));
				console.log('  DIFF: ' + path.relative(ROOT, target) + ' differs (' + gone.length + ' lines only in committed, ' + added.length + ' only in regenerated)');
				for (const x of gone.slice(0, 10)) console.log('    - ' + x.trim());
				for (const x of added.slice(0, 10)) console.log('    + ' + x.trim());
			}
		} else {
			fs.mkdirSync(OUT_DIR, { recursive: true });
			fs.writeFileSync(target, text);
		}
	}
	if (check) {
		console.log(differ ? differ + ' file(s) differ' : 'FlightData is up to date');
		process.exit(differ ? 1 : 0);
	}
}

main().catch((e) => {
	console.error(e.message || e);
	process.exit(2);
});
