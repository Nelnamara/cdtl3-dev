-- Red team of 12 Nov, cooldown and Ready frame fixes (cards 7, 8, 12, 15, 21, 23): a switched-off
-- lane keeps its cooldowns' bars, an early reset of a hidden long cooldown shows in Ready, Highlight
-- Duration, Pinned Hide Time (only while the frame holds pinned icons alone), a switched-off Ready
-- frame takes nothing, and a new item shows nothing
-- while its cooldown is hidden. Real files, real AceDB.
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
mt.__index = function(t, k)
	if k == "GetChildren" then return kids end
	return oldIndex(t, k)
end

local function entry(id, name, extra)
	local e = { id = id, name = name, type = "spells", icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local SPELLS = {
	[901] = { "Long Spell", { bCD = 300000 } },
	[902] = { "Short Spell", { bCD = 60000 } },
	[903] = { "Lit Spell", { bCD = 30000, highlight = true } },
	[904] = { "Pin Spell", { bCD = 20000, pinned = true } },
	[905] = { "Lane2 Spell", { bCD = 300000, lane = 2, barFrame = 2, readyFrame = 2 } },
	[906] = { "Lane3 Spell", { bCD = 300000, lane = 3, barFrame = 3, readyFrame = 3 } },
}
local list = {}
for id, s in pairs(SPELLS) do
	list[#list + 1] = entry(id, s[1], s[2])
	SPELLINFO[id] = { s[1], 1 }
	KNOWN[id] = true
end
-- lane 2 switched off before login
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = { tables = { spells = list },
	lanes = { lane2 = { enabled = false } } } } }

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
local sounds = 0
PlaySoundFile = function() sounds = sounds + 1; return true end
local function cast(id, dur)
	SPELLCD[id] = { startTime = NOW, duration = dur, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id, id)
end
local function reset(id) SPELLCD[id] = nil end
local function live(name) return CDTL3:GetExistingCooldown(name, "spells") end
local function pname(fr) local p = fr:GetParent(); return p and p:GetName() or "nil" end
-- the stub's fade animations do nothing: finish them at once
local function instantFades(fr)
	if fr.animateOut then fr.animateOut.Play = function() fr:SetAlpha(0) end end
	if fr.animateIn then fr.animateIn.Play = function() fr:SetAlpha(1) end end
end
for _, fr in ipairs({ CDTL3_Lane_1, CDTL3_Lane_3, CDTL3_Ready_1, CDTL3_Ready_2, CDTL3_Ready_3 }) do
	instantFades(fr)
end
local r1 = CDTL3.db.profile.ready["ready1"]

---------------------------------------------------------------- card 7: switched-off lane keeps its bars
print("[7 switched-off lane " .. FLAVOR .. "]")
check("lane 2 off at login: never created", CDTL3_Lane_2 == nil)
cast(905, 300)
RunOnUpdate(0.02, 10)
local f5 = live("Lane2 Spell")
check("lane 2 off: icon parked in holding, bar in bar frame 2", f5 and pname(f5.icon) == "CDTL3_Active_Icon_Holding" and pname(f5.bar) == "CDTL3_BarFrame_2_MF",
	f5 and (pname(f5.icon) .. " / " .. pname(f5.bar)))
SPELLCD[905].startTime = NOW - 200   -- 100 s left, under lane 2's Max Time (120)
RunOnUpdate(0.02, 60)
check("lane 2 off, 100 s left, Transition bars on: the bar keeps showing", f5.bar.valid == true and f5.bar:GetAlpha() == 1,
	string.format("valid=%s alpha=%s cd=%.1f", tostring(f5.bar.valid), tostring(f5.bar:GetAlpha()), f5.data.currentCD))
-- the transition indicator marks where a bar hands off to its lane; a bar whose lane is off never
-- does, so it has no line (it used to sit at Max Time / cooldown x bar width, past the bar's end
-- when the lane held more than the whole cooldown, out over other frames: walk 14 Nov)
local function ti(cd) return cd.bar.bar and cd.bar.bar.ti end
local function barWidth(cd)
	local bs = CDTL3.db.profile.barFrames["frame" .. cd.data.barFrame]
	return bs.width - bs.transition.width - (bs.bar.iconEnabled and bs.height or 0)
