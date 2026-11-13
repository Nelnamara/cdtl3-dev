-- Anchor to another frame (feature panel card 21). Real files, real Ace3:
--   default Screen: every lane, bar frame and ready frame placed exactly as before
--   Player frame, Cooldown Manager (where it exists) and a frame by name, with side and offsets
--   the other frame is only read: no method but a read is called on it, no field written
--   a missing frame: the screen position, one chat line, then anchored once it appears (timer, ADDON_LOADED)
--   unusable frames (itself, a loop, forbidden, restricted, a hidden place) fall back with no Lua error
--   unlock-and-drag and Edit Mode change the offset and keep it anchored; screen and layout positions kept
--   options: tooltips, hard offset ranges, screen position controls greyed while anchored; Copy keeps it
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"

local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end

local function Find(t, key, seen)
	seen = seen or {}
	if type(t) ~= "table" or seen[t] then return nil end
	seen[t] = true
	for k, v in pairs(t) do
		if k == key and type(v) == "table" then return v end
		local r = Find(v, key, seen)
		if r then return r end
	end
end

local function chatSince(n, text)
	local hits = 0
	for i = n + 1, #CHAT do
		if tostring(CHAT[i]):find(text, 1, true) then hits = hits + 1 end
	end
	return hits
end

-- A Blizzard-like frame behind a recorder: every method call that isn't a read (Get*/Is*), and
-- every field written, is a write to the other frame
local WRITES = {}
local function Watched(name, w, h)
	local real = CreateFrame("Button", name .. "_real", UIParent)
	real:SetSize(w, h)
	local proxy = setmetatable({}, {
		__index = function(_, k)
			local v = real[k]
			if type(v) == "function" then
				return function(_, ...)
					if not (type(k) == "string" and (k:match("^Get") or k:match("^Is"))) then
						WRITES[#WRITES + 1] = name .. ":" .. tostring(k)
					end
					return v(real, ...)
				end
			end
			return v
		end,
		__newindex = function(_, k) WRITES[#WRITES + 1] = name .. "." .. tostring(k) end,
	})
	_G[name] = proxy
	return proxy, real
end

CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {} } }
LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS

local P = CDTL3.db.profile
local L1, B1, R1 = CDTL3_Lane_1, CDTL3_BarFrame_1, CDTL3_Ready_1
local s1, b1, r1 = P.lanes.lane1, P.barFrames.frame1, P.ready.ready1
local function pt(f) return f.__points[1] or {} end
local function onScreen(f, s)
	local p = pt(f)
	return #f.__points == 1 and p[1] == s.relativeTo and p[2] == s.posX and p[3] == s.posY and p[4] == nil
end
local function on(f, target, mine, theirs, x, y)
	local p = pt(f)
	return #f.__points == 1 and p[1] == mine and p[2] == target and p[3] == theirs and p[4] == x and p[5] == y
end
local function show(f)
	local p = pt(f)
	local rel = p[2]
	if type(rel) == "table" then rel = rel.GetName and rel:GetName() or "frame" end
	return string.format("%s %s %s %s %s", tostring(p[1]), tostring(rel),
		tostring(p[3]), tostring(p[4]), tostring(p[5]))
end

---------------------------------------------------------------- default: Screen, as before
print("[default: Screen, placed as before " .. FLAVOR .. "]")
local all = {
	{ "lanes", "lane", "CDTL3_Lane_" }, { "barFrames", "frame", "CDTL3_BarFrame_" }, { "ready", "ready", "CDTL3_Ready_" },
}
for _, k in ipairs(all) do
	for n = 1, 3 do
		local s, f = P[k[1]][k[2] .. n], _G[k[3] .. n]
		check(string.format("%s%d: Anchor to Screen by default, at its x/y position", k[2], n),
			s.anchor.to == "SCREEN" and f ~= nil and onScreen(f, s) and not f.cdtl3AnchoredTo, f and show(f))
	end
end

