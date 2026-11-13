-- Translations (card 37): AceLocale with the English text as the key.
--   node run.js <addon> <toc number> locale.lua <toc file> [de|pseudo]
-- Always: every L["..."] in the addon's own files is a key of Locales/enUS.lua and returns text (never
-- nil), and every options name / desc / confirmText that is a plain string is such a key (or has no
-- letters, or is a lane/frame/spell name the player typed).
-- de: a fake deDE client with ONE translated key and one translated format: that option and that
-- chat line show German, everything else stays English.
-- pseudo: every key translated to "§" .. key before the code loads, then the options tree is built and
-- every string an option's name / desc / confirmText gives (functions called too) must carry the
-- marker, so a title or tooltip that skipped L[] shows up here.
dofile(HARNESS_DIR .. "/wow.lua")
local MODE = HARNESS_ARG == "plain" and "" or HARNESS_ARG
PLAYER.class = "MAGE"
local fails = 0
local function check(label, ok, detail)
	if not ok then fails = fails + 1 end
	print(string.format("  %-4s %s %s", ok and "ok" or "FAIL", label, detail or ""))
end

local MARK = "\194\167"  -- the section sign, as UTF-8
local DE_COPY_SETTINGS = "Einstellungen kopieren"
local DE_APPLIED = "Stil %s angewendet."

