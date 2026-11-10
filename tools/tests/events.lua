-- Area 2 (CDTL3.lua) + area 3 school colour: combat-log gate, RUNE_POWER_UPDATE through the real
-- AceEvent dispatch, the pet cast's spellCastTimes for the secret fallback, and bar colouring /
-- the colour picker with Spell School Color on, with and without a combat log.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = HARNESS_ARG ~= "" and HARNESS_ARG or "HUNTER"
LoadTOC(HARNESS_TOCFILE)
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end

-- A. combat log
local atLoad = CDTL3.combatLogRegistered
check("combatLogRegistered at load (before TurnOn)", (RETAILAPI and atLoad == false) or (not RETAILAPI and atLoad == nil), tostring(atLoad))
Login()
check("TurnOn: combatLogRegistered", CDTL3.combatLogRegistered == not RETAILAPI, tostring(CDTL3.combatLogRegistered))
check("TurnOn: CLEU registered on a frame", IsEventRegisteredAnywhere("COMBAT_LOG_EVENT_UNFILTERED") == not RETAILAPI,
	tostring(IsEventRegisteredAnywhere("COMBAT_LOG_EVENT_UNFILTERED")))
CDTL3:TurnOff(); CDTL3:TurnOn()
check("TurnOff/TurnOn again: same result", CDTL3.combatLogRegistered == not RETAILAPI and IsEventRegisteredAnywhere("COMBAT_LOG_EVENT_UNFILTERED") == not RETAILAPI)
Advance(11)
local e0 = #ERRORS

-- B. RUNE_POWER_UPDATE (DK only). Rune tracking stays off in 3.0.12, as in 3.0.11: the event is
-- not registered, so spending runes makes no rune entries or icons. The corrected handler is kept.
if PLAYER.class == "DEATHKNIGHT" then
	check("RUNE_POWER_UPDATE not registered (login, TurnOff/TurnOn, +11 s)", not IsEventRegisteredAnywhere("RUNE_POWER_UPDATE"))
	CDTL3.db.profile.global["runes"]["enabled"] = true
	local nRunes = function() local n = 0; for _, cd in ipairs(CDTL3.cooldowns) do if cd.data.type == "runes" then n = n + 1 end end return n end
	local nSaved = function() local n = 0; for _ in pairs(CDTL3.db.profile.tables["runes"]) do n = n + 1 end return n end
	local before, savedBefore = nRunes(), nSaved()
	local dispatched = 0
	for i = 1, 6 do
		dispatched = dispatched + FireEvent("RUNE_POWER_UPDATE", i, false)
		dispatched = dispatched + FireEvent("RUNE_POWER_UPDATE", i, true)
	end
	Advance(1)
	check("spending all six runes: nothing receives the event", dispatched == 0, tostring(dispatched))
	check("spending all six runes: no rune icons", nRunes() == before and before == 0, nRunes() .. " live")
	check("spending all six runes: no saved rune entries", nSaved() == savedBefore and savedBefore == 0, tostring(nSaved()))
	-- the kept handler still reads (event, runeIndex, added) when called directly
	CDTL3:RUNE_POWER_UPDATE("RUNE_POWER_UPDATE", 1, false)
	local saved = CDTL3:GetSpellSettings("Blood Rune 1", "runes")
	check("kept handler, direct call: reads runeIndex from the second argument", saved ~= nil and saved.runeIndex == 1,
		saved and tostring(saved.runeIndex) or "no entry")
	local t = CDTL3.db.profile.tables["runes"]
	for k in pairs(t) do t[k] = nil end
end

-- C. pet cast -> spellCastTimes, read by GetSpellCooldown's secret fallback
if PLAYER.class == "HUNTER" or PLAYER.class == "WARLOCK" then
	local entry = CDTL3:ApplyEntryDefaults({ id = 17253, name = "Bite", type = "petspells", icon = 132278, bCD = 10000, setCustomCD = false }, "petspells")
	entry.ignored = false
	table.insert(CDTL3.db.profile.tables["petspells"], entry)
	SPELLINFO[17253] = { "Bite", 132278 }
	SPELLINFO[17255] = { "Bite", 132278 }   -- another rank, the one the pet casts
	KNOWN[17255] = true
	BASECD[17253], BASECD[17255] = 10000, 10000
	SPELLCD[17253] = { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = true, isOnGCD = false }
	SPELLCD[17255] = SPELLCD[17253]
	local castAt = NOW
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "pet", "Cast-9", 17255)
	local t = CDTL3.spellCastTimes or {}
	check("pet cast records spellCastTimes[cast id]", t[17255] == castAt, tostring(t[17255]))
	check("pet cast records spellCastTimes[saved entry id]", t[17253] == castAt, tostring(t[17253]))
	local ef = CDTL3:GetExistingCooldown("Bite", "petspells")
	check("pet cast starts the live cooldown", ef ~= nil)
	if RETAILAPI and ef then
		local s, d = CDTL3:GetSpellCooldown(17253)
		check("secret fallback: start = pet cast time, duration = base", s == castAt and d == 10, string.format("start=%s dur=%s", tostring(s), tostring(d)))
		RunOnUpdate(0.05, 60)   -- 3 s, several 50-frame polls
		check("after 3 s the countdown reads ~7 s (not restarted per poll)", math.abs(ef.data.currentCD - 7) < 0.3, string.format("currentCD=%.2f", ef.data.currentCD))
	end
end

-- E. school colour with no combat log
local fs
for _, k in ipairs({ "frame3", "frame2", "frame1" }) do
	fs = CDTL3.db.profile.barFrames[k]["bar"]
	fs["fgSchoolColor"], fs["fgClassColor"] = true, false
	fs["fgTextureColor"] = { r = 0.1, g = 0.2, b = 0.3, a = 1 }
end
local fire = CDTL3.db.profile.global["schoolColors"]["Fire"]
local cd = CDTL3:CreateCooldown(CDTL3:GetUID(), "spells", CDTL3:ApplyEntryDefaults({ id = 133, name = "Fireball", bCD = 8000, school = "Fire" }, "spells"))
cd.data.barFrame = 1
CDTL3:SendToBarFrame(cd)
local r, g, b = cd.bar.bar:GetStatusBarColor()
if RETAILAPI then
	check("no combat log: school colour ignored, bar uses frame colour", r == 0.1 and g == 0.2 and b == 0.3, string.format("%s,%s,%s", tostring(r), tostring(g), tostring(b)))
else
	check("combat log: bar uses the Fire school colour", r == fire.r and g == fire.g and b == fire.b, string.format("%s,%s,%s", tostring(r), tostring(g), tostring(b)))
end
-- the Bar Frames colour picker: disabled only when the school colour really applies
local found = 0
local function walk(t, path)
	for k, v in pairs(t) do
		if type(v) == "table" then
			if k == "fgTextureColor" and type(v.disabled) == "function" then
				local info = debug.getinfo(v.disabled, "S")
				if info.linedefined > 2000 and info.linedefined < 2600 then
					found = found + 1
					local dis = v.disabled({})
					check("bar colour picker disabled=" .. tostring(dis) .. " (" .. path .. ")", dis == not RETAILAPI)
				end
			end
			walk(v, path .. "." .. tostring(k))
		end
	end
end
walk(CDTL3:GetBarFrameOptions(), "barFrames")
check("found the bar frames' colour pickers", found >= 1, tostring(found))

print(string.format("RESULT events %s %s: fails=%d lua errors=%d", FLAVOR, PLAYER.class, fails, #ERRORS))
