extends Node3D
class_name CorridorWalls

@export var target: Node3D
@export var target_path: NodePath

var _wall_material: ShaderMaterial

func _ready() -> void:
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path)
	var left_mesh := $LeftWall/MeshInstance3D as MeshInstance3D
	var right_mesh := $RightWall/MeshInstance3D as MeshInstance3D
	_wall_material = (left_mesh.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	left_mesh.material_override = _wall_material
	right_mesh.material_override = _wall_material
	_apply_theme()
	Settings.equipped_theme_changed.connect(func(_id: String) -> void: _apply_theme())
	_create_ambient_fx()

func _process(_delta: float) -> void:
	if target == null:
		return
	global_position.y = target.global_position.y

func _create_ambient_fx() -> void:
	_create_dust_motes()
	_create_soft_clouds()

func _create_dust_motes() -> void:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 9.0
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 1.0
	# local_coords = true : les motes suivent les murs (qui suivent le joueur).
	# Leur vélocité locale lente vers le haut compense la descente du parent →
	# en espace monde les motes semblent flotter sur place pendant la chute.
	p.local_coords = true
	p.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(4.0, 12.0, 3.0)
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.04
	mat.initial_velocity_max = 0.14
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.03
	mat.scale_max = 0.08
	mat.color = Color(0.957, 0.914, 0.804, 0.12)
	p.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	var smат := StandardMaterial3D.new()
	smат.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smат.vertex_color_use_as_albedo = true
	smат.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.surface_set_material(0, smат)
	p.draw_pass_1 = sphere
	add_child(p)

func _create_soft_clouds() -> void:
	var p := GPUParticles3D.new()
	p.amount = 6
	p.lifetime = 18.0
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 1.0
	p.local_coords = true
	p.emitting = true
	p.position = Vector3(0.0, 8.0, -1.0)  # au-dessus de la zone de jeu

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(3.5, 1.5, 1.5)
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = 15.0
	mat.initial_velocity_min = 0.20
	mat.initial_velocity_max = 0.50
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.45
	mat.scale_max = 0.95
	mat.color = Color(0.890, 0.855, 0.785, 0.06)
	p.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.vertex_color_use_as_albedo = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.surface_set_material(0, smat)
	p.draw_pass_1 = sphere
	add_child(p)

func _apply_theme() -> void:
	var theme: Dictionary = Catalog.get_theme(Settings.equipped_theme)
	_wall_material.set_shader_parameter("wall_color", theme["wall_color"])
	_wall_material.set_shader_parameter("line_color", theme["line_color"])
	var world_env: WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		return
	var sky_mat: ProceduralSkyMaterial = world_env.environment.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		return
	sky_mat.sky_top_color = theme["sky_top"]
	sky_mat.sky_horizon_color = theme["sky_horizon"]
