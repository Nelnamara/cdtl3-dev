-- Flight timers (Flights.lua): the route pick from the taxi map, the countdown (estimated, then
-- saved), the hold until landing, learning and the speed fit, Hide Long Timers and Hide out of
-- combat, resuming after a /reload or login, early landing, a flight cut short, the straight-line
-- fallback, turning it off and Forget; then flights that don't start from the taxi map (a chat
-- option like the druids' Moonglade flight, or a loss of control): the route from the takeoff
-- point, learning from the landing point. Runs per client against that client's FlightData file.
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
-- where the player stands ({ continent, x, y } in TaxiNodes coordinates; nil = no position), the
-- chat option call, and the zone text a landing reads
POS = nil
function UnitPosition() if POS then return POS[2], POS[3], 0, POS[1] end end
C_GossipInfo = C_GossipInfo or {}
C_GossipInfo.SelectOption = C_GossipInfo.SelectOption or function() end
C_GossipInfo.SelectOptionByIndex = C_GossipInfo.SelectOptionByIndex or function() end
GOSSIP_OPTIONS = {}
C_GossipInfo.GetOptions = function() return GOSSIP_OPTIONS end
ZONE = "Test Glade"
function GetMinimapZoneText() return ZONE end

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

print("[off the taxi map: setup " .. FLAVOR .. "]")
local nodes = CDTL3.flightData.nodes
check("flight points loaded for this client", type(nodes) == "table" and next(nodes) ~= nil)
FACTION = "Alliance"
function UnitFactionGroup() return FACTION, FACTION end
local function usable(n, faction)
	return n[4] ~= ((faction == "Horde" and 1) or (faction == "Alliance" and 2))
end
-- no other usable point within 20 yards, so standing at it can only mean it
local function alone(id, faction)
	local n = nodes[id]
	for j, m in pairs(nodes) do
		if j ~= id and m[1] == n[1] and usable(m, faction)
			and math.sqrt((m[2] - n[2]) ^ 2 + (m[3] - n[3]) ^ 2) < 20 then
			return false
		end
	end
	return true
