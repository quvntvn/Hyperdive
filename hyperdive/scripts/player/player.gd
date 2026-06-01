extends RigidBody3D
class_name PlayerController

const LATERAL_FORCE: float = 25.0
const MAX_LATERAL_SPEED: float = 12.0
const MAX_FALL_SPEED: float = 18.0
const TOUCH_FOLLOW_SPEED: float = 8.0
const TRAIL_BASE_AMOUNT: int = 40
const WALL_HIT_COOLDOWN: float = 0.3
const CHARACTER_BASE_ROT := Vector3(205.0, 0.0, 0.0)
# Pose FUSÉE (mode envol) : perso droit légèrement penché en avant, membres serrés
# le long du corps. Séparé de la pose plongeon pour ne pas la casser.
const ENVOL_CHARACTER_ROT := Vector3(-12.0, 0.0, 0.0)
const ENVOL_ARM_L := Vector3(0.0, 0.0, 6.0)
const ENVOL_ARM_R := Vector3(0.0, 0.0, -6.0)
const ENVOL_LEG_L := Vector3(0.0, 0.0, 2.5)
const ENVOL_LEG_R := Vector3(0.0, 0.0, -2.5)
const ENVOL_HEAD := Vector3.ZERO
const SLOWMO_DURATION: float = 3.0
const SLOWMO_FACTOR: float = 0.5
const MAGNET_DURATION: float = 5.0
const MAGNET_RADIUS: float = 10.0
const MAGNET_LERP_SPEED: float = 8.0
const BOOST_DURATION: float = 2.0
const BOOST_SPEED_FACTOR: float = 2.5
const SPEED_RAMP_STEP: float = 1000.0        # tous les 1000 m en infini
const SPEED_RAMP_STEP_ENVOL: float = 500.0   # tous les 500 m en envol
const SPEED_RAMP_FACTOR: float = 1.1    # +10 % cumulatif par palier
const SPEED_RAMP_RATE: float = MAX_FALL_SPEED * 0.10 / 10.0  # ≈ 0.18 m/s² → +10 % en ~10 s

var _is_touching: bool = false
var _wall_hit_cooldown: float = 0.0
var _touch_target_x: float = 0.0
var _is_dead: bool = false
var _parachute_active: bool = false
var _level_completed: bool = false
var _run_time: float = 0.0
var _base_skin_color: Color = Color.WHITE
var _trail_gradient: Gradient
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
var boost_timer: float = 0.0
var _boost_trail: GPUParticles3D
var _current_max_fall_speed: float = MAX_FALL_SPEED
var _jetpack_flames: GPUParticles3D
var _jetpack_smoke: GPUParticles3D

signal game_over

func _ready() -> void:
	add_to_group("player")   # référence cross-scène (porte réactive, etc.)
	Settings.reset_run_stats()
	Settings.daily_games += 1
	Settings.update_daily_progress()
	Settings.save_settings()
	# Mode envol : on MONTE (jetpack). Pas de gravité (poussée constante pilotée dans
	# _physics_process), perso en pose FUSÉE penchée + réacteur dorsal + flammes.
	# En envol le jetpack s'AJOUTE au whoosh du vent (les deux jouent ensemble).
	# Sinon : chute, plongeon, whoosh seul.
	Audio.play_whoosh()
	if Settings.active_mode == "envol":
		gravity_scale = 0.0
		$Character.rotation_degrees = ENVOL_CHARACTER_ROT
		_setup_jetpack()
		Audio.play_jetpack()
	else:
		$Character.rotation_degrees = CHARACTER_BASE_ROT
	body_entered.connect(_on_body_entered)
	_apply_skin(Settings.equipped_skin)
	Settings.equipped_skin_changed.connect(_apply_skin)
	_update_body_color()
	_setup_fall_trail()
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

# Réacteur dorsal + flammes en bouffées, mode envol uniquement. En envol on voit le
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
	var c: Color = Catalog.get_trail(Settings.equipped_trail)["color"]
	_trail_gradient.set_color(0, Color(c.r, c.g, c.b, 1.0))
	_trail_gradient.set_color(1, Color(c.r, c.g, c.b, 0.0))
	_trail_node.emitting = true

func _apply_skin(skin_id: String) -> void:
	var skin: Dictionary = Catalog.get_skin_by_id(skin_id)
	_base_skin_color = skin["color"]
	var mat := $Character/Torso.material_override as StandardMaterial3D
	if mat:
		_update_body_color()

