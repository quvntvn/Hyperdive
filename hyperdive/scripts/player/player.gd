extends RigidBody3D
class_name PlayerController

const LATERAL_FORCE: float = 25.0
const MAX_LATERAL_SPEED: float = 12.0
const MAX_FALL_SPEED: float = 18.0
const TILT_DEADZONE: float = 0.1
const TILT_SENSITIVITY: float = 0.25
const TOUCH_FOLLOW_SPEED: float = 8.0
const TRAIL_BASE_AMOUNT: int = 40
const WALL_HIT_COOLDOWN: float = 0.3
const CHARACTER_BASE_ROT := Vector3(205.0, 0.0, 0.0)

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
var _accel_debug_label: Label = null

signal game_over

func _ready() -> void:
	Audio.play_whoosh()
	Settings.reset_run_stats()
	Settings.daily_games += 1
	Settings.update_daily_progress()
	Settings.save_settings()
	$Character.rotation_degrees = CHARACTER_BASE_ROT
	body_entered.connect(_on_body_entered)
	_apply_skin(Settings.equipped_skin)
	Settings.equipped_skin_changed.connect(_apply_skin)
	_update_body_color()
	_setup_fall_trail()
	_apply_trail()
	Settings.equipped_trail_changed.connect(func(_id: String) -> void: _apply_trail())
	_setup_accel_debug()

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

func _setup_accel_debug() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 10
	var lbl := Label.new()
	lbl.position = Vector2(20.0, 120.0)
	lbl.add_theme_font_size_override("font_size", 32)
	cl.add_child(lbl)
	add_child(cl)
	_accel_debug_label = lbl

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
	Audio.set_whoosh_intensity(0.0)
	await get_tree().create_timer(0.6).timeout
	Settings.complete_current_level()
	get_tree().change_scene_to_file("res://scenes/ui/level_screen.tscn")

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
	_flash_hit()
	_shake_camera(0.3)
	_body_recoil()
	_jolt = 1.0
	Audio.play_hit()
	_is_dead = true
	_trigger_ragdoll()

func _trigger_ragdoll() -> void:
	var death_vel := linear_velocity
	$Character.visible = false
	$CollisionShape3D.disabled = true
	freeze = true
	Audio.set_whoosh_intensity(0.0)
	if _trail_node:
		_trail_node.emitting = false

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
			rb.linear_velocity = Vector3(
				randf_range(-2.0, 2.0),
				maxf(death_vel.y, -6.0),
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
			KEY_3:
				Settings.control_mode = SettingsManager.ControlMode.TILT
				Settings.save_settings()
				Settings.control_mode_changed.emit(Settings.control_mode)
			KEY_S:
				var shop := get_tree().get_first_node_in_group("shop_screen")
				if shop:
					shop.open()

func _get_tilt_lateral() -> float:
	# get_gravity() = composante gravité filtrée, plus stable que get_accelerometer()
	# En portrait Android, incliner à droite → gravity.x > 0 (gravity tire vers la droite du device)
	# Si le sens est inversé sur le téléphone, inverser le signe ici (-gravity.x)
	var ax: float = Input.get_gravity().x
	if abs(ax) < TILT_DEADZONE:
		return 0.0
	return clampf(ax * TILT_SENSITIVITY, -1.0, 1.0)

func _get_lateral_input() -> float:
	match Settings.control_mode:
		SettingsManager.ControlMode.KEYBOARD:
			return Input.get_axis("move_left", "move_right")
		SettingsManager.ControlMode.TILT:
			return _get_tilt_lateral()
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

func _shake_camera(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("shake"):
		cam.shake(amount)

func _body_recoil() -> void:
	var tween := create_tween()
	tween.tween_property($Character, "rotation_degrees",
		CHARACTER_BASE_ROT + Vector3(randf_range(-12.0, 12.0), 0.0, randf_range(-8.0, 8.0)), 0.05)
	tween.tween_property($Character, "rotation_degrees", CHARACTER_BASE_ROT, 0.15)

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
	elif Settings.control_mode == SettingsManager.ControlMode.TILT:
		var lateral: float = _get_tilt_lateral()
		linear_velocity.x = lerpf(linear_velocity.x, lateral * MAX_LATERAL_SPEED, delta * 6.0)
	else:
		var lateral: float = _get_lateral_input()
		if lateral != 0.0:
			apply_central_force(Vector3(lateral * LATERAL_FORCE, 0.0, 0.0))
		linear_velocity.x = clampf(linear_velocity.x, -MAX_LATERAL_SPEED, MAX_LATERAL_SPEED)
	if linear_velocity.y < -MAX_FALL_SPEED:
		linear_velocity.y = -MAX_FALL_SPEED
	Audio.set_whoosh_intensity(linear_velocity.y)

func _process(delta: float) -> void:
	if _is_dead or _parachute_active:
		return
	if _accel_debug_label:
		var ax: float = Input.get_accelerometer().x
		var gx: float = Input.get_gravity().x
		_accel_debug_label.text = "accel.x: %.2f\ngravity.x: %.2f" % [ax, gx]
	_sway_time += delta
	_jolt = move_toward(_jolt, 0.0, delta * 4.0)
	var lateral: float = linear_velocity.x
	# speed, phase, base_z, z_amp, x_amp, lat_z, jolt_z, jolt_x, base_x
	# lat_z positif car Character est flippé X=180° (Z local = -Z monde)
	# base_x positif = bras tirés légèrement vers l'arrière (vers la caméra)
	_apply_limb_sway($Character/ArmLeft,  lateral, delta, 3.1, 0.0,  115.0, 15.0,  7.0, 1.2,  40.0,  10.0, 22.0)
	_apply_limb_sway($Character/ArmRight, lateral, delta, 2.8, 1.7, -115.0, 13.0,  7.0, 1.2, -35.0, -18.0, 22.0)
	_apply_limb_sway($Character/LegLeft,  lateral, delta, 2.3, 0.9,  -35.0,  9.0, 10.0, 0.5, -22.0,  28.0)
	_apply_limb_sway($Character/LegRight, lateral, delta, 2.6, 2.4,   35.0,  8.0, 10.0, 0.5,  20.0, -24.0)
	_apply_limb_sway($Character/Head,     lateral, delta, 1.8, 3.2,    0.0,  8.0,  5.0, 0.4,  20.0,   8.0)

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
