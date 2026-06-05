extends RigidBody3D
class_name PlayerController

const LATERAL_FORCE: float = 25.0
const MAX_LATERAL_SPEED: float = 24.0   # doublé avec TOUCH_FOLLOW_SPEED (cap de vitesse latérale)
const MAX_FALL_SPEED: float = 18.0
const TOUCH_FOLLOW_SPEED: float = 16.0   # finger-follow ×2 (plus réactif)
const TRAIL_BASE_AMOUNT: int = 40
const WALL_HIT_COOLDOWN: float = 0.3
const CHARACTER_BASE_ROT := Vector3(205.0, 0.0, 0.0)
# Pose FUSÉE (mode jetpack) : perso droit légèrement penché en avant, membres serrés
# le long du corps. Séparé de la pose plongeon pour ne pas la casser.
const JETPACK_CHARACTER_ROT := Vector3(-12.0, 0.0, 0.0)
const JETPACK_ARM_L := Vector3(0.0, 0.0, 6.0)
const JETPACK_ARM_R := Vector3(0.0, 0.0, -6.0)
const JETPACK_LEG_L := Vector3(0.0, 0.0, 2.5)
const JETPACK_LEG_R := Vector3(0.0, 0.0, -2.5)
const JETPACK_HEAD := Vector3.ZERO
const SLOWMO_DURATION: float = 4.5    # allonge (etait 3.0) pour savourer le slow-motion
const SLOWMO_FACTOR: float = 0.5
const MAGNET_DURATION: float = 8.0    # le plus long (effet passif utilitaire), etait 5.0
const MAGNET_RADIUS: float = 10.0
const MAGNET_LERP_SPEED: float = 8.0
const BOOST_DURATION: float = 4.0     # allonge (etait 2.0) pour pulveriser plusieurs obstacles
const MEGA_BOOST_DURATION: float = 8.0   # méga-boost : 2× le boost normal (jackpot rare)
const BOOST_SPEED_FACTOR: float = 2.5
const BOOST_COLOR: Color = Color(0.914, 0.310, 0.216, 1.0)    # orange #E94F37
const MEGA_BOOST_COLOR: Color = Color(0.69, 0.149, 1.0, 1.0)  # magenta/violet #B026FF
const SPEED_RAMP_STEP: float = 1000.0        # tous les 1000 m en infini
const SPEED_RAMP_STEP_JETPACK: float = 500.0   # tous les 500 m en jetpack
const SPEED_RAMP_FACTOR: float = 1.1    # +10 % cumulatif par palier
# Coop : rampe dédiée plus agressive (+5 % tous les 150 m) → manches courtes et nerveuses.
const SPEED_RAMP_STEP_COOP: float = 150.0
const SPEED_RAMP_FACTOR_COOP: float = 1.05
# Round final de départage : encore plus agressif (+10 % tous les 100 m) → mort subite rapide.
const SPEED_RAMP_STEP_TIEBREAK: float = 100.0
const SPEED_RAMP_FACTOR_TIEBREAK: float = 1.10
const SPEED_RAMP_RATE: float = MAX_FALL_SPEED * 0.10 / 10.0  # ≈ 0.18 m/s² → +10 % en ~10 s

var _is_touching: bool = false
var _wall_hit_cooldown: float = 0.0
var _touch_target_x: float = 0.0
var _is_dead: bool = false
var _parachute_active: bool = false
var _level_completed: bool = false
var _run_time: float = 0.0
# Série en cours sans toucher un mur + meilleure série du run (défi "survis X s sans mur").
var _no_wall_streak: float = 0.0
var _best_no_wall_run: float = 0.0
var _base_skin_color: Color = Color.WHITE
var _trail_gradient: Gradient
var _trail_grad_tex: GradientTexture1D
var _trail_node: GPUParticles3D
var _sway_time: float = 0.0
var _jolt: float = 0.0
var _shield_aura: MeshInstance3D
var _slowmo_active: bool = false
var _magnet_active: bool = false

var has_shield: bool = false
var slowmo_timer: float = 0.0
var magnet_timer: float = 0.0
var _boost_active: bool = false
var boost_is_mega: bool = false       # le boost actif est-il un méga-boost (durée/couleur/FX 2×) ? (lu par le HUD)
var boost_timer: float = 0.0
var _boost_trail: GPUParticles3D
var _boost_aura: MeshInstance3D
var _magnet_aura: Node3D
var _magnet_ring_t: float = 0.0
var _pulverize_sfx_cd: float = 0.0   # throttle du son/vibration de pulverisation (anti-spam zones)
var _current_max_fall_speed: float = MAX_FALL_SPEED
var _jetpack_flames: GPUParticles3D
var _jetpack_smoke: GPUParticles3D

signal game_over

func _ready() -> void:
	add_to_group("player")   # référence cross-scène (porte réactive, etc.)
	Settings.register_run_start()
	# Mode jetpack : on MONTE. Pas de gravité (poussée constante pilotée dans
	# _physics_process), perso en pose FUSÉE penchée + réacteur dorsal + flammes.
	# En jetpack le son du réacteur s'AJOUTE au whoosh du vent (les deux jouent ensemble).
	# Sinon : chute, plongeon, whoosh seul.
	Audio.play_whoosh()
	if Settings.active_mode == "jetpack":
		gravity_scale = 0.0
		$Character.rotation_degrees = JETPACK_CHARACTER_ROT
		_setup_jetpack()
		Audio.play_jetpack()
	else:
		$Character.rotation_degrees = CHARACTER_BASE_ROT
	body_entered.connect(_on_body_entered)
	# Pulverisation en boost : signal PAR FORME touchee → gere le par-element des zones rares
	# (on ne detruit que ce qu'on percute reellement, le reste de la zone survit).
	body_shape_entered.connect(_on_body_shape_entered)
	# Coop : la couleur du corps est forcée à la couleur d'identité du joueur courant (pas le
	# skin équipé du profil) ; le trail est désactivé (l'identité passe par la couleur du corps).
	# Sinon : skin + trail du profil, comme en solo.
	if Coop.active:
		_apply_coop_color(Coop.turn_color())
	else:
		_apply_skin(Settings.equipped_skin)
		Settings.equipped_skin_changed.connect(_apply_skin)
	_update_body_color()
	_setup_fall_trail()
	if Coop.active:
		if _trail_node:
			_trail_node.emitting = false
	else:
		_apply_trail()
		Settings.equipped_trail_changed.connect(func(_id: String) -> void: _apply_trail())

