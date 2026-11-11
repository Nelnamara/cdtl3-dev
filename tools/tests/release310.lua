-- 3.1.0 release checks: the version compare behind the welcome window, the window opening once
-- after an update where combat timers run (and not on Classic clients), its combat timers notice,
-- and the combat timers defaults (on, Blizzard's Tracked Bars not hidden).
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
check("version is 3.1.0", CDTL3.version == "3.1.0")
check("notice version is 3.1", CDTL3.noticeVersion == "3.1")
local function newer(prev)
	g.previousVersion = prev
	local ok, v = pcall(CDTL3.IsNewerVersion, CDTL3)
	return ok and v, ok
end
local cases = {
	{ 0, true }, { "0", true }, { "2.6", true }, { "3.0.9", true }, { "3.0.13", true },
	{ "3.1.0", false }, { "3.1", false }, { "3.1.4", false }, { "3.2.0", false }, { "4.0", false },
	{ "3.0.13-test", true }, { "junk", true }, { "", true },
}
for _, c in ipairs(cases) do
	local v, ok = newer(c[1])
	check(string.format("IsNewerVersion with previous %q: %s", tostring(c[1]), tostring(c[2])), ok and v == c[2], tostring(v))
end
g.previousVersion = "3.0.13"

print("[welcome window " .. FLAVOR .. "]")
if available then
	check("opens once after the update where combat timers run", opened == 1, opened)
	local msg = CDTL3:GetSpecialMessage()
	check("notice names combat timers and says they are on", msg:find("combat timers (experimental), on for everyone", 1, true) ~= nil)
	check("notice says how to turn them off", msg:find("/cdtl3 combattimers off", 1, true) ~= nil and msg:find("Global tab", 1, true) ~= nil)
	check("notice asks for reports", msg:find("report it at the link above", 1, true) ~= nil)
	check("changelog has the 3.1.0 entry first", CDTL3:GetChangeLog():find("Changelog 3.1.0", 1, true) ~= nil
		and CDTL3:GetChangeLog():find("Changelog 3.1.0", 1, true) < CDTL3:GetChangeLog():find("Changelog 3.0.13", 1, true))
else
	check("Classic client: no window after the update", opened == 0, opened)
	check("Classic client: no combat timers notice", CDTL3:GetSpecialMessage() == "")
end

print("[defaults " .. FLAVOR .. "]")
check("combat timers on by default", g.combatTimers.enabled == true)
check("Blizzard's Tracked Bars not hidden by default", g.combatTimers.hideBlizzardBars == false)
check("probe removed", CDTL3.Probe == nil)

print(string.format("RESULT release310 %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
