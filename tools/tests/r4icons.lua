-- Icon and lane extras (feature panel of 12 Nov 2026, cards 2, 5, 22, 23, 25, 26; IconFx.lua):
-- charge pips, the buff lane flash and ghost, the burst window (shaded, and the Ready-by list), the
-- refresh zone (Era, TBC, MoP), the ready-soon pulse and GCD waits in the Ready frame. Each is off until
-- its setting is on. Real files, real AceDB; charges, buffs and the GCD are faked.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
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
-- the stub's scale and vertex colour calls do nothing: record what they were given
mt.__index = function(t, k)
	if k == "GetChildren" then return kids end
	if k == "SetScaleTo" then return function(s, x, y) rawset(s, "__scaleTo", x) end end
	if k == "SetVertexColor" then return function(s, r, gg, b, a) rawset(s, "__vertex", { r, gg, b, a }) end end
	if k == "Play" then return function(s) rawset(s, "__playing", true) end end
	if k == "Stop" then return function(s) rawset(s, "__playing", false) end end
	return oldIndex(t, k)
end

local function entry(id, name, extra)
	local e = { id = id, name = name, type = "spells", icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local SPELLS = {
	[931] = { "Charge Spell", { bCD = 20000, charges = 3 } },
	[932] = { "Warn Spell", { bCD = 30000, warnSecs = 5, warnSound = "CDTL3 Tinks" } },
	[933] = { "Pin A", { bCD = 20000, pinned = true } },
	[934] = { "Pin B", { bCD = 60000, pinned = true } },
	[935] = { "Gcd Spell", { bCD = 8000 } },
	[936] = { "Plain Spell", { bCD = 30000 } },
}
local list = {}
for id, s in pairs(SPELLS) do
	list[#list + 1] = entry(id, s[1], s[2])
	SPELLINFO[id] = { s[1], 1 }
	KNOWN[id] = true
end
local buffs = {
	{ id = 941, name = "Alert Buff", type = "buffs", icon = 1, bCD = 10000, lane = 1, barFrame = 1, readyFrame = 1, enabled = true,
		ignored = false, highlight = false, pinned = false, usedBy = { ME }, alertGain = true, alertEnd = true },
	{ id = 942, name = "Quiet Buff", type = "buffs", icon = 1, bCD = 10000, lane = 1, barFrame = 1, readyFrame = 1, enabled = true,
		ignored = false, highlight = false, pinned = false, usedBy = { ME } },
}
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = { tables = { spells = list, buffs = buffs } } } }

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end
local g = CDTL3.db.profile.global
if g["unlockFrames"] then CDTL3:ToggleFrameLock(true) end   -- a fresh profile starts unlocked
local l1 = CDTL3.db.profile.lanes["lane1"]
local FX = CDTL3.IconFx
local lane = CDTL3_Lane_1

-- the stub's fade animations do nothing: finish them at once
for _, fr in ipairs({ CDTL3_Lane_1, CDTL3_Ready_1 }) do
	if fr.animateOut then fr.animateOut.Play = function() fr:SetAlpha(0) end end
	if fr.animateIn then fr.animateIn.Play = function() fr:SetAlpha(1) end end
end

