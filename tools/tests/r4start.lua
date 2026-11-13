-- Getting started (feature panel of 12 Nov 2026, cards 3, 8, 10, 13, 15, 43; Start.lua):
-- Simple tab first, Help tab and the minimap tooltip, role setups tried on screen then kept or undone,
-- look cards (save, share, import, apply to one frame or all), the ~ before an estimated time, and
-- the three-step tour on a first install (the welcome window stays for existing players).
--   node run.js <addon> <toc number> r4start.lua <toc file> [fresh|existing]
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME = PLAYER.guid
local MODE = HARNESS_ARG == "existing" and "existing" or "fresh"

if MODE == "existing" then
	-- a player who already has CDTL3 (saved variables exist)
	CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {} } }
end

LoadTOC(HARNESS_TOCFILE)
-- LibDeflate's inflate doesn't round-trip under fengari: compression passes the data through (as share.lua)
local LD = LibStub("LibDeflate")
LD.CompressDeflate = function(_, s) return s end
LD.DecompressDeflate = function(_, s) return s end

Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, (tostring(detail or ""):gsub("\n", " / "))))
end
local function chatSince(n, text)
	for i = n + 1, #CHAT do
		if tostring(CHAT[i]):find(text, 1, true) then return true end
	end
	return false
end
local function clear(t) for k in pairs(t) do t[k] = nil end return t end
local S = CDTL3.Start
local P = function() return CDTL3.db.profile end
local g = CDTL3.db.profile.global
local function T() return CDTL3.db.profile.tables end
local function pname(fr) local p = fr:GetParent(); return p and p:GetName() end

---------------------------------------------------------------- card 10: first run
print("[10 first run " .. MODE .. " " .. FLAVOR .. "]")
do
	local welcome = _G["CDTL3_Firstrun"]
	if MODE == "fresh" then
		local tour = _G["CDTL3_Tour"]
		check("first install: the tour is up, the welcome window is not", tour and tour:IsShown() and not (welcome and welcome:IsShown()))
		check("  sample icons are running (Preview)", CDTL3.testing == true)
		check("  step 1 names the lane", tour.head:GetText() == "1 of 3, Lane" and tour.body:GetText():find("slide left", 1, true) ~= nil, tour.head:GetText())
		check("  step 1 has Next only", _G["CDTL3_Tour_Next"]:IsShown() and not _G["CDTL3_Tour_Lock"]:IsShown())
		check("  a badge on each frame", _G["CDTL3_Tour_Badge_1"]:IsShown() and _G["CDTL3_Tour_Badge_2"]:IsShown() and _G["CDTL3_Tour_Badge_3"]:IsShown())
		local anchor = tour.__points[1] and tour.__points[1][2]
		check("  the bubble sits on lane 1", anchor == _G["CDTL3_Lane_1"])
		xpcall(_G["CDTL3_Tour_Next"].__scripts.OnClick, ERRH, _G["CDTL3_Tour_Next"])
		check("step 2: Bars, bubble on bar frame 1", tour.head:GetText() == "2 of 3, Bars" and tour.__points[1][2] == _G["CDTL3_BarFrame_1"], tour.head:GetText())
		xpcall(_G["CDTL3_Tour_Next"].__scripts.OnClick, ERRH, _G["CDTL3_Tour_Next"])
		check("step 3: Ready, with Preview, Lock in place and Open settings", tour.head:GetText() == "3 of 3, Ready" and _G["CDTL3_Tour_Lock"]:IsShown()
			and _G["CDTL3_Tour_Settings"]:IsShown() and _G["CDTL3_Tour_Preview"]:IsShown() and not _G["CDTL3_Tour_Next"]:IsShown())
		check("  Preview reads Stop preview while it runs", _G["CDTL3_Tour_Preview"]:GetText() == "Stop preview")
		local pv = _G["CDTL3_Tour_Preview"]
		xpcall(pv.__scripts.OnClick, ERRH, pv)
		check("  Stop preview stops it and the button reads Preview", CDTL3.testing == false and pv:GetText() == "Preview")
		xpcall(pv.__scripts.OnClick, ERRH, pv)
		check("  and starts it again", CDTL3.testing == true)
		local lock = _G["CDTL3_Tour_Lock"]
		check("  frames are unlocked until Lock in place", g.unlockFrames == true)
		xpcall(lock.__scripts.OnClick, ERRH, lock)
		check("Lock in place: frames locked, tour gone, never again", g.unlockFrames == false and not tour:IsShown() and CDTL3.db.global.tourPending == nil)
		check("  the welcome window is marked seen", g.firstRun == false and g.previousVersion == CDTL3.version)
		check("  the badges are gone", not _G["CDTL3_Tour_Badge_1"]:IsShown())
		check("  its own sample icons are stopped", CDTL3.testing == false)
		check("  second try does nothing", S:StartTour() == false)
		CDTL3:ToggleFrameLock()
	else
		check("existing player: the welcome window opens, no tour", welcome and welcome:IsShown() and _G["CDTL3_Tour"] == nil)
		check("  nothing pending", CDTL3.db.global.tourPending == nil and S:TourDue() == false)
		welcome:Hide()
	end
