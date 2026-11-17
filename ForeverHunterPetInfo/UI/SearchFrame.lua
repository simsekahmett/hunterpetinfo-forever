local _, ns = ...

-- The beast list: a search box and filters above the beasts that pass them.
-- A beast can be looked for by its name, family, zone or abilities, by the
-- rank of an ability, and by how fast it attacks.

local L = ns.L
local DB = ns.DB
local List = ns.List

local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 440, 560
local PADDING = 12
local LIST_TOP, LIST_BOTTOM = 144, 34

-- Creates a check box without a template, those differ between clients
function ns.CreateCheckBox(parent, text, onClick)
  local check = CreateFrame('CheckButton', nil, parent)
  check:SetSize(24, 24)
  check:SetNormalTexture('Interface\\Buttons\\UI-CheckBox-Up')
  check:SetPushedTexture('Interface\\Buttons\\UI-CheckBox-Down')
  check:SetHighlightTexture('Interface\\Buttons\\UI-CheckBox-Highlight', 'ADD')
  check:SetCheckedTexture('Interface\\Buttons\\UI-CheckBox-Check')

  check.label = check:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
  check.label:SetPoint('LEFT', check, 'RIGHT', 2, 1)
  check.label:SetText(text)
  check:SetHitRectInsets(0, -check.label:GetStringWidth() - 4, 0, 0)

  check:SetScript('OnClick', function()
    onClick(check:GetChecked() and true or false)
  end)

  return check
end

local function CreateLabel(parent, text)
  local label = parent:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
  label:SetText(text)
  return label
end

local function CreateEditBox(parent, width, onChange)
  local editBox = CreateFrame('EditBox', nil, parent, 'InputBoxTemplate')
  editBox:SetSize(width, 20)
  editBox:SetAutoFocus(false)
  editBox:SetScript('OnEscapePressed', editBox.ClearFocus)
  editBox:SetScript('OnEnterPressed', editBox.ClearFocus)
  editBox:SetScript('OnTextChanged', function(_, isUserInput)
    if isUserInput then
      onChange()
    end
  end)

  return editBox
end

