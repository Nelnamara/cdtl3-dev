-- Filters cards of the 12 Nov 2026 feature panel: 4 (why an entry won't show, Show anyway, the
-- once-only auto-ignore note), 9 (Hide spells I don't know, Only for this spec), 14 (My spells,
-- Show only the ticked spells) and 30 (Pull from Cooldown Manager, Retail and Forever). Real files,
-- real AceDB, the real options tree and AceConfigDialog.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME, OTHER = PLAYER.guid, "Player-1-0000099"

CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {} } }

-- a spellbook with three cooldowns and one spell without; Ice Block has a cooldown but isn't in it
SPELLINFO[133] = { "Fireball", 135812 }
SPELLINFO[116] = { "Frostbolt", 135846 }
SPELLINFO[2139] = { "Counterspell", 135856 }
SPELLINFO[12051] = { "Evocation", 136075 }
SPELLINFO[1953] = { "Blink", 135736 }
SPELLINFO[45438] = { "Ice Block", 135841 }
local function fullBook()
	SPELLBOOK = { { id = 133, name = "Fireball" }, { id = 2139, name = "Counterspell" }, { id = 12051, name = "Evocation" },
		{ id = 1953, name = "Blink" }, { id = 116, name = "Frostbolt" } }
	for _, s in ipairs(SPELLBOOK) do KNOWN[s.id] = true end
end
fullBook()
BASECD[2139], BASECD[12051], BASECD[1953], BASECD[45438] = 24000, 120000, 15000, 300000

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end
local function clear(t) for k in pairs(t) do t[k] = nil end return t end
local function has(list, v) for _, x in pairs(list or {}) do if x == v then return true end end return false end
local function chatSince(n, text)
	for i = n + 1, #CHAT do
		if tostring(CHAT[i]):find(text, 1, true) then return true end
	end
	return false
end
local function T() return CDTL3.db.profile.tables end
local function G() return CDTL3.db.profile.global end
local function entry(id, name, kind, extra)
	local e = { id = id, name = name, type = kind, icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local function add(kind, e) table.insert(T()[kind], e); return e end
local function find(kind, name)
	for _, e in pairs(T()[kind]) do if e.name == name then return e end end
end
local function A(kind)
	local f = CDTL3:GetFullOptions().args.filters.args
	if kind == "customs" then return f.customs.args.saved.args end
	return f[kind].args
end
local function choose(kind, name)
	CDTL3.currentFilter[kind] = name
	CDTL3.currentFilterHidden[kind] = false
end
local function why(kind) local a = A(kind); if a.whyNotShowing.hidden({}) then return nil end return a.whyNotShowing.name({}) end
local function canShow(kind) return not A(kind).showAnyway.hidden({}) end
local function showAnyway(kind) local a = A(kind); xpcall(function() a.showAnyway.func({}) end, ERRH) end
local function cast(id) FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id .. "-" .. NOW, id) end
local function live(name) return CDTL3:GetExistingCooldown(name, "spells") end
local function parent(f) local p = f and f.icon:GetParent(); return p and p:GetName() end
local function count(kind, name) local n = 0 for _, e in pairs(T()[kind]) do if e.name == name then n = n + 1 end end return n end
local function wipeLive()
	for _, f in pairs(CDTL3.cooldowns) do CDTL3:SendToHolding(f); CDTL3:SendToBarHolding(f) end
	clear(CDTL3.cooldowns)
end
local lanes = CDTL3.db.profile.lanes

