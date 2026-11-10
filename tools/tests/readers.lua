-- Area 1 readers: CheckEdgeCases (Vanish -> Stealth, Shadowmeld, paladin lockouts) and
-- ScanSharedSpellCooldown on the spell data each client really builds, with readable and
-- SECRET cooldowns. Counts Lua errors; prints what each reader saved.
dofile(HARNESS_DIR .. "/wow.lua")
LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local g = CDTL3.db.profile.global
g["detectSharedCD"] = true

local classes = ({
	mop = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT", "MONK" },
	retail = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER" },
})[FLAVOR] or { "PALADIN", "ROGUE", "DRUID", "HUNTER" }
local names = { "Vanish", "Shadowmeld", "Divine Protection", "Divine Shield", "Hand of Protection", "Lay on Hands", "Avenging Wrath" }

for _, secret in ipairs(RETAILAPI and { false, true } or { false }) do
	for _, class in ipairs(classes) do
		PLAYER.class, PLAYER.race = class, "NightElf"
		CDTL3.player = {}
		CDTL3:GetCharacterData()
		local saved = CDTL3.db.profile.tables["spells"]
		for k in pairs(saved) do saved[k] = nil end

		-- every data spell on cooldown: 30 s readable, or secret (comparison throws)
		SPELLCD = {}
		for _, s in ipairs(CDTL3:GetAllSpellData(class, "NightElf")) do
			SPELLINFO[s.id] = { s.name, 136000 }
			BASECD[s.id] = s.bCD
			SPELLCD[s.id] = secret and { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = true, isOnGCD = false }
				or { startTime = NOW - 1, duration = 30, isEnabled = true, isActive = true, isOnGCD = false }
		end

		local e0 = #ERRORS
		for _, n in ipairs(names) do
			xpcall(function() CDTL3:CheckEdgeCases(n) end, ERRH)
		end
		local afterEdge = {}
		for _, s in ipairs(saved) do afterEdge[#afterEdge + 1] = s.name .. (s.ignored and "(ign)" or "") end

		-- shared-cooldown scan: a duration matching the readable 30 s (or the secret fallback's
		-- base cooldown), plus one that matches nothing
		xpcall(function() CDTL3:ScanSharedSpellCooldown("Nothing", 29) end, ERRH)
		xpcall(function() CDTL3:ScanSharedSpellCooldown("Nothing", 7.3) end, ERRH)
		local afterScan = #saved
		-- and through the real path: a live cooldown's first update runs the scan
		local s = saved[1]
		if s then
			local f = CDTL3:CreateCooldown(CDTL3:GetUID(), "spells", s)
			xpcall(function() f.__scripts.OnUpdate(f, 0.02) end, ERRH)
		end
		print(string.format("  %-6s %-11s sd=%-3d edge-saved=[%s] after-scan=%d errors=%d",
			secret and "secret" or "plain", class, #CDTL3.spellData, table.concat(afterEdge, ","), afterScan, #ERRORS - e0))
	end
end
print(string.format("RESULT readers %s: lua errors=%d", FLAVOR, #ERRORS - base))
