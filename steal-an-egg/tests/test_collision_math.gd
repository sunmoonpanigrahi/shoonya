extends TestCase


func test_fast_monster_cannot_skip_a_trap() -> void:
	# At top speed a monster moves 10 m in one frame and jumps right over a 1.8 m trap.
	var trap := Vector3(5, 0, 0.5)
	check(CollisionMath.path_hits(Vector3(0, 0, 0), Vector3(10, 0, 0), trap, GameData.TRAP_RADIUS), "path crosses the trap")
	check(not CollisionMath.path_hits(Vector3(0, 0, 3), Vector3(10, 0, 3), trap, GameData.TRAP_RADIUS), "path misses the trap")
	check(not CollisionMath.path_hits(Vector3(-10, 0, 0), Vector3(0, 0, 0), Vector3(5, 0, 0), 1.0), "trap is past the end")


func test_moving_distance() -> void:
	# Two runners swap places in one frame: they met in the middle.
	var d := CollisionMath.moving_distance(Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 0), Vector3(0, 0, 0))
	check_near(d, 0.0, 1e-4, "head-on")
	# Same speed, same direction, 5 m apart: the gap never closes.
	d = CollisionMath.moving_distance(Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(5, 0, 0), Vector3(15, 0, 0))
	check_near(d, 5.0, 1e-4, "parallel")


func test_swing_cone() -> void:
	var fwd := Vector3(0, 0, -1)
	check(CollisionMath.in_swing(Vector3.ZERO, fwd, Vector3(0, 0, -3), 3.5, 110), "straight ahead")
	check(CollisionMath.in_swing(Vector3.ZERO, fwd, Vector3(1.5, 0, -2), 3.5, 110), "slightly to the side")
	check(not CollisionMath.in_swing(Vector3.ZERO, fwd, Vector3(0, 0, 3), 3.5, 110), "behind")
	check(not CollisionMath.in_swing(Vector3.ZERO, fwd, Vector3(0, 0, -5), 3.5, 110), "out of reach")
