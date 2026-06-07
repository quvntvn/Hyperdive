extends Node3D
class_name CorridorWalls

@export var target: Node3D
@export var target_path: NodePath
## Bouclage vertical du motif (menu). 0 = désactivé (jeu, défilement infini).
## > 0 = nombre de cellules avant répétition ; doit correspondre à MenuCamera.LOOP_CELLS.
@export var loop_cells: float = 0.0

var _wall_material: ShaderMaterial
var _is_menu: bool = false

# --- CYCLE JOUR/NUIT CONTINU (piloté par la DISTANCE, pas le temps) ---------------
# Un cycle complet jour→crépuscule→nuit→aube→jour tous les CYCLE_DISTANCE mètres.
# Nuit (phase 0.5) atteinte à 1250m → jalon « aller loin ».
# Le cycle MODULE le thème équipé, il ne le remplace pas :
#   - luminosité MULTIPLICATIVE (garde la teinte → le thème reste reconnaissable)
#   - teinte d'heure du jour en LERP léger (force 0 le jour → thème pur de jour).
# Tout = lerp de couleurs/uniforms (quasi gratuit), réécriture gatée par delta de phase.
const CYCLE_DISTANCE: float = 3750.0   # cycle 1,5× plus lent (était 2500) → on profite mieux de chaque ambiance

# Keyframes aux phases 0.00=jour, 0.25=crépuscule, 0.50=nuit, 0.75=aube (boucle).
var _k_bright: Array[float] = [1.00, 0.72, 0.40, 0.74]   # luminosité (plancher 0.40 = lisible)
var _k_light: Array[float]  = [1.00, 0.80, 0.58, 0.80]   # énergie lumières (jamais 0)
var _k_star: Array[float]   = [0.00, 0.15, 1.00, 0.15]   # opacité du champ d'étoiles
var _k_tstr: Array[float]   = [0.00, 0.30, 0.35, 0.25]   # force de la teinte d'heure
var _k_tint: Array[Color] = [
	Color(0.96, 0.94, 0.88),   # jour : crème (force 0 → inutilisé)
	Color(0.93, 0.42, 0.22),   # crépuscule : orange brûlé
	Color(0.07, 0.10, 0.26),   # nuit : bleu nuit profond
	Color(0.95, 0.62, 0.62),   # aube : rosé
]

# Bases cachées du thème (jamais relues depuis les matériaux → pas de corruption).
var _base_wall: Color = Color.WHITE
var _base_sky_top: Color = Color.WHITE
var _base_sky_horizon: Color = Color.WHITE
var _base_ground_bottom: Color = Color.WHITE
var _base_ground_horizon: Color = Color.WHITE
var _base_facade: Color = Color.WHITE
var _base_fog: Color = Color.WHITE
var _base_ambient: float = 0.3
var _base_dir_energy: float = 1.5

var _world_env: WorldEnvironment
var _sky_mat: ProceduralSkyMaterial
var _skyline_mat: ShaderMaterial
var _dir_light: DirectionalLight3D
var _star_mat: StandardMaterial3D   # matériau des étoiles ; on module son alpha selon le cycle
var _lights_cached: bool = false
var _last_phase: float = -1.0   # force la 1re application

func _ready() -> void:
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path)
	_is_menu = loop_cells > 0.0
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
	# Champ d'étoiles : seulement EN JEU (pas au menu). Visible la nuit (alpha = cycle).
	if not _is_menu:
		_create_star_field()

func _process(_delta: float) -> void:
	if target == null:
		return
	global_position.y = target.global_position.y
	if _is_menu:
		return
	# Phase du cycle pilotée par la distance/altitude parcourue.
	var phase: float = fposmod(absf(target.global_position.y) / CYCLE_DISTANCE, 1.0)
	# Gate : ne réécrit le ciel/le décor que si la phase a bougé sensiblement
	# (évite de redéclencher la radiance du ciel à chaque frame). ~5-10 maj/s suffisent.
	if absf(phase - _last_phase) < 0.0015:
		return
	_last_phase = phase
	_apply_cycle(phase, true)

func _create_ambient_fx() -> void:
	# Motes de poussière du couloir RETIRÉES (elles flottaient autour du joueur et
	# parasitaient le ciel). Étoiles du ciel (cycle jour/nuit) + nuages jetpack conservés.
	_create_soft_clouds()