func _setup_fall_trail() -> void:
	var trail := GPUParticles3D.new()
	trail.name = "FallTrail"
	trail.amount = TRAIL_BASE_AMOUNT
	trail.lifetime = 0.8
	trail.local_coords = false
	trail.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 20.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 2.5
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.18
	mat.scale_max = 0.36
	_trail_gradient = Gradient.new()
	_trail_gradient.set_color(0, Color(0.949, 0.757, 0.306, 1.0))
	_trail_gradient.set_color(1, Color(0.949, 0.757, 0.306, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = _trail_gradient
	mat.color_ramp = grad_tex
	_trail_grad_tex = grad_tex
	trail.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere_mat.vertex_color_use_as_albedo = true
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.surface_set_material(0, sphere_mat)
	trail.draw_pass_1 = sphere

	add_child(trail)
	_trail_node = trail

# Réacteur dorsal + flammes en bouffées, mode jetpack uniquement. En jetpack on voit le
# DOS du perso et la caméra est côté +Z → le réacteur va sur +Z (face caméra = dos
# visible), PAS en -Z (sinon masqué par le corps). Attaché au Torse (suit pose/lean).
func _setup_jetpack() -> void:
	var torso := $Character/Torso
	# --- Corps du réacteur : bloc avec cap crème + tuyère (flat, Mid-Century) ---
	var reactor := MeshInstance3D.new()
	reactor.name = "JetpackReactor"
	var body := BoxMesh.new()
	# Petit sac à dos : plus étroit que les épaules, ne monte pas au-dessus de la tête.
	body.size = Vector3(0.30, 0.40, 0.20)
	reactor.mesh = body
	var body_mat := StandardMaterial3D.new()
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_mat.albedo_color = Color(0.235, 0.682, 0.639)   # turquoise rétro #3CAEA3
	reactor.material_override = body_mat
	# Plaqué sur le dos CÔTÉ CAMÉRA (+Z), DESCENDU (milieu du dos) → tête visible au-dessus.
	reactor.position = Vector3(0.0, -0.02, 0.15)
	torso.add_child(reactor)

	# Cap crème en haut (détail Mid-Century).
	var cap := MeshInstance3D.new()
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(0.32, 0.04, 0.22)
	cap.mesh = cap_box
	var cap_mat := StandardMaterial3D.new()
	cap_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_mat.albedo_color = Color(0.957, 0.914, 0.804)    # crème #F4E9CD
	cap.material_override = cap_mat
	cap.position = Vector3(0.0, 0.22, 0.0)
	reactor.add_child(cap)

	# Tuyère sombre en bas (d'où sortent les flammes).
	var nozzle := MeshInstance3D.new()
	var noz_box := BoxMesh.new()
	noz_box.size = Vector3(0.16, 0.05, 0.13)
	nozzle.mesh = noz_box
	var noz_mat := StandardMaterial3D.new()
	noz_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	noz_mat.albedo_color = Color(0.239, 0.173, 0.118)    # marron noyer #3D2C1E
	nozzle.material_override = noz_mat
	nozzle.position = Vector3(0.0, -0.22, 0.0)
	reactor.add_child(nozzle)

	# --- Flammes en BOUFFÉES TRÈS courtes et denses, juste sous le réacteur ---
	var flames := GPUParticles3D.new()
	flames.name = "JetpackFlames"
	flames.amount = 56                 # dense
	flames.lifetime = 0.14             # encore plus court → disparaissent près du réacteur
	flames.local_coords = false        # se détachent dans le monde en descendant
	flames.emitting = true
	flames.position = Vector3(0.0, -0.26, 0.0)   # juste sous la tuyère (milieu du dos)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)      # vers le bas, opposé de la montée
	mat.spread = 24.0
	mat.initial_velocity_min = 0.6               # très lent = bouffées collées
	mat.initial_velocity_max = 1.3
	mat.gravity = Vector3.ZERO
	mat.damping_min = 1.5                         # ralentit → billow de fumée
	mat.damping_max = 2.5
	mat.scale_min = 0.8                           # grosses particules → bouffées pleines
	mat.scale_max = 1.3
	# Scale qui GROSSIT puis se dissipe (bouffée qui gonfle avant de s'éteindre).
	var scurve := Curve.new()
	scurve.add_point(Vector2(0.0, 0.3))
	scurve.add_point(Vector2(0.35, 1.0))
	scurve.add_point(Vector2(1.0, 0.0))
	var scurve_tex := CurveTexture.new()
	scurve_tex.curve = scurve
	mat.scale_curve = scurve_tex
	# Cœur jaune #F2C14E → orange #E94F37 → fumée sombre transparente.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.949, 0.757, 0.306, 1.0))
	grad.add_point(0.4, Color(0.914, 0.310, 0.216, 1.0))
	grad.set_color(grad.get_point_count() - 1, Color(0.12, 0.10, 0.10, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	flames.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # plein-bright = brille
	sphere_mat.vertex_color_use_as_albedo = true
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mat.emission_enabled = true
	sphere_mat.emission = Color(0.949, 0.757, 0.306, 1.0)
	sphere_mat.emission_energy_multiplier = 2.0     # DEBUG : très émissif pour confirmer le rendu
	sphere.surface_set_material(0, sphere_mat)
	flames.draw_pass_1 = sphere

	reactor.add_child(flames)
	_jetpack_flames = flames

	# --- Traînée de FUMÉE : sillage gris discret derrière les flammes ---
	var smoke := GPUParticles3D.new()
	smoke.name = "JetpackSmoke"
	smoke.amount = 28                  # modéré
	smoke.lifetime = 0.9               # plus longue que les flammes → s'étire derrière
	smoke.local_coords = false         # reste dans le monde = sillage
	smoke.emitting = true
	smoke.position = Vector3(0.0, -0.30, 0.0)   # sous les flammes

	var smat := ParticleProcessMaterial.new()
	smat.direction = Vector3(0.0, -1.0, 0.0)
	smat.spread = 14.0
	smat.initial_velocity_min = 1.0
	smat.initial_velocity_max = 2.2
	smat.gravity = Vector3.ZERO
	smat.damping_min = 0.5
	smat.damping_max = 1.0
	smat.scale_min = 0.5
	smat.scale_max = 1.0
	# La fumée grossit en s'éloignant (se dilue).
	var sm_curve := Curve.new()
	sm_curve.add_point(Vector2(0.0, 0.4))
	sm_curve.add_point(Vector2(1.0, 1.3))
	var sm_curve_tex := CurveTexture.new()
	sm_curve_tex.curve = sm_curve
	smat.scale_curve = sm_curve_tex
	# Gris sombre semi-transparent → se dissipe en transparence. Opacité faible = discret.
	var sm_grad := Gradient.new()
	sm_grad.set_color(0, Color(0.35, 0.34, 0.36, 0.35))
	sm_grad.set_color(1, Color(0.20, 0.19, 0.20, 0.0))
	var sm_grad_tex := GradientTexture1D.new()
	sm_grad_tex.gradient = sm_grad
	smat.color_ramp = sm_grad_tex
	smoke.process_material = smat

	var sm_sphere := SphereMesh.new()
	sm_sphere.radius = 0.11
	sm_sphere.height = 0.22
	var sm_sphere_mat := StandardMaterial3D.new()
	sm_sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm_sphere_mat.vertex_color_use_as_albedo = true
	sm_sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_sphere.surface_set_material(0, sm_sphere_mat)
	smoke.draw_pass_1 = sm_sphere

	reactor.add_child(smoke)
	_jetpack_smoke = smoke

	# Log pour trancher le côté caméra : compare Z du torse et de la caméra.
	var cam := get_tree().get_first_node_in_group("follow_camera") as Node3D
	var cam_pos: Vector3 = cam.global_position if cam else Vector3.INF
	print("[Jetpack] box.size=", body.size, " reactor.pos(+Z=face caméra)=", reactor.position,
		" | torso.global=", torso.global_position, " cam.global=", cam_pos)


func _apply_trail() -> void:
	if _trail_gradient == null or _trail_node == null:
		return
	if Settings.equipped_trail == "none":
		_trail_node.emitting = false
		return
	var data: Dictionary = Catalog.get_trail(Settings.equipped_trail)
	# On rebâtit un Gradient neuf à chaque fois : les trails multicolores ont N stops,
	# les monocouleurs 2 — assigner directement offsets/colors d'arrays de tailles
	# différentes peut désynchroniser le Gradient, donc on repart d'un objet propre.
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	if data.has("ramp"):
		# Confettis : dégradé arc-en-ciel fluide le long de la durée de vie.
		var ramp: Array = data["ramp"]
		var n: int = ramp.size()
		for i in range(n):
			# Réparti sur 0..0.85 ; on garde la fin pour un fondu transparent.
			offsets.append(float(i) / float(n - 1) * 0.85)
			var rc: Color = ramp[i]
			colors.append(Color(rc.r, rc.g, rc.b, 1.0))
		var last: Color = ramp[n - 1]
		offsets.append(1.0)
		colors.append(Color(last.r, last.g, last.b, 0.0))
	else:
		# Trail monocouleur : couleur unique avec fondu α→0 en fin de vie.
		# "alpha" optionnel (Fantôme) abaisse l'opacité de départ → effet vaporeux.
		var c: Color = data["color"]
		var a: float = data.get("alpha", 1.0)
		offsets.append_array([0.0, 1.0])
		colors.append(Color(c.r, c.g, c.b, a))
		colors.append(Color(c.r, c.g, c.b, 0.0))
	g.offsets = offsets
	g.colors = colors
	_trail_gradient = g
	_trail_grad_tex.gradient = g
	_trail_node.emitting = true

func _apply_skin(skin_id: String) -> void:
	var skin: Dictionary = Catalog.get_skin_by_id(skin_id)
	_base_skin_color = skin["color"]
	var mat := $Character/Torso.material_override as StandardMaterial3D
	if mat == null:
		return
	_style_body_material(mat, skin)

# Coop : matériau plat à la couleur d'identité du joueur (ignore le skin du profil). On pose
# _base_skin_color → le ragdoll et _update_body_color héritent automatiquement de la couleur.
func _apply_coop_color(color: Color) -> void:
	_base_skin_color = color
	var mat := $Character/Torso.material_override as StandardMaterial3D
	if mat == null:
		return
	_style_body_material(mat, {"color": color})

# Applique TOUTES les propriétés du matériau (pas que l'albedo) selon le skin : metallic,
# roughness, anisotropie, émission. Centralisé pour que le ragdoll hérite du même rendu que
# le perso vivant (un or métallique reste métallique à la mort, un skin plat reste plat).
func _style_body_material(mat: StandardMaterial3D, skin: Dictionary) -> void:
	mat.albedo_color = skin["color"]
	# Skin OR : métal brossé doré chaud. metallic plein + roughness basse (réfléchit le
	# ciel + le reflet de la DirectionalLight) + anisotropie (reflet allongé = stries du
	# brossé). Légère émission dorée FIXE (pas animée) pour réchauffer/donner le côté luxe.
	if skin.get("gold", false):
		mat.metallic = 1.0
		mat.roughness = 0.25
		mat.anisotropy_enabled = true
		mat.anisotropy = 0.9
		mat.emission_enabled = true
		mat.emission = skin["color"]
		mat.emission_energy_multiplier = 0.15
	# Skin MÉTAL : chrome/acier brossé froid. Même base métallique, pas d'émission.
	elif skin.get("metallic", false):
		mat.metallic = 1.0
		mat.roughness = 0.2
		mat.anisotropy_enabled = true
		mat.anisotropy = 0.9
		mat.emission_enabled = false
	# Skins normaux : matériau plat (sinon résidu metallic/aniso/émission d'un skin spécial).
	else:
		mat.metallic = 0.0
		mat.roughness = 1.0
		mat.anisotropy_enabled = false
		mat.anisotropy = 0.0
		mat.emission_enabled = false

func _on_level_survived() -> void:
	if _level_completed:
		return
	_level_completed = true
	_parachute_active = true
	var distance: int = int(abs(global_position.y))
	Settings.daily_distance += distance
	Settings.daily_time += int(_run_time)
	Settings.update_daily_progress()
	# Niveau réussi (pas une mort) : on fige quand même les meilleurs scores de run.
	Settings.finalize_run(distance, int(_best_no_wall_run))
	var para := $Character/Parachute
	para.visible = true
	para.scale = Vector3.ZERO
	var t := create_tween()
	t.tween_property(para, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property($Character, "rotation_degrees", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Audio.set_whoosh_intensity(0.0)
	await get_tree().create_timer(0.6).timeout
	# Capturer AVANT complete_current_level() : il crédite les pièces et incrémente
	# campaign_level. On affiche le niveau réussi + le gain exact dans l'overlay.
	var completed: int = Settings.active_level
	var reward: int = Settings.get_level_reward(completed)
	Settings.complete_current_level()
	# Overlay in-game (le jeu reste derrière, flouté) plutôt qu'un changement de scène.
	var screen := get_tree().get_first_node_in_group("level_complete_screen")
	if screen:
		screen.show_level_complete(completed, reward)
	else:
		Transition.change_scene("res://scenes/ui/main_menu.tscn")

func _on_body_entered(body: Node3D) -> void:
	if _is_dead or _level_completed:
		return
	if body.is_in_group("walls"):
		if _wall_hit_cooldown <= 0.0:
			Audio.play_hit()
			_shake_camera(0.15)
			_jolt = 0.4
			_wall_hit_cooldown = WALL_HIT_COOLDOWN
			_no_wall_streak = 0.0   # série sans mur cassée
		return
	if not body.is_in_group("obstacles"):
		return
	if _boost_active:
		return
	# Choc sur un obstacle : impact commun (son + shake + recul), puis bouclier OU mort.
	Audio.play_hit()
	_shake_camera(0.3)
	_body_recoil()
	_jolt = 1.0
	if has_shield:
		has_shield = false
		_remove_shield_aura()
		_shield_shatter()   # eclatement turquoise = SAUVEGARDE (jamais rouge), pas une mort
		# Détruit AUSSI l'obstacle percuté : sinon il reste là et tue le joueur une fraction de
		# seconde après l'éclatement (re-collision injuste). Par-élément pour les zones rares.
		_destroy_obstacle_shield(body)
		return
	_flash_hit()   # flash blanc "mortel" seulement quand on meurt vraiment
	_is_dead = true
	_trigger_ragdoll()

func _trigger_ragdoll() -> void:
	if _boost_active:
		return
	Settings.vibrate(120)   # impact haptique marqué qui accompagne le ragdoll (mort satisfaisante)
	var death_vel := linear_velocity
	# En jetpack, on montait (gravity_scale=0). À la mort : "on RETOMBE" → on rétablit la
	# gravité et on lance le ragdoll vers le BAS (sinon il s'envolerait, vitesse positive).
	var ascending: bool = Settings.get_fall_dir() > 0.0
	gravity_scale = 1.0
	$Character.visible = false
	$CollisionShape3D.disabled = true
	freeze = true
	Audio.set_whoosh_intensity(0.0)
	Audio.stop_jetpack()
	# Nettoie les effets de power-up encore actifs (sinon vignette/pitch/bulle restent au menu).
	_stop_slowmo_fx()
	_remove_shield_aura()
	_remove_magnet_aura()
	_remove_boost_aura()
	_stop_boost_fx()
	if _trail_node:
		_trail_node.emitting = false
	if _jetpack_flames:
		_jetpack_flames.emitting = false
	if _jetpack_smoke:
		_jetpack_smoke.emitting = false

	var rag: Node3D = preload("res://scenes/player/ragdoll.tscn").instantiate()
	# Position et rotation AVANT add_child : les RigidBody3D enfants calculent leur
	# global_transform depuis ce transform au premier frame physique.
	# global_rotation du Character = ~205° autour de X (tête en bas), sans le scale 1.5.
	rag.position = global_position
	rag.rotation = $Character.global_rotation
	get_tree().current_scene.add_child(rag)

	# Le ragdoll hérite du MÊME matériau que le perso vivant (skin équipé) : metallic,
	# roughness, anisotropie, émission, albedo — pas juste la couleur. Sinon un or/acier
	# métallique redevenait jaune/gris plat à la mort. On duplique le matériau par partie
	# (sinon toutes partageraient la ressource du .tscn) pour ne pas polluer d'autres ragdolls.
	# Coop : le ragdoll sort à la couleur d'identité du joueur (matériau plat), pas le skin
	# du profil. Sinon : matériau complet du skin équipé (métal/or/émission préservés).
	var skin: Dictionary = {"color": Coop.turn_color()} if Coop.active else Catalog.get_skin_by_id(Settings.equipped_skin)
	for part: Node in rag.get_children():
		if part is RigidBody3D:
			var mi: MeshInstance3D = part.get_node_or_null("MeshInstance3D")
			if mi and mi.material_override:
				var pmat := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				_style_body_material(pmat, skin)
				mi.material_override = pmat
			var rb := part as RigidBody3D
			# Jetpack : vitesse vers le bas (on retombe). Chute : on garde l'élan vers le bas.
			var vy: float = -6.0 if ascending else maxf(death_vel.y, -6.0)
			rb.linear_velocity = Vector3(
				randf_range(-2.0, 2.0),
				vy,
				randf_range(-2.0, 2.0)
			)
			rb.apply_torque_impulse(Vector3(
				randf_range(-3.0, 3.0),
				randf_range(-3.0, 3.0),
				randf_range(-3.0, 3.0)
			))

	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("set_target"):
		cam.set_target(rag.get_node("Torso"))

	await get_tree().create_timer(1.2).timeout

	var distance: int = int(abs(global_position.y))
	# COOP : la mort = fin du tour. On enregistre le score et on route vers le joueur/écran
	# suivant — AUCUNE stat perso (pas de record, pas de mort comptée, pas de finalize), et
	# PAS d'écran de game over solo. Le solo (Coop.active=false) garde son flux inchangé.
	if Coop.active:
		Audio.play_game_over()
		Coop.end_turn(distance)
		return
	Settings.update_best_distance(distance)
	Settings.daily_distance += distance
	Settings.daily_time += int(_run_time)
	Settings.update_daily_progress()
	Settings.register_death()
	Settings.finalize_run(distance, int(_best_no_wall_run))
	Audio.play_game_over()
	game_over.emit()
	var go_screen := get_tree().get_first_node_in_group("game_over_screen")
	if go_screen:
		go_screen.show_game_over(distance)

func _unhandled_input(event: InputEvent) -> void:
	if Settings.control_mode == SettingsManager.ControlMode.TOUCH:
		if event is InputEventScreenTouch:
			_is_touching = event.pressed
			if event.pressed:
				_update_touch_target(event.position)
		elif event is InputEventScreenDrag:
			_is_touching = true
			_update_touch_target(event.position)
	# Mode switching — dev only, replaced by options menu in Phase E
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				Settings.control_mode = SettingsManager.ControlMode.KEYBOARD
				Settings.save_settings()
				Settings.control_mode_changed.emit(Settings.control_mode)
			KEY_2:
				Settings.control_mode = SettingsManager.ControlMode.TOUCH
				Settings.save_settings()
				Settings.control_mode_changed.emit(Settings.control_mode)
			KEY_S:
				var shop := get_tree().get_first_node_in_group("shop_screen")
				if shop:
					shop.open()


func _get_lateral_input() -> float:
	match Settings.control_mode:
		SettingsManager.ControlMode.KEYBOARD:
			return Input.get_axis("move_left", "move_right")
	return 0.0

func _update_touch_target(screen_pos: Vector2) -> void:
	var screen_width: float = get_viewport().get_visible_rect().size.x
	var normalized: float = clampf(screen_pos.x / screen_width, 0.0, 1.0)
	_touch_target_x = lerpf(-5.0, 5.0, normalized)

func _update_body_color() -> void:
	var mat := $Character/Torso.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = _base_skin_color

func _flash_hit() -> void:
	var mat := $Character/Torso.material_override as StandardMaterial3D
	if mat == null:
		return
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", Color.WHITE, 0.05)
	tween.tween_property(mat, "albedo_color", _base_skin_color, 0.10)

func collect_powerup(powerup_type: String) -> void:
	# Le son dedie + le feedback de ramassage sont joues cote powerup.gd (_juicy_pickup).
	Settings.register_powerup_used(powerup_type)
	match powerup_type:
		"shield":
			has_shield = true
			_show_shield_aura()
		"slowmo":
			_slowmo_active = true
			slowmo_timer = SLOWMO_DURATION
			_start_slowmo_fx()
		"magnet":
			_magnet_active = true
			magnet_timer = MAGNET_DURATION
			_show_magnet_aura()
		"boost":
			_activate_boost(false)
		"megaboost":
			_activate_boost(true)

# Boost ET méga-boost partagent la même mécanique (invincibilité + pulvérisation via _boost_active) :
# seuls la durée, la couleur et l'intensité des FX changent → un seul point de logique, pas de doublon.
func _activate_boost(mega: bool) -> void:
	_boost_active = true
	boost_is_mega = mega
	boost_timer = MEGA_BOOST_DURATION if mega else BOOST_DURATION
	_start_boost_trail(mega)
	_start_boost_fx(mega)

func _show_shield_aura() -> void:
	if _shield_aura != null:
		return
	_shield_aura = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.95
	sphere.height = 1.9
	sphere.radial_segments = 24
	sphere.rings = 12
	_shield_aura.mesh = sphere
	# Bulle Fresnel : transparente au centre, lumineuse sur les bords (ne masque pas la vue).
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/shield_bubble.gdshader")
	mat.set_shader_parameter("bubble_color", Color(0.235, 0.682, 0.639, 1.0))
	_shield_aura.material_override = mat
	add_child(_shield_aura)
	# Pulsation douce en boucle (bulle vivante) ; le tween meurt avec le noeud au remove.
	var tw := create_tween().set_loops()
	tw.tween_method(_set_shield_pulse, 0.8, 1.1, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_set_shield_pulse, 1.1, 0.8, 0.7).set_trans(Tween.TRANS_SINE)

func _set_shield_pulse(v: float) -> void:
	if _shield_aura == null:
		return
	var mat := _shield_aura.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("pulse", v)

func _remove_shield_aura() -> void:
	if _shield_aura == null:
		return
	_shield_aura.queue_free()
	_shield_aura = null

# Eclatement du bouclier au choc absorbe : doit lire comme une SAUVEGARDE (turquoise, jamais
# rouge), pas une mort. Onde de choc + eclats + flash turquoise + son "verre casse" + vibration.
func _shield_shatter() -> void:
	var turquoise := Color(0.235, 0.682, 0.639, 1.0)
	Audio.play_shield_break()
	Settings.vibrate(60)
	var pp := get_tree().get_first_node_in_group("post_process")
	if pp != null and pp.has_method("flash"):
		pp.flash(turquoise, 0.4, 0.22)
	# Torse qui pulse turquoise (feedback sur le perso).
	var tmat := $Character/Torso.material_override as StandardMaterial3D
	if tmat != null:
		var tween := create_tween()
		tween.tween_property(tmat, "albedo_color", turquoise, 0.05)
		tween.tween_property(tmat, "albedo_color", _base_skin_color, 0.25)
	# Onde de choc : anneau qui s'agrandit et s'efface.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 0.9
	torus.rings = 20
	torus.ring_segments = 10
	ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rmat.albedo_color = turquoise
	rmat.emission_enabled = true
	rmat.emission = turquoise
	rmat.emission_energy_multiplier = 3.0
	ring.material_override = rmat
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)   # face a la camera
	var rtw := create_tween()
	rtw.set_parallel(true)
	rtw.tween_property(ring, "scale", Vector3.ONE * 3.5, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.tween_property(rmat, "albedo_color:a", 0.0, 0.4)
	rtw.chain().tween_callback(ring.queue_free)
	# Eclats : burst de particules turquoise/blanches vers l'exterieur.
	var burst := GPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 24
	burst.lifetime = 0.5
	burst.emitting = true
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0.0, 1.0, 0.0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 5.0
	pmat.initial_velocity_max = 10.0
	pmat.gravity = Vector3.ZERO
	pmat.scale_min = 0.1
	pmat.scale_max = 0.22
	pmat.color = turquoise
	burst.process_material = pmat
	var shard := BoxMesh.new()
	shard.size = Vector3(0.1, 0.1, 0.1)
	burst.draw_pass_1 = shard
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)

# Ralenti : effet d'ecran (vignette froide + desaturation, transition douce via PostProcess)
# + vent pitche vers le bas. On RESSENT le slow-motion sans masquer le centre/obstacles.
func _start_slowmo_fx() -> void:
	var pp := get_tree().get_first_node_in_group("post_process")
	if pp != null and pp.has_method("set_slowmo"):
		pp.set_slowmo(true)
	Audio.set_whoosh_pitch(0.7)

func _stop_slowmo_fx() -> void:
	var pp := get_tree().get_first_node_in_group("post_process")
	if pp != null and pp.has_method("set_slowmo"):
		pp.set_slowmo(false)
	Audio.set_whoosh_pitch(1.0)

func _attract_coins(delta: float) -> void:
	for coin: Node3D in get_tree().get_nodes_in_group("coins"):
		var dist: float = global_position.distance_to(coin.global_position)
		if dist < MAGNET_RADIUS:
			# Aspiration MARQUEE : plus la piece est proche, plus elle accelere (effet "happee").
			var t: float = clampf(1.0 - dist / MAGNET_RADIUS, 0.0, 1.0)
			var speed: float = MAGNET_LERP_SPEED * (1.0 + t * 2.5)
			coin.global_position = coin.global_position.lerp(global_position, delta * speed)

func _shake_camera(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("shake"):
		cam.shake(amount)

func _body_recoil() -> void:
	# Repos selon le mode : pose fusée en jetpack, plongeon sinon (sinon le recul
	# remettrait le perso tête en bas en plein vol).
	var base: Vector3 = JETPACK_CHARACTER_ROT if Settings.active_mode == "jetpack" else CHARACTER_BASE_ROT
	var tween := create_tween()
	tween.tween_property($Character, "rotation_degrees",
		base + Vector3(randf_range(-12.0, 12.0), 0.0, randf_range(-8.0, 8.0)), 0.05)
	tween.tween_property($Character, "rotation_degrees", base, 0.15)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_wall_hit_cooldown = maxf(_wall_hit_cooldown - delta, 0.0)
	if not _level_completed:
		_run_time += delta
		# Série sans toucher un mur : s'accumule tant qu'on joue, reset à chaque hit de mur.
		_no_wall_streak += delta
		if _no_wall_streak > _best_no_wall_run:
			_best_no_wall_run = _no_wall_streak
	if _parachute_active:
		linear_velocity.y = maxf(linear_velocity.y, -1.5)
		linear_velocity.x = move_toward(linear_velocity.x, 0.0, 10.0 * delta)
		Audio.set_whoosh_intensity(linear_velocity.y)
		return
	if Settings.control_mode == SettingsManager.ControlMode.TOUCH:
		if _is_touching:
			var diff: float = _touch_target_x - global_position.x
			linear_velocity.x = clampf(diff * TOUCH_FOLLOW_SPEED, -MAX_LATERAL_SPEED, MAX_LATERAL_SPEED)
		else:
			linear_velocity.x = move_toward(linear_velocity.x, 0.0, MAX_LATERAL_SPEED * delta * 4.0)
	else:
		var lateral: float = _get_lateral_input()
		if lateral != 0.0:
			apply_central_force(Vector3(lateral * LATERAL_FORCE, 0.0, 0.0))
		linear_velocity.x = clampf(linear_velocity.x, -MAX_LATERAL_SPEED, MAX_LATERAL_SPEED)
	# Signe vertical centralisé : +1 en jetpack (on monte), -1 en chute.
	var dir: float = Settings.get_fall_dir()
	if Settings.active_mode != "campaign" and not _level_completed:
		# Rampe de vitesse fluide (move_toward, jamais de saut sec). COOP : +5 %/150 m (plus
		# agressif, manches nerveuses). SOLO : inchangé (+10 %/1000 m chute, +10 %/500 m jetpack).
		var step_dist: float
		var factor: float
		if Coop.active and Coop.tiebreak_active:
			step_dist = SPEED_RAMP_STEP_TIEBREAK
			factor = SPEED_RAMP_FACTOR_TIEBREAK
		elif Coop.active:
			step_dist = SPEED_RAMP_STEP_COOP
			factor = SPEED_RAMP_FACTOR_COOP
		else:
			step_dist = SPEED_RAMP_STEP_JETPACK if Settings.active_mode == "jetpack" else SPEED_RAMP_STEP
			factor = SPEED_RAMP_FACTOR
		var steps: int = int(abs(global_position.y) / step_dist)
		var target_speed: float = MAX_FALL_SPEED * pow(factor, steps)
		_current_max_fall_speed = move_toward(_current_max_fall_speed, target_speed, SPEED_RAMP_RATE * delta)
	if _boost_active:
		# Boost dans le sens du déplacement (vers le haut en jetpack, pas vers la mort).
		linear_velocity.y = dir * MAX_FALL_SPEED * BOOST_SPEED_FACTOR
	elif dir > 0.0:
		# Jetpack : poussée constante vers le haut (gravity_scale = 0).
		linear_velocity.y = _current_max_fall_speed
		if _slowmo_active:
			linear_velocity.y = _current_max_fall_speed * SLOWMO_FACTOR
	else:
		# Chute : la gravité accélère, on plafonne la vitesse terminale.
		if linear_velocity.y < -_current_max_fall_speed:
			linear_velocity.y = -_current_max_fall_speed
		if _slowmo_active and linear_velocity.y < -_current_max_fall_speed * SLOWMO_FACTOR:
			linear_velocity.y = -_current_max_fall_speed * SLOWMO_FACTOR
	# Vent toujours actif ; en jetpack le jetpack s'ajoute (même pilotage par la vitesse).
	Audio.set_whoosh_intensity(absf(linear_velocity.y))
	if Settings.active_mode == "jetpack":
		Audio.set_jetpack_intensity(absf(linear_velocity.y))

func _process(delta: float) -> void:
	if _is_dead or _parachute_active:
		return
	_pulverize_sfx_cd = maxf(_pulverize_sfx_cd - delta, 0.0)
	if boost_timer > 0.0:
		boost_timer = maxf(boost_timer - delta, 0.0)
		if boost_timer == 0.0:
			_boost_active = false
			boost_is_mega = false
			_stop_boost_trail()
			_stop_boost_fx()
	if slowmo_timer > 0.0:
		slowmo_timer = maxf(slowmo_timer - delta, 0.0)
		if slowmo_timer == 0.0:
			_slowmo_active = false
			_stop_slowmo_fx()
	if magnet_timer > 0.0:
		magnet_timer = maxf(magnet_timer - delta, 0.0)
		if magnet_timer == 0.0:
			_magnet_active = false
			_remove_magnet_aura()
		else:
			_attract_coins(delta)
			_emit_magnet_rings(delta)
	_sway_time += delta
	_jolt = move_toward(_jolt, 0.0, delta * 4.0)
	# Jetpack : pose fusée fixe (sway désactivé, calibré pour le perso flippé 180°).
	if Settings.active_mode == "jetpack":
		_apply_rocket_pose(delta)
		return
	var lateral: float = linear_velocity.x
	# speed, phase, base_z, z_amp, x_amp, lat_z, jolt_z, jolt_x, base_x
	# lat_z positif car Character est flippé X=180° (Z local = -Z monde)
	# base_x positif = bras tirés légèrement vers l'arrière (vers la caméra)
	_apply_limb_sway($Character/ArmLeft,  lateral, delta, 3.7, 0.0,  115.0, 22.0, 11.0, 1.2,  40.0,  10.0, 22.0)
	_apply_limb_sway($Character/ArmRight, lateral, delta, 3.4, 1.7, -115.0, 20.0, 11.0, 1.2, -35.0, -18.0, 22.0)
	_apply_limb_sway($Character/LegLeft,  lateral, delta, 2.8, 0.9,  -35.0, 12.0, 13.0, 0.5, -22.0,  28.0)
	_apply_limb_sway($Character/LegRight, lateral, delta, 3.1, 2.4,   35.0, 11.0, 13.0, 0.5,  20.0, -24.0)
	_apply_limb_sway($Character/Head,     lateral, delta, 2.2, 3.2,    0.0, 11.0,  7.0, 0.4,  20.0,   8.0)

# Pose fusée VIVANTE : oscillation légère et subtile autour des bases JETPACK (≈25 %
# de l'amplitude du sway chute), pilotée par sin + un peu de vélocité latérale.
func _apply_rocket_pose(delta: float) -> void:
	var t: float = _sway_time
	var lateral: float = linear_velocity.x
	# node, base, phase, x_amp, z_amp, lat_z
	_apply_jetpack_sway($Character/ArmLeft,  delta, JETPACK_ARM_L, t, lateral, 0.0, 3.0, 5.0,  0.3)
	_apply_jetpack_sway($Character/ArmRight, delta, JETPACK_ARM_R, t, lateral, 1.7, 3.0, 5.0, -0.3)
	_apply_jetpack_sway($Character/LegLeft,  delta, JETPACK_LEG_L, t, lateral, 0.9, 2.5, 3.0,  0.2)
	_apply_jetpack_sway($Character/LegRight, delta, JETPACK_LEG_R, t, lateral, 2.4, 2.5, 3.0, -0.2)
	_apply_jetpack_sway($Character/Head,     delta, JETPACK_HEAD,  t, lateral, 3.2, 2.0, 2.0,  0.0)

# Flottement subtil autour d'une base fixe (pose fusée). Lent (speed 2.5), faible amp.
func _apply_jetpack_sway(node: Node3D, delta: float, base: Vector3, t: float, lateral: float,
		phase: float, x_amp: float, z_amp: float, lat_z: float) -> void:
	var s: float = sin(t * 2.5 + phase)
	var target: Vector3 = base + Vector3(s * x_amp, 0.0, s * z_amp + lateral * lat_z)
	node.rotation_degrees = node.rotation_degrees.lerp(target, delta * 8.0)

func _start_boost_trail(mega: bool = false) -> void:
	if _boost_trail != null:
		return
	var trail := GPUParticles3D.new()
	trail.one_shot = false
	trail.amount = 150 if mega else 90        # méga-boost : traînée bien plus dense
	trail.lifetime = 0.35 if mega else 0.3
	trail.local_coords = false
	trail.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 18.0 if mega else 14.0
	mat.initial_velocity_min = 12.0 if mega else 10.0
	mat.initial_velocity_max = 24.0 if mega else 20.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.12 if mega else 0.1
	mat.scale_max = 0.34 if mega else 0.24
	var grad := Gradient.new()
	if mega:
		# Dégradé magenta clair -> violet -> transparent (flamme jackpot, plus grosse/colorée).
		grad.set_color(0, Color(1.0, 0.55, 1.0, 1.0))
		grad.add_point(0.5, MEGA_BOOST_COLOR)
		grad.set_color(1, Color(MEGA_BOOST_COLOR.r, MEGA_BOOST_COLOR.g, MEGA_BOOST_COLOR.b, 0.0))
	else:
		# Degrade jaune moutarde -> orange -> transparent (flamme).
		grad.set_color(0, Color(0.949, 0.757, 0.306, 1.0))   # jaune #F2C14E
		grad.add_point(0.5, Color(0.914, 0.310, 0.216, 1.0))
		grad.set_color(1, Color(0.914, 0.310, 0.216, 0.0))   # orange #E94F37 -> fondu
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	trail.process_material = mat
	var sphere := SphereMesh.new()
	sphere.radius = 0.07 if mega else 0.05
	sphere.height = 0.14 if mega else 0.10
	trail.draw_pass_1 = sphere
	add_child(trail)
	_boost_trail = trail

func _stop_boost_trail() -> void:
	if _boost_trail == null:
		return
	var old_trail: GPUParticles3D = _boost_trail
	_boost_trail = null
	old_trail.emitting = false
	get_tree().create_timer(0.4).timeout.connect(old_trail.queue_free)

# ── Boost : effets ecran + aura d'immunite + punch camera ────────────────────────────────
func _start_boost_fx(mega: bool = false) -> void:
	_show_boost_aura(mega)
	var pp := get_tree().get_first_node_in_group("post_process")
	if pp != null and pp.has_method("set_speed_lines"):
		if mega:
			pp.set_speed_lines(true, MEGA_BOOST_COLOR, 1.0)   # lignes magenta plus denses/intenses
		else:
			pp.set_speed_lines(true, BOOST_COLOR, 0.7)
	_shake_camera(0.45 if mega else 0.25)   # "punch" au declenchement (plus fort en méga)

func _stop_boost_fx() -> void:
	_remove_boost_aura()
	var pp := get_tree().get_first_node_in_group("post_process")
	if pp != null and pp.has_method("set_speed_lines"):
		pp.set_speed_lines(false)

# Aura d'IMMUNITE visible (blanc-orange) : meme bulle Fresnel que le bouclier mais orange →
# le joueur SAIT qu'il est invincible et fonce (sinon il freine par reflexe). Distincte du
# bouclier (turquoise) par la couleur.
func _show_boost_aura(mega: bool = false) -> void:
	if _boost_aura != null:
		return
	_boost_aura = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.15 if mega else 1.0
	sphere.height = 2.3 if mega else 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	_boost_aura.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/shield_bubble.gdshader")
	# Méga : aura magenta éclatante + rim plus large (rim_power plus bas). Normal : blanc-orange chaud.
	mat.set_shader_parameter("bubble_color", Color(0.85, 0.35, 1.0, 1.0) if mega else Color(1.0, 0.55, 0.3, 1.0))
	mat.set_shader_parameter("rim_power", 1.5 if mega else 2.0)
	mat.set_shader_parameter("pulse", 1.4 if mega else 1.1)
	_boost_aura.material_override = mat
	add_child(_boost_aura)

func _remove_boost_aura() -> void:
	if _boost_aura == null:
		return
	_boost_aura.queue_free()
	_boost_aura = null

# ── Aimant : champ magnetique visible (anneaux qui emanent) ───────────────────────────────
func _show_magnet_aura() -> void:
	if _magnet_aura != null:
		return
	_magnet_aura = Node3D.new()
	add_child(_magnet_aura)
	_magnet_ring_t = 0.0

func _remove_magnet_aura() -> void:
	if _magnet_aura == null:
		return
	_magnet_aura.queue_free()
	_magnet_aura = null

# Emane un anneau jaune toutes les ~0.45 s tant que l'aimant est actif : il grandit et
# s'efface → "champ" qui aspire, lisible, centre degage. Peu de noeuds vivants a la fois.
func _emit_magnet_rings(delta: float) -> void:
	if _magnet_aura == null:
		return
	_magnet_ring_t -= delta
	if _magnet_ring_t > 0.0:
		return
	_magnet_ring_t = 0.45
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.62
	torus.rings = 16
	torus.ring_segments = 8
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.949, 0.757, 0.306, 0.7)   # jaune moutarde
	mat.emission_enabled = true
	mat.emission = Color(0.949, 0.757, 0.306, 1.0)
	mat.emission_energy_multiplier = 2.5
	ring.material_override = mat
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)   # face camera
	_magnet_aura.add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * 2.2, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(ring.queue_free)

# ── Pulverisation (boost) : detruit l'obstacle/element percute au lieu de mourir ──────────
# Regle de comptage : un obstacle DETRUIT compte comme esquive/franchi (register_obstacle_dodged),
# comme s'il avait ete depasse. Les ZONES rares ne sont PAS comptees par element : la zone
# (corps StaticBody) survit videe de ses elements et est comptee une fois a son despawn.
func _on_body_shape_entered(_body_rid: RID, body: Node, body_shape_index: int, _local_shape_index: int) -> void:
	if not _boost_active or _is_dead or _level_completed:
		return
	if body == null or not body.is_in_group("obstacles"):
		return
	_pulverize_contact(body, body_shape_index)

func _pulverize_contact(body: Node, body_shape_index: int) -> void:
	var is_zone: bool = body is ObstacleBase and (body as ObstacleBase).zone_length > 0.0
	var col: Node3D = _get_collision_node(body, body_shape_index)
	var pos: Vector3 = col.global_position if col != null else (body as Node3D).global_position
	_spawn_pulverize_burst(pos, _obstacle_color(body), boost_is_mega)
	# Feedback son/shake/vibration limite (anti-spam quand on traverse une zone a 4 elements).
	if _pulverize_sfx_cd <= 0.0:
		Audio.play_hit()
		_shake_camera(0.18 if boost_is_mega else 0.12)
		Settings.vibrate(25)
		_pulverize_sfx_cd = 0.08
	if is_zone:
		_remove_zone_element(body, col)   # retire juste l'element percute, garde le reste
	else:
		Settings.register_obstacle_dodged()
		(body as Node3D).queue_free()

# Retrouve le CollisionShape3D correspondant a l'index de forme rapporte par le signal.
func _get_collision_node(body: Node, body_shape_index: int) -> Node3D:
	if not (body is CollisionObject3D):
		return null
	var owner_id: int = (body as CollisionObject3D).shape_find_owner(body_shape_index)
	var owner_node: Object = (body as CollisionObject3D).shape_owner_get_owner(owner_id)
	return owner_node as Node3D

# Zone : retire la forme percutee + le mesh apparie (meme position locale), garde le corps
# (il finira par despawn proprement, comptant une fois). Le reste de la zone reste intact.
func _remove_zone_element(body: Node, col: Node3D) -> void:
	if col == null:
		return
	var cpos: Vector3 = col.position
	for child in body.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).position.distance_to(cpos) < 0.1:
			(child as MeshInstance3D).queue_free()
			break
	col.queue_free()

func _obstacle_color(body: Node) -> Color:
	# Zones rares / porte = marron noyer ; obstacles standards = orange brule.
	if body is ObstacleBase and (body as ObstacleBase).zone_length > 0.0:
		return Color(0.239, 0.173, 0.118, 1.0)
	return Color(0.914, 0.310, 0.216, 1.0)

# Destruction d'un obstacle quand le BOUCLIER absorbe le choc (partout : solo + coop). Même
# rendu que la pulvérisation boost (burst coloré). body_entered ne fournit pas l'index de
# forme → pour une zone rare on retire l'ÉLÉMENT le plus proche du joueur (celui qu'on percute),
# pas toute la zone (la zone survit et despawn normalement, comptée une fois). Obstacle standard
# = retiré en entier et compté comme esquivé (cohérent avec le boost).
func _destroy_obstacle_shield(body: Node) -> void:
	if body == null or not (body is Node3D):
		return
	var is_zone: bool = body is ObstacleBase and (body as ObstacleBase).zone_length > 0.0
	if is_zone:
		var col: Node3D = _nearest_zone_element(body)
		if col != null:
			_spawn_pulverize_burst(col.global_position, _obstacle_color(body))
			_remove_zone_element(body, col)
		return
	_spawn_pulverize_burst((body as Node3D).global_position, _obstacle_color(body))
	Settings.register_obstacle_dodged()
	(body as Node3D).queue_free()

# Élément (CollisionShape3D) d'une zone rare le plus proche du joueur = celui qu'on percute.
func _nearest_zone_element(body: Node) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for child in body.get_children():
		if child is CollisionShape3D:
			var d: float = global_position.distance_to((child as CollisionShape3D).global_position)
			if d < best_d:
				best_d = d
				best = child as Node3D
	return best

func _spawn_pulverize_burst(pos: Vector3, color: Color, mega: bool = false) -> void:
	var burst := GPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 38 if mega else 18        # méga-boost : pulvérisation bien plus spectaculaire
	burst.lifetime = 0.55 if mega else 0.45
	burst.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 6.0 if mega else 5.0
	mat.initial_velocity_max = 14.0 if mega else 11.0
	mat.gravity = Vector3(0.0, -6.0, 0.0)
	mat.scale_min = 0.1
	mat.scale_max = 0.32 if mega else 0.25
	# Méga : éclats teintés magenta (mix couleur obstacle → magenta) pour le côté jackpot.
	mat.color = color.lerp(MEGA_BOOST_COLOR, 0.6) if mega else color
	burst.process_material = mat
	var shard := BoxMesh.new()
	shard.size = (Vector3.ONE * 0.18) if mega else Vector3(0.14, 0.14, 0.14)
	burst.draw_pass_1 = shard
	get_tree().current_scene.add_child(burst)
	burst.global_position = pos
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)

func _apply_limb_sway(node: Node3D, lateral: float, delta: float,
		speed: float, phase: float,
		base_z: float, z_amp: float, x_amp: float, lat_z: float,
		jolt_z: float, jolt_x: float, base_x: float = 0.0) -> void:
	var s: float = sin(_sway_time * speed + phase)
	var target := Vector3(
		base_x + s * x_amp + _jolt * jolt_x,
		0.0,
		base_z + s * z_amp + lateral * lat_z + _jolt * jolt_z
	)
	node.rotation_degrees = node.rotation_degrees.lerp(target, delta * 8.0)
