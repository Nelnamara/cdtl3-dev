-- Flight timers (Flights.lua): the route pick from the taxi map, the countdown (estimated, then
-- saved), the hold until landing, learning and the speed fit, Hide Long Timers and Hide out of
-- combat, resuming after a /reload or login, early landing, a flight cut short, the straight-line
-- fallback, turning it off and Forget. Runs per client against that client's FlightData file.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "DRUID"

local fails = 0
local function check(label, ok, detail)
	if ok then
		print("  ok   " .. label)
	else
		fails = fails + 1
		print("  FAIL " .. label .. (detail and (" | " .. tostring(detail)) or ""))
	end
end
local function near(a, b, tol)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 0.6)
end

-- the taxi client: a map of slots, the hops to each, and whether the player is on a flight
TAXI = { slots = {}, onTaxi = false, mapID = 1414 }
function NumTaxiNodes() return #TAXI.slots end
function TaxiNodeName(i) return TAXI.slots[i] and TAXI.slots[i].name end
function TaxiNodeGetType(i) return TAXI.slots[i] and TAXI.slots[i].type or "NONE" end
function GetNumRoutes(i) local s = TAXI.slots[i]; return (s and s.hops and #s.hops) or 0 end
function TaxiGetNodeSlot(i, r, src) local h = TAXI.slots[i].hops[r]; if src then return h[1] end return h[2] end
TAKEN = 0
function TakeTaxiNode(i) TAKEN = TAKEN + 1 end
function GetTaxiMapID() return TAXI.mapID end
C_TaxiMap = { GetAllTaxiNodes = function(mapID)
	local t = {}
	for i, s in ipairs(TAXI.slots) do
		t[#t + 1] = { nodeID = s.nodeID, slotIndex = i, name = s.name, position = { x = s.x, y = s.y } }
	end
	return t
end }
function UnitOnTaxi() return TAXI.onTaxi end
if FLAVOR == "retail" then
	function TaxiRequestEarlyLanding() end
end
C_Map = C_Map or {}
C_Map.GetWorldPosFromMapPos = function(mapID, v) return 1, { x = v.x * 10000, y = v.y * 10000 } end
CreateVector2D = CreateVector2D or function(x, y) return { x = x, y = y } end

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local FL = CDTL3.Flights
local P = FL and FL.private
local g = CDTL3.db.profile.global

print("[setup " .. FLAVOR .. "]")
check("Flights.lua loaded", FL ~= nil and P ~= nil)
check("route data loaded for this client", CDTL3.flightData and type(CDTL3.flightData.paths) == "table"
	and next(CDTL3.flightData.paths) ~= nil)
check("on by default, lane 1, bar frame 1, ready frame 1", FL:Enabled() and g.flights.defaultLane == 1
	and g.flights.defaultBar == 1 and g.flights.defaultReady == 1)

-- a route this client's data has: Thunder Bluff to the Crossroads where it exists
local paths = CDTL3.flightData.paths
local routeKey = paths["22-25"] and "22-25" or nil
if not routeKey then
	local keys = {}
	for k, p in pairs(paths) do
		local a, b = k:match("^(%d+)-(%d+)$")
		if a ~= b and p[1] >= 2000 and p[1] <= 10000 then keys[#keys + 1] = k end
	end
	table.sort(keys)
	routeKey = keys[1]
end
local fromID, toID = routeKey:match("^(%d+)-(%d+)$")
local LEN, DELAY = paths[routeKey][1], paths[routeKey][2]
TAXI.slots = {
	{ name = "Thunder Bluff, Mulgore", type = "CURRENT", nodeID = tonumber(fromID), x = 0.1, y = 0.1 },
	{ name = "Crossroads, The Barrens", type = "REACHABLE", nodeID = tonumber(toID), x = 0.3, y = 0.3, hops = { { 1, 2 } } },
	{ name = "Nowhere, Testland", type = "REACHABLE", nodeID = 99999, x = 0.2, y = 0.1, hops = { { 1, 3 } } },
}

local function tick(n, dt) RunOnUpdate(dt or 0.25, n or 1) end
local function takeOff(slot)
	FireEvent("TAXIMAP_OPENED")
	TakeTaxiNode(slot)
	TAXI.onTaxi = true
	tick(2)
end
local function flyFor(seconds) RunOnUpdate(0.5, math.floor(seconds / 0.5 + 0.5)) end
local function land() TAXI.onTaxi = false; tick(2) end
local store = function() return P.Store() end

-- lane 1 hides icons over 10 s: a flight must still show
local lane = CDTL3.db.profile.lanes.lane1
lane.mode.type = "LINEAR"
lane.mode.linear.max = 10
lane.mode.linear.hideTimeSurplus = true

print("[first flight: estimate " .. FLAVOR .. " " .. routeKey .. "]")
local est = LEN / 30.3 + DELAY
takeOff(2)
local f = P.frame
check("takeoff starts a flight", FL:InFlight())
check("a flights countdown exists", f ~= nil and f.data.type == "flights")
check("named for the destination without its zone", f and f.data.name == "Crossroads", f and f.data.name)
check("estimate = route yards / 30.3 + stops", f and near(f.data.baseCD, est, 0.01), f and f.data.baseCD)
check("marked as an estimate", f and f.data.estimated == true)
check("on lane 1", f and f.icon:GetParent() == CDTL3_Lane_1, f and f.icon:GetParent():GetName())
check("faction icon", f and f.data.icon == "Interface\\Icons\\Ability_Mount_Gryphon_01", f and f.data.icon)
local tf = UIParent:CreateFontString()
FL:DimText(f, tf)
check("estimate text is dimmed", near(tf:GetAlpha(), 0.55, 0.001), tf:GetAlpha())
flyFor(1)
check("Hide Long Timers doesn't hide a flight over Max Time", f.icon.valid == true)

-- Hide out of combat keeps the flight's frames up
g.hideOutOfCombat = true
CDTL3.combat = false
check("Hide out of combat: the lane showing the flight is held", FL:Holds(CDTL3_Lane_1))
CDTL3_Lane_1:SetAlpha(1)
CDTL3:Autohide(CDTL3_Lane_1, lane)
check("Hide out of combat: that lane stays visible", CDTL3_Lane_1:GetAlpha() ~= 0, CDTL3_Lane_1:GetAlpha())

-- fly 25% faster than the estimate's speed: the countdown runs out first and waits
local took = LEN / (30.3 * 1.25) + DELAY
flyFor(took - 1)
check("still counting before landing", f.data.currentCD > 0 and f.icon:GetParent() == CDTL3_Lane_1)
if took < est then
	-- a faster flight lands before the estimate runs out
	check("countdown still running when the flight lands early", f.data.currentCD > 0.1, f.data.currentCD)
end
land()
check("landing ends the flight", not FL:InFlight())
check("the countdown goes to the ready frame", f.icon:GetParent() == CDTL3_Ready_1_MF, f.icon:GetParent():GetName())
check("estimate dim cleared on landing", tf:GetAlpha() == 1, tf:GetAlpha())
local saved = store().routes[routeKey]
check("real time saved for the route", near(saved, took, 0.8), saved)
check("speed refitted from the flight", near(FL:Speed(), LEN / (saved - DELAY), 0.01), FL:Speed())
check("nothing left for a resume", CDTL3.db.char.flight == nil)

print("[second flight: saved time " .. FLAVOR .. "]")
Advance(30); tick(4)
takeOff(2)
check("counts down from the saved time", near(f.data.baseCD, saved, 0.01), f.data.baseCD)
check("not an estimate", not f.data.estimated)
check("the same frame is reused", P.frame == f)
-- the saved time runs out before landing: the countdown waits at the end
flyFor(saved + 10)
check("waits at the end while still flying", near(f.data.currentCD, 0.1, 0.001) and f.icon:GetParent() == CDTL3_Lane_1,
	f.data.currentCD)
land()
check("a longer flight replaces the saved time", near(store().routes[routeKey], saved + 10, 1.0), store().routes[routeKey])
saved = store().routes[routeKey]

print("[reload mid-flight " .. FLAVOR .. "]")
Advance(30); tick(4)
takeOff(2)
flyFor(20)
local serverStart = CDTL3.db.char.flight and CDTL3.db.char.flight.serverStart
check("flight saved for a resume", serverStart ~= nil)
P.OnEvent(nil, "PLAYER_LOGOUT")
P.flight = nil		-- the UI reloads
Advance(3)
P.OnEvent(nil, "PLAYER_ENTERING_WORLD", false, true)
Advance(2)
check("resumed after the reload", FL:InFlight() and P.flight.resumed == false)
check("countdown resumes where it was (time ran on)", near(f.data.currentCD, saved - 25, 1.5), f.data.currentCD)
flyFor(saved - 25)
land()
check("a reloaded flight still saves its time", near(store().routes[routeKey], saved, 2.0), store().routes[routeKey])
saved = store().routes[routeKey]

print("[logout mid-flight " .. FLAVOR .. "]")
Advance(30); tick(4)
takeOff(2)
flyFor(20)
P.OnEvent(nil, "PLAYER_LOGOUT")
check("logout time recorded", CDTL3.db.char.flight and CDTL3.db.char.flight.logoutAt ~= nil)
P.flight = nil
Advance(300)		-- logged out five minutes
P.OnEvent(nil, "PLAYER_ENTERING_WORLD", true, false)
Advance(2)
check("resumed after the login", FL:InFlight() and P.flight.resumed == true)
check("countdown resumes from the logout (flight paused)", near(f.data.currentCD, saved - 20, 1.5), f.data.currentCD)
flyFor(saved - 20)
land()
check("a flight resumed after a login doesn't save", near(store().routes[routeKey], saved, 0.01), store().routes[routeKey])

print("[landed while logged out " .. FLAVOR .. "]")
Advance(30); tick(4)
takeOff(2)
flyFor(5)
P.OnEvent(nil, "PLAYER_LOGOUT")
P.flight = nil
TAXI.onTaxi = false
P.StopTicker()
P.OnEvent(nil, "PLAYER_ENTERING_WORLD", true, false)
Advance(2)
check("no resume once off the flight", not FL:InFlight() and CDTL3.db.char.flight == nil)

print("[cut short " .. FLAVOR .. "]")
Advance(30); tick(4)
takeOff(2)
flyFor(saved * 0.3)
land()
check("a flight far shorter than its saved time doesn't overwrite it", near(store().routes[routeKey], saved, 0.01),
	store().routes[routeKey])

if TaxiRequestEarlyLanding then
	print("[early landing " .. FLAVOR .. "]")
	Advance(30); tick(4)
	takeOff(2)
	flyFor(saved * 0.8)
	TaxiRequestEarlyLanding()
	land()
	check("early landing doesn't save", near(store().routes[routeKey], saved, 0.01), store().routes[routeKey])
end

print("[route the data lacks " .. FLAVOR .. "]")
Advance(30); tick(4)
takeOff(3)
local straight = 0.1 * 10000 * 1.2
check("straight-line estimate from the map positions", near(f.data.baseCD, straight / FL:Speed(), 0.01), f.data.baseCD)
check("named Nowhere, dimmed", f.data.name == "Nowhere" and f.data.estimated == true)
flyFor(40)
land()
check("its time is saved too", near(store().routes[fromID .. "-99999"], 40, 1.0), store().routes[fromID .. "-99999"])

print("[off " .. FLAVOR .. "]")
Advance(30); tick(4)
FL:SetEnabled(false)
FireEvent("TAXIMAP_OPENED")
TakeTaxiNode(2)
TAXI.onTaxi = true
tick(2)
check("off: no flight", not FL:InFlight() and P.pending == nil)
TAXI.onTaxi = false
tick(2)
FL:SetEnabled(true)
-- turned off mid-flight
takeOff(2)
FL:SetEnabled(false)
check("turning it off mid-flight ends the countdown", not FL:InFlight() and f.data.currentCD <= 0)
land()
FL:SetEnabled(true)

print("[forget " .. FLAVOR .. "]")
check("learned routes counted", FL:LearnedCount() == 2, FL:LearnedCount())
FL:Forget()
check("Forget clears this client's times", FL:LearnedCount() == 0)
check("and the speed goes back to 30.3", FL:Speed() == 30.3)

print("[no taxi map " .. FLAVOR .. "]")
P.slots = nil
local saveSlots = TAXI.slots
TAXI.slots = {}
TakeTaxiNode(1)
check("a pick with no map does nothing", P.pending == nil)
TAXI.slots = saveSlots

local errs = #ERRORS - base
print(string.format("RESULT flights %s: fails=%d lua errors=%d", FLAVOR, fails, errs))
