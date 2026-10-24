class_name CollisionMath
extends RefCounted
## Hit tests on the flat ground plane. Things can move 10 m per frame at top
## speed, so traps and catches test the whole path travelled this frame.

## Shortest distance on the ground between `point` and the segment `from`→`to`.
static func segment_point_distance(from: Vector3, to: Vector3, point: Vector3) -> float:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var p := Vector2(point.x, point.z)
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 1e-8:
		return a.distance_to(p)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return (a + ab * t).distance_to(p)


static func path_hits(from: Vector3, to: Vector3, point: Vector3, radius: float) -> bool:
	return segment_point_distance(from, to, point) <= radius


## Closest distance on the ground between two things that both moved this frame.
static func moving_distance(a_from: Vector3, a_to: Vector3, b_from: Vector3, b_to: Vector3) -> float:
	# Work in b's frame: b stands still at b_from while a moves by (its motion - b's motion).
	var rel_to := a_to - (b_to - b_from)
	return segment_point_distance(a_from, rel_to, b_from)


## True when `target` is within reach and inside the swing cone in front of the swinger.
static func in_swing(origin: Vector3, forward: Vector3, target: Vector3, reach: float, cone_degrees: float) -> bool:
	var to_target := Vector2(target.x - origin.x, target.z - origin.z)
	var dist := to_target.length()
	if dist > reach:
		return false
	if dist < 0.75:
		return true
	var fwd := Vector2(forward.x, forward.z)
	if fwd.length() < 1e-4:
		return true
	return absf(rad_to_deg(fwd.angle_to(to_target))) <= cone_degrees * 0.5
