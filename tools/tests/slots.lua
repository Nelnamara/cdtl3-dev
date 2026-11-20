-- CDTL3:SlotSettings / CDTL3:SlotFrame (CDTL3.lua): lane, bar frame and ready frame 1 to 3 by number.
-- 1, 2 and 3 give the profile's table and the frame; anything else (0, 4, nil, "1") gives nil, as the
-- old "if i == 1 ... elseif i == 3" chains did. Settings come from the live profile on every call.
-- Real files, real AceDB.
--   node run.js <addon> <toc number> slots.lua <toc file>
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end

print("[slots " .. FLAVOR .. "]")
local groups = {
	{ group = "lanes", key = "lane", frame = "CDTL3_Lane_" },
	{ group = "barFrames", key = "frame", frame = "CDTL3_BarFrame_" },
	{ group = "ready", key = "ready", frame = "CDTL3_Ready_" },
}

-- every frame made, so 1 to 3 all have one
for _, g in ipairs(groups) do
	for n = 1, 3 do
		CDTL3.db.profile[g.group][g.key .. n]["enabled"] = true
	end
end
CDTL3:CreateLanes()
CDTL3:CreateBarFrames()
CDTL3:CreateReadyFrames()

for _, g in ipairs(groups) do
	for n = 1, 3 do
		local s = CDTL3:SlotSettings(g.group, n)
		check(g.group .. " " .. n .. ": settings are profile." .. g.group .. "." .. g.key .. n,
			s ~= nil and rawequal(s, CDTL3.db.profile[g.group][g.key .. n]))
		local f = CDTL3:SlotFrame(g.group, n)
		check(g.group .. " " .. n .. ": frame is " .. g.frame .. n, f ~= nil and rawequal(f, _G[g.frame .. n]))
	end
	for _, n in ipairs({ 0, 4, -1, 1.5 }) do
		check(g.group .. " " .. n .. ": no settings, no frame", CDTL3:SlotSettings(g.group, n) == nil and CDTL3:SlotFrame(g.group, n) == nil)
	end
	check(g.group .. " nil: no settings, no frame", CDTL3:SlotSettings(g.group, nil) == nil and CDTL3:SlotFrame(g.group, nil) == nil)
	check(g.group .. " \"1\": no settings, no frame", CDTL3:SlotSettings(g.group, "1") == nil and CDTL3:SlotFrame(g.group, "1") == nil)
end

-- SlotOfParent: the name of an icon's or bar's parent frame -> its slot
local parents = {
	{ "CDTL3_Lane_1", "lanes", 1 }, { "CDTL3_Lane_2", "lanes", 2 }, { "CDTL3_Lane_3", "lanes", 3 },
	{ "CDTL3_BarFrame_1_MF", "barFrames", 1 }, { "CDTL3_BarFrame_2_MF", "barFrames", 2 }, { "CDTL3_BarFrame_3_MF", "barFrames", 3 },
	{ "CDTL3_Ready_1_MF", "ready", 1 }, { "CDTL3_Ready_2_MF", "ready", 2 }, { "CDTL3_Ready_3_MF", "ready", 3 },
}
for _, c in ipairs(parents) do
	local group, n = CDTL3:SlotOfParent(c[1])
	check("parent " .. c[1] .. " is " .. c[2] .. " " .. c[3], group == c[2] and n == c[3], tostring(group) .. " " .. tostring(n))
end
for _, name in ipairs({ "CDTL3_Lane_1_MF", "CDTL3_BarFrame_1", "CDTL3_Ready_1", "CDTL3_Ready_4_MF", "UIParent", "" }) do
	check("parent " .. name .. " is no slot", CDTL3:SlotOfParent(name) == nil)
end
check("parent nil is no slot", CDTL3:SlotOfParent(nil) == nil)

