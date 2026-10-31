-- Loads the addon's real Data.lua and Helpers.lua for one interface number, runs the real
-- CDTL3:GetCharacterData() once per class, and leaves what it loaded into CDTL3.spellData
-- in HARNESS_OUT as JSON. check.js sets HARNESS_SRC, HARNESS_TOC and HARNESS_CLASSES.
local SRC, TOC = HARNESS_SRC, HARNESS_TOC

CDTL3 = {
	tocversion = TOC,
	-- the same rule as the top of CDTL3.lua
	isForever = (TOC >= 16000 and TOC < 17000),
	player = {},
	spellData = {},
	db = { profile = { global = { debugMode = false } } },
}
CDTL3.retailAPI = TOC >= 110000 or CDTL3.isForever

dofile(SRC .. "/Data.lua")
dofile(SRC .. "/Helpers.lua")

UnitGUID = function() return "Player-0000-00000001" end
CDTL3.GetPlayerPower = function() return 0 end

local function str(s)
	s = tostring(s):gsub("[%c\"\\]", function(c) return string.format("\\u%04x", c:byte()) end)
	return '"' .. s .. '"'
end

local function entry(e)
	local parts = {
		'"id":' .. tostring(e.id),
		'"name":' .. str(e.name),
		'"bCD":' .. (e.bCD and tostring(e.bCD) or "null"),
		'"oaf":' .. tostring(e.oaf == true),
	}
	if e.race then
		parts[#parts + 1] = '"race":' .. str(e.race)
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local classes = {}
for class in HARNESS_CLASSES:gmatch("[^,]+") do
	CDTL3.player = {}
	CDTL3.spellData = {}
	GetPlayerInfoByGUID = function() return "Tester", class, "Tester", "Human", 2, "Tester", "" end
	CDTL3:GetCharacterData()

	local list = {}
	for _, e in ipairs(CDTL3.spellData) do
		list[#list + 1] = entry(e)
	end
	classes[#classes + 1] = str(class) .. ":[" .. table.concat(list, ",") .. "]"
end

HARNESS_OUT = "{" .. table.concat(classes, ",") .. "}"
