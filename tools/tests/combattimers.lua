-- Combat timers (CombatTimers.lua, branch combat-timers): fakes the Forever/Retail timer, curve,
-- text binding and Cooldown Manager APIs on top of wow.lua, then drives real cooldown frames through
-- combat. Arg "full" runs the faked path; without it, checks the module stays inert where the APIs
-- are missing. Hidden values are per-value secrets (compare / arithmetic / concat throw) that the
-- harness can still read with Val() to check what the widgets were given.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME = PLAYER.guid
local FULL = HARNESS_ARG == "full"

local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end

---------------------------------------------------------------- fakes (full only)
local SMT = getmetatable(SECRET)
local function S(v) return setmetatable({ __v = v }, SMT) end
local function IsS(v) return type(v) == "table" and getmetatable(v) == SMT end
local function Val(v) if IsS(v) then return rawget(v, "__v") end return v end
COMBAT = false
LOCKDOWN = false
local function hide(v) if COMBAT then return S(v) end return v end

local function Eval(c, x)
	local p = c.points
	if #p == 0 then return 0 end
	if x <= p[1][1] then return p[1][2] end
	for i = 2, #p do
		if x <= p[i][1] then
			local a, b = p[i - 1], p[i]
			return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
		end
	end
	return p[#p][2]
end
local NO_PCT = false
local function Duration(start, total)
	local function rem() return math.max(0, start + total - NOW) end
	local o = {
		GetRemainingDuration = function() return hide(rem()) end,
		GetTotalDuration = function() return hide(total) end,
		EvaluateRemainingDuration = function(_, c) return hide(Eval(c, rem())) end,
	}
	if not NO_PCT then
		o.EvaluateRemainingPercent = function(_, c) return hide(Eval(c, total > 0 and rem() / total or 0)) end
	end
	return o
end
DUR = {}       -- id -> { start, total }: the game's real cooldown
CHARGE = {}    -- id -> { start, total, active }
BINDINGS = {}
local TEST, CHARGED, CUSTOM, BUFF = 6001, 6002, 6003, 6004

if FULL then
	issecretvalue = IsS
	InCombatLockdown = function() return LOCKDOWN end
	C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
		local c = DUR[id]
		if c then return Duration(c[1], c[2]) end
		return Duration(0, 0)
	end
	C_Spell.GetSpellChargeDuration = function(id) local c = CHARGE[id]; return Duration(c[1], c[2]) end
	C_Spell.GetSpellCharges = function(id)
		local c = CHARGE[id]
		if c then return { currentCharges = hide(1), maxCharges = 2, isActive = c[3], cooldownStartTime = hide(c[1]), cooldownDuration = hide(c[2]) } end
	end
	C_Secrets.ShouldCooldownsBeSecret = function() return COMBAT end
	C_Secrets.ShouldSpellCooldownBeSecret = function() return COMBAT end
	C_CurveUtil = { CreateCurve = function()
		local c = { points = {} }
		c.SetType = function(self, t) self.type = t end
		c.AddPoint = function(self, x, y)
			if IsS(x) or IsS(y) then error("secret curve point") end
			self.points[#self.points + 1] = { x, y }
		end
		return c
	end }
	Enum.LuaCurveType = { Linear = 0, Step = 1 }
	C_DurationUtil = { CreateDurationTextBinding = function()
		local b = { enabled = false }
		b.SetFontString = function(self, fs) self.fs = fs end
		b.SetFormatter = function(self, f) self.formatter = f end
		b.SetDuration = function(self, d) self.dur = d end
		b.SetEnabled = function(self, on) self.enabled = on end
		BINDINGS[#BINDINGS + 1] = b
		return b
	end }
	-- formatters: the seconds formatter records its settings; the rule formatter follows its
	-- documented breakpoints (highest threshold at or below the value, step, div/mod components)
	-- with printf-style specs, or "{}" specs when RULE_STYLE is "brace"; "broken" errors on use
	Enum.SecondsFormatterAbbreviation = { None = 0, Truncate = 1, OneLetter = 2 }
	Enum.SecondsFormatterInterval = { Seconds = 0, Minutes = 1, Hours = 2, Days = 3 }
	Enum.SecondsFormatterIntervalWhitespace = { Preserve = 0, Strip = 1, StripIgnoreLocale = 2 }
	Enum.NumericRuleFormatRounding = { Nearest = 0, Up = 1, Down = 2 }
	RULE_STYLE, NO_RULE, NO_SECONDS = "printf", false, false
	local function stepped(x, step, rounding)
		if not step then return x end
		local q = x / step
		if rounding == 1 then q = math.ceil(q - 1e-9) elseif rounding == 2 then q = math.floor(q + 1e-9) else q = math.floor(q + 0.5) end
		return q * step
	end
	local function spec(fmt)
		if RULE_STYLE == "brace" then
			if fmt:find("%", 1, true) then error("bad format") end
			return (fmt:gsub("{:02}", "%%02d"):gsub("{:%.(%d)f}", "%%.%1f"):gsub("{}", "%%d"))
		end
		if fmt:find("{", 1, true) then error("bad format") end
		return fmt
	end
	local function int(v) return math.floor(v + 0.5) end
	C_StringUtil = {
		CreateSecondsFormatter = function()
			if NO_SECONDS then error("no seconds formatter") end
			local o = { kind = "seconds" }
			o.SetMinInterval = function(self, v) self.minInterval = v end
			o.SetDefaultAbbreviation = function(self, v) if v == nil then error("bad enum") end self.abbreviation = v end
			o.SetDesiredUnitCount = function(self, v) self.units = v end
			o.SetStripIntervalWhitespace = function(self, v) if type(v) ~= "number" then error("bad enum") end self.strip = v end
			o.FormatNumber = function(self, v) return string.format("%ds", int(v)) end
			return o
		end,
		CreateNumericRuleFormatter = function()
			if NO_RULE then error("no rule formatter") end
			local o = { kind = "rule", rules = {} }
			o.SetBreakpoints = function(self, list) if RULE_STYLE == "broken" then error("broken") end self.rules = list end
			o.FormatNumber = function(self, n)
				if IsS(n) then error("secret argument") end
				local r = nil
				for _, b in ipairs(self.rules) do if n >= b.threshold and (not r or b.threshold > r.threshold) then r = b end end
				if not r then return "" end
				local x = stepped(n, r.step, r.rounding)
				local fmt = spec(r.format)
				if not r.components then
					if fmt:find("%%d") then x = int(x) end
					return string.format(fmt, x)
				end
				local vals = {}
				for i, c in ipairs(r.components) do
					local v = x
					if c.div then v = v / c.div end
					if c.mod then v = v % c.mod end
					v = stepped(v, c.step, c.rounding)
					vals[i] = int(v)
				end
				return string.format(fmt, table.unpack(vals))
			end
			return o
		end,
	}
	-- the Cooldown Manager with one Tracked Bars item mapped to the buff, one unmapped
	local INFO = {
		[201] = { cooldownID = 201, spellID = BUFF, linkedSpellIDs = { 6005 }, hasAura = true, selfAura = true, charges = false },
	}
	C_CooldownViewer = {
		IsCooldownViewerAvailable = function() return true, "" end,
		GetCooldownViewerCategorySet = function(cat) if cat == 3 then return { 201 } end return {} end,
		GetCooldownViewerCooldownInfo = function(id) return INFO[id] end,
	}
	Enum.CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 }
	C_CVar.GetCVar = function(name) if name == "cooldownViewerEnabled" then return "1" end return "0" end
	local function Item(id)
		local item = CreateFrame("Frame")
		item.Bar = CreateFrame("StatusBar", nil, item)
		item.cooldownID = id
		item.GetCooldownID = function(self) return self.cooldownID end
		return item
	end
	ITEM, ITEM2 = Item(201), Item(999)
	BuffBarCooldownViewer = CreateFrame("Frame", "BuffBarCooldownViewer")
	BuffBarCooldownViewer.OnAcquireItemFrame = function() end
	BuffBarCooldownViewer.GetItemFrames = function() return { ITEM } end
	BuffBarCooldownViewer.UpdateSystemSettingOpacity = function(self) self:SetAlpha(0.8) end
end

CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {} } }
LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local CT = CDTL3.CombatTimers
local P = CT and CT.internal
local g = CDTL3.db.profile.global
local tables = CDTL3.db.profile.tables
for _, t in ipairs({ "spells", "buffs" }) do g[t]["ignoreThreshold"] = 1800 end
local lane = CDTL3.db.profile.lanes["lane1"]

