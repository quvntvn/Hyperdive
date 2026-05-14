# Keyboard controls are TEMPORARY for Phase A — replaced by touch drag (step 4) and tilt (step 5)
extends RigidBody3D
class_name PlayerController

const LATERAL_FORCE: float = 25.0
const MAX_LATERAL_SPEED: float = 12.0

var _frame: int = 0

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % 30 == 0:
		print("Player @ ", global_position)
	var force_x: float = 0.0
	if Input.is_action_pressed("move_left"):
		force_x -= LATERAL_FORCE
	if Input.is_action_pressed("move_right"):
		force_x += LATERAL_FORCE
	if force_x != 0.0:
		apply_central_force(Vector3(force_x, 0.0, 0.0))
	var vel: Vector3 = linear_velocity
	vel.x = clamp(vel.x, -MAX_LATERAL_SPEED, MAX_LATERAL_SPEED)
	linear_velocity = vel
