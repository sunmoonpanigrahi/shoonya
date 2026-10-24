class_name GameData
extends RefCounted
## All game tables in one place, so balancing is a data edit.

const RARITIES: Array[Dictionary] = [
	{"id": "common", "name": "Common", "hatch_seconds": 60, "coins": 10,
		"monster_kmh": 40.0, "guards": 2, "color": Color(0.88, 0.86, 0.80)},
	{"id": "rare", "name": "Rare", "hatch_seconds": 600, "coins": 50,
		"monster_kmh": 2.0e3, "guards": 2, "color": Color(0.30, 0.58, 1.00)},
	{"id": "epic", "name": "Epic", "hatch_seconds": 1800, "coins": 200,
		"monster_kmh": 1.0e5, "guards": 3, "color": Color(0.68, 0.32, 0.98)},
	{"id": "legendary", "name": "Legendary", "hatch_seconds": 2700, "coins": 500,
		"monster_kmh": 1.0e7, "guards": 3, "color": Color(1.00, 0.60, 0.10)},
	{"id": "mythical", "name": "Mythical", "hatch_seconds": 3300, "coins": 1000,
		"monster_kmh": 1.0e9, "guards": 4, "color": Color(1.00, 0.26, 0.45)},
	{"id": "secret", "name": "Secret", "hatch_seconds": 3600, "coins": 2500,
		"monster_kmh": 5.0e10, "guards": 4, "color": Color(0.10, 0.90, 0.78)},
	{"id": "eternal", "name": "Eternal", "hatch_seconds": 7200, "coins": 6000,
		"monster_kmh": 1.5e12, "guards": 5, "color": Color(0.70, 0.95, 1.00)},
	{"id": "divine", "name": "Divine", "hatch_seconds": 86400, "coins": 50000,
		"monster_kmh": 3.0e12, "guards": 6, "color": Color(1.00, 0.85, 0.25)},
]

## Ordered from the base outwards. Each biome is a ring around the base.
const BIOMES: Array[Dictionary] = [
	{"id": "forest", "name": "Forest", "element": "nature", "outer_radius": 400.0,
		"ground": Color(0.24, 0.52, 0.22), "sky": Color(0.55, 0.80, 0.95), "fog": Color(0.70, 0.85, 0.75)},
	{"id": "desert", "name": "Desert", "element": "earth", "outer_radius": 900.0,
		"ground": Color(0.86, 0.72, 0.42), "sky": Color(0.95, 0.82, 0.60), "fog": Color(0.95, 0.85, 0.65)},
	{"id": "ocean", "name": "Ocean Shore", "element": "water", "outer_radius": 1600.0,
		"ground": Color(0.93, 0.87, 0.66), "sky": Color(0.45, 0.75, 1.00), "fog": Color(0.60, 0.82, 0.95)},
	{"id": "glacier", "name": "Glacier", "element": "ice", "outer_radius": 2500.0,
		"ground": Color(0.86, 0.94, 1.00), "sky": Color(0.75, 0.88, 1.00), "fog": Color(0.88, 0.94, 1.00)},
	{"id": "volcano", "name": "Volcano", "element": "fire", "outer_radius": 3600.0,
		"ground": Color(0.22, 0.14, 0.12), "sky": Color(0.55, 0.20, 0.12), "fog": Color(0.45, 0.22, 0.15)},
	{"id": "storm", "name": "Storm Peaks", "element": "lightning", "outer_radius": 4900.0,
		"ground": Color(0.38, 0.40, 0.48), "sky": Color(0.25, 0.27, 0.40), "fog": Color(0.35, 0.37, 0.48)},
	{"id": "shadow", "name": "Shadow Swamp", "element": "dark", "outer_radius": 6400.0,
		"ground": Color(0.14, 0.12, 0.20), "sky": Color(0.10, 0.06, 0.18), "fog": Color(0.12, 0.08, 0.20)},
	{"id": "sky", "name": "Sky Island", "element": "light", "outer_radius": 8100.0,
		"ground": Color(0.96, 0.95, 0.88), "sky": Color(1.00, 0.95, 0.80), "fog": Color(1.00, 0.97, 0.88)},
]

