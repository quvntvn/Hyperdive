extends Node3D
class_name ObstacleSpawner

@export var player: Node3D
@export var player_path: NodePath
@export var obstacle_scenes: Array[PackedScene]

const SPAWN_INTERVAL_Y: float = 7.2
const SPAWN_AHEAD: float = 60.0
const CORRIDOR_HALF_WIDTH: float = 4.5
const DESPAWN_BEHIND: float = 15.0

var _next_spawn_y: float = 0.0
# Signe vertical : -1 chute (spawn en bas), +1 envol (spawn en haut). Lu une fois au départ.
var _dir: float = -1.0

func _ready() -> void:
	if player == null and not player_path.is_empty():
		player = get_node_or_null(player_path)
	_dir = Settings.get_fall_dir()
	_next_spawn_y = (player.global_position.y if player != null else 0.0) + _dir * SPAWN_AHEAD
	if obstacle_scenes.is_empty():
		push_warning("ObstacleSpawner: obstacle_scenes is empty")

func _process(_delta: float) -> void:
	if player == null or obstacle_scenes.is_empty():
		return
	var player_y: float = player.global_position.y
	# On remplit jusqu'à SPAWN_AHEAD devant le joueur, dans le sens du déplacement.
	while _dir * _next_spawn_y < _dir * player_y + SPAWN_AHEAD:
		_spawn_at(_next_spawn_y)
		_next_spawn_y += _dir * SPAWN_INTERVAL_Y
	# Despawn ce qui est passé DERRIÈRE le joueur (sinon fuite mémoire).
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		if _dir * obstacle.global_position.y < _dir * player_y - DESPAWN_BEHIND:
			obstacle.queue_free()

func _spawn_at(y: float) -> void:
	var picked: PackedScene = obstacle_scenes.pick_random()
	var obstacle: Node3D = picked.instantiate()
	get_parent().add_child(obstacle)
	obstacle.global_position = Vector3(
		randf_range(-CORRIDOR_HALF_WIDTH, CORRIDOR_HALF_WIDTH),
		y,
		0.0
	)
