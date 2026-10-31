#!/usr/bin/env node
// Checks the built-in spell lists in Data.lua against each client's game data (wago.tools).
// See README.md. Usage: node check.js [client key ...] [--src <addon folder>] [--refresh]
'use strict';

const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const HERE = __dirname;
const CACHE = path.join(HERE, 'cache');
const { clients: CLIENTS } = JSON.parse(fs.readFileSync(path.join(HERE, 'builds.json'), 'utf8'));
const TABLES = ['SpellName', 'SpellMisc', 'SpellCooldowns', 'SpellCategories', 'SpellCategory',
	'SpellClassOptions', 'SkillLine', 'SkillLineAbility', 'SkillRaceClassInfo', 'Talent'];

const STARTS_ON_EVENT = 0x02000000; // SpellMisc Attributes_0: the cooldown starts when the effect ends
const PASSIVE = 0x00000040;
const MIN_CD = 3000; // the addon ignores cooldowns of 3 s or less by default

const CLASS_BY_ID = { 1: 'WARRIOR', 2: 'PALADIN', 3: 'HUNTER', 4: 'ROGUE', 5: 'PRIEST', 6: 'DEATHKNIGHT',
	7: 'SHAMAN', 8: 'MAGE', 9: 'WARLOCK', 10: 'MONK', 11: 'DRUID', 12: 'DEMONHUNTER', 13: 'EVOKER' };
const CLASS_BY_FAMILY = { 3: 'MAGE', 4: 'WARRIOR', 5: 'WARLOCK', 6: 'PRIEST', 7: 'DRUID', 8: 'ROGUE', 9: 'HUNTER',
	10: 'PALADIN', 11: 'SHAMAN', 15: 'DEATHKNIGHT', 53: 'MONK', 107: 'DEMONHUNTER', 224: 'EVOKER' };
const WARLOCK_PETS = ['Imp', 'Felhunter', 'Voidwalker', 'Succubus', 'Infernal', 'Doomguard', 'Felguard',
	'Observer', 'Voidlord', 'Shivarra', 'Wrathguard', 'Fel Imp', 'Terrorguard', 'Abyssal'];

// ---------- arguments ----------
let src = path.resolve(HERE, '..', '..');
let refresh = false;
const wanted = [];
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
	if (argv[i] === '--src') src = path.resolve(argv[++i]);
	else if (argv[i] === '--refresh') refresh = true;
	else if (argv[i] === '-h' || argv[i] === '--help') {
		console.log('usage: node check.js [' + CLIENTS.map((c) => c.key).join('|') + ' ...] [--src <addon folder>] [--refresh]');
		process.exit(0);
	} else wanted.push(argv[i]);
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

function eachRow(dir, table, fn) {
	const file = path.join(dir, table + '.csv');
	if (!fs.existsSync(file)) return;
	let col = null;
	parseCSV(fs.readFileSync(file, 'utf8'), (row) => {
		if (!col) {
			col = {};
			row.forEach((h, k) => { col[h] = k; });
			return;
		}
		fn((name) => row[col[name]]);
	});
}

const int = (v) => { const x = parseInt(v, 10); return Number.isFinite(x) ? x : 0; };
const u32 = (v) => int(v) >>> 0;

function singleClass(mask) {
	mask = u32(mask);
	if (mask === 0 || (mask & (mask - 1)) !== 0) return null;
	return CLASS_BY_ID[Math.log2(mask) + 1] || null;
}

