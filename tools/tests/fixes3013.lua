-- 3.0.13 fix cases: (1) Custom CD Time counts from the cast on spells the game gives no cooldown,
-- (2) custom timers with the "spell" trigger fire for spells you know, (3) a buff recast while
-- auras are secret restarts the buff (an estimate). Real files, real AceDB, real event handlers.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME = PLAYER.guid

CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {} } }

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end
local g = CDTL3.db.profile.global
local tables = CDTL3.db.profile.tables
for _, t in ipairs({ "spells", "buffs", "customs" }) do g[t]["ignoreThreshold"] = 1800 end
local function entry(id, name, type, extra)
	local e = { id = id, name = name, type = type, icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local function clear(t) for k in pairs(t) do t[k] = nil end end
local function live(name, type) return CDTL3:GetExistingCooldown(name, type) end
local function reset()
	for _, t in ipairs({ "spells", "buffs", "customs", "detected" }) do clear(tables[t]) end
	for i = #CDTL3.cooldowns, 1, -1 do
		local cd = CDTL3.cooldowns[i]
		if cd.icon and cd.icon.Hide then pcall(cd.icon.Hide, cd.icon) end
		table.remove(CDTL3.cooldowns, i)
	end
	CDTL3.spellCastTimes = {}
	TARGET = nil
	SECRET_AURAS = false
	AURAS = { HELPFUL = {}, HARMFUL = {} }
	SPELLBOOK = {}
	clear(SPELLCD)
end
local function declare(id, name, bcd)
	SPELLINFO[id] = { name, 136000 }
	KNOWN[id] = true
	BASECD[id] = bcd or 0
end
local function cast(id) FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id, id) end
local function poll(f, seconds)
	for _ = 1, math.floor(seconds / 0.02 + 0.5) do NOW = NOW + 0.02; f.__scripts.OnUpdate(f, 0.02) end
end
local function secretCD(onGCD) return { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = true, isOnGCD = onGCD } end
local base = #ERRORS

---------------------------------------------------------------- 1. Custom CD Time without a game cooldown
print("[custom cd " .. FLAVOR .. "]")
local nextId = 770000
local function customCase(label, oaf, secret)
	reset()
	nextId = nextId + 1
	local id, name = nextId, "Seal Test " .. label
	declare(id, name, 0)
	table.insert(tables.spells, entry(id, name, "spells", { bCD = 0, setCustomCD = true, customCDTime = 30000, oaf = oaf or nil }))
	SPELLCD[id] = { startTime = NOW, duration = 1.5, isEnabled = true, isActive = true, isOnGCD = true }  -- the GCD right after the cast
	cast(id)
	local f = live(name, "spells")
	check(label .. ": cast starts the icon", f ~= nil)
	if not f then return end
	check(label .. ": cast time recorded", CDTL3.spellCastTimes[id] == NOW)
	poll(f, 2)
	SPELLCD[id] = secret and secretCD(true) or nil   -- GCD over: no cooldown (secret: still flagged on-GCD)
	poll(f, 3)
	check(label .. ": ~5 s in, ~25 s left", math.abs(f.data.currentCD - 25) < 1.2, string.format("currentCD=%.2f", f.data.currentCD))
	check(label .. ": baseCD is the custom time", math.abs(f.data.baseCD - 30) < 1e-6, tostring(f.data.baseCD))
	poll(f, 26)
	check(label .. ": 31 s in, finished", f.data.currentCD <= 0, string.format("currentCD=%.2f", f.data.currentCD))
end
customCase("plain", false, false)
customCase("oaf", true, false)
if RETAILAPI then
	customCase("secret (not in combat)", false, true)
	SECRET_AURAS = true
	customCase("secret", false, true)
	customCase("secret oaf", true, true)
end

