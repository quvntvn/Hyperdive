extends Camera3D
class_name FollowCamera

@export var target: Node3D
@export var offset: Vector3 = Vector3(0.0, 4.0, 8.0)
@export var smooth_speed: float = 8.0

func _physics_process(delta: float) -> void:
	if not target:
		return
	var desired: Vector3 = target.global_position + offset
	global_position = global_position.lerp(desired, clamp(smooth_speed * delta, 0.0, 1.0))
