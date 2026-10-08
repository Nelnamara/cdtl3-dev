--[[
	Cooldown Timeline 3 - secret timer spike (/cdtl3 secrettest)

	Phase 0 of docs/secret-timers-scope.md. Not a feature: a test panel that answers, in-game,
	whether CDTL3 can keep timers moving while the game hides cooldown values:
	  Q1  does an icon anchored to a StatusBar's fill edge move when the bar is fed a secret?
	  Q2  does a curve result (for split lanes) feed StatusBar:SetValue?
	  Q3  are the duration objects live, or snapshots that must be re-fetched?
	  Q4  does the duration carry the real (talented) cooldown, not the base one?

	Rows on the panel (each icon rides its own bar's fill edge):
	  A  SetMinMaxValues(0, max) + SetValue(dur:GetRemainingDuration())   (linear, absolute)
	  B  SetTimerDuration(dur, Immediate, RemainingTime)                   (linear, own CD)
	  C  SetValue(dur:EvaluateRemainingDuration(curve))                     (split lane)
	  D  text binding + cooldown swipe from the same duration

	Every call goes through pcall; the first error of each step is kept for the report.
]]--

local private = {}

private.errors = {}
private.SPLIT = { { 0, 0 }, { 10, 0.33 }, { 30, 0.66 } }	-- seconds -> lane fraction, then max -> 1

local function Try(key, fn, ...)
	local ok, a, b = pcall(fn, ...)
	if not ok and not private.errors[key] then
		private.errors[key] = tostring(a)
	end
	return ok, a, b
end

-- Printable form of a value that may be secret (never compares or formats a secret)
local function Show(v)
	if v == nil then
		return "nil"
	end

	if issecretvalue then
		local ok, secret = pcall(issecretvalue, v)
		if ok and secret then
			return "|cffff8800SECRET|r"
		end
	end

	local ok, s = pcall(function()
		if type(v) == "number" then
			return string.format("%.1f", v)
		end
		return tostring(v)
	end)

	return ok and s or "|cffff8800unreadable|r"
end

local function Supported()
	return C_DurationUtil and C_Spell and C_Spell.GetSpellCooldownDuration and C_CurveUtil and true
end

-- PANEL
private.CreateRow = function(p, index, label)
	local row = {}
	local y = -26 - (index - 1) * 30

	row.label = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.label:SetPoint("TOPLEFT", 8, y - 4)
	row.label:SetText(label)

	row.bar = CreateFrame("StatusBar", nil, p)
	row.bar:SetSize(300, 18)
	row.bar:SetPoint("TOPLEFT", 120, y)
	row.bar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
	row.bar:GetStatusBarTexture():SetVertexColor(0.2, 0.6, 1, 0.35)
	row.bar:SetMinMaxValues(0, 1)
	row.bar:SetValue(0)

	row.bg = row.bar:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.bg:SetColorTexture(1, 1, 1, 0.08)

	-- the question: does this ride the fill edge when the value is secret?
	row.icon = row.bar:CreateTexture(nil, "OVERLAY")
	row.icon:SetSize(22, 22)
	row.icon:SetPoint("CENTER", row.bar:GetStatusBarTexture(), "RIGHT", 0, 0)

	return row
end

private.CreatePanel = function()
	local p = CreateFrame("Frame", "CDTL3_SecretTest", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	p:SetSize(440, 170)
	p:SetPoint("CENTER", 0, 200)
	p:SetFrameStrata("HIGH")
	if p.SetBackdrop then
		p:SetBackdrop({ bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		p:SetBackdropColor(0, 0, 0, 0.75)
	end
	p:SetMovable(true)
	p:EnableMouse(true)
	p:RegisterForDrag("LeftButton")
	p:SetScript("OnDragStart", p.StartMoving)
	p:SetScript("OnDragStop", p.StopMovingOrSizing)

	p.title = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	p.title:SetPoint("TOPLEFT", 8, -8)

	p.rows = {
		private.CreateRow(p, 1, "A  SetValue"),
		private.CreateRow(p, 2, "B  SetTimerDuration"),
		private.CreateRow(p, 3, "C  curve (split)"),
	}

	-- row D: native countdown text + swipe
	p.dLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	p.dLabel:SetPoint("TOPLEFT", 8, -120)
	p.dLabel:SetText("D  text + swipe")

	p.dIconFrame = CreateFrame("Frame", nil, p)
	p.dIconFrame:SetSize(26, 26)
	p.dIconFrame:SetPoint("TOPLEFT", 120, -114)
	p.dIcon = p.dIconFrame:CreateTexture(nil, "ARTWORK")
	p.dIcon:SetAllPoints()
	p.dCooldown = CreateFrame("Cooldown", nil, p.dIconFrame, "CooldownFrameTemplate")
	p.dCooldown:SetAllPoints()

	p.dText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	p.dText:SetPoint("LEFT", p.dIconFrame, "RIGHT", 10, 0)

	p.status = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	p.status:SetPoint("BOTTOMLEFT", 8, 8)
	p.status:SetJustifyH("LEFT")

	p:SetScript("OnEvent", function(_, event)
		if event == "SPELL_UPDATE_COOLDOWN" then
			private.Rebind()
		elseif event == "PLAYER_REGEN_DISABLED" then
			C_Timer.After(3, function() private.Report("3s into combat") end)
		else
			private.Report("combat ended")
		end
	end)

	return p
end

private.Start = function(p)
	p.elapsed = 0
	p:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	p:RegisterEvent("PLAYER_REGEN_DISABLED")
	p:RegisterEvent("PLAYER_REGEN_ENABLED")
	p:SetScript("OnUpdate", function(_, elapsed)
		private.Update(elapsed)
	end)
	p:Show()
end

-- DRIVING THE ROWS
private.Fetch = function()
	local ok, dur = Try("fetch GetSpellCooldownDuration", C_Spell.GetSpellCooldownDuration, private.spellID, true)
	if ok and dur then
		return dur
	end
end

private.IsActive = function()
	local ok, active = Try("GetSpellCooldown.isActive", function()
		local info = C_Spell.GetSpellCooldown(private.spellID)
		return info and info.isActive
	end)
	-- isActive is documented never-secret; if it isn't a plain boolean we'll see it in the report
	return ok and active == true
end

-- (Re)attach the duration to the native consumers: timer bar (B), text binding and swipe (D)
private.Rebind = function()
	local p = private.panel
	local dur = private.Fetch()
	if not (p and dur) then
		return
	end
	private.dur = dur

	if private.IsActive() then
		if not private.firstDur then
			private.firstDur = dur		-- Q3: keep the cast-time object to compare later
		end
	else
		private.firstDur = nil
	end

	Try("B SetTimerDuration", function()
		p.rows[2].bar:SetTimerDuration(dur, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
	end)

	Try("D text binding", function()
		if not private.binding then
			private.binding = C_DurationUtil.CreateDurationTextBinding()
			private.binding:SetFontString(p.dText)
			private.binding:SetFormatter(C_StringUtil.CreateSecondsFormatter())
		end
		private.binding:SetDuration(dur)
		private.binding:SetEnabled(true)
	end)

	Try("D cooldown swipe", function()
		p.dCooldown:SetCooldownFromDurationObject(dur)
	end)
end

private.Update = function(elapsed)
	local p = private.panel
	local dur = private.Fetch()
	if dur then
		private.dur = dur

		Try("A SetValue(remaining)", function()
			p.rows[1].bar:SetValue(dur:GetRemainingDuration())
		end)

		Try("C SetValue(curve result)", function()
			p.rows[3].bar:SetValue(dur:EvaluateRemainingDuration(private.curve))
		end)
	end

	-- refresh the native consumers twice a second too, in case events miss a change
	p.elapsed = p.elapsed + elapsed
	if p.elapsed > 0.5 then
		p.elapsed = 0
		private.Rebind()

		local restricted = "?"
		if C_Secrets and C_Secrets.ShouldCooldownsBeSecret then
			local ok, r = pcall(C_Secrets.ShouldCooldownsBeSecret)
			restricted = ok and Show(r) or "error"
		end
		local x = select(2, pcall(function() return (p.rows[1].icon:GetCenter()) end))
		p.status:SetText("cooldowns secret: "..restricted.."   duration: "..(dur and Show(dur:GetRemainingDuration()) or "none").."   icon A x: "..Show(x))
	end
end

-- REPORT
private.Report = function(when)
	local P = function(...) CDTL3:Print(...) end
	local dur = private.dur
	P("|cff00ccffSecret timer test|r - "..(when or "report").." - "..tostring(private.spellName).." ("..tostring(private.spellID)..")")

	local base = GetSpellBaseCooldown and select(2, pcall(GetSpellBaseCooldown, private.spellID))
	P("  client "..tostring(CDTL3.tocversion)..(CDTL3.isForever and " (Forever)" or "").." | base cooldown (ms): "..Show(base))

	if C_Secrets then
		local function Q(name, ...)
			if not C_Secrets[name] then
				return "n/a"
			end
			local ok, r = pcall(C_Secrets[name], ...)
			return ok and Show(r) or "error"
		end
		P("  cooldowns secret now: "..Q("ShouldCooldownsBeSecret").." | this spell: "..Q("ShouldSpellCooldownBeSecret", private.spellID).." | secrecy level: "..Q("GetSpellCooldownSecrecy", private.spellID))
	end

	local ok, active, onGCD = pcall(function()
		local info = C_Spell.GetSpellCooldown(private.spellID)
		return info and info.isActive, info and info.isOnGCD
	end)
	P("  isActive: "..(ok and Show(active) or "error").." | isOnGCD: "..(ok and Show(onGCD) or "error"))

	if dur then
		local hs = select(2, pcall(dur.HasSecretValues, dur))
		P("  duration: remaining "..Show(select(2, pcall(dur.GetRemainingDuration, dur)))
			.." | total "..Show(select(2, pcall(dur.GetTotalDuration, dur)))
			.." | holds secrets: "..Show(hs).."   (Q4: total vs base cooldown)")

		local cOK, cRes = pcall(dur.EvaluateRemainingDuration, dur, private.curve)
		P("  Q2 curve result: "..(cOK and (type(cRes).." "..Show(cRes)) or ("error: "..tostring(cRes))))

		if private.firstDur then
			P("  Q3 object from the cast: remaining "..Show(select(2, pcall(private.firstDur.GetRemainingDuration, private.firstDur)))
				.." | same object as now: "..tostring(private.firstDur == dur))
		end
	else
		P("  duration: none returned")
	end

	local panel = private.panel
	local x = select(2, pcall(function() return (panel.rows[1].icon:GetCenter()) end))
	P("  Q1 icon A position: "..Show(x).."   (SECRET here means it rides a secret - watch whether it MOVES)")

	local any = false
	for step, err in pairs(private.errors) do
		any = true
		P("  |cffff4444error|r "..step..": "..err)
	end
	if not any then
		P("  no errors so far")
	end
end

-- COMMAND: /cdtl3 secrettest <spell name or id> [lane max seconds] | report | stop
function CDTL3:SecretTest(args)
	args = (args or ""):trim()

	if not Supported() then
		CDTL3:Print("The secret timer test needs Retail (Midnight) or WoW: Forever.")
		return
	end

	if args == "stop" then
		if private.panel then
			private.panel:Hide()
			private.panel:SetScript("OnUpdate", nil)
			private.panel:UnregisterAllEvents()
			if private.binding then
				pcall(private.binding.SetEnabled, private.binding, false)
			end
			private.panel = nil
		end
		CDTL3:Print("Secret timer test stopped.")
		return
	elseif args == "report" then
		if private.panel then
			private.Report()
		else
			CDTL3:Print("Start the test first: /cdtl3 secrettest <spell name or id>")
		end
		return
	elseif args == "" then
		CDTL3:Print("Usage: /cdtl3 secrettest <spell name or id> [lane max seconds]   then /cdtl3 secrettest report, /cdtl3 secrettest stop")
		return
	end

	local spellArg, maxArg = args:match("^(.-)%s+(%d+)$")
	spellArg = spellArg or args
	local spell = tonumber(spellArg) or spellArg

	local ok, info = pcall(C_Spell.GetSpellInfo, spell)
	if not (ok and info and info.spellID) then
		CDTL3:Print("Spell not found: "..tostring(spellArg).." (use a spell you know, by name or ID)")
		return
	end

	if private.panel then
		CDTL3:SecretTest("stop")
	end

	private.spellID = info.spellID
	private.spellName = info.name
	private.errors = {}
	private.firstDur = nil
	private.dur = nil
	private.max = tonumber(maxArg) or 120

	private.curve = C_CurveUtil.CreateCurve()
	Try("curve setup", function()
		private.curve:SetType(Enum.LuaCurveType.Linear)
		for _, pt in ipairs(private.SPLIT) do
			private.curve:AddPoint(pt[1], pt[2])
		end
		private.curve:AddPoint(private.max, 1)
	end)

	private.frame = private.frame or private.CreatePanel()
	local p = private.frame
	private.panel = p
	p.title:SetText("CDTL3 secret timer test: "..info.name.."  (lane max "..private.max.."s)")
	p.rows[1].bar:SetMinMaxValues(0, private.max)
	for _, row in ipairs(p.rows) do
		row.icon:SetTexture(info.iconID)
	end
	p.dIcon:SetTexture(info.iconID)
	private.Start(p)

	private.Rebind()
	CDTL3:Print("Secret timer test started for "..info.name..". Cast it out of combat, then again in combat (a target dummy is ideal). A report prints 3s into combat and when combat ends; /cdtl3 secrettest report any time, /cdtl3 secrettest stop to close.")
end
