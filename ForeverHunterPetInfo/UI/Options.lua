local _, ns = ...

-- The options, a page of the game's own settings: whose tooltip gets the
-- information, and which parts of it.

local L = ns.L

local Options = {}
ns.Options = Options

-- { option of the tooltip, text, indentation }, a string is a section title
local layout = {
  { 'enabled', 'Add information to the tooltips of beasts' },
  'Whose tooltip',
  { 'wildBeasts', 'Wild beasts' },
  { 'ownPet', 'My pet' },
  { 'otherPets', 'Pets of other hunters' },
  'What is shown',
  { 'attackSpeed', 'Attack speed, and the passive that gives it' },
  { 'family', 'Family' },
  { 'diet', 'Diet' },
  { 'dietIcons', 'As icons', 1 },
  { 'stats', "The family's damage, armor and health bonus" },
  { 'learnable', 'The abilities the family can learn' },
  { 'teaches', 'The abilities the beast teaches' },
  { 'abilityIcons', 'With their icons', 1 },
  { 'teachesOwnPet', 'On my pet as well', 1 },
  { 'teachesOtherPets', 'On the pets of other hunters as well', 1 },
  { 'origin', 'The beast a pet of another hunter was tamed from, with its level and zone' },
}

function Options:Init(saved)
  local options = ns.Tooltip.options

  saved.minimap = saved.minimap or {}

  local panel = CreateFrame('Frame', 'ForeverHunterPetInfoOptions', UIParent)
  panel:Hide()
  self.panel = panel
  self.checks = {}

  local title = panel:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
  title:SetPoint('TOPLEFT', 16, -16)
  title:SetText(ns.TITLE)

  local version = panel:CreateFontString(nil, 'ARTWORK', 'GameFontDisableSmall')
  version:SetPoint('LEFT', title, 'RIGHT', 8, 0)
  -- A copy that was not packaged has a placeholder for a version
  local versionText = C_AddOns and C_AddOns.GetAddOnMetadata(ns.ADDON, 'Version') or ''
  version:SetText(versionText:find('@', 1, true) and 'dev' or versionText)

  local top = -48

  for _, entry in ipairs(layout) do
    if type(entry) == 'string' then
      local header = panel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
      header:SetPoint('TOPLEFT', 16, top - 10)
      header:SetText(L[entry])
      top = top - 30
    else
      local key = entry[1]
      local check = ns.CreateCheckBox(panel, L[entry[2]], function(isChecked)
        options[key] = isChecked
      end)

      check.label:SetFontObject('GameFontHighlight')
      check:SetPoint('TOPLEFT', 14 + (entry[3] or 0) * 22, top)
      self.checks[key] = check
      top = top - 24
    end
  end

  local minimap = ns.CreateCheckBox(panel, L['Show the minimap button'], function(isChecked)
    if isChecked == saved.minimap.hide then
      ns.MinimapButton:Toggle()
    end
  end)
  minimap.label:SetFontObject('GameFontHighlight')
  minimap:SetPoint('TOPLEFT', 14, top - 12)
  self.minimapCheck = minimap

  local announce = ns.CreateCheckBox(panel, L['Tell me in the chat when a new beast or an ability is noted'],
                                     function(isChecked)
    ns.Learner.options.announce = isChecked
  end)
  announce.label:SetFontObject('GameFontHighlight')
  announce:SetPoint('TOPLEFT', 14, top - 36)

  local note = panel:CreateFontString(nil, 'ARTWORK', 'GameFontDisableSmall')
  note:SetPoint('TOPLEFT', 18, top - 70)
  note:SetWidth(560)
  note:SetJustifyH('LEFT')
  note:SetText(L['Attack speeds and abilities are those of Classic until the game shows otherwise. Beasts near you that are not in the data are noted. Cast Beast Lore on a beast and hover it, or tame it, and what it teaches is noted and marked as confirmed.'])

  panel:SetScript('OnShow', function()
    for key, check in pairs(self.checks) do
      check:SetChecked(options[key])
    end

    minimap:SetChecked(not saved.minimap.hide)
    announce:SetChecked(ns.Learner.options.announce)
  end)

  if _G.Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
    Settings.RegisterAddOnCategory(category)
    self.category = category
  end
end

function Options:Open()
  if self.category == nil then
    return
  end

  -- The settings are a protected panel, the game refuses to open them in combat
  if InCombatLockdown() then
    ns.Print(L['The options cannot be opened in combat.'])
    return
  end

  Settings.OpenToCategory(self.category:GetID())
end
