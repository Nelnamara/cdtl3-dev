-- Area 1: the REAL CDTL3:GetCharacterData + CDTL3:IsAuraFadeSpell per client and class, with the
-- whole addon loaded from its TOC (so CDTL3.isForever / retailAPI come from CDTL3.lua itself).
dofile(HARNESS_DIR .. "/wow.lua")
LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local loadErrors = #ERRORS

local fails = 0
local function check(label, got, want)
	local ok
	if want == "falsy" then ok = not got elseif want == "truthy" then ok = got and true or false else ok = (got == want) end
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %-52s got=%-8s want=%s", ok and "ok" or "FAIL", label, tostring(got), tostring(want)))
end

local function asClass(class, race)
	PLAYER.class, PLAYER.race = class, race or "Human"
	CDTL3.player = {}
	CDTL3.spellData = {}
	CDTL3:GetCharacterData()
	return CDTL3.spellData
end

local function find(id)
	for _, s in ipairs(CDTL3.spellData) do if s.id == id then return s end end
end

print(string.format("[%s] interface %d isForever=%s retailAPI=%s load errors=%d", FLAVOR, CDTL3.tocversion,
	tostring(CDTL3.isForever), tostring(CDTL3.retailAPI), loadErrors))

local cases = ({
	era = {
		{ "DRUID", 17116, "Nature's Swiftness", "truthy" },
		{ "SHAMAN", 16188, "Nature's Swiftness", "truthy" },
		{ "MAGE", 12043, "Presence of Mind", "truthy" },
		{ "SHAMAN", 16166, "Elemental Mastery", "truthy" },
		{ "ROGUE", 1784, "Stealth", "truthy" },
		{ "DRUID", 29166, "Innervate", "falsy" },
	},
	forever = {
		{ "SHAMAN", 16166, "Elemental Mastery", "falsy" },
		{ "PALADIN", 1310994, "Swift Judgement", "falsy" },	-- a normal cooldown since Forever build 70755 (3.0.13)
		{ "MAGE", 12043, "Presence of Mind", "truthy" },
	},
	tbc = {
		{ "SHAMAN", 16188, "Nature's Swiftness", "truthy" },
	},
	mop = {
		{ "DRUID", 132158, "Nature's Swiftness", "truthy" },
		{ "MAGE", 12043, "Presence of Mind", "truthy" },
		{ "DEATHKNIGHT", 46584, "Raise Dead", "falsy" },
	},
	retail = {
		{ "MAGE", 205025, "Presence of Mind", "truthy" },
		{ "SHAMAN", 378081, "Nature's Swiftness", "truthy" },
	},
})[FLAVOR]

for _, c in ipairs(cases) do
	local class, id, name, want = c[1], c[2], c[3], c[4]
	asClass(class)
	local byID = CDTL3:IsAuraFadeSpell(id, nil)
	local both = CDTL3:IsAuraFadeSpell(id, name)
	check(string.format("%s %s %d IsAuraFadeSpell(id)", class, name, id), byID, want)
	check(string.format("%s %s %d IsAuraFadeSpell(id, name)", class, name, id), both, want)
end

if FLAVOR == "forever" then
	asClass("PALADIN")
	for _, id in ipairs({ 633, 2800, 10310 }) do
		local s = find(id)
		check("PALADIN Lay on Hands " .. id .. " bCD", s and s.bCD, 1200000)
	end
	-- the corrections must not leak into Era's tables (ForeverSpellData edits in place)
	CDTL3.isForever = false
	local era = CDTL3:GetAllSpellData("PALADIN", "Human")
	CDTL3.isForever = true
	for _, s in ipairs(era) do if s.id == 633 then check("Era data built after Forever: Lay on Hands 633 bCD", s.bCD, 3600000) end end
end

if FLAVOR == "mop" then
	asClass("DEATHKNIGHT", "NightElf")
	check("DEATHKNIGHT spellData size", #CDTL3.spellData, 0)
end

if FLAVOR == "era" then
	local hit
	for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT" }) do
		asClass(class)
		if find(425777) then hit = class end
		if class == "DEATHKNIGHT" then check("Era DEATHKNIGHT spellData (class list < 40000 only)", #CDTL3.spellData > 0, true) end
	end
	check("Era: dead id 425777 absent from every class", hit, nil)
end

-- per-class sizes, all classes the client has
local classes = ({
	era = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
	forever = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
	tbc = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
	mop = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT", "MONK" },
	retail = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER" },
})[FLAVOR]
local sizes, nonOaf = {}, 0
for _, class in ipairs(classes) do
	asClass(class)
	sizes[#sizes + 1] = class .. "=" .. #CDTL3.spellData
	if FLAVOR == "mop" or FLAVOR == "retail" then
		for _, s in ipairs(CDTL3.spellData) do
			if not s.oaf then nonOaf = nonOaf + 1; print("  NOTE non-oaf entry on " .. FLAVOR .. ": " .. class .. " " .. s.id .. " " .. s.name) end
		end
	end
end
print("  spellData sizes: " .. table.concat(sizes, " "))
if FLAVOR == "mop" or FLAVOR == "retail" then check(FLAVOR .. ": entries without oaf", nonOaf, 0) end

print(string.format("RESULT data %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS))
