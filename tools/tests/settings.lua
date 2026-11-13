-- Settings and saved data (red team of 12 Nov 2026, cards 1-6, 9, 10, 14, 34): an "All Settings
-- and Data" import never empties the Filters lists, a badly shaped string is refused before
-- anything is written (a lane on H:MM:SS still round trips), Clear Individual Settings on an entry
-- other characters use asks first and then clears it for all, Filters selections act for this
-- character only, Reset Profile / Copy From ask first, built-in spell data is copied before it's saved,
-- the unlock box follows the lock, Add New's Enabled box, Trigger IDs that aren't spells, and
-- test mode frames. Real files, real AceDB / AceDBOptions / AceSerializer.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "ROGUE"
local ME, OTHER = PLAYER.guid, "Player-1-0000099"

CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {} } }

SPELLINFO[2139] = { "Counterspell", 135856 }
SPELLINFO[1856] = { "Vanish", 132331 }
SPELLINFO[1784] = { "Stealth", 132320 }
KNOWN[2139], KNOWN[1856] = true, true
BASECD[2139] = 24000
BASECD[1856] = 300000

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function clear(t) for k in pairs(t) do t[k] = nil end return t end
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
local function T() return CDTL3.db.profile.tables end

local AS = LibStub("AceSerializer-3.0")
local LD = LibStub("LibDeflate")
-- LibDeflate's inflate doesn't round-trip under fengari, so compression passes the data through;
-- AceSerializer, EncodeForPrint/DecodeForPrint, the export box and ImportHandler run as shipped
LD.CompressDeflate = function(_, s) return s end
LD.DecompressDeflate = function(_, s) return s end
local function encode(t) return LD:EncodeForPrint(LD:CompressDeflate(AS:Serialize(t))) end
local function decode(s) local ok, t = AS:Deserialize(LD:DecompressDeflate(LD:DecodeForPrint(s))); return ok and t end
local function export(mode)
	CDTL3.db.profile.global.exportMode = mode
	return CDTL3:GetFullOptions().args.importexport.args.exportbox.get({})
end
local function import(mode, str)
	CDTL3.db.profile.global.importMode = mode
	local n, e = #CHAT, #ERRORS
	xpcall(function() CDTL3:ImportHandler(str) end, ERRH)
	return chatSince(n, "error importing"), #ERRORS - e, n
end

---------------------------------------------------------------- card 1: All Settings and Data keeps the Filters lists
print("[card 1 import keeps Filters lists " .. FLAVOR .. "]")
do
	local p = CDTL3.db.profile
	clear(T().spells); clear(T().customs); clear(T().buffs)
	table.insert(T().spells, entry(2139, "Counterspell", { ME }, { lane = 3, setCustomCD = true, customCDTime = 20000 }))
	table.insert(T().customs, CDTL3:ApplyEntryDefaults({ id = 2139, name = "My Custom", type = "customs", bCD = 60000, triggerType = "spell" }, "customs"))

	-- a friend's "CDTL3 Settings Only" string (the real export box), with one setting that differs
	p.lanes.lane1.width = 333
	local settingsOnly = export("SETTINGS")
	p.lanes.lane1.width = 400
	local sent = decode(settingsOnly)
	check("Settings Only export: its Filters lists are empty", sent and count(sent.tables.spells) == 0 and count(sent.tables.customs) == 0)

	local refused, errs, n = import("ALL", settingsOnly)
	p = CDTL3.db.profile
	check("Settings Only string imported with All: accepted, no Lua errors", not refused and errs == 0, tostring(errs))
	check("  settings imported (lane 1 width 333)", p.lanes.lane1.width == 333, tostring(p.lanes.lane1.width))
	check("  this profile's spells kept", names(T().spells) == "Counterspell" and T().spells[1].lane == 3 and T().spells[1].customCDTime == 20000, names(T().spells))
	check("  this profile's Customs kept", names(T().customs) == "My Custom", names(T().customs))
	check("  chat says the string had no Filters lists and they were kept", chatSince(n, "Settings Only export") and chatSince(n, "Filters lists were kept"))
	check("  this profile's import/export choices kept", p.global.importMode == "ALL" and p.global.exportMode == "SETTINGS")

	-- an "All Settings and Data" export really carries the Filters lists
	local all = export("ALL")
	local carried = decode(all)
	check("All export carries the Filters lists (spell with its Custom CD Time, Custom)", carried and count(carried.tables.spells) == 1
		and carried.tables.spells[1].customCDTime == 20000 and count(carried.tables.customs) == 1)

	-- a receiver with other lists: the string's lists replace theirs, a list the string leaves empty stays
	clear(T().spells); clear(T().customs)
	table.insert(T().spells, entry(5001, "Receiver Spell", { ME }))
	table.insert(T().buffs, entry(5002, "Receiver Buff", { ME }, { type = "buffs" }))
	p.lanes.lane1.width = 400
	refused, errs, n = import("ALL", all)
	p = CDTL3.db.profile
	check("All string imported with All: accepted, no Lua errors", not refused and errs == 0, tostring(errs))
	check("  string's spells imported (replace this profile's)", names(T().spells) == "Counterspell", names(T().spells))
	check("  string's Customs imported", names(T().customs) == "My Custom", names(T().customs))
	check("  Buffs (empty in the string) kept", names(T().buffs) == "Receiver Buff", names(T().buffs))
	check("  chat names the kept list", chatSince(n, "Buffs") and chatSince(n, "were kept"))
	check("  string's settings imported", p.lanes.lane1.width == 333, tostring(p.lanes.lane1.width))
	clear(T().buffs)

	-- control: Cooldown Data Only still refuses a Settings Only string
	refused = import("CDDATA", settingsOnly)
	check("control: Cooldown Data Only refuses a Settings Only string, lists untouched", refused and names(T().spells) == "Counterspell")
	p.lanes.lane1.width = 400
