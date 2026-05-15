extends Camera3D
class_name FollowCamera

@export var target: Node3D
@export var offset: Vector3 = Vector3(0.0, 3.0, 6.0)
@export var target_path: NodePath

func _ready() -> void:
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path)
	if target == null:
		push_warning("FollowCamera : target non assigné, la caméra restera statique")

func _process(_delta: float) -> void:
	if target == null:
		return
	global_position = target.global_position + offset
	look_at(target.global_position, Vector3.UP)
