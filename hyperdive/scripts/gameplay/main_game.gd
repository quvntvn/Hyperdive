extends Node3D
class_name MainGame

var _campaign_timer: float = 0.0
var _campaign_active: bool = false
var _success_handled: bool = false
var _player_alive: bool = true

func _ready() -> void:
	_create_city_skyline()
	if Settings.active_mode != "campaign":
		return
	$CoinSpawner.set_process(false)
	($PowerupSpawner as PowerupSpawner).set_campaign_mode(true)
	_campaign_timer = Settings.get_level_duration(Settings.active_level)
	_campaign_active = true
	($GameHUD as GameHUD).set_campaign_mode(true)
	($Player as PlayerController).game_over.connect(func() -> void: _player_alive = false)

func _create_city_skyline() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		push_warning("[Skyline] Caméra introuvable — skyline non créée")
		return

	# Conteneur ancré à la caméra → position fixe à l'écran.
	var skyline := Node3D.new()
	skyline.name = "CitySkyline"
	cam.add_child(skyline)
	skyline.position = Vector3(0, -28, -40)

	# Couleur silhouette : bleu nuit doux de la palette, légèrement émissif.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("1F305E")
	mat.emission_enabled = true
	mat.emission = Color("1F305E")
	mat.emission_energy_multiplier = 0.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var building_count := 14
	var total_width := 34.0
	var spacing := total_width / float(building_count)
	var start_x := -total_width / 2.0 + spacing / 2.0

	# seed = 1962 → skyline identique à chaque partie (cohérente avec le thème).
	var rng := RandomNumberGenerator.new()
	rng.seed = 1962

	for i in building_count:
		var b := MeshInstance3D.new()
		var box := BoxMesh.new()
		var w: float = spacing * rng.randf_range(0.6, 0.9)
		var h: float = rng.randf_range(4.0, 12.0)
		box.size = Vector3(w, h, 2.0)
		b.mesh = box
		b.material_override = mat
		# Base alignée en bas, immeubles qui montent vers le haut.
		b.position = Vector3(start_x + float(i) * spacing, h / 2.0, 0.0)
		skyline.add_child(b)

	print("[Skyline] ", building_count, " immeubles créés, ancrés à la caméra")

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
