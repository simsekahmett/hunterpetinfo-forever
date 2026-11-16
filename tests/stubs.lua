-- Minimal WoW API for the offline harness
NOW = 1000
local frames, timers, events = {}, {}, {}
local function noop() end

local methods = {}
local widgetMeta = { __index = function(_, k) return methods[k] or (type(k) == 'string' and k:match('^%u') and noop) or nil end }
local function widget(kind)
  return setmetatable({ kind = kind, scripts = {}, shown = true, text = '', value = 0 }, widgetMeta)
end
function methods:SetScript(n, f) self.scripts[n] = f end
function methods:GetScript(n) return self.scripts[n] end
function methods:HookScript(n, f) local o = self.scripts[n]; self.scripts[n] = function(...) if o then o(...) end f(...) end end
function methods:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown = false end
function methods:SetShown(s) if s then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:SetText(t) self.text = t end
function methods:GetText() return self.text end
function methods:SetChecked(c) self.checked = c end
function methods:GetChecked() return self.checked end
function methods:GetStringWidth() return 100 end
function methods:CreateTexture() return widget('Texture') end
function methods:CreateFontString() return widget('FontString') end
function methods:RegisterEvent(e) events[e] = events[e] or {}; events[e][self] = true end
function methods:SetValue(v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end
function methods:GetWidth() return 140 end
function methods:GetCenter() return 0, 0 end
function methods:GetEffectiveScale() return 1 end
function methods:IsOwned() return false end

function CreateFrame(kind, name)
  local f = widget(kind)
  frames[#frames + 1] = f
  if name then _G[name] = f end
  return f
end
UIParent, Minimap, GameTooltip = widget('Frame'), widget('Frame'), widget('GameTooltip')
BackdropTemplateMixin = {}
UISpecialFrames, SlashCmdList = {}, {}
CHATLOG = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) CHATLOG[#CHATLOG + 1] = m end }

function GetLocale() return TEST_LOCALE or 'enUS' end
function GetTime() return NOW end
function InCombatLockdown() return COMBAT or false end
function IsModifiedClick() return false end
function geterrorhandler() return function(m) error(m, 0) end end
function GetCursorPosition() return 10, 10 end
function GetRealZoneText() return 'Zephras Isle' end
function GetCreatureDifficultyColor() return { r = 1, g = 1, b = 0 } end
function strsplit(sep, s) local out = {}; for part in (s .. sep):gmatch('(.-)' .. sep) do out[#out + 1] = part end; return unpack(out) end
C_Timer = { After = function(d, f) timers[#timers + 1] = { at = NOW + d, f = f } end }
C_Map = { GetAreaInfo = function(id) return 'Zone' .. id end, GetBestMapForUnit = function() return 1 end,
  GetPlayerMapPosition = function() return { GetXY = function() return 0.512, 0.25 end } end }
C_AddOns = { GetAddOnMetadata = function() return 'v0.0.0' end }
Settings = { RegisterCanvasLayoutCategory = function() return { GetID = function() return 7 end } end,
  RegisterAddOnCategory = noop, OpenToCategory = function(id) OPENED_SETTINGS = id end }

-- Secrets: a value addons cannot inspect
SECRET = setmetatable({}, { __eq = function() error('secret compared') end, __concat = function() error('secret concatenated') end })
function issecretvalue(v) return rawequal(v, SECRET) end

-- Units
UNITS = {}
local function unit(u) return UNITS[u] or {} end
function UnitGUID(u) return unit(u).guid end
function UnitName(u) return unit(u).name end
function UnitLevel(u) if u == 'player' then return PLAYER_LEVEL or 30 end return unit(u).level end
function UnitCreatureFamily(u) return unit(u).family end
function UnitAttackSpeed(u) return unit(u).speed end
function UnitPlayerControlled(u) return unit(u).controlled or false end
function UnitIsUnit(a, b) return UNITS[a] ~= nil and UNITS[a] == UNITS[b] end

-- The pet's spellbook
PET_SPELLS = {}
Enum = { TooltipDataType = { Unit = 2 }, SpellBookSpellBank = { Player = 0, Pet = 1 } }
C_SpellBook = {
  HasPetSpells = function() return #PET_SPELLS end,
  GetSpellBookItemName = function(i) return PET_SPELLS[i][1], PET_SPELLS[i][2] end,
  GetSpellBookItemTexture = function(i) return 4000 + i end,
  IsSpellBookItemPassive = function(i) return PET_SPELLS[i][3] or false end,
}

function FireEvent(e, ...)
  for f in pairs(events[e] or {}) do if f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end
end
function Tick(dt)
  NOW = NOW + dt
  for i = #timers, 1, -1 do
    if timers[i].at <= NOW then local t = table.remove(timers, i); t.f() end
  end
end

-- Tooltip pipeline
TOOLTIP_CALLS = {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, f) assert(kind == 2); TOOLTIP_CALLS[#TOOLTIP_CALLS + 1] = f end }
TIP = {}
function GameTooltip:AddLine(text) TIP[#TIP + 1] = text end
function GameTooltip:AddDoubleLine(left, right) TIP[#TIP + 1] = left .. ' | ' .. right end
function GameTooltip:GetUnit() return 'x', TIP_UNIT end
-- Shows the tooltip of a unit, returns the lines the addon added
function Hover(u, data)
  TIP = {}
  TIP_UNIT = u
  UNITS.mouseover = UNITS[u]
  for _, f in ipairs(TOOLTIP_CALLS) do f(GameTooltip, data or { guid = UnitGUID(u) }) end
  return TIP
end
