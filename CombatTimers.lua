--[[
	Cooldown Timeline 3 - combat timers (test build, branch combat-timers)

	On clients that hide cooldown and aura values from addons in combat (Retail 12.x, WoW: Forever),
	spell icons ride a transparent StatusBar fed the game's own timer object, bars drain from it, and
	buffs in the Cooldown Manager's Tracked Bars copy what Blizzard's bar is given. CDTL3's estimate
	(d.currentCD) keeps running underneath for Ready, sorting and everything else.

	Values that may be hidden (secret) are only handed to widgets: never compared, used in arithmetic,
	concatenated or turned into strings. Every call runs in a pcall; a frame that fails stops riding
	and falls back to the estimate until combat ends.
]]--

local CT = {}
CDTL3.CombatTimers = CT

local private = {}

private.READ_INTERVAL = 0.2	-- seconds between isActive reads while riding
private.STALE = 0.5			-- a Tracked Bars feed older than this has ended
private.MIN_FEED = 0.1		-- a feed must run this long before it starts a buff
private.READY_GRACE = 0.5	-- a new rider waits this long for isActive before trusting false
private.HOLD = 0.1			-- the estimate is held here while the game says the cooldown runs
private.TICK = 0.1
private.RECHECK = 3
private.FILL = [[Interface\Buttons\WHITE8X8]]
private.OPPOSITE = { LEFT = "RIGHT", RIGHT = "LEFT", BOTTOM = "TOP", TOP = "BOTTOM" }
private.EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELL_UPDATE_COOLDOWN",
	"SPELL_UPDATE_CHARGES", "CVAR_UPDATE", "PLAYER_ENTERING_WORLD" }
private.LANES = { CDTL3_Lane_1 = true, CDTL3_Lane_2 = true, CDTL3_Lane_3 = true }
private.BAR_FRAMES = { CDTL3_BarFrame_1_MF = true, CDTL3_BarFrame_2_MF = true, CDTL3_BarFrame_3_MF = true }

private.gen = 0			-- bumped by cooldown and combat events: riders re-fetch their timer
private.errors = 0
private.curves = {}
private.spellNames = {}
private.cooldownNames = {}
private.mirrorOn = false
private.hidden = false
private.pendingHide = false
-- hooks on Blizzard's bars can't be removed: they return at once while the module is off
private.mirror = { hooked = {}, recs = {}, byName = {} }

-- HELPERS
local function IsSecret(v)
	if not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, v)
	return ok and secret == true
end

-- for pcall: a bad object or a missing method errors inside the pcall
local function Method(obj, method, ...)
	return obj[method](obj, ...)
end

local function Settings()
	local g = CDTL3.db and CDTL3.db.profile and CDTL3.db.profile.global
	return g and g["combatTimers"]
end

local function ParentName(region)
	local p = region and region:GetParent()
	return p and p:GetName()
end

private.OnLane = function(f)
	return private.LANES[ParentName(f.icon) or ""] and true or false
end

private.OnBarFrame = function(f)
	return private.BAR_FRAMES[ParentName(f.bar) or ""] and true or false
end

private.Error = function(err)
	private.errors = private.errors + 1
	private.lastError = type(err) == "string" and err or "error"
end

private.SpellName = function(id)
	local name = private.spellNames[id]
	if name == nil then
		local ok, n = pcall(C_Spell.GetSpellName, id)
		name = (ok and not IsSecret(n) and type(n) == "string") and n or false
		if name then
			private.spellNames[id] = name
		end
	end
	return name or nil
end

-- AVAILABILITY
function CT:Available()
	return (CDTL3.retailAPI and C_Spell and C_Spell.GetSpellCooldownDuration and C_Secrets and C_CurveUtil
		and C_DurationUtil) and true or false
end

function CT:Enabled()
	if not CT:Available() then
		return false
	end
	local cs = Settings()
	return (cs and cs["enabled"]) and true or false
end

-- SPELLS
private.SpellSecret = function(id)
	if C_Secrets.ShouldSpellCooldownBeSecret then
		local ok, v = pcall(C_Secrets.ShouldSpellCooldownBeSecret, id)
		if ok and not IsSecret(v) and type(v) == "boolean" then
			return v
		end
	end
	if C_Secrets.ShouldCooldownsBeSecret then
		local ok, v = pcall(C_Secrets.ShouldCooldownsBeSecret)
		if ok and not IsSecret(v) and type(v) == "boolean" then
			return v
		end
	end
	return false
end

