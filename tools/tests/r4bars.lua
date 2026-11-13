-- Resource bars, fight timeline and the ready board (feature panel cards 17, 31, 27, 28). Real files, real AceDB.
--   17 Mana gauge at a lane's Ready end: place, fill, percent text only where it can be read, no mana, off
--   31 Change color at: the whole fill takes a color at or above a number; fixed while the value is hidden
--   27 Fight timeline: strip, flags, now line, one row per pinned cooldown; estimates ("~") never from hidden values
--   28 Ready frame mode Stay until used: a slot per pinned cooldown, bright when ready, dimmed with its time left
-- Every feature is off by default and changes nothing then.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "WARRIOR"
local ME = PLAYER.guid

-- a GetChildren that works (the stub's returns nothing): the frames parented to self
local mt = getmetatable(UIParent)
local oldIndex = mt.__index
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
mt.__index = function(t, k)
	if k == "GetChildren" then return kids end
	return oldIndex(t, k)
end

-- power: type -> { current, max }; HIDDEN[type] = the current value is secret
POW, HIDDEN, HIDDENMAX = { [0] = { 62, 100 }, [1] = { 60, 100 } }, {}, {}
function UnitPower(u, t)
	if HIDDEN[t or 0] then return SECRET end
	local p = POW[t or 0]
	return p and p[1] or 0
end
function UnitPowerMax(u, t)
	if HIDDENMAX[t or 0] then return SECRET end
	local p = POW[t or 0]
	return p and p[2] or 0
end

local function entry(id, name, extra)
	local e = { id = id, name = name, type = "spells", icon = 1, bCD = 30000, lane = 1, barFrame = 0, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local SPELLS = {
	[1001] = { "Shield Wall", { bCD = 120000, pinned = true } },
	[1002] = { "Spell Reflection", { bCD = 25000, pinned = true } },
	[1003] = { "Last Stand", { bCD = 180000, pinned = true } },
	[1004] = { "Plain Spell", { bCD = 30000 } },
}
local list = {}
for id, s in pairs(SPELLS) do
	list[#list + 1] = entry(id, s[1], s[2])
	SPELLINFO[id] = { s[1], 1 }
	KNOWN[id] = true
end
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = { tables = { spells = list },
	global = { unlockFrames = false } } } }

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end
local near = function(a, b, tol) return a and b and math.abs(a - b) <= (tol or 0.6) end
local P = CDTL3.db.profile
local g = P.global
if g["unlockFrames"] then CDTL3:ToggleFrameLock(true) end
local sounds = 0
PlaySoundFile = function() sounds = sounds + 1; return true end
local function cast(id, dur)
	SPELLCD[id] = { startTime = NOW, duration = dur, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id, id)
end
local function reset(id) SPELLCD[id] = nil end
local function live(name) return CDTL3:GetExistingCooldown(name, "spells") end
local function pname(fr) local p = fr:GetParent(); return p and p:GetName() or "nil" end
local function instantFades(fr)
	if fr.animateOut then fr.animateOut.Play = function() fr:SetAlpha(0) end end
	if fr.animateIn then fr.animateIn.Play = function() fr:SetAlpha(1) end end
end
for _, fr in ipairs({ CDTL3_Lane_1, CDTL3_Ready_1 }) do instantFades(fr) end
local l1, l2 = P.lanes["lane1"], P.lanes["lane2"]
local r1 = P.ready["ready1"]
local function colorIs(fr, c)
	local r, gg, b = fr:GetStatusBarColor()
	return near(r, c[1] or c.r, 0.001) and near(gg, c[2] or c.g, 0.001) and near(b, c[3] or c.b, 0.001)
end

-- closures built by pcall calls out of the new files (a closure per frame would make a new function each time)
local realPcall = pcall
local fnsFrom, nFns = {}, 0
local counting = false
pcall = function(fn, ...)
	if counting and not fnsFrom[fn] then
		local i = debug.getinfo(2, "S")
		local src = i and i.source or ""
		if src:find("ResourceBars.lua", 1, true) or src:find("FightTimeline.lua", 1, true) or src:find("ReadyBoard.lua", 1, true) then
			fnsFrom[fn] = true
			nFns = nFns + 1
		end
	end
	return realPcall(fn, ...)
end

---------------------------------------------------------------- off by default
print("[off by default " .. FLAVOR .. "]")
check("no gauge, no timeline, no board before anything is switched on",
	CDTL3_Lane_1_Gauge == nil and CDTL3_FightTimeline == nil and CDTL3_Ready_1_Board == nil)
check("lane gauge, color threshold, timeline and ready mode default off",
	l1.gauge.enabled == false and l1.tracking.threshold.enabled == false and g.fightTimeline.enabled == false and r1.mode == "NORMAL")
check("lane 2 and 3 carry the same defaults", P.lanes["lane3"].gauge.enabled == false and l2.tracking.threshold.value == 40
	and l2.gauge.width == 16 and l2.gauge.height == 44)

---------------------------------------------------------------- 17: mana gauge
print("[17 mana gauge " .. FLAVOR .. "]")
l1.gauge.enabled = true
CDTL3:RefreshLane(1)
RunOnUpdate(0.05, 4)
local gauge = CDTL3_Lane_1_Gauge
check("gauge made, a child of lane 1", gauge ~= nil and gauge:GetParent() == CDTL3_Lane_1)
local function pt() local p = gauge.__points[1]; return p and (p[1] .. ">" .. tostring(p[3]) .. " " .. tostring(p[4]) .. "," .. tostring(p[5])) or "none" end
check("horizontal lane: at the Ready (left) end, top aligned, 6 away", pt() == "TOPRIGHT>TOPLEFT -6,0", pt())
check("sized 16 x 44, upright", gauge.__w == 16 and gauge.__h == 44)
local lo, hi = gauge:GetMinMaxValues()
check("fill is mana 62 of 100", gauge:GetValue() == 62 and lo == 0 and hi == 100, tostring(gauge:GetValue()))
check("percent under it: 62%", gauge.pct:GetText() == "62%", tostring(gauge.pct:GetText()))
check("percent hangs from the gauge's bottom", gauge.pct.__points[1][1] == "TOP" and gauge.pct.__points[1][3] == "BOTTOM")
POW[0] = { 31, 100 }
RunOnUpdate(0.05, 4)
check("mana 31: fill and percent follow", gauge:GetValue() == 31 and gauge.pct:GetText() == "31%")
l1.reversed = true; CDTL3:RefreshLane(1)
check("reversed lane: Ready end is its right", pt() == "TOPLEFT>TOPRIGHT 6,0", pt())
l1.reversed = false; l1.vertical = true; CDTL3:RefreshLane(1)
check("vertical lane: Ready end is its bottom", pt() == "TOP>BOTTOM 0,-6", pt())
l1.reversed = true; CDTL3:RefreshLane(1)
check("vertical reversed: Ready end is its top, percent above the gauge", pt() == "BOTTOM>TOP 0,6" and gauge.pct.__points[1][1] == "BOTTOM", pt())
l1.reversed, l1.vertical = false, false; CDTL3:RefreshLane(1)
-- hidden mana (Retail and Forever in combat): the bar is fed the hidden value, the percent is blank, no error
HIDDEN[0] = true; HIDDENMAX[0] = true
local e0 = #ERRORS
RunOnUpdate(0.05, 4)
check("hidden mana: the gauge takes the hidden value", rawequal(gauge:GetValue(), SECRET) and rawequal(select(2, gauge:GetMinMaxValues()), SECRET))
check("hidden mana: no percent text, still showing, no errors", gauge.pct:GetText() == "" and gauge:GetAlpha() == 1 and #ERRORS == e0)
HIDDEN[0] = false; HIDDENMAX[0] = false
RunOnUpdate(0.05, 4)
check("readable again: the percent comes back", gauge.pct:GetText() == "31%", tostring(gauge.pct:GetText()))
POW[0] = { 0, 0 }
RunOnUpdate(0.05, 4)
check("a class with no mana pool: the gauge is invisible", gauge:GetAlpha() == 0)
POW[0] = { 62, 100 }
RunOnUpdate(0.05, 4)
check("mana pool back: visible again", gauge:GetAlpha() == 1 and gauge.pct:GetText() == "62%")
l1.gauge.showPercent = false; CDTL3:RefreshLane(1)
check("Show percent off: no text", gauge.pct:IsShown() == false)
l1.gauge.showPercent = true; l1.gauge.width, l1.gauge.height, l1.gauge.gap = 30, 80, 12; CDTL3:RefreshLane(1)
check("width, height and distance apply", gauge.__w == 30 and gauge.__h == 80 and pt() == "TOPRIGHT>TOPLEFT -12,0", pt())
l1.gauge.width, l1.gauge.height, l1.gauge.gap = 16, 44, 6
l1.gauge.enabled = false; CDTL3:RefreshLane(1)
check("switched off: hidden", gauge:IsShown() == false)
l1.gauge.enabled = true; CDTL3:RefreshLane(1)
check("switched on again: shown", gauge:IsShown() == true)

---------------------------------------------------------------- 31: change color at
print("[31 change color at " .. FLAVOR .. "]")
local lane = CDTL3_Lane_1
CDTL3.player["classPower"] = Enum.PowerType.Rage
POW[1] = { 60, 100 }
l1.tracking.primaryTracking = "CLASS_POWER"
CDTL3:RefreshLane(1)
local baseColor = { lane:GetStatusBarColor() }
RunOnUpdate(0.02, 12)
check("threshold off (default): rage 60 leaves the fill alone", colorIs(lane, baseColor))
local th = l1.tracking.threshold
th.enabled = true
RunOnUpdate(0.02, 12)
check("on, rage 60 at 40: the whole fill takes the changed color", colorIs(lane, th.color), string.format("%.3f", (lane:GetStatusBarColor())))
POW[1] = { 40, 100 }
RunOnUpdate(0.02, 12)
check("exactly 40: still changed (at or above)", colorIs(lane, th.color))
POW[1] = { 39, 100 }
RunOnUpdate(0.02, 12)
check("rage 39: back to the normal color", colorIs(lane, baseColor))
POW[1] = { 80, 100 }
RunOnUpdate(0.02, 12)
th.value = 90
POW[1] = { 80, 100 }
RunOnUpdate(0.02, 12)
check("moved the number to 90: rage 80 is under it", colorIs(lane, baseColor))
th.value = 40
RunOnUpdate(0.02, 12)
check("number back to 40: changed again", colorIs(lane, th.color))
-- hidden in combat: can't be compared, the fill keeps its normal color, nothing throws
HIDDEN[1] = true
e0 = #ERRORS
RunOnUpdate(0.02, 12)
check("rage hidden: the normal color, the bar still fed the hidden value, no errors",
	colorIs(lane, baseColor) and lane.secretRange == true and #ERRORS == e0)
HIDDEN[1] = false
RunOnUpdate(0.02, 12)
check("readable again: changed color back", colorIs(lane, th.color) and lane.secretRange ~= true)
th.color = { r = 0.1, g = 0.9, b = 0.2, a = 1 }
CDTL3:RefreshLane(1)
RunOnUpdate(0.02, 12)
check("a picked color applies", colorIs(lane, th.color))
l1.tracking.primaryTracking = "NONE"
RunOnUpdate(0.02, 12)
check("Primary Tracking no longer Class Power: the normal color", colorIs(lane, baseColor))
l1.tracking.primaryTracking = "CLASS_POWER"
RunOnUpdate(0.02, 12)
th.enabled = false
RunOnUpdate(0.02, 12)
check("switched off: the normal color", colorIs(lane, baseColor))
l1.tracking.primaryTracking = "NONE"
th.enabled = false

---------------------------------------------------------------- 31: stagger (Brewmaster; where the client has UnitStagger)
print("[31 stagger " .. FLAVOR .. "]")
do
	local gen = CDTL3:GetFullOptions().args.lanes.args.lane1.args.general.args
	local pt = gen.primaryTracking
	local mtv = function() return pt.values({}) end
	local cls = CDTL3.player["class"]
	check("no UnitStagger on this client: no Stagger choice, whatever the class", (function() CDTL3.player["class"] = "MONK"; local v = mtv(); CDTL3.player["class"] = cls; return v["STAGGER"] == nil end)())
	local STAG, STAGHIDDEN = 50, false
	function UnitStagger() if STAGHIDDEN then return SECRET end return STAG end
	check("UnitStagger there: a monk's list has Stagger, another class's does not", (function()
		CDTL3.player["class"] = "MONK"; local a = mtv()["STAGGER"]; CDTL3.player["class"] = cls
		return a == "Stagger" and mtv()["STAGGER"] == nil
	end)())
	l1.tracking.primaryTracking = "STAGGER"
	CDTL3:RefreshLane(1)
	local baseC = { lane:GetStatusBarColor() }
	RunOnUpdate(0.02, 12)
	check("Stagger on the lane: the fill is stagger over max health (50 of 100)", near(lane.__val, 0.5, 0.001), tostring(lane.__val))
	th.enabled, th.value = true, 40
	check("  Change color at's controls are not greyed out for it", gen.thresholdValue.disabled() == false and gen.thresholdColor.disabled() == false)
	RunOnUpdate(0.02, 12)
	check("  Change color at 40 (percent of max health), out of combat: 50 is over it, the fill changes", colorIs(lane, th.color))
	STAG = 30
	RunOnUpdate(0.02, 12)
	check("  30 is under it: the normal color", colorIs(lane, baseC))
	STAG, STAGHIDDEN = 60, true
	e0 = #ERRORS
	RunOnUpdate(0.02, 12)
	check("  hidden in combat: the bar is fed the hidden value, the normal color, no errors", rawequal(lane.__val, SECRET) and lane.secretRange == true and colorIs(lane, baseC) and #ERRORS == e0,
		"errors " .. (#ERRORS - e0))
	STAGHIDDEN = false
	RunOnUpdate(0.02, 12)
	check("  readable again: the change comes back", colorIs(lane, th.color) and lane.secretRange ~= true)
	l1.tracking.primaryTracking = "NONE"
	th.enabled = false
	RunOnUpdate(0.02, 12)
	UnitStagger = nil
	l1.tracking.primaryTracking = "STAGGER"
	RunOnUpdate(0.02, 12)
	check("  a client without UnitStagger: nothing to show, no errors", #ERRORS == e0)
	l1.tracking.primaryTracking = "NONE"
end

-- no closure per frame from the new files while lane 1 updates with both features on
th.enabled = true
l1.tracking.primaryTracking = "CLASS_POWER"
CDTL3:RefreshLane(1)
fnsFrom, nFns, counting = {}, 0, true
for _ = 1, 40 do RunOnUpdate(0.02, 15); xpcall(gauge.__scripts.OnUpdate, ERRH, gauge, 0.2) end
counting = false
check("gauge and threshold ticks make no closures (pcall'd functions from the new files)", nFns <= 4, "distinct=" .. nFns)
th.enabled = false
l1.tracking.primaryTracking = "NONE"
l1.gauge.enabled = false; CDTL3:RefreshLane(1)

---------------------------------------------------------------- 28: ready board
print("[28 ready board " .. FLAVOR .. "]")
RunOnUpdate(0.02, 60)
-- before the mode: a pinned cooldown that came back waits in Ready 1 as always
cast(1001, 20)
RunOnUpdate(0.02, 5)
reset(1001)
RunOnUpdate(0.02, 55)
check("Normal mode: the pinned icon waits in Ready 1, no board", live("Shield Wall") and pname(live("Shield Wall").icon) == "CDTL3_Ready_1_MF" and CDTL3_Ready_1_Board == nil,
	live("Shield Wall") and pname(live("Shield Wall").icon))
r1.mode = "STAY"
CDTL3:RefreshReady(1)
RunOnUpdate(0.1, 12)
local board = CDTL3_Ready_1_Board
check("Stay until used: a board in Ready 1", board ~= nil and board:GetParent() == CDTL3_Ready_1 and CDTL3_Ready_1.boardOn == true)
check("a slot for each of the three pinned cooldowns, not the plain one", board and board.count == 3 and CDTL3_Ready_1.boardCount == 3,
	board and tostring(board.count))
local names = {}
for k = 1, board.count do names[board.slots[k].e["name"]] = k end
check("the pinned three are the slots, not the plain one", names["Shield Wall"] and names["Spell Reflection"] and names["Last Stand"] and not names["Plain Spell"])
check("the Ready frame counts them, so Auto-hide Frames keeps it up", CDTL3_Ready_1.childCount >= 3, tostring(CDTL3_Ready_1.childCount))
local sw, lst = live("Shield Wall"), live("Last Stand")
local slotSW, slotLS = board.slots[names["Shield Wall"]], board.slots[names["Last Stand"]]
check("a pinned cooldown never used has no frame yet and still reads ready", lst == nil and slotLS.cd == nil and slotLS.cooling == false and slotLS.state:GetText() == "READY",
	tostring(slotLS.state:GetText()))
check("ready: bright, Ready text; the pinned icon that waited in Ready 1 goes to holding",
	slotSW.cooling == false and slotSW.state:GetText() == "READY" and slotSW.dim:IsShown() == false
	and pname(sw.icon) == "CDTL3_Active_Icon_Holding",
	tostring(slotSW.cooling) .. " " .. tostring(slotSW.state:GetText()) .. " " .. pname(sw.icon))
check("the slot's name text is the short name", (slotSW.name:GetText() or "") ~= "", tostring(slotSW.name:GetText()))
check("slots are fixed: column, first at the top, second one icon lower", board.slots[1].__points[1][1] == "TOPLEFT"
	and board.slots[2].__points[1][5] == board.slots[1].__points[1][5] - r1.icons.size,
	tostring(board.slots[2].__points[1][5]))
sounds = 0
cast(1001, 120)
RunOnUpdate(0.02, 15)
check("used: its slot dims and shows the time left", slotSW.cooling == true and slotSW.dim:IsShown() == true and (slotSW.state:GetText() or ""):match("^[12]:%d%d$") ~= nil,
	tostring(slotSW.state:GetText()))
check("the others stay ready", slotLS.cooling == false and slotLS.state:GetText() == "READY")
RunOnUpdate(0.1, 100)
check("10 s on: the time counts down", (slotSW.state:GetText() or ""):match("^1:[45]%d$") ~= nil, tostring(slotSW.state:GetText()))
reset(1001)
RunOnUpdate(0.02, 60)
check("the game says it is over: bright again at once, one ready sound", slotSW.cooling == false and slotSW.state:GetText() == "READY" and sounds == 1
	and pname(sw.icon) ~= "CDTL3_Ready_1_MF", tostring(slotSW.cooling) .. " sounds=" .. sounds .. " " .. pname(sw.icon))
-- a cooldown whose time is hidden (riding the game's timer): never read, the estimate from the cast, marked ~
cast(1003, 180)
RunOnUpdate(0.02, 15)
lst = live("Last Stand")
check("Last Stand used: it has its frame now and its slot is cooling", lst ~= nil and slotLS.cooling == true)
lst.ct = lst.ct or {}
lst.ct.riding, lst.data.currentCD = true, 0.1
CDTL3.spellCastTimes = CDTL3.spellCastTimes or {}
CDTL3.spellCastTimes[1003] = NOW - 30
board.acc = 1
xpcall(board.__scripts.OnUpdate, ERRH, board, 0.2)
check("hidden time: the estimate from the cast, marked ~ (2:30, not the 0.1 placeholder)", slotLS.state:GetText() == "~2:30", tostring(slotLS.state:GetText()))
lst.ct.riding, lst.ct.noText = false, nil
reset(1003)
RunOnUpdate(0.02, 60)
-- Auto-hide Frames: the board's frame stays out of combat, where a Normal frame holding only pinned icons hides
g["autohide"] = true
CDTL3.combat = false
CDTL3:RefreshReady(1); instantFades(CDTL3_Ready_1)
RunOnUpdate(0.1, 150)
check("Auto-hide on, 15 s out of combat: the board's frame stays up", CDTL3_Ready_1:GetAlpha() ~= 0, tostring(CDTL3_Ready_1:GetAlpha()))
r1.mode = "NORMAL"
CDTL3:RefreshReady(1)
RunOnUpdate(0.1, 150)
check("Normal again: the board is hidden, the ready pinned icons are back in Ready 1",
	board:IsShown() == false and CDTL3_Ready_1.boardOn == nil and (CDTL3_Ready_1.boardCount or 0) == 0 and pname(sw.icon) == "CDTL3_Ready_1_MF",
	pname(sw.icon))
check("and a Normal frame holding only pinned icons hides after Pinned Hide Time, as before", CDTL3_Ready_1:GetAlpha() == 0, tostring(CDTL3_Ready_1:GetAlpha()))
g["autohide"] = false
CDTL3:RefreshReady(1); instantFades(CDTL3_Ready_1)
RunOnUpdate(0.1, 20)

---------------------------------------------------------------- 27: fight timeline
print("[27 fight timeline " .. FLAVOR .. "]")
local FT = CDTL3.FightTimeline
local fts = g.fightTimeline
for _, id in ipairs({ 1001, 1002, 1003 }) do reset(id) end
RunOnUpdate(0.02, 60)
fts.enabled = true
FT.Apply()
RunOnUpdate(0.1, 8)
local tl = CDTL3_FightTimeline
check("the strip is made and showing", tl ~= nil and tl:IsShown() == true)
check("340 wide, 130 high for three rows", tl.sw == 340 and tl.sh == 130, tostring(tl.sw) .. "x" .. tostring(tl.sh))
local function rowOf(name)
	for k = 1, 8 do
		local r = tl.rows[k]
		if r.e and r.e["name"] == name then return r end
	end
end
local rSW, rSR, rLS = rowOf("Shield Wall"), rowOf("Spell Reflection"), rowOf("Last Stand")
check("a row for each pinned cooldown", rSW and rSR and rLS and not rowOf("Plain Spell"))
check("before the pull the now line is at the pull; ready rows read ready", tl.nowText:GetText() == "now 0:00" and tl.nowLine.px == 19 and rSW.lbl:GetText() == "ready"
	and rSW.seg:IsShown() == false, tostring(tl.nowText:GetText()) .. " " .. tostring(tl.nowLine.px))
check("flags at 2:00, 3:00, 5:00 (x 120, 170, 270 of a 340 strip, 360 s)", tl.flagText[1]:GetText() == "2:00" and tl.flagText[2]:GetText() == "3:00" and tl.flagText[3]:GetText() == "5:00"
	and near(tl.flags[1].px, 120) and near(tl.flags[2].px, 170) and near(tl.flags[3].px, 270), tostring(tl.flags[1].px))
check("the axis: pull to 6:00", tl.axisL:GetText() == "pull" and tl.axisR:GetText() == "6:00")
cast(1001, 120)
RunOnUpdate(0.02, 15)
check("Shield Wall used out of combat: a bar from the pull to 2:00 (100 px), ends at 2:00", near(rSW.seg.sw, 100, 1.5) and rSW.seg.px == 20 and rSW.lbl:GetText() == "2:00",
	tostring(rSW.seg.sw) .. " " .. tostring(rSW.lbl:GetText()))
check("its icon sits at the bar's end", near(rSW.ic.px, 20 + 100 - 11, 2), tostring(rSW.ic.px))
-- the pull, 72 s in
FireEvent("PLAYER_REGEN_DISABLED")
Advance(72)
RunOnUpdate(0.02, 60)
local tilde = RETAILAPI and "~" or ""
check("73 s in: now 1:13, the past is shaded 61 px", tl.nowText:GetText() == "now 1:13" and near(tl.past.sw, 61, 1.5), tostring(tl.nowText:GetText()) .. " " .. tostring(tl.past.sw))
check("Shield Wall still ends at 2:00 (" .. (RETAILAPI and "estimate ~ in combat on this client" or "exact on this client") .. ")", rSW.lbl:GetText() == tilde .. "2:00" and near(rSW.seg.px, 20 + 73.2 / 360 * 300, 1.5),
	tostring(rSW.lbl:GetText()) .. " " .. tostring(rSW.seg.px))
check("the part already run is the faded bar from the pull to now", rSW.was:IsShown() and near(rSW.was.sw, tl.past.sw, 1.5))
check("a ready cooldown sits at the now line", rSR.lbl:GetText() == "ready" and near(rSR.ic.px, tl.nowLine.px + 1 - 11, 2))
cast(1003, 600)
RunOnUpdate(0.02, 15)
check("a cooldown back after the strip's end: the bar runs to the end, the icon sits there", near(rLS.seg.px + rLS.seg.sw, 320, 1.5) and near(rLS.ic.px, 320 - 11, 2),
	tostring(rLS.seg.px + rLS.seg.sw))
-- hidden time: never read; the cast plus the base cooldown, marked ~
cast(1002, 25)
RunOnUpdate(0.02, 15)
local sr = live("Spell Reflection")
sr.ct = sr.ct or {}
sr.ct.riding, sr.data.currentCD = true, 0.1
CDTL3.spellCastTimes[1002] = NOW - 10
tl.acc = 1
xpcall(tl.__scripts.OnUpdate, ERRH, tl, 0.2)
check("hidden time: ~ and the end 15 s on (12.5 px), not the 0.1 placeholder", (rSR.lbl:GetText() or ""):sub(1, 1) == "~" and near(rSR.seg.sw, 12.5, 1.5),
	tostring(rSR.lbl:GetText()) .. " " .. tostring(rSR.seg.sw))
sr.ct.riding, sr.ct.noText = false, nil
reset(1002)
-- hide out of combat
fts.hideOutOfCombat = true
FireEvent("PLAYER_REGEN_ENABLED")
check("Hide out of combat: gone after the fight", tl:IsShown() == false)
FireEvent("PLAYER_REGEN_DISABLED")
check("and back at the pull", tl:IsShown() == true)
fts.hideOutOfCombat = false
FireEvent("PLAYER_REGEN_ENABLED")
check("off: it stays after the fight, the now line back at the pull", tl:IsShown() == true)
RunOnUpdate(0.02, 15)
check("out of combat: now 0:00 again", tl.nowText:GetText() == "now 0:00", tostring(tl.nowText:GetText()))
fts.flag2 = 0
RunOnUpdate(0.1, 3)
check("a flag set to 0 is gone", tl.flags[2]:IsShown() == false and tl.flagText[2]:IsShown() == false and tl.flags[1]:IsShown() == true)
fts.flag2 = 180
fts.enabled = false
FT.Apply()
check("switched off: hidden", tl:IsShown() == false)
for _, id in ipairs({ 1001, 1002, 1003 }) do reset(id) end

---------------------------------------------------------------- the options window
print("[options " .. FLAVOR .. "]")
local opts = CDTL3:GetFullOptions()
local lg = opts.args.lanes.args.lane1.args.general.args
check("Lanes > Lane 1 > General has the color threshold and the mana gauge controls", lg.thresholdEnabled and lg.thresholdValue and lg.thresholdColor
	and lg.gaugeEnabled and lg.gaugePercent and lg.gaugeColor and lg.gaugeWidth and lg.gaugeHeight and lg.gaugeGap)
check("the threshold tooltip says the color stays fixed while hidden", lg.thresholdEnabled.desc:find("hidden in combat", 1, true) ~= nil)
check("the number takes only numbers", lg.thresholdValue.validate(nil, "abc") ~= true and lg.thresholdValue.validate(nil, "55") == true)
lg.thresholdValue.set(nil, "55")
check("typed 55 is saved as the number", l1.tracking.threshold.value == 55)
l1.tracking.threshold.value = 40
check("the threshold controls grey out unless Primary Tracking is Class Power", lg.thresholdValue.disabled() == true)
local rg = opts.args.ready.args.ready1.args.general.args
check("Ready > Ready 1 > General has the Mode select", rg.mode and rg.mode.values["STAY"] ~= nil and rg.mode.get() == "NORMAL")
rg.mode.set(nil, "STAY")
check("choosing Stay until used saves it and builds the board", r1.mode == "STAY" and CDTL3_Ready_1.boardOn == true)
rg.mode.set(nil, "NORMAL")
check("and Normal puts it back", r1.mode == "NORMAL" and CDTL3_Ready_1.boardOn == nil)
local ft = opts.args.fightTimeline
check("a Fight Timeline tab with Enabled, Length and three flags", ft and ft.args.enabled and ft.args.span and ft.args.flag1 and ft.args.flag2 and ft.args.flag3)
ft.args.enabled.set(nil, true)
check("switching it on shows the strip", fts.enabled == true and CDTL3_FightTimeline:IsShown() == true)
ft.args.enabled.set(nil, false)

pcall = realPcall
print(string.format("RESULT r4bars %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
