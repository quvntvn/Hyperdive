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
	# Plus bas et plus loin pour remplir tout le bas de l'écran.
	skyline.position = Vector3(0, -34, -90)
	# Légère plongée pour voir les toits par-dessus (vue d'avion douce).
	skyline.rotation_degrees = Vector3(-45, 0, 0)

	# Matériau immeuble : bleu nuit sombre, avec fenêtres émissives via un shader.
	var mat := ShaderMaterial.new()
	mat.shader = _make_skyline_shader()
	mat.render_priority = -1

	var rng := RandomNumberGenerator.new()
	rng.seed = 1962

	# Grille d'immeubles HAUTS (la hauteur est sur Z car on regarde de haut).
	var cols := 15
	var rows := 12
	var cell := 6.0
	var grid_w := cols * cell
	var grid_d := rows * cell

	for ix in cols:
		for iz in rows:
			if rng.randf() < 0.12:
				continue
			var b := MeshInstance3D.new()
			var box := BoxMesh.new()
			var w: float = cell * rng.randf_range(0.6, 0.85)
			var d: float = cell * rng.randf_range(0.6, 0.85)
			var h: float = rng.randf_range(5.0, 16.0)
			box.size = Vector3(w, h, d)
			b.mesh = box
			b.material_override = mat
			var px: float = -grid_w / 2.0 + ix * cell + cell / 2.0
			var pz: float = -grid_d / 2.0 + iz * cell + cell / 2.0
			b.position = Vector3(px, h / 2.0, pz)
			skyline.add_child(b)

	print("[Skyline] ville 3D plongée ", cols, "x", rows, " fenêtres émissives")

# Shader simple : façade bleu nuit + fenêtres lumineuses en grille (jaune chaud).
func _make_skyline_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform vec3 facade_color : source_color = vec3(0.094, 0.141, 0.247);
uniform vec3 window_color : source_color = vec3(0.949, 0.757, 0.306);
uniform vec3 fog_color : source_color = vec3(0.5, 0.5, 0.55);
uniform float fog_start = 15.0;   // distance caméra où la brume commence
uniform float fog_end = 70.0;     // distance où tout est noyé dans la brume

varying float v_view_dist;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	// Distance du vertex à la caméra (en espace vue).
	v_view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec2 grid = UV * vec2(6.0, 14.0);
	vec2 cell = floor(grid);
	vec2 f = fract(grid);
	float win = step(0.2, f.x) * step(f.x, 0.8) * step(0.2, f.y) * step(f.y, 0.8);
	float lit = step(0.45, hash(cell));
	float w = win * lit;
	vec3 col = mix(facade_color, window_color, w * 0.9);

	// Brume : fondu vers fog_color selon la distance à la caméra.
	float fog = clamp((v_view_dist - fog_start) / (fog_end - fog_start), 0.0, 1.0);
	col = mix(col, fog_color, fog);

	// Transparence : les plus lointains deviennent aussi semi-transparents
	// → fondu vers le fond, rendu brumeux.
	float alpha = 1.0 - fog * 0.6;

	ALBEDO = col;
	ALPHA = alpha;
}
"""
	return sh

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
