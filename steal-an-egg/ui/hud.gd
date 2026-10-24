class_name Hud
extends CanvasLayer
## In-game screen: controls, map, speed, the egg you carry, where to go, and messages.

const TOAST_SECONDS := 3.5

var world: World
var controls: TouchControls
var minimap: Minimap
var _effects: Control
var _biome_label: Label
var _coins_label: Label
var _speed_label: Label
var _status_label: Label
var _objective: Control
var _objective_label: Label
var _center_label: Label
var _toasts: VBoxContainer
var _menu: Control
var _overlay_screen: Control
var _speed_lines_seed := 0


func setup(owner_world: World) -> void:
	world = owner_world
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)

	_effects = Control.new()
	_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.draw.connect(_draw_effects)
	root.add_child(_effects)

	minimap = Minimap.new()
	minimap.position = Vector2(16, 16)
	minimap.setup(world)
	root.add_child(minimap)

	_biome_label = UIKit.label("", 24)
	_biome_label.position = Vector2(16, 222)
	root.add_child(_biome_label)

	var top_right := VBoxContainer.new()
	UIKit.pin(top_right, Vector2(1, 0), Vector2(-430, 12), Vector2(414, 120))
	top_right.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_right)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.add_child(row)
	_coins_label = UIKit.label("", 24, UIKit.ACCENT)
	row.add_child(_coins_label)
	var menu_button := UIKit.button("Menu", _open_menu, 120)
	menu_button.custom_minimum_size = Vector2(120, 56)
	row.add_child(menu_button)
	_speed_label = UIKit.label("", 34)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(_speed_label)

	_objective = Control.new()
	UIKit.pin(_objective, Vector2(0.5, 0), Vector2(-40, 14), Vector2(80, 80))
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective.draw.connect(_draw_objective)
	root.add_child(_objective)
	_objective_label = _centered_label(root, 92, 24)
	_status_label = _centered_label(root, 126, 24)
	_center_label = _centered_label(root, 300, 54)

	_toasts = VBoxContainer.new()
	UIKit.pin(_toasts, Vector2(0.5, 0), Vector2(-400, 170), Vector2(800, 0))
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	controls = TouchControls.new()
	root.add_child(controls)
	controls.setup(world)

	world.message.connect(toast)
	SaveGame.hatched.connect(_on_hatched)


