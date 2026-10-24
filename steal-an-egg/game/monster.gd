class_name Monster
extends Node3D
## An egg guard. The host runs its brain; other phones show where the host says it is.

enum State { EMERGE, GUARD, CHASE, STUNNED, TRAPPED }

const EMERGE_SECONDS := 0.8
const GUARD_SPEED := 2.5
const GUARD_RADIUS := 9.0

## Where the local player stands, so Dark monsters can fade with distance.
static var viewer_position := Vector3.ZERO

var id := 0
var element := "nature"
var rarity := 0
var egg_id := -1
var state := State.EMERGE
var state_left := EMERGE_SECONDS
var guard_center := Vector3.ZERO
var guard_angle := 0.0
var speed := 0.0
var velocity := Vector3.ZERO
var yaw := 0.0
var ability_timer := 2.0
var dash_left := 0.0
var prev_position := Vector3.ZERO
## Host-only: last frame's target, for catch tests.
var target_peer := 0

var net_position := Vector3.ZERO
var net_velocity := Vector3.ZERO
var _net_age := 0.0

var _body: Node3D
var _body_material: StandardMaterial3D
var _stars: Node3D
var _jaws: MeshInstance3D
var _bob := 0.0


func setup(monster_id: int, element_id: String, rarity_index: int) -> void:
	id = monster_id
	name = "Monster%d" % monster_id
	element = element_id
	rarity = rarity_index
	guard_angle = randf() * TAU
	_bob = randf() * TAU
	_build()


func size() -> float:
	return 1.0 + 0.22 * rarity


func top_speed() -> float:
	return SpeedScale.world_from_kmh(float(GameData.rarity(rarity)["monster_kmh"]))


func is_active() -> bool:
	return state == State.GUARD or state == State.CHASE


## Stops the monster. Earth monsters shrug off half of a bat stun; traps always hold 5 s.
func stun(seconds: float, from_bat: bool) -> void:
	if from_bat and element == "earth":
		seconds *= 0.5
	if state == State.TRAPPED:
		return
	state_left = maxf(state_left, seconds) if state == State.STUNNED else seconds
	state = State.STUNNED
	speed = 0.0


func trap(at: Vector3) -> void:
	state = State.TRAPPED
	state_left = GameData.TRAP_HOLD_SECONDS
	position = Vector3(at.x, 0.0, at.z)
	speed = 0.0


## Host-side brain. `target` is the thief carrying this monster's egg (or null).
func server_step(delta: float, target: Thief, egg_position: Vector3, world: World) -> void:
	prev_position = position
	target_peer = target.peer_id if target else 0
	if not is_active():
		state_left -= delta
		if state_left > 0.0:
			velocity = Vector3.ZERO
			return
		state = State.GUARD
		speed = 0.0
	guard_center = egg_position
	if target == null:
		state = State.GUARD
		_guard(delta)
		return
	state = State.CHASE
	_chase(delta, target, world)


func _guard(delta: float) -> void:
	guard_angle += delta * 0.4
	var spot := guard_center + Vector3(cos(guard_angle), 0, sin(guard_angle)) * GUARD_RADIUS
	var to_spot := spot - position
	to_spot.y = 0.0
	var dist := to_spot.length()
	# Hurry back to the egg when far away, otherwise stroll around it.
	speed = top_speed() * 0.6 if dist > 40.0 else GUARD_SPEED
	var step := minf(speed * delta, dist)
	velocity = to_spot.normalized() * speed if dist > 0.01 else Vector3.ZERO
	position += to_spot.normalized() * step if dist > 0.01 else Vector3.ZERO
	_keep_out_of_base()
	_face(velocity)


