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
const TYPES: Array[String] = ["shield", "slowmo", "magnet", "boost", "megaboost"]
const TYPES_CAMPAIGN: Array[String] = ["shield", "slowmo", "boost", "megaboost"]
# Tirage PONDÉRÉ (avant : équiprobable). Le boost sort un peu plus souvent que les autres,
# le méga-boost est un JACKPOT très rare : en classique boost 12/40 = 30 %, méga-boost
# 1/40 = 2,5 %, les autres ≈ 22,5 % chacun.
const WEIGHTS: Dictionary = {"shield": 9, "slowmo": 9, "magnet": 9, "boost": 12, "megaboost": 1}

var _next_spawn_y: float = 0.0
var _campaign_mode: bool = false
# Signe vertical : -1 chute (spawn en bas), +1 jetpack (spawn en haut). Lu une fois au départ.
var _dir: float = -1.0
# Liste locale des power-ups vivants, ordonnée par depth croissante (= ordre de spawn). Remplace
# get_tree().get_nodes_in_group("powerups") par frame (qui allouait un Array à chaque _process).
var _alive: Array[Node3D] = []

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
	# Despawn FIFO : _alive ordonnée par depth croissante → le plus ANCIEN (front) part en 1er.
	# Évite le get_nodes_in_group(...) par frame. Un power-up ramassé ailleurs est retiré sans
	# action (is_instance_valid faux après son queue_free).
	while not _alive.is_empty():
		var pu: Node3D = _alive[0]
		if not is_instance_valid(pu):
			_alive.pop_front()
			continue
		if _dir * pu.global_position.y < _dir * player_y - DESPAWN_BEHIND:
			pu.queue_free()
			_alive.pop_front()
		else:
			break

func _spawn_at(y: float) -> void:
	var pool: Array[String] = TYPES_CAMPAIGN if _campaign_mode else TYPES
	var pu: Powerup = powerup_scene.instantiate()
	pu.type = _pick_type(pool)
	get_parent().add_child(pu)
	pu.global_position = Vector3(
		randf_range(-CORRIDOR_HALF_WIDTH, CORRIDOR_HALF_WIDTH),
		y,
		0.0
	)
	_alive.append(pu)

# Tirage pondéré : somme des poids du pool, on tire dans [0,total) et on défausse poids par poids.
func _pick_type(pool: Array[String]) -> String:
	var total: int = 0
	for t: String in pool:
		total += int(WEIGHTS.get(t, 1))
	var r: int = randi() % total
	for t: String in pool:
		r -= int(WEIGHTS.get(t, 1))
		if r < 0:
			return t
	return pool[0]