func _centered_label(parent: Control, y: float, font_size: int) -> Label:
	var l := UIKit.label("", font_size)
	UIKit.pin(l, Vector2(0.5, 0), Vector2(-450, y), Vector2(900, 40))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func toast(text: String, color: Color) -> void:
	var l := UIKit.label(text, 26, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toasts.add_child(l)
	while _toasts.get_child_count() > 3:
		_toasts.get_child(0).free()
	var tween := l.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(l, "modulate:a", 0.0, 0.6)
	tween.tween_callback(l.queue_free)


func _on_hatched(pet: Dictionary, coins: int) -> void:
	var rarity: Dictionary = GameData.rarity(pet["rarity"])
	toast("Your %s egg hatched: %s! +%d coins" % [rarity["name"], pet["name"], coins], rarity["color"])


func _process(_delta: float) -> void:
	var t := world.local_thief
	if t == null:
		return
	var ring := WorldLayout.ring_at(t.position)
	if ring == 0:
		_biome_label.text = "Base · safe zone"
	else:
		var b := GameData.biome(ring - 1)
		_biome_label.text = "%s · %s" % [b["name"], GameData.element(b["element"])["name"]]
	_coins_label.text = UIKit.coins_text(SaveGame.data["coins"]) + "  "
	_speed_label.text = SpeedScale.format_kmh(SpeedScale.kmh_from_t(t.speed_t))
	var egg := world.carried_egg(t.peer_id)
	if egg:
		var r := GameData.rarity(egg.rarity)
		_status_label.text = "Carrying a %s egg · monsters run %s" % [r["name"], SpeedScale.format_kmh(r["monster_kmh"])]
		_status_label.add_theme_color_override("font_color", r["color"])
	else:
		_status_label.text = ""
	if t.fall_left > 0.0:
		_center_label.text = "Falling..."
	elif t.trapped_left > 0.0:
		_center_label.text = "TRAPPED  %.1f" % t.trapped_left
	elif t.stun_left > 0.0:
		_center_label.text = "Stunned!"
	else:
		_center_label.text = ""
	_objective.queue_redraw()
	_effects.queue_redraw()


## Where to go next: home with an egg, back to a lost egg, or to the nearest egg.
func _objective_target() -> Dictionary:
	var t := world.local_thief
	if world.carried_egg(t.peer_id):
		return {"pos": WorldLayout.pad_position(Net.player_index(t.peer_id)), "text": "Your base"}
	var lost := world.egg_by_id(world.lost_egg_id)
	if lost and lost.state == Egg.State.DROPPED:
		return {"pos": lost.position, "text": "Your dropped %s egg" % GameData.rarity(lost.rarity)["name"]}
	var best: Egg = null
	for egg in world.eggs:
		if egg.is_takeable() and (best == null or egg.position.distance_to(t.position) < best.position.distance_to(t.position)):
			best = egg
	if best:
		return {"pos": best.position, "text": "Nearest egg: %s" % GameData.rarity(best.rarity)["name"]}
	return {}


func _draw_objective() -> void:
	var t := world.local_thief
	if t == null:
		return
	var target := _objective_target()
	if target.is_empty():
		_objective_label.text = ""
		return
	var to: Vector3 = target["pos"] - t.position
	var dist := Vector2(to.x, to.z).length()
	_objective_label.text = "%s · %s" % [target["text"], _distance_text(dist)]
	var cam_fwd := Vector2(-sin(world.camera.input_yaw()), -cos(world.camera.input_yaw()))
	var angle := cam_fwd.angle_to(Vector2(to.x, to.z))
	var c := _objective.size * 0.5
	var dir := Vector2(0, -1).rotated(angle)
	var side := Vector2(-dir.y, dir.x)
	_objective.draw_circle(c, 36.0, Color(0, 0, 0, 0.4))
	_objective.draw_colored_polygon(PackedVector2Array([c + dir * 30.0, c - dir * 16.0 + side * 18.0, c - dir * 6.0, c - dir * 16.0 - side * 18.0]), UIKit.ACCENT)


func _distance_text(meters: float) -> String:
	return "%d m" % roundi(meters) if meters < 1000.0 else "%.1f km" % (meters / 1000.0)


func _draw_effects() -> void:
	var t := world.local_thief
	if t == null:
		return
	var s := _effects.size
	# Speed lines rushing past at high speed.
	var strength := clampf((t.speed_t - 0.3) / 0.7, 0.0, 1.0) * (1.0 if t.moving else 0.0)
	if strength > 0.0:
		_speed_lines_seed += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = _speed_lines_seed
		var c := s * 0.5
		for i in int(10 + 50 * strength):
			var a := rng.randf() * TAU
			var dir := Vector2(cos(a), sin(a))
			var r0 := rng.randf_range(0.35, 0.6) * s.length() * 0.5
			var r1 := r0 + rng.randf_range(60.0, 220.0) * strength
			_effects.draw_line(c + dir * r0, c + dir * r1, Color(1, 1, 1, 0.45 * strength), 3.0)
	if t.slow_left > 0.0:
		_effects.draw_rect(Rect2(Vector2.ZERO, s), Color(0.2, 0.7, 0.2, 0.12))
	if t.slippery_left > 0.0:
		_effects.draw_rect(Rect2(Vector2.ZERO, s), Color(0.6, 0.9, 1.0, 0.15))
	if t.flash_left > 0.0:
		_effects.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 0.95, clampf(t.flash_left / 0.9, 0.0, 1.0) * 0.95))


# --- Pause menu --------------------------------------------------------------------

func _open_menu() -> void:
	if _menu:
		return
	controls.visible = false
	if not Net.is_online():
		world.process_mode = Node.PROCESS_MODE_DISABLED
	_menu = PanelContainer.new()
	_menu.theme = UIKit.theme()
	add_child(_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_menu.add_child(box)
	box.add_child(UIKit.label("Paused" if not Net.is_online() else "Menu", 40, UIKit.ACCENT))
	box.add_child(UIKit.button("Resume", _close_menu))
	box.add_child(UIKit.button("Hatchery", _open_screen.bind(HatcheryScreen)))
	box.add_child(UIKit.button("Pets", _open_screen.bind(PetsScreen)))
	box.add_child(UIKit.button("Shop", _open_screen.bind(ShopScreen)))
	box.add_child(UIKit.button("Leave game", func() -> void: Net.leave()))
	_menu.reset_size()
	_menu.position = (get_viewport().get_visible_rect().size - _menu.size) * 0.5


func _close_menu() -> void:
	if _menu:
		_menu.queue_free()
		_menu = null
	controls.visible = true
	world.process_mode = Node.PROCESS_MODE_INHERIT


func _open_screen(screen_class: GDScript) -> void:
	_menu.visible = false
	_overlay_screen = screen_class.new()
	_overlay_screen.embedded = true
	_overlay_screen.closed.connect(func() -> void:
		_overlay_screen = null
		_menu.visible = true)
	add_child(_overlay_screen)
