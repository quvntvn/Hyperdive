extends Node3D
class_name ObstacleSpawner

@export var player: Node3D
@export var player_path: NodePath
@export var obstacle_scenes: Array[PackedScene]
# Obstacles de "zone rare" (rouleau, spirale). VOLONTAIREMENT séparés de obstacle_scenes :
# ils n'entrent PAS dans la pioche pondérée normale. Ils remplacent rarement un spawn normal
# (voir gate ci-dessous), puis le flux normal reprend. Vide => comportement 100 % d'avant.
@export var special_scenes: Array[PackedScene]

const SPAWN_INTERVAL_Y: float = 14.4
const SPAWN_AHEAD: float = 60.0
const CORRIDOR_HALF_WIDTH: float = 4.5
const DESPAWN_BEHIND: float = 15.0
const CUBE_WEIGHT: int = 3   # le petit cube fixe sort 3× plus souvent que chaque autre type
# Zones rares : ~5 % de chance par intervalle, mais jamais avant SPECIAL_MIN_START (échauffement)
# ni à moins de SPECIAL_COOLDOWN d'une zone précédente (rareté préservée). CLEARANCE = couloir
# vide laissé après la zone avant de reprendre le spawn normal.
const SPECIAL_CHANCE: float = 0.05
const SPECIAL_COOLDOWN: float = 180.0
const SPECIAL_MIN_START: float = 120.0
const SPECIAL_CLEARANCE: float = 14.4

var _next_spawn_y: float = 0.0
# Signe vertical : -1 chute (spawn en bas), +1 jetpack (spawn en haut). Lu une fois au départ.
var _dir: float = -1.0
# Pool de tirage pondéré : le cube y figure CUBE_WEIGHT fois, les autres 1 fois.
# pick_random() dessus donne donc une pioche pondérée tout en gardant le ratio des autres.
var _draw_pool: Array[PackedScene] = []
# "Profondeur" minimale (coord dir-relative croissante) à partir de laquelle une zone rare
# peut se déclencher : initialisée à SPECIAL_MIN_START, repoussée de SPECIAL_COOLDOWN à chaque zone.
var _next_special_depth: float = SPECIAL_MIN_START

func _ready() -> void:
	if player == null and not player_path.is_empty():
		player = get_node_or_null(player_path)
	_dir = Settings.get_fall_dir()
	_next_spawn_y = (player.global_position.y if player != null else 0.0) + _dir * SPAWN_AHEAD
	if obstacle_scenes.is_empty():
		push_warning("ObstacleSpawner: obstacle_scenes is empty")
	_build_draw_pool()

# Construit le pool pondéré. Le cube = seul obstacle ponctuel (spawn_centered == false),
# détecté en instanciant brièvement chaque scène (coût unique au démarrage). Robuste si
# l'ordre du tableau change, contrairement à un index hardcodé.
func _build_draw_pool() -> void:
	for scene in obstacle_scenes:
		var probe: Node = scene.instantiate()
		var is_cube: bool = probe is ObstacleBase and not (probe as ObstacleBase).spawn_centered
		probe.free()
		var weight: int = CUBE_WEIGHT if is_cube else 1
		for _i in weight:
			_draw_pool.append(scene)

func _process(_delta: float) -> void:
	if player == null or obstacle_scenes.is_empty():
		return
	var player_y: float = player.global_position.y
	# On remplit jusqu'à SPAWN_AHEAD devant le joueur, dans le sens du déplacement.
	while _dir * _next_spawn_y < _dir * player_y + SPAWN_AHEAD:
		# "depth" = coord dir-relative monotone croissante (positive en chute ET jetpack).
		var depth: float = _dir * _next_spawn_y
		# Gate zone rare : cooldown écoulé + tirage ~5 %. Sinon flux normal inchangé.
		if not special_scenes.is_empty() and depth >= _next_special_depth and randf() < SPECIAL_CHANCE:
			var zone_len: float = _spawn_special_at(_next_spawn_y)
			_next_special_depth = depth + SPECIAL_COOLDOWN
			# Saut vertical = on réserve un couloir vide (zone + marge) → aucun obstacle normal
			# ne se mêle à la zone, et le flux normal reprend juste après.
			_next_spawn_y += _dir * (zone_len + SPECIAL_CLEARANCE)
		else:
			_spawn_at(_next_spawn_y)
			_next_spawn_y += _dir * SPAWN_INTERVAL_Y
	# Despawn ce qui est passé DERRIÈRE le joueur (sinon fuite mémoire).
	for obstacle in get_tree().get_nodes_in_group("obstacles"):
		if _dir * obstacle.global_position.y < _dir * player_y - DESPAWN_BEHIND:
			# Obstacle passé derrière le joueur = esquivé (compté une seule fois, au despawn).
			Settings.register_obstacle_dodged()
			obstacle.queue_free()

func _spawn_at(y: float) -> void:
	var picked: PackedScene = _draw_pool.pick_random()
	var obstacle: Node3D = picked.instantiate()
	get_parent().add_child(obstacle)
	# Obstacles pleine largeur (barre, mur, oscillant) : centrés, ils gèrent leur
	# propre disposition latérale. Sinon : X aléatoire sur la largeur du couloir.
	var x: float = 0.0
	if not (obstacle is ObstacleBase and (obstacle as ObstacleBase).spawn_centered):
		x = randf_range(-CORRIDOR_HALF_WIDTH, CORRIDOR_HALF_WIDTH)
	obstacle.global_position = Vector3(x, y, 0.0)

# Pose UN obstacle de zone rare (rouleau ou spirale, 50/50) au centre. Retourne sa hauteur
# verticale (zone_length) pour que la boucle de spawn saute la zone et reprenne le flux normal.
func _spawn_special_at(y: float) -> float:
	var picked: PackedScene = special_scenes.pick_random()
	var obstacle: Node3D = picked.instantiate()
	get_parent().add_child(obstacle)
	obstacle.global_position = Vector3(0.0, y, 0.0)
	if obstacle is ObstacleBase and (obstacle as ObstacleBase).zone_length > 0.0:
		return (obstacle as ObstacleBase).zone_length
	return SPAWN_INTERVAL_Y
