extends Node3D
class_name PowerupSpawner

@export var player: Node3D
@export var player_path: NodePath
@export var powerup_scene: PackedScene

const SPAWN_INTERVAL_MIN: float = 400.0
const SPAWN_INTERVAL_MAX: float = 600.0
const SPAWN_AHEAD: float = 60.0
const CORRIDOR_HALF_WIDTH: float = 4.0
const DESPAWN_BEHIND: float = 15.0
const TYPES: Array[String] = ["shield", "slowmo", "magnet", "boost"]
const TYPES_CAMPAIGN: Array[String] = ["shield", "slowmo", "boost"]

var _next_spawn_y: float = 0.0
var _campaign_mode: bool = false
# Signe vertical : -1 chute (spawn en bas), +1 envol (spawn en haut). Lu une fois au départ.
var _dir: float = -1.0

func set_campaign_mode(enabled: bool) -> void:
	_campaign_mode = enabled

func _ready() -> void:
	if player == null and not player_path.is_empty():
		player = get_node_or_null(player_path)
	_dir = Settings.get_fall_dir()
	var start_y: float = player.global_position.y if player != null else 0.0
	_next_spawn_y = start_y + _dir * (SPAWN_AHEAD + randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX))
	if powerup_scene == null:
		push_warning("PowerupSpawner: powerup_scene is not assigned")

func _process(_delta: float) -> void:
	if player == null or powerup_scene == null:
		return
	var player_y: float = player.global_position.y
	while _dir * _next_spawn_y < _dir * player_y + SPAWN_AHEAD:
		_spawn_at(_next_spawn_y)
		_next_spawn_y += _dir * randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
	for pu: Node3D in get_tree().get_nodes_in_group("powerups"):
		if _dir * pu.global_position.y < _dir * player_y - DESPAWN_BEHIND:
			pu.queue_free()

func _spawn_at(y: float) -> void:
	var pool: Array[String] = TYPES_CAMPAIGN if _campaign_mode else TYPES
	var pu: Powerup = powerup_scene.instantiate()
	pu.type = pool[randi() % pool.size()]
	get_parent().add_child(pu)
	pu.global_position = Vector3(
		randf_range(-CORRIDOR_HALF_WIDTH, CORRIDOR_HALF_WIDTH),
		y,
		0.0
	)
