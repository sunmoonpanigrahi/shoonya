class_name PetRoamer
extends Node3D
## A hatched pet living at your base: it wanders around your pad, stopping now and then.

const SPEED := 2.2

var home := Vector3.ZERO
var pet: Dictionary = {}
var _model: Node3D
var _label: Label3D
var _target := Vector3.ZERO
var _idle_left := 0.0
var _phase := 0.0
var _pop_left := 0.0


func setup(pet_info: Dictionary, home_position: Vector3, start: Vector3) -> void:
	pet = pet_info
	home = home_position
	name = "Roamer_" + str(pet.get("id", ""))
	_model = PetModel.build(pet["element"], int(pet["rarity"]))
	add_child(_model)
	position = start
	_target = start
	_idle_left = randf_range(0.0, 2.0)
	_phase = randf() * TAU
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.text = pet["name"]
	_label.font_size = 40
	_label.outline_size = 8
	_label.modulate = GameData.rarity(int(pet["rarity"]))["color"]
	_label.position = Vector3(0, 1.9, 0)
	_label.visible = false
	add_child(_label)


## Plays the "just hatched" jump and shows its name for a few seconds.
func pop() -> void:
	_pop_left = 1.2
	_label.visible = true
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(_label):
			_label.visible = false)


func _process(delta: float) -> void:
	if _pop_left > 0.0:
		_pop_left = maxf(_pop_left - delta, 0.0)
		var k := 1.0 - _pop_left / 1.2
		_model.scale = Vector3.ONE * _model_scale() * minf(k * 1.6, 1.0 + 0.25 * sin(k * PI))
		_model.position.y = sin(k * PI) * 1.4
		return
	var to := _target - position
	to.y = 0.0
	var walking := to.length() > 0.2 and _idle_left <= 0.0
	if walking:
		position += to.normalized() * minf(SPEED * delta, to.length())
		rotation.y = atan2(-to.x, -to.z)
	else:
		_idle_left -= delta
		if _idle_left <= 0.0 and to.length() <= 0.2:
			_idle_left = randf_range(1.0, 3.5)
			var angle := randf() * TAU
			_target = home + Vector3(cos(angle), 0, sin(angle)) * randf_range(5.5, 11.0)
	_phase += delta * (12.0 if walking else 3.0)
	PetModel.animate(_model, _phase, walking)


func _model_scale() -> float:
	return 0.9 + 0.08 * int(pet["rarity"])
