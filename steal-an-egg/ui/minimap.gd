class_name Minimap
extends Control
## North-up map around the local thief. Zooms out as the thief speeds up.

var world: World
var _view_radius := 150.0


func setup(owner_world: World) -> void:
	world = owner_world
	custom_minimum_size = Vector2(200, 200)
	size = Vector2(200, 200)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if world and world.local_thief:
		var want := clampf(world.local_thief.world_speed() * 14.0, 150.0, GameData.WORLD_RADIUS * 1.1)
		_view_radius = lerpf(_view_radius, want, clampf(delta * 2.0, 0.0, 1.0))
		queue_redraw()


func _to_map(pos: Vector3, center: Vector3, scale: float) -> Vector2:
	return size * 0.5 + Vector2(pos.x - center.x, pos.z - center.z) * scale


func _draw() -> void:
	if world == null or world.local_thief == null:
		return
	var me := world.local_thief
	var center := me.position
	var scale := size.x * 0.5 / _view_radius
	var mid := _to_map(Vector3.ZERO, center, scale)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.1, 0.85))
	for i in range(GameData.BIOMES.size() - 1, -1, -1):
		var col: Color = GameData.biome(i)["ground"]
		draw_circle(mid, WorldLayout.ring_outer_radius(i + 1) * scale, col.darkened(0.2))
	draw_circle(mid, GameData.BASE_RADIUS * scale, Color(0.75, 0.72, 0.68))
	var my_ring := WorldLayout.ring_at(center)
	var beacon := me.pet_element == "light"
	for egg in world.eggs:
		if not egg.is_takeable():
			continue
		var ring := WorldLayout.ring_at(egg.position)
		if not beacon and absi(ring - my_ring) > 1 and egg.id != world.lost_egg_id:
			continue
		var p := _to_map(egg.position, center, scale)
		var col: Color = GameData.rarity(egg.rarity)["color"]
		draw_circle(p, 6.0, col)
		if egg.state == Egg.State.DROPPED:
			draw_arc(p, 10.0, 0, TAU, 16, Color.WHITE, 2.0)
	for trap: Trap in world.traps.values():
		draw_rect(Rect2(_to_map(trap.position, center, scale) - Vector2(3, 3), Vector2(6, 6)), Color(0.8, 0.8, 0.85))
	for m: Monster in world.monsters.values():
		if m.element == "dark" and m.position.distance_to(center) > 30.0:
			continue
		draw_circle(_to_map(m.position, center, scale), 4.0, Color(1.0, 0.15, 0.15))
	for t: Thief in world.thieves.values():
		_draw_arrow(_to_map(t.position, center, scale), t.yaw, Color.WHITE if t.is_local else t.color, 9.0 if t.is_local else 7.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
	draw_string(get_theme_default_font(), Vector2(8, size.y - 8), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.6))


func _draw_arrow(p: Vector2, yaw: float, color: Color, s: float) -> void:
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-fwd.y, fwd.x)
	draw_colored_polygon(PackedVector2Array([p + fwd * s * 1.4, p - fwd * s * 0.8 + side * s, p - fwd * s * 0.4, p - fwd * s * 0.8 - side * s]), color)
