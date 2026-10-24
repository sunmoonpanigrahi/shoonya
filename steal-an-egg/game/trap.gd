class_name Trap
extends Node3D
## A placed trap. It snaps shut on the first monster or rival thief that runs over it
## and holds them for exactly 5 seconds. Its owner can run over it safely.

enum State { ARMED, HOLDING }

const ARM_SECONDS := 0.25

var id := 0
var owner_peer := 0
var state := State.ARMED
var hold_left := 0.0
var age := 0.0
## Host-only: what the trap is holding ("monster" or "thief") and its id.
var victim_kind := ""
var victim_id := 0

var _teeth: Array[MeshInstance3D] = []
var _label: Label3D


func setup(trap_id: int, owner_id: int, pos: Vector3, owner_color: Color) -> void:
	id = trap_id
	name = "Trap%d" % trap_id
	owner_peer = owner_id
	position = Vector3(pos.x, 0.0, pos.z)
	var metal := Meshes.material(Color(0.45, 0.47, 0.5), 0.1)
	Meshes.add(self, Meshes.cylinder(1.2, 1.25, 0.1, 16), metal, Vector3(0, 0.05, 0))
	Meshes.add(self, Meshes.torus(1.15, 1.35), Meshes.material(owner_color, 1.0), Vector3(0, 0.08, 0))
	var tooth_material := Meshes.material(Color(0.85, 0.87, 0.9))
	for i in 10:
		var a := TAU * i / 10.0
		var pivot := MeshInstance3D.new()
		pivot.position = Vector3(cos(a) * 1.05, 0.1, sin(a) * 1.05)
		pivot.rotation.y = -a
		add_child(pivot)
		Meshes.add(pivot, Meshes.cone(0.12, 0.45, 4), tooth_material, Vector3(0, 0.22, 0))
		_teeth.append(pivot)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 3.6, 0)
	_label.font_size = 64
	_label.outline_size = 10
	_label.modulate = Color(1, 0.35, 0.3)
	_label.no_depth_test = true
	add_child(_label)


func is_armed() -> bool:
	return state == State.ARMED and age >= ARM_SECONDS


func snap(kind: String, victim: int) -> void:
	state = State.HOLDING
	hold_left = GameData.TRAP_HOLD_SECONDS
	victim_kind = kind
	victim_id = victim


func pack() -> Array:
	return [id, owner_peer, position, state, hold_left]


func _process(delta: float) -> void:
	age += delta
	var closed := state == State.HOLDING
	for tooth in _teeth:
		tooth.rotation.z = lerpf(tooth.rotation.z, 0.9 if closed else 0.0, clampf(delta * 20.0, 0.0, 1.0))
	_label.visible = closed
	if closed:
		_label.text = "%.1f" % maxf(hold_left, 0.0)
