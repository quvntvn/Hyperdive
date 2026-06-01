extends ObstacleBase

# Cube identique au cube de base mais qui GLISSE latéralement en va-et-vient.
# PIÈGE géré : on ne touche QUE l'axe X (latéral). Y/Z sont laissés intacts → le
# mouvement est identique en chute et en jetpack, aucune dérive verticale.
# Amplitude bornée pour rester dans le couloir (half = 4.5, cube half ≈ 0.33).
const SPEED: float = 2.0
const AMPLITUDE: float = 2.5

var _t: float = 0.0
var _center: float = 0.0

func _ready() -> void:
	super._ready()
	_t = randf() * TAU   # phase aléatoire → tous ne sont pas synchronisés
	_center = 0.0         # oscille autour du centre du couloir (spawn_centered)

func _physics_process(delta: float) -> void:
	_t += delta * SPEED
	var p: Vector3 = global_position
	p.x = _center + sin(_t) * AMPLITUDE
	global_position = p
