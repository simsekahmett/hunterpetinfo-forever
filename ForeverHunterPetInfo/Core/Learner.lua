local _, ns = ...

-- Notes what the game shows of beasts, in the saved variables:
--
--   * how the client calls a family, from the beasts that are shipped, so
--     that the families are recognized in every language,
--   * the beasts that are not shipped, when they are hovered, targeted or
--     when their nameplate appears: their name, family, level, zone and
--     where the player stood,
--   * what a beast teaches, read from its tooltip once Beast Lore is cast on
--     it, which lists its abilities,
--   * what a beast really teaches and how fast it attacks, read from the pet
--     right after it was tamed, before anything else was taught to it.
--
-- Nothing is noted from a secret value, so it mostly happens out of combat.

local DB = ns.DB
local Data = ns.Data

local Learner = {}
ns.Learner = Learner

local TAME_BEAST = 1515
-- How long after Tame Beast was cast a new pet is taken for its result. The
-- taming takes 20 seconds.
local TAME_WINDOW = 40
-- The pet's spellbook fills up a moment after the pet appears
local SCAN_DELAY = 1.5

Learner.defaults = {
  -- Whether what is noted is told in the chat
  announce = true,
}

function Learner:Init(saved)
  saved.learner = saved.learner or {}
  self.options = saved.learner

  for key, value in pairs(self.defaults) do
    if self.options[key] == nil then
      self.options[key] = value
    end
  end

  self.seen = {}

  -- The beasts around the player: those whose nameplate appears, and the target
  ns.On('NAME_PLATE_UNIT_ADDED', function(unit)
    self:_OnUnit(unit)
  end)
  ns.On('PLAYER_TARGET_CHANGED', function()
    self:_OnUnit('target')
  end)

  ns.On('UNIT_SPELLCAST_SUCCEEDED', function(unit, _, spellId)
    self:_OnSpellCast(unit, spellId)
  end)
  ns.On('UNIT_SPELLCAST_CHANNEL_START', function(unit, _, spellId)
    self:_OnSpellCast(unit, spellId)
  end)
  ns.On('UNIT_PET', function(unit)
    if unit == 'player' then
      self:_OnPetChanged()
    end
  end)
end

------------------------------------------
-- Wild beasts
------------------------------------------

local function FormatAbilities(abilities)
  local texts = {}

  for ability, rank in pairs(abilities) do
    table.insert(texts, ns.L[ability] .. ' ' .. ns.L['(Rank %d)']:format(rank))
  end

  table.sort(texts)
  return table.concat(texts, ', ')
end

function Learner:_Announce(text)
  if self.options.announce then
    ns.Print(text)
  end
end

function Learner:_OnUnit(unit)
  if unit == nil or ns.IsSecret(unit) then
    return
  end

  local npcId, kind = ns.ParseGuid(ns.Read(UnitGUID, unit))

  if kind == 'Creature' then
    -- A failure here must not reach the game's nameplates
    local success, message = pcall(self.Observe, self, unit, npcId)
    if not success then
      geterrorhandler()(message)
    end
  end
end

-- Returns the player's zone and position in percent, if known
local function GetPlayerPosition()
  local zone = GetRealZoneText()
  local map = C_Map and C_Map.GetBestMapForUnit and ns.Read(C_Map.GetBestMapForUnit, 'player')
  local position = map and C_Map.GetPlayerMapPosition(map, 'player')

  if position == nil then
    return zone
  end

  local x, y = position:GetXY()
  if x == nil or ns.IsSecret(x) then
    return zone
  end

  return zone, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
end

