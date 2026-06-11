extends RefCounted
class_name CitySkyline

# Ville lointaine partagée entre le jeu (main_game) et le menu (main_menu).
# Crée une grille d'immeubles en plongée douce, ancrée à la caméra fournie, avec
# façade pilotée par la couleur du thème équipé + fenêtres jaunes + brume teintée.

# Construit la skyline et l'ajoute comme enfant de la caméra (donc fixe à l'écran).
# ascending = true (mode jetpack) : PAS de skyline du tout (ciel + murs suffisent).
# theme_override : id de thème IMPOSÉ (chapitre campagne, passé par main_game) ; "" = thème
# équipé. Le menu appelle sans argument → toujours le thème du joueur.
static func attach_to(cam: Camera3D, ascending: bool = false, theme_override: String = "") -> void:
	if cam == null:
		push_warning("[Skyline] Caméra introuvable — skyline non créée")
		return
	# Mode jetpack : aucune ville (le rendu en contre-plongée ne marchait pas).
	if ascending:
		return

	var skyline := Node3D.new()
	skyline.name = "CitySkyline"
	cam.add_child(skyline)
	# Position fixe à l'écran (enfant de la caméra → identique quel que soit l'angle
	# monde de la caméra). Plongée douce (-45°) : on voit les toits d'en haut.
	skyline.position = Vector3(0, -72, -90)
	skyline.rotation_degrees = Vector3(-45, 0, 0)
	print("[Skyline] mode=chute(plongée) pos=", skyline.position, " rot=", skyline.rotation_degrees)

	# Matériau immeuble : façade pilotée par la couleur du thème équipé (même source
	# que corridor_walls), fenêtres émissives jaunes via un shader.
	var mat := ShaderMaterial.new()
	mat.shader = _make_shader()
	# Couleur du thème : celui imposé par le chapitre campagne s'il y en a un, sinon le thème
	# équipé (même résolution que corridor_walls._apply_theme). Assombrie pour l'effet lointain.
	var theme: Dictionary = Catalog.get_theme(theme_override if theme_override != "" else Settings.equipped_theme)
	var theme_color: Color = theme["wall_color"]
	var facade: Color = theme_color * 0.5
	# Désaturer vers le gris sombre pour mettre le décor en retrait derrière le gameplay.
	facade = facade.lerp(Color(0.1, 0.1, 0.12), 0.3)
	mat.set_shader_parameter("facade_color", facade)
	# Brume = teinte du thème assombrie vers le noir (les lointains s'enfoncent dans l'ombre)
	var fog_tint: Color = theme_color.lerp(Color(0.0, 0.0, 0.0), 0.7)
	mat.set_shader_parameter("fog_color", fog_tint)

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
static func _make_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 facade_color : source_color = vec3(0.094, 0.141, 0.247);
uniform vec3 window_color : source_color = vec3(0.949, 0.757, 0.306);
uniform vec3 fog_color : source_color = vec3(0.5, 0.5, 0.55);

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
	// Fenêtres de la ville lointaine aussi discrètes que celles des murs proches :
	// intensité du mix 0.9 → 0.55 (≈ win_mix des murs) + window_color assombrie ×0.7.
	vec3 col = mix(facade_color, window_color * 0.7, w * 0.55);

	// Brume LÉGÈRE, seulement au fond, plafonnée à 0.5 (garde la ville lisible)
	float fog = clamp((v_view_dist - 55.0) / (110.0 - 55.0), 0.0, 1.0) * 0.5;
	col = mix(col, fog_color, fog);

	ALBEDO = col;
}
"""
	return sh