# Nuages : UNIQUEMENT en mode jetpack (plus de nuages en chute campagne/infini ni au
# menu). Placés en FOND latéral GAUCHE, derrière le mur gauche (x très négatif, reculés
# en z) → ils lisent comme des nuages lointains à gauche, pas au milieu de la piste.
func _create_soft_clouds() -> void:
	if _is_menu or Settings.active_mode != "jetpack":
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


# Met en CACHE les couleurs base du thème, puis applique une fois (phase neutre = jour
# pur). Le cycle (en jeu) re-module ces bases chaque frame. Au menu, cet appel suffit
# (pas de cycle → look statique du thème).
func _apply_theme() -> void:
	var theme: Dictionary = Catalog.get_theme(Settings.equipped_theme)
	# Décor en retrait : on assombrit la couleur des murs (×0.8) pour creuser le
	# contraste avec les éléments de gameplay, sans la rendre laide.
	_base_wall = (theme["wall_color"] as Color) * 0.8
	_base_wall.a = 1.0
	# line_color N'EST PAS modulée par le cycle (lisibilité du couloir, même de nuit).
	_wall_material.set_shader_parameter("line_color", theme["line_color"])

	_world_env = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_env != null and _world_env.environment != null and _world_env.environment.sky != null:
		_sky_mat = _world_env.environment.sky.sky_material as ProceduralSkyMaterial
	if _sky_mat != null:
		var top: Color = theme["sky_top"]
		# Jetpack : caméra inclinée vers le HAUT → on éclaircit le sommet du dôme vers la
		# teinte d'horizon (claire) pour que le ciel couvre tout le haut de l'écran.
		if Settings.active_mode == "jetpack" and target != null:
			top = (theme["sky_top"] as Color).lerp(theme["sky_horizon"], 0.6)
		_base_sky_top = top
		_base_sky_horizon = theme["sky_horizon"]
		# ground_bottom = couleur visible dans l'ouverture du couloir quand on regarde
		# vers le bas (PAS le wall_color du shader).
		_base_ground_bottom = theme["wall_color"]
		_base_ground_horizon = theme["sky_horizon"]

	# Énergies de base des lumières (cachées une seule fois).
	if not _lights_cached:
		_lights_cached = true
		_dir_light = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if _dir_light != null:
			_base_dir_energy = _dir_light.light_energy
		if _world_env != null and _world_env.environment != null:
			_base_ambient = _world_env.environment.ambient_light_energy

	# Application immédiate (phase neutre = jour pur). Skyline résolue plus tard, en jeu.
	_last_phase = -1.0
	_apply_cycle(0.0, false)
	print("[Thème] Équipé='", Settings.equipped_theme, "' base wall=", _base_wall)

# Applique l'état du cycle pour une phase donnée. do_skyline=false pendant _apply_theme
# (la skyline n'existe pas encore au _ready, créée par main_game après).
func _apply_cycle(phase: float, do_skyline: bool) -> void:
	var bright: float = _sample_f(_k_bright, phase)
	var light: float = _sample_f(_k_light, phase)
	var tint: Color = _sample_c(_k_tint, phase)
	var tstr: float = _sample_f(_k_tstr, phase)
	var star: float = _sample_f(_k_star, phase)

	# Murs (la teinte du couloir vit avec l'heure ; les lignes restent nettes).
	if _wall_material != null:
		_wall_material.set_shader_parameter("wall_color", _modulate(_base_wall, bright, tint, tstr))

	# Ciel (les 4 couleurs du ProceduralSky).
	if _sky_mat != null:
		_sky_mat.sky_top_color = _modulate(_base_sky_top, bright, tint, tstr)
		_sky_mat.sky_horizon_color = _modulate(_base_sky_horizon, bright, tint, tstr)
		_sky_mat.ground_bottom_color = _modulate(_base_ground_bottom, bright, tint, tstr)
		_sky_mat.ground_horizon_color = _modulate(_base_ground_horizon, bright, tint, tstr)

	# Skyline (fenêtres jaunes émissives → ressortent davantage la nuit, gratuit).
	if do_skyline:
		_resolve_skyline()
		if _skyline_mat != null:
			_skyline_mat.set_shader_parameter("facade_color", _modulate(_base_facade, bright, tint, tstr))
			_skyline_mat.set_shader_parameter("fog_color", _modulate(_base_fog, bright, tint, tstr))

	# Lumières : baissées la nuit (plancher) → ambiance, MAIS obstacles/pièces émissifs
	# restent éclatants. Le perso garde assez de lumière directionnelle pour rester visible.
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.ambient_light_energy = _base_ambient * light
	if _dir_light != null:
		_dir_light.light_energy = _base_dir_energy * light

	# Étoiles (alpha additif → apparaissent la nuit, invisibles le jour).
	if _star_mat != null:
		_star_mat.albedo_color.a = star

