extends Node3D
class_name DecorElement

@export var type: String = "starburst"
@export var color: Color = Color(0.914, 0.310, 0.216)

func _ready() -> void:
	add_to_group("decor")
	match type:
		"starburst": _build_starburst()
		"boomerang":  _build_boomerang()
		"sputnik":    _build_sputnik()
		"flat":       _build_flat()

func _make_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.25
	return mat

func _add_mesh(mesh: Mesh, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_mat()
	mi.position = pos
	mi.rotation = rot
	add_child(mi)

# Starburst : rayons fins en étoile dans le plan XY
func _build_starburst() -> void:
	var n: int = randi_range(6, 10)
	var ray_len: float = randf_range(0.30, 0.65)
	var thick: float = randf_range(0.04, 0.07)
	for i in n:
		var a: float = (float(i) / float(n)) * TAU
		var box := BoxMesh.new()
		box.size = Vector3(thick, ray_len, thick)
		_add_mesh(box,
			Vector3(sin(a) * ray_len * 0.5, cos(a) * ray_len * 0.5, 0.0),
			Vector3(0.0, 0.0, -a))
	var dot := SphereMesh.new()
	dot.radius = thick * 1.6
	dot.height = thick * 3.2
	_add_mesh(dot)

# Boomerang : deux bras en V (chevron Atomic Age)
func _build_boomerang() -> void:
	var arm_len: float = randf_range(0.45, 0.9)
	var thick: float = randf_range(0.06, 0.11)
	var opening: float = deg_to_rad(randf_range(25.0, 55.0))
	for side in [-1.0, 1.0]:
		var a: float = side * opening
		var box := BoxMesh.new()
		box.size = Vector3(thick, arm_len, thick)
		_add_mesh(box,
			Vector3(sin(a) * arm_len * 0.5, cos(a) * arm_len * 0.5, 0.0),
			Vector3(0.0, 0.0, -a))

# Sputnik : sphère centrale + tiges rayonnantes
func _build_sputnik() -> void:
	var sph_r: float = randf_range(0.10, 0.18)
	var sphere := SphereMesh.new()
	sphere.radius = sph_r
	sphere.height = sph_r * 2.0
	_add_mesh(sphere)
	var rod_count: int = randi_range(4, 6)
	var rod_len: float = randf_range(0.30, 0.60)
	var rod_r: float = randf_range(0.018, 0.032)
	for i in rod_count:
		var a: float = (float(i) / float(rod_count)) * TAU
		var cyl := CylinderMesh.new()
		cyl.height = rod_len
		cyl.top_radius = rod_r
		cyl.bottom_radius = rod_r
		cyl.radial_segments = 5
		_add_mesh(cyl,
			Vector3(sin(a) * (sph_r + rod_len * 0.5), cos(a) * (sph_r + rod_len * 0.5), 0.0),
			Vector3(0.0, 0.0, -a))

# Forme plate : disque, losange ou hexagone dans le plan XY (face caméra)
func _build_flat() -> void:
	var size: float = randf_range(0.22, 0.55)
	var kind: int = randi() % 3
	match kind:
		0:  # disque
			var cyl := CylinderMesh.new()
			cyl.height = 0.05
			cyl.top_radius = size
			cyl.bottom_radius = size
			cyl.radial_segments = 18
			_add_mesh(cyl, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
		1:  # losange (carré tourné 45°)
			var box := BoxMesh.new()
			box.size = Vector3(size * 1.3, size * 1.3, 0.05)
			_add_mesh(box, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.25))
		2:  # hexagone
			var cyl := CylinderMesh.new()
			cyl.height = 0.05
			cyl.top_radius = size
			cyl.bottom_radius = size
			cyl.radial_segments = 6
			_add_mesh(cyl, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
