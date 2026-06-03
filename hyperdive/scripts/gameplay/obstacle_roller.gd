extends ObstacleBase

# Roue crantée "serrure rotative" face caméra (plan X-Y, axe de rotation Z = profondeur).
# Disque PLEIN (pavé de boîtes radiales) SAUF un secteur ouvert ~100° = le passage. Tourne
# lentement → le joueur STEER son X pour viser l'ouverture qui orbite. Franchissable via le
# contrôle latéral (le seul levier du joueur, il ne maîtrise pas sa vitesse) → fair même à
# haute vitesse. Rotation TEMPORELLE pure (indépendante de dir) → identique chute ET jetpack.
#
# Géométrie : 18 secteurs de 20°, chaque boîte fait toute la largeur tangentielle d'un secteur
# au rayon RADIUS et se CHEVAUCHE vers le centre → disque plein sans trou parasite entre boîtes.
# On omet GAP_SECTORS secteurs consécutifs = l'unique ouverture franchissable.

const RADIUS: float = 4.3            # atteint les bords du couloir (half = 4.5) → gate pleine largeur
const SECTORS: int = 18              # secteurs de 20°
const GAP_SECTORS: int = 5           # 5 omis = ouverture ~100° (passage >=3 au rayon moyen)
const BOX_DEPTH: float = 0.7         # épaisseur en Z (face caméra)
const ROT_SPEED: float = 0.5         # rad/s (~12,5 s/tour) : lent → l'ouverture se lit et se vise

func _ready() -> void:
	super._ready()
	var mat := _make_material()
	# Largeur tangentielle : à RADIUS, une boîte couvre tout son secteur (2*R*sin(10°)) et
	# déborde vers le centre sur les voisines → plein. Calculé une fois.
	var box_w: float = 2.0 * RADIUS * sin(PI / float(SECTORS))
	for i in SECTORS:
		if i < GAP_SECTORS:
			continue                 # secteurs omis = l'ouverture (orbite avec la rotation)
		var angle: float = float(i) / float(SECTORS) * TAU
		# Boîte radiale : longueur RADIUS le long de X local, centrée à mi-rayon, tournée de angle.
		var xform := Transform3D(Basis(Vector3(0, 0, 1), angle),
			Vector3(cos(angle) * RADIUS * 0.5, sin(angle) * RADIUS * 0.5, 0.0))
		var size := Vector3(RADIUS, box_w, BOX_DEPTH)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		bm.material = mat
		mi.mesh = bm
		mi.transform = xform
		add_child(mi)
		# La CollisionShape3D DOIT être enfant DIRECT du StaticBody (sinon ignorée) → add_child(self).
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.transform = xform
		add_child(cs)

func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL   # éclairé comme les autres obstacles
	mat.albedo_color = Color(0.239, 0.173, 0.118)              # marron noyer #3D2C1E
	mat.emission_enabled = true
	mat.emission = Color(0.239, 0.173, 0.118)
	mat.emission_energy_multiplier = 0.3
	return mat

func _physics_process(delta: float) -> void:
	# Rotation du corps autour de Z : la roue tourne dans son plan, l'ouverture orbite. La
	# position globale ne bouge pas (rotation autour de l'origine) → despawn dir-relatif intact.
	rotation.z += ROT_SPEED * delta
