class_name UIKit
extends RefCounted
## Shared look for menus and the HUD.

const BG_TOP := Color(0.17, 0.11, 0.33)
const BG_BOTTOM := Color(0.06, 0.04, 0.12)
const PANEL := Color(0.12, 0.09, 0.22, 0.92)
const ACCENT := Color(1.0, 0.78, 0.25)
const TEXT := Color(0.96, 0.95, 1.0)
const MUTED := Color(0.72, 0.7, 0.85)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 26
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	_theme.set_constant("outline_size", "Label", 4)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		match state:
			"normal":
				sb.bg_color = Color(0.32, 0.22, 0.6)
			"hover":
				sb.bg_color = Color(0.4, 0.29, 0.72)
			"pressed":
				sb.bg_color = Color(0.24, 0.16, 0.45)
			"disabled":
				sb.bg_color = Color(0.22, 0.2, 0.28)
			"focus":
				sb.bg_color = Color(0, 0, 0, 0)
				sb.border_color = ACCENT
				sb.set_border_width_all(2)
		_theme.set_stylebox(state, "Button", sb)
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_color("font_disabled_color", "Button", Color(0.6, 0.6, 0.65))
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.set_corner_radius_all(20)
	panel.set_content_margin_all(20)
	_theme.set_stylebox("panel", "PanelContainer", panel)
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0.08, 0.06, 0.16)
	line.set_corner_radius_all(12)
	line.set_content_margin_all(12)
	_theme.set_stylebox("normal", "LineEdit", line)
	_theme.set_stylebox("focus", "LineEdit", line)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.06, 0.16)
	bar_bg.set_corner_radius_all(8)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ACCENT
	bar_fill.set_corner_radius_all(8)
	_theme.set_stylebox("background", "ProgressBar", bar_bg)
	_theme.set_stylebox("fill", "ProgressBar", bar_fill)
	return _theme


## Pins a control to a point of its parent (0..1 on each axis) at a fixed offset and size.
static func pin(c: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


static func label(text: String, size: int = 26, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, on_pressed: Callable, min_width: float = 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 72)
	b.pressed.connect(on_pressed)
	return b


## Fills a screen with the menu background gradient.
static func background(parent: Control) -> void:
	var grad := Gradient.new()
	grad.set_color(0, BG_TOP)
	grad.set_color(1, BG_BOTTOM)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)


## A coloured egg drawn in 2D.
static func draw_egg(canvas: CanvasItem, center: Vector2, height: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var y := -cos(a)
		var w := sin(a) * (0.33 if y < 0.0 else 0.39)
		points.append(center + Vector2(w, y * (0.56 if y < 0.0 else 0.44)) * height)
	canvas.draw_colored_polygon(points, color)
	canvas.draw_polyline(points + PackedVector2Array([points[0]]), color.darkened(0.45), maxf(height * 0.04, 2.0), true)
	canvas.draw_circle(center + Vector2(-0.2, -0.22) * height, height * 0.09, Color(1, 1, 1, 0.5))


## A pet's face and body drawn in 2D, `height` tall, centred on `center`.
static func draw_pet(canvas: CanvasItem, center: Vector2, height: float, color: Color, rarity_index: int = 0) -> void:
	# Tiny shapes (the first frames of a pop-in) can't be drawn as polygons.
	if height < 8.0:
		return
	var h := height
	var dark := color.darkened(0.3)
	# Ears first so the head covers their base.
	for side in [-1.0, 1.0]:
		canvas.draw_colored_polygon(PackedVector2Array([
			center + Vector2(side * h * 0.12, -h * 0.28), center + Vector2(side * h * 0.36, -h * 0.5),
			center + Vector2(side * h * 0.33, -h * 0.16)]), dark)
	canvas.draw_circle(center + Vector2(0, h * 0.2), h * 0.3, color)
	canvas.draw_circle(center + Vector2(0, h * 0.24), h * 0.19, color.lightened(0.45))
	canvas.draw_circle(center + Vector2(0, -h * 0.1), h * 0.28, color)
	for side in [-1.0, 1.0]:
		var eye := center + Vector2(side * h * 0.11, -h * 0.12)
		canvas.draw_circle(eye, h * 0.075, Color.WHITE)
		canvas.draw_circle(eye + Vector2(0, h * 0.01), h * 0.045, Color(0.05, 0.05, 0.08))
		canvas.draw_circle(eye + Vector2(-h * 0.015, -h * 0.015), h * 0.015, Color.WHITE)
		canvas.draw_circle(center + Vector2(side * h * 0.2, -h * 0.02), h * 0.035, Color(1.0, 0.55, 0.6, 0.8))
		canvas.draw_circle(center + Vector2(side * h * 0.14, h * 0.48), h * 0.07, dark)
	canvas.draw_arc(center + Vector2(0, -h * 0.03), h * 0.05, 0.3, PI - 0.3, 10, Color(0.1, 0.05, 0.05), maxf(h * 0.012, 1.5), true)
	if rarity_index >= 5:
		for i in 4:
			var a := TAU * i / 4.0 + float(Time.get_ticks_msec()) / 700.0
			canvas.draw_circle(center + Vector2(cos(a) * h * 0.5, sin(a) * h * 0.35), h * 0.025, Color(1, 1, 0.8))


static func coins_text(coins: int) -> String:
	return "%s coins" % SpeedScale._group_thousands(coins)