-- charge spells ride their recharge timer; maxCharges is never hidden
private.FetchDuration = function(ct, id)
	local charges = false
	if C_Spell.GetSpellCharges and C_Spell.GetSpellChargeDuration then
		local ok, multi = pcall(function()
			local info = C_Spell.GetSpellCharges(id)
			return info and info.maxCharges and info.maxCharges > 1
		end)
		charges = ok and multi == true
	end
	ct.charges = charges

	local ok, dur
	if charges then
		ok, dur = pcall(C_Spell.GetSpellChargeDuration, id)
	else
		ok, dur = pcall(C_Spell.GetSpellCooldownDuration, id, true)
	end
	local t = ok and type(dur)
	ct.dur = (ok and not IsSecret(dur) and (t == "table" or t == "userdata")) and dur or nil
	ct.durGen = private.gen
end

-- isActive / isOnGCD are never hidden; isOnGCD is only trusted when read on SPELL_UPDATE_COOLDOWN
private.ReadActive = function(ct, id, withGCD)
	local ok, active, onGCD = pcall(function()
		if ct.charges then
			local info = C_Spell.GetSpellCharges(id)
			return info and info.isActive, nil
		end
		local info = C_Spell.GetSpellCooldown(id)
		if info then
			return info.isActive, info.isOnGCD
		end
	end)
	if not ok then
		return
	end
	if IsSecret(active) or type(active) ~= "boolean" then
		active = nil
	end
	if IsSecret(onGCD) or type(onGCD) ~= "boolean" then
		onGCD = nil
	end
	ct.active = active
	if withGCD then
		ct.onGCD = onGCD
	end
end

private.SpellWants = function(f, ct)
	local d = f.data
	if d["setCustomCD"] and d["customCDTime"] then
		return false	-- the user's Custom CD Time wins: keep the estimate
	end
	if d["oaf"] and d["oafHeld"] then
		return false
	end
	if not ct.riding and not (d["currentCD"] > 0) then
		return false
	end

	-- the hidden-or-not check is cached, so out of combat this returns before any frame calls
	local now = GetTime()
	if ct.checkGen ~= private.gen or not ct.checkAt or now - ct.checkAt >= private.READ_INTERVAL then
		ct.checkAt = now
		ct.checkGen = private.gen
		ct.secret = private.SpellSecret(d["id"])
		if ct.secret then
			if not ct.dur or ct.durGen ~= private.gen then
				private.FetchDuration(ct, d["id"])
			end
			private.ReadActive(ct, d["id"], false)
		end
	end

	if not (ct.secret and ct.dur) then
		return false
	end
	return private.OnLane(f) or private.OnBarFrame(f)
end

-- Ready on time: the game says the cooldown is over. A new rider waits a moment for the game to
-- report the cooldown running before it trusts a "not active" read (the cast and the cooldown
-- start can land a frame apart).
private.SpellTick = function(f, ct)
	local d = f.data
	if ct.active == true and ct.onGCD ~= true then
		ct.seenActive = true
	end
	local settled = ct.seenActive or GetTime() - ct.since >= private.READY_GRACE
	if settled and (ct.active == false or ct.onGCD == true) then
		d["currentCD"] = 0
		private.Leave(f, false)
		return
	end
	if ct.active == true and ct.onGCD ~= true and d["currentCD"] <= private.HOLD then
		d["currentCD"] = private.HOLD
	end
end

-- BUFFS (Tracked Bars mirror)
-- A feed is fresh while Blizzard keeps updating its bar. A long frame (a hitch) must not read as
-- "stopped": an update made in the last frame this module saw still counts, however long ago.
private.Fresh = function(rec, now)
	if not rec.time then
		return false
	end
	return now - rec.time <= private.STALE or rec.time >= (private.prevFrame or 0)
end

-- Blizzard updates a bar every frame only while its buff is up. A single update (a layout
-- refresh of an idle bar) is not a running buff: the feed must have run for a moment.
private.FeedFor = function(name)
	local rec = name and private.mirror.byName[name]
	if rec and rec.nameSet and rec.nameSet[name] and private.Fresh(rec, GetTime())
		and rec.time - rec.start >= private.MIN_FEED then
		return rec
	end
end

private.BuffWants = function(f, ct)
	local d = f.data
	if not private.mirrorOn then
		return false
	end
	if not ct.riding and not (d["currentCD"] > 0) then
		return false
	end
	local rec = private.FeedFor(d["name"])
	if not rec and not ct.riding then
		return false
	end
	if not CDTL3:AurasAreSecret() then
		return false
	end
	if not (private.OnLane(f) or private.OnBarFrame(f)) then
		return false
	end
	if rec then
		ct.feed = rec
		return true
	end
	d["currentCD"] = 0	-- riding, and Blizzard stopped feeding the bar: the buff ended
	return false
