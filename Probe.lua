--[[
	Cooldown Timeline 3 - Cooldown Manager probe (/cdtl3 probe)

	Read-only diagnostic for docs/cooldown-manager-scope.md ("Probe build"), grown from the
	October /cdtl3 secrettest spike. It finds out in game which ways of showing hidden (secret)
	timers work from addon code. It changes no saved settings, none of CDTL3's own timers and
	none of Blizzard's frames: it reads values, draws its own test bars, and post-hooks the
	Cooldown Manager's Tracked Bars only to copy what they are given. Nothing is created or
	hooked until the player runs the command.

	/cdtl3 probe                  open the panel and start recording (again: show or hide it)
	/cdtl3 probe spell <id|name>  choose the test spell
	/cdtl3 probe report           window with the whole report, selected for copying
	/cdtl3 probe off              stop recording and hide the panel

	Panel rows (bar icons ride their bar's fill edge):
	  A   SetMinMaxValues(0, max) + SetValue(dur:GetRemainingDuration())
	  B   SetTimerDuration(dur, Immediate, RemainingTime)
	  C   SetValue(dur:EvaluateRemainingDuration(curve)), split lane
	  D   duration text binding + cooldown swipe (the swipe is report section 7)
	  S1  timer object kept from the cast, S2 one fetched 2 s later
	  E   buff timer from a cached aura instance ID
	  F   copy of a Tracked Bar (Cooldown Manager mirror)

	Every API call runs in pcall and the first error of each step is kept. Values that may be
	secret are only handed to widgets or labelled with issecretvalue, never compared,
	formatted or used in arithmetic outside a pcall.
]]--

local private = {}

private.MAX_CACHE = 8		-- cached buffs
private.MAX_LOG = 40		-- log lines
private.MAX_ACTIONS = 20	-- blocked / forbidden action lines
private.MAX_LABELS = 6		-- distinct values tallied per item and phase
private.MAX_MIRROR_IDS = 30	-- cooldown IDs counted by the mirror
private.MAX_LIST = 30		-- Cooldown Manager entries listed per category
private.SAMPLE_SECONDS = 2
private.MIN_TEST_CD = 8		-- seconds

private.CATEGORIES = { [0] = "Essential", "Utility", "TrackedBuff", "TrackedBar", "GroupBuff",
	"SpecAgnosticEssential", "SpecAgnosticTracked", "EquipSlotEssential", "EquipSlotTracked" }
private.VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }
private.AURA_FIELDS = { "auraInstanceID", "spellId", "name", "icon", "duration", "expirationTime",
	"applications", "sourceUnit", "isFromPlayerOrPlayerPet" }
private.SECRET_FLAGS = { "HasSecretRestrictions", "ShouldCooldownsBeSecret", "ShouldAurasBeSecret" }
private.EVENTS = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }
private.RIDERS = { "A", "B", "C" }
private.ROWS = {
	{ key = "A", label = "A  SetValue" },
	{ key = "B", label = "B  SetTimerDuration" },
	{ key = "C", label = "C  curve (split lane)" },
	{ key = "D", label = "D  text + swipe" },
	{ key = "S1", label = "S1 object from the cast" },
	{ key = "S2", label = "S2 object 2 s later" },
	{ key = "E", label = "E  buff by cached ID" },
	{ key = "F", label = "F  Tracked Bar copy" },
}

-- hooks on Blizzard's bars can't be removed, so these outlive /cdtl3 probe off
private.hookedBars = {}
private.hookedBarCount = 0
private.acquireHooked = false

-- HELPERS
local function IsSecret(v)
	if not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, v)
	return ok and secret == true
end

-- printable number or string; never formats a secret
local function Show(v)
	if IsSecret(v) then
		return "SECRET"
	elseif v == nil then
		return "nil"
	end
	local ok, s = pcall(function()
		local t = type(v)
		if t == "number" then
			return string.format("%.1f", v)
		elseif t == "boolean" or t == "string" then
			return tostring(v)
		end
		return t
	end)
	return ok and s or "unreadable"
end

-- like Show, without the decimals (IDs, flags, names)
local function Plain(v)
	if IsSecret(v) then
		return "SECRET"
	end
	local ok, s = pcall(tostring, v)
	return ok and s or "unreadable"
end

-- short label for tallies: error / SECRET / nil / true / false / readable / object
local function Kind(ok, v)
	if not ok then
		return "error"
	elseif IsSecret(v) then
		return "SECRET"
	elseif v == nil then
		return "nil"
	end
	local t = type(v)
	if t == "boolean" then
		return tostring(v)
	elseif t == "number" or t == "string" then
		return "readable"
	end
	return "object"
end

-- for pcall: a bad object or a missing method errors inside the pcall, not outside
local function Method(obj, method, ...)
	return obj[method](obj, ...)
end

local function Field(t, key)
	return t[key]
end

local function Phase()
	return private.inCombat and "combat" or "ooc"
end

local function Slot(store, name)
	local s = store[name]
	if not s then
		s = { ooc = {}, combat = {} }
		store[name] = s
	end
	return s[Phase()]
end

-- pcall that counts successes and failures per phase and keeps the first error
local function Try(step, fn, ...)
	local ok, a, b, c, d, e = pcall(fn, ...)
	local s = Slot(private.steps, step)
	if ok then
		s.ok = (s.ok or 0) + 1
	else
		s.fail = (s.fail or 0) + 1
		s.err = s.err or tostring(a)
	end
	return ok, a, b, c, d, e
end

local function Tally(name, label)
	local t = Slot(private.tallies, name)
	if not t[label] then
		local n = 0
		for _ in pairs(t) do
			n = n + 1
		end
		if n >= private.MAX_LABELS then
			label = "other"
		end
	end
	t[label] = (t[label] or 0) + 1
end

local function Count(name)
	local t = Slot(private.counts, name)
	t.n = (t.n or 0) + 1
end

local function Note(name, text)
	Slot(private.notes, name).text = text
end

local function Since()
	local ok, t = pcall(function()
		return string.format("%.1f", GetTime() - private.startTime)
	end)
	return ok and t or "?"
end

local function Log(text)
	if #private.log < private.MAX_LOG then
		private.log[#private.log + 1] = "[" .. Phase() .. " +" .. Since() .. "s] " .. text
	end
end

local function Supported()
	return C_Spell and C_Spell.GetSpellCooldownDuration and C_DurationUtil and true or false
end

private.SpellName = function(id)
	local ok, name = pcall(function()
		if C_Spell.GetSpellName then
			return C_Spell.GetSpellName(id)
		end
		local info = C_Spell.GetSpellInfo(id)
		return info and info.name
	end)
	if ok and not IsSecret(name) and name ~= nil then
		return tostring(name)
	end
	return "spell " .. Plain(id)
end

-- base cooldown in seconds (static spell data) or nil
private.BaseSeconds = function(id)
	local ok, s = pcall(function()
		local ms = GetSpellBaseCooldown(id)
		if IsSecret(ms) or type(ms) ~= "number" then
			return nil
		end
		return ms / 1000
	end)
	return ok and s or nil
end

private.IsKnown = function(id)
	local ok, known = pcall(CDTL3.Compat.IsSpellKnownOrOverridesKnown, id)
	return ok and not IsSecret(known) and known and true or false
end

private.GoodTestSpell = function(id)
	local base = private.BaseSeconds(id)
	return private.IsKnown(id) and base ~= nil and base >= private.MIN_TEST_CD
end

private.IsMine = function(s, guid)
	if type(s) ~= "table" or type(s["usedBy"]) ~= "table" then
		return false
	end
	for _, g in pairs(s["usedBy"]) do
		if g == guid then
			return true
		end
	end
	return false
end

private.SecrecyLabel = function(ok, v)
	local k = Kind(ok, v)
	if k ~= "readable" then
		return k
	end
	if Enum and Enum.SecrecyLevel then
		for name, value in pairs(Enum.SecrecyLevel) do
			if value == v then
				return name
			end
		end
	end
	return tostring(v)
end

private.CombatSeconds = function()
	local t = private.combatSeconds or 0
	if private.inCombat and private.combatStart then
		t = t + (GetTime() - private.combatStart)
	end
	return t
end

private.Total = function(store, name, key)
	local t = store[name]
	if not t then
		return 0
	end
	return (t.ooc[key] or 0) + (t.combat[key] or 0)
end

-- COOLDOWN MANAGER (static data)
private.CategorySet = function(cat, allowUnlearned)
	if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet) then
		return nil, "C_CooldownViewer.GetCooldownViewerCategorySet missing"
	end
	local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, cat, allowUnlearned and true or false)
	if ok and type(ids) == "table" then
		return ids
	end
	return nil, ok and "no list returned" or tostring(ids)
