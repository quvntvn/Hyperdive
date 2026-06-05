extends Area3D
class_name Coin

const ROTATION_SPEED: float = 3.0

# Ressources du burst partagées entre TOUTES les pièces : créées une seule fois.
# Avant, chaque ramassage allouait un nouveau ParticleProcessMaterial + SphereMesh
# (et recompilait le shader de particules). En les mettant en commun, le shader
# se compile une fois et il n'y a plus d'allocation lourde par pièce.
static var _burst_mat: ParticleProcessMaterial
static var _burst_mesh: SphereMesh

static func _ensure_burst_resources() -> void:
	if _burst_mat != null:
		return
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0.0, -3.0, 0.0)
	mat.scale_min = 0.1
	mat.scale_max = 0.2
	mat.color = Color(0.949, 0.757, 0.306, 1.0)
	_burst_mat = mat
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	_burst_mesh = sphere

func _ready() -> void:
	add_to_group("coins")
	body_entered.connect(_on_body_entered)
	_ensure_burst_resources()

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
	burst.process_material = _burst_mat   # ressources partagées (pas de nouvelle alloc)
	burst.draw_pass_1 = _burst_mesh
	var scene_root := get_tree().current_scene
	scene_root.add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	get_tree().create_timer(0.6).timeout.connect(burst.queue_free)
