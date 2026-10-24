class_name EggIcon
extends Control
## A drawn egg (or a pet face) in a rarity or element colour.

var color := Color.WHITE
var is_pet := false
var empty := false


static func make(icon_color: Color, pet: bool = false, icon_size: float = 72.0) -> EggIcon:
	var icon := EggIcon.new()
	icon.color = icon_color
	icon.is_pet = pet
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var c := size * 0.5
	var h := minf(size.x, size.y) * 0.9
	if empty:
		draw_arc(c, h * 0.4, 0, TAU, 32, Color(1, 1, 1, 0.3), 3.0, true)
		return
	if not is_pet:
		UIKit.draw_egg(self, c, h, color)
		return
	draw_circle(c + Vector2(0, h * 0.08), h * 0.38, color)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(side * h * 0.12, -h * 0.2), c + Vector2(side * h * 0.34, -h * 0.45), c + Vector2(side * h * 0.34, -h * 0.12)]), color.darkened(0.2))
		draw_circle(c + Vector2(side * h * 0.13, 0.02 * h), h * 0.06, Color(0.05, 0.05, 0.05))
