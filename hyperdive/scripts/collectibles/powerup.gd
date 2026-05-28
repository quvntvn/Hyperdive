extends Area3D
class_name Powerup

const ROTATION_SPEED: float = 2.0
const EMISSION_BASE: float = 1.8
const EMISSION_PULSE: float = 0.25
const PULSE_SPEED: float = 2.2
const COLORS: Dictionary = {
	"shield": Color(0.235, 0.682, 0.639, 1.0),
	"slowmo": Color(0.122, 0.188, 0.369, 1.0),
	"magnet": Color(0.949, 0.757, 0.306, 1.0),
	"boost": Color(0.914, 0.310, 0.216, 1.0),
}

@export var type: String = "shield"

var _pulse_time: float = 0.0
var _body_meshes: Array[MeshInstance3D] = []
var _halo_mi: MeshInstance3D

func _ready() -> void:
	add_to_group("powerups")
	body_entered.connect(_on_body_entered)
	_build_mesh()
	_add_halo()

func _make_mat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = EMISSION_BASE
	return mat

# Contour blanc lumineux : même mesh agrandi rendu faces arrière uniquement (outline classique)
func _make_rim_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.4)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	return mat

func _add_mi(mesh: Mesh, offset: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_mat(COLORS.get(type, Color.WHITE))
	mi.position = offset
	mi.rotation_degrees = rot_deg
	add_child(mi)
	_body_meshes.append(mi)
	# Halo blanc : copie légèrement agrandie rendue dos-à-caméra → liseré lumineux blanc
	var rim := MeshInstance3D.new()
	rim.mesh = mesh
	rim.scale = Vector3.ONE * 1.10
	rim.material_override = _make_rim_mat()
	rim.position = offset
	rim.rotation_degrees = rot_deg
	add_child(rim)

func _build_mesh() -> void:
	match type:
		"shield":
			var m := CylinderMesh.new()
			m.top_radius = 0.28
			m.bottom_radius = 0.28
			m.height = 0.14
			m.radial_segments = 6
			_add_mi(m)
		"slowmo":
			var top_cone := CylinderMesh.new()
			top_cone.top_radius = 0.25
			top_cone.bottom_radius = 0.0
			top_cone.height = 0.28
			_add_mi(top_cone, Vector3(0.0, 0.14, 0.0))
			var bot_cone := CylinderMesh.new()
			bot_cone.top_radius = 0.0
			bot_cone.bottom_radius = 0.25
			bot_cone.height = 0.28
			_add_mi(bot_cone, Vector3(0.0, -0.14, 0.0))
		"magnet":
			var arm := CylinderMesh.new()
			arm.top_radius = 0.065
			arm.bottom_radius = 0.065
			arm.height = 0.30
			_add_mi(arm, Vector3(-0.15, 0.0, 0.0))
			_add_mi(arm, Vector3(0.15, 0.0, 0.0))
			var bar := CylinderMesh.new()
			bar.top_radius = 0.065
			bar.bottom_radius = 0.065
			bar.height = 0.30
			_add_mi(bar, Vector3(0.0, 0.15, 0.0), Vector3(0.0, 0.0, 90.0))
		"boost":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.26
			cone.bottom_radius = 0.0
			cone.height = 0.38
			_add_mi(cone)
			var tail := CylinderMesh.new()
			tail.top_radius = 0.10
			tail.bottom_radius = 0.10
			tail.height = 0.07
			_add_mi(tail, Vector3(0.0, 0.225, 0.0))

func _add_halo() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.52
	torus.rings = 16
	torus.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	var c: Color = COLORS.get(type, Color.WHITE)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(c.r, c.g, c.b, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 3.5
	mi.material_override = mat
	add_child(mi)
	_halo_mi = mi

func _process(delta: float) -> void:
	rotation.y += ROTATION_SPEED * delta
	_pulse_time += delta
	var pulse: float = EMISSION_PULSE * sin(_pulse_time * PULSE_SPEED)
	for mi: MeshInstance3D in _body_meshes:
		var mat := mi.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = EMISSION_BASE + pulse
	if _halo_mi != null:
		var hmat := _halo_mi.material_override as StandardMaterial3D
		if hmat != null:
			hmat.emission_energy_multiplier = 3.5 + pulse * 2.0

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		(body as PlayerController).collect_powerup(type)
		_spawn_burst()
		queue_free()

func _spawn_burst() -> void:
	var burst := GPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 16
	burst.lifetime = 0.5
	burst.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 80.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0.0, -3.0, 0.0)
	mat.scale_min = 0.12
	mat.scale_max = 0.25
	mat.color = COLORS.get(type, Color.WHITE)
	burst.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	burst.draw_pass_1 = sphere

	var scene_root := get_tree().current_scene
	scene_root.add_child(burst)
	burst.global_position = global_position
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)
