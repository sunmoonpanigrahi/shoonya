class_name Meshes
extends RefCounted
## Small helpers for the placeholder 3D art, built from simple shapes.

static var _materials: Dictionary = {}


static func material(color: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), emission, unshaded]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = mat
	return mat


## A material that can be changed per object (not shared through the cache).
static func own_material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = material(color, emission).duplicate()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func sphere(radius: float, height: float = -1.0, segments: int = 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 if height < 0.0 else height
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 4)
	return m


static func cylinder(top: float, bottom: float, height: float, segments: int = 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func cone(radius: float, height: float, segments: int = 8) -> CylinderMesh:
	return cylinder(0.0, radius, height, segments)


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	return m


static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 8
	return m


## Flat ring on the ground between two radii (a full disc when inner is 0).
static func ring(inner: float, outer: float, segments: int = 128) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var o0 := Vector3(cos(a0) * outer, 0, sin(a0) * outer)
		var o1 := Vector3(cos(a1) * outer, 0, sin(a1) * outer)
		var i0 := Vector3(cos(a0) * inner, 0, sin(a0) * inner)
		var i1 := Vector3(cos(a1) * inner, 0, sin(a1) * inner)
		for v in [i0, o1, o0, i0, i1, o1]:
			st.set_uv(Vector2(v.x, v.z) * 0.05)
			st.add_vertex(v)
	return st.commit()


static func egg(rarity_index: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = sphere(0.36, 0.95, 16)
	var color: Color = GameData.rarity(rarity_index)["color"]
	mi.material_override = material(color, 0.15 + 0.2 * rarity_index)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
