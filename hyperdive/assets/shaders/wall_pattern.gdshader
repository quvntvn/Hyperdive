shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 wall_color : source_color = vec3(0.239, 0.173, 0.118);
uniform vec3 line_color : source_color = vec3(0.949, 0.757, 0.306);
uniform float line_spacing : hint_range(0.5, 10.0) = 2.0;
uniform float line_thickness : hint_range(0.01, 0.5) = 0.06;
uniform float line_alpha : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float y = world_position.y;
	float pattern = fract(y / line_spacing);
	float line_intensity = step(1.0 - line_thickness / line_spacing, pattern);

	vec3 color = mix(wall_color, line_color, line_intensity * line_alpha);
	ALBEDO = color;
}
