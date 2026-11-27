shader_type spatial;
// REALISM R2: Kenney models next to PBR surfaces. Desaturate the toy colours, add gloss
// (car paint reflects the wet street) and a touch of grime so they sit in the same world.

uniform sampler2D colormap : source_color, filter_linear_mipmap;
uniform float saturation = 0.78;
uniform float value = 0.85;
uniform float roughness_base = 0.4;
uniform float metallic_base = 0.15;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(colormap, UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, saturation) * value;
	// lower parts get dirtier (road spray)
	float low = smoothstep(0.9, 0.0, wpos.y);
	c *= mix(1.0, 0.75, low);
	ALBEDO = c;
	ROUGHNESS = roughness_base + low * 0.3 + hash(floor(wpos.xz * 3.0)) * 0.05;
	METALLIC = metallic_base;
}