---------------------------------------------------------------- options
print("[options " .. FLAVOR .. "]")
local laneOpts = CDTL3:GetLaneOptions().args.lane1
local barOpts = CDTL3:GetBarFrameOptions().args.barFrame1
local readyOpts = CDTL3:GetReadyOptions().args.ready1
local function opt(tree, key) return Find(tree, key) end
for label, tree in pairs({ lane = laneOpts, ["bar frame"] = barOpts, ["ready frame"] = readyOpts }) do
	local ok = true
	for _, key in ipairs({ "anchorTo", "anchorFrame", "anchorSide", "anchorX", "anchorY" }) do
		local o = opt(tree, key)
		ok = ok and o ~= nil and type(o.desc) == "string" and o.desc ~= "" and not o.desc:find("\n")
	end
	local x = opt(tree, "anchorX")
	check(label .. ": Anchor to, Frame name, Side, X and Y offset, each with a one-line tooltip", ok)
	check(label .. ": offsets are hard -2000..2000 sliders", x and x.min == -2000 and x.max == 2000 and x.softMin == nil)
end
local aTo, aFrame, aSide, aX, aY = opt(laneOpts, "anchorTo"), opt(laneOpts, "anchorFrame"), opt(laneOpts, "anchorSide"), opt(laneOpts, "anchorX"), opt(laneOpts, "anchorY")
local posX = opt(laneOpts, "posX")
check("on Screen: Side, offsets and Frame name hidden, x Position enabled",
	aSide.hidden() and aX.hidden() and aFrame.hidden() and not posX.disabled())
local vals = aTo.values()
check("choices: Screen, Player frame, A frame by name" .. (vals.COOLDOWNS and ", Cooldown Manager" or ""),
	vals.SCREEN and vals.PLAYER and vals.NAMED and (vals.COOLDOWNS == nil) == (C_CooldownViewer == nil and _G.EssentialCooldownViewer == nil))

---------------------------------------------------------------- Player frame
print("[Player frame " .. FLAVOR .. "]")
local PF, PFreal = Watched("PlayerFrame", 232, 100)
PFreal.GetRect = function() return 500, 300, 232, 100 end
local before = { s1.relativeTo, s1.posX, s1.posY }
aTo.set({}, "PLAYER")
check("Player frame: lane 1 sits above it (its BOTTOM on their TOP), no offset", on(L1, PF, "BOTTOM", "TOP", 0, 0) and L1.cdtl3AnchoredTo == PF, show(L1))
check("  options: Side and offsets show, Frame name hidden, x Position greyed out", not aSide.hidden() and not aX.hidden() and aFrame.hidden() and posX.disabled())
aSide.set({}, "BELOW"); aX.set({}, 10); aY.set({}, -5)
check("Below, X 10, Y -5", on(L1, PF, "TOP", "BOTTOM", 10, -5), show(L1))
for side, pts in pairs({ LEFT = { "RIGHT", "LEFT" }, RIGHT = { "LEFT", "RIGHT" }, CENTER = { "CENTER", "CENTER" }, ABOVE = { "BOTTOM", "TOP" } }) do
	aSide.set({}, side)
	check("side " .. side, on(L1, PF, pts[1], pts[2], 10, -5), show(L1))
end
aSide.set({}, "BELOW")
check("the screen position is kept for later", s1.relativeTo == before[1] and s1.posX == before[2] and s1.posY == before[3])

-- unlocked: the lane's update must not save the anchored point as its screen position
P.global.unlockFrames = true
for _ = 1, 5 do xpcall(L1.__scripts.OnUpdate, ERRH, L1, 0.02) end
check("unlocked: its update leaves the screen position alone", s1.relativeTo == "CENTER" and s1.posX == 0 and s1.posY == -250,
	string.format("%s %s %s", tostring(s1.relativeTo), tostring(s1.posX), tostring(s1.posY)))