end
CDTL3:RefreshAllBars()
check("  its transition indicator is hidden (lane off: no hand-off to mark)", ti(f5) and ti(f5):GetAlpha() == 0,
	ti(f5) and ("alpha " .. tostring(ti(f5):GetAlpha())) or "no indicator")
-- an enabled lane still takes its cooldowns over (control), and switching it off mid-session gives the bar back
local l3 = CDTL3.db.profile.lanes["lane3"]
cast(906, 300)
RunOnUpdate(0.02, 10)
local f6 = live("Lane3 Spell")
SPELLCD[906].startTime = NOW - 200
RunOnUpdate(0.02, 60)
check("lane 3 on, 100 s left: bar handed over to the lane (hidden), icon on lane 3",
	f6.bar.valid == false and f6.bar:GetAlpha() == 0 and pname(f6.icon) == "CDTL3_Lane_3" and f6.icon:GetAlpha() == 1,
	string.format("bar valid=%s alpha=%s icon %s", tostring(f6.bar.valid), tostring(f6.bar:GetAlpha()), pname(f6.icon)))
do
	CDTL3:RefreshAllBars()
	local x = ti(f6) and select(2, ti(f6):GetPoint(1))
	local want = (l3.mode.linear.max / 300) * barWidth(f6)
	check("  lane 3 on, 300 s cooldown: its indicator shows inside the bar, at Max Time / 300 of it",
		ti(f6) and ti(f6):GetAlpha() == 1 and type(x) == "number" and math.abs(x - want) < 0.01 and x <= barWidth(f6),
		string.format("x=%s want=%.2f bar=%.1f", tostring(x), want, barWidth(f6)))
	-- a cooldown shorter than its lane's Max Time never shows a bar on an enabled lane: no line either
	local base = f6.data.baseCD
	f6.data.baseCD = 60
	CDTL3:RefreshAllBars()
	local x2 = select(2, ti(f6):GetPoint(1))
	check("  a 60 s cooldown on a 120 s lane: no indicator, and none past the bar's end", ti(f6):GetAlpha() == 0 and x2 <= barWidth(f6),
		string.format("alpha=%s x=%s bar=%.1f", tostring(ti(f6):GetAlpha()), tostring(x2), barWidth(f6)))
	f6.data.baseCD = base
	CDTL3:RefreshAllBars()
end
l3.enabled = false
CDTL3:RefreshLane(3)   -- what Lanes › Lane 3 › Enabled does
RunOnUpdate(0.02, 10)
check("lane 3 switched off mid-session: its bar shows again at once", f6.bar.valid == true and f6.bar:GetAlpha() == 1,
	string.format("valid=%s alpha=%s", tostring(f6.bar.valid), tostring(f6.bar:GetAlpha())))
l3.enabled = true
CDTL3:CreateLanes()
CDTL3:RefreshLane(3)
RunOnUpdate(0.02, 10)
check("lane 3 back on: the bar hands over to the lane again", f6.bar.valid == false and f6.bar:GetAlpha() == 0,
	string.format("valid=%s alpha=%s", tostring(f6.bar.valid), tostring(f6.bar:GetAlpha())))
reset(905); reset(906)
RunOnUpdate(0.1, 120)

---------------------------------------------------------------- card 8: early reset of a hidden long cooldown
print("[8 early reset of a long cooldown " .. FLAVOR .. "]")
sounds = 0
cast(901, 300)
RunOnUpdate(0.02, 100)
local L = live("Long Spell")
check("300 s cooldown on lane 1, hidden over Max Time (120)", L and pname(L.icon) == "CDTL3_Lane_1" and L.icon.valid == false and L.icon:GetAlpha() == 0,
	L and string.format("valid=%s alpha=%s", tostring(L.icon.valid), tostring(L.icon:GetAlpha())))
