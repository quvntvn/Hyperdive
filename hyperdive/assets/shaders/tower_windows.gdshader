shader_type canvas_item;
// Jumeau 2D de wall_pattern.gdshader (qui est un shader SPATIAL, inutilisable sur de l'UI).
// Dessine une grille de fenêtres allumées/éteintes pseudo-aléatoires sur une colonne (tour),
// teintée par le thème (wall_color / line_color). Posé sur un ColorRect plein dans la carte
// campagne ; comme le ColorRect défile avec le scroll, le motif défile avec la tour.
//
// Le motif est calculé en pixels (UV * rect_size) → les fenêtres gardent une taille constante
// à l'écran quelle que soit la hauteur de la colonne. rect_size est poussé par le script.

uniform vec3 wall_color : source_color = vec3(0.19, 0.14, 0.06);
uniform vec3 line_color : source_color = vec3(0.949, 0.757, 0.306);
uniform vec2 rect_size = vec2(56.0, 2000.0);    // taille de la colonne en px (réglée au build)
uniform float cell_px : hint_range(14.0, 60.0) = 24.0;   // côté d'une cellule de fenêtre en px
uniform vec2 win_size_rel = vec2(0.58, 0.66);   // fraction de la cellule occupée par la fenêtre
uniform float win_corner : hint_range(0.0, 0.45) = 0.18; // arrondi normalisé de la fenêtre
uniform float win_lit_ratio : hint_range(0.0, 1.0) = 0.5;
uniform float win_mix : hint_range(0.0, 1.0) = 0.62;      // intensité du fondu fenêtre/mur
uniform vec3 win_lit_a : source_color = vec3(0.68, 0.65, 0.56);   // crème atténuée (allumée)
uniform vec3 win_lit_b : source_color = vec3(0.62, 0.50, 0.20);   // moutarde atténuée (allumée chaude)
uniform vec3 win_dark : source_color = vec3(0.10, 0.09, 0.07);    // éteinte
uniform float line_alpha : hint_range(0.0, 1.0) = 0.10;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.0;   // 0 = opaque ; >0 = bords fondus
uniform float seed = 1962.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 grid = px / cell_px;
	vec2 cell_id = floor(grid) + vec2(seed);
	vec2 cell_uv = fract(grid);

	vec3 color = wall_color;

	// Lignes d'étages très subtiles (séparation horizontale d'une cellule sur l'autre).
	float line_mask = step(0.94, cell_uv.y);
	color = mix(color, line_color, line_mask * line_alpha);

	// Fenêtre centrée dans la cellule (SDF rectangle arrondi, comme le shader 3D).
	vec2 margin = (vec2(1.0) - win_size_rel) * 0.5;
	vec2 win_local = (cell_uv - margin) / win_size_rel - 0.5;
	vec2 d = abs(win_local) - (0.5 - win_corner);
	float sdf = length(max(d, vec2(0.0))) - win_corner;
	float win_mask = smoothstep(0.05, -0.05, sdf);

	if (win_mask > 0.001) {
		float r = hash21(cell_id);
		float lit = step(1.0 - win_lit_ratio, r);
		vec3 lit_color = mix(win_lit_a, win_lit_b, hash21(cell_id + vec2(7.3, 19.1)));
		vec3 win_color = mix(win_dark, lit_color, lit);
		color = mix(color, win_color, win_mask * win_mix);
	}

	// Bord vertical adouci optionnel (pour fondre les tours dans le décor si voulu).
	float a = 1.0;
	if (edge_alpha > 0.0) {
		float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
		a = mix(1.0, edge, edge_alpha);
	}

	COLOR = vec4(color, a);
}