end
local outCount = {}
local candidates = {}
for k in pairs(paths) do
	local a = k:match("^(%d+)-")
	outCount[tonumber(a)] = (outCount[tonumber(a)] or 0) + 1
	candidates[#candidates + 1] = k
end
table.sort(candidates)
-- the druids' Nighthaven, Moonglade -> Thunder Bluff first where it exists, flown as the Horde
if paths["63-22"] and nodes[63] and nodes[63][4] == 2 then
	table.insert(candidates, 1, "63-22")
	FACTION = "Horde"
end
local function pick(want)
	for _, k in ipairs(candidates) do
		local a, b = k:match("^(%d+)-(%d+)$")
		a, b = tonumber(a), tonumber(b)
		local na, nb = nodes[a], nodes[b]
		if a ~= b and na and nb and na[1] == nb[1] and want(a, b, k)
			and usable(na, FACTION) and usable(nb, FACTION) and alone(a, FACTION) and alone(b, FACTION) then
			return a, b, k
		end
	end
end
local uFrom, uTo, uKey = pick(function(a, b, k) return outCount[a] == 1 and paths[k][1] > 500 end)
local mFrom, mTo = pick(function(a, b, k) return outCount[a] >= 2 and nodes[b][5] ~= nil end)
check("a point with one route out: " .. tostring(uKey) .. " (" .. FACTION .. ")", uKey ~= nil)
check("a point with several: " .. tostring(mFrom) .. "-" .. tostring(mTo), mFrom ~= nil)
local function stand(id) local n = nodes[id]; POS = { n[1], n[2] + 5, n[3] + 5 } end
local function gossipFlight(option, at)
	stand(at)
	C_GossipInfo.SelectOption(option)
	TAXI.onTaxi = true
	tick(2)
end

print("[a chat option that isn't a flight " .. FLAVOR .. "]")
stand(uFrom)
C_GossipInfo.SelectOption(1111)
check("a chat option watches for a takeoff", P.pending and P.pending.unpicked and P.pending.origin == "g:1111")
tick(60)
check("no takeoff: the watch ends", P.pending == nil and not FL:InFlight())

print("[a chat option's flight, one route " .. FLAVOR .. " " .. uKey .. "]")
local uLen, uDelay = paths[uKey][1], paths[uKey][2]
local uName = P.NodeName(uTo) or "Flight"
gossipFlight(4242, uFrom)
f = P.frame
check("takeoff off the map starts a flight from the point stood at", FL:InFlight() and P.flight.from == uFrom,
	P.flight and P.flight.from)
check("the one route from there", P.flight and P.flight.key == uKey, P.flight and P.flight.key)
check("named for the destination (" .. uName .. ")", f.data.name == uName, f.data.name)
check("estimate from the route data, dimmed", near(f.data.baseCD, uLen / FL:Speed() + uDelay, 0.01)
	and f.data.estimated == true, f.data.baseCD)
flyFor(60)
stand(uTo)
land()
check("landing saves the time", near(store().routes[uKey], 60, 1.0), store().routes[uKey])
check("and what that chat option flies", store().starts["g:4242"] == uKey, store().starts["g:4242"])
check("the countdown goes to the ready frame", f.icon:GetParent() == CDTL3_Ready_1_MF, f.icon:GetParent():GetName())

print("[the same chat option again " .. FLAVOR .. "]")
Advance(30); tick(4)
gossipFlight(4242, uFrom)
check("counts down from the saved time", near(f.data.baseCD, store().routes[uKey], 0.01) and not f.data.estimated,
	f.data.baseCD)
flyFor(60); stand(uTo); land()

print("[a takeoff with no chat option " .. FLAVOR .. "]")
Advance(30); tick(4)
stand(uFrom)
FireEvent("PLAYER_CONTROL_LOST")
TAXI.onTaxi = true
tick(2)
check("a takeoff after losing control is found", FL:InFlight() and P.flight.origin == "n:" .. uFrom,
	P.flight and P.flight.origin)
check("the one route from there, at its saved time", P.flight and P.flight.key == uKey
	and near(f.data.baseCD, store().routes[uKey], 0.01), f.data.baseCD)
flyFor(60); stand(uTo); land()
FireEvent("PLAYER_CONTROL_GAINED")

print("[a point several routes leave " .. FLAVOR .. "]")
Advance(30); tick(4)
local mKey = mFrom .. "-" .. mTo
gossipFlight(5555, mFrom)
check("no route known: a flight with no countdown", FL:InFlight() and P.flight.key == nil
	and P.flight.duration == nil)
flyFor(20)
check("the last countdown isn't brought back to the lane", f.icon:GetParent() ~= CDTL3_Lane_1
	and f.data.currentCD <= 0, tostring(f.data.currentCD) .. " " .. tostring(f.icon:GetParent():GetName()))
flyFor(25)
stand(mTo)
land()
check("landing names the route", near(store().routes[mKey], 45, 1.0), store().routes[mKey])
check("and learns it for the chat option", store().starts["g:5555"] == mKey, store().starts["g:5555"])
Advance(30); tick(4)
gossipFlight(5555, mFrom)
check("next time it counts down from the learned time", P.flight and P.flight.key == mKey
	and near(f.data.baseCD, store().routes[mKey], 0.01), f.data.baseCD)
check("named for where it lands", f.data.name == P.NodeName(mTo), f.data.name)
-- this time it lands somewhere else: a point the data has no name for
flyFor(30)
local spot = nodes[mFrom]
nodes[99998] = { spot[1], spot[2] + 3000, spot[3] + 3000, 0 }
POS = { spot[1], spot[2] + 3000, spot[3] + 3000 }
land()
check("landing somewhere else fixes the route", store().starts["g:5555"] == mFrom .. "-99998"
	and near(store().routes[mFrom .. "-99998"], 30, 1.0), store().starts["g:5555"])
check("a point with no name is named for where it was landed at", P.NodeName(99998) == "Test Glade",
	P.NodeName(99998))
nodes[99998] = nil

print("[reload during a flight off the map " .. FLAVOR .. "]")
Advance(30); tick(4)
gossipFlight(4242, uFrom)
flyFor(10)
P.OnEvent(nil, "PLAYER_LOGOUT")
P.flight = nil
Advance(3)
P.OnEvent(nil, "PLAYER_ENTERING_WORLD", false, true)
Advance(2)
check("resumes knowing how it started", FL:InFlight() and P.flight.origin == "g:4242" and P.flight.from == uFrom)
flyFor(50); stand(uTo); land()
check("and still saves", near(store().routes[uKey], 65.5, 2.0), store().routes[uKey])

if nodes[62] and nodes[63] and nodes[62][4] == 1 and nodes[63][4] == 2 then
	print("[each side's Nighthaven " .. FLAVOR .. "]")
	local keep = FACTION
	FACTION = "Horde"
	check("a Horde druid at the Alliance point gets the Horde one",
		P.NearestNode({ cont = nodes[62][1], x = nodes[62][2], y = nodes[62][3] }) == 63)
	FACTION = "Alliance"
	check("an Alliance druid at the Horde point gets the Alliance one",
		P.NearestNode({ cont = nodes[63][1], x = nodes[63][2], y = nodes[63][3] }) == 62)
	FACTION = keep
end

print("[no position, off " .. FLAVOR .. "]")
Advance(30); tick(4)
POS = nil
C_GossipInfo.SelectOption(7777)
TAXI.onTaxi = true
tick(2)
check("no position: a flight with no countdown", FL:InFlight() and P.flight.duration == nil)
flyFor(10)
land()
check("nothing learned without a position", store().starts["g:7777"] == nil)
FL:SetEnabled(false)
stand(uFrom)
C_GossipInfo.SelectOption(4242)
check("off: a chat option watches for nothing", P.pending == nil)
FL:SetEnabled(true)

print("[a chat option picked from Blizzard's window " .. FLAVOR .. "]")
Advance(30); tick(4)
GOSSIP_OPTIONS = { { orderIndex = 1, gossipOptionID = 4242, name = "Fly to Thunder Bluff" } }
FireEvent("GOSSIP_SHOW")
stand(uFrom)
C_GossipInfo.SelectOptionByIndex(1)
check("a pick by index is named by its option ID", P.pending and P.pending.origin == "g:4242",
	P.pending and P.pending.origin)
TAXI.onTaxi = true
tick(2)
check("and flies what that option learned", P.flight and P.flight.key == store().starts["g:4242"], P.flight and P.flight.key)
flyFor(60); stand(uTo); land()
Advance(30); tick(4)
GOSSIP_OPTIONS = { { orderIndex = 1, gossipOptionID = 4242 }, { orderIndex = 2, gossipOptionID = 5151 } }
C_GossipInfo.SelectOptionByIndex(2)
check("options read at the pick when the window changed unseen", P.pending and P.pending.origin == "g:5151",
	P.pending and P.pending.origin)
tick(60)

print("[the UI hidden mid-flight " .. FLAVOR .. "]")
Advance(30); tick(4)
takeOff(2)
local d0 = f.data.baseCD
flyFor(10)
Advance(30)		-- Alt+Z: the countdown's frame gets no updates
tick(1)
check("the countdown counts the hidden time", near(f.data.currentCD, d0 - 41, 1.0), f.data.currentCD)
land()

print("[a route through a stop " .. FLAVOR .. "]")
Advance(30); tick(4)
TAXI.slots[4] = { name = "Far Point, Testland", type = "REACHABLE", nodeID = 99997, x = 0.5, y = 0.5,
	hops = { { 1, 2 }, { 2, 4 } } }
takeOff(4)
local chain = fromID .. "-" .. toID .. "-99997"
check("keyed by every flight point it stops at", P.flight and P.flight.key == chain, P.flight and P.flight.key)
flyFor(30)
land()
check("its time is saved under that chain", near(store().routes[chain], 30, 1.0) and store().routes[fromID .. "-99997"] == nil,
	store().routes[chain])
TAXI.slots[4] = nil

print("[times saved by the test builds " .. FLAVOR .. "]")
local raw = CDTL3.db.global.flightTimes[P.ClientKey()]
raw.format = nil
raw.routes["1-2"] = 99
P.Store()
check("dropped once: routes and starts", next(raw.routes) == nil and next(raw.starts) == nil and raw.format == 2)
check("flight point names kept", next(raw.names) ~= nil)

local errs = #ERRORS - base
print(string.format("RESULT flights %s: fails=%d lua errors=%d", FLAVOR, fails, errs))
