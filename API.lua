-- CDTL3 public messages and read-only API, for other addons and WeakAuras. See docs/EXTENDING.md.
--
-- Messages (AceEvent / CallbackHandler, sent by CDTL3:SendMessage; listen with RegisterMessage):
--   CDTL3_TimerStarted, CDTL3_TimerReady, CDTL3_TimerEnded, each with one table of plain data:
--   { type, id, name, icon, duration, expires, estimated }
-- API: CDTL3.API.GetTimers / GetTimer / IsReady / GetLane, each returning fresh copies.
--
-- Where the game hides a value (Retail and Forever in combat) duration and expires are nil. Nothing
-- here ever hands out, compares or does maths on a hidden value: the numbers come from CDTL3's own
-- timer, which a riding timer (CombatTimers.lua) does not keep, so those are left out.
local CDTL3 = CDTL3
local private = {}

local API = { version = 1 }
CDTL3.API = API

-- timers that are only scaffolding
local SKIP = { testing = true, test = true, spacer = true }

local function IsSecret(v)
	if not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, v)
	return ok and secret == true
end

-- are this timer's times hidden from us right now
private.Hidden = function(f)
	local d = f.data
	if f.ct and f.ct.riding then
		return true
	end
	if d["itemUnread"] then
		return true
	end
	-- a spell cast in combat where combat timers run is about to ride: its times are hidden too
	local CT = CDTL3.CombatTimers
	if CT and (d["type"] == "spells" or d["type"] == "petspells") and InCombatLockdown and InCombatLockdown() then
		local ok, on = pcall(CT.Enabled, CT)
		if ok and on then
			return true
		end
	end
	return false
end

private.Estimated = function(f)
	local d = f.data
	if d["estimated"] then
		return true
	end
	local CT = CDTL3.CombatTimers
	if CT then
		local ok, est = pcall(CT.Estimated, CT, f)
		if ok and est then
			return true
		end
	end
	return false
end

-- seconds left (a number or nil), inside a pcall like every other read of a timer value
private.Remaining = function(f)
	local ok, left = pcall(function()
		local cd = f.data["currentCD"]
		if type(cd) ~= "number" or IsSecret(cd) or cd ~= cd then
			return nil
		end
		return cd
	end)
	return ok and left or nil
end

private.Counting = function(f)
	local left = private.Remaining(f)
	if not left then
		return false
	end
	local ok, counting = pcall(function() return left > 0 end)
	return ok and counting or false
end

-- a fresh table of plain data for one timer; withState adds lane and ready (API only)
private.Snapshot = function(f, withState)
	local d = f.data
	local t = {
		type = d["type"],
		id = d["id"],
		name = d["name"],
		icon = (d["type"] == "items" and d["itemIcon"]) or d["icon"],
		estimated = private.Estimated(f),
	}
	if not private.Hidden(f) then
		local left = private.Remaining(f)
		if left then
			local ok, expires, duration = pcall(function()
				local base = d["baseCD"]
				if type(base) ~= "number" or IsSecret(base) or base ~= base or base <= 0 then
					base = nil
				end
				return GetTime() + math.max(left, 0), base
			end)
			if ok then
				t.expires = expires
				t.duration = duration
			end
		end
	end
	if withState then
		t.lane = d["lane"]
		t.ready = not private.Counting(f)
	end
	return t
end

-- a timer the player sees: not ignored, not switched off, not scaffolding
private.Tracked = function(f)
	local d = f and f.data
	return d and not SKIP[d["type"] or ""] and d["enabled"] and not d["ignored"] and true or false
end

-- Sent from Cooldown.lua. A broken listener must never reach the update loop.
function CDTL3:FireTimer(message, f)
	if not private.Tracked(f) then
		return
	end
	if message == "CDTL3_TimerStarted" and CDTL3.movingLane then
		return	-- MoveToLane keeps the countdown: a move is not a start
	end
	pcall(function()
		CDTL3:SendMessage(message, private.Snapshot(f, false))
	end)
end

-- After SendToReady: a timer that found no Ready frame to wait in is over at once
local READY_FRAMES = { CDTL3_Ready_1_MF = true, CDTL3_Ready_2_MF = true, CDTL3_Ready_3_MF = true }
function CDTL3:FireTimerIfHeld(f)
	local ok, parent = pcall(function() return f.icon:GetParent():GetName() end)
	if ok and not READY_FRAMES[parent or ""] then
		CDTL3:FireTimer("CDTL3_TimerEnded", f)
	end
end

-- GetTimers(): every running timer
function API.GetTimers()
	local out = {}
	for _, f in ipairs(CDTL3.cooldowns or {}) do
		if private.Tracked(f) and private.Counting(f) then
			out[#out + 1] = private.Snapshot(f, true)
		end
	end
	return out
end

-- the cooldown frame for an entry: a running one first, else any
private.Find = function(cdType, id)
	local found
	for _, f in ipairs(CDTL3.cooldowns or {}) do
		local d = f.data
		if d and d["type"] == cdType and d["id"] == id and private.Tracked(f) then
			if private.Counting(f) then
				return f
			end
			found = found or f
		end
	end
	return found
end

-- GetTimer(type, id): one timer (running or ready), or nil when CDTL3 does not track it
function API.GetTimer(cdType, id)
	local f = private.Find(cdType, id)
	return f and private.Snapshot(f, true) or nil
end

-- IsReady(type, id): true or false, or nil when CDTL3 does not track it
function API.IsReady(cdType, id)
	local f = private.Find(cdType, id)
	if not f then
		return nil
	end
	return not private.Counting(f)
end

-- GetLane(name or number): { number, name, enabled, timers = { running timers on it } }, or nil
function API.GetLane(which)
	local lanes = CDTL3.db and CDTL3.db.profile and CDTL3.db.profile.lanes
	if not lanes then
		return nil
	end
	local n
	if type(which) == "number" then
		n = which
	elseif type(which) == "string" then
		n = tonumber(which)
		if not n then
			local want = which:lower()
			for i = 1, 3 do
				local s = lanes["lane" .. i]
				if s and type(s["name"]) == "string" and s["name"]:lower() == want then
					n = i
					break
				end
			end
		end
	end
	local s = n and lanes["lane" .. n]
	if not s then
		return nil
	end
	local out = { number = n, name = s["name"], enabled = s["enabled"] and true or false, timers = {} }
	for _, f in ipairs(CDTL3.cooldowns or {}) do
		if f.data and f.data["lane"] == n and private.Tracked(f) and private.Counting(f) then
			out.timers[#out.timers + 1] = private.Snapshot(f, true)
		end
	end
	return out
end
