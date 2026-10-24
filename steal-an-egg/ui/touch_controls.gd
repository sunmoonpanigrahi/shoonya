class_name TouchControls
extends Control
## On-screen controls. Handles several fingers at once: joystick bottom-left, speed
## control on the right, bat and three traps along the bottom, and drag elsewhere to
## turn the camera. Keyboard works too for desktop testing (WASD, Q/E, Space, T).

const JOY_RADIUS := 110.0
const SPEED_HOLD_RATE := 0.22
const SPEED_TAP_STEP := 0.01
const TAP_SLOP := 28.0

var world: World
## finger index -> what it is doing: {"kind", "start", "pos", "slot"}
var _touches: Dictionary = {}
var _joy_center := Vector2.ZERO
var _joy_vector := Vector2.ZERO
var _speed_dir := 0.0
var _bat_ready_at := 0.0
var _bat_cooldown := 1.0
## What the controls last told the thief, so input set elsewhere (tests) is left alone.
var _last_move := Vector2.ZERO


func setup(owner_world: World) -> void:
	world = owner_world
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := SaveGame.player_info()
	_bat_cooldown = GameData.bat_cooldown(info["bat_level"], info["pet_element"], info["pet_rarity"])


# --- Layout ------------------------------------------------------------------------

func _bat_center() -> Vector2:
	return Vector2(size.x * 0.5 - 210.0, size.y - 86.0)


func _trap_center(slot: int) -> Vector2:
	return Vector2(size.x * 0.5 - 70.0 + slot * 118.0, size.y - 80.0)


func _track_top() -> Vector2:
	return Vector2(size.x - 78.0, 205.0)


func _track_bottom() -> Vector2:
	return Vector2(size.x - 78.0, size.y - 215.0)


func _plus_center() -> Vector2:
	return _track_top() - Vector2(0, 52)


func _minus_center() -> Vector2:
	return _track_bottom() + Vector2(0, 52)


func _joy_home() -> Vector2:
	return Vector2(190.0, size.y - 190.0)


# --- Input ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or world == null or world.local_thief == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position, event.relative)


func _touch_down(index: int, pos: Vector2) -> void:
	var touch := {"start": pos, "pos": pos, "kind": "", "slot": -1}
	if pos.distance_to(_bat_center()) < 72.0:
		touch["kind"] = "bat"
		_swing()
	elif _trap_slot_at(pos) >= 0:
		touch["kind"] = "trap"
		touch["slot"] = _trap_slot_at(pos)
	elif pos.distance_to(_plus_center()) < 46.0:
		touch["kind"] = "plus"
		_nudge_speed(SPEED_TAP_STEP)
	elif pos.distance_to(_minus_center()) < 46.0:
		touch["kind"] = "minus"
		_nudge_speed(-SPEED_TAP_STEP)
	elif absf(pos.x - _track_top().x) < 60.0 and pos.y > _track_top().y - 20.0 and pos.y < _track_bottom().y + 20.0:
		touch["kind"] = "track"
		_set_speed_from_track(pos.y)
	elif pos.x < size.x * 0.42 and pos.y > size.y * 0.35:
		touch["kind"] = "joy"
		_joy_center = pos
		_joy_vector = Vector2.ZERO
	elif pos.y > 230.0 or pos.x > 240.0:
		touch["kind"] = "camera"
	_touches[index] = touch


func _touch_move(index: int, pos: Vector2, relative: Vector2) -> void:
	if not _touches.has(index):
		return
	var touch: Dictionary = _touches[index]
	touch["pos"] = pos
	match touch["kind"]:
		"joy":
			var offset := pos - _joy_center
			if offset.length() > JOY_RADIUS:
				# Let the joystick follow a finger that slides past its edge.
				_joy_center = pos - offset.normalized() * JOY_RADIUS
				offset = pos - _joy_center
			_joy_vector = offset / JOY_RADIUS
		"track":
			_set_speed_from_track(pos.y)
		"camera":
			world.camera.drag(relative.x)


func _touch_up(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var touch: Dictionary = _touches[index]
	_touches.erase(index)
	match touch["kind"]:
		"joy":
			_joy_vector = Vector2.ZERO
		"trap":
			if world.traps_left() <= 0:
				return
			if pos.distance_to(touch["start"]) < TAP_SLOP:
				var t := world.local_thief
				world.request_trap(t.position - t.forward() * 2.5)
			else:
				var ground: Variant = _ground_point(pos)
				if ground != null:
					world.request_trap(ground)


func _process(delta: float) -> void:
	if world == null or world.local_thief == null:
		return
	var thief := world.local_thief
	_speed_dir = 0.0
	for touch in _touches.values():
		if touch["kind"] == "plus":
			_speed_dir += 1.0
		elif touch["kind"] == "minus":
			_speed_dir -= 1.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_EQUAL):
		_speed_dir += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_MINUS):
		_speed_dir -= 1.0
	thief.speed_t = clampf(thief.speed_t + _speed_dir * SPEED_HOLD_RATE * delta, 0.0, 1.0)
	var keys := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	var joy := _joy_vector if _joy_vector.length() > 0.0 else keys.limit_length(1.0)
	if not visible:
		joy = Vector2.ZERO
	if joy != _last_move:
		thief.move_input = joy
		_last_move = joy
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or world == null or world.local_thief == null:
		return
	if event.keycode == KEY_SPACE:
		_swing()
	elif event.keycode == KEY_T and world.traps_left() > 0:
		var t := world.local_thief
		world.request_trap(t.position - t.forward() * 2.5)


