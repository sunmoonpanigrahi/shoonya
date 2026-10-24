class_name Thief
extends Node3D
## A player's thief. The phone that owns it moves it; everyone else shows it at the
## position it reports. The host decides hits, traps and catches and sends effects.

const TURN_SLOW := 2.2
const TURN_FAST := 10.0

var peer_id := 1
var is_local := false
var color := Color.WHITE
var display_name := "Thief"

## 0..1 position of the speed control (see SpeedScale).
var speed_t := 0.1
var yaw := 0.0
var velocity := Vector3.ZERO
var move_input := Vector2.ZERO
var moving := false
var carrying_egg := -1
## Goes up each time the host moves this thief (a fall or a bat hit), so position
## reports sent before the move can be told apart and ignored.
var epoch := 0
var pet_element := ""
var pet_rarity := 0

# Effects sent by the host.
var trapped_left := 0.0
var trapped_at := Vector3.ZERO
var stun_left := 0.0
var fall_left := 0.0
var slow_left := 0.0
var slow_mult := 1.0
var slippery_left := 0.0
var flash_left := 0.0

## Last position reported over the network, and its velocity, for remote thieves.
var net_position := Vector3.ZERO
var net_velocity := Vector3.ZERO
var _net_age := 0.0
## Where this thief was at the start of the host's last frame (for path hit tests).
var prev_logic_position := Vector3.ZERO

var _body: Node3D
var _scarf_material: StandardMaterial3D
var _legs: Array[MeshInstance3D] = []
var _bat_pivot: Node3D
var _swing_left := 0.0
var _step_phase := 0.0
var _trap_ring: MeshInstance3D
var _stars: Node3D
var _label: Label3D


func _init() -> void:
	_build()


func setup(id: int, info: Dictionary, local: bool) -> void:
	peer_id = id
	name = "Thief%d" % id
	is_local = local
	display_name = str(info.get("name", "Thief"))
	color = GameData.PLAYER_COLORS[int(info.get("index", 0)) % GameData.PLAYER_COLORS.size()]
	pet_element = str(info.get("pet_element", ""))
	pet_rarity = int(info.get("pet_rarity", 0))
	_scarf_material.albedo_color = color
	_label.text = display_name
	_label.visible = not local
	_label.modulate = color


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func world_speed() -> float:
	return SpeedScale.world_from_t(speed_t)


func can_act() -> bool:
	return trapped_left <= 0.0 and stun_left <= 0.0 and fall_left <= 0.0


## Position used for game rules: where the owner last said it was.
func logic_position() -> Vector3:
	return position if is_local else net_position


func logic_velocity() -> Vector3:
	return velocity if is_local else net_velocity


## Moves the local thief. `camera_yaw` makes the joystick camera-relative.
func local_move(delta: float, camera_yaw: float) -> void:
	if fall_left > 0.0:
		velocity = Vector3.ZERO
		return
	if trapped_left > 0.0:
		position = Vector3(trapped_at.x, 0.0, trapped_at.z)
		velocity = Vector3.ZERO
		return
	var strength := clampf(move_input.length() * 1.25, 0.0, 1.0)
	moving = strength > 0.05 and stun_left <= 0.0
	var target_velocity := Vector3.ZERO
	if moving:
		var desired := Vector3(move_input.x, 0.0, move_input.y).rotated(Vector3.UP, camera_yaw)
		var desired_yaw := atan2(-desired.x, -desired.z)
		var turn := lerpf(TURN_FAST, TURN_SLOW, speed_t) * (0.35 if slippery_left > 0.0 else 1.0)
		yaw = rotate_toward(yaw, desired_yaw, turn * delta)
		var mult := slow_mult if slow_left > 0.0 else 1.0
		target_velocity = forward() * world_speed() * strength * mult
	if slippery_left > 0.0:
		velocity = velocity.lerp(target_velocity, clampf(delta * 1.5, 0.0, 1.0))
	else:
		velocity = target_velocity
	position = WorldLayout.clamp_to_world(position + velocity * delta)
	position.y = 0.0


## Remote thieves glide to the last reported position, predicting ahead by their velocity.
func remote_follow(delta: float) -> void:
	_net_age += delta
	var predicted := net_position + net_velocity * minf(_net_age, 0.2)
	if position.distance_to(predicted) > 80.0:
		position = predicted
	else:
		position = position.lerp(predicted, clampf(delta * 15.0, 0.0, 1.0))


func apply_net_state(pos: Vector3, vel: Vector3, new_yaw: float, t: float, is_moving: bool) -> void:
	net_position = pos
	net_velocity = vel
	yaw = new_yaw
	speed_t = t
	moving = is_moving
	_net_age = 0.0