func _on_level_survived() -> void:
	if _level_completed:
		return
	_level_completed = true
	_parachute_active = true
	var distance: int = int(abs(global_position.y))
	Settings.daily_distance += distance
	Settings.daily_time += int(_run_time)
	Settings.update_daily_progress()
	var para := $Character/Parachute
	para.visible = true
	para.scale = Vector3.ZERO
	var t := create_tween()
	t.tween_property(para, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property($Character, "rotation_degrees", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Audio.set_whoosh_intensity(0.0)
	await get_tree().create_timer(0.6).timeout
	Settings.complete_current_level()
	Transition.change_scene("res://scenes/ui/level_screen.tscn")

func _on_body_entered(body: Node3D) -> void:
	if _is_dead or _level_completed:
		return
	if body.is_in_group("walls"):
		if _wall_hit_cooldown <= 0.0:
			Audio.play_hit()
			_shake_camera(0.15)
			_jolt = 0.4
			_wall_hit_cooldown = WALL_HIT_COOLDOWN
		return
	if not body.is_in_group("obstacles"):
		return
	if _boost_active:
		return
	_flash_hit()
	_shake_camera(0.3)
	_body_recoil()
	_jolt = 1.0
	Audio.play_hit()
	if has_shield:
		has_shield = false
		_remove_shield_aura()
		_flash_shield_blocked()
		return
	_is_dead = true
	_trigger_ragdoll()

func _trigger_ragdoll() -> void:
	if _boost_active:
		return
	var death_vel := linear_velocity
	# En envol, on montait (gravity_scale=0). À la mort : "on RETOMBE" → on rétablit la
	# gravité et on lance le ragdoll vers le BAS (sinon il s'envolerait, vitesse positive).
	var ascending: bool = Settings.get_fall_dir() > 0.0
	gravity_scale = 1.0
	$Character.visible = false
	$CollisionShape3D.disabled = true
	freeze = true
	Audio.set_whoosh_intensity(0.0)
	Audio.stop_jetpack()
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

	var skin_col: Color = _base_skin_color
	for part: Node in rag.get_children():
		if part is RigidBody3D:
			var mi: MeshInstance3D = part.get_node_or_null("MeshInstance3D")
			if mi and mi.material_override:
				(mi.material_override as StandardMaterial3D).albedo_color = skin_col
			var rb := part as RigidBody3D
			# Envol : vitesse vers le bas (on retombe). Chute : on garde l'élan vers le bas.
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
	Settings.update_best_distance(distance)
	Settings.daily_distance += distance
	Settings.daily_time += int(_run_time)
	Settings.update_daily_progress()
	Settings.save_settings()
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
	Audio.play_coin()
	match powerup_type:
		"shield":
			has_shield = true
			_show_shield_aura()
		"slowmo":
			_slowmo_active = true
			slowmo_timer = SLOWMO_DURATION
		"magnet":
			_magnet_active = true
			magnet_timer = MAGNET_DURATION
		"boost":
			_boost_active = true
			boost_timer = BOOST_DURATION
			_start_boost_trail()

func _show_shield_aura() -> void:
	if _shield_aura != null:
		return
	_shield_aura = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.9
	sphere.height = 1.8
	_shield_aura.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.235, 0.682, 0.639, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.235, 0.682, 0.639, 1.0)
	mat.emission_energy_multiplier = 0.6
	_shield_aura.material_override = mat
	add_child(_shield_aura)

func _remove_shield_aura() -> void:
	if _shield_aura == null:
		return
	_shield_aura.queue_free()
	_shield_aura = null

func _flash_shield_blocked() -> void:
	var mat := $Character/Torso.material_override as StandardMaterial3D
	if mat == null:
		return
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", Color(0.235, 0.682, 0.639, 1.0), 0.05)
	tween.tween_property(mat, "albedo_color", _base_skin_color, 0.25)

func _attract_coins(delta: float) -> void:
	for coin: Node3D in get_tree().get_nodes_in_group("coins"):
		var dist: float = global_position.distance_to(coin.global_position)
		if dist < MAGNET_RADIUS:
			coin.global_position = coin.global_position.lerp(global_position, delta * MAGNET_LERP_SPEED)

func _shake_camera(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("shake"):
		cam.shake(amount)

func _body_recoil() -> void:
	# Repos selon le mode : pose fusée en envol, plongeon sinon (sinon le recul
	# remettrait le perso tête en bas en plein vol).
	var base: Vector3 = ENVOL_CHARACTER_ROT if Settings.active_mode == "envol" else CHARACTER_BASE_ROT
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
	# Signe vertical centralisé : +1 en envol (on monte), -1 en chute.
	var dir: float = Settings.get_fall_dir()
	if Settings.active_mode != "campaign" and not _level_completed:
		# Même rampe fluide qu'en infini, mais palier 500 m en envol (1000 m sinon).
		# Lissage move_toward → montée progressive sans à-coup. Palier 0 = base inchangée.
		var step_dist: float = SPEED_RAMP_STEP_ENVOL if Settings.active_mode == "envol" else SPEED_RAMP_STEP
		var steps: int = int(abs(global_position.y) / step_dist)
		var target_speed: float = MAX_FALL_SPEED * pow(SPEED_RAMP_FACTOR, steps)
		_current_max_fall_speed = move_toward(_current_max_fall_speed, target_speed, SPEED_RAMP_RATE * delta)
	if _boost_active:
		# Boost dans le sens du déplacement (vers le haut en envol, pas vers la mort).
		linear_velocity.y = dir * MAX_FALL_SPEED * BOOST_SPEED_FACTOR
	elif dir > 0.0:
		# Envol : poussée constante vers le haut (gravity_scale = 0).
		linear_velocity.y = _current_max_fall_speed
		if _slowmo_active:
			linear_velocity.y = _current_max_fall_speed * SLOWMO_FACTOR
	else:
		# Chute : la gravité accélère, on plafonne la vitesse terminale.
		if linear_velocity.y < -_current_max_fall_speed:
			linear_velocity.y = -_current_max_fall_speed
		if _slowmo_active and linear_velocity.y < -_current_max_fall_speed * SLOWMO_FACTOR:
			linear_velocity.y = -_current_max_fall_speed * SLOWMO_FACTOR
	# Vent toujours actif ; en envol le jetpack s'ajoute (même pilotage par la vitesse).
	Audio.set_whoosh_intensity(absf(linear_velocity.y))
	if Settings.active_mode == "envol":
		Audio.set_jetpack_intensity(absf(linear_velocity.y))

func _process(delta: float) -> void:
	if _is_dead or _parachute_active:
		return
	if boost_timer > 0.0:
		boost_timer = maxf(boost_timer - delta, 0.0)
		if boost_timer == 0.0:
			_boost_active = false
			_stop_boost_trail()
	if slowmo_timer > 0.0:
		slowmo_timer = maxf(slowmo_timer - delta, 0.0)
		if slowmo_timer == 0.0:
			_slowmo_active = false
	if magnet_timer > 0.0:
		magnet_timer = maxf(magnet_timer - delta, 0.0)
		if magnet_timer == 0.0:
			_magnet_active = false
		else:
			_attract_coins(delta)
	_sway_time += delta
	_jolt = move_toward(_jolt, 0.0, delta * 4.0)
	# Envol : pose fusée fixe (sway désactivé, calibré pour le perso flippé 180°).
	if Settings.active_mode == "envol":
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

# Pose fusée VIVANTE : oscillation légère et subtile autour des bases ENVOL (≈25 %
# de l'amplitude du sway chute), pilotée par sin + un peu de vélocité latérale.
func _apply_rocket_pose(delta: float) -> void:
	var t: float = _sway_time
	var lateral: float = linear_velocity.x
	# node, base, phase, x_amp, z_amp, lat_z
	_apply_envol_sway($Character/ArmLeft,  delta, ENVOL_ARM_L, t, lateral, 0.0, 3.0, 5.0,  0.3)
	_apply_envol_sway($Character/ArmRight, delta, ENVOL_ARM_R, t, lateral, 1.7, 3.0, 5.0, -0.3)
	_apply_envol_sway($Character/LegLeft,  delta, ENVOL_LEG_L, t, lateral, 0.9, 2.5, 3.0,  0.2)
	_apply_envol_sway($Character/LegRight, delta, ENVOL_LEG_R, t, lateral, 2.4, 2.5, 3.0, -0.2)
	_apply_envol_sway($Character/Head,     delta, ENVOL_HEAD,  t, lateral, 3.2, 2.0, 2.0,  0.0)

# Flottement subtil autour d'une base fixe (pose fusée). Lent (speed 2.5), faible amp.
func _apply_envol_sway(node: Node3D, delta: float, base: Vector3, t: float, lateral: float,
		phase: float, x_amp: float, z_amp: float, lat_z: float) -> void:
	var s: float = sin(t * 2.5 + phase)
	var target: Vector3 = base + Vector3(s * x_amp, 0.0, s * z_amp + lateral * lat_z)
	node.rotation_degrees = node.rotation_degrees.lerp(target, delta * 8.0)

func _start_boost_trail() -> void:
	if _boost_trail != null:
		return
	var trail := GPUParticles3D.new()
	trail.one_shot = false
	trail.amount = 60
	trail.lifetime = 0.25
	trail.local_coords = false
	trail.emitting = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 12.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 18.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.08
	mat.scale_max = 0.18
	mat.color = Color(0.914, 0.310, 0.216, 1.0)
	trail.process_material = mat
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.10
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