end

private.CooldownInfo = function(cooldownID)
	if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then
		return nil
	end
	local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
	if ok and type(info) == "table" then
		return info
	end
end

private.CooldownName = function(cooldownID)
	local info = private.CooldownInfo(cooldownID)
	local id = info and info.spellID
	if not IsSecret(id) and type(id) == "number" then
		return private.SpellName(id) .. " (spell " .. id .. ")", id
	end
	return "cooldownID " .. Plain(cooldownID)
end

-- TEST SPELL
-- first known spell with a base cooldown of 8 s or more: CDTL3's saved spells for this
-- character, else the Cooldown Manager's Essential list
private.DefaultSpell = function()
	local guid = CDTL3.player and CDTL3.player["guid"]
	local ok, spells = pcall(function()
		return CDTL3.db.profile.tables["spells"]
	end)
	if guid and ok and type(spells) == "table" then
		for _, s in ipairs(spells) do
			local id = s["id"]
			if type(id) == "number" and private.IsMine(s, guid) and private.GoodTestSpell(id) then
				return id, "first of CDTL3's saved spells for this character"
			end
		end
	end
	for _, cooldownID in ipairs(private.CategorySet(0) or {}) do
		local info = private.CooldownInfo(cooldownID)
		local id = info and info.spellID
		if type(id) == "number" and private.GoodTestSpell(id) then
			return id, "first of the Cooldown Manager's Essential list"
		end
	end
end

private.SetSpell = function(spell, source)
	local ok, info = pcall(C_Spell.GetSpellInfo, spell)
	if not (ok and type(info) == "table" and type(info.spellID) == "number") then
		return false
	end
	private.spell = {
		id = info.spellID,
		name = Plain(info.name),
		icon = info.iconID,
		source = source,
		base = private.BaseSeconds(info.spellID),
	}
	return true
end

-- isActive and isOnGCD are never secret per the docs; nil when they can't be read
private.ReadActive = function()
	local id = private.spell and private.spell.id
	if not id then
		return nil
	end
	local ok, active = pcall(function()
		local i = C_Spell.GetSpellCooldown(id)
		return (i and i.isActive and not i.isOnGCD) and true or false
	end)
	Tally("2 isActive readable", ok and "yes" or "no")
	if ok then
		return active
	end
end

-- the spell's own numbers, as text; secrets come out as SECRET
private.ReadSpellNumbers = function(when)
	local sp = private.spell
	local ok, text = pcall(function()
		local start, total, totalValue = "none", "none", nil
		local dur = C_Spell.GetSpellCooldownDuration(sp.id, true)
		if Kind(true, dur) == "object" then
			local okS, s = pcall(Method, dur, "GetStartTime")
			local okT, t = pcall(Method, dur, "GetTotalDuration")
			start = okS and Show(s) or "error"
			total = okT and Show(t) or "error"
			totalValue = okT and t or nil
		end
		local info = C_Spell.GetSpellCooldown(sp.id)
		local cdStart = info and Show(info.startTime) or "none"
		local cdDuration = info and Show(info.duration) or "none"
		return "timer object start " .. start .. ", total " .. total
			.. " | GetSpellCooldown start " .. cdStart .. ", duration " .. cdDuration
			.. " | base " .. (sp.base and string.format("%.1f", sp.base) or "?") .. " s | "
			.. private.CompareToBase(totalValue, sp.base)
	end)
	Note("2 readings " .. when, ok and text or ("error: " .. tostring(text)))
end

private.CompareToBase = function(total, base)
	local ok, text = pcall(function()
		if IsSecret(total) or type(total) ~= "number" or not base then
			return "total vs base: can't compare (hidden or missing)"
		end
		if math.abs(total - base) < 0.05 then
			return "object total = base"
		end
		return total < base and "object total SHORTER than base (talents or haste)" or "object total LONGER than base"
	end)
	return ok and text or "total vs base: can't compare"
end