func _swing() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _bat_ready_at or not world.local_thief.can_act():
		return
	_bat_ready_at = now + _bat_cooldown
	world.request_bat()


func _nudge_speed(step: float) -> void:
	world.local_thief.speed_t = clampf(world.local_thief.speed_t + step, 0.0, 1.0)


func _set_speed_from_track(y: float) -> void:
	var t := inverse_lerp(_track_bottom().y, _track_top().y, y)
	world.local_thief.speed_t = clampf(t, 0.0, 1.0)


func _trap_slot_at(pos: Vector2) -> int:
	for i in GameData.TRAPS_PER_TRIP:
		if pos.distance_to(_trap_center(i)) < 56.0:
			return i
	return -1


## Where a screen point lands on the ground, or null when it points at the sky.
func _ground_point(screen_pos: Vector2) -> Variant:
	var cam := world.camera
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if dir.y > -0.01:
		return null
	return from + dir * (-from.y / dir.y)


# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	if world == null or world.local_thief == null:
		return
	var font := get_theme_default_font()
	var thief := world.local_thief
	# Joystick.
	var joy_center := _joy_home()
	for touch in _touches.values():
		if touch["kind"] == "joy":
			joy_center = _joy_center
	draw_circle(joy_center, JOY_RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(joy_center, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(joy_center + _joy_vector * JOY_RADIUS, 46.0, Color(1, 1, 1, 0.45))
	# Speed control.
	var top := _track_top()
	var bottom := _track_bottom()
	draw_line(bottom, top, Color(0, 0, 0, 0.35), 30.0)
	var knob := bottom.lerp(top, thief.speed_t)
	draw_line(bottom, knob, Color(1.0, 0.45 + 0.4 * (1.0 - thief.speed_t), 0.15), 22.0)
	draw_circle(knob, 26.0, Color.WHITE)
	_round_button(_plus_center(), 34.0, "+", font)
	_round_button(_minus_center(), 34.0, "-", font)
	draw_string(font, top + Vector2(-150, -2), "1 trillion", HORIZONTAL_ALIGNMENT_RIGHT, 110, 18, Color(1, 1, 1, 0.7))
	draw_string(font, bottom + Vector2(-150, 6), "10 km/h", HORIZONTAL_ALIGNMENT_RIGHT, 110, 18, Color(1, 1, 1, 0.7))
	# Bat.
	var bat := _bat_center()
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown := clampf((_bat_ready_at - now) / _bat_cooldown, 0.0, 1.0)
	draw_circle(bat, 64.0, Color(0.15, 0.1, 0.25, 0.75))
	draw_arc(bat, 64.0, 0, TAU, 48, UIKit.ACCENT if cooldown <= 0.0 else Color(1, 1, 1, 0.3), 4.0, true)
	if cooldown > 0.0:
		draw_arc(bat, 56.0, -PI * 0.5, -PI * 0.5 + TAU * cooldown, 40, Color(1, 1, 1, 0.5), 10.0, true)
	draw_line(bat + Vector2(-26, 30), bat + Vector2(22, -30), Color(0.85, 0.6, 0.35), 16.0, true)
	draw_line(bat + Vector2(-30, 34), bat + Vector2(-18, 20), Color(0.35, 0.22, 0.12), 9.0, true)
	draw_string(font, bat + Vector2(-60, 92), "BAT", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, Color.WHITE)
	# Traps.
	var left := world.traps_left()
	for i in GameData.TRAPS_PER_TRIP:
		var c := _trap_center(i)
		var ready := i < left
		draw_circle(c, 50.0, Color(0.15, 0.1, 0.25, 0.75 if ready else 0.35))
		draw_arc(c, 50.0, 0, TAU, 40, Color(1, 1, 1, 0.5 if ready else 0.15), 3.0, true)
		_draw_trap_icon(c, 26.0, Color(0.85, 0.87, 0.9, 1.0 if ready else 0.25))
	draw_string(font, _trap_center(1) + Vector2(-90, 84), "TRAPS  %d/%d" % [left, GameData.TRAPS_PER_TRIP], HORIZONTAL_ALIGNMENT_CENTER, 180, 20, Color.WHITE)
	# A trap being dragged into place.
	for touch in _touches.values():
		if touch["kind"] == "trap" and left > 0 and touch["pos"].distance_to(touch["start"]) >= TAP_SLOP:
			_draw_trap_icon(touch["pos"], 34.0, Color(1.0, 0.85, 0.3))
			draw_arc(touch["pos"], 46.0, 0, TAU, 40, Color(1.0, 0.85, 0.3, 0.8), 3.0, true)


func _round_button(center: Vector2, radius: float, text: String, font: Font) -> void:
	draw_circle(center, radius, Color(0.15, 0.1, 0.25, 0.75))
	draw_arc(center, radius, 0, TAU, 32, Color(1, 1, 1, 0.5), 3.0, true)
	draw_string(font, center + Vector2(-radius, 13), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 40, Color.WHITE)


func _draw_trap_icon(c: Vector2, r: float, color: Color) -> void:
	draw_arc(c, r, 0, TAU, 32, color, 5.0, true)
	for k in 8:
		var a := TAU * k / 8.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * r, c + dir * (r * 0.45), color, 4.0, true)
