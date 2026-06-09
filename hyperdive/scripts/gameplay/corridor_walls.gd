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
# Le cycle ne touche QUE le CIEL/FOND (ProceduralSky + skyline lointaine + étoiles) :
#   - luminosité MULTIPLICATIVE sur le ciel (garde la teinte du thème)
#   - teinte d'heure du jour en LERP léger (force 0 le jour → thème pur de jour).
# Il NE touche PAS les murs latéraux, ni l'éclairage global (ambient/directionnelle) → le
# perso, les pièces, power-ups et obstacles gardent leur rendu normal, lisibles à toute heure.
# Tout = lerp de couleurs/uniforms (quasi gratuit), réécriture gatée par delta de phase.
const CYCLE_DISTANCE: float = 3750.0   # cycle 1,5× plus lent (était 2500) → on profite mieux de chaque ambiance

# Keyframes aux phases 0.00=jour, 0.25=crépuscule, 0.50=nuit, 0.75=aube (boucle).
var _k_bright: Array[float] = [1.00, 0.72, 0.40, 0.74]   # luminosité du CIEL (plancher 0.40 = lisible)
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
var _base_line: Color = Color.WHITE   # couleur de ligne du thème (cachée → blendée par les zones)
var _lights_cached: bool = false
var _last_phase: float = -1.0   # force la 1re application

# --- ZONES VISUELLES RARES (ambiances ponctuelles : néon / nuages / cosmique) ------
# Une zone visuelle est PROGRAMMÉE en avance (lookahead = SPAWN_AHEAD des spawners) puis son
# blend est animé par la POSITION du joueur quand il traverse la bande → l'ambiance, la
# raréfaction d'obstacles (nuages) et le bonus pièces (cosmique) coïncident exactement.
# L'ambiance OVERRIDE temporairement la sortie du cycle jour/nuit (lerp par _zone_blend),
# puis on re-lerp vers le cycle à la sortie → retour propre, sans saut, peu importe l'heure.
const VISUAL_LOOKAHEAD: float = 60.0   # = ObstacleSpawner.SPAWN_AHEAD (réaction spawners à temps)
const VISUAL_CHECK_STEP: float = 14.4  # un tirage tous les ~14 m de depth (comme les obstacles)
const VISUAL_CHANCE: float = 0.05      # ~5 % par intervalle → rare
const VISUAL_COOLDOWN: float = 200.0   # pas deux zones coup sur coup
const VISUAL_MIN_START: float = 150.0  # échauffement avant la 1re zone
const VISUAL_ENTRY: float = 12.0       # lerp d'entrée (douce)
const VISUAL_HOLD: float = 60.0        # plein régime (~3 s à 18 m/s)
const VISUAL_EXIT: float = 12.0        # lerp de sortie (douce)
const VISUAL_LEN: float = VISUAL_ENTRY + VISUAL_HOLD + VISUAL_EXIT
# Zone "clouds" : conservée pour son ambiance d'ÉCLAIRCIE subtile (teinte claire douce) et sa
# raréfaction d'obstacles (un répit, géré par obstacle_spawner via Zones.in_visual_band). Le
# système de nuages visuels (sprites) a été abandonné — la zone n'affiche plus d'objet, juste
# son léger décalage de couleur de fond.
const VISUAL_NAMES: Array[String] = ["neon", "clouds", "cosmic"]

var _dir: float = -1.0
var _zones_enabled: bool = false
var _next_visual_check: float = VISUAL_MIN_START
var _next_visual_depth: float = VISUAL_MIN_START
var _zone_active: bool = false
var _zone_name: String = ""
var _zone_start_depth: float = 0.0
var _zone_blend: float = 0.0
var _zone_dirty: bool = false   # force une dernière application quand la zone se termine
var _pulse_t: float = 0.0       # horloge du clignotement néon

