extends TestCase


func test_rings() -> void:
	check_eq(WorldLayout.ring_at(Vector3.ZERO), 0, "centre is the base")
	check_eq(WorldLayout.ring_at(Vector3(59, 0, 0)), 0, "inside base")
	check_eq(WorldLayout.ring_at(Vector3(61, 0, 0)), 1, "forest starts after base")
	check_eq(WorldLayout.ring_at(Vector3(0, 0, 401)), 2, "desert after forest")
	check_eq(WorldLayout.ring_at(Vector3(8000, 0, 0)), 8, "sky island is last")
	check_eq(WorldLayout.ring_at(Vector3(20000, 0, 0)), 8, "beyond the edge stays in the last biome")
	check_eq(WorldLayout.biome_at(Vector3(1000, 0, 0)), 2, "ocean shore")


func test_ring_radii_are_continuous() -> void:
	for ring in range(1, GameData.BIOMES.size() + 1):
		check_eq(WorldLayout.ring_inner_radius(ring), WorldLayout.ring_outer_radius(ring - 1), "ring %d" % ring)


func test_respawn_lands_in_previous_biome() -> void:
	for ring in range(1, GameData.BIOMES.size() + 1):
		var caught := Vector3(WorldLayout.ring_mid_radius(ring), 0, 0).rotated(Vector3.UP, 0.7)
		var landed := WorldLayout.respawn_point(caught)
		check_eq(WorldLayout.ring_at(landed), ring - 1, "caught in ring %d" % ring)
		check_near(Vector2(landed.x, landed.z).angle_to(Vector2(caught.x, caught.z)), 0.0, 1e-4, "same direction")


func test_nests_are_deterministic_and_in_their_biome() -> void:
	var a := WorldLayout.nest_positions(1234)
	var b := WorldLayout.nest_positions(1234)
	check_eq(a.size(), GameData.BIOMES.size() * GameData.NESTS_PER_BIOME, "nest count")
	for i in a.size():
		check_eq(a[i]["position"], b[i]["position"], "same seed, same nests")
		check_eq(WorldLayout.biome_at(a[i]["position"]), a[i]["biome"], "nest %d inside its biome" % i)


func test_pads_are_inside_base() -> void:
	for i in GameData.MAX_PLAYERS:
		check_eq(WorldLayout.ring_at(WorldLayout.pad_position(i)), 0, "pad %d" % i)
