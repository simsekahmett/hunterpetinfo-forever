local ns = NS
local DB, Data = ns.DB, ns.Data

local function creature(npcId) return 'Creature-0-4372-0-55-' .. npcId .. '-0000ABCDEF' end
local function pet(npcId) return 'Pet-0-4372-0-55-' .. npcId .. '-0100ABCDEF' end
local function show(title, lines) print('--- ' .. title); for _, l in ipairs(lines) do print('  ' .. l) end end
local function has(lines, text) for _, l in ipairs(lines) do if l:find(text, 1, true) then return true end end end

FireEvent('PLAYER_LOGIN')
assert(SlashCmdList.FOREVERHUNTERPETINFO, 'slash command missing')
local saved = ForeverHunterPetInfoDB
local total = DB:GetCounts()
assert(total > 500, 'beasts missing: ' .. total)

-- Every shipped beast is whole
for npcId, row in pairs(Data.beasts) do
  local beast = DB:GetBeast(npcId)
  assert(DB:GetFamily(beast.family), 'unknown family of ' .. npcId)
  assert(beast.name ~= '' and beast.minLevel >= 1 and beast.maxLevel >= beast.minLevel, 'bad row ' .. npcId)
  assert(beast.speed == nil or DB:IsPetSpeed(beast.speed), 'no passive gives the speed of ' .. npcId)
  for _, entry in ipairs(beast.abilities or {}) do
    local learnable = false
    for _, ability in ipairs(DB:GetFamily(beast.family).abilities) do learnable = learnable or ability == entry[1] end
    assert(learnable, beast.family .. ' cannot learn ' .. entry[1])
  end
end

-- GUIDs
assert(ns.ParseGuid(creature(2850)) == 2850)
assert(select(2, ns.ParseGuid(pet(2850))) == 'Pet')
assert(ns.ParseGuid('Player-4372-0ABCDEF') == nil and ns.ParseGuid(SECRET) == nil and ns.ParseGuid(nil) == nil)

-- A wild beast of the database
local familyName = TEST_LOCALE == 'deDE' and 'Katze' or 'Cat'
UNITS.tooth = { guid = creature(2850), name = 'Broken Tooth', level = 37, family = familyName, speed = 2 }
local lines = Hover('tooth')
show('Broken Tooth', lines)
assert(has(lines, 'Attack speed | 1.0') and has(lines, 'Faster Attack VII'), 'speed')
assert(has(lines, 'Diet | Meat, Fish') and has(lines, 'Teaches') and has(lines, 'Dash'), 'diet, abilities')
assert(DB:GetFamilyKey(familyName) == 'Cat', 'family name not learned')
assert(saved.learned[2850] == nil, 'a shipped beast needs no note')