-- CHARGES
private.PickChargeSpell = function()
	private.charge = nil
	local candidates, seen = {}, {}
	local function add(id)
		if type(id) == "number" and not seen[id] then
			seen[id] = true
			candidates[#candidates + 1] = id
		end
	end

	if private.spell then
		add(private.spell.id)
	end
	local guid = CDTL3.player and CDTL3.player["guid"]
	local ok, spells = pcall(function()
		return CDTL3.db.profile.tables["spells"]
	end)
	if guid and ok and type(spells) == "table" then
		for _, s in ipairs(spells) do
			if private.IsMine(s, guid) then
				add(s["id"])
			end
		end
	end
	for cat = 0, 1 do
		for _, cooldownID in ipairs(private.CategorySet(cat) or {}) do
			local info = private.CooldownInfo(cooldownID)
			if info and not IsSecret(info.charges) and info.charges == true then
				add(info.spellID)
			end
		end
	end

	for _, id in ipairs(candidates) do
		local okC, maxCharges = pcall(function()
			local c = C_Spell.GetSpellCharges(id)
			local m = c and c.maxCharges
			if IsSecret(m) or type(m) ~= "number" then
				return nil
			end
			return m > 1 and m or nil
		end)
		if okC and maxCharges and private.IsKnown(id) then
			private.charge = { id = id, name = private.SpellName(id), max = maxCharges }
			return
		end
	end
end

-- BUFF CACHE
private.ReadAura = function(i)
	local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
	if not a then
		return false
	end
	local id, spellId, name, duration, icon = a.auraInstanceID, a.spellId, a.name, a.duration, a.icon
	if IsSecret(id) or IsSecret(spellId) or IsSecret(name) or IsSecret(duration) then
		return "secret"
	end
	if IsSecret(icon) then
		icon = nil
	end
	return {
		id = id,
		spellId = spellId,
		name = name,
		duration = duration,
		icon = icon,
		timed = type(duration) == "number" and duration > 0,
	}
end

private.CacheAuras = function()
	private.cachePending = nil
	private.cache = {}
	private.cacheSkipped = 0
	private.auraTarget = nil
	private.cacheAt = Since()
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
		Log("C_UnitAuras.GetAuraDataByIndex missing: no buffs cached")
		return
	end

	for i = 1, 40 do
		if #private.cache >= private.MAX_CACHE then
			break
		end
		local ok, a = Try("4 cache: GetAuraDataByIndex", private.ReadAura, i)
		if not ok or not a then
			break
		end
		if a == "secret" then
			private.cacheSkipped = private.cacheSkipped + 1
		else
			private.cache[#private.cache + 1] = a
		end
	end

	-- row E follows the first buff that runs out; a permanent aura would show nothing
	for _, c in ipairs(private.cache) do
		if c.timed then
			private.auraTarget = c
			break
		end
	end
	private.auraTarget = private.auraTarget or private.cache[1]
	if private.panel then
		private.panel.rows.E.icon:SetTexture(private.auraTarget and private.auraTarget.icon or 134400)
	end
	Log("buffs cached: " .. #private.cache)
end

private.DataLabel = function(data)
	if IsSecret(data) then
		return "SECRET table"
	elseif data == nil then
		return "nil (no aura)"
	elseif type(data) ~= "table" then
		return type(data)
	end
	local secret = {}
	for _, f in ipairs(private.AURA_FIELDS) do
		local ok, v = pcall(Field, data, f)
		if not ok or IsSecret(v) then
			secret[#secret + 1] = f
		end
	end
	if #secret == 0 then
		return "data, nothing secret"
	end
	return "data, secret: " .. table.concat(secret, " ")
end

private.SampleAuras = function()
	if not C_UnitAuras then
		return
	end
	for i, c in ipairs(private.cache) do
		local k = "4#" .. i
		if C_UnitAuras.GetAuraDuration then
			local ok, dur = Try(k .. " GetAuraDuration", C_UnitAuras.GetAuraDuration, "player", c.id)
			if ok then
				local kind = Kind(true, dur)
				Tally(k .. " timer object", kind)
				if kind == "object" then
					Tally(k .. " HasSecretValues", Kind(pcall(Method, dur, "HasSecretValues")))
				end
			end
		else
			Tally(k .. " timer object", "API missing")
		end

		local okD, data = Try(k .. " GetAuraDataByAuraInstanceID", C_UnitAuras.GetAuraDataByAuraInstanceID, "player", c.id)
		if okD then
			Tally(k .. " aura data", private.DataLabel(data))
		end

		if C_Secrets and C_Secrets.GetSpellAuraSecrecy then
			Tally(k .. " GetSpellAuraSecrecy", private.SecrecyLabel(Try(k .. " GetSpellAuraSecrecy", C_Secrets.GetSpellAuraSecrecy, c.spellId)))
		end
		if C_Secrets and C_Secrets.ShouldUnitAuraInstanceBeSecret then
			Tally(k .. " ShouldUnitAuraInstanceBeSecret", Kind(Try(k .. " ShouldUnitAuraInstanceBeSecret", C_Secrets.ShouldUnitAuraInstanceBeSecret, "player", c.id)))
		end
	end
end

-- row E: the first cached buff's timer, re-fetched on UNIT_AURA so a recast shows as a reset
private.RebindAura = function()
	local c, p = private.auraTarget, private.panel
	if not (c and p and C_UnitAuras and C_UnitAuras.GetAuraDuration) then
		return
	end
	local ok, dur = Try("4E GetAuraDuration", C_UnitAuras.GetAuraDuration, "player", c.id)
	if ok and Kind(true, dur) == "object" then
		Try("4E SetTimerDuration", private.SetTimer, p.rows.E.bar, dur)
	end
end

-- MIRROR: copy what Blizzard's Tracked Bars are given into row F
-- (Blizzard_CooldownViewer: each BuffBarCooldownViewer item keeps its StatusBar in .Bar and
-- feeds it SetMinMaxValues(0, duration) + SetValue(remaining) every frame while active)
private.InstallMirror = function()
	local viewer = _G["BuffBarCooldownViewer"]
	if not viewer then
		Log("BuffBarCooldownViewer not found: no mirror")
		return
	end

	if not private.acquireHooked then
		local ok, fnType = pcall(function()
			return type(viewer.OnAcquireItemFrame)
		end)
		if ok and fnType == "function" then
			if Try("6 hook OnAcquireItemFrame", hooksecurefunc, viewer, "OnAcquireItemFrame", private.OnAcquire) then
				private.acquireHooked = true
			end
		end
	end

	local ok, items = Try("6 GetItemFrames", Method, viewer, "GetItemFrames")
	if ok and type(items) == "table" then
		for _, item in ipairs(items) do
			private.HookBarItem(item)
			if not private.mirror.target then
				local okID, id = pcall(Method, item, "GetCooldownID")
				if okID and not IsSecret(id) and type(id) == "number" then
					private.mirror.target = id
				end
			end
		end
	end
end

private.OnAcquire = function(_, item)
	if private.recording then
		pcall(private.HookBarItem, item)
	end
end

-- each bar instance is hooked once, ever
private.HookBarItem = function(item)
	local ok, bar = pcall(Field, item, "Bar")
	if not ok or type(bar) ~= "table" or private.hookedBars[bar] then
		return
	end
	private.hookedBars[bar] = item
	private.hookedBarCount = private.hookedBarCount + 1
	Try("6 hook bar SetMinMaxValues", hooksecurefunc, bar, "SetMinMaxValues", private.OnBarMinMax)
	Try("6 hook bar SetValue", hooksecurefunc, bar, "SetValue", private.OnBarValue)
end

private.OnBarMinMax = function(bar, minValue, maxValue)
	if private.recording then
		pcall(private.Mirror, bar, "SetMinMaxValues", minValue, maxValue)
	end
end

private.OnBarValue = function(bar, value)
	if private.recording then
		pcall(private.Mirror, bar, "SetValue", value)
	end
end

private.Mirror = function(bar, method, a, b)
	local item = private.hookedBars[bar]
	local id = item and item:GetCooldownID()
	if IsSecret(id) then
		id = nil
	end
	local m = private.mirror
	local key = id or "none"
	local rec = m.calls[key]
	if not rec then
		if m.ids >= private.MAX_MIRROR_IDS then
			return
		end
		m.ids = m.ids + 1
		rec = { SetMinMaxValues = { ooc = 0, combat = 0 }, SetValue = { ooc = 0, combat = 0 } }
		m.calls[key] = rec
	end
	local phase = Phase()
	rec[method][phase] = rec[method][phase] + 1

	if not m.target and id then
		m.target = id
	end
	local p = private.panel
	if id and id == m.target and p and p:IsShown() then
		if method == "SetMinMaxValues" then
			Try("6F SetMinMaxValues (copy)", Method, p.rows.F.bar, "SetMinMaxValues", a, b)
		else
			Try("6F SetValue (copy)", Method, p.rows.F.bar, "SetValue", a)
		end
	end
end

private.OnActionEvent = function(event, addon, func)
	Count("6 " .. event)
	local named = false
	pcall(function()
		named = string.find(func, "SetCooldownFromDurationObject", 1, true) ~= nil
	end)
	if named then
		private.swipeNamed = private.swipeNamed + 1
		-- a forbidden call pops up Blizzard's warning; don't repeat it
		if event == "ADDON_ACTION_FORBIDDEN" then
			private.swipeStopped = true
		end
	end
	if #private.actionLog < private.MAX_ACTIONS then
		private.actionLog[#private.actionLog + 1] = "[" .. Phase() .. " +" .. Since() .. "s] " .. event .. ": " .. Plain(addon) .. " - " .. Plain(func)
	end
end

-- DRIVING THE ROWS
private.SetTimer = function(bar, dur)
	local interp = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
	local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
	bar:SetTimerDuration(dur, interp, direction)
end

private.SetRemaining = function(bar, dur)
	bar:SetValue(dur:GetRemainingDuration())
end

private.SetCurve = function(bar, dur, curve)
	bar:SetValue(dur:EvaluateRemainingDuration(curve))
end

-- split lane: the last sixth of the cooldown fills a third of the bar, the last half two thirds
private.BuildCurve = function()
	local curve = C_CurveUtil.CreateCurve()
	curve:SetType(Enum.LuaCurveType.Linear)
	local m = private.max
	curve:AddPoint(0, 0)
	curve:AddPoint(m / 6, 0.33)
	curve:AddPoint(m / 2, 0.66)
	curve:AddPoint(m, 1)
	private.curve = curve
end

private.SetupBinding = function()
	local b = C_DurationUtil.CreateDurationTextBinding()
	b:SetFontString(private.panel.dText)
	if C_StringUtil and C_StringUtil.CreateSecondsFormatter then
		b:SetFormatter(C_StringUtil.CreateSecondsFormatter())
	end
	b:SetEnabled(true)
	private.binding = b
end

private.SetupSpell = function()
	local p, sp = private.panel, private.spell
	private.castDur, private.laterDur, private.wasActive, private.castToken = nil, nil, nil, nil
	if not (p and sp) then
		return
	end
	private.max = (sp.base and sp.base > 0) and sp.base or 60
	for _, key in ipairs({ "A", "B", "C", "S1", "S2" }) do
		p.rows[key].icon:SetTexture(sp.icon)
	end
	p.dIcon:SetTexture(sp.icon)
	Try("1A SetMinMaxValues", Method, p.rows.A.bar, "SetMinMaxValues", 0, private.max)
	for _, key in ipairs({ "S1", "S2" }) do
		p.rows[key].bar:SetMinMaxValues(0, private.max)
		p.rows[key].bar:SetValue(0)
	end
	private.curve = nil
	if C_CurveUtil and C_CurveUtil.CreateCurve then
		Try("1C curve setup", private.BuildCurve)
	end
	private.wasActive = private.ReadActive()
end

-- fresh timer object into the event-driven consumers: row B, row D's text and swipe
private.Rebind = function(source)
	local p = private.panel
	local id = private.spell and private.spell.id
	if not (p and id) then
		return
	end
	local ok, dur = Try("2 GetSpellCooldownDuration (rows B, D)", C_Spell.GetSpellCooldownDuration, id, true)
	if source == "event" and ok then
		Tally("2 refetch on SPELL_UPDATE_COOLDOWN", Kind(true, dur))
	end
	if not (ok and Kind(true, dur) == "object") then
		return
	end
	Try("1B SetTimerDuration", private.SetTimer, p.rows.B.bar, dur)
	if private.binding then
		Try("1D binding SetDuration", Method, private.binding, "SetDuration", dur)
	end
	if not private.swipeStopped then
		Try("7 SetCooldownFromDurationObject", Method, p.dCooldown, "SetCooldownFromDurationObject", dur)
	end
end

private.CheckCast = function()
	local active = private.ReadActive()
	if active == nil then
		return
	end
	if active and private.wasActive == false then
		private.OnCast()
	end
	private.wasActive = active
end

-- S1 keeps the object fetched at the cast, S2 one fetched 2 s later
private.OnCast = function()
	Count("2 casts seen")
	Log("test spell cast seen")
	local ok, dur = Try("2 fetch at cast", C_Spell.GetSpellCooldownDuration, private.spell.id, true)
	private.castDur = (ok and Kind(true, dur) == "object") and dur or nil
	private.laterDur = nil
	private.ReadSpellNumbers("at cast")

	local token = {}
	private.castToken = token
	C_Timer.After(2, function()
		if private.recording and private.castToken == token then
			Try("2 after-cast check", private.AfterCast)
		end
	end)
end

private.AfterCast = function()
	local ok, dur = Try("2 fetch 2 s after cast", C_Spell.GetSpellCooldownDuration, private.spell.id, true)
	if ok and Kind(true, dur) == "object" then
		private.laterDur = dur
		if private.castDur then
			Tally("2 cast vs 2 s later object", rawequal(private.castDur, dur) and "same object" or "different objects")
		end
	end
	private.ReadSpellNumbers("2 s after cast")
end

-- every frame while the panel is shown
private.OnUpdate = function(p, elapsed)
	local id = private.spell and private.spell.id
	if id then
		local ok, dur = Try("1 GetSpellCooldownDuration (every frame)", C_Spell.GetSpellCooldownDuration, id, true)
		if ok and Kind(true, dur) == "object" then
			Try("1A SetValue(GetRemainingDuration)", private.SetRemaining, p.rows.A.bar, dur)
			if private.curve then
				Try("1C SetValue(EvaluateRemainingDuration)", private.SetCurve, p.rows.C.bar, dur, private.curve)
			end
		end
	end
	if private.castDur then
		Try("2 S1 SetValue(cast object)", private.SetRemaining, p.rows.S1.bar, private.castDur)
	end
	if private.laterDur then
		Try("2 S2 SetValue(2 s later object)", private.SetRemaining, p.rows.S2.bar, private.laterDur)
	end

	p.elapsed = (p.elapsed or 0) + elapsed
	if p.elapsed >= 0.5 then
		p.elapsed = 0
		private.RefreshText()
	end
end

-- SAMPLING (every 2 s while recording)
private.SampleSecrets = function()
	if not C_Secrets then
		return
	end
	for _, name in ipairs(private.SECRET_FLAGS) do
		if C_Secrets[name] then
			Tally("0 " .. name, Kind(pcall(C_Secrets[name])))
		else
			Tally("0 " .. name, "missing")
		end
	end
	local id = private.spell and private.spell.id
	if id then
		if C_Secrets.ShouldSpellCooldownBeSecret then
			Tally("2 ShouldSpellCooldownBeSecret", Kind(pcall(C_Secrets.ShouldSpellCooldownBeSecret, id)))
		end
		if C_Secrets.GetSpellCooldownSecrecy then
			Tally("2 GetSpellCooldownSecrecy", private.SecrecyLabel(pcall(C_Secrets.GetSpellCooldownSecrecy, id)))
		end
	end
end

private.SampleSpell = function()
	local id = private.spell and private.spell.id
	if not id then
		return
	end
	local ok, dur = Try("2 GetSpellCooldownDuration (every 2 s)", C_Spell.GetSpellCooldownDuration, id, true)
	if ok then
		local kind = Kind(true, dur)
		Tally("2 timer object returned", kind)
		if kind == "object" then
			Tally("2 HasSecretValues", Kind(pcall(Method, dur, "HasSecretValues")))
			if private.curve then
				local okC, r = pcall(Method, dur, "EvaluateRemainingDuration", private.curve)
				Tally("1C curve result", Kind(okC, r) .. (okC and (" " .. type(r)) or ""))
			end
		end
	end
	if private.wasActive then
		private.ReadSpellNumbers("while on cooldown (latest)")
	end
end

private.SampleCharges = function()
	local c = private.charge
	if not c then
		return
	end
	if not C_Spell.GetSpellChargeDuration then
		Tally("3 timer object returned", "API missing")
		return
	end
	local ok, dur = Try("3 GetSpellChargeDuration", C_Spell.GetSpellChargeDuration, c.id)
	if ok then
		local kind = Kind(true, dur)
		Tally("3 timer object returned", kind)
		if kind == "object" then
			Tally("3 HasSecretValues", Kind(pcall(Method, dur, "HasSecretValues")))
			local okR, r = pcall(Method, dur, "GetRemainingDuration")
			local okT, t = pcall(Method, dur, "GetTotalDuration")
			Note("3 latest remaining / total", (okR and Show(r) or "error") .. " / " .. (okT and Show(t) or "error"))
		end
	end
	local okC, current = pcall(function()
		local info = C_Spell.GetSpellCharges(c.id)
		return info and info.currentCharges
	end)
	Tally("3 GetSpellCharges currentCharges", Kind(okC, current))
end

-- is a riding icon's position hidden?
private.SampleRiding = function()
	local p = private.panel
	if not (p and p:IsShown()) then
		return
	end
	for _, key in ipairs(private.RIDERS) do
		local icon = p.rows[key].icon
		Tally("1" .. key .. " icon GetCenter x", Kind(pcall(Method, icon, "GetCenter")))
		local ok, _, _, _, x = pcall(Method, icon, "GetPoint", 1)
		Tally("1" .. key .. " icon GetPoint x offset", Kind(ok, x))
	end
end

private.Sample = function()
	if not private.recording then
		return
	end
	Count("samples")
	private.SampleSecrets()
	private.CheckCast()
	private.SampleSpell()
	private.Rebind("tick")
	private.SampleCharges()
	private.SampleAuras()
	private.SampleRiding()
end

-- EVENTS
private.OnEvent = function(event, a1, a2)
	if not private.recording then
		return
	end
	if event == "SPELL_UPDATE_COOLDOWN" then
		Count("2 SPELL_UPDATE_COOLDOWN")
		private.CheckCast()
		private.Rebind("event")
	elseif event == "SPELL_UPDATE_CHARGES" then
		Count("3 SPELL_UPDATE_CHARGES")
		private.SampleCharges()
	elseif event == "UNIT_AURA" then
		Count("4 UNIT_AURA")
		private.RebindAura()
		if private.inCombat then
			private.SampleAuras()
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		private.inCombat = true
		private.combats = private.combats + 1
		private.combatStart = GetTime()
		Log("combat started")
	elseif event == "PLAYER_REGEN_ENABLED" then
		if private.combatStart then
			private.combatSeconds = private.combatSeconds + (GetTime() - private.combatStart)
		end
		private.combatStart = nil
		private.inCombat = false
		Log("combat ended")
		if private.cachePending then
			private.CacheAuras()
			private.RebindAura()
		end
		private.Sample()
		if not private.toldCombat then
			private.toldCombat = true
			CDTL3:Print("Probe: combat recorded. /cdtl3 probe report opens the report to copy.")
		end
	elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		private.OnActionEvent(event, a1, a2)
	end
end

private.RegisterEvents = function()
	if not private.eventFrame then
		private.eventFrame = CreateFrame("Frame")
		private.eventFrame:SetScript("OnEvent", function(_, event, ...)
			Try("event handler " .. event, private.OnEvent, event, ...)
		end)
	end
	local f = private.eventFrame
	for _, event in ipairs(private.EVENTS) do
		Try("register " .. event, Method, f, "RegisterEvent", event)
	end
	Try("register UNIT_AURA (player)", Method, f, "RegisterUnitEvent", "UNIT_AURA", "player")
end

-- PANEL
private.CreateRow = function(p, y, label)
	local row = {}

	row.label = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.label:SetPoint("TOPLEFT", 8, y - 3)
	row.label:SetText(label)

	row.bar = CreateFrame("StatusBar", nil, p)
	row.bar:SetSize(290, 16)
	row.bar:SetPoint("TOPLEFT", 156, y)
	row.bar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
	row.bar:GetStatusBarTexture():SetVertexColor(0.2, 0.6, 1, 0.35)
	row.bar:SetMinMaxValues(0, 1)
	row.bar:SetValue(0)

	row.bg = row.bar:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.bg:SetColorTexture(1, 1, 1, 0.08)

	-- the icon rides the fill edge
	row.icon = row.bar:CreateTexture(nil, "OVERLAY")
	row.icon:SetSize(20, 20)
	row.icon:SetPoint("CENTER", row.bar:GetStatusBarTexture(), "RIGHT", 0, 0)

	return row
end

private.CreatePanel = function()
	local p = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	p:SetSize(460, 346)
	p:SetPoint("CENTER", 0, 150)
	p:SetFrameStrata("HIGH")
	p:SetClampedToScreen(true)
	if p.SetBackdrop then
		p:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		p:SetBackdropColor(0, 0, 0, 0.8)
	end
	p:SetMovable(true)
	p:EnableMouse(true)
	p:RegisterForDrag("LeftButton")
	p:SetScript("OnDragStart", p.StartMoving)
	p:SetScript("OnDragStop", p.StopMovingOrSizing)

	p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	p.title:SetPoint("TOPLEFT", 8, -8)
	p.title:SetText("CDTL3 probe (read-only)")

	-- hides the panel only; recording goes on
	p.close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
	p.close:SetPoint("TOPRIGHT", 0, 0)
	p.close:SetScript("OnClick", function()
		p:Hide()
	end)

	p.info = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	p.info:SetPoint("TOPLEFT", 8, -26)
	p.info:SetSize(444, 84)
	p.info:SetJustifyH("LEFT")
	p.info:SetJustifyV("TOP")

	p.rows = {}
	local y = -112
	for _, r in ipairs(private.ROWS) do
		if r.key == "D" then
			p.dLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			p.dLabel:SetPoint("TOPLEFT", 8, y - 3)
			p.dLabel:SetText(r.label)

			p.dIconFrame = CreateFrame("Frame", nil, p)
			p.dIconFrame:SetSize(22, 22)
			p.dIconFrame:SetPoint("TOPLEFT", 156, y + 3)
			p.dIcon = p.dIconFrame:CreateTexture(nil, "ARTWORK")
			p.dIcon:SetAllPoints()
			p.dCooldown = CreateFrame("Cooldown", nil, p.dIconFrame, "CooldownFrameTemplate")
			p.dCooldown:SetAllPoints()

			p.dText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			p.dText:SetPoint("LEFT", p.dIconFrame, "RIGHT", 10, 0)
		else
			p.rows[r.key] = private.CreateRow(p, y, r.label)
		end
		y = y - 26
	end

	p.status = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	p.status:SetPoint("BOTTOMLEFT", 8, 8)
	p.status:SetPoint("BOTTOMRIGHT", -8, 8)
	p.status:SetJustifyH("LEFT")

	return p
end

private.RefreshText = function()
	local p = private.panel
	if not p then
		return
	end
	local sp, ch = private.spell, private.charge
	local lines = {}

	if sp then
		lines[#lines + 1] = "Test spell: " .. sp.name .. " (" .. sp.id .. "), base cooldown "
			.. (sp.base and string.format("%.0f s", sp.base) or "?")
	else
		lines[#lines + 1] = "Test spell: none found. Pick one: /cdtl3 probe spell <id or name>"
	end
	lines[#lines + 1] = "Charge spell: " .. (ch and (ch.name .. " (" .. ch.max .. " charges)") or "none known")

	if private.cachePending then
		lines[#lines + 1] = "Buffs: started in combat, so they are cached when combat ends"
	elseif #private.cache == 0 then
		lines[#lines + 1] = "Buffs cached: none. Buff up, then /cdtl3 probe off and /cdtl3 probe"
	else
		local names = {}
		for i, c in ipairs(private.cache) do
			if i > 4 then
				names[#names + 1] = "..."
				break
			end
			names[#names + 1] = Plain(c.name) .. (c == private.auraTarget and " (E)" or "")
		end
		lines[#lines + 1] = "Buffs cached (" .. #private.cache .. "): " .. table.concat(names, ", ")
	end

	lines[#lines + 1] = "Recording: " .. (private.recording and "ON" or "stopped") .. ", "
		.. (private.inCombat and "IN COMBAT" or "out of combat")
		.. " | Tracked Bars hooked: " .. private.hookedBarCount
		.. " | blocked actions: " .. (private.Total(private.counts, "6 ADDON_ACTION_BLOCKED", "n") + private.Total(private.counts, "6 ADDON_ACTION_FORBIDDEN", "n"))
	lines[#lines + 1] = "Cast the test spell, then fight a target dummy: cast it again and recast a buff."
	lines[#lines + 1] = "Leave combat, then /cdtl3 probe report. /cdtl3 probe off stops."
	p.info:SetText(table.concat(lines, "\n"))

	-- row F shows the icon of the buff it copies
	local m = private.mirror
	if m.target and p.rows.F.iconFor ~= m.target then
		p.rows.F.iconFor = m.target
		local info = private.CooldownInfo(m.target)
		local ok, tex = pcall(C_Spell.GetSpellTexture, info and info.spellID)
		p.rows.F.icon:SetTexture((ok and not IsSecret(tex) and tex) or 134400)
	end

	local secret = "?"
	if C_Secrets and C_Secrets.ShouldCooldownsBeSecret then
		local ok, r = pcall(C_Secrets.ShouldCooldownsBeSecret)
		secret = ok and Plain(r) or "error"
	end
	local remaining = "-"
	if sp then
		local ok, r = pcall(function()
			local dur = C_Spell.GetSpellCooldownDuration(sp.id, true)
			return dur and dur:GetRemainingDuration()
		end)
		remaining = ok and Show(r) or "error"
	end
	local okX, x = pcall(Method, p.rows.A.icon, "GetCenter")
	p.status:SetText("cooldowns secret: " .. secret .. " | test spell remaining: " .. remaining .. " | icon A x: " .. (okX and Show(x) or "error"))
end

-- START / STOP
private.Reset = function()
	private.steps, private.tallies, private.counts, private.notes = {}, {}, {}, {}
	private.log, private.actionLog = {}, {}
	private.cache, private.cacheSkipped, private.cachePending, private.cacheAt = {}, 0, nil, nil
	private.auraTarget = nil
	private.mirror = { calls = {}, ids = 0, target = nil }
	private.swipeNamed, private.swipeStopped = 0, nil
	private.castDur, private.laterDur, private.wasActive, private.castToken = nil, nil, nil, nil
	private.combatSeconds, private.combats, private.toldCombat = 0, 0, nil
	private.startTime = GetTime()
	local okD, d = pcall(date, "%Y-%m-%d %H:%M")
	private.startDate = okD and d or "?"
	local ok, c = pcall(function()
		return InCombatLockdown() or UnitAffectingCombat("player")
	end)
	private.inCombat = ok and not IsSecret(c) and c and true or false
	private.combatStart = private.inCombat and GetTime() or nil
	private.startedInCombat = private.inCombat
end

private.Start = function()
	private.Reset()
	private.recording = true
	Log("recording started")

	if not private.spell then
		local id, source = private.DefaultSpell()
		if id then
			private.SetSpell(id, source)
		end
	end

	private.panel = private.panel or private.CreatePanel()
	local p = private.panel
	if private.binding then
		Try("1D binding SetEnabled", Method, private.binding, "SetEnabled", true)
	else
		Try("1D CreateDurationTextBinding", private.SetupBinding)
	end
	p.rows.F.bar:SetMinMaxValues(0, 1)
	p.rows.F.bar:SetValue(0)
	private.SetupSpell()
	private.PickChargeSpell()

	if private.inCombat then
		private.cachePending = true
		Log("started in combat: buffs are cached when combat ends")
	else
		private.CacheAuras()
	end
	private.InstallMirror()
	private.RegisterEvents()
	private.ticker = C_Timer.NewTicker(private.SAMPLE_SECONDS, function()
		Try("2 s sample", private.Sample)
	end)

	p:SetScript("OnUpdate", function(self, elapsed)
		Try("panel update", private.OnUpdate, self, elapsed)
	end)
	p:Show()
	private.Rebind("start")
	private.RebindAura()
	private.Sample()
	private.RefreshText()

	CDTL3:Print("Probe recording (read-only). Test spell: " .. (private.spell and private.spell.name or "none, pick one with /cdtl3 probe spell <id or name>")
		.. ". Cast it, fight a target dummy, then /cdtl3 probe report.")
end

private.Stop = function()
	if private.panel then
		private.panel:SetScript("OnUpdate", nil)
		private.panel:Hide()
	end
	if not private.recording then
		CDTL3:Print("The probe isn't recording.")
		return
	end
	if private.inCombat and private.combatStart then
		private.combatSeconds = private.combatSeconds + (GetTime() - private.combatStart)
		private.combatStart = nil
	end
	private.recording = false
	if private.ticker then
		private.ticker:Cancel()
		private.ticker = nil
	end
	if private.eventFrame then
		private.eventFrame:UnregisterAllEvents()
	end
	if private.binding then
		pcall(Method, private.binding, "SetEnabled", false)
	end
	Log("recording stopped")
	CDTL3:Print("Probe stopped. Its hooks on the Tracked Bars stay until a /reload but do nothing now. /cdtl3 probe report still shows what was recorded.")
end

-- a new test spell starts sections 1, 2 and 7 afresh (the text binding is set up only once)
private.KEEP_ON_SPELL_CHANGE = { ["1D CreateDurationTextBinding"] = true, ["1D binding SetEnabled"] = true }
private.ClearSpellStats = function()
	for _, store in ipairs({ private.steps, private.tallies, private.counts, private.notes }) do
		for name in pairs(store) do
			local first = name:sub(1, 1)
			if (first == "1" or first == "2" or first == "7") and not private.KEEP_ON_SPELL_CHANGE[name] then
				store[name] = nil
			end
		end
	end
	private.spellChangedAt = Since()
end

private.ChooseSpell = function(arg)
	if arg == "" then
		CDTL3:Print("Usage: /cdtl3 probe spell <spell ID or name>")
		return
	end
	if not private.SetSpell(tonumber(arg) or arg, "chosen with /cdtl3 probe spell") then
		CDTL3:Print("Spell not found: " .. arg .. " (use a spell you know, by ID or name)")
		return
	end
	local sp = private.spell
	if private.recording then
		private.ClearSpellStats()
		private.SetupSpell()
		private.Rebind("start")
		Log("test spell changed to " .. sp.name)
		private.RefreshText()
		CDTL3:Print("Probe test spell: " .. sp.name .. " (" .. sp.id .. ").")
	else
		CDTL3:Print("Probe test spell: " .. sp.name .. " (" .. sp.id .. "). /cdtl3 probe starts recording.")
	end
end

-- REPORT
private.StepLines = function(add, step, label)
	private.printed[step] = true
	label = label or ("  " .. step)
	local s = private.steps[step]
	if not s then
		add(label .. ": NOT RUN")
		return
	end
	local fails = (s.ooc.fail or 0) + (s.combat.fail or 0)
	add(string.format("%s: %s | ooc %d ok, %d failed | combat %d ok, %d failed", label, fails > 0 and "FAILED" or "OK",
		s.ooc.ok or 0, s.ooc.fail or 0, s.combat.ok or 0, s.combat.fail or 0))
	if s.ooc.err then
		add("      first error out of combat: " .. s.ooc.err)
	end
	if s.combat.err then
		add("      first error in combat: " .. s.combat.err)
	end
end

-- only when something failed
private.FailLines = function(add, step, label)
	local s = private.steps[step]
	if s and ((s.ooc.fail or 0) + (s.combat.fail or 0)) > 0 then
		private.StepLines(add, step, label)
	end
	private.printed[step] = true
end

local function LabelList(t)
	local parts = {}
	for label, n in pairs(t) do
		parts[#parts + 1] = label .. " x" .. n
	end
	table.sort(parts)
	return #parts > 0 and table.concat(parts, ", ") or "-"
end

private.TallyLine = function(add, name, label)
	label = label or ("  " .. name)
	local t = private.tallies[name]
	if not t then
		add(label .. ": not sampled")
		return
	end
	add(label .. ": ooc " .. LabelList(t.ooc) .. " | combat " .. LabelList(t.combat))
end

private.NoteLines = function(add, name, label)
	local t = private.notes[name]
	add(label or ("  " .. name) .. ":")
	add("      ooc: " .. (t and t.ooc.text or "-"))
	add("      combat: " .. (t and t.combat.text or "-"))
end

private.CountText = function(name)
	local t = private.counts[name]
	return "ooc " .. (t and t.ooc.n or 0) .. ", combat " .. (t and t.combat.n or 0)
end

private.SpecText = function()
	local ok, text = pcall(function()
		local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
		local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
		if not (getSpec and getInfo) then
			return "no spec API"
		end
		local index = getSpec()
		if not index or index == 0 then
			return "none"
		end
		local id, name = getInfo(index)
		return Plain(name) .. " (" .. Plain(id) .. ")"
	end)
	return ok and text or "error"
end

private.CVarText = function(name)
	local ok, v = pcall(function()
		if C_CVar and C_CVar.GetCVar then
			return C_CVar.GetCVar(name)
		end
		return GetCVar(name)
	end)
	return ok and Plain(v) or "error"
end

private.ReportHeader = function(add)
	add("CDTL3 probe report")
	add("A read-only test of how WoW: Forever and Retail let addons show hidden (secret) timers. It changes no settings, leaves CDTL3's own timers alone and never moves or changes Blizzard's frames: it reads values, draws its own test bars on a small panel, and copies the values Blizzard's Tracked Bars are given.")
	add(string.format("CDTL3 %s | recording %s | started %s | samples: %s | combat entered %d time(s), about %d s in combat",
		Plain(CDTL3.version), private.recording and "ON" or "stopped", private.startDate or "?",
		private.CountText("samples"), private.combats or 0, math.floor(private.CombatSeconds())))
	add("How to read: ooc = out of combat, combat = in combat. OK / FAILED = whether a call raised a Lua error (counted per call, first error kept). SECRET = the game hid that value from addons; the probe never compares or prints a hidden value. \"x5\" = seen 5 times. Panel rows A-F, S1 and S2 are explained in their sections.")
	if private.Total(private.counts, "samples", "n") > 0 and not (private.counts["samples"] and private.counts["samples"].combat.n) then
		add("WARNING: nothing was recorded in combat. Fight a target dummy while the probe records, then copy the report again.")
	end
end

private.Report0 = function(add)
	add("== 0. Client")
	local ok, version, build, buildDate, interface = pcall(GetBuildInfo)
	add("  GetBuildInfo: " .. (ok and (Plain(version) .. ", build " .. Plain(build) .. ", " .. Plain(buildDate) .. ", interface " .. Plain(interface)) or "error"))
	add("  CDTL3.isForever " .. Plain(CDTL3.isForever) .. " | CDTL3.retailAPI " .. Plain(CDTL3.retailAPI) .. " | WOW_PROJECT_ID " .. Plain(WOW_PROJECT_ID))
	local okC, className, classToken = pcall(UnitClass, "player")
	add("  Class: " .. (okC and (Plain(className) .. " (" .. Plain(classToken) .. ")") or "error") .. " | spec: " .. private.SpecText())
	add("  C_Secrets flags (true = values are being hidden), sampled every 2 s:")
	for _, name in ipairs(private.SECRET_FLAGS) do
		private.TallyLine(add, "0 " .. name, "    " .. name)
	end
end

private.Report1 = function(add)
	add("== 1. Riding (panel rows A-D)")
	add("Tests: can an icon ride the fill edge of a StatusBar that is fed a hidden timer? A = SetMinMaxValues(0, base cooldown) + SetValue(timer:GetRemainingDuration()) every frame; B = SetTimerDuration(timer, Immediate, RemainingTime) on each cooldown event; C = SetValue(timer:EvaluateRemainingDuration(curve)) every frame, on a split-lane curve; D = countdown text from C_DurationUtil.CreateDurationTextBinding (D's swipe is section 7).")
	add("Look for: every call OK in combat, and the player saying whether icons A, B and C kept moving in combat and D's text kept counting. SECRET icon positions are expected while an icon rides a hidden value.")
	private.StepLines(add, "1 GetSpellCooldownDuration (every frame)")
	private.StepLines(add, "1A SetMinMaxValues")
	private.StepLines(add, "1A SetValue(GetRemainingDuration)")
	private.StepLines(add, "1B SetTimerDuration")
	private.StepLines(add, "1C curve setup")
	private.StepLines(add, "1C SetValue(EvaluateRemainingDuration)")
	private.TallyLine(add, "1C curve result", "  1C curve result (kind and Lua type)")
	private.StepLines(add, "1D CreateDurationTextBinding")
	private.FailLines(add, "1D binding SetEnabled")
	private.StepLines(add, "1D binding SetDuration")
	add("  Icon positions, sampled every 2 s while the panel was open:")
	for _, key in ipairs(private.RIDERS) do
		private.TallyLine(add, "1" .. key .. " icon GetCenter x", "    " .. key .. " GetCenter x")
		private.TallyLine(add, "1" .. key .. " icon GetPoint x offset", "    " .. key .. " GetPoint x offset")
	end
end

private.Report2 = function(add)
	add("== 2. Spell timer object (C_Spell.GetSpellCooldownDuration)")
	local sp = private.spell
	if not sp then
		add("  No test spell: no saved CDTL3 spell for this character and no Cooldown Manager Essential spell is known with a base cooldown of 8 s or more. Pick one with /cdtl3 probe spell <id or name>.")
		return
	end
	add(string.format("  Test spell: %s (spell %s), base cooldown %s s (GetSpellBaseCooldown); %s.", sp.name, Plain(sp.id),
		sp.base and string.format("%.1f", sp.base) or "?", sp.source))
	if private.spellChangedAt then
		add("  The test spell was changed at +" .. private.spellChangedAt .. " s; sections 1, 2 and 7 count from then.")
	end
	add("Tests: does the timer object carry the real (talented) cooldown, does it come back in combat, and is it live or a snapshot that must be fetched again?")
	add("Look for: out of combat, \"object total SHORTER than base\" means talents and haste are included. In combat, an object every time; HasSecretValues true is expected. Rows S1 (object kept from the cast) and S2 (object fetched 2 s later) are drawn like row A from the object they hold: if both stay level with A, one object can be kept; if they drift from A after the cooldown changes (a reset or reduction), objects are snapshots and must be fetched again on SPELL_UPDATE_COOLDOWN.")
	private.StepLines(add, "2 GetSpellCooldownDuration (every 2 s)")
	private.TallyLine(add, "2 timer object returned")
	private.TallyLine(add, "2 HasSecretValues")
	private.TallyLine(add, "2 ShouldSpellCooldownBeSecret")
	private.TallyLine(add, "2 GetSpellCooldownSecrecy")
	private.TallyLine(add, "2 isActive readable", "  2 isActive / isOnGCD readable (used to spot the cast)")
	add("  SPELL_UPDATE_COOLDOWN events: " .. private.CountText("2 SPELL_UPDATE_COOLDOWN") .. " | casts seen: " .. private.CountText("2 casts seen"))
	private.StepLines(add, "2 GetSpellCooldownDuration (rows B, D)")
	private.TallyLine(add, "2 refetch on SPELL_UPDATE_COOLDOWN")
	private.StepLines(add, "2 fetch at cast")
	private.StepLines(add, "2 fetch 2 s after cast")
	private.FailLines(add, "2 after-cast check")
	private.TallyLine(add, "2 cast vs 2 s later object", "  2 object from the cast vs object 2 s later (same object = live by definition)")
	private.StepLines(add, "2 S1 SetValue(cast object)")
	private.StepLines(add, "2 S2 SetValue(2 s later object)")
	add("  Readings (latest per phase):")
	private.NoteLines(add, "2 readings at cast", "    at the cast:")
	private.NoteLines(add, "2 readings 2 s after cast", "    2 s after the cast:")
	private.NoteLines(add, "2 readings while on cooldown (latest)", "    while on cooldown (latest):")
end

private.Report3 = function(add)
	add("== 3. Charges (C_Spell.GetSpellChargeDuration)")
	local c = private.charge
	if not c then
		add("  no charge spell: none of the test spell, CDTL3's saved spells for this character or the Cooldown Manager's charge spells is known with more than one charge.")
		return
	end
	add("  Charge spell: " .. c.name .. " (spell " .. c.id .. "), " .. c.max .. " charges")
	add("Tests: does the recharge timer object come back in combat? Look for: OK and \"object\" in combat (spend a charge while fighting).")
	private.StepLines(add, "3 GetSpellChargeDuration")
	private.TallyLine(add, "3 timer object returned")
	private.TallyLine(add, "3 HasSecretValues")
	private.TallyLine(add, "3 GetSpellCharges currentCharges")
	add("  SPELL_UPDATE_CHARGES events: " .. private.CountText("3 SPELL_UPDATE_CHARGES"))
	private.NoteLines(add, "3 latest remaining / total", "    latest remaining / total:")
end

private.Report4 = function(add)
	add("== 4. Buffs by cached aura instance ID (C_UnitAuras.GetAuraDuration)")
	add("Tests: an aura instance ID copied while auras were readable (out of combat) still works in combat, so buffs you had before the pull could be timed exactly without the Cooldown Manager.")
	add("Look for: GetAuraDuration OK with \"object\" in combat. Row E shows the first timed cached buff from its object, fetched again on every UNIT_AURA: a recast in combat should make row E jump back to full.")
	if private.startedInCombat then
		add("  Recording started in combat, so the cache could not be taken at the start.")
	end
	if private.cachePending then
		add("  Cache: not taken yet (still waiting for combat to end).")
	else
		add(string.format("  Cache: taken at +%s s out of combat, %d buff(s), %d skipped as secret.", private.cacheAt or "?", #private.cache, private.cacheSkipped or 0))
	end
	private.FailLines(add, "4 cache: GetAuraDataByIndex")
	add("  UNIT_AURA events (player): " .. private.CountText("4 UNIT_AURA") .. "; each one in combat samples every cached ID, as does the 2 s timer.")
	for i, c in ipairs(private.cache) do
		local k = "4#" .. i
		add(string.format("  #%d %s (spell %s, instance %s, duration %s s)%s", i, Plain(c.name), Plain(c.spellId), Plain(c.id),
			Show(c.duration), c == private.auraTarget and " - shown on row E" or ""))
		private.StepLines(add, k .. " GetAuraDuration", "    GetAuraDuration")
		private.TallyLine(add, k .. " timer object", "    timer object")
		private.TallyLine(add, k .. " HasSecretValues", "    HasSecretValues")
		private.StepLines(add, k .. " GetAuraDataByAuraInstanceID", "    GetAuraDataByAuraInstanceID")
		private.TallyLine(add, k .. " aura data", "    aura data (which fields are secret)")
		private.TallyLine(add, k .. " GetSpellAuraSecrecy", "    C_Secrets.GetSpellAuraSecrecy")
		private.FailLines(add, k .. " GetSpellAuraSecrecy", "    GetSpellAuraSecrecy call")
		private.TallyLine(add, k .. " ShouldUnitAuraInstanceBeSecret", "    C_Secrets.ShouldUnitAuraInstanceBeSecret")
		private.FailLines(add, k .. " ShouldUnitAuraInstanceBeSecret", "    ShouldUnitAuraInstanceBeSecret call")
	end
	add("  Row E:")
	private.StepLines(add, "4E GetAuraDuration", "    GetAuraDuration (on UNIT_AURA)")
	private.StepLines(add, "4E SetTimerDuration", "    SetTimerDuration")
end

private.CooldownLine = function(cooldownID)
	local info = private.CooldownInfo(cooldownID)
	if not info then
		return "cooldownID " .. Plain(cooldownID) .. ": no info"
	end
	local ok, text = pcall(function()
		local linked = {}
		if type(info.linkedSpellIDs) == "table" then
			for i, id in ipairs(info.linkedSpellIDs) do
				if i > 4 then
					linked[#linked + 1] = "..."
					break
				end
				linked[#linked + 1] = private.SpellName(id) .. " " .. Plain(id)
			end
		end
		return string.format("%s (spell %s, cooldownID %s) | linked: %s | hasAura %s | selfAura %s | charges %s",
			type(info.spellID) == "number" and private.SpellName(info.spellID) or "?", Plain(info.spellID), Plain(cooldownID),
			#linked > 0 and table.concat(linked, ", ") or "none", Plain(info.hasAura), Plain(info.selfAura), Plain(info.charges))
	end)
	return ok and text or ("cooldownID " .. Plain(cooldownID) .. ": " .. tostring(text))
end

private.ViewerLine = function(name)
	local v = _G[name]
	if not v then
		return name .. ": missing"
	end
	local okS, shown = pcall(Method, v, "IsShown")
	local okV, visible = pcall(Method, v, "IsVisible")
	local okI, items = pcall(Method, v, "GetItemFrames")
	local count, withID = "?", 0
	if okI and type(items) == "table" then
		count = #items
		for _, item in ipairs(items) do
			if Kind(pcall(Method, item, "GetCooldownID")) == "readable" then
				withID = withID + 1
			end
		end
	end
	return string.format("%s: exists, shown %s, visible %s, item frames %s (%d with a cooldown)", name,
		okS and Plain(shown) or "error", okV and Plain(visible) or "error", tostring(count), withID)
end

private.Report5 = function(add)
	add("== 5. Cooldown Manager (C_CooldownViewer; static data)")
	add("Tests: is Blizzard's Cooldown Manager available and switched on, and which cooldowns and buffs does it offer this character? On Forever it is off by default (Options > Gameplay Enhancements, or /cdm).")
	if not C_CooldownViewer then
		add("  C_CooldownViewer: missing on this client")
		return
	end
	local ok, available, reason = pcall(C_CooldownViewer.IsCooldownViewerAvailable)
	add("  IsCooldownViewerAvailable: " .. (ok and (Plain(available) .. ", failure reason: \"" .. Plain(reason) .. "\"") or ("error: " .. tostring(available))))
	add("  CVar cooldownViewerEnabled: " .. private.CVarText("cooldownViewerEnabled"))
	add("  Cooldowns per category, GetCooldownViewerCategorySet(cat) / (cat, true) = learned / including unlearned:")
	for cat = 0, 8 do
		local learned, err1 = private.CategorySet(cat, false)
		local all, err2 = private.CategorySet(cat, true)
		add(string.format("    %d %s: %s / %s", cat, private.CATEGORIES[cat] or "?",
			learned and #learned or ("error: " .. tostring(err1)), all and #all or ("error: " .. tostring(err2))))
	end
	for cat = 0, 3 do
		local ids = private.CategorySet(cat, false)
		add("  " .. private.CATEGORIES[cat] .. " (learned):")
		if not ids or #ids == 0 then
			add("    none")
		else
			for i, cooldownID in ipairs(ids) do
				if i > private.MAX_LIST then
					add("    ... and " .. (#ids - private.MAX_LIST) .. " more")
					break
				end
				add("    " .. private.CooldownLine(cooldownID))
			end
		end
	end
	add("  Viewer frames:")
	for _, name in ipairs(private.VIEWERS) do
		add("    " .. private.ViewerLine(name))
	end
end

private.Report6 = function(add)
	add("== 6. Mirror of the Cooldown Manager's Tracked Bars (row F)")
	add("Tests: post-hooks (hooksecurefunc) on the StatusBar of each BuffBarCooldownViewer item (.Bar: SetMinMaxValues / SetValue) copy the hidden buff timer Blizzard draws into row F. Blizzard's frames are never moved or changed. Works only for buffs set up in the Cooldown Manager's Tracked Bars, with the Cooldown Manager on.")
	add("Look for: calls counted in combat, row F moving with Blizzard's bar, no ADDON_ACTION_BLOCKED / FORBIDDEN, and the player seeing no Blizzard Lua errors afterwards.")
	add("  BuffBarCooldownViewer: " .. (_G["BuffBarCooldownViewer"] and "exists" or "missing") .. " | OnAcquireItemFrame hooked: "
		.. tostring(private.acquireHooked) .. " | bars hooked: " .. private.hookedBarCount)
	private.StepLines(add, "6 hook OnAcquireItemFrame")
	private.StepLines(add, "6 GetItemFrames")
	private.StepLines(add, "6 hook bar SetMinMaxValues")
	private.StepLines(add, "6 hook bar SetValue")
	local m = private.mirror
	add("  Row F copies: " .. (m.target and (private.CooldownName(m.target) .. " (cooldownID " .. Plain(m.target) .. ")") or "nothing yet (no Tracked Bar seen)"))
	private.StepLines(add, "6F SetMinMaxValues (copy)")
	private.StepLines(add, "6F SetValue (copy)")
	add("  Calls Blizzard made to the hooked bars, per cooldownID:")
	local keys = {}
	for k in pairs(m.calls) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	if #keys == 0 then
		add("    none")
	end
	for _, k in ipairs(keys) do
		local rec = m.calls[k]
		local name, spellID = private.CooldownName(k)
		add(string.format("    %s: SetMinMaxValues ooc %d, combat %d | SetValue ooc %d, combat %d",
			spellID and (name .. ", cooldownID " .. k) or (name .. " (no Cooldown Manager info)"),
			rec.SetMinMaxValues.ooc, rec.SetMinMaxValues.combat, rec.SetValue.ooc, rec.SetValue.combat))
	end
	if m.ids >= private.MAX_MIRROR_IDS then
		add("    (stopped counting new cooldownIDs after " .. private.MAX_MIRROR_IDS .. ")")
	end
	add("  ADDON_ACTION_BLOCKED: " .. private.CountText("6 ADDON_ACTION_BLOCKED") .. " | ADDON_ACTION_FORBIDDEN: " .. private.CountText("6 ADDON_ACTION_FORBIDDEN") .. " (any addon, while recording)")
	for _, line in ipairs(private.actionLog) do
		add("    " .. line)
	end
end

private.Report7 = function(add)
	add("== 7. Swipe (Cooldown:SetCooldownFromDurationObject on row D's own Cooldown frame)")
	add("Tests: can addon code draw a cooldown swipe straight from the test spell's timer object, in and out of combat? Blizzard's docs mark the call protected (as they do SetCooldown) and allow hidden values in it only for untainted code.")
	add("Look for: OK in combat, no blocked / forbidden event naming it, and the player seeing row D's swipe turn in combat.")
	private.StepLines(add, "7 SetCooldownFromDurationObject")
	add("  Blocked / forbidden events naming SetCooldownFromDurationObject: " .. (private.swipeNamed or 0)
		.. (private.swipeStopped and " (calls stopped after a FORBIDDEN, so Blizzard's warning doesn't repeat)" or ""))
end

private.ReportInternals = function(add)
	add("== Probe internals (event handlers, registration, timers)")
	local names, fine = {}, 0
	for step, s in pairs(private.steps) do
		if not private.printed[step] then
			if ((s.ooc.fail or 0) + (s.combat.fail or 0)) > 0 then
				names[#names + 1] = step
			else
				fine = fine + 1
			end
		end
	end
	table.sort(names)
	for _, step in ipairs(names) do
		private.StepLines(add, step)
	end
	add("  " .. (#names == 0 and "none failed" or (#names .. " failed")) .. "; " .. fine .. " other step(s) OK")
end

private.ReportLog = function(add)
	add("== Log (first " .. private.MAX_LOG .. " entries)")
	for _, line in ipairs(private.log) do
		add("  " .. line)
	end
end

private.BuildReport = function()
	local lines = {}
	local function add(s)
		lines[#lines + 1] = s
	end
	private.printed = {}
	local sections = { private.ReportHeader, private.Report0, private.Report1, private.Report2, private.Report3,
		private.Report4, private.Report5, private.Report6, private.Report7, private.ReportInternals, private.ReportLog }
	for _, section in ipairs(sections) do
		local ok, err = pcall(section, add)
		if not ok then
			add("  (the probe hit an error writing this part: " .. tostring(err) .. ")")
		end
		add("")
	end
	return table.concat(lines, "\n")
end

private.CreateWindow = function()
	local w = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	w:SetSize(640, 480)
	w:SetPoint("CENTER")
	w:SetFrameStrata("DIALOG")
	w:SetClampedToScreen(true)
	if w.SetBackdrop then
		w:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		w:SetBackdropColor(0, 0, 0, 0.9)
	end
	w:SetMovable(true)
	w:EnableMouse(true)
	w:RegisterForDrag("LeftButton")
	w:SetScript("OnDragStart", w.StartMoving)
	w:SetScript("OnDragStop", w.StopMovingOrSizing)

	w.title = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	w.title:SetPoint("TOPLEFT", 10, -10)
	w.title:SetText("CDTL3 probe report - the text is selected: Cmd/Ctrl+C copies it (Cmd/Ctrl+A selects all again)")

	w.close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
	w.close:SetPoint("TOPRIGHT", 0, 0)
	w.close:SetScript("OnClick", function()
		w:Hide()
	end)

	-- the scroll template names its scroll bar after its parent, so this one frame is named
	local sf = CreateFrame("ScrollFrame", "CDTL3_ProbeReportScroll", w, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", 12, -32)
	sf:SetPoint("BOTTOMRIGHT", -32, 12)

	local eb = CreateFrame("EditBox", nil, sf)
	eb:SetMultiLine(true)
	eb:SetMaxLetters(0)
	eb:SetAutoFocus(false)
	eb:SetFontObject(ChatFontNormal)
	eb:SetWidth(590)
	eb:SetScript("OnEscapePressed", function()
		w:Hide()
	end)
	-- typing can't change the report
	eb:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(private.reportText or "")
			self:HighlightText()
		end
	end)
	sf:SetScrollChild(eb)

	w.scroll, w.edit = sf, eb
	return w
end

private.ShowReport = function()
	private.reportText = private.BuildReport()
	private.window = private.window or private.CreateWindow()
	local w = private.window
	w.edit:SetText(private.reportText)
	w:Show()
	w.scroll:SetVerticalScroll(0)
	w.edit:SetFocus()
	w.edit:HighlightText()
end

-- COMMAND: /cdtl3 probe [spell <id or name> | report | off]
function CDTL3:Probe(args)
	args = (args or ""):trim()

	if not Supported() then
		CDTL3:Print("The probe needs WoW: Forever or Retail: it tests timer APIs this client doesn't have.")
		return
	end

	local cmd, rest = args:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()

	if cmd == "" then
		if not private.recording then
			private.Start()
		elseif private.panel:IsShown() then
			private.panel:Hide()
			CDTL3:Print("Probe panel hidden, still recording. /cdtl3 probe shows it again, /cdtl3 probe off stops.")
		else
			private.panel:Show()
			private.RefreshText()
		end
	elseif cmd == "spell" then
		private.ChooseSpell(rest or "")
	elseif cmd == "report" then
		if not private.steps then
			CDTL3:Print("Nothing recorded yet: /cdtl3 probe starts recording.")
			return
		end
		private.ShowReport()
	elseif cmd == "off" then
		private.Stop()
	else
		CDTL3:Print("Usage: /cdtl3 probe | /cdtl3 probe spell <id or name> | /cdtl3 probe report | /cdtl3 probe off")
	end
end
