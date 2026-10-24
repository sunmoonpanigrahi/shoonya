class_name Egg
extends Node3D
## One egg per nest. The host decides its state; everyone shows it.

enum State { NEST, CARRIED, DROPPED, EMPTY }

var id := 0
var biome := 0
var element := "nature"
var rarity := 0
var state := State.NEST
var carrier := 0
var nest_position := Vector3.ZERO
## Host-only: seconds until an empty nest grows a new egg.
var refill_left := 0.0

var _mesh: MeshInstance3D
var _beacon: MeshInstance3D
var _beacon_material: StandardMaterial3D
var _spin := 0.0


func setup(egg_id: int, biome_index: int, nest_pos: Vector3, rarity_index: int) -> void:
	id = egg_id
	name = "Egg%d" % egg_id
	biome = biome_index
	element = GameData.element_of_biome(biome_index)
	nest_position = nest_pos
	position = nest_pos
	_spin = egg_id * 0.7
	_beacon_material = Meshes.own_material(Color.WHITE, 1.0)
	_beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon = Meshes.add(self, Meshes.cylinder(0.5, 0.5, 1.0, 8), _beacon_material)
	set_rarity(rarity_index)


func set_rarity(rarity_index: int) -> void:
	rarity = rarity_index
	if _mesh:
		_mesh.queue_free()
	_mesh = Meshes.egg(rarity)
	add_child(_mesh)
	var col: Color = GameData.rarity(rarity)["color"]
	_beacon_material.albedo_color = Color(col.r, col.g, col.b, 0.35)


func is_takeable() -> bool:
	return state == State.NEST or state == State.DROPPED


func pack() -> Array:
	return [id, state, rarity, position, carrier]


func _process(delta: float) -> void:
	visible = state != State.EMPTY
	_spin += delta
	match state:
		State.NEST:
			position = nest_position
			_mesh.position.y = 0.9 + sin(_spin * 2.0) * 0.12
			_mesh.rotation.y = _spin
		State.DROPPED:
			_mesh.position.y = 0.48
			_mesh.rotation.y = _spin * 2.0
		State.CARRIED:
			_mesh.position.y = 0.0
	# Tall light beams make eggs easy to find from far away; a dropped egg shines brightest.
	var height := 150.0 if state == State.DROPPED else 30.0 + 10.0 * rarity
	_beacon.visible = state != State.CARRIED
	_beacon.scale = Vector3(1.0 if state == State.DROPPED else 0.5, height, 1.0 if state == State.DROPPED else 0.5)
	_beacon.position.y = height * 0.5