-- unlocked drag: lane dropped at left 600, bottom 450 (400 x 44); its TOP centre is 800, 494, the
-- player frame's BOTTOM centre 616, 300: the offset becomes 184, 194
L1.GetRect = function() return 600, 450, 400, 44 end
xpcall(L1.__scripts.OnDragStop, ERRH, L1)
check("unlocked drag: still anchored, offset 184, 194 from the player frame", on(L1, PF, "TOP", "BOTTOM", 184, 194) and s1.anchor.x == 184 and s1.anchor.y == 194, show(L1))
check("  screen position untouched", s1.relativeTo == "CENTER" and s1.posX == 0 and s1.posY == -250)
L1.GetRect = function() return 9000, -7000, 400, 44 end
xpcall(L1.__scripts.OnDragStop, ERRH, L1)
check("a drag far off: held to the sliders' ends (2000, -2000)", s1.anchor.x == 2000 and s1.anchor.y == -2000, tostring(s1.anchor.x) .. ", " .. tostring(s1.anchor.y))
aX.set({}, 0); aY.set({}, 0)

-- Edit Mode: a drag, then Reset Position
if LEM_STUB then
	local moved = LEM_STUB.frames[L1]
	L1.GetRect = function() return 400, 100, 400, 44 end
	s1.editMode = nil
	xpcall(moved, ERRH, L1, "Modern", "LEFT", 400, 0)
	check("Edit Mode drag: still anchored, offset from the player frame (184 .. : -16, -156)", on(L1, PF, "TOP", "BOTTOM", -16, -156), show(L1))
	check("  this layout's screen position not written, plain position untouched",
		(s1.editMode == nil or s1.editMode.Modern == nil) and s1.relativeTo == "CENTER" and s1.posX == 0 and s1.posY == -250)
	xpcall(moved, ERRH, L1, "Modern", "CENTER", 0, -250)
	check("Edit Mode Reset Position: anchored with no offset", on(L1, PF, "TOP", "BOTTOM", 0, 0), show(L1))
end

check("the player frame was only read (no call but Get/Is, no field written)", #WRITES == 0, table.concat(WRITES, ", "))
aTo.set({}, "SCREEN")
check("back to Screen: at its old screen position", onScreen(L1, s1) and not L1.cdtl3AnchoredTo, show(L1))
if LEM_STUB then
	local moved = LEM_STUB.frames[L1]
	xpcall(moved, ERRH, L1, "Modern", "LEFT", 40, 60)
	check("control: on Screen an Edit Mode drag saves the layout and plain position as before",
		s1.editMode and s1.editMode.Modern and s1.editMode.Modern.point == "LEFT" and s1.relativeTo == "LEFT" and s1.posX == 40 and s1.posY == 60)
	s1.editMode = nil
	s1.relativeTo, s1.posX, s1.posY = "CENTER", 0, -250
	CDTL3:RefreshLane(1)
end
-- unlocked drag on Screen: the frame's update saves the place, as before
L1:ClearAllPoints(); L1:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -34)
xpcall(L1.__scripts.OnDragStop, ERRH, L1)
xpcall(L1.__scripts.OnUpdate, ERRH, L1, 0.02)
check("control: on Screen an unlocked drag saves the screen position as before", s1.relativeTo == "TOPLEFT" and s1.posX == 12 and s1.posY == -34,
	string.format("%s %s %s", tostring(s1.relativeTo), tostring(s1.posX), tostring(s1.posY)))
s1.relativeTo, s1.posX, s1.posY = "CENTER", 0, -250
CDTL3:RefreshLane(1)

---------------------------------------------------------------- a frame by name
print("[a frame by name " .. FLAVOR .. "]")
local n0 = #CHAT
aTo.set({}, "NAMED")
check("A frame by name, nothing typed: screen position, no chat line", onScreen(L1, s1) and chatSince(n0, "can't find") == 0 and not aFrame.hidden())
aFrame.set({}, "  MyRaidFrames  ")
check("name typed (spaces trimmed): not there yet, so the screen position", s1.anchor.frame == "MyRaidFrames" and onScreen(L1, s1), show(L1))
check("  one chat line says why", chatSince(n0, "can't find the frame \"MyRaidFrames\" yet") == 1)
CDTL3:RefreshLane(1)
check("  a refresh doesn't say it again", chatSince(n0, "can't find") == 1)
local RF = CreateFrame("Frame", "MyRaidFrames", UIParent)
Advance(5)
check("the frame appears: anchored within 5 seconds", on(L1, RF, "TOP", "BOTTOM", 0, 0), show(L1))
check("  nothing left waiting", next(CDTL3.Anchors.pending) == nil)

