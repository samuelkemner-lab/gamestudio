shader_type spatial;
// Kenney city buildings at night: dark facades, lit windows.
// Windows are the light-blue / blue cells of the Kenney colormap (only on walls, not roofs).
// per_building = true: every building gets one lighting mood (street level, no fragmented cells).
// per_building = false: random lit cells in world space (cheap, fine for the far skyline).

uniform sampler2D colormap : source_color, filter_linear_mipmap;
uniform vec3 warm_light : source_color = vec3(1.0, 0.78, 0.5);
uniform vec3 cool_light : source_color = vec3(0.6, 0.75, 1.0);
uniform float lit_chance = 0.35;
uniform float facade_brightness = 0.10;
uniform float window_energy = 0.9;
uniform float cell_size = 0.9;
uniform bool per_building = false;
uniform vec2 window_grid = vec2(2.6, 3.3);  // street level: lit pattern per window-sized cell

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = texture(colormap, UV).rgb;
	float wall = step(abs(world_normal.y), 0.5);
	float is_window = step(0.55, c.b) * step(0.08, c.b - c.r) * wall;
	vec3 seed;
	float frame = 1.0;
	if (per_building) {
		// horizontal coordinate along the facade, vertical by floor
		float along = abs(world_normal.x) > abs(world_normal.z) ? world_pos.z : world_pos.x;
		vec2 g = vec2(along / window_grid.x, world_pos.y / window_grid.y);
		vec3 b = floor(MODEL_MATRIX[3].xyz * 0.37);
		seed = b + vec3(floor(g), 0.0) * 1.7;
		frame = step(0.1, fract(g.x)) * step(0.16, fract(g.y));  // dark mullions between windows
	} else {
		seed = floor(world_pos / cell_size);
	}
	float h = hash(seed);
	float lit = step(h, lit_chance);
	vec3 col_seed = per_building ? floor(MODEL_MATRIX[3].xyz * 0.37) : seed;
	vec3 light_col = mix(warm_light, cool_light, step(0.72, hash(col_seed + 3.1)));
	ALBEDO = c * facade_brightness * (1.0 - is_window * 0.6);
	ROUGHNESS = 0.9;
	EMISSION = is_window * lit * frame * light_col * window_energy * (0.6 + 0.4 * hash(seed + 7.7));
}
