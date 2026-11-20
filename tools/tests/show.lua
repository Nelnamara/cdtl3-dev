-- Show, sound and first steps (feature panel of 12 Nov 2026, cards 1, 7, 11, 12, 16): per-spell
-- ready sounds, Flash when ready and a spoken name, Mute ready sounds and Play sound; Show per
-- lane, bar frame and ready frame (always, only in combat, boss fights only, dim instead of hide);
-- the Preview button and the minimap Shift-click; the unlock box's move-then-lock wording until
-- the first lock; the first flight's chat line. Real files, real AceDB.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME = PLAYER.guid

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

-- text to speech as every client documents it today: C_VoiceChat.SpeakText(voiceID, text, rate,
-- volume, overlap) and the player's voice settings in C_TTSSettings (a case below takes it away)
local SPOKEN = {}
local VOICE = 3
VOICES = { { voiceID = 7, name = "Voice" }, { voiceID = 3, name = "Other" } }	-- the installed voices; the option picks 3
local VoiceChat = {
	SpeakText = function(voiceID, text, rate, volume, overlap)
		SPOKEN[#SPOKEN + 1] = { voiceID = voiceID, text = text, rate = rate, volume = volume, overlap = overlap }
	end,
	GetTtsVoices = function() return VOICES end,
}
local TTSSettings = {
	GetVoiceOptionID = function() return VOICE end,
	GetSpeechRate = function() return 2 end,
	GetSpeechVolume = function() return 80 end,
}
C_VoiceChat, C_TTSSettings = VoiceChat, TTSSettings

local function entry(id, name, extra)
	local e = { id = id, name = name, type = "spells", icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local SPELLS = {
	[911] = { "Plain Spell" },
	[912] = { "Own Sound Spell", { ownSound = true, sound = "CDTL3 Tinks" } },
	[913] = { "Silent Spell", { ownSound = true, sound = "None" } },
	[914] = { "Flash Spell", { readyFlash = true } },
	[915] = { "Say Spell", { sayName = true } },
	[916] = { "Ready2 Spell", { readyFrame = 2 } },
	[917] = { "Lit Spell", { highlight = true } },
}
local list = {}
for id, s in pairs(SPELLS) do
	list[#list + 1] = entry(id, s[1], s[2])
	SPELLINFO[id] = { s[1], 1 }
	KNOWN[id] = true
end
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = { tables = { spells = list } } } }

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, (tostring(detail or ""):gsub("\n", " / "))))
end
local g = CDTL3.db.profile.global
local function chatSince(n, text)
	for i = n + 1, #CHAT do
		if tostring(CHAT[i]):find(text, 1, true) then return true end
	end
	return false
end

-- the stub's fade animations do nothing: finish them at once
local function instantFades(fr, alpha)
	if fr.animateOut then fr.animateOut.Play = function() fr:SetAlpha(0) end end
	if fr.animateIn then fr.animateIn.Play = function() fr:SetAlpha(alpha or 1) end end
end

---------------------------------------------------------------- card 12: move, then lock
print("[12 move-then-lock " .. FLAVOR .. "]")
do
	local box = CDTL3.unlockFrame
	local editMode = LibStub("LibEditMode", true) ~= nil
	local text = box.text:GetText() or ""
	check("fresh install: frames unlocked, the box is up", g.unlockFrames == true and box:IsShown())
	check("  it says to drag the frames, then click Lock", text:find("Drag the frames where you want them", 1, true) ~= nil
		and text:find("then click Lock", 1, true) ~= nil, text)
	check("  Edit Mode named only where CDTL3's frames are in Edit Mode (" .. (editMode and "yes" or "no") .. " here)",
		(text:find("Edit Mode can place them too", 1, true) ~= nil) == editMode, text)
	check("  the box grows to fit the extra lines", box:GetHeight() >= 96, tostring(box:GetHeight()))
	local btn = _G["CDTL3_Unlock_Frame_Button"]
	xpcall(btn.__scripts.OnClick, ERRH, btn)
	check("Lock: frames locked, box hidden, the first lock saved account-wide",
		g.unlockFrames == false and not box:IsShown() and CDTL3.db.global.lockedOnce == true)
	CDTL3:ToggleFrameLock()
	if box.__scripts.OnShow then box.__scripts.OnShow(box) end	-- the game runs OnShow when Show() shows it
	text = box.text:GetText() or ""
	check("unlocked again: the box is up with its plain wording", box:IsShown() and text == "CDTL3\nFrames currently unlocked\nDrag and drop to move", text)
	check("  back to its old size", box:GetWidth() == 180 and box:GetHeight() == 70, box:GetWidth() .. "x" .. box:GetHeight())
	CDTL3:ToggleFrameLock()
	check("locked again", g.unlockFrames == false)
end

