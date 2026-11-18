-- Lanes, bar frames and ready frames as built (Lanes.lua, BarFrames.lua, Ready.lua). Every object the
-- stub client records under them is printed as a DUMP line: creation order, type, name, parent, shown,
-- alpha, level, size, points, texture, font and text, the Lua fields of the frames, and the last
-- arguments and the call count of every other setter (strata, colours, fades, mouse...). Dumped after
-- creation, after refreshes over their settings (border on and off, unlocked, debug, switched off,
-- sizes, alpha), after stacking bars and icons in every grow direction and padding, and after the lane
-- texts in every mode, way up and direction. Two copies of the addon build the same frames when their
-- DUMP lines are the same (diff them). Then the riding estimate the Fight Timeline and the Ready board
-- share. Real files, real AceDB.
--   node run.js <addon> <toc number> framedump.lua <toc file>
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"

local mt = getmetatable(UIParent)
local oldIndex = mt.__index
-- a GetChildren that works (the stub's returns nothing): the frames parented to self
local skipTypes = { Texture = true, FontString = true, AnimationGroup = true, Animation = true }
local function kids(self)
	local out = {}
	for _, f in ipairs(GetAllFrames()) do
		if rawget(f, "__parent") == self and f ~= self and not skipTypes[rawget(f, "__otype")] then
			out[#out + 1] = f
		end
	end
	return table.unpack(out)
end
-- every setter the stub doesn't model keeps its last arguments and a call count. The stub answers
-- those with an empty function (one shared function where closures are reused, as in fengari; a new
-- one each time in Lua 5.1), and the ones it models with their own function.
local plain = { Get = true, Is = true, Has = true, Can = true }
local EMPTY = oldIndex(UIParent, "NoSuchSetterAnywhere")
mt.__index = function(t, k)
	if k == "GetChildren" then return kids end
	local v = oldIndex(t, k)
	if type(v) == "function" and type(k) == "string" and not plain[k:sub(1, 3)] and not plain[k:sub(1, 2)]
		and not k:match("^Create") and (v == EMPTY or v ~= oldIndex(t, k)) then
		return function(self, ...)
			local calls = rawget(self, "__calls")
			if not calls then
				calls = {}
				rawset(self, "__calls", calls)
			end
			local c = calls[k]
			calls[k] = { n = (c and c.n or 0) + 1, args = table.pack(...) }
			return v(self, ...)
		end
	end
	return v
end

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end
local P = CDTL3.db.profile
local g = P.global

---------------------------------------------------------------- the dump
local function index()
	local at = {}
	for i, o in ipairs(GetAllFrames()) do at[o] = i end
	return at
end
local function val(v, at)
	local t = type(v)
	if t == "table" then
		if at[v] then
			return rawget(v, "__name") or ("#" .. at[v])
		end
		return "{table}"
	elseif t == "number" then
		return string.format("%.10g", v)
	elseif t == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end
local function list(t, n, at)
	local out = {}
	for i = 1, n or #t do out[i] = val(t[i], at) end
	return table.concat(out, ",")
end
local function sorted(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	return keys
end
-- one line per object: what the stub records, then the frame's own Lua fields
local function line(o, at)
	local parts = { "#" .. at[o], rawget(o, "__otype"), tostring(rawget(o, "__name")), "parent=" .. val(rawget(o, "__parent"), at),
		"shown=" .. tostring(rawget(o, "__shown")), "alpha=" .. val(rawget(o, "__alpha"), at), "level=" .. val(rawget(o, "__level"), at),
		"size=" .. val(rawget(o, "__w"), at) .. "x" .. val(rawget(o, "__h"), at) }
	local pts = {}
	for i, p in ipairs(rawget(o, "__points")) do pts[i] = "(" .. list(p, nil, at) .. ")" end
	parts[#parts + 1] = "points=" .. table.concat(pts)
	for _, k in ipairs({ "__tex", "__atlas", "__text", "__min", "__max", "__val", "__reverse", "__enabled" }) do
		local v = rawget(o, k)
		-- a file ID is a spell's icon on a cooldown frame: which saved spell gets which frame follows
		-- table order, which changes from run to run (these files only set texture paths)
		if k == "__tex" and type(v) == "number" then v = "file id" end
		if v ~= nil then parts[#parts + 1] = k:sub(3) .. "=" .. val(v, at) end
	end
	for _, k in ipairs({ "__font", "__sbc" }) do
		local v = rawget(o, k)
		if v then parts[#parts + 1] = k:sub(3) .. "=(" .. list(v, 4, at) .. ")" end
	end
	local scripts = sorted(rawget(o, "__scripts"))
	if #scripts > 0 then parts[#parts + 1] = "scripts=" .. table.concat(scripts, ",") end
	local calls = rawget(o, "__calls")
	if calls then
		for _, k in ipairs(sorted(calls)) do
			parts[#parts + 1] = k .. "x" .. calls[k].n .. "(" .. list(calls[k].args, calls[k].args.n, at) .. ")"
		end
	end
	local fields = {}
	for _, k in ipairs(sorted(o)) do
		if type(k) == "string" and k:sub(1, 2) ~= "__" then
			local v = rawget(o, k)
			local t = type(v)
			if t == "table" and not at[v] then
				-- a plain table: its size (validChildren, slots...)
				fields[#fields + 1] = k .. "=[" .. #v .. "]"
			elseif t ~= "function" then
				fields[#fields + 1] = k .. "=" .. val(v, at)
			end
		end
	end
	if #fields > 0 then parts[#parts + 1] = "fields{" .. table.concat(fields, " ") .. "}" end
	return table.concat(parts, " ")
end
-- the objects under a frame (its own, and everything parented to them), in creation order
local function under(root, at)
	local out = {}
	for _, o in ipairs(GetAllFrames()) do
		local p = o
		while p do
			if p == root then
				out[#out + 1] = o
				break
			end
			p = rawget(p, "__parent")
		end
	end
	return out
end
local function dump(label, roots)
	local at = index()
	for _, root in ipairs(roots) do
		for _, o in ipairs(under(root, at)) do
			print("DUMP " .. label .. " " .. line(o, at))
		end
	end
end
local GROUPS = { lanes = "lane", barFrames = "frame", ready = "ready" }
local function frames(group)
	local out = {}
	for n = 1, 3 do out[#out + 1] = CDTL3:SlotFrame(group, n) end
	return out
end
local function all()
	local out = {}
	for _, group in ipairs({ "lanes", "barFrames", "ready" }) do
		for _, f in ipairs(frames(group)) do out[#out + 1] = f end
	end
	return out
end
local function refresh(group, n)
	if group == "lanes" then
		CDTL3:RefreshLane(n)
	elseif group == "barFrames" then
		CDTL3:RefreshBarFrame(n)
	else
		CDTL3:RefreshReady(n)
	end
end
-- saved values the frames write back (positions while unlocked, the lane mode texts)
local function dumpSettings(label)
	for group, key in pairs(GROUPS) do
		for n = 1, 3 do
			local s = P[group][key .. n]
			print(string.format("DUMP %s settings %s %d pos=%s,%s,%s", label, group, n, val(s["relativeTo"], {}), val(s["posX"], {}), val(s["posY"], {})))
		end
	end
	for n = 1, 3 do
		local st = P.lanes["lane" .. n]["modeText"]
		for k = 1, 5 do
			local t = st["text" .. k]
			print(string.format("DUMP %s settings lane %d text%d used=%s pos=%s text=%s align=%s offX=%s", label, n, k,
				tostring(t["used"]), val(t["pos"], {}), val(t["text"], {}), val(t["align"], {}), val(t["offX"], {})))
		end
	end
end

---------------------------------------------------------------- created
print("[created " .. FLAVOR .. "]")
for group, key in pairs(GROUPS) do
	for n = 1, 3 do
		P[group][key .. n]["enabled"] = true
	end
end
CDTL3:CreateLanes()
CDTL3:CreateBarFrames()
CDTL3:CreateReadyFrames()
for group in pairs(GROUPS) do
	check(group .. ": all three made", #frames(group) == 3)
end
dump("created", all())
dumpSettings("created")

---------------------------------------------------------------- refreshes over the settings
print("[refreshes " .. FLAVOR .. "]")
local steps = {
	{ "border none", function(s) s["border"]["style"] = "None" end },
	{ "border back", function(s) s["border"]["style"] = "CDTL3 Shadow" end },
	{ "sizes", function(s)
		s["width"], s["height"], s["padding"] = 222, 33, 4
		if s["icons"] then s["icons"]["size"] = 37 end
	end },
	{ "colours", function(s) s["bgTextureColor"] = { r = 0.2, g = 0.3, b = 0.4, a = 0.6 } end },
	{ "alpha", function(s) s["alpha"] = 0.7 end },
	{ "unlocked", function() g["unlockFrames"] = true end },
	{ "debug", function() g["debugMode"] = true end },
	{ "locked", function() g["unlockFrames"] = false end },
	{ "no debug", function() g["debugMode"] = false end },
	{ "switched off", function(s) s["enabled"] = false end },
	{ "switched on", function(s) s["enabled"] = true end },
}
for _, step in ipairs(steps) do
	for group, key in pairs(GROUPS) do
		for n = 1, 3 do
			step[2](P[group][key .. n])
			refresh(group, n)
		end
	end
	dump(step[1], all())
end
-- a frame first given a border after it was made (its border frame is made then)
for group, key in pairs(GROUPS) do
	P[group][key .. "2"]["border"]["style"] = "None"
end
for _, group in ipairs({ "lanes", "barFrames", "ready" }) do
	local f = CDTL3:SlotFrame(group, 2)
	if group == "lanes" then f.bd = nil else f.mf.bd = nil end
	refresh(group, 2)
end
for group, key in pairs(GROUPS) do
	P[group][key .. "2"]["border"]["style"] = "CDTL3 Shadow"
	refresh(group, 2)
end
dump("late border", all())
check("no Lua errors in the refreshes", #ERRORS == base, tostring(#ERRORS - base))

---------------------------------------------------------------- stacking bars and icons
print("[stacking " .. FLAVOR .. "]")
local GROWS = { "UP", "DOWN", "LEFT", "RIGHT", "CENTER_V", "CENTER_H" }
local PADS = { 0, 3, -4 }
for _, group in ipairs({ "barFrames", "ready" }) do
	local f = CDTL3:SlotFrame(group, 1)
	local s = CDTL3:SlotSettings(group, 1)
	-- five bars or icons, an invalid one and a faded one (both left out)
	local children = {}
	for k = 1, 5 do
		local c = CreateFrame("Frame", nil, f.mf)
		c.valid = true
		children[k] = c
	end
	local invalid = CreateFrame("Frame", nil, f.mf)
	invalid.valid = false
	local faded = CreateFrame("Frame", nil, f.mf)
	faded.valid = true
	faded:SetAlpha(0)
	local cell = group == "barFrames" and s["bar"] or s["icons"]
	-- what the frame already holds (bars of the saved spells), stacked first
	for k = 1, 5 do children[k].valid = false end
	f.mf.triggerUpdate = true
	xpcall(f.__scripts.OnUpdate, ERRH, f, 0.01)
	local held = #f.validChildren
	local placed = 0
	for _, grow in ipairs(GROWS) do
		for count = 0, 5 do
			for k = 1, 5 do children[k].valid = k <= count end
			for _, px in ipairs(PADS) do
				for _, py in ipairs(PADS) do
					for _, fp in ipairs({ 0, 2 }) do
						s["grow"], cell["xPadding"], cell["yPadding"], s["padding"] = grow, px, py, fp
						f.mf.triggerUpdate = true
						xpcall(f.__scripts.OnUpdate, ERRH, f, 0.01)
						local at = index()
						local parts = { "mf=" .. val(f.mf.__w, at) .. "x" .. val(f.mf.__h, at) }
						for _, p in ipairs(f.mf.__points) do parts[#parts + 1] = "(" .. list(p, nil, at) .. ")" end
						for _, c in ipairs(f.validChildren) do
							local pts = {}
							for _, p in ipairs(c.__points) do pts[#pts + 1] = "(" .. list(p, nil, at) .. ")" end
							parts[#parts + 1] = val(c, at) .. "=" .. table.concat(pts)
						end
						print(string.format("DUMP stack %s %s n=%d px=%d py=%d fp=%d childCount=%s valid=%d %s", group, grow, count, px, py, fp,
							tostring(f.childCount), #f.validChildren, table.concat(parts, " ")))
						if #f.validChildren == held + count then placed = placed + 1 end
					end
				end
			end
		end
	end
	check(group .. ": the showing children counted in every layout (the invalid and the faded one left out)", placed == #GROWS * 6 * 18,
		tostring(placed) .. " (" .. held .. " held before)")
	for k = 1, 5 do children[k].valid = false end
	f.mf.triggerUpdate = true
	xpcall(f.__scripts.OnUpdate, ERRH, f, 0.01)
end
dump("stacked", all())
check("no Lua errors in the stacking", #ERRORS == base, tostring(#ERRORS - base))

---------------------------------------------------------------- lane texts
print("[lane texts " .. FLAVOR .. "]")
local s1 = P.lanes["lane1"]
-- every slot told apart: its own offsets, place, alignment, anchor, size and colour
for k = 1, 5 do
	local t = s1["modeText"]["text" .. k]
	t["offX"], t["offY"], t["align"], t["size"] = k * 2 - 1, -k, ({ "LEFT", "CENTER", "RIGHT", "LEFT", "CENTER" })[k], 10 + k
	t["color"] = { r = k / 10, g = 0.5, b = 1 - k / 10, a = 1 }
	local c = s1["customText"]["text" .. k]
	c["enabled"], c["used"], c["text"] = k % 2 == 1, k ~= 4, "C" .. k
	c["anchor"], c["align"], c["pos"] = ({ "TOPLEFT", "LEFT", "BOTTOM", "RIGHT", "CENTER" })[k], ({ "CENTER", "LEFT", "RIGHT", "CENTER", "LEFT" })[k], k / 7
	c["offX"], c["offY"], c["size"] = -k, k * 3, 8 + k
	c["outline"] = ({ "", "OUTLINE", "NONE", "THICKOUTLINE", 5 })[k]
	c["shadColor"] = { r = 0, g = k / 10, b = 0, a = 1 }
end
s1["modeText"]["text3"]["enabled"] = false
local modes = {
	{ "LINEAR" },
	{ "SPLIT", 0 }, { "SPLIT", 1 }, { "SPLIT", 2 }, { "SPLIT", 3 }, { "SPLIT", 4 }, { "SPLIT", 1.5 }, { "SPLIT", "x" },
	{ "SPLIT_ABS", 0 }, { "SPLIT", 0 }, { "SPLIT_ABS", 1 }, { "SPLIT_ABS", 2 }, { "SPLIT_ABS", 3 },
	{ "SPLIT_ABS", 3, 45 }, { "SPLIT_ABS", 3, 20 }, { "SPLIT_ABS", 3, 5 }, { "SPLIT_ABS", "x" }, { "SPLIT", 4 },
	{ "LINEAR_ABS" }, { "SPLIT", 3 },
}
local n = 0
for _, way in ipairs({ { false, false }, { false, true }, { true, false }, { true, true } }) do
	s1["vertical"], s1["reversed"] = way[1], way[2]
	for _, m in ipairs(modes) do
		s1["mode"]["type"] = m[1]
		if m[1] == "SPLIT" then
			s1["mode"]["split"]["count"] = m[2]
		elseif m[1] == "SPLIT_ABS" then
			s1["mode"]["splitAbs"]["count"] = m[2]
			s1["mode"]["splitAbs"]["max"] = m[3] or 120
		end
		CDTL3:RefreshLane(1)
		n = n + 1
		local label = string.format("text %s%s %s %s", way[1] and "vertical" or "horizontal", way[2] and " reversed" or "", m[1], tostring(m[2]) .. "/" .. tostring(m[3]))
		local at = index()
		local f = CDTL3_Lane_1
		for _, key in ipairs({ "t1", "t2", "t3", "t4", "t5", "c1", "c2", "c3", "c4", "c5" }) do
			print("DUMP " .. label .. " " .. key .. " " .. line(f[key], at))
		end
		for k = 1, 5 do
			local t = s1["modeText"]["text" .. k]
			print(string.format("DUMP %s text%d used=%s pos=%s text=%s", label, k, tostring(t["used"]), val(t["pos"], at), val(t["text"], at)))
		end
	end
end
check("every mode, way up and direction drawn", n == 4 * #modes)
dump("texts", { CDTL3_Lane_1 })
dumpSettings("end")
check("no Lua errors in the lane texts", #ERRORS == base, tostring(#ERRORS - base))

---------------------------------------------------------------- the riding estimate
-- A cooldown riding the game's own timer (combat timers) is never read: its time left is its cast
-- plus its base cooldown, at least 0; its base cooldown with no cast or no base; nil if it isn't riding.
print("[riding estimate " .. FLAVOR .. "]")
CDTL3.spellCastTimes = CDTL3.spellCastTimes or {}
-- label, riding (nil: no combat timer), base cooldown, seconds since the cast (nil: none), seconds left
local cases = {
	{ "riding, cast 30 s ago, base 180", true, 180, 30, 150 },
	{ "riding, cast 200 s ago, base 180: not below 0", true, 180, 200, 0 },
	{ "riding, no cast: its base", true, 180, nil, 180 },
	{ "riding, base 0: 0", true, 0, 5, 0 },
	{ "riding, no base: 0", true, nil, 5, 0 },
	{ "not riding: nil", false, 180, 30, nil },
	{ "no combat timer: nil", nil, 180, 30, nil },
}
for _, c in ipairs(cases) do
	CDTL3.spellCastTimes[9911] = c[4] and (NOW - c[4])
	local cd = { ct = c[2] ~= nil and { riding = c[2] } or nil, data = { id = 9911, baseCD = c[3], currentCD = 0.1 } }
	local left = CDTL3:RidingTimeLeft(cd)
	check(c[1], left == c[5], tostring(left))
end
CDTL3.spellCastTimes[9911] = nil

print(string.format("RESULT framedump %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
