-- AtlasLootForever :: Reference.lua
-- Reference loot, pulled from foreverchanges.pro on 2026-09-19.
--
-- This is NOT what you collected: it is the table published by that site,
-- mixing drops seen in the beta with data from the client. What you loot
-- yourself stays in the collector database and shows counts and percentages;
-- items from here show no count until you see them drop.
--
-- Format: ["Dungeon name"] = { { "Boss", { "itemID:Name", ... } }, ... }
-- The dungeon key is the name GetInstanceInfo() returns, which is why wings
-- (Scarlet Monastery, Dire Maul, Blackrock Spire, Stratholme) are merged into
-- a single entry, in wing order.

local ADDON, ns = ...

-- Merges a shared pool with the boss's own items
local function plus(shared, own)
	local out = {}
	for _, v in ipairs(own or {}) do out[#out + 1] = v end
	for _, v in ipairs(shared or {}) do out[#out + 1] = v end
	return out
end

-- Scholomance pool: the same sets drop from several bosses
local SCHOLO = {
	"18681:Burial Shawl", "14633:Necropile Mantle", "14626:Necropile Robe",
	"14637:Cadaverous Armor", "14611:Bloodmail Hauberk", "14624:Deathbone Chestplate",
	"14629:Necropile Cuffs", "14640:Cadaverous Gloves", "14615:Bloodmail Gauntlets",
	"14622:Deathbone Gauntlets", "14636:Cadaverous Belt", "14614:Bloodmail Belt",
	"14620:Deathbone Girdle", "14632:Necropile Leggings", "14638:Cadaverous Leggings",
	"18682:Ghoul Skin Leggings", "14612:Bloodmail Legguards", "14623:Deathbone Legguards",
	"14631:Necropile Boots", "14641:Cadaverous Walkers", "14616:Bloodmail Boots",
	"14621:Deathbone Sabatons", "18684:Dimly Opalescent Ring", "23201:Libram of Divinity",
	"23200:Totem of Sustaining", "18680:Ancient Bone Bow", "18683:Hammer of the Vesper",
}

-- Pool shared by the four Sunken Temple dragonkin
local ST_DRAKES = {
	"12465:Nightfall Drape", "12466:Dawnspire Cord", "12464:Bloodfire Talons",
	"10797:Firebreather", "12463:Drakefang Butcher", "12243:Smoldering Claw",
	"10795:Drakeclaw Band", "10796:Drakestone",
}

-- Dire Maul ogre pool (guards and trash share it)
local DM_OGRE = {
	"18450:Robe of Combustion", "18451:Hyena Hide Belt", "18458:Modest Armguards",
	"18459:Gallant's Wristguards", "18460:Unsophisticated Hand Cannon",
	"18462:Jagged Bone Fist", "18463:Ogre Pocket Knife", "18464:Gordok Nose Ring",
}
local DM_GUARD = plus(DM_OGRE, {
	"18494:Denwatcher's Shoulders", "18493:Bulky Iron Spaulders", "18496:Heliotrope Cloak",
	"18497:Sublime Wristguards", "18498:Hedgecutter", "18250:Gordok Shackle Key",
})
local DM_TRASH = plus(DM_OGRE, {
	"18289:Barbed Thorn Necklace", "18295:Phasing Boots", "18296:Marksman Bands",
	"18298:Unbridled Leggings", "18337:Orphic Bracers", "18338:Wand of Arcane Potency",
	"18339:Eidolon Cloak", "18340:Eidolon Talisman", "18343:Petrified Band",
	"18344:Stonebark Gauntlets", "18354:Pimgib's Collar", "18333:Libram of Focus",
	"18334:Libram of Protection", "18332:Libram of Rapidity",
	"18493:Bulky Iron Spaulders", "18494:Denwatcher's Shoulders", "18496:Heliotrope Cloak",
	"18497:Sublime Wristguards", "18498:Hedgecutter",
})

ns.Reference = {

	["Hall of Thanes"] = {
		{ "Faldrim Anvilmar", { "270227:Ephemeral Choker", "271096:Aetherwisp Bracers", "271097:Spiritwraith Drape" } },
		{ "Magmatus", { "270230:Kindlegem Girdle", "270231:Flamefist Grips", "271095:Fang of Magmatus" } },
		{ "Plunder", { "270228:Golemheart Stave", "271098:Golemguard Chest" } },
		{ "Durgen Dirgehammer", { "270256:Durgen's Crescent Axe", "270260:Direhammer Leggings", "270261:Robes of the Disgraced Thane", "274286:Durgen Dirgehammer's Head" } },
	},

	["Ruins of Lordaeron"] = {
		{ "The Baron", { "271204:Meathook Slicer", "271205:Abomination Bones", "271206:Leftover Abomination Skin" } },
		{ "Witherfang", { "271201:Atrophic Girdle", "271202:Witherbite Bracers", "271203:Segmented Spider Leg" } },
		{ "The Abandoned", { "271207:Wispcloth Leggings", "271208:Grip of Fear", "271216:Scepter of the Abandoned" } },
		{ "Bjork", { "271209:Bonerust Leggings", "271210:Tuskwrap Belt", "271217:Corpse Chopper" } },
		{ "Rath'mael", { "271213:Mirror of Rath'mael", "271214:Frostbane Treads", "271215:Coldspire Staff" } },
		{ "Viktor the Vile", { "271211:Vilewalkers", "271212:Bloodied Chestwraps", "271218:Vileblood Scimitar" } },
	},

	-- Bosses named in the client, but no drop seen in the beta yet
	["Excavation Site"] = {
		{ "Saltspine", {} }, { "Shadetooth", {} }, { "Highland Horror", {} }, { "Relic Guardian", {} },
	},
	["City of Dalaran"] = {
		{ "Arcane Anomaly", {} }, { "Fel Ancient", {} }, { "Mana Devourer", {} },
		{ "Mana Elemental", {} }, { "Unstable Sentinel", {} }, { "Shade of the Archmage", {} },
		{ "Lyn the Ignored", {} }, { "Atrexis the Grave Knight", {} }, { "Mana Wraith", {} },
		{ "Unassigned", { "277507:Dalaran Sewer Key", "275989:Tome of Dalaran", "275996:The Founding of Dalaran" } },
	},

	["Ragefire Chasm"] = {
		{ "Oggleflint", { "272999:Barbaric Crossbow", "272996:Trogg Scepter", "272998:Bone Knuckles" } },
		{ "Taragaman the Hungerer", { "14149:Subterranean Cape", "14148:Crystalline Cuffs", "14145:Cursed Felblades" } },
		{ "Jergosh the Invoker", { "14150:Robe of Evocation", "14147:Cavedweller Bracers", "14151:Chanting Blade" } },
		{ "Bazzalan", { "273003:Searing Dagger", "273007:Chasm Walkers", "273005:Satyrskin Cloak" } },
	},

	["Wailing Caverns"] = {
		{ "Lord Cobrahn", { "6460:Cobrahn's Grasp", "10410:Leggings of the Fang", "6465:Robe of the Moccasin" } },
		{ "Lady Anacondra", { "10412:Belt of the Fang", "5404:Serpent's Shoulders", "6446:Snakeskin Bag", "273088:Snake Eye Kaleidoscope" } },
		{ "Kresh", { "13245:Kresh's Back", "6447:Worn Turtle Shell Shield" } },
		{ "Lord Pythas", { "6472:Stinging Viper", "6473:Armor of the Fang", "273089:Slither Cord" } },
		{ "Skum", { "6449:Glowing Lizardscale Cloak", "6448:Tail Spike" } },
		{ "Lord Serpentis", { "6469:Venomstrike", "5970:Serpent Gloves", "10411:Footpads of the Fang", "6459:Savage Trodders" } },
		{ "Verdan the Everliving", { "6630:Seedcloud Buckler", "6631:Living Root", "6629:Sporid Cape" } },
		{ "Mutanus the Devourer", { "6461:Slime-encrusted Pads", "6627:Mutant Scale Breastplate", "6463:Deep Fathom Ring", "10441:Glowing Shard" } },
		{ "Deviate Faerie Dragon", { "5243:Firebelcher", "6632:Feyscale Cloak" } },
		{ "Trash", { "10413:Gloves of the Fang" } },
	},

	["The Deadmines"] = {
		{ "Rhahk'Zor", { "872:Rockslicer", "5187:Rhahk'Zor's Hammer", "273289:Ogre Loincloth" } },
		{ "Miner Johnson", { "5443:Gold-plated Buckler", "5444:Miner's Cape" } },
		{ "Sneed", { "5194:Taskmaster Axe", "5195:Gold-flecked Gloves", "273293:Bandsaw Wristbands" } },
		{ "Sneed's Shredder", { "1937:Buzz Saw", "2169:Buzzer Blade", "285292:Dull Sawblade" } },
		{ "Gilnid", { "1156:Lavishly Jeweled Ring", "5199:Smelting Pants" } },
		{ "Mr. Smite", { "7230:Smite's Mighty Hammer", "5192:Thief's Blade", "5196:Smite's Reaver", "284715:First Mate Band" } },
		{ "Captain Greenskin", { "5201:Emberstone Staff", "10403:Blackened Defias Belt", "5200:Impaling Harpoon" } },
		{ "Edwin VanCleef", { "5193:Cape of the Brotherhood", "5202:Corsair's Overshirt", "10399:Blackened Defias Armor", "5191:Cruel Barb", "2874:An Unsent Letter" } },
		{ "Cookie", { "5198:Cookie's Stirring Rod", "5197:Cookie's Tenderizer", "8490:Cat Carrier (Siamese)", "273298:Lookie's Spyglass" } },
	},

	["Shadowfang Keep"] = {
		{ "Rethilgore", { "5254:Rugged Spaulders", "273457:Sorcerer Collar" } },
		{ "Fel Steed / Shadow Charger", { "6341:Eerie Stable Lantern", "932:Fel Steed Saddlebags" } },
		{ "Razorclaw the Butcher", { "1292:Butcher's Cleaver", "6226:Bloody Apron", "6633:Butcher's Slicer" } },
		{ "Baron Silverlaine", { "6321:Silverlaine's Family Seal", "6323:Baron's Scepter", "273637:Blade of Silverlaine" } },
		{ "Commander Springvale", { "6320:Commander's Crest", "3191:Arced War Axe" } },
		{ "Odo the Blindwatcher", { "6318:Odo's Ley Staff", "6319:Girdle of the Blindwatcher", "273645:Blindwatcher's Sight" } },
		{ "Deathsworn Captain", { "6642:Phantom Armor", "6641:Haunting Blade" } },
		{ "Arugal's Voidwalker", { "5943:Rift Bracers" } },
		{ "Fenrus the Devourer", { "6340:Fenrus' Hide", "3230:Black Wolf Bracers", "273646:Half-Eaten Boots" } },
		{ "Wolf Master Nandos", { "3748:Feline Mantle", "6314:Wolfmaster Cape" } },
		{ "Archmage Arugal", { "6324:Robes of Arugal", "6392:Belt of Arugal", "6220:Meteor Shard" } },
	},

	["Blackfathom Deeps"] = {
		{ "Ghamoo-ra", { "6907:Tortoise Armor", "6908:Ghamoo-ra's Bind" } },
		{ "Lady Sarevess", { "888:Naga Battle Gloves", "3078:Naga Heartpiercer", "11121:Darkwater Talwar" } },
		{ "Gelihast", { "6906:Algae Fists", "6905:Reef Axe", "1470:Murloc Skin Bag" } },
		{ "Baron Aquanis", { "16782:Strange Water Globe" } },
		{ "Twilight Lord Kelris", { "1155:Rod of the Sleepwalker", "6903:Gaze Dreamer Pants" } },
		{ "Old Serra'kis", { "6901:Glowing Thresher Cape", "6904:Bite of Serra'kis", "6902:Bands of Serra'kis" } },
		{ "Aku'mai", { "6911:Moss Cinch", "6910:Leech Pants", "6909:Strike of the Hydra" } },
	},

	["The Stockade"] = {
		{ "Kam Deepfury", { "2280:Kam's Walking Stick" } },
		{ "Bruegal Ironknuckle", { "3228:Jimmied Handcuffs", "2941:Prison Shank", "2942:Iron Knuckles" } },
		{ "Trash", { "1076:Defias Renegade Ring" } },
	},

	["Gnomeregan"] = {
		{ "Techbot", { "9444:Techbot CPU Shell" } },
		{ "Grubbis", { "9445:Grubbis Paws" } },
		{ "Viscous Fallout", { "9454:Acidic Walkers", "9453:Toxic Revenger", "9452:Hydrocane" } },
		{ "Electrocutioner 6000", { "9447:Electrocutioner Lagnut", "9446:Electrocutioner Leg", "9448:Spidertank Oilrag", "6893:Workshop Key" } },
		{ "Crowd Pummeler 9-60", { "9449:Manual Crowd Pummeler", "9450:Gnomebot Operating Boots" } },
		{ "Dark Iron Ambassador", { "9455:Emissary Cuffs", "9456:Glass Shooter", "9457:Royal Diplomatic Scepter" } },
		{ "Mekgineer Thermaplugg", { "9492:Electromagnetic Gigaflux Reactivator", "9461:Charged Gear", "9458:Thermaplugg's Central Core", "9459:Thermaplugg's Left Arm", "4415:Schematic: Craftsman's Monocle", "4413:Schematic: Discombobulator Ray", "4411:Schematic: Flame Deflector", "7742:Schematic: Gnomish Cloaking Device", "11828:Schematic: Pet Bombling" } },
	},

	["Razorfen Kraul"] = {
		{ "Aggem Thorncurse", { "6681:Thornspike" } },
		{ "Death Speaker Jargba", { "2816:Death Speaker Scepter", "6685:Death Speaker Mantle", "6682:Death Speaker Robes" } },
		{ "Overlord Ramtusk", { "6687:Corpsemaker", "6686:Tusken Helm" } },
		{ "Razorfen Spearhide", { "6679:Armor Piercer" } },
		{ "Agathelos the Raging", { "6691:Swinetusk Shank", "6690:Ferine Leggings" } },
		{ "Blind Hunter", { "6695:Stygian Bone Amulet", "6697:Batwing Mantle", "6696:Nightstalker Bow" } },
		{ "Charlga Razorflank", { "6693:Agamaggan's Clutch", "6694:Heart of Agamaggan", "6692:Pronged Reaver", "17008:Small Scroll" } },
		{ "Earthcaller Halmgar", { "6689:Wind Spirit Staff", "6688:Whisperwind Headdress" } },
	},

	["Scarlet Monastery"] = {
		{ "Interrogator Vishas", { "7682:Torturing Poker", "7683:Bloody Brass Knuckles" } },
		{ "Azshir the Sleepless", { "7709:Blighted Leggings", "7708:Necrotic Wand", "7731:Ghostshard Talisman" } },
		{ "Fallen Champion", { "7691:Embalmed Shroud", "7690:Ebon Vise", "7689:Morbid Dawn" } },
		{ "Ironspine", { "7688:Ironspine's Ribcage", "7687:Ironspine's Fist", "7686:Ironspine's Eye" } },
		{ "Bloodmage Thalnos", { "7685:Orb of the Forgotten Seer", "7684:Bloodmage Mantle" } },
		{ "Houndmaster Loksey", { "7710:Loksey's Training Stick", "7756:Dog Training Gloves", "3456:Dog Whistle" } },
		{ "Arcanist Doan", { "7714:Hypnotic Blade", "7713:Illusionary Rod", "7712:Mantle of Doan", "7711:Robe of Doan" } },
		{ "Doan's Strongbox", { "7146:The Scarlet Key" } },
		{ "Herod", { "7719:Raging Berserker's Helm", "7718:Herod's Shoulder", "10330:Scarlet Leggings", "7717:Ravager" } },
		{ "High Inquisitor Fairbanks", { "19507:Inquisitor's Shawl", "19508:Branded Leather Bracers", "19509:Dusty Mail Boots" } },
		{ "Scarlet Commander Mograine", { "7724:Gauntlets of Divinity", "10330:Scarlet Leggings", "7726:Aegis of the Scarlet Commander", "7723:Mograine's Might" } },
		{ "High Inquisitor Whitemane", { "7720:Whitemane's Chapeau", "7722:Triune Amulet", "7721:Hand of Righteousness" } },
	},

	["Razorfen Downs"] = {
		{ "Tuten'kash", { "10776:Silky Spider Cape", "10775:Carapace of Tuten'kash", "10777:Arachnid Gloves" } },
		{ "Mordresh Fire Eye", { "10769:Glowing Eye of Mordresh", "10771:Deathmage Sash", "10770:Mordresh's Lifeless Skull" } },
		{ "Glutton", { "10774:Fleshhide Shoulders", "10772:Glutton's Cleaver" } },
		{ "Ragglesnout", { "10768:Boar Champion's Belt", "10767:Savage Boar's Guard", "10758:X'caliboar" } },
		{ "Amnennar the Coldbringer", { "10763:Icemetal Barbute", "10762:Robes of the Lich", "10764:Deathchill Armor", "10761:Coldrage Dagger", "10765:Bonefingers" } },
		{ "Plaguemaw the Rotting", { "10766:Plaguerot Sprig", "10760:Swine Fists" } },
	},

	["Uldaman"] = {
		{ "Eric \"The Swift\"", { "9394:Horned Viking Helmet", "9398:Worn Running Boots", "2459:Swiftness Potion" } },
		{ "Baelog", { "9401:Nordic Longshank", "9399:Precision Arrow", "9400:Baelog's Shortbow" } },
		{ "Olaf", { "9404:Olaf's All Purpose Shield", "9403:Battered Viking Shield", "1177:Oil of Olaf" } },
		{ "Revelosh", { "9389:Revelosh's Spaulders", "9388:Revelosh's Armguards", "9390:Revelosh's Gloves", "9387:Revelosh's Boots", "7741:The Shaft of Tsol" } },
		{ "Ironaya", { "9409:Ironaya's Bracers", "9407:Stoneweaver Leggings", "9408:Ironshod Bludgeon" } },
		{ "Obsidian Sentinel", { "8053:Obsidian Power Source" } },
		{ "Ancient Stone Keeper", { "9410:Cragfists", "9411:Rockshard Pauldrons" } },
		{ "Galgann Firehammer", { "11310:Flameseer Mantle", "9412:Galgann's Fireblaster", "11311:Emberscale Cape", "9419:Galgann's Firehammer" } },
		{ "Grimlok", { "9415:Grimlok's Tribal Vestments", "9416:Grimlok's Charge", "9414:Oilskin Leggings", "7670:Shattered Necklace Sapphire" } },
		{ "Archaedas", { "11118:Archaedic Stone", "9413:The Rockpounder", "9418:Stoneslayer" } },
	},

	["Zul'Farrak"] = {
		{ "Antu'sul", { "9640:Vice Grips", "9641:Lifeblood Amulet", "9639:The Hand of Antu'sul", "9379:Sang'thraze the Deflector" } },
		{ "Theka the Martyr", { "10660:First Mosh'aru Tablet" } },
		{ "Sandarr Dunereaver", { "9523:Troll Temper" } },
		{ "Witch Doctor Zum'rah", { "18083:Jumanza Grips", "18082:Zum'rah's Vexing Cane" } },
		{ "Nekrum Gutchewer", { "9471:Nekrum's Medallion" } },
		{ "Shadowpriest Sezz'ziz", { "9470:Bad Mojo Mask", "9473:Jinxed Hoodoo Skin", "9474:Jinxed Hoodoo Kilt", "9475:Diabolic Skiver" } },
		{ "Dustwraith", { "12471:Desertwalker Cane" } },
		{ "Sandfury Executioner", { "8444:Executioner's Key" } },
		{ "Sergeant Bly", { "8548:Divino-matic Rod", "5616:Gutwrencher" } },
		{ "Hydromancer Velratha", { "9234:Tiara of the Deep", "10661:Second Mosh'aru Tablet" } },
		{ "Gahz'rilla", { "9469:Gahz'rilla Scale Armor", "9467:Gahz'rilla Fang" } },
		{ "Chief Ukorz Sandscalp", { "9479:Embrace of the Lycan", "9476:Big Bad Pauldrons", "9478:Ripsaw", "9477:The Chief's Enforcer", "11086:Jang'thraze the Protector" } },
		{ "Zerillis", { "12470:Sandstalker Ankleguards" } },
		{ "Trash", { "9512:Blackmetal Cape", "9484:Spellshock Leggings", "862:Runed Ring", "6440:Brainlash", "9483:Flaming Incinerator", "2040:Troll Protector", "5616:Gutwrencher", "9511:Bloodletter Scalpel", "9481:The Minotaur", "9480:Eyegouger", "9482:Witch Doctor's Cane", "9243:Shriveled Heart" } },
	},

	["Maraudon"] = {
		{ "Veng", { "17765:Gem of the Fifth Khan" } },
		{ "Noxxion", { "17746:Noxxion's Shackles", "17744:Heart of Noxxion", "17745:Noxious Shooter" } },
		{ "Razorlash", { "17749:Phytoskin Spaulders", "17748:Vinerot Sandals", "17750:Chloromesh Girdle", "17751:Brusslehide Leggings" } },
		{ "Maraudos", { "17764:Gem of the Fourth Khan" } },
		{ "Lord Vyletongue", { "17755:Satyrmane Sash", "17754:Infernal Trickster Leggings", "17752:Satyr's Lash" } },
		{ "Meshlok the Harvester", { "17767:Bloomsprout Headpiece", "17741:Nature's Embrace", "17742:Fungus Shroud Armor" } },
		{ "Celebras the Cursed", { "17740:Soothsayer's Headdress", "17739:Grovekeeper's Drape", "17738:Claw of Celebras" } },
		{ "Landslide", { "17734:Helm of the Mountain", "17736:Rockgrip Gauntlets", "17737:Cloud Stone", "17943:Fist of Stone" } },
		{ "Tinkerer Gizlock", { "17718:Gizlock's Hypertech Buckler", "17717:Megashot Rifle", "17719:Inventor's Focal Sword" } },
		{ "Rotgrip", { "17732:Rotgrip Mantle", "17728:Albino Crocscale Boots", "17730:Gatorbite Axe" } },
		{ "Princess Theradras", { "17780:Blade of Eternal Darkness", "17715:Eye of Theradras", "17707:Gemshard Heart", "17714:Bracers of the Stone Princess", "17711:Elemental Rockridge Leggings", "17713:Blackstone Ring", "17710:Charstone Dirk", "17766:Princess Theradras' Scepter" } },
		{ "The Nameless Prophet", { "17757:Amulet of Spirits" } },
		{ "Kolk", { "17761:Gem of the First Khan" } },
		{ "Gelk", { "17762:Gem of the Second Khan" } },
		{ "Magra", { "17763:Gem of the Third Khan" } },
	},

	["The Temple of Atal'Hakkar"] = {
		{ "Balcony Minibosses", { "10783:Atal'ai Spaulders", "10784:Atal'ai Breastplate", "10787:Atal'ai Gloves", "10788:Atal'ai Girdle", "10785:Atal'ai Leggings", "10786:Atal'ai Boots", "20606:Amber Voodoo Feather", "20607:Blue Voodoo Feather", "20608:Green Voodoo Feather" } },
		{ "Atal'alarion", { "10800:Darkwater Bracers", "10798:Atal'alarion's Tusk Ring", "10799:Headspike" } },
		{ "Spawn of Hakkar", { "10801:Slitherscale Boots", "10802:Wingveil Cloak" } },
		{ "Avatar of Hakkar", { "12462:Embrace of the Wind Serpent", "10843:Featherskin Cape", "10845:Warrior's Embrace", "10842:Windscale Sarong", "10846:Bloodshot Greaves", "10838:Might of Hakkar", "10844:Spire of Hakkar" } },
		{ "Jammal'an the Prophet", { "10806:Vestments of the Atal'ai Prophet", "10808:Gloves of the Atal'ai Prophet", "10807:Kilt of the Atal'ai Prophet" } },
		{ "Ogom the Wretched", { "10805:Eater of the Dead", "10803:Blade of the Wretched", "10804:Fist of the Damned" } },
		{ "Dreamscythe", ST_DRAKES },
		{ "Weaver", ST_DRAKES },
		{ "Hazzas", ST_DRAKES },
		{ "Morphaz", ST_DRAKES },
		{ "Shade of Eranikus", { "10847:Dragon's Call", "10833:Horns of Eranikus", "10829:Dragon's Eye", "10836:Rod of Corrosion", "10835:Crest of Supremacy", "10837:Tooth of Eranikus", "10828:Dire Nail", "10454:Essence of Eranikus" } },
		{ "Trash", { "10630:Soulcatcher Halo", "10632:Slimescale Bracers", "10631:Murkwater Gauntlets", "10633:Silvershell Leggings", "10629:Mistwalker Boots", "10634:Mindseye Circle", "10624:Stinging Bow", "10623:Winter's Bite", "10625:Stealthblade", "10626:Ragehammer", "10628:Deathblow", "10627:Bludgeon of the Grinning Dog", "10782:Hakkari Shroud", "10781:Hakkari Breastplate", "10780:Mark of Hakkar", "16216:Formula: Enchant Cloak - Greater Resistance", "15733:Pattern: Green Dragonscale Leggings" } },
	},

	["Blackrock Depths"] = {
		{ "Lord Roccor", { "22234:Mantle of Lost Hope", "11632:Earthslag Shoulders", "11631:Stoneshell Guard", "22397:Idol of Ferocity", "11630:Rockshard Pellets", "11813:Formula: Smoking Heart of the Mountain" } },
		{ "High Interrogator Gerstahn", { "11626:Blackveil Cape", "11624:Kentic Amice", "22240:Greaves of Withering Despair", "11625:Enthralled Sphere", "11140:Prison Cell Key" } },
		{ "Houndmaster Grebmar", { "11623:Spritecaster Cape", "11627:Fleetfoot Greaves", "11628:Houndmaster's Bow", "11629:Houndmaster's Rifle" } },
		{ "Ring of Law: Gorosh the Dervish", { "11726:Savage Gladiator Chain", "22271:Leggings of Frenzied Magic", "22257:Bloodclot Band", "22266:Flarethorn" } },
		{ "Ring of Law: Grizzle", { "11722:Dregmetal Spaulders", "11703:Stonewall Girdle", "22270:Entrenching Boots", "11702:Grizzle's Skinner", "11610:Plans: Dark Iron Pulverizer" } },
		{ "Ring of Law: Eviscerator", { "11685:Splinthide Shoulders", "11679:Rubicund Armguards", "11686:Girdle of Beastial Fury", "11730:Savage Gladiator Grips" } },
		{ "Ring of Law: Ok'thor the Breaker", { "11665:Ogreseer Fists", "11662:Ban'thok Sash", "11728:Savage Gladiator Leggings", "11824:Cyclopean Band" } },
		{ "Ring of Law: Anub'shiah", { "11678:Carapace of Anub'shiah", "11677:Graverot Cape", "11675:Shadefiend Boots", "11731:Savage Gladiator Greaves" } },
		{ "Ring of Law: Hedrum the Creeper", { "11633:Spiderfang Carapace", "11634:Silkweb Gloves", "11635:Hookfang Shanker", "11729:Savage Gladiator Helm" } },
		{ "Pyromancer Loregrain", { "11747:Flamestrider Robes", "11749:Searingscale Leggings", "11748:Pyric Caduceus", "11750:Kindling Stave", "11207:Formula: Enchant Weapon - Fiery Weapon" } },
		{ "Dark Coffer", { "11197:Dark Keeper Key", "22256:Mana Shaping Handwraps", "22205:Black Steel Bindings", "22255:Magma Forged Band", "22254:Wand of Eternal Light", "11923:The Hammer of Grace", "11945:Dark Iron Ring", "11946:Fire Opal Necklace", "11752:Black Blood of the Tormented", "11751:Burning Essence", "11753:Eye of Kajal" } },
		{ "Warder Stilgiss", { "11782:Boreal Mantle", "22241:Dark Warder's Pauldrons", "11783:Chillsteel Girdle", "11784:Arbiter's Blade" } },
		{ "Verek", { "11755:Verek's Collar", "22242:Verek's Leash" } },
		{ "Watchman Doomgrip", { "22205:Black Steel Bindings", "22255:Magma Forged Band", "22256:Mana Shaping Handwraps", "22254:Wand of Eternal Light" } },
		{ "Fineous Darkvire", { "11839:Chief Architect's Monocle", "22223:Foreman's Head Protector", "11842:Lead Surveyor's Mantle", "11841:Senior Designer's Pantaloons", "11840:Master Builder's Shirt" } },
		{ "Lord Incendius", { "11766:Flameweave Cuffs", "11764:Cinderhide Armsplints", "11765:Pyremail Wristguards", "11767:Emberplate Armguards", "19268:Ace of Elementals", "11768:Incendic Bracers" } },
		{ "Bael'Gar", { "11807:Sash of the Burning Heart", "11802:Lavacrest Leggings", "11805:Rubidium Hammer", "11803:Force of Magma" } },
		{ "General Angerforge", { "11820:Royal Decorated Armor", "11821:Warstrife Leggings", "11810:Force of Will", "11817:Lord General's Sword", "11816:Angerforge's Battle Axe", "11841:Senior Designer's Pantaloons" } },
		{ "Golem Lord Argelmach", { "11823:Luminary Kilt", "11822:Omnicast Boots", "11669:Naglering", "11819:Second Wind" } },
		{ "Grim Guzzler", { "11735:Ragefury Eyepatch", "18043:Coal Miner Boots", "22275:Firemoss Boots", "18044:Hurley's Tankard", "18592:Plans: Sulfuron Hammer", "11612:Plans: Dark Iron Plate", "2662:Ribbly's Quiver", "2663:Ribbly's Bandolier", "11742:Wayfarer's Knapsack", "12793:Mixologist's Tunic", "12791:Barman Shanker", "18653:Schematic: Goblin Jumper Cables XL", "13483:Recipe: Transmute Fire to Earth", "15759:Pattern: Black Dragonscale Breastplate", "11325:Dark Iron Ale Mug", "11602:Grim Guzzler Key" } },
		{ "Phalanx", { "22212:Golem Fitted Pauldrons", "11745:Fists of Phalanx", "11744:Bloodfist", "11743:Rockfist" } },
		{ "Ambassador Flamelash", { "11808:Circle of Flame", "11812:Cape of the Fire Salamander", "11814:Molten Fists", "11832:Burst of Knowledge", "11809:Flame Wrath", "23320:Tablet of Flame Shock VI" } },
		{ "Panzor the Invincible", { "22245:Soot Encrusted Footwear", "11787:Shalehusk Boots", "11785:Rock Golem Bulwark", "11786:Stone of the Earth" } },
		{ "Chest of The Seven", { "11925:Ghostshroud", "11926:Deathdealer Breastplate", "11929:Haunting Specter Leggings", "11927:Legplates of the Eternal Guardian", "11920:Wraith Scythe", "11923:The Hammer of Grace", "11922:Blood-etched Blade", "11921:Impervious Giant" } },
		{ "Magmus", { "11746:Golem Skull Helm", "11935:Magmus Stone", "22395:Totem of Rage", "22400:Libram of Truth", "22208:Lavastone Hammer" } },
		{ "Princess Moira Bronzebeard", { "12557:Ebonsteel Spaulders", "12554:Hands of the Exalted Herald", "12556:High Priestess Boots", "12553:Swiftwalker Boots" } },
		{ "Emperor Dagran Thaurissan", { "11684:Ironfoe", "11933:Imperial Jewel", "11930:The Emperor's New Cape", "11924:Robes of the Royal Crown", "22204:Wristguards of Renown", "22207:Sash of the Grand Hunt", "11934:Emperor's Seal", "11815:Hand of Justice", "11928:Thaurissan's Royal Scepter", "11931:Dreadforge Retaliator", "11932:Guiding Stave of Wisdom", "12033:Thaurissan Family Jewels" } },
		{ "Trash", { "12549:Braincage", "12552:Blisterbane Wrap", "12551:Stoneshield Cloak", "12542:Funeral Pyre Vestment", "12546:Aristocratic Cuffs", "12550:Runed Golem Shackles", "12547:Mar Alom's Grip", "12555:Battlechaser's Greaves", "12527:Ribsplitter", "12531:Searing Needle", "12535:Doomforged Straightedge", "12528:The Judge's Gavel", "12532:Spire of the Stoneshapers", "15781:Pattern: Black Dragonscale Leggings", "15770:Pattern: Black Dragonscale Shoulders", "11611:Plans: Dark Iron Sunderer", "11614:Plans: Dark Iron Mail", "11615:Plans: Dark Iron Shoulders", "16048:Schematic: Dark Iron Rifle", "16053:Schematic: Master Engineer's Goggles", "16049:Schematic: Dark Iron Bomb", "18654:Schematic: Gnomish Alarm-O-Bot", "18661:Schematic: World Enlarger", "22305:Ironweave Mantle" } },
	},

	["Dire Maul"] = {
		{ "Pusillin", { "18267:Recipe: Runn Tum Tuber Surprise", "18249:Crescent Key" } },
		{ "Zevrim Thornhoof", { "18319:Fervent Helm", "18313:Helm of Awareness", "18323:Satyr's Bow", "18308:Clever Hat", "18306:Gloves of Shadowy Mist" } },
		{ "Hydrospawn", { "18317:Tempest Talisman", "18322:Waterspout Boots", "18324:Waveslicer", "19268:Ace of Elementals", "18305:Breakwater Legguards", "18307:Riptide Shoes" } },
		{ "Lethtendris", { "18325:Felhide Cap", "18311:Quel'dorai Channeling Rod", "18301:Lethtendris's Wand", "18302:Band of Vigor" } },
		{ "Alzzin the Wildshaper", { "18328:Shadewood Cloak", "18312:Energized Chestplate", "18309:Gloves of Restoration", "18326:Razor Gauntlets", "18327:Whipvine Cord", "18318:Merciful Greaves", "18321:Energetic Rod", "18310:Fiendish Machete", "18314:Ring of Demonic Guile", "18315:Ring of Demonic Potency" } },
		{ "Tendris Warpwood", { "18393:Warpwood Binding", "18390:Tanglemoss Leggings", "18352:Petrified Bark Shield", "18353:Stoneflower Staff" } },
		{ "Illyanna Ravenoak", { "18383:Force Imbued Gauntlets", "18386:Padre's Trousers", "18349:Gauntlets of Accuracy", "18347:Well Balanced Axe" } },
		{ "Magister Kalendris", { "18374:Flamescarred Shoulders", "18397:Elder Magus Pendant", "18371:Mindtap Talisman", "18350:Amplifying Cloak", "18351:Magically Sealed Bracers", "22309:Pattern: Big Bag of Enchantment" } },
		{ "Tsu'zee", { "18387:Brightspark Gloves", "18346:Threadbare Trousers", "18345:Murmuring Ring" } },
		{ "Immol'thar", { "18381:Evil Eye Pendant", "18384:Bile-etched Spaulders", "18389:Cloak of the Cosmos", "18385:Robe of Everlasting Night", "18394:Demon Howl Wristguards", "18377:Quickdraw Gloves", "18391:Eyestalk Cord", "18379:Odious Greaves", "18370:Vigilance Charm", "18372:Blade of the New Moon" } },
		{ "Prince Tortheldrin", { "18382:Fluctuating Cloak", "18373:Chestplate of Tranquility", "18375:Bracers of the Eclipse", "18378:Silvermoon Leggings", "18380:Eldritch Reinforced Legplates", "18395:Emerald Flame Ring", "18388:Stoneshatter", "18396:Mind Carver", "18376:Timeworn Mace", "18392:Distracting Dagger" } },
		{ "Shen'dralar Provisioner", { "18487:Pattern: Mooncloth Robe" } },
		{ "Lord Hel'nurath", { "18757:Diabolic Mantle", "18754:Fel Hardened Bracers", "18755:Xorothian Firestick", "18756:Dreadguard's Protector" } },
		{ "Guard Mol'dar", plus(DM_GUARD, { "18268:Gordok Inner Door Key" }) },
		{ "Guard Fengus", plus(DM_OGRE, { "18250:Gordok Shackle Key", "18266:Gordok Courtyard Key" }) },
		{ "Guard Slip'kik", DM_GUARD },
		{ "Stomper Kreeg", { "18425:Kreeg's Mug", "18269:Gordok Green Grog", "18284:Kreeg's Stout Beatdown", "18287:Evermurky", "18288:Molasses Firewater", "9260:Volatile Rum" } },
		{ "Knot Thimblejack's Cache", { "18414:Pattern: Belt of the Archmage", "18517:Pattern: Chromatic Cloak", "18518:Pattern: Hide of the Wild", "18519:Pattern: Shifting Cloak", "18415:Pattern: Felcloth Gloves", "18416:Pattern: Inferno Gloves", "18417:Pattern: Mooncloth Gloves", "18418:Pattern: Cloak of Warding", "18514:Pattern: Girdle of Insight", "18515:Pattern: Mongoose Boots", "18516:Pattern: Swift Flight Bracers", "18258:Gordok Ogre Suit", "18240:Ogre Tannin" } },
		{ "Captain Kromcrush", { "18503:Kromcrush's Chestplate", "18505:Mugger's Belt", "18507:Boots of the Full Moon", "18502:Monstrous Glaive" } },
		{ "Cho'Rush the Observer", { "18490:Insightful Hood", "18483:Mana Channeling Wand", "18485:Observer's Shield", "18484:Cho'Rush's Blade" } },
		{ "King Gordok", { "18526:Crown of the Ogre King", "18525:Bracers of Prosperity", "18527:Harmonious Gauntlets", "18524:Leggings of Destruction", "18521:Grimy Metal Boots", "18522:Band of the Ogre King", "18523:Brightly Glowing Stone", "18520:Barbarous Blade", "19258:Ace of Warlords", "18780:Top Half of Advanced Armorsmithing: Volume I" } },
		{ "Tribute", { "18538:Treant's Bane", "18528:Cyclone Spaulders", "18495:Redoubt Cloak", "18532:Mindsurge Robe", "18530:Ogre Forged Hauberk", "18533:Gordok Bracers of Power", "18529:Elemental Plate Girdle", "18500:Tarnished Elven Ring", "18537:Counterattack Lodestone", "18499:Barrier Shield", "18531:Unyielding Maul", "18534:Rod of the Ogre Magi", "18479:Carrion Scorpid Helm", "18480:Scarab Plate Helm", "18478:Hyena Hide Jerkin", "18475:Oddly Magical Belt", "18477:Shaggy Leggings", "18476:Mud Stained Boots", "18482:Ogre Toothpick Shooter", "18481:Skullcracking Mace", "18655:Schematic: Major Recombobulator" } },
		{ "Trash", plus(DM_TRASH, { "18255:Runn Tum Tuber", "18297:Thornling Seed", "18640:Happy Fun Rock" }) },
	},

	["Blackrock Spire"] = {
		{ "Burning Felguard", { "13181:Demonskin Gloves", "13182:Phase Blade" } },
		{ "Spirestone Butcher", { "12608:Butcher's Apron", "13286:Rivenspike" } },
		{ "Highlord Omokk", { "16670:Boots of Elements", "13166:Slamshot Shoulders", "13168:Plate of the Shaman King", "13170:Skyshroud Leggings", "13169:Tressermane Leggings", "13167:Fist of Omokk", "12336:Gemstone of Spirestone", "12534:Omokk's Head" } },
		{ "Spirestone Battle Lord", { "13284:Swiftdart Battleboots", "13285:The Blackrock Slicer" } },
		{ "Spirestone Lord Magus", { "13282:Ogreseer Tower Boots", "13283:Magus Ring", "13261:Globe of D'sak" } },
		{ "Shadow Hunter Vosh'gajin", { "16712:Shadowcraft Gloves", "13257:Demonic Runed Spaulders", "12626:Funeral Cuffs", "13255:Trueaim Gauntlets", "12653:Riphook", "12651:Blackcrow", "12654:Doomshot" } },
		{ "War Master Voone", { "16676:Beaststalker's Gloves", "13177:Talisman of Evasion", "13179:Brazecore Armguards", "22231:Kayser's Boots of Precision", "13173:Flightblade Throwing Axe", "12582:Keris of Zul'Serak", "12335:Gemstone of Smolderthorn", "13175:Voone's Twitchbow" } },
		{ "Bannok Grimaxe", { "12637:Backusarian Gauntlets", "12634:Chiselbrand Girdle", "12621:Demonfork", "12838:Plans: Arcanite Reaper" } },
		{ "Mother Smolderweb", { "16715:Wildheart Boots", "13244:Gilded Gauntlets", "13213:Smolderweb's Eye", "13183:Venomspitter" } },
		{ "Crystal Fang", { "13185:Sunderseer Mantle", "13184:Fallbrush Handgrips", "13218:Fang of the Crystal Spider" } },
		{ "Urok Doomhowl", { "13258:Slaghide Gauntlets", "22232:Marksman's Girdle", "13259:Ribsteel Footguards", "13178:Rosewine Circle", "18784:Top Half of Advanced Armorsmithing: Volume III" } },
		{ "Quartermaster Zigris", { "13247:Quartermaster Zigris' Footlocker", "13253:Hands of Power", "13252:Cloudrunner Girdle", "12835:Plans: Annihilator" } },
		{ "Halycon", { "13212:Halycon's Spiked Collar", "22313:Ironweave Bracers", "13211:Slashclaw Bracers", "13210:Pads of the Dread Wolf" } },
		{ "Gizrul the Slavener", { "16718:Wildheart Spaulders", "13208:Bleak Howler Armguards", "13206:Wolfshear Leggings", "13205:Rhombeard Protector" } },
		{ "Ghok Bashguud", { "13203:Armswake Cloak", "13198:Hurd Smasher", "13204:Bashguuder" } },
		{ "Overlord Wyrmthalak", { "13143:Mark of the Dragon Lord", "16679:Beaststalker's Mantle", "13162:Reiver Claws", "13164:Heart of the Scale", "22321:Heart of Wyrmthalak", "13163:Relentless Scythe", "13148:Chillpike", "13161:Trindlehaven Staff", "12337:Gemstone of Bloodaxe", "12780:General Drakkisath's Command" } },
		{ "Pyroguard Emberseer", { "16672:Gauntlets of Elements", "12929:Emberfury Talisman", "12927:Truestrike Shoulders", "12905:Wildfire Cape", "12926:Flaming Band", "23320:Tablet of Flame Shock VI" } },
		{ "Solakar Flamewreath", { "16695:Devout Mantle", "12609:Polychromatic Visionwrap", "12603:Nightbrace Tunic", "12589:Dustfeather Sash", "12606:Crystallized Girdle", "18657:Schematic: Hyper-Radiant Flame Reflector" } },
		{ "Jed Runewatcher", { "12604:Starfire Tiara", "12930:Briarwood Reed", "12605:Serpentine Skuller" } },
		{ "Goraluk Anvilcrack", { "13502:Handcrafted Mastersmith Girdle", "13498:Handcrafted Mastersmith Leggings", "18047:Flame Walkers", "18048:Mastersmith's Hammer", "12834:Plans: Arcanite Champion", "12837:Plans: Masterwork Stormhammer", "18779:Bottom Half of Advanced Armorsmithing: Volume I", "12806:Unforged Rune Covered Breastplate", "12696:Plans: Demon Forged Breastplate" } },
		{ "Gyth", { "12871:Chromatic Carapace", "16669:Pauldrons of Elements", "22225:Dragonskin Cowl", "12960:Tribal War Feathers", "12953:Dragoneye Coif", "12952:Gyth's Skull", "13522:Recipe: Flask of Chromatic Resistance" } },
		{ "Warchief Rend Blackhand", { "12590:Felstriker", "16733:Spaulders of Valor", "12587:Eye of Rend", "12588:Bonespike Shoulder", "12936:Battleborn Armbraces", "18104:Feralsurge Girdle", "12935:Warmaster Legguards", "18102:Dragonrider Boots", "22247:Faith Healer's Boots", "18103:Band of Rumination", "12940:Dal'Rend's Sacred Charge", "12939:Dal'Rend's Tribal Guardian", "12583:Blackhand Doomsaw" } },
		{ "The Beast", { "12731:Pristine Hide of the Beast", "16729:Lightforge Spaulders", "12967:Bloodmoon Cloak", "12968:Frostweaver Cape", "12966:Blackmist Armguards", "12965:Spiritshroud Leggings", "12963:Blademaster Leggings", "12964:Tristam Legguards", "22311:Ironweave Boots", "12709:Pip's Skinner", "12969:Seeping Willow", "24101:Book of Ferocious Bite V", "19227:Ace of Beasts" } },
		{ "General Drakkisath", { "12592:Blackblade of Shahram", "22267:Spellweaver's Turban", "13141:Tooth of Gnarr", "22269:Shadow Prowler's Cloak", "13142:Brigam Girdle", "13098:Painweaver Band", "22268:Draconic Infused Emblem", "22253:Tome of the Lost", "12602:Draconian Deflector", "15730:Pattern: Red Dragonscale Breastplate", "13519:Recipe: Flask of the Titans", "16690:Devout Robe", "16688:Magister's Robes", "16700:Dreadmist Robe", "16721:Shadowcraft Tunic", "16706:Wildheart Vest", "16674:Beaststalker's Tunic", "16666:Vest of Elements", "16726:Lightforge Breastplate", "16730:Breastplate of Valor" } },
	},

	["Scholomance"] = {
		{ "Blood Steward of Kirtonos", { "13523:Blood of Innocents" } },
		{ "Kirtonos the Herald", { "16734:Boots of Valor", "13960:Heart of the Fiend", "13955:Stoneform Shoulders", "13969:Loomguard Armbraces", "13957:Gargoyle Slashers", "13956:Clutch of Andros", "13967:Windreaver Greaves", "14024:Frightalon", "13983:Gravestone War Axe" } },
		{ "Jandice Barov", { "16701:Dreadmist Mantle", "14548:Royal Cap Spaulders", "18689:Phantasmal Cloak", "14543:Darkshade Gloves", "14545:Ghostloom Leggings", "18690:Wraithplate Leggings", "14541:Barovian Family Sword", "22394:Staff of Metanoia", "13523:Blood of Innocents" } },
		{ "Rattlegore", { "16711:Shadowcraft Boots", "14539:Bone Ring Helm", "14538:Deadwalker Mantle", "18686:Bone Golem Shoulders", "14537:Corpselight Greaves", "14528:Rattlecage Buckler", "14531:Frightskull Shaft", "18782:Top Half of Advanced Armorsmithing: Volume II", "13873:Viewing Room Key" } },
		{ "Death Knight Darkreaver", { "18760:Necromantic Band", "18761:Oblivion's Touch", "18758:Specter's Blade", "18759:Malicious Axe" } },
		{ "Marduk Blackpool", { "18692:Death Knight Sabatons", "14576:Ebon Hilt of Marduk" } },
		{ "Vectus", { "18691:Dark Advisor's Pendant", "14577:Skullsmoke Pants" } },
		{ "Ras Frostwhisper", { "13314:Alanna's Embrace", "16689:Magister's Mantle", "14503:Death's Clutch", "14340:Freezing Lich Robes", "18693:Shivery Handwraps", "14525:Boneclenched Gauntlets", "14502:Frostbite Girdle", "14522:Maelstrom Leggings", "18694:Shadowy Mail Greaves", "18695:Spellbound Tome", "18696:Intricately Runed Shield", "13952:Iceblade Hacker", "14487:Bonechill Hammer", "13521:Recipe: Flask of Supreme Power" } },
		{ "Instructor Malicia", plus(SCHOLO, { "16710:Shadowcraft Bracers" }) },
		{ "Doctor Theolen Krastinov", plus(SCHOLO, { "16684:Magister's Gloves", "14617:Sawbones Shirt" }) },
		{ "Lorekeeper Polkelt", plus(SCHOLO, { "16705:Dreadmist Wraps" }) },
		{ "The Ravenian", plus(SCHOLO, { "16716:Wildheart Belt" }) },
		{ "Lord Alexei Barov", plus(SCHOLO, { "16722:Lightforge Bracers" }) },
		{ "Lady Illucia Barov", SCHOLO },
		{ "Darkmaster Gandling", { "13937:Headmaster's Charge", "14514:Pattern: Robe of the Void", "16693:Devout Crown", "16686:Magister's Crown", "16698:Dreadmist Mask", "16707:Shadowcraft Cap", "16720:Wildheart Cowl", "16677:Beaststalker's Cap", "16667:Coif of Elements", "16727:Lightforge Helm", "16731:Helm of Valor", "13944:Tombstone Breastplate", "13951:Vigorsteel Vambraces", "13950:Detention Strap", "13398:Boots of the Shrieker", "22433:Don Mauricio's Band of Domination", "13938:Bonecreeper Stylus", "13953:Silent Fang", "13964:Witchblade", "19276:Ace of Portals", "13501:Recipe: Major Mana Potion" } },
	},

	["Stratholme"] = {
		{ "Skul", { "13395:Skul's Fingerbone Claws", "13394:Skul's Cold Embrace", "13396:Skul's Ghastly Touch" } },
		{ "Stratholme Courier", { "13303:Crusaders' Square Postbox Key", "13305:Elders' Square Postbox Key", "13304:Festival Lane Postbox Key", "13307:Ezra Grimm's Postbox Key", "13306:King's Square Postbox Key", "13302:Market Row Postbox Key" } },
		{ "Hearthsinger Forresten", { "16682:Magister's Boots", "13378:Songbird Blouse", "13384:Rainbow Girdle", "13383:Woollies of the Prancing Minstrel", "13379:Piccolo of the Flaming Fire" } },
		{ "The Unforgiven", { "16717:Wildheart Gloves", "13404:Mask of the Unforgiven", "13405:Wailing Nightbane Pauldrons", "13409:Tearfall Bracers", "13408:Soul Breaker" } },
		{ "Postmaster Malown", { "13390:The Postmaster's Band", "13388:The Postmaster's Tunic", "13389:The Postmaster's Trousers", "13391:The Postmaster's Treads", "13392:The Postmaster's Seal", "13393:Malown's Slam" } },
		{ "Timmy the Cruel", { "16724:Lightforge Gauntlets", "13400:Vambraces of the Sadist", "13403:Grimgore Noose", "13402:Timmy's Galosches", "13401:The Cruel Hand of Timmy" } },
		{ "Malor the Zealous", { "12845:Medallion of Faith" } },
		{ "Crimson Hammersmith", { "18781:Bottom Half of Advanced Armorsmithing: Volume II" } },
		{ "Cannon Master Willey", { "16708:Shadowcraft Spaulders", "22407:Helm of the New Moon", "22403:Nacreous Shell Necklace", "22405:Mantle of the Scarlet Crusade", "18721:Barrage Girdle", "13381:Master Cannoneer Boots", "13382:Cannonball Runner", "13380:Willey's Portable Howitzer", "13377:Miniature Cannon Balls", "22404:Willey's Back Scratcher", "22406:Redemption", "12839:Plans: Heartseeker" } },
		{ "Archivist Galford", { "16692:Devout Gloves", "13386:Archivist Cape", "13387:Foresight Girdle", "18716:Ash Covered Boots", "13385:Tome of Knowledge", "12811:Righteous Orb", "22897:Tome of Conjure Food VII" } },
		{ "Balnazzar", { "13353:Book of the Dead", "14512:Pattern: Truefaith Vestments", "16725:Lightforge Boots", "13359:Crown of Tyranny", "18718:Grand Crusader's Helm", "12103:Star of Mystaria", "18720:Shroud of the Nathrezim", "13358:Wyrmtongue Shoulders", "13369:Fire Striders", "13360:Gift of the Elven Magi", "18717:Hammer of the Grand Crusader", "22334:Band of Mending", "13348:Demonshear", "13520:Recipe: Flask of Distilled Wisdom", "13250:Head of Balnazzar" } },
		{ "Magistrate Barthilas", { "18727:Crimson Felt Hat", "13376:Royal Tribunal Cloak", "18726:Magistrate's Cuffs", "18722:Death Grips", "23198:Idol of Brutality", "18725:Peacemaker", "12382:Key to the City" } },
		{ "Stonespine", { "13397:Stoneskin Gargoyle Cape", "13954:Verdant Footpads", "13399:Gargoyle Shredder Talons" } },
		{ "Baroness Anastari", { "16704:Dreadmist Sandals", "18728:Anastari Heirloom", "18730:Shadowy Laced Handwraps", "18729:Screeching Bow", "13534:Banshee Finger", "13538:Windshrieker Pauldrons", "13535:Coldtouch Phantom Wraps", "13537:Chillhide Bracers", "13539:Banshee's Touch", "13514:Wail of the Banshee" } },
		{ "Black Guard Swordsmith", { "18783:Bottom Half of Advanced Armorsmithing: Volume III" } },
		{ "Nerub'enkan", { "16675:Beaststalker's Boots", "18740:Thuzadin Sash", "18739:Chitinous Plate Legguards", "18738:Carapace Spine Crossbow", "13529:Husk of Nerub'enkan", "13533:Acid-etched Pauldrons", "13532:Darkspinner Claws", "13531:Crypt Stalker Leggings", "13530:Fangdrip Runners", "13508:Eye of Arachnida" } },
		{ "Maleki the Pallid", { "16691:Devout Sandals", "18734:Pale Moon Cloak", "18735:Maleki's Footwraps", "13524:Skull of Burning Shadows", "18737:Bone Slicing Hatchet", "13528:Twilight Void Bracers", "13525:Darkbind Fingers", "13526:Flamescarred Girdle", "13527:Lavawalker Greaves", "13509:Clutch of Foresight", "12833:Plans: Hammer of the Titans" } },
		{ "Ramstein the Gorger", { "16737:Gauntlets of Valor", "18723:Animated Chain Necklace", "13374:Soulstealer Mantle", "13373:Band of Flesh", "13515:Ramstein's Lightning Bolts", "13375:Crest of Retribution", "13372:Slavedriver's Cane" } },
		{ "Baron Rivendare", { "13335:Deathcharger's Reins", "13505:Runeblade of Baron Rivendare", "22411:Helm of the Executioner", "22412:Thuzadin Mantle", "13340:Cape of the Black Baron", "13346:Robes of the Exalted", "22409:Tunic of the Crescent Moon", "13344:Dracorian Gauntlets", "22410:Gauntlets of Deftness", "13345:Seal of Rivendare", "22408:Ritssyn's Wand of Bad Mojo", "13349:Scepter of the Unholy", "13368:Bonescraper", "13361:Skullforge Reaver", "16694:Devout Skirt", "16687:Magister's Leggings", "16699:Dreadmist Leggings", "16709:Shadowcraft Pants", "16719:Wildheart Kilt", "16678:Beaststalker's Pants", "16668:Kilt of Elements", "16728:Lightforge Legplates", "16732:Legplates of Valor" } },
	},
}

-- Index: "Dungeon" -> { ["Boss"] = { {id, name}, ... } }, built once at load
ns.RefIndex = {}

for dungeon, bosses in pairs(ns.Reference) do
	local byBoss = {}
	for _, entry in ipairs(bosses) do
		local bossName, items = entry[1], entry[2]
		local parsed = {}
		for _, raw in ipairs(items) do
			local id, name = raw:match("^(%d+):(.+)$")
			if id then
				parsed[#parsed + 1] = { id = tonumber(id), name = name }
			end
		end
		byBoss[bossName] = parsed
	end
	ns.RefIndex[dungeon] = byBoss
end

-- Set of itemIDs per dungeon, for coverage and for spotting new items
ns.RefItemSet = {}

for dungeon, byBoss in pairs(ns.RefIndex) do
	local set, total = {}, 0
	for _, items in pairs(byBoss) do
		for _, item in ipairs(items) do
			if not set[item.id] then
				set[item.id] = true
				total = total + 1
			end
		end
	end
	ns.RefItemSet[dungeon] = { set = set, total = total }
end

function ns.IsInReference(instanceName, itemID)
	local entry = instanceName and ns.RefItemSet[instanceName]
	if not entry then return false end
	return entry.set[itemID] == true
end

-- How many reference items of that dungeon you have seen drop (seen/total),
-- and how many you saw that are NOT in the reference (extra).
function ns.Coverage(instanceName, dbKey)
	local entry = instanceName and ns.RefItemSet[instanceName]
	local total = entry and entry.total or 0

	local db = ns.db
	local instance = db and dbKey and db.instances[dbKey]
	if not instance then return 0, total, 0 end

	local seen, extra, counted = 0, 0, {}
	for npcID in pairs(instance.npcs) do
		local npc = db.npcs[npcID]
		if npc then
			for itemID in pairs(npc.items) do
				if not counted[itemID] then
					counted[itemID] = true
					if entry and entry.set[itemID] then
						seen = seen + 1
					else
						extra = extra + 1
					end
				end
			end
		end
	end

	return seen, total, extra
end

function ns.GlobalCoverage()
	local total = 0
	for _, entry in pairs(ns.RefItemSet) do
		total = total + entry.total
	end

	local db = ns.db
	if not db then return 0, total, 0 end

	local seen, extra = 0, 0
	for key, instance in pairs(db.instances) do
		local s, _, e = ns.Coverage(instance.name, key)
		seen = seen + s
		extra = extra + e
	end

	return seen, total, extra
end

function ns.RefBosses(instanceName)
	return instanceName and ns.Reference[instanceName] or nil
end

function ns.RefItems(instanceName, bossName)
	local byBoss = instanceName and ns.RefIndex[instanceName]
	return byBoss and byBoss[bossName] or nil
end