-- a profile switch: the next call reads the new profile's tables
local before = CDTL3:SlotSettings("lanes", 2)
CDTL3.db:SetProfile("Other")
local after = CDTL3:SlotSettings("lanes", 2)
check("after a profile switch: the new profile's lane 2", after ~= nil and not rawequal(after, before) and rawequal(after, CDTL3.db.profile.lanes["lane2"]))
check("  and its ready 3", rawequal(CDTL3:SlotSettings("ready", 3), CDTL3.db.profile.ready["ready3"]))
CDTL3.db:SetProfile("Default")
check("back on Default: the first table again", rawequal(CDTL3:SlotSettings("lanes", 2), before))

-- the refreshes still skip a number without a frame
local ok = pcall(function()
	CDTL3:RefreshLane(4)
	CDTL3:RefreshBarFrame(0)
	CDTL3:RefreshReady(4)
end)
check("RefreshLane(4), RefreshBarFrame(0), RefreshReady(4) do nothing", ok)

-- SlotParent: the frame that holds slot n's timers (the lane itself, the bar frame's or ready frame's _MF)
local parentNames = {
	lanes = { "CDTL3_Lane_1", "CDTL3_Lane_2", "CDTL3_Lane_3" },
	barFrames = { "CDTL3_BarFrame_1_MF", "CDTL3_BarFrame_2_MF", "CDTL3_BarFrame_3_MF" },
	ready = { "CDTL3_Ready_1_MF", "CDTL3_Ready_2_MF", "CDTL3_Ready_3_MF" },
}
for _, g in ipairs(groups) do
	for n = 1, 3 do
		local name = parentNames[g.group][n]
		local pf = CDTL3:SlotParent(g.group, n)
		check(g.group .. " " .. n .. ": parent frame is " .. name, pf ~= nil and rawequal(pf, _G[name]))
		check("  and it names that slot", CDTL3:SlotOfParent(pf and pf:GetName()) == g.group)
		if g.group ~= "lanes" then
			check("  and it is the frame's mf", rawequal(pf, CDTL3:SlotFrame(g.group, n).mf))
		end
	end
	for _, n in ipairs({ 0, 4, -1, 1.5 }) do
		check(g.group .. " " .. n .. ": no parent frame", CDTL3:SlotParent(g.group, n) == nil)
	end
	check(g.group .. " nil and \"1\": no parent frame", CDTL3:SlotParent(g.group, nil) == nil and CDTL3:SlotParent(g.group, "1") == nil)
end

-- Where a timer goes, for every slot number, as the old "if n == 1 ... elseif n == 3" chains sent it:
-- 1 to 3 to that slot while its frame exists (and, for Ready, is switched on), anything else to holding.
local cd = CDTL3:CreateCooldown(CDTL3:GetUID(), "spells", { id = 9901, name = "Slot Test", icon = 1, bCD = 30000,
	lane = 1, barFrame = 1, readyFrame = 1, enabled = true, ignored = false, highlight = false, pinned = false })
local d = cd.data
local function pname(fr) local p = fr:GetParent(); return p and p:GetName() or "nil" end
local numbers = { 0, 1, 2, 3, 4, -1, 1.5, "1", "nil" }
local function value(v) if v == "nil" then return nil end return v end
local function label(v) return type(v) == "string" and v ~= "nil" and ('"' .. v .. '"') or tostring(v) end
local function slotOf(v) return type(v) == "number" and v >= 1 and v <= 3 and v % 1 == 0 and v or nil end

for _, v in ipairs(numbers) do
	local n = slotOf(v)
	d["lane"] = value(v)
	CDTL3:SendToLane(cd)
	local want = n and ("CDTL3_Lane_" .. n) or "CDTL3_Active_Icon_Holding"
	check("lane " .. label(v) .. ": the icon goes to " .. want, pname(cd.icon) == want, pname(cd.icon))

	d["barFrame"] = value(v)
	CDTL3:SendToBarFrame(cd)
	want = n and ("CDTL3_BarFrame_" .. n .. "_MF") or "CDTL3_Bar_Holding"
	check("bar frame " .. label(v) .. ": the bar goes to " .. want, pname(cd.bar) == want, pname(cd.bar))

	d["readyFrame"] = value(v)
	local rf = n and _G["CDTL3_Ready_" .. n]
	if rf then rf.combatTimer = 99 end
	cd.icon.readyTime = -5
	CDTL3:SendToReady(cd)
	want = n and ("CDTL3_Ready_" .. n .. "_MF") or "CDTL3_Active_Icon_Holding"
	check("ready frame " .. label(v) .. ": the icon goes to " .. want, pname(cd.icon) == want, pname(cd.icon))
	if rf then
		local rs = CDTL3.db.profile.ready["ready" .. n]
		check("  waits that frame's Normal Duration and restarts its combat timer",
			cd.icon.readyTime == rs["nTime"] and rf.combatTimer == 0, tostring(cd.icon.readyTime) .. " " .. tostring(rf.combatTimer))
	else
		check("  and its ready time is left alone", cd.icon.readyTime == -5)
	end
