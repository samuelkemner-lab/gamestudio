class_name CityBuilder
extends RoomBuilder
## The outside world: "Zuidkade", a night street in a Rotterdam-like harbour city.
## Shops you can visit (music store, coffeeshop, snackbar, night shop, casino, pro studio),
## your flat (Kade 17), parked + driving cars, pedestrians, the quay with the river and a bridge.
## Models: Kenney City Kit Commercial / Roads, Car Kit, Retro Urban Kit (CC0). Everything else procedural.
## Local axes: main street runs along X (z = 0). North side front line z = -LINE, south side z = +LINE.

const ROADS := "res://assets/models/kenney_roads/%s.glb"
const CARS := "res://assets/models/kenney_cars/%s.glb"
const RETRO := "res://assets/models/kenney_retro_urban/%s.glb"
const ROAD_HW := 6.0  # half width of the main road
const LINE := 10.0  # building line (road + 4 m sidewalk)
const X_MIN := -70.0
const X_MAX := 70.0
const CROSS_X := 20.0  # side street to the quay
const QUAY_Z := 34.0
const WATER_Z := 40.0
const BSCALE := 11.0  # Kenney commercial buildings -> metres
const CAR_SCALE := 1.7

## Shops: id, name, x, side (-1 north / +1 south), width, colour, window colour, small text, door label
const SHOPS := [
	{"id": "home", "name": "KADE 17", "x": -42.0, "side": -1, "w": 10.0, "color": Color("ffb070"), "glass": Color("ffcf9a"), "sub": "7TH FLOOR · YOUR FLAT", "door": "Go home (Kade 17)"},
	{"id": "music", "name": "WAX & WIRES", "x": -28.0, "side": -1, "w": 11.0, "color": Color("25d9f5"), "glass": Color("5fe3ff"), "sub": "MUSIC GEAR · SYNTHS · KITS", "door": "Enter Wax & Wires (music store)"},
	{"id": "coffeeshop", "name": "GROENE WOLK", "x": -14.0, "side": -1, "w": 11.0, "color": Color("4ade80"), "glass": Color("7dffa8"), "sub": "COFFEESHOP · 18+", "door": "Enter Groene Wolk (coffeeshop)"},
	{"id": "snackbar", "name": "SNACKBAR DE HOEK", "x": 0.0, "side": -1, "w": 11.0, "color": Color("fbbf24"), "glass": Color("ffe08a"), "sub": "KAPSALON · FRIKANDEL · FRIET", "door": "Enter Snackbar De Hoek"},
	{"id": "nightshop", "name": "NACHTWINKEL", "x": 30.0, "side": -1, "w": 10.0, "color": Color("f472b6"), "glass": Color("ffb3dc"), "sub": "OPEN 24/7", "door": "Enter Nachtwinkel (24/7)"},
	{"id": "studio", "name": "MAAS SOUND", "x": -24.0, "side": 1, "w": 12.0, "color": Color("a78bfa"), "glass": Color("c4b5fd"), "sub": "PRO RECORDING STUDIOS", "door": "Maas Sound Studios"},
]

var spawn_local := Vector3(-42.0, 0.05, -8.4)
var city_env: Environment
var wetness := 0.65
var _wet_mats: Array[ShaderMaterial] = []
var _car_mat: ShaderMaterial
var game: GameState  # set by main (reputation for being recognised)

## Closing time per shop in game minutes (the night runs 22:00 = 1320 .. 06:00 = 1800).
const HOURS := {"music": 24 * 60, "coffeeshop": 25 * 60, "snackbar": 27 * 60, "casino": 30 * 60, "nightshop": 99999, "studio": 99999, "home": 99999}
var _shop_state := {}  # id -> {shutter, lights, mats}
var _open := {}
var weather := "dry"
var _rain: GPUParticles3D
var _amb_city: AudioStreamPlayer
var _amb_rain: AudioStreamPlayer
var _amb_water: AudioStreamPlayer3D
var _signal_state := 0  # 0 green, 1 amber, 2 red (main road)
var _signal_t := 0.0
var _signal_lamps: Array = []  # [[green_mat, amber_mat, red_mat], ...]
var _greet_t := 0.0
var _greeted := {}
var _bouncer: NPC
var skyline: RotterdamSkyline
var tram4: Dictionary
var metro_entrance: StaticBody3D
var station_id := "zuidkade"
var tram_stop_x := -8.0
var cat: StreetCat
var flocks: Array[PigeonFlock] = []
var _stare := {}
var _react_t := 0.0
var _chat_t := 6.0
var _chat_i := 0
var seats: Array[StaticBody3D] = []
var cam_attr: CameraAttributesPractical
var quality_high := true
var player: Node3D  # set by main, cars brake for it
var cars: Array = []  # [{node, dir, lane, speed, brake}]
var pedestrians: Array[NPC] = []
var _bmat: ShaderMaterial
var _chip: Node3D
var _rng := RandomNumberGenerator.new()
var _brake_mats := {}


func build_city() -> void:
	_rng.seed = 2026
	_base_remap = {"_defaultMat": mat(Color("2a2633"), 0.6, "")}
	_outdoor_environment()
	_car_mat = ShaderMaterial.new()
	_car_mat.shader = load("res://assets/shaders/kenney_tint.gdshader")
	_car_mat.set_shader_parameter("colormap", load("res://assets/models/kenney_cars/Textures/colormap.png"))
	_car_mat.set_shader_parameter("roughness_base", 0.28)
	_car_mat.set_shader_parameter("metallic_base", 0.35)
	_bmat = ShaderMaterial.new()
	_bmat.shader = load("res://assets/shaders/night_building.gdshader")
	_bmat.set_shader_parameter("colormap", load("res://assets/models/kenney_city/Textures/colormap.png"))
	_bmat.set_shader_parameter("per_building", true)
	_bmat.set_shader_parameter("lit_chance", 0.5)
	_bmat.set_shader_parameter("window_energy", 0.5)
	_bmat.set_shader_parameter("facade_brightness", 0.26)
	_ground_and_roads()
	_facades()
	_north_side()
	_south_side()
	_casino()
	_quay_and_river()
	_street_lights()
	_street_props()
	_parked_cars()
	_tram_lines()
	_traffic()
	tram4 = _tram(-8.0, -120.0, "4  CENTRAAL")
	_tram_shelter(-8.0, 1, "Zuidkade")
	metro_entrance = _metro_entrance(Vector3(40.0, 0, 8.2), 180.0, "Zuidkade")
	metro_entrance.set_meta("station", "zuidkade")
	_traffic_lights()
	_pedestrians()
	_smokers()
	_wildlife()
	_steam()
	_loose_props()
	_seats()
	_bounds_walls()
	_decals()
	_moon()


# ================= Outdoor light & post (REALISM R1) =================

## Night in a harbour city: AgX tonemapping, sky glowing orange from light pollution,
## SDFGI bounce light, SSR on wet ground, thin volumetric fog, cool-shadow / warm-highlight grade.
func _outdoor_environment() -> void:
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("04050c")
	sky_mat.sky_horizon_color = Color("3b2a33")  # sodium light pollution
	sky_mat.ground_horizon_color = Color("2a2028")
	sky_mat.ground_bottom_color = Color("07060a")
	sky_mat.sky_curve = 0.09
	sky_mat.sky_energy_multiplier = 0.9
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = 4 if Engine.get_version_info().minor >= 4 else Environment.TONE_MAPPER_ACES  # AgX
	e.tonemap_exposure = 1.25
	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 1.6
	e.ssr_enabled = true
	e.ssr_max_steps = 56
	e.ssr_fade_in = 0.1
	e.ssr_fade_out = 2.0
	e.ssr_depth_tolerance = 0.3
	e.sdfgi_enabled = true
	e.sdfgi_cascades = 4
	e.sdfgi_min_cell_size = 0.4
	e.sdfgi_use_occlusion = true
	e.sdfgi_read_sky_light = true
	e.sdfgi_bounce_feedback = 0.4
	e.sdfgi_energy = 1.2
	e.glow_enabled = true
	e.glow_intensity = 0.45
	e.glow_bloom = 0.03
	e.glow_hdr_threshold = 1.3
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.007
	e.volumetric_fog_albedo = Color(0.78, 0.74, 0.86)
	e.volumetric_fog_length = 64.0
	e.volumetric_fog_gi_inject = 0.4
	# far haze (volumetric fog only reaches 64 m): the skyline across the river fades into the night
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color("1b1824")
	e.fog_density = 0.55
	e.fog_depth_begin = 90.0
	e.fog_depth_end = 900.0
	e.fog_depth_curve = 1.6
	e.fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 0.9
	# 1D LUT: shadows lean cool blue, highlights lean warm
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0))
	g.set_color(1, Color(1.0, 0.97, 0.9))
	g.add_point(0.18, Color(0.15, 0.17, 0.23))
	g.add_point(0.5, Color(0.5, 0.5, 0.5))
	var lut := GradientTexture1D.new()
	lut.gradient = g
	lut.width = 256
	e.adjustment_color_correction = lut
	city_env = e
	cam_attr = CameraAttributesPractical.new()
	cam_attr.auto_exposure_enabled = true
	cam_attr.auto_exposure_scale = 0.55
	cam_attr.auto_exposure_min_sensitivity = 80.0
	cam_attr.auto_exposure_max_sensitivity = 900.0
	cam_attr.auto_exposure_speed = 1.2


## F9 in game: Low drops the expensive features (for weaker GPUs).
func apply_quality(high: bool) -> void:
	quality_high = high
	city_env.sdfgi_enabled = high
	city_env.ssr_enabled = high
	city_env.volumetric_fog_enabled = high
	city_env.ssao_enabled = high
	if not high:
		city_env.ambient_light_energy = 0.8
	else:
		city_env.ambient_light_energy = 0.55


## Window-shaped light projected onto the sidewalk (a light texture / projector).
static var _window_projector: ImageTexture
static func window_projector() -> ImageTexture:
	if _window_projector:
		return _window_projector
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var pane := 1.0
			var fx := fmod(x / 128.0 * 3.0, 1.0)
			if fx < 0.07 or fx > 0.93:
				pane = 0.08  # mullions
			if y < 10 or y > 118 or x < 6 or x > 122:
				pane = 0.0
			var soft := clampf(1.0 - Vector2(x - 64, y - 64).length() / 96.0, 0.0, 1.0)
			var v := pane * (0.55 + 0.45 * soft)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	_window_projector = ImageTexture.create_from_image(img)
	return _window_projector


# ================= PBR surfaces + wetness (REALISM R2) =================

const MAT_DIR := "res://assets/materials/%s/%s_1K-JPG_%s.jpg"

