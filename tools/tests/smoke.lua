-- Smoke load: every file of one TOC in order (real Ace3 + libs, LibEditMode stubbed), then
-- ADDON_LOADED -> OnInitialize, PLAYER_LOGIN -> OnEnable, PLAYER_ENTERING_WORLD -> TurnOn,
-- the 5 s / 10 s timers (GetCharacterData, ScanCurrentCooldowns, first-run frame), some
-- frames of OnUpdate, a player + pet cast, options-table validation, and opening the
-- options window on each tab.
dofile(HARNESS_DIR .. "/wow.lua")
local class = HARNESS_ARG ~= "" and HARNESS_ARG or "MAGE"
PLAYER.class = class
PLAYER.race = (class == "DEATHKNIGHT" or class == "DEMONHUNTER") and "NightElf" or (class == "EVOKER" and "Dracthyr" or "Human")

-- a small spellbook, with one spell on cooldown, so the login scan has work to do
SPELLINFO[133] = { "Fireball", 135812 }
SPELLINFO[12043] = { "Presence of Mind", 136031 }
SPELLINFO[2139] = { "Counterspell", 135856 }
SPELLBOOK = { { id = 133, name = "Fireball" }, { id = 2139, name = "Counterspell" }, { id = 12043, name = "Presence of Mind" } }
KNOWN[133], KNOWN[2139], KNOWN[12043] = true, true, true
BASECD[2139] = 24000
SPELLCD[2139] = { startTime = NOW - 2, duration = 24, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }

local files = LoadTOC(HARNESS_TOCFILE)
local n = #ERRORS
print(string.format("[%s %s %s] loaded %d toc entries (%d lua files), load errors: %d", HARNESS_TOCFILE, FLAVOR, class, #files, #LOADED_FILES, n))
TrackMisses()

Login()
print(string.format("  after login: errors %d, enabled=%s, combatLogRegistered=%s, CLEU registered=%s",
	#ERRORS, tostring(CDTL3.enabled), tostring(CDTL3.combatLogRegistered), tostring(IsEventRegisteredAnywhere("COMBAT_LOG_EVENT_UNFILTERED"))))

Advance(5.1)
print(string.format("  after 5s timer: errors %d, class=%s spellData=%d saved spells=%d live cds=%d",
	#ERRORS, tostring(CDTL3.player.class), #CDTL3.spellData, #CDTL3.db.profile.tables.spells, #CDTL3.cooldowns))
Advance(5)
print(string.format("  after 10s timer: errors %d", #ERRORS))

-- casts: a player spell and (hunter/warlock) a pet spell
SPELLCD[133] = nil
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2139)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 12043)
SPELLINFO[17253] = { "Bite", 132278 }
KNOWN[17253] = true
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "pet", "Cast-3", 17253)
RunOnUpdate(0.02, 120)
print(string.format("  after casts + 120 frames: errors %d, live cds=%d", #ERRORS, #CDTL3.cooldowns))

-- options: validate the full tree, then open the window and visit each tab
local reg = LibStub("AceConfigRegistry-3.0")
local ok, err = pcall(function() return reg:GetOptionsTable("CDTL3", "dialog", "MyLib-1.0") end)
print("  options validate: " .. (ok and "ok" or ("FAIL " .. tostring(err))))
local ACD = LibStub("AceConfigDialog-3.0")
local before = #ERRORS
xpcall(function() ACD:Open("CDTL3") end, ERRH)
for _, tab in ipairs({ "lanes", "ready", "barFrames", "filters", "profiles" }) do
	xpcall(function() ACD:SelectGroup("CDTL3", tab) end, ERRH)
end
print(string.format("  options window + tabs: new errors %d", #ERRORS - before))

-- minimap right-click: toggles the lock (ToggleFrameLock), twice back to where it was
local locked0 = CDTL3.db.profile.global["unlockFrames"]
local click = CDTL3.minimapBtn and CDTL3.minimapBtn.__scripts.OnClick
if click then
	xpcall(click, ERRH, CDTL3.minimapBtn, "RightButton")
	local after1 = CDTL3.db.profile.global["unlockFrames"]
	xpcall(click, ERRH, CDTL3.minimapBtn, "RightButton")
	print(string.format("  minimap right-click: unlockFrames %s -> %s -> %s", tostring(locked0), tostring(after1), tostring(CDTL3.db.profile.global["unlockFrames"])))
end

local addonMisses = {}
for k, c in pairs(MISSES) do addonMisses[#addonMisses + 1] = k end
table.sort(addonMisses)
print("  nil-global reads from addon files: " .. table.concat(addonMisses, ", "))
print(string.format("RESULT %s %s: total lua errors %d", HARNESS_TOCFILE, class, #ERRORS))
