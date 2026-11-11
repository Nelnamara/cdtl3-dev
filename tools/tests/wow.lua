-- Stub WoW client for loading the REAL CDTL3 files (and the real bundled Ace3) under fengari.
-- Set HARNESS_SRC / HARNESS_TOC before dofile'ing this. Exposes:
--   NOW, Advance(dt), RunTimers(), FireEvent(e, ...), RunOnUpdate(dt, n), ERRORS, CHAT,
--   PLAYER (class/race/guid), SPELLCD[id] (C_Spell.GetSpellCooldown result), LoadTOC(tocName),
--   MISSES (nil-global reads from addon files), SetSecret(v) helpers.
local TOC = HARNESS_TOC
FLAVOR = (TOC >= 110000 and "retail") or (TOC >= 50000 and "mop") or (TOC >= 20000 and "tbc")
	or ((TOC >= 16000 and TOC < 17000) and "forever") or "era"
RETAILAPI = (FLAVOR == "retail" or FLAVOR == "forever")

---------------------------------------------------------------- Lua 5.1 compat
loadstring = function(s, name) return load(s, name) end
unpack = table.unpack
table.getn = function(t) return #t end
getfenv = function() return _G end
setfenv = function(f) return f end
math.mod = math.fmod
string.gfind = string.gmatch
math.pow = function(a, b) return a ^ b end

strlen, strsub, strlower, strupper = string.len, string.sub, string.lower, string.upper
strfind, strmatch, gsub, strrep = string.find, string.match, string.gsub, string.rep
strbyte, strchar, format, strformat = string.byte, string.char, string.format, string.format
gmatch = string.gmatch
tinsert, tremove, tconcat, sort = table.insert, table.remove, table.concat, table.sort
floor, ceil, abs, max, min, sqrt, random = math.floor, math.ceil, math.abs, math.max, math.min, math.sqrt, math.random
date, time = os.date, os.time
function strtrim(s, chars)
	chars = chars or "%s"
	return (s:gsub("^[" .. chars .. "]+", ""):gsub("[" .. chars .. "]+$", ""))
