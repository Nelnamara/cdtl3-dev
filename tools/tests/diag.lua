-- Diagnostics and performance (feature panel of 12 Nov, cards 35, 36, 38): the failure log and /cdtl3 log,
-- /cdtl3 report, the Update rate, Pause while hidden and /cdtl3 perf. Real files, real AceDB and AceGUI.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME = PLAYER.guid

-- a value made from a hidden one is hidden too: the stub's SECRET prints as "<secret>", so a string holding
-- that text stands for a hidden string (Blizzard's issecretvalue says true for both)
issecretvalue = function(v)
	return rawequal(v, SECRET) or (type(v) == "string" and v:find("<secret>", 1, true) ~= nil)
end

-- the scroll frame template's scroll bar, which AceGUI's MultiLineEditBox looks up by name
local realCreateFrame = CreateFrame
CreateFrame = function(otype, name, parent, template, ...)
	local f = realCreateFrame(otype, name, parent, template, ...)
	if f:GetName() and type(template) == "string" and template:find("UIPanelScrollFrameTemplate", 1, true) then
		_G[f:GetName() .. "ScrollBar"] = realCreateFrame("Slider", f:GetName() .. "ScrollBar", f)
	end
	return f
end

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

local function entry(id, name, bCD)
	return { id = id, name = name, type = "spells", icon = 1, bCD = bCD, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
end
SPELLINFO[901] = { "Quick Spell", 1 }
SPELLINFO[902] = { "Short Spell", 1 }
KNOWN[901], KNOWN[902] = true, true
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = { tables = {
	spells = { entry(901, "Quick Spell", 3005), entry(902, "Short Spell", 30000) } } } } }

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
local D = CDTL3.DiagnosticsInternal
local sounds = 0
PlaySoundFile = function() sounds = sounds + 1; return true end
local function cast(id, dur)
	SPELLCD[id] = { startTime = NOW, duration = dur, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id, id)
end
local function live(name) return CDTL3:GetExistingCooldown(name, "spells") end
local function pname(fr) local p = fr:GetParent(); return p and p:GetName() or "nil" end
local function has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
local function chatSince(n)
	local out = {}
	for i = n + 1, #CHAT do out[#out + 1] = tostring(CHAT[i]) end
	return table.concat(out, "\n")
end

