-- Card 33: timer types from other addons (CDTL3:RegisterTimerType / StartTimer / StopTimer, API.lua).
-- Real files, real AceDB; the listener is a plain AceEvent object, as another addon would be.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"

CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {} } }

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
if g["unlockFrames"] then CDTL3:ToggleFrameLock(true) end
PlaySoundFile = function() return true end
for _, fr in ipairs({ CDTL3_Lane_1, CDTL3_Lane_2, CDTL3_Lane_3, CDTL3_Ready_1, CDTL3_Ready_2, CDTL3_Ready_3 }) do
	if fr then
		if fr.animateOut then fr.animateOut.Play = function() fr:SetAlpha(0) end end
		if fr.animateIn then fr.animateIn.Play = function() fr:SetAlpha(1) end end
	end
end
local function pname(x) return x:GetParent():GetName() end
local function live(name) return CDTL3:GetExistingCooldown(name, "groupcd") end
local function near(a, b, tol) return type(a) == "number" and math.abs(a - b) <= (tol or 0.05) end

local L = {}
LibStub("AceEvent-3.0"):Embed(L)
local got = { Started = {}, Ready = {}, Ended = {} }
for _, k in ipairs({ "Started", "Ready", "Ended" }) do
	L:RegisterMessage("CDTL3_Timer" .. k, function(msg, data) got[k][#got[k] + 1] = data end)
end
local function count(list, id) local n = 0 for _, d in ipairs(list) do if d.id == id then n = n + 1 end end return n end

print("[timer types " .. FLAVOR .. "]")

---------------------------------------------------------------- unknown key, before anything is registered
local e0 = #ERRORS
check("an unknown key: StartTimer and StopTimer refuse, no error", CDTL3:StartTimer("groupcd", "x", { duration = 30 }) == false
	and CDTL3:StopTimer("groupcd", "x") == false and #ERRORS == e0)

---------------------------------------------------------------- register
check("RegisterTimerType returns true", CDTL3:RegisterTimerType("GroupCD", { name = "Group cooldowns", icon = 1234 }) == true)
check("  twice is harmless, and updates the name", CDTL3:RegisterTimerType("groupcd", { name = "Group cooldowns", icon = 1234 }) == true
	and CDTL3.timerTypes.groupcd and CDTL3.timerTypes.groupcd.name == "Group cooldowns" and CDTL3.timerTypes.groupcd.icon == 1234)
check("  keys are case-insensitive: one type", (function() local n = 0 for _ in pairs(CDTL3.timerTypes) do n = n + 1 end return n == 1 end)())
check("  a key the addon uses itself is refused", CDTL3:RegisterTimerType("spells", { name = "x" }) == false and CDTL3.timerTypes.spells == nil)
check("  bad arguments are refused, no error", CDTL3:RegisterTimerType(nil, {}) == false and CDTL3:RegisterTimerType("zz", nil) == false and #ERRORS == e0)
local gs = g["groupcd"]
check("  it gets Defaults: Enabled, lane 1, bar frame 1, Ready frame 1", gs and gs.enabled == true and gs.defaultLane == 1 and gs.defaultBar == 1 and gs.defaultReady == 1)

---------------------------------------------------------------- Filters > Defaults section
local defaults = CDTL3:GetFilterOptions().args.defaults.args
local values = defaults.list.values({})
check("Filters > Defaults lists it by name", values["GROUPCD"] == "Group cooldowns" and values["SPELLS"] == "Spells")
local savedSel = CDTL3.currentFilter["default"]
CDTL3.currentFilter["default"] = "GROUPCD"
CDTL3.currentFilterHidden["default"] = false
check("  Enabled, Default Lane, Default Bar and Default Ready read and write its settings", defaults.enabled.get({}) == true
	and defaults.defaultLane.get({}) == 1 and defaults.defaultBar.get({}) == 1 and defaults.defaultReady.get({}) == 1)
defaults.defaultLane.set({}, 2); defaults.defaultBar.set({}, 2); defaults.defaultReady.set({}, 2)
check("  the setters save", g.groupcd.defaultLane == 2 and g.groupcd.defaultBar == 2 and g.groupcd.defaultReady == 2)
defaults.defaultLane.set({}, 1); defaults.defaultBar.set({}, 1); defaults.defaultReady.set({}, 1)
check("  the controls that need a saved list are hidden for it, the others not", defaults.ignoreThreshold.hidden({}) == true
	and defaults.clearAll.hidden({}) == true and defaults.setDefaultLane.hidden({}) == true and not defaults.defaultLane.hidden({}))
CDTL3.currentFilter["default"] = "SPELLS"
check("  and still shown for Spells", not defaults.ignoreThreshold.hidden({}) and not defaults.setDefaultLane.hidden({}))
CDTL3.currentFilter["default"] = savedSel

---------------------------------------------------------------- start, countdown
local t0 = NOW
check("StartTimer returns true", CDTL3:StartTimer("groupcd", "Tania-Realm:Rebirth", { name = "Rebirth", icon = 136080, duration = 60,
	startedAt = NOW - 10, owner = "Tania-Realm", class = "DRUID" }) == true)
local f = live("Rebirth")
check("it is a live cooldown of the type, on lane 1 and bar frame 1", f and f.data.type == "groupcd" and pname(f.icon) == "CDTL3_Lane_1"
	and pname(f.bar) == "CDTL3_BarFrame_1_MF", f and (pname(f.icon) .. " " .. pname(f.bar)))
check("  counting down from startedAt + duration (50 s left, not 60)", f and near(f.data.currentCD, 50), f and tostring(f.data.currentCD))
check("  name, icon, owner and class kept", f and f.data.name == "Rebirth" and f.data.icon == 136080 and f.data.owner == "Tania-Realm" and f.data.class == "DRUID")
local s = got.Started[#got.Started]
check("Started message: type, id, name, a duration of 60 and an expiry 50 s away", s and s.type == "groupcd" and s.id == "Tania-Realm:Rebirth"
	and s.name == "Rebirth" and s.duration == 60 and near(s.expires, t0 + 50), s and tostring(s.expires))
check("  the owner's short name is a text tag", CDTL3:ConvertAllTextTags("[cd.owner]", f) == "Tania" and CDTL3:ConvertAllTextTags("[cd.owner]", { data = {} }) == "")
RunOnUpdate(0.1, 100)
check("  ten seconds later: 40 s left", near(f.data.currentCD, 40, 0.2), tostring(f.data.currentCD))
local tm = CDTL3.API.GetTimer("groupcd", "Tania-Realm:Rebirth")
check("  the API sees it as running", tm and tm.ready == false and tm.lane == 1 and near(tm.expires, NOW + 40, 0.2))

---------------------------------------------------------------- Ready at the right time
CDTL3:StartTimer("groupcd", 7, { name = "Short", duration = 5, startedAt = NOW })
local sh = live("Short")
RunOnUpdate(0.02, 240)	-- 4.8 s
check("4.8 s into a 5 s timer: still on the lane, no Ready", sh and pname(sh.icon) == "CDTL3_Lane_1" and count(got.Ready, 7) == 0, sh and pname(sh.icon))
RunOnUpdate(0.02, 20)	-- 5.2 s
check("5.2 s in: Ready sent once, the icon waits in Ready frame 1", count(got.Ready, 7) == 1 and pname(sh.icon) == "CDTL3_Ready_1_MF" and count(got.Ended, 7) == 0,
	pname(sh.icon) .. " ready=" .. count(got.Ready, 7))
RunOnUpdate(0.02, 1200)
check("  then Ended once, and the icon leaves", count(got.Ended, 7) == 1 and pname(sh.icon) == "CDTL3_Active_Icon_Holding" and count(got.Ready, 7) == 1,
	pname(sh.icon) .. " ended=" .. count(got.Ended, 7))
check("  the long timer is still counting", near(f.data.currentCD, 60 - 10 - (NOW - t0), 0.5) and pname(f.icon) == "CDTL3_Lane_1", tostring(f.data.currentCD))

---------------------------------------------------------------- stop
local nReady = #got.Ready
check("StopTimer returns true", CDTL3:StopTimer("groupcd", "Tania-Realm:Rebirth") == true)
check("  gone at once: off the lane and the bar frame, not counting", pname(f.icon) == "CDTL3_Active_Icon_Holding" and pname(f.bar) == "CDTL3_Bar_Holding"
	and CDTL3.API.IsReady("groupcd", "Tania-Realm:Rebirth") == true, pname(f.icon) .. " " .. pname(f.bar))
check("  no Ready, and Ended once", #got.Ready == nReady and count(got.Ended, "Tania-Realm:Rebirth") == 1)
RunOnUpdate(0.02, 100)
check("  it stays gone", pname(f.icon) == "CDTL3_Active_Icon_Holding" and #got.Ready == nReady)
check("  stopping it again, or an unknown id, is false and harmless", CDTL3:StopTimer("groupcd", "Tania-Realm:Rebirth") == true and CDTL3:StopTimer("groupcd", "nope") == false)

---------------------------------------------------------------- restart
local nFrames = #CDTL3.cooldowns
check("StartTimer on a stopped one restarts it on the same frame", CDTL3:StartTimer("groupcd", "Tania-Realm:Rebirth", { name = "Rebirth", duration = 100, startedAt = NOW })
	and live("Rebirth") == f and #CDTL3.cooldowns == nFrames and pname(f.icon) == "CDTL3_Lane_1" and near(f.data.currentCD, 100), tostring(f.data.currentCD))
RunOnUpdate(0.1, 50)
check("  and counts down", near(f.data.currentCD, 95, 0.2), tostring(f.data.currentCD))
CDTL3:StartTimer("groupcd", "Tania-Realm:Rebirth", { name = "Rebirth", duration = 20, startedAt = NOW - 5 })
check("  a restart while running: 15 s left from the new start", live("Rebirth") == f and near(f.data.currentCD, 15), tostring(f.data.currentCD))
check("  the icon falls back to the type's icon when none is given", f.data.icon == 1234, tostring(f.data.icon))
CDTL3:StopTimer("groupcd", "Tania-Realm:Rebirth")

---------------------------------------------------------------- refused starts
local nBefore = #CDTL3.cooldowns
local startedBefore = #got.Started
check("an already-expired start is ignored", CDTL3:StartTimer("groupcd", "old", { name = "Old", duration = 60, startedAt = NOW - 100 }) == false
	and live("Old") == nil and #CDTL3.cooldowns == nBefore)
check("  so is one ending exactly now", CDTL3:StartTimer("groupcd", "old", { name = "Old", duration = 60, startedAt = NOW - 60 }) == false)
check("  an expired restart leaves a running timer alone", (function()
	CDTL3:StartTimer("groupcd", "keep", { name = "Keep", duration = 30, startedAt = NOW })
	local k = live("Keep")
	local ok = CDTL3:StartTimer("groupcd", "keep", { name = "Keep", duration = 10, startedAt = NOW - 50 })
	return ok == false and near(k.data.currentCD, 30) and k.data.baseCD == 30
end)())
CDTL3:StopTimer("groupcd", "keep")
local bad = {
	{ "nope", "a", { duration = 30 } },
	{ "groupcd", nil, { duration = 30 } },
	{ "groupcd", "a", nil },
	{ "groupcd", "a", { duration = 0 } },
	{ "groupcd", "a", { duration = -5 } },
	{ "groupcd", "a", { duration = "30" } },
	{ "groupcd", "a", { duration = 0 / 0 } },
	{ "groupcd", "a", { duration = math.huge } },
	{ "groupcd", "a", { duration = 30, startedAt = "now" } },
	{ "groupcd", {}, { duration = 30 } },
	{ 5, "a", { duration = 30 } },
}
local allFalse = true
for _, b in ipairs(bad) do
	local ok, res = pcall(CDTL3.StartTimer, CDTL3, b[1], b[2], b[3])
	if not ok or res ~= false then allFalse = false end
end
check("an unknown key, no id, no table, or a bad duration or start: refused, no error, nothing started", allFalse and live("a") == nil
	and #CDTL3.cooldowns == nBefore + 1 and #ERRORS == e0, tostring(#CDTL3.cooldowns - nBefore))
check("  a missing startedAt means now", CDTL3:StartTimer("groupcd", "now", { name = "Now", duration = 30 }) and near(live("Now").data.currentCD, 30))
CDTL3:StopTimer("groupcd", "now")

---------------------------------------------------------------- Defaults lane assignment
g.groupcd.defaultLane, g.groupcd.defaultBar, g.groupcd.defaultReady = 2, 3, 2
CDTL3:StartTimer("groupcd", "lane2", { name = "Lane Two", duration = 30, startedAt = NOW })
local l2 = live("Lane Two")
check("Default Lane 2, Default Bar 3: the new timer goes there", l2 and pname(l2.icon) == "CDTL3_Lane_2" and pname(l2.bar) == "CDTL3_BarFrame_3_MF"
	and l2.data.lane == 2 and l2.data.barFrame == 3 and l2.data.readyFrame == 2, l2 and (pname(l2.icon) .. " " .. pname(l2.bar)))
check("  the API names its lane", CDTL3.API.GetTimer("groupcd", "lane2").lane == 2 and #CDTL3.API.GetLane(2).timers == 1)
g.groupcd.defaultLane = 1
CDTL3:StartTimer("groupcd", "lane2", { name = "Lane Two", duration = 30, startedAt = NOW })
check("  a restart takes the Defaults as they are then", pname(l2.icon) == "CDTL3_Lane_1" and l2.data.lane == 1, pname(l2.icon))
g.groupcd.defaultLane = 0
CDTL3:StartTimer("groupcd", "hid", { name = "Hidden Lane", duration = 4, startedAt = NOW })
local hid = live("Hidden Lane")
local nr = count(got.Ready, "hid")
check("Default Lane Hide: the icon waits in holding, the bar frame still shows it", hid and pname(hid.icon) == "CDTL3_Active_Icon_Holding" and pname(hid.bar) == "CDTL3_BarFrame_3_MF",
	hid and (pname(hid.icon) .. " " .. pname(hid.bar)))
RunOnUpdate(0.02, 260)
check("  and it still gets Ready and Ended when it is over", count(got.Ready, "hid") == nr + 1 and count(got.Ended, "hid") == 1, count(got.Ready, "hid") .. "/" .. count(got.Ended, "hid"))
g.groupcd.defaultLane, g.groupcd.defaultBar, g.groupcd.defaultReady = 1, 1, 1

-- Enabled off: new timers are not started
CDTL3.currentFilter["default"] = "GROUPCD"
defaults.enabled.set({}, false)
check("Enabled off: StartTimer starts nothing", CDTL3:StartTimer("groupcd", "off", { name = "Off", duration = 30, startedAt = NOW }) == false and live("Off") == nil)
defaults.enabled.set({}, true)
check("  Enabled on again: it starts", CDTL3:StartTimer("groupcd", "off", { name = "Off", duration = 30, startedAt = NOW }) == true and live("Off") ~= nil)
CDTL3.currentFilter["default"] = savedSel

-- a profile switch: the type's Defaults are made again in the new profile
CDTL3.db:SetProfile("Other")
CDTL3:GetFilterOptions().args.defaults.args.list.values({})
check("a new profile gets the type's Defaults on the Filters tab", CDTL3.db.profile.global.groupcd and CDTL3.db.profile.global.groupcd.defaultLane == 1
	and CDTL3.db.profile.global.groupcd.enabled == true)
CDTL3.db:SetProfile("Default")

check("no lua errors", #ERRORS == base, tostring(#ERRORS - base))
print(string.format("RESULT timertypes %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
