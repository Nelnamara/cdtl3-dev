-- Setups (Start.lua): a setup never changes an entry or a per-type default set to Hide (lane 0), and a preview
-- belongs to the profile it started in: a profile change undoes it there first, Keep and Undo leave no
-- setupUndo behind in any profile.
--   node run.js <addon> <toc number> r4fix2.lua <toc file>
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME = PLAYER.guid
local function entry(id, name, lane)
	return { id = id, name = name, type = "spells", icon = 1, bCD = 30000, lane = lane, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
end
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = {
	Default = { lanes = { lane1 = { icons = { size = 50 } } }, global = { debuffs = { defaultLane = 0 } },
		tables = { spells = { entry(801, "Hidden Spell", 0), entry(802, "Mine", 2) } } },
	Alt = { lanes = { lane1 = { icons = { size = 33 } } } },
} }
LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, tostring(detail or "")))
end
local S = CDTL3.Start
local DB = CDTL3.db
local P = DB.profile

print("[setups keep Hide " .. FLAVOR .. "]")
S.PreviewSetup("dps")
check("a preview leaves a Hide entry and a Hide per-type default alone", P.tables.spells[1].lane == 0 and P.global.debuffs.defaultLane == 0,
	tostring(P.tables.spells[1].lane) .. " / " .. tostring(P.global.debuffs.defaultLane))
check("  while it moves the others", P.tables.spells[2].lane ~= nil and P.global.spells.defaultLane ~= 0)
S.KeepSetup()
check("Keep leaves them alone too", P.tables.spells[1].lane == 0 and P.global.debuffs.defaultLane == 0)
check("  and no setupUndo is left behind", P.global.setupUndo == nil)
S.PreviewSetup("tank")
S.UndoSetup()
check("Undo puts the Hide values back as they were", P.tables.spells[1].lane == 0 and P.global.debuffs.defaultLane == 0 and P.tables.spells[2].lane == 2)

print("[a preview belongs to its profile " .. FLAVOR .. "]")
DB:SetProfile("Default")
S.PreviewSetup("healer")
check("previewing in Default: it waits, saved with Default", S.pending ~= nil and DB.profiles.Default.global.setupUndo ~= nil)
DB:SetProfile("Alt")
check("a profile switch undoes the preview first", S.pending == nil and DB:GetCurrentProfile() == "Alt")
check("  Default's own lanes are back and no setupUndo is left in it", DB.profiles.Default.lanes.lane1.icons.size == 50 and DB.profiles.Default.global.setupUndo == nil)
check("  the profile switched to is untouched", DB.profile.lanes.lane1.icons.size == 33 and DB.profile.global.setupUndo == nil)
S.UndoSetup()
check("  a late Undo does nothing to either profile", DB.profiles.Alt.lanes.lane1.icons.size == 33 and DB.profiles.Default.lanes.lane1.icons.size == 50)

-- the same from Alt, then Keep after previewing again, in the new profile
S.PreviewSetup("tank")
check("a preview in Alt is saved with Alt", DB.profiles.Alt.global.setupUndo ~= nil and DB.profiles.Default.global.setupUndo == nil)
S.KeepSetup()
check("Keep in Alt clears Alt's setupUndo", DB.profiles.Alt.global.setupUndo == nil and S.pending == nil)
DB:SetProfile("Default")
check("  switching later changes nothing (nothing pending)", DB:GetCurrentProfile() == "Default" and DB.profile.global.setupUndo == nil)

check("no Lua errors", #ERRORS == base, #ERRORS - base)
print(string.format("RESULT r4fix2 %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
