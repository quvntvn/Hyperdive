extends RigidBody3D
class_name PlayerController

const LATERAL_FORCE: float = 25.0
const MAX_LATERAL_SPEED: float = 12.0
const TILT_DEADZONE: float = 0.1
const TILT_SENSITIVITY: float = 0.25
const MAX_LIVES: int = 3
const INVINCIBILITY_TIME: float = 1.0

var _is_touching: bool = false
var _touch_x_normalized: float = 0.0
var lives: int = MAX_LIVES
var _invincibility_left: float = 0.0

signal life_lost(remaining_lives: int)
signal game_over

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("Player ready — contact_monitor=", contact_monitor, " max_contacts=", max_contacts_reported, " signal_connected=", body_entered.is_connected(_on_body_entered))

func _on_body_entered(body: Node3D) -> void:
	print("Collision avec ", body.name, " | groupes=", body.get_groups(), " | invincibility_left=", _invincibility_left, " | lives=", lives)
	if _invincibility_left > 0.0:
		return
	if not body.is_in_group("obstacles"):
		return
	lives -= 1
	_invincibility_left = INVINCIBILITY_TIME
	life_lost.emit(lives)
	if lives <= 0:
		game_over.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_is_touching = event.pressed
		if event.pressed:
			_touch_x_normalized = clamp(
				event.position.x / float(get_viewport().get_visible_rect().size.x),
				0.0, 1.0
			)
		else:
			_touch_x_normalized = 0.0
	elif event is InputEventScreenDrag:
		_touch_x_normalized = clamp(
			event.position.x / float(get_viewport().get_visible_rect().size.x),
			0.0, 1.0
		)
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

func _get_touch_lateral() -> float:
	if not _is_touching:
		return 0.0
	return (_touch_x_normalized - 0.5) * 2.0

func _get_tilt_lateral() -> float:
	var accel_x: float = Input.get_accelerometer().x
	if abs(accel_x) < TILT_DEADZONE:
		return 0.0
	return clamp(accel_x * TILT_SENSITIVITY, -1.0, 1.0)

func _get_lateral_input() -> float:
	match Settings.control_mode:
		SettingsManager.ControlMode.KEYBOARD:
			return Input.get_axis("move_left", "move_right")
		SettingsManager.ControlMode.TOUCH:
			return _get_touch_lateral()
		SettingsManager.ControlMode.TILT:
			return _get_tilt_lateral()
	return 0.0

func _physics_process(delta: float) -> void:
	_invincibility_left = maxf(_invincibility_left - delta, 0.0)
	var lateral: float = _get_lateral_input()
	if lateral != 0.0:
		apply_central_force(Vector3(lateral * LATERAL_FORCE, 0.0, 0.0))
	var vel: Vector3 = linear_velocity
	vel.x = clamp(vel.x, -MAX_LATERAL_SPEED, MAX_LATERAL_SPEED)
	linear_velocity = vel
