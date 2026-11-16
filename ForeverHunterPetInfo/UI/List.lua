local _, ns = ...

-- A scrolling list of beasts that only creates the rows that fit on screen.
-- Each row shows a beast's family icon, name and attack speed, its level and
-- zone, and the abilities it teaches. Hovering a row shows everything known
-- of the beast.

local L = ns.L
local DB = ns.DB

local List = {}
List.__index = List
ns.List = List

local GRAY = '|cff909090'
local ROW_HEIGHT = 44

-- Everything is shown in the tooltip of a row, whatever the player's options
local everything = {
  attackSpeed = true,
  family = true,
  diet = true,
  stats = true,
  learnable = true,
  teaches = true,
  abilityIcons = true,
}

local function FormatLevel(beast)
  local level = ns.ColorLevel(beast.minLevel)

  if beast.maxLevel > beast.minLevel then
    level = level .. '-' .. ns.ColorLevel(beast.maxLevel)
  end

  return level
end

local function FormatPlace(beast)
  local place = beast.area

  if beast.x ~= nil and beast.x >= 0 then
    place = place .. string.format(' (%.0f, %.0f)', beast.x, beast.y)
  end

  return place
end

local function ShowTooltip(row)
  local beast = row.beast

  if beast == nil then
    return
  end

  GameTooltip:SetOwner(row, 'ANCHOR_RIGHT')
  GameTooltip:SetText(beast.name)
  GameTooltip:AddDoubleLine(L['Level'], FormatLevel(beast), 1, 0.82, 0, 1, 1, 1)

  if beast.area ~= '' then
    GameTooltip:AddDoubleLine(L['Zone'], FormatPlace(beast), 1, 0.82, 0, 1, 1, 1)
  end

  for _, line in ipairs(ns.Tooltip:GetLines(beast, beast.family, 'Creature', false, everything)) do
    GameTooltip:AddDoubleLine(line[1], line[2], 1, 0.82, 0, 1, 1, 1)
  end

  if beast.isLearned then
    GameTooltip:AddLine(L['Seen in game, not part of the shipped data.'], 0.6, 0.6, 0.6, true)
  elseif not beast.abilitiesConfirmed and beast.abilities ~= nil then
    GameTooltip:AddLine(L['Abilities as in Classic, confirmed with Beast Lore or once you tame it.'], 0.6, 0.6, 0.6, true)
  end

  GameTooltip:Show()
end

-- Creates a list of a fixed size
function List.New(parent, width, height)
  local self = setmetatable({}, List)

  self.ids = {}
  self.offset = 0
  self.rows = {}
  self.visible = math.floor(height / ROW_HEIGHT)

  local frame = CreateFrame('Frame', nil, parent)
  frame:SetSize(width, height)
  frame:EnableMouseWheel(true)
  frame:SetScript('OnMouseWheel', function(_, delta)
    self:SetOffset(self.offset - delta * 2)
  end)
  self.frame = frame

  local background = frame:CreateTexture(nil, 'BACKGROUND')
  background:SetAllPoints()
  background:SetColorTexture(0, 0, 0, 0.35)

  local slider = CreateFrame('Slider', nil, frame)
  slider:SetOrientation('VERTICAL')
  slider:SetPoint('TOPRIGHT', -1, -1)
  slider:SetPoint('BOTTOMRIGHT', -1, 1)
  slider:SetWidth(8)
  slider:SetMinMaxValues(0, 0)
  slider:SetValueStep(1)
  slider:SetValue(0)

  local track = slider:CreateTexture(nil, 'BACKGROUND')
  track:SetAllPoints()
  track:SetColorTexture(1, 1, 1, 0.05)

  local thumb = slider:CreateTexture(nil, 'OVERLAY')
  thumb:SetColorTexture(0.67, 0.83, 0.45, 0.8)
  thumb:SetSize(8, 32)
  slider:SetThumbTexture(thumb)

  slider:SetScript('OnValueChanged', function(_, value)
    self:SetOffset(math.floor(value + 0.5), true)
  end)
  slider:Hide()
  self.slider = slider

  for index = 1, self.visible do
    self.rows[index] = self:_CreateRow(index, width - 12)
  end

  return self
end

