-- Area 3: item relearn, MoveToLane (and the three controls that use it), bulk Filters controls on a
-- two-character profile, and the oaf hold release under SECRET cooldowns. Real files, real AceDB.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "ROGUE"
local ME, OTHER = PLAYER.guid, "Player-1-0000099"

-- a shared profile that already holds another character's entries (and one used by both)
local function entry(id, name, owners, extra)
	local e = { id = id, name = name, type = "spells", icon = 1, bCD = 30000, lane = 1, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = owners, setCustomCD = false }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default", ["Other - Realm"] = "Default" }, profiles = { Default = { tables = {
	spells = {
		entry(11, "Mine A", { ME }),
		entry(12, "Theirs B", { OTHER }, { lane = 3, barFrame = 3, readyFrame = 3, bCD = 600000, ignored = true }),
		entry(13, "Shared C", { OTHER, ME }),
		entry(14, "Theirs D", { OTHER }, { bCD = 2000, ignored = false }),
	},
} } } }

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end
local function poll(f, frames) for _ = 1, frames or 1 do NOW = NOW + 0.02; f.__scripts.OnUpdate(f, 0.02) end end
local function pollTo(f, seconds) local n = math.floor(seconds / 0.02 + 0.5); poll(f, n) end
local sounds = 0
PlaySoundFile = function() sounds = sounds + 1; return true end
local g = CDTL3.db.profile.global

---------------------------------------------------------------- 1. item relearn
print("[items " .. FLAVOR .. "]")
g["items"]["ignoreThreshold"] = 600
GetInventoryItemID = function(_, slot) if slot == 13 then return 5001 end end
ITEMSPELL = { [5001] = { "Use Trinket", 99001 } }
SPELLINFO[99001] = { "Use Trinket", 1 }
ITEMCD = {}
local function useItem() FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-i", 99001) end
local function itemFrame() return CDTL3:GetExistingCooldown("Use Trinket", "items") end
local function savedItem() return CDTL3:GetSpellSettings("Item 5001", "items", true) end

-- (a) positive read teaches
useItem()
local f = itemFrame()
check("first use saves the item and starts a frame (bCD 0)", f ~= nil and savedItem() and savedItem().bCD == 0)
ITEMCD[5001] = { NOW, 45 }
poll(f, 1)
check("(a) positive read right after use: learns 45 s, not ignored", f.data.baseCD == 45 and savedItem().bCD == 45000 and savedItem().ignored == false,
	string.format("baseCD=%s bCD=%s ignored=%s", tostring(f.data.baseCD), tostring(savedItem().bCD), tostring(savedItem().ignored)))

-- reset the item to "unlearned" for the next cases
local function resetItem()
	local s = savedItem(); s.bCD = 0; s.ignored = nil
	f.data.baseCD = 0; f.data.ignored = nil
	ITEMCD[5001] = nil
end

-- (b) readable 0 within 2 s of the use: "no cooldown" -> ignored
resetItem()
useItem()
ITEMCD[5001] = { 0, 0 }
pollTo(f, 1.0)   -- polls at 0 and 50 frames (1 s) after the use
check("(b) readable 0 within 2 s: learns no cooldown, ignored", savedItem().bCD == 0 and savedItem().ignored == true and f.data.ignored == true,
	string.format("bCD=%s ignored=%s", tostring(savedItem().bCD), tostring(savedItem().ignored)))

-- (c) secret until after the window, then readable 0: teaches nothing, ends the countdown
resetItem()
useItem()
local secretRead = RETAILAPI
if secretRead then
	ITEMCD[5001] = { SECRET, SECRET }
	pollTo(f, 3.0)
	check("(c) while secret: nothing learned, still counting", savedItem().bCD == 0 and savedItem().ignored == nil and f.data.currentCD > 0,
		string.format("currentCD=%.1f", f.data.currentCD))
else
	-- classic has no secret values: the "later 0" case is a 0 read first seen after the window
	-- (e.g. the frame was hidden); skip the early polls
	NOW = NOW + 3
end
ITEMCD[5001] = { 0, 0 }
poll(f, 50)
check("(c) later readable 0: nothing learned, not ignored", savedItem().bCD == 0 and savedItem().ignored == nil,
	string.format("bCD=%s ignored=%s", tostring(savedItem().bCD), tostring(savedItem().ignored)))
check("(c) later readable 0: the countdown ends (ready)", f.data.currentCD < 0, string.format("currentCD=%.1f", f.data.currentCD))

