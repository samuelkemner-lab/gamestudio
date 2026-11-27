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
	_bmat = ShaderMaterial.new()
	_bmat.shader = load("res://assets/shaders/night_building.gdshader")
	_bmat.set_shader_parameter("colormap", load("res://assets/models/kenney_city/Textures/colormap.png"))
	_bmat.set_shader_parameter("per_building", true)
	_bmat.set_shader_parameter("lit_chance", 0.5)
	_bmat.set_shader_parameter("window_energy", 0.5)
	_bmat.set_shader_parameter("facade_brightness", 0.26)
	_ground_and_roads()
	_north_side()
	_south_side()
	_casino()
	_quay_and_river()
	_street_lights()
	_street_props()
	_parked_cars()
	_traffic()
	_pedestrians()
	_bounds_walls()
	_moon()


func spawn_point() -> Vector3:
	return to_global(spawn_local)


# ================= Ground, roads, sidewalks =================

func _ground_and_roads() -> void:
	var g := group("Streets")
	var asphalt := mat(Color("24222b"), 0.85, "plaster", 0.25)
	var walk := mat(Color("4b4856"), 0.9, "plaster", 0.35)
	var curb := mat(Color("6e6a7a"), 0.8, "")
	var paint := mat(Color("d9d6e0"), 0.7, "")
	var yellow := mat(Color("e8c547"), 0.7, "")
	# ground collision (everything walkable is at y = 0)
	solid(Vector3(600, 1, 600), Vector3(0, -0.5, 0))
	# far ground
	part(g, box(Vector3(600, 0.1, 300 + WATER_Z)), Vector3(0, -0.08, (WATER_Z - 300) / 2.0), mat(Color("121019"), 1.0, "plaster", 0.1))
	# main road (continues into the dark both ways for traffic)
	part(g, box(Vector3(300, 0.04, ROAD_HW * 2)), Vector3(0, 0.0, 0), asphalt)
	for x in range(-148, 150, 6):
		part(g, box(Vector3(3.0, 0.02, 0.18)), Vector3(x, 0.03, 0), paint)  # dashed centre line
	for z in [-3.4, 3.4]:
		part(g, box(Vector3(300, 0.02, 0.12)), Vector3(0, 0.03, z), paint)  # parking lane line
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
			part(g, box(Vector3(0.6, 0.02, ROAD_HW * 2 - 1.0)), Vector3(zx[0] - 2.4 + i * 0.8, 0.035, zx[1]), paint)
	for i in 6:
		part(g, box(Vector3(9.0, 0.02, 0.5)), Vector3(CROSS_X, 0.035, ROAD_HW + 1.4 + i * 0.7), paint)
	# yellow "no parking" in front of the casino
	part(g, box(Vector3(20.0, 0.02, 0.14)), Vector3(-50.0, 0.035, ROAD_HW - 0.3), yellow)
	# street name signs (Dutch blue plates)
	_street_sign(g, Vector3(CROSS_X - 5.6, 0, LINE - 1.0), "Zuidkade", 0.0)
	_street_sign(g, Vector3(CROSS_X + 5.6, 0, LINE + 2.0), "Maasboulevard", 90.0)


func _street_sign(parent: Node3D, pos: Vector3, text: String, rot_y: float) -> void:
	var s := Node3D.new()
	s.position = pos
	s.rotation_degrees.y = rot_y
	parent.add_child(s)
	part(s, cyl(0.05, 2.8), Vector3(0, 1.4, 0), mat(Color("8a8a98"), 0.4, ""))
	part(s, box(Vector3(1.5, 0.32, 0.04)), Vector3(0, 2.6, 0), mat(Color("1d4fb8"), 0.6, ""))
	text3d(s, text, Vector3(0, 2.6, 0.03), Color("f4f4f4"), 0.0036, Vector3.ZERO, 0.0)
	text3d(s, text, Vector3(0, 2.6, -0.03), Color("f4f4f4"), 0.0036, Vector3(0, 180, 0), 0.0)


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
	var slots := {-56.0: "building-f", -42.0: "building-m", -28.0: "building-k", -14.0: "building-c",
		0.0: "building-e", 14.0: "building-l", 30.0: "building-a", 44.0: "building-n", 58.0: "building-h"}
	for x in slots.keys():
		_building(slots[x], x, -1)
	# backdrop row behind (rooftops seen from the quay / street)
	for i in 12:
		var m: String = fillers[i % fillers.size()]
		_building(m, -66.0 + i * 12.0, -1, 0.0, BSCALE * 1.15, 26.0)
	for s in SHOPS:
		if s.side == -1:
			_storefront(s)
	_alleys(-1, slots.keys())


