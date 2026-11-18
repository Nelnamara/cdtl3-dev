-- Options tree dump, for refactors of Options.lua (or any file that adds options): prints the whole
-- settings window as text, so the dump from the old code and the dump from the new code can be
-- compared line by line. Every key of every option in sorted order (type, name, desc, order, width,
-- values and the rest); functions are called with the info AceConfigDialog would pass, inside a
-- pcall (name, desc, hidden, disabled, values, get, confirm, image...), and members an option takes
-- from a parent group (get, hidden, disabled...) are called for it too; set, func and validate are
-- noted as present. Then every setter is run once with a new value, printing the CDTL3 methods it
-- called and what get gives back, and at the end the saved settings in full and the data of the
-- running cooldowns (two spells are cast first, so the Filters controls change live ones too).
-- Dumped in several states: right after login; with every text slot used and in edit, Filters
-- entries selected and a valid Custom being added; a saved Custom selected; an invalid Custom; the
-- set pass; then the tree again.
--
-- Run it from the repo root on the old code (a copy outside the repo) and on the new, for each
-- client, and diff the files (about 100,000 lines each, half a minute a client):
--   mkdir ../old && git archive <old commit> | tar -x -C ../old
--   node tools/tests/run.js ../old 120105 tools/tests/optionsdump.lua CooldownTimeline3_Mainline.toc > ../old.txt
--   node tools/tests/run.js . 120105 tools/tests/optionsdump.lua CooldownTimeline3_Mainline.toc > ../new.txt
--   diff ../old.txt ../new.txt
-- The other clients: 50504 CooldownTimeline3_Mists.toc, 20506 CooldownTimeline3_TBC.toc,
-- 11509 CooldownTimeline3_Vanilla.toc, 16001 CooldownTimeline3_Camelot.toc. An optional last
-- argument picks the class (default: DEATHKNIGHT on Retail and MoP, else ROGUE).
-- Not in runall.sh: it has nothing to check by itself. Its last line, RESULT, counts the Lua errors
-- outside the option calls (0 expected); an option call that errors shows as "error" in the dump.
dofile(HARNESS_DIR .. "/wow.lua")
local class = HARNESS_ARG ~= "" and HARNESS_ARG or ((FLAVOR == "retail" or FLAVOR == "mop") and "DEATHKNIGHT" or "ROGUE")
PLAYER.class = class
PLAYER.race = (class == "DEATHKNIGHT") and "NightElf" or "Human"
local ME = PLAYER.guid

-- saved entries on every Filters tab, so the per-entry controls have something to show
local function entry(t, id, name, extra)
	local e = { id = id, name = name, type = t, icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
SPELLINFO[2139] = { "Counterspell", 135856 }
SPELLINFO[1856] = { "Vanish", 132331 }
KNOWN[2139], KNOWN[1856] = true, true
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = { tables = {
	spells = { entry("spells", 2139, "Counterspell", { setCustomCD = true, customCDTime = 20000 }), entry("spells", 1856, "Vanish") },
	items = { entry("items", 5512, "Healthstone", { itemName = "Healthstone", itemIcon = 2 }) },
	buffs = { entry("buffs", 1784, "Stealth", { bCD = 10000 }) },
	debuffs = { entry("debuffs", 25771, "Forbearance", { bCD = 60000 }) },
	offensives = { entry("offensives", 1943, "Rupture", { bCD = 16000 }) },
	petspells = { entry("petspells", 17253, "Bite", { bCD = 10000 }) },
	runes = { entry("runes", 1, "Blood Rune", { bCD = 10000 }) },
	customs = { entry("customs", 2139, "My Custom", { bCD = 60000, triggerType = "spell" }) },
	detected = { entry("detected", 1856, "Vanish") },
} } } }

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
-- both spells cooling down, so the Filters controls change a running cooldown too
SPELLCD[2139] = { startTime = NOW, duration = 24, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
SPELLCD[1856] = { startTime = NOW, duration = 300, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2139)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 1856)
RunOnUpdate(0.02, 10)
local errorsAtStart = #ERRORS

