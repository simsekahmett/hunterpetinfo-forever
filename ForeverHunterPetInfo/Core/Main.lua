local _, ns = ...

local L = ns.L

-- Handles '/fhpi', followed by nothing, a command, or a text to search for
local function OnSlashCommand(message)
  local text = ns.Trim(message or '')
  local command = text:lower()

  if text == '' then
    ns.UI:Toggle()
  elseif command == 'options' or command == 'config' or command == 'opt' then
    ns.Options:Open()
  elseif command == 'tooltip' then
    ns.Print(ns.Tooltip:Toggle() and L['Beast tooltips: on'] or L['Beast tooltips: off'])
  elseif command == 'minimap' then
    ns.MinimapButton:Toggle()
  elseif command == 'help' or command == '?' then
    ns.Print('/fhpi - ' .. L['open or close the beast list'])
    ns.Print('/fhpi <' .. L['name, family, zone or ability'] .. '> - ' .. L['search the beasts'])
    ns.Print('/fhpi options - ' .. L['open the options'])
    ns.Print('/fhpi tooltip - ' .. L['show or hide the information in tooltips'])
    ns.Print('/fhpi minimap - ' .. L['show or hide the minimap button'])
  else
    ns.UI:Open(text)
  end
end

-- The bootstrap waits for login, by then the saved variables are loaded
ns.On('PLAYER_LOGIN', function()
  _G.ForeverHunterPetInfoDB = _G.ForeverHunterPetInfoDB or {}
  local saved = _G.ForeverHunterPetInfoDB

  ns.DB:Init(saved)
  ns.Learner:Init(saved)
  ns.Tooltip:Init(saved)
  ns.MinimapButton:Init(saved)
  ns.Options:Init(saved)

  _G.SLASH_FOREVERHUNTERPETINFO1 = '/fhpi'
  _G.SLASH_FOREVERHUNTERPETINFO2 = '/hunterpetinfo'
  _G.SLASH_FOREVERHUNTERPETINFO3 = '/hpi'
  _G.SlashCmdList.FOREVERHUNTERPETINFO = OnSlashCommand
end)

-- Lets other addons and macros use the beast list
_G.ForeverHunterPetInfo = {
  Toggle = function()
    ns.UI:Toggle()
  end,
  Search = function(text)
    ns.UI:Open(text)
  end,
  -- Returns what is known of an NPC, or nil if it's not a beast
  GetBeast = function(npcId)
    return ns.DB:GetBeast(npcId)
  end,
}
