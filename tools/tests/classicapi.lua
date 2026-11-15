-- Classic clients: the addon calls the current API names (C_UnitAuras.GetAuraDataByIndex,
-- C_CombatLog.GetCurrentEventInfo) and falls back to UnitAura / CombatLogGetCurrentEventInfo only when
-- the new ones are missing. Extra arg "new" drops the old names, "old" drops the new ones, so each set is
-- proven alone; the default has both, as the clients do.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local mode = HARNESS_ARG ~= "" and HARNESS_ARG or "both"
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end
if mode == "new" then
	UnitAura = nil
	CombatLogGetCurrentEventInfo = nil
elseif mode == "old" then
	C_CombatLog = nil
	C_UnitAuras.GetAuraDataByIndex = nil
end

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
print("[classic api " .. FLAVOR .. " " .. mode .. "]")
if RETAILAPI then
	-- retail and Forever keep the data path and the closed combat log whatever the names
	check("retail API: combat log stays closed", CDTL3:NoCombatLog() == true)
else
	check("combat log usable", CDTL3:NoCombatLog() == false)
	check("CLEU registered", CDTL3.combatLogRegistered == true and IsEventRegisteredAnywhere("COMBAT_LOG_EVENT_UNFILTERED"))

	local ME = PLAYER.guid
	CLEU_ARGS = { 0, "SPELL_CAST_SUCCESS", false, ME, "Tester", 0, 0, nil, nil, 0, 0, 133, "Fireball", 4 }
	local ok, err = pcall(CDTL3.COMBAT_LOG_EVENT_UNFILTERED, CDTL3)
	check("handler ran on the " .. (mode == "old" and "old" or "new") .. " name", ok, tostring(err))
	check("school read from the event", CDTL3.spellSchools["Fireball"] == "Fire", tostring(CDTL3.spellSchools["Fireball"]))
	CLEU_ARGS = nil

	AURAS = { HELPFUL = { { name = "Arcane Intellect", spellId = 1459, duration = 1800, icon = 135932, applications = 2, expirationTime = NOW + 900 } }, HARMFUL = {} }
	local name, spellID, duration, icon, count, expiry = CDTL3:GetUnitAura("player", 1, "HELPFUL")
	check("GetUnitAura fields", name == "Arcane Intellect" and spellID == 1459 and duration == 1800 and icon == 135932 and count == 2 and expiry == NOW + 900,
		table.concat({ tostring(name), tostring(spellID), tostring(duration), tostring(icon), tostring(count), tostring(expiry) }, ","))
	check("GetUnitAura past the last aura is nil", CDTL3:GetUnitAura("player", 2, "HELPFUL") == nil)
end
check("no lua errors", #ERRORS == 0, tostring(ERRORS[1]))
print(string.format("RESULT classicapi %s %s fails=%d lua errors=%d", FLAVOR, mode, fails, #ERRORS))
