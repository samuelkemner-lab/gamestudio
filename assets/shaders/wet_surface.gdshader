shader_type spatial;
// REALISM R2: PBR ground/wall surface projected in world space (no UVs needed),
// with wetness (darker + glossier) and puddles that turn into mirrors for neon and street lights.
// Rain adds animated ripple rings inside the puddles.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tile_size = 3.0;          // metres per texture repeat
uniform float normal_strength = 0.5;
uniform float wetness : hint_range(0.0, 1.0) = 0.6;
uniform float puddles : hint_range(0.0, 1.0) = 0.5;  // how much of the flat ground becomes puddle
uniform float puddle_scale = 0.18;
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform float dirt : hint_range(0.0, 1.0) = 0.35;    // large-scale grime variation (breaks tiling)

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(wnrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec2 uv_top = wpos.xz / tile_size;
	vec2 uv_x = wpos.zy / tile_size;
	vec2 uv_z = wpos.xy / tile_size;
	vec3 alb = texture(albedo_tex, uv_top).rgb * w.y + texture(albedo_tex, uv_x).rgb * w.x + texture(albedo_tex, uv_z).rgb * w.z;
	float rough = texture(rough_tex, uv_top).g * w.y + texture(rough_tex, uv_x).g * w.x + texture(rough_tex, uv_z).g * w.z;

	// grime: big soft patches so the texture never looks like a repeating tile
	float g = fbm(wpos.xz * 0.07 + wpos.y * 0.05);
	alb *= mix(1.0, mix(0.72, 1.08, g), dirt);

	// puddles only on flat, upward-facing ground
	float flat_ground = smoothstep(0.85, 0.98, wnrm.y);
	float pn = fbm(wpos.xz * puddle_scale);
	float puddle = smoothstep(1.0 - puddles * 0.55, 1.0 - puddles * 0.55 + 0.06, pn) * flat_ground * wetness;

	float damp = wetness * mix(0.6, 1.0, g);
	ALBEDO = alb * tint * mix(1.0, 0.58, damp) * mix(1.0, 0.7, puddle);
	ROUGHNESS = mix(mix(rough, rough * 0.4, damp), 0.03, puddle);
	SPECULAR = 0.5;
	METALLIC = 0.0;

	vec3 nm = texture(normal_tex, uv_top).rgb;
	// rain ripples: expanding rings in the puddles
	if (rain > 0.0) {
		vec2 cell = floor(wpos.xz * 2.0);
		vec2 local = fract(wpos.xz * 2.0) - 0.5;
		float t = fract(TIME * 1.3 + hash(cell));
		float r = length(local);
		float ring = sin((r - t * 0.5) * 60.0) * smoothstep(0.5, 0.0, r) * (1.0 - t) * step(r, t * 0.5 + 0.02);
		nm.xy += normalize(local + 0.0001) * ring * 0.25 * rain * puddle;
	}
	NORMAL_MAP = mix(nm, vec3(0.5, 0.5, 1.0), puddle * 0.85);
	NORMAL_MAP_DEPTH = normal_strength * w.y + 0.15;
}
