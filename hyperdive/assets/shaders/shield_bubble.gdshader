shader_type spatial;
// Bulle de bouclier : transparente au centre, lumineuse sur les BORDS (Fresnel) → on voit
// clairement la protection sans masquer le perso ni la vue des obstacles. Additif = glow.
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 bubble_color : source_color = vec4(0.235, 0.682, 0.639, 1.0);
uniform float rim_power = 2.5;
uniform float base_alpha = 0.05;
uniform float pulse = 1.0;

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	ALBEDO = bubble_color.rgb;
	EMISSION = bubble_color.rgb * (0.3 + f * 1.6) * pulse;
	ALPHA = clamp(base_alpha + f, 0.0, 1.0) * pulse;
}
