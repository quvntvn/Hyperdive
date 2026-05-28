shader_type spatial;
render_mode unshaded, cull_back;

// Couleur de base du mur (contrôlée par le thème)
uniform vec3 wall_color : source_color = vec3(0.239, 0.173, 0.118);
// Lignes horizontales d'étages (contrôlées par le thème)
uniform vec3 line_color : source_color = vec3(0.949, 0.757, 0.306);
uniform float line_spacing : hint_range(0.5, 10.0) = 1.35;
uniform float line_thickness : hint_range(0.01, 0.5) = 0.04;
uniform float line_alpha : hint_range(0.0, 1.0) = 0.18;

// Grille de fenêtres
uniform vec2 win_cell = vec2(0.88, 1.35);       // taille d'une cellule en unités monde (hz, Y)
uniform vec2 win_size_rel = vec2(0.60, 0.66);   // fraction de la cellule occupée par la fenêtre
uniform float win_corner : hint_range(0.0, 0.45) = 0.14;  // rayon d'arrondi normalisé [0,1]
uniform vec3 win_lit_a : source_color = vec3(0.957, 0.914, 0.804); // crème (allumée)
uniform vec3 win_lit_b : source_color = vec3(0.949, 0.757, 0.306); // moutarde (allumée chaude)
uniform vec3 win_dark : source_color = vec3(0.075, 0.063, 0.047);  // éteinte
uniform float win_lit_ratio : hint_range(0.0, 1.0) = 0.62;         // proportion fenêtres allumées

varying vec3 world_position;
varying vec3 world_normal;

// Hash pseudo-aléatoire 2D → [0, 1]
float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Normale en espace monde pour identifier la face du BoxMesh
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float y = world_position.y;

	// Lignes horizontales (séparation d'étages, très subtiles)
	float line_pat = fract(y / line_spacing);
	float line_mask = step(1.0 - line_thickness / line_spacing, line_pat);
	vec3 color = mix(wall_color, line_color, line_mask * line_alpha);

	// Grille de fenêtres — axe horizontal selon la normale de la face :
	//   Face Z (avant/arrière du box, normale ≈ ±Z) : l'horizontal sur la surface est X
	//   Face X (côtés intérieurs, normale ≈ ±X)     : l'horizontal sur la surface est Z
	// Sans cette sélection, world_position.z est constant sur les faces Z
	// → toute la largeur obtient la même cellule → lignes verticales infinies.
	float is_z_face = step(0.5, abs(world_normal.z));
	float hz = mix(world_position.z, world_position.x, is_z_face);

	vec2 grid = vec2(hz / win_cell.x, y / win_cell.y);
	vec2 cell_id = floor(grid);
	vec2 cell_uv = fract(grid); // [0,1] dans la cellule

	// Fenêtre centrée dans la cellule → espace normalisé [-0.5, 0.5]
	vec2 margin = (vec2(1.0) - win_size_rel) * 0.5;
	vec2 win_local = (cell_uv - margin) / win_size_rel - 0.5;

	// SDF rectangle arrondi (rayon = win_corner dans l'espace [-0.5, 0.5])
	vec2 d = abs(win_local) - (0.5 - win_corner);
	float sdf = length(max(d, vec2(0.0))) - win_corner;
	float win_mask = smoothstep(0.025, -0.025, sdf);

	if (win_mask > 0.001) {
		float r = hash21(cell_id);
		float lit = step(1.0 - win_lit_ratio, r);
		// Mélange crème / moutarde pour varier la teinte des fenêtres allumées
		vec3 lit_color = mix(win_lit_a, win_lit_b, hash21(cell_id + vec2(7.3, 19.1)));
		vec3 win_color = mix(win_dark, lit_color, lit);
		color = mix(color, win_color, win_mask);
	}

	ALBEDO = color;
}