function loadGame(dir) {
	const g = { name: new Map(), attr: new Map(), cd: new Map(), charges: new Map(), sla: new Map(),
		talent: new Map(), pvp: new Set(), spec: new Map(), lineOwner: new Map() };

	eachRow(dir, 'SpellName', (r) => g.name.set(int(r('ID')), r('Name_lang')));

	// difficulty 0, else the lowest difficulty listed
	const attrDiff = new Map();
	eachRow(dir, 'SpellMisc', (r) => {
		const id = int(r('SpellID'));
		const d = int(r('DifficultyID'));
		if (!attrDiff.has(id) || d < attrDiff.get(id)) {
			attrDiff.set(id, d);
			g.attr.set(id, u32(r('Attributes_0')));
		}
	});
	eachRow(dir, 'SpellCooldowns', (r) => {
		if (int(r('DifficultyID')) !== 0) return;
		g.cd.set(int(r('SpellID')), Math.max(int(r('RecoveryTime')), int(r('CategoryRecoveryTime'))));
	});
	const cat = new Map();
	eachRow(dir, 'SpellCategory', (r) => cat.set(int(r('ID')), { max: int(r('MaxCharges')), recovery: int(r('ChargeRecoveryTime')) }));
	eachRow(dir, 'SpellCategories', (r) => {
		if (int(r('DifficultyID')) !== 0) return;
		const c = cat.get(int(r('ChargeCategory')));
		if (c) g.charges.set(int(r('SpellID')), c);
	});
	const family = new Map();
	eachRow(dir, 'SpellClassOptions', (r) => family.set(int(r('SpellID')), int(r('SpellClassSet'))));
	const familyClass = (sid) => CLASS_BY_FAMILY[family.get(sid)] || null;

	// skill lines: class lines (category 7, one class), racial lines, pet lines
	const lineClasses = new Map();
	eachRow(dir, 'SkillRaceClassInfo', (r) => {
		const id = int(r('SkillID'));
		if (!lineClasses.has(id)) lineClasses.set(id, new Set());
		const c = singleClass(r('ClassMask'));
		if (c) lineClasses.get(id).add(c);
	});
	eachRow(dir, 'SkillLine', (r) => {
		const id = int(r('ID'));
		const name = r('DisplayName_lang') || '';
		const category = int(r('CategoryID'));
		if (name.startsWith('Pet - ') || name === 'Beetle') {
			const pet = name.startsWith('Pet - ') ? name.slice(6) : name;
			if (WARLOCK_PETS.some((w) => pet.startsWith(w))) g.lineOwner.set(id, ['PET', 'WARLOCK']);
			else if (pet.startsWith('Ghoul') || pet.startsWith('Abomination')) g.lineOwner.set(id, ['PET', 'DEATHKNIGHT']);
			else g.lineOwner.set(id, ['PET', 'HUNTER']);
		} else if (category === 9 && name.includes('Racial')) {
			g.lineOwner.set(id, ['RACIAL', null]);
		} else if (category === 7) {
			const cs = lineClasses.get(id);
			if (cs && cs.size === 1) g.lineOwner.set(id, ['CLASS', [...cs][0]]);
		}
	});
	eachRow(dir, 'SkillLineAbility', (r) => {
		const sid = int(r('Spell'));
		if (!g.sla.has(sid)) g.sla.set(sid, []);
		g.sla.get(sid).push({ line: int(r('SkillLine')), classMask: r('ClassMask') });
	});

	// talents, talent trees, PvP talents, specialization spells
	const tabClass = new Map();
	eachRow(dir, 'TalentTab', (r) => tabClass.set(int(r('ID')), singleClass(r('ClassMask'))));
	eachRow(dir, 'Talent', (r) => {
		const cls = CLASS_BY_ID[int(r('ClassID'))] || tabClass.get(int(r('TabID'))) || null;
		const ids = [int(r('SpellID'))];
		for (let k = 0; k <= 8; k++) ids.push(int(r('SpellRank_' + k)));
		for (const sid of ids) if (sid) g.talent.set(sid, cls || familyClass(sid));
	});
	eachRow(dir, 'TraitDefinition', (r) => {
		const sid = int(r('SpellID'));
		if (sid && !g.talent.has(sid)) g.talent.set(sid, familyClass(sid));
	});
	eachRow(dir, 'PvpTalent', (r) => {
		const sid = int(r('SpellID'));
		if (!sid) return;
		g.pvp.add(sid);
		if (!g.talent.has(sid)) g.talent.set(sid, familyClass(sid));
	});
	const specClass = new Map();
	eachRow(dir, 'ChrSpecialization', (r) => specClass.set(int(r('ID')), CLASS_BY_ID[int(r('ClassID'))] || null));
	eachRow(dir, 'SpecializationSpells', (r) => {
		const sid = int(r('SpellID'));
		if (sid) g.spec.set(sid, specClass.get(int(r('SpecID'))) || null);
	});
	return g;
}

// who can use a spell: [kind, class] pairs (kind CLASS / PET / RACIAL)
function owners(g, sid) {
	const out = new Map();
	for (const a of g.sla.get(sid) || []) {
		const o = g.lineOwner.get(a.line);
		if (!o) continue;
		let [kind, cls] = o;
		if (kind === 'CLASS' && !cls) cls = singleClass(a.classMask);
		out.set(kind + ':' + cls, [kind, cls]);
	}
	if (g.talent.get(sid)) out.set('CLASS:' + g.talent.get(sid), ['CLASS', g.talent.get(sid)]);
	if (g.spec.get(sid)) out.set('CLASS:' + g.spec.get(sid), ['CLASS', g.spec.get(sid)]);
	return [...out.values()];
}

// ---------- the addon's lists, from the real code ----------
function loadLists(client) {
	const L = lauxlib.luaL_newstate();
	lualib.luaL_openlibs(L);
	lua.lua_pushstring(L, to_luastring(src.replace(/\\/g, '/')));
	lua.lua_setglobal(L, to_luastring('HARNESS_SRC'));
	lua.lua_pushinteger(L, client.interface);
	lua.lua_setglobal(L, to_luastring('HARNESS_TOC'));
	lua.lua_pushstring(L, to_luastring(client.classes.join(',')));
	lua.lua_setglobal(L, to_luastring('HARNESS_CLASSES'));
	const code = fs.readFileSync(path.join(HERE, 'harness.lua'));
	if (lauxlib.luaL_loadbuffer(L, code, null, to_luastring('harness.lua')) !== lua.LUA_OK ||
		lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
		throw new Error('Lua error loading ' + src + ' at interface ' + client.interface + ': ' + lua.lua_tojsstring(L, -1));
	}
	lua.lua_getglobal(L, to_luastring('HARNESS_OUT'));
	return JSON.parse(lua.lua_tojsstring(L, -1));
}

