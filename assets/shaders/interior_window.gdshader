shader_type spatial;
// REALISM R3: fake interior behind a window (interior mapping). One quad, no extra geometry:
// a ray from the camera is intersected with a virtual box room behind the glass.
// Per-window variation (lit / dark / TV, wall colour, curtains) comes from INSTANCE_CUSTOM
// (MultiMesh) or the window position. Frame + mullions are drawn on top, glass reflects SSR.

uniform vec2 win_size = vec2(1.2, 1.8);   // metres
uniform float room_depth = 1.6;            // relative to window width
uniform float lit_chance = 0.45;
uniform vec3 frame_color : source_color = vec3(0.86, 0.85, 0.82);
uniform float frame_width = 0.06;          // relative

varying vec3 obj_cam;
varying vec3 obj_pos;
varying vec4 custom;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	obj_pos = VERTEX;
	obj_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 uv = obj_pos.xy / win_size + 0.5;
	float seed = custom.x + hash(dot(floor(NODE_POSITION_WORLD * 3.0), vec3(1.0, 57.0, 113.0)));
	vec3 dir = normalize(obj_pos - obj_cam);
	vec3 d = vec3(dir.x / win_size.x, dir.y / win_size.y, dir.z / win_size.x);
	vec3 p = vec3(uv, 0.0);
	// box room: x,y in [0,1], z in [-depth, 0]
	float tx = d.x > 0.0 ? (1.0 - p.x) / d.x : -p.x / d.x;
	float ty = d.y > 0.0 ? (1.0 - p.y) / d.y : -p.y / d.y;
	float tz = (-room_depth - p.z) / min(d.z, -0.0001);
	float t = min(min(tx, ty), tz);
	vec3 h = p + d * t;

	float lit = step(hash(seed * 7.1), lit_chance);
	float tv = step(0.82, hash(seed * 3.3)) * (1.0 - lit);
	vec3 wall_cols[4] = vec3[4](vec3(0.74, 0.66, 0.52), vec3(0.55, 0.62, 0.55), vec3(0.5, 0.55, 0.66), vec3(0.8, 0.76, 0.7));
	vec3 wall = wall_cols[int(hash(seed * 5.7) * 4.0) % 4];
	vec3 col;
	if (t == tz) {
		col = wall;  // back wall
		// furniture silhouettes: a cabinet and a picture frame
		float cab_x = hash(seed * 2.1) * 0.5 + 0.1;
		if (h.x > cab_x && h.x < cab_x + 0.35 && h.y < 0.45) col = vec3(0.18, 0.13, 0.1);
		if (h.x > 0.62 && h.x < 0.82 && h.y > 0.55 && h.y < 0.75) col = vec3(0.3, 0.25, 0.4);
	} else if (t == tx) {
		col = wall * 0.75;  // side walls
		if (h.y < 0.4 && h.z < -0.4) col = vec3(0.25, 0.2, 0.17);  // sofa / bed edge
	} else {
		col = d.y < 0.0 ? vec3(0.32, 0.22, 0.15) : wall * 1.1;  // floor / ceiling
	}
	// light: ceiling lamp falloff (lit), flickering blue TV, or almost dark
	float lamp = 1.0 - clamp(length(vec2(h.x - 0.5, h.z + room_depth * 0.5)) * 0.9, 0.0, 1.0);
	vec3 lamp_col = mix(vec3(1.0, 0.72, 0.42), vec3(0.95, 0.95, 1.0), step(0.75, hash(seed * 9.9)));
	vec3 light = lit * lamp_col * (0.25 + 0.75 * lamp + 0.25 * step(0.5, h.y));
	float flick = 0.6 + 0.4 * sin(TIME * 7.0 + seed * 40.0) * sin(TIME * 2.3 + seed);
	light += tv * vec3(0.25, 0.4, 0.9) * flick * 0.6;
	light += vec3(0.012, 0.012, 0.02);
	vec3 interior = col * light;

	// curtains: half-drawn on one or both sides
	float cur = hash(seed * 4.4);
	float curtain = 0.0;
	if (cur > 0.35) curtain = step(uv.x, 0.18 + 0.1 * sin(uv.y * 40.0) * 0.1) + step(0.82, uv.x) * step(0.6, cur);
	vec3 curtain_col = mix(vec3(0.55, 0.15, 0.15), vec3(0.75, 0.7, 0.6), hash(seed * 6.6));
	interior = mix(interior, curtain_col * (lit * lamp_col * 0.55 + 0.02), clamp(curtain, 0.0, 1.0));

	// frame, mullion, transom
	float fw = frame_width;
	float fr = 1.0 - step(fw, uv.x) * step(uv.x, 1.0 - fw) * step(fw, uv.y) * step(uv.y, 1.0 - fw);
	fr = max(fr, 1.0 - step(fw * 0.5, abs(uv.x - 0.5)));
	fr = max(fr, (1.0 - step(fw * 0.5, abs(uv.y - 0.72))));
	ALBEDO = mix(vec3(0.02), frame_color * 0.35, fr);
	EMISSION = interior * (1.0 - fr) * 0.85;
	ROUGHNESS = mix(0.04, 0.6, fr);
	SPECULAR = mix(0.7, 0.3, fr);
	METALLIC = 0.0;
}