reset(901)   -- Cold Snap, Preparation, Readiness: the game says ready now
RunOnUpdate(0.02, 60)
check("after the reset: icon in Ready 1, one ready sound", pname(L.icon) == "CDTL3_Ready_1_MF" and sounds == 1, pname(L.icon) .. " sounds=" .. sounds)
check("the Ready icon shows (valid, alpha 1, counted by Ready 1)", L.icon.valid == true and L.icon:GetAlpha() == 1 and CDTL3_Ready_1.childCount == 1,
	string.format("valid=%s alpha=%s count=%d", tostring(L.icon.valid), tostring(L.icon:GetAlpha()), CDTL3_Ready_1.childCount))
RunOnUpdate(0.1, 80)
check("it leaves Ready after the Normal Duration", pname(L.icon) ~= "CDTL3_Ready_1_MF", pname(L.icon))

---------------------------------------------------------------- card 15: Highlight Duration
print("[15 Highlight Duration " .. FLAVOR .. "]")
r1.nTime, r1.hTime = 5, 15
cast(903, 30)
RunOnUpdate(0.02, 5)
local H = live("Lit Spell")
reset(903)
RunOnUpdate(0.02, 55)   -- the next 50-frame poll sees it ready
check("highlighted icon in Ready 1 with the Highlight Duration (15 s)", pname(H.icon) == "CDTL3_Ready_1_MF" and H.icon.readyTime > 14,
	string.format("%s readyTime=%.2f", pname(H.icon), H.icon.readyTime))
cast(902, 60)
RunOnUpdate(0.02, 5)
local S = live("Short Spell")
reset(902)
RunOnUpdate(0.02, 55)
check("plain icon gets the Normal Duration (5 s)", pname(S.icon) == "CDTL3_Ready_1_MF" and S.icon.readyTime > 4 and S.icon.readyTime <= 5,
	string.format("readyTime=%.2f", S.icon.readyTime))
RunOnUpdate(0.1, 80)   -- 8 s
check("8 s later: plain icon gone, highlighted one still in Ready 1", pname(S.icon) ~= "CDTL3_Ready_1_MF" and pname(H.icon) == "CDTL3_Ready_1_MF",
	pname(S.icon) .. " / " .. pname(H.icon))
RunOnUpdate(0.1, 80)   -- 16 s
check("16 s later: highlighted icon gone too", pname(H.icon) ~= "CDTL3_Ready_1_MF", pname(H.icon))
r1.nTime, r1.hTime = 5, 10

---------------------------------------------------------------- card 21: Pinned Hide Time
print("[21 Pinned Hide Time " .. FLAVOR .. "]")
g["autohide"] = true
r1.pTime = 3
CDTL3:RefreshReady(1); instantFades(CDTL3_Ready_1)
CDTL3.combat = false
cast(904, 20)
RunOnUpdate(0.02, 5)
local P = live("Pin Spell")
reset(904)
RunOnUpdate(0.02, 55)
check("pinned icon in Ready 1, frame showing", pname(P.icon) == "CDTL3_Ready_1_MF" and CDTL3_Ready_1:GetAlpha() ~= 0,
	string.format("%s alpha=%s", pname(P.icon), tostring(CDTL3_Ready_1:GetAlpha())))
RunOnUpdate(0.1, 20)   -- 2 s: under pTime
check("2 s out of combat (pTime 3): still showing", CDTL3_Ready_1:GetAlpha() ~= 0)
RunOnUpdate(0.1, 30)   -- 5 s
check("5 s out of combat: Ready 1 hidden, the pinned icon still in it", CDTL3_Ready_1:GetAlpha() == 0 and pname(P.icon) == "CDTL3_Ready_1_MF",
	string.format("alpha=%s timer=%.1f", tostring(CDTL3_Ready_1:GetAlpha()), CDTL3_Ready_1.combatTimer))