# couleur base × luminosité (garde la teinte) puis lerp léger vers la teinte d'heure.
# Alpha forcé à 1 (Color*float multiplie aussi l'alpha → sinon ciel/murs translucides).
func _modulate(base: Color, bright: float, tint: Color, tstr: float) -> Color:
	var c := Color(base.r * bright, base.g * bright, base.b * bright)
	c = c.lerp(Color(tint.r, tint.g, tint.b), tstr)
	c.a = 1.0
	return c

# Échantillonne des keyframes (4 points aux phases 0/.25/.5/.75) en boucle, lerp continu.
func _sample_f(keys: Array[float], phase: float) -> float:
	var seg: float = phase * 4.0
	var i: int = int(floor(seg)) % 4
	var f: float = seg - floor(seg)
	return lerpf(keys[i], keys[(i + 1) % 4], f)

func _sample_c(keys: Array[Color], phase: float) -> Color:
	var seg: float = phase * 4.0
	var i: int = int(floor(seg)) % 4
	var f: float = seg - floor(seg)
	return keys[i].lerp(keys[(i + 1) % 4], f)

# Résout (une fois) le matériau partagé de la skyline pour le moduler. La skyline est
# créée par main_game APRÈS le _ready du couloir → résolution paresseuse en _process.
# Base cachée à la 1re résolution et JAMAIS relue (sinon on relirait notre propre valeur
# modulée = corruption). En jetpack/menu il n'y a pas de skyline → reste null.
func _resolve_skyline() -> void:
	if _skyline_mat != null:
		return
	var cam := get_parent().get_node_or_null("Camera3D")
	if cam == null:
		return
	var skyline := cam.get_node_or_null("CitySkyline")
	if skyline == null:
		return
	for c in skyline.get_children():
		if c is MeshInstance3D:
			var m := (c as MeshInstance3D).material_override
			if m is ShaderMaterial:
				_skyline_mat = m as ShaderMaterial
				_base_facade = _skyline_mat.get_shader_parameter("facade_color")
				_base_fog = _skyline_mat.get_shader_parameter("fog_color")
			return

# Champ d'ÉTOILES FIXES : GPUParticles3D ancrées à la caméra, réparties sur une sphère
# lointaine (rayon 90), VÉLOCITÉ ZÉRO (elles ne dérivent pas → vraies étoiles immobiles),
# très petites. Émises toutes d'un coup (explosiveness 1) avec une durée de vie quasi
# infinie → permanentes. Leur opacité (alpha du matériau) est pilotée par le cycle :
# 0 le jour (ciel propre) → monte la nuit. Additif → léger glow d'étoile.
func _create_star_field() -> void:
	var cam := get_parent().get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var p := GPUParticles3D.new()
	p.name = "StarField"
	p.amount = 170
	p.lifetime = 1000.0          # quasi infini → étoiles permanentes
	p.one_shot = false
	p.explosiveness = 1.0        # toutes émises d'un coup au départ (puis statiques)
	p.randomness = 0.0
	p.local_coords = true        # fixes par rapport à la caméra (aucune dérive monde)
	p.fixed_fps = 2              # statiques → pas besoin de simuler souvent
	p.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	p.emitting = true

	var mat := ParticleProcessMaterial.new()
	# Réparties sur la SURFACE d'une sphère lointaine → distance uniforme = petites étoiles nettes.
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	mat.emission_sphere_radius = 90.0
	mat.direction = Vector3.ZERO
	mat.initial_velocity_min = 0.0   # ÉTOILES FIXES : aucune vélocité
	mat.initial_velocity_max = 0.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.30
	mat.scale_max = 0.70
	p.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 6
	sphere.rings = 3
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD   # léger glow d'étoile
	# alpha 0 = invisible le jour ; le cycle remonte l'alpha la nuit.
	_star_mat.albedo_color = Color(1.0, 0.97, 0.9, 0.0)
	sphere.surface_set_material(0, _star_mat)
	p.draw_pass_1 = sphere
	cam.add_child(p)
	p.position = Vector3.ZERO
