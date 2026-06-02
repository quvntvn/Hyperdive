shader_type canvas_item;
// Backdrop-blur réutilisable pour le "verre" des boutons/panneaux.
// Posé DERRIÈRE l'élément (show_behind_parent) : il floute ce qui est déjà dessiné
// (le décor), puis le StyleBox translucide du bouton se pose par-dessus = effet givré.
//
// Astuce mutualisation : la taille du rect est déduite via fwidth(UV) (dérivée de l'UV
// par pixel écran), donc UN SEUL ShaderMaterial partagé suffit pour tous les boutons,
// quelle que soit leur taille — pas besoin d'uniform de taille par instance.

uniform float corner_radius : hint_range(0.0, 60.0) = 20.0; // doit matcher le thème
uniform float blur_radius : hint_range(0.0, 16.0) = 6.0;    // FORT : espacement des taps du
                                                           // noyau gaussien 5x5 (reach ≈ 2x
                                                           // ce rayon). Augmenter = flou plus
                                                           // large, même nb de taps (coût fixe).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// SDF d'un rectangle à coins arrondis (espace pixels, centré).
float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
	// Taille du rect en pixels, déduite de la dérivée d'UV (1 / variation par pixel).
	vec2 rect_px = 1.0 / fwidth(UV);
	vec2 p = (UV - 0.5) * rect_px;
	float d = rounded_box(p, rect_px * 0.5, corner_radius);
	// Masque coins arrondis (antialiasé sur ~1.5px).
	float mask = 1.0 - smoothstep(-1.5, 1.5, d);
	if (mask < 0.004) {
		discard;
	}

	// Flou gaussien 5x5 (25 taps) — fort et bien diffus, mais lisse (pondération 1,4,6,4,1
	// par axe, somme 256 → pas de banding même avec un grand espacement de taps).
	vec2 o = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 c = vec3(0.0);
	// Ligne y=-2 (poids axe 1)
	c += texture(screen_tex, SCREEN_UV + vec2(-2.0, -2.0) * o).rgb *  1.0;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0, -2.0) * o).rgb *  4.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0, -2.0) * o).rgb *  6.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0, -2.0) * o).rgb *  4.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 2.0, -2.0) * o).rgb *  1.0;
	// Ligne y=-1 (poids axe 4)
	c += texture(screen_tex, SCREEN_UV + vec2(-2.0, -1.0) * o).rgb *  4.0;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0, -1.0) * o).rgb * 16.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0, -1.0) * o).rgb * 24.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0, -1.0) * o).rgb * 16.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 2.0, -1.0) * o).rgb *  4.0;
	// Ligne y=0 (poids axe 6)
	c += texture(screen_tex, SCREEN_UV + vec2(-2.0,  0.0) * o).rgb *  6.0;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0,  0.0) * o).rgb * 24.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0,  0.0) * o).rgb * 36.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0,  0.0) * o).rgb * 24.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 2.0,  0.0) * o).rgb *  6.0;
	// Ligne y=1 (poids axe 4)
	c += texture(screen_tex, SCREEN_UV + vec2(-2.0,  1.0) * o).rgb *  4.0;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0,  1.0) * o).rgb * 16.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0,  1.0) * o).rgb * 24.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0,  1.0) * o).rgb * 16.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 2.0,  1.0) * o).rgb *  4.0;
	// Ligne y=2 (poids axe 1)
	c += texture(screen_tex, SCREEN_UV + vec2(-2.0,  2.0) * o).rgb *  1.0;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0,  2.0) * o).rgb *  4.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0,  2.0) * o).rgb *  6.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0,  2.0) * o).rgb *  4.0;
	c += texture(screen_tex, SCREEN_UV + vec2( 2.0,  2.0) * o).rgb *  1.0;
	c /= 256.0;

	COLOR = vec4(c, mask);
}