aFrame.set({}, "LateAddonFrame")
check("another missing frame: screen position", onScreen(L1, s1))
L1:ClearAllPoints(); L1:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 5, -5)	-- being dragged at its screen position
Advance(5)
check("  while it waits, the 5 s look doesn't pull a frame being dragged back", pt(L1)[1] == "TOPLEFT" and pt(L1)[4] == 5 and CDTL3.Anchors.pending[L1] ~= nil)
local LF = CreateFrame("Frame", "LateAddonFrame", UIParent)
FireEvent("ADDON_LOADED", "SomeRaidFrames")
check("its addon loads: anchored at once", on(L1, LF, "TOP", "BOTTOM", 0, 0), show(L1))

-- frames it can't use
local e0 = #ERRORS
aFrame.set({}, "CDTL3_Lane_1")
check("lane 1 named itself: screen position", onScreen(L1, s1))
local s2 = P.lanes.lane2
s2.anchor.to, s2.anchor.frame = "NAMED", "CDTL3_Lane_1"
CDTL3:RefreshLane(2)
check("lane 2 on lane 1: anchored (lanes can chain)", CDTL3_Lane_2.cdtl3AnchoredTo == L1)
local realSetPoint = L1.SetPoint
L1.SetPoint = function(self, p, rel, ...)
	if type(rel) == "table" and rel.__points and rel.__points[1] and rel.__points[1][2] == self then
		error("Cannot anchor to a region dependent on it")
	end
	return realSetPoint(self, p, rel, ...)
