local _, ns = ...

-- Adds to the tooltip of a beast what a hunter wants to know before taming
-- it: how fast it attacks, its family, what it eats, and the abilities it
-- teaches. The tooltips of tamed pets show the beast they once were.

local L = ns.L
local DB = ns.DB
local Data = ns.Data

local Tooltip = {}
ns.Tooltip = Tooltip

local GRAY = '|cff909090'
local CONFIRMED = '|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t'

Tooltip.defaults = {
  enabled = true,
  -- Whose tooltip
  ownPet = true,
  otherPets = true,
  wildBeasts = true,
  -- What is shown
  attackSpeed = true,
  family = true,
  diet = true,
  dietIcons = false,
  stats = false,
  learnable = false,
  teaches = true,
  teachesOwnPet = false,
  teachesOtherPets = false,
  abilityIcons = true,
  -- Of the pets of others: the beast it was
  origin = true,
}

local function FormatPercent(value)
  if value > 0 then
    return '|cff40c040+' .. value .. '%|r'
  elseif value < 0 then
    return '|cffe04040' .. value .. '%|r'
  end

  return GRAY .. '0%|r'
end

local function FormatAbility(options, ability)
  local icon = options.abilityIcons and DB:GetAbilityIcon(ability)
  return (icon and ns.IconText(icon) .. ' ' or '') .. L[ability]
end

-- Returns the lines for a beast, as { left, right } pairs.
--   beast    A beast of the database, or nil for a creature it doesn't know
--   family   The key of its family
--   kind     'Creature' for a wild beast, 'Pet' for a tamed one
--   isOwn    Whether it's the player's pet
--   options  What to show, the player's options by default
function Tooltip:GetLines(beast, family, kind, isOwn, options)
  options = options or self.options
  local lines = {}
  local familyData = DB:GetFamily(family)

  if options.attackSpeed and beast ~= nil then
    local text = GRAY .. L['unknown'] .. '|r'

    if beast.speed ~= nil then
      local passive = DB:GetSpeedPassive(beast.speed)
      text = string.format('%.1f', beast.speed)

      if beast.speedSource == 'seen' then
        text = text .. GRAY .. ' (' .. L['in the wild'] .. ')|r'
      elseif passive ~= nil then
        text = text .. GRAY .. ' (' .. passive .. ')|r'
      end

      if beast.speedSource == 'tamed' then
        text = text .. ' ' .. CONFIRMED
      end
    end

    table.insert(lines, { L['Attack speed'], text })
  end

  if options.family and family ~= nil then
    table.insert(lines, { L['Family'], DB:GetFamilyName(family) })
  end

  if familyData ~= nil then
    if options.diet then
      local diet = {}

      for index, food in ipairs(familyData.diet) do
        diet[index] = options.dietIcons and ns.IconText(Data.dietIcons[food]) or L[food]
      end

      table.insert(lines, { L['Diet'], table.concat(diet, options.dietIcons and ' ' or ', ') })
    end

    if options.stats then
      table.insert(lines, {
        L['Family bonus'],
        string.format('%s %s  %s %s  %s %s', L['Damage'], FormatPercent(familyData.damage), L['Armor'],
                      FormatPercent(familyData.armor), L['Health'], FormatPercent(familyData.health)),
      })
    end

    if options.learnable then
      local abilities = {}

      for index, ability in ipairs(familyData.abilities) do
        abilities[index] = L[ability]
      end

      table.insert(lines, { L['Can learn'], table.concat(abilities, ', ') })
    end
  end

  local showsTeaches = options.teaches
  if kind == 'Pet' then
    showsTeaches = showsTeaches and ((isOwn and options.teachesOwnPet) or (not isOwn and options.teachesOtherPets))
  end

  if showsTeaches and beast ~= nil and beast.abilities ~= nil then
    for index, entry in ipairs(beast.abilities) do
      local text = FormatAbility(options, entry[1]) .. ' ' .. L['(Rank %d)']:format(entry[2])

      if beast.abilitiesConfirmed then
        text = text .. ' ' .. CONFIRMED
      end

      table.insert(lines, { index == 1 and L['Teaches'] or ' ', text })
    end
  end

  -- The beast a pet of someone else was, to go and tame the same
  if kind == 'Pet' and not isOwn and options.origin and beast ~= nil then
    local level = ns.ColorLevel(beast.minLevel)

    if beast.maxLevel > beast.minLevel then
      level = level .. ' - ' .. ns.ColorLevel(beast.maxLevel)
    end

    table.insert(lines, { L['Tamed from'], beast.name })
    table.insert(lines, { L['Level'], level })

    if beast.area ~= '' then
      table.insert(lines, { L['Zone'], beast.area })
    end
  end

  return lines
end

function Tooltip:_OnUnit(tooltip, data)
  local options = self.options

  if not options.enabled then
    return
  end

  -- The unit can be a secret in combat, the tooltip then stays as it is
  local _, unit = tooltip:GetUnit()
  if unit == nil or ns.IsSecret(unit) then
    return
  end

  local guid = type(data) == 'table' and data.guid or nil
  if guid == nil or ns.IsSecret(guid) then
    guid = ns.Read(UnitGUID, unit)
  end

  local npcId, kind = ns.ParseGuid(guid)
  if npcId == nil then
    return
  end

  local isOwn = false

  if kind == 'Pet' then
    -- Whose pet it is decides what is shown, a secret answer shows nothing
    local ok, same = pcall(UnitIsUnit, unit, 'pet')
    if not ok or ns.IsSecret(same) then
      return
    end

    isOwn = same and true or false
  end

  if kind == 'Creature' and not options.wildBeasts then
    return
  elseif kind == 'Pet' and ((isOwn and not options.ownPet) or (not isOwn and not options.otherPets)) then
    return
  end

  local family

  if kind == 'Creature' then
    family = ns.Learner:Observe(unit, npcId)

    -- With Beast Lore on the beast, its tooltip lists what it teaches
    if type(data) == 'table' then
      ns.Learner:ReadLore(npcId, family or (DB:GetBeast(npcId) or {}).family, data.lines)
    end
  else
    family = DB:GetFamilyKey(ns.Read(UnitCreatureFamily, unit))
  end

  local beast = DB:GetBeast(npcId)
  family = family or (beast and beast.family)

  -- Neither a known beast nor a creature of a pet family
  if family == nil then
    return
  end

  local lines = self:GetLines(beast, family, kind, isOwn)

  for _, line in ipairs(lines) do
    tooltip:AddDoubleLine(line[1], line[2], 1, 0.82, 0, 1, 1, 1)
  end

  if #lines > 0 then
    tooltip:Show()
  end
end

function Tooltip:Init(saved)
  saved.tooltip = saved.tooltip or {}
  self.options = saved.tooltip

  for key, value in pairs(self.defaults) do
    if self.options[key] == nil then
      self.options[key] = value
    end
  end

  local function OnUnit(tooltip, data)
    if tooltip ~= GameTooltip then
      return
    end

    -- A failure here must never break the game's tooltips
    local success, message = pcall(self._OnUnit, self, tooltip, data)
    if not success then
      geterrorhandler()(message)
    end
  end

  -- The modern client builds tooltips from data and rejects the legacy
  -- script, which is only hooked on clients without the data
  if _G.TooltipDataProcessor and _G.Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnit)
  else
    pcall(GameTooltip.HookScript, GameTooltip, 'OnTooltipSetUnit', OnUnit)
  end
end

-- Turns the tooltip information on or off, returns whether it's on
function Tooltip:Toggle()
  self.options.enabled = not self.options.enabled
  return self.options.enabled
end
