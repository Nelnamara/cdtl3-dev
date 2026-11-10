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
	C_StringUtil = { CreateSecondsFormatter = function() return { SetMinInterval = function() end } end }
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
check("Blizzard's Tracked Bars hidden (alpha 0) at login", BuffBarCooldownViewer:GetAlpha() == 0)
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
-- the buff's text: SetFormattedText takes hidden values in game; record instead of formatting
local txt = fb.icon.txt and fb.icon.txt.text2
local function record(fs) if fs then rawset(fs, "SetFormattedText", function(self, fmt, v) self.__fmt, self.__fv = fmt, v end) end end
record(txt)
if fb.bar.txt then record(fb.bar.txt.text1); record(fb.bar.txt.text2); record(fb.bar.txt.text3) end
feed(ITEM, 0.4, 60, 55)
check("fresh feed starts the buff on its lane", parentName(fb.icon) == "CDTL3_Lane_1" and CT:Riding(fb) and fb.ct.kind == "buff", tostring(parentName(fb.icon)))
local _, bmx = fb.ct.rider:GetMinMaxValues()
check("LINEAR: rider takes Blizzard's max and value", Val(bmx) == 60 and Val(fb.ct.rider:GetValue()) == 55)
check("buff [cd.time] text: %.0f of the fed value", txt and txt.__fmt == "%.0f" and Val(txt.__fv) == 55)
lane.mode.type = "SPLIT_ABS"
feed(ITEM, 0.04, 60, 54)
check("SPLIT_ABS: buff on a straight line over splitAbs.max", select(2, fb.ct.rider:GetMinMaxValues()) == lane.mode.splitAbs.max and Val(fb.ct.rider:GetValue()) == 54)
lane.mode.type = "LINEAR"
if fb.bar:IsVisible() then
	local _, fmx = fb.bar.bar:GetMinMaxValues()
	check("buff bar takes Blizzard's max and value", Val(fmx) == 60 and Val(fb.bar.bar:GetValue()) == 54)
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