end
string.trim = function(s, chars) return strtrim(s, chars) end
function strsplit(delim, str, pieces)
	local out, pos = {}, 1
	while true do
		if pieces and #out == pieces - 1 then out[#out + 1] = str:sub(pos); break end
		local s, e = str:find(delim, pos, true)
		if not s then out[#out + 1] = str:sub(pos); break end
		out[#out + 1] = str:sub(pos, s - 1)
		pos = e + 1
	end
	return table.unpack(out)
end
string.split = strsplit
function strjoin(delim, ...) return table.concat({ ... }, delim) end
function strconcat(...) return table.concat({ ... }) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
table.wipe = wipe
function tContains(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
function tostringall(...)
	local n = select("#", ...)
	local t = { ... }
	for i = 1, n do t[i] = tostring(t[i]) end
	return table.unpack(t, 1, n)
end
bit = {
	band = function(a, b, ...) local r = math.tointeger(a) & math.tointeger(b); for _, x in ipairs({ ... }) do r = r & x end return r end,
	bor = function(a, b, ...) local r = math.tointeger(a) | math.tointeger(b); for _, x in ipairs({ ... }) do r = r | x end return r end,
	bxor = function(a, b) return math.tointeger(a) ~ math.tointeger(b) end,
	bnot = function(a) return ~math.tointeger(a) & 0xFFFFFFFF end,
	lshift = function(a, n) return (math.tointeger(a) << n) & 0xFFFFFFFF end,
	rshift = function(a, n) return (math.tointeger(a) & 0xFFFFFFFF) >> n end,
}

---------------------------------------------------------------- errors / time / events
ERRORS = {}
local function errh(e)
	local tb = debug.traceback(tostring(e), 2)
	ERRORS[#ERRORS + 1] = tb
	print("!! LUA ERROR: " .. tb)
	return e
end
ERRH = errh
function geterrorhandler() return errh end
function seterrorhandler() end
function securecallfunction(f, ...)
	local r = table.pack(xpcall(f, errh, ...))
	if r[1] then return table.unpack(r, 2, r.n) end
end
securecall = function(f, ...)
	if type(f) == "string" then f = _G[f] end
	return securecallfunction(f, ...)
end
function securecallmethod(obj, m, ...) return securecallfunction(obj[m], obj, ...) end
function issecurevariable() return false, "CDTL3" end
function issecure() return false end
function InCombatLockdown() return false end
function debugstack() return "" end
function debuglocals() return "" end
function hooksecurefunc(t, name, hook)
	if type(t) == "string" then t, name, hook = _G, t, name end
	local orig = t[name]
	t[name] = function(...)
		local r = table.pack(orig(...))
		hook(...)
		return table.unpack(r, 1, r.n)
	end
end

NOW = 1000
function GetTime() return NOW end
function GetServerTime() return 1700000000 + math.floor(NOW) end
function debugprofilestop() return NOW * 1000 end
local timers = {}
function Advance(dt)
	NOW = NOW + dt
	RunTimers()
end
function RunTimers()
	local again = true
	while again do
		again = false
		table.sort(timers, function(a, b) return a.t < b.t end)
		for i, tm in ipairs(timers) do
			if tm.t <= NOW then
				table.remove(timers, i)
				xpcall(tm.f, errh)
				again = true
				break
			end
		end
	end
end
C_Timer = {
	After = function(d, f) timers[#timers + 1] = { t = NOW + d, f = f } end,
	NewTimer = function(d, f) local h = { Cancel = function() end }; timers[#timers + 1] = { t = NOW + d, f = function() f(h) end }; return h end,
	NewTicker = function(d, f) return { Cancel = function() end } end,
}

local eventFrames = {}   -- event -> { frame = true }
function FireEvent(event, ...)
	local list = {}
	for f in pairs(eventFrames[event] or {}) do list[#list + 1] = f end
	for _, f in ipairs(list) do
		local h = f.__scripts and f.__scripts.OnEvent
		if h then xpcall(h, errh, f, event, ...) end
	end
	return #list
end
function IsEventRegisteredAnywhere(event)
	for _ in pairs(eventFrames[event] or {}) do return true end
	return false
end
REFUSED_EVENTS = {}  -- event -> true: RegisterEvent errors (combat log on retailAPI clients)

---------------------------------------------------------------- frame / region mock
local Methods = {}
local MockMT = {}
local allFrames = {}
local function newObj(otype, name, parent)
	local o = setmetatable({ __otype = otype, __name = name, __parent = parent, __shown = true,
		__scripts = {}, __points = {}, __w = 0, __h = 0, __alpha = 1, __level = 1, __enabled = true,
		__children = {}, __min = 0, __max = 1, __val = 0 }, MockMT)
	allFrames[#allFrames + 1] = o
	return o
end
MOCK_NEW = newObj
MockMT.__index = function(t, k)
	local m = Methods[k]
	if m then return m end
	if type(k) ~= "string" or not k:match("^%u") then return nil end
	if k:match("^Create") then
		return function(self, ...) local c = newObj(k:sub(7), nil, self); return c end
	end
	if k:match("^Is") or k:match("^Has") or k:match("^Can") then return function() return false end end
	if k:match("^Get") then return function() return nil end end
	return function() end
end
local function child(self, key, otype)
	local c = rawget(self, key)
	if not c then c = newObj(otype or "Texture", nil, self); rawset(self, key, c) end
	return c
end
Methods.GetName = function(s) return s.__name end
Methods.GetDebugName = function(s) return s.__name or "anon" end
Methods.GetParent = function(s) return s.__parent end
Methods.SetParent = function(s, p) s.__parent = p end
Methods.Show = function(s) s.__shown = true end
Methods.Hide = function(s) s.__shown = false end
Methods.SetShown = function(s, v) s.__shown = v and true or false end
Methods.IsShown = function(s) return s.__shown end
Methods.IsVisible = function(s)
	local f = s
	while f do
		if type(f) ~= "table" or not f.__shown then return f == nil end
		f = f.__parent
	end
	return true
end
Methods.SetScript = function(s, k, f) s.__scripts[k] = f end
Methods.GetScript = function(s, k) return s.__scripts[k] end
Methods.HasScript = function() return true end
Methods.HookScript = function(s, k, f)
	local old = s.__scripts[k]
	if old then
		s.__scripts[k] = function(...) old(...); f(...) end
	else
		s.__scripts[k] = f
	end
end
Methods.RegisterEvent = function(s, e)
	if REFUSED_EVENTS[e] then error("Attempt to register a forbidden event: " .. e) end
	eventFrames[e] = eventFrames[e] or {}; eventFrames[e][s] = true
	return true
end
Methods.RegisterUnitEvent = Methods.RegisterEvent
Methods.UnregisterEvent = function(s, e) if eventFrames[e] then eventFrames[e][s] = nil end end
Methods.UnregisterAllEvents = function(s) for _, l in pairs(eventFrames) do l[s] = nil end end
Methods.IsEventRegistered = function(s, e) return eventFrames[e] and eventFrames[e][s] or false end
Methods.SetWidth = function(s, w) s.__w = w end
Methods.SetHeight = function(s, h) s.__h = h end
Methods.SetSize = function(s, w, h) s.__w, s.__h = w, h or w end
Methods.GetWidth = function(s) return s.__w or 0 end
Methods.GetHeight = function(s) return s.__h or 0 end
Methods.GetSize = function(s) return s.__w or 0, s.__h or 0 end
Methods.GetRect = function(s) return 0, 0, s.__w, s.__h end
Methods.SetPoint = function(s, ...) s.__points[#s.__points + 1] = { ... } end
Methods.ClearAllPoints = function(s) s.__points = {} end
Methods.GetNumPoints = function(s) return #s.__points end
Methods.GetPoint = function(s, i) local p = s.__points[i or 1]; if p then return table.unpack(p) end end
Methods.GetPointByName = Methods.GetPoint
Methods.GetLeft = function() return 0 end
Methods.GetRight = function(s) return s.__w or 0 end
Methods.GetTop = function(s) return s.__h or 0 end
Methods.GetBottom = function() return 0 end
Methods.GetCenter = function() return 0, 0 end
Methods.GetScale = function() return 1 end
Methods.GetEffectiveScale = function() return 1 end
Methods.GetAlpha = function(s) return s.__alpha end
Methods.SetAlpha = function(s, a) s.__alpha = a end
Methods.GetEffectiveAlpha = function(s) return s.__alpha end
Methods.SetText = function(s, t) s.__text = t end
Methods.SetFormattedText = function(s, f, ...) s.__text = string.format(f, ...) end
Methods.GetText = function(s) return s.__text end
Methods.GetStringWidth = function(s) return #(tostring(s.__text or "")) * 6 end
Methods.GetUnboundedStringWidth = Methods.GetStringWidth
Methods.GetStringHeight = function() return 12 end
Methods.GetNumLines = function() return 1 end
Methods.GetLineHeight = function() return 12 end
Methods.SetFont = function(s, p, z, f) s.__font = { p, z, f }; return true end
Methods.GetFont = function(s) local f = s.__font or {}; return f[1] or "Fonts\\FRIZQT__.TTF", f[2] or 12, f[3] or "" end
Methods.SetFontObject = function(s, o) s.__fontobj = o end
Methods.GetFontObject = function(s) return s.__fontobj end
Methods.GetTextColor = function() return 1, 1, 1, 1 end
Methods.GetShadowColor = function() return 0, 0, 0, 1 end
Methods.GetShadowOffset = function() return 0, 0 end
Methods.GetJustifyH = function() return "CENTER" end
Methods.GetJustifyV = function() return "MIDDLE" end
Methods.GetFrameLevel = function(s) return s.__level end
Methods.SetFrameLevel = function(s, l) s.__level = l end
Methods.GetFrameStrata = function() return "MEDIUM" end
Methods.GetDrawLayer = function() return "ARTWORK", 0 end
Methods.GetObjectType = function(s) return s.__otype end
Methods.IsObjectType = function(s, t) return t == s.__otype or t == "Frame" or t == "Region" end
Methods.GetMinMaxValues = function(s) return s.__min, s.__max end
Methods.SetMinMaxValues = function(s, a, b) s.__min, s.__max = a, b end
Methods.GetValue = function(s) return s.__val end
Methods.SetValue = function(s, v) s.__val = v end
Methods.GetValueStep = function() return 1 end
Methods.GetStatusBarTexture = function(s) return child(s, "__sbt") end
Methods.GetStatusBarColor = function(s) local c = s.__sbc or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
Methods.SetStatusBarColor = function(s, r, g, b, a) s.__sbc = { r, g, b, a } end
Methods.GetRegions = function() end
Methods.GetChildren = function() end
Methods.GetNumChildren = function() return 0 end
Methods.GetNumRegions = function() return 0 end
Methods.GetNormalTexture = function(s) return child(s, "__nt") end
Methods.GetPushedTexture = function(s) return child(s, "__pt") end
Methods.GetHighlightTexture = function(s) return child(s, "__ht") end
Methods.GetDisabledTexture = function(s) return child(s, "__dt") end
Methods.GetCheckedTexture = function(s) return child(s, "__ct") end
Methods.GetThumbTexture = function(s) return child(s, "__tt") end
Methods.GetFontString = function(s) return child(s, "__fs", "FontString") end
Methods.GetNormalFontObject = function(s) return GameFontNormal end
Methods.GetHighlightFontObject = function(s) return GameFontHighlight end
Methods.GetDisabledFontObject = function(s) return GameFontDisable end
Methods.GetVertexColor = function() return 1, 1, 1, 1 end
Methods.SetTexture = function(s, t) s.__tex = t; return true end
Methods.GetTexture = function(s) return s.__tex end
Methods.SetAtlas = function(s, a) s.__atlas = a; return true end
Methods.GetAtlas = function(s) return s.__atlas end
Methods.SetStatusBarTexture = function(s, t) s.__tex = t; return true end
Methods.GetTexCoord = function() return 0, 0, 0, 1, 1, 0, 1, 1 end
Methods.IsMouseOver = function() return false end
Methods.IsMouseEnabled = function() return true end
Methods.IsEnabled = function(s) return s.__enabled end
Methods.Enable = function(s) s.__enabled = true end
Methods.Disable = function(s) s.__enabled = false end
Methods.SetEnabled = function(s, v) s.__enabled = v and true or false end
Methods.GetChecked = function(s) return s.__checked end
Methods.SetChecked = function(s, v) s.__checked = v end
Methods.GetID = function(s) return s.__id or 0 end
Methods.SetID = function(s, v) s.__id = v end
Methods.SetBackdrop = function(s, b) s.__backdrop = b end
Methods.GetBackdrop = function(s) return s.__backdrop end
Methods.GetBackdropColor = function() return 0, 0, 0, 0 end
Methods.GetBackdropBorderColor = function() return 0, 0, 0, 0 end
Methods.IsPlaying = function() return false end
Methods.IsForbidden = function() return false end
Methods.IsMovable = function() return true end
Methods.IsResizable = function() return true end
Methods.IsProtected = function() return false end
Methods.IsAnchoringRestricted = function() return false end
Methods.GetNumber = function() return 0 end
Methods.GetCursorPosition = function() return 0 end
Methods.HasFocus = function() return false end
Methods.GetMaxLetters = function() return 0 end
Methods.GetVerticalScroll = function() return 0 end
Methods.GetHorizontalScroll = function() return 0 end
Methods.GetVerticalScrollRange = function() return 0 end
Methods.GetHorizontalScrollRange = function() return 0 end
Methods.GetScrollChild = function(s) return s.__scrollchild end
Methods.SetScrollChild = function(s, c) s.__scrollchild = c end
Methods.GetCooldownTimes = function() return 0, 0 end
Methods.IsOwned = function(s, o) return s.__owner == o end
Methods.SetOwner = function(s, o) s.__owner = o end
Methods.NumLines = function() return 0 end
Methods.GetHitRectInsets = function() return 0, 0, 0, 0 end
Methods.GetClampRectInsets = function() return 0, 0, 0, 0 end
Methods.GetResizeBounds = function() return 0, 0, 0, 0 end
Methods.GetDuration = function() return 0 end
Methods.GetElapsed = function() return 0 end
Methods.GetProgress = function() return 0 end
Methods.GetOrientation = function() return "HORIZONTAL" end
Methods.GetReverseFill = function() return false end
Methods.GetFillStyle = function() return "STANDARD" end
Methods.GetRotation = function() return 0 end
Methods.GetSpacing = function() return 0 end
Methods.GetIndentedWordWrap = function() return false end
Methods.GetWordWrap = function() return true end
Methods.GetNonSpaceWrap = function() return false end
Methods.GetMaxLines = function() return 0 end
Methods.GetTextInsets = function() return 0, 0, 0, 0 end
Methods.GetAttribute = function(s, k) return s.__attr and s.__attr[k] end
Methods.SetAttribute = function(s, k, v) s.__attr = s.__attr or {}; s.__attr[k] = v end
Methods.GetPropagateKeyboardInput = function() return false end
Methods.GetButtonState = function() return "NORMAL" end
Methods.GetMotionScriptsWhileDisabled = function() return false end
Methods.CreateAnimationGroup = function(s) return newObj("AnimationGroup", nil, s) end
Methods.CreateAnimation = function(s) return newObj("Animation", nil, s) end
Methods.GetRegionParent = function(s) return s.__parent end
Methods.GetTextureFileID = function() return 0 end
Methods.GetTextureFilePath = function(s) return s.__tex end

function CreateFrame(otype, name, parent, template, id)
	local f = newObj(otype or "Frame", name, parent or nil)
	if name then
		if type(parent) == "table" and parent.__name then name = name:gsub("%$parent", parent.__name) end
		f.__name = name
		_G[name] = f
	end
	if otype == "GameTooltip" then f.__shown = false end
	return f
end
function CreateFont(name) local f = newObj("Font", name); _G[name] = f; return f end
function GetAllFrames() return allFrames end

-- OnUpdate across every frame that has one and is visible
function RunOnUpdate(dt, n)
	for _ = 1, (n or 1) do
		NOW = NOW + dt
		local list = {}
		for _, f in ipairs(allFrames) do
			if f.__scripts.OnUpdate and Methods.IsVisible(f) then list[#list + 1] = f end
		end
		for _, f in ipairs(list) do xpcall(f.__scripts.OnUpdate, errh, f, dt) end
		RunTimers()
	end
end

UIParent = CreateFrame("Frame", "UIParent")
WorldFrame = CreateFrame("Frame", "WorldFrame")
Minimap = CreateFrame("Minimap", "Minimap", UIParent); Minimap:SetSize(140, 140)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip", UIParent)
DEFAULT_CHAT_FRAME = CreateFrame("ScrollingMessageFrame", "ChatFrame1", UIParent)
CHAT = {}
Methods.AddMessage = function(s, m) CHAT[#CHAT + 1] = m end
SELECTED_CHAT_FRAME = DEFAULT_CHAT_FRAME
for _, n in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontNormalSmall", "GameFontHighlightSmall",
	"GameFontDisable", "GameFontDisableSmall", "GameFontNormalLarge", "GameFontHighlightLarge", "ChatFontNormal",
	"GameFontRed", "GameFontGreen", "GameFontWhite", "NumberFontNormal", "GameFontNormalHuge", "SystemFont_Shadow_Med1",
	"GameFontHighlightMedium", "GameFontNormalMed3", "GameFontNormalLeft", "GameFontHighlightLeft",
	"GameTooltipText", "GameTooltipHeaderText", "GameFontDisableLarge", "QuestFontNormalSmall", "GameFontBlack",
	"GameFontNormalOutline", "NumberFontNormalSmall", "Game15Font_o1", "GameFontNormalTiny", "GameFontHighlightExtraSmall" }) do
	CreateFont(n)
end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UNIT_NAME_FONT = STANDARD_TEXT_FONT
DAMAGE_TEXT_FONT = STANDARD_TEXT_FONT
UISpecialFrames = {}
BackdropTemplateMixin = {}
SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
function PlaySound() end
function PlaySoundFile() return true end
function StopSound() end
function GetCursorPosition() return 0, 0 end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function HideUIPanel() end
function ShowUIPanel() end
function CloseDropDownMenus() end
function GetMouseFocus() return nil end
function GetMouseFoci() return {} end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function IsModifierKeyDown() return false end
function GetBindingKey() return nil end
function ClearCursor() end
function GetCursorInfo() return nil end
function GetCVar() return "0" end
function GetCVarBool() return false end
function SetCVar() end
C_CVar = { GetCVar = function() return "0" end, GetCVarBool = function() return false end, SetCVar = function() end }
StaticPopupDialogs = {}
function StaticPopup_Show(which) STATIC_SHOWN = which; return CreateFrame("Frame") end
function StaticPopup_Hide() end
function StaticPopup_Visible() return nil end
function RegisterStateDriver() end
function UnregisterStateDriver() end
function FCF_GetCurrentChatFrame() return DEFAULT_CHAT_FRAME end
function ChatFrame_OpenChat() end
function ChatEdit_GetActiveWindow() return nil end
function ChatEdit_InsertLink() return false end
function ChatFrame_AddMessageEventFilter() end
function GetChatWindowInfo() end
function ToggleDropDownMenu() end
function UIDropDownMenu_Initialize() end
function EasyMenu() end
function SecureHandlerWrapScript() end
OKAY, CANCEL, ACCEPT, YES, NO, CLOSE, DEFAULT, NONE = "Okay", "Cancel", "Accept", "Yes", "No", "Close", "Default", "None"
KEY_BUTTON1, KEY_BUTTON2, NOT_BOUND = "LeftButton", "RightButton", "Not Bound"
ADD, DELETE, REMOVE, SAVE, RESET, SETTINGS = "Add", "Delete", "Remove", "Save", "Reset", "Settings"
FONT_COLOR_CODE_CLOSE = "|r"
NORMAL_FONT_COLOR_CODE = "|cffffd200"
HIGHLIGHT_FONT_COLOR_CODE = "|cffffffff"
RED_FONT_COLOR_CODE = "|cffff2020"
GREEN_FONT_COLOR_CODE = "|cff20ff20"
local function Color(r, g, b, a)
	return { r = r, g = g, b = b, a = a or 1, GetRGB = function(c) return c.r, c.g, c.b end,
		GetRGBA = function(c) return c.r, c.g, c.b, c.a end, WrapTextInColorCode = function(c, t) return t end,
		GenerateHexColor = function() return "ffffffff" end }
end
CreateColor = Color
NORMAL_FONT_COLOR = Color(1, 0.82, 0)
HIGHLIGHT_FONT_COLOR = Color(1, 1, 1)
GRAY_FONT_COLOR = Color(0.5, 0.5, 0.5)
RED_FONT_COLOR = Color(1, 0.1, 0.1)
DISABLED_FONT_COLOR = Color(0.5, 0.5, 0.5)
RAID_CLASS_COLORS = setmetatable({}, { __index = function(t, k) local c = Color(1, 1, 1); c.colorStr = "ffffffff"; rawset(t, k, c); return c end })
CLASS_ICON_TCOORDS = setmetatable({}, { __index = function() return { 0, 1, 0, 1 } end })
LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function(_, k) return k end })
LOCALIZED_CLASS_NAMES_FEMALE = LOCALIZED_CLASS_NAMES_MALE
CLASS_SORT_ORDER = { "WARRIOR", "DEATHKNIGHT", "PALADIN", "MONK", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER", "DEMONHUNTER", "EVOKER" }
COMBATLOG_OBJECT_AFFILIATION_MINE = 1
COMBATLOG_OBJECT_TYPE_PLAYER = 0x400
COMBATLOG_OBJECT_TYPE_PET = 0x1000
BOOKTYPE_SPELL, BOOKTYPE_PET = "spell", "pet"
MAX_PLAYER_LEVEL = 60
WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = 1, 2
WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_MISTS_CLASSIC = 5, 19
WOW_PROJECT_ID = ({ retail = 1, era = 2, tbc = 5, mop = 19, forever = 18 })[FLAVOR]
LE_EXPANSION_LEVEL_CURRENT = ({ retail = 11, era = 0, tbc = 1, mop = 4, forever = 0 })[FLAVOR]

---------------------------------------------------------------- game / player
PLAYER = { guid = "Player-1-0000001", name = "Tester", realm = "Realm", class = "MAGE", race = "Human", level = 60 }
function GetBuildInfo() return "test", "70000", "Oct 30 2026", TOC end
function GetLocale() return "enUS" end
function GetCurrentRegion() return 1 end
function GetCurrentRegionName() return "US" end
function GetRealmName() return PLAYER.realm end
function GetNormalizedRealmName() return PLAYER.realm end
function UnitName(u) if u == "player" then return PLAYER.name, nil end return nil end
function UnitFullName(u) return PLAYER.name, PLAYER.realm end
function UnitGUID(u) if u == "player" then return PLAYER.guid end if u == "pet" then return "Pet-1" end end
function UnitClass(u) return PLAYER.class, PLAYER.class, 1 end
function UnitClassBase(u) return PLAYER.class, 1 end
function UnitRace(u) return PLAYER.race, PLAYER.race, 1 end
function UnitSex() return 2 end
function UnitLevel() return PLAYER.level end
function UnitFactionGroup() return "Alliance", "Alliance" end
-- TARGET: nil (no target) | "self" | "friend" | "enemy"; harnesses set it to test target-dependent code
TARGET = nil
function UnitExists(u) return u == "player" or (u == "target" and TARGET ~= nil) end
function UnitIsUnit(a, b) if a == "target" and b == "player" then return TARGET == "self" end return a == b end
function UnitIsFriend(a, b) if b == "target" then return TARGET == "self" or TARGET == "friend" end return a == b end
function UnitAffectingCombat() return false end
function UnitHealth() return 100 end
function UnitHealthMax() return 100 end
function UnitPower() return 50 end
function UnitPowerMax() return 100 end
function UnitPowerType() return 0, "MANA" end
function UnitAttackSpeed() return 2, nil end
function UnitRangedDamage() return 3, 0, 0, 0, 0, 0 end
function UnitCastingInfo() return nil end
function UnitChannelInfo() return nil end
function UnitIsDeadOrGhost() return false end
function UnitInVehicle() return false end
function UnitOnTaxi() return false end
function IsInInstance() return false, "none" end
function IsInGroup() return false end
function IsInRaid() return false end
function IsMounted() return false end
function IsResting() return false end
function IsLoggedIn() return LOGGED_IN end
function GetPlayerInfoByGUID(guid)
	if guid == PLAYER.guid then return PLAYER.class, PLAYER.class, PLAYER.race, PLAYER.race, 2, PLAYER.name, PLAYER.realm end
end
function GetInventoryItemID() return nil end
function GetInventoryItemCooldown() return 0, 0, 1 end
function GetInventoryItemTexture() return nil end
function IsInventoryItemLocked() return false end
function GetComboPoints() return 0 end
function GetShapeshiftForm() return 0 end
function GetRuneCooldown(i) return NOW - 1, 10, false end
function GetSpellBaseCooldown(id) return (BASECD and BASECD[id]) or 0, 1500 end
function GetNumGroupMembers() return 0 end
function GetNumTalentGroups() return 1 end
function GetActiveTalentGroup() return 1 end
function GetNumSpecializations() return 0 end
function GetSpecialization() return nil end
function GetTalentInfo() return nil end
function GetNumTalentTabs() return 0 end
function GetTalentTabInfo() return nil end
function GetAddOnMetadata(_, k) return "3.0.12" end
C_AddOns = { GetAddOnMetadata = function(_, k) return "3.0.12" end, IsAddOnLoaded = function() return false end,
	LoadAddOn = function() return false end, GetAddOnInfo = function() return nil end, GetNumAddOns = function() return 0 end }
function IsAddOnLoaded() return false end
SlashCmdList = {}
hash_SlashCmdList = {}
C_SpecializationInfo = {
	GetNumSpecializationsForClassID = function() return 0 end,
	GetSpecialization = function() return nil end,
	GetActiveSpecGroup = function() return 1 end,
	CanPlayerUseTalentUI = function() return false, "test" end,
	GetSpecializationInfo = function() return nil end,
	GetTalentInfo = function() return nil end,
}
C_ClassTalents = { GetActiveConfigID = function() return nil end }
C_Texture = { GetAtlasInfo = function(name) if RETAILAPI then return { width = 10, height = 10, file = name } end end }
C_Secrets = { ShouldAurasBeSecret = function() return SECRET_AURAS and true or false end }
C_EncodingUtil = nil
C_UIFileAsset = { IsKnownFile = function() return true end }
LE_EXPANSION_CLASSIC, LE_EXPANSION_BURNING_CRUSADE, LE_EXPANSION_WRATH_OF_THE_LICH_KING = 0, 1, 2
LE_EXPANSION_CATACLYSM, LE_EXPANSION_MISTS_OF_PANDARIA = 3, 4
LE_EXPANSION_WARLORDS_OF_DRAENOR, LE_EXPANSION_LEGION, LE_EXPANSION_BATTLE_FOR_AZEROTH = 5, 6, 7
LE_EXPANSION_SHADOWLANDS, LE_EXPANSION_DRAGONFLIGHT, LE_EXPANSION_WAR_WITHIN, LE_EXPANSION_MIDNIGHT = 8, 9, 10, 11
function ClassicExpansionAtLeast(x)
	if FLAVOR == "retail" or FLAVOR == "forever" then return true end
	return (LE_EXPANSION_LEVEL_CURRENT or 0) >= x
end
function ClassicExpansionAtMost(x)
	if FLAVOR == "retail" then return false end
	return (LE_EXPANSION_LEVEL_CURRENT or 0) <= x
end
function GetClassicExpansionLevel() return LE_EXPANSION_LEVEL_CURRENT end
function GetExpansionLevel() return LE_EXPANSION_LEVEL_CURRENT end
Item = {
	CreateFromItemID = function(_, id)
		return { ContinueOnItemLoad = function(self, f) f() end, GetItemName = function() return "Item " .. tostring(id) end,
			GetItemIcon = function() return 134400 end, GetItemLink = function() return "|cff|Hitem:" .. tostring(id) .. "|h[Item]|h|r" end,
			IsItemEmpty = function() return false end }
	end,
}
C_Container = {
	GetContainerNumSlots = function() return 0 end,
	GetContainerItemID = function() return nil end,
	GetItemCooldown = function(id) local c = ITEMCD and ITEMCD[id]; if c then return c[1], c[2], c[3] or 1 end return 0, 0, 1 end,
}
C_Item = {
	GetItemSpell = function(id) local s = ITEMSPELL and ITEMSPELL[id]; if s then return s[1], s[2] end end,
	GetItemInfoInstant = function(id) return id, "Item", "Misc", "", 134400, 0, 0 end,
	GetItemInfo = function(id) return "Item " .. tostring(id) end,
	GetItemNameByID = function(id) return "Item " .. tostring(id) end,
}
C_UnitAuras = {
	GetAuraDataByIndex = function(u, i, f) local l = AURAS and AURAS[f or "HELPFUL"]; return l and l[i] end,
	GetAuraDataByAuraInstanceID = function() return nil end,
	GetPlayerAuraBySpellID = function() return nil end,
}
Enum = setmetatable({
	PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6 },
	SpellBookSpellBank = { Player = 0, Pet = 1 },
	SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 },
}, { __index = function(t, k) local e = setmetatable({}, { __index = function() return 0 end }); rawset(t, k, e); return e end })
Settings = {
	RegisterCanvasLayoutCategory = function(frame, name)
		return { ID = name, GetID = function(c) return c.ID end, name = name }
	end,
	RegisterCanvasLayoutSubcategory = function(cat, frame, name) return { ID = name, GetID = function(c) return c.ID end } end,
	RegisterAddOnCategory = function() end,
	GetCategory = function() return nil end,
	OpenToCategory = function() end,
}
SettingsPanel = CreateFrame("Frame", "SettingsPanel", UIParent); SettingsPanel:Hide()
function InterfaceOptions_AddCategory() end

---------------------------------------------------------------- spells (flavor-specific)
-- SPELLINFO[id] = { name, icon }; SPELLCD[id] = C_Spell.GetSpellCooldown-style table;
-- SPELLBOOK = { {id=, name=}, ... }; KNOWN[id] = true
SPELLINFO, SPELLCD, SPELLBOOK, KNOWN, BASECD = {}, {}, {}, {}, {}
-- a value whose comparison / arithmetic throws, like a Midnight secret number
SECRET = setmetatable({}, {
	__lt = function() error("attempt to compare a secret number value") end,
	__le = function() error("attempt to compare a secret number value") end,
	__add = function() error("attempt to perform arithmetic on a secret number value") end,
	__sub = function() error("attempt to perform arithmetic on a secret number value") end,
	__mul = function() error("attempt to perform arithmetic on a secret number value") end,
	__div = function() error("attempt to perform arithmetic on a secret number value") end,
	__unm = function() error("attempt to perform arithmetic on a secret number value") end,
	__concat = function() error("attempt to concatenate a secret value") end,
	__tostring = function() return "<secret>" end,
})
local function cdOf(id)
	local c = SPELLCD[id]
	if c then return c end
	return { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1, isOnGCD = false }
end
if RETAILAPI then
	C_Spell = {
		GetSpellInfo = function(id)
			local s = SPELLINFO[id]
			if s then return { name = s[1], iconID = s[2] or 136000, originalIconID = s[2] or 136000, spellID = id } end
			if type(id) == "number" then return { name = "Spell " .. id, iconID = 136000, originalIconID = 136000, spellID = id } end
		end,
		GetSpellCooldown = function(id) return cdOf(id) end,
		GetSpellCharges = function(id) return nil end,
		GetSpellLink = function(id) return "|cff71d5ff|Hspell:" .. tostring(id) .. "|h[x]|h|r" end,
		IsSpellUsable = function() return true, false end,
		GetSpellName = function(id) local s = SPELLINFO[id]; return s and s[1] end,
		GetSpellTexture = function() return 136000 end,
	}
	C_SpellBook = {
		GetNumSpellBookSkillLines = function() return 1 end,
		GetSpellBookSkillLineInfo = function(i) return { itemIndexOffset = 0, numSpellBookItems = #SPELLBOOK, name = "General" } end,
		GetSpellBookItemName = function(j) local s = SPELLBOOK[j]; if s then return s.name, "" end end,
		GetSpellBookItemType = function(j) local s = SPELLBOOK[j]; if s then return 1, s.id end end,
		IsSpellKnown = function(id) return KNOWN[id] or false end,
		IsSpellKnownOrInSpellBook = function(id) return KNOWN[id] or false end,
		HasPetSpells = function() return nil end,
		GetSpellBookItemInfo = function() return nil end,
	}
	if FLAVOR == "retail" then
		-- retail 12.x still has the deprecated stub; Forever has nothing
		CombatLogGetCurrentEventInfo = function() return nil end
	end
	REFUSED_EVENTS["COMBAT_LOG_EVENT_UNFILTERED"] = true
else
	C_Spell = {
		GetSpellCooldown = function(id) return cdOf(id) end,
		GetSpellInfo = function(id) return nil end,
	}
	function GetSpellInfo(id)
		local s = SPELLINFO[id]
		if s then return s[1], "", s[2] or 136000, 0, 0, 0, id, s[2] or 136000 end
		if type(id) == "number" then return "Spell " .. id, "", 136000, 0, 0, 0, id, 136000 end
	end
	function GetSpellCooldown(id)
		local c = cdOf(id)
		return c.startTime, c.duration, c.isEnabled and 1 or 0, 1
	end
	function GetSpellCharges() return nil end
	function GetSpellLink(id) return "|cff71d5ff|Hspell:" .. tostring(id) .. "|h[x]|h|r" end
	function IsUsableSpell() return true, false end
	function IsSpellKnown(id) return KNOWN[id] or false end
	function IsSpellKnownOrOverridesKnown(id) return KNOWN[id] or false end
	function GetNumSpellTabs() return 1 end
	function GetSpellTabInfo(i) return "General", 136000, 0, #SPELLBOOK end
	function GetSpellBookItemName(j) local s = SPELLBOOK[j]; if s then return s.name, "", s.id end end
	function UnitAura() return nil end
	function UnitBuff() return nil end
	function UnitDebuff() return nil end
	function CombatLogGetCurrentEventInfo() return table.unpack(CLEU_ARGS or {}) end
	function GetItemSpell(id) return C_Item.GetItemSpell(id) end
	function GetItemInfoInstant(id) return C_Item.GetItemInfoInstant(id) end
	function GetItemCooldown(id) return C_Container.GetItemCooldown(id) end
	C_Container.GetItemCooldown = C_Container.GetItemCooldown
end
C_Engraving = (FLAVOR == "era") and { IsEngravingEnabled = function() return false end } or nil

---------------------------------------------------------------- loader
local ADDON = "CooldownTimeline3"
ADDON_NS = {}
local SRC = HARNESS_SRC
LOADED_FILES = {}
local function loadLua(path)
	local f, err = loadfile(path)
	if not f then
		errh("LOAD " .. path .. ": " .. tostring(err))
		return
	end
	LOADED_FILES[#LOADED_FILES + 1] = path
	xpcall(f, errh, ADDON, ADDON_NS)
end
STUB_FILES = {}  -- relative path (lowercase, forward slashes) -> function to run instead
local function norm(p) return (p:gsub("\\", "/")) end
local function loadXML(path)
	local x = HARNESS_READ(path)
	if not x then errh("missing xml " .. path); return end
	x = x:gsub("<!%-%-.-%-%->", "")
	local dir = path:match("^(.*)/[^/]*$") or "."
	for tag, file in x:gmatch("<(%a+)%s+file%s*=%s*\"([^\"]+)\"") do
		local p = dir .. "/" .. norm(file)
		if tag == "Script" then loadLua(p) elseif tag == "Include" then loadXML(p) end
	end
end
function LoadTOC(tocName)
	local t = HARNESS_READ(SRC .. "/" .. tocName)
	local files = {}
	for line in t:gmatch("[^\r\n]+") do
		if not line:match("^##") and line:match("%S") then
			files[#files + 1] = norm(line:match("^%s*(.-)%s*$"))
		end
	end
	for _, f in ipairs(files) do
		local stub = STUB_FILES[f:lower()]
		if stub then
			stub()
		elseif f:match("%.xml$") then
			loadXML(SRC .. "/" .. f)
		else
			loadLua(SRC .. "/" .. f)
		end
	end
	return files
end

-- LibEditMode stub (the real one needs Blizzard's EditModeManagerFrame; its licence forbids edits)
STUB_FILES["libs/libeditmode/embed.xml"] = function()
	local LEM = LibStub:NewLibrary("LibEditMode", 18)
	LEM.SettingType = setmetatable({}, { __index = function(_, k) return k end })
	LEM.frames, LEM.callbacks = {}, {}
	function LEM:AddFrame(frame, cb, default) self.frames[frame] = cb end
	function LEM:AddFrameSettings() end
	function LEM:AddFrameSettingsButtons() end
	function LEM:AddFrameSettingsButton() end
	function LEM:GetActiveLayoutName() return "Modern" end
	function LEM:IsInEditMode() return false end
	function LEM:RegisterCallback(ev, f) self.callbacks[ev] = f end
	LEM_STUB = LEM
end

-- nil global reads from the addon's own files (feature detection shows up here too)
MISSES = {}
function TrackMisses()
	setmetatable(_G, { __index = function(_, k)
		local info = debug.getinfo(2, "Sl")
		local src = info and info.source or "?"
		if not src:find("/Libs/") and not src:find("harness") and not src:find("wow.lua") then
			local key = tostring(k) .. " @" .. (src:match("[^/]+$") or src) .. ":" .. tostring(info and info.currentline)
			MISSES[key] = (MISSES[key] or 0) + 1
		end
		return nil
	end })
end

function Login()
	FireEvent("ADDON_LOADED", ADDON)
	LOGGED_IN = true
	FireEvent("PLAYER_LOGIN")
	FireEvent("PLAYER_ENTERING_WORLD", true, false)
end

function ReportErrors(label)
	print(string.format("[%s] lua errors: %d", label, #ERRORS))
end
