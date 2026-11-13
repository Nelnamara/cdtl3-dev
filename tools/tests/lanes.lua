-- Lanes (red team of 12 Nov 2026, cards 13 16 17 19 20 22 24 25 32). Real files, real Ace3:
--   20 Hide out of combat refreshes lanes and bar frames by frame number at the pull
--   32 Grouped stacking: the per-stack pass runs once per update, not once per icon. Every icon's
--      stack, sOffset and frame levels (icon, bd, hl) over many layouts must match the old code,
--      kept below word for word as the reference
--   17 vertical lanes: the secondary marker moves along the long side, sized for the lane
--   13 the GCD marker while the GCD's timing is hidden (Retail, Forever): rides a StatusBar fed the
--      GCD spell's timer, or the last cast's on Forever (no 61304); no closure per frame, and
--      nothing read on the hidden path while timings can be read
--   16 Secondary Tracking switched on from the options sizes and shows the marker at once
--   19 lane custom texts with live tags keep updating
--   22 Override Autohide brings back an empty lane that faded out, and fades it again
--   24 Split Count saves whole numbers only, typed into the options window; a fraction saved
--      before that reads as the whole number the slider shows
--   25 Edit Mode slider ranges cover the options window's
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"

local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end

-- secret numbers the harness can still read (as combattimers.lua does)
local SMT = getmetatable(SECRET)
local function S(v) return setmetatable({ __v = v }, SMT) end
local function IsS(v) return type(v) == "table" and getmetatable(v) == SMT end
local function Val(v) if IsS(v) then return rawget(v, "__v") end return v end

-- frames remember their orientation
local RealCreateFrame = CreateFrame
CreateFrame = function(...)
	local f = RealCreateFrame(...)
	f.SetOrientation = function(self, o) self.__orient = o end
	return f
end

-- first table under t whose key is `match` (or for which match(k, v) is true)
local function Find(t, match, seen)
	seen = seen or {}
	if type(t) ~= "table" or seen[t] then return nil end
	seen[t] = true
	for k, v in pairs(t) do
		if type(v) == "table" then
			if (type(match) == "string" and k == match) or (type(match) == "function" and match(k, v)) then
				return v
			end
			local r = Find(v, match, seen)
			if r then return r end
		end
	end
end

local function step(f, n)
	for _ = 1, n or 1 do
		xpcall(f.__scripts.OnUpdate, ERRH, f, 0.02)
	end
end

-- fades finish at once (the stub's animations never play)
local function instantFades(f, alpha)
	f.animateOut.Play = function() f:SetAlpha(0) end
	f.animateIn.Play = function() f:SetAlpha(alpha) end
end

-- lane 1 and bar frame 1 off at login, Hide out of combat on
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {
	lanes = { lane1 = { enabled = false } },
	barFrames = { frame1 = { enabled = false } },
	global = { hideOutOfCombat = true, unlockFrames = false },
} } }

LoadTOC(HARNESS_TOCFILE)
local EM = {}	-- frame name -> its Edit Mode settings
if LEM_STUB then
	LEM_STUB.AddFrameSettings = function(self, frame, settings) EM[frame:GetName()] = settings end
end
Login()
Advance(11)
local g = CDTL3.db.profile.global
local L = CDTL3.db.profile.lanes

