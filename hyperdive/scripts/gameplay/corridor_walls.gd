extends Node3D
class_name CorridorWalls

@export var target: Node3D
@export var target_path: NodePath

var _wall_material: ShaderMaterial
var _debug_skyline_logged: bool = false

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
	if not _debug_skyline_logged:
		_debug_skyline_logged = true
		_log_skyline_debug()

func _log_skyline_debug() -> void:
	print("[Skyline DEBUG] CorridorWalls global_position=", global_position)
	var cam := get_viewport().get_camera_3d()
	if cam:
		print("[Skyline DEBUG] Camera global_position=", cam.global_position, "  far=", cam.far, "  fov=", cam.fov)
	else:
		print("[Skyline DEBUG] Aucune Camera3D active trouvée dans le viewport")
	var count := 0
	for child in get_children():
		if child is MeshInstance3D:
			print("[Skyline DEBUG] Bâtiment[", count, "] global=", child.global_position,
				  "  size=", (child as MeshInstance3D).mesh.size if (child as MeshInstance3D).mesh is BoxMesh else "?")
			count += 1
			if count >= 3:
				break

func _create_ambient_fx() -> void:
	_create_dust_motes()
	_create_soft_clouds()
	_create_city_skyline()

func _create_dust_motes() -> void:
	var p := GPUParticles3D.new()
	p.amount = 150
	p.lifetime = 10.0
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 1.0
	# local_coords = true : motes simulent en espace local des murs (qui suivent le joueur).
	# Leur dérive locale lente vers le haut compense la descente du parent →
	# en espace monde les motes semblent flotter sur place pendant la chute.
	p.local_coords = true
	p.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(3.5, 10.0, 2.5)
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.04
	mat.initial_velocity_max = 0.16
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.15
	mat.scale_max = 0.40
	mat.color = Color(0.957, 0.914, 0.804, 0.28)
	p.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.10
	sphere.height = 0.20
	var smat := StandardMaterial3D.new()  # ASCII uniquement — pas de caractères cyrilliques
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.vertex_color_use_as_albedo = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.surface_set_material(0, smat)
	p.draw_pass_1 = sphere
	add_child(p)

func _create_soft_clouds() -> void:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 14.0
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 1.0
	p.local_coords = true
	p.emitting = true
	p.position = Vector3(0.0, 4.0, 0.0)  # légèrement au-dessus du joueur, dans le champ

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(3.5, 2.0, 2.0)
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = 20.0
	mat.initial_velocity_min = 0.20
	mat.initial_velocity_max = 0.50
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.60
	mat.scale_max = 1.20
	mat.color = Color(0.910, 0.875, 0.805, 0.15)
	p.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.60
	sphere.height = 1.20
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.vertex_color_use_as_albedo = true
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.surface_set_material(0, cmat)
	p.draw_pass_1 = sphere
	add_child(p)

func _create_city_skyline() -> void:
	# DEBUG : Y_BASE réduit de -48 → -20, taille ×3, couleur magenta émissive.
	# Objectif : confirmer que les bâtiments se rendent bien avant de les rendre discrets.
	# La caméra (Z=12, inclinée -35°) atteint Z=0 vers player.y-42 → à -48 les bâtiments
	# étaient juste hors frustum. À -20 ils sont dans le bas du champ visible.
	const Y_BASE: float = -20.0
	var buildings: Array = [
		[-11.5, 9.0,  54.0],
		[ -9.0, 10.5, 84.0],
		[ -6.5, 7.5,  42.0],
		[ -4.2, 12.0, 72.0],
		[ -1.5, 8.4,  96.0],
		[  1.0, 7.5,  60.0],
		[  3.5, 12.6, 78.0],
		[  6.0, 7.5,  48.0],
		[  8.5, 10.5, 66.0],
		[ 11.0, 9.0,  60.0],
	]
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1.0, 0.0, 1.0)  # DEBUG: magenta vif
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.0, 1.0)
	bmat.emission_energy_multiplier = 5.0
	for b in buildings:
		var bx: float = b[0]
		var bw: float = b[1]
		var bh: float = b[2]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(bw, bh, 2.0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = bmat
		mi.position = Vector3(bx, Y_BASE - bh * 0.5, 0.0)
		add_child(mi)
	print("[Skyline DEBUG] Y_BASE=", Y_BASE, " (local). Bâtiments magenta créés.")

func _apply_theme() -> void:
	var theme: Dictionary = Catalog.get_theme(Settings.equipped_theme)
	_wall_material.set_shader_parameter("wall_color", theme["wall_color"])
	_wall_material.set_shader_parameter("line_color", theme["line_color"])
	print("[Thème] Équipé='", Settings.equipped_theme,
		  "'  wall_color=", theme["wall_color"],
		  "  → shader lu=", _wall_material.get_shader_parameter("wall_color"))
	var world_env: WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		push_warning("[Thème] WorldEnvironment introuvable depuis parent '", get_parent().name, "'")
		return
	var sky_mat: ProceduralSkyMaterial = world_env.environment.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		push_warning("[Thème] ProceduralSkyMaterial introuvable")
		return
	sky_mat.sky_top_color = theme["sky_top"]
	sky_mat.sky_horizon_color = theme["sky_horizon"]
	# FIX : ground_bottom_color était hardcodé en marron (Color(0.239, 0.173, 0.118)) dans la
	# scène et jamais touché par le thème. C'est cette couleur qui est visible dans l'ouverture
	# du couloir quand on regarde vers le bas — pas le wall_color du shader.
	sky_mat.ground_bottom_color = theme["wall_color"]
	sky_mat.ground_horizon_color = theme["sky_horizon"]
	print("[Thème] Ciel : top=", theme["sky_top"],
		  "  horizon=", theme["sky_horizon"],
		  "  ground_bottom=", theme["wall_color"])
