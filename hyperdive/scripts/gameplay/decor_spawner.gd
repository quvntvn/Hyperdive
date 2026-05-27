extends Node3D
class_name DecorSpawner

@export var player: Node3D
@export var player_path: NodePath
@export var decor_scene: PackedScene

const SPAWN_INTERVAL_MIN: float = 18.0
const SPAWN_INTERVAL_MAX: float = 40.0
const SPAWN_AHEAD: float = 70.0
const DESPAWN_BEHIND: float = 20.0
const WALL_X_MIN: float = 4.3
const WALL_X_MAX: float = 4.8
const WALL_Z_RANGE: float = 3.2
const SCALE_MIN: float = 0.6
const SCALE_MAX: float = 1.4

const TYPES: Array[String] = ["starburst", "boomerang", "sputnik", "flat"]
const PALETTE: Array[Color] = [
	Color(0.914, 0.310, 0.216),  # orange brûlé
	Color(0.235, 0.682, 0.639),  # turquoise rétro
	Color(0.949, 0.757, 0.306),  # jaune moutarde
	Color(0.957, 0.914, 0.804),  # crème
	Color(0.486, 0.180, 0.165),  # bordeaux
]

var _next_spawn_y: float = 0.0

func _ready() -> void:
	if player == null and not player_path.is_empty():
		player = get_node_or_null(player_path)
	var start_y: float = player.global_position.y if player != null else 0.0
	_next_spawn_y = start_y - SPAWN_AHEAD * 0.35
	if decor_scene == null:
		push_warning("DecorSpawner: decor_scene is not assigned")

func _process(_delta: float) -> void:
	if player == null or decor_scene == null:
		return
	var player_y: float = player.global_position.y
	while player_y - SPAWN_AHEAD < _next_spawn_y:
		_spawn_at(_next_spawn_y)
		_next_spawn_y -= randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
	for el: Node3D in get_tree().get_nodes_in_group("decor"):
		if el.global_position.y > player_y + DESPAWN_BEHIND:
			el.queue_free()

func _spawn_at(y: float) -> void:
	var el: DecorElement = decor_scene.instantiate()
	el.type = TYPES[randi() % TYPES.size()]
	el.color = PALETTE[randi() % PALETTE.size()]
	get_parent().add_child(el)

	var side: float = 1.0 if randi() % 2 == 0 else -1.0
	el.global_position = Vector3(
		randf_range(WALL_X_MIN, WALL_X_MAX) * side,
		y,
		randf_range(-WALL_Z_RANGE, WALL_Z_RANGE)
	)
	var s: float = randf_range(SCALE_MIN, SCALE_MAX)
	el.scale = Vector3(s, s, s)
	el.rotation = Vector3(
		randf_range(-0.15, 0.15),
		randf_range(-0.28, 0.28),
		randf_range(-0.28, 0.28)
	)
