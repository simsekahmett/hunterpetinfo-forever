local _, ns = ...

-- Lookups over the beasts: those shipped with the addon (Data/Beasts.lua),
-- and what the Learner noted in game, which completes and corrects them.
--
-- A beast is returned as a table:
--   id, name, family          The NPC, its name and the key of its family
--   minLevel, maxLevel
--   areaId, area, x, y        Where it lives, 'area' is its zone's name
--   speed                     Seconds between attacks once tamed, nil if unknown
--   speedSource               'tamed' (read from a tamed pet), 'classic' (as
--                             it was in Classic) or 'seen' (of the wild beast)
--   abilities                 { { name, rank }, ... } it teaches, or nil
--   abilitiesConfirmed        Whether those were read in game, from a tamed
--                             pet or from Beast Lore
--   isLearned                 Whether the addon only knows it from the game
--   isNoted                   Whether anything of it was noted in game

local L = ns.L
local Data = ns.Data

local DB = {}
ns.DB = DB

-- Indices of the shipped rows
local NAME, FAMILY, MIN_LEVEL, MAX_LEVEL, AREA_ID, X, Y, SPEED, ABILITIES, AREA = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10

function DB:Init(saved)
  saved.learned = saved.learned or {}
  saved.familyNames = saved.familyNames or {}
  saved.abilityIcons = saved.abilityIcons or {}

  self.learned = saved.learned
  self.familyNames = saved.familyNames
  self.abilityIcons = saved.abilityIcons
  self.names = Data.beastNames or {}
  self.cache = {}
  self.ids = nil
end

------------------------------------------
-- Families
------------------------------------------

function DB:GetFamily(key)
  return key ~= nil and Data.families[key] or nil
end

function DB:GetFamilyName(key)
  return L[key]
end

-- Returns the families' keys, sorted by their name
function DB:GetFamilyKeys()
  if self.familyKeys == nil then
    self.familyKeys = {}

    for key in pairs(Data.families) do
      table.insert(self.familyKeys, key)
    end

    table.sort(self.familyKeys, function(a, b)
      return L[a] < L[b]
    end)
  end

  return self.familyKeys
end

-- Returns the key of a family from the name the client gives it, which is
-- localized
function DB:GetFamilyKey(name)
  if name == nil then
    return nil
  end

  if Data.families[name] ~= nil then
    return name
  elseif Data.familyAliases[name] ~= nil then
    return Data.familyAliases[name]
  elseif self.familyNames[name] ~= nil then
    return self.familyNames[name]
  end

  for key in pairs(Data.families) do
    if L[key] == name then
      return key
    end
  end

  return nil
end

-- Notes how the client calls a family
function DB:SetFamilyName(name, key)
  if Data.families[key] ~= nil and Data.families[name] == nil then
    self.familyNames[name] = key
  end
end

------------------------------------------
-- Abilities
------------------------------------------

function DB:GetAbilityIcon(ability)
  return Data.abilityIcons[ability] or self.abilityIcons[ability]
end

-- Returns every ability a beast can teach, sorted by name
function DB:GetAbilities()
  if self.abilityList == nil then
    local seen = {}
    self.abilityList = {}

    for _, family in pairs(Data.families) do
      for _, ability in ipairs(family.abilities) do
        if not seen[ability] then
          seen[ability] = true
          table.insert(self.abilityList, ability)
        end
      end
    end

    table.sort(self.abilityList, function(a, b)
      return L[a] < L[b]
    end)
  end

  return self.abilityList
end

-- Returns the passive that gives a pet an attack speed, as 'Faster Attack V'
function DB:GetSpeedPassive(speed)
  if speed == nil then
    return nil
  end

  for _, passive in ipairs(Data.speedPassives) do
    if math.abs(passive[1] - speed) < 0.05 then
      return L[passive[2]] .. ' ' .. passive[3]
    end
  end

  return nil
end

-- Returns whether a number of seconds is an attack speed a tamed pet can have
function DB:IsPetSpeed(speed)
  return math.abs(speed - 2) < 0.05 or self:GetSpeedPassive(speed) ~= nil
end

------------------------------------------
-- Beasts
------------------------------------------

local function ByName(a, b)
  return a[1] < b[1]
end

-- Returns the beast of an NPC, or nil if it's not known to be one
function DB:GetBeast(npcId)
  local beast = self.cache[npcId]

  if beast ~= nil then
    return beast
  end

  local row = Data.beasts[npcId]
  local note = self.learned[npcId]

  if row == nil and note == nil then
    return nil
  end

  beast = { id = npcId }

  if row ~= nil then
    beast.name = self.names[npcId] or row[NAME]
    beast.family = row[FAMILY]
    beast.minLevel, beast.maxLevel = row[MIN_LEVEL], row[MAX_LEVEL]
    beast.areaId, beast.x, beast.y = row[AREA_ID], row[X], row[Y]
    beast.area = row[AREA]

    if row[SPEED] > 0 then
      beast.speed, beast.speedSource = row[SPEED], 'classic'
    end

    if row[ABILITIES] ~= nil then
      beast.abilities = {}
      for index = 1, #row[ABILITIES], 2 do
        table.insert(beast.abilities, { row[ABILITIES][index], row[ABILITIES][index + 1] })
      end
    end
  else
    beast.isLearned = true
    beast.name = note.name or ('NPC ' .. npcId)
    beast.family = note.family
    beast.minLevel, beast.maxLevel = note.minLevel or 0, note.maxLevel or 0
    beast.areaId, beast.x, beast.y = 0, note.x or -1, note.y or -1
    beast.area = note.zone

    if note.seenSpeed ~= nil then
      beast.speed, beast.speedSource = note.seenSpeed, 'seen'
    end
  end

  -- What the game showed replaces what is assumed
  if note ~= nil then
    if note.speed ~= nil then
      beast.speed, beast.speedSource = note.speed, 'tamed'
    end

    if note.abilities ~= nil and next(note.abilities) ~= nil then
      beast.abilities = {}
      beast.abilitiesConfirmed = true

      for ability, rank in pairs(note.abilities) do
        table.insert(beast.abilities, { ability, rank })
      end
      table.sort(beast.abilities, ByName)
    end
  end

  if beast.areaId ~= nil and beast.areaId > 0 and C_Map and C_Map.GetAreaInfo then
    beast.area = C_Map.GetAreaInfo(beast.areaId) or beast.area
  end
  beast.area = beast.area or ''
  beast.isNoted = beast.isLearned or beast.abilitiesConfirmed or beast.speedSource == 'tamed' or false

  self.cache[npcId] = beast
  return beast
