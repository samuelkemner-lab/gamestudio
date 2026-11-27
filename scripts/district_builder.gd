class_name DistrictBuilder
extends CityBuilder
## The other metro/tram stops: compact districts that reuse the Zuidkade toolkit (facade rows,
## PBR materials, line-4 tram, pedestrians with names). Each has one thing to do there:
##   centraal  – Stationsplein: station hall, kiosk (coffee), busking spot, taxis, bikes
##   markt     – Marktstraat: market hall arch, Huisraad warehouse (furniture −15%), döner place
##   haven     – Kraanweg: harbour, cranes, containers, club De Kraan (open mic night)
## The shared night environment lives in the Zuidkade CityBuilder (main swaps it in).

const D_MIN := -56.0
const D_MAX := 56.0
const D_HOURS := {"kiosk": 99999, "huisraad_store": 26 * 60, "doner": 29 * 60, "club": 29 * 60}
const NAMES := {"centraal": "Centraal", "markt": "Marktplein", "haven": "Havenkwartier"}

var district := ""
var features := {}  # name -> StaticBody3D (interactables, for tests)


func build_district(id: String) -> void:
	district = id
	station_id = id
	_rng.seed = hash(id)
	_base_remap = {"_defaultMat": mat(Color("2a2633"), 0.6, "")}
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
	match id:
		"centraal":
			_ground({"street": "Stationsplein", "north_plaza": 14.0, "south_quay": false})
			_centraal()
		"markt":
			_ground({"street": "Marktstraat", "north_plaza": 0.0, "south_quay": false})
			_markt()
		"haven":
			_ground({"street": "Kraanweg", "north_plaza": 0.0, "south_quay": true})
			_haven()
	_d_lights()
	_d_people()
	_d_bounds()
	_decals()


func _process(delta: float) -> void:
	_drive(delta)
	if _rain and player and is_instance_valid(player):
		_rain.global_position = player.global_position + Vector3(0, 9.0, 0)
	_react_t -= delta
	if _react_t <= 0.0:
		_react_t = 0.2
		_reactions(0.2)


func is_open(id: String, minutes: int) -> bool:
	return minutes < int(D_HOURS.get(id, HOURS.get(id, 99999)))


func closing_text(id: String) -> String:
	var m := int(D_HOURS.get(id, 99999)) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## Rain, wet streets and fewer people out. The fog itself lives in the shared city_env.
func apply_weather(w: String) -> void:
	weather = w
	if not _rain:
		_build_rain()
		_build_ambience()
		_amb_water.position = Vector3(0, 0.5, 16.0)
	var raining := w == "rain"
	_rain.emitting = raining
	_rain.visible = raining
	set_rain(1.0 if raining else 0.0)
	set_wetness(1.0 if raining else (0.75 if w == "mist" else 0.45))
	_amb_rain.volume_db = -6.0 if raining else -80.0
	_amb_water.volume_db = -4.0 if district == "haven" else -80.0
	for i in pedestrians.size():
		var p := pedestrians[i]
		p.visible = not raining or i % 2 == 0 or p.speed == 0.0
		if p.speed > 0.0:
			p.walk_anim = "run" if raining else "walk"


func spawn_point() -> Vector3:
	return metro_exit_point()


func tram_stop_point() -> Vector3:
	return to_global(Vector3(tram_stop_x, 0.05, ROAD_HW + 1.0))


# ================= Shared street =================

