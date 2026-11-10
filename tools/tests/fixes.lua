-- Review-fix cases (3.0.12 F5-F8): saved oaf flags follow the spell data, Vanish -> Stealth only
-- on the Classic lists, player cast times under the saved rank's id, and Clear Settings / Clear
-- Quest Items scoped to the current character. Real files, real AceDB, real GetCharacterData.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME, OTHER, THIRD = PLAYER.guid, "Player-1-0000099", "Player-1-0000077"

CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default", ["Other - Realm"] = "Default" }, profiles = { Default = {} } }

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
g["spells"]["ignoreThreshold"] = 1800
local function entry(id, name, owners, extra)
	local e = { id = id, name = name, type = "spells", icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = owners, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
local function clearTable(t) for k in pairs(t) do t[k] = nil end return t end
local function asClass(class, race)
	PLAYER.class, PLAYER.race = class, race or "Human"
	CDTL3.player = {}
	CDTL3.spellData = {}
	CDTL3:GetCharacterData()
	clearTable(CDTL3.db.profile.tables["spells"])
end
local function frameOaf(e) return CDTL3:CreateCooldown(CDTL3:GetUID(), e.type or "spells", e).data.oaf end

---------------------------------------------------------------- 2. saved oaf flags follow the spell data
print("[oaf flags " .. FLAVOR .. "]")
local known = ({
	era = { "MAGE", 12043, "Presence of Mind" }, forever = { "MAGE", 12043, "Presence of Mind" },
	tbc = { "SHAMAN", 16188, "Nature's Swiftness" }, mop = { "MAGE", 12043, "Presence of Mind" },
	retail = { "MAGE", 205025, "Presence of Mind" },
})[FLAVOR]
asClass(known[1])
check("data lists " .. known[3] .. " as oaf", CDTL3:GetSpellData(known[2]) and CDTL3:GetSpellData(known[2]).oaf)
check("known oaf spell, saved without the flag: frame is oaf", frameOaf(entry(known[2], known[3], { ME })) == true)
check("known oaf spell, saved oaf = false: data wins, frame is oaf", frameOaf(entry(known[2], known[3], { ME }, { oaf = false })) == true)
check("known oaf spell by English name (unlisted rank id): frame is oaf", frameOaf(entry(990777, known[3], { ME })) == true)
check("NewSpellEntry: known oaf spell gets oaf = true", CDTL3:NewSpellEntry(known[2], known[3], 1, "spells").oaf == true)
check("unknown spell, saved oaf = true: saved flag kept", frameOaf(entry(990001, "Not In Data", { ME }, { oaf = true })) == true)
check("unknown spell, saved without the flag: not oaf", not frameOaf(entry(990002, "Also Not In Data", { ME })))
check("unknown spell, petspells, saved oaf = true: saved flag kept", frameOaf(entry(990003, "Pet Not In Data", { ME }, { oaf = true, type = "petspells" })) == true)
check("NewSpellEntry: unknown spell gets no flag", CDTL3:NewSpellEntry(990004, "Unknown New", 1, "spells").oaf == nil)

-- a spell the data lists without the flag: the stale saved true is overridden
local plain
for _, s in ipairs(CDTL3.spellData) do if not s.oaf and s.name ~= known[3] then plain = s; break end end
if FLAVOR == "mop" or FLAVOR == "retail" then
	check("mop/retail lists only oaf spells (no non-oaf case here)", plain == nil, plain and plain.name)
else
	check("non-oaf data spell " .. (plain and plain.name or "?") .. ", saved oaf = true: data wins, not oaf",
		plain and not frameOaf(entry(plain.id, plain.name, { ME }, { oaf = true })))
end
if FLAVOR == "forever" then
	asClass("SHAMAN")
	local em = CDTL3:GetSpellData(16166)
	check("Forever data lists Elemental Mastery without the flag", em and not em.oaf, em and tostring(em.oaf) or "missing")
	local stale = entry(16166, "Elemental Mastery", { ME }, { oaf = true, bCD = 180000 })
	table.insert(CDTL3.db.profile.tables["spells"], stale)
	local f = CDTL3:CreateCooldown(CDTL3:GetUID(), "spells", stale)
	check("Forever: Elemental Mastery saved oaf = true by 3.0.11 -> frame not oaf", not f.data.oaf, tostring(f.data.oaf))
	check("Forever: Lightning Mastery (its Forever name) by name only (other id), saved oaf = true -> not oaf",
		not frameOaf(entry(990016, "Lightning Mastery", { ME }, { oaf = true })))
	check("Forever: NewSpellEntry for Elemental Mastery gets no flag", not CDTL3:NewSpellEntry(16166, "Elemental Mastery", 1, "spells").oaf)
	-- the /cdtl3 oaf report still runs and lists the stale saved flag next to the data's
	local e0 = #ERRORS
	clearTable(CHAT)
	CDTL3:ChatCommand("oaf")
	local savedLine, frameLine = false, false
	for _, m in ipairs(CHAT) do
		if m:find("saved: Elemental Mastery", 1, true) and m:find("saved-oaf=true", 1, true) and m:find("data-oaf=nil", 1, true) then savedLine = true end
		if m:find("frame: Elemental Mastery", 1, true) then frameLine = true end
	end
	check("/cdtl3 oaf: runs without errors", #ERRORS == e0, tostring(#ERRORS - e0))
	check("/cdtl3 oaf: shows the stale saved flag beside the data's", savedLine)
	check("/cdtl3 oaf: no held frame line for Elemental Mastery", not frameLine)
end
if FLAVOR == "mop" or FLAVOR == "retail" then
	-- DK Raise Dead: the DK list is Classic-only, so the data doesn't know it; the saved flag stays (harmless)
	asClass("DEATHKNIGHT")
	check("mop/retail DK: Raise Dead saved oaf = true stays (data doesn't list it)", frameOaf(entry(46584, "Raise Dead", { ME }, { oaf = true })) == true)
end

---------------------------------------------------------------- 3. Vanish -> Stealth / Shadowmeld
print("[edge cases " .. FLAVOR .. "]")
local classicLists = CDTL3.tocversion < 40000
local spells = CDTL3.db.profile.tables["spells"]
local function liveFor(name) return CDTL3:GetExistingCooldown(name, "spells") end
local function dropLive(name)
	local f = liveFor(name)
	while f do
		for i, cd in ipairs(CDTL3.cooldowns) do if cd == f then table.remove(CDTL3.cooldowns, i); break end end
		f = liveFor(name)
	end
end

asClass("ROGUE", "NightElf")
dropLive("Stealth")
CDTL3:CheckEdgeCases("Vanish")
local st = CDTL3:GetSpellSettings("Stealth", "spells")
if classicLists then
	check("Vanish, no saved Stealth: Stealth saved from the data (Classic lists)", st ~= nil)
else
	check("Vanish, no saved Stealth: nothing saved (as 3.0.11)", st == nil and #spells == 0, tostring(#spells))
	check("Vanish, no saved Stealth: no Stealth icon (as 3.0.11)", liveFor("Stealth") == nil)
end

-- the login / reload / Ignore Threshold path: Vanish on cooldown in the spell book
asClass("ROGUE", "NightElf")
dropLive("Stealth"); dropLive("Vanish")
SPELLBOOK = { { id = 1856, name = "Vanish" } }
SPELLINFO[1856] = { "Vanish", 132331 }
KNOWN[1856] = true
BASECD[1856] = 120000
SPELLCD[1856] = { startTime = NOW - 5, duration = 120, isEnabled = true, isActive = true, isOnGCD = false }
table.insert(spells, entry(1856, "Vanish", { ME }, { bCD = 120000 }))
local e0 = #ERRORS
CDTL3:ScanCurrentCooldowns("ROGUE", "NightElf")
check("ScanCurrentCooldowns with Vanish cooling: no errors", #ERRORS == e0, tostring(#ERRORS - e0))
check("ScanCurrentCooldowns: Vanish icon", liveFor("Vanish") ~= nil)
if classicLists then
	check("ScanCurrentCooldowns: Stealth saved (Classic lists)", CDTL3:GetSpellSettings("Stealth", "spells") ~= nil)
else
	check("ScanCurrentCooldowns: no Stealth entry or icon on mop/retail (as 3.0.11)",
		CDTL3:GetSpellSettings("Stealth", "spells") == nil and liveFor("Stealth") == nil)
end
SPELLBOOK = {}
SPELLCD[1856] = nil

-- a Stealth entry the player saved by casting it: unchanged on every client (3.0.11 did this too)
asClass("ROGUE", "NightElf")
dropLive("Stealth")
table.insert(spells, entry(1784, "Stealth", { ME }, { bCD = 6000 }))
CDTL3:CheckEdgeCases("Vanish")
check("Vanish with a saved Stealth entry: Stealth icon (unchanged)", liveFor("Stealth") ~= nil)

-- Shadowmeld: the racial lists exist only below 40000, so mop/retail never had a data fallback
asClass("ROGUE", "NightElf")
dropLive("Shadowmeld")
local smData = CDTL3:GetSpellData(0, "Shadowmeld")
CDTL3:CheckEdgeCases("Shadowmeld")
local sm = CDTL3:GetSpellSettings("Shadowmeld", "spells")
if classicLists then
	check("Shadowmeld: saved from the data when the data lists it", (sm ~= nil) == (smData ~= nil), tostring(smData ~= nil))
else
	check("Shadowmeld: data doesn't list it on mop/retail, nothing saved", smData == nil and sm == nil)
end

---------------------------------------------------------------- 4. player cast at a newer rank than the saved one
print("[player rank " .. FLAVOR .. "]")
asClass("MAGE")
SPELLINFO[880001] = { "Ranked Bolt", 135808 }
SPELLINFO[880003] = { "Ranked Bolt", 135808 }
KNOWN[880003] = true
BASECD[880001], BASECD[880003] = 10000, 10000
local cdState = RETAILAPI and { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = true, isOnGCD = false }
	or { startTime = NOW, duration = 10, isEnabled = true, isActive = true, isOnGCD = false }
SPELLCD[880001], SPELLCD[880003] = cdState, cdState
table.insert(spells, entry(880001, "Ranked Bolt", { ME }, { bCD = 10000, rank = "1" }))
local castAt = NOW
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-r", 880003)
local t = CDTL3.spellCastTimes or {}
check("player cast records spellCastTimes[cast id]", t[880003] == castAt, tostring(t[880003]))
check("player cast records spellCastTimes[saved entry id]", t[880001] == castAt, tostring(t[880001]))
local rf = liveFor("Ranked Bolt")
check("player cast at rank 3 starts the rank-1 entry's icon", rf ~= nil and rf.data.id == 880001)
if RETAILAPI and rf then
	local s, d = CDTL3:GetSpellCooldown(880001)
	check("secret fallback by the saved id: start = cast time, duration = base", s == castAt and d == 10, string.format("start=%s dur=%s", tostring(s), tostring(d)))
	RunOnUpdate(0.05, 60)
	check("after 3 s the countdown reads ~7 s (not frozen, not ready early)", math.abs(rf.data.currentCD - 7) < 0.3, string.format("currentCD=%.2f", rf.data.currentCD))
end
-- same rank as saved: one key, same value
local castAt2 = NOW
KNOWN[880001] = true
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-r1", 880001)
check("cast at the saved rank: spellCastTimes[id] = cast time", CDTL3.spellCastTimes[880001] == castAt2)

---------------------------------------------------------------- 5. Clear Settings, shared entries
print("[Clear Settings " .. FLAVOR .. "]")
asClass("MAGE")
local theirs = entry(21, "Theirs", { OTHER })
local theirsOwners = theirs.usedBy
for _, e in ipairs({
	entry(20, "Mine Only", { ME }),
	entry(22, "Mine Twice", { ME, ME }),
	entry(23, "Shared Dup", { ME, OTHER, ME }),
	entry(24, "Shared Three", { OTHER, ME, THIRD }),
	theirs,
	entry(25, "Ownerless", nil),
	entry(26, "Ownerless Empty", {}),
}) do table.insert(spells, e) end
local fopts = CDTL3:GetFilterOptions()
local def = fopts.args.defaults.args
CDTL3.currentFilter["default"] = "SPELLS"
def.clearAll.func({})
local names, n, holes = {}, 0, false
for _, e in pairs(spells) do n = n + 1; names[#names + 1] = e.name end
for i = 1, n do if spells[i] == nil then holes = true end end
table.sort(names)
local function byName(nm) for _, e in ipairs(spells) do if e.name == nm then return e end end end
check("Clear Settings: entries only I use are gone; shared, theirs and ownerless stay",
	table.concat(names, ",") == "Ownerless,Ownerless Empty,Shared Dup,Shared Three,Theirs", table.concat(names, ","))
check("Clear Settings: no holes", not holes and #spells == n)
local sd, s3 = byName("Shared Dup"), byName("Shared Three")
check("Clear Settings: shared entry (me twice) keeps only the other owner", sd and #sd.usedBy == 1 and sd.usedBy[1] == OTHER, sd and table.concat(sd.usedBy, ","))
local function owners(e) local o = {}; for _, x in ipairs(e.usedBy) do o[#o + 1] = x end; table.sort(o); return table.concat(o, ",") end
check("Clear Settings: shared entry (three owners) keeps the other two", s3 and #s3.usedBy == 2 and owners(s3) == table.concat({ THIRD, OTHER }, ","),
	s3 and owners(s3))
check("Clear Settings: shared entries no longer listed for me", sd and s3 and not CDTL3:IsMyEntry(sd) and not CDTL3:IsMyEntry(s3))
check("Clear Settings: their entry untouched (same owners table)", byName("Theirs") and byName("Theirs").usedBy == theirsOwners and #theirsOwners == 1)
check("Clear Settings: shared entry settings untouched", sd and sd.lane == 1 and sd.bCD == 30000 and sd.ignored == false)

---------------------------------------------------------------- 6. Clear Quest Items, shared entries
print("[Clear Quest Items " .. FLAVOR .. "]")
local QUEST = { [7001] = true, [7002] = true, [7003] = true, [7005] = true }
local realInstant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id) return id, "Item", "Misc", "", 134400, QUEST[id] and 12 or 4, 0 end
local function item(itemID, owners) return { id = 60000 + itemID, name = "Use " .. itemID, itemName = "Item " .. itemID, itemID = itemID,
	type = "items", icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1, enabled = true, ignored = false, usedBy = owners } end
local items = clearTable(CDTL3.db.profile.tables["items"])
for _, e in ipairs({
	item(7001, { ME }),          -- quest, only mine
	item(7002, { OTHER, ME }),   -- quest, shared
	item(7003, { OTHER }),       -- quest, theirs
	item(7004, { ME }),          -- not a quest item
	item(7005, nil),             -- quest, ownerless
}) do table.insert(items, e) end
CDTL3.currentFilter["default"] = "ITEMS"
check("Clear Quest Items: description says this character", def.clearQuestItems.desc({}):find("this character", 1, true) ~= nil)
def.clearQuestItems.func({})
items = CDTL3.db.profile.tables["items"]
local byItem = {}
for _, e in pairs(items) do byItem[e.itemID] = e end
check("Clear Quest Items: my-only quest item gone", byItem[7001] == nil)
check("Clear Quest Items: shared quest item kept, only the other owner left", byItem[7002] and #byItem[7002].usedBy == 1 and byItem[7002].usedBy[1] == OTHER,
	byItem[7002] and table.concat(byItem[7002].usedBy, ","))
check("Clear Quest Items: their quest item kept", byItem[7003] and #byItem[7003].usedBy == 1 and byItem[7003].usedBy[1] == OTHER)
check("Clear Quest Items: my non-quest item kept, still mine", byItem[7004] and CDTL3:IsMyEntry(byItem[7004]))
check("Clear Quest Items: ownerless quest item kept", byItem[7005] ~= nil)
check("Clear Quest Items: list has no holes", #items == 4)
C_Item.GetItemInfoInstant = realInstant

print(string.format("RESULT fixes %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