local played = {}
PlaySoundFile = function(path) played[#played + 1] = path; return true end
local function P(name) return CDTL3.LSM:Fetch("sound", name) end
local function cast(id, dur)
	SPELLCD[id] = { startTime = NOW, duration = dur, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id, id)
end
local function live(name) return CDTL3:GetExistingCooldown(name, "spells") end
local function pname(fr) local p = fr:GetParent(); return p and p:GetName() or "nil" end
-- cast, then the game says ready: what played, and the frame
local function ready(id)
	played = {}
	cast(id, 30)
	RunOnUpdate(0.02, 5)
	SPELLCD[id] = nil
	RunOnUpdate(0.02, 55)
	return live(SPELLS[id][1])
end
local function leave() RunOnUpdate(0.1, 80) end	-- past every Normal Duration
local function playedOnly(name) return #played == 1 and played[1] == P(name) end
local function shown(fr) return tostring(#played) .. " played: " .. table.concat(played, ", ") end

---------------------------------------------------------------- card 1: ready sounds, flash, spoken name
print("[1 ready sounds, flash, spoken name " .. FLAVOR .. "]")
do
	local F = ready(911)
	check("no own sound: its Ready frame's Normal Sound, as before", F and pname(F.icon) == "CDTL3_Ready_1_MF" and playedOnly("CDTL3 Click"), shown())
	leave()
	F = ready(916)
	check("  in Ready 2: Ready 2's Normal Sound", F and pname(F.icon) == "CDTL3_Ready_2_MF" and playedOnly("CDTL3 Tinks"), shown())
	leave()
	F = ready(912)
	check("Own ready sound: its own sound, not the frame's", playedOnly("CDTL3 Tinks"), shown())
	leave()
	ready(913)
	check("Own ready sound None: silent", #played == 0, shown())
	leave()

	-- Flash when ready
	F = ready(914)
	local hl = F and F.icon.hl
	check("Flash when ready: the icon flashes in Ready 1 (the Flash Icon highlight)", hl and hl:IsShown() and hl.agPulse ~= nil
		and pname(F.icon) == "CDTL3_Ready_1_MF", hl and tostring(hl:IsShown()))
	leave()
	check("  back out of Ready: no flash", pname(F.icon) ~= "CDTL3_Ready_1_MF" and not F.icon.hl:IsShown(), pname(F.icon))
	local plain = live("Plain Spell")
	check("  an icon without it never flashes", not (plain.icon.hl and plain.icon.hl:IsShown()))

	-- Say its name when ready
	SPOKEN = {}
	F = ready(915)
	local said = SPOKEN[1]
	check("Say its name when ready: spoken once, with the player's voice, speed and volume", #SPOKEN == 1 and said.text == "Say Spell"
		and said.voiceID == VOICE and said.rate == 2 and said.volume == 80 and said.overlap == false,
		said and string.format("%d said, %s voice %s", #SPOKEN, tostring(said.text), tostring(said.voiceID)))
	check("  and its sound still plays", playedOnly("CDTL3 Click"), shown())
	leave()
	VOICE = nil
	SPOKEN = {}
	ready(915)
	check("no voice picked in the game's options: the first voice", #SPOKEN == 1 and SPOKEN[1].voiceID == 7, SPOKEN[1] and tostring(SPOKEN[1].voiceID))
	leave()
	VOICE = 99
	SPOKEN = {}
	ready(915)
	check("the picked voice is not installed: the first installed voice, not the stale ID", #SPOKEN == 1 and SPOKEN[1].voiceID == 7, SPOKEN[1] and tostring(SPOKEN[1].voiceID))
	leave()
	VOICE = 3
	local realVoices = VOICES
	VOICES = {}
	SPOKEN = {}
	local n0, e0v = CDTL3:FailureCount("Say its name"), #ERRORS
	ready(915)
	check("no voice installed: nothing spoken, no error, the reason in /cdtl3 log", #SPOKEN == 0 and #ERRORS == e0v
		and CDTL3:FailureCount("Say its name") == n0 + 1 and CDTL3:LogText():find("no text to speech voice", 1, true) ~= nil,
		tostring(CDTL3:FailureCount("Say its name")))
	leave()
	VOICES = realVoices

	-- the Filters controls
	local fa = CDTL3:GetFilterOptions().args.spells.args
	CDTL3.currentFilter["spells"] = "Plain Spell"
	CDTL3.currentFilterHidden["spells"] = false
	local e = CDTL3:GetSpellSettings("Plain Spell", "spells")
	check("Filters: all four controls are there, nothing ticked by default", fa.ownSound and fa.sound and fa.readyFlash and fa.sayName
		and fa.ownSound.get({}) == false and fa.readyFlash.get({}) == false and fa.sayName.get({}) == false)
	check("  each has a tooltip", fa.ownSound.desc ~= "" and fa.sound.desc ~= "" and fa.readyFlash.desc ~= "" and fa.sayName.desc ~= "")
	check("  Ready Sound hidden until Own ready sound is ticked", fa.sound.hidden({}) == true)
	fa.ownSound.set({}, true)
	check("ticking Own ready sound starts from its Ready frame's Normal Sound", e.ownSound == true and e.sound == "CDTL3 Click"
		and fa.sound.hidden({}) == false and fa.sound.get({}) == "CDTL3 Click", tostring(e.sound))
	played = {}
	fa.sound.set({}, "CDTL3 Rattle")
	check("picking a sound in Filters plays it once, so you know what it is", playedOnly("CDTL3 Rattle"), shown())
	played = {}
	fa.sound.set({}, "None")
	check("  picking None plays nothing", #played == 0, shown())
	fa.sound.set({}, "Blizzard: Raid Warning")
	check("  a Blizzard sound plays by its file data ID", #played == 1 and played[1] == 567397, shown())
	fa.sound.set({}, "CDTL3 Rattle")
	ready(911)
	check("  picked Rattle: Rattle plays", playedOnly("CDTL3 Rattle"), shown())
	leave()
	fa.ownSound.set({}, false)
	ready(911)
	check("  unticked: the frame's sound again, the pick kept for next time", playedOnly("CDTL3 Click") and e.sound == "CDTL3 Rattle", shown())
	leave()
	fa.readyFlash.set({}, true)
	F = ready(911)
	check("Flash when ready ticked in Filters: it flashes", F.icon.hl and F.icon.hl:IsShown())
	fa.readyFlash.set({}, false)
	check("  unticked while it waits in Ready: the flash stops at once", not F.icon.hl:IsShown())
	leave()
	check("Say its name shown where the game has text to speech", fa.sayName.hidden({}) == false)
	C_VoiceChat = nil
	check("  hidden where it doesn't", fa.sayName.hidden({}) == true and CDTL3:CanSpeak() == false)
	SPOKEN = {}
	local e0 = #ERRORS
	ready(915)
	check("  a saved Say on such a client: no speech, no error, the sound plays", #SPOKEN == 0 and #ERRORS == e0 and playedOnly("CDTL3 Click"), shown())
	leave()
	C_VoiceChat = VoiceChat
	CDTL3.currentFilter["spells"] = "<< Select >>"
	CDTL3.currentFilterHidden["spells"] = true

	-- the Ready tab: Mute ready sounds and Play sound
	local ra = CDTL3:GetReadyOptions().args
	check("Ready tab: Mute ready sounds, off by default, with a tooltip", ra.muteReadySounds and ra.muteReadySounds.get({}) == false
		and g.muteReadySounds == false and ra.muteReadySounds.desc ~= "")
	ra.muteReadySounds.set({}, true)
	SPOKEN = {}
	ready(911); local n1 = #played; leave()
	ready(912); local n2 = #played; leave()
	ready(915); local n3 = #played; leave()
	check("muted: no Ready frame sound, no own sound, nothing spoken", n1 == 0 and n2 == 0 and n3 == 0 and #SPOKEN == 0,
		string.format("%d %d %d, %d said", n1, n2, n3, #SPOKEN))
	F = ready(914)
	check("  a muted Flash when ready still flashes", F.icon.hl and F.icon.hl:IsShown())
	leave()
	local gen = ra.ready1.args.general.args
	played = {}
	gen.nSoundTest.func({})
	check("Ready 1 > Play sound (Normal): plays it, even muted", playedOnly("CDTL3 Click") and gen.nSoundTest.name == "Play sound", shown())
	played = {}
	gen.nSound.set({}, "CDTL3 Tinks")
	check("Ready 1 > Normal Sound: picking plays it once", playedOnly("CDTL3 Tinks"), shown())
	gen.nSound.set({}, "CDTL3 Click")
	played = {}
	gen.hSound.set({}, "None")
	check("Ready 1 > Highlight Sound: picking None plays nothing", #played == 0, shown())
	gen.hSound.set({}, "CDTL3 Rattle")
	check("  picking Rattle plays it once", playedOnly("CDTL3 Rattle"), shown())
	gen.hSound.set({}, "None")
	check("Blizzard sounds are registered, named Blizzard: <name>, with numeric file data IDs", (function()
		local n, bad = 0, nil
		for name, path in pairs(LibStub("LibSharedMedia-3.0"):HashTable("sound")) do
			if name:find("^Blizzard: ") then
				n = n + 1
				if type(path) ~= "number" then bad = name end
			end
		end
		return n >= 20 and not bad
	end)(), "")
	played = {}
	gen.hSoundTest.func({})
	check("  Play sound (Highlight) with Highlight Sound None: nothing", #played == 0, shown())
	CDTL3.db.profile.ready.ready1.hSound = "CDTL3 Tinks"
	played = {}
	gen.hSoundTest.func({})
	check("  with Tinks picked: Tinks", playedOnly("CDTL3 Tinks"), shown())
	CDTL3.db.profile.ready.ready1.hSound = "None"
	ra.muteReadySounds.set({}, false)
	ready(911)
	check("unmuted: sounds again", playedOnly("CDTL3 Click"), shown())
	leave()
end

---------------------------------------------------------------- card 7: Show modes
print("[7 show modes " .. FLAVOR .. "]")
do
	local L1, B1, R1 = CDTL3.db.profile.lanes.lane1, CDTL3.db.profile.barFrames.frame1, CDTL3.db.profile.ready.ready1
	local lane, bar, rdy = CDTL3_Lane_1, CDTL3_BarFrame_1, CDTL3_Ready_1
	instantFades(lane, L1.alpha); instantFades(bar, 1); instantFades(rdy, 1)
	local function refresh() CDTL3:RefreshLane(1); CDTL3:RefreshBarFrame(1); CDTL3:RefreshReady(1) end
	local function alphas() return string.format("lane %s bar %s ready %s", tostring(lane:GetAlpha()), tostring(bar:GetAlpha()), tostring(rdy:GetAlpha())) end
	local allDefault = true
	for _, grp in ipairs({ { CDTL3.db.profile.lanes, "lane" }, { CDTL3.db.profile.barFrames, "frame" }, { CDTL3.db.profile.ready, "ready" } }) do
		for i = 1, 3 do
			local s = grp[1][grp[2] .. i]
			if not (s.showMode == "GLOBAL" and s.dimInsteadOfHide == false and s.dimAlpha == 0.3) then allDefault = false end
		end
	end
	check("every lane, bar frame and ready frame starts on Use the global setting, no dim", allDefault)
	CDTL3.combat = false
	refresh()
	check("global Hide out of combat off: all shown out of combat, as before", lane:GetAlpha() == L1.alpha and bar:GetAlpha() == 1 and rdy:GetAlpha() == 1, alphas())
	local spy = 0
	local realLane = CDTL3.RefreshLane
	CDTL3.RefreshLane = function(...) spy = spy + 1; return realLane(...) end
	CDTL3:ApplyCombatVisibility()
	check("  nothing set to hide: the combat edge refreshes nothing, as before", spy == 0, tostring(spy))
	CDTL3.RefreshLane = realLane

	-- Only in combat, on the lane alone
	L1.showMode = "COMBAT"
	refresh()
	check("lane 1 Only in combat, out of combat: lane hidden, the others shown", lane:GetAlpha() == 0 and bar:GetAlpha() == 1 and rdy:GetAlpha() == 1, alphas())
	FireEvent("PLAYER_REGEN_DISABLED")
	check("  the pull shows it at once", CDTL3.combat and lane:GetAlpha() == L1.alpha, alphas())
	FireEvent("PLAYER_REGEN_ENABLED")
	check("  combat ends: hidden again", lane:GetAlpha() == 0, alphas())

	-- Always against the global Hide out of combat
	g.hideOutOfCombat = true
	L1.showMode = "ALWAYS"
	refresh()
	check("global Hide out of combat on, lane 1 Always: the lane stays, bar and ready frames (global) hide",
		lane:GetAlpha() == L1.alpha and bar:GetAlpha() == 0 and rdy:GetAlpha() == 0, alphas())
	g.hideOutOfCombat = false

	-- Boss fights only
	L1.showMode = "BOSS"
	FireEvent("PLAYER_REGEN_DISABLED")
	check("lane 1 Boss fights only, in combat with no boss: hidden", lane:GetAlpha() == 0, alphas())
	FireEvent("ENCOUNTER_START", 1, "Test Boss", 14, 20)
	check("  ENCOUNTER_START shows it", lane:GetAlpha() == L1.alpha, alphas())
	FireEvent("ENCOUNTER_END", 1, "Test Boss", 14, 20, 1)
	check("  ENCOUNTER_END hides it", lane:GetAlpha() == 0, alphas())
	FireEvent("ENCOUNTER_START", 2, "Other Boss", 14, 20)
	FireEvent("PLAYER_ENTERING_WORLD", false, false)
	check("  a zone change with no ENCOUNTER_END (released mid-fight): hidden", lane:GetAlpha() == 0 and CDTL3.inEncounter == false, alphas())
	local realUE = UnitExists
	UnitExists = function(u) if u == "boss1" then return true end return realUE(u) end
	FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	check("  a boss unit frame (boss1) shows it", lane:GetAlpha() == L1.alpha, alphas())
	UnitExists = realUE
	FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	check("  boss1 gone: hidden", lane:GetAlpha() == 0, alphas())
	local realIEP = IsEncounterInProgress
	IsEncounterInProgress = function() error("attempt to compare a secret boolean value") end
	local e0 = #ERRORS
	CDTL3:RefreshLane(1)
	check("  the game hiding the answer: no boss, no error", lane:GetAlpha() == 0 and #ERRORS == e0 and CDTL3:InBossFight() == false)
	IsEncounterInProgress = function() return true end
	CDTL3:RefreshLane(1)
	check("  the game saying an encounter is in progress (after a /reload mid-fight): shown", lane:GetAlpha() == L1.alpha, alphas())
	IsEncounterInProgress = realIEP
	FireEvent("PLAYER_REGEN_ENABLED")
	check("  out of combat, no boss: hidden", lane:GetAlpha() == 0, alphas())

	-- encounter events and loading screens refresh only the Boss fights only frames (global Hide out of combat alone: none)
	do
		local calls = { lane = 0, bar = 0, ready = 0 }
		local rl, rb, rr = CDTL3.RefreshLane, CDTL3.RefreshBarFrame, CDTL3.RefreshReady
		CDTL3.RefreshLane = function(...) calls.lane = calls.lane + 1; return rl(...) end
		CDTL3.RefreshBarFrame = function(...) calls.bar = calls.bar + 1; return rb(...) end
		CDTL3.RefreshReady = function(...) calls.ready = calls.ready + 1; return rr(...) end
		g.hideOutOfCombat = true
		FireEvent("ENCOUNTER_START", 1, "Test Boss", 14, 20)
		check("  only lane 1 is Boss fights only: an encounter start refreshes that lane and no bar or ready frame",
			calls.lane == 1 and calls.bar == 0 and calls.ready == 0, string.format("%d/%d/%d", calls.lane, calls.bar, calls.ready))
		FireEvent("PLAYER_ENTERING_WORLD", false, false)
		check("  a loading screen: the same", calls.lane == 2 and calls.bar == 0 and calls.ready == 0, string.format("%d/%d/%d", calls.lane, calls.bar, calls.ready))
		L1.showMode = "GLOBAL"
		calls.lane = 0
		FireEvent("ENCOUNTER_END", 1, "Test Boss", 14, 20, 1)
		check("  no frame on Boss fights only (global Hide out of combat alone): nothing refreshed", calls.lane == 0 and calls.bar == 0 and calls.ready == 0,
			string.format("%d/%d/%d", calls.lane, calls.bar, calls.ready))
		FireEvent("PLAYER_REGEN_ENABLED")
		check("  a combat edge still refreshes every frame", calls.lane >= 1 and calls.bar >= 1 and calls.ready >= 1, string.format("%d/%d/%d", calls.lane, calls.bar, calls.ready))
		CDTL3.RefreshLane, CDTL3.RefreshBarFrame, CDTL3.RefreshReady = rl, rb, rr
		g.hideOutOfCombat = false
		L1.showMode = "BOSS"
	end

	-- Dim instead of hide, on the bar frame and the ready frame
	L1.showMode = "GLOBAL"
	B1.showMode, B1.dimInsteadOfHide, B1.dimAlpha = "COMBAT", true, 0.4
	R1.showMode = "COMBAT"
	refresh()
	check("bar frame 1 Only in combat + Dim (0.4), ready frame 1 Only in combat: dimmed and hidden out of combat",
		lane:GetAlpha() == L1.alpha and bar:GetAlpha() == 0.4 and rdy:GetAlpha() == 0, alphas())
	FireEvent("PLAYER_REGEN_DISABLED")
	check("  in combat: both fully shown", bar:GetAlpha() == 1 and rdy:GetAlpha() == 1, alphas())
	FireEvent("PLAYER_REGEN_ENABLED")
	check("  out again: dimmed and hidden", bar:GetAlpha() == 0.4 and rdy:GetAlpha() == 0, alphas())
	g.autohide = true
	refresh()
	check("  with Auto-hide Frames, the empty dimmed bar frame still goes", bar:GetAlpha() == 0 and bar.childCount == 0, alphas())
	g.autohide = false
	refresh()

	-- what always wins
	CDTL3.testing = true
	refresh()
	check("test mode shows them", bar:GetAlpha() == 1 and rdy:GetAlpha() == 1, alphas())
	CDTL3.testing = false
	CDTL3:ToggleFrameLock()
	check("unlocked frames show", bar:GetAlpha() == 1 and rdy:GetAlpha() == 1, alphas())
	CDTL3:ToggleFrameLock()
	check("  locked again: dimmed and hidden", bar:GetAlpha() == 0.4 and rdy:GetAlpha() == 0, alphas())

	-- the options (Lanes > Lane 1 > General)
	local la = CDTL3:GetLaneOptions().args.lane1.args.general.args
	local v = la.showMode.values
	check("Lane 1 > General: Show with its four choices, each control with a tooltip", v.GLOBAL == "Use the global setting" and v.ALWAYS == "Always"
		and v.COMBAT == "Only in combat" and v.BOSS == "Boss fights only" and la.showMode.desc ~= "" and la.dimInsteadOfHide.desc ~= "" and la.dimAlpha.desc ~= "")
	check("  Dimmed alpha hidden until Dim instead of hide is ticked", la.dimAlpha.hidden({}) == true)
	la.showMode.set({}, "COMBAT")
	check("  Show > Only in combat: saved, the lane hides at once", L1.showMode == "COMBAT" and lane:GetAlpha() == 0, alphas())
	la.dimInsteadOfHide.set({}, true)
	la.dimAlpha.set({}, 0.5)
	check("  Dim instead of hide at 0.5: the lane dims at once", lane:GetAlpha() == 0.5 and la.dimAlpha.hidden({}) == false, alphas())
	la.showMode.set({}, "ALWAYS")
	check("  Always: shown, and Dim greyed out", lane:GetAlpha() == L1.alpha and la.dimInsteadOfHide.disabled({}) == true, alphas())
	local ba = CDTL3:GetBarFrameOptions().args.barFrame1.args.general.args
	local rd = CDTL3:GetReadyOptions().args.ready1.args.general.args
	check("  the same controls on Bar Frames and Ready", ba.showMode and ba.dimInsteadOfHide and ba.dimAlpha and rd.showMode and rd.dimInsteadOfHide and rd.dimAlpha)
	for _, s in ipairs({ L1, B1, R1 }) do s.showMode, s.dimInsteadOfHide, s.dimAlpha = "GLOBAL", false, 0.3 end
	refresh()
end

---------------------------------------------------------------- card 11: Preview
print("[11 preview " .. FLAVOR .. "]")
do
	local pv = CDTL3:GetMainOptions().args.global.args.preview
	local function tests()
		local onLane = 0
		for _, cd in ipairs(CDTL3.cooldowns) do
			if cd.data.type == "testing" and pname(cd.icon) ~= "CDTL3_Active_Icon_Holding" then onLane = onLane + 1 end
		end
		return onLane
	end
	check("Global tab, first: Preview with sample icons, with a tooltip", pv and pv.order == 1 and pv.type == "execute" and pv.name({}) == "Preview with sample icons" and pv.desc ~= "")
	g.hideOutOfCombat = true
	CDTL3.combat = false
	CDTL3:RefreshLane(1)
	instantFades(CDTL3_Lane_1, CDTL3.db.profile.lanes.lane1.alpha)
	check("  (Hide out of combat on: lane 1 hidden)", CDTL3_Lane_1:GetAlpha() == 0)
	pv.func({})
	check("click: test mode on, the Test Panel open, sample icons on the lanes", CDTL3.testing == true and CDTL3.testingFrame ~= nil
		and tests() == g.testingNumber, tostring(tests()))
	check("  the hidden lane shows them", CDTL3_Lane_1:GetAlpha() ~= 0, tostring(CDTL3_Lane_1:GetAlpha()))
	check("  the button now reads Stop preview", pv.name({}) == "Stop preview")
	pv.func({})
	check("Stop preview: test mode off, panel closed, samples cleared", CDTL3.testing == false and CDTL3.testingFrame == nil and tests() == 0, tostring(tests()))
	check("  lane 1 hidden again, the button back to Preview", CDTL3_Lane_1:GetAlpha() == 0 and pv.name({}) == "Preview with sample icons")
	g.hideOutOfCombat = false
	CDTL3:RefreshLane(1)

	CDTL3:StartPreview()
	CDTL3.testingFrame:Fire("OnClose")	-- the Test Panel's own close button
	check("closing the Test Panel ends the preview mode too", CDTL3.testing == false and CDTL3.testingFrame == nil and pv.name({}) == "Preview with sample icons")
	CDTL3:StopPreview()

	-- the minimap button
	local btn = CDTL3.minimapBtn
	local lines = {}
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
	local function tip() lines = {}; btn.__scripts.OnEnter(btn); return table.concat(lines, " | ") end
	check("minimap tooltip: Shift-click: Preview with sample icons", tip():find("Shift-click: Preview with sample icons", 1, true) ~= nil, tip())
	local realShift = IsShiftKeyDown
	IsShiftKeyDown = function() return true end
	xpcall(btn.__scripts.OnClick, ERRH, btn, "LeftButton")
	check("  Shift-click starts the preview", CDTL3.testing == true and tests() == g.testingNumber, tostring(tests()))
	check("  the tooltip then says Shift-click: Stop preview", tip():find("Shift-click: Stop preview", 1, true) ~= nil, tip())
	xpcall(btn.__scripts.OnClick, ERRH, btn, "LeftButton")
	check("  Shift-click again stops it", CDTL3.testing == false and tests() == 0)
	IsShiftKeyDown = realShift
	local locked = g.unlockFrames
	xpcall(btn.__scripts.OnClick, ERRH, btn, "LeftButton")
	check("  a plain left-click doesn't start it", CDTL3.testing == false)
	xpcall(btn.__scripts.OnClick, ERRH, btn, "RightButton")
	check("  right-click still locks and unlocks", g.unlockFrames ~= locked)
	xpcall(btn.__scripts.OnClick, ERRH, btn, "RightButton")
	GameTooltip.AddLine = nil
end

---------------------------------------------------------------- card 16: the first flight says whose timer it is
print("[16 first flight " .. FLAVOR .. "]")
do
	local FL = CDTL3.Flights
	local Pf = FL and FL.private
	local function fly(duration)
		Pf.pending = { key = "1-2", name = "Crossroads", duration = duration, estimated = true, len = 3000, delay = 0, at = GetTime() }
		Pf.Takeoff()
		RunOnUpdate(0.1, 5)
		Pf.Land()
		RunOnUpdate(0.1, 100)
	end
	check("no flight yet: nothing said", CDTL3.db.global.flightNoteShown == nil)
	local n = #CHAT
	fly(nil)
	check("a flight with no countdown: nothing said, still waiting for the first counted one", not chatSince(n, "flight timer")
		and CDTL3.db.global.flightNoteShown == nil)
	n = #CHAT
	fly(60)
	local said = 0
	for i = n + 1, #CHAT do
		if tostring(CHAT[i]):find("CDTL3's flight timer", 1, true) then said = said + 1 end
	end
	check("first counted flight: one chat line names CDTL3", said == 1, tostring(said))
	check("  and where to turn it off (the setting's real place)", chatSince(n, "Global tab, Flight timers")
		and CDTL3:GetMainOptions().args.global.args.flights.name == "Flight timers")
	check("  the destination in it", chatSince(n, "The countdown to Crossroads"))
	check("  saved account-wide", CDTL3.db.global.flightNoteShown == true)
	n = #CHAT
	fly(60)
	check("the next flight: nothing said", not chatSince(n, "flight timer"))
end

---------------------------------------------------------------- highlight effects (issue 13) and the finish effect
print("[highlight effects and finish effect " .. FLAVOR .. "]")
do
	local lane1 = CDTL3:SlotSettings("lanes", 1)
	local hs = lane1["icons"]["highlight"]
	local function anims(group)
		local out = {}
		for i, a in ipairs(group.__anims or {}) do out[i] = a end
		return out
	end
	local function eq(got, ...)
		local want = { ... }
		if not got or #got ~= #want then return false end
		for i = 1, #want do if got[i] ~= want[i] then return false end end
		return true
	end

	check("the highlight border texture is None out of the box", hs["border"]["style"] == "None", tostring(hs["border"]["style"]))
	cast(917, 600)
	local F = live("Lit Spell")
	-- style -> the group it starts, and what it is on
	local STYLES = {
		{ "PULSE", "agIconPulse", function(fr) return fr.icon end },
		{ "BOUNCE", "agBounce", function(fr) return fr.icon end },
		{ "SHAKE", "agShake", function(fr) return fr.icon.tx end },
		{ "SCALE", "agScale", function(fr) return fr.icon end },
		{ "FLASH", "agPulse", function(fr) return fr.icon.hl end },
		{ "BORDER_FLASH", "agBorderPulse", function(fr) return fr.icon.hl end },
		{ "GLOW", "agGlow", function(fr) return fr.icon.hl.glow end },
	}
	for _, st in ipairs(STYLES) do
		hs["style"] = st[1]
		CDTL3:RefreshAllIcons()
		local hl = F.icon.hl
		local g = hl and hl[st[2]]
		check(st[1] .. " draws with the border texture None: its animation runs, on the right frame",
			hl and hl:IsShown() and g and g.__running == true and g:GetParent() == st[3](F), g and tostring(g.__running))
		local made = g
		CDTL3:RefreshAllIcons()
		check("  a refresh plays the same group again (none made per refresh)", hl[st[2]] == made and made.__plays >= 2, tostring(made and made.__plays))
		CDTL3:RemoveHighlights(F.icon, lane1)
		check("  RemoveHighlights stops it", g.__running == false)
	end

	-- the values
	hs["style"] = "PULSE"; CDTL3:RefreshAllIcons()
	local a = anims(F.icon.hl.agIconPulse)[1]
	check("Pulse: icon alpha 0.2 to 1 in 0.5 s, bounce looping", a and eq(a.__set.SetFromAlpha, 0.2) and eq(a.__set.SetToAlpha, 1)
		and eq(a.__set.SetDuration, 0.5) and eq(F.icon.hl.agIconPulse.__set.SetLooping, "BOUNCE"))
	hs["style"] = "BOUNCE"; CDTL3:RefreshAllIcons()
	local up, down = table.unpack(anims(F.icon.hl.agBounce))
	check("Bounce: up 10 in 0.25 s, down 10 in 0.25 s, 0.25 s rest, repeating", up and down and eq(up.__set.SetOffset, 0, 10)
		and eq(down.__set.SetOffset, 0, -10) and eq(up.__set.SetDuration, 0.25) and eq(down.__set.SetDuration, 0.25)
		and eq(down.__set.SetEndDelay, 0.25) and eq(F.icon.hl.agBounce.__set.SetLooping, "REPEAT"))
	hs["style"] = "SHAKE"; CDTL3:RefreshAllIcons()
	local r1, r2 = table.unpack(anims(F.icon.hl.agShake))
	check("Shake: 10 degrees each way in 0.5 s legs, bounce looping, on the texture", r1 and r2 and r1.__atype == "Rotation"
		and eq(r1.__set.SetDegrees, 10) and eq(r2.__set.SetDegrees, -20) and eq(F.icon.hl.agShake.__set.SetLooping, "BOUNCE"))
	hs["style"] = "SCALE"; CDTL3:RefreshAllIcons()
	local s1, s2 = table.unpack(anims(F.icon.hl.agScale))
	check("Scale: to 1.2 in 0.25 s then 0.8 in 0.25 s, repeating", s1 and s2 and eq(s1.__set.SetScaleTo, 1.2, 1.2)
		and eq(s2.__set.SetScaleTo, 0.8, 0.8) and eq(s1.__set.SetDuration, 0.25) and eq(s2.__set.SetDuration, 0.25)
		and eq(F.icon.hl.agScale.__set.SetLooping, "REPEAT"))

	-- only one effect at a time: switching style stops the old one
	hs["style"] = "BOUNCE"; CDTL3:RefreshAllIcons()
	hs["style"] = "PULSE"; CDTL3:RefreshAllIcons()
	check("switching style stops the old effect", F.icon.hl.agBounce.__running == false and F.icon.hl.agIconPulse.__running == true)
	-- the highlight off: everything stops
	F.data["highlight"] = false
	CDTL3:RefreshAllIcons()
	check("Highlight unticked: its effect stops and the frame hides", F.icon.hl.agIconPulse.__running == false and not F.icon.hl:IsShown())
	F.data["highlight"] = true

	-- Border and Border Pulse with border None: a plain edge of four textures, no backdrop edge
	local function edgeShown(hl)
		local e = hl.edge
		if not e then return false end
		for i = 1, 4 do if not e[i]:IsShown() then return false end end
		return true
	end
	for _, style in ipairs({ "BORDER", "BORDER_FLASH" }) do
		hs["style"] = style; CDTL3:RefreshAllIcons()
		local hl = F.icon.hl
		local b = hl.__backdrop
		check(style .. " with border None draws a plain edge of four textures in the border colour, no backdrop edge",
			edgeShown(hl) and hl:IsShown() and not (b and b.edgeFile == CDTL3.LSM:Fetch("border", "CDTL3 Pixel")), b and tostring(b.edgeFile))
	end
	hs["style"] = "GLOW"; CDTL3:RefreshAllIcons()
	check("Glow: a gold halo frame, no plain edge, no game glow call", F.icon.hl.glow and F.icon.hl.glow:IsShown() and not edgeShown(F.icon.hl))
	hs["style"] = "PULSE"; CDTL3:RefreshAllIcons()
	check("  another style hides the halo and the edge", not F.icon.hl.glow:IsShown() and not edgeShown(F.icon.hl))
	hs["border"]["style"] = "CDTL3 Shadow"; hs["style"] = "BORDER"; CDTL3:RefreshAllIcons()
	check("  a chosen texture is used as before, with no plain edge", F.icon.hl.__backdrop.edgeFile == CDTL3.LSM:Fetch("border", "CDTL3 Shadow")
		and not edgeShown(F.icon.hl))
	hs["border"]["style"] = "None"

	-- a round Masque skin (Masque keeps its skin's shape in the button's _MSQ_CFG): round highlights
	local hl = F.icon.hl
	rawset(F.icon, "_MSQ_CFG", { Shape = "Circle" })
	hs["style"] = "BORDER"; CDTL3:RefreshAllIcons()
	local size = lane1["icons"]["size"]
	check("round skin: Border draws a round edge (Media/ring.tga) round the icon, no square edge", hl.roundEdge and hl.roundEdge:IsShown()
		and hl.roundEdge.__tex == CDTL3.IconFx.RING_TEX and hl.roundEdge.__w == size + 4 and not edgeShown(hl), hl.roundEdge and tostring(hl.roundEdge.__w))
	hs["style"] = "GLOW"; CDTL3:RefreshAllIcons()
	check("  Glow: two gold circles, no square bars, no round edge", hl.glow.roundInner:IsShown() and hl.glow.roundOuter:IsShown()
		and not hl.glow.inner[1]:IsShown() and not hl.roundEdge:IsShown())
	hs["style"] = "FLASH"; CDTL3:RefreshAllIcons()
	check("  Flash Icon: a white disc (Media/disc.tga), not a square", hl.tx.__tex == CDTL3.IconFx.DISC_TEX, tostring(hl.tx.__tex))
	rawset(F.icon, "_MSQ_CFG", { Shape = "Square" })
	hs["style"] = "GLOW"; CDTL3:RefreshAllIcons()
	check("a square skin: the square glow again", hl.glow.inner[1]:IsShown() and not hl.glow.roundInner:IsShown())
	hs["style"] = "BORDER"; CDTL3:RefreshAllIcons()
	check("  and the square edge", edgeShown(hl) and not hl.roundEdge:IsShown())
	rawset(F.icon, "_MSQ_CFG", nil)
	hs["style"] = "BORDER"
	CDTL3:RefreshAllIcons()

	-- the options: eight styles, Border Pulse's label
	local opt = CDTL3:GetFullOptions().args.lanes.args.lane1.args.icons.args.highlightStyle
	local keys = 0
	for _ in pairs(opt.values) do keys = keys + 1 end
	check("Lanes > Icons > Highlight Style offers eight styles, Border Flash saved as BORDER_FLASH, labelled Border Pulse",
		keys == 8 and opt.values.BORDER_FLASH == "Border Pulse" and opt.values.PULSE == "Pulse" and opt.values.SCALE == "Scale")
	check("  its tooltip names the Filters Highlight spells", opt.desc:find("Highlight in Filters", 1, true) ~= nil, opt.desc)
	local ropt = CDTL3:GetFullOptions().args.ready.args.ready1.args.icons.args.highlightStyle
	check("  the Ready frames offer the same", ropt and ropt.values.BOUNCE == "Bounce")
	check("  the menu lists them in the samples' order", opt.sorting and table.concat(opt.sorting, ",") == "GLOW,PULSE,BORDER,BORDER_FLASH,BOUNCE,SHAKE,SCALE,FLASH")
	CDTL3:RemoveHighlights(F.icon, lane1)
	F.data["currentCD"] = 0
	SPELLCD[917] = nil
	RunOnUpdate(0.02, 5)
	leave()

	-- finish effect
	local function poolFrames()
		local out = {}
		for _, fr in ipairs(GetAllFrames()) do
			local p = rawget(fr, "__parent")
			if rawget(fr, "pic") and rawget(fr, "ring") and p and p.__name == "CDTL3_Lane_1" then out[#out + 1] = fr end
		end
		return out
	end
	for n = 1, 3 do
		check("lane " .. n .. ": Finish effect is off by default", CDTL3:SlotSettings("lanes", n)["icons"]["finishFx"] == "NONE")
	end
	ready(911)
	check("None: nothing is drawn when an icon finishes", #poolFrames() == 0, tostring(#poolFrames()))
	leave()

	local fopt = CDTL3:GetFullOptions().args.lanes.args.lane1.args.icons.args.finishFx
	check("Lanes > Icons has Finish effect: None, Grow and fade, Gold ring",
		fopt and fopt.values.NONE == "None" and fopt.values.GROW == "Grow and fade" and fopt.values.RING == "Gold ring")
	check("  None is first in the menu", fopt and fopt.sorting and table.concat(fopt.sorting, ",") == "NONE,GROW,RING")
	fopt.set(nil, "GROW")
	check("  the choice is saved on the lane", lane1["icons"]["finishFx"] == "GROW")

	local Fn = ready(911)
	local pf = poolFrames()
	local fr = pf[1]
	check("Grow and fade: one pooled frame plays once as the icon reaches Ready", #pf == 1 and fr.group.__running == true and fr.group.__plays == 1
		and fr:IsShown(), tostring(#pf))
	check("  at the lane's Ready end (left, an icon at 0 percent), sized as the icon", fr and fr.__points[1][1] == "LEFT" and fr.__points[1][2] == fr:GetParent()
		and fr.__w == lane1["icons"]["size"], fr and tostring(fr.__points[1] and fr.__points[1][1]))
	check("  grows to 2.2 and fades to 0 in 0.5 s, the icon's picture shown, no ring", fr.pic:IsShown() and not fr.ring:IsShown()
		and eq(fr.scale.__set.SetScaleTo, 2.2, 2.2) and eq(fr.fade.__set.SetFromAlpha, 1) and eq(fr.fade.__set.SetToAlpha, 0)
		and eq(fr.fade.__set.SetDuration, 0.5) and eq(fr.scale.__set.SetDuration, 0.5))
	check("  the icon went on to its Ready frame as before", Fn and pname(Fn.icon) == "CDTL3_Ready_1_MF")
	fr.group.__scripts.OnFinished(fr.group)
	check("  when it ends the frame hides", not fr:IsShown())
	leave()

	lane1["reversed"] = true
	ready(911)
	check("Reversed lane: plays at the right end", poolFrames()[2] and poolFrames()[2].__points[1][1] == "RIGHT")
	leave()
	lane1["reversed"] = false; lane1["vertical"] = true
	ready(911)
	check("Vertical lane: plays at the bottom end; reversed, the top", poolFrames()[3] and poolFrames()[3].__points[1][1] == "BOTTOM")
	leave()
	lane1["reversed"] = true
	ready(911)
	check("  reversed vertical: the top", poolFrames()[4] and poolFrames()[4].__points[1][1] == "TOP")
	leave()
	lane1["reversed"] = false; lane1["vertical"] = false

	fopt.set(nil, "RING")
	ready(911)
	pf = poolFrames()
	-- the fifth finish reuses the first pooled frame
	fr = pf[1]
	check("Gold ring: the pool keeps four frames and the fifth finish reuses the first (none made per finish)", #pf == 4
		and fr.group.__plays == 2, tostring(#pf) .. " frames, plays " .. tostring(fr.group.__plays))
	check("  a ring grows from 0.6 to 2.4 of the icon size (a 0.6 ring scaled 4 times) round the icon's centre, no picture",
		fr.ring:IsShown() and not fr.pic:IsShown() and eq(fr.scale.__set.SetScaleTo, 2.4 / 0.6, 2.4 / 0.6)
		and fr.__w == lane1["icons"]["size"] and math.abs(fr.ring.__w - lane1["icons"]["size"] * 0.6) < 1e-9
		and fr.ring.__points[1] and fr.ring.__points[1][1] == "CENTER", tostring(fr.ring.__w))
	check("  over 0.9 s: full for 0.35 s, then fades over 0.55 s", eq(fr.scale.__set.SetDuration, 0.9)
		and eq(fr.fade.__set.SetStartDelay, 0.35) and math.abs(fr.fade.__set.SetDuration[1] - 0.55) < 1e-9)
	local sh = fr.shrink
	check("  the icon shrinks to a fifth and fades into the ring's centre over 0.45 s, on the lane beside the ring (not grown with it)",
		sh and sh:IsShown() and sh.group.__running and rawget(sh, "__parent") == fr:GetParent() and sh.pic.__tex ~= nil
		and eq(sh.scale.__set.SetScaleTo, 0.2, 0.2) and eq(sh.scale.__set.SetDuration, 0.45) and eq(sh.fade.__set.SetDuration, 0.45)
		and eq(sh.fade.__set.SetToAlpha, 0) and sh.__w == lane1["icons"]["size"] and sh.__points[1][1] == fr.__points[1][1],
		sh and tostring(sh.pic.__tex))
	leave()
	local total = #GetAllFrames()
	ready(911); leave(); ready(911); leave()
	check("  more finishes make no new frames", #GetAllFrames() == total and #poolFrames() == 4, tostring(#GetAllFrames() - total))
	fopt.set(nil, "NONE")
	local plays = 0
	for _, f2 in ipairs(poolFrames()) do plays = plays + f2.group.__plays end
	ready(911)
	local plays2 = 0
	for _, f2 in ipairs(poolFrames()) do plays2 = plays2 + f2.group.__plays end
	check("  set back to None: nothing more plays", plays == plays2)
	leave()
end

---------------------------------------------------------------- Show and hide animations
print("[show and hide animations " .. FLAVOR .. "]")
do
	local P = CDTL3.db.profile
	local L1, B1, R1 = P.lanes.lane1, P.barFrames.frame1, P.ready.ready1
	local lane, bar, rdy = CDTL3_Lane_1, CDTL3_BarFrame_1, CDTL3_Ready_1
	local function same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] end
	local function shape(a, type_, d, from, to, loops, bounce)
		return a.type == type_ and a.duration == d and a.from == from and a.to == to and a.loops == loops and a.bounce == bounce
	end
	local function alphaOf(grp, k) return grp.__anims[k] end
	-- the options setters of lane 1, bar frame 1 and ready 1
	local function opt(opts, set, dir, name) return opts.args[set].args.showHide.args[dir].args[name] end
	local lo, bo, ro = CDTL3:GetLaneOptions(), CDTL3:GetBarFrameOptions(), CDTL3:GetReadyOptions()

	check("defaults: lane and Ready frame show FADE 0 to 1 and hide FADE 1 to 0 over 0.3 s, once, no bounce",
		shape(L1.showAnim, "FADE", 0.3, 0, 1, 1, false) and shape(L1.hideAnim, "FADE", 0.3, 1, 0, 1, false)
		and shape(R1.showAnim, "FADE", 0.3, 0, 1, 1, false) and shape(R1.hideAnim, "FADE", 0.3, 1, 0, 1, false))
	check("  bar frames: the same over 1.0 s", shape(B1.showAnim, "FADE", 1, 0, 1, 1, false) and shape(B1.hideAnim, "FADE", 1, 1, 0, 1, false))
	local all = true
	for i = 1, 3 do
		for _, s in ipairs({ P.lanes["lane" .. i], P.ready["ready" .. i] }) do
			if s.showAnim.duration ~= 0.3 or s.hideAnim.duration ~= 0.3 then all = false end
		end
		if P.barFrames["frame" .. i].showAnim.duration ~= 1 then all = false end
	end
	check("  the same on lanes, Ready frames and bar frames 2 and 3 (old profiles get them from the defaults)", all)

	CDTL3:RefreshLane(1); CDTL3:RefreshBarFrame(1); CDTL3:RefreshReady(1)
	local function A(fr, dir) return fr[dir].__anims end
	local li, lo1 = A(lane, "animateIn"), A(lane, "animateOut")
	check("a lane's default groups look as before: one Alpha, 0 to its alpha in, its alpha to 0 out, 0.3 s",
		#li == 1 and li[1].__atype == "Alpha" and same(li[1].__set.SetFromAlpha, { 0 }) == true and li[1].__set.SetToAlpha[1] == L1.alpha
		and li[1].__set.SetDuration[1] == 0.3 and #lo1 == 1 and lo1[1].__set.SetFromAlpha[1] == L1.alpha and lo1[1].__set.SetToAlpha[1] == 0
		and lo1[1].__set.SetDuration[1] == 0.3)
	check("  a bar frame's take 1.0 s, a Ready frame's 0.3 s",
		A(bar, "animateIn")[1].__set.SetDuration[1] == 1 and A(bar, "animateOut")[1].__set.SetDuration[1] == 1
		and A(rdy, "animateIn")[1].__set.SetDuration[1] == 0.3)

	-- each kind reads its own settings
	local g1, g2, g3 = lane.animateIn, bar.animateOut, rdy.animateIn
	L1.showAnim.duration = 2; B1.hideAnim.duration = 2.5; R1.showAnim.to = 0.5
	CDTL3:RefreshLane(1); CDTL3:RefreshBarFrame(1); CDTL3:RefreshReady(1)
	check("each frame kind uses its own settings",
		lane.animateIn.__anims[1].__set.SetDuration[1] == 2 and lane.animateOut.__anims[1].__set.SetDuration[1] == 0.3
		and bar.animateOut.__anims[1].__set.SetDuration[1] == 2.5 and bar.animateIn.__anims[1].__set.SetDuration[1] == 1
		and rdy.animateIn.__anims[1].__set.SetToAlpha[1] == 0.5 and rdy.animateOut.__anims[1].__set.SetFromAlpha[1] == 1)
	check("  a number changed: the same group, new numbers (nothing piles up)", lane.animateIn == g1 and bar.animateOut == g2 and rdy.animateIn == g3)
	L1.showAnim.duration = 0.3; B1.hideAnim.duration = 1; R1.showAnim.to = 1
	CDTL3:RefreshLane(1); CDTL3:RefreshBarFrame(1); CDTL3:RefreshReady(1)
	local frames = #GetAllFrames()
	for _ = 1, 5 do CDTL3:RefreshLane(1); CDTL3:RefreshBarFrame(1); CDTL3:RefreshReady(1) end
	check("  refreshing again makes nothing new", #GetAllFrames() == frames and lane.animateIn == g1)

	-- Scale, through the options
	local x0, y0, w0, h0 = lane.__points and #lane.__points, 0, lane:GetWidth(), lane:GetHeight()
	local pts0 = {}
	for i, p in ipairs(lane.__points or {}) do pts0[i] = table.concat({ tostring(p[1]), tostring(p[2]), tostring(p[3]), tostring(p[4]), tostring(p[5]) }, "|") end
	opt(lo, "lane1", "show", "type").set({}, "SCALE")
	opt(lo, "lane1", "hide", "type").set({}, "SCALE")
	check("Scale picked: from and to change to 0.6 and 1 for show, 1 and 0.6 for hide",
		shape(L1.showAnim, "SCALE", 0.3, 0.6, 1, 1, false) and shape(L1.hideAnim, "SCALE", 0.3, 1, 0.6, 1, false))
	check("  a changed type builds a new group", lane.animateIn ~= g1)
	local sin, sout = A(lane, "animateIn"), A(lane, "animateOut")
	check("  show: Scale 0.6 to 1 around the centre while the Alpha runs 0 to the lane's alpha",
		#sin == 2 and sin[1].__atype == "Alpha" and sin[2].__atype == "Scale" and same(sin[2].__set.SetScaleFrom, { 0.6, 0.6 })
		and same(sin[2].__set.SetScaleTo, { 1, 1 }) and sin[2].__set.SetOrigin[1] == "CENTER" and sin[1].__set.SetFromAlpha[1] == 0
		and sin[1].__set.SetToAlpha[1] == L1.alpha)
	check("  hide: Scale 1 to 0.6 while the Alpha runs from the lane's alpha to 0",
		#sout == 2 and same(sout[2].__set.SetScaleFrom, { 1, 1 }) and same(sout[2].__set.SetScaleTo, { 0.6, 0.6 })
		and sout[1].__set.SetFromAlpha[1] == L1.alpha and sout[1].__set.SetToAlpha[1] == 0)
	local pts1 = {}
	for i, p in ipairs(lane.__points or {}) do pts1[i] = table.concat({ tostring(p[1]), tostring(p[2]), tostring(p[3]), tostring(p[4]), tostring(p[5]) }, "|") end
	check("  the lane's saved position, points and size are untouched (a Scale animation only draws it)",
		table.concat(pts0, ";") == table.concat(pts1, ";") and lane:GetWidth() == w0 and lane:GetHeight() == h0 and L1.width == w0 and lane:GetScale() == 1)
	opt(lo, "lane1", "show", "type").set({}, "FADE")
	check("  back to Fade: 0 to 1 and 1 to 0 again, one Alpha in the group", shape(L1.showAnim, "FADE", 0.3, 0, 1, 1, false) and #A(lane, "animateIn") == 1)
	opt(lo, "lane1", "hide", "type").set({}, "FADE")

	-- loops and bounce
	opt(bo, "barFrame1", "show", "loops").set({}, 3)
	opt(bo, "barFrame1", "show", "bounce").set({}, true)
	local bi = A(bar, "animateIn")
	check("3 loops with bounce: three Alphas in orders 1, 2, 3, the second playing back the other way",
		#bi == 3 and bi[1].__set.SetOrder[1] == 1 and bi[2].__set.SetOrder[1] == 2 and bi[3].__set.SetOrder[1] == 3
		and bi[1].__set.SetFromAlpha[1] == 0 and bi[1].__set.SetToAlpha[1] == 1 and bi[2].__set.SetFromAlpha[1] == 1
		and bi[2].__set.SetToAlpha[1] == 0 and bi[3].__set.SetFromAlpha[1] == 0 and bi[3].__set.SetToAlpha[1] == 1)
	opt(bo, "barFrame1", "show", "bounce").set({}, false)
	bi = A(bar, "animateIn")
	check("  without bounce every loop plays the same way", #bi == 3 and bi[2].__set.SetFromAlpha[1] == 0 and bi[2].__set.SetToAlpha[1] == 1)
	opt(bo, "barFrame1", "show", "loops").set({}, 1)
	check("  back to one loop", #A(bar, "animateIn") == 1)
	opt(ro, "ready1", "hide", "type").set({}, "SCALE")
	opt(ro, "ready1", "hide", "loops").set({}, 2)
	opt(ro, "ready1", "hide", "bounce").set({}, true)
	local rs = A(rdy, "animateOut")
	check("  Scale with bounce: each loop has its Scale, the second 0.6 back to 1",
		#rs == 4 and same(rs[2].__set.SetScaleFrom, { 1, 1 }) and same(rs[2].__set.SetScaleTo, { 0.6, 0.6 })
		and same(rs[4].__set.SetScaleFrom, { 0.6, 0.6 }) and same(rs[4].__set.SetScaleTo, { 1, 1 }))
	-- the options themselves
	local range = opt(lo, "lane1", "show", "from")
	check("options: Length 0.1 to 3, Loops 1 to 10, From and To 0 to 1 for Fade and 0.1 to 2 for Scale",
		opt(lo, "lane1", "show", "duration").min == 0.1 and opt(lo, "lane1", "show", "duration").max == 3
		and opt(lo, "lane1", "show", "loops").min == 1 and opt(lo, "lane1", "show", "loops").max == 10
		and range.min == 0 and range.max == 1 and opt(ro, "ready1", "hide", "toScale").min == 0.1 and opt(ro, "ready1", "hide", "toScale").max == 2)
	opt(ro, "ready1", "hide", "type").set({}, "FADE")
	opt(ro, "ready1", "hide", "loops").set({}, 1)
	opt(ro, "ready1", "hide", "bounce").set({}, false)

	-- a group that runs to its end leaves the frame at rest; a stopped one leaves it alone
	local gin, gout = lane.animateIn, lane.animateOut
	lane:SetAlpha(0.2); gin.__scripts.OnFinished(gin, false)
	check("a show that ends leaves the lane at its alpha", lane:GetAlpha() == L1.alpha, tostring(lane:GetAlpha()))
	gout.__scripts.OnFinished(gout, false)
	check("  a hide that ends leaves it at 0", lane:GetAlpha() == 0, tostring(lane:GetAlpha()))
	lane:SetAlpha(0.7); gout.__scripts.OnFinished(gout, true)
	check("  a group that was stopped changes nothing", lane:GetAlpha() == 0.7)

	-- Autohide still hides and shows, and Pause while hidden still sees the hidden lane
	instantFades(lane, L1.alpha); instantFades(bar, 1); instantFades(rdy, 1)
	CDTL3.combat = false
	L1.showMode = "COMBAT"
	CDTL3:RefreshLane(1)
	check("Autohide: Only in combat, out of combat: the lane hides", lane:GetAlpha() == 0, tostring(lane:GetAlpha()))
	CDTL3.combat = true
	CDTL3:RefreshLane(1)
	check("  in combat: it shows again", lane:GetAlpha() == L1.alpha, tostring(lane:GetAlpha()))
	CDTL3.combat = false
	L1.showMode = "GLOBAL"
	CDTL3:RefreshLane(1)
end

print(string.format("RESULT show %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
