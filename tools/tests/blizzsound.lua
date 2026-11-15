-- Blizzard sounds in their own menu: every sound picker is two menus (the main one without the
-- "Blizzard: " sounds, and "Blizzard sound" beside it) on the same saved setting; the Play sound
-- buttons are wide enough to read. Real files, real AceDB.
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)
local base = #ERRORS
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, (tostring(detail or ""):gsub("\n", " / "))))
end
local played = {}
PlaySoundFile = function(path) played[#played + 1] = path; return true end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function isB(k) return k:sub(1, 10) == "Blizzard: " end
local function list(opt, info)
	local v = opt.values
	if type(v) == "function" then v = v(info) end
	return v
end
local function text(v, info)
	if type(v) == "function" then return v(info) end
	return v
end

local opts = CDTL3:GetFullOptions()
local pickers = {}
local function walk(group, path, seen)
	if seen[group] or type(group.args) ~= "table" then return end
	seen[group] = true
	for k, o in pairs(group.args) do
		if type(o) == "table" then
			if o.type == "select" and o.dialogControl == "LSM30_Sound" and k:sub(-8) ~= "Blizzard" then
				pickers[#pickers + 1] = { path = path .. "." .. k, main = o, blz = group.args[k .. "Blizzard"] }
			elseif o.type == "group" then
				walk(o, path .. "." .. k, seen)
			end
		end
	end
end
walk(opts, "root", {})

print("[blizzard sound menus " .. FLAVOR .. "]")
local info = {}
local nB = 0
for name in pairs(AceGUIWidgetLSMlists.sound) do if isB(name) then nB = nB + 1 end end
check("the game's sounds are registered (28)", nB == 28, nB)
check("sound pickers found in the tree (Ready 1 Normal and Highlight, Simple at least)", #pickers >= 3, #pickers)
for _, p in ipairs(pickers) do
	local m, b = p.main, p.blz
	check(p.path .. ": a Blizzard sound menu next to it", b and text(b.name, info) == "Blizzard sound" and b.dialogControl == "LSM30_Sound" and b.type == "select")
	if b then
		check("  placed right after it", b.order > m.order and b.order < m.order + 1, tostring(m.order) .. " -> " .. tostring(b.order))
		local ml, bl = list(m, info), list(b, info)
		local mB, bN = 0, 0
		for k in pairs(ml) do if isB(k) then mB = mB + 1 end end
		for k in pairs(bl) do if not isB(k) then bN = bN + 1 end end
		check("  main menu holds no Blizzard entry, and keeps None", mB == 0 and ml["None"] ~= nil and ml["CDTL3 Click"] ~= nil)
		check("  Blizzard menu holds exactly the 28", bN == 0 and count(bl) == 28, count(bl))
		check("  same hidden and disabled as the main menu", type(b.hidden) == type(m.hidden) and type(b.disabled) == type(m.disabled))
	end
end

local function ready1() return CDTL3.db.profile.ready.ready1 end
local g = opts.args.ready.args.ready1.args.general.args
local m, b = g.nSound, g.nSoundBlizzard
check("the lists are made when read (a sound registered later shows up)", (function()
	-- the lists table is LibSharedMedia's own, filled live as other addons register
	AceGUIWidgetLSMlists.sound["Zzz Late Pack"] = "x.ogg"
	AceGUIWidgetLSMlists.sound["Blizzard: Zzz Late"] = "y.ogg"
	local ml, bl = list(m, info), list(b, info)
	local ok = ml["Zzz Late Pack"] ~= nil and bl["Blizzard: Zzz Late"] ~= nil and ml["Blizzard: Zzz Late"] == nil and bl["Zzz Late Pack"] == nil
	AceGUIWidgetLSMlists.sound["Zzz Late Pack"] = nil
	AceGUIWidgetLSMlists.sound["Blizzard: Zzz Late"] = nil
	return ok
end)())

ready1().nSound = "CDTL3 Click"
check("a normal saved sound: main shows it, Blizzard menu shows none", m.get(info) == "CDTL3 Click" and b.get(info) == nil)
played = {}
b.set(info, "Blizzard: Raid Warning")
check("picking a Blizzard sound saves it in the same setting", ready1().nSound == "Blizzard: Raid Warning", ready1().nSound)
check("  and plays it once", #played == 1, #played)
check("  Blizzard menu shows it, the main menu shows no selection", b.get(info) == "Blizzard: Raid Warning" and m.get(info) == nil)
played = {}
m.set(info, "CDTL3 Tinks")
check("picking in the main menu replaces it and plays once", ready1().nSound == "CDTL3 Tinks" and #played == 1)
check("  main shows it, Blizzard shows none", m.get(info) == "CDTL3 Tinks" and b.get(info) == nil)
ready1().nSound = "Gone Pack Sound"
local nm, nb = text(m.name, info), text(b.name, info)
check("a missing sound: main says (missing), the Blizzard menu doesn't", nm:find("(missing)", 1, true) and not nb:find("(missing)", 1, true), nm .. " | " .. nb)
ready1().nSound = "Blizzard: Raid Warning"
nm = text(m.name, info)
check("a Blizzard pick is not flagged missing", not nm:find("(missing)", 1, true), nm)
played = {}
g.nSoundTest.func(info)
check("Play sound plays a Blizzard pick", #played == 1, #played)
ready1().nSound = "CDTL3 Click"

check("Ready 1: Play sound buttons are not half width", g.nSoundTest.width ~= "half" and g.hSoundTest.width ~= "half", tostring(g.nSoundTest.width) .. " " .. tostring(g.hSoundTest.width))

print(string.format("RESULT blizzsound %s: fails=%d lua errors=%d", FLAVOR, fails, #ERRORS - base))
