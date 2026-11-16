local _, ns = ...

-- Interface texts. Beast and zone names are not listed here: zones are named
-- by the client, beasts by Data/BeastNames.lua.
--
-- The English text is the key, a locale only lists its translations. To add a
-- language, add a block and translate the right-hand side:
--
--   translations.deDE = {
--     ['Attack speed'] = 'Angriffstempo',
--     ['Wolf'] = 'Wolf',
--   }
--
-- Family and ability names are keys as well ('Wolf', 'Bite'). Family names
-- do not have to be translated for the addon to recognize a beast: it learns
-- how the client calls a family the first time a known beast is hovered.

local translations = {}

local locale = translations[GetLocale()]

if locale ~= nil then
  for key, text in pairs(locale) do
    ns.L[key] = text
  end
end
