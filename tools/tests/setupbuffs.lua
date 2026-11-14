-- A buff gained while a setup is previewed (Start.lua, Quick Style > Setup) goes back to the lane its Filters entry
-- says when the preview is undone (owner's walk, 13 Nov, Forever druid: Mark of the Wild and Thorns stopped showing on
-- the lane Filters named, and came back only once a setup and a Filters lane change moved them). Its live cooldown was
-- made on the preview's lane; Undo put the entry's lane back but left the icon on the preview's lane (hidden there,
-- past that lane's Max Time), and every recast restarted it on that lane until a /reload.
--   node run.js <addon> <toc number> setupbuffs.lua <toc file>
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "DRUID"
local ME = PLAYER.guid
local MOTW, THORNS, CAMP = 5232, 467, 1229741

local function entry(id, name, secs, lane)
	return { id = id, name = name, type = "buffs", icon = 136078, bCD = secs * 1000, lane = lane, barFrame = 2, readyFrame = 2,
		enabled = true, ignored = false, highlight = false, pinned = false, usedBy = { ME } }
end

-- a 3.1.1 profile: the buffs' lane set to the Long buffs scale, three long buffs un-ignored by hand on it
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {
	global = { previousVersion = "3.1.1", firstRun = false },
	lanes = { lane2 = { mode = { type = "SPLIT_ABS", splitAbs = { max = 3600, hideTimeSurplus = false, s1v = 30, s2v = 120, s3v = 600 } } } },
	tables = { buffs = { entry(MOTW, "Mark of the Wild", 3600, 2), entry(THORNS, "Thorns", 600, 2), entry(CAMP, "Camp Benefits", 7200, 2) } },
} } }
SPELLINFO[MOTW] = { "Mark of the Wild", 136078 }
SPELLINFO[THORNS] = { "Thorns", 136104 }
SPELLINFO[CAMP] = { "Camp Benefits", 136000 }

local inst = 100
local function aura(id, name, secs, left)
	inst = inst + 1
	return { name = name, spellId = id, duration = secs, expirationTime = NOW + left, applications = 0, icon = 136078,
		sourceUnit = "player", auraInstanceID = inst, isHarmful = false }
end
AURAS = { HELPFUL = {}, HARMFUL = {} }

LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
RunOnUpdate(0.02, 10)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, tostring(detail or "")))
end

local S = CDTL3.Start
local P = CDTL3.db.profile

-- the buff lands on the player: what UNIT_AURA (Retail, Forever) and the combat log (Classic) both hand on
local function gain(id, name, secs)
	for i = #AURAS.HELPFUL, 1, -1 do
		if AURAS.HELPFUL[i].name == name then table.remove(AURAS.HELPFUL, i) end
	end
	table.insert(AURAS.HELPFUL, aura(id, name, secs, secs))
	CDTL3:OnPlayerAuraApplied(id, name, "buffs", true)
	RunOnUpdate(0.02, 30)	-- past the 0.5 s same-aura dedupe, and the icons update
end

-- where its Filters entry says, where the live icon is, and whether it shows
local function where(name)
	local e = CDTL3:GetSpellSettings(name, "buffs")
	local f = CDTL3:GetExistingCooldown(name, "buffs")
	local parent = f and f.icon:GetParent()
	return e and e.lane, f and f.data.lane, parent and parent:GetName(), f and f.icon.valid
end
local function shows(name, lane)
	local saved, live, parent, valid = where(name)
	return saved == lane and live == lane and parent == "CDTL3_Lane_" .. lane and valid == true,
		string.format("Filters lane %s, live lane %s, on %s, shown %s", tostring(saved), tostring(live), tostring(parent), tostring(valid))
end

print("[a buff gained during a setup preview " .. FLAVOR .. "]")
-- Classic finds a buff that was up at login only through the combat log, so it lands here on every client
gain(CAMP, "Camp Benefits", 7200)
check("before the preview: Camp Benefits shows on lane 2, its Filters lane", shows("Camp Benefits", 2))

S.PreviewSetup("healer")
RunOnUpdate(0.02, 10)
check("Healer preview: the buffs' entries and the live one move to lane 3", select(1, where("Mark of the Wild")) == 3 and select(2, where("Camp Benefits")) == 3)
gain(MOTW, "Mark of the Wild", 3600)
check("  Mark of the Wild cast during the preview starts on the preview's lane 3", select(2, where("Mark of the Wild")) == 3)

S.UndoSetup()
RunOnUpdate(0.02, 30)
check("Undo: Mark of the Wild shows on lane 2 again, where Filters says", shows("Mark of the Wild", 2))
check("  Camp Benefits (up before the preview) is back on lane 2 too", shows("Camp Benefits", 2))
gain(MOTW, "Mark of the Wild", 3600)
check("  a recast restarts it on lane 2", shows("Mark of the Wild", 2))

print("[previews switched, then undone " .. FLAVOR .. "]")
S.PreviewSetup("tank")
gain(THORNS, "Thorns", 600)
check("Tank preview: Thorns cast during it starts on lane 3", select(2, where("Thorns")) == 3)
S.PreviewSetup("starter")
RunOnUpdate(0.02, 10)
check("  switched to Starter: everything on its one lane", select(2, where("Thorns")) == 1 and select(2, where("Mark of the Wild")) == 1)
S.UndoSetup()
RunOnUpdate(0.02, 30)
check("Undo: Thorns shows on lane 2", shows("Thorns", 2))
check("  Mark of the Wild shows on lane 2", shows("Mark of the Wild", 2))
check("  nothing left saved for the next login", P.global.setupUndo == nil and S.pending == nil)

print("[kept " .. FLAVOR .. "]")
S.PreviewSetup("dps")
gain(THORNS, "Thorns", 600)
S.KeepSetup()
RunOnUpdate(0.02, 30)
local saved, live = where("Thorns")
check("Keep: Thorns's Filters lane and its live lane agree (the DPS setup's lane 3)", saved == 3 and live == 3,
	tostring(saved) .. " / " .. tostring(live))
check("  Mark of the Wild too", select(1, where("Mark of the Wild")) == 3 and select(2, where("Mark of the Wild")) == 3)

check("no Lua errors", #ERRORS == base, #ERRORS - base)
print(string.format("RESULT setupbuffs %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
