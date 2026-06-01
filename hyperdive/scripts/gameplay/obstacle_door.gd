extends ObstacleBase

# Porte coulissante : deux panneaux bordeaux qui s'écartent/rejoignent en rythme.
# Fermés (openness 0) ils bouchent tout le couloir ; ouverts (openness 1) ils laissent
# un passage central de GAP (>=3, franchissable). Les panneaux sont TOUJOURS mortels
# (collision fixe) ; c'est l'espace central qui laisse passer. Cycle purement temporel
# (delta) → strictement identique en chute et en envol.
const PANEL_HALF: float = 2.25     # demi-largeur d'un panneau (largeur 4.5)
const GAP_HALF: float = 1.5        # passage ouvert = 3.0
const CLOSED_TIME: float = 1.0
const OPEN_TIME: float = 1.6       # ouvert assez longtemps pour passer même à haute vitesse
const TRANS: float = 0.4           # transition fluide (pas de snap)
const PERIOD: float = CLOSED_TIME + TRANS + OPEN_TIME + TRANS

var _t: float = 0.0

func _ready() -> void:
	super._ready()
	_t = randf() * PERIOD   # désynchronise les portes entre elles

func _physics_process(delta: float) -> void:
	_t += delta
	var openness: float = _openness(fmod(_t, PERIOD))
	# Fermé : centre du panneau à ±PANEL_HALF (bords se rejoignent à x=0).
	# Ouvert : centre à ±(GAP_HALF + PANEL_HALF) → bord intérieur à ±GAP_HALF.
	var x: float = lerpf(PANEL_HALF, GAP_HALF + PANEL_HALF, openness)
	$PanelLeft.position.x = -x
	$PanelLeftShape.position.x = -x
	$PanelRight.position.x = x
	$PanelRightShape.position.x = x

# 0 = fermé, 1 = ouvert, transitions douces avec maintien (dwell) aux deux extrêmes.
func _openness(phase: float) -> float:
	if phase < CLOSED_TIME:
		return 0.0
	phase -= CLOSED_TIME
	if phase < TRANS:
		return smoothstep(0.0, 1.0, phase / TRANS)
	phase -= TRANS
	if phase < OPEN_TIME:
		return 1.0
	phase -= OPEN_TIME
	return 1.0 - smoothstep(0.0, 1.0, phase / TRANS)