func _ready() -> void:
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path)
	_is_menu = loop_cells > 0.0
	_dir = Settings.get_fall_dir()
	# Zones visuelles : seulement EN JEU hors campagne/coop (niveaux courts/chronométrés/sans
	# pièces → une zone rare casserait le rythme et les twists vitesse/pièces n'ont pas de sens).
	_zones_enabled = not _is_menu and Settings.active_mode != "campaign" and not Coop.active and not Story.active
	# Reset systématique en jeu (autoload persistant) : repart à neutre même si le run précédent
	# s'est terminé en pleine zone (sinon visual_speed_mult resterait ≠ 1 pour le run suivant).
	if not _is_menu:
		Zones.reset()
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
	# Champ d'étoiles : seulement EN JEU (pas au menu). Visible la nuit (alpha = cycle).
	if not _is_menu:
		_create_star_field()

func _process(delta: float) -> void:
	if target == null:
		return
	global_position.y = target.global_position.y
	if _is_menu:
		return
	if _zones_enabled:
		_update_visual_zones(_dir * target.global_position.y, delta)
	# Phase du cycle pilotée par la distance/altitude parcourue.
	var phase: float = fposmod(absf(target.global_position.y) / CYCLE_DISTANCE, 1.0)
	# Pendant une zone (blend > 0) ou à sa toute fin, on applique CHAQUE frame (le blend bouge
	# même si la phase est figée). Sinon on garde l'optimisation par delta de phase.
	if _zone_blend > 0.0 or _zone_dirty:
		_zone_dirty = false
		_last_phase = phase
		_apply_cycle(phase, true)
		return
	# Gate : ne réécrit le ciel/le décor que si la phase a bougé sensiblement
	# (évite de redéclencher la radiance du ciel à chaque frame). ~5-10 maj/s suffisent.
	if absf(phase - _last_phase) < 0.0015:
		return
	_last_phase = phase
	_apply_cycle(phase, true)

# Scheduler + animation du blend des zones visuelles. depth = coord dir-relative du joueur.
func _update_visual_zones(depth: float, delta: float) -> void:
	Zones.prune(depth)
	# 1) PROGRAMMATION (aucune zone en cours) : un tirage par intervalle, cooldown + démarrage
	#    mini respectés, et exclusion vs les bandes d'obstacles. La bande est posée LOOKAHEAD
	#    devant → les spawners (qui remplissent SPAWN_AHEAD devant) réagissent à temps.
	if not _zone_active:
		while depth >= _next_visual_check:
			_next_visual_check += VISUAL_CHECK_STEP
			if depth >= _next_visual_depth and randf() < VISUAL_CHANCE:
				var s: float = depth + VISUAL_LOOKAHEAD
				if not Zones.obstacle_band_intersects(s, s + VISUAL_LEN, VISUAL_CHECK_STEP):
					_zone_active = true
					_zone_name = VISUAL_NAMES.pick_random()
					_zone_start_depth = s
					_pulse_t = 0.0
					Zones.register_visual_band(s, s + VISUAL_LEN)
					Zones.visual_name = _zone_name   # annoncé tôt (lookahead) pour les twists spawn-ahead
					_next_visual_depth = s + VISUAL_COOLDOWN
					break
		return
	# 2) ANIMATION du blend selon la position du joueur dans la bande [start, start+LEN].
	_pulse_t += delta
	var local: float = depth - _zone_start_depth
	var b: float = 0.0
	if local <= 0.0:
		b = 0.0
	elif local < VISUAL_ENTRY:
		b = local / VISUAL_ENTRY
	elif local < VISUAL_ENTRY + VISUAL_HOLD:
		b = 1.0
	elif local < VISUAL_LEN:
		b = 1.0 - (local - VISUAL_ENTRY - VISUAL_HOLD) / VISUAL_EXIT
	else:
		# Zone terminée : on désactive et on force une dernière application (retour au cycle pur).
		_zone_active = false
		_zone_dirty = true
		_zone_name = ""
		Zones.visual_name = ""
	_zone_blend = clampf(b, 0.0, 1.0)
	Zones.visual_blend = _zone_blend
	Zones.visual_speed_mult = lerpf(1.0, _zone_speed_target(_zone_name), _zone_blend)