---------------------------------------------------------------- text of a value
local function keyLess(a, b)
	local ta, tb = type(a), type(b)
	if ta ~= tb then return ta < tb end
	if ta == "number" or ta == "string" then return a < b end
	return tostring(a) < tostring(b)
end
local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys, keyLess)
	return keys
end
local function text(v, depth, seen)
	local tv = type(v)
	if tv == "string" then
		return (string.format("%q", v):gsub("\\\n", "\\n"))
	elseif tv == "number" then
		if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
		return string.format("%.17g", v)
	elseif tv == "table" then
		if v == CDTL3 then return "<CDTL3>" end
		seen = seen or {}
		depth = depth or 0
		if seen[v] then return "<cycle>" end
		if depth > 8 then return "<deep>" end
		seen[v] = true
		local parts = {}
		for _, k in ipairs(sortedKeys(v)) do
			parts[#parts + 1] = "[" .. text(k) .. "]=" .. text(v[k], depth + 1, seen)
		end
		seen[v] = nil
		return "{" .. table.concat(parts, ",") .. "}"
	elseif tv == "function" then
		return "fn"
	end
	return tostring(v)
end
local function pack(...) return { n = select("#", ...), ... } end
local function texts(p, from)
	local parts = {}
	for i = from or 1, p.n do parts[#parts + 1] = text(p[i]) end
	return table.concat(parts, ", ")
end

---------------------------------------------------------------- calling an option's members
-- members AceConfigDialog takes from the nearest parent group that has them
local INHERITED = { set = true, get = true, func = true, confirm = true, validate = true, disabled = true, hidden = true }
-- members that are run only by a click or a change: noted, not called
local NOT_CALLED = { set = true, func = true, validate = true }

local function infoFor(root, path, option, handler)
	local info = {}
	for i = 1, #path do info[i] = path[i] end
	info.options, info.appName, info.option, info.type, info.arg, info.handler = root, "CDTL3", option, option.type, option.arg, handler
	info.uiType, info.uiName = "dialog", "AceConfigDialog-3.0"
	return info
end
-- member m (a function, or a method name on the handler): "ok <values>" or "error"
local function call(root, path, option, handler, m, ...)
	local args = pack(...)
	local info = infoFor(root, path, option, handler)
	local res
	if type(m) == "string" then
		if not (handler and type(handler[m]) == "function") then return "method " .. text(m) end
		res = pack(pcall(handler[m], handler, info, unpack(args, 1, args.n)))
	elseif type(m) == "function" then
		res = pack(pcall(m, info, unpack(args, 1, args.n)))
	else
		return "value " .. text(m)
	end
	if not res[1] then return "error" end
	return "ok " .. texts(res, 2)
end
local function valuesOf(root, path, option, h)
	local vals = option.values
	local info = infoFor(root, path, option, h)
	if type(vals) == "function" then
		local ok, v = pcall(vals, info)
		return ok and v or nil
	elseif type(vals) == "string" and h and type(h[vals]) == "function" then
		local ok, v = pcall(h[vals], h, info)
		return ok and v or nil
	end
	return vals
end
-- a member as AceConfigDialog finds it: the option's own, else the nearest parent group's
local function member(option, inherited, m)
	if option[m] ~= nil then return option[m] end
	return INHERITED[m] and inherited[m] or nil
end

local out = {}
local function emit(s) out[#out + 1] = s end
local function flush()
	if #out > 0 then print(table.concat(out, "\n")) end
	out = {}
end

local function shownMember(root, path, option, h, field, v)
	if field == "handler" then
		return type(v)
	elseif NOT_CALLED[field] then
		return (type(v) == "function" and "present") or text(v)
	elseif type(v) == "function" then
		return call(root, path, option, h, v)
	elseif type(v) == "string" and INHERITED[field] and h and type(h[v]) == "function" then
		return call(root, path, option, h, v)
	end
	return text(v)
end

-- every option under group (args and plugins), sorted by key; each option's fields sorted by name
local function dumpGroup(state, root, group, path, handler, inherited)
	handler = group.handler or handler
	local children = {}
	for k, v in pairs(group.args or {}) do children[#children + 1] = { k, v, "" } end
	for pname, plugin in pairs(group.plugins or {}) do
		for k, v in pairs(plugin) do children[#children + 1] = { k, v, "plugin " .. tostring(pname) .. " " } end
	end
	table.sort(children, function(a, b)
		if a[3] ~= b[3] then return a[3] < b[3] end
		return keyLess(a[1], b[1])
	end)
	for _, c in ipairs(children) do
		local k, option = c[1], c[2]
		path[#path + 1] = k
		local where = state .. " " .. c[3] .. table.concat(path, ".")
		if type(option) ~= "table" then
			emit(where .. " = " .. text(option))
		else
			local h = option.handler or handler
			for _, field in ipairs(sortedKeys(option)) do
				if field ~= "args" and field ~= "plugins" then
					local v = option[field]
					local shown
					if field == "get" and option.type == "multiselect" and v then
						local parts = {}
						local list = valuesOf(root, path, option, h)
						for _, key in ipairs(sortedKeys(type(list) == "table" and list or {})) do
							parts[#parts + 1] = text(key) .. ":" .. call(root, path, option, h, v, key)
						end
						shown = "{" .. table.concat(parts, ",") .. "}"
					else
						shown = shownMember(root, path, option, h, field, v)
					end
					emit(where .. " " .. field .. " = " .. shown)
				end
			end
			-- members taken from a parent group, called for this option
			if not option.args then
				for _, m in ipairs(sortedKeys(INHERITED)) do
					if option[m] == nil and inherited[m] ~= nil then
						emit(where .. " " .. m .. " (from group) = " .. shownMember(root, path, option, h, m, inherited[m]))
					end
				end
			end
			if option.args or option.plugins then
				local below = {}
				for m in pairs(INHERITED) do below[m] = member(option, inherited, m) end
				dumpGroup(state, root, option, path, h, below)
			end
		end
		path[#path] = nil
	end
end

local function dumpTree(state)
	local reg = LibStub("AceConfigRegistry-3.0")
	for _, app in ipairs({ "CDTL3", "CDTL3Bliz" }) do
		local ok, root = pcall(function() return reg:GetOptionsTable(app, "dialog", "AceConfigDialog-3.0") end)
		emit(state .. " app " .. app .. " " .. (ok and "ok" or "error"))
		if ok and root then
			for _, field in ipairs(sortedKeys(root)) do
				if field ~= "args" and field ~= "plugins" then
					emit(state .. " " .. app .. " " .. field .. " = " .. shownMember(root, {}, root, root.handler, field, root[field]))
				end
			end
			local inherited = {}
			for m in pairs(INHERITED) do inherited[m] = root[m] end
			dumpGroup(state .. " " .. app, root, root, {}, root.handler, inherited)
		end
	end
	flush()
end

---------------------------------------------------------------- the states
print(string.format("[options dump %s %s %s]", HARNESS_TOCFILE, FLAVOR, class))

-- 1: right after login (Filters: the first entry of each tab, picked by OnEnable's 5 s step)
dumpTree("login")

-- 2: every text slot used and in edit, the highlight border, secondary tracking, splits, the
-- transition indicator; Filters entries selected (the spell with a Custom CD Time) and a valid
-- Custom being added
local p = CDTL3.db.profile
local function eachText(t)
	for _, k in ipairs(sortedKeys(t)) do
		local v = t[k]
		if type(v) == "table" then
			if v["edit"] ~= nil and v["used"] ~= nil then
				v["edit"], v["used"] = true, true
			else
				eachText(v)
			end
		end
	end
end
for _, group in ipairs({ "lanes", "barFrames", "ready" }) do eachText(p[group]) end
p.lanes.lane1.icons.highlight.style = "BORDER"
p.lanes.lane1.tracking.secondaryTracking = "HEALTH"
p.lanes.lane2.mode.type = "SPLIT"
p.lanes.lane2.mode.split.count = 3
p.lanes.lane3.mode.type = "SPLIT_ABS"
p.lanes.lane3.mode.splitAbs.count = 3
p.barFrames.frame1.transition.hideTransitioned = true
p.barFrames.frame1.transition.showTI = true
p.barFrames.frame1.transition.style = "LINE"
local SELECT = { spells = "Counterspell", items = "Healthstone", buffs = "Stealth", debuffs = "Forbearance",
	offensives = "Rupture", petspells = "Bite", runes = "Blood Rune", detected = "Vanish" }
for _, t in ipairs(sortedKeys(SELECT)) do
	CDTL3.currentFilter[t], CDTL3.currentFilterHidden[t] = SELECT[t], false
end
local function validCustom()
	return { id = 1856, name = "Vanish", icon = 132331, type = "customs", bCD = 60000, triggerType = "spell", enabled = false, lane = 2 }
end
CDTL3.currentFilter["customs"], CDTL3.currentFilterHidden["customs"] = "<< Add New >>", false
CDTL3.custom, CDTL3.customIsValid = validCustom(), true
dumpTree("edit")

-- 3: the other branches: a saved Custom selected, the spell without a Custom CD Time, another
-- highlight style on each lane; then a Custom being added without a valid ID
CDTL3.currentFilter["customs"] = "My Custom"
CDTL3.currentFilter["spells"] = "Vanish"
p.lanes.lane1.icons.highlight.style = "GLOW"
p.lanes.lane2.icons.highlight.style = "BORDER_FLASH"
dumpTree("saved")
CDTL3.currentFilter["customs"] = "<< Add New >>"
CDTL3.custom, CDTL3.customIsValid = {}, false
dumpTree("invalid")

---------------------------------------------------------------- 4: the set pass
-- each settable option (Profiles and the Import/Export boxes left out), sorted by path, gets a new
-- value; printed: the value, the CDTL3 methods the setter called itself, and what get gives after
local SKIP = { profiles = true, importbox = true, exportbox = true }
local calls, depth, logging = {}, 0, false
local function argText(...)
	local parts = {}
	for i = 1, select("#", ...) do
		local a = select(i, ...)
		parts[#parts + 1] = (a == CDTL3 and "self") or (type(a) == "table" and "tbl") or text(a)
	end
	return table.concat(parts, ", ")
end
local wrapped = {}
for _, k in ipairs(sortedKeys(CDTL3)) do
	local f = CDTL3[k]
	if type(f) == "function" and type(k) == "string" then
		local function finish(ok, ...)
			depth = depth - 1
			if not ok then error((...), 0) end
			return ...
		end
		wrapped[k] = f
		CDTL3[k] = function(...)
			if logging and depth == 0 then calls[#calls + 1] = k .. "(" .. argText(...) .. ")" end
			depth = depth + 1
			return finish(pcall(f, ...))
		end
	end
end

local function newValue(root, path, option, h, get)
	local t = option.type
	local cur = call(root, path, option, h, get)
	if t == "toggle" then
		return pack(not (cur == "ok true"))
	elseif t == "range" then
		local lo, hi = option.min or option.softMin or 0, option.max or option.softMax or 1
		return pack((cur == "ok " .. text(lo)) and hi or lo)
	elseif t == "select" then
		local vals = valuesOf(root, path, option, h)
		if type(vals) ~= "table" then return nil end
		for _, k in ipairs(sortedKeys(vals)) do
			if cur ~= "ok " .. text(k) then return pack(k) end
		end
	elseif t == "color" then
		return pack(0.25, 0.5, 0.75, 0.625)
	elseif t == "input" then
		return pack("7")
	end
	return nil
end

-- Filters controls act on the selection: each one starts from the same selection, the entries of
-- state 2 (a valid Custom being added), or with savedCustom the saved Custom and the plain spell
local function selectFor(path, savedCustom)
	if path[1] ~= "filters" then return end
	for _, t in ipairs(sortedKeys(SELECT)) do
		CDTL3.currentFilter[t], CDTL3.currentFilterHidden[t] = SELECT[t], false
	end
	CDTL3.currentFilterHidden["customs"] = false
	if savedCustom then
		CDTL3.currentFilter["customs"], CDTL3.currentFilter["spells"] = "My Custom", "Vanish"
	else
		CDTL3.currentFilter["customs"] = "<< Add New >>"
		CDTL3.custom, CDTL3.customIsValid = validCustom(), true
	end
end

local function setPass(label, savedCustom, root, group, path, handler, inherited)
	handler = group.handler or handler
	local children = {}
	for k, v in pairs(group.args or {}) do children[#children + 1] = { k, v } end
	for _, plugin in pairs(group.plugins or {}) do
		for k, v in pairs(plugin) do children[#children + 1] = { k, v } end
	end
	table.sort(children, function(a, b) return keyLess(a[1], b[1]) end)
	for _, c in ipairs(children) do
		local k, option = c[1], c[2]
		if type(option) == "table" and not SKIP[k] then
			path[#path + 1] = k
			local h = option.handler or handler
			if option.args or option.plugins then
				local below = {}
				for m in pairs(INHERITED) do below[m] = member(option, inherited, m) end
				setPass(label, savedCustom, root, option, path, h, below)
			else
				local get, set, validate = member(option, inherited, "get"), member(option, inherited, "set"), member(option, inherited, "validate")
				local t = option.type
				if get and set and t ~= "execute" and t ~= "description" and t ~= "header" and t ~= "multiselect" then
					local where = label .. " " .. table.concat(path, ".")
					selectFor(path, savedCustom)
					local val = newValue(root, path, option, h, get)
					if val and validate then
						local valid = call(root, path, option, h, validate, unpack(val, 1, val.n))
						if valid ~= "ok true" and valid ~= "ok nil" and valid ~= "ok " then
							emit(where .. " " .. texts(val) .. " refused: " .. valid)
							val = nil
						end
					end
					if val then
						calls = {}
						logging = true
						local r = call(root, path, option, h, set, unpack(val, 1, val.n))
						logging = false
						emit(where .. " " .. texts(val) .. " -> " .. r .. " calls [" .. table.concat(calls, "; ") .. "] get " .. call(root, path, option, h, get))
					elseif not validate then
						emit(where .. " no new value")
					end
				end
			end
			path[#path] = nil
		end
	end
end

do
	local reg = LibStub("AceConfigRegistry-3.0")
	local root = reg:GetOptionsTable("CDTL3", "dialog", "AceConfigDialog-3.0")
	local inherited = {}
	for m in pairs(INHERITED) do inherited[m] = root[m] end
	setPass("set", false, root, root, {}, root.handler, inherited)
	-- the Filters tabs again, on the saved Custom and the spell without a Custom CD Time
	setPass("set2", true, root, { args = { filters = root.args.filters } }, {}, root.handler, inherited)
	flush()
end
for k, f in pairs(wrapped) do CDTL3[k] = f end

-- 5: the tree after the set pass, and the saved settings in full
dumpTree("after")
local function dumpTable(label, t, seen)
	seen = seen or {}
	if seen[t] then emit("saved " .. label .. " = <cycle>") return end
	seen[t] = true
	for _, k in ipairs(sortedKeys(t)) do
		local v = t[k]
		if type(v) == "table" and v ~= CDTL3 then
			dumpTable(label .. "." .. tostring(k), v, seen)
		else
			emit("saved " .. label .. "." .. tostring(k) .. " = " .. text(v))
		end
	end
	seen[t] = nil
end
dumpTable("profile", CDTL3.db.profile)
dumpTable("global", CDTL3.db.global)
dumpTable("char", CDTL3.db.char)
dumpTable("currentFilter", CDTL3.currentFilter)
dumpTable("currentFilterHidden", CDTL3.currentFilterHidden)
dumpTable("custom", CDTL3.custom or {})
emit("saved customIsValid = " .. text(CDTL3.customIsValid))
-- the running cooldowns' data (plain values)
local running = {}
for _, cd in pairs(CDTL3.cooldowns) do running[#running + 1] = cd end
local function cdKey(cd) return tostring(cd.data and cd.data["type"]) .. " " .. tostring(cd.data and (cd.data["name"] or cd.data["itemName"])) end
table.sort(running, function(x, y) return cdKey(x) < cdKey(y) end)
for _, cd in ipairs(running) do
	for _, k in ipairs(sortedKeys(cd.data or {})) do
		if type(cd.data[k]) ~= "table" then
			emit("running " .. cdKey(cd) .. " " .. tostring(k) .. " = " .. text(cd.data[k]))
		end
	end
end
flush()

print(string.format("RESULT optionsdump %s %s: lua errors %d", HARNESS_TOCFILE, class, #ERRORS - errorsAtStart))
