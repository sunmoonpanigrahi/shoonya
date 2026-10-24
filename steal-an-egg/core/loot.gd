class_name Loot
extends RefCounted
## Egg rarity rolls and pets.

## Chance of each rarity for an egg in biome `biome_index`: 25% one tier lower,
## 65% the biome's own tier, 10% one tier higher (renormalised at the ends).
static func rarity_weights(biome_index: int) -> Dictionary:
	var weights := {}
	var top := GameData.RARITIES.size() - 1
	var main := clampi(biome_index, 0, top)
	weights[main] = 0.65
	if main > 0:
		weights[main - 1] = 0.25
	if main < top:
		weights[main + 1] = 0.10
	var total := 0.0
	for w in weights.values():
		total += w
	for k in weights.keys():
		weights[k] = weights[k] / total
	return weights


static func roll_rarity(biome_index: int, rng: RandomNumberGenerator) -> int:
	var weights := rarity_weights(biome_index)
	var roll := rng.randf()
	var keys := weights.keys()
	keys.sort()
	for k in keys:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return keys.back()


## Seconds before an empty nest grows a new egg.
static func nest_refill_seconds(biome_index: int) -> float:
	return 20.0 + 10.0 * biome_index


static func make_pet(rarity_index: int, element_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var names: Array = GameData.element(element_id)["pet_names"]
	return {
		"id": "pet_%d_%d" % [Time.get_ticks_usec(), rng.randi()],
		"name": names[rng.randi() % names.size()],
		"element": element_id,
		"rarity": rarity_index,
	}


static func perk_description(pet: Dictionary) -> String:
	var element_id: String = pet.get("element", "nature")
	var rarity_index := int(pet.get("rarity", 0))
	var strength := GameData.perk_strength(rarity_index)
	var pct := roundi(strength * 100.0)
	var text := ""
	match element_id:
		"nature":
			text = "Slows on you are %d%% weaker." % pct
		"earth":
			text = "Your bat stuns monsters %d%% longer." % pct
		"water":
			text = "Builds you a new trap every %d s while you are out." % roundi(40.0 - 4.0 * rarity_index)
		"ice":
			text = "Monsters within 20 m of you are %d%% slower." % roundi(strength * 50.0)
		"fire":
			text = "Every 12 s, stuns monsters within 12 m for %.1f s." % (0.5 + 2.0 * strength)
		"lightning":
			text = "Your bat recharges %d%% faster." % pct
		"dark":
			text = "Monsters wake up %.1f s later after you grab an egg." % (1.0 + 0.5 * rarity_index)
		"light":
			text = "Shows every egg on your map and blocks blinding flashes."
	return "%s: %s" % [GameData.element(element_id)["perk"], text]