func _chase(delta: float, target: Thief, world: World) -> void:
	var target_pos := target.logic_position()
	var top := top_speed() * world.chill_factor(position)
	if dash_left > 0.0:
		dash_left -= delta
		top *= 1.7
	speed = minf(speed + top_speed() / 1.2 * delta, top)
	var lead := target.logic_velocity() * clampf(position.distance_to(target_pos) / maxf(speed, 1.0), 0.0, 0.4)
	var to_target := target_pos + lead - position
	to_target.y = 0.0
	var dist := position.distance_to(target_pos)
	var step := minf(speed * delta, to_target.length())
	velocity = to_target.normalized() * speed if to_target.length() > 0.01 else Vector3.ZERO
	position += to_target.normalized() * step if to_target.length() > 0.01 else Vector3.ZERO
	_keep_out_of_base()
	_face(velocity)
	_use_ability(delta, target, dist, world)


func _use_ability(delta: float, target: Thief, dist: float, world: World) -> void:
	ability_timer -= delta
	if ability_timer > 0.0:
		return
	match element:
		"nature":
			if dist < 30.0:
				world.send_effect(target.peer_id, "slow", 0.55, 2.0)
				ability_timer = 5.0
		"water":
			dash_left = 1.0
			ability_timer = 6.0
		"ice":
			if dist < 20.0:
				world.send_effect(target.peer_id, "slippery", 1.2, 0)
				ability_timer = 0.5
		"fire":
			if dist < 10.0:
				world.send_effect(target.peer_id, "slow", 0.75, 1.0)
				ability_timer = 1.0
		"lightning":
			if dist > 15.0:
				var jump := minf(dist * 0.45, 300.0)
				position += (target.logic_position() - position).normalized() * jump
				position.y = 0.0
				_keep_out_of_base()
				ability_timer = 8.0
		"light":
			if dist < 45.0:
				world.send_effect(target.peer_id, "flash", 0.9, 0)
				ability_timer = 7.0


func _keep_out_of_base() -> void:
	var flat := Vector2(position.x, position.z)
	var limit := GameData.BASE_RADIUS + 2.0
	if flat.length() < limit:
		flat = (flat.normalized() if flat.length() > 0.01 else Vector2(1, 0)) * limit
		position = Vector3(flat.x, 0.0, flat.y)
	position = WorldLayout.clamp_to_world(position)


