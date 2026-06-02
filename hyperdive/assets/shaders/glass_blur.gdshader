shader_type canvas_item;
// Backdrop-blur réutilisable pour le "verre" des boutons/panneaux.
// Posé DERRIÈRE l'élément (show_behind_parent) : il floute ce qui est déjà dessiné
// (le décor), puis le StyleBox translucide du bouton se pose par-dessus = effet givré.
//
// Astuce mutualisation : la taille du rect est déduite via fwidth(UV) (dérivée de l'UV
// par pixel écran), donc UN SEUL ShaderMaterial partagé suffit pour tous les boutons,
// quelle que soit leur taille — pas besoin d'uniform de taille par instance.

uniform float corner_radius : hint_range(0.0, 60.0) = 20.0; // doit matcher le thème
uniform float blur_radius : hint_range(0.0, 40.0) = 16.0;   // RAYON du disque de flou en px
                                                           // (reach max des taps). Augmenter =
                                                           // flou plus large, même nb de taps.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// Nb de taps du disque. Coût = nb de fetchs texture. 16 = compromis mobile (lisse + pas cher).
const int TAPS = 16;
const float GOLDEN_ANGLE = 2.39996323; // angle d'or → spirale de Vogel régulière

// SDF d'un rectangle à coins arrondis (espace pixels, centré).
float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Bruit pseudo-aléatoire 0..1 par pixel (sert à tourner le disque → casse tout motif résiduel).
float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
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

	// Échantillonnage en DISQUE DE VOGEL (spirale par angle d'or), PAS une grille carrée :
	// une grille régulière entre en résonance avec le motif de fenêtres du décor → moiré /
	// quadrillage. Le disque répartit les taps de façon homogène et apériodique. On tourne
	// le disque d'un angle pseudo-aléatoire par pixel pour transformer le moindre motif
	// résiduel en bruit fin (imperceptible) plutôt qu'en grille visible.
	float rot = hash12(SCREEN_UV) * 6.28318530718;
	vec3 c = vec3(0.0);
	for (int i = 0; i < TAPS; i++) {
		float fi = float(i) + 0.5;
		float r = sqrt(fi / float(TAPS));          // densité uniforme sur le disque
		float a = fi * GOLDEN_ANGLE + rot;
		vec2 off = vec2(cos(a), sin(a)) * r * blur_radius * SCREEN_PIXEL_SIZE;
		c += texture(screen_tex, SCREEN_UV + off).rgb;
	}
	c /= float(TAPS);

	COLOR = vec4(c, mask);
}