-- a real game cooldown still wins over the cast time
do
	reset()
	local id, name = 770100, "Real CD Test"
	declare(id, name, 60000)
	table.insert(tables.spells, entry(id, name, "spells", { bCD = 60000, setCustomCD = true, customCDTime = 30000 }))
	SPELLCD[id] = { startTime = NOW - 10, duration = 60, isEnabled = true, isActive = true, isOnGCD = false }
	cast(id)
	local f = live(name, "spells")
	check("real cooldown: icon exists", f ~= nil)
	if f then
		poll(f, 0.02)
		check("real cooldown + custom 30 s: counts from the game's start (~20 s, not 30)", math.abs(f.data.currentCD - 20) < 1.2, string.format("currentCD=%.2f", f.data.currentCD))
		poll(f, 3)
		check("real cooldown: ~17 s left 3 s later", math.abs(f.data.currentCD - 17) < 1.2, string.format("currentCD=%.2f", f.data.currentCD))
	end
end

---------------------------------------------------------------- 2. custom timer with the "spell" trigger
print("[custom trigger " .. FLAVOR .. "]")
do
	reset()
	local id, name = 770200, "Trigger Known"
	declare(id, name, 10000)
	table.insert(tables.customs, entry(880200, name, "customs", { bCD = 20000, triggerType = "spell" }))
	check("custom spell trigger: no customs icon before the cast", live(name, "customs") == nil)
	cast(id)
	local cf = live(name, "customs")
	check("known spell cast creates the customs cooldown", cf ~= nil)
	if cf then
		poll(cf, 5)
		local before = cf.data.currentCD
		cast(id)
		check("second cast: same customs frame (no duplicate)", live(name, "customs") == cf)
		check("second cast: customs cooldown restarted", cf.data.currentCD > before + 3 or cf.data.currentCD >= cf.data.baseCD - 0.5,
			string.format("before=%.2f after=%.2f base=%s", before, cf.data.currentCD, tostring(cf.data.baseCD)))
	end
	check("known spell still gets its own spells entry", CDTL3:GetSpellSettings(name, "spells") ~= nil)
	check("known spell not recorded as detected", CDTL3:GetSpellSettings(name, "detected") == nil)

	-- ignored custom timer: matched, but no icon
	reset()
	declare(id, name, 10000)
	table.insert(tables.customs, entry(880200, name, "customs", { bCD = 20000, triggerType = "spell", ignored = true }))
	cast(id)
	check("ignored custom spell trigger: no customs icon", live(name, "customs") == nil)

	-- a custom timer of another trigger type is not fired by the cast
	reset()
	declare(id, name, 10000)
	table.insert(tables.customs, entry(880200, name, "customs", { bCD = 20000, triggerType = "aura" }))
	cast(id)
	check("custom aura trigger: a cast does not start it", live(name, "customs") == nil)

	-- unknown spell, no custom trigger: recorded as detected
	reset()
	g["customDetection"] = true
	local uid, uname = 770201, "Unknown Spell A"
	SPELLINFO[uid] = { uname, 136000 }; KNOWN[uid] = false; BASECD[uid] = 30000
	cast(uid)
	check("unknown spell, no trigger, customDetection on: recorded as detected", CDTL3:GetSpellSettings(uname, "detected") ~= nil)
	check("unknown spell, no trigger: no customs icon", live(uname, "customs") == nil)

	-- unknown spell matching a custom trigger: customs fires, not recorded as detected
	reset()
	local mid, mname = 770202, "Unknown Spell B"
	SPELLINFO[mid] = { mname, 136000 }; KNOWN[mid] = false; BASECD[mid] = 30000
	table.insert(tables.customs, entry(880202, mname, "customs", { bCD = 20000, triggerType = "spell" }))
	cast(mid)
	check("unknown spell matching a custom trigger: customs icon", live(mname, "customs") ~= nil)
	check("unknown spell matching a custom trigger: not recorded as detected", CDTL3:GetSpellSettings(mname, "detected") == nil)
	g["customDetection"] = false
end

---------------------------------------------------------------- 3. buff recast while auras are secret
print("[buff recast " .. FLAVOR .. "]")
local function buffSetup(extra)
	reset()
	local id, name = 770300, "Buff Recast"
	declare(id, name, 0)
	local s = entry(990300, name, "buffs", extra or { bCD = 60000 })
	table.insert(tables.buffs, s)
	return id, name, s