end

-- a slot whose frame isn't made yet (the old "if CDTL3_Lane_2 then" failing): holding
for n = 1, 3 do
	local names = { "CDTL3_Lane_" .. n, "CDTL3_BarFrame_" .. n .. "_MF", "CDTL3_Ready_" .. n .. "_MF" }
	local saved = {}
	for i, name in ipairs(names) do saved[i] = _G[name]; _G[name] = nil end
	d["lane"], d["barFrame"], d["readyFrame"] = n, n, n
	CDTL3:SendToLane(cd)
	check("lane " .. n .. " not made yet: the icon goes to holding", pname(cd.icon) == "CDTL3_Active_Icon_Holding", pname(cd.icon))
	CDTL3:SendToBarFrame(cd)
	check("bar frame " .. n .. " not made yet: the bar goes to holding", pname(cd.bar) == "CDTL3_Bar_Holding", pname(cd.bar))
	CDTL3:SendToReady(cd)
	check("ready frame " .. n .. " not made yet: the icon goes to holding", pname(cd.icon) == "CDTL3_Active_Icon_Holding", pname(cd.icon))
	for i, name in ipairs(names) do _G[name] = saved[i] end
end

-- a switched-off Ready frame takes nothing
CDTL3.db.profile.ready["ready2"]["enabled"] = false
d["readyFrame"] = 2
CDTL3:SendToReady(cd)
check("ready frame 2 switched off: the icon goes to holding", pname(cd.icon) == "CDTL3_Active_Icon_Holding", pname(cd.icon))
CDTL3.db.profile.ready["ready2"]["enabled"] = true

-- offensives have their own holding frames
d["type"], d["lane"], d["barFrame"] = "offensives", 4, 4
CDTL3:SendToLane(cd)
CDTL3:SendToBarFrame(cd)
check("an offensive with no lane goes to the offensive icon holding", pname(cd.icon) == "CDTL3_Offensive_Icon_Holding", pname(cd.icon))
check("  and its bar to the offensive bar holding", pname(cd.bar) == "CDTL3_Offensive_Bar_Holding", pname(cd.bar))
d["type"] = "spells"

-- RefreshIcon's settings: an icon on a lane uses its lane's (0 counts as 1), one in a Ready frame its Ready
-- frame's, anything else lane 1's; seen through the icon size each one sets
for n = 1, 3 do
	CDTL3.db.profile.lanes["lane" .. n]["icons"]["size"] = 20 + n
	CDTL3.db.profile.ready["ready" .. n]["icons"]["size"] = 30 + n
end
local function iconSize(parentName, key, v)
	cd.icon:SetParent(_G[parentName])
	d[key] = value(v)
	CDTL3:RefreshIcon(cd)
	return (cd.icon:GetSize())
end
for _, v in ipairs(numbers) do
	local n = (v == 0) and 1 or slotOf(v)
	for k = 1, 3 do
		local want = 20 + (n or 1)
		local got = iconSize("CDTL3_Lane_" .. k, "lane", v)
		check("an icon on lane " .. k .. " with lane " .. label(v) .. " is size " .. want, got == want, tostring(got))
		want = n and (30 + n) or 21
		got = iconSize("CDTL3_Ready_" .. k .. "_MF", "readyFrame", v)
		check("an icon in ready frame " .. k .. " with ready frame " .. label(v) .. " is size " .. want, got == want, tostring(got))
	end
	local got = iconSize("CDTL3_Active_Icon_Holding", "lane", v)
	check("an icon in holding with lane " .. label(v) .. " is lane 1's size", got == 21, tostring(got))
