-- Copied-code cleanup (17 Nov 2026): the shared pieces that replaced copies keep doing what the copies did.
--   Paladin lockouts (Detect Shared CD): one cast puts the other protections on 120 s and Avenging Wrath on 30 s,
--     and Avenging Wrath puts the four protections on 30 s (entries built from the data on the first cast;
--     a second cast changes nothing)
--   IconFx Ring / RingShow (also used by Group.lua's Burst strip, which defaults to the BACKGROUND layer)
--   the debug and unlock boxes' dark panel
-- Prints each state line so the same file can be run on the old tree and the outputs diffed.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end
-- remember the layer each texture was made on
do
	local mt = getmetatable(UIParent)
	local oldIndex = mt.__index
	mt.__index = function(t, k)
		if k == "CreateTexture" then
			return function(self, name, layer)
				local c = MOCK_NEW("Texture", name, self)
				rawset(c, "__layer", layer)
				return c
			end
		end
		return oldIndex(t, k)
	end
end
LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local g = CDTL3.db.profile.global

---------------------------------------------------------------- rings
print("[rings " .. FLAVOR .. "]")
local FX = CDTL3.IconFx
local host = CreateFrame("Frame", nil, UIParent)
local r1 = FX.Ring(host, 3, 0, 0, 0, 1)
check("IconFx.Ring: four bars on OVERLAY by default", #r1 == 4 and r1[1].__layer == "OVERLAY" and r1[4].__layer == "OVERLAY")
local r2 = FX.Ring(host, 5, 1, 1, 1, 1, "ARTWORK")
check("IconFx.Ring: a given layer is used", r2[1].__layer == "ARTWORK" and r2[3].__layer == "ARTWORK")
check("IconFx.Ring: top bar anchors above the frame, left bar beside it",
	r1[1].__points[1][1] == "BOTTOMLEFT" and r1[1].__points[1][4] == -3 and r1[3].__points[1][1] == "TOPRIGHT" and r1[1].__h == 3 and r1[3].__w == 3)
FX.RingShow(r1, false)
check("IconFx.RingShow hides all four", not r1[1].__shown and not r1[2].__shown and not r1[3].__shown and not r1[4].__shown)
FX.RingShow(r1, true)
check("IconFx.RingShow shows all four", r1[1].__shown and r1[2].__shown and r1[3].__shown and r1[4].__shown)

local filterDefaults = CDTL3:GetFilterOptions().args.defaults.args
if filterDefaults.burstStrip then
	filterDefaults.burstStrip.set({}, true)
	local st = CDTL3_BurstStrip
	local s1 = st and st.slots and st.slots[1]
	check("Burst strip: shadow bars on BACKGROUND", st and st.shadow and #st.shadow == 4 and st.shadow[1].__layer == "BACKGROUND")
	check("Burst strip: slot edge on BACKGROUND, glow and ring hidden until a proc",
		s1 and s1.edge and s1.edge[2].__layer == "BACKGROUND" and s1.glow and s1.ring and not s1.glow[1].__shown and not s1.ring[1].__shown)
	filterDefaults.burstStrip.set({}, false)
end

---------------------------------------------------------------- dark panel of the debug and unlock boxes
print("[panels " .. FLAVOR .. "]")
local u = CDTL3.unlockFrame
check("unlock box: dark panel texture on BACKGROUND", u and u.bg and u.bg.__layer == "BACKGROUND" and u.bg.__otype == "Texture")
local dbg = CDTL3.debugFrame
check("debug box: dark panel texture on BACKGROUND", dbg and dbg.bg and dbg.bg.__layer == "BACKGROUND")

---------------------------------------------------------------- paladin lockouts
print("[lockouts " .. FLAVOR .. "]")
local function lines()
	local out = {}
	for _, cd in ipairs(CDTL3.cooldowns) do
		if cd.data and cd.data.type == "spells" then
			out[#out + 1] = string.format("%s cd=%s override=%s", tostring(cd.data.name), tostring(cd.data.currentCD), tostring(cd.data.overrideCD))
		end
	end
	table.sort(out)
	return out
end
local function drop()
	for _, f in pairs(CDTL3.cooldowns) do CDTL3:SendToHolding(f); CDTL3:SendToBarHolding(f) end
	for k in pairs(CDTL3.cooldowns) do CDTL3.cooldowns[k] = nil end
end
local function clearSaved() local t = CDTL3.db.profile.tables.spells; for k in pairs(t) do t[k] = nil end end
PLAYER.class, PLAYER.race = "PALADIN", "Human"
CDTL3.player = { guid = PLAYER.guid }
CDTL3:GetCharacterData()
g.detectSharedCD = true
for _, s in ipairs(CDTL3:GetAllSpellData("PALADIN", "Human")) do
	SPELLINFO[s.id] = SPELLINFO[s.id] or { s.name, 135000 }
	BASECD[s.id] = s.bCD
end
local PROT = { "Divine Protection", "Divine Shield", "Hand of Protection", "Lay on Hands", "Avenging Wrath" }
local e0 = #ERRORS
for _, cast in ipairs({ "Divine Shield", "Avenging Wrath" }) do
	clearSaved()
	drop()
	local e1 = #ERRORS
	xpcall(function() CDTL3:CheckEdgeCases(cast) end, ERRH)
	local got = lines()
	print("  after " .. cast .. " (first): " .. table.concat(got, " | "))
	xpcall(function() CDTL3:CheckEdgeCases(cast) end, ERRH)
	local again = lines()
	print("  after " .. cast .. " (again): " .. table.concat(again, " | "))
	check(cast .. ": no Lua errors", #ERRORS == e1)
	check(cast .. ": a second cast changes nothing", table.concat(got, "|") == table.concat(again, "|"))
	if #got > 0 then
		for _, n in ipairs(PROT) do
			local hit
			for _, l in ipairs(got) do
				if l:sub(1, #n + 4) == n .. " cd=" then hit = l end
			end
			if n == cast then
				check(cast .. ": not locked by itself", hit == nil)
			elseif hit then
				local expect = (cast == "Avenging Wrath" or n == "Avenging Wrath") and 30 or 120
				check(cast .. " -> " .. n .. " locked " .. expect .. " s", hit:find("cd=" .. expect .. " override=true", 1, true) ~= nil, hit)
			end
		end
	else
		print("  (" .. cast .. ": this client's data builds no lockout entries)")
	end
end
g.detectSharedCD = false
clearSaved()
drop()
check("lockouts: no Lua errors", #ERRORS == e0)

print(string.format("RESULT dedupe %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
