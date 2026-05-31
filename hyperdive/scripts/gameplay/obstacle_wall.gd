extends ObstacleBase

# Mur occupant TOUTE la largeur du couloir sauf un TROU à position latérale aléatoire.
# Construit en deux blocs (gauche/droite) encadrant l'ouverture. Le trou fait toujours
# 2*GAP_HALF de large (franchissable), et chaque bloc garde au moins ~1.0 de large.
const HALF_W: float = 4.5     # demi-largeur du couloir
const GAP_HALF: float = 1.5   # demi-largeur du trou → ouverture = 3.0 mini (franchissable)
const HOLE_RANGE: float = 3.0 # centre du trou dans [-3, 3] → reste atteignable, jamais collé au bord
const HEIGHT: float = 1.6
const DEPTH: float = 0.65

func _ready() -> void:
	super._ready()
	var hole: float = randf_range(-HOLE_RANGE, HOLE_RANGE)
	_make_block(-HALF_W, hole - GAP_HALF)   # bloc gauche
	_make_block(hole + GAP_HALF, HALF_W)    # bloc droit

func _make_block(x0: float, x1: float) -> void:
	var w: float = x1 - x0
	if w <= 0.05:
		return
	var cx: float = (x0 + x1) * 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = Color(0.914, 0.310, 0.216)
	mat.emission_enabled = true
	mat.emission = Color(0.914, 0.310, 0.216)
	mat.emission_energy_multiplier = 0.3
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, HEIGHT, DEPTH)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.x = cx
	add_child(mi)
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, HEIGHT, DEPTH)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.x = cx
	add_child(cs)