const ELEMENTS: Dictionary = {
	"nature": {"name": "Nature", "color": Color(0.30, 0.80, 0.30),
		"ability": "Vine Snare", "ability_text": "Throws vines that slow you down.",
		"perk": "Vine Ward", "perk_text": "Slows on you are weaker.",
		"pet_names": ["Leafling", "Sproutle", "Mossy"]},
	"earth": {"name": "Earth", "color": Color(0.62, 0.45, 0.25),
		"ability": "Stone Hide", "ability_text": "Bat stuns last half as long.",
		"perk": "Slugger", "perk_text": "Your bat stuns monsters for longer.",
		"pet_names": ["Pebblit", "Rumblet", "Cragpup"]},
	"water": {"name": "Water", "color": Color(0.20, 0.55, 0.95),
		"ability": "Wave Dash", "ability_text": "Bursts forward every few seconds.",
		"perk": "Trap Maker", "perk_text": "Builds a new trap while you are out.",
		"pet_names": ["Splashfin", "Driplet", "Tideling"]},
	"ice": {"name": "Ice", "color": Color(0.65, 0.90, 1.00),
		"ability": "Frost Trail", "ability_text": "Makes the ground slippery near it.",
		"perk": "Chill Aura", "perk_text": "Monsters near you are slowed.",
		"pet_names": ["Frostkit", "Snowpuff", "Glacey"]},
	"fire": {"name": "Fire", "color": Color(1.00, 0.40, 0.10),
		"ability": "Flame Trail", "ability_text": "Burning ground slows you.",
		"perk": "Ember Burst", "perk_text": "Now and then stuns monsters around you.",
		"pet_names": ["Emberkit", "Cindercub", "Blazy"]},
	"lightning": {"name": "Lightning", "color": Color(1.00, 0.92, 0.25),
		"ability": "Blink", "ability_text": "Teleports closer to you.",
		"perk": "Quick Swing", "perk_text": "Your bat recharges faster.",
		"pet_names": ["Zapling", "Sparkit", "Voltie"]},
	"dark": {"name": "Dark", "color": Color(0.45, 0.25, 0.70),
		"ability": "Shade", "ability_text": "Nearly invisible until it is close.",
		"perk": "Shadow Cloak", "perk_text": "Monsters wake up later after you grab an egg.",
		"pet_names": ["Gloomlet", "Shadepaw", "Duskit"]},
	"light": {"name": "Light", "color": Color(1.00, 0.98, 0.75),
		"ability": "Flash", "ability_text": "Blinds you with a bright flash.",
		"perk": "Beacon", "perk_text": "Shows every egg on your map and blocks flashes.",
		"pet_names": ["Glimmer", "Halopup", "Sunnet"]},
}

const BASE_RADIUS := 60.0
const WORLD_RADIUS := 8100.0
const NESTS_PER_BIOME := 3

const TRAPS_PER_TRIP := 3
const TRAP_HOLD_SECONDS := 5.0
const TRAP_RADIUS := 1.8
const TRAP_MAX_PLACE_DISTANCE := 80.0
const TRAP_LIFETIME := 90.0

const BAT_BASE_COOLDOWN := 1.0
const BAT_BASE_STUN := 1.5
const BAT_REACH := 3.5
const BAT_CONE_DEGREES := 110.0
const THIEF_STUN_FROM_BAT := 0.8

const CATCH_RADIUS := 1.6
const PICKUP_RADIUS := 2.5
const FALL_SECONDS := 1.4

## Hatched pets wandering around your base pad.
const BASE_PETS_SHOWN := 12

const START_INCUBATORS := 2
const MAX_INCUBATORS := 6
const MAX_STORAGE := 10
## Coins for each extra incubator slot (3rd, 4th, 5th, 6th).
const INCUBATOR_COSTS: Array[int] = [100, 400, 1500, 6000]
## Coins for bat levels 1..5.
const BAT_COSTS: Array[int] = [150, 600, 2500, 10000, 40000]
## Pet Index gifts: a full biome page pays this many times its pets' hatch coins;
## the full index pays the Champion coins and a golden crown for your thief.
const INDEX_PAGE_GIFT_MULTIPLIER := 3
const INDEX_CHAMPION_COINS := 100000

const BAT_STUN_PER_LEVEL := 0.25
const BAT_COOLDOWN_PER_LEVEL := 0.08

const LAN_GAME_PORT := 8910
## Joiners listen here for hosts announcing themselves.
const LAN_DISCOVERY_PORT := 8911
## Hosts listen here for joiners asking who is hosting.
const LAN_PROBE_PORT := 8912
## How long a quiet phone is waited for before it counts as gone (ENet peer timeout).
const NET_TIMEOUT_LIMIT := 64
const NET_TIMEOUT_MIN_MS := 15000
const NET_TIMEOUT_MAX_MS := 60000
const MAX_PLAYERS := 4
const PLAYER_COLORS: Array[Color] = [
	Color(0.95, 0.30, 0.30), Color(0.25, 0.60, 1.00), Color(0.30, 0.85, 0.40), Color(1.00, 0.80, 0.20),
]


static func rarity(index: int) -> Dictionary:
	return RARITIES[clampi(index, 0, RARITIES.size() - 1)]


static func biome(index: int) -> Dictionary:
	return BIOMES[clampi(index, 0, BIOMES.size() - 1)]


static func element(id: String) -> Dictionary:
	return ELEMENTS.get(id, ELEMENTS["nature"])


static func element_of_biome(index: int) -> String:
	return biome(index)["element"]


static func biome_of_element(element_id: String) -> int:
	for i in BIOMES.size():
		if BIOMES[i]["element"] == element_id:
			return i
	return 0


## Pet perk strength by egg rarity: 0.15 for common up to 0.5 for divine.
static func perk_strength(rarity_index: int) -> float:
	return 0.15 + 0.05 * clampi(rarity_index, 0, RARITIES.size() - 1)


static func bat_cooldown(bat_level: int, pet_element: String, pet_rarity: int) -> float:
	var cooldown := BAT_BASE_COOLDOWN - BAT_COOLDOWN_PER_LEVEL * bat_level
	if pet_element == "lightning":
		cooldown *= 1.0 - perk_strength(pet_rarity)
	return maxf(cooldown, 0.3)


static func bat_stun(bat_level: int, pet_element: String, pet_rarity: int) -> float:
	var stun := BAT_BASE_STUN + BAT_STUN_PER_LEVEL * bat_level
	if pet_element == "earth":
		stun *= 1.0 + perk_strength(pet_rarity)
	return stun


static func delivery_coins(rarity_index: int) -> int:
	return maxi(2, int(rarity(rarity_index)["coins"]) / 10)


static func incubator_slots(level: int) -> int:
	return mini(START_INCUBATORS + level, MAX_INCUBATORS)
