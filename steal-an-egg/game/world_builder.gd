class_name WorldBuilder
extends RefCounted
## Builds the look of the ring world: ground, scenery, nests, the base and the sky.

const SECTORS := 8


static func build_environment(root: Node3D) -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = GameData.biome(0)["sky"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = GameData.biome(0)["fog"]
	env.fog_density = 0.0016
	env.fog_sky_affect = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	root.add_child(sun)
	return we


## Blends sky and fog colours as the player moves between biomes.
static func update_environment(we: WorldEnvironment, pos: Vector3, delta: float) -> void:
	var r := Vector2(pos.x, pos.z).length()
	var sky: Color = GameData.biome(0)["sky"]
	var fog: Color = GameData.biome(0)["fog"]
	for i in GameData.BIOMES.size():
		var start := WorldLayout.ring_inner_radius(i + 1)
		var k := smoothstep(start - 40.0, start + 40.0, r)
		sky = sky.lerp(GameData.biome(i)["sky"], k)
		fog = fog.lerp(GameData.biome(i)["fog"], k)
	var env := we.environment
	var blend := clampf(delta * 3.0, 0.0, 1.0)
	env.background_color = env.background_color.lerp(sky, blend)
	env.fog_light_color = env.fog_light_color.lerp(fog, blend)


static func build_ground(root: Node3D) -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	root.add_child(ground)
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 256
	noise.height = 256
	var fast := FastNoiseLite.new()
	fast.frequency = 0.03
	noise.noise = fast
	_add_ground_ring(ground, 0.0, GameData.BASE_RADIUS, Color(0.55, 0.52, 0.48), noise)
	for i in GameData.BIOMES.size():
		_add_ground_ring(ground, WorldLayout.ring_inner_radius(i + 1), WorldLayout.ring_outer_radius(i + 1), GameData.biome(i)["ground"], noise)
	# Thin bright lines where one biome ends and the next begins.
	for i in GameData.BIOMES.size():
		var r := WorldLayout.ring_outer_radius(i + 1)
		var line := MeshInstance3D.new()
		line.mesh = Meshes.ring(r - 1.5, r + 1.5, 256)
		line.material_override = Meshes.material(Color(1, 1, 1, 0.5), 0.0, true)
		line.position.y = 0.03
		ground.add_child(line)


static func _add_ground_ring(parent: Node3D, inner: float, outer: float, color: Color, noise: NoiseTexture2D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Meshes.ring(inner, outer, 256)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = noise
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Scattered scenery for each biome, batched into a few multimeshes per biome.
static func build_props(root: Node3D, seed_value: int) -> void:
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 99
	for b in GameData.BIOMES.size():
		var inner := WorldLayout.ring_inner_radius(b + 1) + 15.0
		var outer := WorldLayout.ring_outer_radius(b + 1) - 15.0
		var area := PI * (outer * outer - inner * inner)
		var count := clampi(int(area / 6000.0), 150, 500)
		for part in _prop_parts(GameData.biome(b)["id"]):
			var per_sector: Array = []
			for s in SECTORS:
				per_sector.append([])
			for n in count / int(part.get("rarity", 1)):
				var angle := rng.randf() * TAU
				var radius := sqrt(lerpf(inner * inner, outer * outer, rng.randf()))
				var sector := int(angle / TAU * SECTORS) % SECTORS
				var size := rng.randf_range(0.7, 1.4) * float(part.get("size", 1.0))
				var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size),
					Vector3(cos(angle) * radius, float(part.get("y", 0.0)) * size + rng.randf_range(0.0, float(part.get("float", 0.0))), sin(angle) * radius))
				per_sector[sector].append(t)
			for s in SECTORS:
				_add_multimesh(props, part["mesh"], part["mat"], per_sector[s])


