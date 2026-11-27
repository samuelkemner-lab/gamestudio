shader_type spatial;
// Kenney city buildings at night: dark facades, random lit windows.
// Windows are the light-blue / blue cells of the Kenney colormap.

uniform sampler2D colormap : source_color, filter_linear_mipmap;
uniform vec3 warm_light : source_color = vec3(1.0, 0.78, 0.5);
uniform vec3 cool_light : source_color = vec3(0.6, 0.75, 1.0);
uniform float lit_chance = 0.35;
uniform float facade_brightness = 0.10;
uniform float window_energy = 0.9;
uniform float cell_size = 0.9;

varying vec3 world_pos;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(colormap, UV).rgb;
	float is_window = step(0.55, c.b) * step(0.08, c.b - c.r);
	float h = hash(floor(world_pos / cell_size));
	float lit = step(h, lit_chance);
	vec3 light_col = mix(warm_light, cool_light, step(0.72, hash(floor(world_pos / cell_size) + 3.1)));
	ALBEDO = c * facade_brightness * (1.0 - is_window * 0.6);
	ROUGHNESS = 0.9;
	EMISSION = is_window * lit * light_col * window_energy * (0.6 + 0.4 * hash(floor(world_pos / cell_size) + 7.7));
}
