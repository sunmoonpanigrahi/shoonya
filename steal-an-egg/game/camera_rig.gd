class_name CameraRig
extends Camera3D
## Third-person camera behind the local thief. It swings behind the thief's heading
## and pulls back and widens with speed. Dragging on the screen turns it.

var target: Thief
var cam_yaw := 0.0
var drag_yaw := 0.0


func _ready() -> void:
	far = 3500.0
	near = 0.2
	current = true


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var t := target.speed_t
	if target.moving:
		cam_yaw = rotate_toward(cam_yaw, target.yaw, delta * lerpf(1.6, 2.6, t))
	drag_yaw = move_toward(drag_yaw, 0.0, delta * 0.6) if target.moving else drag_yaw
	var yaw := cam_yaw + drag_yaw
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	var dist := lerpf(6.5, 9.0, t)
	var height := lerpf(3.2, 4.8, t) + target.fall_left * 25.0
	var focus := target.position + Vector3(0, 1.4, 0)
	position = focus + back * dist + Vector3(0, height, 0)
	look_at(focus + Vector3(0, 0.3, 0) - back * 4.0, Vector3.UP)
	fov = lerpf(fov, lerpf(68.0, 92.0, t), clampf(delta * 4.0, 0.0, 1.0))


## Yaw the joystick is relative to.
func input_yaw() -> float:
	return cam_yaw + drag_yaw


func drag(dx_pixels: float) -> void:
	drag_yaw -= dx_pixels * 0.008