static func _add_multimesh(parent: Node3D, mesh: Mesh, mat: Material, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


## Each scenery piece: a mesh, a material, how high it sits, and how common it is.
static func _prop_parts(biome_id: String) -> Array[Dictionary]:
	var m := Meshes
	match biome_id:
		"forest":
			return [
				{"mesh": m.cylinder(0.25, 0.35, 3.0, 6), "mat": m.material(Color(0.4, 0.26, 0.15)), "y": 1.5, "size": 1.5},
				{"mesh": m.cone(2.0, 5.0, 7), "mat": m.material(Color(0.15, 0.45, 0.18)), "y": 5.5, "size": 1.5},
				{"mesh": m.sphere(0.8, 1.0, 8), "mat": m.material(Color(0.25, 0.55, 0.2)), "y": 0.3, "rarity": 2},
			]
		"desert":
			return [
				{"mesh": m.capsule(0.45, 4.0), "mat": m.material(Color(0.3, 0.6, 0.3)), "y": 2.0, "size": 1.2},
				{"mesh": m.box(Vector3(3, 2, 3)), "mat": m.material(Color(0.75, 0.55, 0.35)), "y": 0.6, "size": 1.6},
			]
		"ocean":
			return [
				{"mesh": m.cylinder(0.2, 0.3, 6.0, 6), "mat": m.material(Color(0.55, 0.4, 0.25)), "y": 3.0, "size": 1.2},
				{"mesh": m.sphere(2.2, 0.8, 8), "mat": m.material(Color(0.2, 0.6, 0.25)), "y": 6.2, "size": 1.2},
				{"mesh": m.cylinder(9.0, 9.0, 0.1, 16), "mat": m.material(Color(0.2, 0.55, 0.9), 0.2), "y": 0.06, "size": 2.0, "rarity": 2},
			]
		"glacier":
			return [
				{"mesh": m.cone(1.4, 7.0, 5), "mat": m.material(Color(0.75, 0.92, 1.0), 0.15), "y": 3.5, "size": 1.4},
				{"mesh": m.sphere(2.5, 2.0, 8), "mat": m.material(Color(0.97, 0.98, 1.0)), "y": 0.2, "size": 1.3},
			]
		"volcano":
			return [
				{"mesh": m.cylinder(3.0, 14.0, 18.0, 10), "mat": m.material(Color(0.25, 0.15, 0.12)), "y": 9.0, "size": 1.5, "rarity": 6},
				{"mesh": m.sphere(1.6, 2.0, 7), "mat": m.material(Color(0.18, 0.12, 0.1)), "y": 0.5, "size": 1.3},
				{"mesh": m.cylinder(6.0, 6.0, 0.1, 12), "mat": m.material(Color(1.0, 0.4, 0.05), 2.5), "y": 0.06, "size": 1.5, "rarity": 2},
			]
		"storm":
			return [
				{"mesh": m.box(Vector3(3, 14, 3)), "mat": m.material(Color(0.35, 0.36, 0.42)), "y": 7.0, "size": 1.4},
				{"mesh": m.cone(0.6, 4.0, 4), "mat": m.material(Color(1.0, 0.95, 0.35), 2.0), "y": 2.0, "size": 1.2, "rarity": 2},
			]
		"shadow":
			return [
				{"mesh": m.cylinder(0.1, 0.4, 7.0, 5), "mat": m.material(Color(0.12, 0.1, 0.12)), "y": 3.5, "size": 1.3},
				{"mesh": m.sphere(0.9, 0.9, 8), "mat": m.material(Color(0.6, 0.25, 0.9), 2.0), "y": 0.6, "size": 1.2, "rarity": 2},
				{"mesh": m.cylinder(7.0, 7.0, 0.1, 12), "mat": m.material(Color(0.2, 0.25, 0.15)), "y": 0.06, "size": 1.5, "rarity": 2},
			]
		"sky":
			return [
				{"mesh": m.sphere(4.0, 3.0, 10), "mat": m.material(Color(1, 1, 1)), "y": 6.0, "size": 1.8, "float": 30.0},
				{"mesh": m.cylinder(1.0, 1.2, 12.0, 8), "mat": m.material(Color(1.0, 0.85, 0.4), 0.5), "y": 6.0, "size": 1.2, "rarity": 2},
			]
	return []


static func build_nests(root: Node3D, nests: Array[Dictionary]) -> void:
	var holder := Node3D.new()
	holder.name = "Nests"
	root.add_child(holder)
	var twig := Meshes.material(Color(0.45, 0.32, 0.18))
	var rock := Meshes.material(Color(0.4, 0.4, 0.42))
	for nest in nests:
		var n := Node3D.new()
		n.position = nest["position"]
		holder.add_child(n)
		Meshes.add(n, Meshes.torus(0.7, 1.5), twig, Vector3(0, 0.3, 0))
		for i in 5:
			var a := TAU * i / 5.0
			Meshes.add(n, Meshes.sphere(0.6, 0.8, 6), rock, Vector3(cos(a) * 2.6, 0.2, sin(a) * 2.6))


static func build_base(root: Node3D) -> Node3D:
	var base := Node3D.new()
	base.name = "Base"
	root.add_child(base)
	var stone := Meshes.material(Color(0.7, 0.68, 0.62))
	# A low wall with gaps marks the safe zone; monsters never come inside.
	for i in 24:
		if i % 6 == 0:
			continue
		var a := TAU * i / 24.0
		var r := GameData.BASE_RADIUS
		Meshes.add(base, Meshes.box(Vector3(14.0, 1.6, 1.2)), stone, Vector3(cos(a) * r, 0.8, sin(a) * r), Vector3.ONE, Vector3(0, -a + PI * 0.5, 0))
	Meshes.add(base, Meshes.cylinder(4.0, 5.0, 1.0, 16), stone, Vector3(0, 0.5, 0))
	Meshes.add(base, Meshes.cylinder(0.3, 0.3, 14.0, 8), Meshes.material(Color(0.5, 0.35, 0.2)), Vector3(0, 7.0, 0))
	Meshes.add(base, Meshes.box(Vector3(4.0, 2.4, 0.1)), Meshes.material(Color(0.95, 0.75, 0.2), 0.5), Vector3(2.0, 12.6, 0))
	for p in GameData.MAX_PLAYERS:
		var pad := WorldLayout.pad_position(p)
		Meshes.add(base, Meshes.cylinder(7.0, 7.0, 0.15, 24), Meshes.material(GameData.PLAYER_COLORS[p], 0.4), pad + Vector3(0, 0.08, 0))
	return base


## Incubator pods on the local player's pad, showing the eggs that are hatching.
static func build_incubators(base: Node3D, player_index: int) -> Array[MeshInstance3D]:
	var pods: Array[MeshInstance3D] = []
	var pad := WorldLayout.pad_position(player_index)
	var glass := Meshes.material(Color(0.8, 0.95, 1.0, 0.35))
	for i in GameData.MAX_INCUBATORS:
		var a := TAU * i / GameData.MAX_INCUBATORS
		var pos := pad + Vector3(cos(a) * 4.2, 0.0, sin(a) * 4.2)
		Meshes.add(base, Meshes.cylinder(0.9, 1.1, 0.5, 12), Meshes.material(Color(0.3, 0.3, 0.35)), pos + Vector3(0, 0.25, 0))
		Meshes.add(base, Meshes.sphere(0.85, 1.6, 12), glass, pos + Vector3(0, 1.2, 0))
		var egg_mesh := Meshes.add(base, Meshes.sphere(0.36, 0.95, 16), Meshes.material(Color.WHITE), pos + Vector3(0, 1.1, 0))
		egg_mesh.visible = false
		pods.append(egg_mesh)
	return pods
