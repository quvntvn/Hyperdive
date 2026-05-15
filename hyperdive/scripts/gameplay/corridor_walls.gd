extends Node3D
class_name CorridorWalls

@export var target: Node3D
@export var target_path: NodePath

func _ready() -> void:
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path)

func _process(_delta: float) -> void:
	if target == null:
		return
	global_position.y = target.global_position.y
