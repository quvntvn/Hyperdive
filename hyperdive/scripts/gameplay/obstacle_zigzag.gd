extends ObstacleBase

# Couloir en ZIGZAG (chicane) : une séquence de murs partiels qui bouchent alternativement le
# côté GAUCHE puis DROIT, etc. → le joueur slalome en S. Chaque mur couvre WALL_W de large et
# laisse un passage OPENING (>=3) du côté opposé ; l'alternance force à changer de bord à
# chaque mur. STATIQUE (la disposition fait le défi, plus lisible qu'un mouvement).
#
# POINT CRITIQUE = l'espacement vertical STEP_Y. À haute vitesse (infini/jetpack accélèrent), le
# joueur doit avoir le temps de traverser le couloir latéralement (~WALL_W) AVANT le mur suivant.
# Vitesse latérale max ≈ 24 u/s ; à ~40 u/s de chute, STEP_Y=16 laisse ~0,4 s par mur → OK.
# Calé GÉNÉREUX (mieux vaut trop facile que mort garantie) ; à resserrer au test si trop simple.
#
# Étalé dans le sens du déplacement via dir → reste dans la zone réservée par le spawner et
# s'enchaîne correctement en chute (descend) ET jetpack (monte). L'alternance G/D est symétrique,
# donc valable dans les deux sens.

const HALF: float = 4.5              # demi-largeur du couloir
const WALL_W: float = 5.5            # un mur couvre 5,5 → laisse OPENING = 3,5 (>=3, franchissable)
const WALL_H: float = 1.6            # épaisseur verticale (mortel comme le mur à trou)
const WALL_D: float = 0.7            # profondeur Z
const NUM_WALLS: int = 4             # 4 murs = chicane marquante mais pas interminable
const STEP_Y: float = 16.0           # espacement vertical GÉNÉREUX (le point critique haute vitesse)

func _ready() -> void:
	super._ready()
	# dir = +1 jetpack (zone au-dessus), -1 chute (zone en dessous) → étale les murs dans le sens
	# où le spawner a réservé la zone, sinon ils déborderaient sur le flux normal.
	var dir: float = Settings.get_fall_dir()
	var mat := _make_material()
	for i in NUM_WALLS:
		# i pair → bouche la GAUCHE (passage à droite) ; i impair → bouche la DROITE (passage à
		# gauche). Vraie alternance, jamais deux murs du même côté de suite.
		var blocking_left: bool = (i % 2 == 0)
		var cx: float = (-HALF + WALL_W * 0.5) if blocking_left else (HALF - WALL_W * 0.5)
		var pos := Vector3(cx, dir * float(i) * STEP_Y, 0.0)
		var size := Vector3(WALL_W, WALL_H, WALL_D)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		bm.material = mat
		mi.mesh = bm
		mi.position = pos
		add_child(mi)
		# CollisionShape3D = enfant DIRECT du StaticBody (sinon ignorée).
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		add_child(cs)

func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL   # éclairé comme les autres obstacles
	mat.albedo_color = Color(0.239, 0.173, 0.118)              # marron noyer #3D2C1E
	mat.emission_enabled = true
	mat.emission = Color(0.239, 0.173, 0.118)
	mat.emission_energy_multiplier = 0.3
	return mat
