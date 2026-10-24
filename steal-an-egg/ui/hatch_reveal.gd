class_name HatchReveal
extends Control
## Full-screen hatching moment: the egg wobbles, cracks, and the pet pops out with its
## name, rarity and perk. Shows each waiting hatchling in turn, then closes itself.

signal finished

const WOBBLE := 1.3
const CRACK := 0.45
const POP := 0.6

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _time := 0.0
var _info: VBoxContainer
var _title: Label
var _subtitle: Label
var _perk: Label
var _equip: Button
var _next: Button


## Opens a reveal for every hatchling waiting to be shown. Returns null if there are none.
static func show_pending(parent: Node) -> HatchReveal:
	var reveals := SaveGame.take_reveals()
	if reveals.is_empty():
		return null
	var reveal := HatchReveal.new()
	reveal._queue = reveals
	parent.add_child(reveal)
	return reveal


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_info = VBoxContainer.new()
	_info.alignment = BoxContainer.ALIGNMENT_CENTER
	_info.add_theme_constant_override("separation", 10)
	UIKit.pin(_info, Vector2(0.5, 1.0), Vector2(-450, -290), Vector2(900, 270))
	add_child(_info)
	_title = _centered(46, UIKit.ACCENT)
	_subtitle = _centered(26, Color.WHITE)
	_perk = _centered(22, UIKit.MUTED)
	_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	_info.add_child(buttons)
	_equip = UIKit.button("Equip", _on_equip, 220)
	buttons.add_child(_equip)
	_next = UIKit.button("Nice!", _advance, 220)
	buttons.add_child(_next)
	SaveGame.hatched.connect(_on_more_hatched)
	_start_next()


func _centered(font_size: int, color: Color) -> Label:
	var l := UIKit.label("", font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_child(l)
	return l


func _on_more_hatched(_pet: Dictionary, _coins: int, _slot: int) -> void:
	_queue.append_array(SaveGame.take_reveals())


func _start_next() -> void:
	if _queue.is_empty():
		finished.emit()
		queue_free()
		return
	_current = _queue.pop_front()
	_time = 0.0
	_info.visible = false
	var pet: Dictionary = _current["pet"]
	var rarity := GameData.rarity(pet["rarity"])
	var element := GameData.element(pet["element"])
	_title.text = "%s hatched!" % pet["name"]
	_title.add_theme_color_override("font_color", rarity["color"])
	var extra := "  ·  NEW in your Pet Index!" if _current.get("new_entry", false) else ""
	_subtitle.text = "%s %s pet  ·  +%s%s" % [rarity["name"], element["name"], UIKit.coins_text(_current["coins"]), extra]
	_perk.text = Loot.perk_description(pet)
	_next.text = "Next" if not _queue.is_empty() else "Nice!"


func _process(delta: float) -> void:
	_time += delta
	if not _current.is_empty():
		_info.visible = _time >= WOBBLE + CRACK
		_equip.visible = SaveGame.data["equipped_pet"] != _current["pet"]["id"]
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Tapping skips straight to the pet.
	if event is InputEventMouseButton and event.pressed and _time < WOBBLE + CRACK:
		_time = WOBBLE + CRACK
		accept_event()


func _on_equip() -> void:
	SaveGame.equip(_current["pet"]["id"])
	_equip.visible = false


func _advance() -> void:
	_start_next()


func _exit_tree() -> void:
	if SaveGame.hatched.is_connected(_on_more_hatched):
		SaveGame.hatched.disconnect(_on_more_hatched)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.08, 0.86))
	if _current.is_empty():
		return
	var pet: Dictionary = _current["pet"]
	var egg_color: Color = GameData.rarity(pet["rarity"])["color"]
	var pet_color: Color = GameData.element(pet["element"])["color"]
	var center := Vector2(size.x * 0.5, size.y * 0.36)
	var h := minf(size.y * 0.42, 300.0)
	if _time < WOBBLE:
		var k := _time / WOBBLE
		draw_set_transform(center + Vector2(0, h * 0.5), sin(_time * 22.0) * 0.25 * k, Vector2.ONE)
		UIKit.draw_egg(self, Vector2(0, -h * 0.5), h, egg_color)
		draw_set_transform(Vector2.ZERO)
		return
	if _time < WOBBLE + CRACK:
		var k := (_time - WOBBLE) / CRACK
		UIKit.draw_egg(self, center, h, egg_color)
		var crack := PackedVector2Array()
		for i in 9:
			var x := -0.32 + 0.08 * i
			crack.append(center + Vector2(x * h, (0.04 if i % 2 == 0 else -0.04) * h))
		draw_polyline(crack, Color(0.15, 0.1, 0.05), 5.0 + 4.0 * k, true)
		draw_circle(center, h * 0.6 * k, Color(1, 1, 1, 0.5 * k))
		return
	var t := _time - WOBBLE - CRACK
	# Shell halves fly apart while the pet bounces up out of them.
	var fly := minf(t / POP, 1.0)
	var shell_alpha := clampf(1.0 - t / (POP * 1.5), 0.0, 1.0)
	_draw_shell(center + Vector2(-h * 0.5 * fly, -h * 0.6 * fly), h, egg_color, -fly * 0.8, true, shell_alpha)
	_draw_shell(center + Vector2(h * 0.5 * fly, h * 0.25 * fly), h, egg_color, fly * 0.6, false, shell_alpha)
	for i in 14:
		var a := TAU * i / 14.0 + t
		var r := h * (0.35 + 0.5 * fly)
		draw_circle(center + Vector2(cos(a), sin(a)) * r, 6.0 * (1.0 - fly * 0.5), Color(egg_color, 1.0 - fly * 0.6))
	var bounce := 1.0 + 0.18 * sin(minf(t / POP, 1.0) * PI) + 0.03 * sin(_time * 4.0)
	UIKit.draw_pet(self, center + Vector2(0, -h * 0.05), h * 0.9 * minf(t / (POP * 0.6), 1.0) * bounce, pet_color, int(pet["rarity"]))


func _draw_shell(at: Vector2, h: float, color: Color, angle: float, top: bool, alpha: float) -> void:
	draw_set_transform(at, angle, Vector2.ONE)
	var points := PackedVector2Array()
	for i in 21:
		var a := PI * i / 20.0
		var y := -sin(a) * (0.56 if top else -0.44)
		points.append(Vector2(cos(a) * (0.33 if top else 0.39), y) * h)
	# Jagged broken edge along the rim, teeth pointing away from the shell.
	var half_width := (0.33 if top else 0.39) * h
	var tooth := (0.06 if top else -0.06) * h
	for i in range(1, 8):
		points.append(Vector2(lerpf(-half_width, half_width, i / 8.0), tooth if i % 2 == 1 else 0.0))
	draw_colored_polygon(points, Color(color, alpha))
	draw_set_transform(Vector2.ZERO)