---------------------------------------------------------------- the new file in every TOC
print("[TOCs " .. FLAVOR .. "]")
local tocsOK, where = true, {}
for _, toc in ipairs({ "CooldownTimeline3.toc", "CooldownTimeline3_Camelot.toc", "CooldownTimeline3_Mainline.toc",
		"CooldownTimeline3_Mists.toc", "CooldownTimeline3_TBC.toc", "CooldownTimeline3_Vanilla.toc" }) do
	local files = {}
	for line in (HARNESS_READ(HARNESS_SRC .. "/" .. toc) or ""):gmatch("[^\r\n]+") do
		if not line:match("^##") and line:match("%S") then files[#files + 1] = line:match("^%s*(.-)%s*$") end
	end
	local at
	for i, f in ipairs(files) do if f == "CDTL3.lua" then at = i end end
	if not (at and files[at + 1] == "Diagnostics.lua") then tocsOK = false; where[#where + 1] = toc end
end
check("all six TOCs load Diagnostics.lua right after CDTL3.lua", tocsOK, table.concat(where, ", "))

---------------------------------------------------------------- card 36: the failure log
print("[36 failure log " .. FLAVOR .. "]")
local chat0 = #CHAT
ITEMCD = { [7001] = { SECRET, SECRET } }
local st = CDTL3:GetItemCooldown(7001)
check("hidden item cooldown: nil back, logged under GetItemCooldown", st == nil and CDTL3:FailureCount("GetItemCooldown") == 1,
	tostring(CDTL3:FailureCount("GetItemCooldown")))
local realInv = GetInventoryItemCooldown
GetInventoryItemCooldown = function() return SECRET, SECRET, 1 end
st = CDTL3:GetInventoryItemCooldown(13)
GetInventoryItemCooldown = realInv
check("hidden trinket cooldown: nil back, logged under GetInventoryItemCooldown", st == nil and CDTL3:FailureCount("GetInventoryItemCooldown") == 1)
AURAS = { HELPFUL = { { name = "Hidden Buff", spellId = 5555, duration = SECRET, icon = 1, applications = 0,
	expirationTime = NOW + 10, sourceUnit = "player" } } }
local a, unknown = CDTL3:AuraExists("player", "Hidden Buff")
AURAS = nil
check("aura with a hidden duration: unknown, logged under AuraExists", a == nil and unknown == true and CDTL3:FailureCount("AuraExists") == 1)
if RETAILAPI then
	SPELLCD[777] = { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
	CDTL3:GetSpellCooldown(777)
	SPELLCD[777] = nil
	check("hidden spell cooldown: logged under GetSpellCooldown", CDTL3:FailureCount("GetSpellCooldown") == 1)
	local realCharges = C_Spell.GetSpellCharges
	C_Spell.GetSpellCharges = function(id)
		return { maxCharges = 2, currentCharges = SECRET, cooldownStartTime = SECRET, cooldownDuration = SECRET }
	end
	local cc, mc = CDTL3:GetSpellCharges(778)
	C_Spell.GetSpellCharges = realCharges
	check("hidden charges: 0 of 2 back, logged under GetSpellCharges", cc == 0 and mc == 2 and CDTL3:FailureCount("GetSpellCharges") == 1)
else
	print("  (spell cooldown and charge reads aren't pcall'd on this client)")
end
local P = CDTL3.CombatTimers.internal
P.Error("attempt to index a nil value", "CombatTimers.Update")
check("combat timers' own failures land in the log", CDTL3:FailureCount("CombatTimers.Update") == 1)
local realGSC = C_Spell.GetSpellCooldown
C_Spell.GetSpellCooldown = function() error("attempt to compare a secret boolean value") end
P.ReadActive({}, 901, true)
C_Spell.GetSpellCooldown = realGSC
check("combat timers' isActive read: logged under CombatTimers.ReadActive", CDTL3:FailureCount("CombatTimers.ReadActive") == 1)

local before = CDTL3:FailureCount()
for _ = 1, 5000 do CDTL3:LogFailure("Test place", "same error") end
local lines, mine = CDTL3:LogLines(), {}
for _, l in ipairs(lines) do if has(l, "Test place") then mine[#mine + 1] = l end end
check("5000 repeats: counted 5000 times on one line", CDTL3:FailureCount() - before == 5000 and #mine == 1 and has(mine[1], "(x5000,"), mine[1])
for i = 1, 300 do CDTL3:LogFailure("Many", "error " .. i) end
lines = CDTL3:LogLines()
check("300 different lines: the last 200 kept, the oldest gone", #lines == 200 and has(lines[200], "error 300")
	and has(lines[1], "error 101") and CDTL3:FailureCount("Many") == 300, #lines .. " | " .. tostring(lines[1]))
CDTL3:LogFailure("Hidden error", SECRET)
check("a hidden error object is logged without its text", has(CDTL3:LogLines(1)[1], "Hidden error: (no error text)"), CDTL3:LogLines(1)[1])
check("the log prints nothing to chat", #CHAT == chat0, (#CHAT - chat0) .. " lines")
CDTL3:ChatCommand("log")
local text = D.boxText
check("/cdtl3 log: a copy box with the count by place and the lines", D.box ~= nil and has(text, "failures since login")
	and has(text, "By place: Test place 5000") and has(text, "GetItemCooldown"), text and text:sub(1, 120))
check("no hidden value in the log", not has(text, "<secret>"))
D.box:Release(); D.box = nil

---------------------------------------------------------------- card 35: /cdtl3 report
print("[35 report " .. FLAVOR .. "]")
AURAS = { HELPFUL = {
	{ name = "Arcane Intellect", spellId = 1459, duration = 3600, icon = 1, applications = 0, expirationTime = NOW + 3000, sourceUnit = "player" },
	{ name = SECRET, spellId = 1460, duration = 30, icon = 1, applications = 0, expirationTime = NOW + 20, sourceUnit = "player" },
} }
local L1 = CDTL3.db.profile.lanes["lane1"]
L1.width = 333
chat0 = #CHAT
CDTL3:ChatCommand("report")
text = D.boxText or ""
check("/cdtl3 report opens a copy box", D.box ~= nil and #text > 200, #text .. " characters")
check("version", has(text, "CDTL3 version: " .. CDTL3.version))
check("client and build", has(text, "Client: ") and has(text, "build 70000") and has(text, "interface " .. HARNESS_TOC))
check("combat timers status line", has(text, "Combat timers: "))
check("the aura report (/cdtl3 auras)", has(text, "AURA CHECK v" .. CDTL3.version) and has(text, "Arcane Intellect (1459)"))
check("a hidden aura is left out, no hidden value anywhere", has(text, "details hidden") and not has(text, "<secret>"))
check("the character's GUID is left out", not has(text, ME) and has(text, "guid: (known)"))
check("lanes and what they track", has(text, 'Lane 1 "Lane 1": on, mode LINEAR') and has(text, "secondary GCD")
	and has(text, "default lane for: spells, petspells, items, runes, customs, flights"))
check("non-default settings, with the default", has(text, "lanes.lane1.width = 333  (default 400)"))
check("settings at their defaults aren't listed (false ones too), nor the lane's own scale labels", not has(text, "lanes.lane1.height")
	and not has(text, "global.autohide") and not has(text, "global.firstRun") and not has(text, "modeText.text1.text")
	and has(text, "global.unlockFrames = false  (default true)"))
check("entry counts per type", has(text, "spells: 2 saved, 2 yours (0 of them ignored)") and has(text, "buffs: "))
check("recent log lines", has(text, "== Recent log ==") and has(text, "GetItemCooldown") and has(text, "(the whole log: /cdtl3 log)"))
check("memory", has(text, "Memory: "))
check("the issues link", has(text, CDTL3.supportlink))
check("nothing printed to chat", #CHAT == chat0, chatSince(chat0))
if HARNESS_ARG == "show" then print(text) end   -- node run.js <addon> <toc> diag.lua <toc file> show
local realLanes = D.Lanes
D.Lanes = function() error("a part broke") end
text = CDTL3:BuildReport()
D.Lanes = realLanes
check("a part that fails says so and the rest still comes out", has(text, "(this part failed:") and has(text, "== Memory =="))
D.box:Release(); D.box = nil
AURAS = nil
L1.width = 400

---------------------------------------------------------------- card 38: performance controls
print("[38 performance " .. FLAVOR .. "]")
local def = CDTL3.db.defaults.profile
check("Update rate defaults to Full", def.global.updateRate == 0 and g.updateRate == 0)
check("Pause while hidden defaults off on every lane", def.lanes.lane1.pauseHidden == false and def.lanes.lane2.pauseHidden == false
	and def.lanes.lane3.pauseHidden == false and L1.pauseHidden == false)
local ur = CDTL3:GetMainOptions().args.global.args.updateRate
check("Global: Update rate (Full, 30, 15 per second) with a tooltip", ur and ur.type == "select" and ur.values[0] == "Full"
	and ur.values[30] and ur.values[15] and type(ur.desc) == "string" and ur.get({}) == 0)
ur.set({}, 15)
check("the setting saves", g.updateRate == 15)
ur.set({}, 0)
local function find(t, key)
	if type(t) ~= "table" then return nil end
	if t.args and t.args[key] then return t.args[key] end
	for _, v in pairs(t.args or {}) do local r = find(v, key); if r then return r end end
end
local ph = find(CDTL3:GetLaneOptions().args.lane1, "pauseHidden")
check("Lanes › Lane 1: Pause while hidden toggle with a tooltip", ph and ph.type == "toggle" and type(ph.desc) == "string" and ph.get({}) == false)
ph.set({}, true)
check("the toggle saves per lane", L1.pauseHidden == true and CDTL3.db.profile.lanes.lane2.pauseHidden == false)
ph.set({}, false)

-- count the icon's slides, the bar's fills and the time text's redraws
cast(902, 30)
RunOnUpdate(1 / 60, 3)
local F = live("Short Spell")
local ic, bar, t2 = F.icon, F.bar.bar, F.icon.txt.text2
local slides, fills, texts = 0, 0, 0
local SP, SV, ST = ic.SetPoint, bar.SetValue, t2.SetText
rawset(ic, "SetPoint", function(s, ...) slides = slides + 1; return SP(s, ...) end)
rawset(bar, "SetValue", function(s, ...) fills = fills + 1; return SV(s, ...) end)
rawset(t2, "SetText", function(s, ...) texts = texts + 1; return ST(s, ...) end)
local function placedRight()
	local _, x = ic:GetPoint(1)
	local want = (L1.width - L1.icons.size) * (F.data.currentCD / F.data.baseCD)
	return type(x) == "number" and math.abs(x - want) < 1e-9, string.format("x=%s want=%.4f", tostring(x), want)
end

-- Full: every frame, exactly where the formula puts it
local allRight, frameSlides, frameFills, why = true, true, true, ""
for _ = 1, 60 do
	local s0, f0 = slides, fills
	RunOnUpdate(1 / 60, 1)
	local ok, d = placedRight()
	if not ok then allRight = false; why = d end
	if slides - s0 ~= 2 then frameSlides = false end   -- a horizontal lane sets its point twice
	if fills - f0 ~= 1 then frameFills = false end
end
check("Full: the icon slides every frame, to the position the lane's formula gives", allRight and frameSlides, why)
check("Full: the bar fills every frame", frameFills)

for _, rate in ipairs({ 30, 15 }) do
	g.updateRate = rate
	RunOnUpdate(1 / 60, 8)
	slides, fills, texts = 0, 0, 0
	local moved, right = 0, true
	for _ = 1, 120 do
		local s0 = slides
		RunOnUpdate(1 / 60, 1)
		if slides > s0 then
			moved = moved + 1
			if not placedRight() then right = false end
		end
	end
	local want = rate * 2
	check(rate .. " a second at 60 fps: the icon slides on " .. want .. " of 120 frames", math.abs(moved - want) <= 1, "moved on " .. moved)
	check(rate .. " a second: each slide lands where that frame's time puts it", right)
	check(rate .. " a second: the bar fills as often", math.abs(fills - want) <= 1, "fills=" .. fills)
	check(rate .. " a second: the time text still changes (over 10 s left: 10 a second at most)", texts >= 10 and texts <= 21, "texts=" .. texts)
end
g.updateRate = 0
rawset(t2, "SetText", nil)
SPELLCD[902] = nil   -- the 30 s cooldown ends (and leaves Ready) before the next part counts sounds
RunOnUpdate(1 / 60, 60)
RunOnUpdate(0.1, 80)

-- Ready and the ready sound land on the same frame at every rate, and with the lane paused
local function readyRun(rate, paused)
	g.updateRate = rate
	L1.pauseHidden = paused
	L1.alpha = paused and 0 or 1
	CDTL3:RefreshLane(1)
	sounds = 0
	cast(901, 3.005)
	local Q = live("Quick Spell")
	local qs = 0
	local QSP = Q.icon.SetPoint
	rawset(Q.icon, "SetPoint", function(s, ...)
		if pname(s) == "CDTL3_Lane_1" then qs = qs + 1 end   -- slides on the lane, not the Ready frame's layout
		return QSP(s, ...)
	end)
	local readyFrame, soundFrame
	for i = 1, 400 do
		RunOnUpdate(1 / 60, 1)
		if not readyFrame and pname(Q.icon) == "CDTL3_Ready_1_MF" then readyFrame = i end
		if not soundFrame and sounds > 0 then soundFrame = i end
		if readyFrame and soundFrame then break end
	end
	rawset(Q.icon, "SetPoint", nil)
	SPELLCD[901] = nil
	RunOnUpdate(0.1, 80)   -- out of Ready again
	return readyFrame, soundFrame, qs
end
local r0, s0 = readyRun(0, false)
local r30, s30 = readyRun(30, false)
local r15, s15 = readyRun(15, false)
local rp, sp, slidesPaused = readyRun(15, true)
check("Ready on the same frame at Full, 30 and 15 a second", r0 and r0 == r30 and r0 == r15,
	string.format("frames %s / %s / %s", tostring(r0), tostring(r30), tostring(r15)))
check("the ready sound on that same frame at every rate", s0 and s0 == r0 and s30 == r0 and s15 == r0,
	string.format("frames %s / %s / %s", tostring(s0), tostring(s30), tostring(s15)))
check("paused lane (alpha 0): Ready and its sound still on that frame", rp == r0 and sp == r0, string.format("%s / %s", tostring(rp), tostring(sp)))
check("paused lane: its icon never slid while it was hidden", slidesPaused == 0, "slides=" .. tostring(slidesPaused))

-- Pause while hidden: nothing moves while the lane is faded out; it catches up on the first frame back
g.updateRate = 0
L1.pauseHidden, L1.alpha = true, 0
CDTL3:RefreshLane(1)
cast(902, 30)
RunOnUpdate(1 / 60, 5)
texts = 0
rawset(t2, "SetText", function(s, ...) texts = texts + 1; return ST(s, ...) end)
slides, fills = 0, 0
local cd0 = F.data.currentCD
RunOnUpdate(1 / 60, 60)
check("lane faded out: no slides and no text redraws for 60 frames", slides == 0 and texts == 0, string.format("slides=%d texts=%d", slides, texts))
check("lane faded out: the timer still counts down", math.abs((cd0 - F.data.currentCD) - 1) < 0.05, string.format("%.3f", cd0 - F.data.currentCD))
check("bars aren't on lanes: the bar still fills", fills == 60, "fills=" .. fills)
L1.alpha = 1
CDTL3:RefreshLane(1)
slides, texts = 0, 0
RunOnUpdate(1 / 60, 1)
local okPlace, dPlace = placedRight()
check("lane shows again: on its first frame the icon is in place and its time text redone", slides > 0 and okPlace and texts == 1, dPlace .. " texts=" .. texts)
L1.pauseHidden = false
L1.alpha = 0
CDTL3:RefreshLane(1)
slides = 0
RunOnUpdate(1 / 60, 10)
check("Pause while hidden off (the default): a faded-out lane's icons keep sliding, as before", slides == 20, "slides=" .. slides)
L1.alpha = 1
CDTL3:RefreshLane(1)
rawset(t2, "SetText", nil)
rawset(ic, "SetPoint", nil)
rawset(bar, "SetValue", nil)

-- /cdtl3 perf
chat0 = #CHAT
GetAddOnMemoryUsage = function(name) return name == "CooldownTimeline3" and 456.7 or 0 end
UpdateAddOnMemoryUsage = function() end
CDTL3:ChatCommand("perf")
local out = chatSince(chat0)
check("/cdtl3 perf: the update rate and pause settings", has(out, "update rate: Full") and has(out, "pause while hidden: off"), out)
check("CPU: says it isn't measured while scriptProfile is off", has(out, "CPU: not measured") and has(out, "scriptProfile"))
check("memory", has(out, "Memory: 457 KB (CDTL3)"))
check("frame counts", has(out, "cooldown frames (each runs its own OnUpdate)") and has(out, "lanes, ") and has(out, "ready frames"))
local realBool, realCBool = GetCVarBool, C_CVar.GetCVarBool
GetCVarBool = function(k) return k == "scriptProfile" end
C_CVar.GetCVarBool = GetCVarBool
GetAddOnCPUUsage = function(name) return name == "CooldownTimeline3" and 1234 or 0 end
UpdateAddOnCPUUsage = function() end
GetFrameCPUUsage = function() return 2 end
g.updateRate = 15
L1.pauseHidden = true
chat0 = #CHAT
CDTL3:ChatCommand("perf")
out = chatSince(chat0)
check("scriptProfile on: CPU in ms, split by part", has(out, "CPU: 1234 ms since the reload") and has(out, "of it: cooldown frames"), out)
check("perf shows the throttle and the paused lane", has(out, "update rate: 15 per second") and has(out, "pause while hidden: lane 1"))
GetCVarBool, C_CVar.GetCVarBool = realBool, realCBool
GetAddOnCPUUsage, UpdateAddOnCPUUsage, GetFrameCPUUsage = nil, nil, nil
g.updateRate = 0
L1.pauseHidden = false

print(string.format("RESULT diag %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
