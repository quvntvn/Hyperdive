extends ObstacleBase

# Porte automatique : deux panneaux bordeaux qui s'écartent à l'APPROCHE du joueur,
# comme des portes coulissantes réactives. FERMÉS par défaut (openness 0) ils bouchent
# tout le couloir ; OUVERTS (openness 1) ils laissent un passage central de GAP (>=3,
# franchissable). Les panneaux sont TOUJOURS mortels (collision fixe) ; c'est l'espace
# central qui laisse passer.
#
# Déclenchement par DISTANCE VERTICALE absolue au joueur → marche en chute (le joueur
# arrive par le haut) ET en envol (par le bas) sans dépendre du signe dir : dans les
# deux cas il se RAPPROCHE, donc abs(porte.y - joueur.y) décroît.
const PANEL_HALF: float = 2.25     # demi-largeur d'un panneau (largeur 4.5)
const GAP_HALF: float = 1.5        # passage ouvert = 3.0
const OPEN_DISTANCE: float = 16.0  # ouvre quand le joueur est à moins de 16 u (assez tôt
                                   # pour finir d'ouvrir avant l'arrivée, même à haute vitesse)
const OPEN_SPEED: float = 3.0      # vitesse de lerp de l'openness (s^-1) → mouvement fluide

var _openness: float = 0.0
var _player: Node3D = null

func _ready() -> void:
	super._ready()
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	# Cible : ouverte si le joueur est proche sur l'axe vertical (abs → chute ET envol).
	var target: float = 0.0
	if _player != null:
		if absf(global_position.y - _player.global_position.y) < OPEN_DISTANCE:
			target = 1.0
	# Lissage : openness glisse vers la cible, jamais de snap.
	_openness = move_toward(_openness, target, OPEN_SPEED * delta)
	# Fermé : centre du panneau à ±PANEL_HALF (bords se rejoignent à x=0).
	# Ouvert : centre à ±(GAP_HALF + PANEL_HALF) → bord intérieur à ±GAP_HALF.
	var x: float = lerpf(PANEL_HALF, GAP_HALF + PANEL_HALF, _openness)
	$PanelLeft.position.x = -x
	$PanelLeftShape.position.x = -x
	$PanelRight.position.x = x
	$PanelRightShape.position.x = x