end
d["lane"], d["readyFrame"] = 1, 1

-- RefreshBar's settings: a bar in a bar frame uses its bar frame's (0 shows as 1), anywhere else frame 1's
for n = 1, 3 do
	CDTL3.db.profile.barFrames["frame" .. n]["width"] = 100 + n
end
for _, v in ipairs({ 0, 1, 2, 3 }) do
	for k = 1, 3 do
		cd.bar:SetParent(_G["CDTL3_BarFrame_" .. k .. "_MF"])
		d["barFrame"] = v
		CDTL3:RefreshBar(cd)
		local want = 100 + ((v == 0) and 1 or v)
		check("a bar in bar frame " .. k .. " with bar frame " .. v .. " is " .. want .. " wide", cd.bar:GetWidth() == want, tostring(cd.bar:GetWidth()))
	end
end
for _, v in ipairs(numbers) do
	cd.bar:SetParent(_G["CDTL3_Bar_Holding"])
	d["barFrame"] = value(v)
	CDTL3:RefreshBar(cd)
	check("a bar in holding with bar frame " .. label(v) .. " is frame 1's width", cd.bar:GetWidth() == 101, tostring(cd.bar:GetWidth()))
end

-- the Transition bars threshold: the Max Time of the lane's mode (any slot), or none with no lane
local lane1 = CDTL3.db.profile.lanes["lane1"]
local modes = { LINEAR = "linear", LINEAR_ABS = "linearAbs", SPLIT = "split", SPLIT_ABS = "splitAbs" }
local maxes = { linear = 41, linearAbs = 42, split = 43, splitAbs = 44 }
local savedType, savedMax = lane1["mode"]["type"], {}
for key, m in pairs(maxes) do savedMax[key] = lane1["mode"][key]["max"]; lane1["mode"][key]["max"] = m end
cd.bar:SetParent(_G["CDTL3_BarFrame_1_MF"])
d["barFrame"], d["lane"] = 1, 1
for mode, key in pairs(modes) do
	lane1["mode"]["type"] = mode
	CDTL3:RefreshBar(cd)
	check("a " .. mode .. " lane: the transition threshold is its Max Time", cd.bar.transitionThreshold == maxes[key], tostring(cd.bar.transitionThreshold))
end
d["lane"] = 4
CDTL3:RefreshBar(cd)
check("no lane: no transition threshold", cd.bar.transitionThreshold == 10000000, tostring(cd.bar.transitionThreshold))
lane1["mode"]["type"] = savedType
for key, m in pairs(savedMax) do lane1["mode"][key]["max"] = m end
d["lane"] = 1

-- combat start and end set each Ready frame's combat timer (its Pinned Hide Time, then 0); a missing frame is skipped
for n = 1, 3 do
	CDTL3.db.profile.ready["ready" .. n]["pTime"] = 5 + n
	_G["CDTL3_Ready_" .. n].combatTimer = -1
end
local ready2 = CDTL3_Ready_2
_G["CDTL3_Ready_2"] = nil
CDTL3:PLAYER_REGEN_DISABLED()
check("combat start: ready 1 and 3 hold their Pinned Hide Time, ready 2 (not made) is skipped",
	CDTL3_Ready_1.combatTimer == 6 and CDTL3_Ready_3.combatTimer == 8 and ready2.combatTimer == -1)
_G["CDTL3_Ready_2"] = ready2
CDTL3:PLAYER_REGEN_DISABLED()
check("  with ready 2 made: 6, 7, 8", CDTL3_Ready_1.combatTimer == 6 and ready2.combatTimer == 7 and CDTL3_Ready_3.combatTimer == 8)
CDTL3:PLAYER_REGEN_ENABLED()
check("combat end: every ready frame's combat timer back to 0",
	CDTL3_Ready_1.combatTimer == 0 and ready2.combatTimer == 0 and CDTL3_Ready_3.combatTimer == 0)

print(string.format("RESULT slots %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