---------------------------------------------------------------- 20. Hide out of combat at the pull
print("[hide out of combat: refresh by frame number " .. FLAVOR .. "]")
local numbers = {}
for _, f in ipairs(CDTL3.lanes) do numbers[#numbers + 1] = f.number end
check("lane 1 off at login: the list holds lanes 2 and 3", table.concat(numbers, ",") == "2,3", table.concat(numbers, ","))
local lanesDone, barsDone = {}, {}
local realLane, realBar = CDTL3.RefreshLane, CDTL3.RefreshBarFrame
CDTL3.RefreshLane = function(self, i) lanesDone[#lanesDone + 1] = tostring(i); return realLane(self, i) end
CDTL3.RefreshBarFrame = function(self, i) barsDone[#barsDone + 1] = tostring(i); return realBar(self, i) end
CDTL3_Lane_3:SetAlpha(0)	-- faded while out of combat
CDTL3.combat = true
CDTL3:ApplyCombatVisibility()
CDTL3.RefreshLane, CDTL3.RefreshBarFrame = realLane, realBar
check("pull: lanes refreshed by number", table.concat(lanesDone, ",") == "2,3", table.concat(lanesDone, ","))
check("pull: bar frames refreshed by number", table.concat(barsDone, ",") == "2,3", table.concat(barsDone, ","))
check("pull: the last lane shows", CDTL3_Lane_3:GetAlpha() == L.lane3.alpha, tostring(CDTL3_Lane_3:GetAlpha()))
CDTL3.combat = false
g.hideOutOfCombat = false
L.lane1.enabled = true
CDTL3:CreateLanes()
for i = 1, 3 do CDTL3:RefreshLane(i) end

---------------------------------------------------------------- 32. Grouped stacking, old vs new
print("[grouped stacking: old per-icon loop vs once per pass " .. FLAVOR .. "]")

-- THE OLD CODE (Lanes.lua before the fix), word for word apart from its name: the reference
local OldCalcStacking = function(f, s, count)
	local baseLevel = 5
	local levelMultiplier = 5

	if count >= 2 and s["stacking"]["enabled"] then
		local style = s["stacking"]["style"]
		
		if style == "GROUPED" then
			local height = s["stacking"]["height"]
			local grow = s["stacking"]["grow"]
			local iconSize = s["icons"]["size"]

			-- combat timers (CombatTimers.lua): riding icons sit out (stack 1, no offset), and a
			-- pass is skipped (empty list) while any other position reads back hidden
			local kids, n = f.validChildren, count
			local CT = CDTL3.CombatTimers
			if CT and CT.GroupedChildren then
				kids, n = CT:GroupedChildren(f.validChildren, count)
				if not kids then
					kids, n = {}, 0
				end
			end

			table.sort(kids, function(a, b)
				local aX, aY = a:GetCenter()
				local bX, bY = b:GetCenter()
				
				if s["vertical"] then
					if aY == bY then
						return a.uid < b.uid
					end
					
					return aY < bY
				else
					if aX == bX then
						return a.uid < b.uid
					end
				
					return aX < bX
				end
			end)
			
			local indicies = {}
			local currentIndex = 1
			
			for k, iconA in pairs(kids) do
				if k == 1 then
					table.insert(indicies, currentIndex)
				end
				
				if k + 1 <= n then
					local iconB = kids[k + 1]
					local aX, aY = iconA:GetCenter()
					local bX, bY = iconB:GetCenter()
					
					local distance = 0
					if s["vertical"] then
						distance = math.abs(aY - bY)
					else
						distance = math.abs(aX - bX)
					end
					
					if distance <= iconSize then
						table.insert(indicies, currentIndex)
					else
						currentIndex = currentIndex + 1
						table.insert(indicies, currentIndex)
					end
				end
				
				for i = 1, currentIndex, 1 do
					local currentStack = {}
					local stackCount = 0
					-- Count how many we have in the i'nth stack
					for k, v in pairs(indicies) do
						if v == i then
							stackCount = stackCount + 1
							table.insert(currentStack, kids[k])
						end
					end
					
					table.sort(currentStack, function(a, b)
							if a.currentCD == b.currentCD then
								return a.uid < b.uid
							end
					
							return a.currentCD > b.currentCD
						end)
					
					-- Then set the correct data for the i'nth stack
					for k, icon in pairs(currentStack) do
						icon.stack = i
						local iconOffset = 0
						local stackOffset = 0
						if iconSize * stackCount > height then
							local maxHeight = height - iconSize
							iconOffset = (maxHeight / (stackCount - 1)) * (k - 1)
							
							stackOffset = maxHeight / 2
						else
							iconOffset = iconSize * (k - 1)
							stackOffset = (iconSize * (stackCount - 1)) / 2
						end
						
						if grow == "DOWN" then
							iconOffset = -iconOffset
						elseif grow == "CENTER" then
							if stackCount == 1 then
								iconOffset = 0
							else
								iconOffset = iconOffset - stackOffset
							end
						end
						
						icon.sOffset = iconOffset
						
						local levelMultiplier = 5
						local baseLevel = k * levelMultiplier
						
						icon:SetFrameLevel(baseLevel)
						if icon.bd then
							icon.bd:SetFrameLevel(baseLevel + 1)
						end
						if icon.hl then
							icon.hl:SetFrameLevel(baseLevel + 2)
						end
					end
				end
			end
		elseif style == "OFFSET" then
			table.sort(f.validChildren, function(a, b)
				if a.currentCD == b.currentCD then
					return a.uid < b.uid
				end
				
				return a.currentCD > b.currentCD
			end)
			
			local offset = s["stacking"]["height"] / (count - 1)
			local height = s["stacking"]["height"]
			local grow = s["stacking"]["grow"]
			
			for k, child in ipairs(f.validChildren) do
				local o = (offset * k) - offset
				
				if grow == "DOWN" then
					o = -o
				elseif grow == "CENTER" then
					o = o - (height / 2)
				end
				
				child.sOffset = o
				
				child:SetFrameLevel(baseLevel * k)
				if child.bd then
					child.bd:SetFrameLevel(baseLevel * k + 1)
				end
				if child.hl then
					child.hl:SetFrameLevel(baseLevel * k + 2)
				end
			end
			
		elseif style == "STAGGERED" then
			
		else
			table.sort(f.validChildren, function(a, b)
				if a.currentCD == b.currentCD then
					return a.uid < b.uid
				end
				return a.currentCD > b.currentCD
			end)
		
			for k, child in ipairs(f.validChildren) do
				child:SetFrameLevel(baseLevel * k)
				if child.bd then
					child.bd:SetFrameLevel(baseLevel * k + 1)
				end
				if child.hl then
					child.hl:SetFrameLevel(baseLevel * k + 2)
				end
			end
		end
	else
		for k, child in ipairs(f.validChildren) do
			child.stack = 1
			child.sOffset = 0
			child:SetFrameLevel(baseLevel * k)
			
			if child.bd then
				child.bd:SetFrameLevel(baseLevel * k + 1)
			end
			if child.hl then
				child.hl:SetFrameLevel(baseLevel * k + 2)
			end
		end
	end
end

local seed = 20261112
local function rand(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n
end

local levelCalls = 0
local function Level(o, l)
	o.level = l
	levelCalls = levelCalls + 1
end

-- two identical sets of icons from one layout
local function Icons(specs)
	local list = {}
	for j, sp in ipairs(specs) do
		local ic = { uid = sp.uid, currentCD = sp.cd, cx = sp.x, cy = sp.y, ctRiding = sp.riding, stack = 0, sOffset = 999 }
		ic.GetCenter = function(self) return self.cx, self.cy end
		ic.SetFrameLevel = Level
		if sp.bd then ic.bd = { SetFrameLevel = Level } end
		if sp.hl then ic.hl = { SetFrameLevel = Level } end
		list[j] = ic
	end
	return list
end

-- icons along the lane: "overlap" (closer than an icon), "touch" (exactly one icon apart),
-- "apart", or "mixed" clusters of all of those plus icons on the same spot
local function Layout(vertical, n, pattern, size)
	local uids = {}
	for j = 1, n do uids[j] = j end
	for j = n, 2, -1 do
		local r = rand(j) + 1
		uids[j], uids[r] = uids[r], uids[j]
	end
	local specs, pos = {}, 100
	for j = 1, n do
		local gap
		if pattern == "overlap" then
			gap = rand(size)
		elseif pattern == "touch" then
			gap = size
		elseif pattern == "apart" then
			gap = size + 1 + rand(3 * size)
		else
			local r = rand(7)
			gap = (r == 0 and 0) or (r == 1 and rand(size)) or (r == 2 and size) or (r == 3 and size + 1)
				or (r == 4 and size * 2) or (r == 5 and size - 1) or rand(5 * size)
		end
		if j > 1 then pos = pos + gap end
		local across = rand(60) - 30
		local cd = (rand(4) == 0) and 30 or (rand(6000) / 100)
		specs[j] = { uid = uids[j], cd = cd, x = vertical and across or pos, y = vertical and pos or across,
			bd = rand(3) ~= 0, hl = rand(2) == 0, riding = pattern == "mixed" and rand(9) == 0 }
	end
	-- shuffled, so the sort by position has work to do
	for j = n, 2, -1 do
		local r = rand(j) + 1
		specs[j], specs[r] = specs[r], specs[j]
	end
	return specs
end

local function Same(a, b)
	-- a lone icon in a stack shorter than one icon: the old code gave it a NaN offset, the new code 0
	-- (a NaN on both sides is a mismatch: the new code must never make one)
	return a == b or (a ~= a and b == 0) or (b ~= b and a == 0)
end

local lane2, s2 = CDTL3_Lane_2, L.lane2
local function RunNew(list)
	lane2.validChildren = list
	lane2.childCount = #list
	lane2.triggerUpdate = false
	lane2.updateCount = 0
	lane2:SetAlpha(1)
	step(lane2)
end
local function RunOld(list)
	xpcall(OldCalcStacking, ERRH, { validChildren = list }, s2, #list)
end

s2.stacking.enabled = true
s2.stacking.style = "GROUPED"
local sizes = { 40, 30, 17 }
local layouts, mismatches, icons = 0, 0, 0
local oldCalls, newCalls, old40, new40 = 0, 0, 0, 0
local errorsBefore = #ERRORS
for _, vertical in ipairs({ false, true }) do
	for _, grow in ipairs({ "UP", "DOWN", "CENTER" }) do
		for _, pattern in ipairs({ "overlap", "touch", "apart", "mixed" }) do
			for n = 2, 40 do
				if pattern == "mixed" or n <= 6 or n % 6 == 4 then
					for _, heightKind in ipairs({ "under", "over" }) do
						local size = sizes[(n % 3) + 1]
						local height
						if heightKind == "over" then
							height = size * n + 1 + rand(20)
						else
							local r = rand(4)
							height = (r == 0 and 0) or (r == 1 and math.floor(size / 2)) or (r == 2 and size) or (size + rand(size * 2))
						end
						s2.vertical, s2.stacking.grow, s2.stacking.height, s2.icons.size = vertical, grow, height, size
						local specs = Layout(vertical, n, pattern, size)
						local A, B = Icons(specs), Icons(specs)
						levelCalls = 0
						RunOld(A)
						local oc = levelCalls
						levelCalls = 0
						RunNew(B)
						local nc = levelCalls
						oldCalls, newCalls = oldCalls + oc, newCalls + nc
						if n == 40 and pattern == "apart" then old40, new40 = old40 + oc, new40 + nc end
						layouts = layouts + 1

						local bad = nil
						for j = 1, n do
							local a, b = A[j], B[j]
							icons = icons + 1
							if a.uid ~= b.uid then
								bad = string.format("order differs at %d: uid %s vs %s", j, tostring(a.uid), tostring(b.uid))
							elseif not (Same(a.stack, b.stack) and Same(a.sOffset, b.sOffset) and Same(a.level, b.level)
									and Same(a.bd and a.bd.level, b.bd and b.bd.level) and Same(a.hl and a.hl.level, b.hl and b.hl.level)) then
								bad = string.format("uid %d: old stack %s off %s lv %s/%s/%s, new stack %s off %s lv %s/%s/%s", a.uid,
									tostring(a.stack), tostring(a.sOffset), tostring(a.level), tostring(a.bd and a.bd.level), tostring(a.hl and a.hl.level),
									tostring(b.stack), tostring(b.sOffset), tostring(b.level), tostring(b.bd and b.bd.level), tostring(b.hl and b.hl.level))
							end
							if bad then break end
						end
						if bad then
							mismatches = mismatches + 1
							if mismatches <= 5 then
								check(string.format("layout %s %s %s n=%d height %d size %d", vertical and "vertical" or "horizontal",
									grow, pattern, n, height, size), false, bad)
							end
						end
					end
				end
			end
		end
	end
end
check(string.format("%d layouts, %d icons: stack, sOffset and icon/bd/hl levels identical to the old code", layouts, icons),
	mismatches == 0 and #ERRORS == errorsBefore, string.format("mismatches %d, new lua errors %d", mismatches, #ERRORS - errorsBefore))
check("frame-level calls drop", newCalls < oldCalls, string.format("old %d, new %d in all; 40 icons apart: old %d, new %d", oldCalls, newCalls, old40, new40))

-- the look on the CurseForge demos: icons passing each other jump out, then settle back in the lane
s2.vertical, s2.stacking.grow, s2.stacking.height, s2.icons.size = false, "UP", 80, 40
local pass = Icons({ { uid = 1, cd = 20, x = 200, y = 0 }, { uid = 2, cd = 10, x = 210, y = 0 } })
RunNew(pass)
check("two icons passing: one stays in the lane, the other jumps out one icon",
	pass[1].stack == 1 and pass[2].stack == 1 and pass[1].sOffset + pass[2].sOffset == 40 and pass[1].sOffset * pass[2].sOffset == 0,
	string.format("offsets %s, %s", tostring(pass[1].sOffset), tostring(pass[2].sOffset)))
pass[2].cx = 300
RunNew(pass)
check("past each other: both back in the lane", pass[1].sOffset == 0 and pass[2].sOffset == 0 and pass[1].stack ~= pass[2].stack,
	string.format("offsets %s, %s", tostring(pass[1].sOffset), tostring(pass[2].sOffset)))
s2.stacking.enabled = false
s2.icons.size = 30
lane2.validChildren, lane2.childCount = {}, 0
CDTL3:RefreshLane(2)

---------------------------------------------------------------- 17. vertical lanes: the secondary marker
print("[secondary marker on vertical lanes " .. FLAVOR .. "]")
local l1, s1 = CDTL3_Lane_1, L.lane1
local function readableGCD(left)
	SPELLCD[8921] = { startTime = NOW - (1.5 - left), duration = 1.5, isEnabled = true, isActive = true, isOnGCD = true, modRate = 1 }
end
local function point(f) return f.__points[1] or {} end
local travel = s1.width - s1.tracking.stWidth
readableGCD(0.75)
step(l1)
local p = point(l1.st)
check("horizontal: marker 5 x 44, half way across", l1.st:GetWidth() == 5 and l1.st:GetHeight() == 44 and p[1] == "LEFT" and p[2] == travel / 2 and p[3] == 0 and l1.st:IsShown(),
	string.format("%s %s %s, %dx%d", tostring(p[1]), tostring(p[2]), tostring(p[3]), l1.st:GetWidth(), l1.st:GetHeight()))
s1.vertical = true
CDTL3:RefreshLane(1)
step(l1)
p = point(l1.st)
check("vertical: marker 44 x 5, half way up", l1.st:GetWidth() == 44 and l1.st:GetHeight() == 5 and p[1] == "BOTTOM" and p[2] == 0 and p[3] == travel / 2 and l1.st:IsShown(),
	string.format("%s %s %s, %dx%d", tostring(p[1]), tostring(p[2]), tostring(p[3]), l1.st:GetWidth(), l1.st:GetHeight()))
s1.tracking.secondaryReversed = true
step(l1)
p = point(l1.st)
check("vertical + Reverse: half way down from the top", p[1] == "TOP" and p[2] == 0 and p[3] == -travel / 2,
	string.format("%s %s %s", tostring(p[1]), tostring(p[2]), tostring(p[3])))
s1.vertical, s1.tracking.secondaryReversed = false, false
CDTL3:RefreshLane(1)

---------------------------------------------------------------- 13. the GCD marker while the GCD is hidden
if RETAILAPI then
	print("[GCD marker while the GCD's timing is hidden " .. FLAVOR .. "]")
	-- Retail has the GCD spell (61304); WoW: Forever doesn't (wow.lua's GetSpellCooldown gives nil for
	-- it there, as the game does), so there the marker reads the GCD from the player's last cast
	local HAS_GCD_SPELL = FLAVOR ~= "forever"
	local CAST = 880500
	SPELLINFO[CAST] = { "Test Bolt", 1 }
	KNOWN[CAST] = true
	local gcdLeft, castLeft = 0.9, 0.7
	local hidden = true		-- C_Secrets: cooldowns hidden (in combat)
	C_Secrets.ShouldCooldownsBeSecret = function() return hidden end
	C_Secrets.ShouldSpellCooldownBeSecret = function() return hidden end
	local reads = 0			-- GCD spell / last cast reads by the hidden path
	local realGetCD = C_Spell.GetSpellCooldown
	C_Spell.GetSpellCooldown = function(id)
		if id == 61304 or id == CAST then reads = reads + 1 end
		return realGetCD(id)
	end
	C_Spell.GetSpellCooldownDuration = function(id)
		reads = reads + 1
		if id == 61304 and HAS_GCD_SPELL then
			return { GetRemainingDuration = function() return S(gcdLeft) end, GetTotalDuration = function() return S(1.2) end }
		elseif id == CAST then
			return { GetRemainingDuration = function() return S(castLeft) end, GetTotalDuration = function() return S(1.2) end }
		end
	end
	local function hiddenGCD(on)
		SPELLCD[8921] = { startTime = S(on and NOW or 0), duration = S(on and 1.2 or 0), isEnabled = true, isActive = on, isOnGCD = on, modRate = 1 }
		if HAS_GCD_SPELL then
			SPELLCD[61304] = { startTime = S(on and NOW or 0), duration = S(on and 1.2 or 0), isEnabled = true, isActive = on, isOnGCD = on, modRate = 1 }
		end
		SPELLCD[CAST] = { startTime = S(on and NOW or 0), duration = S(on and 1.2 or 0), isEnabled = true, isActive = on, isOnGCD = on, modRate = 1 }
	end
	hiddenGCD(true)
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-gcd", CAST)
	local before = #ERRORS
	step(l1)
	local rider = l1.stRider
	p = point(l1.st)
	check("in combat: the marker shows", l1.st:IsShown() and rider ~= nil)
	local want = HAS_GCD_SPELL and gcdLeft or castLeft
	check(HAS_GCD_SPELL and "Retail: the GCD spell (61304) comes first, over the last cast" or "Forever (no 61304): it rides the last cast's GCD",
		rider ~= nil and IsS(rider:GetValue()) and Val(rider:GetValue()) == want, rider and tostring(Val(rider:GetValue())))
	if rider then
		local mn, mx = rider:GetMinMaxValues()
		local rp = point(rider)
		check("it sits on the fill edge of a StatusBar along the lane", p[1] == "LEFT" and p[2] == rider:GetStatusBarTexture() and p[3] == "RIGHT"
			and rp[1] == "LEFT" and rp[2] == l1 and rider:GetWidth() == travel and rider:GetHeight() == 1 and rider.__orient == "HORIZONTAL",
			string.format("%s/%s, bar %dx%d %s", tostring(p[1]), tostring(p[3]), rider:GetWidth(), rider:GetHeight(), tostring(rider.__orient)))
		check("the bar runs 0 to the base GCD (as out of combat) and holds the hidden time", mn == 0 and mx == 1.5 and IsS(rider:GetValue()) and Val(rider:GetValue()) == want,
			string.format("%s..%s value %s", tostring(mn), tostring(mx), tostring(Val(rider:GetValue()))))
		s1.vertical = true
		CDTL3:RefreshLane(1)
		step(l1)
		p, rp = point(l1.st), point(rider)
		check("vertical lane: the bar stands up, the marker rides its top edge", rider.__orient == "VERTICAL" and rider:GetWidth() == 1 and rider:GetHeight() == travel
			and rp[1] == "BOTTOM" and p[1] == "BOTTOM" and p[3] == "TOP", string.format("%s %s/%s", tostring(rider.__orient), tostring(p[1]), tostring(p[3])))
		s1.tracking.secondaryReversed = true
		step(l1)
		p, rp = point(l1.st), point(rider)
		check("vertical + Reverse: from the top down", rp[1] == "TOP" and p[1] == "TOP" and p[3] == "BOTTOM" and rider:GetReverseFill() == true)
		s1.vertical, s1.tracking.secondaryReversed = false, false
		CDTL3:RefreshLane(1)
	end
	s1.tracking.primaryTracking = "GCD"
	step(l1)
	local mn, mx = l1:GetMinMaxValues()
	check("primary GCD tracking in combat: the lane's fill takes the hidden time", mx == 1.5 and IsS(l1:GetValue()) and Val(l1:GetValue()) == want)
	-- every frame in combat: the hidden path hands pcall functions defined outside the caller, never a
	-- function written inside it (a closure made on every call in the game's Lua 5.1; fengari's Lua
	-- 5.3 reuses such closures, so the test looks at where each one is defined)
	local realPcall = pcall
	local calls, inner = 0, 0
	pcall = function(fn, ...)
		if type(fn) == "function" then
			local info, caller = debug.getinfo(fn, "S"), debug.getinfo(2, "S")
			if info and caller and tostring(info.source):find("Lanes.lua", 1, true) and info.source == caller.source then
				calls = calls + 1
				if info.linedefined > caller.linedefined and info.lastlinedefined <= caller.lastlinedefined then
					inner = inner + 1
				end
			end
		end
		return realPcall(fn, ...)
	end
	step(l1, 20)
	pcall = realPcall
	check("in combat, 20 frames: every pcall on the hidden path takes a named function (no per-frame closure)", calls > 0 and inner == 0,
		string.format("%d pcalls from Lanes.lua, %d of a function made inside its caller", calls, inner))
	check("no hidden value compared or used in maths", #ERRORS == before, string.format("new lua errors %d", #ERRORS - before))
	hiddenGCD(false)
	step(l1)
	mn, mx = l1:GetMinMaxValues()
	check("GCD over: marker hidden, the fill back on a plain range", not l1.st:IsShown() and mx == 1 and not IsS(l1:GetValue()))
	-- out of combat (timings readable), GCD not running: the hidden path isn't taken at all
	hidden = false
	SPELLCD[8921], SPELLCD[61304], SPELLCD[CAST] = nil, nil, nil
	reads = 0
	step(l1, 50)
	check("out of combat, no GCD: 50 frames read no GCD spell or last cast (the hidden path is skipped)", reads == 0, "reads " .. reads)
	readableGCD(0.75)
	step(l1)
	check("out of combat, GCD running: the readable timing still drives the marker", l1.st:IsShown() and point(l1.st)[2] == travel / 2 and reads == 0,
		string.format("%s reads %d", tostring(point(l1.st)[2]), reads))
	SPELLCD[8921] = nil
	s1.tracking.primaryTracking = "NONE"
	C_Spell.GetSpellCooldown = realGetCD
	C_Spell.GetSpellCooldownDuration = nil
	C_Secrets.ShouldCooldownsBeSecret, C_Secrets.ShouldSpellCooldownBeSecret = nil, nil
	CDTL3.lastPlayerCast = nil
end

---------------------------------------------------------------- 16. Secondary Tracking from the options
print("[Secondary Tracking switched on from the options " .. FLAVOR .. "]")
local laneOpts = CDTL3:GetLaneOptions()
local w0, h0 = lane2.st:GetSize()
check("lane 2 starts with None and an unsized marker", s2.tracking.secondaryTracking == "NONE" and w0 == 0 and h0 == 0)
local stOpt = Find(laneOpts.args.lane2, "secondaryTracking")
xpcall(stOpt.set, ERRH, {}, "GCD")
readableGCD(0.75)
step(lane2)
local w, h = lane2.st:GetSize()
check("GCD picked: the marker is sized (5 x 30), textured and showing", w == 5 and h == 30 and (lane2.st.bg.__tex or lane2.st.bg.__atlas) ~= nil and lane2.st:IsShown(),
	string.format("%dx%d shown %s", w, h, tostring(lane2.st:IsShown())))
xpcall(stOpt.set, ERRH, {}, "NONE")

---------------------------------------------------------------- 19. lane custom text with a live tag
print("[lane custom text with a live tag " .. FLAVOR .. "]")
local HP = 100
UnitHealth = function() return HP end
local ct = s1.customText.text1
ct.enabled, ct.text = true, "[p.hp.cur]"
ct.dtags, ct.ttags = CDTL3:ScanForDynamicTags(ct.text), CDTL3:ScanForTimeTags(ct.text)
CDTL3:RefreshLane(1)
check("refresh: the text reads 100", l1.c1:GetText() == "100", tostring(l1.c1:GetText()))
HP = 55
step(l1, 20)
check("health 55: the text follows within its poll rate", l1.c1:GetText() == "55", tostring(l1.c1:GetText()))
ct.enabled = false
CDTL3:RefreshLane(1)

---------------------------------------------------------------- 22. Override Autohide on an empty lane
print("[Override Autohide brings back an empty lane " .. FLAVOR .. "]")
local l3, s3 = CDTL3_Lane_3, L.lane3
instantFades(l3, s3.alpha)
g.autohide = true
s3.tracking.primaryTracking = "HEALTH"
s3.tracking.overrideAutohide = true
HP = 100
CDTL3:RefreshLane(3)
step(l3, 3)
check("empty lane, full health: faded out", l3:GetAlpha() == 0 and l3.childCount == 0, tostring(l3:GetAlpha()))
HP = 40
step(l3, 3)
check("health 40: the lane comes back", l3:GetAlpha() == s3.alpha and l3.overrideAutohide == true, tostring(l3:GetAlpha()))
HP = 100
step(l3, 3)
check("full health again: the empty lane fades out", l3:GetAlpha() == 0 and l3.overrideAutohide == false, tostring(l3:GetAlpha()))
g.autohide = false
s3.tracking.primaryTracking, s3.tracking.overrideAutohide = "NONE", false
CDTL3:RefreshLane(3)

---------------------------------------------------------------- 24. Split Count, whole numbers
print("[Split Count takes whole numbers " .. FLAVOR .. "]")
for i = 1, 3 do
	for _, key in ipairs({ "sSplitCount", "saSplitCount" }) do
		local o = Find(laneOpts.args["lane" .. i], key)
		check(string.format("lane %d %s: step 1", i, key), o and o.step == 1, o and tostring(o.step))
	end
end
-- typed into the options window: AceConfigDialog's own slider, its edit box and Enter
local AceGUI = LibStub("AceGUI-3.0")
local made = {}
local realCreate = AceGUI.Create
AceGUI.Create = function(self, kind, ...)
	local wd = realCreate(self, kind, ...)
	if kind == "Slider" then made[#made + 1] = wd end
	return wd
end
local ACD = LibStub("AceConfigDialog-3.0")
local function typeSplitCount(text)
	for i = #made, 1, -1 do
		local wd = made[i]
		local o = wd:GetUserData("option")
		if o and o.name == "Split Count" then
			wd.editbox:SetText(text)
			xpcall(wd.editbox.__scripts.OnEnterPressed, ERRH, wd.editbox)
			return true
		end
	end
	return false
end
-- SelectGroup redraws on the next frame; opening again draws the selected group now
local function openLane1()
	xpcall(function()
		ACD:Open("CDTL3")
		ACD:SelectGroup("CDTL3", "lanes", "lane1", "general")
		ACD:Open("CDTL3")
	end, ERRH)
end
s1.mode.type = "SPLIT"
s1.mode.split.count, s1.mode.splitAbs.count = 1, 1
openLane1()
local typed = typeSplitCount("1.5")
check("Split (%): typing 1.5 saves 2", typed and s1.mode.split.count == 2, string.format("found %s, saved %s", tostring(typed), tostring(s1.mode.split.count)))
s1.mode.type = "SPLIT_ABS"
openLane1()
typed = typeSplitCount("2.4")
check("Split (Time): typing 2.4 saves 2", typed and s1.mode.splitAbs.count == 2, string.format("found %s, saved %s", tostring(typed), tostring(s1.mode.splitAbs.count)))
AceGUI.Create = realCreate
xpcall(function() ACD:Close("CDTL3") end, ERRH)
-- a fraction saved before the slider took whole numbers works as the whole number the slider shows
local lane1Opts = laneOpts.args.lane1
for _, c in ipairs({ { "SPLIT_ABS", "splitAbs", "sa", 1.5, 2, 45, 120 }, { "SPLIT", "split", "s", 2.5, 3, 50, 100 } }) do
	local mode, key, pre, saved, whole, cur, total = c[1], c[2], c[3], c[4], c[5], c[6], c[7]
	s1.mode.type = mode
	local ss = s1.mode[key]
	ss.count = whole
	local want = CDTL3.CalcSplitPosition(cur, total, s1)
	ss.count = saved
	local got = CDTL3.CalcSplitPosition(cur, total, s1)
	check(string.format("%s saved as %s: icons placed as with %d splits", mode, tostring(saved), whole), got == want and got < 1,
		string.format("%s, want %s", tostring(got), tostring(want)))
	CDTL3:RefreshLane(1)
	local mt = s1.modeText
	check(string.format("  marks for %d splits", whole), mt.text2.used == true and mt.text3.used == true and mt.text4.used == (whole == 3))
	local o = Find(lane1Opts, pre .. "SplitCount")
	check(string.format("  the slider shows %d", whole), o and o.get({}) == whole, o and tostring(o.get({})))
	local p2, p3 = Find(lane1Opts, pre .. "Split2Position"), Find(lane1Opts, pre .. "Split3Position")
	check("  Split 2 controls shown, Split 3 " .. (whole == 3 and "shown" or "hidden"), p2.hidden({}) == false and p3.hidden({}) == (whole ~= 3))
	ss.count = 2
end
s1.mode.type = "LINEAR"
CDTL3:RefreshLane(1)

---------------------------------------------------------------- 25. Edit Mode ranges
if LEM_STUB then
	print("[Edit Mode ranges cover the options window's " .. FLAVOR .. "]")
	local function byDesc(tree, desc) return Find(tree, function(k, v) return v.desc == desc end) end
	local bars, ready = CDTL3:GetBarFrameOptions(), CDTL3:GetReadyOptions()
	local cases = {
		{ "CDTL3_Lane_1", "Width", byDesc(laneOpts, "Sets the width for the lane") },
		{ "CDTL3_Lane_1", "Height", byDesc(laneOpts, "Sets the height for the lane") },
		{ "CDTL3_Lane_1", "Icon Size", byDesc(laneOpts.args.lane1, "Sets the size of icons in lane 1") },
		{ "CDTL3_BarFrame_2", "Bar Width", byDesc(bars, "Sets the width of the bars") },
		{ "CDTL3_BarFrame_2", "Bar Height", byDesc(bars, "Sets the height of the bars") },
		{ "CDTL3_Ready_1", "Icon Size", byDesc(ready, "Sets the size of the frame, and icons in the ready frame") },
	}
	for _, c in ipairs(cases) do
		local setting
		for _, st in ipairs(EM[c[1]] or {}) do
			if st.name == c[2] then setting = st end
		end
		local o = c[3]
		local lo, hi = o and (o.min or o.softMin), o and (o.max or o.softMax)
		check(string.format("%s %s: Edit Mode %s..%s covers the options window's %s..%s", c[1], c[2], tostring(setting and setting.minValue),
			tostring(setting and setting.maxValue), tostring(lo), tostring(hi)),
			setting and o and setting.minValue == lo and setting.maxValue >= hi)
	end
	-- a lane 300 px thick shows and keeps 300 in Edit Mode
	local heightSetting
	for _, st in ipairs(EM["CDTL3_Lane_1"] or {}) do
		if st.name == "Height" then heightSetting = st end
	end
	s1.height = 300
	check("a 300 px lane reads 300 inside Edit Mode's range", heightSetting and heightSetting.get("Modern") == 300 and heightSetting.maxValue >= 300)
	s1.height = 44
end

print(string.format("RESULT lanes %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS))