if MODE == "de" or MODE == "pseudo" then
	GAME_LOCALE = "deDE"
	STUB_FILES["locales/locales.xml"] = function()
		local function run(name)
			local f = assert(loadfile(HARNESS_SRC .. "/Locales/" .. name .. ".lua"))
			f("CooldownTimeline3", {})
		end
		run("enUS")
		local AL = LibStub("AceLocale-3.0")
		local app = AL:GetLocale("CDTL3")
		if MODE == "pseudo" then
			local keys = {}
			for k in pairs(app) do keys[#keys + 1] = k end
			local D = AL:NewLocale("CDTL3", "deDE")
			for _, k in ipairs(keys) do D[k] = MARK .. k end
		else
			run("deDE")
			local D = AL:NewLocale("CDTL3", "deDE")
			D["Copy Settings"] = DE_COPY_SETTINGS
			D["Applied the %s style."] = DE_APPLIED
		end
	end
end

local files = LoadTOC(HARNESS_TOCFILE)
local loadErrors = #ERRORS
Login()
Advance(11)
check("loads and logs in without errors", #ERRORS == 0, "errors " .. #ERRORS .. " (load " .. loadErrors .. ")")

local AL = LibStub("AceLocale-3.0")
local L = AL:GetLocale("CDTL3")

---------------------------------------------------------------- every L["..."] in the code is a key
local function literals(src)
	local found = {}
	local i = 1
	while true do
		local s, e = src:find('L%["', i)
		if not s then break end
		local before = s > 1 and src:sub(s - 1, s - 1) or " "
		i = e + 1
		local before2 = s > 2 and src:sub(s - 2, s - 2) or " "
		if not before:match("[%w_:]") and not (before == "." and before2 ~= ".") then
			local j = e + 1
			while j <= #src do
				local c = src:sub(j, j)
				if c == "\\" then j = j + 2
				elseif c == '"' then break
				else j = j + 1 end
			end
			if src:sub(j + 1, j + 1) == "]" then
				local lit = src:sub(e, j)
				local fn = load("return " .. lit)
				if fn then found[#found + 1] = fn() end
				i = j + 1
			end
		end
	end
	return found
end

local used, missing, nilLookups, total = {}, {}, {}, 0
for _, f in ipairs(files) do
	if f:match("%.lua$") and not f:lower():match("^libs/") and not f:lower():match("^flightdata/") then
		local src = HARNESS_READ(HARNESS_SRC .. "/" .. f)
		if src then
			for _, key in ipairs(literals(src)) do
				total = total + 1
				used[key] = true
				if rawget(L, key) == nil then missing[key] = f end
				if L[key] == nil then nilLookups[key] = true end
			end
		end
	end
end
local nMissing, nNil = 0, 0
for k, f in pairs(missing) do nMissing = nMissing + 1; if nMissing <= 10 then print("    missing from enUS (" .. f .. "): " .. k) end end
for k in pairs(nilLookups) do nNil = nNil + 1 end
check("every L[\"...\"] in the code is a key of enUS", nMissing == 0, string.format("%d lookups, %d missing", total, nMissing))
check("no L[...] lookup returns nil", nNil == 0, tostring(nNil) .. " nil")
local unused = 0
for k in pairs(L) do if not used[k] then unused = unused + 1; if unused <= 5 then print("    unused enUS key: " .. k) end end end
check("enUS holds no key the code never uses", unused == 0, tostring(unused) .. " unused")
check("an unknown key comes back as itself", L["No such phrase \1"] == "No such phrase \1")

---------------------------------------------------------------- the options tree
local function trim(s) return (s:gsub("^[ \n]+", ""):gsub("[ \n]+$", "")) end
local function letters(s)
	local t = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("%%[-%d.]*%a", "")
	return t:find("%a") ~= nil
end
local FIELDS = { "name", "desc", "confirmText", "usage" }
-- text that is data, not a phrase: the addon's own name, the version line, the "<< Select >>" markers
-- that Filters compares against
local DATA = { ["CDTL3"] = true }
local function isData(s)
	return DATA[s] or s:match("^CDTL3 v[%d%.]+") ~= nil or s == DE_COPY_SETTINGS or s:match("^<<.*>>$") ~= nil
end
-- the Profiles tab's stock controls come from AceDBOptions, which translates itself
local ACEDB = { name = 1, desc = 1, descreset = 1, reset = 1, choosedesc = 1, new = 1, choose = 1, copydesc = 1,
	copyfrom = 1, deldesc = 1, delete = 1 }
local function isAceDB(path)
	local key = path:match("^opts%.profiles%.(%w+)")
	return path == "opts.profiles" or (key and ACEDB[key] ~= nil)
end

-- a phrase with %s / %d in its key is shown filled in: match the filled-in text against the key's pattern
local patterns = {}
for k in pairs(L) do
	if k:find("%%[sd]") then
		local p = k:gsub("%%[sd]", function(c) return c == "%s" and "\1" or "\2" end)
		p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("\1", ".-"):gsub("\2", "%%d+")
		patterns[#patterns + 1] = "^" .. p .. "$"
	end
end
local function isPhrase(s)
	if rawget(L, s) ~= nil or rawget(L, trim(s)) ~= nil then return true end
	local t = trim(s)
	for _, p in ipairs(patterns) do
		if t:find(p) then return true end
	end
	return false
end

local opts = CDTL3:GetFullOptions()
local seen, nodes, strings, bad, badList = {}, 0, 0, 0, {}
local function note(path, field, s)
	bad = bad + 1
	if #badList < (MODE == "pseudo" and 90 or 12) then badList[#badList + 1] = path .. "." .. field .. " = " .. s:sub(1, 70):gsub("\n", "\\n") end
end
local function walk(node, path, dynamic)
	if type(node) ~= "table" or seen[node] then return end
	seen[node] = true
	nodes = nodes + 1
	for _, field in ipairs(FIELDS) do
		local v = node[field]
		if dynamic and type(v) == "function" then
			local ok, r = pcall(v, { options = opts, option = node, [0] = "cdtl3", type = node.type, arg = "x" })
			if ok then v = r else v = nil end
		end
		if type(v) == "string" and letters(v) and not isData(v) and not isAceDB(path) then
			strings = strings + 1
			if dynamic then
				if not v:find(MARK, 1, true) and not v:find("|T", 1, true) then note(path, field, v) end
			else
				if not isPhrase(v) then note(path, field, v) end
			end
		end
	end
	for k, child in pairs(node.args or {}) do walk(child, path .. "." .. tostring(k), dynamic) end
end

if MODE == "pseudo" then
	-- strings that are the player's own text, not the addon's: lane and frame names, spell names,
	-- the changelog and welcome text (English by design)
	local ALLOW = { "^Lane %d", "^Bar Frame %d", "^Ready %d", "Changelog", "^\n*CDTL3 continues", "^Currently custom tags" }
	local function allowed(s) for _, p in ipairs(ALLOW) do if s:find(p) then return true end end end
	local oldNote = note
	note = function(path, field, s) if not allowed(s) then oldNote(path, field, s) end end
	walk(opts, "opts", true)
	check("pseudo-locale: every string an option gives goes through L[]", bad == 0, string.format("%d strings in %d options, %d not translated", strings, nodes, bad))
else
	walk(opts, "opts", false)
	check("every plain-string option name / desc is a key of enUS", bad == 0, string.format("%d strings in %d options, %d not keys", strings, nodes, bad))
end
for _, l in ipairs(badList) do print("    " .. l) end

---------------------------------------------------------------- the fake deDE client
if MODE == "de" then
	check("the game locale is the fake deDE one", GAME_LOCALE == "deDE")
	check("a translated key returns the German text", L["Copy Settings"] == DE_COPY_SETTINGS, tostring(L["Copy Settings"]))
	check("an untranslated key stays English", L["Copy From"] == "Copy From" and L["Lanes"] == "Lanes")
	local heads, others = {}, {}
	local seenNode = {}
	local function find(node)
		if type(node) ~= "table" or seenNode[node] then return end
		seenNode[node] = true
		if node.type == "header" and rawget(node, "name") ~= nil and node.name == DE_COPY_SETTINGS then heads[#heads + 1] = node end
		if node.name == "Copy From" then others[#others + 1] = node end
		for _, c in pairs(node.args or {}) do find(c) end
	end
	find(opts)
	check("the Copy Settings header shows the German text in the options window", #heads >= 3, #heads .. " headers")
	check("the Copy From dropdown beside it stays English", #others >= 3, #others .. " dropdowns")
	local before = #CHAT
	CDTL3:ApplyPreset("minimal")
	local line = CHAT[#CHAT]
	check("a chat line with a value uses the translated pattern", #CHAT > before and tostring(line):find("Stil Minimal angewendet.", 1, true) ~= nil, tostring(line))
	local from = #CHAT + 1
	CDTL3:PrintHelp()
	local english = false
	for i = from, #CHAT do
		if tostring(CHAT[i]):find("commands (/cdtl3 <command>):", 1, true) then english = true end
	end
	check("a chat line with no translation stays English", english)
end

print(string.format("RESULT locale%s %s: fails=%d lua errors=%d", MODE ~= "" and (" " .. MODE) or "", HARNESS_TOCFILE, fails, #ERRORS))
