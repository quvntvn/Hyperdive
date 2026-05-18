extends Node3D
class_name CoinSpawner

@export var player: Node3D
@export var player_path: NodePath
@export var coin_scene: PackedScene

const SPAWN_INTERVAL_Y: float = 3.6
const SPAWN_AHEAD: float = 60.0
const CORRIDOR_HALF_WIDTH: float = 4.0
const DESPAWN_BEHIND: float = 15.0

var _next_spawn_y: float = -SPAWN_AHEAD

func _ready() -> void:
	if player == null and not player_path.is_empty():
		player = get_node_or_null(player_path)
	_next_spawn_y = (player.global_position.y if player != null else 0.0) - SPAWN_AHEAD
	if coin_scene == null:
		push_warning("CoinSpawner: coin_scene is not assigned")

func _process(_delta: float) -> void:
	if player == null or coin_scene == null:
		return
	var player_y: float = player.global_position.y
	while player_y - SPAWN_AHEAD < _next_spawn_y:
		_spawn_at(_next_spawn_y)
		_next_spawn_y -= SPAWN_INTERVAL_Y
	for coin in get_tree().get_nodes_in_group("coins"):
		if coin.global_position.y > player_y + DESPAWN_BEHIND:
			coin.queue_free()

func _spawn_at(y: float) -> void:
	var coin: Node3D = coin_scene.instantiate()
	get_parent().add_child(coin)
	coin.global_position = Vector3(
		randf_range(-CORRIDOR_HALF_WIDTH, CORRIDOR_HALF_WIDTH),
		y,
		0.0
	)