-- Notes a wild creature that is hovered, targeted or near. Returns the key
-- of its family if it has one, known beast or not.
function Learner:Observe(unit, npcId)
  local familyName = ns.Read(UnitCreatureFamily, unit)

  if familyName == nil then
    return nil
  end

  local row = Data.beasts[npcId]

  if row ~= nil then
    -- A beast whose family is known tells how the client calls it
    DB:SetFamilyName(familyName, Data.familyAliases[row[2]] or row[2])
    return row[2]
  end

  local family = DB:GetFamilyKey(familyName)

  if family == nil then
    return nil
  end

  -- Pets and guardians of players are not beasts to tame
  if ns.Read(UnitPlayerControlled, unit) ~= false then
    return family
  end

  local name = ns.Read(UnitName, unit)
  local level = ns.Read(UnitLevel, unit)

  if name == nil or level == nil or level < 1 then
    return family
  end

  local note = DB:GetNote(npcId)

  -- Seen before: only a level outside of its range is news
  if note ~= nil and note.minLevel ~= nil then
    if level < note.minLevel or level > note.maxLevel then
      note.minLevel = math.min(note.minLevel, level)
      note.maxLevel = math.max(note.maxLevel, level)
      DB:Invalidate(npcId)
    end

    return family
  end

  local zone, x, y = GetPlayerPosition()

  note = DB:GetNote(npcId, true)
  note.name = name
  note.family = note.family or family
  note.minLevel, note.maxLevel = level, level
  note.zone = zone
  note.x, note.y = x, y

  local speed = ns.Read(UnitAttackSpeed, unit)
  if speed ~= nil and speed > 0 then
    note.seenSpeed = math.floor(speed * 10 + 0.5) / 10
  end

  DB:Invalidate(npcId)
  self:_Announce(ns.L['New beast noted: %s (%s, level %d), %s']:format(name, DB:GetFamilyName(family), level,
                                                                      zone or '?'))

  return family
end

-- Returns the rank that follows the name of an ability in a text, as in
-- 'Bite (Rank 3)', if the text names nothing else
local function FindRank(text, name)
  local _, last = text:find(name, 1, true)

  if last == nil then
    return nil
  end

  local rank = tonumber(text:sub(last + 1):match('^%s*%(?%D-(%d+)%)?%s*$'))
  return rank ~= nil and rank >= 1 and rank <= 20 and rank or nil
end

-- Notes the abilities listed in the tooltip of a wild beast, which the game
-- adds once Beast Lore is cast on it. 'lines' are those of the tooltip's
-- data, the first of which is the name of the beast.
function Learner:ReadLore(npcId, family, lines)
  local familyData = DB:GetFamily(family)

  if familyData == nil or type(lines) ~= 'table' then
    return
  end

  local found = {}

  for index = 2, #lines do
    local line = lines[index]

    for _, text in ipairs({ line.leftText, line.rightText }) do
      if type(text) == 'string' and not ns.IsSecret(text) and #text < 120 then
        -- Several abilities may share a line
        for part in text:gmatch('[^,;\n]+') do
          for _, ability in ipairs(familyData.abilities) do
            local rank = FindRank(part, ns.L[ability])

            if rank ~= nil then
              found[ability] = rank
            end
          end
        end
      end
    end
  end

  if next(found) == nil then
    return
  end

  local note = DB:GetNote(npcId, true)
  local isNews = note.abilities == nil

  for ability, rank in pairs(found) do
    isNews = isNews or note.abilities[ability] ~= rank
  end

  if not isNews then
    return
  end

  note.abilities = found
  DB:Invalidate(npcId)

  local beast = DB:GetBeast(npcId)
  self:_Announce(ns.L['%s teaches %s']:format(beast and beast.name or ('NPC ' .. npcId), FormatAbilities(found)))
end

------------------------------------------
-- Tamed beasts
------------------------------------------

function Learner:_OnSpellCast(unit, spellId)
  if unit ~= 'player' or spellId == nil or ns.IsSecret(spellId) or spellId ~= TAME_BEAST then
    return
  end

  self.tame = {
    at = GetTime(),
    npcId = ns.ParseGuid(ns.Read(UnitGUID, 'target')),
  }
end

function Learner:_OnPetChanged()
  local tame = self.tame

  if tame == nil or GetTime() - tame.at > TAME_WINDOW then
    self.tame = nil
    return
  end

  local npcId, kind = ns.ParseGuid(ns.Read(UnitGUID, 'pet'))

  -- The pet that was dismissed for the taming goes first, the new one follows
  if npcId == nil or kind ~= 'Pet' or (tame.npcId ~= nil and tame.npcId ~= npcId) then
    return
  end

  self.tame = nil

  C_Timer.After(SCAN_DELAY, function()
    -- Still the same pet
    if ns.ParseGuid(ns.Read(UnitGUID, 'pet')) == npcId then
      self:ScanPet(npcId)
    end
  end)
