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

print(string.format("RESULT slots %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