FireEvent("PLAYER_REGEN_DISABLED")
RunOnUpdate(0.02, 5)
check("pull: Ready 1 shows the pinned icon again", CDTL3.combat and CDTL3_Ready_1:GetAlpha() ~= 0, tostring(CDTL3_Ready_1:GetAlpha()))
RunOnUpdate(0.1, 50)
check("in combat: stays", CDTL3_Ready_1:GetAlpha() ~= 0)
FireEvent("PLAYER_REGEN_ENABLED")
RunOnUpdate(0.1, 20)
check("2 s after combat: still showing", CDTL3_Ready_1:GetAlpha() ~= 0)
RunOnUpdate(0.1, 20)
check("4 s after combat: hidden again", CDTL3_Ready_1:GetAlpha() == 0)
-- Pinned Hide Time hides only a frame holding pinned icons alone: an icon with Normal Duration left
-- keeps it showing (Normal Duration 15, Pinned Hide Time 10)
print("[21 Pinned Hide Time, unpinned icons " .. FLAVOR .. "]")
P.data.pinned = false
RunOnUpdate(0.1, 80)   -- the unpinned P counts its Normal Duration (5 s) and leaves
r1.nTime, r1.pTime = 15, 10
cast(902, 60)
RunOnUpdate(0.02, 5)
reset(902)
RunOnUpdate(0.02, 55)
check("plain icon in Ready 1 (Normal Duration 15), frame showing", pname(S.icon) == "CDTL3_Ready_1_MF" and CDTL3_Ready_1:GetAlpha() ~= 0,
	string.format("%s alpha=%s", pname(S.icon), tostring(CDTL3_Ready_1:GetAlpha())))
RunOnUpdate(0.1, 110)   -- ~12 s: past Pinned Hide Time, ~3 s of Normal Duration left
check("~12 s: past Pinned Hide Time, the icon has time left: still showing", pname(S.icon) == "CDTL3_Ready_1_MF" and CDTL3_Ready_1:GetAlpha() ~= 0,
	string.format("%s readyTime=%.1f alpha=%s", pname(S.icon), S.icon.readyTime or -1, tostring(CDTL3_Ready_1:GetAlpha())))
RunOnUpdate(0.1, 50)   -- ~17 s
check("~17 s: Normal Duration over, icon gone, empty frame hidden", pname(S.icon) ~= "CDTL3_Ready_1_MF" and CDTL3_Ready_1:GetAlpha() == 0,
	string.format("%s alpha=%s", pname(S.icon), tostring(CDTL3_Ready_1:GetAlpha())))
-- a pinned and a plain icon together: the frame stays while the plain one has time, then hides with
-- only the pinned one left
r1.pTime = 3
P.data.pinned = true
cast(904, 20); cast(902, 60)
RunOnUpdate(0.02, 5)
reset(904); reset(902)
RunOnUpdate(0.02, 55)
check("pinned + plain in Ready 1, showing", pname(P.icon) == "CDTL3_Ready_1_MF" and pname(S.icon) == "CDTL3_Ready_1_MF" and CDTL3_Ready_1:GetAlpha() ~= 0)
RunOnUpdate(0.1, 60)   -- ~7 s: past Pinned Hide Time 3, the plain icon has ~8 s left
check("~7 s: the plain icon has time left: still showing", pname(S.icon) == "CDTL3_Ready_1_MF" and CDTL3_Ready_1:GetAlpha() ~= 0,
	string.format("alpha=%s", tostring(CDTL3_Ready_1:GetAlpha())))
RunOnUpdate(0.1, 100)  -- ~17 s
check("~17 s: only the pinned icon left: hidden, the pinned icon still in it", pname(S.icon) ~= "CDTL3_Ready_1_MF" and pname(P.icon) == "CDTL3_Ready_1_MF"
	and CDTL3_Ready_1:GetAlpha() == 0, string.format("%s / %s alpha=%s", pname(P.icon), pname(S.icon), tostring(CDTL3_Ready_1:GetAlpha())))
r1.nTime = 5
g["autohide"] = false
CDTL3:RefreshReady(1); instantFades(CDTL3_Ready_1)
P.data.pinned = false
RunOnUpdate(0.1, 80)
check("Auto-hide off again: Ready 1 back to its alpha", CDTL3_Ready_1:GetAlpha() == 1)