end

---------------------------------------------------------------- card 5: nested shape checked before anything is written
print("[card 5 import shape " .. FLAVOR .. "]")
do
	local p = CDTL3.db.profile
	local function settingsWith(path, value)
		local t = decode(export("ALL"))
		local node = t
		for i = 1, #path - 1 do node = node[path[i]] end
		node[path[#path]] = value
		return t
	end
	local function refusedCleanly(label, mode, t, after)
		local before = AS:Serialize(CDTL3.db.profile)
		local refused, errs = import(mode, encode(t))
		CDTL3.db.profile.global.importMode = "SETTINGS"
		local same = AS:Serialize(CDTL3.db.profile):gsub("importMode^S%w+", "") == before:gsub("importMode^S%w+", "")
		check(label .. ": refused, profile unchanged, no Lua errors", refused and same and errs == 0, string.format("refused=%s same=%s errors=%d", tostring(refused), tostring(same), errs))
	end
	refusedCleanly("Settings: lanes.lane1 = 0", "SETTINGS", { global = {}, lanes = { lane1 = 0 }, barFrames = {}, ready = {}, holders = {} })
	refusedCleanly("Settings: lanes.lane1.tracking = \"x\"", "SETTINGS", settingsWith({ "lanes", "lane1", "tracking" }, "x"))
	refusedCleanly("Settings: lanes.lane1.width = \"wide\"", "SETTINGS", settingsWith({ "lanes", "lane1", "width" }, "wide"))
	refusedCleanly("Settings: ready.ready1.icons.border.color = 5", "SETTINGS", settingsWith({ "ready", "ready1", "icons", "border", "color" }, 5))
	refusedCleanly("All: global.spells = 7", "ALL", settingsWith({ "global", "spells" }, 7))
	refusedCleanly("All: tables.spells = { 5 }", "ALL", settingsWith({ "tables", "spells" }, { 5 }))
	refusedCleanly("All: tables = \"x\"", "ALL", settingsWith({ "tables" }, "x"))
	refusedCleanly("All: an extra list tables.extra = 5", "ALL", settingsWith({ "tables", "extra" }, 5))
	refusedCleanly("Cooldown Data: spells = { 5 }", "CDDATA", { spells = { 5 } })
	refusedCleanly("Cooldown Data: an entry with usedBy = 5", "CDDATA", { spells = { entry(7001, "Bad Owners", 5) } })
	refusedCleanly("Cooldown Data: an entry with bCD = \"long\"", "CDDATA", { spells = { entry(7002, "Bad Time", { ME }, { bCD = "long" }) } })

	local e0 = #ERRORS
	for i = 1, 3 do FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-shape" .. i, 2139); Advance(30) end
	xpcall(function() CDTL3:RefreshConfig() end, ERRH)
	check("after the refused strings: casts and a refresh run with no Lua errors", #ERRORS == e0, tostring(#ERRORS - e0))

	-- every real export still passes: set every option the window shows to its own value (what the
	-- setters write), then the welcome window's "previousVersion" text, then round trip each mode
	local isInherited = { set = true, get = true, disabled = true, hidden = true, validate = true }
	local function member(root, path, option, name)
		if not isInherited[name] then return option[name] end
		local g, m = root, root[name]
		for i = 1, #path do g = g.args[path[i]]; if g[name] ~= nil then m = g[name] end end
		return m
	end
	local function call(root, path, option, name, ...)
		local m = member(root, path, option, name)
		if type(m) ~= "function" and type(m) ~= "string" then return true, m end
		local info, g, handler = {}, root, root.handler
		for i = 1, #path do info[i] = path[i]; g = g.args[path[i]]; handler = g.handler or handler end
		info.options, info.appName, info.option, info.type, info.arg, info.handler = root, "CDTL3", option, option.type, option.arg, handler
		if type(m) == "string" then
			if type(option[name]) == "string" and (name == "name" or name == "desc") then return true, m end
			return pcall(handler[m], handler, info, ...)
		end
		return pcall(m, info, ...)
	end
	local walked = 0
	local function walk(root, group, path)
		for k, v in pairs(group.args or {}) do
			if k ~= "profiles" and k ~= "importbox" and k ~= "exportbox" then
				path[#path + 1] = k
				local ok, hidden = call(root, path, v, "hidden")
				if ok and not hidden then
					if v.type == "group" then
						walk(root, v, path)
					elseif v.type ~= "execute" and v.type ~= "description" and v.type ~= "header" and v.type ~= "multiselect" then
						local okg, a, b, c, d = call(root, path, v, "get")
						if okg then
							walked = walked + 1
							if v.type == "color" then
								call(root, path, v, "set", a or 1, b or 1, c or 1, d or 1)
							else
								local val = a
								if v.type == "select" and val == nil then
									local okv, vals = call(root, path, v, "values")
									val = okv and type(vals) == "table" and next(vals) or nil
								end
								if v.type == "toggle" and val == nil then val = false end
								if v.type == "range" and val == nil then val = v.min or v.softMin or 1 end
								if v.type == "input" and val ~= nil then
									-- AceConfigDialog calls set only when validate accepts the text
									local okv, res = call(root, path, v, "validate", val)
									if okv and res ~= nil and res ~= true and type(member(root, path, v, "validate")) == "function" then val = nil end
								end
								if val ~= nil and not (v.type == "input" and val == "") then
									call(root, path, v, "set", val)
								end
							end
						end
					end
				end
				path[#path] = nil
			end
		end
	end
	local root = CDTL3:GetFullOptions()
	local w0 = #ERRORS
	walk(root, root, {})
	CDTL3.db.profile.global.previousVersion = CDTL3.version	-- as the welcome window's close (CDTL3.lua) saves it
	table.insert(T().customs, CDTL3:ApplyEntryDefaults({ id = 2139, name = "Walk Custom", type = "customs", bCD = 60000, triggerType = "spell" }, "customs"))
	check("set every shown option to its own value (" .. walked .. " options), no Lua errors", walked > 500 and #ERRORS == w0, tostring(#ERRORS - w0))
	for _, mode in ipairs({ "ALL", "SETTINGS", "CDDATA" }) do
		local refused, errs = import(mode, export(mode))
		check("round trip after the walk, " .. mode .. ": accepted, no Lua errors", not refused and errs == 0, tostring(errs))
	end

	-- a Linear (Time) or Split (Time) lane on H:MM:SS saves its marks as ConvertTime gives them: a
	-- number for a mark under a minute, where the default is text. Its own export comes back in.
	for _, mode in ipairs({ "LINEAR_ABS", "SPLIT_ABS" }) do
		local l1 = CDTL3.db.profile.lanes.lane1	-- an import replaces the lanes table
		l1.mode.type = mode
		l1.mode.linearAbs.timeFormat, l1.mode.splitAbs.timeFormat, l1.mode.linearAbs.max = "H:MM:SS", "H:MM:SS", 180
		xpcall(function() CDTL3:RefreshLane(1) end, ERRH)
		local mark = l1.modeText.text2.text
		check(mode .. " on H:MM:SS: its first mark is saved as a number", type(mark) == "number", type(mark) .. " " .. tostring(mark))
		for _, m in ipairs({ "SETTINGS", "ALL" }) do
			local refused, errs = import(m, export(m))
			check("  its own " .. m .. " export imports: accepted, no Lua errors", not refused and errs == 0, string.format("refused=%s errors=%d", tostring(refused), errs))
		end
	end
	local l1 = CDTL3.db.profile.lanes.lane1
	l1.mode.type, l1.mode.linearAbs.timeFormat, l1.mode.splitAbs.timeFormat, l1.mode.linearAbs.max = "LINEAR", "XhYmZs", "XhYmZs", 120
	xpcall(function() CDTL3:RefreshLane(1) end, ERRH)
	if CDTL3.db.profile.global.unlockFrames then CDTL3:ToggleFrameLock(true) end
end

---------------------------------------------------------------- card 2: Clear Individual Settings, shared entries
print("[card 2 clear individual settings " .. FLAVOR .. "]")
do
	local fopts = CDTL3:GetFilterOptions()
	local cs = fopts.args.spells.args.clearSettings
	local spells = clear(T().spells)
	local shared = entry(3001, "Shared Spell", { ME, OTHER }, { lane = 3, setCustomCD = true, customCDTime = 15000 })
	local theirsSame = entry(3003, "Same Name", { OTHER }, { lane = 2 })
	for _, e in ipairs({ shared, entry(3002, "Mine Spell", { ME }), theirsSame, entry(3004, "Same Name", { ME }) }) do table.insert(spells, e) end

	-- an entry other characters use too: the button asks first, saying it resets them for everyone,
	-- and on Confirm the entry goes (only dropping this character let the next cast claim it back)
	local function warns(c)
		return type(c) == "string" and c:find("Other characters on this profile use these settings", 1, true) ~= nil
			and c:find("resets them for every character on this profile", 1, true) ~= nil
	end
	local function confirmOf(o) if type(o.confirm) == "function" then return o.confirm({}) end return o.confirm end
	CDTL3.currentFilter["spells"] = "Shared Spell"; CDTL3.currentFilterHidden["spells"] = false
	local c = confirmOf(cs)
	check("shared entry: Clear asks first, warning it resets every character's settings", warns(c), tostring(c))
	cs.func({})
	check("  on Confirm the entry goes for everyone", names(T().spells) == "Mine Spell,Same Name,Same Name", names(T().spells))
	check("  selection back to << Select >>", CDTL3.currentFilter["spells"] == "<< Select >>" and CDTL3.currentFilterHidden["spells"] == true)
	-- the next cast (as after a reload) starts it fresh: no old settings to claim back
	SPELLINFO[3001], KNOWN[3001] = { "Shared Spell", 1 }, true
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-shared", 3001)
	local back
	for k = #T().spells, 1, -1 do
		local e = T().spells[k]
		if e.name == "Shared Spell" then back = e; table.remove(T().spells, k) end
	end
	check("  the next cast starts it fresh: lane 3 and the Custom CD Time don't come back", back == nil or (back.lane ~= 3 and back.customCDTime ~= 15000),
		back and string.format("lane %s, Custom CD Time %s", tostring(back.lane), tostring(back.customCDTime)) or "no entry")
	SPELLINFO[3001], KNOWN[3001] = nil, nil

	CDTL3.currentFilter["spells"] = "Mine Spell"; CDTL3.currentFilterHidden["spells"] = false
	c = confirmOf(cs)
	check("an entry only I use: the usual confirm, no shared warning", c == true, tostring(c))
	cs.func({})
	check("  removed", names(T().spells) == "Same Name,Same Name", names(T().spells))

	CDTL3.currentFilter["spells"] = "Same Name"; CDTL3.currentFilterHidden["spells"] = false
	c = confirmOf(cs)
	check("same name, another character's own copy: mine is only mine, no shared warning", c == true, tostring(c))
	cs.func({})
	check("  mine removed, theirs kept", #T().spells == 1 and T().spells[1] == theirsSame
		and theirsSame.usedBy[1] == OTHER and theirsSame.lane == 2, names(T().spells))

	local customs = clear(T().customs)
	local sharedCustom = CDTL3:ApplyEntryDefaults({ id = 2139, name = "Shared Custom", type = "customs", bCD = 60000, triggerType = "spell" }, "customs")
	sharedCustom.usedBy = { OTHER, ME }
	table.insert(customs, sharedCustom)
	CDTL3.currentFilter["customs"] = "Shared Custom"
	local ccs = fopts.args.customs.args.saved.args.clearSettings
	c = confirmOf(ccs)
	check("a Custom other characters use: asks first with the warning", warns(c), tostring(c))
	ccs.func({})
	check("  on Confirm it goes for everyone", #T().customs == 0, names(T().customs))
	check("  Custom tab back to << Add New >>", CDTL3.currentFilter["customs"] == "<< Add New >>")
	c = confirmOf(ccs)
	check("  << Add New >>: Clear keeps its usual confirm", c == true, tostring(c))
	clear(T().spells); clear(T().customs)
end

---------------------------------------------------------------- card 4: stale Filters selection
print("[card 4 stale Filters selection " .. FLAVOR .. "]")
do
	local QUEST = { [7101] = true }
	local realInstant = C_Item.GetItemInfoInstant
	C_Item.GetItemInfoInstant = function(id) return id, "Item", "Misc", "", 134400, QUEST[id] and 12 or 4, 0 end
	local function item(itemID, owners) return { id = 60000 + itemID, name = "Use " .. itemID, itemName = "Item " .. itemID, itemID = itemID,
		type = "items", icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1, enabled = true, ignored = false, usedBy = owners } end
	local items = clear(T().items)
	table.insert(items, item(7101, { ME }))
	table.insert(items, item(7102, { ME }))
	local def = CDTL3:GetFilterOptions().args.defaults.args
	CDTL3.currentFilter["default"] = "ITEMS"

	CDTL3.currentFilter["items"] = "Item 7101"; CDTL3.currentFilterHidden["items"] = false
	def.clearQuestItems.func({})
	check("Clear Quest Items: the cleared item's selection goes back to << Select >>", CDTL3.currentFilter["items"] == "<< Select >>"
		and CDTL3.currentFilterHidden["items"] == true, tostring(CDTL3.currentFilter["items"]))
	CDTL3.currentFilter["items"] = "Item 7102"; CDTL3.currentFilterHidden["items"] = false
	def.clearQuestItems.func({})
	check("control: a kept item stays selected", CDTL3.currentFilter["items"] == "Item 7102" and CDTL3.currentFilterHidden["items"] == false)
	C_Item.GetItemInfoInstant = realInstant
	clear(T().items)
	CDTL3.currentFilter["default"] = "SPELLS"

	-- profile switch: the new profile has the same name, used only by another character
	CDTL3.db:SetProfile("Alt")
	local altEntry = entry(2139, "Counterspell", { OTHER }, { lane = 2 })
	table.insert(T().spells, altEntry)
	CDTL3.db:SetProfile("Default")
	table.insert(T().spells, entry(2139, "Counterspell", { ME }))
	table.insert(T().customs, CDTL3:ApplyEntryDefaults({ id = 2139, name = "Default Custom", type = "customs", bCD = 60000, triggerType = "spell" }, "customs"))
	CDTL3.currentFilter["spells"] = "Counterspell"; CDTL3.currentFilterHidden["spells"] = false
	CDTL3.currentFilter["customs"] = "Default Custom"
	xpcall(function() CDTL3:RefreshConfig() end, ERRH)
	check("control: a refresh in the same profile keeps a valid selection", CDTL3.currentFilter["spells"] == "Counterspell" and CDTL3.currentFilter["customs"] == "Default Custom")
	CDTL3.db:SetProfile("Alt")
	check("profile switch: a selection that isn't mine there goes back to << Select >>", CDTL3.currentFilter["spells"] == "<< Select >>"
		and CDTL3.currentFilterHidden["spells"] == true, tostring(CDTL3.currentFilter["spells"]))
	check("profile switch: Custom tab back to << Add New >>", CDTL3.currentFilter["customs"] == "<< Add New >>")
	check("  the other character's entry untouched", altEntry.lane == 2 and #altEntry.usedBy == 1)
	CDTL3.db:SetProfile("Default")
	clear(T().spells); clear(T().customs)
end

---------------------------------------------------------------- card 3: Reset Profile and Copy From ask first
print("[card 3 profile confirms " .. FLAVOR .. "]")
do
	local function hasConfirm(o) return o and o.confirm == true and type(o.confirmText) == "string"
		and o.confirmText:find("Every character on this profile loses its Filters lists", 1, true) ~= nil end
	local pa = CDTL3:GetFullOptions().args.profiles.args
	check("Reset Profile asks first, and says every character loses its Filters lists", hasConfirm(pa.reset))
	check("Copy From asks first, same warning", hasConfirm(pa.copyfrom))
	check("Delete still asks first", pa.delete and pa.delete.confirm == true)
	check("Reset and Copy From still call AceDBOptions' own handlers", pa.reset.func == "Reset" and pa.copyfrom.set == "CopyProfile")
	local reg = LibStub("AceConfigRegistry-3.0")
	xpcall(function() CDTL3:RefreshConfig() end, ERRH)
	local registered = reg.tables["CDTL3"]
	if type(registered) == "function" then registered = registered("dialog", "AceConfigDialog-3.0") end
	check("the registered window (after a refresh) has both confirms", registered and hasConfirm(registered.args.profiles.args.reset)
		and hasConfirm(registered.args.profiles.args.copyfrom))
	-- AceDBOptions shares one args table between every addon: another addon's Profiles tab is unchanged
	OTHERADDONDB = {}
	local odb = LibStub("AceDB-3.0"):New("OTHERADDONDB")
	local ot = LibStub("AceDBOptions-3.0"):GetOptionsTable(odb)
	check("another addon's Reset Profile / Copy From unchanged", ot.args.reset.confirm == nil and ot.args.copyfrom.confirm == nil and ot.args ~= pa)
	-- Reset still resets (in a scratch profile)
	CDTL3.db:SetProfile("ResetMe")
	CDTL3.db.profile.lanes.lane1.width = 222
	local okr = xpcall(function() CDTL3.profile.handler:Reset() end, ERRH)
	check("Reset still resets the profile", okr and CDTL3.db.profile.lanes.lane1.width == 400, tostring(CDTL3.db.profile.lanes.lane1.width))
	CDTL3.db:SetProfile("Default")
end

---------------------------------------------------------------- card 6: built-in spell data copied before it's saved
print("[card 6 spell data copies " .. FLAVOR .. "]")
do
	local function savedNamed(n) for _, e in pairs(T().spells) do if e.name == n then return e end end end
	local function isDataRow(e) for _, s in ipairs(CDTL3.spellData) do if rawequal(s, e) then return true end end return false end
	local function noRowSaved(label)
		local shared = 0
		for _, e in pairs(T().spells) do if isDataRow(e) then shared = shared + 1 end end
		local touched = 0
		for _, s in ipairs(CDTL3.spellData) do if s.usedBy ~= nil or s.lane ~= nil then touched = touched + 1 end end
		check(label .. ": no saved entry is a spell data row, and the data rows are unchanged", shared == 0 and touched == 0,
			string.format("shared=%d touched=%d", shared, touched))
	end

	if CDTL3.tocversion < 40000 then
		clear(T().spells)
		CDTL3:CheckEdgeCases("Vanish")
		local a = savedNamed("Stealth")
		check("Vanish with no saved Stealth: Stealth saved", a ~= nil)
		if a then
			noRowSaved("Vanish -> Stealth")
			a.lane, a.ignored, a.barFrame = 3, true, 2		-- the player's Filters changes in profile Default
			CDTL3.db:SetProfile("Spec2")
			clear(T().spells)
			CDTL3:CheckEdgeCases("Vanish")
			local b = savedNamed("Stealth")
			check("second profile: its own Stealth entry, not Default's", b ~= nil and not rawequal(a, b))
			check("Default's Stealth keeps lane 3 / ignored / bar frame 2", a.lane == 3 and a.ignored == true and a.barFrame == 2,
				string.format("%s/%s/%s", tostring(a.lane), tostring(a.ignored), tostring(a.barFrame)))
			CDTL3.db:SetProfile("Default")
		end
	else
		print("  (Vanish -> Stealth from the data runs only on the Classic lists)")
	end

	-- Shadowmeld and the paladin lockouts (Detect Shared CD) build entries from the data the same way
	local g = CDTL3.db.profile.global
	g.detectSharedCD = true
	local realData = CDTL3.spellData
	for _, case in ipairs({ { "PALADIN", "Human", "Divine Shield" }, { "PALADIN", "Human", "Avenging Wrath" }, { "ROGUE", "NightElf", "Shadowmeld" } }) do
		CDTL3.spellData = CDTL3:GetAllSpellData(case[1], case[2])
		clear(T().spells)
		local e0 = #ERRORS
		xpcall(function() CDTL3:CheckEdgeCases(case[3]) end, ERRH)
		if #T().spells > 0 then
			noRowSaved(case[3] .. " (" .. #T().spells .. " saved)")
		else
			print("  (" .. case[3] .. ": this client's data saves nothing here)")
		end
		check(case[3] .. ": no Lua errors", #ERRORS == e0)
	end
	CDTL3.spellData = realData
	g.detectSharedCD = false
	clear(T().spells)
end

---------------------------------------------------------------- card 9: the unlock box follows the lock state
print("[card 9 unlock box " .. FLAVOR .. "]")
do
	local popup = CDTL3.unlockFrame
	local btn = _G["CDTL3_Unlock_Frame_Button"]
	local function locked() return not CDTL3.db.profile.global.unlockFrames end
	CDTL3.db:SetProfile("LockA")	-- new profiles start unlocked
	check("unlocked profile: box shown", not locked() and popup:IsShown())
	CDTL3.db:SetProfile("LockB")
	CDTL3:ToggleFrameLock()
	check("second profile locked: box hidden", locked() and not popup:IsShown())
	CDTL3.db:SetProfile("LockA")
	check("back to the unlocked profile: box shown", not locked() and popup:IsShown())
	CDTL3.db:SetProfile("LockB")
	check("switch to the locked profile: box hidden", locked() and not popup:IsShown())
	popup:Show()	-- however the box got up over locked frames, Lock must not unlock them
	xpcall(btn.__scripts.OnClick, ERRH, btn)
	check("Lock with frames already locked: they stay locked, box hidden", locked() and not popup:IsShown())
	CDTL3.db:SetProfile("LockA")
	xpcall(btn.__scripts.OnClick, ERRH, btn)
	check("Lock on unlocked frames: locked, box hidden", locked() and not popup:IsShown())
	CDTL3.db:SetProfile("Default")
end

---------------------------------------------------------------- cards 10 and 14: Custom > Add New
print("[cards 10, 14 Custom > Add New " .. FLAVOR .. "]")
do
	-- the game reads a numeric string (what the input box gives) as a spell ID and returns nothing
	-- for an ID that isn't a spell; the stubs take only numbers and name every number
	local realC, realG = C_Spell.GetSpellInfo, GetSpellInfo
	local function lookup(id) local n = tonumber(id); return n and SPELLINFO[n], n end
	if RETAILAPI then
		C_Spell.GetSpellInfo = function(id) local s, n = lookup(id); if s then return { name = s[1], iconID = s[2], originalIconID = s[2], spellID = n } end end
	else
		GetSpellInfo = function(id) local s, n = lookup(id); if s then return s[1], "", s[2], 0, 0, 0, n, s[2] end end
	end

	local a = CDTL3:GetFilterOptions().args.customs.args.saved.args
	local function fresh()
		CDTL3.currentFilter["customs"] = "<< Add New >>"
		CDTL3.currentFilterHidden["customs"] = false
		CDTL3.custom = {}
		CDTL3.customIsValid = false
		a.triggerType.set({}, "spell")
	end

	-- card 14: an ID that isn't a spell is refused (Retail/Forever gave a blank name before)
	fresh()
	a.triggerID.set({}, "99999999")
	check("Trigger ID that isn't a spell: refused", CDTL3.customIsValid == false and CDTL3.custom.name == nil, tostring(CDTL3.custom.name))
	check("  Save Custom stays disabled", a.saveCustom.disabled() == true)
	a.triggerID.set({}, "2139")
	check("a real spell ID is accepted", CDTL3.customIsValid == true and CDTL3.custom.name == "Counterspell", tostring(CDTL3.custom.name))

	-- card 10: Enabled can be unticked, shows unticked, and saves off
	clear(T().customs)
	check("Enabled starts ticked (Customs show by default)", a.enabled.get({}) == true)
	a.enabled.set({}, false)
	local shown = a.enabled.get({})
	check("unticked: the box reads false (explicit false)", shown == false, tostring(shown))
	a.enabled.set({}, true)
	check("ticked again: true", a.enabled.get({}) == true)
	a.enabled.set({}, false)
	a.saveCustom.func({})
	local saved = T().customs[1]
	check("saved custom is switched off, as the box showed", saved and saved.name == "Counterspell" and saved.enabled == false)

	local g = CDTL3.db.profile.global
	g.customs.showByDefault = false
	fresh()
	a.triggerID.set({}, "2139")
	check("Customs hidden by default: box starts unticked", a.enabled.get({}) == false)
	a.enabled.set({}, true)
	check("  ticking it reads true", a.enabled.get({}) == true)
	g.customs.showByDefault = true
	CDTL3.custom = {}
	CDTL3.customIsValid = false
	clear(T().customs)
	C_Spell.GetSpellInfo, GetSpellInfo = realC, realG
end

---------------------------------------------------------------- card 34: test mode
print("[card 34 test mode " .. FLAVOR .. "]")
do
	local g = CDTL3.db.profile.global
	g.testingType, g.testingNumber, g.testingMinTime, g.testingMaxTime = "spells", 3, 10, 30
	local function tests()
		local entries, frames = 0, {}
		for _, cd in ipairs(CDTL3.cooldowns) do
			if cd.data.type == "testing" then entries = entries + 1; frames[cd] = true end
		end
		return entries, count(frames), frames
	end
	-- the Test Panel's Clear button (CDTL3:CreateTestingFrame, CDTL3.lua)
	local function clearTests()
		for _, cd in ipairs(CDTL3.cooldowns) do
			if cd.data["type"] == "testing" and cd.icon:GetParent():GetName() ~= "CDTL3_Active_Icon_Holding" then
				CDTL3:SendToHolding(cd)
				CDTL3:SendToBarHolding(cd)
			end
		end
	end
	local e0 = #ERRORS
	CDTL3:GenerateTestCooldowns()
	local entries, frames, first = tests()
	check("Create 3: each test cooldown listed once", entries == 3 and frames == 3, string.format("%d entries, %d frames", entries, frames))
	RunOnUpdate(0.02, 50)
	clearTests()
	g.testingMinTime, g.testingMaxTime = 20, 40
	CDTL3:GenerateTestCooldowns()
	local entries2, frames2, second = tests()
	local reused = 0
	for cd in pairs(second) do if first[cd] then reused = reused + 1 end end
	check("Clear then Create: the parked frames are reused, no new ones", entries2 == 3 and frames2 == 3 and reused == 3,
		string.format("%d entries, %d frames, %d reused", entries2, frames2, reused))
	local inLanes, fresh = 0, 0
	for cd in pairs(second) do
		if cd.icon:GetParent():GetName() ~= "CDTL3_Active_Icon_Holding" then inLanes = inLanes + 1 end
		if cd.data.baseCD >= 20 and math.abs(cd.data.currentCD - cd.data.baseCD) < 0.01 then fresh = fresh + 1 end
	end
	check("  reused ones are back on their lane with the new times (20-40 s), restarted", inLanes == 3 and fresh == 3,
		string.format("on lane %d, restarted %d", inLanes, fresh))
	local byName = {}
	for cd in pairs(second) do byName[cd.data.name] = true end
	check("  named Test Spell 1-3", byName["Test Spell 1"] and byName["Test Spell 2"] and byName["Test Spell 3"])
	CDTL3:GenerateTestCooldowns()
	local entries3, frames3 = tests()
	check("Create again without Clear: 3 more (nothing parked to reuse)", entries3 == 6 and frames3 == 6, string.format("%d entries, %d frames", entries3, frames3))
	RunOnUpdate(0.02, 50)
	check("test mode: no Lua errors", #ERRORS == e0, tostring(#ERRORS - e0))
	clearTests()
end

print(string.format("RESULT settings %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
