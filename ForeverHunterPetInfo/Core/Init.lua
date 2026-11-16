local ADDON, ns = ...

ns.ADDON = ADDON
ns.TITLE = 'Forever Hunter Pet Info'
ns.ICON = 132161
ns.Data = {}

-- Missing translations fall back to the English text, which is the key
ns.L = setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

------------------------------------------
-- Secrets
------------------------------------------

-- Forever inherits the addon restrictions of the modern client: in combat and
-- in instances, what the game tells addons about units can be a secret, a
-- value that raises an error when it is compared, indexed or concatenated.

-- Returns whether a value is a secret, which addons cannot inspect
function ns.IsSecret(value)
  return _G.issecretvalue ~= nil and _G.issecretvalue(value)
end

-- Returns the results of a function, or nothing if it fails or if its first
-- result is a secret
function ns.Read(func, ...)
  if type(func) ~= 'function' then
    return nil
  end

  local ok, first, second, third = pcall(func, ...)
  if not ok or first == nil or ns.IsSecret(first) then
    return nil
  end

  return first, second, third
end

-- Returns the NPC a creature or a pet is, and which of the two it is, from
-- its GUID: Creature-0-<server>-<instance>-<zone>-<npcId>-<spawn>. A tamed
-- pet keeps the ID of the beast it was.
function ns.ParseGuid(guid)
  if type(guid) ~= 'string' or ns.IsSecret(guid) then
    return nil
  end

  local kind, _, _, _, _, npcId = strsplit('-', guid)
  if kind ~= 'Creature' and kind ~= 'Pet' then
    return nil
  end

  npcId = tonumber(npcId)
  if npcId == nil then
    return nil
  end

  return npcId, kind
end

------------------------------------------
-- Events
------------------------------------------

local listeners = {}
local eventFrame = CreateFrame('Frame')

eventFrame:SetScript('OnEvent', function(_, event, ...)
  local callbacks = listeners[event]

  for index = 1, #callbacks do
    callbacks[index](...)
  end
end)

function ns.On(event, callback)
  if listeners[event] == nil then
    listeners[event] = {}
    eventFrame:RegisterEvent(event)
  end

  table.insert(listeners[event], callback)
end

------------------------------------------
-- Utilities
------------------------------------------

function ns.Print(...)
  local message = string.format('|cffabd473[%s]|r: %s', ns.TITLE, table.concat({ ... }, ' '))
  DEFAULT_CHAT_FRAME:AddMessage(message)
end

function ns.Trim(text)
  return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Lowers the second byte of a two byte UTF-8 sequence, for the Latin-1 and
-- Cyrillic blocks. Other scripts either have no case or are left as they are.
local function LowerSequence(lead, trail)
  local leadByte, trailByte = lead:byte(), trail:byte()

  if leadByte == 195 then
    -- À..Þ, except the multiplication sign
    if trailByte >= 128 and trailByte <= 158 and trailByte ~= 151 then
      return lead .. string.char(trailByte + 32)
    end
  elseif leadByte == 208 then
    if trailByte >= 144 and trailByte <= 159 then
      -- А..П
      return lead .. string.char(trailByte + 32)
    elseif trailByte >= 160 and trailByte <= 175 then
      -- Р..Я
      return '\209' .. string.char(trailByte - 32)
    elseif trailByte >= 128 and trailByte <= 143 then
      -- Ѐ..Џ
      return '\209' .. string.char(trailByte + 16)
    end
  end
end

-- Returns a string in lower case, for case-insensitive searches
function ns.Lower(text)
  text = text:lower()

  if text:find('[\195\208]') then
    text = text:gsub('([\195\208])([\128-\191])', LowerSequence)
  end

  return text
end

-- Returns a level colored by how hard a creature of that level is for the
-- player, as the game colors it
function ns.ColorLevel(level)
  local color = _G.GetCreatureDifficultyColor and GetCreatureDifficultyColor(level)

  if type(color) ~= 'table' or color.r == nil then
    return tostring(level)
  end

  return string.format('|cff%02x%02x%02x%d|r', color.r * 255, color.g * 255, color.b * 255, level)
end

-- Returns a texture as text, to place it in a line
function ns.IconText(icon)
  return '|T' .. icon .. ':14:14:0:0|t'
end