-- (d) ready item: further reads (0 or positive) don't restart or teach
ITEMCD[5001] = { 0, 0 }
poll(f, 150)
check("(d) ready item, readable 0 polls: stays ready, nothing learned", f.data.currentCD < 0 and savedItem().bCD == 0, string.format("currentCD=%.1f", f.data.currentCD))
ITEMCD[5001] = { NOW, 60 }
poll(f, 100)
check("(d) ready item, positive read without a use: still waits for its use", f.data.currentCD < 0 and savedItem().bCD == 0, string.format("currentCD=%.1f bCD=%s", f.data.currentCD, tostring(savedItem().bCD)))
-- (e) next use learns
ITEMCD[5001] = nil
useItem()
ITEMCD[5001] = { NOW, 60 }
poll(f, 1)
check("(e) next use: learns 60 s", savedItem().bCD == 60000 and f.data.baseCD == 60, string.format("bCD=%s", tostring(savedItem().bCD)))
-- (f) a learned item reading 0 when ready keeps its cooldown
ITEMCD[5001] = { 0, 0 }
poll(f, 50)
check("(f) learned item, 0 read: ready, cooldown kept", f.data.baseCD == 60 and savedItem().bCD == 60000 and f.data.currentCD < 0,
	string.format("baseCD=%s currentCD=%.1f", tostring(f.data.baseCD), f.data.currentCD))

---------------------------------------------------------------- 2. MoveToLane + its three callers
print("[MoveToLane " .. FLAVOR .. "]")
CDTL3.player = {}; CDTL3:GetCharacterData()
local spells = CDTL3.db.profile.tables["spells"]
local function liveFor(name) return CDTL3:GetExistingCooldown(name, "spells") end
SPELLINFO[11] = { "Mine A", 1 }; SPELLINFO[13] = { "Shared C", 1 }
local a = CDTL3:CreateCooldown(CDTL3:GetUID(), "spells", spells[1])
local c = CDTL3:CreateCooldown(CDTL3:GetUID(), "spells", spells[3])
a.data.currentCD = 12.5           -- counting
c.data.currentCD = -1             -- finished
CDTL3:SendToReady(c)
local cParent = c.icon:GetParent()
sounds = 0
a.data.lane = 2; c.data.lane = 2
CDTL3:MoveToLane(a); CDTL3:MoveToLane(c)
check("MoveToLane: counting icon moves to lane 2 and keeps 12.5 s", a.icon:GetParent() == CDTL3_Lane_2 and a.data.currentCD == 12.5, tostring(a.data.currentCD))
check("MoveToLane: finished icon stays put, still ready, no sound", c.icon:GetParent() == cParent and c.data.currentCD == -1 and sounds == 0)

-- Filters -> Spells -> lane picker
local fopts = CDTL3:GetFilterOptions()
local laneCtl
local function findLane(t)
	for k, v in pairs(t) do
		if type(v) == "table" then
			if k == "lane" and v.type == "select" and type(v.set) == "function" then laneCtl = laneCtl or v end
			findLane(v)
		end
	end
end
findLane(fopts.args.spells)
CDTL3.currentFilter["spells"] = "Mine A"
a.data.currentCD = 8
laneCtl.set({}, 3)
check("Filters lane picker: counting icon to lane 3, keeps 8 s", a.icon:GetParent() == CDTL3_Lane_3 and a.data.currentCD == 8 and spells[1].lane == 3,
	string.format("cd=%s saved lane=%s", tostring(a.data.currentCD), tostring(spells[1].lane)))
CDTL3.currentFilter["spells"] = "Shared C"
laneCtl.set({}, 1)
check("Filters lane picker: finished icon stays put", c.icon:GetParent() == cParent and c.data.currentCD == -1)

---------------------------------------------------------------- 3. bulk Filters controls, two characters
print("[bulk Filters " .. FLAVOR .. "]")
local def = fopts.args.defaults.args
CDTL3.currentFilter["default"] = "SPELLS"
local function snap(i) local e = spells[i]; return string.format("%s|%s|%s|%s|%s", tostring(e.ignored), tostring(e.lane), tostring(e.barFrame), tostring(e.readyFrame), tostring(e.bCD)) end
local function byName(n) for _, e in ipairs(spells) do if e.name == n then return e end end end
local B0, D0 = snap(2), snap(4)

-- Ignore Threshold slider: 20 s -> A and C (30 s) ignored; B (600 s) / D (2 s) are another character's
a.data.currentCD = 5
def.ignoreThreshold.set({}, 20)
check("slider: my entries recomputed (A, C ignored at 20 s)", byName("Mine A").ignored == true and byName("Shared C").ignored == true)
check("slider: other character's entries untouched", snap(2) == B0 and snap(4) == D0, snap(2) .. " / " .. snap(4))
def.ignoreThreshold.set({}, 1800)
check("slider back to 1800: A and C shown again", byName("Mine A").ignored == false and byName("Shared C").ignored == false)
check("slider: counting icon kept its time (MoveToLane)", math.abs(a.data.currentCD - 5) < 1e-9, tostring(a.data.currentCD))