end

private.BuffTick = function(f, ct)
	local d = f.data
	if d["currentCD"] <= private.HOLD then
		d["currentCD"] = private.HOLD
	end
end

-- RIDING
private.Enter = function(f, ct, kind)
	ct.riding = true
	ct.kind = kind
	ct.since = GetTime()
	ct.seenActive = false
	ct.onGCD = nil	-- a read left over from an earlier ride would send a fresh cast straight to Ready
	f.icon.ctRiding = true
end

-- resync: restart the poll so the next one re-reads the (now readable) cooldown
private.Leave = function(f, resync)
	local ct = f.ct
	if not ct then
		return
	end
	ct.riding = false
	ct.feed = nil
	f.icon.ctRiding = nil
	if ct.rider then
		pcall(Method, ct.rider, "Hide")
	end
	if ct.anchored then
		ct.anchored = false
		pcall(function()
			f.icon:ClearAllPoints()
			f.icon:SetPoint("CENTER", 0, 0)
		end)
	end
	if ct.bindings then
		for _, b in pairs(ct.bindings) do
			if b.on then
				pcall(Method, b.binding, "SetEnabled", false)
			end
			b.on = false
			b.dur = nil
		end
	end
	if ct.barDriven then
		ct.barDriven = false
		pcall(Method, f.bar.bar, "SetMinMaxValues", 0, 1)	-- what RefreshBar sets
	end
	if resync then
		f.updateCount = 0
	end
end

private.Fail = function(f, err)
	private.Error(err)
	if f.ct then
		f.ct.broken = true	-- back to the estimate until combat ends
	end
	pcall(private.Leave, f, true)
end

private.Update = function(f)
	local d = f.data
	local kind = nil
	if d["type"] == "spells" or d["type"] == "petspells" then
		kind = "spell"
	elseif d["type"] == "buffs" then
		kind = "buff"
	end
	if not kind then
		return
	end

	local ct = f.ct
	if not ct then
		ct = {}
		f.ct = ct
	end

	local want = false
	if not ct.broken and CT:Enabled() then
		if kind == "spell" then
			want = private.SpellWants(f, ct)
		else
			want = private.BuffWants(f, ct)
		end
	end

	if want then
		if not ct.riding then
			private.Enter(f, ct, kind)
		end
		if kind == "spell" then
			private.SpellTick(f, ct)
		else
			private.BuffTick(f, ct)
		end
	elseif ct.riding then
		private.Leave(f, true)
	end
end

-- every frame from CooldownUpdate, before IconUpdate / BarUpdate
function CT:Update(f, elapsed)
	if not (f.ct and f.ct.riding) and not CT:Enabled() then
		return
	end
	local ok, err = pcall(private.Update, f, elapsed)
	if not ok then
		private.Fail(f, err)
	end
end

function CT:Riding(f)
	return (f.ct and f.ct.riding) and true or false
end