-- Creates a button that picks one of several choices from a menu.
-- 'getChoices' returns them as { value, text } pairs, the value false stands
-- for no choice.
function UI:_CreatePicker(parent, width, title, getChoices, getValue, setValue)
  local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
  button:SetSize(width, 22)

  local function Update()
    local value = getValue() or false

    for _, choice in ipairs(getChoices()) do
      if choice[1] == value then
        button:SetText(title .. ': ' .. choice[2])
      end
    end
  end

  local function Pick(value)
    setValue(value or nil)
    Update()
    self:Refresh()
  end

  button:SetScript('OnClick', function()
    local choices = getChoices()

    if _G.MenuUtil and MenuUtil.CreateContextMenu then
      MenuUtil.CreateContextMenu(button, function(_, root)
        for _, choice in ipairs(choices) do
          root:CreateRadio(choice[2], function(value)
            return (getValue() or false) == value
          end, Pick, choice[1])
        end
      end)
      return
    end

    -- Without menus, a click moves on to the next choice
    local value = getValue() or false

    for index, choice in ipairs(choices) do
      if choice[1] == value then
        Pick(choices[index % #choices + 1][1])
        return
      end
    end

    Pick(choices[1][1])
  end)

  button.Update = Update
  Update()

  return button
end

function UI:_Create()
  local frame = CreateFrame('Frame', 'ForeverHunterPetInfoFrame', UIParent,
                            _G.BackdropTemplateMixin and 'BackdropTemplate' or nil)
  self.frame = frame

  frame:SetSize(WIDTH, HEIGHT)
  frame:SetPoint('CENTER')
  frame:SetFrameStrata('HIGH')
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag('LeftButton')
  frame:SetScript('OnDragStart', frame.StartMoving)
  frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
  frame:Hide()

  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = 'Interface\\Buttons\\WHITE8x8',
      edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
      edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.04, 0.05, 0.04, 0.95)
    frame:SetBackdropBorderColor(0.67, 0.83, 0.45, 0.9)
  end

  -- Escape closes the window
  table.insert(UISpecialFrames, 'ForeverHunterPetInfoFrame')

  local icon = frame:CreateTexture(nil, 'ARTWORK')
  icon:SetSize(26, 26)
  icon:SetPoint('TOPLEFT', PADDING, -7)
  icon:SetTexture(ns.LOGO)

  local title = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
  title:SetPoint('LEFT', icon, 'RIGHT', 6, 0)
  title:SetText(ns.TITLE)

  local close = CreateFrame('Button', nil, frame, 'UIPanelCloseButton')
  close:SetPoint('TOPRIGHT', -2, -2)

  local function OnChange()
    self:Refresh()
  end

  -- First row: what is typed
  local searchLabel = CreateLabel(frame, L['Search'])
  searchLabel:SetPoint('TOPLEFT', PADDING, -44)

  self.searchBox = CreateEditBox(frame, 150, OnChange)
  self.searchBox:SetPoint('LEFT', searchLabel, 'RIGHT', 10, 0)

  local speedLabel = CreateLabel(frame, L['Max. speed'])
  speedLabel:SetPoint('LEFT', self.searchBox, 'RIGHT', 12, 0)

  self.speedBox = CreateEditBox(frame, 34, OnChange)
  self.speedBox:SetPoint('LEFT', speedLabel, 'RIGHT', 10, 0)
  self.speedBox:SetMaxLetters(4)

  local rankLabel = CreateLabel(frame, L['Rank'])
  rankLabel:SetPoint('LEFT', self.speedBox, 'RIGHT', 12, 0)

  self.rankBox = CreateEditBox(frame, 24, OnChange)
  self.rankBox:SetPoint('LEFT', rankLabel, 'RIGHT', 10, 0)
  self.rankBox:SetMaxLetters(2)

  -- Second row: what is picked
  self.filter = { sort = 'name' }

  local pickerWidth = (WIDTH - PADDING * 2 - 8) / 3

  self.familyPicker = self:_CreatePicker(frame, pickerWidth, L['Family'], function()
    local choices = { { false, L['All'] } }

    for _, key in ipairs(DB:GetFamilyKeys()) do
      table.insert(choices, { key, DB:GetFamilyName(key) })
    end

    return choices
  end, function()
    return self.filter.family
  end, function(value)
    self.filter.family = value
  end)
  self.familyPicker:SetPoint('TOPLEFT', PADDING, -66)

  self.abilityPicker = self:_CreatePicker(frame, pickerWidth, L['Teaches'], function()
    local choices = { { false, L['Anything'] } }

    for _, ability in ipairs(DB:GetAbilities()) do
      table.insert(choices, { ability, L[ability] })
    end

    return choices
  end, function()
    return self.filter.ability
  end, function(value)
    self.filter.ability = value
  end)
  self.abilityPicker:SetPoint('LEFT', self.familyPicker, 'RIGHT', 4, 0)

  self.sortPicker = self:_CreatePicker(frame, pickerWidth, L['Sort'], function()
    local choices = {}

    for _, sort in ipairs(DB.sorts) do
      table.insert(choices, { sort.key, L[sort.text] })
    end

    return choices
  end, function()
    return self.filter.sort
  end, function(value)
    self.filter.sort = value or 'name'
  end)
  self.sortPicker:SetPoint('LEFT', self.abilityPicker, 'RIGHT', 4, 0)

  -- Third row: a beast above the hunter's level cannot be tamed
  self.levelCheck = ns.CreateCheckBox(frame, L['Only beasts I can tame at my level'], function(isChecked)
    self.onlyTameable = isChecked
    self:Refresh()
  end)
  self.levelCheck:SetPoint('TOPLEFT', PADDING - 4, -92)

  self.rareCheck = ns.CreateCheckBox(frame, L['Rare only'], function(isChecked)
    self.filter.rare = isChecked or nil
    self:Refresh()
  end)
  self.rareCheck:SetPoint('TOPLEFT', 254, -92)

  -- Fourth row: what the addon picked up in game
  self.notedCheck = ns.CreateCheckBox(frame, L['Only what was noted in game: new beasts and confirmed abilities'],
                                      function(isChecked)
    self.filter.noted = isChecked or nil
    self:Refresh()
  end)
  self.notedCheck:SetPoint('TOPLEFT', PADDING - 4, -114)

  local reset = CreateFrame('Button', nil, frame, 'UIPanelButtonTemplate')
  reset:SetSize(70, 22)
  reset:SetPoint('TOPRIGHT', -PADDING, -93)
  reset:SetText(L['Reset'])
  reset:SetScript('OnClick', function()
    self:Reset()
  end)

  self.list = List.New(frame, WIDTH - PADDING * 2, HEIGHT - LIST_TOP - LIST_BOTTOM)
  self.list.frame:SetPoint('TOPLEFT', PADDING, -LIST_TOP)

  local status = frame:CreateFontString(nil, 'ARTWORK', 'GameFontDisableSmall')
  status:SetPoint('BOTTOMLEFT', PADDING, 12)
  status:SetPoint('BOTTOMRIGHT', -PADDING, 12)
  status:SetJustifyH('LEFT')
  self.status = status

  frame:SetScript('OnShow', function()
    self:Refresh()
  end)

  -- A beast noted whilst the window is open shows up in it
  DB.onChange = function()
    if frame:IsShown() then
      self:Refresh(true)
    end
  end
end

-- Lists the beasts that pass the filters. The scroll position is kept if
-- 'keepOffset' is set.
function UI:Refresh(keepOffset)
  local filter = self.filter

  filter.text = self.searchBox:GetText()
  filter.maxSpeed = tonumber((self.speedBox:GetText():gsub(',', '.')))
  filter.rank = tonumber(self.rankBox:GetText())
  filter.maxLevel = self.onlyTameable and UnitLevel('player') or nil

  self.results = DB:Search(filter)
  self.list:SetIds(self.results, keepOffset)

  local total, learned = DB:GetCounts()
  local text = L['%d of %d beasts']:format(#self.results, total)

  if learned > 0 then
    text = text .. ', ' .. L['%d seen in game']:format(learned)
  end

  self.status:SetText(text)
end

function UI:Reset()
  self.filter = { sort = 'name' }
  self.onlyTameable = false

  self.searchBox:SetText('')
  self.speedBox:SetText('')
  self.rankBox:SetText('')
  self.levelCheck:SetChecked(false)
  self.notedCheck:SetChecked(false)
  self.rareCheck:SetChecked(false)
  self.familyPicker.Update()
  self.abilityPicker.Update()
  self.sortPicker.Update()

  self:Refresh()
end

-- Opens the window, searching for a text if one is given
function UI:Open(text)
  if self.frame == nil then
    self:_Create()
  end

  if text ~= nil then
    self.searchBox:SetText(text)
  end

  if self.frame:IsShown() then
    self:Refresh()
  else
    self.frame:Show()
  end
end

function UI:Toggle()
  if self.frame ~= nil and self.frame:IsShown() then
    self.frame:Hide()
  else
    self:Open()
  end
end
