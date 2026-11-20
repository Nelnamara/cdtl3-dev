-- 3.1.0 / 3.2.0 release checks: the version compare behind the welcome window, the window opening
-- once after an update on every client, its "New in 3.2.0" block, its combat timers notice (only
-- where combat timers run and only for a player who last saw something older than 3.1), the Take
-- the tour button, and the combat timers defaults (on, Blizzard's Tracked Bars not hidden).
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

-- a profile that has seen 3.0.13 and said "don't show again": an update, not a first run
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" },
	profiles = { Default = { global = { firstRun = false, previousVersion = "3.0.13" } } } }

-- the timer APIs CombatTimers.lua looks for (Retail, Forever), as bare stubs: only availability matters here
if RETAILAPI then
	C_Spell.GetSpellCooldownDuration = C_Spell.GetSpellCooldownDuration or function() return nil end
	C_CurveUtil = C_CurveUtil or { CreateCurve = function() return { SetType = function() end, AddPoint = function() end } end }
	C_DurationUtil = C_DurationUtil or { CreateDurationTextBinding = function()
		return { SetFontString = function() end, SetFormatter = function() end, SetDuration = function() end, SetEnabled = function() end }
	end }
end

-- count the welcome window being built
local opened = 0
LoadTOC(HARNESS_TOCFILE)
local realCreateFrame = CreateFrame
CreateFrame = function(kind, name, ...)
	if name == "CDTL3_Firstrun" then
		opened = opened + 1
	end
	return realCreateFrame(kind, name, ...)
end
Login()
Advance(11)
local base = #ERRORS
local g = CDTL3.db.profile.global
local CT = CDTL3.CombatTimers
local available = CT and CT:Available()

print("[version " .. FLAVOR .. "]")
check("version is 3.3.0", CDTL3.version == "3.3.0")
check("notice version is 3.3 (the window opens once on every client for anyone who last saw 3.2.x or older)", CDTL3.noticeVersion == "3.3")
local function newer(prev)
	g.previousVersion = prev
	local ok, v = pcall(CDTL3.IsNewerVersion, CDTL3)
	return ok and v, ok
end
local cases = {
	{ 0, true }, { "0", true }, { "2.6", true }, { "3.0.9", true }, { "3.0.13", true },
	{ "3.1.0", true }, { "3.1", true }, { "3.1.4", true }, { "3.2.0", true }, { "3.2.2", true }, { "3.3.0", false }, { "3.3", false }, { "4.0", false },
	{ "3.0.13-test", true }, { "junk", true }, { "", true },
}
for _, c in ipairs(cases) do
	local v, ok = newer(c[1])
	check(string.format("IsNewerVersion with previous %q: %s", tostring(c[1]), tostring(c[2])), ok and v == c[2], tostring(v))
end
g.previousVersion = "3.0.13"

print("[welcome window " .. FLAVOR .. "]")
check("opens once after the update, on every client", opened == 1, opened)
local msg = CDTL3:GetSpecialMessage()
check("3.2.0 block shows on every client", msg:find("New in 3.2.0", 1, true) == 1 or msg:find("New in 3.2.0", 1, true) ~= nil)
check("  it names the Simple tab, Quick Style > Setup, Filters, Effects, Pinned, CooldownCollaborator and /cdtl3 help",
	msg:find("Simple tab", 1, true) and msg:find("Quick Style > Setup", 1, true) and msg:find("Filters says why", 1, true)
	and msg:find("Effects", 1, true) and msg:find("Pinned", 1, true) and msg:find("CooldownCollaborator", 1, true)
	and msg:find("/cdtl3 help", 1, true))
check("  it comes before the combat timers block", not available or msg:find("New in 3.2.0", 1, true) < msg:find("New in 3.1.0", 1, true))
if available then
	check("combat timers block shows for a player coming from 3.0.13 where they run", msg:find("combat timers (experimental), on for everyone", 1, true) ~= nil)
	check("  it says how to turn them off", msg:find("/cdtl3 combattimers off", 1, true) ~= nil and msg:find("Global tab", 1, true) ~= nil)
	check("  it asks for reports", msg:find("report it at the link above", 1, true) ~= nil)
