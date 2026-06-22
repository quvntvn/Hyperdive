extends Node3D
class_name CoinSpawner

@export var player: Node3D
@export var player_path: NodePath
@export var coin_scene: PackedScene

const SPAWN_INTERVAL_Y: float = 14.4
const SPAWN_AHEAD: float = 60.0
const CORRIDOR_HALF_WIDTH: float = 4.0
const DESPAWN_BEHIND: float = 15.0
# Twist "cosmique" : pièces plus DENSES dans la bande visuelle cosmique (trésor spatial).
const COSMIC_COIN_MULT: float = 0.5

var _next_spawn_y: float = -SPAWN_AHEAD
# Signe vertical : -1 chute (spawn en bas), +1 jetpack (spawn en haut). Lu une fois au départ.
var _dir: float = -1.0
# Liste locale des pièces vivantes, ordonnée par depth croissante (= ordre de spawn). Remplace
# get_tree().get_nodes_in_group("coins") par frame (qui allouait un Array à chaque _process).
var _alive: Array[Node3D] = []

func _ready() -> void:
	if player == null and not player_path.is_empty():
		player = get_node_or_null(player_path)
	_dir = Settings.get_fall_dir()
	_next_spawn_y = (player.global_position.y if player != null else 0.0) + _dir * SPAWN_AHEAD
	if coin_scene == null:
		push_warning("CoinSpawner: coin_scene is not assigned")

func _process(_delta: float) -> void:
	if player == null or coin_scene == null:
		return
	var player_y: float = player.global_position.y
	while _dir * _next_spawn_y < _dir * player_y + SPAWN_AHEAD:
		_spawn_at(_next_spawn_y)
		# Twist cosmique : intervalle réduit (pièces denses) dans la bande visuelle cosmique.
		var interval: float = SPAWN_INTERVAL_Y
		if Zones.in_visual_band(_dir * _next_spawn_y, "cosmic"):
			interval *= COSMIC_COIN_MULT
		_next_spawn_y += _dir * interval
	# Despawn FIFO : _alive ordonnée par depth croissante → le plus ANCIEN (front) part en 1er.
	# Évite le get_nodes_in_group(...) par frame. Une pièce ramassée ailleurs (collecte/aimant)
	# est retirée sans action (is_instance_valid faux après son queue_free).
	while not _alive.is_empty():
		var coin: Node3D = _alive[0]
		if not is_instance_valid(coin):
			_alive.pop_front()
			continue
		if _dir * coin.global_position.y < _dir * player_y - DESPAWN_BEHIND:
			coin.queue_free()
			_alive.pop_front()
		else:
			break

func _spawn_at(y: float) -> void:
	var coin: Node3D = coin_scene.instantiate()
	get_parent().add_child(coin)
	coin.global_position = Vector3(
		randf_range(-CORRIDOR_HALF_WIDTH, CORRIDOR_HALF_WIDTH),
		y,
		0.0
	)
	_alive.append(coin)
