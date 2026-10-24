class_name PetIndex
extends RefCounted
## The Pet Index: one entry for every pet you can hatch. Each biome's eggs come in
## a few rarities, and each biome + rarity hatches a different pet. Fill a biome's
## page for a gift; fill the whole index for the Champion's gift.

const CHAMPION_GIFT := "champion"


## Every entry, page by page (biome by biome), rarest last within a page.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in GameData.BIOMES.size():
		for r in page_rarities(b):
			out.append({"key": key_for(b, r), "biome": b, "rarity": r, "element": GameData.element_of_biome(b)})
	return out


## Egg rarities that can turn up in a biome.
static func page_rarities(biome_index: int) -> Array[int]:
	var out: Array[int] = []
	for r in Loot.rarity_weights(biome_index).keys():
		out.append(int(r))
	out.sort()
	return out


## Each entry is its own kind of pet: a biome's pets are named in rarity order.
static func species_name(biome_index: int, rarity_index: int) -> String:
	var names: Array = GameData.element(GameData.element_of_biome(biome_index))["pet_names"]
	var position := maxi(page_rarities(biome_index).find(rarity_index), 0)
	return names[position % names.size()]


static func key_for(biome_index: int, rarity_index: int) -> String:
	return "%s:%d" % [GameData.biome(biome_index)["id"], rarity_index]


## The entry a hatched pet fills in.
static func key_for_pet(pet: Dictionary) -> String:
	return key_for(GameData.biome_of_element(pet.get("element", "nature")), int(pet.get("rarity", 0)))


static func found_count(found: Dictionary) -> int:
	var n := 0
	for e in entries():
		if found.has(e["key"]):
			n += 1
	return n


static func page_found_count(found: Dictionary, biome_index: int) -> int:
	var n := 0
	for r in page_rarities(biome_index):
		if found.has(key_for(biome_index, r)):
			n += 1
	return n


static func is_page_complete(found: Dictionary, biome_index: int) -> bool:
	return page_found_count(found, biome_index) == page_rarities(biome_index).size()


static func is_complete(found: Dictionary) -> bool:
	return found_count(found) == entries().size()


static func page_gift_id(biome_index: int) -> String:
	return "page_" + str(GameData.biome(biome_index)["id"])


## A page's gift: three times the coins its pets gave when they hatched.
static func page_gift_coins(biome_index: int) -> int:
	var total := 0
	for r in page_rarities(biome_index):
		total += int(GameData.rarity(r)["coins"])
	return total * GameData.INDEX_PAGE_GIFT_MULTIPLIER


## Gifts that are earned but not yet claimed: [{"id", "title", "coins", "crown"}].
static func claimable_gifts(found: Dictionary, claimed: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in GameData.BIOMES.size():
		var id := page_gift_id(b)
		if is_page_complete(found, b) and not claimed.has(id):
			out.append({"id": id, "title": "%s page complete" % GameData.biome(b)["name"], "coins": page_gift_coins(b), "crown": false})
	if is_complete(found) and not claimed.has(CHAMPION_GIFT):
		out.append({"id": CHAMPION_GIFT, "title": "Pet Index complete!", "coins": GameData.INDEX_CHAMPION_COINS, "crown": true})
	return out