function List:_CreateRow(index, width)
  local row = CreateFrame('Button', nil, self.frame)
  row:SetSize(width, ROW_HEIGHT)
  row:SetPoint('TOPLEFT', 2, -(index - 1) * ROW_HEIGHT)
  row:RegisterForClicks('LeftButtonUp')

  local highlight = row:CreateTexture(nil, 'HIGHLIGHT')
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 0.1)

  -- Every other row is a shade darker
  if index % 2 == 0 then
    local stripe = row:CreateTexture(nil, 'BACKGROUND')
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, 0.03)
  end

  row.icon = row:CreateTexture(nil, 'ARTWORK')
  row.icon:SetSize(34, 34)
  row.icon:SetPoint('LEFT', 4, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  row.speed = row:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
  row.speed:SetPoint('TOPRIGHT', -4, -4)
  row.speed:SetJustifyH('RIGHT')

  row.name = row:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
  row.name:SetPoint('TOPLEFT', row.icon, 'TOPRIGHT', 6, 1)
  row.name:SetPoint('RIGHT', row.speed, 'LEFT', -4, 0)
  row.name:SetJustifyH('LEFT')
  row.name:SetWordWrap(false)

  row.place = row:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  row.place:SetPoint('TOPLEFT', row.name, 'BOTTOMLEFT', 0, -2)
  row.place:SetPoint('RIGHT', -4, 0)
  row.place:SetJustifyH('LEFT')
  row.place:SetWordWrap(false)

  row.abilities = row:CreateFontString(nil, 'ARTWORK', 'GameFontDisableSmall')
  row.abilities:SetPoint('TOPLEFT', row.place, 'BOTTOMLEFT', 0, -2)
  row.abilities:SetPoint('RIGHT', -4, 0)
  row.abilities:SetJustifyH('LEFT')
  row.abilities:SetWordWrap(false)

  row:SetScript('OnEnter', ShowTooltip)
  row:SetScript('OnLeave', function()
    GameTooltip:Hide()
  end)

  -- A shift-click writes the beast's name in the chat, as elsewhere in the game
  row:SetScript('OnClick', function()
    local beast = row.beast

    if beast == nil or not IsModifiedClick('CHATLINK') then
      return
    end

    local text = beast.name .. (beast.area ~= '' and (' - ' .. FormatPlace(beast)) or '')

    if _G.ChatFrameUtil and _G.ChatFrameUtil.InsertLink then
      _G.ChatFrameUtil.InsertLink(text)
    elseif _G.ChatEdit_InsertLink then
      _G.ChatEdit_InsertLink(text)
    end
  end)

  return row
end

-- Sets the beasts listed, as NPC IDs. The scroll position is kept if
-- 'keepOffset' is set.
function List:SetIds(ids, keepOffset)
  self.ids = ids

  local maxOffset = math.max(0, #ids - self.visible)
  self.slider:SetMinMaxValues(0, maxOffset)
  self.slider:SetShown(maxOffset > 0)
  self:SetOffset(keepOffset and self.offset or 0)
end

function List:SetOffset(offset, fromSlider)
  offset = math.max(0, math.min(offset, math.max(0, #self.ids - self.visible)))
  self.offset = offset

  if not fromSlider then
    self.slider:SetValue(offset)
  end

  self:Refresh()
end

-- Returns the texts of a row, which the tests read as well
function List.Describe(beast)
  local family = DB:GetFamily(beast.family)
  local speed = GRAY .. '?|r'

  if beast.speed ~= nil then
    speed = string.format('%.1f', beast.speed)

    if beast.speedSource == 'seen' then
      speed = GRAY .. speed .. '|r'
    end
  end

  local abilities = {}
  for index, entry in ipairs(beast.abilities or {}) do
    abilities[index] = L[entry[1]] .. ' ' .. entry[2]
  end

  local place = FormatLevel(beast) .. '  ' .. DB:GetFamilyName(beast.family or '')
  if beast.area ~= '' then
    place = place .. GRAY .. '  -  ' .. FormatPlace(beast) .. '|r'
  end

  return {
    icon = family and family.icon or 134400,
    name = beast.name,
    speed = speed,
    place = place,
    abilities = table.concat(abilities, ', '),
  }
end

function List:Refresh()
  for index = 1, self.visible do
    local row = self.rows[index]
    local npcId = self.ids[self.offset + index]
    local beast = npcId and DB:GetBeast(npcId)

    row.beast = beast

    if beast == nil then
      row:Hide()
    else
      local texts = List.Describe(beast)

      row.icon:SetTexture(texts.icon)
      row.name:SetText(texts.name)
      row.speed:SetText(texts.speed)
      row.place:SetText(texts.place)
      row.abilities:SetText(texts.abilities)

      -- The abilities read from a tamed pet stand out from the assumed ones
      if beast.abilitiesConfirmed then
        row.abilities:SetTextColor(0.4, 0.85, 0.4)
      else
        row.abilities:SetTextColor(0.6, 0.6, 0.6)
      end

      row:Show()

      if GameTooltip:IsOwned(row) then
        ShowTooltip(row)
      end
    end
  end
end