local played = {}
PlaySoundFile = function(path) played[#played + 1] = path; return true end
local function P(name) return CDTL3.LSM:Fetch("sound", name) end
local function cast(id, dur)
	SPELLCD[id] = { startTime = NOW, duration = dur, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id, id)
end
local function live(name, t) return CDTL3:GetExistingCooldown(name, t or "spells") end
local function pname(fr) local p = fr:GetParent(); return p and p:GetName() or "nil" end
local function leave() RunOnUpdate(0.1, 80) end	-- past every Normal Duration
local function near(a, b, tol) return a and b and math.abs(a - b) <= tol end

-- charges: CH = { cur, max, start, dur } for spell 931, as the game gives them
local CH = { cur = 2, max = 3, start = NOW - 4, dur = 10 }
local chargeData = nil   -- retail: what C_Spell.GetSpellCharges hands out (a test can put hidden values in)
if RETAILAPI then
	C_Spell.GetSpellCharges = function(id)
		if id ~= 931 then return nil end
		if chargeData then return chargeData end
		return { currentCharges = CH.cur, maxCharges = CH.max, cooldownStartTime = CH.start, cooldownDuration = CH.dur, chargeModRate = 1 }
	end
else
	GetSpellCharges = function(id)
		if id ~= 931 then return nil end
		return CH.cur, CH.max, CH.start, CH.dur, 1
	end
end

---------------------------------------------------------------- off by default
print("[off by default " .. FLAVOR .. "]")
do
	local fx = l1.fx
	check("every lane has the Effects settings, all off", fx and fx.chargePips == false and fx.gcdWait == false and fx.burst.enabled == false
		and fx.burst.list == false and fx.burst.shaded == true and fx.burst.secs == 25 and fx.refresh.enabled == false and fx.refresh.pct == 30)
	local fx3 = CDTL3.db.profile.lanes["lane3"].fx
	check("  lane 3 too", fx3 and fx3.chargePips == false and fx3.burst.enabled == false)
	check("no zone, no list, no flash made on the lane", lane.fxBurst == nil and lane.fxRefresh == nil and lane.fxList == nil and lane.fxFlash == nil)

	-- a plain spell: lane, then Ready, nothing of the extras
	played = {}
	cast(936, 30)
	RunOnUpdate(0.02, 5)
	local F = live("Plain Spell")
	check("a plain cast rides lane 1", pname(F.icon) == "CDTL3_Lane_1", pname(F.icon))
	check("  no pips, no pulse", F.icon.fxPips == nil and F.icon.fxPulse == nil)
	SPELLCD[936] = nil
	RunOnUpdate(0.02, 55)
	check("  Ready 1 with its one sound, as before", pname(F.icon) == "CDTL3_Ready_1_MF" and #played == 1 and played[1] == P("CDTL3 Click"), pname(F.icon) .. " " .. #played)
	leave()
end

---------------------------------------------------------------- fp02 charge pips
print("[fp02 charge pips " .. FLAVOR .. "]")
do
	-- pips off: a charge spell with a charge left reads ready at once
	CH.cur, CH.max, CH.start, CH.dur = 2, 3, NOW - 4, 10
	cast(931, 0)
	RunOnUpdate(0.02, 60)
	local F = live("Charge Spell")
	check("pips off: no pips drawn", F.icon.fxPips == nil)
	leave()

	l1.fx.chargePips = true
	CH.start = NOW - 4
	played = {}
	cast(931, 0)
	RunOnUpdate(0.02, 60)
	local ic = F.icon
	local pf = ic.fxPips
	check("pips on: the spell rides its recharge on the lane", pname(ic) == "CDTL3_Lane_1" and near(F.data.currentCD, 4.8, 0.6),
		pname(ic) .. " cd=" .. tostring(F.data.currentCD))
	check("  three pips on the icon's bottom edge", pf and pf:IsShown() and pf.n == 3 and pf.pip[3].__shown and not pf.pip[4].__shown,
		pf and tostring(pf.n))
	do
		local t2 = ic.txt and ic.txt.text2
		local base2 = l1.icons.text2.offY
		local last = t2 and t2.__points[#t2.__points]
		check("  the icon's timer text stands 4 px higher so the pips don't sit on it", t2 and ic.fxNudge == true and last and last[5] == base2 + 4,
			last and tostring(last[5]) .. " vs " .. tostring(base2))
		CDTL3:RefreshIcon(F)
		last = t2.__points[#t2.__points]
		check("  and a refresh of the icon keeps it there", last and last[5] == base2 + 4, last and tostring(last[5]))
	end
	check("  each fed the count: 2 charges light two (pip i spans i-1 to i)", pf and pf.pip[1].lit.__val == 2 and pf.pip[2].lit.__val == 2
		and pf.pip[3].lit.__val == 2 and pf.pip[1].lit.__min == 0 and pf.pip[2].lit.__min == 1 and pf.pip[3].lit.__max == 3)
	check("  the third pip fills as it recharges (about half)", pf and near(pf.pip[3].part.__val, 0.6, 0.15) and pf.pip[1].part.__val == 0,
		pf and tostring(pf.pip[3].part.__val))
	check("  no ready sound while it recharges", #played == 0)

	-- one charge back, still short of full: still riding, two pips lit... then 3 of 3 and it is ready
	CH.cur, CH.start = 3, NOW - 12
	SPELLCD[931] = nil
	RunOnUpdate(0.02, 60)
	check("all charges back: Ready 1, the pips gone", pname(ic) == "CDTL3_Ready_1_MF" and not ic.fxPips:IsShown(), pname(ic))
	check("  the timer text is back where it was", ic.fxNudge == false)
	leave()

	-- a spell that is not a charge spell never gets pips, and the answer is remembered
	l1.fx.chargePips = true
	cast(936, 30)
	RunOnUpdate(0.02, 5)
	local P1 = live("Plain Spell")
	check("a spell with no charges shows no pips", P1.data.fxMax == false and (P1.icon.fxPips == nil or not P1.icon.fxPips:IsShown()))
	SPELLCD[936] = nil
	RunOnUpdate(0.02, 55)
	leave()

	-- hidden charge count and times (Retail, Forever in combat): the count only goes into the bars
	if RETAILAPI then
		CH.cur, CH.start = 2, NOW - 4
		chargeData = { currentCharges = SECRET, maxCharges = 3, cooldownStartTime = SECRET, cooldownDuration = SECRET }
		local e0 = #ERRORS
		cast(931, 0)
		RunOnUpdate(0.02, 60)
		pf = F.icon.fxPips
		check("hidden count: the pips take it without a compare, no errors", pf and pf:IsShown() and rawequal(pf.pip[1].lit.__val, SECRET)
			and rawequal(pf.pip[3].lit.__val, SECRET) and #ERRORS == e0, "errors " .. (#ERRORS - e0))
		check("  the filling pip is left out (it needs the count compared)", pf.pip[1].part.__val == 0 and pf.pip[2].part.__val == 0 and pf.pip[3].part.__val == 0)
		chargeData = nil
		CH.cur = 3
		SPELLCD[931] = nil
		RunOnUpdate(0.02, 60)
		leave()
	end
	l1.fx.chargePips = false
end

---------------------------------------------------------------- fp05 lane flash
print("[fp05 lane flash " .. FLAVOR .. "]")
do
	local function aura(up)
		if up then
			AURAS = { HELPFUL = { { name = "Alert Buff", spellId = 941, duration = 10, expirationTime = NOW + 10, applications = 0, icon = 1 } }, HARMFUL = {} }
		else
			AURAS = { HELPFUL = {}, HARMFUL = {} }
		end
	end
	-- gained (the buff shows up on you: its cooldown is made from the saved entry and starts on its lane)
	played = {}
	aura(true)
	CDTL3:OnPlayerAuraApplied(941, "Alert Buff", "buffs", true)
	local B = live("Alert Buff", "buffs")
	check("the buff has its alert settings from Filters", B and B.data.alertGain == true and B.data.alertEnd == true)
	RunOnUpdate(0.02, 5)
	local fl = lane.fxFlash
	check("gained: the lane flashes green round its edge", fl and fl:IsShown() and fl.greenRing[1].__shown == true and fl.redEnd.__shown == false,
		fl and tostring(fl:IsShown()))
	check("  and its sound plays", #played == 1 and played[1] == P("CDTL3 Click"), #played .. " played")
	RunOnUpdate(0.1, 20)
	check("  the flash fades after a moment", not fl:IsShown() and lane.fxFlashUntil == nil)

	-- dropped
	played = {}
	aura(false)
	RunOnUpdate(0.02, 60)
	check("dropped: red at the Ready end of the lane", fl:IsShown() and fl.redEnd.__shown == true and fl.greenRing[1].__shown == false)
	local gh = lane.fxGhost
	check("  a struck-out ghost of the buff at the Ready end, with the buff's art", gh and gh:IsShown() and gh.tex.__tex == 1 and gh.strike.__w > 50,
		gh and tostring(gh.tex.__tex))
	check("  its sound plays first, then the buff goes to Ready with Ready 1's own sound, as before", #played == 2 and played[1] == P("CDTL3 Tinks")
		and played[2] == P("CDTL3 Click") and pname(B.icon) == "CDTL3_Ready_1_MF", #played .. " played, " .. pname(B.icon))
	RunOnUpdate(0.1, 15)
	check("  the ghost is gone after 2 s", not gh:IsShown())
	leave()

	-- a cooldown made at login for a buff that isn't up never flashes: it was never gained or lost
	played = {}
	aura(false)
	CDTL3:SendToLane(B)
	RunOnUpdate(0.02, 60)
	local tinks = false
	for _, p in ipairs(played) do if p == P("CDTL3 Tinks") then tinks = true end end
	check("a buff that isn't up when its cooldown starts: no flash, no alert sound", not tinks and not lane.fxFlash:IsShown(), #played .. " played")
	leave()

	-- off per buff
	played = {}
	AURAS = { HELPFUL = { { name = "Quiet Buff", spellId = 942, duration = 10, expirationTime = NOW + 10, applications = 0, icon = 1 } }, HARMFUL = {} }
	CDTL3:OnPlayerAuraApplied(942, "Quiet Buff", "buffs", true)
	RunOnUpdate(0.02, 5)
	check("a buff without the alerts ticked: nothing", #played == 0 and not lane.fxFlash:IsShown())
	AURAS = { HELPFUL = {}, HARMFUL = {} }
	RunOnUpdate(0.02, 60)
	leave()

	-- not right after a login or a zone change
	FireEvent("PLAYER_ENTERING_WORLD", false, false)
	played = {}
	aura(true)
	CDTL3:SendToLane(B)
	RunOnUpdate(0.02, 5)
	check("a buff already up as the world loads (a reload) isn't a gain", #played == 0)
	aura(false)
	RunOnUpdate(0.02, 60)
	leave()
	Advance(9)

	-- Retail and Forever, auras hidden: only a Tracked Bars buff
	if RETAILAPI then
		local CT = CDTL3.CombatTimers
		local oldIn = CT.BuffInTrackedBars
		local tracked = false
		CT.BuffInTrackedBars = function() return tracked end
		SECRET_AURAS = true
		played = {}
		aura(true)
		CDTL3:SendToLane(B)
		RunOnUpdate(0.02, 5)
		check("auras hidden, buff not in Tracked Bars: no alert (an estimate would flash on a guess)", #played == 0 and not lane.fxFlash:IsShown())
		RunOnUpdate(0.1, 120)
		played = {}
		tracked = true
		aura(true)
		CDTL3:SendToLane(B)
		RunOnUpdate(0.02, 5)
		check("  in Tracked Bars: it flashes and plays", #played == 1 and lane.fxFlash:IsShown(), #played .. " played")
		SECRET_AURAS = false
		CT.BuffInTrackedBars = oldIn
		aura(false)
		RunOnUpdate(0.02, 60)
		leave()
	end
	AURAS = nil
end

---------------------------------------------------------------- fp22 burst window
print("[fp22 burst window " .. FLAVOR .. "]")
do
	l1.mode.type = "LINEAR_ABS"
	l1.mode.linearAbs.max = 120
	l1.fx.burst.enabled = true
	l1.fx.burst.secs = 25
	CDTL3:RefreshLane(1)
	local z = lane.fxBurst
	check("shaded window on a Linear (Time) lane: Ready to 25 s, 25/120 of the travel plus the icon", z and z:IsShown() and near(z.__w, (400 - 40) * 25 / 120 + 40, 0.01),
		z and tostring(z.__w))
	check("  tagged Burst 25s", z and z.tag.__text == "Burst 25s", z and tostring(z.tag.__text))
	check("  striped: a dark base and the tiled stripe texture in the zone's colour (gold)", z and z.base and z.fill.__tex and tostring(z.fill.__tex):find("Media\\zone-stripes.tga", 1, true) ~= nil
		and z.fill.__vertex and near(z.fill.__vertex[1], 1, 0.001) and near(z.fill.__vertex[2], 0.82, 0.001) and z.fill.__vertex[4] == 1, z and tostring(z.fill.__tex))
	check("  the Ready-by list is not on unless asked for", lane.fxList == nil)

	l1.fx.burst.secs = 60
	CDTL3:RefreshLane(1)
	check("  60 s: half the travel", near(z.__w, (400 - 40) * 0.5 + 40, 0.01) and z.tag.__text == "Burst 60s", tostring(z.__w))
	l1.fx.burst.secs = 25

	l1.mode.type = "SPLIT_ABS"
	CDTL3:RefreshLane(1)
	check("  Split (Time) lane: 25 s sits where its icons do (between the 10 s and 30 s marks)", z:IsShown() and near(z.__w, (400 - 40) * 0.4375 + 40, 0.5), tostring(z.__w))
	l1.mode.type = "LINEAR"
	CDTL3:RefreshLane(1)
	check("  a percent lane has no seconds to shade: hidden", not z:IsShown())
	l1.mode.type = "LINEAR_ABS"
	l1.fx.burst.shaded = false
	CDTL3:RefreshLane(1)
	check("  Shaded window unticked: hidden", not z:IsShown())
	l1.fx.burst.shaded = true
	CDTL3:RefreshLane(1)
	l1.reversed = true
	CDTL3:RefreshLane(1)
	check("  a reversed lane shades from its right end", z.__points[1][1] == "TOPRIGHT", z.__points[1] and z.__points[1][1])
	l1.reversed = false
	CDTL3:RefreshLane(1)

	-- the Ready-by list
	l1.fx.burst.list = true
	CDTL3:RefreshLane(1)
	local lf = lane.fxList
	check("Ready-by list ticked: a list under the lane, Shaded window still on (both can be)", lf and lf:IsShown() and z:IsShown() and lf.head.__text == "Burst in 25 s",
		lf and tostring(lf.head.__text))
	cast(933, 20)
	cast(934, 60)
	RunOnUpdate(0.02, 20)
	local r1, r2 = lf.row[1], lf.row[2]
	check("  pinned cooldowns, soonest first", r1.name.__text == "Pin A" and r2.name.__text == "Pin B" and not lf.row[3].name.__shown,
		tostring(r1.name.__text) .. ", " .. tostring(r2.name.__text))
	check("  a tick for the one back before 25 s, a cross for the one that isn't", r1.mark.__tex:find("ReadyCheck%-Ready") ~= nil and r2.mark.__tex:find("NotReady") ~= nil,
		tostring(r1.mark.__tex) .. " / " .. tostring(r2.mark.__tex))
	local A = live("Pin A")
	check("  each with its time", A.fxListTime and A.fxListTime.__shown and tonumber(A.fxListTime.__text) and tonumber(A.fxListTime.__text) <= 20, A.fxListTime and tostring(A.fxListTime.__text))
	local plain = live("Plain Spell")
	check("  an unpinned spell isn't listed", plain.fxListTime == nil)

	-- the time hidden in combat (a riding spell): the game's own timer in the row, no tick
	local bound = {}
	local oldDU = C_DurationUtil
	C_DurationUtil = { CreateDurationTextBinding = function()
		local b = {}
		function b:SetFontString(fs) b.fs = fs end
		function b:SetFormatter() end
		function b:SetDuration(d) b.dur = d end
		function b:SetEnabled(on) b.on = on end
		bound[#bound + 1] = b
		return b
	end }
	local B2 = live("Pin B")
	B2.ct = { riding = true, kind = "spell", dur = {} }
	lf.listAt = nil
	lane.__scripts.OnUpdate(lane, 0.02)
	check("  hidden time (riding): bound to the game's timer, no tick or cross", #bound == 1 and bound[1].fs == B2.fxListTime and bound[1].on == true and not r2.mark.__shown,
		#bound .. " bindings")
	B2.ct = nil
	C_DurationUtil = oldDU
	lf.listAt = nil
	lane.__scripts.OnUpdate(lane, 0.02)
	check("  not riding any more: the estimate and its cross again", r2.mark.__shown and r2.mark.__tex:find("NotReady") ~= nil)

	SPELLCD[933], SPELLCD[934] = nil, nil
	RunOnUpdate(0.02, 60)
	lf.listAt = nil
	lane.__scripts.OnUpdate(lane, 0.02)
	check("  a pinned one that is back reads ticked with no time", r1.mark.__tex:find("ReadyCheck%-Ready") ~= nil and r1.name.__text and (live("Pin A").fxListTime.__text == ""),
		tostring(live("Pin A").fxListTime.__text))
	l1.fx.burst.list = false
	CDTL3:RefreshLane(1)
	check("  unticked: the list goes", not lf:IsShown())
	l1.fx.burst.enabled = false
	CDTL3:RefreshLane(1)
	check("  Mark a burst window off: the shading goes too", not z:IsShown())
	l1.mode.type = "LINEAR"
	CDTL3:RefreshLane(1)
	leave()
end

---------------------------------------------------------------- fp23 refresh zone
print("[fp23 refresh zone " .. FLAVOR .. "]")
do
	local opts = CDTL3:GetLaneOptions().args.lane1.args.effects.args
	l1.fx.refresh.enabled = true
	l1.fx.refresh.pct = 30
	CDTL3:RefreshLane(1)
	if RETAILAPI then
		check("Retail and Forever can't see debuffs on enemies: no zone drawn", lane.fxRefresh == nil or not lane.fxRefresh:IsShown())
		check("  and its options are hidden", opts.refreshEnabled.hidden() == true and opts.refreshPct.hidden() == true and opts.refreshHeader.hidden() == true)
	else
		local z = lane.fxRefresh
		check("refresh zone on a Linear (%) lane: the last 30%, plus the icon", z and z:IsShown() and near(z.__w, (400 - 40) * 0.3 + 40, 0.01), z and tostring(z.__w))
		check("  its options are shown", not opts.refreshEnabled.hidden() and not opts.refreshPct.hidden())
		l1.fx.refresh.pct = 50
		CDTL3:RefreshLane(1)
		check("  50%: half the travel", near(z.__w, (400 - 40) * 0.5 + 40, 0.01))
		l1.mode.type = "LINEAR_ABS"
		CDTL3:RefreshLane(1)
		check("  not on a Time lane", not z:IsShown())
		l1.mode.type = "LINEAR"
		l1.fx.refresh.enabled = false
		CDTL3:RefreshLane(1)
		check("  off: gone", not z:IsShown())
	end
	l1.fx.refresh.enabled = false
	l1.fx.refresh.pct = 30
	CDTL3:RefreshLane(1)
end

---------------------------------------------------------------- fp25 ready-soon pulse
print("[fp25 ready-soon pulse " .. FLAVOR .. "]")
do
	played = {}
	cast(932, 12)
	RunOnUpdate(0.02, 5)
	local F = live("Warn Spell")
	check("Warn 5 s before ready, 12 s left: no pulse yet", F.icon.fxPulse == nil or not F.icon.fxPulse:IsShown())
	SPELLCD[932].startTime = NOW - 8   -- 4 s left
	RunOnUpdate(0.02, 55)
	local p = F.icon.fxPulse
	check("  4 s left: the icon pulses (orange border, once a second)", p and p:IsShown() and F.icon.fxPulseOn == true,
		p and tostring(p:IsShown()))
	local sc
	for _, o in ipairs(GetAllFrames()) do
		if p and p.sg and rawget(o, "__parent") == p.sg then sc = o end
	end
	check("  and the icon itself scales up to about 1.07 at the peak, on the same beat", p and p.sg and p.sg.__playing == true and sc and sc.__scaleTo == 1.07, sc and tostring(sc.__scaleTo))
	check("  its sound plays once as it starts", #played == 1 and played[1] == P("CDTL3 Tinks"), #played .. " played")
	RunOnUpdate(0.02, 60)
	check("  and not again while it keeps pulsing", #played == 1)
	SPELLCD[932] = nil
	RunOnUpdate(0.02, 60)
	check("  ready: the pulse stops (it is the lane's)", pname(F.icon) == "CDTL3_Ready_1_MF" and not p:IsShown() and not F.icon.fxPulseOn)
	check("  and the scale stops with it", p.sg.__playing == false)
	leave()

	-- the Filters control, live
	local fa = CDTL3:GetFilterOptions().args.spells.args
	CDTL3.currentFilter["spells"] = "Plain Spell"
	CDTL3.currentFilterHidden["spells"] = false
	local e = CDTL3:GetSpellSettings("Plain Spell", "spells")
	check("Filters: Warn before ready is there, 0 (off) by default, with a tooltip", fa.warnSecs and fa.warnSecs.get({}) == 0 and fa.warnSecs.desc ~= "")
	check("  its sound is hidden until a time is set", fa.warnSound.hidden({}) == true)
	local PL = live("Plain Spell")
	fa.warnSecs.set({}, 6)
	check("  set to 6: saved on the entry and on the live icon", e.warnSecs == 6 and PL.data.warnSecs == 6 and fa.warnSound.hidden({}) == false and fa.warnSound.get({}) == "None")
	fa.warnSecs.set({}, 0)
	check("  back to 0: cleared", e.warnSecs == nil and PL.data.warnSecs == nil)
	check("  the buff-only controls aren't on a spell", fa.alertGain == nil and fa.alertEnd == nil)
	local ba = CDTL3:GetFilterOptions().args.buffs.args
	CDTL3.currentFilter["buffs"] = "Alert Buff"
	CDTL3.currentFilterHidden["buffs"] = false
	local be = CDTL3:GetSpellSettings("Alert Buff", "buffs")
	check("Filters (buff): Alert when gained / ends, with their sounds shown once ticked", ba.alertGain and ba.alertEnd and ba.alertGain.get({}) == true
		and ba.gainSound.hidden({}) == false and ba.gainSound.get({}) == "CDTL3 Click" and ba.endSound.get({}) == "CDTL3 Tinks")
	ba.alertGain.set({}, false)
	check("  unticking Gained: saved and live, its sound hidden", be.alertGain == false and live("Alert Buff", "buffs").data.alertGain == false and ba.gainSound.hidden({}) == true)
	ba.alertGain.set({}, true)
	ba.gainSound.set({}, "CDTL3 Rattle")
	check("  a picked sound is kept", be.gainSound == "CDTL3 Rattle" and live("Alert Buff", "buffs").data.gainSound == "CDTL3 Rattle")
	be.gainSound = nil
	live("Alert Buff", "buffs").data.gainSound = nil
end

---------------------------------------------------------------- fp26 GCD waits
print("[fp26 GCD waits " .. FLAVOR .. "]")
do
	local function gcd(on, dur)
		local t = on and { startTime = NOW, duration = dur or 2, isEnabled = true, isActive = true, modRate = 1, isOnGCD = true } or nil
		SPELLCD[935] = t
		SPELLCD[8921] = t
	end

	-- off by default: the tail rides the lane
	played = {}
	cast(935, 8)
	RunOnUpdate(0.02, 5)
	local F = live("Gcd Spell")
	gcd(true)
	RunOnUpdate(0.02, 55)
	check("GCD waits off: the GCD tail stays on the lane", pname(F.icon) == "CDTL3_Lane_1" and F.data.currentCD > 0, pname(F.icon))
	gcd(false)
	RunOnUpdate(0.02, 60)
	leave()
	played = {}

	l1.fx.gcdWait = true
	cast(935, 8)
	RunOnUpdate(0.02, 5)
	check("on: with its real cooldown running it rides the lane", pname(F.icon) == "CDTL3_Lane_1")
	gcd(true)
	RunOnUpdate(0.02, 55)
	local ic = F.icon
	check("only the GCD left: it goes straight to the Ready frame", pname(ic) == "CDTL3_Ready_1_MF" and ic.fxGCD == true, pname(ic))
	check("  under a GCD sweep", ic.fxSweep and ic.fxSweep:IsShown())
	check("  reading GCD where READY goes", ic.fxGCDText and ic.fxGCDText:IsShown() and ic.fxGCDText.__text == "GCD", ic.fxGCDText and tostring(ic.fxGCDText.__text))
	check("  with no ready sound", #played == 0, #played .. " played")
	local t0 = ic.readyTime
	RunOnUpdate(0.02, 20)
	check("  its Ready time waits for the GCD", ic.readyTime == t0, tostring(ic.readyTime) .. " vs " .. tostring(t0))
	gcd(false)
	RunOnUpdate(0.02, 60)
	check("GCD over: the label and sweep go, still in Ready, still silent", pname(ic) == "CDTL3_Ready_1_MF" and not ic.fxGCD and not ic.fxGCDText:IsShown()
		and not ic.fxSweep:IsShown() and #played == 0, pname(ic) .. " " .. #played)
	leave()
	check("  and it leaves Ready after its time", pname(ic) ~= "CDTL3_Ready_1_MF", pname(ic))

	-- the wait turns out to be a real cooldown (cast again, or not the GCD): back to its lane with its time
	cast(935, 8)
	RunOnUpdate(0.02, 5)
	gcd(true)
	RunOnUpdate(0.02, 55)
	check("another GCD tail: in Ready again", pname(ic) == "CDTL3_Ready_1_MF" and ic.fxGCD == true)
	SPELLCD[8921] = nil
	SPELLCD[935] = { startTime = NOW, duration = 6, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	RunOnUpdate(0.02, 60)
	check("it was a real cooldown: back on its lane, wait over", pname(ic) == "CDTL3_Lane_1" and not ic.fxGCD and F.data.currentCD > 0, pname(ic))
	SPELLCD[935] = nil
	RunOnUpdate(0.02, 60)
	leave()

	-- a spell whose Ready frame is Hide has nowhere to wait: it stays
	local e = CDTL3:GetSpellSettings("Gcd Spell", "spells")
	F.data.readyFrame = 0
	cast(935, 8)
	RunOnUpdate(0.02, 5)
	gcd(true)
	RunOnUpdate(0.02, 55)
	check("Ready frame Hide: it stays on the lane", pname(ic) == "CDTL3_Lane_1" and not ic.fxGCD, pname(ic))
	gcd(false)
	RunOnUpdate(0.02, 60)
	leave()
	F.data.readyFrame = e.readyFrame
	l1.fx.gcdWait = false
end

---------------------------------------------------------------- options
print("[effects options " .. FLAVOR .. "]")
do
	local opts = CDTL3:GetLaneOptions().args.lane1.args.effects
	local a = opts.args
	check("Lanes > Lane 1 has an Effects tab", opts.type == "group" and opts.name == "Effects")
	check("  every control has a name and a tooltip", a.chargePips.desc ~= "" and a.gcdWait.desc ~= "" and a.burstEnabled.desc ~= "" and a.burstShaded.desc ~= ""
		and a.burstList.desc ~= "" and a.burstSecs.desc ~= "" and a.refreshEnabled.desc ~= "")
	check("  all off by default, Shaded window the default look", a.chargePips.get({}) == false and a.gcdWait.get({}) == false and a.burstEnabled.get({}) == false
		and a.burstShaded.get({}) == true and a.burstList.get({}) == false)
	check("  burst controls greyed out until Mark a burst window", a.burstSecs.disabled() == true and a.burstShaded.disabled() == true and a.burstList.disabled() == true)
	a.burstEnabled.set({}, true)
	a.burstSecs.set({}, 90)
	a.burstList.set({}, true)
	check("  ticked: they wake, the values are saved", a.burstSecs.disabled() == false and l1.fx.burst.secs == 90 and l1.fx.burst.list == true and l1.fx.burst.shaded == true)
	check("  Burst in reaches 1 to 3600 seconds", a.burstSecs.min == 1 and a.burstSecs.max == 3600)
	a.burstEnabled.set({}, false)
	a.burstList.set({}, false)
	a.burstSecs.set({}, 25)
	a.chargePips.set({}, true)
	a.gcdWait.set({}, true)
	check("  Charge pips and GCD waits save", l1.fx.chargePips == true and l1.fx.gcdWait == true)
	a.chargePips.set({}, false)
	a.gcdWait.set({}, false)
	local a3 = CDTL3:GetLaneOptions().args.lane3.args.effects.args
	a3.chargePips.set({}, true)
	check("  each lane has its own", CDTL3.db.profile.lanes["lane3"].fx.chargePips == true and l1.fx.chargePips == false)
	a3.chargePips.set({}, false)
end

print(string.format("RESULT r4icons %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
