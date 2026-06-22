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
	# Jetpack : on monte. Miroir vertical de la caméra de chute (pitch + offset inversés)
	# → on regarde vers le HAUT, perso vers le bas du cadre. DEBUG Étape 1, à doser en Étape 2.
	if Settings.active_mode == "jetpack":
		rotation_degrees.x = -rotation_degrees.x
		offset.y = -offset.y

func shake(amount: float) -> void:
	_shake_intensity = amount

func set_target(node: Node3D) -> void:
	target = node

func _process(delta: float) -> void:
	if target == null:
		return
	# La caméra n'est PAS interpolée (physics_interpolation_mode OFF), mais le perso EST rendu
	# interpolé (interpolation physique 120Hz). Lire target.global_position donnerait la position
	# physique BRUTE (calée sur les ticks), décalée du rendu interpolé du perso → vibration verticale.
	# On suit donc la transform INTERPOLÉE du perso : caméra et perso restent dans le même temps-espace.
	# (Suivi Y rigide, aucun lerp — conforme au CLAUDE.md.) S'applique à TOUS les modes (chute/jetpack).
	var target_y: float = target.get_global_transform_interpolated().origin.y
	global_position.x = offset.x
	global_position.y = target_y + offset.y
	if _shake_intensity > 0.0:
		global_position.x += randf_range(-1.0, 1.0) * _shake_intensity
		global_position.y += randf_range(-1.0, 1.0) * _shake_intensity
		_shake_intensity -= SHAKE_DECAY * delta
		if _shake_intensity < 0.005:
			_shake_intensity = 0.0
