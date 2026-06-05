extends Area3D
class_name Powerup

const ROTATION_SPEED: float = 2.0
const EMISSION_BASE: float = 1.8
const EMISSION_PULSE: float = 0.25
const PULSE_SPEED: float = 2.2
const FLOAT_AMP: float = 0.12        # amplitude du flottement vertical (rend l'objet vivant)
const FLOAT_SPEED: float = 2.0
const COLORS: Dictionary = {
	"shield": Color(0.235, 0.682, 0.639, 1.0),   # turquoise #3CAEA3
	"slowmo": Color(0.122, 0.188, 0.369, 1.0),   # bleu nuit #1F305E
	"magnet": Color(0.949, 0.757, 0.306, 1.0),   # jaune moutarde #F2C14E
	"boost": Color(0.914, 0.310, 0.216, 1.0),    # orange #E94F37
	"megaboost": Color(0.69, 0.149, 1.0, 1.0),   # magenta/violet #B026FF (jackpot rare)
}
const CREAM: Color = Color(0.957, 0.914, 0.804, 1.0)   # crème #F4E9CD (accents lisibles)

@export var type: String = "shield"

var _pulse_time: float = 0.0
var _float_time: float = 0.0
var _body_meshes: Array[MeshInstance3D] = []
var _halo_mi: MeshInstance3D
var _visual: Node3D            # pivot qui porte tous les meshes : tourne + flotte + "pop"
var _collected: bool = false

func _ready() -> void:
	add_to_group("powerups")
	body_entered.connect(_on_body_entered)
	_visual = Node3D.new()
	add_child(_visual)
	_build_mesh()
	_add_halo()

func _make_mat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = EMISSION_BASE
	return mat

# Contour lumineux : même mesh agrandi rendu faces arrière uniquement (outline classique).
func _make_rim_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.4)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	return mat

func _add_mi(mesh: Mesh, offset: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO,
		color_override: Color = Color(0, 0, 0, 0)) -> void:
	var c: Color = color_override if color_override.a > 0.0 else COLORS.get(type, Color.WHITE)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_mat(c)
	mi.position = offset
	mi.rotation_degrees = rot_deg
	_visual.add_child(mi)
	_body_meshes.append(mi)
	# Liseré lumineux : copie légèrement agrandie rendue dos-à-caméra.
	var rim := MeshInstance3D.new()
	rim.mesh = mesh
	rim.scale = Vector3.ONE * 1.10
	rim.material_override = _make_rim_mat()
	rim.position = offset
	rim.rotation_degrees = rot_deg
	_visual.add_child(rim)

func _build_mesh() -> void:
	match type:
		"shield":
			# Bulle de protection : cœur sphérique turquoise + anneau orbital plus clair.
			var core := SphereMesh.new()
			core.radius = 0.22
			core.height = 0.44
			core.radial_segments = 12
			core.rings = 6
			_add_mi(core)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.30
			ring.outer_radius = 0.36
			ring.rings = 16
			ring.ring_segments = 8
			_add_mi(ring, Vector3.ZERO, Vector3(80.0, 0.0, 0.0))
		"slowmo":
			# Sablier (2 cônes) + accents CRÈME pour ressortir sur fond sombre (bleu nuit seul = invisible).
			var top_cone := CylinderMesh.new()
			top_cone.top_radius = 0.25
			top_cone.bottom_radius = 0.0
			top_cone.height = 0.28
			_add_mi(top_cone, Vector3(0.0, 0.14, 0.0))
			var bot_cone := CylinderMesh.new()
			bot_cone.top_radius = 0.0
			bot_cone.bottom_radius = 0.25
			bot_cone.height = 0.28
			_add_mi(bot_cone, Vector3(0.0, -0.14, 0.0))
			# Plateaux crème haut/bas = lisibilité.
			var cap := CylinderMesh.new()
			cap.top_radius = 0.27
			cap.bottom_radius = 0.27
			cap.height = 0.04
			_add_mi(cap, Vector3(0.0, 0.28, 0.0), Vector3.ZERO, CREAM)
			_add_mi(cap, Vector3(0.0, -0.28, 0.0), Vector3.ZERO, CREAM)
		"magnet":
			# Fer à cheval (U) jaune avec embouts CRÈME (lit "aimant").
			var arm := CylinderMesh.new()
			arm.top_radius = 0.065
			arm.bottom_radius = 0.065
			arm.height = 0.30
			_add_mi(arm, Vector3(-0.15, 0.0, 0.0))
			_add_mi(arm, Vector3(0.15, 0.0, 0.0))
			var bar := CylinderMesh.new()
			bar.top_radius = 0.065
			bar.bottom_radius = 0.065
			bar.height = 0.30
			_add_mi(bar, Vector3(0.0, 0.15, 0.0), Vector3(0.0, 0.0, 90.0))
			# Embouts crème (les "pôles").
			var tip := CylinderMesh.new()
			tip.top_radius = 0.085
			tip.bottom_radius = 0.085
			tip.height = 0.05
			_add_mi(tip, Vector3(-0.15, -0.15, 0.0), Vector3.ZERO, CREAM)
			_add_mi(tip, Vector3(0.15, -0.15, 0.0), Vector3.ZERO, CREAM)
		"boost", "megaboost":
			# Flèche/fusée orientée verticalement (orange = boost, magenta = méga-boost).
			var cone := CylinderMesh.new()
			cone.top_radius = 0.26
			cone.bottom_radius = 0.0
			cone.height = 0.38
			_add_mi(cone)
			var tail := CylinderMesh.new()
			tail.top_radius = 0.10
			tail.bottom_radius = 0.10
			tail.height = 0.07
			_add_mi(tail, Vector3(0.0, 0.225, 0.0))

