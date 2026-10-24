class_name PetModel
extends RefCounted
## Builds a pet out of simple shapes: a round body and head with big eyes, plus ears,
## horns or a tail in its element's style. Rarer pets are bigger and glow; the rarest
## have sparkles circling them (a child node named "Sparkles").


static func build(element_id: String, rarity_index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "PetModel"
	var col: Color = GameData.element(element_id)["color"]
	var glow := 0.0 if rarity_index < 3 else 0.12 * rarity_index
	var body_mat := Meshes.material(col, glow)
	var dark_mat := Meshes.material(col.darkened(0.3), glow)
	var light_mat := Meshes.material(col.lightened(0.45))
	var white := Meshes.material(Color.WHITE)
	var black := Meshes.material(Color(0.05, 0.05, 0.08))
	root.scale = Vector3.ONE * (0.9 + 0.08 * rarity_index)

	Meshes.add(root, Meshes.sphere(0.38, 0.62, 14), body_mat, Vector3(0, 0.42, 0))
	Meshes.add(root, Meshes.sphere(0.26, 0.4, 12), light_mat, Vector3(0, 0.38, -0.2), Vector3(1, 1, 0.55))
	Meshes.add(root, Meshes.sphere(0.3, 0.56, 14), body_mat, Vector3(0, 0.86, -0.06))
	for side in [-1.0, 1.0]:
		Meshes.add(root, Meshes.sphere(0.09), white, Vector3(0.12 * side, 0.9, -0.31))
		Meshes.add(root, Meshes.sphere(0.05), black if element_id != "dark" else Meshes.material(Color(0.8, 0.3, 1.0), 2.0), Vector3(0.12 * side, 0.9, -0.38))
		Meshes.add(root, Meshes.sphere(0.018), white, Vector3(0.105 * side, 0.92, -0.425))
		Meshes.add(root, Meshes.sphere(0.05), Meshes.material(Color(1.0, 0.55, 0.6)), Vector3(0.21 * side, 0.8, -0.26), Vector3(1, 0.6, 0.5))
		Meshes.add(root, Meshes.sphere(0.11, 0.14, 8), dark_mat, Vector3(0.17 * side, 0.07, -0.08))
	Meshes.add(root, Meshes.box(Vector3(0.1, 0.02, 0.02)), black, Vector3(0, 0.79, -0.35))
	_add_element_parts(root, element_id, dark_mat, glow)
	if rarity_index >= 5:
		var sparkles := Node3D.new()
		sparkles.name = "Sparkles"
		sparkles.position = Vector3(0, 0.6, 0)
		root.add_child(sparkles)
		var spark := Meshes.material(GameData.rarity(rarity_index)["color"], 3.0)
		for i in 3:
			var a := TAU * i / 3.0
			Meshes.add(sparkles, Meshes.sphere(0.045), spark, Vector3(cos(a) * 0.62, sin(a * 2.0) * 0.15, sin(a) * 0.62))
	return root


static func _add_element_parts(root: Node3D, element_id: String, dark_mat: Material, glow: float) -> void:
	var m := Meshes
	match element_id:
		"nature":
			var leaf := m.material(Color(0.25, 0.75, 0.25), glow)
			for side in [-1.0, 1.0]:
				m.add(root, m.sphere(0.12, 0.3, 8), leaf, Vector3(0.14 * side, 1.17, 0), Vector3(0.6, 1, 0.4), Vector3(0, 0, -0.5 * side))
			m.add(root, m.cylinder(0.02, 0.02, 0.15, 5), m.material(Color(0.4, 0.3, 0.15)), Vector3(0, 1.18, 0.02))
			m.add(root, m.cone(0.09, 0.3, 6), leaf, Vector3(0, 0.38, 0.4), Vector3.ONE, Vector3(1.4, 0, 0))
		"earth":
			for side in [-1.0, 1.0]:
				m.add(root, m.cone(0.07, 0.22, 5), m.material(Color(0.5, 0.42, 0.32)), Vector3(0.15 * side, 1.15, 0), Vector3.ONE, Vector3(0, 0, -0.35 * side))
			for i in 3:
				m.add(root, m.box(Vector3(0.14, 0.1, 0.14)), dark_mat, Vector3(0, 0.62 - 0.12 * i, 0.32), Vector3.ONE, Vector3(0.6, 0.8, 0))
		"water":
			m.add(root, m.cone(0.13, 0.32, 4), m.material(Color(0.3, 0.75, 1.0), glow), Vector3(0, 1.2, 0.02), Vector3(0.35, 1, 1))
			m.add(root, m.sphere(0.2, 0.08, 8), dark_mat, Vector3(0, 0.3, 0.45), Vector3(1.4, 1, 1))
		"ice":
			var crystal := m.material(Color(0.8, 0.97, 1.0), 0.6 + glow)
			for i in 3:
				var a := -0.5 + 0.5 * i
				m.add(root, m.cone(0.06, 0.3, 4), crystal, Vector3(sin(a) * 0.15, 1.18, 0), Vector3.ONE, Vector3(0, 0, -a))
			m.add(root, m.cone(0.07, 0.28, 4), crystal, Vector3(0, 0.4, 0.42), Vector3.ONE, Vector3(1.3, 0, 0))
		"fire":
			var flame := m.material(Color(1.0, 0.55, 0.1), 2.5)
			m.add(root, m.cone(0.13, 0.36, 7), flame, Vector3(0, 1.22, 0))
			m.add(root, m.cone(0.08, 0.22, 6), m.material(Color(1.0, 0.85, 0.2), 3.0), Vector3(0, 1.17, -0.05))
			m.add(root, m.cone(0.1, 0.3, 6), flame, Vector3(0, 0.45, 0.42), Vector3.ONE, Vector3(1.2, 0, 0))
		"lightning":
			var bolt := m.material(Color(1.0, 0.95, 0.3), 2.5)
			for side in [-1.0, 1.0]:
				m.add(root, m.box(Vector3(0.06, 0.24, 0.06)), bolt, Vector3(0.16 * side, 1.15, 0), Vector3.ONE, Vector3(0, 0, -0.5 * side))
				m.add(root, m.box(Vector3(0.06, 0.16, 0.06)), bolt, Vector3(0.24 * side, 1.3, 0), Vector3.ONE, Vector3(0, 0, 0.5 * side))
			m.add(root, m.box(Vector3(0.06, 0.3, 0.06)), bolt, Vector3(0, 0.5, 0.42), Vector3.ONE, Vector3(1.0, 0, 0.4))
		"dark":
			var wing := m.material(Color(0.3, 0.12, 0.45))
			for side in [-1.0, 1.0]:
				m.add(root, m.cone(0.1, 0.3, 4), wing, Vector3(0.18 * side, 1.15, 0.02), Vector3.ONE, Vector3(0, 0, -0.45 * side))
				m.add(root, m.sphere(0.22, 0.04, 8), wing, Vector3(0.38 * side, 0.6, 0.12), Vector3(1, 1, 0.6), Vector3(0, 0, 0.6 * side))
		"light":
			m.add(root, m.torus(0.17, 0.22), m.material(Color(1.0, 0.92, 0.5), 3.0), Vector3(0, 1.32, 0))
			for side in [-1.0, 1.0]:
				m.add(root, m.sphere(0.22, 0.05, 8), m.material(Color(1, 1, 1), 0.5), Vector3(0.38 * side, 0.62, 0.12), Vector3(1, 1, 0.6), Vector3(0, 0, 0.6 * side))


## Gentle hopping and turning for any pet model; call every frame.
static func animate(model: Node3D, phase: float, hopping: bool) -> void:
	var hop := absf(sin(phase)) * (0.35 if hopping else 0.06)
	model.position.y = hop
	model.rotation.z = sin(phase * 0.5) * (0.12 if hopping else 0.04)
	var sparkles := model.get_node_or_null("Sparkles")
	if sparkles:
		sparkles.rotation.y = phase * 0.5