end
aFrame.set({}, "CDTL3_Lane_2")
check("lane 1 on lane 2 (a loop): screen position, no Lua error", onScreen(L1, s1) and #ERRORS == e0, show(L1))
L1.SetPoint = nil
s2.anchor.to, s2.anchor.frame = "SCREEN", ""
CDTL3:RefreshLane(2)
local FB = CreateFrame("Frame", "ForbiddenFrame", UIParent); FB.IsForbidden = function() return true end
aFrame.set({}, "ForbiddenFrame")
check("a forbidden frame: screen position", onScreen(L1, s1))
local RS = CreateFrame("Frame", "RestrictedFrame", UIParent); RS.IsAnchoringRestricted = function() return true end
aFrame.set({}, "RestrictedFrame")
check("a frame whose anchoring is restricted: screen position", onScreen(L1, s1))
aFrame.set({}, "SOUNDKIT")
check("a name that isn't a frame: screen position", onScreen(L1, s1))
if RETAILAPI then
	local SMT = getmetatable(SECRET)
	issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == SMT end
	local SF = CreateFrame("Frame", "SecretPlaceFrame", UIParent); SF.GetLeft = function() return SECRET end
	aFrame.set({}, "SecretPlaceFrame")
	check("a frame whose place reads back hidden: screen position", onScreen(L1, s1))
	aFrame.set({}, "MyRaidFrames")
	aX.set({}, 0); aY.set({}, 0)
	L1.GetRect = function() return 1, 2, 3, 4 end
	RF.GetRect = function() return SECRET, SECRET, 3, 4 end
	xpcall(L1.__scripts.OnDragStop, ERRH, L1)
	check("a drag while their place reads back hidden: the offset stays, still anchored", s1.anchor.x == 0 and s1.anchor.y == 0 and L1.cdtl3AnchoredTo == RF)
	RF.GetRect = nil
	issecretvalue = nil
end
check("no Lua errors from frames it can't use", #ERRORS == e0, tostring(#ERRORS - e0))
aTo.set({}, "SCREEN")

---------------------------------------------------------------- Cooldown Manager
print("[Cooldown Manager " .. FLAVOR .. "]")
local hadAPI = C_CooldownViewer
if not hadAPI then
	check("no Cooldown Manager on this client: not offered", aTo.values().COOLDOWNS == nil)
	C_CooldownViewer = {}
end
local CM = Watched("EssentialCooldownViewer", 300, 50)
check("Cooldown Manager offered where it exists", aTo.values().COOLDOWNS ~= nil)
aTo.set({}, "COOLDOWNS")
check("Cooldown Manager: lane 1 below its Essential row", on(L1, CM, "TOP", "BOTTOM", 0, 0), show(L1))
aTo.set({}, "SCREEN")
check("  only read", #WRITES == 0, table.concat(WRITES, ", "))
C_CooldownViewer = hadAPI
EssentialCooldownViewer = nil
check("the choice stays listed while a lane holds it, even without the Cooldown Manager", (function()
	s1.anchor.to = "COOLDOWNS"; local has = aTo.values().COOLDOWNS ~= nil; s1.anchor.to = "SCREEN"; return has end)())

---------------------------------------------------------------- bar frames and ready frames
print("[bar frames and ready frames " .. FLAVOR .. "]")
local bTo, rTo = opt(barOpts, "anchorTo"), opt(readyOpts, "anchorTo")
bTo.set({}, "PLAYER")
check("bar frame 1 on the player frame", on(B1, PF, "BOTTOM", "TOP", 0, 0) and opt(barOpts, "posX").disabled(), show(B1))
rTo.set({}, "PLAYER")
opt(readyOpts, "anchorSide").set({}, "RIGHT")
check("ready frame 1 right of the player frame", on(R1, PF, "LEFT", "RIGHT", 0, 0), show(R1))
-- ready frame dropped with its LEFT middle at 760, 350: player frame RIGHT middle 732, 350 -> 28, 0
R1.GetRect = function() return 760, 325, 50, 50 end
xpcall(R1.__scripts.OnDragStop, ERRH, R1)
check("ready frame drag: offset 28, 0", on(R1, PF, "LEFT", "RIGHT", 28, 0), show(R1))
for _ = 1, 3 do
	xpcall(B1.__scripts.OnUpdate, ERRH, B1, 0.02)
	xpcall(R1.__scripts.OnUpdate, ERRH, R1, 0.02)
end
check("unlocked updates keep their screen positions", b1.relativeTo == "CENTER" and b1.posX == -300 and b1.posY == 0
	and r1.relativeTo == "CENTER" and r1.posX == -300 and r1.posY == -75)

-- Copy Settings keeps the target's place
CDTL3:CopyFrameSettings("ready", 1, 2)
check("Copy From ready frame 1: ready frame 2 stays on the screen", P.ready.ready2.anchor.to == "SCREEN" and onScreen(CDTL3_Ready_2, P.ready.ready2))
bTo.set({}, "SCREEN"); rTo.set({}, "SCREEN")
check("bar and ready frames back on the screen", onScreen(B1, b1) and onScreen(R1, r1))
R1:SetAlpha(1)
R1:ClearAllPoints(); R1:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 21, -43)
xpcall(R1.__scripts.OnUpdate, ERRH, R1, 0.02)
check("control: on Screen an unlocked ready frame saves its place as before", r1.relativeTo == "TOPLEFT" and r1.posX == 21 and r1.posY == -43)
r1.relativeTo, r1.posX, r1.posY = "CENTER", -300, -75
CDTL3:RefreshReady(1)

---------------------------------------------------------------- a profile switch and a reload keep it
print("[profile switch " .. FLAVOR .. "]")
aTo.set({}, "PLAYER")
CDTL3.db:SetProfile("Other")
check("another profile: lane 1 on the screen", onScreen(L1, CDTL3.db.profile.lanes.lane1))
CDTL3.db:SetProfile("Default")
check("back: on the player frame again", L1.cdtl3AnchoredTo == PF and CDTL3.db.profile.lanes.lane1.anchor.to == "PLAYER")
CDTL3.db.profile.lanes.lane1.anchor.to = "SCREEN"
CDTL3:RefreshLane(1)

print(string.format("RESULT anchors %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS))
