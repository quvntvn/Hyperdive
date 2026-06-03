extends ObstacleBase

# Spirale / escalier de cubes : SLALOM. Cubes échelonnés en Y avec un X en zigzag → le joueur
# weave latéralement (son vrai contrôle) pour passer entre eux. STATIQUE : c'est la disposition
# qui fait le défi (plus lisible qu'un mouvement). Passage >=3 entre marches → franchissable à
# haute vitesse. Placé dans le sens du déplacement (dir) → reste dans la zone réservée par le
# spawner, identique en chute et en jetpack.

const CUBE: float = 1.0
const STEP_Y: float = 2.4
# Zigzag latéral (mur à mur) : force un vrai slalom gauche-droite-gauche.
const XS: Array[float] = [-3.0, -1.5, 0.0, 1.5, 3.0, 1.5, 0.0]

func _ready() -> void:
	super._ready()
	# dir = +1 jetpack (zone au-dessus), -1 chute (zone en dessous) → on étale les cubes dans
	# le sens où le spawner a réservé la zone (sinon ils déborderaient sur le flux normal).
	var dir: float = Settings.get_fall_dir()
	var mat := _make_material()
	for i in XS.size():
		var pos := Vector3(XS[i], dir * float(i) * STEP_Y, 0.0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(CUBE, CUBE, CUBE)
		bm.material = mat
		mi.mesh = bm
		mi.position = pos
		add_child(mi)
		# CollisionShape3D = enfant DIRECT du StaticBody (sinon ignorée).
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(CUBE, CUBE, CUBE)
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