-- Set All x3
g["spells"]["defaultLane"], g["spells"]["defaultBar"], g["spells"]["defaultReady"] = 2, 2, 2
a.data.currentCD = 6
def.setDefaultLane.func({})
def.setDefaultBar.func({})
def.setDefaultReady.func({})
local A = byName("Mine A")
check("Set All lane/bar/ready: my entries set to 2", A.lane == 2 and A.barFrame == 2 and A.readyFrame == 2 and byName("Shared C").lane == 2)
check("Set All: other character's entries untouched", snap(2) == B0 and snap(4) == D0, snap(2) .. " / " .. snap(4))
check("Set All lane: counting icon kept its time", math.abs(a.data.currentCD - 6) < 1e-9 and a.icon:GetParent() == CDTL3_Lane_2, tostring(a.data.currentCD))

-- Clear Settings
def.clearAll.func({})
local names, n, holes = {}, 0, false
for k, e in pairs(spells) do n = n + 1; names[#names + 1] = e.name end
for i = 1, n do if spells[i] == nil then holes = true end end
table.sort(names)
check("Clear Settings: my-only entry gone, shared and theirs kept", table.concat(names, ",") == "Shared C,Theirs B,Theirs D", table.concat(names, ","))
check("Clear Settings: list has no holes", not holes and #spells == n)
local function snapE(e) return string.format("%s|%s|%s|%s|%s", tostring(e.ignored), tostring(e.lane), tostring(e.barFrame), tostring(e.readyFrame), tostring(e.bCD)) end
check("Clear Settings: their entries unchanged", snapE(byName("Theirs B")) == B0 and snapE(byName("Theirs D")) == D0)
local sc = byName("Shared C")
check("Clear Settings: shared entry keeps only the other character", sc and #sc.usedBy == 1 and sc.usedBy[1] == OTHER and not CDTL3:IsMyEntry(sc),
	sc and table.concat(sc.usedBy, ",") or "gone")
check("Clear Settings: their entries' owners unchanged", #byName("Theirs B").usedBy == 1 and byName("Theirs B").usedBy[1] == OTHER)

---------------------------------------------------------------- 4. oaf hold release with secret cooldowns
if RETAILAPI then
	print("[oaf release " .. FLAVOR .. "]")
	-- Stealth: in Forever's data with oaf = true
	local sd
	for _, s in ipairs(CDTL3.spellData) do if s.name == "Stealth" then sd = s end end
	check("Stealth is an oaf spell in this client's data", sd and sd.oaf, sd and tostring(sd.id))
	local id = sd.id
	SPELLINFO[id] = { "Stealth", 132320 }
	KNOWN[id] = true
	BASECD[id] = 10000
	g["spells"]["ignoreThreshold"] = 1800
	local stealthAura = { name = "Stealth", spellId = id, duration = 0, icon = 132320, applications = 0, expirationTime = 0 }
	AURAS = { HELPFUL = { stealthAura }, HARMFUL = {} }
	SPELLCD[id] = { startTime = 0, duration = 0, isEnabled = false, isActive = false, isOnGCD = false }  -- held: not started
	local castAt = NOW
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-s", id)
	local st = liveFor("Stealth")
	check("Stealth cast: live frame, oaf flag set", st ~= nil and st.data.oaf, st and tostring(st.data.oaf))
	pollTo(st, 20)
	check("held 20 s: countdown not running", st.data.oafHeld == true and st.data.currentCD == st.data.baseCD, string.format("held=%s cd=%s", tostring(st.data.oafHeld), tostring(st.data.currentCD)))
	-- leave stealth: the cooldown starts now, and its values are secret
	AURAS = { HELPFUL = {}, HARMFUL = {} }
	SPELLCD[id] = { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = true, isOnGCD = false }
	local releaseAt = NOW
	pollTo(st, 1.0)
	local wrote = CDTL3.spellCastTimes[id]
	check("release: spellCastTimes[id] moved from the cast to the release", wrote and wrote > castAt + 19 and wrote <= releaseAt + 1.0,
		string.format("cast=%.2f release=%.2f written=%s", castAt, releaseAt, tostring(wrote)))
	pollTo(st, 2.0)
	local elapsed = NOW - wrote
	check("3 s after release: secret fallback counts from the release (~7 s left)", math.abs(st.data.currentCD - (10 - elapsed)) < 0.1 and st.data.currentCD > 6,
		string.format("currentCD=%.2f", st.data.currentCD))
	-- a channel mid-cooldown holds the icon but must not move the start
	local before = CDTL3.spellCastTimes[id]
	UnitChannelInfo = function() return "Channel" end
	pollTo(st, 1.0)
	UnitChannelInfo = function() return nil end
	pollTo(st, 1.0)
	check("channel mid-cooldown: start not rewritten", CDTL3.spellCastTimes[id] == before)
end

print(string.format("RESULT cooldown3 %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS))