func _ground(o: Dictionary) -> void:
	var g := group("Streets")
	var asphalt := pbr("Asphalt031", 4.0, Color(0.62, 0.62, 0.66), 0.55, 0.45)
	var walk := pbr("PavingStones128", 2.4, Color(0.78, 0.77, 0.8), 0.35, 0.7)
	var curb := pbr("Concrete034", 2.0, Color(0.7, 0.7, 0.72), 0.0, 0.4, 0.5)
	var paint := mat(Color("b9b7c2"), 0.45, "")
	solid(Vector3(500, 1, 300), Vector3(0, -0.5, 0))
	part(g, box(Vector3(500, 0.1, 300)), Vector3(0, -0.08, 0), pbr("Asphalt031", 5.0, Color(0.3, 0.3, 0.33), 0.3, 0.3))
	part(g, box(Vector3(300, 0.04, ROAD_HW * 2)), Vector3(0, 0.0, 0), asphalt)
	for x in range(-148, 150, 6):
		_paint(g, Vector3(3.0, 0.004, 0.18), Vector3(x, 0.022, 0), paint)
	for side in [-1, 1]:
		part(g, box(Vector3(300, 0.12, 4.0)), Vector3(0, 0.06, side * (ROAD_HW + 2.0)), walk)
		part(g, box(Vector3(300, 0.16, 0.22)), Vector3(0, 0.08, side * (ROAD_HW + 0.11)), curb)
	var plaza: float = o.north_plaza
	if plaza > 0.0:
		part(g, box(Vector3(D_MAX - D_MIN, 0.12, plaza)), Vector3(0, 0.06, -(LINE + plaza / 2.0)), pbr("PavingStones150", 3.0, Color(0.74, 0.72, 0.74), 0.4, 0.7))
	for i in 7:
		_paint(g, Vector3(0.6, 0.004, ROAD_HW * 2 - 1.0), Vector3(-2.4 + i * 0.8, 0.022, 0), paint)
	_street_sign(g, Vector3(-6.0, 0, LINE - 1.0), str(o.street), 0.0)
	_tram_lines()


func _row(specs: Array, side: int) -> void:
	var stone := pbr("Concrete034", 1.5, Color(0.78, 0.76, 0.72), 0.0, 0.4, 0.5)
	var dark_stone := pbr("Concrete047A", 2.0, Color(0.42, 0.41, 0.43), 0.0, 0.5, 0.6)
	var i := 100 if side == 1 else 0
	for spec in specs:
		_facade(spec, side, i, stone, dark_stone)
		i += 1


func _fill_ends(side: int) -> void:
	var fillers := ["building-f", "building-l", "building-k", "building-h", "building-a", "building-c", "building-n"]
	for x in [-70.0, -86.0, -102.0, -120.0, 70.0, 86.0, 102.0, 120.0]:
		_building(fillers[_rng.randi() % fillers.size()], x, side, 0.0 if side == 1 else 180.0)


func _d_lights() -> void:
	var g := group("StreetLights")
	var i := 0
	for x in range(-50, 51, 14):
		for side in [-1, 1]:
			if (i % 2 == 0) == (side == 1):
				continue
			var z: float = side * (ROAD_HW + 0.7)
			kit(g, "light-curved", Vector3(x, 0, z), 0.0 if side == 1 else 180.0, 9.0, {}, ROADS)
			var head := Vector3(x, 5.4, z - side * 1.5)
			var led := i % 3 == 2
			part(g, box(Vector3(0.5, 0.08, 0.8)), head + Vector3(0, -0.12, 0), glow(Color("eef3ff") if led else Color("ffb35c"), 6.0))
			var l := OmniLight3D.new()
			l.position = head + Vector3(0, -0.4, 0)
			l.light_color = Color("dfe8ff") if led else Color("ffa04a")
			l.light_energy = 1.7
			l.omni_range = 12.0
			l.omni_attenuation = 1.4
			l.shadow_enabled = i % 4 == 0
			l.light_volumetric_fog_energy = 1.4
			g.add_child(l)
		i += 1


