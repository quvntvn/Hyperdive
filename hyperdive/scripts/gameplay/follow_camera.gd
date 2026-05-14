extends Camera3D
class_name FollowCamera

@export var target: Node3D
@export var offset: Vector3 = Vector3(0.0, 3.0, 6.0)

var _frame: int = 0

func _process(_delta: float) -> void:
	if target == null:
		return
	_frame += 1
	if _frame % 30 == 0:
		print("Cam @ ", global_position, " | target_pos = ", target.global_position)
	global_position = target.global_position + offset
	look_at(target.global_position, Vector3.UP)