## ambientCG PBR set projected in world space, with wetness and puddles.
func pbr(set_name: String, tile: float, tint := Color.WHITE, puddle := 0.5, normal := 0.55, dirt := 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/wet_surface.gdshader")
	m.set_shader_parameter("albedo_tex", load(MAT_DIR % [set_name, set_name, "Color"]))
	m.set_shader_parameter("normal_tex", load(MAT_DIR % [set_name, set_name, "NormalGL"]))
	m.set_shader_parameter("rough_tex", load(MAT_DIR % [set_name, set_name, "Roughness"]))
	m.set_shader_parameter("tile_size", tile)
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("puddles", puddle)
	m.set_shader_parameter("normal_strength", normal)
	m.set_shader_parameter("dirt", dirt)
	m.set_shader_parameter("wetness", wetness)
	_wet_mats.append(m)
	return m


## 0 = dry night, 1 = soaked. Driven by the weather.
func set_wetness(v: float) -> void:
	wetness = clampf(v, 0.0, 1.0)
	for m in _wet_mats:
		m.set_shader_parameter("wetness", wetness)


func set_rain(v: float) -> void:
	for m in _wet_mats:
		m.set_shader_parameter("rain", v)


## The "used" layer: gum, oil, cracks, manholes, drains, grime at the foot of the facades.
func _decals() -> void:
	var g := group("Decals")
	var add := func(kind: String, pos: Vector3, size: Vector3, rot_y := 0.0, mod := Color.WHITE) -> Decal:
		var d := DecalKit.make(kind, size, mod)
		d.position = pos
		d.rotation_degrees.y = rot_y
		g.add_child(d)
		return d
	# sidewalks: gum patches and cracks, every few metres
	for side in [-1, 1]:
		var x := X_MIN + 2.0
		while x < X_MAX - 2.0:
			var z: float = side * (ROAD_HW + 2.0) + _rng.randf_range(-1.2, 1.2)
			add.call("gum", Vector3(x, 0.1, z), Vector3(3.0, 0.6, 3.0), _rng.randf() * 360.0)
			if _rng.randf() < 0.45:
				add.call("crack", Vector3(x + 1.5, 0.1, side * (ROAD_HW + 2.0) + _rng.randf_range(-1.5, 1.5)), Vector3(1.8, 0.6, 1.8), _rng.randf() * 360.0)
			if _rng.randf() < 0.3:
				add.call("oil", Vector3(x + 0.7, 0.1, z), Vector3(1.2, 0.6, 1.2), _rng.randf() * 360.0, Color(1, 1, 1, 0.6))
			x += _rng.randf_range(4.0, 6.5)
	# road: oil stains in the parking lanes, under the traffic lanes, manholes, drains at the kerb
	for i in 34:
		var ox := _rng.randf_range(X_MIN, X_MAX)
		var oz: float = [-4.7, 4.7, -1.7, 1.7][i % 4] + _rng.randf_range(-0.4, 0.4)
		add.call("oil", Vector3(ox, 0.05, oz), Vector3(_rng.randf_range(1.5, 3.5), 0.6, _rng.randf_range(1.2, 2.4)), _rng.randf() * 180.0)
	for x in [-55.0, -22.0, 12.0, 46.0]:
		add.call("manhole", Vector3(x, 0.05, 0.9), Vector3(0.9, 0.5, 0.9))
	for x in range(-66, 70, 12):
		for side in [-1, 1]:
			add.call("drain", Vector3(x + 3.0, 0.05, side * (ROAD_HW - 0.35)), Vector3(0.9, 0.5, 0.5))
	for i in 12:
		add.call("crack", Vector3(_rng.randf_range(X_MIN, X_MAX), 0.05, _rng.randf_range(-5.5, 5.5)), Vector3(3.0, 0.6, 3.0), _rng.randf() * 360.0)
	# grime along the foot of the shopfronts (wall decals: -Y into the wall)
	for side in [-1, 1]:
		var x := X_MIN + 3.0
		while x < X_MAX - 3.0:
			var d: Decal = add.call("grime", Vector3(x, 0.5, side * (LINE - 0.1)), Vector3(4.0, 0.8, 1.2))
			d.rotation_degrees = Vector3(-90.0 if side == -1 else 90.0, 0.0, 0.0)
			d.rotation_degrees.y = 0.0 if side == -1 else 180.0
			x += 4.0


func spawn_point() -> Vector3:
	return to_global(spawn_local)


## Street side of the metro entrance pavilion (where you come up from the platform).
func metro_exit_point() -> Vector3:
	return metro_entrance.get_parent().to_global(Vector3(0, 0.05, 2.6))


## Yaw for the player stepping out of the pavilion (facing away from it).
func metro_exit_yaw() -> float:
	return (metro_entrance.get_parent() as Node3D).global_rotation.y + PI


# ================= Ground, roads, sidewalks =================

func _ground_and_roads() -> void:
	var g := group("Streets")
	var asphalt := pbr("Asphalt031", 4.0, Color(0.62, 0.62, 0.66), 0.55, 0.45)
	var walk := pbr("PavingStones128", 2.4, Color(0.78, 0.77, 0.8), 0.35, 0.7)
	var curb := pbr("Concrete034", 2.0, Color(0.7, 0.7, 0.72), 0.0, 0.4, 0.5)
	var paint := mat(Color("b9b7c2"), 0.45, "")
	var yellow := mat(Color("c9a93c"), 0.45, "")
	# ground collision (everything walkable is at y = 0)
	solid(Vector3(600, 1, 600), Vector3(0, -0.5, 0))
	# far ground
	part(g, box(Vector3(600, 0.1, 300 + WATER_Z)), Vector3(0, -0.08, (WATER_Z - 300) / 2.0), pbr("Asphalt031", 5.0, Color(0.3, 0.3, 0.33), 0.3, 0.3))
	# main road (continues into the dark both ways for traffic)
	part(g, box(Vector3(300, 0.04, ROAD_HW * 2)), Vector3(0, 0.0, 0), asphalt)
	for x in range(-148, 150, 6):
		_paint(g, Vector3(3.0, 0.004, 0.18), Vector3(x, 0.022, 0), paint)  # dashed centre line
	for z in [-3.4, 3.4]:
		_paint(g, Vector3(300, 0.004, 0.12), Vector3(0, 0.022, z), paint)  # parking lane line
	# sidewalks + curbs (visual height only, collision stays flat)
	for side in [-1, 1]:
		var z: float = side * (ROAD_HW + 2.0)
		part(g, box(Vector3(300, 0.12, 4.0)), Vector3(0, 0.06, z), walk)
		part(g, box(Vector3(300, 0.16, 0.22)), Vector3(0, 0.08, side * (ROAD_HW + 0.11)), curb)
	# side street to the quay
	part(g, box(Vector3(10.0, 0.04, QUAY_Z - ROAD_HW)), Vector3(CROSS_X, 0.0, (QUAY_Z + ROAD_HW) / 2.0), asphalt)
	for zz in range(9, 32, 6):
		part(g, box(Vector3(0.18, 0.02, 3.0)), Vector3(CROSS_X, 0.03, zz), paint)
	for sx in [-1, 1]:
		var x: float = CROSS_X + sx * 7.0
		part(g, box(Vector3(4.0, 0.12, QUAY_Z - LINE)), Vector3(x, 0.06, (QUAY_Z + LINE) / 2.0), walk)
		part(g, box(Vector3(0.22, 0.16, QUAY_Z - LINE)), Vector3(CROSS_X + sx * 5.11, 0.08, (QUAY_Z + LINE) / 2.0), curb)
	# zebra crossings
	for zx in [[-35.0, 0.0], [CROSS_X - 9.0, 0.0]]:
		for i in 7:
			_paint(g, Vector3(0.6, 0.004, ROAD_HW * 2 - 1.0), Vector3(zx[0] - 2.4 + i * 0.8, 0.022, zx[1]), paint)
	for i in 6:
		_paint(g, Vector3(9.0, 0.004, 0.5), Vector3(CROSS_X, 0.022, ROAD_HW + 1.4 + i * 0.7), paint)
	# yellow "no parking" in front of the casino
	_paint(g, Vector3(20.0, 0.004, 0.14), Vector3(-50.0, 0.022, ROAD_HW - 0.3), yellow)
	# street name signs (Dutch blue plates)
	_street_sign(g, Vector3(CROSS_X - 5.6, 0, LINE - 1.0), "Zuidkade", 0.0)
	_street_sign(g, Vector3(CROSS_X + 5.6, 0, LINE + 2.0), "Maasboulevard", 90.0)


func _paint(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	var p := part(parent, box(size), pos, m)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _street_sign(parent: Node3D, pos: Vector3, text: String, rot_y: float) -> void:
	var s := Node3D.new()
	s.position = pos
	s.rotation_degrees.y = rot_y
	parent.add_child(s)
	part(s, cyl(0.05, 2.8), Vector3(0, 1.4, 0), mat(Color("8a8a98"), 0.4, ""))
	part(s, box(Vector3(1.5, 0.32, 0.04)), Vector3(0, 2.6, 0), mat(Color("1d4fb8"), 0.6, ""))
	text3d(s, text, Vector3(0, 2.6, 0.03), Color("f4f4f4"), 0.0036, Vector3.ZERO, 0.0)
	text3d(s, text, Vector3(0, 2.6, -0.03), Color("f4f4f4"), 0.0036, Vector3(0, 180, 0), 0.0)


# ================= Facades (REALISM R3) =================
# Continuous rows of Rotterdam-style houses: pre-war brick, post-war "wederopbouw" and plaster.
# Windows (interior-mapped) and their stone reveals are batched in MultiMeshes.

const FACADE_STYLES := {
	"prewar": {"wall": "Bricks097", "tile": 1.0, "win": Vector2(1.1, 1.9), "floor_h": 3.3, "lintel": true, "bands": true, "cornice": 0.7},
	"wederopbouw": {"wall": "Bricks101", "tile": 1.3, "win": Vector2(2.2, 1.45), "floor_h": 3.0, "lintel": false, "bands": false, "cornice": 0.25},
	"plaster": {"wall": "Plaster001", "tile": 3.0, "win": Vector2(1.25, 1.65), "floor_h": 3.1, "lintel": false, "bands": true, "cornice": 0.45},
}
const NORTH_ROW := [
	[-65.0, 10.0, 4, "plaster", ""], [-54.5, 11.0, 5, "wederopbouw", ""], [-42.0, 14.0, 7, "wederopbouw", "home"],
	[-28.0, 14.0, 4, "prewar", "music"], [-14.0, 14.0, 4, "prewar", "coffeeshop"], [0.0, 14.0, 3, "plaster", "snackbar"],
	[11.0, 8.0, 4, "prewar", ""], [19.0, 8.0, 5, "prewar", ""], [30.0, 14.0, 4, "wederopbouw", "nightshop"],
	[42.5, 11.0, 4, "plaster", ""], [53.5, 11.0, 5, "prewar", ""], [64.5, 11.0, 4, "wederopbouw", ""],
]
const SOUTH_ROW := [
	[-65.5, 9.0, 4, "prewar", ""], [-34.5, 9.0, 4, "plaster", ""], [-24.0, 12.0, 5, "wederopbouw", "studio"],
	[-13.5, 9.0, 4, "prewar", ""], [-3.5, 11.0, 4, "plaster", ""], [6.5, 9.0, 5, "prewar", ""],
	[35.0, 12.0, 4, "prewar", ""], [46.5, 11.0, 5, "wederopbouw", ""], [56.5, 9.0, 4, "plaster", ""], [65.5, 9.0, 4, "prewar", ""],
]
const PLASTER_TINTS := [Color(0.86, 0.8, 0.68), Color(0.72, 0.78, 0.82), Color(0.85, 0.74, 0.66), Color(0.78, 0.8, 0.72)]

var _win_batches := {}  # "w x h" -> {size, items: [[Transform3D, seed]]}
var _reveal_batch: Array[Transform3D] = []
var _wall_mats := {}


func _wall_mat(style: String, variant: int) -> ShaderMaterial:
	var key := "%s_%d" % [style, variant]
	if _wall_mats.has(key):
		return _wall_mats[key]
	var st: Dictionary = FACADE_STYLES[style]
	var tint: Color = Color(0.85, 0.82, 0.8) if style != "plaster" else PLASTER_TINTS[variant % PLASTER_TINTS.size()]
	if style == "prewar":
		tint = [Color(0.8, 0.74, 0.7), Color(0.62, 0.55, 0.52), Color(0.9, 0.8, 0.72)][variant % 3]
	elif style == "wederopbouw":
		tint = [Color(0.72, 0.62, 0.55), Color(0.55, 0.48, 0.45)][variant % 2]
	var m := pbr(st.wall, st.tile, tint, 0.0, 0.7, 0.55)
	_wall_mats[key] = m
	return m


func _facades() -> void:
	var stone := pbr("Concrete034", 1.5, Color(0.78, 0.76, 0.72), 0.0, 0.4, 0.5)
	var dark_stone := pbr("Concrete047A", 2.0, Color(0.42, 0.41, 0.43), 0.0, 0.5, 0.6)
	var i := 0
	for spec in NORTH_ROW:
		_facade(spec, -1, i, stone, dark_stone)
		i += 1
	for spec in SOUTH_ROW:
		_facade(spec, 1, i, stone, dark_stone)
		i += 1
	_flush_facade_batches(stone)


func _facade(spec: Array, side: int, idx: int, stone: Material, dark_stone: Material) -> void:
	var x: float = spec[0]
	var w: float = spec[1]
	var floors: int = spec[2]
	var style: String = spec[3]
	var shop: String = spec[4]
	var st: Dictionary = FACADE_STYLES[style]
	var plinth := 5.0 if shop != "" and shop != "home" else 4.2
	var fh: float = st.floor_h
	var top := plinth + floors * fh
	var g := Node3D.new()
	g.name = "Facade_%d" % idx
	g.position = Vector3(x, 0, side * LINE)
	g.rotation_degrees.y = 0.0 if side == -1 else 180.0
	add_child(g)
	var wall := _wall_mat(style, idx)
	# body (10 m deep) + collision
	part(g, box(Vector3(w, top + 0.4, 10.0)), Vector3(0, (top + 0.4) / 2.0, -5.0), wall)
	solid(Vector3(w, top, 10.0), Vector3(x, top / 2.0, side * (LINE + 5.0)))
	# plinth band
	part(g, box(Vector3(w + 0.05, 0.4, 0.3)), Vector3(0, plinth, 0.1), stone)
	if shop == "":
		_plinth(g, w, plinth, dark_stone, idx)
	# floors: windows, reveals, sills, lintels, bands
	var win: Vector2 = st.win
	var cols := maxi(2, int((w - 1.2) / (win.x + 1.1)))
	var pitch := w / cols
	for f in floors:
		var y0 := plinth + 0.35 + f * fh + 0.75
		var cy := y0 + win.y / 2.0
		if st.bands and f > 0:
			part(g, box(Vector3(w, 0.14, 0.12)), Vector3(0, plinth + 0.35 + f * fh, 0.06), stone)
		for c in cols:
			var cx := -w / 2.0 + pitch * (c + 0.5)
			_window(g, Vector3(cx, cy, 0.0), win, st.lintel)
	# cornice + parapet
	var cor: float = st.cornice
	part(g, box(Vector3(w + 0.3, cor, 0.45)), Vector3(0, top + cor / 2.0, 0.15), stone)
	if style == "prewar":
		part(g, box(Vector3(w + 0.1, 0.18, 0.6)), Vector3(0, top - 0.1, 0.25), stone)
	# zinc drainpipe on one edge
	var px := w / 2.0 - 0.2 if idx % 2 == 0 else -w / 2.0 + 0.2
	part(g, cyl(0.06, top), Vector3(px, top / 2.0, 0.12), mat(Color("6c6f76"), 0.35, ""))
	# roof clutter
	var roof_y := top + cor
	for k in _rng.randi_range(1, 3):
		var rx := _rng.randf_range(-w / 2.0 + 1.0, w / 2.0 - 1.0)
		match _rng.randi() % 4:
			0, 1:
				part(g, box(Vector3(0.7, 1.4, 0.7)), Vector3(rx, roof_y + 0.7, -_rng.randf_range(2, 8)), wall)
			2:
				part(g, box(Vector3(1.1, 0.8, 0.8)), Vector3(rx, roof_y + 0.4, -_rng.randf_range(2, 8)), mat(Color("8c8f96"), 0.4, ""))
			3:
				part(g, cyl(0.03, 2.4), Vector3(rx, roof_y + 1.2, -3.0), mat(Color("3a3c42"), 0.4, ""))
				part(g, box(Vector3(1.2, 0.04, 0.04)), Vector3(rx, roof_y + 2.1, -3.0), mat(Color("3a3c42"), 0.4, ""))
	# wall grime under every window column (rain streaks)
	if _rng.randf() < 0.7:
		var d := DecalKit.make("grime", Vector3(w * 0.9, 0.6, plinth * 0.5), Color(1, 1, 1, 0.5))
		g.add_child(d)
		d.position = Vector3(0, plinth + 0.8, 0.0)
		d.rotation_degrees = Vector3(-90, 0, 0)


## Ground floor of a house without a shop: a front door and either a closed shop (shutter + tag) or a window.
func _plinth(g: Node3D, w: float, h: float, dark_stone: Material, idx: int) -> void:
	part(g, box(Vector3(w, h - 0.2, 0.15)), Vector3(0, (h - 0.2) / 2.0, 0.07), dark_stone)
	var door_x := -w / 2.0 + 1.4 if idx % 2 == 0 else w / 2.0 - 1.4
	part(g, box(Vector3(1.2, 2.4, 0.12)), Vector3(door_x, 1.2, 0.12), mat(Color("2a2420"), 0.6, "wood", 1.0))
	part(g, box(Vector3(1.4, 0.12, 0.3)), Vector3(door_x, 2.5, 0.2), dark_stone)
	part(g, box(Vector3(0.05, 0.25, 0.05)), Vector3(door_x + 0.4, 1.15, 0.2), mat(Color("b8b2a0"), 0.3, ""))
	var rest := w - 3.2
	var rx := w / 2.0 - 1.6 - rest / 2.0 if idx % 2 == 0 else -w / 2.0 + 1.6 + rest / 2.0
	if idx % 3 != 1:
		# closed shop: ribbed shutter, faded sign plate, graffiti
		part(g, box(Vector3(rest, 3.0, 0.1)), Vector3(rx, 1.55, 0.14), _shutter_mat())
		part(g, box(Vector3(rest, 0.6, 0.08)), Vector3(rx, 3.45, 0.15), mat(Color("3b3a40"), 0.7, "plaster"))
		var tag := DecalKit.make("tag", Vector3(rest * 0.7, 0.6, 1.6))
		g.add_child(tag)
		tag.position = Vector3(rx, 1.4, 0.15)
		tag.rotation_degrees = Vector3(-90, 0, 0)
	else:
		_window(g, Vector3(rx, 2.0, 0.0), Vector2(minf(rest - 0.6, 3.0), 1.8), false)


var _shutter: StandardMaterial3D
func _shutter_mat() -> StandardMaterial3D:
	if _shutter:
		return _shutter
	var img := Image.create(8, 64, true, Image.FORMAT_RGB8)
	for y in 64:
		var v := 0.5 + 0.18 * sin(y / 64.0 * TAU * 8.0)
		for x in 8:
			img.set_pixel(x, y, Color(v, v, v * 1.03))
	img.generate_mipmaps()
	_shutter = StandardMaterial3D.new()
	_shutter.albedo_texture = ImageTexture.create_from_image(img)
	_shutter.albedo_color = Color(0.55, 0.56, 0.6)
	_shutter.uv1_triplanar = true
	_shutter.uv1_scale = Vector3(1, 1.0 / 0.95, 1) * 0.6
	_shutter.metallic = 0.5
	_shutter.roughness = 0.45
	return _shutter


## A window at `c` (local to facade g): stone reveals around it, a sill, maybe a lintel, and an
## interior-mapped glass quad, all queued for the MultiMesh batches.
func _window(g: Node3D, c: Vector3, size: Vector2, lintel: bool) -> void:
	var to_city := g.transform
	var depth := 0.24
	var t := 0.12
	var reveal_specs := [
		[Vector3(c.x - size.x / 2.0 - t / 2.0, c.y, depth / 2.0), Vector3(t, size.y + t * 2.0, depth)],
		[Vector3(c.x + size.x / 2.0 + t / 2.0, c.y, depth / 2.0), Vector3(t, size.y + t * 2.0, depth)],
		[Vector3(c.x, c.y + size.y / 2.0 + t / 2.0, depth / 2.0), Vector3(size.x, t, depth)],
		[Vector3(c.x, c.y - size.y / 2.0 - 0.05, depth / 2.0 + 0.05), Vector3(size.x + 0.3, 0.1, depth + 0.1)],  # sill
	]
	if lintel:
		reveal_specs.append([Vector3(c.x, c.y + size.y / 2.0 + 0.25, 0.08), Vector3(size.x + 0.5, 0.3, 0.16)])
	for r in reveal_specs:
		_reveal_batch.append(to_city * Transform3D(Basis().scaled(r[1]), r[0]))
	var key := "%.2fx%.2f" % [size.x, size.y]
	if not _win_batches.has(key):
		_win_batches[key] = {"size": size, "items": []}
	_win_batches[key].items.append([to_city * Transform3D(Basis(), Vector3(c.x, c.y, 0.02)), _rng.randf()])


func _flush_facade_batches(stone: Material) -> void:
	var g := group("FacadeBatches")
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box(Vector3.ONE)
	mm.instance_count = _reveal_batch.size()
	for i in _reveal_batch.size():
		mm.set_instance_transform(i, _reveal_batch[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Reveals"
	mmi.multimesh = mm
	mmi.material_override = stone
	g.add_child(mmi)
	var shader: Shader = load("res://assets/shaders/interior_window.gdshader")
	for key in _win_batches.keys():
		var b: Dictionary = _win_batches[key]
		var q := QuadMesh.new()
		q.size = b.size
		var wm := MultiMesh.new()
		wm.transform_format = MultiMesh.TRANSFORM_3D
		wm.use_custom_data = true
		wm.mesh = q
		wm.instance_count = b.items.size()
		for i in b.items.size():
			wm.set_instance_transform(i, b.items[i][0])
			wm.set_instance_custom_data(i, Color(b.items[i][1], 0, 0, 0))
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("win_size", b.size)
		sm.set_shader_parameter("lit_chance", 0.42)
		var wi := MultiMeshInstance3D.new()
		wi.name = "Windows_" + key
		wi.multimesh = wm
		wi.material_override = sm
		wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(wi)


# ================= Buildings =================

func _building(model: String, x: float, side: int, rot: float = 0.0, scl: float = BSCALE, line: float = LINE) -> Node3D:
	var b := kit(self, model, Vector3(x, 0, side * line), rot, scl, {"colormap": _bmat}, CITY)
	var sz: Vector3 = b.get_meta("size")
	var depth: float = sz.x if int(rot) % 180 != 0 else sz.z
	var width: float = sz.z if int(rot) % 180 != 0 else sz.x
	b.position.z = side * (line + depth / 2.0)
	solid(Vector3(width, sz.y, depth), Vector3(x, sz.y / 2.0, b.position.z))
	return b


func _north_side() -> void:
	var fillers := ["building-f", "building-l", "building-k", "building-h", "building-a", "building-c", "building-n"]
	# backdrop row behind (rooftops seen from the quay / street)
	for i in 12:
		var m: String = fillers[i % fillers.size()]
		_building(m, -66.0 + i * 12.0, -1, 0.0, BSCALE * 1.15, 26.0)
	for s in SHOPS:
		if s.side == -1:
			_storefront(s)


func _south_side() -> void:
	for s in SHOPS:
		if s.side == 1:
			_storefront(s)
	# second row facing the quay (fronts at QUAY_Z)
	var quay_models := ["building-a", "building-e", "building-h", "building-k", "building-f", "building-l", "building-c"]
	var x := -64.0
	var i := 0
	while x < 70.0:
		if absf(x - CROSS_X) > 9.0:
			var b := kit(self, quay_models[i % quay_models.size()], Vector3(x, 0, 0), 180.0, BSCALE, {"colormap": _bmat}, CITY)
			var sz: Vector3 = b.get_meta("size")
			b.position.z = QUAY_Z - sz.z / 2.0
			solid(Vector3(sz.x, sz.y, sz.z), Vector3(x, sz.y / 2.0, b.position.z))
			if i % 2 == 0:
				_cafe_front(Vector3(x, 0, QUAY_Z))
		x += 12.0
		i += 1
	# dumpsters in the side street
	for z in [14.0, 22.0]:
		kit(self, "detail-dumpster-closed", Vector3(CROSS_X - 8.4, 0, z), 90.0, 3.6, {}, RETRO)


## Dark gaps between buildings: dumpsters, a cable, a glowing back door.
func _alleys(side: int, xs: Array) -> void:
	var sorted := xs.duplicate()
	sorted.sort()
	for i in sorted.size() - 1:
		var gx: float = (sorted[i] + sorted[i + 1]) / 2.0
		if absf(gx - CROSS_X) < 8.0 or absf(gx + 50.0) < 10.0:
			continue
		var z: float = side * (LINE + 1.6)
		if _rng.randf() < 0.7:
			kit(self, "detail-dumpster-closed", Vector3(gx, 0, z), _rng.randf_range(-10, 10), 3.6, {}, RETRO)
		part(self, box(Vector3(0.6, 0.9, 0.5)), Vector3(gx + 1.2, 0.45, side * (LINE + 0.6)), mat(Color("2b3a2e"), 0.8, ""))


func _storefront(s: Dictionary) -> void:
	var side: int = s.side
	var w: float = s.w
	var col: Color = s.color
	var g := Node3D.new()
	g.name = "Shop_" + str(s.id)
	g.position = Vector3(s.x, 0, side * LINE)
	g.rotation_degrees.y = 0.0 if side == -1 else 180.0
	add_child(g)
	var frame := mat(Color("1a1722"), 0.7, "plaster", 1.0)
	var trim := mat(col.darkened(0.55), 0.6, "")
	part(g, box(Vector3(w, 4.2, 0.4)), Vector3(0, 2.1, 0.12), frame)
	part(g, box(Vector3(w, 0.16, 0.5)), Vector3(0, 4.25, 0.16), trim)
	var is_home: bool = s.id == "home"
	if not is_home:
		# shop window: lit interior with a few silhouettes behind the glass
		var ww := w * 0.56
		var wx := -w * 0.19
		var glass_m := glow(Color(s.glass).darkened(0.25), 0.07)
		glass_m.albedo_color = Color(0.02, 0.025, 0.03)
		glass_m.roughness = 0.05
		part(g, box(Vector3(ww, 2.5, 0.05)), Vector3(wx, 1.6, 0.34), glass_m)
		_shop_reg(str(s.id)).mats.append(glass_m)
		for i in 3:
			part(g, box(Vector3(0.08, 2.5, 0.08)), Vector3(wx - ww / 2.0 + ww * (i + 1) / 4.0, 1.6, 0.37), frame)
		_window_dressing(g, str(s.id), wx, ww)
		# awning
		var aw := part(g, box(Vector3(w * 0.92, 0.1, 1.8)), Vector3(0, 3.55, 1.05), mat(col.darkened(0.35), 0.9, "fabric", 3.0), Vector3(-14, 0, 0))
		aw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		part(g, box(Vector3(w * 0.92, 0.35, 0.05)), Vector3(0, 3.18, 1.93), mat(col.darkened(0.2), 0.9, "fabric", 3.0))
	# door
	var dx: float = w * 0.32 if not is_home else 0.0
	part(g, box(Vector3(1.7, 2.7, 0.1)), Vector3(dx, 1.35, 0.33), frame)
	var door_m := glow(Color(s.glass).darkened(0.45), 0.25)
	door_m.albedo_color = Color(0.04, 0.05, 0.06)
	door_m.roughness = 0.05
	part(g, box(Vector3(1.4, 2.45, 0.05)), Vector3(dx, 1.25, 0.37), door_m)
	_shop_reg(str(s.id)).mats.append(door_m)
	part(g, box(Vector3(0.06, 0.5, 0.06)), Vector3(dx - 0.45, 1.2, 0.43), mat(Color("c9c9d4"), 0.3, ""))
	var door := solid(Vector3(1.8, 2.7, 0.6), g.transform * Vector3(dx, 1.35, 0.5), "shop", str(s.door), g.rotation_degrees.y)
	door.set_meta("shop_id", s.id)
	_shop_reg(str(s.id)).door_out = g.transform * Vector3(dx, 0.05, 2.2)  # street side of the door
	# sign: dark plate + neon text + neon tube outline
	var sign_w: float = minf(w * 0.86, 1.0 + str(s.name).length() * 0.62)
	part(g, box(Vector3(sign_w, 1.15, 0.18)), Vector3(0, 4.95, 0.3), mat(Color("0f0d15"), 0.6, ""))
	text3d(g, str(s.name), Vector3(0, 5.0, 0.41), col, 0.0125, Vector3.ZERO, 4.0)
	for yy in [4.42, 5.48]:
		part(g, box(Vector3(sign_w - 0.1, 0.04, 0.04)), Vector3(0, yy, 0.41), glow(col, 3.0))
	text3d(g, str(s.sub), Vector3(dx if is_home else -w * 0.19, 3.05 if not is_home else 3.0, 0.42), Color("f4efff") if not is_home else col, 0.0038, Vector3.ZERO, 1.2)
	if is_home:
		# intercom, house number, mailboxes, warm entrance lamp
		part(g, box(Vector3(0.3, 0.5, 0.06)), Vector3(1.25, 1.35, 0.36), mat(Color("8a8a98"), 0.35, ""))
		for i in 4:
			part(g, box(Vector3(0.18, 0.05, 0.02)), Vector3(1.25, 1.5 - i * 0.09, 0.4), glow(Color("ffd9a0"), 0.6))
		text3d(g, "17", Vector3(-1.2, 2.4, 0.4), Color("f4efff"), 0.006, Vector3.ZERO, 0.8)
		part(g, sphere(0.14), Vector3(0, 2.95, 0.55), glow(Color("ffcf9a"), 3.0))
	var l := OmniLight3D.new()
	l.position = g.transform * Vector3(0, 3.0, 2.4)
	l.light_color = col.lerp(Color.WHITE, 0.3)
	l.light_energy = 1.3 if not is_home else 1.0
	l.omni_range = 7.5
	l.light_volumetric_fog_energy = 0.6
	add_child(l)
	_shop_reg(str(s.id)).lights.append(l)
	if not is_home:
		# roller shutter, down when the shop is closed
		var sh := part(g, box(Vector3(w * 0.94, 3.05, 0.08)), Vector3(0, 1.55, 0.46), _shutter_mat())
		sh.visible = false
		_shop_reg(str(s.id)).shutter = sh
		# warm white shop light falling out of the window onto the wet sidewalk
		var sp := SpotLight3D.new()
		g.add_child(sp)
		sp.position = Vector3(-w * 0.19, 2.9, -0.4)
		sp.rotation_degrees = Vector3(-52, 180, 0)
		sp.light_color = Color(s.glass).lerp(Color("fff1dc"), 0.55)
		sp.light_energy = 5.0
		sp.spot_range = 9.0
		sp.spot_angle = 48.0
		sp.light_projector = window_projector()
		sp.light_volumetric_fog_energy = 0.3
		_shop_reg(str(s.id)).lights.append(sp)


## Things visible behind each shop window.
func _window_dressing(g: Node3D, id: String, wx: float, ww: float) -> void:
	var dark := mat(Color("120f18"), 0.8, "")
	match id:
		"music":
			for i in 3:
				var gx := wx - ww / 2.0 + 0.8 + i * 1.6
				part(g, capsule(0.28, 0.9), Vector3(gx, 0.9, 0.22), dark)  # guitar bodies
				part(g, box(Vector3(0.08, 0.9, 0.05)), Vector3(gx, 1.75, 0.22), dark)
			part(g, box(Vector3(1.4, 0.5, 0.4)), Vector3(wx + ww / 2.0 - 1.0, 0.7, 0.2), dark)  # synth on a stand
			part(g, box(Vector3(0.7, 1.1, 0.5)), Vector3(wx + ww / 2.0 - 0.6, 1.9, 0.2), dark)  # speaker
		"coffeeshop":
			for i in 4:
				part(g, cyl(0.09, 0.3), Vector3(wx - ww / 2.0 + 0.8 + i * 1.0, 1.9, 0.22), dark)  # jars
			part(g, box(Vector3(ww * 0.8, 0.08, 0.4)), Vector3(wx, 1.72, 0.2), dark)
			part(g, sphere(0.35), Vector3(wx + ww / 2.0 - 0.7, 0.8, 0.22), mat(Color("1d3a24"), 0.9, ""))  # plant
		"snackbar":
			part(g, box(Vector3(ww * 0.85, 1.0, 0.4)), Vector3(wx, 0.5, 0.2), dark)  # counter
			for i in 3:
				part(g, box(Vector3(0.9, 0.5, 0.04)), Vector3(wx - 1.2 + i * 1.2, 2.35, 0.3), glow(Color("fff3c4"), 0.9))  # menu boards
		"nightshop":
			for row in 3:
				part(g, box(Vector3(ww * 0.85, 0.06, 0.4)), Vector3(wx, 0.7 + row * 0.6, 0.2), dark)
				for i in 6:
					part(g, box(Vector3(0.2, 0.32, 0.18)), Vector3(wx - ww * 0.38 + i * ww * 0.15, 0.9 + row * 0.6, 0.22), mat(Color.from_hsv(_rng.randf(), 0.7, 0.6), 0.5, ""))
		"studio":
			part(g, box(Vector3(0.5, 0.2, 0.06)), Vector3(wx, 2.55, 0.4), glow(Color("ff3030"), 4.0))  # ON AIR light
			text3d(g, "ON AIR", Vector3(wx, 2.55, 0.44), Color("ffffff"), 0.0022, Vector3.ZERO, 0.5)


## Terrace in front of quay buildings: parasol, tables, string lights.
func _cafe_front(pos: Vector3) -> void:
	kit(self, "detail-parasol-a", pos + Vector3(-2.0, 0, 2.0), 0, 6.0, {}, CITY)
	for i in 2:
		part(self, cyl(0.45, 0.06), pos + Vector3(-3.0 + i * 2.2, 0.75, 1.4), mat(Color("2e2a38"), 0.6, ""))
		part(self, cyl(0.05, 0.75), pos + Vector3(-3.0 + i * 2.2, 0.37, 1.4), mat(Color("2e2a38"), 0.6, ""))
	for i in 8:
		part(self, sphere(0.06), pos + Vector3(-4.0 + i * 1.1, 3.0 - absf(sin(i * 0.8)) * 0.2, 0.5), glow(Color("ffd08a"), 4.0))


# ================= Casino =================

func _casino() -> void:
	var cx := -50.0
	var g := Node3D.new()
	g.name = "Casino"
	g.position = Vector3(cx, 0, LINE)
	g.rotation_degrees.y = 180.0
	add_child(g)
	var body := mat(Color("2a1420"), 0.8, "plaster", 0.8)
	var gold := mat(Color("d4a73a"), 0.35, "")
	var red := mat(Color("7a1020"), 0.9, "fabric", 3.0)
	# building body (behind the facade line, local -z)
	part(g, box(Vector3(22, 13, 14)), Vector3(0, 6.5, -7.0), body)
	solid(Vector3(22, 13, 14), Vector3(cx, 6.5, LINE + 7.0))
	part(g, box(Vector3(22.4, 0.5, 14.4)), Vector3(0, 13.25, -7.0), mat(Color("1a0d14"), 0.7, ""))
	for i in 5:
		part(g, box(Vector3(0.6, 12.5, 0.5)), Vector3(-10.5 + i * 5.25, 6.25, 0.15), mat(Color("3a1c2a"), 0.7, "plaster"))
	# upper windows (purple glow)
	for row in 2:
		for i in 4:
			part(g, box(Vector3(3.6, 1.8, 0.05)), Vector3(-7.9 + i * 5.25, 7.5 + row * 3.0, 0.05), glow(Color("6a2a8a"), 0.5))
	# entrance: two glass doors, gold frames
	for dx in [-1.6, 1.6]:
		part(g, box(Vector3(2.6, 3.4, 0.08)), Vector3(dx, 1.7, 0.2), glow(Color("e0a850"), 0.35))
		part(g, box(Vector3(2.8, 0.12, 0.2)), Vector3(dx, 3.45, 0.24), gold)
	var door := solid(Vector3(6.0, 3.4, 0.8), g.transform * Vector3(0, 1.7, 0.6), "shop", "Enter Lucky Stack (casino)", 180.0)
	door.set_meta("shop_id", "casino")
	# marquee canopy with chasing bulbs
	part(g, box(Vector3(14, 0.7, 4.2)), Vector3(0, 4.4, 2.1), mat(Color("150a10"), 0.6, ""))
	part(g, box(Vector3(14.1, 0.18, 4.3)), Vector3(0, 4.0, 2.1), gold)
	var bulbs: Array[Transform3D] = []
	for i in 34:
		bulbs.append(Transform3D(Basis(), Vector3(-6.8 + i * 0.41, 3.92, 4.27)))
	for i in 10:
		bulbs.append(Transform3D(Basis(), Vector3(-7.07, 3.92, 0.3 + i * 0.4)))
		bulbs.append(Transform3D(Basis(), Vector3(7.07, 3.92, 0.3 + i * 0.4)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere(0.07)
	mm.instance_count = bulbs.size()
	for i in bulbs.size():
		mm.set_instance_transform(i, bulbs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = glow(Color("ffd27a"), 6.0)
	g.add_child(mmi)
	# big sign
	part(g, box(Vector3(16.5, 3.0, 0.4)), Vector3(0, 7.4, 0.4), mat(Color("0d070b"), 0.6, ""))
	text3d(g, "LUCKY STACK", Vector3(0, 7.65, 0.62), Color("ffcc4d"), 0.034, Vector3.ZERO, 5.0)
	text3d(g, "CASINO  ·  SLOTS  ·  ROULETTE  ·  OPEN ALL NIGHT", Vector3(0, 6.45, 0.62), Color("ff4d6d"), 0.0075, Vector3.ZERO, 3.0)
	for yy in [5.95, 8.85]:
		part(g, box(Vector3(16.2, 0.06, 0.06)), Vector3(0, yy, 0.62), glow(Color("ff4d6d"), 4.0))
	# spinning casino chip on the roof
	_chip = Node3D.new()
	_chip.position = Vector3(0, 16.5, -3.0)
	g.add_child(_chip)
	part(_chip, cyl(2.4, 0.5), Vector3.ZERO, glow(Color("e0244a"), 1.6), Vector3(90, 0, 0))
	part(_chip, cyl(1.7, 0.56), Vector3.ZERO, mat(Color("f2efe6"), 0.5, ""), Vector3(90, 0, 0))
	for i in 8:
		var a := TAU * i / 8.0
		part(_chip, box(Vector3(0.5, 0.5, 0.58)), Vector3(cos(a) * 2.05, sin(a) * 2.05, 0), mat(Color("f2efe6"), 0.5, ""), Vector3(0, 0, rad_to_deg(a)))
	text3d(_chip, "$", Vector3(0, 0, 0.31), Color("e0244a"), 0.03, Vector3.ZERO, 2.0)
	text3d(_chip, "$", Vector3(0, 0, -0.31), Color("e0244a"), 0.03, Vector3(0, 180, 0), 2.0)
	part(g, cyl(0.15, 3.0), Vector3(0, 14.5, -3.0), mat(Color("3a3a44"), 0.4, ""))
	# red carpet + velvet ropes
	part(g, box(Vector3(5.0, 0.03, 5.5)), Vector3(0, 0.13, 2.8), red)
	for side in [-1, 1]:
		for i in 3:
			part(g, cyl(0.06, 1.0), Vector3(side * 3.0, 0.62, 1.2 + i * 1.8), gold)
			part(g, sphere(0.1), Vector3(side * 3.0, 1.15, 1.2 + i * 1.8), gold)
		for i in 2:
			part(g, cyl(0.035, 1.8), Vector3(side * 3.0, 0.92, 2.1 + i * 1.8), red, Vector3(90, 0, 0))
	for spec in [[Vector3(0, 3.2, 3.5), Color("ffcf7a"), 3.2, 11.0], [Vector3(-6, 8, 2.5), Color("ff4d6d"), 2.0, 12.0], [Vector3(6, 8, 2.5), Color("ffcc4d"), 2.0, 12.0]]:
		var l := OmniLight3D.new()
		l.position = g.transform * spec[0]
		l.light_color = spec[1]
		l.light_energy = spec[2]
		l.omni_range = spec[3]
		l.shadow_enabled = spec[0].y < 4.0
		add_child(l)
	# bouncer at the door
	var bouncer := NPC.new()
	add_child(bouncer)
	bouncer.setup({"model": "business_male", "voice_hz": 95.0, "recolor": {}, "accessory": "", "name": "Dennis", "persona": "bouncer"})
	bouncer.position = g.transform * Vector3(2.4, 0, 1.1)
	bouncer.rotation.y = 0.0
	bouncer.name = "Bouncer"
	_bouncer = bouncer


func _process(delta: float) -> void:
	if _chip:
		_chip.rotation.y += delta * 0.8
	_tick_signals(delta)
	_drive(delta)
	if _rain and player and is_instance_valid(player):
		_rain.global_position = player.global_position + Vector3(0, 9.0, 0)
	_greet_t -= delta
	if _greet_t <= 0.0:
		_greet_t = 0.5
		_greet()
	_react_t -= delta
	if _react_t <= 0.0:
		_react_t = 0.2
		_reactions(0.2)
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = randf_range(8.0, 13.0)
		_smoker_chat()


# ================= Quay, river, bridge, skyline =================

func _quay_and_river() -> void:
	var g := group("Quay")
	var stone := pbr("PavingStones150", 3.0, Color(0.72, 0.7, 0.72), 0.45, 0.7)
	part(g, box(Vector3(140, 0.12, WATER_Z - QUAY_Z)), Vector3(0, 0.06, (QUAY_Z + WATER_Z) / 2.0), stone)
	part(g, box(Vector3(300, 3.0, 0.8)), Vector3(0, -1.5, WATER_Z + 0.4), pbr("Concrete047A", 3.0, Color(0.45, 0.45, 0.48), 0.0, 0.5, 0.6))
	# railing
	var rail := mat(Color("5c5a68"), 0.35, "")
	part(g, cyl(0.05, 140.0), Vector3(0, 1.05, WATER_Z - 0.2), rail, Vector3(0, 0, 90))
	part(g, cyl(0.035, 140.0), Vector3(0, 0.6, WATER_Z - 0.2), rail, Vector3(0, 0, 90))
	for x in range(-70, 71, 2):
		part(g, cyl(0.04, 1.05), Vector3(x, 0.52, WATER_Z - 0.2), rail)
	# benches + lamps on the boulevard
	for x in [-50.0, -30.0, 0.0, 34.0, 52.0]:
		kit(g, "detail-bench", Vector3(x, 0, WATER_Z - 1.4), 180, 3.2, {}, RETRO)
	# water: dark, glossy, with light reflections
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("070a16")
	water.metallic = 0.6
	water.roughness = 0.08
	part(g, box(Vector3(900, 0.1, 700)), Vector3(0, -1.2, WATER_Z + 350.5), water)
	var refl: Array[Transform3D] = []
	for i in 70:
		var rx := _rng.randf_range(-200, 220)
		var rz := _rng.randf_range(90, 240)
		refl.append(Transform3D(Basis().scaled(Vector3(_rng.randf_range(0.8, 2.5), 1, _rng.randf_range(30, 90))), Vector3(rx, -1.1, rz)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box(Vector3(1, 0.02, 1))
	mm.instance_count = refl.size()
	for i in refl.size():
		mm.set_instance_transform(i, refl[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = glow(Color("ffb46a"), 1.6)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mmi)
	# the view across the Maas: swan bridge, observation tower, market hall, cube houses, towers
	skyline = RotterdamSkyline.build(self, g)


# ================= Lights =================

func _street_lights() -> void:
	var g := group("StreetLights")
	var i := 0
	var spots: Array = []
	for x in [-63.0, -49.0, -35.0, -21.0, -7.0, 7.0, 22.0, 37.0, 51.0, 65.0]:
		spots.append([x, -1])
	for x in [-66.0, -36.0, -15.0, 4.0, 34.0, 48.0, 64.0]:
		spots.append([x, 1])
	for sp in spots:
		if true:
			var xx: float = sp[0]
			var side: int = sp[1]
			var z: float = side * (ROAD_HW + 0.7)
			kit(g, "light-curved", Vector3(xx, 0, z), 0.0 if side == 1 else 180.0, 9.0, {}, ROADS)
			var head := Vector3(xx, 5.4, z - side * 1.5)
			var led := i % 3 == 2  # the city is halfway through swapping sodium for LED
			var lamp_col := Color("dfe8ff") if led else Color("ffa04a")
			part(g, box(Vector3(0.5, 0.08, 0.8)), head + Vector3(0, -0.12, 0), glow(Color("eef3ff") if led else Color("ffb35c"), 6.0))
			var l := OmniLight3D.new()
			l.position = head + Vector3(0, -0.4, 0)
			l.light_color = lamp_col
			l.light_energy = 1.5 if led else 1.9
			l.omni_range = 12.0
			l.omni_attenuation = 1.4
			l.shadow_enabled = i % 3 == 0
			l.light_volumetric_fog_energy = 1.4
			g.add_child(l)
			i += 1
	# quay lamps (cool white)
	for x in [-56.0, -36.0, -14.0, 8.0, 32.0, 56.0]:
		part(g, cyl(0.08, 4.2), Vector3(x, 2.1, WATER_Z - 0.6), mat(Color("2c2c36"), 0.4, ""))
		part(g, sphere(0.25), Vector3(x, 4.3, WATER_Z - 0.6), glow(Color("cfe0ff"), 5.0))
		var ql := OmniLight3D.new()
		ql.position = Vector3(x, 4.0, WATER_Z - 0.8)
		ql.light_color = Color("b9ccff")
		ql.light_energy = 1.8
		ql.omni_range = 10.0
		g.add_child(ql)


func _moon() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("8fa4ff")
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.light_volumetric_fog_energy = 0.4
	add_child(moon)
	moon.basis = Basis.looking_at(Vector3(-0.4, -0.7, 0.55).normalized())
	part(self, sphere(9.0), Vector3(120, 140, 420), glow(Color("dfe6ff"), 3.0))


# ================= Props =================

func _street_props() -> void:
	var g := group("Props")
	# trees in planters along both sidewalks
	var grate := mat(Color("26232e"), 0.6, "")
	for spec in [[-58.0, -1], [-35.0, -1], [7.0, -1], [37.0, -1], [63.0, -1], [-36.0, 1], [2.0, 1], [46.0, 1], [64.0, 1]]:
		var tp := Vector3(spec[0], 0, spec[1] * (ROAD_HW + 1.0))
		kit(g, "tree-large", tp, _rng.randf_range(0, 90), 3.0, {"treeA": _tree_mat()}, RETRO)
		part(g, box(Vector3(1.3, 0.14, 1.3)), tp + Vector3(0, 0.07, 0), grate)
		solid(Vector3(0.5, 3.0, 0.5), tp + Vector3(0, 1.5, 0))
	# benches
	kit(g, "detail-bench", Vector3(-21.0, 0, -(ROAD_HW + 3.2)), 0, 3.2, {}, RETRO)
	kit(g, "detail-bench", Vector3(8.0, 0, ROAD_HW + 3.2), 180, 3.2, {}, RETRO)
	# Dutch bike racks with bikes
	for spec in [[-19.0, -1], [-9.5, -1], [33.5, -1], [-12.0, 1], [48.0, 1]]:
		for i in 3:
			_bike(g, Vector3(spec[0] + i * 0.7, 0, spec[1] * (ROAD_HW + 1.1)), 90.0 + _rng.randf_range(-6, 6), Color.from_hsv(_rng.randf(), 0.5, 0.5))
	# bus stop on the south side
	var bus := Vector3(30.0, 0, ROAD_HW + 2.4)
	part(g, box(Vector3(4.0, 0.08, 1.6)), bus + Vector3(0, 2.4, 0.3), mat(Color("2c2c36"), 0.5, ""))
	part(g, box(Vector3(4.0, 2.3, 0.04)), bus + Vector3(0, 1.2, 1.05), _glass())
	part(g, box(Vector3(1.2, 1.8, 0.08)), bus + Vector3(-1.4, 1.1, 1.0), glow(Color("e6e0ff"), 0.8))
	text3d(g, "STUDIO GRIND\nOUT NOW?", bus + Vector3(-1.4, 1.3, 0.95), Color("1a1426"), 0.0035, Vector3(0, 180, 0), 0.0)
	part(g, cyl(0.05, 2.8), bus + Vector3(2.4, 1.4, -0.2), mat(Color("8a8a98"), 0.4, ""))
	part(g, box(Vector3(0.6, 0.6, 0.04)), bus + Vector3(2.4, 2.7, -0.2), mat(Color("e8c547"), 0.6, ""))
	text3d(g, "4", bus + Vector3(2.4, 2.7, -0.23), Color("1a1426"), 0.006, Vector3(0, 180, 0), 0.0)
	solid(Vector3(4.0, 2.4, 0.2), bus + Vector3(0, 1.2, 1.05))
	# road works closing both ends of the street (the edge of the playable area)
	for end in [X_MIN, X_MAX]:
		for z in range(-9, 10, 2):
			kit(g, "construction-barrier", Vector3(end, 0, z), 90, 7.0, {}, ROADS)
		kit(g, "construction-light", Vector3(end, 0, -ROAD_HW - 1.0), 90, 7.0, {}, ROADS)
		kit(g, "construction-light", Vector3(end, 0, ROAD_HW + 1.0), 90, 7.0, {}, ROADS)
		for i in 5:
			kit(g, "construction-cone", Vector3(end - signf(end) * 2.0, 0, -4.0 + i * 2.0), 0, 6.0, {}, ROADS)
		var wl := OmniLight3D.new()
		wl.position = Vector3(end, 1.6, 0)
		wl.light_color = Color("ff8a1f")
		wl.light_energy = 1.4
		wl.omni_range = 7.0
		g.add_child(wl)


var _tree_m: ShaderMaterial
func _tree_mat() -> ShaderMaterial:
	if _tree_m:
		return _tree_m
	_tree_m = ShaderMaterial.new()
	_tree_m.shader = load("res://assets/shaders/kenney_tint.gdshader")
	_tree_m.set_shader_parameter("colormap", load("res://assets/models/kenney_retro_urban/Textures/treeA.png"))
	_tree_m.set_shader_parameter("saturation", 0.75)
	_tree_m.set_shader_parameter("value", 0.38)
	_tree_m.set_shader_parameter("roughness_base", 0.85)
	_tree_m.set_shader_parameter("metallic_base", 0.0)
	return _tree_m


func _bike(parent: Node3D, pos: Vector3, rot_y: float, color: Color) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation_degrees.y = rot_y
	parent.add_child(b)
	var tyre := mat(Color("141318"), 0.9, "")
	var frame := mat(color, 0.4, "")
	for zz in [-0.52, 0.52]:
		var t := TorusMesh.new()
		t.inner_radius = 0.29
		t.outer_radius = 0.34
		part(b, t, Vector3(0, 0.34, zz), tyre, Vector3(0, 0, 90))
	part(b, cyl(0.025, 0.95), Vector3(0, 0.55, 0), frame, Vector3(90, 0, 0))
	part(b, cyl(0.025, 0.5), Vector3(0, 0.52, -0.25), frame, Vector3(50, 0, 0))
	part(b, cyl(0.025, 0.45), Vector3(0, 0.6, 0.42), frame, Vector3(-20, 0, 0))
	part(b, box(Vector3(0.12, 0.04, 0.24)), Vector3(0, 0.82, -0.32), tyre)  # saddle
	part(b, cyl(0.02, 0.55), Vector3(0, 0.88, 0.48), frame, Vector3(0, 0, 90))  # handlebar


# ================= Cars =================

func _car(model: String, pos: Vector3, rot_y: float, driving := false) -> Node3D:
	var c := kit(self, model, pos, rot_y, CAR_SCALE, {"colormap": _car_mat}, CARS)
	# head + tail lights
	var sz: Vector3 = c.get_meta("size")
	var lights := Node3D.new()
	c.add_child(lights)
	lights.scale = Vector3.ONE / CAR_SCALE
	var brake := glow(Color("ff2020"), 0.8 if driving else 0.0)
	var head := glow(Color("fff2d0"), 3.0) if driving else mat(Color("cfd2dc"), 0.2, "")
	for sx in [-0.55, 0.55]:
		part(lights, box(Vector3(0.3, 0.12, 0.05)), Vector3(sx * sz.x / 1.6, sz.y * 0.32, -sz.z / 2.0 - 0.02), brake)
		part(lights, box(Vector3(0.3, 0.12, 0.05)), Vector3(sx * sz.x / 1.6, sz.y * 0.3, sz.z / 2.0 + 0.02), head)
	c.set_meta("brake", brake)
	if driving:
		var hl := SpotLight3D.new()
		lights.add_child(hl)
		hl.position = Vector3(0, sz.y * 0.3, sz.z / 2.0 + 0.2)
		hl.rotation_degrees = Vector3(-7, 180, 0)
		hl.light_color = Color("fff0d6")
		hl.light_energy = 5.0
		hl.spot_range = 20.0
		hl.spot_angle = 28.0
		hl.light_volumetric_fog_energy = 1.0
		var tl := OmniLight3D.new()
		lights.add_child(tl)
		tl.position = Vector3(0, sz.y * 0.3, -sz.z / 2.0 - 0.4)
		tl.light_color = Color("ff2a1a")
		tl.light_energy = 0.6
		tl.omni_range = 3.5
		c.set_meta("tail", tl)
	return c


func _parked_cars() -> void:
	var models := ["sedan", "taxi", "suv", "hatchback-sports", "van", "sedan-sports", "suv-luxury", "delivery"]
	var spots := [[-60.0, -1], [-51.5, -1], [-24.0, -1], [-5.0, -1], [40.0, -1], [52.0, -1],
		[-30.0, 1], [-18.0, 1], [-2.0, 1], [42.0, 1], [60.0, 1]]
	for i in spots.size():
		var x: float = spots[i][0]
		var side: int = spots[i][1]
		var c := _car(models[i % models.size()], Vector3(x, 0, side * 4.7), 90.0 if side == 1 else -90.0)
		var sz: Vector3 = c.get_meta("size")
		solid(Vector3(sz.z, sz.y, sz.x), Vector3(x, sz.y / 2.0, side * 4.7))
	# police car parked by the casino (watching you)
	var p := _car("police", Vector3(-38.5, 0, 4.7), 90.0)
	var ps: Vector3 = p.get_meta("size")
	solid(Vector3(ps.z, ps.y, ps.x), Vector3(-38.5, ps.y / 2.0, 4.7))


func _traffic() -> void:
	var models := ["taxi", "sedan", "suv", "van", "hatchback-sports"]
	for i in 4:
		var dir := 1 if i % 2 == 0 else -1
		var lane := 1.7 if dir == 1 else -1.7  # the Netherlands: drive on the right
		var x := _rng.randf_range(-140, 140)
		var c := _car(models[i % models.size()], Vector3(x, 0, lane), 90.0 if dir == 1 else -90.0, true)
		cars.append({"node": c, "dir": dir, "lane": lane, "speed": _rng.randf_range(8.0, 11.0), "cur": 9.0, "len": 4.6})


func _drive(delta: float) -> void:
	var ppos := to_local(player.global_position) if player and is_instance_valid(player) else Vector3(9999, 0, 9999)
	for c in cars:
		var n: Node3D = c.node
		var half: float = c.len / 2.0
		var ahead: float = (ppos.x - n.position.x) * c.dir
		var blocked := absf(ppos.z - c.lane) < 2.2 and ahead > 0.0 and ahead < half + 6.0
		if blocked and c.has("bell") and not (c.bell as AudioStreamPlayer3D).playing:
			(c.bell as AudioStreamPlayer3D).play()
		# brake for the car (or tram) in front
		for o in cars:
			if o != c and o.dir == c.dir:
				var gap: float = (o.node.position.x - n.position.x) * c.dir
				if gap > 0.0 and gap < half + o.len / 2.0 + 3.0:
					blocked = true
		# red light at the junction: stop before the line
		if _signal_state != 0:
			var stop_x: float = CROSS_X - 7.5 if c.dir == 1 else CROSS_X + 7.5
			var to_line: float = (stop_x - n.position.x) * c.dir - half
			if to_line > -0.5 and to_line < 14.0:
				blocked = true
		var target: float = 0.0 if blocked else c.speed
		if c.has("stop_x"):
			target = _tram_stop(c, delta, target)
		c.cur = move_toward(c.cur, target, (18.0 if blocked else 5.0) * delta)
		n.position.x += c.dir * c.cur * delta
		if not n.has_meta("brake"):
			if n.position.x * c.dir > 150.0:
				n.position.x = -150.0 * c.dir
				c.served = false
			continue
		var bm: StandardMaterial3D = n.get_meta("brake")
		var braking: bool = c.cur < c.speed * 0.6
		bm.emission_energy_multiplier = 4.0 if braking else 0.8
		if n.has_meta("tail"):
			var tl: OmniLight3D = n.get_meta("tail")
			tl.light_energy = 2.2 if braking else 0.6
		if n.position.x * c.dir > 150.0:
			n.position.x = -150.0 * c.dir


# ================= Shops: opening hours (REALISM R4) =================

func _shop_reg(id: String) -> Dictionary:
	if not _shop_state.has(id):
		_shop_state[id] = {"shutter": null, "lights": [], "mats": []}
	return _shop_state[id]


func is_open(id: String, minutes: int) -> bool:
	return minutes < int(HOURS.get(id, 99999))


func closing_text(id: String) -> String:
	var m := int(HOURS.get(id, 99999)) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## Shutters down, lights off for closed shops.
func update_hours(minutes: int) -> void:
	for id in _shop_state.keys():
		var open := is_open(id, minutes)
		if _open.get(id, null) == open:
			continue
		_open[id] = open
		var st: Dictionary = _shop_state[id]
		if st.shutter:
			(st.shutter as Node3D).visible = not open
		for l in st.lights:
			(l as Light3D).visible = open
		for m in st.mats:
			(m as StandardMaterial3D).emission_energy_multiplier = (0.07 if open else 0.0)


# ================= Weather & ambience (REALISM R5) =================

func apply_weather(w: String) -> void:
	weather = w
	if not _rain:
		_build_rain()
		_build_ambience()
	var raining := w == "rain"
	_rain.emitting = raining
	_rain.visible = raining
	set_rain(1.0 if raining else 0.0)
	set_wetness(1.0 if raining else (0.75 if w == "mist" else 0.45))
	city_env.volumetric_fog_density = 0.028 if w == "mist" else (0.011 if raining else 0.007)
	city_env.fog_density = 0.9 if w == "mist" else (0.72 if raining else 0.55)
	_amb_rain.volume_db = -6.0 if raining else -80.0
	# fewer people out in the rain, and the ones who are out hurry
	for i in pedestrians.size():
		var p := pedestrians[i]
		var smoker := str(p.data.get("persona", "")) == "smoker"
		p.visible = not raining or i % 2 == 0 or smoker
		p.walk_anim = "run" if raining and not smoker else "walk"
		p.speed = (2.4 if raining else 1.15) if not smoker else 0.0


func set_audio_active(on: bool) -> void:
	if not _amb_city:
		return
	for p in [_amb_city, _amb_rain, _amb_water]:
		if on and not p.playing:
			p.play()
		elif not on:
			p.stop()


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 3500
	_rain.lifetime = 1.1
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 1, 22)
	pm.direction = Vector3(0.08, -1, 0.04)
	pm.spread = 2.0
	pm.initial_velocity_min = 15.0
	pm.initial_velocity_max = 19.0
	pm.gravity = Vector3(0, -2, 0)
	_rain.process_material = pm
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.5, 0.012)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.75, 0.8, 0.9, 0.28)
	drop.material = dm
	_rain.draw_pass_1 = drop
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)


func _build_ambience() -> void:
	_amb_city = AudioStreamPlayer.new()
	_amb_city.stream = AmbienceSynth.city()
	_amb_city.volume_db = -14.0
	add_child(_amb_city)
	_amb_rain = AudioStreamPlayer.new()
	_amb_rain.stream = AmbienceSynth.rain()
	_amb_rain.volume_db = -80.0
	add_child(_amb_rain)
	_amb_water = AudioStreamPlayer3D.new()
	_amb_water.stream = AmbienceSynth.water()
	_amb_water.position = Vector3(CROSS_X, 0.5, WATER_Z)
	_amb_water.unit_size = 10.0
	_amb_water.volume_db = -4.0
	add_child(_amb_water)


# ================= Tram, rails, overhead wires, traffic lights (REALISM R4) =================

func _tram_lines() -> void:
	var g := group("TramLines")
	var rail := mat(Color("8d8f96"), 0.25, "")
	rail.metallic = 0.8
	for lane in [-1.7, 1.7]:
		for off in [-0.72, 0.72]:
			part(g, box(Vector3(300, 0.025, 0.08)), Vector3(0, 0.035, lane + off), rail)
		var wire := part(g, cyl(0.015, 300), Vector3(0, 6.3, lane), mat(Color("222228"), 0.5, ""), Vector3(0, 0, 90))
		wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# span wires from facade to facade every 25 m
	for x in range(-62, 70, 25):
		var span := part(g, cyl(0.012, LINE * 2.0), Vector3(x, 6.6, 0), mat(Color("222228"), 0.5, ""), Vector3(90, 0, 0))
		span.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Articulated low-floor tram (3 hollow sections) on line 4. It stops at `stop_x`, opens the doors on the
## sidewalk side for a while (board with E), then drives on. Returns its entry in `cars`.
func _tram(stop_x := -8.0, start_x := -120.0, dest := "4  CENTRAAL") -> Dictionary:
	var t := Node3D.new()
	t.name = "Tram"
	add_child(t)
	var body := mat(Color("c9ccd2"), 0.35, "")
	body.metallic = 0.35
	var stripe := mat(Color("d6302a"), 0.45, "")
	var doors: Array = []
	for seg in 3:
		var holder := Node3D.new()
		holder.position = Vector3(0, 0, -9.4 + seg * 9.4)
		t.add_child(holder)
		var car := carriage(holder, 9.0, 2.5, 2.3, 0.42, body, stripe, [0.0])
		doors.append_array(car.doors)
		if seg < 2:
			part(t, box(Vector3(2.3, 2.5, 0.42)), Vector3(0, 1.62, -9.4 + seg * 9.4 + 4.7), mat(Color("15161a"), 0.9, "fabric"))  # bellows
	# cabs with destination signs and lights
	for e in [-1.0, 1.0]:
		var cz: float = e * 14.15
		part(t, box(Vector3(2.5, 1.0, 0.5)), Vector3(0, 0.95, cz), body)
		part(t, box(Vector3(2.4, 1.2, 0.08)), Vector3(0, 2.0, cz + e * 0.1), mat(Color("0b0d10"), 0.05, ""), Vector3(e * -12.0, 0, 0))
		part(t, box(Vector3(1.6, 0.26, 0.05)), Vector3(0, 2.6, cz + e * 0.18), mat(Color("0a0a0a"), 0.6, ""))
		text3d(t, dest, Vector3(0, 2.6, cz + e * 0.22), Color("ffb547"), 0.0034, Vector3(0, 0 if e > 0 else 180, 0), 3.0)
		for hx in [-0.85, 0.85]:
			part(t, sphere(0.09), Vector3(hx, 0.85, cz + e * 0.27), glow(Color("fff3dc") if e > 0 else Color("ff2a1a"), 4.0))
	part(t, box(Vector3(0.1, 0.9, 1.2)), Vector3(0, 3.35, 0), mat(Color("444"), 0.4, ""), Vector3(25, 0, 0))  # pantograph
	part(t, box(Vector3(1.4, 0.06, 0.1)), Vector3(0, 3.8, 0.2), mat(Color("444"), 0.4, ""))
	t.rotation_degrees.y = 90.0
	t.position = Vector3(start_x, 0, 1.7)
	var hl := SpotLight3D.new()
	t.add_child(hl)
	hl.position = Vector3(0, 0.9, 14.5)
	hl.rotation_degrees = Vector3(-6, 180, 0)
	hl.light_color = Color("fff3dc")
	hl.light_energy = 5.0
	hl.spot_range = 22.0
	hl.spot_angle = 30.0
	var bell := AudioStreamPlayer3D.new()
	bell.stream = AmbienceSynth.tram_bell()
	bell.unit_size = 12.0
	t.add_child(bell)
	var chime := AudioStreamPlayer3D.new()
	chime.stream = AmbienceSynth.chime()
	chime.unit_size = 6.0
	chime.position = Vector3(-1.2, 1.5, 0)
	t.add_child(chime)
	# what you press E on to board: a thick invisible slab on the sidewalk side, only active while the doors are open
	var board := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.6, 2.6, 26.0)
	col.shape = sh
	board.add_child(col)
	board.position = Vector3(-2.0, 1.3, 0)
	board.collision_layer = 0
	board.set_meta("interact", "tram_board")
	board.set_meta("label", "Board tram 4")
	t.add_child(board)
	RoomBuilder.set_doors(doors, 0.0)
	var entry := {"node": t, "dir": 1, "lane": 1.7, "speed": 7.0, "cur": 7.0, "len": 28.5, "bell": bell,
		"stop_x": stop_x, "dwell": 0.0, "served": false, "doors": doors, "door_f": 0.0, "board": board, "chime": chime, "dwell_time": 14.0}
	board.set_meta("tram", entry)
	board.set_meta("builder", self)
	cars.append(entry)
	return entry


## Tram stop shelter ("abri") with a timetable plate and the line number.
func _tram_shelter(x: float, side: int, stop_name: String) -> void:
	var g := Node3D.new()
	g.name = "TramStop"
	g.position = Vector3(x, 0, side * (ROAD_HW + 1.6))
	add_child(g)
	var frame := mat(Color("2b2d33"), 0.35, "")
	frame.metallic = 0.6
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.8, 0.9, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	var back := side * 1.1
	part(g, box(Vector3(4.2, 2.3, 0.04)), Vector3(0, 1.25, back), glass)
	for ex in [-2.1, 2.1]:
		part(g, box(Vector3(0.08, 2.5, 1.2)), Vector3(ex, 1.25, back * 0.5), frame)
	part(g, box(Vector3(4.5, 0.1, 1.5)), Vector3(0, 2.5, back * 0.5), frame)
	part(g, box(Vector3(4.3, 0.06, 1.3)), Vector3(0, 2.44, back * 0.5), glow(Color("e8f0ff"), 1.2))
	part(g, box(Vector3(2.6, 0.08, 0.4)), Vector3(0, 0.5, back * 0.75), mat(Color("6b6f78"), 0.5, ""))
	# advertising light box on one end + stop pole
	part(g, box(Vector3(0.12, 1.7, 1.1)), Vector3(2.25, 1.2, back * 0.5), glow(Color("ffe8c8"), 0.9))
	part(g, cyl(0.05, 3.0), Vector3(-2.6, 1.5, 0), frame)
	part(g, box(Vector3(0.6, 0.6, 0.06)), Vector3(-2.6, 2.75, 0), mat(Color("f4f4f4"), 0.5, ""))
	var face := Vector3(0, 180 if side > 0 else 0, 0)  # towards the road
	text3d(g, "4", Vector3(-2.6, 2.75, -0.04 * side), Color("d6302a"), 0.01, face, 0.0)
	text3d(g, "4", Vector3(-2.6, 2.75, 0.04 * side), Color("d6302a"), 0.01, face + Vector3(0, 180, 0), 0.0)
	text3d(g, stop_name.to_upper(), Vector3(0, 2.62, back * 0.5 - side * 0.76), Color("f4f4f4"), 0.0028, face, 1.0)
	solid(Vector3(4.2, 2.3, 0.2), g.position + Vector3(0, 1.15, back))


## Metro entrance pavilion: glass box with an escalator going down and a big "M" on a pole.
func _metro_entrance(pos: Vector3, rot_y: float, station: String) -> StaticBody3D:
	var g := Node3D.new()
	g.name = "MetroEntrance"
	g.position = pos
	g.rotation_degrees.y = rot_y
	add_child(g)
	var frame := mat(Color("26282e"), 0.35, "")
	frame.metallic = 0.6
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.75, 0.85, 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	# glass walls on 3 sides, open front (+Z)
	part(g, box(Vector3(3.4, 2.8, 0.04)), Vector3(0, 1.4, -1.6), glass)
	for ex in [-1.7, 1.7]:
		part(g, box(Vector3(0.04, 2.8, 3.2)), Vector3(ex, 1.4, 0), glass)
		part(g, box(Vector3(0.1, 2.9, 0.1)), Vector3(ex, 1.45, 1.6), frame)
		part(g, box(Vector3(0.1, 2.9, 0.1)), Vector3(ex, 1.45, -1.6), frame)
	part(g, box(Vector3(3.7, 0.18, 3.5)), Vector3(0, 2.92, 0), frame)
	part(g, box(Vector3(3.2, 0.04, 3.0)), Vector3(0, 2.82, 0), glow(Color("f2f5ff"), 1.4))
	# escalator disappearing into the floor + dark stairwell
	part(g, box(Vector3(2.6, 0.04, 2.6)), Vector3(0, 0.03, -0.2), mat(Color("0b0b0e"), 0.9, ""))
	part(g, box(Vector3(1.1, 0.08, 2.6)), Vector3(-0.6, 0.06, -0.2), mat(Color("6c7078"), 0.3, ""), Vector3(-14, 0, 0))
	part(g, box(Vector3(1.1, 0.08, 2.6)), Vector3(0.6, 0.06, -0.2), mat(Color("6c7078"), 0.3, ""), Vector3(-14, 0, 0))
	for hx in [-1.2, 0.0, 1.2]:
		part(g, box(Vector3(0.08, 0.06, 2.6)), Vector3(hx, 0.95, -0.2), glow(Color("9fd0ff"), 1.5), Vector3(-14, 0, 0))
	# "M" pole
	part(g, cyl(0.07, 4.2), Vector3(2.3, 2.1, 1.5), frame)
	part(g, box(Vector3(0.9, 0.9, 0.12)), Vector3(2.3, 4.3, 1.5), glow(Color("e3261c"), 2.2))
	text3d(g, "M", Vector3(2.3, 4.28, 1.57), Color.WHITE, 0.012, Vector3.ZERO, 2.0)
	text3d(g, "M", Vector3(2.3, 4.28, 1.43), Color.WHITE, 0.012, Vector3(0, 180, 0), 2.0)
	text3d(g, "METRO  " + station.to_upper(), Vector3(0, 3.12, 1.76), Color.WHITE, 0.003, Vector3.ZERO, 1.5)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 2.4, 0.4)
	l.light_color = Color("e8eeff")
	l.light_energy = 1.4
	l.omni_range = 6.0
	g.add_child(l)
	var body := solid(Vector3(2.8, 2.6, 2.0), Vector3.ZERO, "metro_in", "Metro %s  (go down)" % station)
	remove_child(body)
	g.add_child(body)
	body.position = Vector3(0, 1.3, -0.4)
	for ex in [-1.7, 1.7]:
		var w := solid(Vector3(0.1, 2.8, 3.2), Vector3.ZERO)
		remove_child(w)
		g.add_child(w)
		w.position = Vector3(ex, 1.4, 0)
	return body


## Line 4 stop logic: brake smoothly to the stop, doors open (sidewalk side), wait, close, go.
func _tram_stop(c: Dictionary, delta: float, target: float) -> float:
	var n: Node3D = c.node
	if c.dwell > 0.0:
		c.dwell -= delta
		c.cur = 0.0
		c.door_f = move_toward(c.door_f, 1.0 if c.dwell > 1.4 else 0.0, delta * 1.5)
		RoomBuilder.set_doors(c.doors, c.door_f, -1.0)
		(c.board as StaticBody3D).collision_layer = 1 if c.dwell > 1.6 else 0
		if c.dwell <= 0.0:
			c.served = true
			c.door_f = 0.0
			RoomBuilder.set_doors(c.doors, 0.0)
		return 0.0
	var to_stop: float = (c.stop_x - n.position.x) * c.dir
	if not c.served and to_stop > -0.3 and to_stop < 32.0:
		if to_stop < 0.3:
			c.cur = 0.0
			n.position.x = c.stop_x
			c.dwell = c.dwell_time
			if n.is_inside_tree():
				(c.chime as AudioStreamPlayer3D).play()
			return 0.0
		return minf(target, maxf(sqrt(2.0 * 1.4 * to_stop), 0.7))
	return target


func _traffic_lights() -> void:
	var g := group("TrafficLights")
	var pole := mat(Color("3a3d44"), 0.4, "")
	# east-bound lane is on the south half (z > 0), west-bound on the north half
	for spec in [[CROSS_X - 7.5, ROAD_HW + 0.6, 90.0], [CROSS_X + 7.5, -(ROAD_HW + 0.6), -90.0]]:
		var p := Node3D.new()
		p.position = Vector3(spec[0], 0, spec[1])
		p.rotation_degrees.y = spec[2] + 180.0
		g.add_child(p)
		part(p, cyl(0.08, 3.4), Vector3(0, 1.7, 0), pole)
		part(p, box(Vector3(0.38, 1.1, 0.28)), Vector3(0, 3.0, 0), mat(Color("17181c"), 0.6, ""))
		var mats := []
		for k in 3:
			var c: Color = [Color("39ff7a"), Color("ffb020"), Color("ff2a2a")][k]
			var m := glow(c, 0.0)
			part(p, sphere(0.1), Vector3(0, 3.3 - k * 0.3, 0.15), m)
			mats.append(m)
		_signal_lamps.append(mats)
		# stop line
		part(g, box(Vector3(0.4, 0.02, ROAD_HW - 0.2)), Vector3(spec[0], 0.036, signf(spec[1]) * (ROAD_HW - 0.2) / 2.0), mat(Color("b9b7c2"), 0.45, ""))
	_apply_signal()


func _tick_signals(delta: float) -> void:
	_signal_t += delta
	var durations := [22.0, 3.0, 16.0]
	if _signal_t >= durations[_signal_state]:
		_signal_t = 0.0
		_signal_state = (_signal_state + 1) % 3
		_apply_signal()


func _apply_signal() -> void:
	for mats in _signal_lamps:
		for k in 3:
			(mats[k] as StandardMaterial3D).emission_energy_multiplier = 6.0 if k == _signal_state else 0.0


# ================= Life on the street =================

func _smokers() -> void:
	for i in 2:
		var n := NPC.new()
		n.name = "Smoker%d" % i
		add_child(n)
		n.setup({"model": ["worker_male", "casual_female"][i], "recolor": {}, "voice_hz": [115.0, 220.0][i], "accessory": "", "name": ["Rachid", "Nienke"][i], "persona": "smoker"})
		n.position = Vector3(4.6 + i * 1.1, 0, -(ROAD_HW + 2.6))
		n.rotation.y = deg_to_rad(-60.0 + i * 140.0)
		var ember := part(n, sphere(0.018), Vector3(0.22, 1.32, 0.18), glow(Color("ff6a1a"), 6.0))
		ember.name = "Ember"
		pedestrians.append(n)


## People recognise you once you have a name in the scene.
func _greet() -> void:
	if not game or not player or game.reputation < 10:
		return
	for p in pedestrians:
		if not p.visible or _greeted.has(p.name):
			continue
		if p.global_position.distance_to(player.global_position) < 3.2:
			_greeted[p.name] = true
			var lines := ["Yo! You're the producer from Kade 17, right?", "Bro, that last track is on my playlist.", "Kade 17! When are you dropping again?", "My cousin says you made that beat. Respect."]
			p.say(lines[randi() % lines.size()], 3.5)


# ================= Reactions to the player =================

## People notice what you do: bump into them, stare, sneak up behind them, lie on the street.
func _reactions(dt: float) -> void:
	if not player or not is_instance_valid(player):
		return
	var pp: Vector3 = player.global_position
	var cam: Camera3D = player.camera
	var fwd := -cam.global_transform.basis.z
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	var people: Array = pedestrians.duplicate()
	if _bouncer:
		people.append(_bouncer)
	for p: NPC in people:
		if not p.visible:
			continue
		var to_p := p.global_position - pp
		var d := to_p.length()
		if d > 9.0:
			_stare.erase(p.name)
			continue
		# bumped into
		if d < 0.85 and hspeed > 1.0 and p.can_react("bump", 5.0):
			p.face(pp)
			p.react("hit", StreetTalk._pick(StreetTalk.BUMP), 2.2)
			continue
		# lying on the street
		if player.posture == 2 and d < 3.5 and p.can_react("prone", 30.0):
			p.face(pp)
			p.react("interact", StreetTalk._pick(StreetTalk.PRONE), 4.0)
			continue
		# sneaking up behind them
		if player.posture == 1 and d < 2.2:
			var their_fwd := Vector3(sin(p.rotation.y), 0, cos(p.rotation.y))
			if their_fwd.dot(-to_p.normalized()) < -0.3 and p.can_react("sneak", 25.0):
				p.face(pp)
				p.react("", StreetTalk._pick(StreetTalk.SNEAK), 3.0)
				continue
		# staring at them
		var eye := (p.global_position + Vector3(0, 1.5, 0) - cam.global_position).normalized()
		if fwd.dot(eye) > 0.993 and d < 8.0:
			_stare[p.name] = float(_stare.get(p.name, 0.0)) + dt
			if _stare[p.name] > 2.5 and p.can_react("stare", 20.0):
				_stare[p.name] = 0.0
				p.face(pp)
				p.react("", StreetTalk._pick(StreetTalk.STARE), 3.0)
		else:
			_stare.erase(p.name)


## The two smokers talk to each other.
func _smoker_chat() -> void:
	var smokers: Array[NPC] = []
	for p in pedestrians:
		if str(p.data.get("persona", "")) == "smoker" and p.visible:
			smokers.append(p)
	if smokers.size() < 2 or smokers[0].is_busy():
		return
	var pair: Array = StreetTalk.SMOKER_CHAT[_chat_i % StreetTalk.SMOKER_CHAT.size()]
	_chat_i += 1
	smokers[0].say(pair[0], 3.2)
	get_tree().create_timer(3.4).timeout.connect(func():
		if is_instance_valid(smokers[1]) and not smokers[1].is_busy():
			smokers[1].say(pair[1], 3.2))


# ================= Animals, steam, props, seats =================

func _wildlife() -> void:
	cat = StreetCat.new()
	cat.name = "Cat"
	add_child(cat)
	cat.build()
	cat.player = player
	cat.spots = [Vector3(5.0, 0, -8.6), Vector3(-3.0, 0, -8.8), Vector3(CROSS_X - 8.0, 0, 18.0), Vector3(9.0, 0, -7.6)]
	cat.position = cat.spots[0]
	for spec in [[Vector3(-12.0, 0, 37.0), 7, 1.6], [Vector3(30.0, 0, 37.5), 6, 1.4], [Vector3(26.0, 0, 8.6), 5, 1.0]]:
		var f := PigeonFlock.new()
		add_child(f)
		f.position = spec[0]
		f.build(spec[1], spec[2])
		flocks.append(f)


func set_player(p: Node3D) -> void:
	player = p
	if cat:
		cat.player = p
	for f in flocks:
		f.player = p


## Steam rising from the manholes on a cold night.
func _steam() -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(1.4, 1.4)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.8, 0.8, 0.85, 0.09)
	m.roughness = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	m.albedo_texture = gt
	qm.material = m
	for x in [-22.0, 12.0]:
		var s := GPUParticles3D.new()
		s.amount = 10
		s.lifetime = 4.5
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 12.0
		pm.initial_velocity_min = 0.4
		pm.initial_velocity_max = 0.8
		pm.gravity = Vector3(0.15, 0.05, 0)
		pm.scale_min = 0.6
		pm.scale_max = 1.6
		s.process_material = pm
		s.draw_pass_1 = qm
		s.position = Vector3(x, 0.1, 0.9)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)


## Things lying around that you can pick up and throw.
func _loose_props() -> void:
	var cols := [Color("c8ff3d"), Color("d42a2a"), Color("2a6ad4"), Color("e8e8e8")]
	var spots := [Vector3(-20.0, 0.2, -9.1), Vector3(3.8, 0.2, -9.2), Vector3(7.5, 0.2, 9.3), Vector3(-48.0, 0.2, 8.9),
		Vector3(CROSS_X - 8.6, 0.2, 20.0), Vector3(-30.0, 0.2, 38.6), Vector3(29.0, 0.2, 9.4)]
	for i in spots.size():
		var b: RigidBody3D = Props.bottle() if i % 3 == 2 else Props.can(cols[i % cols.size()])
		b.position = spots[i]
		b.rotation = Vector3(deg_to_rad(90.0) if i % 2 == 0 else 0.0, randf() * TAU, 0)
		add_child(b)
	var ball := Props.ball()
	ball.position = Vector3(CROSS_X + 3.0, 0.3, 30.0)
	add_child(ball)
	for i in 2:
		var c := Props.cone()
		c.position = Vector3(X_MAX - 3.0, 0.4, -3.0 + i * 6.0)
		add_child(c)


## Benches you can sit on: [position, yaw the player faces].
func _seats() -> void:
	var specs := [[Vector3(-21.0, 0, -(ROAD_HW + 3.2)), PI], [Vector3(8.0, 0, ROAD_HW + 3.2), 0.0]]
	for x in [-50.0, -30.0, 0.0, 34.0, 52.0]:
		specs.append([Vector3(x, 0, WATER_Z - 1.4), PI])
	for sp in specs:
		var b := solid(Vector3(1.8, 0.5, 0.6), sp[0] + Vector3(0, 0.25, 0), "seat", "Sit down")
		b.set_meta("yaw", sp[1])
		seats.append(b)


# ================= Pedestrians =================

func _pedestrians() -> void:
	var looks := [
		{"model": "casual_female", "recolor": {}, "voice_hz": 230.0, "name": "Sanne", "persona": "student"},
		{"model": "worker_male", "recolor": {}, "voice_hz": 120.0, "name": "Kees", "persona": "nightshift"},
		{"model": "suit_female", "recolor": {}, "voice_hz": 210.0, "name": "Fatima", "persona": "business"},
		{"model": "casual_male", "recolor": {"LightBlue": Color("2e5e3a")}, "voice_hz": 130.0, "name": "Jordy", "persona": "local"},
		{"model": "hoodie_male", "recolor": {"Purple": Color("6b2020")}, "voice_hz": 140.0, "name": "Mo", "persona": "student"},
		{"model": "worker_female", "recolor": {}, "voice_hz": 220.0, "name": "Ilse", "persona": "nightshift"},
	]
	var routes := [
		[Vector3(-64, 0, -8.6), Vector3(-2, 0, -8.6)],
		[Vector3(60, 0, -8.6), Vector3(10, 0, -8.6)],
		[Vector3(-60, 0, 8.4), Vector3(-6, 0, 8.4)],
		[Vector3(64, 0, 8.4), Vector3(45, 0, 8.4)],
		[Vector3(-60, 0, 37.0), Vector3(60, 0, 37.0)],
		[Vector3(CROSS_X + 7.0, 0, 11.0), Vector3(CROSS_X + 7.0, 0, 33.0)],
	]
	for i in looks.size():
		var d: Dictionary = looks[i]
		d["accessory"] = ""
		var p := NPC.new()
		p.name = "Pedestrian%d" % i
		add_child(p)
		p.setup(d)
		p.speed = _rng.randf_range(1.0, 1.35)
		var r: Array = routes[i]
		var start: Vector3 = r[0].lerp(r[1], _rng.randf())
		p.position = start
		pedestrians.append(p)
		_walk_loop(p, r, _rng.randf() < 0.5)


func _walk_loop(p: NPC, route: Array, forward: bool) -> void:
	var target: Vector3 = route[1] if forward else route[0]
	var pts: Array[Vector3] = [target]
	p.walk_path(pts)
	p.arrived.connect(func(): _walk_loop(p, route, not forward), CONNECT_ONE_SHOT)


# ================= Invisible walls =================

func _bounds_walls() -> void:
	solid(Vector3(1, 10, 60), Vector3(X_MIN - 0.5, 5, 10))
	solid(Vector3(1, 10, 60), Vector3(X_MAX + 0.5, 5, 10))
	solid(Vector3(160, 10, 1), Vector3(0, 5, -LINE - 0.5))  # behind north sidewalk
	# south building line, open at the side street
	var left_w := (CROSS_X - 5.0 - 4.0) - X_MIN
	solid(Vector3(left_w, 10, 1), Vector3(X_MIN + left_w / 2.0, 5, LINE + 0.5))
	var right_w := X_MAX - (CROSS_X + 9.0)
	solid(Vector3(right_w, 10, 1), Vector3(X_MAX - right_w / 2.0, 5, LINE + 0.5))
	# side street walls up to the quay
	for sx in [CROSS_X - 9.5, CROSS_X + 9.5]:
		solid(Vector3(1, 10, QUAY_Z - LINE), Vector3(sx, 5, (QUAY_Z + LINE) / 2.0))
	# quay row front + river railing
	var ql := (CROSS_X - 9.0) - X_MIN
	solid(Vector3(ql, 10, 1), Vector3(X_MIN + ql / 2.0, 5, QUAY_Z - 0.5))
	var qr := X_MAX - (CROSS_X + 9.0)
	solid(Vector3(qr, 10, 1), Vector3(X_MAX - qr / 2.0, 5, QUAY_Z - 0.5))
	solid(Vector3(160, 4, 1), Vector3(0, 2, WATER_Z + 0.3))
	solid(Vector3(1, 10, WATER_Z - QUAY_Z + 2), Vector3(X_MIN - 0.5, 5, (QUAY_Z + WATER_Z) / 2.0))
	solid(Vector3(1, 10, WATER_Z - QUAY_Z + 2), Vector3(X_MAX + 0.5, 5, (QUAY_Z + WATER_Z) / 2.0))