func _south_side() -> void:
	var slots := {-24.0: "building-i", -6.0: "building-b", 40.0: "building-g", 56.0: "building-d", -66.0: "building-j"}
	for x in slots.keys():
		_building(slots[x], x, 1)
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
	_alleys(1, [-24.0, -6.0, 40.0, 56.0])


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
		part(g, box(Vector3(ww, 2.5, 0.05)), Vector3(wx, 1.6, 0.34), glow(Color(s.glass).darkened(0.25), 0.2))
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
	part(g, box(Vector3(1.4, 2.45, 0.05)), Vector3(dx, 1.25, 0.37), glow(Color(s.glass).darkened(0.45), 0.25))
	part(g, box(Vector3(0.06, 0.5, 0.06)), Vector3(dx - 0.45, 1.2, 0.43), mat(Color("c9c9d4"), 0.3, ""))
	var door := solid(Vector3(1.8, 2.7, 0.6), g.transform * Vector3(dx, 1.35, 0.5), "shop", str(s.door), g.rotation_degrees.y)
	door.set_meta("shop_id", s.id)
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
	l.light_energy = 2.4 if not is_home else 1.6
	l.omni_range = 8.5
	l.light_volumetric_fog_energy = 0.6
	add_child(l)


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
	bouncer.setup({"model": "business_male", "voice_hz": 95.0, "recolor": {}, "accessory": ""})
	bouncer.position = g.transform * Vector3(2.4, 0, 1.1)
	bouncer.rotation.y = 0.0
	bouncer.name = "Bouncer"


func _process(delta: float) -> void:
	if _chip:
		_chip.rotation.y += delta * 0.8
	_drive(delta)


# ================= Quay, river, bridge, skyline =================

func _quay_and_river() -> void:
	var g := group("Quay")
	var stone := mat(Color("5a5664"), 0.9, "plaster", 0.4)
	part(g, box(Vector3(140, 0.12, WATER_Z - QUAY_Z)), Vector3(0, 0.06, (QUAY_Z + WATER_Z) / 2.0), stone)
	part(g, box(Vector3(300, 3.0, 0.8)), Vector3(0, -1.5, WATER_Z + 0.4), mat(Color("2a2832"), 0.9, "plaster"))
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
	# cable-stayed bridge across the river: two white pylons, glowing fan cables, red warning lights
	var white := mat(Color("d8dbe6"), 0.5, "")
	var bz := 190.0
	part(g, box(Vector3(520, 1.6, 18)), Vector3(40, 14.0, bz), mat(Color("2c2a36"), 0.8, ""))
	for x in range(-200, 280, 40):
		part(g, box(Vector3(5, 14, 5)), Vector3(x, 6.0, bz), mat(Color("24222c"), 0.9, ""))
	var cable_m := glow(Color("c8d4ff"), 0.9)
	for px in [10.0, 130.0]:
		part(g, box(Vector3(3.5, 80, 3.5)), Vector3(px, 40, bz), white).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part(g, sphere(1.0), Vector3(px, 81, bz), glow(Color("ff3030"), 8.0))
		for k in 7:
			for sgn in [-1, 1]:
				var start := Vector3(px, 76 - k * 5.0, bz)
				var anchor := Vector3(px + sgn * (14 + k * 9.0), 14.8, bz)
				var mid := (anchor + start) / 2.0
				var cable := MeshInstance3D.new()
				cable.mesh = cyl(0.22, anchor.distance_to(start))
				cable.material_override = cable_m
				cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				g.add_child(cable)
				cable.position = mid
				cable.basis = Basis(Quaternion(Vector3.UP, (anchor - start).normalized()))
	var deck_lights: Array[Transform3D] = []
	for x in range(-220, 300, 6):
		deck_lights.append(Transform3D(Basis(), Vector3(x, 15.0, bz - 9.2)))
	var dmm := MultiMesh.new()
	dmm.transform_format = MultiMesh.TRANSFORM_3D
	dmm.mesh = sphere(0.35)
	dmm.instance_count = deck_lights.size()
	for i in deck_lights.size():
		dmm.set_instance_transform(i, deck_lights[i])
	var dmmi := MultiMeshInstance3D.new()
	dmmi.multimesh = dmm
	dmmi.material_override = glow(Color("9fc4ff"), 5.0)
	g.add_child(dmmi)
	# skyline across the river
	var far := mat(Color("0d0c17"), 0.9, "")
	var lights: Array[Transform3D] = []
	for i in 46:
		var w := _rng.randf_range(10, 22)
		var h := _rng.randf_range(20, 95)
		var x := _rng.randf_range(-260, 300)
		var z := _rng.randf_range(260, 340)
		part(g, box(Vector3(w, h, w)), Vector3(x, h / 2.0 - 1.0, z), far).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for row in range(1, int(h / 3.2)):
			for c in range(int(w / 2.4)):
				if _rng.randf() < 0.33:
					lights.append(Transform3D(Basis().rotated(Vector3.UP, PI / 2.0).scaled(Vector3(1.8, 1.8, 1.8)), Vector3(x - w / 2.0 + 1.2 + c * 2.4, row * 3.2 - 1.0, z - w / 2.0 - 0.05)))
	_multimesh(g, lights, glow(Color("ffc27a"), 2.2))


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
			part(g, box(Vector3(0.5, 0.08, 0.8)), head + Vector3(0, -0.12, 0), glow(Color("ffb35c"), 6.0))
			var l := OmniLight3D.new()
			l.position = head + Vector3(0, -0.4, 0)
			l.light_color = Color("ffa04a")
			l.light_energy = 1.9
			l.omni_range = 12.0
			l.omni_attenuation = 1.3
			l.shadow_enabled = i % 4 == 0
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
	moon.light_energy = 0.9
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
		kit(g, "tree-large", tp, _rng.randf_range(0, 90), 3.0, {}, RETRO)
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