// ---------- checks ----------
function check(client, g, lists) {
	const r = { missing: [], name: [], bCD: [], oaf: [], unlisted: [], checked: 0, onEvent: 0 };
	const classes = Object.keys(lists);
	const inAll = (id) => classes.every((c) => lists[c].some((e) => e.id === id));
	const label = (cls, id) => (classes.length > 1 && inAll(id) ? 'all classes' : cls);

	const seen = new Set();
	for (const cls of classes) {
		for (const e of lists[cls]) {
			const key = e.id + '|' + e.name;
			if (seen.has(key)) continue;
			seen.add(key);
			r.checked++;
			const who = label(cls, e.id);
			if (!g.name.has(e.id)) {
				r.missing.push(`${e.id} ${e.name} [${who}]`);
				continue;
			}
			if (g.name.get(e.id) !== e.name) r.name.push(`${e.id} ${e.name} [${who}]: game name "${g.name.get(e.id)}"`);
			const cd = g.cd.get(e.id) || 0;
			if (e.bCD !== cd) r.bCD.push(`${e.id} ${e.name} [${who}]: list ${e.bCD}, game ${cd}`);
			const bit = ((g.attr.get(e.id) || 0) & STARTS_ON_EVENT) !== 0;
			if (e.oaf !== bit) r.oaf.push(`${e.id} ${e.name} [${who}]: list oaf ${e.oaf}, game ${bit ? 'starts on event' : 'normal cooldown'}`);
		}
	}

	// player, pet and racial spells whose cooldown starts on an event, with a cooldown over 3 s
	const racials = classes.flatMap((c) => lists[c].filter((e) => e.race !== undefined));
	const candidates = new Set([...g.sla.keys(), ...g.talent.keys(), ...g.spec.keys()]);
	for (const sid of [...candidates].sort((a, b) => a - b)) {
		const attr = g.attr.get(sid);
		if (attr === undefined || !(attr & STARTS_ON_EVENT) || (attr & PASSIVE)) continue;
		const cd = g.cd.get(sid) || 0;
		const ch = g.charges.get(sid);
		const chargeCD = ch && ch.max > 1 ? ch.recovery : 0;
		if (cd <= MIN_CD && chargeCD <= MIN_CD) continue;
		for (const [kind, cls] of owners(g, sid)) {
			if (!cls && kind !== 'RACIAL') continue;
			r.onEvent++;
			const pool = kind === 'RACIAL' ? racials : (lists[cls] || []);
			const listed = pool.filter((e) => e.id === sid);
			if (listed.some((e) => e.oaf)) continue;
			const who = kind === 'RACIAL' ? 'racial' : kind === 'PET' ? cls + ' pet' : cls;
			const how = listed.length ? 'listed without oaf' : 'not listed';
			r.unlisted.push(`${sid} ${g.name.get(sid)} [${who}]: ${how}, cooldown ${cd}${g.pvp.has(sid) ? ' (PvP talent)' : ''}`);
		}
	}
	return r;
}

const KINDS = [['missing', 'missing IDs'], ['name', 'name mismatches'], ['bCD', 'bCD mismatches'],
	['oaf', 'oaf mismatches'], ['unlisted', 'on-event spells not listed']];

async function main() {
	console.log('Data.lua: ' + path.join(src, 'Data.lua'));
	let total = 0;
	const summary = [];
	for (const client of CLIENTS.filter((c) => !wanted.length || wanted.includes(c.key))) {
		const dir = await fetchTables(client.build, TABLES.concat(client.extraTables || []));
		const g = loadGame(dir);
		const res = check(client, g, loadLists(client));
		console.log(`\n== ${client.name} (interface ${client.interface}, build ${client.build})`);
		console.log(`   ${res.checked} list entries checked, ${res.onEvent} on-event spells found in the game data`);
		for (const [k, title] of KINDS) {
			console.log(`   ${title}: ${res[k].length}`);
			for (const line of res[k]) console.log('      ' + line);
			total += res[k].length;
		}
		summary.push([client.key].concat(KINDS.map(([k]) => res[k].length)));
	}
	console.log('\nclient    missing  name  bCD  oaf  unlisted');
	for (const s of summary) console.log(s[0].padEnd(9) + s.slice(1).map((v, k) => String(v).padStart([8, 6, 5, 5, 10][k])).join(''));
	process.exit(total ? 1 : 0);
}

main().catch((e) => {
	console.error(e.message || e);
	process.exit(2);
});
