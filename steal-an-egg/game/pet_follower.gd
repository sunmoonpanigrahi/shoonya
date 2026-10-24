class_name PetFollower
extends Node3D
## The equipped pet, hopping along next to its thief.

var thief: Thief
var _body: Node3D
var _hop := 0.0


func setup(owner_thief: Thief, element_id: String, rarity_index: int) -> void:
	thief = owner_thief
	name = "Pet%d" % owner_thief.peer_id
	var col: Color = GameData.element(element_id)["color"]
	var glow := 0.1 + 0.25 * rarity_index
	_body = Node3D.new()
	add_child(_body)
	Meshes.add(_body, Meshes.sphere(0.32, 0.55), Meshes.material(col, glow), Vector3(0, 0.3, 0))
	for side in [-1.0, 1.0]:
		Meshes.add(_body, Meshes.cone(0.09, 0.25, 5), Meshes.material(col.darkened(0.25), glow), Vector3(0.15 * side, 0.62, 0))
		Meshes.add(_body, Meshes.sphere(0.06), Meshes.material(Color(0.05, 0.05, 0.05)), Vector3(0.11 * side, 0.38, -0.27))
	if rarity_index >= 6:
		Meshes.add(_body, Meshes.torus(0.18, 0.22), Meshes.material(Color(1, 0.9, 0.4), 3.0), Vector3(0, 0.85, 0))
	position = thief.position


func _process(delta: float) -> void:
	if not is_instance_valid(thief):
		queue_free()
		return
	var side := thief.forward().cross(Vector3.UP).normalized()
	var spot := thief.position - thief.forward() * 1.6 + side * 1.0
	if position.distance_to(spot) > 30.0:
		position = spot
	else:
		position = position.lerp(spot, clampf(delta * 8.0, 0.0, 1.0))
	position.y = 0.0
	_hop += delta * (14.0 if thief.moving else 4.0)
	_body.position.y = absf(sin(_hop)) * 0.35
	rotation.y = thief.yaw
