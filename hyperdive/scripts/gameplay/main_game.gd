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
	# Ville fixe en espace monde. N'est PAS enfant d'un nœud qui suit le joueur.
	# Les tops des bâtiments sont à CITY_Y ; ils descendent vers -Y.
	# Visible depuis le bas du couloir quand le joueur atteint ~player.y = CITY_Y + 42.
	const CITY_Y: float = -300.0
	const CITY_Z: float = 0.0
	var buildings: Array = [
		[-12.0, 9.0,  54.0],
		[ -8.5, 10.5, 84.0],
		[ -5.5, 7.5,  42.0],
		[ -2.5, 12.0, 72.0],
		[  0.5, 8.4,  60.0],
		[  3.5, 7.5,  96.0],
		[  6.5, 12.6, 78.0],
		[ 10.0, 7.5,  48.0],
		[ 13.5, 9.0,  66.0],
	]
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1.0, 0.0, 1.0)  # DEBUG: magenta vif
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.0, 1.0)
	bmat.emission_energy_multiplier = 5.0
	var root := Node3D.new()
	root.name = "CityBackground"
	add_child(root)
	for b in buildings:
		var bx: float = b[0]
		var bw: float = b[1]
		var bh: float = b[2]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(bw, bh, 4.0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = bmat
		# top du bâtiment à CITY_Y, bâtiment descend vers -Y
		mi.position = Vector3(bx, CITY_Y - bh * 0.5, CITY_Z)
		root.add_child(mi)
	var cam := $Camera3D as Camera3D
	var player_y: float = ($Player as Node3D).global_position.y
	print("[Ville DEBUG] CityBackground créé. CITY_Y=", CITY_Y, "  CITY_Z=", CITY_Z)
	print("[Ville DEBUG] Joueur spawn Y=", player_y)
	print("[Ville DEBUG] Camera3D far=", cam.far if cam else -1, "  fov=", cam.fov if cam else -1)
	print("[Ville DEBUG] Visible depuis ~player.y=", CITY_Y + 42.0,
		  " (quand le bas du frustum atteint Z=0 à Y=", CITY_Y, ")")

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