# Met en CACHE les couleurs base du thème, puis applique une fois (phase neutre = jour
# pur). Le cycle (en jeu) re-module ces bases chaque frame. Au menu, cet appel suffit
# (pas de cycle → look statique du thème).
func _apply_theme() -> void:
	var theme: Dictionary = Catalog.get_theme(Settings.equipped_theme)
	# Décor en retrait : on assombrit la couleur des murs (×0.8) pour creuser le
	# contraste avec les éléments de gameplay, sans la rendre laide.
	_base_wall = (theme["wall_color"] as Color) * 0.8
	_base_wall.a = 1.0
	# line_color N'EST PAS modulée par le cycle (lisibilité du couloir, même de nuit), mais
	# elle est cachée ici pour que les ZONES visuelles puissent la blender (néon = lignes vives).
	_base_line = theme["line_color"]
	_wall_material.set_shader_parameter("line_color", _base_line)

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
	var tint: Color = _sample_c(_k_tint, phase)
	var tstr: float = _sample_f(_k_tstr, phase)
	var star: float = _sample_f(_k_star, phase)

	# --- Le cycle jour/nuit ne touche QUE le CIEL / FOND LOINTAIN ----------------------
	# Murs latéraux, perso, pièces, power-ups et obstacles gardent leur rendu NORMAL : leur
	# couleur (wall_color) ET l'ÉCLAIRAGE global (ambient + directionnelle) restent CONSTANTS,
	# peu importe l'heure → lisibilité du gameplay préservée à tout moment, sur tous les thèmes.
	# Seuls le ciel (ProceduralSky), la skyline lointaine et les étoiles vivent avec le cycle.
	# (Les ZONES visuelles rares, plus bas, peuvent encore tout teinter ponctuellement.)
	var wall: Color = _base_wall          # constant (thème) → murs jamais teintés par le cycle
	var line: Color = _base_line
	var sky_top: Color = _modulate(_base_sky_top, bright, tint, tstr)
	var sky_hor: Color = _modulate(_base_sky_horizon, bright, tint, tstr)
	var grd_bot: Color = _modulate(_base_ground_bottom, bright, tint, tstr)
	var grd_hor: Color = _modulate(_base_ground_horizon, bright, tint, tstr)
	var ambient: float = _base_ambient    # constant → éclairage du gameplay stable
	var dir_e: float = _base_dir_energy    # constant
	var star_a: float = star

	# --- Override d'ambiance (zone visuelle) : lerp par _zone_blend, retour propre au cycle ---
	if _zone_blend > 0.0 and _zone_name != "":
		var z: Dictionary = _zone_targets(_zone_name)
		var t: float = _zone_blend
		# NUAGES : éclaircie TRÈS subtile (pas de voile laiteux plein écran). On atténue fortement
		# le décalage de couleur → la zone reste un répit visuel léger (+ raréfaction d'obstacles).
		if _zone_name == "clouds":
			t *= 0.30
		wall = wall.lerp(z["wall"], t)
		line = line.lerp(z["line"], t)
		sky_top = sky_top.lerp(z["sky_top"], t)
		sky_hor = sky_hor.lerp(z["sky_horizon"], t)
		grd_bot = grd_bot.lerp(z["ground_bottom"], t)
		grd_hor = grd_hor.lerp(z["ground_horizon"], t)
		ambient = lerpf(ambient, ambient * float(z["light_mult"]), t)
		dir_e = lerpf(dir_e, dir_e * float(z["light_mult"]), t)
		star_a = lerpf(star_a, float(z["star"]), t)
		# Néon : les lignes du couloir CLIGNOTENT (pulsation synthwave). Multiplicatif sur le RGB.
		if _zone_name == "neon":
			var pulse: float = 0.75 + 0.25 * sin(_pulse_t * 6.0)
			line = Color(line.r * pulse, line.g * pulse, line.b * pulse, line.a)

	# Murs (la teinte du couloir vit avec l'heure ; les lignes restent nettes).
	if _wall_material != null:
		_wall_material.set_shader_parameter("wall_color", wall)
		_wall_material.set_shader_parameter("line_color", line)

	# Ciel (les 4 couleurs du ProceduralSky).
	if _sky_mat != null:
		_sky_mat.sky_top_color = sky_top
		_sky_mat.sky_horizon_color = sky_hor
		_sky_mat.ground_bottom_color = grd_bot
		_sky_mat.ground_horizon_color = grd_hor

	# Skyline (fenêtres jaunes émissives → ressortent davantage la nuit, gratuit).
	if do_skyline:
		_resolve_skyline()
		if _skyline_mat != null:
			_skyline_mat.set_shader_parameter("facade_color", _modulate(_base_facade, bright, tint, tstr))
			_skyline_mat.set_shader_parameter("fog_color", _modulate(_base_fog, bright, tint, tstr))

	# Lumières : baissées la nuit (plancher) → ambiance, MAIS obstacles/pièces émissifs
	# restent éclatants. Le perso garde assez de lumière directionnelle pour rester visible.
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.ambient_light_energy = ambient
	if _dir_light != null:
		_dir_light.light_energy = dir_e

	# Étoiles (alpha additif → apparaissent la nuit, invisibles le jour).
	if _star_mat != null:
		_star_mat.albedo_color.a = star_a

	# Garde-fou : si un ancien fog traînait (résidu d'un run précédent), on le coupe.
	if _world_env != null and _world_env.environment != null and _world_env.environment.fog_enabled:
		_world_env.environment.fog_enabled = false