end

-- Returns the note the Learner keeps of an NPC, created if 'create' is set.
-- A note that is written to must be followed by a call to Invalidate.
function DB:GetNote(npcId, create)
  if self.learned[npcId] == nil and create then
    self.learned[npcId] = {}
  end

  return self.learned[npcId]
end

function DB:Invalidate(npcId)
  self.cache[npcId] = nil

  if Data.beasts[npcId] == nil then
    self.ids = nil
  end

  if self.onChange ~= nil then
    self.onChange()
  end
end

-- Returns the ID of every known beast
function DB:GetIds()
  if self.ids == nil then
    self.ids = {}

    for npcId in pairs(Data.beasts) do
      table.insert(self.ids, npcId)
    end

    for npcId in pairs(self.learned) do
      if Data.beasts[npcId] == nil then
        table.insert(self.ids, npcId)
      end
    end
  end

  return self.ids
end

function DB:GetCounts()
  local learned = 0

  for npcId in pairs(self.learned) do
    if Data.beasts[npcId] == nil then
      learned = learned + 1
    end
  end

  return #self:GetIds(), learned
end

-- Returns the rank of an ability a beast teaches, or nil
function DB:GetRank(beast, ability)
  if beast.abilities ~= nil then
    for _, entry in ipairs(beast.abilities) do
      if entry[1] == ability then
        return entry[2]
      end
    end
  end

  return nil
end

------------------------------------------
-- Search
------------------------------------------

-- The ways to sort a search, the unknown values last
local function Unknown(value, fallback)
  return value ~= nil and value or fallback
end

DB.sorts = {
  { key = 'name', text = 'Name' },
  { key = 'fast', text = 'Attack speed, fastest first', value = function(beast) return Unknown(beast.speed, 99) end },
  { key = 'slow', text = 'Attack speed, slowest first', value = function(beast) return -Unknown(beast.speed, -99) end },
  { key = 'low', text = 'Level, lowest first', value = function(beast) return beast.minLevel end },
  { key = 'high', text = 'Level, highest first', value = function(beast) return -beast.maxLevel end },
}

local function Matches(beast, words)
  local text = beast.searchText

  if text == nil then
    local parts = { beast.name, L[beast.family or ''], beast.area }

    if beast.abilities ~= nil then
      for _, entry in ipairs(beast.abilities) do
        table.insert(parts, L[entry[1]])
      end
    end

    text = ns.Lower(table.concat(parts, '\n'))
    beast.searchText = text
  end

  for _, word in ipairs(words) do
    if not text:find(word, 1, true) then
      return false
    end
  end

  return true
end

-- Returns the IDs of the beasts that pass a filter, sorted. Every field of
-- the filter is optional:
--   text      Words that must all be in the name, family, zone or abilities
--   family    The key of a family
--   ability   An ability the beast must teach
--   rank      The rank of that ability, or of any ability if none is given
--   maxSpeed  The slowest attack speed accepted
--   maxLevel  The highest level accepted
--   noted     Whether only the beasts something was noted of in game pass
--   sort      A key of DB.sorts
function DB:Search(filter)
  local words = {}

  for word in ns.Lower(filter.text or ''):gmatch('%S+') do
    table.insert(words, word)
  end

  local results = {}

  for _, npcId in ipairs(self:GetIds()) do
    local beast = self:GetBeast(npcId)
    local isMatch = true

    if filter.family ~= nil and beast.family ~= filter.family then
      isMatch = false
    elseif filter.maxSpeed ~= nil and (beast.speed == nil or beast.speed > filter.maxSpeed + 0.001) then
      isMatch = false
    elseif filter.maxLevel ~= nil and beast.minLevel > filter.maxLevel then
      isMatch = false
    elseif filter.noted and not beast.isNoted then
      isMatch = false
    elseif filter.ability ~= nil then
      local rank = self:GetRank(beast, filter.ability)
      isMatch = rank ~= nil and (filter.rank == nil or rank == filter.rank)
    elseif filter.rank ~= nil then
      isMatch = false

      for _, entry in ipairs(beast.abilities or {}) do
        if entry[2] == filter.rank then
          isMatch = true
        end
      end
    end

    if isMatch and (#words == 0 or Matches(beast, words)) then
      table.insert(results, npcId)
    end
  end

  local sort

  for _, candidate in ipairs(self.sorts) do
    if candidate.key == filter.sort then
      sort = candidate.value
    end
  end

  table.sort(results, function(a, b)
    local beastA, beastB = self:GetBeast(a), self:GetBeast(b)

    if sort ~= nil then
      local valueA, valueB = sort(beastA), sort(beastB)

      if valueA ~= valueB then
        return valueA < valueB
      end
    end

    if beastA.name ~= beastB.name then
      return beastA.name < beastB.name
    end

    return a < b
  end)

  return results
end
