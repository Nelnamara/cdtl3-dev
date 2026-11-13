-- Cards 32, 41, 42: the public messages (CDTL3_TimerStarted / Ready / Ended), the read-only
-- CDTL3.API, and /cdtl3 help. A listener is a plain AceEvent object, as another addon would be.
-- Real files, real AceDB.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME = PLAYER.guid

local function entry(id, name, extra)
	local e = { id = id, name = name, type = "spells", icon = 4242, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local list = { entry(921, "Alpha Spell"), entry(922, "Beta Spell", { lane = 2, barFrame = 2, readyFrame = 2, bCD = 20000 }) }
for _, e in ipairs(list) do SPELLINFO[e.id] = { e.name, e.icon }; KNOWN[e.id] = true end
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = { tables = { spells = list } } } }

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
local function cast(id, dur)
	SPELLCD[id] = { startTime = NOW, duration = dur, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id, id)
end
local function live(name) return CDTL3:GetExistingCooldown(name, "spells") end

-- a listener that is not CDTL3, the way another addon would be
local L = {}
LibStub("AceEvent-3.0"):Embed(L)
local got = { Started = {}, Ready = {}, Ended = {} }
for _, k in ipairs({ "Started", "Ready", "Ended" }) do
	L:RegisterMessage("CDTL3_Timer" .. k, function(msg, data) got[k][#got[k] + 1] = { msg = msg, data = data } end)
end
local function last(k) return got[k][#got[k]] end

print("[API " .. FLAVOR .. "]")
check("API.version is 1", CDTL3.API and CDTL3.API.version == 1)

---------------------------------------------------------------- 32. messages
print("[32 messages " .. FLAVOR .. "]")
cast(921, 30)
RunOnUpdate(0.02, 10)
local a = live("Alpha Spell")
local s = last("Started")
check("Started received once", #got.Started >= 1 and s and s.msg == "CDTL3_TimerStarted")
local d = s and s.data or {}
check("Started carries type, id, name, icon", d.type == "spells" and d.id == 921 and d.name == "Alpha Spell" and d.icon == 4242,
	string.format("%s %s %s %s", tostring(d.type), tostring(d.id), tostring(d.name), tostring(d.icon)))
check("Started carries a duration and an expiry, estimated false", type(d.duration) == "number" and d.duration > 0 and type(d.expires) == "number"
	and d.estimated == false and d.expires > NOW - 1, string.format("duration=%s expires=%s now=%s", tostring(d.duration), tostring(d.expires), tostring(NOW)))
check("the message data is not CDTL3's own table", d ~= a.data)
local nStarted = #got.Started

-- a move keeps the countdown and is not a start
a.data.currentCD = 12
a.data.lane = 2
CDTL3:MoveToLane(a)
check("MoveToLane sends no Started", #got.Started == nStarted)
a.data.lane = 1
CDTL3:MoveToLane(a)

-- finish it: Ready, then Ended when the Ready frame has had its time
SPELLCD[921] = nil
a.data.currentCD = -1
RunOnUpdate(0.02, 5)
local r = last("Ready")
check("Ready received with the entry's fields", r and r.msg == "CDTL3_TimerReady" and r.data.type == "spells" and r.data.id == 921
	and r.data.name == "Alpha Spell", r and tostring(r.data.name))
check("Ready: no Ended yet while the Ready frame shows it", #got.Ended == 0)
RunOnUpdate(0.02, 1200)
local e = last("Ended")
check("Ended received after the Ready frame's time", e and e.msg == "CDTL3_TimerEnded" and e.data.id == 921 and e.data.name == "Alpha Spell",
	tostring(#got.Ended))
check("exactly one Ready and one Ended", #got.Ready == 1 and #got.Ended == 1, #got.Ready .. "/" .. #got.Ended)

-- hidden times: nil, and Ready still fires (itemUnread is how a timer whose cooldown is hidden is flagged)
cast(921, 30)
RunOnUpdate(0.02, 10)
a = live("Alpha Spell")
a.data.itemUnread = true
a.data.currentCD = -1
local nReady = #got.Ready
SPELLCD[921] = nil
RunOnUpdate(0.02, 5)
local hr = last("Ready")
check("hidden: Ready still fires", #got.Ready == nReady + 1)
check("hidden: duration and expires are nil, the rest is there", hr and hr.data.duration == nil and hr.data.expires == nil
	and hr.data.id == 921 and hr.data.name == "Alpha Spell")
a.data.itemUnread = nil
RunOnUpdate(0.02, 1200)

-- a riding timer (combat timers): times nil in Started and in the API
cast(921, 30)
RunOnUpdate(0.02, 5)
a = live("Alpha Spell")
local n0 = #got.Started
a.ct = { riding = true }
CDTL3:FireTimer("CDTL3_TimerStarted", a)
local ride = last("Started")
check("riding: Started has nil duration and expires", #got.Started == n0 + 1 and ride.data.duration == nil and ride.data.expires == nil and ride.data.id == 921)
local rt = CDTL3.API.GetTimer("spells", 921)
check("riding: API.GetTimer has nil duration and expires", rt and rt.duration == nil and rt.expires == nil and rt.name == "Alpha Spell")
a.ct = nil

-- an error in a listener cannot reach the update loop
local bad = {}
LibStub("AceEvent-3.0"):Embed(bad)
bad:RegisterMessage("CDTL3_TimerStarted", function() error("listener broke") end)
-- (the stub's error handler records the listener's error and prints it: that one entry is expected, so it is removed)
local e0 = #ERRORS
local okc = pcall(CDTL3.SendToLane, CDTL3, a)
local swallowed = #ERRORS - e0
for _ = 1, swallowed do table.remove(ERRORS) end
check("a failing listener does not break SendToLane", okc and swallowed == 1, tostring(swallowed))
bad:UnregisterMessage("CDTL3_TimerStarted")

-- scaffolding timers send nothing
local nBefore = #got.Started
local td = { id = 1, name = "T", type = "testing", icon = 1, bCD = 5000, lane = 1, barFrame = 1, readyFrame = 1, enabled = true, ignored = false, usedBy = { ME } }
local tf = CDTL3:CreateCooldown(CDTL3:GetUID(), "testing", td)
check("test timers send no messages", #got.Started == nBefore)

---------------------------------------------------------------- 41. API
print("[41 API " .. FLAVOR .. "]")
-- back to a clean, counting state for both spells
cast(921, 30)
cast(922, 20)
RunOnUpdate(0.02, 10)
a = live("Alpha Spell")
local b = live("Beta Spell")
a.data.currentCD = 25; a.data.baseCD = 30
b.data.currentCD = 15
local API = CDTL3.API
local timers = API.GetTimers()
check("GetTimers lists the running timers", type(timers) == "table" and #timers >= 2, tostring(#timers))
local ta
for _, t in ipairs(timers) do if t.id == 921 then ta = t end end
check("GetTimers entry: plain fields, ready false, lane", ta and ta.type == "spells" and ta.name == "Alpha Spell" and ta.icon == 4242
	and ta.ready == false and ta.lane == 1 and type(ta.expires) == "number" and ta.duration == 30)
check("GetTimers entry has no tables inside it", (function() for _, v in pairs(ta) do if type(v) == "table" then return false end end return true end)())
ta.name = "MUTATED"; ta.expires = -5; timers[1] = nil
local again = API.GetTimer("spells", 921)
check("copies: changing a result changes nothing", again.name == "Alpha Spell" and again.expires ~= -5 and live("Alpha Spell").data.name == "Alpha Spell")
check("copies: two calls return different tables", API.GetTimer("spells", 921) ~= API.GetTimer("spells", 921) and API.GetTimers() ~= API.GetTimers())
check("IsReady false while counting", API.IsReady("spells", 921) == false)
check("GetTimer of an unknown entry is nil, IsReady too", API.GetTimer("spells", 99999) == nil and API.IsReady("spells", 99999) == nil)
a.data.currentCD = -1
check("IsReady true once it is over", API.IsReady("spells", 921) == true)
local ready = API.GetTimer("spells", 921)
check("GetTimer of a ready timer: ready true, expires not in the future", ready.ready == true and ready.expires <= NOW + 0.001,
	tostring(ready.expires) .. " vs " .. tostring(NOW))
local ids = {}
for _, t in ipairs(API.GetTimers()) do ids[t.id] = true end
check("GetTimers leaves out the ready one", not ids[921] and ids[922])

local l2 = API.GetLane(2)
check("GetLane(2): number, name, enabled and its running timers", l2 and l2.number == 2 and l2.name == "Lane 2" and l2.enabled == true
	and #l2.timers == 1 and l2.timers[1].id == 922, l2 and tostring(#l2.timers))
local l2n = API.GetLane("lane 2")
check("GetLane by name (any case) and by numeral string", l2n and l2n.number == 2 and API.GetLane("2").number == 2)
check("GetLane of nothing is nil", API.GetLane(9) == nil and API.GetLane("Nope") == nil and API.GetLane() == nil)
l2.timers[1].id = 0; l2.name = "x"
check("GetLane returns copies", API.GetLane(2).timers[1].id == 922 and API.GetLane(2).name == "Lane 2")
-- hidden times through the lane
b.ct = { riding = true }
check("GetLane: a riding timer's times are nil", API.GetLane(2).timers[1].expires == nil and API.GetLane(2).timers[1].duration == nil)
b.ct = nil

---------------------------------------------------------------- 42. /cdtl3 help
print("[42 help " .. FLAVOR .. "]")
local printed = {}
local oldPrint = CDTL3.Print
CDTL3.Print = function(_, ...) printed[#printed + 1] = table.concat({ ... }, " ") end
CDTL3:ChatCommand("help")
CDTL3.Print = oldPrint
local text = table.concat(printed, "\n")
local missing = {}
for _, w in ipairs({ "lanes", "ready", "bars", "filters", "profiles", "lock", "unlock", "test", "debug", "auras", "oaf", "combattimers", "minimap", "report", "log", "perf", "help" }) do
	if not text:find("/cdtl3 " .. w, 1, true) and not text:find(w, 1, true) then missing[#missing + 1] = w end
end
check("/cdtl3 help names every subcommand incl. report, log, perf", #missing == 0, table.concat(missing, ","))
check("each line is one command and one sentence", #printed >= 17 and not text:find("\n\n"), tostring(#printed))
check("/cdtl3 ? does the same", (function() local n = #printed; CDTL3.Print = function() n = n + 1 end; CDTL3:ChatCommand("?"); CDTL3.Print = oldPrint; return n > #printed end)())

check("no lua errors", #ERRORS == base, tostring(#ERRORS - base))
print(string.format("RESULT api %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
