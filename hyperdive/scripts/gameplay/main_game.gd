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
	# Face caméra, en bas de l'écran, loin en profondeur. PAS d'inclinaison.
	skyline.position = Vector3(0, -24, -50)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1962

	# On construit un ruban de tours collées : chaque tour = un quad (2 triangles).
	# Bases toutes alignées sur y=0, sommets de hauteurs variées → profil en dents.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var total_width := 60.0
	var tower_count := 22
	var tw := total_width / float(tower_count)   # largeur d'une tour
	var x := -total_width / 2.0

	for i in tower_count:
		var h: float = rng.randf_range(6.0, 22.0)   # hauteur variée
		var x0 := x
		var x1 := x + tw
		# 4 coins de la tour (quad vertical, face +Z vers la caméra)
		var bl := Vector3(x0, 0, 0)
		var br := Vector3(x1, 0, 0)
		var tl := Vector3(x0, h, 0)
		var tr := Vector3(x1, h, 0)
		# triangle 1
		st.add_vertex(bl); st.add_vertex(tl); st.add_vertex(tr)
		# triangle 2
		st.add_vertex(bl); st.add_vertex(tr); st.add_vertex(br)
		x = x1

	st.generate_normals()
	var mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	# Silhouette sombre : bleu nuit, à peine plus clair que le fond → lointain.
	mat.albedo_color = Color("18243F")    # bleu nuit assombri
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # visible des deux côtés
	mi.material_override = mat
	skyline.add_child(mi)

	print("[Skyline] silhouette plate ", tower_count, " tours, face caméra")

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
