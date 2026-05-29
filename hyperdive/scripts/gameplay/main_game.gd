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

	var skyline := Node3D.new()
	skyline.name = "CitySkyline"
	cam.add_child(skyline)
	# Loin devant + bas de l'écran.
	skyline.position = Vector3(0, -30, -55)
	# CLÉ : incliner pour voir la ville EN PLONGÉE (comme vue d'avion),
	# pas de face. On bascule vers l'avant ~70°.
	skyline.rotation_degrees = Vector3(-70, 0, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("1F305E")
	mat.emission_enabled = true
	mat.emission = Color("1F305E")
	mat.emission_energy_multiplier = 0.35
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var rng := RandomNumberGenerator.new()
	rng.seed = 1962

	# Grille d'immeubles sur X (largeur) ET Z (profondeur) → vraie ville,
	# pas une rangée plate. Chaque immeuble est un bloc 3D de hauteur variée.
	var cols := 9
	var rows := 6
	var cell := 5.0
	var grid_w := cols * cell
	var grid_d := rows * cell

	for ix in cols:
		for iz in rows:
			if rng.randf() < 0.15:
				continue
			var b := MeshInstance3D.new()
			var box := BoxMesh.new()
			var w: float = cell * rng.randf_range(0.55, 0.8)
			var d: float = cell * rng.randf_range(0.55, 0.8)
			var h: float = rng.randf_range(3.0, 14.0)
			box.size = Vector3(w, h, d)
			b.mesh = box
			b.material_override = mat
			var px: float = -grid_w / 2.0 + ix * cell + cell / 2.0
			var pz: float = -grid_d / 2.0 + iz * cell + cell / 2.0
			b.position = Vector3(px, h / 2.0, pz)
			skyline.add_child(b)

	print("[Skyline] grille ville ", cols, "x", rows, " inclinée -70°, ancrée caméra")

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
