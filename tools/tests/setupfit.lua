-- Setup previews fitted to the setup (Start.lua, Quick Style > Setup; Design Handoff docs/looks/looks-start.html,
-- "Try it on screen first"), and Split (Time) marks past a lane's Max Time:
--   a. every preview makes a fresh set of sample icons fitted to that setup's lanes (sample mode on or not):
--      two on the short lane, three on the long lane, two on the buffs lane, each on its lane and inside its
--      Max Time; switching setups replaces them; they start again at Ready; Keep and Undo clear them; the
--      Test Panel's own settings never change
--   b. a setup sets each lane's Split (Time) marks inside its Max Time, in rising order; Undo, the copy a
--      reload undoes (ResolveStale) and Keep
--   c. on any Split (Time) lane a mark at or past Max Time isn't drawn and doesn't split the lane
--   node run.js <addon> <toc number> setupfit.lua <toc file>
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"

-- the owner's lane 1: Split (Time), marks 30 s, 2m and 10m (count 3), on a 15:00 lane
local OWN = { count = 3, s1v = 30, s1p = 0.2, s2v = 120, s2p = 0.45, s3v = 600, s3p = 0.7 }
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {
	lanes = { lane1 = { mode = { type = "SPLIT_ABS", splitAbs = { max = 900, count = OWN.count, s1v = OWN.s1v, s1p = OWN.s1p,
		s2v = OWN.s2v, s2p = OWN.s2p, s3v = OWN.s3v, s3p = OWN.s3p } } } },
} } }

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, (tostring(detail or ""):gsub("\n", " / "))))
end
local S = CDTL3.Start
local P = CDTL3.db.profile
local g = P.global
local function lane(n) return P.lanes["lane" .. n] end
local function pname(fr) local p = fr:GetParent(); return p and p:GetName() end
local HOLD = "CDTL3_Active_Icon_Holding"

