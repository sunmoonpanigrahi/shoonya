class_name HatchEffect
extends Node3D
## An egg hatching in the world: it shakes, cracks open, and the pet jumps out.

signal hatched(roamer: PetRoamer)

const SHAKE_SECONDS := 1.2
const SHELL_SECONDS := 0.9

var _pet: Dictionary
var _home := Vector3.ZERO
var _egg: MeshInstance3D
var _shells: Array[MeshInstance3D] = []
var _sparks: CPUParticles3D
var _time := 0.0
var _cracked := false


func setup(pet: Dictionary, at: Vector3, pad_center: Vector3) -> void:
	_pet = pet
	_home = pad_center
	position = at
	_egg = Meshes.egg(int(pet["rarity"]))
	_egg.position.y = 1.1
	add_child(_egg)
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 40
	_sparks.lifetime = 0.9
	_sparks.explosiveness = 1.0
	_sparks.direction = Vector3.UP
	_sparks.spread = 180.0
	_sparks.initial_velocity_min = 3.0
	_sparks.initial_velocity_max = 6.0
	_sparks.gravity = Vector3(0, -6, 0)
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.2
	_sparks.mesh = Meshes.sphere(0.06, -1.0, 6)
	_sparks.material_override = Meshes.material(GameData.rarity(int(pet["rarity"]))["color"], 3.0, true)
	_sparks.position.y = 1.1
	add_child(_sparks)


func _process(delta: float) -> void:
	_time += delta
	if _time < SHAKE_SECONDS:
		var k := _time / SHAKE_SECONDS
		_egg.rotation.z = sin(_time * 30.0) * 0.35 * k
		_egg.position.y = 1.1 + absf(sin(_time * 15.0)) * 0.1 * k
		return
	if not _cracked:
		_crack()
	var t := _time - SHAKE_SECONDS
	for i in _shells.size():
		var shell := _shells[i]
		var dir := -1.0 if i == 0 else 1.0
		shell.position = Vector3(dir * t * 2.5, 1.1 + t * (3.0 if i == 0 else 1.0) - 6.0 * t * t, 0)
		shell.rotation.z = dir * t * 6.0
	if t > SHELL_SECONDS:
		queue_free()


func _crack() -> void:
	_cracked = true
	_egg.visible = false
	var col: Color = GameData.rarity(int(_pet["rarity"]))["color"]
	for i in 2:
		var half := SphereMesh.new()
		half.radius = 0.36
		half.height = 0.48
		half.is_hemisphere = true
		half.radial_segments = 12
		half.rings = 4
		var shell := Meshes.add(self, half, Meshes.material(col, 0.3), Vector3(0, 1.1, 0), Vector3.ONE,
			Vector3(PI if i == 1 else 0.0, 0, 0))
		_shells.append(shell)
	_sparks.emitting = true
	var roamer := PetRoamer.new()
	get_parent().add_child(roamer)
	roamer.setup(_pet, _home, position)
	roamer.pop()
	hatched.emit(roamer)
