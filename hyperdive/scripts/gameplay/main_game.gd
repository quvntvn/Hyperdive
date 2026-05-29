extends Node3D
class_name MainGame

var _campaign_timer: float = 0.0
var _campaign_active: bool = false
var _success_handled: bool = false
var _player_alive: bool = true

func _ready() -> void:
	_create_debug_skyline()
	if Settings.active_mode != "campaign":
		return
	$CoinSpawner.set_process(false)
	($PowerupSpawner as PowerupSpawner).set_campaign_mode(true)
	_campaign_timer = Settings.get_level_duration(Settings.active_level)
	_campaign_active = true
	($GameHUD as GameHUD).set_campaign_mode(true)
	($Player as PlayerController).game_over.connect(func() -> void: _player_alive = false)

func _create_debug_skyline() -> void:
	var city := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(80, 20, 5)
	city.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 1)
	mat.emission_enabled = true
	mat.emission = Color(1, 0, 1)
	mat.emission_energy_multiplier = 2.0
	city.material_override = mat

	# Joueur tombe sur -Y (player.gd : linear_velocity.y = -MAX_FALL_SPEED).
	# La ville est placée sur l'axe de PROFONDEUR (-Z, loin devant la caméra),
	# pas sur -Y → le joueur en chute ne peut jamais l'atteindre physiquement.
	# MeshInstance3D sans CollisionShape = aucune interaction physique.
	city.position = Vector3(0, -50, -200)
	add_child(city)

	print("[Axes] Joueur tombe sur -Y (linear_velocity.y = -MAX_FALL_SPEED)")
	print("[Skyline] city world pos =", city.global_position)
	var cam := get_viewport().get_camera_3d()
	if cam:
		print("[Camera] pos=", cam.global_position, "  rotation=", cam.rotation_degrees)

func _process(delta: float) -> void:
	if not _campaign_active or _success_handled or not _player_alive:
		return
	_campaign_timer -= delta
	($GameHUD as GameHUD).update_campaign_time(maxf(_campaign_timer, 0.0))
	if _campaign_timer <= 0.0:
		_on_campaign_success()

func _on_campaign_success() -> void:
	_success_handled = true
	_campaign_active = false
	($Player as PlayerController)._on_level_survived()
