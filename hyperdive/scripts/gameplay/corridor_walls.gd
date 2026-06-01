extends Node3D
class_name CorridorWalls

@export var target: Node3D
@export var target_path: NodePath
## Bouclage vertical du motif (menu). 0 = désactivé (jeu, défilement infini).
## > 0 = nombre de cellules avant répétition ; doit correspondre à MenuCamera.LOOP_CELLS.
@export var loop_cells: float = 0.0

var _wall_material: ShaderMaterial

func _ready() -> void:
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path)
	var left_mesh := $LeftWall/MeshInstance3D as MeshInstance3D
	var right_mesh := $RightWall/MeshInstance3D as MeshInstance3D
	_wall_material = (left_mesh.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	left_mesh.material_override = _wall_material
	right_mesh.material_override = _wall_material
	_wall_material.set_shader_parameter("loop_cells", loop_cells)
	# Décor en retrait : fenêtres moins prononcées pour ne pas attirer l'œil
	# (win_mix défaut 0.68 → 0.50, ≈26% de moins). Le gameplay doit primer.
	_wall_material.set_shader_parameter("win_mix", 0.50)
	_apply_theme()
	Settings.equipped_theme_changed.connect(func(_id: String) -> void: _apply_theme())
	_create_ambient_fx()

func _process(_delta: float) -> void:
	if target == null:
		return
	global_position.y = target.global_position.y

func _create_ambient_fx() -> void:
	# loop_cells > 0 = instance du MENU (piste qui boucle). En jeu loop_cells == 0.
	var is_menu: bool = loop_cells > 0.0
	# Motes flottantes : seulement EN JEU. Au menu la piste reste propre.
	if not is_menu:
		_create_dust_motes()
	_create_soft_clouds()

func _create_dust_motes() -> void:
	var p := GPUParticles3D.new()
	p.amount = 75
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

# Nuages : UNIQUEMENT en mode jetpack (plus de nuages en chute campagne/infini ni au
# menu). Placés en FOND latéral GAUCHE, derrière le mur gauche (x très négatif, reculés
# en z) → ils lisent comme des nuages lointains à gauche, pas au milieu de la piste.
func _create_soft_clouds() -> void:
	var is_menu: bool = loop_cells > 0.0
	if is_menu or Settings.active_mode != "jetpack":
		return

	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 14.0
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 1.0
	p.local_coords = true
	p.emitting = true
	# Tout à gauche, au-delà du mur gauche (couloir = ±4.5), reculé en profondeur.
	p.position = Vector3(-10.0, 6.0, -5.0)

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(2.0, 9.0, 2.5)
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = 20.0
	mat.initial_velocity_min = 0.10
	mat.initial_velocity_max = 0.30
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.60
	mat.scale_max = 1.20
	# Opacité /2 (0.075 -> 0.0375) : nuages lointains discrets.
	mat.color = Color(0.910, 0.875, 0.805, 0.0375)
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


func _apply_theme() -> void:
	var theme: Dictionary = Catalog.get_theme(Settings.equipped_theme)
	# Décor en retrait : on assombrit la couleur des murs (×0.8) pour creuser le
	# contraste avec les éléments de gameplay, sans la rendre laide.
	var base_wall: Color = theme["wall_color"]
	var dimmed_wall: Color = base_wall * 0.8
	_wall_material.set_shader_parameter("wall_color", dimmed_wall)
	_wall_material.set_shader_parameter("line_color", theme["line_color"])
	print("[Thème] Équipé='", Settings.equipped_theme,
		  "'  wall_color base=", base_wall, " → assombrie ×0.8=", dimmed_wall,
		  "  shader lu=", _wall_material.get_shader_parameter("wall_color"))
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
	# Jetpack : caméra inclinée vers le HAUT → on éclaircit le sommet du dôme vers la
	# teinte d'horizon (claire) pour que le ciel couvre tout le haut de l'écran.
	# DEBUG Étape 1, à doser. Gardé hors menu via target != null.
	if Settings.active_mode == "jetpack" and target != null:
		sky_mat.sky_top_color = (theme["sky_top"] as Color).lerp(theme["sky_horizon"], 0.6)
	print("[Thème] Ciel : top=", theme["sky_top"],
		  "  horizon=", theme["sky_horizon"],
		  "  ground_bottom=", theme["wall_color"])