func _add_halo() -> void:
	# Méga-boost : halo PLUS GROS et PLUS lumineux → on voit tout de suite que c'est le rare.
	var mega: bool = type == "megaboost"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.54 if mega else 0.42
	torus.outer_radius = 0.70 if mega else 0.52
	torus.rings = 16
	torus.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	# Ralenti : halo CRÈME (le bleu nuit serait sombre/invisible). Les autres : couleur du type.
	var c: Color = CREAM if type == "slowmo" else COLORS.get(type, Color.WHITE)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(c.r, c.g, c.b, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 5.0 if mega else 3.5
	mi.material_override = mat
	_visual.add_child(mi)
	_halo_mi = mi

func _process(delta: float) -> void:
	if _collected:
		return
	_visual.rotation.y += ROTATION_SPEED * delta
	_float_time += delta
	_visual.position.y = sin(_float_time * FLOAT_SPEED) * FLOAT_AMP
	_pulse_time += delta
	var pulse: float = EMISSION_PULSE * sin(_pulse_time * PULSE_SPEED)
	for mi: MeshInstance3D in _body_meshes:
		var mat := mi.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = EMISSION_BASE + pulse
	if _halo_mi != null:
		var hmat := _halo_mi.material_override as StandardMaterial3D
		if hmat != null:
			hmat.emission_energy_multiplier = 3.5 + pulse * 2.0

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body is PlayerController:
		_collected = true
		(body as PlayerController).collect_powerup(type)
		_juicy_pickup()

# Ramassage "marqué mais sobre" : son dédié + vibration + flash écran + shake léger + pop de
# l'objet + burst de particules renforcé. Le moment de récompense doit claquer.
func _juicy_pickup() -> void:
	var c: Color = COLORS.get(type, Color.WHITE)
	# Le méga-boost réutilise le son du boost (pas de SFX dédié). Vibration plus marquée (jackpot).
	Audio.play_powerup("boost" if type == "megaboost" else type)
	Settings.vibrate(70 if type == "megaboost" else (40 if type == "boost" else 35))
	var pp := get_tree().get_first_node_in_group("post_process")
	if pp != null and pp.has_method("flash"):
		pp.flash(c)
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam != null and cam.has_method("shake"):
		cam.shake(0.1)
	_spawn_burst()
	# Pop : l'objet gonfle vite puis disparaît (au lieu de s'effacer sèchement).
	monitoring = false
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ONE * 1.8, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_visual, "position:y", _visual.position.y + 0.4, 0.12)
	tw.tween_callback(queue_free)

func _spawn_burst() -> void:
	var mega: bool = type == "megaboost"
	var burst := GPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 60 if mega else 28        # méga-boost : burst de ramassage bien plus dense
	burst.lifetime = 0.7 if mega else 0.55
	burst.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 90.0
	mat.initial_velocity_min = 5.0 if mega else 4.0
	mat.initial_velocity_max = 12.0 if mega else 8.0
	mat.gravity = Vector3(0.0, -3.0, 0.0)
	mat.scale_min = 0.12
	mat.scale_max = 0.28
	mat.color = COLORS.get(type, Color.WHITE)
	burst.process_material = mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	burst.draw_pass_1 = sphere

	var scene_root := get_tree().current_scene
	scene_root.add_child(burst)
	burst.global_position = global_position
	get_tree().create_timer(0.8).timeout.connect(burst.queue_free)
