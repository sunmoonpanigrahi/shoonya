extends TestCase


func test_every_findable_pet_has_an_entry() -> void:
	var entries := PetIndex.entries()
	# Forest and Sky Island have two rarities each, the six biomes between have three.
	check_eq(entries.size(), 2 + 6 * 3 + 2, "entry count")
	var keys := {}
	for e in entries:
		check(not keys.has(e["key"]), "unique key %s" % e["key"])
		keys[e["key"]] = true
		check(Loot.rarity_weights(e["biome"]).has(e["rarity"]), "%s can actually hatch" % e["key"])
	check_eq(PetIndex.page_rarities(0), [0, 1], "Forest: common and rare")
	check_eq(PetIndex.page_rarities(7), [6, 7], "Sky Island: eternal and divine")


func test_each_entry_is_its_own_pet() -> void:
	for b in GameData.BIOMES.size():
		var names := {}
		for r in PetIndex.page_rarities(b):
			names[PetIndex.species_name(b, r)] = true
		check_eq(names.size(), PetIndex.page_rarities(b).size(), "biome %d pets have different names" % b)
	var rng := RandomNumberGenerator.new()
	check_eq(Loot.make_pet(2, "earth", rng)["name"], PetIndex.species_name(1, 2), "hatched pet is that entry's pet")
	check_eq(PetIndex.key_for_pet({"element": "earth", "rarity": 2}), "desert:2")


func test_gifts() -> void:
	var found := {}
	check(PetIndex.claimable_gifts(found, []).is_empty(), "nothing yet")
	found["forest:0"] = true
	check(not PetIndex.is_page_complete(found, 0), "half a page")
	found["forest:1"] = true
	var gifts := PetIndex.claimable_gifts(found, [])
	check_eq(gifts.size(), 1, "Forest page gift")
	check_eq(gifts[0]["coins"], (10 + 50) * GameData.INDEX_PAGE_GIFT_MULTIPLIER, "page gift coins")
	check(PetIndex.claimable_gifts(found, ["page_forest"]).is_empty(), "claimed once only")
	for e in PetIndex.entries():
		found[e["key"]] = true
	check(PetIndex.is_complete(found), "full index")
	var all_gifts := PetIndex.claimable_gifts(found, ["page_forest"])
	check_eq(all_gifts.size(), GameData.BIOMES.size() - 1 + 1, "other pages plus the champion gift")
	check(all_gifts.back()["crown"], "champion gift includes the crown")
