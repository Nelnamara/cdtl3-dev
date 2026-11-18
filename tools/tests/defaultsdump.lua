-- Prints every saved-variable default (CDTL3.db.defaults) as sorted lines "path = value".
-- Used to prove a change to the defaults tables in CDTL3.lua leaves them identical: run it on the
-- old and the new tree and diff the output (lines starting "  " only; the RESULT line is the check).
dofile(HARNESS_DIR .. "/wow.lua")
PLAYER.class = "MAGE"
CDTL3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = { Default = {} } }
LoadTOC(HARNESS_TOCFILE)
Login()
Advance(11)

local out = {}
local function walk(t, path)
	for k, v in pairs(t) do
		local p = path .. "." .. tostring(k)
		if type(v) == "table" then
			out[#out + 1] = "  " .. p .. " = {}"
			walk(v, p)
		else
			out[#out + 1] = "  " .. p .. " = " .. type(v) .. ":" .. tostring(v)
		end
	end
end
walk(CDTL3.db.defaults, "defaults")
table.sort(out)
print(table.concat(out, "\n"))
print(string.format("RESULT defaultsdump lines=%d fails=0 lua errors=%d", #out, #ERRORS))