func _d_people() -> void:
	var looks := {
		"centraal": [
			{"model": "business_male", "name": "Rutger", "persona": "business", "voice_hz": 125.0},
			{"model": "casual_female", "name": "Noor", "persona": "student", "voice_hz": 235.0},
			{"model": "worker_male", "name": "Wim", "persona": "nightshift", "voice_hz": 115.0},
			{"model": "punk_female", "name": "Yara", "persona": "local", "voice_hz": 220.0},
		],
		"markt": [
			{"model": "casual_male", "name": "Daan", "persona": "local", "voice_hz": 135.0},
			{"model": "suit_female", "name": "Esra", "persona": "business", "voice_hz": 215.0},
			{"model": "hoodie_male", "name": "Bilal", "persona": "student", "voice_hz": 140.0},
		],
		"haven": [
			{"model": "punk_male", "name": "Jesse", "persona": "smoker", "voice_hz": 130.0},
			{"model": "punk_female", "name": "Lotte", "persona": "student", "voice_hz": 225.0},
			{"model": "worker_male", "name": "Sjaak", "persona": "nightshift", "voice_hz": 110.0},
		],
	}
	var routes := [
		[Vector3(-50, 0, -8.6), Vector3(40, 0, -8.6)],
		[Vector3(50, 0, 8.4), Vector3(-30, 0, 8.4)],
		[Vector3(-40, 0, 8.4), Vector3(-12, 0, 8.4)],
		[Vector3(20, 0, -8.6), Vector3(50, 0, -8.6)],
	]
	var arr: Array = looks.get(district, [])
	for i in arr.size():
		var d: Dictionary = arr[i]
		d["recolor"] = {}
		d["accessory"] = ""
		var p := NPC.new()
		p.name = "%s_%s" % [district, d.name]
		add_child(p)
		p.setup(d)
		p.speed = _rng.randf_range(1.0, 1.3)
		var r: Array = routes[i % routes.size()]
		p.position = (r[0] as Vector3).lerp(r[1], _rng.randf())
		pedestrians.append(p)
		_walk_loop(p, r, _rng.randf() < 0.5)


func _d_bounds() -> void:
	solid(Vector3(1, 10, 80), Vector3(D_MIN - 0.5, 5, 0))
	solid(Vector3(1, 10, 80), Vector3(D_MAX + 0.5, 5, 0))
	if district != "haven":
		solid(Vector3(D_MAX - D_MIN, 10, 1), Vector3(0, 5, LINE + 0.5))
	if district != "centraal":
		solid(Vector3(D_MAX - D_MIN, 10, 1), Vector3(0, 5, -LINE - 0.5))