else
	check("Classic client: no combat timers block", msg:find("New in 3.1.0", 1, true) == nil)
end
g.previousVersion = "3.1.1"
check("a player coming from 3.1.1 is not told about combat timers again", CDTL3:GetSpecialMessage():find("New in 3.1.0", 1, true) == nil)
check("  but still sees New in 3.2.0", CDTL3:GetSpecialMessage():find("New in 3.2.0", 1, true) ~= nil)
check("LastSeenOlderThan: 3.1.1 vs 3.1 false, vs 3.2 true", CDTL3:LastSeenOlderThan("3.1") == false and CDTL3:LastSeenOlderThan("3.2") == true)
g.previousVersion = "3.0.13"
local log = CDTL3:GetChangeLog()
local at322, at321, at320, at311, at310, at3013 = log:find("Changelog 3.2.2", 1, true), log:find("Changelog 3.2.1", 1, true), log:find("Changelog 3.2.0", 1, true),
	log:find("Changelog 3.1.1", 1, true), log:find("Changelog 3.1.0", 1, true), log:find("Changelog 3.0.13", 1, true)
check("changelog has 3.2.2 first, then 3.2.1, 3.2.0, 3.1.1, 3.1.0", at322 and at321 and at320 and at311 and at310 and at3013
	and at322 < at321 and at321 < at320 and at320 < at311 and at311 < at310 and at310 < at3013)
check("  3.2.2 names the border errors and the cut-off labels", log:find("secret number value", 1, true) ~= nil and log:find("no longer cut off", 1, true) ~= nil)
check("  3.2.1 names /cdtl3 tour and /cdtl3 whatsnew", log:find("/cdtl3 tour", 1, true) ~= nil and log:find("/cdtl3 whatsnew", 1, true) ~= nil)
check("changelog has 3.3.0 above 3.2.2, with the highlight effects, the Finish effect and the samples", log:find("Changelog 3.3.0", 1, true) and log:find("Changelog 3.3.0", 1, true) < at322
	and log:find("Border Pulse", 1, true) and log:find("Finish effect", 1, true) and log:find("live samples", 1, true) and log:find("TeZwo", 1, true))
check("changelog says every cooldown you pin, not only defensives", log:find("every cooldown you pin", 1, true) ~= nil and log:find("pinned defensive", 1, true) == nil)

print("[take the tour " .. FLAVOR .. "]")
local win = _G["CDTL3_Firstrun"]
local shippedVersion = CDTL3.version
CDTL3.version = "3.3.0"	-- the release this notice version belongs to
local tourBtn = _G["CDTL3_Firstrun_Tour"]
check("the window has a Take the tour button", win and tourBtn and tourBtn:GetText() == "Take the tour")
check("  no tour is up and none is pending before the click", _G["CDTL3_Tour"] == nil and CDTL3.db.global.tourPending == nil)
if win and tourBtn then
	g.firstRun = true
	xpcall(tourBtn.__scripts.OnClick, ERRH, tourBtn)
	check("  it closes the window", not win:IsShown())
	check("  it marks the window seen", g.firstRun == false and g.previousVersion == CDTL3.version)
	local tour = _G["CDTL3_Tour"]
	check("  it starts the three-step tour", tour and tour:IsShown() and tour.head:GetText() == "1 of 3, Lane", tour and tour.head:GetText())
	check("  the update does not open the window again", CDTL3:IsNewerVersion() == false)
	xpcall(_G["CDTL3_Tour_Skip"].__scripts.OnClick, ERRH, _G["CDTL3_Tour_Skip"])
	check("  closing the tour ends it for good", not tour:IsShown() and CDTL3.db.global.tourPending == nil and CDTL3.Start:StartTour() == false)
end
CDTL3.version = shippedVersion
print("[defaults " .. FLAVOR .. "]")
check("combat timers on by default", g.combatTimers.enabled == true)
check("Blizzard's Tracked Bars not hidden by default", g.combatTimers.hideBlizzardBars == false)
check("probe removed", CDTL3.Probe == nil)

print(string.format("RESULT release310 %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
