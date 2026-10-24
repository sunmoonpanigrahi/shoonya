extends TestCase


func test_weights_sum_to_one() -> void:
	for b in GameData.BIOMES.size():
		var total := 0.0
		for w in Loot.rarity_weights(b).values():
			total += w
		check_near(total, 1.0, 1e-6, "biome %d" % b)


func test_each_biome_favours_its_own_rarity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for b in GameData.BIOMES.size():
		var counts := {}
		for i in 2000:
			var r := Loot.roll_rarity(b, rng)
			counts[r] = counts.get(r, 0) + 1
			check(absi(r - b) <= 1, "biome %d rolled rarity %d" % [b, r])
		check(counts.get(b, 0) > 1000, "biome %d mostly rolls rarity %d" % [b, b])


func test_pet() -> void:
	var rng := RandomNumberGenerator.new()
	var pet := Loot.make_pet(3, "fire", rng)
	check_eq(pet["element"], "fire")
	check_eq(pet["rarity"], 3)
	check(GameData.element("fire")["pet_names"].has(pet["name"]), "fire pet name")
	check_eq(Loot.perk_description(pet), "Ember Burst: Every 12 s, stuns monsters within 12 m for 1.1 s.")