end

-- Returns the name, rank, icon and passiveness of a spell of the pet
local function GetPetSpell(index)
  local name, subName, icon, isPassive

  if C_SpellBook and C_SpellBook.GetSpellBookItemName and Enum.SpellBookSpellBank then
    local bank = Enum.SpellBookSpellBank.Pet

    name, subName = ns.Read(C_SpellBook.GetSpellBookItemName, index, bank)
    icon = ns.Read(C_SpellBook.GetSpellBookItemTexture, index, bank)
    isPassive = ns.Read(C_SpellBook.IsSpellBookItemPassive, index, bank)
  elseif _G.GetSpellBookItemName then
    name, subName = ns.Read(GetSpellBookItemName, index, 'pet')
    icon = ns.Read(_G.GetSpellBookItemTexture, index, 'pet')
    isPassive = ns.Read(_G.IsPassiveSpell, index, 'pet')
  end

  if name == nil then
    return nil
  end

  local rank = type(subName) == 'string' and not ns.IsSecret(subName) and tonumber(subName:match('%d+')) or nil
  return name, rank, icon, isPassive
end

-- Returns the key of an ability from the name the client gives it
local function GetAbilityKey(name)
  for _, ability in ipairs(DB:GetAbilities()) do
    if ability == name or ns.L[ability] == name then
      return ability
    end
  end

  for ability in pairs(Data.trainerAbilities) do
    if ability == name or ns.L[ability] == name then
      return ability
    end
  end

  return name
end

-- Notes what a freshly tamed pet knows as what its beast teaches. Returns
-- whether it could be read.
function Learner:ScanPet(npcId)
  local count

  if C_SpellBook and C_SpellBook.HasPetSpells then
    count = ns.Read(C_SpellBook.HasPetSpells)
  elseif _G.HasPetSpells then
    count = ns.Read(_G.HasPetSpells)
  end

  if type(count) ~= 'number' or count < 1 then
    return false
  end

  local abilities = {}

  for index = 1, count do
    local name, rank, icon, isPassive = GetPetSpell(index)

    -- Abilities have a rank, the pet's commands and passives have none
    if name ~= nil and rank ~= nil and not isPassive then
      local ability = GetAbilityKey(name)

      if not Data.trainerAbilities[ability] then
        abilities[ability] = rank

        if icon ~= nil and Data.abilityIcons[ability] == nil then
          DB.abilityIcons[ability] = icon
        end
      end
    end
  end

  local note = DB:GetNote(npcId, true)
  note.tamed = true

  -- A pet without a ranked ability may be a beast that teaches nothing, or a
  -- spellbook that was not ready: what is assumed of the beast is then kept
  if next(abilities) ~= nil then
    note.abilities = abilities
  end

  -- The passive the beast came with shows in how fast the pet attacks. A
  -- speed that no passive gives is a pet under a haste effect, and ignored.
  local speed = ns.Read(UnitAttackSpeed, 'pet')
  if speed ~= nil then
    speed = math.floor(speed * 10 + 0.5) / 10

    if DB:IsPetSpeed(speed) then
      note.speed = speed
    end
  end

  -- A beast that is not shipped is named after what was tamed
  if Data.beasts[npcId] == nil then
    local family = DB:GetFamilyKey(ns.Read(UnitCreatureFamily, 'pet'))
    local level = ns.Read(UnitLevel, 'pet')

    note.family = note.family or family
    if note.minLevel == nil and level ~= nil and level > 0 then
      note.minLevel, note.maxLevel = level, level
    end
  end

  DB:Invalidate(npcId)

  if next(abilities) ~= nil then
    local beast = DB:GetBeast(npcId)
    self:_Announce(ns.L['%s teaches %s']:format(beast.name, FormatAbilities(abilities)))
  end

  return true
end
