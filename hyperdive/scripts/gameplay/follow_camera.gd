extends Camera3D
class_name FollowCamera

const SHAKE_DECAY: float = 8.0

@export var target: Node3D
@export var offset: Vector3 = Vector3(0.0, 3.0, 0.0)
@export var target_path: NodePath

var _shake_intensity: float = 0.0

func _ready() -> void:
	add_to_group("follow_camera")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path)
	if target == null:
		push_warning("FollowCamera : target non assigné, la caméra restera statique")

func shake(amount: float) -> void:
	_shake_intensity = amount

func set_target(node: Node3D) -> void:
	target = node

func _process(delta: float) -> void:
	if target == null:
		return
	global_position.x = offset.x
	global_position.y = target.global_position.y + offset.y
	if _shake_intensity > 0.0:
		global_position.x += randf_range(-1.0, 1.0) * _shake_intensity
		global_position.y += randf_range(-1.0, 1.0) * _shake_intensity
		_shake_intensity -= SHAKE_DECAY * delta
		if _shake_intensity < 0.005:
			_shake_intensity = 0.0
