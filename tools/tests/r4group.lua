-- Group play (Group.lua; feature panel cards 18, 19 and 24): the Caster lane (names under icons, fed by a fake
-- CooldownCollaborator through the timer-type API and, on MoP/TBC/Era, by the combat log), the effect strip on a
-- spell's icon, and the Burst pack with its optional strip. Real files, real AceDB.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"

CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {} } }

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
if g["unlockFrames"] then CDTL3:ToggleFrameLock(true) end
PlaySoundFile = function() return true end
for _, fr in ipairs({ CDTL3_Lane_1, CDTL3_Lane_2, CDTL3_Lane_3, CDTL3_Ready_1, CDTL3_Ready_2, CDTL3_Ready_3 }) do
	if fr then
		if fr.animateOut then fr.animateOut.Play = function() fr:SetAlpha(0) end end
		if fr.animateIn then fr.animateIn.Play = function() fr:SetAlpha(1) end end
	end
end
local function pname(x) return x:GetParent():GetName() end
local function live(name, t) return CDTL3:GetExistingCooldown(name, t) end
local function near(a, b, tol) return type(a) == "number" and math.abs(a - b) <= (tol or 0.05) end
local P = CDTL3.Group
local lane1 = CDTL3.db.profile.lanes["lane1"]

print("[group play " .. FLAVOR .. "]")

---------------------------------------------------------------- nothing changes until turned on
check("a fresh profile: no group settings saved, no feed running, no strip, no extra timer type",
	g.group == nil and not P.raidOn and not P.extOn and CDTL3_BurstStrip == nil and next(CDTL3.timerTypes) == nil and CDTL3.effectsLive == false)
check("  the lane's Caster lane box is off", lane1.casterLane == false)
local n0 = #CDTL3.cooldowns

---------------------------------------------------------------- Caster lane: a fake CooldownCollaborator
RAID_CLASS_COLORS.DRUID = { r = 1, g = 0.49, b = 0.04 }
RAID_CLASS_COLORS.WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }
check("CooldownCollaborator registers its type with CDTL3", CDTL3:RegisterTimerType("cdcGroup", { name = "Group cooldowns", icon = 136080 }) == true)
CDTL3:StartTimer("cdcGroup", "Tania-Realm:Rebirth", { name = "Rebirth", icon = 136080, duration = 600, startedAt = NOW - 30, owner = "Tania-Realm", class = "DRUID" })
CDTL3:StartTimer("cdcGroup", "Brannoc-Realm:Rallying Cry", { name = "Rallying Cry", icon = 132351, duration = 180, startedAt = NOW - 100, owner = "Brannoc-Realm", class = "WARRIOR" })
local rb, rc = live("Rebirth", "cdcgroup"), live("Rallying Cry", "cdcgroup")
check("two casters' timers are on lane 1 with their owner and class", rb and rc and pname(rb.icon) == "CDTL3_Lane_1" and rb.data.owner == "Tania-Realm" and rc.data.class == "WARRIOR")
check("  Caster lane off: no name under either icon", not (rb.icon.cdtl3Caster and rb.icon.cdtl3Caster.__shown) and not (rc.icon.cdtl3Caster and rc.icon.cdtl3Caster.__shown))

-- the lane's own option (the real options tree carries it), then the setter
local function find(node, key, seen)
	seen = seen or {}
	if type(node) ~= "table" or seen[node] then return nil end
	seen[node] = true
	if node.args and node.args[key] then return node.args[key] end
	for _, c in pairs(node.args or {}) do
		local r = find(c, key, seen)
		if r then return r end
	end
