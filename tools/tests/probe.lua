-- /cdtl3 probe (Probe.lua, branch cdm-probe): fakes the Forever/Retail timer APIs the stub lacks,
-- then drives it through start, casts, combat, auras, the Cooldown Manager mirror, report and off.
-- Arg "full" runs the faked path; without it, checks the probe stays inert where the APIs are missing.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)

local base = #ERRORS
CHAT = {}
-- inert path first: the stub has no GetSpellCooldownDuration
CDTL3:ChatCommand("probe")
print("inert: " .. tostring(CHAT[#CHAT]))
if HARNESS_ARG ~= "full" then
	print(string.format("RESULT probe inert %s: lua errors=%d", FLAVOR, #ERRORS - base))
	return
end

COMBAT = false
issecretvalue = function(v) return rawequal(v, SECRET) end
local function hide(v) if COMBAT then return SECRET end return v end
local function Duration(start, total)
	return {
		GetRemainingDuration = function() return hide(math.max(0, start + total - NOW)) end,
		GetStartTime = function() return hide(start) end,
		GetTotalDuration = function() return hide(total) end,
		HasSecretValues = function() return COMBAT end,
		EvaluateRemainingDuration = function() return hide(0.5) end,
		IsZero = function() return false end,
	}
end
local TEST, CHARGE, BUFF = 5001, 5002, 5003
SPELLINFO[TEST] = { "Test Bolt", 136001 }
SPELLINFO[CHARGE] = { "Test Dash", 136002 }
SPELLINFO[BUFF] = { "Test Shield", 136003 }
KNOWN[TEST], KNOWN[CHARGE] = true, true
BASECD[TEST] = 30000
C_Spell.GetSpellCooldownDuration = function(id)
	local c = SPELLCD[id]
	if c and c.isActive then return Duration(c.start, c.total) end
	return Duration(0, 0)
end
C_Spell.GetSpellChargeDuration = function(id) return Duration(NOW - 1, 10) end
C_Spell.GetSpellCharges = function(id) if id == CHARGE then return { currentCharges = hide(1), maxCharges = 2, isActive = true } end end
C_Spell.GetSpellTexture = function() return 136000 end
C_DurationUtil = { CreateDurationTextBinding = function()
	return { SetFontString = function() end, SetFormatter = function() end, SetEnabled = function() end, SetDuration = function() end }
end }
C_StringUtil = { CreateSecondsFormatter = function() return {} end }
C_CurveUtil = { CreateCurve = function() return { SetType = function() end, AddPoint = function() end } end }
Enum.LuaCurveType = { Linear = 0 }
Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
C_Secrets.HasSecretRestrictions = function() return COMBAT end
C_Secrets.ShouldCooldownsBeSecret = function() return COMBAT end
C_Secrets.ShouldSpellCooldownBeSecret = function() return COMBAT end
C_Secrets.GetSpellCooldownSecrecy = function() return 2 end
C_Secrets.GetSpellAuraSecrecy = function() return 2 end
C_Secrets.ShouldUnitAuraInstanceBeSecret = function() return COMBAT end
C_CVar = { GetCVar = function() return "1" end }
local CDM = { [0] = { 101 }, [1] = { 102 }, [2] = { 103 }, [3] = { 104 } }
local INFO = {
	[101] = { cooldownID = 101, spellID = TEST, linkedSpellIDs = {}, hasAura = false, selfAura = false, charges = false },
	[102] = { cooldownID = 102, spellID = CHARGE, linkedSpellIDs = {}, hasAura = false, selfAura = false, charges = true },
	[103] = { cooldownID = 103, spellID = BUFF, linkedSpellIDs = { BUFF }, hasAura = true, selfAura = true, charges = false },
	[104] = { cooldownID = 104, spellID = BUFF, linkedSpellIDs = { BUFF }, hasAura = true, selfAura = true, charges = false },
}
C_CooldownViewer = {
	IsCooldownViewerAvailable = function() return true, "" end,
	GetCooldownViewerCategorySet = function(cat) return CDM[cat] or {} end,
	GetCooldownViewerCooldownInfo = function(id) return INFO[id] end,
}
AURAS = { HELPFUL = { { auraInstanceID = 77, spellId = BUFF, name = "Test Shield", duration = 60, icon = 136003, expirationTime = NOW + 60 } } }
C_UnitAuras.GetAuraDuration = function(u, id) if id == 77 then return Duration(NOW - 5, 60) end error("invalid aura instance") end
C_UnitAuras.GetAuraDataByAuraInstanceID = function(u, id)
	if id == 77 then return { auraInstanceID = hide(77), spellId = BUFF, name = "Test Shield", duration = hide(60), expirationTime = hide(NOW + 55) } end
end
C_Timer.NewTicker = function(d, f)
	local h = { cancelled = false }
	h.Cancel = function() h.cancelled = true end
	local function tick() if not h.cancelled then f(h); C_Timer.After(d, tick) end end
	C_Timer.After(d, tick)
	return h
end
local realCreate = CreateFrame
CreateFrame = function(otype, ...)
	local f = realCreate(otype, ...)
	if otype == "StatusBar" then
		local tex = MOCK_NEW("Texture", nil, f)
		rawset(f, "GetStatusBarTexture", function() return tex end)
	end
	return f
end
-- a Cooldown Manager Tracked Bars viewer with one item
local item = realCreate("Frame")
item.Bar = CreateFrame("StatusBar", nil, item)
item.cooldownID = 104
item.GetCooldownID = function(self) return self.cooldownID end
BuffBarCooldownViewer = realCreate("Frame", "BuffBarCooldownViewer")
BuffBarCooldownViewer.OnAcquireItemFrame = function(self, it) end
BuffBarCooldownViewer.GetItemFrames = function() return { item } end

base = #ERRORS
CHAT = {}
CDTL3:ChatCommand("probe")
RunOnUpdate(0.1, 10)
-- cast out of combat
SPELLCD[TEST] = { startTime = NOW, duration = 30, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1, start = NOW, total = 24 }
FireEvent("SPELL_UPDATE_COOLDOWN")
Advance(2.5)
RunOnUpdate(0.1, 10)
-- Blizzard bar calls out of combat
item.Bar:SetMinMaxValues(0, 60); item.Bar:SetValue(40)
-- pull
FireEvent("PLAYER_REGEN_DISABLED")
COMBAT = true
SPELLCD[TEST] = { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
FireEvent("SPELL_UPDATE_COOLDOWN")
SPELLCD[TEST] = { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1, start = NOW, total = 24 }
FireEvent("SPELL_UPDATE_COOLDOWN")
FireEvent("UNIT_AURA", "player", { isFullUpdate = SECRET })
item.Bar:SetMinMaxValues(0, SECRET); item.Bar:SetValue(SECRET)
-- a new bar acquired in combat
local item2 = realCreate("Frame"); item2.Bar = CreateFrame("StatusBar", nil, item2); item2.cooldownID = 999
item2.GetCooldownID = function(self) return self.cooldownID end
BuffBarCooldownViewer:OnAcquireItemFrame(item2)
item2.Bar:SetValue(SECRET)
FireEvent("ADDON_ACTION_BLOCKED", "CooldownTimeline3", "Cooldown:SetCooldownFromDurationObject()")
RunOnUpdate(0.1, 30)
Advance(4)
COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
Advance(2)
local function grab()
	local r
	for _, f in ipairs(GetAllFrames()) do
		if type(f.__text) == "string" and f.__text:find("CDTL3 probe report", 1, true) then r = f.__text end
	end
	return r
end
CDTL3:ChatCommand("probe report")
local report = grab()
CDTL3:ChatCommand("probe spell 5002")
CDTL3:ChatCommand("probe")   -- hide
CDTL3:ChatCommand("probe")   -- show
RunOnUpdate(0.1, 5)
CDTL3:ChatCommand("probe report")
local report2 = grab()
CDTL3:ChatCommand("probe off")
CDTL3:ChatCommand("probe report")
CDTL3:ChatCommand("probe bogus")
CDTL3:ChatCommand("probe")   -- restart after off
CDTL3:ChatCommand("probe off")
print("---- REPORT 2 (after spell change), sections 1-2 and 6:")
local s2 = report2 or ""
print(s2:sub(s2:find("== 1.", 1, true) or 1, (s2:find("== 3.", 1, true) or 1) - 1))
print(s2:sub(s2:find("== 6.", 1, true) or 1, (s2:find("== 7.", 1, true) or 1) - 1))
print("---- REPORT 1:")
print(report or "NO REPORT")
for _, m in ipairs(CHAT) do print("CHAT: " .. m) end
for i = base + 1, #ERRORS do print("ERR: " .. tostring(ERRORS[i])) end
print(string.format("RESULT probe full %s: lua errors=%d report=%s", FLAVOR, #ERRORS - base, report and "yes" or "no"))
