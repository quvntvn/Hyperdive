extends RigidBody3D
class_name PlayerController

const LATERAL_FORCE: float = 25.0
const MAX_LATERAL_SPEED: float = 12.0
const MAX_FALL_SPEED: float = 18.0
const TILT_DEADZONE: float = 0.1
const TILT_SENSITIVITY: float = 0.25
const MAX_LIVES: int = 3
const INVINCIBILITY_TIME: float = 1.0
const TOUCH_FOLLOW_SPEED: float = 8.0

var _is_touching: bool = false
var _touch_target_x: float = 0.0
var lives: int = MAX_LIVES
var _invincibility_left: float = 0.0
var _is_dead: bool = false
var _base_skin_color: Color = Color.WHITE
var _trail_gradient: Gradient

signal life_lost(remaining_lives: int)
signal game_over

func _ready() -> void:
	Audio.play_whoosh()
	Settings.reset_run_stats()
	body_entered.connect(_on_body_entered)
	_apply_skin(Settings.equipped_skin)
	Settings.equipped_skin_changed.connect(_apply_skin)
	_update_damage_state(MAX_LIVES)
	_setup_fall_trail()
	_apply_trail()
	Settings.equipped_trail_changed.connect(func(_id: String) -> void: _apply_trail())

func _setup_fall_trail() -> void:
	var trail := GPUParticles3D.new()
	trail.name = "FallTrail"
	trail.amount = 40
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
	trail.draw_pass_1 = sphere

	add_child(trail)

func _apply_trail() -> void:
	if _trail_gradient == null:
		return
	var c: Color = Catalog.get_trail(Settings.equipped_trail)["color"]
	_trail_gradient.set_color(0, Color(c.r, c.g, c.b, 1.0))
	_trail_gradient.set_color(1, Color(c.r, c.g, c.b, 0.0))

func _apply_skin(skin_id: String) -> void:
	var skin: Dictionary = Catalog.get_skin_by_id(skin_id)
	_base_skin_color = skin["color"]
	var mat := $Character/Torso.material_override as StandardMaterial3D
	if mat:
		_update_body_color(lives)

func _on_body_entered(body: Node3D) -> void:
	if _invincibility_left > 0.0 or _is_dead:
		return
	if not body.is_in_group("obstacles"):
		return
	lives -= 1
	_update_damage_state(lives)
	_flash_hit()
	_shake_camera(0.3)
	_invincibility_left = INVINCIBILITY_TIME
	life_lost.emit(lives)
	Audio.play_hit()
	if lives <= 0:
		_is_dead = true
		_collapse_ragdoll()
		await get_tree().create_timer(0.4).timeout
		var distance: int = int(abs(global_position.y))
		Settings.update_best_distance(distance)
		Audio.play_game_over()
		game_over.emit()
		var go_screen := get_tree().get_first_node_in_group("game_over_screen")
		if go_screen:
			go_screen.show_game_over(distance)

func _collapse_ragdoll() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property($Character/ArmLeft, "rotation_degrees",
		Vector3(randf_range(-120.0, 120.0), 0.0, randf_range(-120.0, 120.0)), 0.4)
	tween.tween_property($Character/ArmRight, "rotation_degrees",
		Vector3(randf_range(-120.0, 120.0), 0.0, randf_range(-120.0, 120.0)), 0.4)
	tween.tween_property($Character/LegLeft, "rotation_degrees",
		Vector3(randf_range(-120.0, 120.0), 0.0, randf_range(-120.0, 120.0)), 0.4)
	tween.tween_property($Character/LegRight, "rotation_degrees",
		Vector3(randf_range(-120.0, 120.0), 0.0, randf_range(-120.0, 120.0)), 0.4)
	tween.tween_property($Character/Head, "rotation_degrees",
		Vector3(randf_range(-120.0, 120.0), 0.0, randf_range(-120.0, 120.0)), 0.4)
	tween.tween_property($Character, "rotation_degrees",
		Vector3(0.0, 0.0, randf_range(-60.0, 60.0)), 0.4)

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
	var accel_x: float = Input.get_accelerometer().x
	if abs(accel_x) < TILT_DEADZONE:
		return 0.0
	return clamp(accel_x * TILT_SENSITIVITY, -1.0, 1.0)

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

func _update_damage_state(p_lives: int) -> void:
	var arm_l := $Character/ArmLeft
	var arm_r := $Character/ArmRight
	var leg_r := $Character/LegRight
	var head := $Character/Head
	var arm_l_rot := Vector3.ZERO
	var arm_r_rot := Vector3.ZERO
	var leg_r_rot := Vector3.ZERO
	var head_rot := Vector3.ZERO
	match p_lives:
		2:
			arm_r_rot = Vector3(0, 0, -50)
		1:
			arm_r_rot = Vector3(0, 0, -90)
			arm_l_rot = Vector3(0, 0, 50)
			leg_r_rot = Vector3(35, 0, 0)
			head_rot = Vector3(0, 0, 25)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(arm_l, "rotation_degrees", arm_l_rot, 0.2)
	tween.tween_property(arm_r, "rotation_degrees", arm_r_rot, 0.2)
	tween.tween_property(leg_r, "rotation_degrees", leg_r_rot, 0.2)
	tween.tween_property(head, "rotation_degrees", head_rot, 0.2)
	_update_body_color(p_lives)

func _get_damage_color(p_lives: int) -> Color:
	var damage_t: float = 1.0 - float(p_lives) / float(MAX_LIVES)
	var bruised := Color(0.35, 0.28, 0.38)
	return _base_skin_color.lerp(bruised, damage_t * 0.5)

func _update_body_color(p_lives: int) -> void:
	var mat := $Character/Torso.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = _get_damage_color(p_lives)

func _flash_hit() -> void:
	var mat := $Character/Torso.material_override as StandardMaterial3D
	if mat == null:
		return
	var recover_color := _get_damage_color(lives)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", Color.WHITE, 0.05)
	tween.tween_property(mat, "albedo_color", recover_color, 0.10)

func _shake_camera(amount: float) -> void:
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("shake"):
		cam.shake(amount)

func _physics_process(delta: float) -> void:
	_invincibility_left = maxf(_invincibility_left - delta, 0.0)
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
	if linear_velocity.y < -MAX_FALL_SPEED:
		linear_velocity.y = -MAX_FALL_SPEED
	Audio.set_whoosh_intensity(linear_velocity.y)