func _multimesh_box(parent: Node3D, xfs: Array[Transform3D], m: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box(Vector3(1, 0.02, 1))
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


func _interactable(size: Vector3, pos: Vector3, kind: String, label: String) -> StaticBody3D:
	var b := solid(size, pos, kind, label)
	b.set_meta("builder", self)
	features[kind] = b
	return b


func _shopfront(id: String, title: String, sub: String, x: float, side: int, w: float, col: Color, glass: Color) -> void:
	_storefront({"id": id, "name": title, "x": x, "side": side, "w": w, "color": col, "glass": glass, "sub": sub, "door": "Enter " + title.capitalize()})
	for c in get_children():
		if c is StaticBody3D and c.get_meta("shop_id", "") == id:
			c.set_meta("builder", self)
			features[id] = c


# ================= Centraal =================

func _centraal() -> void:
	# south row: hotel + offices
	_row([[-48.0, 14.0, 6, "wederopbouw", ""], [-34.0, 14.0, 8, "plaster", ""], [-20.0, 14.0, 7, "wederopbouw", ""],
		[-4.0, 18.0, 9, "plaster", ""], [13.0, 16.0, 6, "prewar", ""], [29.0, 16.0, 7, "wederopbouw", ""], [45.0, 16.0, 6, "plaster", ""]], 1)
	_flush_facade_batches(pbr("Concrete034", 1.5, Color(0.78, 0.76, 0.72), 0.0, 0.4, 0.5))
	_fill_ends(1)
	text3d(self, "HOTEL MAAS", Vector3(-4.0, 30.5, LINE - 0.4), Color("ffd27a"), 0.02, Vector3(0, 180, 0), 3.0)
	# station hall: long glass front, columns, and the pointed roof that sticks out over the square
	var hall := group("StationHall")
	var back_z := -(LINE + 14.0)
	var steel := mat(Color("2c2f36"), 0.35, "")
	steel.metallic = 0.7
	var glass := glow(Color("ffd9a8"), 0.35)
	glass.albedo_color = Color(0.08, 0.07, 0.06)
	part(hall, box(Vector3(70, 9, 0.2)), Vector3(0, 4.5, back_z - 0.1), glass)
	for x in range(-34, 35, 4):
		part(hall, box(Vector3(0.25, 9.2, 0.35)), Vector3(x, 4.6, back_z), steel)
	part(hall, box(Vector3(72, 2.0, 20)), Vector3(0, 10.0, back_z - 10.0), mat(Color("1d1f24"), 0.6, ""))
	# pointed roof: a sloped slab rising towards the square, steel underside with light lines
	var roof := MeshInstance3D.new()
	roof.mesh = box(Vector3(46, 0.6, 24))
	roof.material_override = steel
	hall.add_child(roof)
	roof.position = Vector3(0, 14.0, back_z + 5.0)
	roof.rotation_degrees = Vector3(-24, 0, 0)
	for k in 9:
		var strip := MeshInstance3D.new()
		strip.mesh = box(Vector3(0.12, 0.05, 23))
		strip.material_override = glow(Color("f2f0ea"), 2.2)
		hall.add_child(strip)
		strip.position = Vector3(-20 + k * 5, 13.6, back_z + 5.0)
		strip.rotation_degrees = Vector3(-24, 0, 0)
	text3d(hall, "CENTRAAL", Vector3(0, 18.6, back_z + 15.9), Color("f4efe6"), 0.03, Vector3(-24, 0, 0), 2.5)
	var hl := OmniLight3D.new()
	hl.position = Vector3(0, 6.0, back_z + 4.0)
	hl.light_color = Color("ffd9a8")
	hl.light_energy = 2.4
	hl.omni_range = 22.0
	hall.add_child(hl)
	solid(Vector3(70, 10, 1), Vector3(0, 5, back_z - 0.6))
	_interactable(Vector3(8, 4, 1.2), Vector3(0, 2, back_z + 0.6), "station_hall", "Station hall")
	# bike racks full of bikes (Dutch!)
	var cols := [Color("2b2b33"), Color("6b1f22"), Color("1f3a5a"), Color("c8c8cc"), Color("2f4a2a")]
	for k in 18:
		_bike(self, Vector3(-30 + k * 0.75, 0, back_z + 3.0), 0.0, cols[k % cols.size()])
	part(self, box(Vector3(14, 0.08, 0.08)), Vector3(-23.6, 0.55, back_z + 3.0), mat(Color("8a8c94"), 0.3, ""))
	solid(Vector3(14, 1.2, 1.2), Vector3(-23.6, 0.6, back_z + 3.0))
	# taxi rank
	for k in 3:
		var c := _car("taxi", Vector3(14.0 + k * 6.0, 0, -4.7), -90.0)
		var sz: Vector3 = c.get_meta("size")
		solid(Vector3(sz.z, sz.y, sz.x), Vector3(14.0 + k * 6.0, sz.y / 2.0, -4.7))
	# kiosk (coffee) and the busking spot
	var kz := -(LINE + 5.0)
	part(self, box(Vector3(3.2, 2.6, 2.2)), Vector3(22.0, 1.3, kz), mat(Color("2a3b2f"), 0.6, ""))
	part(self, box(Vector3(2.4, 1.0, 0.05)), Vector3(22.0, 1.6, kz + 1.12), glow(Color("ffe9b8"), 1.4))
	part(self, box(Vector3(3.6, 0.15, 2.8)), Vector3(22.0, 2.7, kz + 0.3), mat(Color("1a1a1e"), 0.6, ""))
	text3d(self, "KIOSK  ·  KOFFIE", Vector3(22.0, 2.95, kz + 1.72), Color("ffe9b8"), 0.004, Vector3.ZERO, 2.0)
	_interactable(Vector3(3.2, 2.6, 2.6), Vector3(22.0, 1.3, kz + 0.2), "kiosk", "Kiosk: coffee (€3, stay up 30 min longer)")
	part(self, cyl(1.4, 0.04), Vector3(-6.0, 0.13, kz), glow(Color("ffcf8a"), 0.6))
	part(self, box(Vector3(0.5, 0.7, 0.4)), Vector3(-6.0, 0.35, kz - 0.6), mat(Color("15151a"), 0.5, ""))
	part(self, cyl(0.12, 0.02), Vector3(-6.0, 0.45, kz - 0.39), mat(Color("444"), 0.4, ""), Vector3(90, 0, 0))
	_interactable(Vector3(2.2, 1.6, 2.2), Vector3(-6.0, 0.8, kz), "busk", "Busk: play your beats for tips (30 min)")
	# metro + tram
	metro_entrance = _metro_entrance(Vector3(-16.0, 0, -(LINE + 5.0)), 0.0, "Centraal")
	metro_entrance.set_meta("station", "centraal")
	tram_stop_x = 8.0
	tram4 = _tram(tram_stop_x, -100.0, "4  MARKTPLEIN")
	_tram_shelter(tram_stop_x, 1, "Centraal")
	solid(Vector3(1, 10, 16), Vector3(D_MIN - 0.5, 5, -(LINE + 7.0)))
	solid(Vector3(1, 10, 16), Vector3(D_MAX + 0.5, 5, -(LINE + 7.0)))


# ================= Marktplein =================

func _markt() -> void:
	_row([[-48.0, 14.0, 5, "prewar", ""], [-34.0, 14.0, 4, "plaster", ""], [32.0, 14.0, 5, "plaster", ""], [47.0, 16.0, 6, "wederopbouw", ""]], -1)
	_row([[-46.0, 18.0, 5, "wederopbouw", ""], [-26.0, 16.0, 4, "prewar", "huisraad_store"], [-10.0, 12.0, 4, "plaster", "doner"],
		[8.0, 16.0, 5, "prewar", ""], [26.0, 14.0, 4, "wederopbouw", ""], [44.0, 18.0, 5, "plaster", ""]], 1)
	_flush_facade_batches(pbr("Concrete034", 1.5, Color(0.78, 0.76, 0.72), 0.0, 0.4, 0.5))
	_fill_ends(-1)
	_fill_ends(1)
	_shopfront("huisraad_store", "HUISRAAD", "MEUBELS · LAMPEN · KLEDEN", -26.0, 1, 16.0, Color("e0a43a"), Color("ffe2a8"))
	_shopfront("doner", "DONER PALACE", "DÖNER · DURUM · KAPSALON", -10.0, 1, 12.0, Color("ff5a3d"), Color("ffd0a0"))
	# market hall: a huge arch, its glass end wall glowing with the painted ceiling inside
	var g := group("MarketHall")
	var arch := cyl(17.0, 46.0)
	arch.radial_segments = 48
	var hall_m := pbr("Concrete034", 2.0, Color(0.62, 0.62, 0.64), 0.0, 0.4, 0.5)
	part(g, arch, Vector3(0, -1.0, -(LINE + 23.2)), hall_m, Vector3(90, 0, 0))
	var cap := cyl(16.2, 0.3)
	cap.radial_segments = 48
	var mural := glow(Color("ff8a3d"), 0.9)
	part(g, cap, Vector3(0, -1.0, -(LINE + 0.05)), mural, Vector3(90, 0, 0))
	var mull := mat(Color("1d1f24"), 0.4, "")
	for k in 11:
		var mx := -15.0 + k * 3.0
		var mh := 2.0 * sqrt(maxf(16.0 * 16.0 - mx * mx, 0.0))
		part(g, box(Vector3(0.18, mh, 0.12)), Vector3(mx, -1.0, -(LINE - 0.05)), mull)
	for k in 6:
		var my := 1.5 + k * 2.6
		var mw := 2.0 * sqrt(maxf(16.0 * 16.0 - (my + 1.0) * (my + 1.0), 0.0))
		part(g, box(Vector3(mw, 0.16, 0.12)), Vector3(0, my, -(LINE - 0.05)), mull)
	var ml := OmniLight3D.new()
	ml.position = Vector3(0, 4.0, -(LINE - 3.0))
	ml.light_color = Color("ffa860")
	ml.light_energy = 2.0
	ml.omni_range = 18.0
	g.add_child(ml)
	_interactable(Vector3(12, 4, 1), Vector3(0, 2, -LINE), "market_hall", "Market hall")
	# closed market stalls with striped tarps
	for k in 6:
		var sx: float = [-22.0, -14.0, -6.0, 6.0, 14.0, 22.0][k]
		part(self, box(Vector3(3.0, 0.9, 1.0)), Vector3(sx, 0.45, -(LINE - 0.6)), mat(Color("3a3530"), 0.8, "wood"))
		part(self, box(Vector3(3.3, 0.06, 1.4)), Vector3(sx, 2.2, -(LINE - 0.8)), mat([Color("b8322e"), Color("2f6b9a"), Color("e8e2d2")][k % 3], 0.8, "fabric"), Vector3(-12, 0, 0))
		solid(Vector3(3.0, 1.0, 1.0), Vector3(sx, 0.5, -(LINE - 0.6)))
	metro_entrance = _metro_entrance(Vector3(50.0, 0, -8.2), 0.0, "Marktplein")
	metro_entrance.set_meta("station", "markt")
	tram_stop_x = 4.0
	tram4 = _tram(tram_stop_x, -100.0, "4  ZUIDKADE")
	_tram_shelter(tram_stop_x, 1, "Marktplein")


# ================= Havenkwartier =================

func _haven() -> void:
	_row([[-48.0, 16.0, 4, "prewar", ""], [-30.0, 20.0, 3, "prewar", "club"], [-8.0, 18.0, 4, "wederopbouw", ""],
		[12.0, 16.0, 3, "prewar", ""], [30.0, 18.0, 4, "prewar", ""], [47.0, 16.0, 3, "wederopbouw", ""]], -1)
	_flush_facade_batches(pbr("Concrete034", 1.5, Color(0.78, 0.76, 0.72), 0.0, 0.4, 0.5))
	_fill_ends(-1)
	_shopfront("club", "DE KRAAN", "CLUB · OPEN MIC · DO-ZA", -30.0, -1, 20.0, Color("7a5cff"), Color("b8a8ff"))
	# a queue at the club door and a bouncer
	var queue := [{"model": "hoodie_male", "name": "Koen", "persona": "student"}, {"model": "casual_female", "name": "Ilona", "persona": "local"},
		{"model": "punk_male", "name": "Ricardo", "persona": "student"}]
	for i in queue.size():
		var d: Dictionary = queue[i]
		d["recolor"] = {}
		d["accessory"] = ""
		d["voice_hz"] = 150.0 + i * 30.0
		var p := NPC.new()
		add_child(p)
		p.setup(d)
		p.speed = 0.0
		p.position = Vector3(-30.0 + 20.0 * 0.32 + 1.6 + i * 0.9, 0, -(LINE - 1.4))
		p.rotation.y = -PI * 0.5
		pedestrians.append(p)
	var bouncer := NPC.new()
	add_child(bouncer)
	bouncer.setup({"model": "business_male", "name": "Mo Kraan", "persona": "bouncer", "recolor": {"Grey": Color("111111")}, "accessory": "", "voice_hz": 95.0})
	bouncer.speed = 0.0
	bouncer.position = Vector3(-30.0 + 20.0 * 0.32 - 1.4, 0, -(LINE - 1.2))
	bouncer.rotation.y = 0.0
	_bouncer = bouncer
	# the harbour: quay edge, water, cranes and stacked containers
	var g := group("Harbour")
	var stone := pbr("PavingStones150", 3.0, Color(0.7, 0.7, 0.72), 0.45, 0.7)
	part(g, box(Vector3(140, 0.12, 6.0)), Vector3(0, 0.06, LINE + 3.0), stone)
	part(g, box(Vector3(300, 3.0, 0.8)), Vector3(0, -1.5, LINE + 6.4), pbr("Concrete047A", 3.0, Color(0.45, 0.45, 0.48), 0.0, 0.5, 0.6))
	var rail := mat(Color("5c5a68"), 0.35, "")
	part(g, cyl(0.05, 112.0), Vector3(0, 1.05, LINE + 5.8), rail, Vector3(0, 0, 90))
	for x in range(-56, 57, 2):
		part(g, cyl(0.04, 1.05), Vector3(x, 0.52, LINE + 5.8), rail)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("070a16")
	water.metallic = 0.6
	water.roughness = 0.08
	part(g, box(Vector3(600, 0.1, 300)), Vector3(0, -1.2, LINE + 156.0), water)
	for c in 3:
		var cx := -40.0 + c * 40.0
		var cz := LINE + 55.0 + c * 8.0
		var crane := mat(Color("b8452a") if c != 1 else Color("2f6b9a"), 0.6, "")
		for lx in [-5.0, 5.0]:
			for lz in [-4.0, 4.0]:
				part(g, box(Vector3(0.8, 30, 0.8)), Vector3(cx + lx, 14, cz + lz), crane)
		part(g, box(Vector3(12, 3, 9)), Vector3(cx, 30, cz), crane)
		part(g, box(Vector3(2.0, 1.6, 56)), Vector3(cx, 33, cz - 12), crane)
		part(g, sphere(0.6), Vector3(cx, 34.5, cz - 39), glow(Color("ff2a1a"), 8.0))
		part(g, sphere(0.6), Vector3(cx, 34.5, cz + 15), glow(Color("ff2a1a"), 8.0))
		# work lights under the boom and on the legs
		for k in 5:
			part(g, box(Vector3(0.6, 0.15, 0.6)), Vector3(cx, 32.1, cz - 36 + k * 11.0), glow(Color("fff1d6"), 6.0))
		var fl := SpotLight3D.new()
		fl.position = Vector3(cx, 31.5, cz - 8)
		fl.rotation_degrees = Vector3(-90, 0, 0)
		fl.light_color = Color("fff1d6")
		fl.light_energy = 6.0
		fl.spot_range = 45.0
		fl.spot_angle = 40.0
		g.add_child(fl)
	var cont_cols := [Color("8a2a22"), Color("1f4a7a"), Color("c88a1f"), Color("2f6a3a"), Color("6a6a70")]
	for k in 40:
		var bx := -60.0 + (k % 10) * 13.0
		var by := 1.3 + (k / 10) * 2.6
		part(g, box(Vector3(12.0, 2.5, 2.4)), Vector3(bx, by - 1.2, LINE + 70.0 + (k / 10) * 0.2), mat(cont_cols[(k * 7) % cont_cols.size()], 0.7, ""))
	# yard light masts + light on the water
	for x in [-45.0, 0.0, 45.0]:
		part(g, cyl(0.25, 24.0), Vector3(x, 11.0, LINE + 64.0), mat(Color("3a3c42"), 0.4, ""))
		part(g, box(Vector3(3.0, 0.4, 1.0)), Vector3(x, 23.2, LINE + 64.0), glow(Color("ffd39a"), 7.0))
		var yl := OmniLight3D.new()
		yl.position = Vector3(x, 21.0, LINE + 62.0)
		yl.light_color = Color("ffc98a")
		yl.light_energy = 4.0
		yl.omni_range = 40.0
		g.add_child(yl)
	var refl: Array[Transform3D] = []
	for k in 40:
		refl.append(Transform3D(Basis().scaled(Vector3(_rng.randf_range(0.6, 2.0), 1, _rng.randf_range(8, 26))), Vector3(_rng.randf_range(-60, 60), -1.09, LINE + _rng.randf_range(20, 60))))
	_multimesh_box(g, refl, glow(Color("ffb46a"), 1.2))
	for x in range(-50, 51, 20):
		part(g, cyl(0.06, 3.8), Vector3(x, 1.9, LINE + 5.5), mat(Color("2c2c36"), 0.4, ""))
		part(g, sphere(0.22), Vector3(x, 3.9, LINE + 5.5), glow(Color("cfe0ff"), 5.0))
		var ql := OmniLight3D.new()
		ql.position = Vector3(x, 3.6, LINE + 5.0)
		ql.light_color = Color("b9ccff")
		ql.light_energy = 1.6
		ql.omni_range = 9.0
		g.add_child(ql)
	solid(Vector3(D_MAX - D_MIN, 4, 1), Vector3(0, 2, LINE + 6.2))
	metro_entrance = _metro_entrance(Vector3(48.0, 0, -8.2), 0.0, "Havenkwartier")
	metro_entrance.set_meta("station", "haven")
	tram4 = {}
