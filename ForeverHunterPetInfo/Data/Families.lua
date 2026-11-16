local _, ns = ...

-- The pet families of WoW Forever, and what is shared by their beasts.
--
-- 'damage', 'armor' and 'health' are in percent, against a pet without a
-- family. 'abilities' lists what a family learns from other beasts, its own
-- ability last. Abilities bought from pet trainers (Growl, Cower, the
-- resistances...) are open to every family and are not listed.
--
-- This file is written by hand, tools/gen_data.py reads its ability lists.

ns.Data.families = {
  ['Bat'] = { icon = 132182, damage = 7, armor = 0, health = 0, diet = { 'Fungus', 'Fruit' }, abilities = { 'Bite', 'Dive', 'Sonic Blast' } },
  ['Bear'] = { icon = 132183, damage = -9, armor = 5, health = 8, diet = { 'Meat', 'Fish', 'Cheese', 'Bread', 'Fungus', 'Fruit' }, abilities = { 'Bite', 'Claw', 'Dash', 'Swipe' } },
  ['Bird of Prey'] = { icon = 132192, damage = 7, armor = 0, health = 0, diet = { 'Meat' }, abilities = { 'Claw', 'Dive', 'Mine!' } },
  ['Boar'] = { icon = 132184, damage = -10, armor = 9, health = 4, diet = { 'Meat', 'Fish', 'Cheese', 'Bread', 'Fungus', 'Fruit' }, abilities = { 'Bite', 'Dash', 'Charge' } },
  ['Carrion Bird'] = { icon = 132200, damage = 0, armor = 5, health = 0, diet = { 'Meat', 'Fish' }, abilities = { 'Bite', 'Claw', 'Dive', 'Demoralizing Screech' } },
  ['Cat'] = { icon = 132185, damage = 10, armor = 0, health = -2, diet = { 'Meat', 'Fish' }, abilities = { 'Bite', 'Claw', 'Dash', 'Prowl' } },
  ['Crab'] = { icon = 132186, damage = -5, armor = 13, health = -4, diet = { 'Fish', 'Bread', 'Fungus', 'Fruit' }, abilities = { 'Claw', 'Dash', 'Pinch' } },
  ['Crocolisk'] = { icon = 132187, damage = 0, armor = 10, health = -5, diet = { 'Meat', 'Fish' }, abilities = { 'Bite', 'Dash', 'Dismember' } },
  ['Fox'] = { icon = 134400, damage = 0, armor = 5, health = 0, diet = { 'Meat' }, abilities = { 'Bite', 'Dash', "Trickster's Dance" } },
  ['Gorilla'] = { icon = 132189, damage = 2, armor = 0, health = 4, diet = { 'Fungus', 'Fruit' }, abilities = { 'Bite', 'Dash', 'Thunderstomp' } },
  ['Hyena'] = { icon = 132190, damage = 0, armor = 5, health = 0, diet = { 'Meat', 'Fruit' }, abilities = { 'Bite', 'Dash', 'Tendon Rip' } },
  ['Raptor'] = { icon = 132193, damage = 10, armor = 3, health = -5, diet = { 'Meat' }, abilities = { 'Bite', 'Claw', 'Dash', 'Savage Rend' } },
  ['Scorpid'] = { icon = 132195, damage = -6, armor = 10, health = 0, diet = { 'Meat' }, abilities = { 'Claw', 'Dash', 'Scorpid Poison' } },
  ['Spider'] = { icon = 132196, damage = 7, armor = 0, health = 0, diet = { 'Meat' }, abilities = { 'Bite', 'Dash', 'Web' } },
  ['Tallstrider'] = { icon = 132198, damage = 0, armor = 0, health = 5, diet = { 'Cheese', 'Fungus', 'Fruit' }, abilities = { 'Bite', 'Dash', 'Dust Cloud' } },
  ['Turtle'] = { icon = 132199, damage = -10, armor = 13, health = 0, diet = { 'Fish', 'Fungus', 'Fruit', 'Raw Fish' }, abilities = { 'Bite', 'Dash', 'Shell Shield' } },
  ['Wind Serpent'] = { icon = 132202, damage = 7, armor = 0, health = 0, diet = { 'Fish', 'Cheese', 'Bread' }, abilities = { 'Bite', 'Dive', 'Lightning Breath' } },
  ['Wolf'] = { icon = 132203, damage = 0, armor = 5, health = 0, diet = { 'Meat' }, abilities = { 'Bite', 'Dash', 'Furious Howl' } },
}

-- Names a family went by before Forever, for data and clients that still use them
ns.Data.familyAliases = {
  ['Owl'] = 'Bird of Prey',
}

ns.Data.dietIcons = {
  ['Bread'] = 133968,
  ['Cheese'] = 133949,
  ['Fish'] = 134031,
  ['Fruit'] = 133976,
  ['Fungus'] = 134528,
  ['Meat'] = 134021,
  ['Raw Fish'] = 133906,
}

-- The icons of the abilities that came from Classic. Those of the abilities
-- that are new in Forever are picked up from the pet's spellbook in game.
ns.Data.abilityIcons = {
  ['Bite'] = 132278,
  ['Charge'] = 132184,
  ['Claw'] = 132140,
  ['Dash'] = 132120,
  ['Demoralizing Screech'] = 132182,
  ['Dive'] = 136126,
  ['Furious Howl'] = 132203,
  ['Lightning Breath'] = 136048,
  ['Prowl'] = 132142,
  ['Scorpid Poison'] = 132274,
  ['Shell Shield'] = 132199,
  ['Thunderstomp'] = 132189,
}

-- Abilities bought from pet trainers, a tamed beast knowing one teaches nothing
ns.Data.trainerAbilities = {
  ['Growl'] = true,
  ['Cower'] = true,
  ['Great Stamina'] = true,
  ['Natural Armor'] = true,
  ['Arcane Resistance'] = true,
  ['Fire Resistance'] = true,
  ['Frost Resistance'] = true,
  ['Nature Resistance'] = true,
  ['Shadow Resistance'] = true,
}

-- A tamed pet attacks every 2 seconds, the passive its beast came with
-- changes that. { seconds between attacks, passive, rank }
ns.Data.speedPassives = {
  { 1.0, 'Faster Attack', 'VII' },
  { 1.2, 'Faster Attack', 'VI' },
  { 1.3, 'Faster Attack', 'V' },
  { 1.4, 'Faster Attack', 'IV' },
  { 1.5, 'Faster Attack', 'III' },
  { 1.6, 'Faster Attack', 'II' },
  { 1.7, 'Faster Attack', 'I' },
  { 2.4, 'Slower Attack', 'I' },
  { 2.5, 'Slower Attack', 'II' },
  { 2.7, 'Slower Attack', 'III' },
}
