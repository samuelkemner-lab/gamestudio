shader_type spatial;
// Far-skyline towers (Rotterdam-style): curtain wall with floors, mullions and lit offices/flats.
// Works in object space, so rotated or leaning boxes keep a straight window grid.
// Meshes must be built at real size (no node scale): 1 unit = 1 metre.

uniform vec3 facade : source_color = vec3(0.06, 0.07, 0.09);  // spandrels / frame
uniform vec3 glass : source_color = vec3(0.02, 0.03, 0.05);
uniform vec3 warm_light : source_color = vec3(1.0, 0.78, 0.52);
uniform vec3 cool_light : source_color = vec3(0.66, 0.8, 1.0);
uniform float lit_chance = 0.3;
uniform float cool_ratio = 0.3;
uniform float window_energy = 0.75;
uniform float floor_h = 3.6;
uniform float col_w = 1.8;
uniform float glass_frac = 0.72;  // how much of a floor is glass (rest = spandrel band)
uniform float mullion = 0.12;
uniform float bands = 0.0;  // >0: horizontal colour bands every n floors (e.g. the red-striped tower)
uniform vec3 band_color : source_color = vec3(0.6, 0.08, 0.06);
uniform float led_grid = 0.0;  // 1 = facade of LED dots (the leaning telecom tower)
uniform vec3 led_color : source_color = vec3(0.75, 0.95, 1.0);
uniform float seed = 0.0;

varying vec3 lpos;
varying vec3 lnorm;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
}

void fragment() {
	float wall = step(abs(lnorm.y), 0.5);
	float along = abs(lnorm.x) > abs(lnorm.z) ? lpos.z : lpos.x;
	float side = abs(lnorm.x) > abs(lnorm.z) ? sign(lnorm.x) * 2.0 : sign(lnorm.z) * 3.0;
	vec2 g = vec2(along / col_w, lpos.y / floor_h);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float is_glass = step(mullion, f.x) * step(f.y, glass_frac) * wall;
	// offices light up in clusters: whole rows of a few columns share a state
	vec3 cluster = vec3(floor(cell.x / 3.0), cell.y, side + seed);
	float lit = step(hash(cluster), lit_chance) * step(0.35, hash(vec3(cell, side + seed + 1.3)));
	vec3 lc = mix(warm_light, cool_light, step(1.0 - cool_ratio, hash(cluster + 4.1)));
	vec3 base = mix(facade, glass, is_glass);
	if (bands > 0.0) {
		float b = step(mod(cell.y, bands), 0.5) * (1.0 - is_glass) * wall;
		base = mix(base, band_color, b);
	}
	ALBEDO = base;
	ROUGHNESS = mix(0.8, 0.12, is_glass);
	METALLIC = is_glass * 0.4;
	vec3 em = is_glass * lit * lc * window_energy * (0.55 + 0.45 * hash(vec3(cell, seed + 9.0)));
	if (led_grid > 0.5) {
		vec2 d = fract(vec2(along, lpos.y) / 1.2) - 0.5;
		float dot_on = step(length(d), 0.22) * wall;
		// slow diagonal wave so the facade looks alive
		float wave = 0.5 + 0.5 * sin(along * 0.12 + lpos.y * 0.08 - TIME * 0.8);
		em = dot_on * led_color * (0.08 + 0.9 * wave * wave);
		ALBEDO = facade;
	}
	EMISSION = em;
}
