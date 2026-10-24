class_name WorldLayout
extends RefCounted
## Geometry of the ring world: the base in the centre and the biomes around it.

## Ring number of a position: 0 is the base, 1..8 are the biomes from the inside out.
static func ring_at(pos: Vector3) -> int:
	var r := Vector2(pos.x, pos.z).length()
	if r <= GameData.BASE_RADIUS:
		return 0
	for i in GameData.BIOMES.size():
		if r <= float(GameData.BIOMES[i]["outer_radius"]):
			return i + 1
	return GameData.BIOMES.size()


## Biome index (0..7) of a position; the base counts as the first biome.
static func biome_at(pos: Vector3) -> int:
	return maxi(ring_at(pos) - 1, 0)


static func ring_inner_radius(ring: int) -> float:
	if ring <= 0:
		return 0.0
	if ring == 1:
		return GameData.BASE_RADIUS
	return float(GameData.BIOMES[ring - 2]["outer_radius"])


static func ring_outer_radius(ring: int) -> float:
	if ring <= 0:
		return GameData.BASE_RADIUS
	return float(GameData.BIOMES[mini(ring, GameData.BIOMES.size()) - 1]["outer_radius"])


static func ring_mid_radius(ring: int) -> float:
	return (ring_inner_radius(ring) + ring_outer_radius(ring)) * 0.5


## Where a caught thief lands: the previous ring at the same angle (the base edge from the first biome).
static func respawn_point(caught_at: Vector3) -> Vector3:
	var ring := ring_at(caught_at)
	var dir := Vector2(caught_at.x, caught_at.z)
	if dir.length() < 0.01:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var radius := GameData.BASE_RADIUS - 8.0 if ring <= 1 else ring_mid_radius(ring - 1)
	return Vector3(dir.x * radius, 0.0, dir.y * radius)


## Nest positions for every biome, the same on every device for the same seed.
static func nest_positions(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Dictionary] = []
	for b in GameData.BIOMES.size():
		var inner := ring_inner_radius(b + 1)
		var outer := ring_outer_radius(b + 1)
		var offset := rng.randf() * TAU
		for n in GameData.NESTS_PER_BIOME:
			var angle := offset + TAU * n / GameData.NESTS_PER_BIOME + rng.randf_range(-0.4, 0.4)
			var radius := lerpf(inner, outer, rng.randf_range(0.3, 0.75))
			out.append({"biome": b, "position": Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)})
	return out


## Spot on a player's coloured pad inside the base.
static func pad_position(player_index: int) -> Vector3:
	var angle := PI * 0.5 + TAU * player_index / GameData.MAX_PLAYERS
	return Vector3(cos(angle) * 28.0, 0.0, sin(angle) * 28.0)


static func clamp_to_world(pos: Vector3) -> Vector3:
	var flat := Vector2(pos.x, pos.z)
	if flat.length() > GameData.WORLD_RADIUS - 5.0:
		flat = flat.normalized() * (GameData.WORLD_RADIUS - 5.0)
	return Vector3(flat.x, pos.y, flat.y)
