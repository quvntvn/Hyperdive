shader_type canvas_item;
// Backdrop-blur réutilisable pour le "verre" des boutons/panneaux.
// Posé DERRIÈRE l'élément (show_behind_parent) : il floute ce qui est déjà dessiné
// (le décor), puis le StyleBox translucide du bouton se pose par-dessus = effet givré.
//
// Astuce mutualisation : la taille du rect est déduite via fwidth(UV) (dérivée de l'UV
// par pixel écran), donc UN SEUL ShaderMaterial partagé suffit pour tous les boutons,
// quelle que soit leur taille — pas besoin d'uniform de taille par instance.

uniform float corner_radius : hint_range(0.0, 60.0) = 18.0; // doit matcher le thème
uniform float blur_radius : hint_range(0.0, 8.0) = 3.6;     // MODÉRÉ ; élargir l'étalement
                                                           // ne coûte RIEN de plus (même
                                                           // nb de taps) mais rend le flou
                                                           // visible sur écran haute densité.
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

	// Box-blur 13 taps (3x3 + 4 cardinaux à 2x) — modéré mais visible.
	vec2 o = SCREEN_PIXEL_SIZE * blur_radius;
	vec3 c = vec3(0.0);
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0, -1.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0, -1.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0, -1.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0,  0.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0,  0.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0,  0.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2(-1.0,  1.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0,  1.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 1.0,  1.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0, -2.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 0.0,  2.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2(-2.0,  0.0) * o).rgb;
	c += texture(screen_tex, SCREEN_UV + vec2( 2.0,  0.0) * o).rgb;
	c /= 13.0;

	COLOR = vec4(c, mask);
}