func _car(model: String, pos: Vector3, rot_y: float) -> Node3D:
	var c := kit(self, model, pos, rot_y, CAR_SCALE, {}, CARS)
	# head + tail lights
	var sz: Vector3 = c.get_meta("size")
	var lights := Node3D.new()
	c.add_child(lights)
	lights.scale = Vector3.ONE / CAR_SCALE
	var brake := glow(Color("ff2020"), 0.8)
	for sx in [-0.55, 0.55]:
		part(lights, box(Vector3(0.3, 0.12, 0.05)), Vector3(sx * sz.x / 1.6, sz.y * 0.32, -sz.z / 2.0 - 0.02), brake)
		part(lights, box(Vector3(0.3, 0.12, 0.05)), Vector3(sx * sz.x / 1.6, sz.y * 0.3, sz.z / 2.0 + 0.02), glow(Color("fff2d0"), 3.0))
	c.set_meta("brake", brake)
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
		var lane := -1.7 if dir == 1 else 1.7
		var x := _rng.randf_range(-140, 140)
		var c := _car(models[i % models.size()], Vector3(x, 0, lane), 90.0 if dir == 1 else -90.0)
		cars.append({"node": c, "dir": dir, "lane": lane, "speed": _rng.randf_range(8.0, 11.0), "cur": 9.0})


func _drive(delta: float) -> void:
	var ppos := to_local(player.global_position) if player and is_instance_valid(player) else Vector3(9999, 0, 9999)
	for c in cars:
		var n: Node3D = c.node
		var ahead: float = (ppos.x - n.position.x) * c.dir
		var blocked := absf(ppos.z - c.lane) < 2.2 and ahead > 0.0 and ahead < 9.0
		# brake for the player and for the car in front
		for o in cars:
			if o != c and o.dir == c.dir:
				var gap: float = (o.node.position.x - n.position.x) * c.dir
				if gap > 0.0 and gap < 8.0:
					blocked = true
		var target: float = 0.0 if blocked else c.speed
		c.cur = move_toward(c.cur, target, (18.0 if blocked else 5.0) * delta)
		n.position.x += c.dir * c.cur * delta
		var bm: StandardMaterial3D = n.get_meta("brake")
		bm.emission_energy_multiplier = 4.0 if c.cur < c.speed * 0.6 else 0.8
		if n.position.x * c.dir > 150.0:
			n.position.x = -150.0 * c.dir


# ================= Pedestrians =================

func _pedestrians() -> void:
	var looks := [
		{"model": "casual_female", "recolor": {}, "voice_hz": 230.0},
		{"model": "worker_male", "recolor": {}, "voice_hz": 120.0},
		{"model": "suit_female", "recolor": {}, "voice_hz": 210.0},
		{"model": "casual_male", "recolor": {"LightBlue": Color("2e5e3a")}, "voice_hz": 130.0},
		{"model": "hoodie_male", "recolor": {"Purple": Color("6b2020")}, "voice_hz": 140.0},
		{"model": "worker_female", "recolor": {}, "voice_hz": 220.0},
	]
	var routes := [
		[Vector3(-64, 0, -8.6), Vector3(-2, 0, -8.6)],
		[Vector3(60, 0, -8.6), Vector3(10, 0, -8.6)],
		[Vector3(-60, 0, 8.4), Vector3(-6, 0, 8.4)],
		[Vector3(64, 0, 8.4), Vector3(32, 0, 8.4)],
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