end
local opts = CDTL3:GetFullOptions()
local laneGeneral = opts.args.lanes.args.lane1.args.general
local opt, scaleBtn = laneGeneral.args.casterLane, laneGeneral.args.casterScale
check("the lane's General tab has the Caster lane box and the scale button", opt and opt.type == "toggle" and scaleBtn and scaleBtn.type == "execute")
opt.set({}, true)
check("  ticking it saves on the lane", lane1.casterLane == true and opt.get({}) == true)
local fs = rb.icon.cdtl3Caster
check("  each icon shows its caster's short name under it", fs and fs.__shown and fs.__text == "Tania" and rc.icon.cdtl3Caster.__text == "Brannoc", fs and tostring(fs.__text))
local col
fs.SetTextColor = function(self, r, gr, b) col = { r, gr, b } end
CDTL3:RefreshAllIcons()
check("  in the caster's class colour (a druid orange)", col and near(col[1], 1) and near(col[2], 0.49) and near(col[3], 0.04), col and (col[1] .. "," .. col[2]))
check("  it sits under the icon", (function() for _, p in ipairs(fs.__points) do if p[1] == "TOP" and p[3] == "BOTTOM" then return true end end end)())
scaleBtn.func({})
check("  the scale button: Linear (Time), 3 minutes, labelled Ready 45s 1m30s 2m15s 3m", lane1.mode.type == "LINEAR_ABS" and lane1.mode.linearAbs.max == 180
	and lane1.mode.linearAbs.hideTimeSurplus == false and lane1.modeText.text1.text == "Ready" and lane1.modeText.text2.text == "45s"
	and lane1.modeText.text3.text == "1m30s" and lane1.modeText.text4.text == "2m15s" and lane1.modeText.text5.text == "3m")
RunOnUpdate(0.05, 10)
check("  on the fixed scale a 570 s Rebirth sits at the far end, a 80 s Rallying Cry near 44%",
	near(rb.icon.currentCD, 570 - 0.5, 1) and rc.icon.currentCD < 180 and rc.icon.currentCD > 70)
-- a timer with no owner (a plain one) gets no name; a Ready icon keeps the name
CDTL3:StartTimer("cdcGroup", "noowner", { name = "Plain", duration = 60 })
check("  a timer with no owner shows no name", not (live("Plain", "cdcgroup").icon.cdtl3Caster and live("Plain", "cdcgroup").icon.cdtl3Caster.__shown))
CDTL3:StartTimer("cdcGroup", "Odrin-Realm:PWB", { name = "PWB", duration = 2, startedAt = NOW, owner = "Odrin-Realm", class = "PRIEST" })
local pw = live("PWB", "cdcgroup")
RunOnUpdate(0.05, 60)
check("  a ready icon waiting in the Ready frame keeps its caster's name", pname(pw.icon) == "CDTL3_Ready_1_MF" and pw.icon.cdtl3Caster and pw.icon.cdtl3Caster.__shown and pw.icon.cdtl3Caster.__text == "Odrin", pname(pw.icon))
opt.set({}, false)
check("  unticking hides the names again", not fs.__shown and not rc.icon.cdtl3Caster.__shown)
check("the API sees the collaborator's timers like any other", CDTL3.API.GetTimer("cdcgroup", "Tania-Realm:Rebirth") ~= nil)
for _, id in ipairs({ "Tania-Realm:Rebirth", "Brannoc-Realm:Rallying Cry", "noowner" }) do CDTL3:StopTimer("cdcGroup", id) end

---------------------------------------------------------------- Raid cooldowns from the combat log
local logOpen = not RETAILAPI
local list = P.RaidList()
local ally = "Player-9-AAA"
local origInfo = GetPlayerInfoByGUID
GetPlayerInfoByGUID = function(guid)
	if guid == ally then return "WARRIOR", "WARRIOR", "Human", "Human", 2, "Brannoc", "Realm" end
	return origInfo(guid)
end
local function cast(srcGUID, srcName, flags, spellID, spellName, sub)
	if not (C_CombatLog or CombatLogGetCurrentEventInfo) then return end	-- Forever: the game never sends the event
	CLEU_ARGS = { NOW, sub or "SPELL_CAST_SUCCESS", false, srcGUID, srcName, flags, 0, "", "", 0, 0, spellID, spellName, 1, "BUFF" }
	CDTL3:COMBAT_LOG_EVENT_UNFILTERED()
	CLEU_ARGS = nil
