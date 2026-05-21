extends Area3D
class_name Coin

const ROTATION_SPEED: float = 3.0

func _ready() -> void:
	add_to_group("coins")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	rotation.y += ROTATION_SPEED * delta

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		Settings.add_coin()
		Audio.play_coin()
		_spawn_burst()
		queue_free()

func _spawn_burst() -> void:
	var burst := GPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 12
	burst.lifetime = 0.4
	burst.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0.0, -3.0, 0.0)
	mat.scale_min = 0.1
	mat.scale_max = 0.2
	mat.color = Color(0.949, 0.757, 0.306, 1.0)
	burst.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	burst.draw_pass_1 = sphere

	var scene_root := get_tree().current_scene
	scene_root.add_child(burst)
	burst.global_position = global_position

	get_tree().create_timer(0.6).timeout.connect(burst.queue_free)
