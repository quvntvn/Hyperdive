shader_type canvas_item;
// Lignes de vitesse (boost) : stries radiales lumineuses sur les BORDS, centre dégagé →
// sensation d'hyper-vitesse sans masquer où on va. Additif. strength 0 = invisible.
render_mode blend_add;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(0.914, 0.310, 0.216, 1.0);

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV - vec2(0.5);
	float ang = atan(uv.y, uv.x);
	float rad = length(uv);
	// Stries : ~64 secteurs, certains allumés (hash) + scintillement temporel.
	float sector = floor((ang + 3.14159) / 6.28318 * 64.0);
	float on = step(0.55, hash(sector) + 0.15 * sin(TIME * 8.0 + sector));
	float w = smoothstep(0.45, 0.95, abs(sin(ang * 64.0)));
	// Fondu : rien au centre, fort vers l'extérieur.
	float edge = smoothstep(0.18, 0.6, rad);
	float a = on * w * edge * strength;
	COLOR = vec4(line_color.rgb * a, a);
}