-- SPLIT LANE CURVES
-- CalcSplitPosition is piecewise linear in the remaining time, so a linear curve with knots at
-- 0, each split point and the lane's end reproduces it exactly.
-- variant "abs": SPLIT_ABS, x = seconds over splitAbs.max
-- variant "sec": SPLIT, x = seconds over total (split points are percentages of it)
-- variant "pct": SPLIT, x = remaining fraction 0-1 (EvaluateRemainingPercent's range)
private.SplitCurve = function(s, variant, total)
	local ss = variant == "abs" and s["mode"]["splitAbs"] or s["mode"]["split"]
	local key = table.concat({ variant, tostring(s["mode"]["type"]), tostring(total), tostring(ss["max"]),
		tostring(ss["count"]), tostring(ss["s1v"]), tostring(ss["s1p"]), tostring(ss["s2v"]), tostring(ss["s2p"]),
		tostring(ss["s3v"]), tostring(ss["s3p"]) }, ":")
	local curve = private.curves[key]
	if curve then
		return curve
	end

	local span = ss["max"]
	local scale = 1
	if variant == "pct" then
		span, scale = 1, 1 / 100
	elseif variant == "sec" then
		span, scale = total, total / 100
	end

	local xs = { 0, span, span * (1 - 1e-6) }
	local count = math.min(tonumber(ss["count"]) or 0, 3)
	for i = 1, count do
		local v = ss["s" .. i .. "v"]
		if type(v) == "number" then
			local x = v * scale
			if x > 0 and x < span then
				xs[#xs + 1] = x
			end
		end
	end
	table.sort(xs)

	curve = C_CurveUtil.CreateCurve()
	if Enum.LuaCurveType and Enum.LuaCurveType.Linear then
		curve:SetType(Enum.LuaCurveType.Linear)
	end
	local last = nil
	for _, x in ipairs(xs) do
		if x ~= last then
			last = x
			local ok, y = pcall(CDTL3.CalcSplitPosition, x, span, s)
			if ok and type(y) == "number" and y == y and y ~= math.huge and y ~= -math.huge then
				curve:AddPoint(x, y)
			end
		end
	end
	private.curves[key] = curve
	return curve
end

-- out of combat, so the curves exist before the pull
private.Prewarm = function()
	local lanes = CDTL3.db and CDTL3.db.profile and CDTL3.db.profile.lanes
	if not lanes then
		return
	end
	for _, key in ipairs({ "lane1", "lane2", "lane3" }) do
		local s = lanes[key]
		local mode = s and s["mode"] and s["mode"]["type"]
		if mode == "SPLIT_ABS" then
			pcall(private.SplitCurve, s, "abs")
		elseif mode == "SPLIT" then
			pcall(private.SplitCurve, s, "pct")
			pcall(private.SplitCurve, s, "sec", s["mode"]["split"]["max"])
		end
	end
end

-- LANE ICONS
private.Rider = function(ct, lane, s)
	local rider = ct.rider
	if not rider then
		rider = CreateFrame("StatusBar", nil, lane)
		rider:SetStatusBarTexture(private.FILL)
		rider:SetStatusBarColor(0, 0, 0, 0)
		local tex = rider:GetStatusBarTexture()
		if tex then
			tex:SetAlpha(0)
		end
		rider:EnableMouse(false)
		ct.rider = rider
	end

	local vertical = s["vertical"] and true or false
	local reversed = s["reversed"] and true or false
	local len = math.max(s["width"] - s["icons"]["size"], 1)
	local anchor = "LEFT"
	if vertical then
		anchor = reversed and "TOP" or "BOTTOM"
	elseif reversed then
		anchor = "RIGHT"
	end

	if rider:GetParent() ~= lane or ct.riderAnchor ~= anchor or ct.riderLen ~= len or ct.riderVertical ~= vertical then
		rider:SetParent(lane)
		rider:ClearAllPoints()
		rider:SetPoint(anchor, lane, anchor, 0, 0)
		if vertical then
			rider:SetSize(1, len)
			rider:SetOrientation("VERTICAL")
		else
			rider:SetSize(len, 1)
			rider:SetOrientation("HORIZONTAL")
		end
		rider:SetReverseFill(reversed)
		ct.riderAnchor, ct.riderLen, ct.riderVertical = anchor, len, vertical
	end
	if not rider:IsShown() then
		rider:Show()
	end
	return rider
end

private.SetRiderValue = function(f, ct, rider, s, mode, max)
	if ct.kind == "buff" then
		-- curves can't take a hidden value from addon code: split lanes show buffs on a straight line
		local top = ct.feed.max
		if mode == "LINEAR_ABS" then
			top = s["mode"]["linearAbs"]["max"]
		elseif mode == "SPLIT_ABS" then
			top = s["mode"]["splitAbs"]["max"]
		end
		rider:SetMinMaxValues(0, top)
		rider:SetValue(ct.feed.value)
		return
	end

	local d = f.data
	local T = ct.dur
	if mode == "LINEAR_ABS" or (mode == "LINEAR" and d["baseCD"] > max) then
		rider:SetMinMaxValues(0, max)
		rider:SetValue(T:GetRemainingDuration())
	elseif mode == "LINEAR" then
		rider:SetMinMaxValues(0, T:GetTotalDuration())
		rider:SetValue(T:GetRemainingDuration())
	elseif mode == "SPLIT_ABS" then
		rider:SetMinMaxValues(0, 1)
		rider:SetValue(T:EvaluateRemainingDuration(private.SplitCurve(s, "abs")))
	elseif mode == "SPLIT" then
		local splitMax = s["mode"]["split"]["max"]
		rider:SetMinMaxValues(0, 1)
		if d["baseCD"] > splitMax then
			rider:SetValue(T:EvaluateRemainingDuration(private.SplitCurve(s, "sec", splitMax)))
		elseif T.EvaluateRemainingPercent then
			rider:SetValue(T:EvaluateRemainingPercent(private.SplitCurve(s, "pct")))
		else
			local total = d["baseCD"] > 0 and math.min(d["baseCD"], splitMax) or splitMax
			rider:SetValue(T:EvaluateRemainingDuration(private.SplitCurve(s, "sec", total)))
		end
	else
		error("unknown lane mode")
	end
end

private.PlaceIcon = function(f, ct, s, mode, max)
	local ic = f.icon
	local rider = private.Rider(ct, ic:GetParent(), s)
	private.SetRiderValue(f, ct, rider, s, mode, max)

	local anchor = ct.riderAnchor
	local x, y = 0, ic.yOffset + ic.sOffset
	if ct.riderVertical then
		x, y = y, 0
	end
	ic:ClearAllPoints()
	ic:SetPoint(anchor, rider:GetStatusBarTexture(), private.OPPOSITE[anchor], x, y)
	ct.anchored = true
end

-- from IconUpdate in place of its SetPoint block; false = place it the normal way
function CT:PlaceIcon(f, s, mode, max)
	local ct = f.ct
	if not (ct and ct.riding) then
		return false
	end
	local ok, err = pcall(private.PlaceIcon, f, ct, s, mode, max)
	if ok then
		return true
	end
	private.Fail(f, err)
	return false
end

-- BAR FRAMES: from BarUpdate in place of SetValue(iconPercent); false = set it the normal way
function CT:DriveBar(f)
	local ct = f.ct
	if not (ct and ct.riding) then
		return false
	end
	local ok, err = pcall(function()
		local bar = f.bar.bar
		ct.barDriven = true
		if ct.kind == "buff" then
			bar:SetMinMaxValues(0, ct.feed.max)
			bar:SetValue(ct.feed.value)
		else
			bar:SetMinMaxValues(0, ct.dur:GetTotalDuration())
			bar:SetValue(ct.dur:GetRemainingDuration())
		end
	end)
	if ok then
		return true
	end
	private.Fail(f, err)
	return false
end

-- COUNTDOWN TEXT
private.TimeOnly = function(text)
	return type(text) == "string" and text:match("^%s*(.-)%s*$") == "[cd.time]"
end

-- as close to CDTL3:GetReadableTime as the seconds formatter allows
private.Formatter = function()
	if private.formatter == nil then
		private.formatter = false
		if C_StringUtil and C_StringUtil.CreateSecondsFormatter then
			local ok, fmt = pcall(C_StringUtil.CreateSecondsFormatter)
			if ok and fmt then
				pcall(function() fmt:SetMinInterval(Enum.SecondsFormatterInterval.Seconds) end)
				pcall(function() fmt:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter) end)
				pcall(function() fmt:SetDesiredUnitCount(2) end)
				pcall(function() fmt:SetStripIntervalWhitespace(true) end)
				private.formatter = fmt
			end
		end
	end
	return private.formatter or nil
end

private.BindText = function(f, ct, tf)
	if ct.kind == "buff" then
		tf:SetFormattedText("%.0f", ct.feed.value)
		return
	end
	ct.bindings = ct.bindings or {}
	local b = ct.bindings[tf]
	if not b then
		local binding = C_DurationUtil.CreateDurationTextBinding()
		binding:SetFontString(tf)
		local fmt = private.Formatter()
		if fmt then
			binding:SetFormatter(fmt)
		end
		b = { binding = binding }
		ct.bindings[tf] = b
	end
	if not rawequal(b.dur, ct.dur) then
		b.binding:SetDuration(ct.dur)
		b.dur = ct.dur
	end
	if not b.on then
		b.binding:SetEnabled(true)
		b.on = true
	end
end

-- from UpdateText: true = the module owns this FontString this frame (a [cd.time]-only template)
function CT:OwnsText(f, tf, s)
	local ct = f.ct
	if not (ct and ct.riding and not ct.noText and tf and s and s["enabled"] and private.TimeOnly(s["text"])) then
		return false
	end
	local ok, err = pcall(private.BindText, f, ct, tf)
	if ok then
		return true
	end
	-- only the text falls back to the estimate; the icon and bar keep riding
	private.Error(err)
	ct.noText = true
	if ct.bindings then
		for _, b in pairs(ct.bindings) do
			if b.on then
				pcall(Method, b.binding, "SetEnabled", false)
			end
			b.on = false
			b.dur = nil
		end
	end
	return false
end

-- STACKING: GROUPED leaves riding icons out (their positions are hidden) and skips a pass when any
-- other position reads back hidden. Returns nil to skip.
function CT:GroupedChildren(list, count)
	local riding = false
	for _, c in ipairs(list) do
		if c.ctRiding then
			riding = true
			break
		end
	end

	local kids = list
	if riding then
		kids = {}
		for _, c in ipairs(list) do
			if c.ctRiding then
				c.stack = 1
				c.sOffset = 0
			else
				kids[#kids + 1] = c
			end
		end
	end

	if issecretvalue then
		for _, c in ipairs(kids) do
			local ok, x, y = pcall(Method, c, "GetCenter")
			if not ok or IsSecret(x) or IsSecret(y) then
				return nil
			end
		end
	end

	return kids, riding and #kids or count
end

-- COOLDOWN MANAGER
private.ViewerOn = function()
	if not (C_CooldownViewer and C_CooldownViewer.IsCooldownViewerAvailable) then
		return false
	end
	local ok, available = pcall(C_CooldownViewer.IsCooldownViewerAvailable)
	if not (ok and available == true) then
		return false
	end
	local okC, v = pcall(function()
		if C_CVar and C_CVar.GetCVar then
			return C_CVar.GetCVar("cooldownViewerEnabled")
		end
		return GetCVar("cooldownViewerEnabled")
	end)
	return (okC and v == "1") and true or false
end

-- cooldownID -> set of buff names (its spell and linked spells; static, never hidden)
private.NamesFor = function(cooldownID)
	local set = private.cooldownNames[cooldownID]
	if set then
		return set
	end
	set = {}
	local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
	if ok and type(info) == "table" then
		local function add(spellID)
			if not IsSecret(spellID) and type(spellID) == "number" then
				local name = private.SpellName(spellID)
				if name then
					set[name] = true
					set[1] = set[1] or name	-- the display name
				end
			end
		end
		add(info.spellID)
		if type(info.linkedSpellIDs) == "table" then
			for _, id in ipairs(info.linkedSpellIDs) do
				add(id)
			end
		end
	end
	if set[1] then
		private.cooldownNames[cooldownID] = set
	end
	return set
end

private.ItemCooldownID = function(item)
	local ok, id = pcall(Method, item, "GetCooldownID")
	if ok and not IsSecret(id) and type(id) == "number" then
		return id
	end
end

private.Items = function(viewer)
	local ok, items = pcall(Method, viewer, "GetItemFrames")
	if ok and type(items) == "table" then
		return items
	end
	local okC, list = pcall(function()
		return { viewer:GetChildren() }
	end)
	return okC and list or {}
end

-- in the hooks: keep what Blizzard's bar was given, never read or compare it
private.Store = function(bar, key, v)
	local m = private.mirror
	local item = m.hooked[bar]
	if not item then
		return
	end
	local now = GetTime()
	local rec = m.recs[item]
	if not rec then
		rec = { session = 0 }
		m.recs[item] = rec
	end
	if not private.Fresh(rec, now) then
		rec.session = rec.session + 1
		rec.start = now
	end
	rec[key] = v
	rec.time = now

	local id = private.ItemCooldownID(item)
	if not id then
		rec.cdID, rec.nameSet = nil, nil
		return
	end
	if rec.cdID ~= id then
		if rec.cdID then
			rec.session = rec.session + 1	-- a pooled bar now shows another buff
			rec.start = now
		end
		rec.cdID = id
		rec.nameSet = private.NamesFor(id)
		for name in pairs(rec.nameSet) do
			if type(name) == "string" then
				m.byName[name] = rec
			end
		end
	end
end

private.OnBarMinMax = function(bar, _, maxValue)
	if private.mirrorOn then
		pcall(private.Store, bar, "max", maxValue)
	end
end

private.OnBarValue = function(bar, value)
	if private.mirrorOn then
		pcall(private.Store, bar, "value", value)
	end
end

-- each bar instance is hooked once, ever
private.HookItem = function(item)
	local m = private.mirror
	local ok, bar = pcall(function()
		return item.Bar
	end)
	if not ok or type(bar) ~= "table" or m.hooked[bar] then
		return
	end
	m.hooked[bar] = item
	pcall(hooksecurefunc, bar, "SetMinMaxValues", private.OnBarMinMax)
	pcall(hooksecurefunc, bar, "SetValue", private.OnBarValue)
end

private.OnAcquire = function(_, item)
	pcall(private.HookItem, item)
end

private.HookMethod = function(viewer, method, fn)
	local ok, t = pcall(function()
		return type(viewer[method])
	end)
	return ok and t == "function" and pcall(hooksecurefunc, viewer, method, fn) or false
end

private.Install = function(viewer)
	local m = private.mirror
	if not m.acquireHooked then
		m.acquireHooked = private.HookMethod(viewer, "OnAcquireItemFrame", private.OnAcquire)
	end
	for _, item in ipairs(private.Items(viewer)) do
		private.HookItem(item)
	end
	private.installed = true
end

-- HIDE BLIZZARD'S TRACKED BARS (alpha only, out of combat: the one write to a Blizzard frame)
-- Blizzard's own opacity is remembered and put back, so none of its Edit Mode code is ever called.
private.SaveAlpha = function(viewer)
	local ok, a = pcall(Method, viewer, "GetAlpha")
	if ok and not IsSecret(a) and type(a) == "number" and a > 0 then
		private.savedAlpha = a
	end
end

-- after Blizzard re-applies its Edit Mode opacity
private.OnOpacity = function(viewer)
	if private.hidden then
		private.SaveAlpha(viewer)
		if InCombatLockdown() then
			private.hidden = false
			private.pendingHide = true
		else
			pcall(Method, viewer, "SetAlpha", 0)
		end
	end
end

private.ApplyHide = function()
	local viewer = _G["BuffBarCooldownViewer"]
	if not viewer then
		return
	end
	local m = private.mirror
	if not m.opacityHooked then
		m.opacityHooked = private.HookMethod(viewer, "UpdateSystemSettingOpacity", private.OnOpacity)
	end

	local cs = Settings()
	local want = (CT:Enabled() and cs and cs["hideBlizzardBars"]) and true or false
	if want == private.hidden then
		private.pendingHide = false
		return
	end
	if InCombatLockdown() then
		private.pendingHide = true
		return
	end
	private.pendingHide = false
	if want then
		private.SaveAlpha(viewer)
		private.hidden = true
		pcall(Method, viewer, "SetAlpha", 0)
	else
		private.hidden = false
		pcall(Method, viewer, "SetAlpha", private.savedAlpha or 1)
	end
end

private.RecheckMirror = function()
	private.lastRecheck = GetTime()
	local viewer = _G["BuffBarCooldownViewer"]
	local on = CT:Enabled() and viewer and private.ViewerOn()
	if on then
		private.Install(viewer)
	end
	private.mirrorOn = (on and private.installed) and true or false
	private.ApplyHide()
end

-- a fresh feed for a buff that isn't on a lane or bar frame starts it (in combat)
private.StartBuffs = function()
	if not (private.mirrorOn and CT:Enabled() and CDTL3:AurasAreSecret()) then
		return
	end
	local g = CDTL3.db.profile.global
	if not (g["buffs"] and g["buffs"]["enabled"]) then
		return
	end
	local now = GetTime()
	for _, f in ipairs(CDTL3.cooldowns) do
		local d = f.data
		if d and d["type"] == "buffs" and d["enabled"] and not d["ignored"] and (d["baseCD"] or 0) > 0 then
			local rec = private.FeedFor(d["name"])
			if rec then
				local ct = f.ct
				if not ct then
					ct = {}
					f.ct = ct
				end
				if ct.startedRec ~= rec or ct.startedSession ~= rec.session then
					ct.startedRec, ct.startedSession = rec, rec.session
					if not (private.OnLane(f) or private.OnBarFrame(f)) then
						CDTL3:SendToLane(f)
						CDTL3:SendToBarFrame(f)
						d["currentCD"] = d["baseCD"]
					end
				end
			end
		end
	end
end

-- current Tracked Bars: display names, and a set of every name (linked spells too)
private.TrackedBars = function()
	local list, all, seen = {}, {}, {}
	local function add(cooldownID)
		if not cooldownID or seen[cooldownID] then
			return
		end
		seen[cooldownID] = true
		local set = private.NamesFor(cooldownID)
		if set[1] then
			list[#list + 1] = set[1]
			for name in pairs(set) do
				if type(name) == "string" then
					all[name] = true
				end
			end
		end
	end
	local viewer = _G["BuffBarCooldownViewer"]
	if viewer then
		for _, item in ipairs(private.Items(viewer)) do
			add(private.ItemCooldownID(item))
		end
	end
	-- the saved Tracked Bars list too: an inactive buff's bar may not be laid out
	if C_CooldownViewer.GetCooldownViewerCategorySet then
		local cat = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBar or 3
		local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, cat)
		if ok and type(ids) == "table" then
			for _, id in ipairs(ids) do
				if not IsSecret(id) and type(id) == "number" then
					add(id)
				end
			end
		end
	end
	return list, all
end

function CT:BuffInTrackedBars(name)
	if not CT:Available() or type(name) ~= "string" or not private.ViewerOn() then
		return nil
	end
	local ok, _, all = pcall(private.TrackedBars)
	if not ok then
		return nil
	end
	return all[name] and true or false
end

-- SETTINGS
function CT:SetEnabled(on)
	local cs = Settings()
	if not cs then
		return
	end
	cs["enabled"] = on and true or false
	if not cs["enabled"] then
		for _, f in ipairs(CDTL3.cooldowns or {}) do
			if f.ct and f.ct.riding then
				pcall(private.Leave, f, true)
			end
		end
	end
	if CT:Available() then
		local ok, err = pcall(private.RecheckMirror)
		if not ok then
			private.Error(err)
		end
	end
end

function CT:SetHideBlizzardBars(on)
	local cs = Settings()
	if not cs then
		return
	end
	cs["hideBlizzardBars"] = on and true or false
	if CT:Available() then
		local ok, err = pcall(private.ApplyHide)
		if not ok then
			private.Error(err)
		end
	end
end

local function Plural(n, word)
	return n .. " " .. word .. (n == 1 and "" or "s")
end

function CT:StatusLine()
	if not CT:Available() then
		return "Combat timers: not available on this client"
	end
	local spells, buffs = 0, 0
	for _, f in ipairs(CDTL3.cooldowns or {}) do
		if f.ct and f.ct.riding then
			if f.ct.kind == "buff" then
				buffs = buffs + 1
			else
				spells = spells + 1
			end
		end
	end
	local parts = {
		"Combat timers: " .. (CT:Enabled() and "on (experimental)" or "off"),
		"riding: " .. Plural(spells, "spell") .. ", " .. Plural(buffs, "buff"),
	}
	local cdm = private.ViewerOn()
	parts[#parts + 1] = "Cooldown Manager: " .. (cdm and "on" or "off")
	if cdm then
		local ok, list = pcall(private.TrackedBars)
		parts[#parts + 1] = "Tracked Bars: " .. ((ok and #list > 0) and table.concat(list, ", ") or "none")
		if _G["BuffBarCooldownViewer"] then
			parts[#parts + 1] = "Blizzard's Tracked Bars: " .. (private.hidden and "hidden" or "shown")
		end
	end
	if private.errors > 0 then
		parts[#parts + 1] = "errors: " .. private.errors
	end
	return table.concat(parts, " | ")
end

-- EVENTS
private.ReadRiding = function()
	for _, f in ipairs(CDTL3.cooldowns or {}) do
		local ct = f.ct
		if ct and ct.riding and ct.kind == "spell" then
			private.ReadActive(ct, f.data["id"], true)
		end
	end
end

private.OnEvent = function(event)
	if event == "SPELL_UPDATE_COOLDOWN" then
		private.gen = private.gen + 1
		private.ReadRiding()
	elseif event == "SPELL_UPDATE_CHARGES" or event == "PLAYER_REGEN_DISABLED" then
		private.gen = private.gen + 1
	elseif event == "PLAYER_REGEN_ENABLED" then
		private.gen = private.gen + 1
		for _, f in ipairs(CDTL3.cooldowns or {}) do
			if f.ct then
				f.ct.broken = nil
				f.ct.noText = nil
			end
		end
		private.RecheckMirror()
		private.Prewarm()
	elseif event == "CVAR_UPDATE" then
		private.RecheckMirror()
	elseif event == "PLAYER_ENTERING_WORLD" then
		private.RecheckMirror()
		private.Prewarm()
	end
end

private.OnUpdate = function(elapsed)
	-- the time of the last frame seen, for private.Fresh
	local now = GetTime()
	if now ~= private.thisFrame then
		private.prevFrame = private.thisFrame
		private.thisFrame = now
	end

	private.tick = (private.tick or 0) + elapsed
	if private.tick < private.TICK then
		return
	end
	private.tick = 0
	if not CDTL3.db then
		return
	end
	private.StartBuffs()
	if not InCombatLockdown() then
		if private.pendingHide then
			private.ApplyHide()
		end
		if not private.installed and GetTime() - (private.lastRecheck or 0) >= private.RECHECK then
			private.RecheckMirror()
		end
	end
end

if CT:Available() then
	local ef = CreateFrame("Frame")
	ef:SetScript("OnEvent", function(_, event)
		if not CDTL3.db then
			return
		end
		local ok, err = pcall(private.OnEvent, event)
		if not ok then
			private.Error(err)
		end
	end)
	ef:SetScript("OnUpdate", function(_, elapsed)
		local ok, err = pcall(private.OnUpdate, elapsed)
		if not ok then
			private.Error(err)
		end
	end)
	for _, event in ipairs(private.EVENTS) do
		pcall(ef.RegisterEvent, ef, event)
	end
	private.eventFrame = ef
end

-- for tools/tests only
CT.internal = private
