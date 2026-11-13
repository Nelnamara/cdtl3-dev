-- Profiles (feature panel card 39). Real files, real AceDB / AceDBOptions / LibDualSpec:
--   new characters: the Default profile (as before), the last profile used, or a chosen one
--   shared entries: off by default and nothing changes; on copies this profile's lists into the
--     account-wide ones, every profile then uses them; off gives the profile a copy; round trips;
--     other profiles join and get them back; Copy From, Reset Profile and imports while shared;
--     a logout saves each table once, and a reload finds everything again
--   profiles by zone: raid, dungeon (party, scenario), PvP (battleground, arena), open world; back
--     afterwards; a hand-picked profile stays; waits out combat; zone profiles win over spec profiles
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME, MAIN, ALT = PLAYER.guid, "Player-1-0000050", "Player-1-0000060"

local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end
local function chatSince(n, text)
	for i = n + 1, #CHAT do
		if tostring(CHAT[i]):find(text, 1, true) then return true end
	end
	return false
end
local function DeepCopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = DeepCopy(v) end
	return c
end
local function Same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local function E(id, name, owners, extra)
	local e = { id = id, name = name, type = "spells", icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = owners, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local function C(name, owners)
	return { id = 2139, name = name, type = "customs", triggerType = "spell", bCD = 60000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, usedBy = owners }
end
local function byName(list, name)
	for _, e in pairs(list or {}) do if e.name == name then return e end end
end
local function count(list) local n = 0 for _ in pairs(list or {}) do n = n + 1 end return n end
local function names(list)
	local n = {}
	for _, e in pairs(list or {}) do n[#n + 1] = tostring(e.name) end
	table.sort(n)
	return table.concat(n, ",")
end

-- an account with a main on "Main" (and its Filters lists), an alt profile, and empty profiles to switch to.
-- "Tester" has never logged in: New characters start on the last profile used, Main.
CDTL3DB = {
	profileKeys = { ["Mainchar - Realm"] = "Main" },
	profiles = {
		Main = { tables = {
			spells = { E(2139, "Counterspell", { MAIN }, { lane = 3 }), E(1953, "Blink", { MAIN, ME }) },
			customs = { C("Pull Timer", { MAIN }) },
			items = { { id = 60001, name = "Use Hearthstone", itemName = "Hearthstone", itemID = 6948, type = "items", bCD = 900000, usedBy = { MAIN } } },
		} },
		Alt = { tables = { spells = { E(5000, "Alt Spell", { ALT }), E(2139, "Counterspell", { ALT }, { lane = 2 }) } } },
		Seed = { tables = { spells = { E(7000, "Seed Spell", { MAIN }), E(2139, "Counterspell", { MAIN }, { lane = 1, color = { r = 1 } }) } } },
		Raid = {}, Dungeon = {}, PvP = {}, World = {}, Other = {}, SpecA = {},
	},
	global = { newCharacterProfile = "LAST", lastProfile = "Main" },
}

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local PR = CDTL3.Profiles
local db = CDTL3.db
local function T() return CDTL3.db.profile.tables end
-- a profile's own lists: in its saved data, or (while it is the profile in use and shared) kept aside
local function Own(name)
	local a = PR.attached
	if a and a.profile == name then return a.own end
	return rawget(CDTL3.db.sv.profiles[name], "tables")
end
local function Store() return CDTL3.db.global.sharedEntries end
local plug = CDTL3.profile and CDTL3.profile.plugins and CDTL3.profile.plugins.CDTL3
local function opt(key) return plug and plug[key] end

---------------------------------------------------------------- new characters
print("[new characters " .. FLAVOR .. "]")
check("a new character with New characters start on = the last profile used: on Main", db:GetCurrentProfile() == "Main", db:GetCurrentProfile())
check("  a chat line says which profile it started on", chatSince(0, "starts on the profile \"Main\""))
do
	local real = CDTL3DB
	local function try(sv)
		CDTL3DB = sv
		PR.startedOn = nil
		PR.StartNewCharacter()
		CDTL3DB = real
		return sv.profileKeys and sv.profileKeys["Tester - Realm"]
	end
	local profiles = { Main = {}, Picked = {} }
	check("nothing set: AceDB's Default, as before", try({ profiles = profiles, global = {} }) == nil)
	check("the Default profile chosen: as before", try({ profiles = profiles, global = { newCharacterProfile = nil, lastProfile = "Main" } }) == nil)
	check("a profile I choose: Picked", try({ profiles = profiles, global = { newCharacterProfile = "CHOSEN", newCharacterProfileName = "Picked" } }) == "Picked")
	check("the chosen profile was deleted: Default, as before", try({ profiles = profiles, global = { newCharacterProfile = "CHOSEN", newCharacterProfileName = "Gone" } }) == nil)
	check("the last profile used: Main", try({ profiles = profiles, global = { newCharacterProfile = "LAST", lastProfile = "Main" } }) == "Main")
	check("a character that already has a profile keeps it",
		try({ profiles = profiles, profileKeys = { ["Tester - Realm"] = "Mine" }, global = { newCharacterProfile = "LAST", lastProfile = "Main" } }) == "Mine")
	check("a first install (no saved data): nothing to do", pcall(function() CDTL3DB = nil; PR.StartNewCharacter(); CDTL3DB = real end) and CDTL3DB == real)
end
local nc, ncName = opt("newCharacterProfile"), opt("newCharacterProfileName")
check("Profiles tab: New characters start on, with a one-line tooltip", nc and nc.type == "select" and nc.desc and not nc.desc:find("\n")
	and nc.values.DEFAULT and nc.values.LAST and nc.values.CHOSEN)
check("  the profile picker shows only for A profile I choose", ncName and ncName.hidden() == true and ncName.desc ~= nil)
nc.set({}, "CHOSEN")
check("  A profile I choose: the picker shows, listing the profiles", ncName.hidden() == false and ncName.values().Seed == "Seed")
nc.set({}, "DEFAULT")
check("  back to the Default profile: the setting is cleared (today's behaviour)", db.global.newCharacterProfile == nil and nc.get() == "DEFAULT")
db:SetProfile("Other")
check("the last profile used follows a switch", db.global.lastProfile == "Other")
db:SetProfile("Main")

---------------------------------------------------------------- shared entries: off by default
print("[shared entries, off by default " .. FLAVOR .. "]")
local share = opt("shareEntries")
check("Profiles tab: the share option, off, with a one-line tooltip", share and share.type == "toggle" and share.get() == false
	and share.name == "Share my Custom timers and spell settings with all my characters" and share.desc and not share.desc:find("\n"))
check("off: no shared store, this profile's own lists in use", Store() == nil and rawget(db.profile, "tables") == Own("Main"))
local before = DeepCopy(T())
check("  Main's lists as saved", names(T().spells) == "Blink,Counterspell" and names(T().customs) == "Pull Timer")

---------------------------------------------------------------- round trip: on, then off
print("[round trip " .. FLAVOR .. "]")
local n0 = #CHAT
share.set({}, true)
local lists = Store().lists
check("on: the shared lists hold a copy of Main's entries", Same(lists.spells, before.spells) and Same(lists.customs, before.customs)
	and Same(lists.items, before.items) and lists.spells[1] ~= before.spells[1])
check("  every profile reads the shared lists, Main's own are kept as they were", T() == lists and Same(Own("Main"), before) and Own("Main") ~= lists)
check("  a chat line says so", chatSince(n0, "now shared by all your characters"))
share.set({}, false)
check("off: Main's own lists again, exactly as before", rawget(db.profile, "tables") == Own("Main") and Same(T(), before))
check("  the shared copy is kept (nothing is deleted)", Store() and Same(Store().lists.spells, before.spells))
share.set({}, true)
T().spells[1].lane = 2
table.insert(T().customs, C("Shared Custom", { ME }))
check("on again, edits go to the shared lists only", Own("Main").spells[1].lane == 3 and byName(Own("Main").customs, "Shared Custom") == nil
	and byName(Store().lists.customs, "Shared Custom") ~= nil)
share.set({}, false)
check("off: the edits come back to Main", T().spells[1].lane == 2 and byName(T().customs, "Shared Custom") ~= nil and count(T().spells) == 2)
T().spells[1].lane = 3
share.set({}, true)

---------------------------------------------------------------- other profiles while shared
print("[other profiles while shared " .. FLAVOR .. "]")
local mainOwn = Own("Main")
db:SetProfile("Alt")
check("switching away: Main gets its own lists back in the saved data", rawget(db.sv.profiles.Main, "tables") == mainOwn)
check("Alt uses the shared lists", T() == Store().lists)
check("  Alt's own entry joined", byName(T().spells, "Alt Spell") ~= nil)
local cs = byName(T().spells, "Counterspell")
check("  Counterspell keeps the shared settings (lane 3), with Alt's character added",
	cs.lane == 3 and table.concat(cs.usedBy, ",") == MAIN .. "," .. ALT, tostring(cs.lane) .. " " .. table.concat(cs.usedBy, ","))
check("  Alt's own lists unchanged", names(Own("Alt").spells) == "Alt Spell,Counterspell" and byName(Own("Alt").spells, "Counterspell").lane == 2)
db:SetProfile("Main")
check("back on Main: the same shared lists, Alt's spell listed", T() == Store().lists and byName(T().spells, "Alt Spell") ~= nil)

-- Copy From while shared: the shared lists aren't written over
local sharedCS = DeepCopy(byName(T().spells, "Counterspell"))
db:CopyProfile("Seed")
check("Copy From Seed while shared: the shared Counterspell is unchanged", Same(byName(T().spells, "Counterspell"), sharedCS))
check("  Seed's new spell joins, every shared entry still there", byName(T().spells, "Seed Spell") ~= nil and names(T().spells) == "Alt Spell,Blink,Counterspell,Seed Spell", names(T().spells))
check("  Main's own lists now hold Seed's spells and keep what they held", names(Own("Main").spells) == "Blink,Counterspell,Seed Spell"
	and byName(Own("Main").customs, "Pull Timer") ~= nil, names(Own("Main").spells))
db:ResetProfile()
check("Reset Profile while shared: every shared entry kept", names(T().spells) == "Alt Spell,Blink,Counterspell,Seed Spell" and T() == Store().lists)
check("  Main's own lists keep their entries too", names(Own("Main").spells) == "Blink,Counterspell,Seed Spell")

-- imports while shared
local AS, LD = LibStub("AceSerializer-3.0"), LibStub("LibDeflate")
LD.CompressDeflate = function(_, s) return s end
LD.DecompressDeflate = function(_, s) return s end
local function import(mode, data)
	CDTL3.db.profile.global.importMode = mode
	local e = #ERRORS
	xpcall(function() CDTL3:ImportHandler(LD:EncodeForPrint(AS:Serialize(data))) end, ERRH)
	return #ERRORS - e
end
CDTL3.db.profile.global.exportMode = "ALL"
local full = DeepCopy(CDTL3:GetFullOptions().args.importexport and (function()
	local ok, s = pcall(CDTL3:GetFullOptions().args.importexport.args.exportbox.get, {})
	local okd, t = AS:Deserialize(LD:DecodeForPrint(s))
	return okd and t
end)())
check("an All Settings and Data export while shared carries the shared entries", full and count(full.tables.spells) == 4, full and tostring(count(full.tables.spells)))
full.tables.spells = { E(8000, "Imported Spell", { ME }) }
local errs = import("ALL", full)
check("All Settings and Data import while shared: no Lua errors, its spell joins, nothing shared lost", errs == 0
	and names(T().spells) == "Alt Spell,Blink,Counterspell,Imported Spell,Seed Spell" and T() == Store().lists, names(T().spells))
local aliased = false
for k, v in pairs(Own("Main")) do if Store().lists[k] == v then aliased = true end end
check("  Main's own lists share no table with the shared ones", not aliased)

---------------------------------------------------------------- logout and reload
print("[logout and reload " .. FLAVOR .. "]")
local DEFAULTS = CDTL3.db.defaults
local storeBefore = DeepCopy(Store().lists)
FireEvent("PLAYER_LOGOUT")
local twice = {}
local function mark(t, seen)
	if type(t) ~= "table" then return end
	if seen[t] then twice[#twice + 1] = t return end
	seen[t] = true
	for _, v in pairs(t) do mark(v, seen) end
end
mark(CDTL3DB, {})
check("logout: the saved data holds every table once", #twice == 0, tostring(#twice))
check("  Main's saved lists are its own, the shared ones under global", rawget(CDTL3DB.profiles.Main, "tables") ~= CDTL3DB.global.sharedEntries.lists
	and CDTL3DB.global.sharedEntries.lists.spells ~= nil)
-- a reload: the saved file read back (fresh tables), the database opened again
CDTL3DB = DeepCopy(CDTL3DB)
CDTL3.db = LibStub("AceDB-3.0"):New("CDTL3DB", DEFAULTS, true)
local LDS = LibStub("LibDualSpec-1.0", true)
if LDS then pcall(LDS.EnhanceDatabase, LDS, CDTL3.db, "CDTL3") end
CDTL3.db.RegisterCallback(CDTL3, "OnProfileChanged", "RefreshConfig")
CDTL3.db.RegisterCallback(CDTL3, "OnProfileCopied", "RefreshConfig")
CDTL3.db.RegisterCallback(CDTL3, "OnProfileReset", "RefreshConfig")
PR.attached = nil
PR.Setup()
db = CDTL3.db
xpcall(function() CDTL3:RefreshConfig() end, ERRH)
check("reload: still shared, on Main, every shared entry there", PR.Sharing() and db:GetCurrentProfile() == "Main" and T() == Store().lists
	and Same(Store().lists.spells, storeBefore.spells) and Same(Store().lists.customs, storeBefore.customs))
check("  Main's own lists came back too (the import's spell and what they held)", names(Own("Main").spells) == "Blink,Counterspell,Imported Spell,Seed Spell",
	names(Own("Main").spells))

---------------------------------------------------------------- switching off with another profile in it
print("[switching off " .. FLAVOR .. "]")
n0 = #CHAT
opt("shareEntries").set({}, false)
check("off: Main gets every shared entry, its own lists in use", rawget(db.profile, "tables") == Own("Main")
	and names(T().spells) == "Alt Spell,Blink,Counterspell,Imported Spell,Seed Spell", names(T().spells))
check("  Counterspell has the shared settings (lane 3)", byName(T().spells, "Counterspell").lane == 3)
check("  a chat line says so", chatSince(n0, "Sharing is off"))
check("  the shared copy is kept, Alt still waiting for its copy", Store() and Store().joined.Alt == true and Store().joined.Main == nil)
db:SetProfile("Alt")
check("Alt, used again: it gets every shared entry", names(T().spells) == "Alt Spell,Blink,Counterspell,Imported Spell,Seed Spell"
	and rawget(db.profile, "tables") == Own("Alt") and Store().joined.Alt == nil, names(T().spells))
check("  its own Counterspell takes the shared settings (lane 3), both characters kept", byName(T().spells, "Counterspell").lane == 3
	and #byName(T().spells, "Counterspell").usedBy == 2)
db:SetProfile("Main")
check("no entry anywhere was lost", byName(Own("Main").customs, "Pull Timer") ~= nil and byName(Own("Main").customs, "Shared Custom") ~= nil
	and count(Own("Main").items) == 1)

---------------------------------------------------------------- profiles by zone
print("[profiles by zone " .. FLAVOR .. "]")
local ZONE = { false, "none" }
IsInInstance = function() return ZONE[1], ZONE[2] end
local function enter(kind)
	ZONE[1], ZONE[2] = kind ~= "none", kind
	FireEvent("PLAYER_ENTERING_WORLD", false, false)
end
db.global.lastProfile = "Main"
enter("raid")
check("nothing set: a raid changes nothing", db:GetCurrentProfile() == "Main")
enter("none")
local zr, zd, zp, zw = opt("zone_raid"), opt("zone_dungeon"), opt("zone_pvp"), opt("zone_world")
check("Profiles tab: Raids, Dungeons, PvP, Open world, each a one-line tooltip, None by default",
	zr and zd and zp and zw and zr.get() == PR.NONE and zw.get() == PR.NONE and not zd.desc():find("\n") and zr.values()[PR.NONE] == "None" and zr.values().Raid == "Raid")
zr.set({}, "Raid"); zd.set({}, "Dungeon"); zp.set({}, "PvP")
check("set in the open world: no switch yet", db:GetCurrentProfile() == "Main")
enter("raid")
check("a raid: Raid profile", db:GetCurrentProfile() == "Raid")
check("  the last profile used stays Main (zone profiles never count)", db.global.lastProfile == "Main")
enter("none")
check("back in the open world: Main again", db:GetCurrentProfile() == "Main")
for _, z in ipairs({ { "party", "Dungeon" }, { "scenario", "Dungeon" }, { "pvp", "PvP" }, { "arena", "PvP" } }) do
	enter(z[1])
	check(z[1] .. ": " .. z[2] .. " profile", db:GetCurrentProfile() == z[2], db:GetCurrentProfile())
end
enter("raid")
check("straight from an arena to a raid: Raid", db:GetCurrentProfile() == "Raid")
enter("none")
check("  and out: Main", db:GetCurrentProfile() == "Main")
enter("raid")
db:SetProfile("Other")
enter("none")
check("a profile picked by hand in the raid stays afterwards", db:GetCurrentProfile() == "Other")
db:SetProfile("Main")
zw.set({}, "World")
check("Open world set while there: World at once", db:GetCurrentProfile() == "World")
enter("raid")
check("  a raid: Raid", db:GetCurrentProfile() == "Raid")
enter("none")
check("  the open world again: World", db:GetCurrentProfile() == "World")
zw.set({}, PR.NONE)
check("Open world back to None while there: Main again", db:GetCurrentProfile() == "Main")
InCombatLockdown = function() return true end
enter("raid")
check("zoning in during combat: waits", db:GetCurrentProfile() == "Main")
InCombatLockdown = function() return false end
FireEvent("PLAYER_REGEN_ENABLED")
check("  combat over: Raid", db:GetCurrentProfile() == "Raid")
enter("none")

-- with spec profiles: the zone's profile wins while there, the spec's comes back afterwards
check("the spec check, asked with no spec in a raid, answers Raid; asked for a spec, as before", (function()
	if type(db.GetDualSpecProfile) ~= "function" then return true end
	ZONE[1], ZONE[2] = true, "raid"
	local zone, spec = db:GetDualSpecProfile(), db:GetDualSpecProfile(1)
	ZONE[1], ZONE[2] = false, "none"
	return zone == "Raid" and spec == db:GetCurrentProfile() and db:GetDualSpecProfile() == db:GetCurrentProfile()
end)())
if LDS and type(db.SetDualSpecProfile) == "function" and FLAVOR ~= "mop" and FLAVOR ~= "retail" then
	GetNumTalentGroups = function() return 2 end
	LDS.currentSpec = 1
	db:SetDualSpecEnabled(true)
	db:SetDualSpecProfile("SpecA", 1)
	check("spec profiles on: SpecA", db:GetCurrentProfile() == "SpecA")
	enter("raid")
	check("  a raid: Raid wins over the spec profile", db:GetCurrentProfile() == "Raid")
	db:CheckDualSpecState()
	check("  a spec check in the raid leaves Raid", db:GetCurrentProfile() == "Raid")
	enter("none")
	check("  out of the raid: the spec profile, SpecA", db:GetCurrentProfile() == "SpecA")
	db:SetDualSpecEnabled(false)
	db:SetProfile("Main")
	GetNumTalentGroups = function() return 1 end
end

-- a deleted profile leaves the zone settings and the new-character choice
db.global.newCharacterProfile, db.global.newCharacterProfileName = "CHOSEN", "Dungeon"
db:DeleteProfile("Dungeon")
check("deleting a profile clears the zone and new-character settings that named it", zd.get() == PR.NONE and db.global.newCharacterProfileName == nil)
enter("party")
check("  a dungeon then changes nothing", db:GetCurrentProfile() == "Main")
enter("none")

---------------------------------------------------------------- the options window
print("[options window " .. FLAVOR .. "]")
local ok, err = pcall(function() return LibStub("AceConfigRegistry-3.0"):GetOptionsTable("CDTL3")("dialog", "MyLib-1.0") end)
check("the full options tree, Profiles tab included, passes AceConfig's checks", ok, tostring(err))
check("the registered Profiles tab carries the new options", CDTL3:GetFullOptions().args.profiles.plugins.CDTL3.shareEntries ~= nil)

print(string.format("RESULT profiles %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS))