## An effect decided by the host. Only the owner moves the thief; everyone shows it.
func apply_effect(kind: String, a: Variant, b: Variant, new_epoch: int = -1) -> void:
	if new_epoch >= 0:
		epoch = maxi(epoch, new_epoch)
	match kind:
		"trap":
			trapped_left = float(a)
			trapped_at = b
		"release":
			trapped_left = 0.0
		"stun":
			stun_left = maxf(stun_left, float(a))
		"knock":
			stun_left = maxf(stun_left, GameData.THIEF_STUN_FROM_BAT)
			_teleport(logic_position() + Vector3(b))
		"fall":
			fall_left = GameData.FALL_SECONDS
			trapped_left = 0.0
			stun_left = 0.0
			velocity = Vector3.ZERO
			_teleport(Vector3(a))
		"slow":
			var mult := float(a)
			if pet_element == "nature":
				mult = 1.0 - (1.0 - mult) * (1.0 - GameData.perk_strength(pet_rarity))
			slow_mult = minf(mult, slow_mult) if slow_left > 0.0 else mult
			slow_left = maxf(slow_left, float(b))
		"slippery":
			slippery_left = maxf(slippery_left, float(a))
		"flash":
			if pet_element != "light":
				flash_left = maxf(flash_left, float(a))


func _teleport(to: Vector3) -> void:
	to = WorldLayout.clamp_to_world(Vector3(to.x, 0.0, to.z))
	position = to
	net_position = to
	net_velocity = Vector3.ZERO
	prev_logic_position = to


func swing_bat() -> void:
	_swing_left = 0.3


func _process(delta: float) -> void:
	trapped_left = maxf(trapped_left - delta, 0.0)
	stun_left = maxf(stun_left - delta, 0.0)
	fall_left = maxf(fall_left - delta, 0.0)
	slow_left = maxf(slow_left - delta, 0.0)
	slippery_left = maxf(slippery_left - delta, 0.0)
	flash_left = maxf(flash_left - delta, 0.0)
	rotation.y = yaw
	_animate(delta)


func _animate(delta: float) -> void:
	# Falling from the sky into the previous biome.
	var fall_height := 0.0
	if fall_left > 0.0:
		var k := fall_left / GameData.FALL_SECONDS
		fall_height = 60.0 * k * k
	_body.position.y = fall_height
	var run := moving and can_act()
	if run:
		_step_phase += delta * lerpf(9.0, 22.0, speed_t)
	var swing := sin(_step_phase) * (0.7 if run else 0.0)
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_body.rotation.x = -0.25 * speed_t if run else 0.0
	if _swing_left > 0.0:
		_swing_left = maxf(_swing_left - delta, 0.0)
		var k := 1.0 - _swing_left / 0.3
		_bat_pivot.rotation = Vector3(-0.3, lerpf(1.2, -1.8, k), 0.0)
	else:
		_bat_pivot.rotation = Vector3(0.6, 0.4, 0.0)
	_trap_ring.visible = trapped_left > 0.0
	_stars.visible = stun_left > 0.0 and trapped_left <= 0.0
	_stars.rotate_y(delta * 6.0)


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var cloth := Meshes.material(Color(0.12, 0.12, 0.16))
	var skin := Meshes.material(Color(0.95, 0.76, 0.6))
	Meshes.add(_body, Meshes.capsule(0.32, 1.1), cloth, Vector3(0, 1.05, 0))
	Meshes.add(_body, Meshes.sphere(0.27), skin, Vector3(0, 1.82, 0))
	# The bandit mask across the eyes.
	Meshes.add(_body, Meshes.box(Vector3(0.56, 0.11, 0.2)), Meshes.material(Color.BLACK), Vector3(0, 1.86, -0.17))
	_scarf_material = Meshes.own_material(Color.RED)
	_scarf_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	Meshes.add(_body, Meshes.torus(0.2, 0.33), _scarf_material, Vector3(0, 1.55, 0))
	# Loot sack on the back where a carried egg sits.
	Meshes.add(_body, Meshes.sphere(0.22), Meshes.material(Color(0.55, 0.4, 0.25)), Vector3(0, 1.15, 0.33))
	for side in [-1.0, 1.0]:
		var leg_pivot := MeshInstance3D.new()
		leg_pivot.position = Vector3(0.15 * side, 0.6, 0)
		_body.add_child(leg_pivot)
		Meshes.add(leg_pivot, Meshes.capsule(0.1, 0.6), cloth, Vector3(0, -0.3, 0))
		_legs.append(leg_pivot)
	_bat_pivot = Node3D.new()
	_bat_pivot.position = Vector3(0.38, 1.15, -0.05)
	_body.add_child(_bat_pivot)
	var wood := Meshes.material(Color(0.78, 0.55, 0.3))
	Meshes.add(_bat_pivot, Meshes.cylinder(0.07, 0.035, 0.95), wood, Vector3(0, 0.45, 0))
	_trap_ring = Meshes.add(self, Meshes.torus(0.55, 0.85), Meshes.material(Color(0.9, 0.15, 0.1), 1.2), Vector3(0, 0.15, 0))
	_trap_ring.visible = false
	_stars = Node3D.new()
	_stars.position = Vector3(0, 2.3, 0)
	_body.add_child(_stars)
	for i in 3:
		var a := TAU * i / 3.0
		Meshes.add(_stars, Meshes.sphere(0.07), Meshes.material(Color(1, 0.9, 0.2), 2.0), Vector3(cos(a) * 0.35, 0, sin(a) * 0.35))
	_stars.visible = false
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.7, 0)
	_label.font_size = 48
	_label.outline_size = 8
	_label.no_depth_test = true
	add_child(_label)


## Where a carried egg sits.
func egg_anchor() -> Vector3:
	return position + Vector3(0, _body.position.y + 1.35, 0) + forward() * -0.45