-- sample icons on the frames: count per lane, every one, and the times on lane n ("48,80,160")
local function samples()
	local per, list = { 0, 0, 0 }, {}
	for _, cd in ipairs(CDTL3.cooldowns) do
		if cd.data.type == "testing" and pname(cd.icon) ~= HOLD then
			list[#list + 1] = cd
			local n = tonumber((pname(cd.icon) or ""):match("^CDTL3_Lane_(%d)$"))
			if n then per[n] = per[n] + 1 end
		end
	end
	return per, list
end
local function times(n)
	local _, list = samples()
	local t = {}
	for _, cd in ipairs(list) do
		if pname(cd.icon) == "CDTL3_Lane_" .. n then t[#t + 1] = cd.data.baseCD end
	end
	table.sort(t)
	for i, v in ipairs(t) do t[i] = string.format("%g", v) end
	return table.concat(t, ",")
end
-- every sample on its own lane (data and frame agree), inside that lane's Max Time, and looping
local function placed()
	local _, list = samples()
	for _, cd in ipairs(list) do
		local d = cd.data
		if pname(cd.icon) ~= "CDTL3_Lane_" .. tostring(d.lane) or not d.sampleLoop or d.baseCD >= lane(d.lane).mode.linear.max then
			return false, d.name .. " on " .. tostring(pname(cd.icon))
		end
	end
	return true
end
local function testPanel() return table.concat({ tostring(g.testingNumber), tostring(g.testingMinTime), tostring(g.testingMaxTime),
	tostring(g.testingLoop), tostring(g.testingType) }, "/") end
local function marks(n)
	local sa = lane(n).mode.splitAbs
	return sa.count, sa.s1v, sa.s2v, sa.s3v, sa.s1p, sa.s2p, sa.s3p
end
local function fits(n)
	local sa = lane(n).mode.splitAbs
	return sa.count == 3 and sa.s1v < sa.s2v and sa.s2v < sa.s3v and sa.s3v < sa.max and sa.s1p < sa.s2p and sa.s2p < sa.s3p and sa.s3p < 1
end
local function own(n)
	local c, v1, v2, v3, p1, p2, p3 = marks(n)
	return c == OWN.count and v1 == OWN.s1v and v2 == OWN.s2v and v3 == OWN.s3v and p1 == OWN.s1p and p2 == OWN.s2p and p3 == OWN.s3p
end
local function markText(n) local c, v1, v2, v3 = marks(n); return string.format("count %s: %s/%s/%s", tostring(c), tostring(v1), tostring(v2), tostring(v3)) end
local function deepcopy(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = deepcopy(v) end return o end

---------------------------------------------------------------- a. sample icons fitted to the setup
print("[a samples fitted to the setup " .. FLAVOR .. "]")
local panel0 = testPanel()
CDTL3:StartPreview()	-- sample mode already on: the player's own ten samples (10 s to 3:00)
local per0 = samples()
check("sample mode on first, with the Test Panel's samples", CDTL3.testing == true and per0[1] + per0[2] + per0[3] == g.testingNumber,
	table.concat(per0, "/"))

S.PreviewSetup("healer")
local per = samples()
check("Healer with sample mode already on: fresh samples, 3 on the big lane, 2 short, 2 buffs, nothing else on the frames",
	per[1] == 3 and per[2] == 2 and per[3] == 2 and #select(2, samples()) == 7, table.concat(per, "/") .. ", " .. #select(2, samples()) .. " on frames")
check("  big cooldowns 48 s, 1:20, 2:40 (the look's 16/27/53 % of 5:00)", times(1) == "48,80,160", times(1))
check("  short cooldowns 3 and 6 s (10 and 20 % of 30 s)", times(2) == "3,6", times(2))
check("  buffs 15 and 30 s on the 1:00 lane", times(3) == "15,30", times(3))
check("  each on its lane, inside its Max Time, looping", placed())
check("  the Test Panel's settings are untouched", testPanel() == panel0, testPanel())

S.PreviewSetup("dps")
per = samples()
check("switching to DPS replaces them: 3/2/2, the Healer's gone", per[1] == 3 and per[2] == 2 and per[3] == 2 and #select(2, samples()) == 7,
	table.concat(per, "/") .. ", " .. #select(2, samples()) .. " on frames")
check("  burst 29 s, 48 s, 1:36 inside 3:00", times(1) == "29,48,96", times(1))
check("  rotation 3 and 6 s, procs 15 and 30 s", times(2) == "3,6" and times(3) == "15,30", times(2) .. " | " .. times(3))
check("  each on its lane, inside its Max Time", placed())

S.PreviewSetup("starter")
per = samples()
check("Starter: three on its one 2:00 lane", per[1] == 3 and per[2] == 0 and per[3] == 0 and times(1) == "19,32,64",
	table.concat(per, "/") .. " " .. times(1))

-- the samples ran out (the Test Panel's Clear): a preview still makes its own
for _, cd in ipairs(CDTL3.cooldowns) do
	if cd.data.type == "testing" and pname(cd.icon) ~= HOLD then CDTL3:SendToHolding(cd); CDTL3:SendToBarHolding(cd) end
end
S.PreviewSetup("tank")
per = samples()
check("Tank after every sample was gone: 3/2/2 again", per[1] == 3 and per[2] == 2 and per[3] == 2, table.concat(per, "/"))
check("  each on its lane, inside its Max Time", placed())

-- they start again at Ready (Ready 1 for spells; buffs go to Ready 2, here switched off)
S.PreviewSetup("healer")
P.ready.ready2.enabled = false
-- a restart: back on its own lane, its time jumped up to its full length
local track = {}
for _, cd in ipairs(select(2, samples())) do
	track[#track + 1] = { cd = cd, n = cd.data.lane, last = cd.data.currentCD, again = 0, ready = false }
end
local function follow(dt, steps)
	for _ = 1, steps do
		RunOnUpdate(dt, 1)
		for _, t in ipairs(track) do
			local d = t.cd.data
			if pname(t.cd.icon) == "CDTL3_Ready_1_MF" then t.ready = true end
			if d.currentCD > t.last + 0.5 and pname(t.cd.icon) == "CDTL3_Lane_" .. t.n and math.abs(d.currentCD - d.baseCD) <= dt + 1e-6 then
				t.again = t.again + 1
			end
			t.last = d.currentCD
		end
	end
end
local function report(maxCD)
	local looped, n, how = 0, 0, {}
	for _, t in ipairs(track) do
		if t.cd.data.baseCD <= maxCD then
			n = n + 1
			if t.again > 0 then looped = looped + 1 end
			how[#how + 1] = string.format("%g s x%d", t.cd.data.baseCD, t.again)
		end
	end
	return looped, n, table.concat(how, ", ")
end
follow(0.1, 400)
local looped, n, how = report(30)
check("the 3, 6, 15 and 30 s samples reach Ready and start again on their lane (Test Panel Loop off)", n == 4 and looped == 4 and g.testingLoop == false, how)
local viaReady = false
for _, t in ipairs(track) do if t.cd.data.lane == 2 and t.ready then viaReady = true end end
check("  spells wait in Ready 1 first; buffs, with Ready 2 off, start again at once", viaReady)
follow(0.5, 360)
looped, n, how = report(1000)
local _, live = samples()
check("  after 3:20 all seven have started again and none is parked", n == 7 and looped == 7 and #live == 7, how .. "; " .. #live .. " on frames")
P.ready.ready2.enabled = true

S.UndoSetup()
per = samples()
check("Undo clears them; sample mode stays on (the preview didn't start it)", per[1] + per[2] + per[3] == 0 and #select(2, samples()) == 0
	and CDTL3.testing == true, table.concat(per, "/") .. " testing " .. tostring(CDTL3.testing))
local loose = 0
for _, cd in ipairs(CDTL3.cooldowns) do if cd.data.sampleLoop then loose = loose + 1 end end
check("  no sample keeps its loop", loose == 0, tostring(loose))
CDTL3:StopPreview()

S.PreviewSetup("healer")
check("a preview from sample mode off turns it on", CDTL3.testing == true and #select(2, samples()) == 7)
S.KeepSetup()
check("Keep clears them and ends the sample mode it started", CDTL3.testing == false and #select(2, samples()) == 0)
check("Test Panel settings still untouched", testPanel() == panel0, testPanel())

-- put the lanes back as the player had them (Keep kept the Healer)
S.PreviewSetup("dps"); S.UndoSetup()
g.setupKey = ""

---------------------------------------------------------------- b. a setup's marks fit its Max Time
print("[b setup marks inside Max Time " .. FLAVOR .. "]")
-- lane 1 is the owner's again: Keep above kept the Healer's marks, so set them back
do
	local sa = lane(1).mode.splitAbs
	sa.max, sa.count, sa.s1v, sa.s1p, sa.s2v, sa.s2p, sa.s3v, sa.s3p = 900, OWN.count, OWN.s1v, OWN.s1p, OWN.s2v, OWN.s2p, OWN.s3v, OWN.s3p
	for _, m in ipairs({ "linear", "linearAbs", "split" }) do lane(1).mode[m].max = 900 end
end
CDTL3:RefreshConfig()
check("lane 1 starts as the owner's: Split (Time) 30 s, 2m, 10m on 15:00", own(1) and lane(1).mode.splitAbs.max == 900, markText(1))

S.PreviewSetup("dps")
check("DPS (lane 1 up to 3:00): its marks are inside 3:00, rising", fits(1) and lane(1).mode.splitAbs.max == 180, markText(1))
check("  30s, 1m, 2m", select(2, marks(1)) == 30 and select(3, marks(1)) == 60 and select(4, marks(1)) == 120, markText(1))
check("  lanes 2 (30 s) and 3 (1:00) fit theirs too", fits(2) and fits(3), markText(2) .. " | " .. markText(3))
local function shownMarks(n)
	local st, out = lane(n).modeText, {}
	for i = 2, 4 do if st["text" .. i].used then out[#out + 1] = st["text" .. i].text end end
	return table.concat(out, " ")
end
check("  lane 1 draws 30s 1m 2m and ends at 3m, no 10m", shownMarks(1) == "30s 1m 2m" and lane(1).modeText.text5.text == "3m",
	shownMarks(1) .. " | " .. tostring(lane(1).modeText.text5.text))
local snapMarks = g.setupUndo and g.setupUndo.lanes[1].marks
check("  the copy saved for a reload holds my own marks", type(snapMarks) == "table" and snapMarks.s3v == 600 and snapMarks.s1p == OWN.s1p and snapMarks.count == 3)

S.UndoSetup()
check("Undo: my own 30 s, 2m, 10m and their positions exactly, on 15:00", own(1) and lane(1).mode.splitAbs.max == 900, markText(1))

S.PreviewSetup("healer")
check("Healer (5:00): 30s, 1m, 2m like the look", fits(1) and select(2, marks(1)) == 30 and select(3, marks(1)) == 60 and select(4, marks(1)) == 120, markText(1))
S.PreviewSetup("dps")
-- a reload while it waits: the session's preview is gone, the saved copy is undone at login
local saved = deepcopy(g.setupUndo)
CDTL3:StopPreview()
S.pending = nil
g.setupUndo = saved
local ok = S.ResolveStale()
check("ResolveStale (undo at the next login): my own marks exactly", ok and own(1) and lane(1).mode.splitAbs.max == 900 and g.setupUndo == nil, markText(1))

S.PreviewSetup("dps")
S.KeepSetup()
check("Keep keeps the fitted marks", fits(1) and select(4, marks(1)) == 120 and lane(1).mode.splitAbs.max == 180 and g.setupUndo == nil, markText(1))

---------------------------------------------------------------- c. a mark past Max Time on any Split (Time) lane
print("[c marks past Max Time " .. FLAVOR .. "]")
local s2 = lane(2)
local sa = s2.mode.splitAbs
s2.enabled = true
s2.mode.type = "SPLIT_ABS"
sa.max, sa.count, sa.s1v, sa.s1p, sa.s2v, sa.s2p, sa.s3v, sa.s3p = 180, 3, 30, 0.25, 120, 0.5, 600, 0.75
for i = 1, 5 do s2.modeText["text" .. i].enabled = true end
CDTL3:RefreshLane(2)
local L2 = _G["CDTL3_Lane_2"]
check("Split (Time) 30/120/600 on a 3:00 lane: no label for 10m", s2.modeText.text4.used == false and L2.t4:GetAlpha() == 0,
	tostring(s2.modeText.text4.text) .. " used " .. tostring(s2.modeText.text4.used))
check("  30s and 2m drawn, 3m at the end", s2.modeText.text2.used and s2.modeText.text3.used and L2.t2:GetAlpha() == 1 and L2.t3:GetAlpha() == 1
	and s2.modeText.text2.text == "30s" and s2.modeText.text3.text == "2m" and s2.modeText.text5.text == "3m")
check("  the saved values are untouched (the sliders still show 10m and count 3)", sa.s3v == 600 and sa.count == 3 and CDTL3:SplitCount(sa) == 3)

local td = { id = 1, name = "Mark Test", type = "testing", icon = 1, bCD = 134000, lane = 2, barFrame = 1, readyFrame = 1, enabled = true,
	ignored = false, usedBy = {} }
local f = CDTL3:CreateCooldown(CDTL3:GetUID(), "testing", td)
CDTL3:SendToLane(f)
RunOnUpdate(0.001, 1)
local function percent()
	local p = f.icon.__points[#f.icon.__points]
	return p and p[2] / (s2.width - s2.icons.size)
end
local p134 = percent()
check("a 134 s cooldown sits between the 2m mark and the end", p134 and p134 > 0.5 and p134 < 1 and math.abs(p134 - (0.5 + 0.5 * 14 / 60)) < 1e-3,
	string.format("%.4f of the lane", p134 or -1))
local worst = 0
for v = 1, 179, 2 do
	local p = CDTL3.CalcSplitPosition(v, v, s2)
	if p > worst then worst = p end
end
check("  nothing inside 3:00 is placed at or past the end", worst < 1, string.format("highest %.4f", worst))
check("  smooth into the end: 179 s at 0.99+", CDTL3.CalcSplitPosition(179, 179, s2) > 0.99, string.format("%.4f", CDTL3.CalcSplitPosition(179, 179, s2)))
sa.s1v, sa.s2v, sa.s3v = 200, 300, 600
CDTL3:RefreshLane(2)
check("every mark past Max Time: no mark drawn, a straight line (90 s halfway)", not s2.modeText.text2.used and not s2.modeText.text3.used and not s2.modeText.text4.used
	and math.abs(CDTL3.CalcSplitPosition(90, 90, s2) - 0.5) < 1e-9, string.format("%.4f", CDTL3.CalcSplitPosition(90, 90, s2)))
sa.s1v, sa.s2v, sa.s3v = 30, 120, 170
CDTL3:RefreshLane(2)
check("marks all inside Max Time: all three drawn and splitting as before", s2.modeText.text4.used == true
	and math.abs(CDTL3.CalcSplitPosition(150, 150, s2) - (0.5 + 0.25 * 30 / 50)) < 1e-9)
f.data.currentCD = -1
RunOnUpdate(0.1, 2)

check("no Lua errors", #ERRORS == base, tostring(#ERRORS - base))
print(string.format("RESULT setupfit %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