local function entry(id, name, type, extra)
	local e = { id = id, name = name, type = type, icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local function declare(id, name, bcd)
	SPELLINFO[id] = { name, 136000 }
	KNOWN[id] = true
	BASECD[id] = bcd or 0
end
local function cast(id) FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id, id) end
local function poll(f, seconds)
	for _ = 1, math.max(1, math.floor(seconds / 0.02 + 0.5)) do NOW = NOW + 0.02; f.__scripts.OnUpdate(f, 0.02) end
end
local function parentName(r) local p = r:GetParent(); return p and p:GetName() end

check("module table exists", CT ~= nil)
if not FULL then
	check("inert: not available", CT and CT:Available() == false)
	check("inert: not enabled", CT and CT:Enabled() == false)
	check("inert: status line", CT and CT:StatusLine() == "Combat timers: not available on this client", CT and CT:StatusLine())
	check("inert: BuffInTrackedBars nil", CT and CT:BuffInTrackedBars("Anything") == nil)
	check("inert: no event frame", P and P.eventFrame == nil)
	declare(TEST, "Inert Bolt", 30000)
	table.insert(tables.spells, entry(TEST, "Inert Bolt", "spells"))
	SPELLCD[TEST] = { startTime = NOW, duration = 30, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
	cast(TEST)
	local f = CDTL3:GetExistingCooldown("Inert Bolt", "spells")
	check("inert: cast starts an icon on the lane", f and parentName(f.icon) == "CDTL3_Lane_1")
	if f then
		poll(f, 1)
		local p = { f.icon:GetPoint(1) }
		check("inert: icon placed the normal way", f.ct == nil and p[1] == "LEFT" and type(p[2]) == "number", tostring(p[1]) .. " " .. tostring(p[2]))
	end
	CT:SetEnabled(false); CT:SetEnabled(true); CT:SetHideBlizzardBars(true)
	print(string.format("RESULT combattimers inert %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
	return
end

check("available", CT:Available() == true)
check("enabled by default", CT:Enabled() == true)

---------------------------------------------------------------- 1. split-lane curves
print("[curves " .. FLAVOR .. "]")
local function laneCopy(modeType, count, splitMax)
	local s = { width = 400, icons = { size = 40 }, mode = { type = modeType,
		split = { max = splitMax or 120, count = count, s1v = 10, s1p = 0.33, s2v = 33, s2p = 0.66, s3v = 66, s3p = 0.75 },
		splitAbs = { max = 120, count = count, s1v = 10, s1p = 0.25, s2v = 30, s2p = 0.5, s3v = 60, s3p = 0.75 } } }
	return s
end
local function worst(curve, span, s, total)
	local w = 0
	for i = 0, 400 do
		local x = span * i / 400
		local d = math.abs(Eval(curve, x) - CDTL3.CalcSplitPosition(x, total, s))
		if d > w then w = d end
	end
	return w
end
for count = 1, 3 do
	local s = laneCopy("SPLIT_ABS", count)
	local e = worst(P.SplitCurve(s, "abs"), 150, s, 120)
	check("SPLIT_ABS count " .. count .. ": curve reproduces CalcSplitPosition", e < 1e-6, string.format("max diff %.2g", e))
	s = laneCopy("SPLIT", count)
	e = worst(P.SplitCurve(s, "pct"), 1, s, 1)
	check("SPLIT (percent) count " .. count .. ": curve reproduces CalcSplitPosition", e < 1e-6, string.format("max diff %.2g", e))
	s = laneCopy("SPLIT", count, 20)
	e = worst(P.SplitCurve(s, "sec", 20), 30, s, 20)
	check("SPLIT (seconds, base over max) count " .. count .. ": curve reproduces", e < 1e-6, string.format("max diff %.2g", e))
	s = laneCopy("SPLIT", count)
	e = worst(P.SplitCurve(s, "sec", 45), 45, s, 45)
	check("SPLIT (seconds fallback) count " .. count .. ": curve reproduces", e < 1e-6, string.format("max diff %.2g", e))
end
local sc = laneCopy("SPLIT_ABS", 2)
check("curves are cached by settings", P.SplitCurve(sc, "abs") == P.SplitCurve(laneCopy("SPLIT_ABS", 2), "abs"))
check("curve type set to linear", P.SplitCurve(sc, "abs").type == Enum.LuaCurveType.Linear)

---------------------------------------------------------------- 1b. split segments (Tracked Bars buffs on Split (Time))
print("[segments " .. FLAVOR .. "]")
-- where the chain puts the icon: each segment's clamped fill times its share of the lane
local function chainPosition(segs, n, v, geo)
	local pos = 0
	for k = 1, n do
		local seg = segs[k]
		local a, b = seg:GetMinMaxValues()
		local size = geo.vertical and seg.__h or seg.__w
		local frac = math.min(math.max((v - a) / (b - a), 0), 1)
		pos = pos + frac * size
	end
	return pos / geo.len
end
for count = 1, 3 do
	local s = laneCopy("SPLIT_ABS", count)
	local geo = P.Geometry(s)
	local cts = {}
	local last = P.Segments(cts, CDTL3_Lane_1, s, geo)
	local w, worstAt = 0, nil
	for i = 0, 600 do
		local v = 150 * i / 600
		for _, seg in ipairs(cts.segs) do seg:SetValue(v) end
		local d = math.abs(chainPosition(cts.segs, cts.segCount, v, geo) - CDTL3.CalcSplitPosition(v, 120, s))
		if d > w then w, worstAt = d, v end
	end
	check("SPLIT_ABS count " .. count .. ": " .. (count + 1) .. " segments reproduce CalcSplitPosition (0-150 s, max 120)",
		cts.segCount == count + 1 and last == cts.segs[count + 1] and w < 1e-9, string.format("max diff %.2g at %s", w, tostring(worstAt)))
	local chained = true
	local total = 0
	for k, seg in ipairs(cts.segs) do
		local pt = { seg:GetPoint(1) }
		if k == 1 then
			chained = chained and pt[1] == "LEFT" and pt[2] == CDTL3_Lane_1 and pt[3] == "LEFT"
		else
			chained = chained and pt[1] == "LEFT" and pt[2] == cts.segs[k - 1]:GetStatusBarTexture() and pt[3] == "RIGHT"
		end
		chained = chained and seg.__h == 1 and seg:IsShown() and seg:GetParent() == CDTL3_Lane_1
		total = total + seg.__w
	end
	check("count " .. count .. ": segment 1 on the lane, each next one on the previous fill edge, lengths add up to the lane",
		chained and math.abs(total - geo.len) < 1e-9)
end
-- at and around the knots exactly
do
	local s = laneCopy("SPLIT_ABS", 3)
	local geo = P.Geometry(s)
	local cts = {}
	P.Segments(cts, CDTL3_Lane_1, s, geo)
	local ok = true
	for _, v in ipairs({ 0, 0.001, 9.999, 10, 10.001, 30, 60, 119.999, 120, 121, 3600 }) do
		for _, seg in ipairs(cts.segs) do seg:SetValue(v) end
		ok = ok and math.abs(chainPosition(cts.segs, cts.segCount, v, geo) - CDTL3.CalcSplitPosition(v, 120, s)) < 1e-9
	end
	check("segments match at the knots, below the first, at the max and past it", ok)
	-- vertical, reversed: same chain on the other axis
	s.vertical, s.reversed = true, true
	geo = P.Geometry(s)
	P.Segments(cts, CDTL3_Lane_1, s, geo)
	local p1, p2 = { cts.segs[1]:GetPoint(1) }, { cts.segs[2]:GetPoint(1) }
	local okv = p1[1] == "TOP" and p1[3] == "TOP" and p2[1] == "TOP" and p2[2] == cts.segs[1]:GetStatusBarTexture() and p2[3] == "BOTTOM"
		and cts.segs[1].__w == 1 and cts.segs[1].__reverse == true
	for _, v in ipairs({ 5, 25, 45, 90 }) do
		for _, seg in ipairs(cts.segs) do seg:SetValue(v) end
		okv = okv and math.abs(chainPosition(cts.segs, cts.segCount, v, geo) - CDTL3.CalcSplitPosition(v, 120, s)) < 1e-9
	end
	check("vertical reversed lane: chained TOP to BOTTOM fill edge, reverse fill, same positions", okv)
end
do
	local s = laneCopy("SPLIT_ABS", 3)
	s.mode.splitAbs.s2v = 5
	check("values not increasing: no segments (straight line)", P.SplitKnots(s) == nil and P.Segments({}, CDTL3_Lane_1, s, P.Geometry(s)) == nil)
	s = laneCopy("SPLIT_ABS", 2)
	s.mode.splitAbs.s2p = 0.25
	check("positions not increasing: no segments", P.SplitKnots(s) == nil)
	s = laneCopy("SPLIT_ABS", 3)
	s.mode.splitAbs.s3v = 120
	check("a split point at the max: no segments", P.SplitKnots(s) == nil)
	s = laneCopy("SPLIT_ABS", 0)
	check("no split points: no segments", P.SplitKnots(s) == nil)
	s = laneCopy("SPLIT_ABS", 1)
	s.mode.splitAbs.s2v, s.mode.splitAbs.s2p = 5, 0.1   -- inactive points are ignored
	check("inactive split points ignored", P.SplitKnots(s) ~= nil and #P.SplitKnots(s) == 3)
end

---------------------------------------------------------------- 1c. countdown text format
print("[text format " .. FLAVOR .. "]")
local function freshFormatter() P.formatter, P.textForm = nil, nil; return P.Formatter() end
-- CDTL3:GetReadableTime as the game's Lua 5.1 prints it (fengari is 5.3, where 7.0 .. ".0" is "7.0.0")
local function readable(v)
	if v > 60 then local r = math.floor(v + 0.5); return string.format("%d:%02d", math.floor(r / 60), r % 60) end
	if v > 10 then return string.format("%.0f", v) end
	return string.format("%.1f", v)
end
check("test's GetReadableTime copy agrees where 5.3 prints the same", readable(3.24) == tostring(CDTL3:GetReadableTime(3.24))
	and readable(42.4) == tostring(CDTL3:GetReadableTime(42.4)))
do
	local fmt = freshFormatter()
	check("rule formatter chosen: CDTL3's style", fmt and fmt.kind == "rule" and P.textForm == "cdtl3", tostring(P.textForm))
	local bad = nil
	for i = 0, 1500 do
		local v = 0.05 + i * 0.4013
		local tenths = (v * 10) % 1
		local frac = v % 1
		-- skip exact rounding ties (printf rounds half to even), and 10 itself ("10.0" in CDTL3)
		if math.abs(tenths - 0.5) > 0.01 and math.abs(frac - 0.5) > 0.01 and math.abs(v - 10) > 0.01 then
			if fmt:FormatNumber(v) ~= readable(v) then bad = bad or string.format("%.3f: %s vs %s", v, fmt:FormatNumber(v), readable(v)) end
		end
	end
	check("rule formatter text matches GetReadableTime from 0 to 600 s", bad == nil, bad)
	RULE_STYLE = "brace"
	fmt = freshFormatter()
	check("formatter reading {} specs: found by the self-check", fmt and fmt.kind == "rule" and P.textForm == "cdtl3" and fmt:FormatNumber(93.4) == "1:33")
	RULE_STYLE = "broken"
	fmt = freshFormatter()
	check("rule formatter failing: seconds formatter with the documented enums", fmt and fmt.kind == "seconds" and P.textForm == "units"
		and fmt.abbreviation == Enum.SecondsFormatterAbbreviation.OneLetter and fmt.strip == Enum.SecondsFormatterIntervalWhitespace.Strip
		and fmt.minInterval == Enum.SecondsFormatterInterval.Seconds and fmt.units == 2)
	RULE_STYLE = "printf"
	NO_RULE, NO_SECONDS = true, true
	fmt = freshFormatter()
	check("no formatter at all: the binding's own default", fmt == nil and P.textForm == "default")
	local b = C_DurationUtil.CreateDurationTextBinding()
	local okNone = pcall(P.SetFormatter, b)
	check("binding without a formatter: no error, none set", okNone and b.formatter == nil)
	NO_RULE, NO_SECONDS = false, false
	freshFormatter()
	local refusing = C_DurationUtil.CreateDurationTextBinding()
	refusing.SetFormatter = function(self, f) if f.kind == "rule" then error("not a formatter") end self.formatter = f end
	local okR = pcall(P.SetFormatter, refusing)
	check("binding refusing the rule formatter: seconds formatter instead, for later bindings too", okR and refusing.formatter
		and refusing.formatter.kind == "seconds" and P.textForm == "units" and P.Formatter().kind == "seconds")
	freshFormatter()
	check("formatter reset to CDTL3's style for the rest", P.textForm == "cdtl3")
end

---------------------------------------------------------------- 2. a spell rides in combat
print("[spells " .. FLAVOR .. "]")
declare(TEST, "Test Bolt", 30000)
table.insert(tables.spells, entry(TEST, "Test Bolt", "spells"))
SPELLCD[TEST] = { startTime = NOW, duration = 30, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
DUR[TEST] = { NOW, 24 }   -- the talented cooldown the estimate doesn't know
cast(TEST)
local f = CDTL3:GetExistingCooldown("Test Bolt", "spells")
check("cast starts an icon on lane 1", f and parentName(f.icon) == "CDTL3_Lane_1")
poll(f, 0.5)
check("out of combat: not riding", not CT:Riding(f))
local p0 = { f.icon:GetPoint(1) }
check("out of combat: icon placed the normal way", p0[1] == "LEFT" and type(p0[2]) == "number")

-- pull
COMBAT = true
SPELLCD[TEST] = { startTime = S(DUR[TEST][1]), duration = S(30), isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
FireEvent("PLAYER_REGEN_DISABLED")
FireEvent("SPELL_UPDATE_COOLDOWN")
poll(f, 1)
local ct = f.ct
check("in combat: riding", CT:Riding(f) and ct.kind == "spell")
check("in combat: no module errors", P.errors == 0, tostring(P.lastError))
local pt = { f.icon:GetPoint(1) }
check("icon anchored to its rider's fill edge", ct.rider and pt[1] == "LEFT" and pt[2] == ct.rider:GetStatusBarTexture() and pt[3] == "RIGHT",
	tostring(pt[1]) .. " -> " .. tostring(pt[3]))
check("rider parented to the lane, 1 px thick, lane width minus icon", ct.rider:GetParent() == CDTL3_Lane_1 and ct.rider.__w == lane.width - lane.icons.size and ct.rider.__h == 1)
local rem = DUR[TEST][1] + 24 - NOW
local mn, mx = ct.rider:GetMinMaxValues()
check("LINEAR: rider fed (0, total) and the remaining time (hidden)", IsS(mx) and Val(mx) == 24 and IsS(ct.rider:GetValue()) and math.abs(Val(ct.rider:GetValue()) - rem) < 0.03,
	string.format("max=%s value=%s", tostring(Val(mx)), tostring(Val(ct.rider:GetValue()))))
check("estimate keeps counting (plain number)", type(f.data.currentCD) == "number" and f.data.currentCD > 20)

local function modeCheck(label, modeType, expect, setup)
	lane.mode.type = modeType
	if setup then setup() end
	poll(f, 0.02)
	local v = Val(ct.rider:GetValue())
	local r = DUR[TEST][1] + 24 - NOW
	local want = expect(r)
	check(label, P.errors == 0 and math.abs(v - want) < 0.01, string.format("value=%.4f want=%.4f", v, want))
end
modeCheck("LINEAR_ABS: remaining seconds over linearAbs.max", "LINEAR_ABS", function(r) return r end)
check("LINEAR_ABS: max is the lane max", select(2, ct.rider:GetMinMaxValues()) == lane.mode.linearAbs.max)
modeCheck("SPLIT_ABS: curve of the remaining seconds", "SPLIT_ABS", function(r) return CDTL3.CalcSplitPosition(r, lane.mode.splitAbs.max, lane) end)
modeCheck("SPLIT: percent curve of the real length", "SPLIT", function(r) return CDTL3.CalcSplitPosition(r / 24, 1, lane) end)
modeCheck("SPLIT, base over split max: seconds curve", "SPLIT", function(r) return CDTL3.CalcSplitPosition(r, 20, lane) end,
	function() lane.mode.split.max = 20 end)
lane.mode.split.max = 120
NO_PCT = true
FireEvent("SPELL_UPDATE_COOLDOWN")   -- re-fetch: the new object has no EvaluateRemainingPercent
modeCheck("SPLIT, no EvaluateRemainingPercent: seconds over min(base, max)", "SPLIT", function(r) return CDTL3.CalcSplitPosition(r, 30, lane) end)
NO_PCT = false
lane.mode.type = "LINEAR"
for _, o in ipairs({ { false, true, "RIGHT", "LEFT" }, { true, false, "BOTTOM", "TOP" }, { true, true, "TOP", "BOTTOM" }, { false, false, "LEFT", "RIGHT" } }) do
	lane.vertical, lane.reversed = o[1], o[2]
	poll(f, 0.02)
	local q = { f.icon:GetPoint(1) }
	local rp = { ct.rider:GetPoint(1) }
	check(string.format("vertical=%s reversed=%s: rider at %s, icon %s -> fill %s", tostring(o[1]), tostring(o[2]), o[3], o[3], o[4]),
		rp[1] == o[3] and q[1] == o[3] and q[2] == ct.rider:GetStatusBarTexture() and q[3] == o[4])
end

-- countdown text: text2 is "[cd.time]" by default, text1 "[cd.stacks]"
local bound = nil
for _, b in ipairs(BINDINGS) do if b.fs == f.icon.txt.text2 then bound = b end end
check("[cd.time] text gets a duration binding, enabled, with the timer", bound and bound.enabled and bound.dur == ct.dur)
check("the binding formats in CDTL3's style (rule formatter)", bound and bound.formatter and bound.formatter.kind == "rule"
	and bound.formatter:FormatNumber(93.4) == "1:33" and bound.formatter:FormatNumber(4.26) == "4.3")
local other = false
for _, b in ipairs(BINDINGS) do if b.fs == f.icon.txt.text1 then other = true end end
check("[cd.stacks] text gets no binding", not other)

-- bar frame
local ba = f.bar
local barShown = ba:IsVisible() and parentName(ba) == "CDTL3_BarFrame_1_MF"
if barShown then
	local _, bmax = ba.bar:GetMinMaxValues()
	check("bar takes the timer: (0, total) and remaining", IsS(bmax) and Val(bmax) == 24 and IsS(ba.bar:GetValue()))
else
	check("bar frame visible for the bar check", false, "parent=" .. tostring(parentName(ba)) .. " visible=" .. tostring(ba:IsVisible()))
end

-- "Transition bars": a bar it hid comes back when the option is unticked (it used to need a /reload)
do
	local bfs = CDTL3.db.profile.barFrames["frame1"]
	local wasOn, wasThreshold = bfs.transition.hideTransitioned, ba.transitionThreshold
	bfs.transition.hideTransitioned = true
	ba.transitionThreshold = 100000
	poll(f, 0.04)
	check("Transition bars on, cooldown under the lane's Max Time: bar hidden", ba.valid == false and ba:GetAlpha() == 0)
	bfs.transition.hideTransitioned = false
	poll(f, 0.04)
	check("Transition bars unticked: the hidden bar comes back", ba.valid == true and ba:GetAlpha() == 1)
	f.data.ignored = true
	poll(f, 0.04)
	check("an ignored cooldown's bar stays hidden", ba.valid == false and ba:GetAlpha() == 0)
	f.data.ignored = false
	poll(f, 0.04)
	check("un-ignored: bar back", ba.valid == true and ba:GetAlpha() == 1)
	bfs.transition.hideTransitioned, ba.transitionThreshold = wasOn, wasThreshold
	poll(f, 0.04)
end

-- GROUPED stacking with a riding icon (and a second, plain icon)
declare(6010, "Plain Bolt", 60000)
table.insert(tables.spells, entry(6010, "Plain Bolt", "spells", { setCustomCD = true, customCDTime = 60000 }))
cast(6010)
local f2 = CDTL3:GetExistingCooldown("Plain Bolt", "spells")
poll(f2, 0.1)
check("Custom CD Time spell doesn't ride", f2 and not CT:Riding(f2))
lane.stacking.enabled, lane.stacking.style = true, "GROUPED"
f.icon.valid, f2.icon.valid = true, true
rawset(CDTL3_Lane_1, "GetChildren", function() return f.icon, f2.icon, ct.rider end)
f.icon.sOffset = 7
CDTL3_Lane_1.triggerUpdate = true
local e0 = #ERRORS
for _ = 1, 10 do CDTL3_Lane_1.__scripts.OnUpdate(CDTL3_Lane_1, 0.02) end
check("GROUPED with a riding icon: no errors, rider left out", #ERRORS == e0 and f.icon.stack == 1 and f.icon.sOffset == 0, "sOffset=" .. tostring(f.icon.sOffset))
rawset(f2.icon, "GetCenter", function() return S(10), S(20) end)
for _ = 1, 10 do CDTL3_Lane_1.__scripts.OnUpdate(CDTL3_Lane_1, 0.02) end
check("GROUPED with a hidden position: pass skipped, no errors", #ERRORS == e0)
rawset(f2.icon, "GetCenter", nil)
lane.stacking.enabled = false
rawset(CDTL3_Lane_1, "GetChildren", nil)

-- held while the game says it runs, Ready when it says it's done
f.data.currentCD = 0.05
poll(f, 0.02)
check("estimate ran out but isActive: held at 0.1, still on the lane", f.data.currentCD > 0 and parentName(f.icon) == "CDTL3_Lane_1" and CT:Riding(f),
	string.format("currentCD=%.3f", f.data.currentCD))
poll(f, 1)
check("held for a second more", parentName(f.icon) == "CDTL3_Lane_1" and CT:Riding(f))
SPELLCD[TEST] = { startTime = S(0), duration = S(0), isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
FireEvent("SPELL_UPDATE_COOLDOWN")
poll(f, 0.02)
check("isActive false: Ready at once", parentName(f.icon) == "CDTL3_Ready_1_MF" and not CT:Riding(f), tostring(parentName(f.icon)))
check("after Ready: rider hidden, binding off, bar min/max restored", not ct.rider:IsShown() and not bound.enabled
	and select(2, ba.bar:GetMinMaxValues()) == 1)

-- isActive turns false early (the estimate is too long): Ready on the game's time
SPELLCD[TEST] = { startTime = S(NOW), duration = S(30), isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
DUR[TEST] = { NOW, 24 }
cast(TEST)
FireEvent("SPELL_UPDATE_COOLDOWN")
poll(f, 0.5)
check("recast in combat: rides again", CT:Riding(f) and parentName(f.icon) == "CDTL3_Lane_1")
poll(f, 23.5)
check("23.5 s in: still riding", CT:Riding(f))
SPELLCD[TEST] = { startTime = S(0), duration = S(0), isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
FireEvent("SPELL_UPDATE_COOLDOWN")
poll(f, 0.04)
check("game says done at 24 s while the estimate has ~6 s: Ready", parentName(f.icon) == "CDTL3_Ready_1_MF", string.format("estimate was %.1f", f.data.currentCD))

-- a ride that ends on a GCD read must not leave that read behind for the next cast
SPELLCD[TEST] = { startTime = S(NOW), duration = S(1.5), isEnabled = true, isActive = true, isOnGCD = true, modRate = 1 }
DUR[TEST] = { NOW, 24 }
cast(TEST)
poll(f, 0.1)
FireEvent("SPELL_UPDATE_COOLDOWN")
poll(f, 0.7)
check("only the GCD running: Ready after the grace", parentName(f.icon) == "CDTL3_Ready_1_MF", tostring(parentName(f.icon)))
SPELLCD[TEST] = { startTime = S(NOW), duration = S(30), isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
DUR[TEST] = { NOW, 24 }
cast(TEST)	-- no cooldown event before the ride starts
poll(f, 1)
check("next cast with no cooldown event: the old GCD read is dropped, still riding", CT:Riding(f) and parentName(f.icon) == "CDTL3_Lane_1",
	tostring(parentName(f.icon)))
SPELLCD[TEST] = { startTime = S(0), duration = S(0), isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
FireEvent("SPELL_UPDATE_COOLDOWN")
poll(f, 0.04)

-- leaving combat re-anchors the icon to the lane
SPELLCD[TEST] = { startTime = S(NOW), duration = S(30), isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
DUR[TEST] = { NOW, 24 }
cast(TEST)
FireEvent("SPELL_UPDATE_COOLDOWN")
poll(f, 0.5)
check("rides before leaving combat", CT:Riding(f))
COMBAT = false
SPELLCD[TEST] = { startTime = DUR[TEST][1], duration = 30, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
FireEvent("PLAYER_REGEN_ENABLED")
poll(f, 0.04)
local pl = { f.icon:GetPoint(1) }
check("combat over: not riding, icon anchored to the lane again", not CT:Riding(f) and pl[1] == "LEFT" and type(pl[2]) == "number"
	and not ct.rider:IsShown(), tostring(pl[2]))
check("combat over: bar back on (0, 1) with a plain value", select(2, ba.bar:GetMinMaxValues()) == 1 and type(ba.bar:GetValue()) == "number")

-- charges ride the recharge timer, Ready from the charge info
declare(CHARGED, "Test Dash", 20000)
table.insert(tables.spells, entry(CHARGED, "Test Dash", "spells", { bCD = 20000 }))
SPELLCD[CHARGED] = { startTime = NOW, duration = 20, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
cast(CHARGED)
local fc = CDTL3:GetExistingCooldown("Test Dash", "spells")
COMBAT = true
CHARGE[CHARGED] = { NOW, 12, true }
SPELLCD[CHARGED] = { startTime = S(NOW), duration = S(20), isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }   -- all charges spent
FireEvent("SPELL_UPDATE_CHARGES")
poll(fc, 0.6)
check("charge spell rides the recharge timer", CT:Riding(fc) and fc.ct.charges and Val(select(2, fc.ct.rider:GetMinMaxValues())) == 12)
CHARGE[CHARGED][3] = false
FireEvent("SPELL_UPDATE_CHARGES")
poll(fc, 0.3)
check("recharge done (charge isActive false): Ready", parentName(fc.icon) == "CDTL3_Ready_1_MF")

---------------------------------------------------------------- 3. Tracked Bars mirror
print("[mirror " .. FLAVOR .. "]")
check("hide is off by default (3.1.0): Blizzard's Tracked Bars shown at login",
	g.combatTimers.hideBlizzardBars == false and BuffBarCooldownViewer:GetAlpha() == 1, tostring(BuffBarCooldownViewer:GetAlpha()))
CT:SetHideBlizzardBars(true)
check("hide ticked: Blizzard's Tracked Bars at alpha 0", BuffBarCooldownViewer:GetAlpha() == 0)
BuffBarCooldownViewer:UpdateSystemSettingOpacity()   -- Edit Mode resets it
check("re-hidden after Edit Mode resets the opacity", BuffBarCooldownViewer:GetAlpha() == 0)
CT:SetHideBlizzardBars(false)
check("hide off: Blizzard's own opacity back", BuffBarCooldownViewer:GetAlpha() == 0.8)
CT:SetHideBlizzardBars(true)
check("hide on again: alpha 0", BuffBarCooldownViewer:GetAlpha() == 0)
LOCKDOWN = true
CT:SetHideBlizzardBars(false)
check("in combat: the change waits", BuffBarCooldownViewer:GetAlpha() == 0)
LOCKDOWN = false
RunOnUpdate(0.05, 4)
check("after combat: applied", BuffBarCooldownViewer:GetAlpha() == 0.8)
CT:SetHideBlizzardBars(true)

SPELLINFO[BUFF] = { "Test Shield", 136003 }
SPELLINFO[6005] = { "Test Shield Linked", 136003 }
check("BuffInTrackedBars: tracked buff true", CT:BuffInTrackedBars("Test Shield") == true)
check("BuffInTrackedBars: linked spell name true", CT:BuffInTrackedBars("Test Shield Linked") == true)
check("BuffInTrackedBars: other buff false", CT:BuffInTrackedBars("Not Tracked") == false)

local bs = entry(BUFF, "Test Shield", "buffs", { bCD = 60000 })
table.insert(tables.buffs, bs)
local fb = CDTL3:CreateCooldown(CDTL3:GetUID(), "buffs", bs)
CDTL3:SendToHolding(fb); CDTL3:SendToBarHolding(fb)
SECRET_AURAS = true
COMBAT = true
FireEvent("PLAYER_REGEN_DISABLED")
local function feed(item, seconds, total, left)
	for _ = 1, math.floor(seconds / 0.02 + 0.5) do
		item.Bar:SetMinMaxValues(0, S(total))
		item.Bar:SetValue(S(left))
		ITEM2.Bar:SetMinMaxValues(0, S(5)); ITEM2.Bar:SetValue(S(4))
		RunOnUpdate(0.02, 1)
	end
end
-- the unmapped item gets hooked when acquired
BuffBarCooldownViewer:OnAcquireItemFrame(ITEM2)
check("bars hooked (acquired item too)", P.mirror.hooked[ITEM.Bar] ~= nil and P.mirror.hooked[ITEM2.Bar] ~= nil)
check("mirror on", P.mirrorOn == true)
-- the buff's text stays CDTL3's own (from the estimate): the fed value must never reach a text
local txt = fb.icon.txt and fb.icon.txt.text2
local function record(fs) if fs then rawset(fs, "SetFormattedText", function(self, fmt, v) self.__fmt, self.__fv = fmt, v end) end end
record(txt)
if fb.bar.txt then record(fb.bar.txt.text1); record(fb.bar.txt.text2); record(fb.bar.txt.text3) end
feed(ITEM, 0.4, 60, 55)
check("fresh feed starts the buff on its lane", parentName(fb.icon) == "CDTL3_Lane_1" and CT:Riding(fb) and fb.ct.kind == "buff", tostring(parentName(fb.icon)))
local _, bmx = fb.ct.rider:GetMinMaxValues()
check("LINEAR: rider takes Blizzard's max and value", Val(bmx) == 60 and Val(fb.ct.rider:GetValue()) == 55)
check("buff [cd.time] text: CDTL3's own, the fed value is never formatted into it", txt and txt.__fmt == nil and txt.__fv == nil)
lane.mode.type = "SPLIT_ABS"
feed(ITEM, 0.04, 60, 54)
do
	local c = fb.ct
	local n = c.segCount
	local pt = { fb.icon:GetPoint(1) }
	local fedAll = n == 4
	for k = 1, n do fedAll = fedAll and IsS(c.segs[k]:GetValue()) and Val(c.segs[k]:GetValue()) == 54 end
	check("SPLIT_ABS: buff rides 4 chained segments, each fed Blizzard's value (hidden)", fedAll and not c.rider:IsShown(), "segments=" .. tostring(n))
	check("SPLIT_ABS: icon anchored to the last segment's fill edge", pt[1] == "LEFT" and pt[2] == c.segs[n]:GetStatusBarTexture() and pt[3] == "RIGHT")
	local geo = P.Geometry(lane)
	local pos = chainPosition(c.segs, n, 54, geo)
	check("SPLIT_ABS: chain puts the buff at CalcSplitPosition", math.abs(pos - CDTL3.CalcSplitPosition(54, lane.mode.splitAbs.max, lane)) < 1e-9,
		string.format("%.4f", pos))
	check("SPLIT_ABS: no module errors", P.errors == 0, tostring(P.lastError))
	-- the lane's settings change: laid out again
	lane.mode.splitAbs.count = 2
	feed(ITEM, 0.04, 60, 53)
	check("settings changed (2 split points): 3 segments, the 4th hidden", c.segCount == 3 and not c.segs[4]:IsShown()
		and ({ fb.icon:GetPoint(1) })[2] == c.segs[3]:GetStatusBarTexture())
	lane.mode.splitAbs.count = 3
	-- split points that don't increase: build 1's straight line
	local s2v = lane.mode.splitAbs.s2v
	lane.mode.splitAbs.s2v = 5
	feed(ITEM, 0.04, 60, 52)
	check("split points not increasing: straight line over splitAbs.max, segments hidden", c.rider:IsShown() and not c.segs[1]:IsShown()
		and select(2, c.rider:GetMinMaxValues()) == lane.mode.splitAbs.max and Val(c.rider:GetValue()) == 52
		and ({ fb.icon:GetPoint(1) })[2] == c.rider:GetStatusBarTexture())
	lane.mode.splitAbs.s2v = s2v
	lane.mode.type = "SPLIT"
	feed(ITEM, 0.04, 60, 52)
	check("SPLIT (%): buff keeps the straight line", c.rider:IsShown() and not c.segs[1]:IsShown())
	lane.mode.type = "SPLIT_ABS"
	feed(ITEM, 0.04, 60, 52)
	check("back on Split (Time): segments again", c.segs[1]:IsShown() and not c.rider:IsShown())
	P.Leave(fb, false)
	check("leaving hides the segments", not c.segs[1]:IsShown() and not c.segs[4]:IsShown() and not c.rider:IsShown())
	feed(ITEM, 0.04, 60, 52)
	check("rides the segments again on the next frame", CT:Riding(fb) and c.segs[1]:IsShown())
end
lane.mode.type = "LINEAR"
if fb.bar:IsVisible() then
	local _, fmx = fb.bar.bar:GetMinMaxValues()
	check("buff bar takes Blizzard's max and value", Val(fmx) == 60 and Val(fb.bar.bar:GetValue()) == 52)
end
local rogue = 0
for _, cd in ipairs(CDTL3.cooldowns) do if cd ~= fb and cd.ct and cd.ct.kind == "buff" and cd.ct.riding then rogue = rogue + 1 end end
check("unmapped item feeds nothing", rogue == 0 and P.mirror.recs[ITEM2] and P.mirror.recs[ITEM2].nameSet and next(P.mirror.recs[ITEM2].nameSet) == nil)
fb.data.currentCD = 0.05
feed(ITEM, 0.1, 60, 53)
check("buff estimate ran out while fed: held", CT:Riding(fb) and parentName(fb.icon) == "CDTL3_Lane_1")
check("status line", CT:StatusLine():find("riding: 1 spell, 1 buff", 1, true) and CT:StatusLine():find("Tracked Bars: Test Shield", 1, true)
	and CT:StatusLine():find("Blizzard's Tracked Bars: hidden", 1, true), CT:StatusLine())
print("  " .. CT:StatusLine())
RunOnUpdate(0.02, 35)   -- no feed for 0.7 s
check("stale feed ends the buff (Ready)", not CT:Riding(fb) and parentName(fb.icon) ~= "CDTL3_Lane_1", tostring(parentName(fb.icon)))
feed(ITEM, 0.4, 60, 59)
check("a new feed starts it again", CT:Riding(fb) and parentName(fb.icon) == "CDTL3_Lane_1")

-- one long frame is not "Blizzard stopped": CDTL3's update runs before Blizzard's next one
NOW = NOW + 1.5
fb.__scripts.OnUpdate(fb, 1.5)
check("a 1.5 s frame hitch doesn't end the buff", CT:Riding(fb) and parentName(fb.icon) == "CDTL3_Lane_1", tostring(parentName(fb.icon)))
feed(ITEM, 0.1, 60, 57)
check("still riding after the hitch", CT:Riding(fb) and Val(fb.ct.rider:GetValue()) == 57)

-- a single update of an idle bar (a layout refresh) is not a running buff
RunOnUpdate(0.02, 35)
check("feed stopped: buff ended", not CT:Riding(fb) and parentName(fb.icon) ~= "CDTL3_Lane_1")
ITEM.Bar:SetMinMaxValues(0, S(0)); ITEM.Bar:SetValue(S(0))
RunOnUpdate(0.02, 20)
check("one update of an idle bar doesn't start the buff", not CT:Riding(fb) and parentName(fb.icon) ~= "CDTL3_Lane_1", tostring(parentName(fb.icon)))
RunOnUpdate(0.02, 15)
feed(ITEM, 0.4, 60, 59)
check("a real feed after it starts the buff", CT:Riding(fb) and parentName(fb.icon) == "CDTL3_Lane_1")

---------------------------------------------------------------- 3b. estimated buffs are dimmed
print("[estimated " .. FLAVOR .. "]")
SPELLINFO[6020] = { "Guess Ward", 136004 }
local gs = entry(6020, "Guess Ward", "buffs", { bCD = 30000 })
table.insert(tables.buffs, gs)
local fg = CDTL3:CreateCooldown(CDTL3:GetUID(), "buffs", gs)
CDTL3:SendToLane(fg); CDTL3:SendToBarFrame(fg)
fg.data.currentCD = 25
local gt = fg.icon.txt and fg.icon.txt.text2
local gb = fg.bar.txt and fg.bar.txt.text1
local alphaSets = 0
if gt then
	local orig = gt.SetAlpha
	rawset(gt, "SetAlpha", function(self, a) alphaSets = alphaSets + 1; orig(self, a) end)
end
feed(ITEM, 0.1, 60, 50)
check("unfed buff while auras are hidden: estimated", CT:Estimated(fg) == true and parentName(fg.icon) == "CDTL3_Lane_1")
check("its icon text drawn at 0.55", gt and gt:GetAlpha() == 0.55, gt and tostring(gt:GetAlpha()))
check("its bar text drawn at 0.55", gb and gb:GetAlpha() == 0.55, gb and tostring(gb:GetAlpha()))
feed(ITEM, 0.2, 60, 50)
check("alpha set only when it changes", alphaSets == 1, tostring(alphaSets))
check("a riding buff: not estimated, text at full alpha", CT:Riding(fb) and CT:Estimated(fb) == false and fb.icon.txt.text2:GetAlpha() == 1)
check("a spell: not estimated", CT:Estimated(f) == false and f.icon.txt.text2:GetAlpha() == 1)
check("a debuff with no feed: estimated", CT:Estimated({ data = { type = "debuffs" } }) == true)
check("an item: not estimated", CT:Estimated({ data = { type = "items" } }) == false)
SECRET_AURAS = false
feed(ITEM, 0.06, 60, 50)
check("auras readable: not estimated, alpha back to 1", CT:Estimated(fg) == false and gt:GetAlpha() == 1 and gb:GetAlpha() == 1)
SECRET_AURAS = true
feed(ITEM, 0.06, 60, 50)
check("hidden again: dimmed again", gt:GetAlpha() == 0.55)
CT:SetEnabled(false)
feed(ITEM, 0.06, 60, 50)
check("module off: not estimated, alpha 1", CT:Estimated(fg) == false and gt:GetAlpha() == 1)
CT:SetEnabled(true)
feed(ITEM, 0.06, 60, 50)
check("module on again: dimmed", gt:GetAlpha() == 0.55)
fg.data.currentCD = 0.01
feed(ITEM, 0.1, 60, 50)
check("estimate over, off its lane: text alpha restored", parentName(fg.icon) ~= "CDTL3_Lane_1" and gt:GetAlpha() == 1 and gb:GetAlpha() == 1,
	tostring(parentName(fg.icon)) .. " " .. tostring(gt:GetAlpha()))

---------------------------------------------------------------- 4. setting off
print("[off " .. FLAVOR .. "]")
SPELLCD[TEST] = { startTime = S(NOW), duration = S(30), isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
DUR[TEST] = { NOW, 24 }
cast(TEST)
FireEvent("SPELL_UPDATE_COOLDOWN")
poll(f, 0.5)
check("spell riding before the switch", CT:Riding(f))
CT:SetEnabled(false)
check("off: nothing rides", not CT:Riding(f) and not CT:Riding(fb) and not f.icon.ctRiding)
check("off: Blizzard's opacity back", BuffBarCooldownViewer:GetAlpha() == 0.8)
check("off: setting saved", g.combatTimers.enabled == false and CT:Enabled() == false)
feed(ITEM, 0.1, 60, 58)
poll(f, 0.1)
local po = { f.icon:GetPoint(1) }
check("off: icon placed the normal way, no riding next frames", not CT:Riding(f) and not CT:Riding(fb) and type(po[2]) == "number")
check("off: status line", CT:StatusLine():find("Combat timers: off", 1, true) ~= nil, CT:StatusLine())
CT:SetEnabled(true)
check("on again: Blizzard's bars hidden", BuffBarCooldownViewer:GetAlpha() == 0)
poll(f, 0.3)
check("on again: rides", CT:Riding(f))

COMBAT = false
SECRET_AURAS = false
FireEvent("PLAYER_REGEN_ENABLED")
RunOnUpdate(0.02, 5)
check("no module errors anywhere", P.errors == 0, tostring(P.lastError))
for i = base + 1, #ERRORS do print("ERR: " .. tostring(ERRORS[i])) end
print(string.format("RESULT combattimers full %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