func _face(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.1:
		yaw = atan2(-dir.x, -dir.z)


# --- Network state for phones that are not the host -----------------------------

func pack() -> Array:
	return [id, element, rarity, position, velocity, yaw, state]


func apply_net_state(pos: Vector3, vel: Vector3, new_yaw: float, new_state: int) -> void:
	net_position = pos
	net_velocity = vel
	yaw = new_yaw
	state = new_state
	_net_age = 0.0


func remote_follow(delta: float) -> void:
	_net_age += delta
	var predicted := net_position + net_velocity * minf(_net_age, 0.2)
	if position.distance_to(predicted) > 100.0:
		position = predicted
	else:
		position = position.lerp(predicted, clampf(delta * 15.0, 0.0, 1.0))


# --- Looks ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if _body == null:
		return
	rotation.y = yaw
	_bob += delta * (12.0 if state == State.CHASE else 3.0)
	var rise := 0.0
	if state == State.EMERGE:
		rise = -2.5 * size() * clampf(state_left / EMERGE_SECONDS, 0.0, 1.0)
	_body.position.y = rise + absf(sin(_bob)) * 0.25 * size()
	_stars.visible = state == State.STUNNED
	_stars.rotate_y(delta * 6.0)
	_jaws.visible = state == State.TRAPPED
	if element == "dark":
		var d := position.distance_to(viewer_position)
		_body_material.albedo_color.a = clampf(1.2 - d / 35.0, 0.15, 1.0)


func _build() -> void:
	var el := GameData.element(element)
	var col: Color = el["color"]
	var s := size()
	_body = Node3D.new()
	add_child(_body)
	_body_material = Meshes.own_material(col.darkened(0.15), 0.25 if element in ["fire", "lightning", "light"] else 0.0)
	Meshes.add(_body, Meshes.sphere(0.8 * s, 1.5 * s, 14), _body_material, Vector3(0, 0.8 * s, 0))
	var white := Meshes.material(Color.WHITE)
	var black := Meshes.material(Color(0.05, 0.05, 0.05))
	var eye_glow := Meshes.material(Color(1.0, 0.2, 0.15), 2.0)
	for side in [-1.0, 1.0]:
		Meshes.add(_body, Meshes.sphere(0.2 * s), white, Vector3(0.28 * s * side, 1.15 * s, -0.62 * s))
		Meshes.add(_body, Meshes.sphere(0.09 * s), eye_glow if rarity >= 4 else black, Vector3(0.28 * s * side, 1.15 * s, -0.8 * s))
	# Teeth.
	for i in 4:
		Meshes.add(_body, Meshes.cone(0.06 * s, 0.18 * s, 4), white, Vector3((-0.24 + 0.16 * i) * s, 0.72 * s, -0.72 * s), Vector3.ONE, Vector3(PI, 0, 0))
	_add_element_parts(s, col)
	_stars = Node3D.new()
	_stars.position = Vector3(0, 2.0 * s, 0)
	_body.add_child(_stars)
	for i in 3:
		var a := TAU * i / 3.0
		Meshes.add(_stars, Meshes.sphere(0.1), Meshes.material(Color(1, 0.9, 0.2), 2.0), Vector3(cos(a) * 0.5 * s, 0, sin(a) * 0.5 * s))
	_stars.visible = false
	_jaws = Meshes.add(self, Meshes.torus(0.7 * s, 1.1 * s), Meshes.material(Color(0.5, 0.5, 0.55), 0.3), Vector3(0, 0.3, 0))
	_jaws.visible = false


func _add_element_parts(s: float, col: Color) -> void:
	match element:
		"nature":
			for i in 5:
				var a := TAU * i / 5.0
				Meshes.add(_body, Meshes.cone(0.18 * s, 0.6 * s, 5), Meshes.material(Color(0.2, 0.65, 0.2)),
					Vector3(cos(a) * 0.35 * s, 1.5 * s, sin(a) * 0.35 * s), Vector3.ONE, Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5))
		"earth":
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				Meshes.add(_body, Meshes.box(Vector3(0.4, 0.35, 0.4) * s), Meshes.material(Color(0.45, 0.35, 0.25)),
					Vector3(cos(a) * 0.55 * s, 1.1 * s, sin(a) * 0.55 * s), Vector3.ONE, Vector3(0.3, a, 0.2))
		"water":
			Meshes.add(_body, Meshes.cone(0.35 * s, 0.9 * s, 4), Meshes.material(Color(0.15, 0.4, 0.85)),
				Vector3(0, 1.6 * s, 0.2 * s), Vector3(0.3, 1, 1))
		"ice":
			for i in 6:
				var a := TAU * i / 6.0
				Meshes.add(_body, Meshes.cone(0.12 * s, 0.8 * s, 5), Meshes.material(Color(0.8, 0.95, 1.0), 0.3),
					Vector3(cos(a) * 0.45 * s, 1.35 * s, sin(a) * 0.45 * s), Vector3.ONE, Vector3(sin(a) * 0.6, 0, -cos(a) * 0.6))
		"fire":
			Meshes.add(_body, Meshes.cone(0.45 * s, 1.1 * s, 7), Meshes.material(Color(1.0, 0.55, 0.1), 2.5), Vector3(0, 1.85 * s, 0))
		"lightning":
			for side in [-1.0, 1.0]:
				Meshes.add(_body, Meshes.box(Vector3(0.12, 0.7, 0.12) * s), Meshes.material(Color(1.0, 0.95, 0.3), 3.0),
					Vector3(0.35 * s * side, 1.75 * s, 0), Vector3.ONE, Vector3(0, 0, 0.5 * side))
		"dark":
			for side in [-1.0, 1.0]:
				Meshes.add(_body, Meshes.cone(0.12 * s, 0.7 * s, 5), Meshes.material(Color(0.3, 0.1, 0.45)),
					Vector3(0.35 * s * side, 1.65 * s, 0), Vector3.ONE, Vector3(0, 0, -0.4 * side))
		"light":
			Meshes.add(_body, Meshes.torus(0.45 * s, 0.55 * s), Meshes.material(Color(1.0, 0.95, 0.6), 3.0), Vector3(0, 1.9 * s, 0))