end
local PARTY = 0x412
if logOpen then
	check("this client has a raid cooldown list (" .. #list .. " spells)", list and #list >= 10)
	local row = list[1]
	local sname = (GetSpellInfo(row[1]))
	local nb = #CDTL3.cooldowns
	cast(ally, "Brannoc-Realm", PARTY, row[1], sname)
	check("off by default: a party member's cast starts nothing", #CDTL3.cooldowns == nb and live(sname, "raidcds") == nil)
	g.group = nil
	-- the options: the toggle and the tick list are there, the toggle turns the feed on
	local defaults = CDTL3:GetFilterOptions().args.defaults.args
	check("Filters > Defaults has Track raid cooldowns and the tick list", defaults.raidCasts and defaults.raidTicks and defaults.raidCasts.hidden() == false)
	defaults.raidCasts.set({}, true)
	check("  turning it on registers the Raid cooldowns type and saves the setting", CDTL3.timerTypes.raidcds and CDTL3.timerTypes.raidcds.name == "Raid cooldowns"
		and P.raidOn == true and g.group.raidCasts == true)
	check("  the type is in the Defaults list for lane choice", defaults.list.values({})["RAIDCDS"] == "Raid cooldowns")
	check("  the tick list holds this client's spells, all ticked", (function() local v = defaults.raidTicks.values({}); local n = 0 for id in pairs(v) do n = n + 1; if not defaults.raidTicks.get({}, id) then return false end end return n >= 10 end)())
	cast(ally, "Brannoc-Realm", PARTY, row[1], sname)
	local f = live(sname, "raidcds")
	check("a party member's cast puts a timer on lane 1: owner, class, full length", f and pname(f.icon) == "CDTL3_Lane_1" and f.data.owner == "Brannoc-Realm"
		and f.data.class == "WARRIOR" and near(f.data.baseCD, row[2]) and near(f.data.currentCD, row[2], 0.5), f and tostring(f.data.currentCD))
	lane1.casterLane = true
	CDTL3:RefreshAllIcons()
	check("  with Caster lane on it carries the caster's name", f.icon.cdtl3Caster and f.icon.cdtl3Caster.__shown and f.icon.cdtl3Caster.__text == "Brannoc")
	lane1.casterLane = false
	RunOnUpdate(0.1, 100)
	cast(ally, "Brannoc-Realm", PARTY, row[1], sname)
	check("  a second cast restarts the same icon", live(sname, "raidcds") == f and near(f.data.currentCD, row[2], 0.5))
	local nc = #CDTL3.cooldowns
	cast(ally, "Brannoc-Realm", PARTY, 1, "Frostbolt")
	check("a spell that is not on the list is ignored", #CDTL3.cooldowns == nc)
	cast("Player-9-ZZZ", "Stranger-Realm", 0x548, row[1], sname)
	check("a player outside the group is ignored", #CDTL3.cooldowns == nc)
	cast(PLAYER.guid, "Tester", 0x511, row[1], sname)
	check("my own cast is ignored", #CDTL3.cooldowns == nc)
	cast("Pet-1-AAA", "Wolf", 0x1112, row[1], sname)
	check("a pet's cast is ignored", #CDTL3.cooldowns == nc)
	local row2 = list[2]
	local sname2 = (GetSpellInfo(row2[1]))
	defaults.raidTicks.set({}, row2[1], false)
	cast(ally, "Brannoc-Realm", PARTY, row2[1], sname2)
	check("unticking a spell stops it", live(sname2, "raidcds") == nil and defaults.raidTicks.get({}, row2[1]) == false)
	defaults.raidTicks.set({}, row2[1], true)
	cast(ally, "Brannoc-Realm", PARTY, row2[1], sname2)
	check("  ticking it again starts it", live(sname2, "raidcds") ~= nil)
	cast(ally, "Brannoc-Realm", PARTY, row[1], sname, "SPELL_AURA_APPLIED")
	check("only a successful cast counts", true)
	defaults.raidCasts.set({}, false)
	local nn = #CDTL3.cooldowns
	cast("Player-9-BBB", "Odrin-Realm", PARTY, row[1], sname)
	check("  switched off again: nothing new", P.raidOn == false and #CDTL3.cooldowns == nn)
else
	check("no combat log here: no list, the Raid cooldowns controls are hidden, the feed can't run", list == nil
		and CDTL3:GetFilterOptions().args.defaults.args.raidCasts.hidden() == true)
	g.group = nil
	CDTL3:GetFilterOptions().args.defaults.args.raidCasts.set({}, true)
	cast(ally, "Brannoc-Realm", PARTY, 29166, "Innervate")
	check("  even with the setting on nothing starts and no type is made", P.raidOn == false and CDTL3.timerTypes.raidcds == nil)
	CDTL3.db.profile.global.group.raidCasts = false
	P.Apply()
end

---------------------------------------------------------------- Effect on target (strip on the cooldown icon)
local EID, ENAME = 102342, "Ironbark"
SPELLINFO[EID] = { ENAME, 135966 }
KNOWN[EID] = true
local entry = CDTL3:NewSpellEntry(EID, ENAME, 135966, "spells")
entry.bCD = 90000
entry.ignored = false
entry.enabled = true
CDTL3:SaveNewEntry(entry, "spells", true)
local sf = CDTL3:CreateCooldown(CDTL3:GetUID(), "spells", entry)
SPELLCD[EID] = { startTime = NOW - 3, duration = 90, isEnabled = true, isActive = true, modRate = 1, isOnGCD = false }
sf.data.currentCD = 87
sf.data.baseCD = 90
local filt = CDTL3:GetFilterOptions()
local showOpt, lenOpt = find(filt, "showEffect"), find(filt, "effectLength")
check("Filters > Spells has Show effect on target and Effect length (and no other tab does)", showOpt and lenOpt and find(filt.args.buffs or {}, "showEffect") == nil)
CDTL3.currentFilter["spells"] = ENAME
CDTL3.currentFilterHidden["spells"] = false
check("  off by default; Effect length stays hidden until it is on", showOpt.get({}) == false and lenOpt.hidden({}) == true)
RunOnUpdate(0.05, 5)
check("  with it off a cast on a friend draws no strip", (function()
	if logOpen then cast(PLAYER.guid, "Tester", 0x511, EID, ENAME, "SPELL_AURA_APPLIED") end
	RunOnUpdate(0.05, 3)
	return sf.icon.cdtl3Strip == nil and CDTL3.effectsLive == false
end)())
showOpt.set({}, true)
check("  ticking it saves on the entry and turns the watch on", entry.showEffect == true and P.extOn == true and lenOpt.hidden({}) == false)
lenOpt.set({}, 12)
check("  Effect length saves", lenOpt.get({}) == 12 and entry.effectLength == 12)

local strip
if logOpen then
	-- Classic: exact. The aura really lands on Thrallson, and the game says how long it lasts.
	AURAS = { HELPFUL = { { name = ENAME, icon = 135966, applications = 1, duration = 11, expirationTime = NOW + 11, spellId = EID } } }
	local oldGUID = UnitGUID
	UnitGUID = function(u) if u == "target" then return "Player-9-THR" end return oldGUID(u) end
	local oldInfo2 = GetPlayerInfoByGUID
	GetPlayerInfoByGUID = function(guid) if guid == "Player-9-THR" then return "WARRIOR", "WARRIOR", "Orc", "Orc", 2, "Thrallson", "Realm" end return oldInfo2(guid) end
	CLEU_ARGS = { NOW, "SPELL_AURA_APPLIED", false, PLAYER.guid, "Tester", 0x511, 0, "Player-9-THR", "Thrallson-Realm", 0x512, 0, EID, ENAME, 1, "BUFF" }
	CDTL3:COMBAT_LOG_EVENT_UNFILTERED()
	CLEU_ARGS = nil
	RunOnUpdate(0.05, 20)
	strip = sf.icon.cdtl3Strip
	check("Classic: my aura landing on Thrallson draws the strip on my Ironbark icon with his name", strip and strip.shown and strip.name.__text == "Thrallson", strip and tostring(strip.name.__text))
	check("  the length is the one the game reports (11 s), counted from the landing", near(P.effects[ENAME].len, 11) and near(P.effects[ENAME].untilT, NOW - 1 + 11, 0.5))
	check("  not dimmed (exact), and the time text counts down", strip.__alpha == 1 and tonumber(strip.time.__text) and near(tonumber(strip.time.__text), 10, 0.2), tostring(strip.time.__text))
	check("  the fill is about 91% of the icon's width", near(strip.fill.__w, strip.__w * (10 / 11), 1.5), tostring(strip.fill.__w) .. "/" .. tostring(strip.__w))
	check("  the cooldown icon itself is untouched (still on the lane, still counting)", pname(sf.icon) == "CDTL3_Lane_1" and sf.data.currentCD > 80)
	CLEU_ARGS = { NOW, "SPELL_AURA_REMOVED", false, PLAYER.guid, "Tester", 0x511, 0, "Player-9-THR", "Thrallson-Realm", 0x512, 0, EID, ENAME, 1, "BUFF" }
	CDTL3:COMBAT_LOG_EVENT_UNFILTERED()
	CLEU_ARGS = nil
	check("  removed early (a dispel): the strip goes at once, exactly", strip.shown == false and CDTL3.effectsLive == false)
	-- someone else's aura, or one on myself: ignored
	CLEU_ARGS = { NOW, "SPELL_AURA_APPLIED", false, "Player-9-ZZZ", "Other", 0x512, 0, "Player-9-THR", "Thrallson-Realm", 0x512, 0, EID, ENAME, 1, "BUFF" }
	CDTL3:COMBAT_LOG_EVENT_UNFILTERED()
	CLEU_ARGS = { NOW, "SPELL_AURA_APPLIED", false, PLAYER.guid, "Tester", 0x511, 0, PLAYER.guid, "Tester", 0x511, 0, EID, ENAME, 1, "BUFF" }
	CDTL3:COMBAT_LOG_EVENT_UNFILTERED()
	CLEU_ARGS = nil
	check("  an aura from someone else, or on myself, draws nothing", CDTL3.effectsLive == false)
	-- the game gives no length: the entry's Effect length is used
	AURAS = nil
	CLEU_ARGS = { NOW, "SPELL_AURA_APPLIED", false, PLAYER.guid, "Tester", 0x511, 0, "Player-9-THR", "Thrallson-Realm", 0x512, 0, EID, ENAME, 1, "BUFF" }
	CDTL3:COMBAT_LOG_EVENT_UNFILTERED()
	CLEU_ARGS = nil
	check("  with no readable length the entry's Effect length (12 s) is used", near(P.effects[ENAME].len, 12))
	RunOnUpdate(0.1, 130)
	check("  and the strip ends by itself when the time is up", strip.shown == false and CDTL3.effectsLive == false and #ERRORS == base)
	UnitGUID, GetPlayerInfoByGUID = oldGUID, oldInfo2
else
	-- Retail and Forever: an estimate from my own cast
	TARGET = "friend"
	local oldName, oldClass = UnitName, UnitClass
	UnitName = function(u) if u == "target" then return "Thrallson-Realm" end return oldName(u) end
	UnitClass = function(u) if u == "target" then return "Warrior", "WARRIOR", 1 end return oldClass(u) end
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", EID)
	RunOnUpdate(0.05, 20)
	strip = sf.icon.cdtl3Strip
	check("Retail/Forever: my cast on a friendly target draws the strip with the target's name", strip and strip.shown and strip.name.__text == "Thrallson", strip and tostring(strip.name.__text))
	check("  it is an estimate, so it is dimmed, with the entry's 12 s length", strip.__alpha < 1 and P.effects[ENAME].estimated == true and near(P.effects[ENAME].len, 12))
	check("  the time text counts down from the cast", tonumber(strip.time.__text) and near(tonumber(strip.time.__text), 11, 0.3), tostring(strip.time.__text))
	-- a name the game hides: time only
	UnitName = function(u) if u == "target" then return SECRET end return oldName(u) end
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", EID)
	RunOnUpdate(0.05, 5)
	check("  a hidden name: no name, still the strip, no error", strip.shown and strip.name.__text == "" and #ERRORS == base, tostring(strip.name.__text))
	-- no friendly target
	TARGET = nil
	CDTL3.Group.effects[ENAME].active = false
	CDTL3.effectsLive = false
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-3", EID)
	check("  a cast with no friendly target still counts, without a name", P.effects[ENAME].active == true and P.effects[ENAME].name == nil)
	RunOnUpdate(0.1, 140)
	check("  and it ends by itself", strip.shown == false and CDTL3.effectsLive == false)
	UnitName, UnitClass = oldName, oldClass
end
showOpt.set({}, false)
check("unticking Show effect on target switches the watch off", entry.showEffect == nil and P.extOn == false)

---------------------------------------------------------------- Burst pack
local lanes = CDTL3.db.profile.lanes
check("before the pack: lanes keep their names and scale, no Burst strip", lanes.lane3.name == "Lane 3" and lanes.lane3.mode.type ~= "SPLIT_ABS" and CDTL3_BurstStrip == nil)
local EQUIP = { [13] = 100, [14] = 101 }
GetInventoryItemID = function(_, slot) return EQUIP[slot] end
ITEMSPELL = { [100] = { "Relic Use", 9001 }, [101] = { "Figurine Use", 9002 }, [200] = { "Healing Potion Use", 9003 } }
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end
C_Container.GetContainerItemID = function(bag, slot) if bag == 0 and slot == 1 then return 300 elseif bag == 0 and slot == 2 then return 200 end end
local oldInstant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(id)
	if id == 200 then return id, "Consumable", "Potion", "", 134400, 0, 1 end
	return oldInstant(id)
end
if C_Item.GetItemInfoInstant ~= oldInstant and GetItemInfoInstant then GetItemInfoInstant = function(id) return C_Item.GetItemInfoInstant(id) end end

local expectAuras = ({ era = 0, forever = 0, tbc = 2, mop = 8, retail = 10 })[FLAVOR]
-- a lust timer already saved on lane 1 and counting: the pack moves it, it does not restart
local lustRow = P.BurstList() and P.BurstList()[1]
local lustName, lustEntry, lustF
if lustRow then
	lustName = (GetSpellInfo and GetSpellInfo(lustRow[1])) or (C_Spell.GetSpellInfo(lustRow[1]) or {}).name
	lustEntry = CDTL3:ApplyEntryDefaults({ id = lustRow[1], name = lustName, icon = 136012, type = "customs", bCD = 40000, setCustomCD = false, triggerType = "aura" }, "customs")
	lustEntry.ignored = false
	table.insert(CDTL3.db.profile.tables.customs, lustEntry)
	lustF = CDTL3:CreateCooldown(CDTL3:GetUID(), "customs", lustEntry)
	lustF.data.currentCD = 25
	check("a saved lust timer is counting on lane 1", pname(lustF.icon) == "CDTL3_Lane_1")
end

local filterDefaults = CDTL3:GetFilterOptions().args.defaults.args
check("Filters > Defaults has the Burst pack button, the Burst lane choice and the Burst strip box", filterDefaults.burstPack and filterDefaults.burstPack.type == "execute"
	and filterDefaults.burstLane and filterDefaults.burstStrip and filterDefaults.burstStrip.type == "toggle")
check("  the lane choice defaults to lane 3", filterDefaults.burstLane.get({}) == 3)
filterDefaults.burstPack.func({})
local nAura = 0
for _, e in pairs(CDTL3.db.profile.tables.customs) do
	if e.burst == "lust" or e.burst == "sated" then
		nAura = nAura + 1
		if not (e.lane == 3 and e.readyFrame == 3 and e.ignored == false and e.enabled == true and e.triggerType == "aura") then nAura = -100 end
	end
end
check("the pack adds this client's lust/Sated timers (" .. expectAuras .. ") as aura customs on lane 3, Ready 3", nAura == expectAuras, tostring(nAura))
if FLAVOR == "mop" or FLAVOR == "retail" then
	local hasSated = false
	for _, e in pairs(CDTL3.db.profile.tables.customs) do if e.burst == "sated" and e.bCD == 600000 then hasSated = true end end
	check("  Sated and Exhaustion are there, 10 minutes", hasSated)
elseif FLAVOR == "tbc" then
	local hasSated = false
	for _, e in pairs(CDTL3.db.profile.tables.customs) do if e.burst == "sated" then hasSated = true end end
	check("  TBC has Bloodlust and Heroism but no Sated", not hasSated and nAura == 2)
else
	check("  this client has no lust at all: trinkets and potion only", nAura == 0)
end
if lustF then
	check("  the already-counting lust timer moved to lane 3 and kept its time", pname(lustF.icon) == "CDTL3_Lane_3" and near(lustF.data.currentCD, 25, 1) and lustEntry.burst == "lust")
end
local trinkets, potion = {}, nil
for _, e in pairs(CDTL3.db.profile.tables.items) do
	if e.burst == "trinket" then trinkets[#trinkets + 1] = e elseif e.burst == "potion" then potion = e end
end
check("  both worn trinkets with an on-use effect are items on lane 3", #trinkets == 2 and trinkets[1].lane == 3 and trinkets[2].lane == 3 and trinkets[1].ignored == false)
check("  the carried potion is too (the first with a use spell), not the other bag item", potion and potion.itemID == 200 and potion.lane == 3 and potion.readyFrame == 3)
check("  lane 3 is named Burst and on the long-buff scale (Split Time, 1 hour)", lanes.lane3.name == "Burst" and lanes.lane3.mode.type == "SPLIT_ABS"
	and lanes.lane3.mode.splitAbs.max == 3600 and lanes.lane3.mode.splitAbs.hideTimeSurplus == false and lanes.lane3.enabled == true)
check("  lanes 1 and 2 are unchanged", lanes.lane1.name == "Lane 1" and lanes.lane2.name == "Lane 2" and lanes.lane1.mode.type == "LINEAR_ABS" or lanes.lane1.mode.type == "LINEAR")
local nEntries = #CDTL3.db.profile.tables.customs + #CDTL3.db.profile.tables.items
filterDefaults.burstPack.func({})
check("pressing it again adds nothing", #CDTL3.db.profile.tables.customs + #CDTL3.db.profile.tables.items == nEntries)
filterDefaults.burstLane.set({}, 2)
filterDefaults.burstPack.func({})
check("a different Burst lane moves the whole pack there", (function() for _, e in pairs(CDTL3.db.profile.tables.items) do if e.burst and e.lane ~= 2 then return false end end return lanes.lane2.name == "Burst" end)())
filterDefaults.burstLane.set({}, 3)
filterDefaults.burstPack.func({})

---------------------------------------------------------------- Burst strip
check("the Burst strip is off by default: no frame", CDTL3_BurstStrip == nil and filterDefaults.burstStripX.hidden() == true)
filterDefaults.burstStrip.set({}, true)
local st = CDTL3_BurstStrip
check("turning it on builds it: five fixed slots, Lust, Sated, Trinket 1, Trinket 2, Potion", st and st:IsShown() and #st.slots == 5
	and st.slots[1].label.__text == "Lust" and st.slots[2].label.__text == "Sated" and st.slots[3].label.__text == "Trinket 1"
	and st.slots[4].label.__text == "Trinket 2" and st.slots[5].label.__text == "Potion")
check("  its position sliders show up and move it", filterDefaults.burstStripX.hidden() == false)
filterDefaults.burstStripX.set({}, 120)
filterDefaults.burstStripY.set({}, -80)
check("  position saved and applied", g.group.stripX == 120 and g.group.stripY == -80 and (function() for _, p in ipairs(st.__points) do if p[1] == "CENTER" and p[4] == 120 and p[5] == -80 then return true end end end)())
RunOnUpdate(0.3, 2)
check("  trinket slots and the potion read ready, nothing has run yet", st.slots[3].state.__text == "ready" and st.slots[4].state.__text == "ready" and st.slots[5].state.__text == "ready",
	tostring(st.slots[3].state.__text) .. "/" .. tostring(st.slots[5].state.__text))
if lustF then
	check("  the lust slot says up and counts the seconds left", st.slots[1].state.__text == "up" and st.slots[1].count.__text == "25", tostring(st.slots[1].state.__text) .. " " .. tostring(st.slots[1].count.__text))
	check("  the Sated slot has no timer to show: ready", st.slots[2].state.__text == (FLAVOR == "tbc" and "-" or "ready"))
else
	check("  no lust or Sated on this client: those two slots show a dash", st.slots[1].state.__text == "-" and st.slots[2].state.__text == "-", tostring(st.slots[1].state.__text))
end
-- a trinket's cooldown running: the slot says cooling
local tr
for _, e in pairs(CDTL3.db.profile.tables.items) do if e.burst == "trinket" and e.itemID == 101 then tr = e end end
local trF = CDTL3:CreateCooldown(CDTL3:GetUID(), "items", tr)
ITEMCD = { [101] = { NOW - 25, 120, 1 } }
trF.data.currentCD = 95
RunOnUpdate(0.3, 2)
check("  a trinket on cooldown: its slot says cooling with the time (1:35)", st.slots[4].state.__text == "cooling" and tostring(st.slots[4].count.__text):match("^1:3%d$") ~= nil,tostring(st.slots[4].state.__text) .. " " .. tostring(st.slots[4].count.__text))
-- dragging: only while the frames are unlocked
local before = g.group.stripX
st.__scripts.OnDragStart(st)
check("  a drag does nothing while the frames are locked", before == g.group.stripX)
filterDefaults.burstStrip.set({}, false)
check("turning it off hides it", not st:IsShown())

check("no lua errors", #ERRORS == base, tostring(#ERRORS - base))
print(string.format("RESULT r4group %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
