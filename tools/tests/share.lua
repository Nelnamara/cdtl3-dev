-- Sharing and media (feature panel of 12 Nov 2026, cards 34 and 40, and the owner's note on red
-- team card 1): "!CDTL3:2!" exports naming the client and CDTL3 version, a round trip of every
-- export kind, older strings importing as before, the import preview with Accept / Cancel (what's
-- in it, another client, spells this client doesn't have), Into a new profile, Copy this lane,
-- refused strings, imported Filters entries listed for the importing character on a shared Default
-- profile, the "(missing)" note on font / bar texture / sound dropdowns and CDTL3's media
-- fallbacks, CDTL3's own media registered with LibSharedMedia, and Masque groups per timer type.
-- Real files, real AceDB / AceConfig / AceSerializer / LibSharedMedia.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME, OTHER, SENDER = PLAYER.guid, "Player-1-0000099", "Player-2-0000777"

-- one Default profile shared by two characters
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default", ["Other - Realm"] = "Default" }, profiles = { Default = {} } }

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
local function T() return CDTL3.db.profile.tables end
local function entry(id, name, owners, extra)
	local e = { id = id, name = name, type = "spells", icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = owners, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local function chatSince(n, text)
	for i = n + 1, #CHAT do
		if tostring(CHAT[i]):find(text, 1, true) then return true end
	end
	return false
end
local function names(list)
	local n = {}
	for _, e in pairs(list) do n[#n + 1] = tostring(e.name) end
	table.sort(n)
	return table.concat(n, ",")
end
local function find(list, name) for _, e in pairs(list) do if e.name == name then return e end end end
local function copy(t) if type(t) ~= "table" then return t end local c = {} for k, v in pairs(t) do c[k] = copy(v) end return c end
local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in pairs(a) do if not same(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local function snap() return copy(CDTL3.db.profile) end

local CLIENT = ({ retail = "Retail", forever = "Forever", mop = "Mists", tbc = "TBC", era = "Era" })[FLAVOR]
local CLIENT_NAME = ({ Retail = "Retail", Forever = "WoW: Forever", Mists = "MoP Classic", TBC = "TBC Anniversary", Era = "Classic Era" })[CLIENT]

-- spells "this client doesn't have": the stubs name every number, so these IDs answer nothing
local MISSING = {}
if RETAILAPI then
	local real = C_Spell.GetSpellInfo
	C_Spell.GetSpellInfo = function(id) if MISSING[id] then return nil end return real(id) end
else
	local real = GetSpellInfo
	GetSpellInfo = function(id) if MISSING[id] then return nil end return real(id) end
end

local AS = LibStub("AceSerializer-3.0")
local LD = LibStub("LibDeflate")
-- LibDeflate's inflate doesn't round-trip under fengari, so compression passes the data through;
-- AceSerializer, EncodeForPrint/DecodeForPrint, the export box and the Import box run as shipped
LD.CompressDeflate = function(_, s) return s end
LD.DecompressDeflate = function(_, s) return s end
local function v2(t) return "!CDTL3:2!" .. LD:EncodeForPrint(LD:CompressDeflate(AS:Serialize(t))) end
local function old(t) return LD:EncodeForPrint(LD:CompressDeflate(AS:Serialize(t))) end
local function unwrap(s)
	local body = type(s) == "string" and s:match("^!CDTL3:2!(.*)$")
	if not body then return nil end
	local ok, t = AS:Deserialize(LD:DecompressDeflate(LD:DecodeForPrint(body)))
	return ok and t or nil
end

local function IE() return CDTL3:GetFullOptions().args.importexport.args end
local function exportBox(mode)
	CDTL3.db.profile.global.exportMode = mode
	return IE().exportbox.get({})
end
-- the Import box as AceConfigDialog runs it: its confirm first (a text = the Accept / Cancel box),
-- then set on Accept; when confirm gives no text, set at once (the import then says what's wrong)
local function importFlow(mode, str, answer)
	CDTL3.db.profile.global.importMode = mode
	local ie = IE()
	local n, e = #CHAT, #ERRORS
	local text
	xpcall(function() text = ie.importbox.confirm({}, str) end, ERRH)
	local asked = type(text) == "string"
	if not asked or answer == "accept" then
		xpcall(function() ie.importbox.set({}, str) end, ERRH)
	end
	return { text = asked and text or nil, refused = chatSince(n, "error importing"), errors = #ERRORS - e, chat = n }
end
local function owners(e)
	local t = {}
	for _, g in pairs(e and e.usedBy or {}) do t[#t + 1] = g end
	table.sort(t)
	return table.concat(t, ",")
end
local function sorted(...) local t = { ... }; table.sort(t); return table.concat(t, ",") end

---------------------------------------------------------------- card 34: the header
print("[card 34 header " .. FLAVOR .. "]")
do
	for _, mode in ipairs({ "ALL", "SETTINGS", "CDDATA" }) do
		local s = exportBox(mode)
		local w = unwrap(s)
		check(mode .. " export: starts with !CDTL3:2!, names this client (" .. CLIENT .. ") and CDTL3 " .. CDTL3.version,
			s:sub(1, 9) == "!CDTL3:2!" and w ~= nil and w.kind == mode and w.client == CLIENT and w.version == CDTL3.version
				and w.toc == HARNESS_TOC and type(w.data) == "table",
			w and string.format("%s %s %s %s", tostring(w.kind), tostring(w.client), tostring(w.version), tostring(w.toc)) or "undecodable")
	end
	local w = unwrap(exportBox("SETTINGS"))
	check("Settings Only still carries every Filters list empty", w and type(w.data.tables) == "table" and next(w.data.tables.spells) == nil
		and next(w.data.tables.customs) == nil and type(w.data.lanes) == "table")
end

---------------------------------------------------------------- card 34: a round trip of every export kind
print("[card 34 round trip of every export kind " .. FLAVOR .. "]")
do
	local p = CDTL3.db.profile
	clear(T().spells); clear(T().buffs); clear(T().customs)
	table.insert(T().spells, entry(2001, "Alpha", { ME }, { lane = 2, setCustomCD = true, customCDTime = 20000 }))
	table.insert(T().buffs, entry(2002, "Shield", { ME }, { type = "buffs" }))
	p.lanes.lane1.width = 333

	local all = exportBox("ALL")
	p.lanes.lane1.width = 400
	clear(T().spells)
	local r = importFlow("ALL", all, "accept")
	check("All Settings and Data: previewed, then imported (lane 1 width 333, Alpha with its Custom CD Time)", r.text and not r.refused and r.errors == 0
		and CDTL3.db.profile.lanes.lane1.width == 333 and names(T().spells) == "Alpha" and T().spells[1].customCDTime == 20000,
		string.format("width=%s spells=%s errors=%d", tostring(CDTL3.db.profile.lanes.lane1.width), names(T().spells), r.errors))

	local settings = exportBox("SETTINGS")
	CDTL3.db.profile.lanes.lane1.width = 222
	table.insert(T().spells, entry(2003, "Beta", { ME }))
	r = importFlow("SETTINGS", settings, "accept")
	check("CDTL3 Settings Only: imported (width 333), this profile's Filters lists stay", r.text and not r.refused and r.errors == 0
		and CDTL3.db.profile.lanes.lane1.width == 333 and names(T().spells) == "Alpha,Beta", names(T().spells))

	local data = exportBox("CDDATA")
	clear(T().spells)
	CDTL3.db.profile.lanes.lane1.width = 444
	r = importFlow("CDDATA", data, "accept")
	check("Cooldown Data Only: imported (Alpha, Beta back), settings stay (width 444)", r.text and not r.refused and r.errors == 0
		and names(T().spells) == "Alpha,Beta" and names(T().buffs) == "Shield" and CDTL3.db.profile.lanes.lane1.width == 444, names(T().spells))
	CDTL3.db.profile.lanes.lane1.width = 333

	-- Copy this lane (Lanes > Lane 2 > General)
	local lanes = CDTL3.db.profile.lanes
	lanes.lane2.width, lanes.lane2.name, lanes.lane2.posX, lanes.lane2.icons.size = 250, "Big CDs", 123, 44
	local function laneArgs(n) return CDTL3:GetFullOptions().args.lanes.args["lane" .. n].args.general.args end
	local la = laneArgs(2)
	check("Copy this lane: a button, with the box hidden until it's pressed", la.shareLane and la.shareLane.type == "execute"
		and la.shareLane.name == "Copy this lane" and type(la.shareLane.desc) == "string" and la.shareLaneBox.hidden({}) == true)
	la.shareLane.func({})
	la = laneArgs(2)
	local ls = la.shareLaneBox.get({})
	local w = unwrap(ls)
	check("  pressed: the box shows a !CDTL3:2! lane string", la.shareLaneBox.hidden({}) == false and w and w.kind == "LANE" and w.lane == 2
		and w.client == CLIENT and w.version == CDTL3.version)
	check("  it holds the lane's settings and its name, not where it sits or whether it's on", w and w.data.width == 250 and w.data.icons.size == 44
		and w.data.name == "Big CDs" and w.data.posX == nil and w.data.posY == nil and w.data.enabled == nil and w.data.editMode == nil)
	check("  only lane 2's box opened", laneArgs(1).shareLaneBox.hidden({}) == true)

	lanes.lane2.width, lanes.lane2.name, lanes.lane2.posX, lanes.lane2.icons.size = 100, "Mine", 50, 30
	r = importFlow("SETTINGS", ls, "accept")	-- the import mode doesn't matter for a lane string
	lanes = CDTL3.db.profile.lanes
	check("lane string: the preview names the lane and what stays", r.text and r.text:find('One lane: settings for lane 2 ("Big CDs"), made on ' .. CDTL3.version .. " " .. CLIENT_NAME .. ".", 1, true)
		and r.text:find("Replaces lane 2's settings in this profile (Default), except its name, position and whether it's on.", 1, true), r.text)
	check("  imported: lane 2 width 250, icon size 44; its name and position kept", not r.refused and r.errors == 0 and lanes.lane2.width == 250
		and lanes.lane2.icons.size == 44 and lanes.lane2.name == "Mine" and lanes.lane2.posX == 50,
		string.format("%s %s %s %s", tostring(lanes.lane2.width), tostring(lanes.lane2.icons.size), tostring(lanes.lane2.name), tostring(lanes.lane2.posX)))
	check("  the other lanes untouched", lanes.lane1.width == 333)
	for n = 1, 3 do
		local was = lanes["lane" .. n].height
		lanes["lane" .. n].height = 17
		local s = CDTL3:ExportString("LANE", n)
		lanes["lane" .. n].height = 3
		r = importFlow("ALL", s, "accept")
		lanes = CDTL3.db.profile.lanes
		check("lane " .. n .. " string round trip (height 17 back)", not r.refused and r.errors == 0 and lanes["lane" .. n].height == 17, tostring(lanes["lane" .. n].height))
		lanes["lane" .. n].height = was
	end
end

---------------------------------------------------------------- card 34: older strings import as before
print("[card 34 older strings " .. FLAVOR .. "]")
do
	-- what the export box made before the header: the data itself, no wrapper
	local function oldExport(mode)
		if mode == "CDDATA" then return old(CDTL3:TableCopy(CDTL3.db.profile.tables)) end
		local t = CDTL3:TableCopy(CDTL3.db.profile)
		if mode == "SETTINGS" then
			for _, k in ipairs({ "spells", "petspells", "items", "buffs", "debuffs", "offensives", "runes", "customs", "detected" }) do t.tables[k] = {} end
		end
		return old(t)
	end
	local function change()
		CDTL3.db.profile.lanes.lane1.width = 111
		clear(T().spells)
		table.insert(T().spells, entry(2101, "Gamma", { ME }))
	end
	for _, mode in ipairs({ "ALL", "SETTINGS", "CDDATA" }) do
		CDTL3.db.profile.global.exportMode, CDTL3.db.profile.global.importMode = mode, mode
		local o, n = oldExport(mode), exportBox(mode)
		change()
		local r1 = importFlow(mode, o, "accept")
		local afterOld = snap()
		change()
		local r2 = importFlow(mode, n, "accept")
		local afterNew = snap()
		check(mode .. ": an older string (no header) imports exactly as the new one", r1.text and not r1.refused and r1.errors == 0 and r2.text
			and not r2.refused and same(afterOld, afterNew))
		check("  its preview says it's from an older CDTL3, no client warning", r1.text and r1.text:find("made on an older CDTL3", 1, true)
			and not r1.text:find("Made on ", 1, true), r1.text)
	end
	-- the 3.1.1 suite's own old-format strings (settings.lua) still import: a Settings Only string
	CDTL3.db.profile.global.exportMode = "SETTINGS"
	local t = CDTL3:TableCopy(CDTL3.db.profile)
	t.lanes.lane1.width = 377
	local r = importFlow("SETTINGS", old(t), "accept")
	check("a hand-made older Settings string: imported (width 377)", not r.refused and CDTL3.db.profile.lanes.lane1.width == 377)
	CDTL3.db.profile.lanes.lane1.width = 333
end

---------------------------------------------------------------- card 34: the preview
print("[card 34 preview: counts, Cancel, another client, missing spells " .. FLAVOR .. "]")
do
	-- the card's own example: three lanes, 41 spells, 6 buffs
	clear(T().spells); clear(T().buffs); clear(T().customs); clear(T().items)
	for i = 1, 41 do table.insert(T().spells, entry(3000 + i, "Spell " .. (3000 + i), { SENDER })) end
	for i = 1, 6 do table.insert(T().buffs, entry(3100 + i, "Buff " .. i, { SENDER }, { type = "buffs" })) end
	for n = 1, 3 do CDTL3.db.profile.lanes["lane" .. n].enabled = true end
	local all = exportBox("ALL")
	CDTL3.db.profile.global.importMode = "ALL"
	local before = snap()
	local r = importFlow("ALL", all)	-- Cancel
	local want = "All Settings and Data: 3 lanes, 41 spells, 6 buffs, made on " .. CDTL3.version .. " " .. CLIENT_NAME .. "."
	check("preview: \"" .. want .. "\"", r.text and r.text:find(want, 1, true) ~= nil, r.text)
	check("  same client: no client warning, no missing spells", r.text and not r.text:find("Made on ", 1, true) and not r.text:find("in this client", 1, true))
	check("  says where it goes and asks", r.text and r.text:find("Replaces this profile's settings and the Filters lists the string has (Default).", 1, true)
		and r.text:sub(-10) == "Import it?")
	check("Cancel: nothing written", same(before, snap()) and r.errors == 0)
	CDTL3.db.profile.lanes.lane3.enabled = false
	r = importFlow("SETTINGS", exportBox("SETTINGS"))
	check("Settings Only preview: lanes counted from the string (2 on), no lists", r.text and r.text:find("CDTL3 Settings Only: 2 lanes, made on ", 1, true)
		and r.text:find("Its Filters lists stay.", 1, true), r.text)
	r = importFlow("CDDATA", exportBox("CDDATA"))
	check("Cooldown Data Only preview: lists only", r.text and r.text:find("Cooldown Data Only: 41 spells, 6 buffs, made on ", 1, true)
		and r.text:find("Settings stay.", 1, true), r.text)
	CDTL3.db.profile.lanes.lane3.enabled = true

	-- the same string from another client, with spells this client doesn't have
	local other = CLIENT == "Retail" and { "Era", 11509, "Classic Era" } or { "Retail", 120105, "Retail" }
	local w = unwrap(all)
	w.client, w.toc = other[1], other[2]
	w.data.tables.spells[1].name, w.data.tables.spells[2].name = "Zeta Strike", "Alpha Shout"
	MISSING[w.data.tables.spells[1].id], MISSING[w.data.tables.spells[2].id] = true, true
	local foreign = v2(w)
	CDTL3.db.profile.global.importMode = "ALL"
	before = snap()
	r = importFlow("ALL", foreign)
	check("another client: \"made on " .. CDTL3.version .. " " .. other[3] .. "\" and a warning", r.text and r.text:find("made on " .. CDTL3.version .. " " .. other[3] .. ".", 1, true)
		and r.text:find("Made on " .. other[3] .. " and this is " .. CLIENT_NAME .. ": spells, textures and fonts can differ.", 1, true), r.text)
	check("  names the 2 spells this client doesn't have", r.text and r.text:find("2 spells in it aren't in this client: Alpha Shout, Zeta Strike. They are imported but can't show here.", 1, true), r.text)
	check("  Cancel: nothing written", same(before, snap()))
	for i = 3, 10 do MISSING[w.data.tables.spells[i].id] = true end
	r = importFlow("ALL", foreign)
	check("  10 missing: 8 named, \"and 2 more\"", r.text and r.text:find("10 spells in it aren't in this client: ", 1, true) and r.text:find(" and 2 more. They are", 1, true), r.text)
	r = importFlow("ALL", foreign, "accept")
	check("  Accept: imported, the missing ones too", not r.refused and r.errors == 0 and #T().spells == 41 and find(T().spells, "Zeta Strike") ~= nil)
	-- an older string with spells this client doesn't have: warned too (it can't say which game it's from)
	r = importFlow("CDDATA", old(CDTL3:TableCopy(CDTL3.db.profile.tables)))
	check("  an older string: the missing spells are named as well", r.text and r.text:find("10 spells in it aren't in this client", 1, true)
		and r.text:find("made on an older CDTL3", 1, true), r.text)
	clear(MISSING)
	-- names from someone else's string are shown as plain text
	w.data.tables.spells[1].name = "|cffff0000Red|r"
	MISSING[w.data.tables.spells[1].id] = true
	r = importFlow("ALL", v2(w))
	check("  a name with colour codes is shown as plain text", r.text and r.text:find("||cffff0000Red||r", 1, true), r.text)
	clear(MISSING)
end

---------------------------------------------------------------- card 34: into a new profile
print("[card 34 import into a new profile " .. FLAVOR .. "]")
do
	local ie = IE()
	check("Into a new profile: a toggle with a tooltip, off by default", ie.importNewProfile.type == "toggle" and type(ie.importNewProfile.desc) == "string"
		and ie.importNewProfile.get({}) == false)
	CDTL3.db.profile.global.importMode = "ALL"
	local all = exportBox("ALL")
	local before = snap()
	ie.importNewProfile.set({}, true)
	local r = importFlow("ALL", all, "accept")
	check("the preview says it goes into a new profile", r.text and r.text:find("Goes into a new profile, Imported. This profile (Default) stays as it is.", 1, true), r.text)
	check("imported into a new profile, Imported, now the current one", not r.refused and r.errors == 0 and CDTL3.db:GetCurrentProfile() == "Imported")
	check("  it has the string's settings and lists", #T().spells == 41 and #T().buffs == 6 and CDTL3.db.profile.lanes.lane1.width == 333)
	check("  and this profile's import choice (All Settings and Data)", CDTL3.db.profile.global.importMode == "ALL")
	check("  chat says where it went", chatSince(r.chat, "Imported into a new profile, Imported. Default is unchanged"))
	r = importFlow("ALL", all, "accept")
	check("a second import: Imported 2", not r.refused and CDTL3.db:GetCurrentProfile() == "Imported 2")
	local count = #(CDTL3.db:GetProfiles())
	r = importFlow("ALL", "not a share string", "accept")
	check("a bad string with the option on: refused, no profile made", r.refused and #(CDTL3.db:GetProfiles()) == count and CDTL3.db:GetCurrentProfile() == "Imported 2")
	CDTL3.db:SetProfile("Default")
	check("Default is as it was", same(before, snap()))
	ie.importNewProfile.set({}, false)
	check("switched off: nothing stored (today's behaviour)", CDTL3.db.global.importNewProfile == nil and ie.importNewProfile.get({}) == false)
	r = importFlow("ALL", all)
	check("  and the preview says this profile again", r.text and r.text:find("(Default).", 1, true) and not r.text:find("new profile", 1, true))
end

---------------------------------------------------------------- red team card 1 note: imported entries are this character's too
print("[red team card 1: imported Filters entries are this character's too " .. FLAVOR .. "]")
do
	CDTL3.db:SetProfile("Default")
	-- what a friend sends: their own entries
	clear(T().spells); clear(T().buffs); clear(T().items); clear(T().customs)
	table.insert(T().spells, entry(4001, "Sent A", { SENDER }))
	table.insert(T().spells, entry(4002, "Sent B", { SENDER, ME }))
	table.insert(T().spells, entry(4003, "Sent C", nil))
	local custom = CDTL3:ApplyEntryDefaults({ id = 4004, name = "Sent Custom", type = "customs", bCD = 60000, triggerType = "spell" }, "customs")
	custom.usedBy = { SENDER }
	table.insert(T().customs, custom)
	local sent = exportBox("ALL")

	-- this Default profile is shared with another character, whose buff the string leaves empty
	clear(T().spells); clear(T().customs)
	table.insert(T().buffs, entry(4010, "Their Buff", { OTHER }, { type = "buffs" }))
	local r = importFlow("ALL", sent, "accept")
	check("All Settings and Data imported", not r.refused and r.errors == 0 and names(T().spells) == "Sent A,Sent B,Sent C", names(T().spells))
	check("  Sent A: the sender's and this character's", owners(find(T().spells, "Sent A")) == sorted(SENDER, ME), owners(find(T().spells, "Sent A")))
	check("  Sent B: already this character's, listed once", owners(find(T().spells, "Sent B")) == sorted(SENDER, ME), owners(find(T().spells, "Sent B")))
	check("  Sent C (no owners in the string): this character's", owners(find(T().spells, "Sent C")) == ME, owners(find(T().spells, "Sent C")))
	check("  the Custom too", owners(find(T().customs, "Sent Custom")) == sorted(SENDER, ME))
	local mine, myCustoms = CDTL3:LoadFilterList("spells"), CDTL3:LoadFilterList("customs")
	check("  listed in this character's Filters at once", mine["Sent A"] and mine["Sent B"] and mine["Sent C"] and myCustoms["Sent Custom"])
	check("  the profile's other character isn't added", not owners(find(T().spells, "Sent A")):find(OTHER, 1, true))
	check("  their Buffs entry (the string had none) kept as it was", names(T().buffs) == "Their Buff" and owners(T().buffs[1]) == OTHER)
	local real = CDTL3.player.guid
	CDTL3.player.guid = OTHER
	local theirs = CDTL3:LoadFilterList("spells")
	local theirBuffs = CDTL3:LoadFilterList("buffs")
	CDTL3.player.guid = real
	check("  the other character's Filters: their buff, not the imported spells", theirs["Sent A"] == nil and theirBuffs["Their Buff"] ~= nil)

	-- Cooldown Data Only claims the same way
	local items = { { id = 4020, name = "Use Sent", itemName = "Sent Trinket", itemID = 4020, type = "items", icon = 1, bCD = 120000, lane = 1,
		barFrame = 1, readyFrame = 1, enabled = true, ignored = false, usedBy = { SENDER } } }
	r = importFlow("CDDATA", v2({ kind = "CDDATA", client = CLIENT, toc = HARNESS_TOC, version = CDTL3.version, data = { items = items } }), "accept")
	check("Cooldown Data Only: the item is the sender's and this character's", not r.refused and owners(find(T().items, "Use Sent")) == sorted(SENDER, ME)
		and CDTL3:LoadFilterList("items", true)["Sent Trinket"] ~= nil, owners(find(T().items, "Use Sent")))
	clear(T().spells); clear(T().buffs); clear(T().items); clear(T().customs)
end

---------------------------------------------------------------- card 34: refused strings
print("[card 34 refused strings " .. FLAVOR .. "]")
do
	CDTL3.db.profile.global.importMode = "ALL"
	local good = unwrap(exportBox("ALL"))
	local function refusedCleanly(label, mode, str, chatText)
		CDTL3.db.profile.global.importMode = mode
		local before = snap()
		local r = importFlow(mode, str, "accept")
		local ok = r.text == nil and r.refused and r.errors == 0 and same(before, snap()) and (not chatText or chatSince(r.chat, chatText))
		check(label .. ": no preview, refused, nothing written", ok, string.format("text=%s refused=%s errors=%d", tostring(r.text), tostring(r.refused), r.errors))
	end
	good.data.lanes.lane1.width = 99
	refusedCleanly("a newer format (!CDTL3:3!)", "ALL", "!CDTL3:3!" .. LD:EncodeForPrint(AS:Serialize(good)), "made by a newer CDTL3")
	refusedCleanly("a header cut short (!CDTL3:2)", "ALL", "!CDTL3:2" .. LD:EncodeForPrint(AS:Serialize(good)))
	refusedCleanly("the header, then junk", "ALL", "!CDTL3:2!@@@@")
	refusedCleanly("the header, then a table that isn't a share", "ALL", v2(good.data))
	refusedCleanly("an unknown kind", "ALL", v2({ kind = "EVERYTHING", data = good.data }))
	refusedCleanly("a lane string for lane 7", "ALL", v2({ kind = "LANE", lane = 7, data = {} }))
	local badLane = unwrap(CDTL3:ExportString("LANE", 1))
	badLane.data.width = "wide"
	refusedCleanly("a lane string with a malformed value", "ALL", v2(badLane))
	refusedCleanly("a Settings Only string with Cooldown Data Only (and the chat says which it is)", "CDDATA", exportBox("SETTINGS"), "is a \"CDTL3 Settings Only\" export")
	refusedCleanly("a Cooldown Data Only string with All Settings and Data", "ALL", exportBox("CDDATA"), "is a \"Cooldown Data Only\" export")
	refusedCleanly("an empty box", "ALL", "")
end

---------------------------------------------------------------- card 40: media dropdowns and fallbacks
print("[card 40 media dropdowns and fallbacks " .. FLAVOR .. "]")
do
	local L = LibStub("LibSharedMedia-3.0")
	local KINDS = { LSM30_Font = "font", LSM30_Statusbar = "statusbar", LSM30_Sound = "sound" }
	local found = {}
	local function walk(group)
		for k, v in pairs(group.args or {}) do
			if type(v) == "table" and k ~= "profiles" then
				if v.type == "group" then
					walk(v)
				elseif v.type == "select" and KINDS[v.dialogControl] then
					found[#found + 1] = { opt = v, kind = KINDS[v.dialogControl], key = k }
				end
			end
		end
	end
	walk(CDTL3:GetFullOptions())
	local counts = { font = 0, statusbar = 0, sound = 0 }
	for _, f in ipairs(found) do counts[f.kind] = counts[f.kind] + 1 end
	check("the window's font, bar texture and sound dropdowns found", counts.font > 0 and counts.statusbar > 0 and counts.sound > 0,
		string.format("fonts %d, textures %d, sounds %d", counts.font, counts.statusbar, counts.sound))

	local GONE = { font = "Gone Font", statusbar = "Gone Texture", sound = "Gone Sound" }
	local USING = { font = "Fira Sans Condensed", statusbar = "CDTL3 Smooth", sound = "CDTL3 Click" }
	local tested, noted, clean = 0, 0, 0
	local missed = {}
	local e0 = #ERRORS
	for _, f in ipairs(found) do
		local o = f.opt
		local ok, was = pcall(o.get, {})
		-- a per-entry picker (Filters › an entry › Ready Sound) saves nothing while no entry is picked,
		-- so it has no saved name to check here; it shares the same note code as the rest
		local takes = false
		if ok and type(was) == "string" then
			o.set({}, GONE[f.kind])
			takes = o.get({}) == GONE[f.kind]
			o.set({}, was)
		end
		if takes then
			tested = tested + 1
			local plain = o.name({})
			o.set({}, GONE[f.kind])
			local n, d = o.name({}), o.desc({})
			if n == plain .. " |cffff9900(missing)|r" and d:find("Missing, using the default: " .. USING[f.kind] .. ".", 1, true)
				and d:find('"' .. GONE[f.kind] .. '"', 1, true) then
				noted = noted + 1
			else
				missed[#missed + 1] = f.key .. " (" .. tostring(plain) .. ")"
			end
			o.set({}, was)
			if o.name({}) == plain and not tostring(o.desc({})):find("Missing", 1, true) then clean = clean + 1 end
		end
	end
	check("every one (" .. tested .. ", plus " .. (#found - tested) .. " per-entry pickers with no entry picked) says (missing) and names the default when its saved name isn't registered",
		tested > 0 and noted == tested,
		string.format("%d of %d; missed: %s", noted, tested, table.concat(missed, ", ")))
	check("  and says nothing once a registered name is saved", clean == tested)
	check("  no Lua errors", #ERRORS == e0)
	local tex
	for _, f in ipairs(found) do if f.kind == "statusbar" and not tex then tex = f.opt end end
	local was = tex.get({})
	tex.set({}, "Blizzard Modern: Cast")
	local atlas = CDTL3.barAtlases["Blizzard Modern: Cast"] ~= nil
	check("a modern bar atlas is missing only where the client has none (" .. tostring(atlas) .. ")", (tex.name({}):find("(missing)", 1, true) == nil) == atlas)
	tex.set({}, was)

	check("CDTL3's sound for a missing name: its default sound, not silence", CDTL3.LSM:Fetch("sound", "Gone Sound") == L:Fetch("sound", "CDTL3 Click"))
	check("  a missing font: Fira Sans Condensed", CDTL3.LSM:Fetch("font", "Gone Font") == L:Fetch("font", "Fira Sans Condensed"))
	check("  a missing bar texture: CDTL3 Smooth", CDTL3.LSM:Fetch("statusbar", "Gone Texture") == L:Fetch("statusbar", "CDTL3 Smooth"))
	check("  registered names unchanged (None still plays nothing)", CDTL3.LSM:Fetch("sound", "None") == L:Fetch("sound", "None")
		and CDTL3.LSM:Fetch("sound", "CDTL3 Rattle") == L:Fetch("sound", "CDTL3 Rattle") and CDTL3.LSM:Fetch("border", "None") == L:Fetch("border", "None"))
	check("  a border is untouched (no fallback asked for)", CDTL3.LSM:Fetch("border", "Gone Border") == L:Fetch("border", "Gone Border"))
	check("  noDefault still means none", CDTL3.LSM:Fetch("sound", "Gone Sound", true) == nil)
	check("  other addons' LibSharedMedia unchanged: a missing sound there is still None", L:Fetch("sound", "Gone Sound") == L:Fetch("sound", "None"))

	-- a Ready frame whose sound pack is gone plays CDTL3 Click, a missing bar texture draws CDTL3 Smooth
	local played
	local realPSF = PlaySoundFile
	PlaySoundFile = function(path) played = path; return true end
	local r1 = CDTL3.db.profile.ready.ready1
	local wasSound = r1.nSound
	r1.nSound = "Gone Sound"
	local e = entry(5001, "Ready Test", { ME })
	table.insert(T().spells, e)
	local cd
	xpcall(function()
		cd = CDTL3:CreateCooldown(CDTL3:GetUID(), "spells", e)
		CDTL3:SendToReady(cd)
	end, ERRH)
	PlaySoundFile = realPSF
	r1.nSound = wasSound
	check("a Ready frame whose saved sound is missing plays CDTL3 Click", played == L:Fetch("sound", "CDTL3 Click"), tostring(played))
	local bar = CreateFrame("StatusBar")
	CDTL3:SetBarTexture(bar, "Gone Texture")
	check("a bar whose saved texture is missing draws CDTL3 Smooth", bar.__tex == L:Fetch("statusbar", "CDTL3 Smooth"), tostring(bar.__tex))
	clear(T().spells)
end

---------------------------------------------------------------- card 40: CDTL3's own media in LibSharedMedia
print("[card 40 CDTL3's own media registered with LibSharedMedia " .. FLAVOR .. "]")
do
	local L = LibStub("LibSharedMedia-3.0")
	local M = [[Interface\Addons\CooldownTimeline3\Media\]]
	local own = {
		{ "sound", "CDTL3 Click", "ready-click.ogg" }, { "sound", "CDTL3 Rattle", "ready-rattle.ogg" }, { "sound", "CDTL3 Tinks", "ready-tinks.ogg" },
		{ "border", "CDTL3 Shadow", "border-dropshad.tga" }, { "statusbar", "CDTL3 Fire", "bar-fire.tga" }, { "statusbar", "CDTL3 Web", "bar-web.tga" },
		{ "statusbar", "CDTL3 Smooth", "bar-smooth.tga" }, { "background", "CDTL3 Icon Shadow", "icon-shadow.tga" },
		{ "font", "Fira Sans Condensed", "FiraSansCondensed-Regular.ttf" },
	}
	for _, m in ipairs(own) do
		check(m[1] .. " \"" .. m[2] .. "\": registered for every addon, the shipped file", L:IsValid(m[1], m[2]) and L:Fetch(m[1], m[2], true) == M .. m[3]
			and HARNESS_READ(HARNESS_SRC .. "/Media/" .. m[3]) ~= nil)
		check("  in the dropdowns' list", AceGUIWidgetLSMlists[m[1]] and AceGUIWidgetLSMlists[m[1]][m[2]] ~= nil)
	end
	check("border \"CDTL3 Pixel\" (Presets.lua) too", L:IsValid("border", "CDTL3 Pixel"))
end

---------------------------------------------------------------- card 40: Masque groups per timer type
print("[card 40 Masque groups per timer type " .. FLAVOR .. "]")
do
	local groups, member, doubled = {}, {}, 0
	local MSQ = {}
	function MSQ:Group(addon, group, id)
		local key = addon .. "/" .. tostring(group)
		if not groups[key] then
			local g = { addon = addon, name = group, id = id, buttons = {} }
			function g:AddButton(b, regions)
				if member[b] and member[b] ~= self then doubled = doubled + 1 end
				self.buttons[b] = regions
				member[b] = self
			end
			function g:RemoveButton(b)
				if self.buttons[b] then self.buttons[b] = nil; member[b] = nil end
			end
			groups[key] = g
		end
		return groups[key]
	end
	local realMasque = CDTL3.Masque
	CDTL3.Masque, CDTL3.masqueGroups = MSQ, nil
	local e0 = #ERRORS
	local cds = {}
	xpcall(function()
		for i, t in ipairs({ "spells", "items", "buffs", "debuffs", "customs", "testing" }) do
			cds[t] = CDTL3:CreateCooldown(CDTL3:GetUID(), t, entry(6000 + i, "Masque " .. t, { ME }, { type = t }))
		end
		CDTL3:RefreshAllIcons()
		CDTL3:RefreshAllBars()
	end, ERRH)
	local root = groups["CDTL3/nil"]
	check("CDTL3's own group is still there (a skin chosen for it carries over)", root ~= nil and CDTL3.masqueGroup == root)
	local G = { spells = "Spells", items = "Items", buffs = "Buffs", debuffs = "Debuffs", customs = "Custom" }
	for t, name in pairs(G) do
		local g = groups["CDTL3/" .. name]
		check("a " .. t .. " icon is in CDTL3 > " .. name .. " (its own id " .. t .. ")", g and g.addon == "CDTL3" and g.id == t and cds[t] and g.buttons[cds[t].icon] ~= nil
			and g.buttons[cds[t].icon].Icon == cds[t].icon.tx)
		check("  its bar's icon too", g and cds[t] and g.buttons[cds[t].bar.icon] ~= nil and g.buttons[cds[t].bar.icon].Icon == cds[t].bar.icon.tx)
	end
	check("test icons stay in the CDTL3 group", root and cds.testing and root.buttons[cds.testing.icon] ~= nil)
	check("each button in one group only, after every refresh", doubled == 0)
	local sc = cds.spells
	sc.data.type = "buffs"
	xpcall(function() CDTL3:RefreshIcon(sc) end, ERRH)
	check("a frame now showing a buff moves from Spells to Buffs", groups["CDTL3/Spells"].buttons[sc.icon] == nil and groups["CDTL3/Buffs"].buttons[sc.icon] ~= nil and doubled == 0)
	sc.data.type = "spells"
	CDTL3.Masque, CDTL3.masqueGroups = realMasque, nil
	xpcall(function() CDTL3:RefreshAllIcons(); CDTL3:RefreshAllBars() end, ERRH)
	check("without Masque: refreshes run, no Lua errors", #ERRORS == e0, tostring(#ERRORS - e0))
end

print(string.format("RESULT share %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