end

---------------------------------------------------------------- defaults: no change until asked
print("[defaults " .. FLAVOR .. "]")
do
	check("no setup kept, no ~ unless switched on", g.setupKey == "" and g.estimateTilde == false)
	local e = CDTL3:ApplyEntryDefaults({ bCD = 15000 }, "spells")
	check("a new spell goes to the Filters default lane, as before", e.lane == g.spells.defaultLane, tostring(e.lane))
	check("the old Style list and Apply Style still exist (hidden)", CDTL3:GetFullOptions().args.style.args.apply.func ~= nil)
end

---------------------------------------------------------------- card 13: Simple tab
print("[13 simple tab " .. FLAVOR .. "]")
do
	local opts = CDTL3:GetFullOptions()
	local simple = opts.args.simple
	local first = true
	for k, v in pairs(opts.args) do
		if k ~= "simple" and type(v) == "table" and (v.order or 100) <= simple.order then first = false end
	end
	check("a Simple tab, ahead of every other tab", simple and simple.type == "group" and first, simple and simple.order)
	local a = simple.args
	check("what to show: Spells, Items, Buffs, Debuffs", a.spells and a.items and a.buffs and a.debuffs)
	a.buffs.set({}, false)
	check("  Buffs off: the Filters default follows", g.buffs.enabled == false and a.buffs.get({}) == false)
	a.buffs.set({}, true)
	check("  and on again", g.buffs.enabled == true)
	a.width.set({}, 333)
	check("Timeline width sets lane 1", P().lanes.lane1.width == 333 and a.width.get({}) == 333)
	check("  a slider that reaches every saved value (1 to 1000)", a.width.min == 1 and a.width.max == 1000)
	a.iconSize.set({}, 44)
	check("Icon size sets lane 1's icons", P().lanes.lane1.icons.size == 44 and a.iconSize.get({}) == 44)
	check("Ready sound is Ready 1's Normal Sound", a.readySound.get({}) == P().ready.ready1.nSound and a.readySound.dialogControl == "LSM30_Sound")
	a.readySound.set({}, "CDTL3 Tinks")
	check("  changed", P().ready.ready1.nSound == "CDTL3 Tinks")
	P().ready.ready1.nSound = "CDTL3 Click"
	check("  a Play button", a.playSound.type == "execute")
	local was = g.unlockFrames
	check("Lock frames button reads by state", a.lockFrames.name({}) == (was and "Lock frames" or "Unlock frames"))
	a.lockFrames.func({})
	check("  and toggles the lock", g.unlockFrames ~= was)
	a.lockFrames.func({})
	P().lanes.lane1.width = 400
	P().lanes.lane1.icons.size = 40
end

