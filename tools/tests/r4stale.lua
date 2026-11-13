-- A setup previewed on screen (Start.lua, card 3) and neither kept nor undone before a reload must be UNDONE on the
-- next login, never count as kept. The saved variables below are what a reload leaves behind: the Healer setup's
-- values in the profile, plus the copy of the old lanes the preview saved (global.setupUndo).
--   node run.js <addon> <toc number> r4stale.lua <toc file>
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local ME = PLAYER.guid

local function max(n) return { linear = { max = n }, linearAbs = { max = n }, split = { max = n }, splitAbs = { max = n } } end
local function types(v) return { spells = v, petspells = v, items = v, buffs = v, debuffs = v } end
local function entry(id, name, lane)
	return { id = id, name = name, type = "spells", icon = 1, bCD = 30000, lane = lane, barFrame = 1, readyFrame = 1,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME }, setCustomCD = false }
end

CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {
	-- what the Healer preview wrote (the lanes it set, the gauge it turned on, the entries it moved)
	lanes = {
		lane1 = { enabled = true, icons = { size = 36 }, mode = max(300), gauge = { enabled = true } },
		lane2 = { enabled = true, icons = { size = 36 }, mode = max(30) },
		lane3 = { enabled = true, icons = { size = 36 }, mode = max(60) },
	},
	global = {
		setupKey = "healer",
		spells = { defaultLane = 1 }, petspells = { defaultLane = 1 }, items = { defaultLane = 1 }, buffs = { defaultLane = 3, ignoreThreshold = 300 }, debuffs = { defaultLane = 3 },
		-- the old lanes, saved when the preview started
		setupUndo = {
			profile = "Default", setupKey = "",
			lanes = {
				[1] = { enabled = true, size = 50, max = { linear = 120, linearAbs = 120, split = 120, splitAbs = 120 }, gauge = false },
				[2] = { enabled = false, size = 50, max = { linear = 120, linearAbs = 120, split = 120, splitAbs = 120 }, gauge = false },
				[3] = { enabled = true, size = 44, max = { linear = 90, linearAbs = 90, split = 90, splitAbs = 90 }, gauge = false },
			},
			defaults = types(2), thresholds = types(11),
			entries = { { t = "spells", k = 1, lane = 2 }, { t = "spells", k = 2, lane = 3 } },
		},
	},
	tables = { spells = { entry(801, "Big Spell", 1), entry(802, "Short Spell", 2) } },
} } }

LoadTOC(HARNESS_TOCFILE)
Login()
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, (tostring(detail or ""):gsub("\n", " / "))))
end
local function chatHas(text)
	for i = 1, #CHAT do
		if tostring(CHAT[i]):find(text, 1, true) then return true end
	end
	return false
end

print("[3 a setup left unkept over a reload " .. FLAVOR .. "]")
local P = CDTL3.db.profile
local g = P.global
check("login, straight after the profile loads: the unkept setup is not kept", g.setupKey == "" and CDTL3.Start.pending == nil, tostring(g.setupKey))
check("  my old lanes are back (on or off, size, Max Time)", P.lanes.lane1.enabled and P.lanes.lane1.icons.size == 50 and P.lanes.lane1.mode.linear.max == 120 and P.lanes.lane1.mode.splitAbs.max == 120
	and P.lanes.lane2.enabled == false and P.lanes.lane3.icons.size == 44 and P.lanes.lane3.mode.linearAbs.max == 90)
check("  the Mana gauge the Healer setup turned on is off again", P.lanes.lane1.gauge.enabled == false)
check("  Filters defaults and the buffs' Ignore Threshold", g.spells.defaultLane == 2 and g.buffs.defaultLane == 2 and g.buffs.ignoreThreshold == 11 and g.debuffs.defaultLane == 2)
check("  my entries are on their old lanes", P.tables.spells[1].lane == 2 and P.tables.spells[2].lane == 3)
check("  nothing is left saved, so it happens once", g.setupUndo == nil)
local e = CDTL3:ApplyEntryDefaults({ bCD = 15000 }, "spells")
check("  a new spell follows the Filters default, not the setup", e.lane == g.spells.defaultLane, tostring(e.lane))
Advance(11)
check("  a chat line says so", chatHas("A setup you were trying was not kept"))
check("no lua errors", #ERRORS == 0, tostring(#ERRORS))
print(string.format("RESULT r4stale %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS))
