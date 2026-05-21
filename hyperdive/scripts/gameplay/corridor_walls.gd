extends Node3D
class_name CorridorWalls

@export var target: Node3D
@export var target_path: NodePath

var _wall_material: ShaderMaterial

func _ready() -> void:
	if target == null and not target_path.is_empty():
		target = get_node_or_null(target_path)
	var left_mesh := $LeftWall/MeshInstance3D as MeshInstance3D
	var right_mesh := $RightWall/MeshInstance3D as MeshInstance3D
	_wall_material = (left_mesh.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	left_mesh.material_override = _wall_material
	right_mesh.material_override = _wall_material
	_apply_theme()
	Settings.equipped_theme_changed.connect(func(_id: String) -> void: _apply_theme())

func _process(_delta: float) -> void:
	if target == null:
		return
	global_position.y = target.global_position.y

func _apply_theme() -> void:
	var theme: Dictionary = Catalog.get_theme(Settings.equipped_theme)
	_wall_material.set_shader_parameter("wall_color", theme["wall_color"])
	_wall_material.set_shader_parameter("line_color", theme["line_color"])
	var world_env: WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null:
		return
	var sky_mat: ProceduralSkyMaterial = world_env.environment.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		return
	sky_mat.sky_top_color = theme["sky_top"]
	sky_mat.sky_horizon_color = theme["sky_horizon"]