---------------------------------------------------------------- card 15: tooltip and Help
print("[15 minimap tooltip and Help " .. FLAVOR .. "]")
do
	local btn = CDTL3.minimapBtn
	local lines = {}
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
	local function tip() lines = {}; btn.__scripts.OnEnter(btn); return table.concat(lines, " | ") end
	local text = tip()
	local unlocked = g.unlockFrames
	check("tooltip: frames locked or not", text:find("Frames: |cffffd100" .. (unlocked and "unlocked" or "locked"), 1, true) ~= nil, text)
	local CT = CDTL3.CombatTimers
	check("  combat timers line only where they run (" .. tostring(CT and CT:Available()) .. ")", (text:find("Combat timers: ", 1, true) ~= nil) == (CT and CT:Available() or false), text)
	check("  left-click, right-click, Shift-click, Ctrl-click, drag", text:find("Left-click: Open settings", 1, true) and text:find("Right-click: Lock/unlock", 1, true)
		and text:find("Shift-click: Preview with sample icons", 1, true) and text:find("Ctrl-click: Help", 1, true) and text:find("Drag: Reposition", 1, true) and true)
	g.unlockFrames = not unlocked
	check("  the lock word follows the lock", tip():find("Frames: |cffffd100" .. (unlocked and "locked" or "unlocked"), 1, true) ~= nil)
	g.unlockFrames = unlocked
	GameTooltip.AddLine = nil

	local realCtrl = IsControlKeyDown
	IsControlKeyDown = function() return true end
	xpcall(btn.__scripts.OnClick, ERRH, btn, "LeftButton")
	IsControlKeyDown = realCtrl
	local ACD = LibStub("AceConfigDialog-3.0")
	local st = ACD:GetStatusTable("CDTL3")
	check("Ctrl-click opens the window on the Help tab", st and st.groups and st.groups.selected == "help", st and st.groups and tostring(st.groups.selected))

	local help = CDTL3:GetFullOptions().args.help
	local lines2 = CDTL3.helpLines
	local rows, runs = 0, 0
	for k in pairs(help.args) do
		if k:match("^row%d+$") then rows = rows + 1 elseif k:match("^run%d+$") then runs = runs + 1 end
	end
	check("a Help tab, last, listing every /cdtl3 command", help.order > 2005 and rows == #lines2 and runs == #lines2, rows .. " rows for " .. #lines2)
	check("  the same lines /cdtl3 help prints", help.args.row2.name({}):find("/cdtl3 " .. lines2[2][1], 1, true) and help.args.row2.name({}):find(lines2[2][2], 1, true) and true)
	check("  no Run for the settings window itself or help", help.args.run1.hidden() == true and help.args["run" .. #lines2].hidden() == true and help.args.run2.hidden() == false)
	local lockIdx
	for i, l in ipairs(lines2) do if l[1] == "lock / unlock" then lockIdx = i end end
	local before = g.unlockFrames
	help.args["run" .. lockIdx].func({})
	check("Run on lock / unlock flips the lock", g.unlockFrames ~= before)
	help.args["run" .. lockIdx].func({})
	check("  and back", g.unlockFrames == before)
	local n = #CHAT
	for i, l in ipairs(lines2) do
		if l[1]:find("^combattimers") then help.args["run" .. i].func({}) end
	end
	check("Run on combattimers runs the command (no errors)", #ERRORS == base)
end

---------------------------------------------------------------- card 8: ~ before the time
print("[8 estimate mark " .. FLAVOR .. "]")
do
	-- frames whose cooldown values error when touched: nothing here may read or compute with them
	local function fake(data, ct)
		return { data = setmetatable(data, { __index = function(_, k)
			if k == "currentCD" or k == "baseCD" then error("hidden value read: " .. k) end
		end }), ct = ct }
	end
	local combat = false
	local realCombat = InCombatLockdown
	InCombatLockdown = function() return combat end
	local custom = fake({ type = "spells", setCustomCD = true, customCDTime = 15 })
	local item = fake({ type = "items" })
	local plain = fake({ type = "spells", setCustomCD = false })
	local riding = fake({ type = "spells", setCustomCD = true, customCDTime = 15 }, { riding = true })
	local flight = fake({ type = "flights", estimated = true })

	check("off by default: no mark on anything", CDTL3:EstimateMark(custom) == "" and CDTL3:EstimateMark(flight) == "")
	g.estimateTilde = true
	if CDTL3.retailAPI then
		check("Custom CD Time spell: estimate", S.EstimateKind(custom) == "custom" and CDTL3:EstimateMark(custom) == "~")
		check("  an item out of combat: exact (readable)", S.EstimateKind(item) == nil and CDTL3:EstimateMark(item) == "")
		combat = true
		check("  an item in combat: estimate", S.EstimateKind(item) == "item" and CDTL3:EstimateMark(item) == "~")
		combat = false
		check("  a plain spell: exact", CDTL3:EstimateMark(plain) == "")
		check("  a spell riding the game's timer: exact whatever its Custom CD Time", CDTL3:EstimateMark(riding) == "")
		local buff = fake({ type = "buffs" })
		local CT = CDTL3.CombatTimers
		local realEst = CT and CT.Estimated
		if CT then CT.Estimated = function() return true end end
		check("  a buff the combat timers call an estimate", S.EstimateKind(buff) == "buff")
		if CT then CT.Estimated = realEst end
	else
		check("Classic: Custom CD Time and items are exact", S.EstimateKind(custom) == nil and CDTL3:EstimateMark(item) == "")
	end
	check("a flight estimate (every client)", S.EstimateKind(flight) == "flight" and CDTL3:EstimateMark(flight) == "~")

	-- the time text itself: "~" then the time, on icons and bars (both read [cd.time])
	local frame = { data = { type = "spells", setCustomCD = true, customCDTime = 15, currentCD = 38, estimated = true } }
	local shown = CDTL3:ConvertTextTimeTags("[cd.time]", frame)
	check("[cd.time] of an estimate starts with ~", tostring(shown):sub(1, 1) == "~" and tostring(shown):find("38", 1, true) ~= nil, tostring(shown))
	frame.data.estimated = nil
	frame.data.setCustomCD = false
	shown = CDTL3:ConvertTextTimeTags("[cd.time]", frame)
	check("  an exact one is plain", tostring(shown) == "38", tostring(shown))
	g.estimateTilde = false
	frame.data.estimated = true
	check("  switched off: plain again", tostring(CDTL3:ConvertTextTimeTags("[cd.time]", frame)) == "38")

	-- the tooltip line
	g.estimateTilde = true
	local lines = {}
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
	CDTL3:EstimateTooltip(flight)
	CDTL3:EstimateTooltip(plain)
	GameTooltip.AddLine = nil
	check("tooltip names the estimate (flight), none for an exact timer", #lines == 1 and lines[1]:find("~ Estimate", 1, true) == 1, table.concat(lines, "|"))
	g.estimateTilde = false

	local opts = CDTL3:GetFullOptions()
	local toggle = opts.args.global.args.estimateTilde
	check("Global tab toggle " .. (CDTL3.retailAPI and "shown" or "hidden on Classic"), toggle and toggle.hidden() == (not CDTL3.retailAPI))
	toggle.set({}, true)
	check("  it sets the mark", g.estimateTilde == true and toggle.get({}) == true)
	toggle.set({}, false)
	local legend = opts.args.lanes.args.lane1.args.general.args.estimateLegend
	check("Lanes > Lane 1 > General: a one-line legend", legend and legend.name:find("A ~ before a time means CDTL3's estimate", 1, true) ~= nil)
	InCombatLockdown = realCombat
end

---------------------------------------------------------------- card 3: setups
print("[3 setups " .. FLAVOR .. "]")
do
	local function spell(id, name, bcd, lane, t)
		return { id = id, name = name, type = t or "spells", icon = 1, bCD = bcd, lane = lane, barFrame = 1, readyFrame = 1,
			enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
	end
	clear(T().spells); clear(T().buffs)
	local big = spell(701, "Big Spell", 180000, 2)
	local short = spell(702, "Short Spell", 20000, 1)
	local buff = spell(703, "Some Buff", 20000, 2, "buffs")
	local theirs = spell(704, "Other Char Spell", 20000, 3)
	theirs.usedBy = { "Player-1-0000099" }
	table.insert(T().spells, big); table.insert(T().spells, short); table.insert(T().spells, theirs); table.insert(T().buffs, buff)
	local lane = function(n) return P().lanes["lane" .. n] end
	local thr0 = g.buffs.ignoreThreshold
	local sizes0 = lane(1).icons.size

	local n = #CHAT
	check("Quick Style has the four setups as buttons", CDTL3:GetFullOptions().args.style.args.setuphealer.func ~= nil and CDTL3:GetFullOptions().args.style.args.setupstarter ~= nil
		and CDTL3:GetFullOptions().args.style.args.setuptank ~= nil and CDTL3:GetFullOptions().args.style.args.setupdps ~= nil)
	CDTL3:GetFullOptions().args.style.args.setuphealer.func({})
	check("Healer: shown on the real frames with sample icons", CDTL3.testing == true and _G["CDTL3_Setup_Banner"]:IsShown())
	check("  banner says Previewing: Healer", _G["CDTL3_Setup_Banner"].text:GetText():find("Previewing: |cffffd100Healer|r", 1, true) ~= nil, _G["CDTL3_Setup_Banner"].text:GetText())
	check("  lane 1 shows up to 5:00, lane 2 up to 30 s, lane 3 up to 1:00", lane(1).mode.linear.max == 300 and lane(2).mode.linear.max == 30 and lane(3).mode.linear.max == 60
		and lane(1).mode.linearAbs.max == 300)
	check("  lane labels on screen", _G["CDTL3_Setup_Label_1"]:IsShown() and _G["CDTL3_Setup_Label_1"].text:GetText() == "Lane 1, Big cooldowns, up to 5:00"
		and _G["CDTL3_Setup_Label_2"].text:GetText() == "Lane 2, Short cooldowns, up to 30 s", _G["CDTL3_Setup_Label_2"].text:GetText())
	check("  my spells go to the lane for their length; another character's stay", big.lane == 1 and short.lane == 2 and buff.lane == 3 and theirs.lane == 3)
	check("  buffs' Ignore Threshold 300 s", g.buffs.ignoreThreshold == 300)
	local per = { 0, 0, 0 }
	for _, cd in ipairs(CDTL3.cooldowns) do
		if cd.data.type == "testing" and pname(cd.icon) ~= "CDTL3_Active_Icon_Holding" then per[cd.data.lane] = (per[cd.data.lane] or 0) + 1 end
	end
	check("  sample icons spread over the lanes", per[1] > 0 and per[2] > 0 and per[3] > 0, table.concat(per, "/"))
	check("  the Healer chip is the one in use", _G["CDTL3_Setup_Chip_healer"]:IsEnabled() == false and _G["CDTL3_Setup_Chip_tank"]:IsEnabled() == true)
	check("  nothing is kept yet", g.setupKey == "healer" and S.pending ~= nil)
	check("  Healer turns the Mana gauge on for its big-cooldowns lane only (the look shows mana)", lane(1).gauge.enabled == true and lane(2).gauge.enabled == false
		and lane(3).gauge.enabled == false and _G["CDTL3_Lane_1"].cdtl3Gauge and _G["CDTL3_Lane_1"].cdtl3Gauge:IsShown())
	check("  the preview is saved with the profile while it waits, so a reload can undo it", type(g.setupUndo) == "table" and g.setupUndo.setupKey == "" and g.setupUndo.lanes[1].gauge == false
		and #g.setupUndo.entries == 3 and g.setupUndo.profile == CDTL3.db:GetCurrentProfile())

	local chip = _G["CDTL3_Setup_Chip_starter"]
	xpcall(chip.__scripts.OnClick, ERRH, chip)
	check("Starter chip: one lane, bigger icons", lane(1).enabled and not lane(2).enabled and not lane(3).enabled and lane(1).icons.size == 48 and lane(1).mode.linear.max == 120)
	check("  everything on lane 1", big.lane == 1 and short.lane == 1 and buff.lane == 1)
	check("  Healer's buff threshold gone (started again from my own lanes)", g.buffs.ignoreThreshold == thr0, tostring(g.buffs.ignoreThreshold))
	check("  lanes 2 and 3 labels hidden", not _G["CDTL3_Setup_Label_2"]:IsShown() and not _G["CDTL3_Setup_Label_3"]:IsShown())

	xpcall(_G["CDTL3_Setup_Undo"].__scripts.OnClick, ERRH, _G["CDTL3_Setup_Undo"])
	check("Undo: my old lanes are back", lane(2).enabled and lane(3).enabled and lane(1).icons.size == sizes0 and lane(1).mode.linear.max == 120 and lane(2).mode.linear.max == 120)
	check("  my entries' lanes too", big.lane == 2 and short.lane == 1 and buff.lane == 2 and theirs.lane == 3)
	check("  banner and labels gone, the preview it started stopped, nothing kept", not _G["CDTL3_Setup_Banner"]:IsShown() and CDTL3.testing == false
		and g.setupKey == "" and S.pending == nil)
	check("  a chat line says so", chatSince(n, "Put your old lanes back."))
	check("  the gauge Healer turned on is off again, and nothing is left saved", lane(1).gauge.enabled == false and g.setupUndo == nil)

	S.PreviewSetup("tank")
	S.PreviewSetup("healer")
	S.KeepSetup()
	check("Keep: saved, banner gone, preview stopped", g.setupKey == "healer" and not _G["CDTL3_Setup_Banner"]:IsShown() and CDTL3.testing == false and big.lane == 1 and short.lane == 2)
	check("  and nothing is left to undo at the next login", g.setupUndo == nil)
	local a = CDTL3:ApplyEntryDefaults({ bCD = 15000 }, "spells")
	local b = CDTL3:ApplyEntryDefaults({ bCD = 90000 }, "spells")
	local c = CDTL3:ApplyEntryDefaults({ bCD = 15000 }, "buffs")
	check("  new entries follow it: short spell lane 2, long lane 1, buff lane 3", a.lane == 2 and b.lane == 1 and c.lane == 3, a.lane .. "/" .. b.lane .. "/" .. c.lane)
	S.PreviewSetup("dps")
	S.UndoSetup()
	check("  Undo after a later preview goes back to the kept Healer", g.setupKey == "healer" and lane(2).mode.linear.max == 30)
	-- put everything back
	S.PreviewSetup("starter"); S.UndoSetup()
	g.setupKey = ""
	lane(1).gauge.enabled = false
	lane(1).mode.linear.max, lane(2).mode.linear.max, lane(3).mode.linear.max = 120, 120, 120
	for k = 1, 3 do for _, m in ipairs({ "linearAbs", "split", "splitAbs" }) do lane(k).mode[m].max = 120 end end
	g.buffs.ignoreThreshold = thr0
	clear(T().spells); clear(T().buffs)
	check("setups: no Lua errors", #ERRORS == base, tostring(#ERRORS - base))
end

---------------------------------------------------------------- card 43: look cards
print("[43 look cards " .. FLAVOR .. "]")
do
	local style = CDTL3:GetFullOptions().args.style.args
	local function cards() return CDTL3:GetFullOptions().args.style.args end
	local lanes = function(n) return P().lanes["lane" .. n] end
	local looksList = CDTL3:GetLooks()
	clear(looksList)

	local nCards = 0
	for i = 1, 16 do if style["card" .. i].hidden() == false then nCards = nCards + 1 end end
	check("cards for the built-in looks, nothing hidden that exists (" .. nCards .. ")", nCards >= 3 and style.card1.name({}) == "CDTL3 Classic" and style.card2.name({}) == "Minimal")
	check("  a built-in card says Built in, with Apply and no Share", style.card2.args.kind.name({}) == "Built in" and style.card2.args.share.hidden() == true and style.card2.args.delete.hidden() == true)
	check("  a preview drawing on each", style.card2.args.preview.name({}):find("|T", 1, true) ~= nil)

	-- save the current look under a name
	lanes(1).border.size = 3
	lanes(1).fgClassColor = false
	lanes(1).bgTextureColor = { r = 0.2, g = 0.1, b = 0.4, a = 0.8 }
	local n = #CHAT
	style.saveCard.args.saveName.set({}, "Raid Night")
	local look = looksList[1]
	check("Save current look as: kept under its name", look and look.name == "Raid Night" and look.border.size == 3 and look.classColor == false and look.bgColor.b == 0.4)
	check("  chat line", chatSince(n, "Saved the look Raid Night."))
	check("  a card for it, Yours, with Share and Delete", cards()["card" .. (nCards + 1)].name({}) == "Raid Night" and cards()["card" .. (nCards + 1)].args.kind.name({}) == "Yours"
		and not cards()["card" .. (nCards + 1)].args.share.hidden())
	style.saveCard.args.saveName.set({}, "Minimal")
	check("  a built-in name is refused", #looksList == 1 and chatSince(n, "built-in look"))
	style.saveCard.args.saveName.set({}, "   ")
	check("  an empty name is refused", #looksList == 1 and chatSince(n, "Type a name"))

	-- share
	local slot = "card" .. (nCards + 1)
	cards()[slot].args.share.func({})
	local box = cards().shareBox
	local text = box.get({})
	check("Share: the string in a box to copy, !CDTL3:2! header", box.hidden() == false and text:sub(1, 9) == "!CDTL3:2!", tostring(text):sub(1, 20))
	check("  its title names the look", box.name({}):find("Raid Night", 1, true) ~= nil)
	local read = CDTL3:ReadLookString(text)
	check("  it reads back the same look", read and read.name == "Raid Night" and read.border.size == 3 and read.classColor == false and read.bgColor.r == 0.2)

	-- import: delete, then import the string
	cards()[slot].args.delete.func({})
	check("Delete: gone", #looksList == 0)
	cards().importLook.set({}, text)
	check("Import a look: back in the list", #looksList == 1 and looksList[1].name == "Raid Night" and looksList[1].border.size == 3)
	local before = P().lanes.lane1.width
	n = #CHAT
	cards().importLook.set({}, "not a string at all")
	check("  junk is refused with a line", #looksList == 1 and chatSince(n, "CDTL3 look string"))
	n = #CHAT
	cards().importLook.set({}, CDTL3:ExportString("LANE", 1))
	check("  a lane string isn't a look", #looksList == 1 and chatSince(n, "look string"))
	-- badly shaped looks are refused, nothing stored
	local bad = CDTL3:ExportString("LOOK", nil, { name = "Bad", border = { style = "None", size = "huge" } })
	check("  a look with a text size is refused", CDTL3:ReadLookString(bad) == nil)
	bad = CDTL3:ExportString("LOOK", nil, { name = "Bad", bgColor = { r = 9, g = 0, b = 0 } })
	check("  a colour out of range is refused", CDTL3:ReadLookString(bad) == nil)
	bad = CDTL3:ExportString("LOOK", nil, { name = string.rep("x", 100) })
	check("  a name that long is refused", CDTL3:ReadLookString(bad) == nil)
	bad = CDTL3:ExportString("LOOK", nil, { name = "Extra", evil = { 1, 2, 3 }, fg = "Solid" })
	local cleaned = CDTL3:ReadLookString(bad)
	check("  unknown fields are dropped", cleaned and cleaned.evil == nil and cleaned.fg == "Solid")

	-- a look string pasted into the Import/Export box is refused with where to put it
	n = #CHAT
	local before2 = CDTL3.db.profile.lanes.lane1.border.size
	CDTL3.db.profile.global.importMode = "ALL"
	CDTL3:ImportHandler(text)
	CDTL3.db.profile.global.importMode = "SETTINGS"
	check("the Import tab refuses a look string and says where it goes", chatSince(n, "Quick Style") and CDTL3.db.profile.lanes.lane1.border.size == before2)
	check("  its preview says no", CDTL3:ImportPreview(text) == false)

	-- apply to one frame, then everything
	for k = 1, 3 do lanes(k).border.size = 7 end
	P().barFrames.frame1.border.size = 7
	P().ready.ready1.border.size = 7
	cards().lookTarget.set({}, "lanes:2")
	local card = cards()["card" .. (nCards + 1)]
	check("Apply to lists Everything and every lane, bar frame and ready frame", cards().lookTarget.values()["all"] == "Everything" and cards().lookTarget.values()["lanes:3"] == "Lane 3"
		and cards().lookTarget.values()["barFrames:1"] == "Bar Frame 1" and cards().lookTarget.values()["ready:2"] == "Ready Frame 2")
	check("  one frame: no confirm", card.args.apply.confirm() == false)
	n = #CHAT
	card.args.apply.func({})
	check("Apply to Lane 2: only lane 2 takes it", lanes(2).border.size == 3 and lanes(1).border.size == 7 and lanes(3).border.size == 7, lanes(1).border.size .. "/" .. lanes(2).border.size .. "/" .. lanes(3).border.size)
	check("  chat line names the frame", chatSince(n, "Raid Night style to Lane 2"))
	check("  its colours came too", lanes(2).fgClassColor == false and lanes(2).bgTextureColor.b == 0.4)
	cards().lookTarget.set({}, "all")
	check("  Everything asks first", type(card.args.apply.confirm()) == "string")
	card.args.apply.func({})
	check("Apply to Everything: every lane, bar frame and ready frame", lanes(1).border.size == 3 and lanes(3).border.size == 3 and P().barFrames.frame1.border.size == 3 and P().ready.ready1.border.size == 3)

	-- a built-in card to one frame
	for k = 1, 3 do lanes(k).border.style = "CDTL3 Shadow" end
	cards().lookTarget.set({}, "lanes:1")
	cards().card2.args.apply.func({})
	check("Minimal on Lane 1 only", lanes(1).border.style == "CDTL3 Pixel" and lanes(2).border.style == "CDTL3 Shadow" and lanes(3).border.style == "CDTL3 Shadow")
	cards().lookTarget.set({}, "all")
	n = #CHAT
	CDTL3:ApplyPreset("minimal")
	check("/ApplyPreset as before: all frames, the old chat line", lanes(2).border.style == "CDTL3 Pixel" and chatSince(n, "Applied the Minimal style."))
	CDTL3:ApplyPreset("classic")
	check("CDTL3 Classic puts the shipped looks back", lanes(1).border.style == "CDTL3 Shadow" and lanes(1).fgClassColor == true)

	-- twelve at most
	clear(looksList)
	for i = 1, 12 do CDTL3:SaveLook("Look " .. i) end
	n = #CHAT
	cards().saveCard.args.saveName.set({}, "Look 13")
	check("twelve looks at most", #looksList == 12 and chatSince(n, "You can keep 12 looks"))
	CDTL3:SaveLook("Look 3")
	check("  saving a name again replaces it", #looksList == 12)
	local shown = 0
	for i = 1, 16 do if cards()["card" .. i].hidden() == false then shown = shown + 1 end end
	check("  every look has a card slot", shown == nCards + 12, tostring(shown))
	clear(looksList)

	-- the share round trip through every flavour of real header
	local looks = CDTL3:CaptureLook("Now")
	local s2 = CDTL3:ExportString("LOOK", nil, looks)
	check("ExportString LOOK uses the same !CDTL3:2! header as every share string", s2:sub(1, 9) == "!CDTL3:2!" and CDTL3:ReadLookString(s2).name == "Now")
	check("  the existing kinds still start the same", CDTL3:ExportString("LANE", 1):sub(1, 9) == "!CDTL3:2!" and CDTL3:ExportString("ALL"):sub(1, 9) == "!CDTL3:2!")
	check("looks: no Lua errors", #ERRORS == base, tostring(#ERRORS - base))
end

print(string.format("RESULT r4start %s %s: fails=%d lua errors=%d", MODE, FLAVOR, fails, #ERRORS - base))
