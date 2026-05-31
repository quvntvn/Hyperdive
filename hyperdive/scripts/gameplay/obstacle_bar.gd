extends ObstacleBase

# Barre horizontale large : occupe la majeure partie du couloir, laissant un passage
# (GAP) soit à gauche soit à droite (aléatoire au spawn). Centrée par le spawner ;
# c'est l'offset de la poutre qui décide du côté ouvert.
const HALF_W: float = 4.5     # demi-largeur du couloir
const BEAM_W: float = 6.0     # largeur de la poutre → passage = 9 - 6 = 3.0

func _ready() -> void:
	super._ready()
	# Passage à droite → poutre décalée à gauche (et inversement).
	var gap_on_right: bool = randf() < 0.5
	var offset: float = HALF_W - BEAM_W / 2.0   # 1.5
	var cx: float = -offset if gap_on_right else offset
	$Beam.position.x = cx
	$BeamShape.position.x = cx