end
-- a buff frame 20 s into a 60 s buff. Retail-API clients read it from a real aura (readable
-- at this point); Classic clients have no aura stub, so the frame is set running by hand.
local function liveBuff(s)
	if RETAILAPI then
		AURAS = { HELPFUL = { { name = s.name, spellId = s.id, duration = 60, icon = 136000, applications = 0, expirationTime = NOW + 60 } }, HARMFUL = {} }
	end
	local f = CDTL3:CreateCooldown(CDTL3:GetUID(), "buffs", s)
	poll(f, 0.02)
	if not RETAILAPI then f.data.currentCD = 60 end
	poll(f, 20)
	AURAS = { HELPFUL = {}, HARMFUL = {} }
	return f
end
if RETAILAPI then
	do
		local id, name, s = buffSetup()
		local f = liveBuff(s)
		check("setup: live buff frame partway (~40 s left)", f.data.currentCD < 45 and f.data.currentCD > 35, string.format("%.2f", f.data.currentCD))
		SECRET_AURAS = true
		check("AurasAreSecret() is true", CDTL3:AurasAreSecret() == true)
		cast(id)
		check("secret auras: recast restarts the live buff to baseCD", f.data.currentCD >= f.data.baseCD - 0.5 and f.data.baseCD == 60,
			string.format("currentCD=%.2f baseCD=%s", f.data.currentCD, tostring(f.data.baseCD)))
		check("secret auras: still one buff frame", live(name, "buffs") == f)
	end
	do
		local id, name = buffSetup()
		SECRET_AURAS = true
		check("no live frame before the cast", live(name, "buffs") == nil)
		cast(id)
		check("secret auras, no live frame: cast creates one", live(name, "buffs") ~= nil)
	end
	do
		local id, name, s = buffSetup()
		local f = liveBuff(s)
		local before = f.data.currentCD
		SECRET_AURAS = false
		cast(id)
		check("readable auras: cast leaves the live buff alone", live(name, "buffs") == f and f.data.currentCD <= before + 0.01, string.format("before=%.2f after=%.2f", before, f.data.currentCD))
		buffSetup(); cast(id)
		check("readable auras, no frame: cast creates none", live(name, "buffs") == nil)
	end
	for _, tcase in ipairs({
		{ "friendly player targeted", "friend", false },
		{ "self targeted", "self", true },
		{ "enemy targeted", "enemy", true },
		{ "no target", nil, true },
	}) do
		local id, name, s = buffSetup()
		local f = liveBuff(s)
		local before = f.data.currentCD
		SECRET_AURAS = true
		TARGET = tcase[2]
		cast(id)
		check("secret auras, " .. tcase[1] .. ": " .. (tcase[3] and "restarts" or "does NOT restart"), (f.data.currentCD > before + 3) == tcase[3],
			string.format("before=%.2f after=%.2f", before, f.data.currentCD))
		if not tcase[3] then
			buffSetup(); SECRET_AURAS = true; TARGET = tcase[2]; cast(id)
			check("secret auras, " .. tcase[1] .. ", no frame: none created", live(name, "buffs") == nil)
		end
	end
	do
		local id, name = buffSetup({ bCD = 0 })
		SECRET_AURAS = true
		cast(id)
		check("secret auras, bCD 0: no buff frame", live(name, "buffs") == nil)
		id, name = buffSetup({ bCD = 60000, ignored = true })
		SECRET_AURAS = true
		cast(id)
		check("secret auras, ignored buff: no buff frame", live(name, "buffs") == nil)
		reset()
		declare(770301, "Not Saved", 0)
		SECRET_AURAS = true
		cast(770301)
		check("secret auras, spell with no saved buff: no buff frame", live("Not Saved", "buffs") == nil)
	end
else
	local id, name, s = buffSetup()
	local f = liveBuff(s)
	local before = f.data.currentCD
	-- Classic clients have no C_Secrets at all (the stub exists on every flavour), so remove it
	local stubSecrets = C_Secrets
	C_Secrets = nil
	check("AurasAreSecret() is false on this client", CDTL3:AurasAreSecret() == false)
	cast(id)
	check("cast does not restart a live buff", live(name, "buffs") == f and f.data.currentCD <= before + 0.01, string.format("before=%.2f after=%.2f", before, f.data.currentCD))
	buffSetup(); cast(id)
	check("cast creates no buff frame", live(name, "buffs") == nil)
	C_Secrets = stubSecrets
end
SECRET_AURAS = false

print(string.format("RESULT fixes3013 %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
