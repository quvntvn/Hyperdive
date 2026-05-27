extends Area3D
class_name Powerup

const ROTATION_SPEED: float = 2.0
const COLORS: Dictionary = {
	"shield": Color(0.235, 0.682, 0.639, 1.0),
	"slowmo": Color(0.122, 0.188, 0.369, 1.0),
	"magnet": Color(0.949, 0.757, 0.306, 1.0),
}

@export var type: String = "shield"

func _ready() -> void:
	add_to_group("powerups")
	body_entered.connect(_on_body_entered)
	_apply_color()

func _apply_color() -> void:
	var mi := $MeshInstance3D as MeshInstance3D
	if mi == null or mi.material_override == null:
		return
	var mat: StandardMaterial3D = mi.material_override.duplicate()
	mi.material_override = mat
	var c: Color = COLORS.get(type, Color.WHITE)
	mat.albedo_color = c
	mat.emission = c

func _process(delta: float) -> void:
	rotation.y += ROTATION_SPEED * delta

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		(body as PlayerController).collect_powerup(type)
		_spawn_burst()
		queue_free()

func _spawn_burst() -> void:
	var burst := GPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 16
	burst.lifetime = 0.5
	burst.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 80.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0.0, -3.0, 0.0)
	mat.scale_min = 0.12
	mat.scale_max = 0.25
	mat.color = COLORS.get(type, Color.WHITE)
	burst.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	burst.draw_pass_1 = sphere

	var scene_root := get_tree().current_scene
	scene_root.add_child(burst)
	burst.global_position = global_position
	get_tree().create_timer(0.7).timeout.connect(burst.queue_free)