-- A creature that is no beast gets nothing, nor does a player
UNITS.guard = { guid = creature(68), name = 'Stormwind City Guard', level = 55 }
UNITS.someone = { guid = 'Player-4372-0ABCDEF', name = 'Someone' }
assert(#Hover('guard') == 0 and #Hover('someone') == 0)

-- Secrets leave the tooltip alone, without an error
UNITS.hidden = { guid = SECRET, family = SECRET }
assert(#Hover('hidden') == 0)
TIP_UNIT = SECRET
for _, f in ipairs(TOOLTIP_CALLS) do f(GameTooltip, {}) end

-- A beast that is not shipped is noted, once its family is known
UNITS.fox = { guid = creature(238500), name = 'Juvenile Vuldren', level = 3, family = 'Fox', speed = 2 }
lines = Hover('fox')
show('Juvenile Vuldren (new)', lines)
assert(has(lines, 'Family | Fox') and has(lines, 'in the wild'))
local note = saved.learned[238500]
assert(note and note.family == 'Fox' and note.minLevel == 3 and note.zone == 'Zephras Isle' and note.x == 51.2, 'note')
assert(DB:GetCounts() == total + 1)
UNITS.imp = { guid = creature(416), name = 'Imp', level = 10, family = 'Imp' }
assert(#Hover('imp') == 0 and saved.learned[416] == nil, 'a demon is no beast')
UNITS.guardian = { guid = creature(238501), name = 'Hawk', level = 30, family = 'Bird of Prey', controlled = true }
Hover('guardian'); assert(saved.learned[238501] == nil, 'a guardian is no beast')

-- Taming it tells what it teaches and how fast it attacks
UNITS.target = UNITS.fox
FireEvent('UNIT_SPELLCAST_CHANNEL_START', 'player', 'cast', 1515)
Tick(20)
UNITS.pet = { guid = pet(238500), name = 'Fox', level = 3, family = 'Fox', speed = 1.52 }
PET_SPELLS = { { 'Attack' }, { 'Follow' }, { 'Bite', 'Rank 1' }, { 'Growl', 'Rank 1' }, { 'Faster Attack III', '', true } }
FireEvent('UNIT_PET', 'player')
Tick(2)
local beast = DB:GetBeast(238500)
assert(beast.speed == 1.5 and beast.speedSource == 'tamed', 'tamed speed')
assert(beast.abilitiesConfirmed and #beast.abilities == 1 and beast.abilities[1][1] == 'Bite', 'tamed abilities')
lines = Hover('pet')
show('own pet', lines)
assert(has(lines, 'Faster Attack III') and not has(lines, 'Teaches') and not has(lines, 'Tamed from'))

-- A summoned pet is not a tamed one: its abilities are left alone
UNITS.pet = { guid = pet(2850), name = 'Tooth', level = 37, family = familyName, speed = 1 }
PET_SPELLS = { { 'Claw', 'Rank 8' } }
FireEvent('UNIT_PET', 'player')
Tick(60)
assert(saved.learned[2850] == nil, 'noted without a taming')

-- The pet of someone else shows the beast it was
UNITS.other = { guid = pet(2850), name = 'Fluffy', level = 60, family = familyName }
lines = Hover('other')
show('pet of another hunter', lines)
local toothName = DB:GetBeast(2850).name
assert(toothName == (Data.beastNames and Data.beastNames[2850] or 'Broken Tooth'), 'localized name')
assert(TEST_LOCALE ~= 'deDE' or toothName == 'Zerbrochener Zahn', 'German name')
assert(has(lines, 'Tamed from | ' .. toothName) and has(lines, 'Zone | Zone3') and not has(lines, 'Teaches'))

-- Options
ns.Tooltip.options.otherPets = false
assert(#Hover('other') == 0)
ns.Tooltip.options.otherPets = true
SlashCmdList.FOREVERHUNTERPETINFO('tooltip'); assert(#Hover('tooth') == 0)
SlashCmdList.FOREVERHUNTERPETINFO('tooltip'); assert(#Hover('tooth') > 0)
SlashCmdList.FOREVERHUNTERPETINFO('options'); assert(OPENED_SETTINGS == 7)

-- Search
local function search(filter) filter.sort = filter.sort or 'name'; return DB:Search(filter) end
local function contains(ids, npcId) for _, id in ipairs(ids) do if id == npcId then return true end end end
local fastest = search({ maxSpeed = 1.0 })
assert(#fastest == 3 and contains(fastest, 2850), 'fastest: ' .. #fastest)
assert(contains(search({ text = toothName:upper() }), 2850) and contains(search({ text = 'cat zone3' }), 2850))
assert(#search({ text = 'no such beast' }) == 0)
local foxes = search({ family = 'Fox' }); assert(#foxes == 1 and foxes[1] == 238500)
for _, npcId in ipairs(search({ ability = 'Bite', rank = 7 })) do assert(DB:GetRank(DB:GetBeast(npcId), 'Bite') == 7) end
assert(#search({ ability = 'Bite', rank = 7 }) > 0 and #search({ ability = 'Bite' }) > #search({ ability = 'Bite', rank = 7 }))
for _, npcId in ipairs(search({ maxLevel = 10 })) do assert(DB:GetBeast(npcId).minLevel <= 10) end
local bySpeed = search({ family = 'Cat', sort = 'fast' }); assert(bySpeed[1] == 2850, 'sort')
local byLevel = search({ sort = 'high' }); assert(DB:GetBeast(byLevel[1]).maxLevel >= DB:GetBeast(byLevel[#byLevel]).maxLevel)

-- The window
SlashCmdList.FOREVERHUNTERPETINFO('')
local UI = ns.UI
assert(UI.frame:IsShown() and #UI.results == total + 1)
SlashCmdList.FOREVERHUNTERPETINFO('wolf')
assert(#UI.results > 0 and #UI.results < total)
print('"wolf": ' .. #UI.results .. ' of ' .. total + 1)
for index = 1, 3 do
  local texts = ns.List.Describe(DB:GetBeast(UI.results[index]))
  print('  ' .. texts.name .. ' [' .. texts.speed .. ']  ' .. texts.place .. '  ' .. texts.abilities)
end
UI.speedBox:SetText('1,3'); UI:Refresh()
for _, npcId in ipairs(UI.results) do assert(DB:GetBeast(npcId).speed <= 1.3) end
UI.levelCheck.scripts.OnClick(); UI.onlyTameable = true; PLAYER_LEVEL = 20; UI:Refresh()
for _, npcId in ipairs(UI.results) do assert(DB:GetBeast(npcId).minLevel <= 20) end
UI.familyPicker.scripts.OnClick(); UI.sortPicker.scripts.OnClick()
UI:Reset(); assert(#UI.results == total + 1)
UI.list:SetOffset(5); assert(UI.list.rows[1].beast.id == UI.results[6])
SlashCmdList.FOREVERHUNTERPETINFO(''); assert(not UI.frame:IsShown())
ForeverHunterPetInfo_OnCompartmentClick(nil, 'LeftButton'); assert(UI.frame:IsShown())
ns.Options.panel.scripts.OnShow(ns.Options.panel)
SlashCmdList.FOREVERHUNTERPETINFO('help'); assert(#CHATLOG >= 5)
assert(ForeverHunterPetInfo.GetBeast(2850).name ~= nil)
