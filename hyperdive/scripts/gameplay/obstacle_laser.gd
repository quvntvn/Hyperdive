extends ObstacleBase

# Laser balayant : barre fine bordeaux traversant TOUT le couloir, qui s'allume/éteint.
# - Éteint (OFF_TIME) : sombre, collision OFF → on passe.
# - Avertissement (WARN_TIME) : pulse faiblement, collision ENCORE OFF → on peut encore
#   passer. OBLIGATOIRE pour éviter la mort surprise.
# - Allumé (ON_TIME) : plein éclat, collision ON → mortel.
# Cycle purement temporel (delta) → identique en chute et en envol. Matériau PROPRE
# par instance (créé au _ready) pour animer l'émission sans affecter les autres lasers.
const OFF_TIME: float = 1.8     # éteint : assez long pour passer même à haute vitesse
const WARN_TIME: float = 0.5    # avertissement (pulse), collision encore OFF
const ON_TIME: float = 0.9      # allumé : mortel
const PERIOD: float = OFF_TIME + WARN_TIME + ON_TIME

const BORDEAUX := Color(0.486, 0.180, 0.165)

var _t: float = 0.0
var _mat: StandardMaterial3D
var _shape: CollisionShape3D

func _ready() -> void:
	super._ready()
	_t = randf() * PERIOD   # désynchronise les lasers entre eux
	_shape = $BeamShape
	_shape.disabled = true
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mat.albedo_color = BORDEAUX
	_mat.emission_enabled = true
	_mat.emission = BORDEAUX
	_mat.emission_energy_multiplier = 0.0
	$Beam.material_override = _mat

func _physics_process(delta: float) -> void:
	_t += delta
	var phase: float = fmod(_t, PERIOD)
	if phase < OFF_TIME:
		# Éteint : sombre, inoffensif.
		_mat.emission_energy_multiplier = 0.0
		_shape.disabled = true
	elif phase < OFF_TIME + WARN_TIME:
		# Avertissement : pulse faible et accéléré, toujours inoffensif.
		var w: float = (phase - OFF_TIME) / WARN_TIME
		_mat.emission_energy_multiplier = 0.15 + 0.4 * absf(sin(w * PI * 6.0))
		_shape.disabled = true
	else:
		# Allumé : plein éclat, mortel.
		_mat.emission_energy_multiplier = 2.5
		_shape.disabled = false