---------------------------------------------------------------- card 23: switched-off Ready frame
print("[23 Ready frame switched off " .. FLAVOR .. "]")
r1.enabled = false
CDTL3:RefreshReady(1)   -- what Ready › Ready 1 › Enabled does
sounds = 0
cast(902, 60)
RunOnUpdate(0.02, 5)
reset(902)
RunOnUpdate(0.02, 55)
check("Ready 1 off: no ready sound", sounds == 0, "sounds=" .. sounds)
check("Ready 1 off: the icon goes to holding, not into the hidden frame", pname(S.icon) == "CDTL3_Active_Icon_Holding", pname(S.icon))
r1.enabled = true
CDTL3:CreateReadyFrames()
CDTL3:RefreshReady(1)
cast(902, 60)
RunOnUpdate(0.02, 5)
reset(902)
RunOnUpdate(0.02, 55)
check("Ready 1 on again: icon in Ready 1, one sound", pname(S.icon) == "CDTL3_Ready_1_MF" and sounds == 1, pname(S.icon) .. " sounds=" .. sounds)
RunOnUpdate(0.1, 80)

---------------------------------------------------------------- card 12: new item while its cooldown is hidden
print("[12 new item, hidden cooldown " .. FLAVOR .. "]")
if RETAILAPI then
	g["items"]["ignoreThreshold"] = 600
	GetInventoryItemID = function(_, slot) if slot == 13 then return 5001 elseif slot == 14 then return 5002 end end
	ITEMSPELL = { [5001] = { "Use Trinket", 99001 }, [5002] = { "Use Potion", 99002 } }
	SPELLINFO[99001] = { "Use Trinket", 1 }
	SPELLINFO[99002] = { "Use Potion", 1 }
	ITEMCD = { [5001] = { SECRET, SECRET }, [5002] = { SECRET, SECRET } }
	sounds = 0
	local usedAt = NOW
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-i", 99001)
	local it = CDTL3:GetExistingCooldown("Use Trinket", "items")
	RunOnUpdate(0.02, 150)   -- 3 s, still hidden
	check("first use, cooldown hidden: a frame exists, nothing learned", it ~= nil and it.data.baseCD == 0)
	check("hidden: no icon (not valid, alpha 0)", it.icon.valid == false and it.icon:GetAlpha() == 0,
		string.format("%s valid=%s alpha=%s", pname(it.icon), tostring(it.icon.valid), tostring(it.icon:GetAlpha())))
	check("hidden: no bar (not valid, alpha 0), so no made-up 16:40", it.bar.valid == false and it.bar:GetAlpha() == 0,
		string.format("%s valid=%s alpha=%s", pname(it.bar), tostring(it.bar.valid), tostring(it.bar:GetAlpha())))
	check("hidden: not sent to Ready, no sound", pname(it.icon) == "CDTL3_Lane_1" and sounds == 0, pname(it.icon) .. " sounds=" .. sounds)
	-- readable again (combat over) while it's still cooling: learns and shows the real time
	ITEMCD[5001] = { usedAt, 60 }
	RunOnUpdate(0.02, 55)
	check("readable: learns 60 s and shows on its lane", it.data.baseCD == 60 and it.icon.valid == true and it.icon:GetAlpha() == 1
		and math.abs(it.data.currentCD - (usedAt + 60 - NOW)) < 0.1,
		string.format("baseCD=%s valid=%s alpha=%s cd=%.1f", tostring(it.data.baseCD), tostring(it.icon.valid), tostring(it.icon:GetAlpha()), it.data.currentCD))
	-- a cooldown that stays hidden until it has run out: Ready once readable, and the Ready icon shows
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-p", 99002)
	local pot = CDTL3:GetExistingCooldown("Use Potion", "items")
	RunOnUpdate(0.02, 100)
	check("second item hidden: no icon, no bar", pot and pot.icon:GetAlpha() == 0 and pot.bar:GetAlpha() == 0 and pot.data.itemUnread == true)
	sounds = 0
	ITEMCD[5002] = { 0, 0 }
	RunOnUpdate(0.02, 60)
	check("readable 0 after the window: nothing learned, in Ready 1 and showing", pot.data.baseCD == 0 and pname(pot.icon) == "CDTL3_Ready_1_MF"
		and pot.icon:GetAlpha() == 1 and sounds == 1,
		string.format("%s alpha=%s sounds=%d", pname(pot.icon), tostring(pot.icon:GetAlpha()), sounds))
else
	print("  (no hidden item cooldowns on this client: covered by cooldown3's item cases)")
end

print(string.format("RESULT rtengine %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
