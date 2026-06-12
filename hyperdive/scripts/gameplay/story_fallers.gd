extends Node3D
class_name StoryFallers
# Les 6 silhouettes de la famille (2 adultes + 4 enfants) qui chutent avec le joueur pendant
# l'OUVERTURE du chapitre 1 (objectif "descent"). Des OMBRES, pas des personnages : la FORME
# du personnage du joueur (mêmes primitives tête/torse/bras/jambes que player.tscn, pose
# plongeon spread-eagle figée) en matériau sombre unshaded uniforme — AUCUNE collision, aucun
# skin, aucun visage, aucun script player. Elles suivent le Y (interpolé) du joueur avec un
# drift sinusoïdal léger, puis se DISPERSENT une à une au fil de la descente (fondu alpha +
# dérive latérale/verticale) — préfigure la séparation de la famille. Le joueur finit SEUL.

const SILHOUETTE_COLOR: Color = Color(0.08, 0.10, 0.18, 0.92)   # bleu nuit sombre (ombre)
const LEAVE_DURATION: float = 2.8   # durée du fondu/de la dérive quand une silhouette part
const ADULT_SCALE: float = 1.5     # même gabarit que le Character du joueur (scale 1.5)
const CHILD_SCALE: float = 1.0     # ≈ 0.67 × adulte → enfants nettement plus petits

# Une entrée par membre de la famille : gabarit (adulte/enfant), offset de base autour du joueur
# (x latéral dans le couloir, y au-dessus/en-dessous, z léger hors plan) et seuil de départ
# (fraction de la descente où la silhouette se disperse). Les ENFANTS partent tôt, les PARENTS
# tiennent le plus longtemps (deux grandes formes qui restent = lisible) ; la dernière part vers
# ~86 % → tout le monde a disparu juste avant l'impact.
const FAMILY: Array[Dictionary] = [
	{"adult": false, "base": Vector3(-3.4, -4.5,  0.8), "leave": 0.18},
	{"adult": false, "base": Vector3( 3.6, -1.0, -0.9), "leave": 0.34},
	{"adult": false, "base": Vector3(-1.2, -6.0, -1.2), "leave": 0.50},
	{"adult": false, "base": Vector3( 1.6, -5.0,  1.0), "leave": 0.64},
	{"adult": true,  "base": Vector3(-2.6, -1.5, -0.6), "leave": 0.76},
	{"adult": true,  "base": Vector3( 2.4, -3.0,  0.5), "leave": 0.86},
]

var _player: Node3D
var _ground_dist: float = 400.0
var _fallers: Array[Dictionary] = []
var _t: float = 0.0

func setup(player: Node3D, ground_dist: float) -> void:
	_player = player
	_ground_dist = maxf(ground_dist, 1.0)
	# Meshes PARTAGÉS entre les 6 silhouettes (mêmes dimensions que player.tscn) — seul le
	# matériau est propre à chacune (son alpha s'anime indépendamment à la dispersion).
	var torso := BoxMesh.new()
	torso.size = Vector3(0.26, 0.40, 0.16)
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	var arm := CapsuleMesh.new()
	arm.radius = 0.05
	arm.height = 0.36
	var leg := CapsuleMesh.new()
	leg.radius = 0.06
	leg.height = 0.40
	for f: Dictionary in FAMILY:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = SILHOUETTE_COLOR
		var node := _make_silhouette(bool(f["adult"]), torso, head, arm, leg, mat)
		# Tête la première comme le joueur (CHARACTER_BASE_ROT ~205° X) + inclinaison propre
		# à chacune (lacet/roulis légers : leur chute n'est pas un copier-coller).
		node.rotation_degrees = Vector3(
			205.0 + randf_range(-8.0, 8.0), randf_range(-10.0, 10.0), randf_range(-14.0, 14.0))
		add_child(node)
		_fallers.append({
			"node": node, "mat": mat, "base": f["base"] as Vector3, "leave": float(f["leave"]),
			"phase": randf_range(0.0, TAU), "leave_t": -1.0,   # -1 = pas encore partie
			# Dérive de dispersion : vers SON côté du couloir + vers le haut (elle "ralentit"
			# dans la chute et reste derrière) pendant que l'alpha tombe.
			"drift": Vector3(signf((f["base"] as Vector3).x) * 3.0, 5.0, -0.8),
		})

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_t += delta
	# Suit le Y INTERPOLÉ du joueur (même pattern que la caméra → pas de jitter à 120 Hz).
	global_position.y = (_player.get_global_transform_interpolated().origin as Vector3).y
	var progress: float = clampf(absf(global_position.y) / _ground_dist, 0.0, 1.0)
	for f: Dictionary in _fallers:
		var node := f["node"] as Node3D
		if not node.visible:
			continue
		# Départ déclenché quand la descente atteint le seuil de cette silhouette.
		if float(f["leave_t"]) < 0.0 and progress >= float(f["leave"]):
			f["leave_t"] = 0.0
		var leave: float = 0.0
		if float(f["leave_t"]) >= 0.0:
			f["leave_t"] = float(f["leave_t"]) + delta / LEAVE_DURATION
			leave = clampf(float(f["leave_t"]), 0.0, 1.0)
		# Flottement lent autour de l'offset de base : leur chute n'est pas parfaitement
		# synchrone avec la nôtre (vivantes), sans physique ni collision.
		var phase: float = float(f["phase"])
		var sway := Vector3(sin(_t * 0.55 + phase) * 0.45, sin(_t * 0.34 + phase * 1.7) * 0.9, 0.0)
		var k: float = smoothstep(0.0, 1.0, leave)
		node.position = (f["base"] as Vector3) + sway + (f["drift"] as Vector3) * k
		(f["mat"] as StandardMaterial3D).albedo_color.a = SILHOUETTE_COLOR.a * (1.0 - k)
		if leave >= 1.0:
			node.visible = false

# Assemble une silhouette : les primitives du Character du joueur (mêmes tailles/offsets que
# player.tscn) en pose plongeon FIGÉE — bras écartés (±115° Z, les bases du sway), jambes
# ouvertes (±35° Z). Juste des formes : pas de collision, pas de script, pas de détail.
func _make_silhouette(adult: bool, torso: Mesh, head: Mesh, arm: Mesh, leg: Mesh,
		mat: StandardMaterial3D) -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * (ADULT_SCALE if adult else CHILD_SCALE)
	_add_part(root, torso, Vector3(0.0, 0.10, 0.0), Vector3.ZERO, mat)
	_add_part(root, head, Vector3(0.0, 0.42, 0.0), Vector3.ZERO, mat)
	_add_part(root, arm, Vector3(-0.19, 0.10, 0.0), Vector3(22.0, 0.0, 115.0), mat)
	_add_part(root, arm, Vector3(0.19, 0.10, 0.0), Vector3(22.0, 0.0, -115.0), mat)
	_add_part(root, leg, Vector3(-0.13, -0.28, 0.0), Vector3(0.0, 0.0, -35.0), mat)
	_add_part(root, leg, Vector3(0.13, -0.28, 0.0), Vector3(0.0, 0.0, 35.0), mat)
	return root

func _add_part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3,
		mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat
	parent.add_child(mi)