---------------------------------------------------------------- today's behaviour with nothing turned on
print("[defaults " .. FLAVOR .. "]")
do
	check("Hide spells I don't know off, Show only the ticked spells off", G().spells.hideUnknown == false and not CDTL3:OnlyTickedSpells())
	clear(T().spells)
	local plain = add("spells", entry(2139, "Counterspell", "spells", { bCD = 24000 }))
	local unknown = add("spells", entry(45438, "Ice Block", "spells", { bCD = 30000 }))
	local hand = add("spells", entry(12051, "Evocation", "spells", { bCD = 30000, ignored = true }))
	check("an entry the rules don't touch: IsIgnored is its own Ignored box", not CDTL3:IsIgnored(plain, "spells")
		and not CDTL3:IsIgnored(unknown, "spells") and CDTL3:IsIgnored(hand, "spells"))
	choose("spells", "Counterspell")
	check("nothing stops it: no reason line, no Show anyway", why("spells") == nil and not canShow("spells"))
	SPELLCD[2139] = { startTime = NOW, duration = 24, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	cast(2139)
	check("a cast still makes its icon on lane 1", parent(live("Counterspell")) == "CDTL3_Lane_1", tostring(parent(live("Counterspell"))))
	wipeLive()
	SPELLCD[2139] = nil
end

---------------------------------------------------------------- card 4: the reason line and Show anyway
print("[card 4 why it won't show " .. FLAVOR .. "]")
do
	clear(T().spells); clear(T().buffs); clear(T().items)
	lanes.lane1.mode.type = "LINEAR"
	lanes.lane1.mode.linear.max, lanes.lane1.mode.linear.hideTimeSurplus = 120, true

	add("spells", entry(9001, "Tiny", "spells", { bCD = 1500, ignored = true }))
	choose("spells", "Tiny")
	local w = why("spells")
	check("3 s or less: says so", w and w:find("Ignored automatically: its cooldown is 3 s or less", 1, true), tostring(w))
	check("  Show anyway offered (unticks Ignored)", canShow("spells") and A("spells").showAnyway.desc({}):find("Ignored", 1, true))
	showAnyway("spells")
	check("  Show anyway unticks Ignored; the line goes", find("spells", "Tiny").ignored == false and why("spells") == nil)

	G().buffs.ignoreThreshold = 120
	add("buffs", entry(7101, "Long Buff", "buffs", { bCD = 300000, ignored = true, lane = 2 }))
	choose("buffs", "Long Buff")
	w = why("buffs")
	check("over the threshold: names the 300 s duration and the Buffs threshold", w and w:find("its 300 s duration is over the Buffs Ignore Threshold (120 s)", 1, true), tostring(w))
	showAnyway("buffs")
	check("  Show anyway unticks Ignored", find("buffs", "Long Buff").ignored == false)

	add("spells", entry(9002, "By Hand", "spells", { bCD = 30000, ignored = true }))
	choose("spells", "By Hand")
	w = why("spells")
	check("ignored by hand: says so", w and w:find("Ignored by hand", 1, true), tostring(w))
	showAnyway("spells")
	check("  Show anyway unticks it", find("spells", "By Hand").ignored == false and why("spells") == nil)

	add("spells", entry(9003, "Long Spell", "spells", { bCD = 180000 }))
	choose("spells", "Long Spell")
	w = why("spells")
	check("Max Time + Hide Long Timers: names the lane setting to change", w and w:find("Lane 1's Max Time", 1, true)
		and w:find("Max Time to 180", 1, true) and w:find("Hide Long Timers", 1, true), tostring(w))
	check("  no Show anyway (it says which lane setting to change instead)", not canShow("spells"))
	check("  the lane is unchanged", lanes.lane1.mode.linear.max == 120 and lanes.lane1.mode.linear.hideTimeSurplus == true)
	find("spells", "Long Spell").setCustomCD, find("spells", "Long Spell").customCDTime = true, 60000
	check("  a Custom CD Time under Max Time: no line", why("spells") == nil)
	find("spells", "Long Spell").setCustomCD = false
	lanes.lane1.mode.linear.hideTimeSurplus = false
	check("  Hide Long Timers off: no line", why("spells") == nil)
	lanes.lane1.mode.linear.hideTimeSurplus = true

	add("spells", entry(9004, "Switched Off", "spells", { enabled = false }))
	choose("spells", "Switched Off")
	w = why("spells")
	check("Enabled unticked: says so", w and w:find("Enabled box", 1, true), tostring(w))
	showAnyway("spells")
	check("  Show anyway ticks Enabled", find("spells", "Switched Off").enabled == true and why("spells") == nil)

	add("items", entry(7201, "Use Trinket", "items", { itemID = 5001, itemName = "Shiny Trinket" }))
	G().items.enabled = false
	choose("items", "Shiny Trinket")
	w = why("items")
	check("type switched off: names Filters > Defaults", w and w:find("all Items are off", 1, true), tostring(w))
	showAnyway("items")
	check("  Show anyway switches Items back on", G().items.enabled == true and why("items") == nil)

	add("spells", entry(9005, "No Lane", "spells", { lane = 0 }))
	choose("spells", "No Lane")
	w = why("spells")
	check("Lane set to Hide: says so (and that its bar still shows)", w and w:find("Not on a lane", 1, true) and w:find("Bar Frame 1", 1, true), tostring(w))
	showAnyway("spells")
	check("  Show anyway puts it on the Spells Default Lane (1)", find("spells", "No Lane").lane == 1 and why("spells") == nil)
	find("spells", "No Lane").lane = 0
	lanes.lane1.enabled = false
	showAnyway("spells")
	check("  with lane 1 switched off: the first lane that's on (2)", find("spells", "No Lane").lane == 2, tostring(find("spells", "No Lane").lane))
	lanes.lane1.enabled = true

	add("spells", entry(9006, "Lane Three", "spells", { lane = 3 }))
	lanes.lane3.enabled = false
	choose("spells", "Lane Three")
	w = why("spells")
	check("lane switched off: names the lane", w and w:find("Lane 3 is switched off", 1, true), tostring(w))
	local e0 = #ERRORS
	showAnyway("spells")
	check("  Show anyway switches Lane 3 on", lanes.lane3.enabled == true and why("spells") == nil and #ERRORS == e0)

	-- Add New in Custom has no reason line
	CDTL3.currentFilter.customs = "<< Add New >>"
	check("Custom > Add New: no reason line", A("customs").whyNotShowing.hidden({}))

	-- the options window draws the line and the button
	add("spells", entry(9007, "Drawn", "spells", { bCD = 1000, ignored = true }))
	choose("spells", "Drawn")
	e0 = #ERRORS
	local ACD = LibStub("AceConfigDialog-3.0")
	xpcall(function() ACD:Open("CDTL3"); ACD:SelectGroup("CDTL3", "filters", "spells") end, ERRH)
	check("  the Spells tab draws with the reason line, no Lua errors", #ERRORS == e0, tostring(#ERRORS - e0))
	xpcall(function() ACD:Close("CDTL3") end, ERRH)
end

---------------------------------------------------------------- card 4: the first automatic ignore says so, once
print("[card 4 auto-ignore note " .. FLAVOR .. "]")
do
	clear(T().spells)
	CDTL3.db.global.autoIgnoreNoted = nil
	local n = #CHAT
	SPELLCD[2139] = { startTime = NOW, duration = 24, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	cast(2139)
	check("a new spell that isn't ignored: no note", not chatSince(n, "won't show") and not CDTL3.db.global.autoIgnoreNoted)
	cast(133)
	check("first automatic ignore (Fireball, no cooldown): one chat line", chatSince(n, "Fireball won't show: CDTL3 ignored it because its cooldown is 3 s or less"))
	check("  it says where to undo it", chatSince(n, "/cdtl3 filters") and chatSince(n, "Spells tab") and chatSince(n, "Show anyway"))
	check("  saved flag set (account-wide)", CDTL3.db.global.autoIgnoreNoted == true)
	n = #CHAT
	cast(116)
	check("the next automatic ignore (Frostbolt): no second note", find("spells", "Frostbolt") and find("spells", "Frostbolt").ignored and not chatSince(n, "won't show"))
	CDTL3.db.global.autoIgnoreNoted = nil
	n = #CHAT
	CDTL3:NoteAutoIgnore({ name = "Hearthstone", itemName = "Hearthstone", bCD = 0 }, "items")
	check("an item learned as no cooldown: names the Items tab", chatSince(n, "Hearthstone won't show") and chatSince(n, "Items tab"))
	CDTL3.db.global.autoIgnoreNoted = nil
	n = #CHAT
	CDTL3:NoteAutoIgnore({ name = "Mid", bCD = 60000 }, "spells")
	check("  nothing to say when the rule wouldn't ignore it", not chatSince(n, "won't show") and not CDTL3.db.global.autoIgnoreNoted)
	CDTL3.db.global.autoIgnoreNoted = true
	wipeLive()
	SPELLCD[2139] = nil
end

---------------------------------------------------------------- card 9: Hide spells I don't know
print("[card 9 hide spells I don't know " .. FLAVOR .. "]")
do
	clear(T().spells)
	local block = add("spells", entry(45438, "Ice Block", "spells", { bCD = 30000 }))
	local cs = add("spells", entry(2139, "Counterspell", "spells", { bCD = 24000 }))
	local blink = add("spells", entry(99999, "Blink", "spells", { bCD = 15000 }))	-- another rank's ID
	local a = A("spells")
	check("toggle off by default", a.hideUnknown.get({}) == false)
	a.hideUnknown.set({}, true)
	check("on: saved in the profile", G().spells.hideUnknown == true)
	check("  a spell this character doesn't know counts as ignored (its box untouched)", CDTL3:IsIgnored(block, "spells") and block.ignored == false)
	check("  a known spell isn't", not CDTL3:IsIgnored(cs, "spells"))
	check("  another rank of a spellbook spell isn't (known by name)", not CDTL3:IsIgnored(blink, "spells"))
	choose("spells", "Ice Block")
	local w = why("spells")
	check("  reason line says so, no Show anyway", w and w:find("doesn't know it right now", 1, true) and not canShow("spells"), tostring(w))

	-- a live icon of a spell that stops being known leaves the lane; it comes back when known again
	SPELLCD[2139] = { startTime = NOW, duration = 24, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	cast(2139)
	local f = live("Counterspell")
	check("  Counterspell cast: on lane 1", parent(f) == "CDTL3_Lane_1")
	KNOWN[2139] = false
	SPELLBOOK = { { id = 133, name = "Fireball" } }
	FireEvent("SPELLS_CHANGED")
	Advance(1.2)
	check("  talent swapped out (SPELLS_CHANGED): off its lane and bar frame", parent(f) == "CDTL3_Active_Icon_Holding"
		and f.bar:GetParent():GetName() == "CDTL3_Bar_Holding", tostring(parent(f)))
	cast(2139)
	check("  can't come back by a cast while unknown", parent(f) == "CDTL3_Active_Icon_Holding")
	fullBook()
	FireEvent("SPELLS_CHANGED")
	Advance(1.2)
	check("  known again: back on lane 1 while its cooldown runs", parent(f) == "CDTL3_Lane_1", tostring(parent(f)))
	a.hideUnknown.set({}, false)
	check("off: Ice Block shows like before", not CDTL3:IsIgnored(block, "spells") and G().spells.hideUnknown == false)
	wipeLive()
	SPELLCD[2139] = nil
end

---------------------------------------------------------------- card 9: Only for this spec
print("[card 9 only for this spec " .. FLAVOR .. "]")
do
	clear(T().spells)
	local evo = add("spells", entry(12051, "Evocation", "spells", { bCD = 120000 }))
	choose("spells", "Evocation")
	local a = A("spells")
	local specs = FLAVOR == "mop" or FLAVOR == "retail"
	check("specs only where the client has them", CDTL3:HasSpecs() == specs)
	if not specs then
		check("  Only for this spec hidden", a.onlyThisSpec.hidden({}))
		evo.onlySpecs = { 62 }
		check("  a spec list saved elsewhere hides nothing here", not CDTL3:IsIgnored(evo, "spells"))
		evo.onlySpecs = nil
	else
		local SPECS = { { 62, "Arcane" }, { 63, "Fire" } }
		SPEC = 1
		C_SpecializationInfo.GetSpecialization = function() return SPEC end
		C_SpecializationInfo.GetSpecializationInfo = function(i) local s = SPECS[i]; if s then return s[1], s[2] end end
		GetSpecializationInfoByID = function(id) for _, s in ipairs(SPECS) do if s[1] == id then return s[1], s[2] end end end
		check("  shown on a spell, named for the spec you're in", not a.onlyThisSpec.hidden({}) and a.onlyThisSpec.name({}) == "Only for this spec (Arcane)", a.onlyThisSpec.name({}))
		a.onlyThisSpec.set({}, true)
		check("  ticked: the spec ID saved on the entry", has(evo.onlySpecs, 62) and #evo.onlySpecs == 1 and a.onlyThisSpec.get({}))
		check("  named for its specs", a.onlyThisSpec.name({}) == "Only for Arcane", a.onlyThisSpec.name({}))
		check("  in that spec it shows", not CDTL3:IsIgnored(evo, "spells"))
		SPELLCD[12051] = { startTime = NOW, duration = 120, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
		cast(12051)
		local f = live("Evocation")
		check("  cast in Arcane: on lane 1", parent(f) == "CDTL3_Lane_1")
		SPEC = 2
		FireEvent("ACTIVE_TALENT_GROUP_CHANGED")
		Advance(2.2)
		check("  switched to Fire: counts as ignored, its icon leaves the lane", CDTL3:IsIgnored(evo, "spells") and parent(f) == "CDTL3_Active_Icon_Holding", tostring(parent(f)))
		local w = why("spells")
		check("  reason line names the spec", w and w:find("only for Arcane", 1, true), tostring(w))
		showAnyway("spells")
		check("  Show anyway adds Fire", has(evo.onlySpecs, 62) and has(evo.onlySpecs, 63) and not CDTL3:IsIgnored(evo, "spells"))
		check("  and the running icon is back on its lane", parent(f) == "CDTL3_Lane_1", tostring(parent(f)))
		a.onlyThisSpec.set({}, false)
		check("  unticked: every spec again", evo.onlySpecs == nil and not a.onlyThisSpec.get({}))
		SPEC = 0
		check("  no spec chosen yet: can't tick, nothing hidden", a.onlyThisSpec.disabled({}) and not CDTL3:IsIgnored(evo, "spells"))
		SPEC = 1
		wipeLive()
		SPELLCD[12051] = nil
	end
end

---------------------------------------------------------------- card 14: My spells and Show only the ticked spells
print("[card 14 my spells " .. FLAVOR .. "]")
do
	clear(T().spells)
	wipeLive()
	CDTL3:ForgetSpellbook()
	local a = A("spells")
	local my = a.mySpells.args.list
	local values = my.values({})
	local keys = {}
	for k in pairs(values) do keys[#keys + 1] = k end
	table.sort(keys)
	check("lists the spellbook's spells with a cooldown (not Fireball, not Ice Block)", table.concat(keys, ",") == "Blink,Counterspell,Evocation", table.concat(keys, ","))
	check("  with icons", values["Blink"] and values["Blink"]:find("|T135736:16", 1, true) and values["Blink"]:find("Blink", 1, true), tostring(values["Blink"]))

	local n0 = #CDTL3.cooldowns
	my.set({}, "Blink", true)
	local blink = find("spells", "Blink")
	check("ticking one never cast makes its entry", blink and blink.id == 1953 and blink.bCD == 15000 and has(blink.usedBy, ME) and has(blink.pickedBy, ME))
	check("  shown: not ignored, on the Spells Default Lane", blink and blink.ignored == false and blink.lane == G().spells.defaultLane)
	check("  no icon made before it's cast", #CDTL3.cooldowns == n0 and not live("Blink"))
	check("  ticked in the list", my.get({}, "Blink") == true)
	check("  listed in Filters > Spells", CDTL3:LoadFilterList("spells")["Blink"] == "Blink")

	local evo = add("spells", entry(12051, "Evocation", "spells", { bCD = 120000, usedBy = { OTHER }, lane = 3, ignored = true, setCustomCD = true, customCDTime = 60000 }))
	my.set({}, "Evocation", true)
	check("ticking a saved one claims it for this character", has(evo.usedBy, ME) and has(evo.usedBy, OTHER) and has(evo.pickedBy, ME))
	check("  un-ignores it and keeps its settings", evo.ignored == false and evo.lane == 3 and evo.customCDTime == 60000 and count("spells", "Evocation") == 1)

	local cs = add("spells", entry(2139, "Counterspell", "spells", { bCD = 24000, lane = 2 }))
	check("Show only the ticked spells off: unticked ones show as before", not CDTL3:IsIgnored(cs, "spells"))
	SPELLCD[2139] = { startTime = NOW, duration = 24, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	cast(2139)
	local f = live("Counterspell")
	check("  Counterspell cast: on lane 2", parent(f) == "CDTL3_Lane_2")
	a.onlyTicked.set({}, true)
	check("on: saved for this character", CDTL3.db.char.onlyTickedSpells == true and a.onlyTicked.get({}))
	check("  an unticked spell counts as ignored, its own settings untouched", CDTL3:IsIgnored(cs, "spells") and cs.ignored == false and cs.lane == 2)
	check("  its running icon leaves the lane", parent(f) == "CDTL3_Active_Icon_Holding", tostring(parent(f)))
	cast(2139)
	check("  a cast doesn't bring it back", parent(f) == "CDTL3_Active_Icon_Holding")
	SPELLCD[1953] = { startTime = NOW, duration = 15, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	cast(1953)
	check("  a ticked spell's cast shows it", parent(live("Blink")) == "CDTL3_Lane_1", tostring(parent(live("Blink"))))
	choose("spells", "Counterspell")
	local w = why("spells")
	check("  reason line says it isn't ticked", w and w:find("isn't ticked in My spells", 1, true), tostring(w))
	showAnyway("spells")
	check("  Show anyway ticks it, and its icon is back", has(cs.pickedBy, ME) and not CDTL3:IsIgnored(cs, "spells") and parent(f) == "CDTL3_Lane_2", tostring(parent(f)))
	my.set({}, "Counterspell", false)
	check("unticking keeps the entry and its settings", find("spells", "Counterspell") and cs.pickedBy == nil and cs.lane == 2 and CDTL3:IsIgnored(cs, "spells"))

	local theirs = add("spells", entry(5555, "Their Pick", "spells", { pickedBy = { OTHER }, usedBy = { ME, OTHER } }))
	check("another character's tick doesn't count for this one", CDTL3:IsIgnored(theirs, "spells"))

	-- a ticked spell the spellbook no longer lists stays in the list, so it can be unticked
	KNOWN[1953] = false
	SPELLBOOK = { { id = 133, name = "Fireball" }, { id = 2139, name = "Counterspell" }, { id = 12051, name = "Evocation" } }
	FireEvent("SPELLS_CHANGED")
	Advance(1.2)
	values = my.values({})
	check("a ticked spell gone from the spellbook stays listed, marked", values["Blink"] and values["Blink"]:find("not in your spellbook", 1, true), tostring(values["Blink"]))
	fullBook()
	FireEvent("SPELLS_CHANGED")
	Advance(1.2)

	a.onlyTicked.set({}, false)
	check("off: every spell shows again", not CDTL3:IsIgnored(cs, "spells") and not CDTL3:IsIgnored(theirs, "spells") and CDTL3.db.char.onlyTickedSpells == nil)

	local e0 = #ERRORS
	local ACD = LibStub("AceConfigDialog-3.0")
	choose("spells", "Evocation")
	xpcall(function() ACD:Open("CDTL3"); ACD:SelectGroup("CDTL3", "filters", "spells") end, ERRH)
	check("the Spells tab draws My spells and the rules, no Lua errors", #ERRORS == e0, tostring(#ERRORS - e0))
	xpcall(function() ACD:Close("CDTL3") end, ERRH)
	wipeLive()
	SPELLCD[2139], SPELLCD[1953] = nil, nil
end

---------------------------------------------------------------- card 30: Pull from Cooldown Manager
print("[card 30 pull from Cooldown Manager " .. FLAVOR .. "]")
do
	local CT = CDTL3.CombatTimers
	local a = A("buffs")
	check("no Cooldown Manager here: button hidden, nothing pulled", a.pullCooldownManager.hidden({}) and CDTL3:PullTrackedBuffs() == nil)

	if RETAILAPI then
		-- just enough of the Cooldown Manager for Tracked Bars (installed for this block only)
		local keep = { csd = C_Spell.GetSpellCooldownDuration, curve = C_CurveUtil, dur = C_DurationUtil, viewer = C_CooldownViewer, cvar = C_CVar.GetCVar }
		local function install()
			C_Spell.GetSpellCooldownDuration = function() return nil end
			C_CurveUtil, C_DurationUtil = {}, {}
			C_CooldownViewer = {
				IsCooldownViewerAvailable = function() return true, "" end,
				GetCooldownViewerCategorySet = function(cat) if cat == 3 then return { 301, 302, 303 } end return {} end,
				GetCooldownViewerCooldownInfo = function(id) return INFO[id] end,
			}
			Enum.CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 }
			C_CVar.GetCVar = function(name) if name == "cooldownViewerEnabled" then return VIEWER_ON end return "0" end
		end
		local function remove()
			C_Spell.GetSpellCooldownDuration, C_CurveUtil, C_DurationUtil, C_CooldownViewer = keep.csd, keep.curve, keep.dur, keep.viewer
			C_CVar.GetCVar = keep.cvar
		end
		SPELLINFO[7001] = { "Ice Barrier", 135988 }
		SPELLINFO[7002] = { "Arcane Power", 136048 }
		SPELLINFO[7003] = { "Arcane Surge", 136048 }
		SPELLINFO[7004] = { "Presence Buff", 136031 }
		INFO = {
			[301] = { cooldownID = 301, spellID = 7001, hasAura = true },
			[302] = { cooldownID = 302, spellID = 7002, linkedSpellIDs = { 7003 }, hasAura = true },
			[303] = { cooldownID = 303, spellID = 7004, hasAura = true },
		}
		VIEWER_ON = "1"
		clear(T().buffs)
		local surge = add("buffs", entry(7003, "Arcane Surge", "buffs", { usedBy = { OTHER }, ignored = true, lane = 3, bCD = 15000 }))
		add("buffs", entry(7010, "Mana Shield", "buffs", { lane = 2, bCD = 60000 }))
		add("buffs", entry(7011, "Old Buff", "buffs", { lane = 2, ignored = true }))
		AURAS = { HELPFUL = { { name = "Presence Buff", spellId = 7004, duration = 20, expirationTime = NOW + 15, applications = 0, icon = 136031 } } }

		install()
		check("Retail and Forever: button shown", not a.pullCooldownManager.hidden({}))
		local bars = CT:TrackedBarBuffs()
		check("Tracked Bars read with their spells", bars and #bars == 3 and bars[2].name == "Arcane Power" and bars[2].names[2] == "Arcane Surge" and bars[1].spellID == 7001)
		check("  before pulling, the list of buffs not tracked shows", not a.notInTrackedBars.hidden({}) and a.notInTrackedBars.name({}):find("Mana Shield", 1, true))
		local n = #CHAT
		local e0 = #ERRORS
		xpcall(function() a.pullCooldownManager.func({}) end, ERRH)
		remove()
		check("pulled with no Lua errors", #ERRORS == e0, tostring(#ERRORS - e0))
		local ice = find("buffs", "Ice Barrier")
		check("a Tracked Bars buff never seen: entry made for this character", ice and ice.id == 7001 and has(ice.usedBy, ME) and ice.cdmPulled == true)
		check("  assigned: Buffs default lane, bar frame and Ready frame, not ignored", ice and ice.lane == G().buffs.defaultLane
			and ice.barFrame == G().buffs.defaultBar and ice.readyFrame == G().buffs.defaultReady and ice.ignored == false)
		check("  no icon yet (not on you), length to learn", ice and ice.bCD == 0 and not CDTL3:GetExistingCooldown("Ice Barrier", "buffs"))
		check("a saved one (under a linked spell's name) claimed, un-ignored, its lane kept, not doubled",
			has(surge.usedBy, ME) and has(surge.usedBy, OTHER) and surge.ignored == false and surge.lane == 3
			and count("buffs", "Arcane Surge") == 1 and count("buffs", "Arcane Power") == 0)
		local pres = find("buffs", "Presence Buff")
		check("a buff on you now: its length read and its icon shown", pres and pres.bCD == 20000 and CDTL3:GetExistingCooldown("Presence Buff", "buffs"))
		check("chat: what was pulled", chatSince(n, "Pulled 3 buffs from the Cooldown Manager's Tracked Bars: 2 new, 1 already saved."))
		check("chat: the buffs not in Tracked Bars (not the ignored one)", chatSince(n, "Not in Tracked Bars, so estimated in combat: Mana Shield.") and not chatSince(n, "Old Buff"))
		check("listed in Filters > Buffs", CDTL3:LoadFilterList("buffs")["Ice Barrier"] and CDTL3:LoadFilterList("buffs")["Arcane Surge"])

		install()
		local again = CDTL3:PullTrackedBuffs()
		remove()
		check("pulling again makes nothing twice", again and #again.made == 0 and #again.claimed == 3 and count("buffs", "Ice Barrier") == 1)

		-- the pulled buff learns its length the first time it's seen
		AURAS.HELPFUL[2] = { name = "Ice Barrier", spellId = 7001, duration = 60, expirationTime = NOW + 60, applications = 0, icon = 135988 }
		CDTL3:OnPlayerAuraApplied(7001, "Ice Barrier", "buffs", true)
		local f = CDTL3:GetExistingCooldown("Ice Barrier", "buffs")
		check("first sighting: length learned (60 s) and its icon shown", ice.bCD == 60000 and f and f.data.baseCD == 60, tostring(ice.bCD))

		VIEWER_ON = "0"
		install()
		n = #CHAT
		xpcall(function() a.pullCooldownManager.func({}) end, ERRH)
		check("Cooldown Manager switched off: the list hides, chat says to turn it on", a.notInTrackedBars.hidden({}) and chatSince(n, "switched off"))
		INFO = {}
		n = #CHAT
		xpcall(function() a.pullCooldownManager.func({}) end, ERRH)
		check("no Tracked Bars yet: chat says where to add them", chatSince(n, "have no buffs yet"))
		e0 = #ERRORS
		local ACD = LibStub("AceConfigDialog-3.0")
		xpcall(function() ACD:Open("CDTL3"); ACD:SelectGroup("CDTL3", "filters", "buffs") end, ERRH)
		check("the Buffs tab draws the button, no Lua errors", #ERRORS == e0, tostring(#ERRORS - e0))
		xpcall(function() ACD:Close("CDTL3") end, ERRH)
		remove()
		AURAS = nil
		check("fakes removed: hidden again", a.pullCooldownManager.hidden({}))
	end
end

---------------------------------------------------------------- frames keep running
do
	local e0 = #ERRORS
	RunOnUpdate(0.05, 60)
	check("60 frames afterwards: no Lua errors", #ERRORS == e0, tostring(#ERRORS - e0))
end

for i = base + 1, #ERRORS do print("  ERROR " .. tostring(ERRORS[i])) end
print(string.format("RESULT filtercards %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
