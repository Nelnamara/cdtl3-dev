-- Cooldown.lua's shared parts (copied-code cleanup of 17 Nov 2026): the unlock box on icons and bars,
-- icon and bar texts 1 to 3, the split-lane stretches and the spell countdown. Each is checked against
-- what the hand-copied blocks did; CalcSplitPosition against those blocks, kept here as the reference.
-- With `dump` it also prints every frame call it drives and the frames it made (DUMP lines), so two
-- copies of the addon can be compared line by line. Real files, real AceDB.
--   node run.js <addon> <toc number> cdparts.lua <toc file> [dump]
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local DUMP = HARNESS_ARG == "dump"

-- the stub's text colour, shadow and wrap calls do nothing: record what they were given; with dump,
-- log every call that isn't a read
local mt = getmetatable(UIParent)
local oldIndex = mt.__index
local record = {
	SetTextColor = function(s, r, g, b, a) rawset(s, "__tc", { r, g, b, a }) end,
	SetShadowColor = function(s, r, g, b, a) rawset(s, "__sc", { r, g, b, a }) end,
	SetShadowOffset = function(s, x, y) rawset(s, "__so", { x, y }) end,
	SetNonSpaceWrap = function(s, v) rawset(s, "__nsw", v) end,
}
local ids, idsUpTo = {}, 0
local function id(o)
	if ids[o] then return ids[o] end
	local all = GetAllFrames()
	for i = idsUpTo + 1, #all do ids[all[i]] = i; idsUpTo = i end
	return ids[o] or "?"
end
local function fmt(v, depth)
	local t = type(v)
	if t == "number" then return string.format("%.17g", v) end
	if t == "string" then return string.format("%q", v) end
	if t == "function" then return "fn" end
	if t ~= "table" then return tostring(v) end
	if rawget(v, "__otype") then return "@" .. id(v) end
	if (depth or 0) > 2 then return "{...}" end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local out = {}
	for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. fmt(v[k], (depth or 0) + 1) end
	return "{" .. table.concat(out, ",") .. "}"
