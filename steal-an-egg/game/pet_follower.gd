class_name PetFollower
extends Node3D
## The equipped pet, hopping along next to its thief.

var thief: Thief
var _model: Node3D
var _hop := 0.0


func setup(owner_thief: Thief, element_id: String, rarity_index: int) -> void:
	thief = owner_thief
	name = "Pet%d" % owner_thief.peer_id
	_model = PetModel.build(element_id, rarity_index)
	add_child(_model)
	position = thief.position


func _process(delta: float) -> void:
	if not is_instance_valid(thief):
		queue_free()
		return
	var side := thief.forward().cross(Vector3.UP).normalized()
	var spot := thief.position - thief.forward() * 1.4 + side * 1.1
	if position.distance_to(spot) > 30.0:
		position = spot
	else:
		position = position.lerp(spot, clampf(delta * 8.0, 0.0, 1.0))
	position.y = 0.0
	_hop += delta * (14.0 if thief.moving else 4.0)
	PetModel.animate(_model, _hop, thief.moving)
	rotation.y = thief.yaw