# Cibles visuelles d'une ambiance (couleurs absolues + multiplicateurs). Blendées par
# _zone_blend par-dessus la sortie du cycle dans _apply_cycle. Palette Mid-Century respectée.
func _zone_targets(name: String) -> Dictionary:
	match name:
		"neon":
			# Tunnel synthwave : couloir sombre bleu nuit, lignes turquoise vives (qui pulsent),
			# ciel dégradé sombre → glow orange/magenta à l'horizon. Lumières baissées (néon pop).
			return {
				"wall": Color(0.06, 0.09, 0.17),
				"line": Color(0.45, 1.00, 0.92),
				"sky_top": Color(0.05, 0.06, 0.14),
				"sky_horizon": Color(0.85, 0.30, 0.40),
				"ground_bottom": Color(0.04, 0.05, 0.10),
				"ground_horizon": Color(0.85, 0.30, 0.40),
				"light_mult": 0.55,
				"star": 0.25,
			}
		"clouds":
			# Brume cotonneuse : tout devient laiteux/clair, lignes en gris doux (restent
			# lisibles sur le clair), lumières inchangées (couvert lumineux). Pas d'étoiles.
			# La densité de brume est appliquée à part (fog WorldEnvironment) dans _apply_cycle.
			# Blancs ADOUCIS (étaient ~0.80-0.93, lecture « aveuglante ») → gris-crème doux : ambiance
			# nuageuse lisible, plus de bascule trop claire à l'entrée.
			return {
				"wall": Color(0.70, 0.70, 0.69),
				"line": Color(0.52, 0.54, 0.54),
				"sky_top": Color(0.72, 0.72, 0.70),
				"sky_horizon": Color(0.80, 0.79, 0.75),
				"ground_bottom": Color(0.74, 0.73, 0.70),
				"ground_horizon": Color(0.78, 0.77, 0.73),
				"light_mult": 1.0,
				"star": 0.0,
			}
		"cosmic":
			# L'espace : couloir/ciel quasi noirs, dégradé NÉBULEUSE violet→turquoise à l'horizon,
			# étoiles à fond. Lumières basses (les obstacles/pièces émissifs restent éclatants).
			return {
				"wall": Color(0.05, 0.06, 0.10),
				"line": Color(0.30, 0.55, 0.62),
				"sky_top": Color(0.02, 0.02, 0.06),
				"sky_horizon": Color(0.35, 0.18, 0.40),
				"ground_bottom": Color(0.02, 0.03, 0.06),
				"ground_horizon": Color(0.16, 0.30, 0.34),
				"light_mult": 0.45,
				"star": 1.0,
			}
		_:
			return {}

# Multiplicateur de vitesse du twist (1.0 = neutre). Néon = rush (+10 %).
func _zone_speed_target(name: String) -> float:
	match name:
		"neon":
			return 1.10
		"cosmic":
			return 0.85   # flottement : on ralentit légèrement (sensation d'apesanteur)
		_:
			return 1.0

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