end
local LOG, logging = {}, false
mt.__index = function(t, k)
	local m = record[k] or oldIndex(t, k)
	if logging and type(m) == "function" and type(k) == "string" and not (k:match("^Get") or k:match("^Is")
		or k:match("^Has") or k:match("^Can")) then
		return function(self, ...)
			local args = {}
			for i = 1, select("#", ...) do args[i] = fmt((select(i, ...))) end
			local who = (type(self) == "table" and rawget(self, "__otype")) and id(self) or fmt(self)
			LOG[#LOG + 1] = who .. ":" .. k .. "(" .. table.concat(args, ", ") .. ")"
			return m(self, ...)
		end
	end
	return m
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
local function near(a, b, e) return type(a) == "number" and math.abs(a - b) <= (e or 1e-6) end
local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end
local function index(o) local all = GetAllFrames(); for i = #all, 1, -1 do if all[i] == o then return i end end end
local firstFrame = #GetAllFrames() + 1
local g = CDTL3.db.profile.global
logging = DUMP

local function newCooldown(id_, name, extra)
	local data = { id = id_, name = name, icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false }
	for k, v in pairs(extra or {}) do data[k] = v end
	SPELLINFO[id_] = { name, 1 }
	return CDTL3:CreateCooldown(CDTL3:GetUID(), "spells", data)
end

---------------------------------------------------------------- 1. the unlock box
print("[unlock box " .. FLAVOR .. "]")
local function box(f, name, shown)
	local db = f.db
	return db ~= nil and db:GetName() == name and db:GetParent() == f and db.__shown == shown
		and db.bg and db.bg.__otype == "Texture" and db.bg:GetParent() == db
		and db.text and db.text.__otype == "FontString" and db.text:GetParent() == db
		and index(db) < index(db.bg) and index(db.bg) < index(db.text)
end
for _, locked in ipairs({ false, true }) do
	if g["unlockFrames"] == locked then CDTL3:ToggleFrameLock(true) end
	local cd = newCooldown(locked and 962 or 961, locked and "Box Locked" or "Box Unlocked")
	local name = cd:GetName()
	local word = locked and "locked: hidden" or "unlocked: shown"
	check("icon " .. word .. ", " .. name .. "_Icon_DB on the icon, its bg then its text", box(cd.icon, name .. "_Icon_DB", not locked))
	check("  made after the icon's texture", index(cd.icon.tx) < index(cd.icon.db))
	check("bar " .. word .. ", " .. name .. "_Bar_DB on the bar, its bg then its text", box(cd.bar, name .. "_Bar_DB", not locked))
	check("  made after the bar's icon texture", index(cd.bar.icon.tx) < index(cd.bar.db))
	check("  icon and bar at frame level 20", cd.icon.__level == 20 and cd.bar.__level == 20)
end
if g["unlockFrames"] then CDTL3:ToggleFrameLock(true) end

---------------------------------------------------------------- 2. texts 1 to 3
print("[texts " .. FLAVOR .. "]")
local cd = newCooldown(963, "Text Test")
local LSM = CDTL3.LSM
local ALIGN, ANCHOR = { "LEFT", "CENTER", "RIGHT" }, { "TOPLEFT", "BOTTOM", "RIGHT" }
local OUTLINE, WANT_OUTLINE = { "NONE", "OUTLINE", "" }, { nil, "OUTLINE", nil }
local function setTexts(ss, mask, tag)
	for i = 1, 3 do
		local ts = ss["text" .. i]
		ts["enabled"] = math.floor(mask / 2 ^ (i - 1)) % 2 == 1
		ts["align"], ts["anchor"] = ALIGN[i], ANCHOR[i]
		ts["offX"], ts["offY"] = i * 3, -i * 2
		ts["size"], ts["outline"] = 10 + i, OUTLINE[i]
		ts["color"] = { r = 0.1 * i, g = 0.2, b = 0.3, a = 1 }
		ts["shadColor"] = { r = 0, g = 0, b = 0.1 * i, a = 0.5 }
		ts["shadX"], ts["shadY"] = i, -i
		ts["text"] = tag .. " text " .. i
	end
end
-- each enabled text as its settings say (nudge on text 2 only), each disabled one hidden
local function textsRight(fr, ss, nudge)
	local why = ""
	for i = 1, 3 do
		local ts, t = ss["text" .. i], fr.txt and fr.txt["text" .. i]
		if ts["enabled"] then
			local p = t and t.__points
			local y = ts["offY"] + ((i == 2 and nudge) or 0)
			if not (t and t.__shown and #p == 1 and same(p[1], { ts["align"], fr, ts["anchor"], ts["offX"], y })
				and t.__font and t.__font[1] == LSM:Fetch("font", ts["font"]) and t.__font[2] == ts["size"] and t.__font[3] == WANT_OUTLINE[i]
				and t.__text == ts["text"] and same(t.__tc, { ts.color.r, ts.color.g, ts.color.b, ts.color.a })
				and same(t.__sc, { ts.shadColor.r, ts.shadColor.g, ts.shadColor.b, ts.shadColor.a })
				and same(t.__so, { ts["shadX"], ts["shadY"] }) and t.__nsw == false) then
				why = why .. " text" .. i .. " wrong"
			end
		elseif t and t.__shown then
			why = why .. " text" .. i .. " shown"
		end
	end
	return why == "", why
end

local bs = CDTL3.db.profile.barFrames["frame1"]["bar"]
local ls = CDTL3.db.profile.lanes["lane1"]["icons"]
cd.data["barFrame"], cd.data["lane"] = 1, 1
cd.bar:SetParent(CDTL3_BarFrame_1_MF)
cd.icon:SetParent(CDTL3_Lane_1)
local made = {}
for mask = 0, 7 do
	setTexts(bs, mask, "bar")
	CDTL3:RefreshBar(cd)
	local ok, why = textsRight(cd.bar, bs, nil)
	check("bar, texts on " .. mask .. ": each text where, how and what its settings say", ok, why)
	for _, nudge in ipairs({ false, true }) do
		setTexts(ls, mask, "icon")
		cd.icon.fxNudge = nudge
		CDTL3:RefreshIcon(cd)
		ok, why = textsRight(cd.icon, ls, nudge and 4 or 0)
		check("  icon, charge pips " .. (nudge and "on (text 2 up 4 px)" or "off") .. ": the same", ok, why)
	end
	for _, fr in ipairs({ cd.bar, cd.icon }) do
		for i = 1, 3 do
			local t = fr.txt and fr.txt["text" .. i]
			if t then
				made[t] = true
				check("  " .. (fr == cd.bar and "bar" or "icon") .. " text " .. i .. ": one font string on the text frame",
					t:GetParent() == fr.txt and fr.txt:GetParent() == fr and fr.txt:GetName() == fr:GetName() .. "_TEXT")
			end
		end
	end
end
local count = 0
for _ in pairs(made) do count = count + 1 end
check("six font strings in all, each made once and reused", count == 6, tostring(count))
setTexts(bs, 0, "bar"); setTexts(ls, 0, "icon")
CDTL3:RefreshBar(cd); CDTL3:RefreshIcon(cd)
check("all texts off: all six hidden", not (cd.bar.txt.text1.__shown or cd.bar.txt.text2.__shown or cd.bar.txt.text3.__shown
	or cd.icon.txt.text1.__shown or cd.icon.txt.text2.__shown or cd.icon.txt.text3.__shown))
-- a size of 0 sets no font; another outline passes through
setTexts(ls, 7, "icon")
ls["text1"]["size"] = 0
ls["text3"]["outline"] = "THICKOUTLINE"
rawset(cd.icon.txt.text1, "__font", nil)
CDTL3:RefreshIcon(cd)
check("size 0: no font set", cd.icon.txt.text1.__font == nil)
check("THICKOUTLINE: set as it is", cd.icon.txt.text3.__font and cd.icon.txt.text3.__font[3] == "THICKOUTLINE")
-- on a fresh icon (CreateCooldown refreshes it on its lane), the texts are made in the order 1, 2, 3
setTexts(ls, 5, "icon")
local cd2 = newCooldown(964, "Text Order")
check("texts 1 and 3 on: the text frame, then text 1, then text 3; no text 2",
	index(cd2.icon.txt) < index(cd2.icon.txt.text1) and index(cd2.icon.txt.text1) < index(cd2.icon.txt.text3) and cd2.icon.txt.text2 == nil)
setTexts(ls, 0, "icon")
local cd3 = newCooldown(965, "Text None")
check("all off on a fresh icon: no text frame made", cd3.icon:GetParent() == CDTL3_Lane_1 and cd3.icon.txt == nil)

---------------------------------------------------------------- 3. split-lane stretches
print("[split stretches " .. FLAVOR .. "]")
-- the split position as the hand-copied blocks worked it out (Cooldown.lua at af4b7b5)
local splitKeys = { SPLIT = "split", SPLIT_ABS = "splitAbs" }
local function REF(current, total, s)
	local p = 1
	local max = 100
	local value = (current / total) * 100
	local ss = s["mode"][splitKeys[s["mode"]["type"]] or ""]
	local abs = s["mode"]["type"] == "SPLIT_ABS"
	if s["mode"]["type"] == "SPLIT" then
		if total > ss["max"] then total = ss["max"] end
	elseif abs then
		max = ss["max"]; value = current; total = ss["max"]
	end
	local splits = nil
	if abs then splits = CDTL3:SplitAbsCount(ss) else splits = CDTL3:SplitCount(ss) end
	if current < total then
		if abs and splits == 0 then
			p = current / total
		elseif splits == 1 then
			local s1v, s1p = ss["s1v"], ss["s1p"]
			if value > s1v then
				local rPercent = max - s1v; local rSize = 1 - s1p; local cPercent = value - s1v; local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			else
				local rPercent = s1v; local rSize = s1p; local cPercent = value - s1v; local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			end
		elseif splits == 2 then
			local s1v, s1p, s2v, s2p = ss["s1v"], ss["s1p"], ss["s2v"], ss["s2p"]
			if value > s2v then
				local rPercent = max - s2v; local rSize = 1 - s2p; local cPercent = value - s2v; local aPercent = cPercent / rPercent
				p = s2p + (rSize * aPercent)
			elseif value > s1v then
				local rPercent = s2v - s1v; local rSize = s2p - s1p; local cPercent = value - s1v; local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			else
				local rPercent = s1v; local rSize = s1p; local cPercent = value - s1v; local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			end
		elseif splits == 3 then
			local s1v, s1p, s2v, s2p, s3v, s3p = ss["s1v"], ss["s1p"], ss["s2v"], ss["s2p"], ss["s3v"], ss["s3p"]
			if value > s3v then
				local rPercent = max - s3v; local rSize = 1 - s3p; local cPercent = value - s3v; local aPercent = cPercent / rPercent
				p = s3p + (rSize * aPercent)
			elseif value > s2v then
				local rPercent = s3v - s2v; local rSize = s3p - s2p; local cPercent = value - s2v; local aPercent = cPercent / rPercent
				p = s2p + (rSize * aPercent)
			elseif value > s1v then
				local rPercent = s2v - s1v; local rSize = s2p - s1p; local cPercent = value - s1v; local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			else
				local rPercent = s1v; local rSize = s1p; local cPercent = value - s1v; local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			end
		end
	end
	return p
end
local marks = {
	{ "in order", 10, 0.33, 33, 0.66, 66, 0.75 },
	{ "out of order", 50, 0.6, 20, 0.3, 70, 0.9 },
	{ "all at one value", 40, 0.2, 40, 0.5, 40, 0.8 },
	{ "first at 0, last at the end", 0, 0.1, 100, 0.5, 120, 0.9 },
	{ "fractions", 12.5, 0.125, 37.25, 0.4, 81.75, 0.95 },
}
local compared, differ, firstDiff = 0, 0, nil
for _, mode in ipairs({ "SPLIT", "SPLIT_ABS" }) do
	for _, m in ipairs(marks) do
		for _, n in ipairs({ "x", 0, 1, 2, 3 }) do
			for _, smax in ipairs({ 60, 120 }) do
				local ss = { max = smax, count = n, s1v = m[2], s1p = m[3], s2v = m[4], s2p = m[5], s3v = m[6], s3p = m[7] }
				local s = { mode = { type = mode, split = ss, splitAbs = ss } }
				for _, total in ipairs({ 1, 20, 45, 120, 200 }) do
					local points = {}
					for k = -2, 40 do points[#points + 1] = total * k / 37 end
					for j = 2, 6, 2 do
						points[#points + 1] = m[j]
						points[#points + 1] = m[j] * total / 100
					end
					for _, cur in ipairs(points) do
						local want, got = REF(cur, total, s), CDTL3.CalcSplitPosition(cur, total, s)
						compared = compared + 1
						if not (want == got or (want ~= want and got ~= got)) then
							differ = differ + 1
							firstDiff = firstDiff or string.format("%s %s count %s max %s total %s at %s: %s vs %s", mode, m[1], tostring(n),
								smax, total, cur, tostring(got), tostring(want))
						end
						if DUMP then LOG[#LOG + 1] = "split " .. mode .. " " .. m[1] .. " " .. tostring(n) .. " " .. smax .. " " .. fmt(total) .. " " .. fmt(cur) .. " = " .. fmt(got) end
					end
				end
			end
		end
	end
end
check(string.format("CalcSplitPosition is the copied blocks' result exactly, at %d points (marks in and out of order, at the ends, counts none to 3; 4 and 5 are checked in lanes.lua)",
	compared), differ == 0, firstDiff)

---------------------------------------------------------------- 4. the spell countdown
print("[spell countdown " .. FLAVOR .. "]")
local polled, scans = {}, {}
local realPoll = CDTL3.IconFx.PollCharges
CDTL3.IconFx.PollCharges = function(self, f) polled[f] = (polled[f] or 0) + 1; return realPoll(self, f) end
local realScan = CDTL3.ScanSharedSpellCooldown
CDTL3.ScanSharedSpellCooldown = function(self, name, cdLeft) scans[name] = (scans[name] or 0) + 1; return realScan(self, name, cdLeft) end
g["detectSharedCD"] = true
local function frames(f, n)
	for _ = 1, n do
		NOW = NOW + 0.02
		f.__scripts.OnUpdate(f, 0.02)
		if DUMP then
			local d = f.data
			LOG[#LOG + 1] = string.format("cd %s count=%s left=%s base=%s held=%s gameHeld=%s", d["name"], fmt(f.updateCount),
				fmt(d["currentCD"]), fmt(d["baseCD"]), tostring(d["oafHeld"]), tostring(d["oafGameHeld"]))
		end
	end
end
local function cdTable(start, duration, enabled)
	return { startTime = start, duration = duration, isEnabled = enabled, isActive = true, modRate = 1, isOnGCD = false }
end

local cases = {
	{ key = "plain", id = 971, name = "Plain Bolt", extra = {}, pips = true },
	{ key = "starts when used", id = 972, name = "Fade Step", extra = { oaf = true }, pips = false },
	{ key = "Custom CD Time", id = 973, name = "Custom Nova", extra = { setCustomCD = true, customCDTime = 20000 }, pips = true },
}
for _, c in ipairs(cases) do
	SPELLCD[c.id] = cdTable(NOW - 5, 30, true)
	local f = newCooldown(c.id, c.name, c.extra)
	f.data["lane"] = 1
	CDTL3:SendToLane(f)
	local d = f.data
	check(c.key .. ": on lane 1 and showing", f.icon:GetParent() == CDTL3_Lane_1 and f.icon:IsVisible())
	local length = c.extra.customCDTime and 20 or 30
	local start = NOW - 5
	frames(f, 1)
	check(c.key .. ": the first frame reads the game" .. (c.extra.customCDTime and " (Custom CD Time's length)" or ""),
		near(d["currentCD"], start + length - NOW) and d["baseCD"] == length, string.format("%s, base %s", tostring(d["currentCD"]), tostring(d["baseCD"])))
	check("  charge pips polled " .. (c.pips and "once" or "never") .. ", shared cooldowns scanned " .. (c.pips and "once" or "never"),
		(polled[f] or 0) == (c.pips and 1 or 0) and (scans[c.name] or 0) == (c.pips and 1 or 0),
		tostring(polled[f]) .. " " .. tostring(scans[c.name]))
	-- the game moves: frames 2 to 50 only count down, the 51st (count 50) reads it again
	local before = d["currentCD"]
	SPELLCD[c.id] = cdTable(NOW - 10, 30, true)
	frames(f, 49)
	check("  the next 49 frames count down without a read", near(d["currentCD"], before - 49 * 0.02, 1e-9), tostring(d["currentCD"]))
	frames(f, 1)
	check("  the 51st reads the game again", near(d["currentCD"], (NOW - 0.02 * 50 - 10) + length - NOW), tostring(d["currentCD"]))
	check("  pips polled " .. (c.pips and "twice" or "never") .. ", shared cooldowns still scanned only on the first",
		(polled[f] or 0) == (c.pips and 2 or 0) and (scans[c.name] or 0) == (c.pips and 1 or 0),
		tostring(polled[f]) .. " " .. tostring(scans[c.name]))
	-- overridden: counts down, never reads
	d["overrideCD"] = true
	before = d["currentCD"]
	SPELLCD[c.id] = cdTable(NOW, 30, true)
	frames(f, 50)
	check("  overridden: 50 frames count down, the poll frame reads nothing", near(d["currentCD"], before - 50 * 0.02, 1e-9) and (polled[f] or 0) == (c.pips and 2 or 0),
		tostring(d["currentCD"]))
	d["overrideCD"] = false
	if c.extra.oaf then
		-- the game holds it (cooldown not started): no countdown at all
		SPELLCD[c.id] = cdTable(0, 0, false)
		frames(f, 50)
		before = d["currentCD"]
		frames(f, 30)
		check("  held by the game: the countdown stands still", d["oafHeld"] == true and d["currentCD"] == before, tostring(d["currentCD"]))
	end
	if c.extra.customCDTime then
		-- a spell the game gives no cooldown counts its Custom CD Time from the last cast
		SPELLCD[c.id] = cdTable(0, 0, true)
		CDTL3.spellCastTimes = CDTL3.spellCastTimes or {}
		CDTL3.spellCastTimes[c.id] = NOW - 3
		local castAt = NOW - 3
		frames(f, 50)
		check("  no game cooldown: counts from the last cast", near(d["currentCD"], castAt + 20 - NOW), tostring(d["currentCD"]))
	end
	-- a spell that has run out is left alone
	d["currentCD"] = -1
	SPELLCD[c.id] = cdTable(NOW, 30, true)
	frames(f, 1)
	check("  run out (below 0): no countdown, no read", d["currentCD"] == -1, tostring(d["currentCD"]))
	CDTL3:SendToHolding(f)
end

---------------------------------------------------------------- dump
if DUMP then
	logging = false
	for _, line in ipairs(LOG) do print("DUMP " .. line) end
	local all = GetAllFrames()
	for i = firstFrame, #all do
		local o = all[i]
		local pts = {}
		for _, p in ipairs(o.__points) do pts[#pts + 1] = fmt(p) end
		print(string.format("DUMP frame %d %s %s parent=%s shown=%s size=%s,%s level=%s alpha=%s points=%s font=%s text=%s tex=%s tc=%s sc=%s so=%s nsw=%s",
			i, o.__otype, tostring(o.__name), fmt(o.__parent), tostring(o.__shown), fmt(o.__w), fmt(o.__h), fmt(o.__level), fmt(o.__alpha),
			table.concat(pts, ";"), fmt(o.__font), fmt(o.__text), fmt(o.__tex), fmt(o.__tc), fmt(o.__sc), fmt(o.__so), tostring(o.__nsw)))
	end
end

print(string.format("RESULT cdparts %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
