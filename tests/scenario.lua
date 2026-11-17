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
total = total + 1
UNITS.imp = { guid = creature(416), name = 'Imp', level = 10, family = 'Imp' }
assert(#Hover('imp') == 0 and saved.learned[416] == nil, 'a demon is no beast')
UNITS.guardian = { guid = creature(238501), name = 'Hawk', level = 30, family = 'Bird of Prey', controlled = true }
Hover('guardian'); assert(saved.learned[238501] == nil, 'a guardian is no beast')

-- Beasts near the player are noted without being hovered, and told in the chat
UNITS.nameplate3 = { guid = creature(238510), name = 'Scrawny Ursera', level = 3, family = 'Bear', speed = 2 }
local chat = #CHATLOG
FireEvent('NAME_PLATE_UNIT_ADDED', 'nameplate3')
assert(saved.learned[238510] and saved.learned[238510].family == 'Bear', 'nameplate')
assert(#CHATLOG == chat + 1 and CHATLOG[#CHATLOG]:find('Scrawny Ursera (Bear, level 3), Zephras Isle', 1, true), 'announce')
print(CHATLOG[#CHATLOG])
UNITS.nameplate3.level = 4
FireEvent('NAME_PLATE_UNIT_ADDED', 'nameplate3')
assert(saved.learned[238510].maxLevel == 4 and #CHATLOG == chat + 1, 'level range')
UNITS.target = { guid = creature(238511), name = 'Ornery Galestrider', level = 12, family = 'Tallstrider', classification = 'rare' }
FireEvent('PLAYER_TARGET_CHANGED')
assert(saved.learned[238511] and saved.learned[238511].rare and not saved.learned[238510].rare, 'target')
UNITS.target = UNITS.tooth; FireEvent('PLAYER_TARGET_CHANGED'); assert(saved.learned[2850] == nil)
UNITS.nameplate5 = { guid = SECRET, family = SECRET }; FireEvent('NAME_PLATE_UNIT_ADDED', 'nameplate5')
FireEvent('NAME_PLATE_UNIT_ADDED', SECRET)
local noted = DB:Search({ noted = true, sort = 'name' })
assert(#noted == 3, 'noted: ' .. #noted)

-- Beast Lore lists the abilities of a beast in its tooltip
UNITS.bear = UNITS.nameplate3
local lore = { { leftText = 'Scrawny Ursera' }, { leftText = 'Level 4 Beast' }, { leftText = 'Bite (Rank 1), Swipe (Rank 2)' },
  { leftText = 'Claw the enemy for 12 damage' }, { leftText = SECRET }, { leftText = 'Dash', rightText = 'Rank 3' } }
lines = Hover('bear', { guid = UNITS.bear.guid, lines = lore })
show('Scrawny Ursera (Beast Lore)', lines)
local ursera = DB:GetBeast(238510)
assert(ursera.abilitiesConfirmed and DB:GetRank(ursera, 'Bite') == 1 and DB:GetRank(ursera, 'Swipe') == 2, 'lore')
assert(DB:GetRank(ursera, 'Claw') == nil and DB:GetRank(ursera, 'Dash') == nil, 'lore misread')
assert(CHATLOG[#CHATLOG]:find('Scrawny Ursera teaches Bite (Rank 1), Swipe (Rank 2)', 1, true), CHATLOG[#CHATLOG])
chat = #CHATLOG
Hover('bear', { guid = UNITS.bear.guid, lines = lore }); assert(#CHATLOG == chat, 'told twice')
-- Of a shipped beast as well, replacing what Classic said
Hover('tooth', { guid = UNITS.tooth.guid, lines = { { leftText = 'x' }, { leftText = 'Dash (Rank 2)' } } })
assert(DB:GetRank(DB:GetBeast(2850), 'Dash') == 2 and DB:GetBeast(2850).abilitiesConfirmed and DB:GetBeast(2850).speed == 1)
saved.learned[2850] = nil; DB:Invalidate(2850)
ns.Learner.options.announce = false
chat = #CHATLOG
Hover('tooth', { guid = UNITS.tooth.guid, lines = { { leftText = 'x' }, { leftText = 'Dash (Rank 1)' } } })
assert(#CHATLOG == chat, 'announced whilst off')
saved.learned[2850] = nil; DB:Invalidate(2850)
ns.Learner.options.announce = true

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
total = total + 2
local foxes = search({ family = 'Fox' }); assert(#foxes == 1 and foxes[1] == 238500)
for _, npcId in ipairs(search({ ability = 'Bite', rank = 7 })) do assert(DB:GetRank(DB:GetBeast(npcId), 'Bite') == 7) end
assert(#search({ ability = 'Bite', rank = 7 }) > 0 and #search({ ability = 'Bite' }) > #search({ ability = 'Bite', rank = 7 }))
for _, npcId in ipairs(search({ maxLevel = 10 })) do assert(DB:GetBeast(npcId).minLevel <= 10) end
local rares = search({ rare = true })
assert(contains(rares, 2850) and contains(rares, 238511) and not contains(rares, 238510) and #rares < 100, 'rares: ' .. #rares)
for _, npcId in ipairs(search({ rare = true, family = 'Cat' })) do assert(DB:GetBeast(npcId).family == 'Cat' and DB:GetBeast(npcId).isRare) end
assert(ns.List.Describe(DB:GetBeast(2850)).name:find('Rare', 1, true), 'rare tag')
print('rares: ' .. #rares .. ', rare cats: ' .. #search({ rare = true, family = 'Cat' }))
local bySpeed = search({ family = 'Cat', sort = 'fast' }); assert(bySpeed[1] == 2850, 'sort')
local byLevel = search({ sort = 'high' }); assert(DB:GetBeast(byLevel[1]).maxLevel >= DB:GetBeast(byLevel[#byLevel]).maxLevel)

-- The window
SlashCmdList.FOREVERHUNTERPETINFO('')
local UI = ns.UI
assert(UI.frame:IsShown() and #UI.results == total)
SlashCmdList.FOREVERHUNTERPETINFO('wolf')
assert(#UI.results > 0 and #UI.results < total)
print('"wolf": ' .. #UI.results .. ' of ' .. total)
for index = 1, 3 do
  local texts = ns.List.Describe(DB:GetBeast(UI.results[index]))
  print('  ' .. texts.name .. ' [' .. texts.speed .. ']  ' .. texts.place .. '  ' .. texts.abilities)
end
UI.speedBox:SetText('1,3'); UI:Refresh()
for _, npcId in ipairs(UI.results) do assert(DB:GetBeast(npcId).speed <= 1.3) end
UI.levelCheck.scripts.OnClick(); UI.onlyTameable = true; PLAYER_LEVEL = 20; UI:Refresh()
for _, npcId in ipairs(UI.results) do assert(DB:GetBeast(npcId).minLevel <= 20) end
UI.familyPicker.scripts.OnClick(); UI.sortPicker.scripts.OnClick()
UI:Reset(); assert(#UI.results == total)
UI.rareCheck.scripts.OnClick(); UI.filter.rare = true; UI:Refresh(); assert(#UI.results == #rares, 'rare filter')
UI:Reset(); assert(#UI.results == total)
UI.notedCheck.scripts.OnClick(); UI.filter.noted = true; UI:Refresh(); assert(#UI.results == 3, 'noted filter')
UI:Reset(); assert(#UI.results == total)
UI.list:SetOffset(5); assert(UI.list.rows[1].beast.id == UI.results[6])
SlashCmdList.FOREVERHUNTERPETINFO(''); assert(not UI.frame:IsShown())
ForeverHunterPetInfo_OnCompartmentClick(nil, 'LeftButton'); assert(UI.frame:IsShown())
ns.Options.panel.scripts.OnShow(ns.Options.panel)
SlashCmdList.FOREVERHUNTERPETINFO('help'); assert(#CHATLOG >= 5)
assert(ForeverHunterPetInfo.GetBeast(2850).name ~= nil)
