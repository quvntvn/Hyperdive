shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float halftone_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float halftone_size : hint_range(2.0, 20.0) = 6.0;
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.05;
// Effet RALENTI (piloté par le player) : assombrit/teinte les bords, désature légèrement,
// applique une teinte froide globale. À 0 = aucun effet (jeu normal). Centre toujours net.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 col = texture(screen_texture, uv).rgb;

    vec2 cell = floor(FRAGCOORD.xy / halftone_size);
    vec2 cell_uv = (FRAGCOORD.xy - cell * halftone_size) / halftone_size - 0.5;
    float dist = length(cell_uv);
    float luminance = dot(col, vec3(0.299, 0.587, 0.114));
    float dot_radius = 0.5 * (1.0 - luminance);
    float halftone = smoothstep(dot_radius + 0.05, dot_radius - 0.05, dist);

    col = mix(col, col * 0.4, halftone * halftone_intensity);

    float grain = (random(uv + fract(TIME * 0.5)) - 0.5) * grain_intensity;
    col += grain;

    // Désaturation globale (vers le gris) selon la luminance.
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(lum), desaturation);
    // Teinte froide globale (multiplicative, dosée par l'alpha de tint_color).
    col = mix(col, col * tint_color.rgb, tint_color.a);
    // Vignette : assombrit les BORDS, laisse le centre intact (lisibilité gameplay).
    float vd = length(uv - vec2(0.5)) * 1.414;
    float vig = 1.0 - vignette_strength * smoothstep(0.35, 0.95, vd);
    col *= vig;

    COLOR = vec4(col, 1.0);
}
