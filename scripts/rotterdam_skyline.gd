class_name RotterdamSkyline
extends RefCounted
## The view across the Maas from the Zuidkade: a swan-necked cable-stayed bridge, the observation
## tower in the park, the market-hall arch, the tilted cube houses and a "Manhattan on the Maas"
## cluster of towers. Silhouettes are recognisable, but nothing carries a real name or logo.
## Layout (city-local, looking +Z from the quay): left = +X (west), right = -X (east).

const SHADER := preload("res://assets/shaders/skyline_tower.gdshader")
const BANK_Z := 252.0  # far bank of the river
const BRIDGE_X := -165.0
const DECK_Y := 14.0
const PYLON_Z := 75.0

var cb: RoomBuilder
var root: Node3D
var landmarks := {}
var towers: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()


static func build(builder: RoomBuilder, parent: Node3D) -> RotterdamSkyline:
	var s := RotterdamSkyline.new()
	s.cb = builder
	s._rng.seed = 1010
	s.root = Node3D.new()
	s.root.name = "Skyline"
	parent.add_child(s.root)
	s._far_bank()
	s._bridge()
	s._observation_tower()
	s._market_hall()
	s._cube_houses()
	s._east_cluster()
	s._west_centre()
	s._reflections()
	return s


# ---------- helpers ----------

func _group(n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	root.add_child(g)
	landmarks[n] = g
	return g


func facade_mat(p: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("seed", _rng.randf() * 100.0)
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


## A box tower standing on the ground (y = -1 is the far-bank street level).
func tower(parent: Node3D, pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := cb.part(parent, cb.box(size), pos + Vector3(0, size.y / 2.0, 0), m, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	towers.append(mi)
	return mi


func beam(parent: Node3D, a: Vector3, b: Vector3, thick: Vector2, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = cb.box(Vector3(thick.x, a.distance_to(b), thick.y))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = (a + b) / 2.0
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return mi


func cable(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = cb.cyl(r, a.distance_to(b))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = (a + b) / 2.0
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))


func _points(parent: Node3D, pts: Array[Vector3], radius: float, m: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cb.sphere(radius)
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


func _lit(c: Color, albedo: Color, energy: float, rough := 0.6) -> StandardMaterial3D:
	## floodlit surface: real albedo plus a little emission so it reads at night
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


# ---------- far bank ----------

func _far_bank() -> void:
	var g := _group("far_bank")
	cb.part(g, cb.box(Vector3(760, 3.0, 140)), Vector3(20, -2.5, BANK_Z + 70), cb.mat(Color("15141b"), 0.9, ""))
	cb.part(g, cb.box(Vector3(760, 2.6, 1.2)), Vector3(20, -1.7, BANK_Z), cb.mat(Color("2a2a30"), 0.8, ""))
	var lamps: Array[Vector3] = []
	for x in range(-340, 380, 11):
		lamps.append(Vector3(x, 3.6, BANK_Z + 2.5))
	_points(g, lamps, 0.45, cb.glow(Color("ffb15c"), 6.0))
	# low waterfront blocks (5–8 floors) so the towers stand in a real city, not on a plain
	var x := -330.0
	while x < 360.0:
		var w := _rng.randf_range(16, 34)
		var h := _rng.randf_range(14, 28)
		var free := absf(x - BRIDGE_X) > 22.0 and absf(x - 95.0) > 70.0 and not (x > 150.0 and x < 245.0)
		if free:
			tower(g, Vector3(x, -1, BANK_Z + 16 + _rng.randf_range(0, 10)), Vector3(w, h, 18), facade_mat({
				"facade": Color(0.09, 0.08, 0.08), "glass_frac": 0.6, "col_w": 2.6, "floor_h": 3.1, "lit_chance": 0.42, "cool_ratio": 0.15}))
		x += w + _rng.randf_range(2, 8)


# ---------- the swan bridge ----------

func _bridge() -> void:
	var g := _group("swan_bridge")
	var white := _lit(Color("dfe8ff"), Color("e4e7ee"), 0.55, 0.4)
	var concrete := cb.mat(Color("3a3a42"), 0.9, "")
	var steel := cb.mat(Color("6d7f99"), 0.5, "")
	var x0 := BRIDGE_X
	# deck: approach ramp on our side, main span over the river, then down into the far bank
	cb.part(g, cb.box(Vector3(28, 1.8, 250)), Vector3(x0, DECK_Y - 0.9, 125), cb.mat(Color("2a2b33"), 0.7, ""))
	beam(g, Vector3(x0, 1.0, -70), Vector3(x0, DECK_Y - 0.9, 0), Vector2(28, 1.8), concrete)
	beam(g, Vector3(x0, DECK_Y - 0.9, 250), Vector3(x0, 4.0, 330), Vector2(28, 1.8), concrete)
	for z in [0.0, 50.0, 140.0, 250.0]:
		cb.part(g, cb.box(Vector3(18, DECK_Y + 2, 6)), Vector3(x0, (DECK_Y - 2) / 2.0 - 1.0, z), concrete)
	# the bascule section near the far bank: pale blue steel frame
	for sx in [-15.0, 15.0]:
		beam(g, Vector3(x0 + sx, DECK_Y, 222), Vector3(x0 + sx, DECK_Y + 16, 226), Vector2(2.2, 2.2), steel)
	beam(g, Vector3(x0 - 15, DECK_Y + 16, 226), Vector3(x0 + 15, DECK_Y + 16, 226), Vector2(2.0, 2.4), steel)
	# deck edge LEDs + railing glow
	var led := cb.glow(Color("a9c8ff"), 4.0)
	for sx in [-14.2, 14.2]:
		beam(g, Vector3(x0 + sx, DECK_Y + 0.15, -40), Vector3(x0 + sx, DECK_Y + 0.15, 250), Vector2(0.25, 0.25), led)
	var deck_lamps: Array[Vector3] = []
	for z in range(0, 251, 12):
		for sx in [-12.0, 12.0]:
			deck_lamps.append(Vector3(x0 + sx, DECK_Y + 7.0, z))
	_points(g, deck_lamps, 0.4, cb.glow(Color("fff1d8"), 5.0))
	# pylon: two legs straddling the deck, a kink above it, then one neck leaning back (the "swan")
	var foot_l := Vector3(x0 - 17, -2, PYLON_Z)
	var foot_r := Vector3(x0 + 17, -2, PYLON_Z)
	var knee := Vector3(x0, 44, PYLON_Z + 7)
	var head := Vector3(x0, 136, PYLON_Z - 22)
	cb.part(g, cb.box(Vector3(44, 6, 14)), Vector3(x0, -2.0, PYLON_Z), concrete)
	beam(g, foot_l, knee, Vector2(4.2, 5.0), white)
	beam(g, foot_r, knee, Vector2(4.2, 5.0), white)
	beam(g, Vector3(x0 - 12, DECK_Y - 2, PYLON_Z - 1.5), Vector3(x0 + 12, DECK_Y - 2, PYLON_Z - 1.5), Vector2(2.5, 3.0), white)
	beam(g, knee, head, Vector2(4.6, 6.0), white)
	cb.part(g, cb.sphere(0.9), head + Vector3(0, 3.2, 0), cb.glow(Color("ff2a1a"), 10.0))
	cb.part(g, cb.sphere(0.7), knee + Vector3(0, 2.0, 0), cb.glow(Color("ff2a1a"), 8.0))
	# 32 front stays in two planes fanning out over the main span, 8 back stays to the approach
	var stay := cb.glow(Color("d6e2ff"), 1.6)
	for k in 16:
		var t := float(k) / 15.0
		var top := knee.lerp(head, 0.5 + 0.48 * t)
		var z := lerpf(98.0, 236.0, t)
		for sx in [-13.0, 13.0]:
			cable(g, top, Vector3(x0 + sx, DECK_Y + 0.4, z), 0.28, stay)
	for k in 4:
		var top := knee.lerp(head, 0.9 + 0.025 * k)
		for sx in [-13.0, 13.0]:
			cable(g, top, Vector3(x0 + sx, DECK_Y + 0.4, -14.0 + k * 3.0), 0.4, stay)
	# floodlight on the pylon
	var fl := SpotLight3D.new()
	fl.light_color = Color("cddcff")
	fl.light_energy = 14.0
	fl.spot_range = 160.0
	fl.spot_angle = 18.0
	fl.position = Vector3(x0 + 30, DECK_Y + 2, PYLON_Z - 40)
	fl.basis = Basis.looking_at((knee.lerp(head, 0.5) - fl.position).normalized(), Vector3.UP)
	g.add_child(fl)


# ---------- observation tower in the park ----------

func _observation_tower() -> void:
	var g := _group("observation_tower")
	var p := Vector3(205, -1, 365)
	var concrete := _lit(Color("ffd9a8"), Color("c9c4bb"), 0.22, 0.8)
	# park trees around the foot
	for i in 26:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(14, 60)
		cb.part(g, cb.sphere(_rng.randf_range(4, 7)), p + Vector3(cos(a) * r, 5, sin(a) * r), cb.mat(Color("0d140f"), 1.0, ""))
	cb.part(g, cb.cyl(4.6, 96, 4.2), p + Vector3(0, 48, 0), concrete)
	# crow's nest: wide disc with a glass band
	cb.part(g, cb.cyl(11.0, 7.0), p + Vector3(0, 98, 0), concrete)
	cb.part(g, cb.cyl(11.08, 2.6), p + Vector3(0, 98.4, 0), cb.glow(Color("ffd49a"), 4.0))
	cb.part(g, cb.cyl(6.0, 9.0, 5.0), p + Vector3(0, 106, 0), concrete)
	# space tower: slim mast with the panorama cabin ring
	cb.part(g, cb.cyl(1.7, 72, 1.2), p + Vector3(0, 146, 0), concrete)
	cb.part(g, cb.cyl(4.4, 3.4), p + Vector3(0, 116, 0), concrete)
	cb.part(g, cb.cyl(4.45, 1.4), p + Vector3(0, 116.2, 0), cb.glow(Color("bcd6ff"), 3.0))
	cb.part(g, cb.cyl(0.25, 8), p + Vector3(0, 186, 0), cb.mat(Color("9a9aa0"), 0.5, ""))
	var red := cb.glow(Color("ff2a1a"), 10.0)
	cb.part(g, cb.sphere(0.8), p + Vector3(0, 190.5, 0), red)
	for i in 4:
		var a := i * PI / 2.0
		cb.part(g, cb.sphere(0.6), p + Vector3(cos(a) * 11.2, 101.6, sin(a) * 11.2), red)


# ---------- market hall arch ----------

func _market_hall() -> void:
	var g := _group("market_hall")
	var p := Vector3(95, -1, 286)
	var arch := cb.cyl(30.0, 118.0)
	arch.radial_segments = 40
	var mi := cb.part(g, arch, p, facade_mat({
		"facade": Color(0.42, 0.42, 0.44), "glass_frac": 0.55, "col_w": 2.9, "floor_h": 2.9, "lit_chance": 0.5, "cool_ratio": 0.1, "mullion": 0.35}), Vector3(0, 0, 90))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	towers.append(mi)
	# the glass end walls show the giant painted ceiling inside: warm, colourful glow
	for sx in [-1.0, 1.0]:
		var cap := cb.cyl(29.4, 0.3)
		cap.radial_segments = 40
		cb.part(g, cap, p + Vector3(sx * 59.2, 0, 0), cb.glow(Color("ff9a4a"), 1.3), Vector3(0, 0, 90))
	# a pencil-shaped tower next door
	var pen := Vector3(200, -1, 288)
	var hexa := cb.cyl(8.0, 42.0)
	hexa.radial_segments = 6
	cb.part(g, hexa, pen + Vector3(0, 21, 0), facade_mat({"facade": Color(0.5, 0.48, 0.45), "lit_chance": 0.45, "cool_ratio": 0.0}))
	var cone := cb.cyl(0.4, 26.0, 0.0)
	cone.top_radius = 0.2
	cone.bottom_radius = 8.6
	cone.radial_segments = 6
	cb.part(g, cone, pen + Vector3(0, 55, 0), cb.mat(Color("2a2c33"), 0.5, ""))


# ---------- tilted cube houses ----------

func _cube_houses() -> void:
	var g := _group("cube_houses")
	var ochre := _lit(Color("ffcf6a"), Color("d9a23a"), 0.18, 0.8)
	var pillar := cb.mat(Color("6a6660"), 0.9, "")
	var tilt := Basis(Quaternion(Vector3(1, 1, 1).normalized(), Vector3.UP))
	var win := cb.glow(Color("ffd08a"), 2.0)
	for i in 9:
		var base := Vector3(160 + i * 9.6, -1, 260 + (i % 2) * 2.0)
		var hexa := cb.cyl(1.6, 9.0)
		hexa.radial_segments = 6
		cb.part(g, hexa, base + Vector3(0, 4.5, 0), pillar)
		var cube := MeshInstance3D.new()
		cube.mesh = cb.box(Vector3(7.2, 7.2, 7.2))
		cube.material_override = ochre
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(cube)
		cube.position = base + Vector3(0, 9.0 + 6.2, 0)
		cube.basis = tilt
		if i % 3 != 1:
			cb.part(g, cb.box(Vector3(1.4, 1.0, 0.1)), base + Vector3(_rng.randf_range(-1.5, 1.5), 14.5, -3.6), win)


# ---------- "Manhattan on the Maas" (east of the bridge) ----------

func _east_cluster() -> void:
	var g := _group("east_cluster")
	# the vertical city: three stacked, shifted towers
	var vert := _group("vertical_city")
	for i in 3:
		var x := -125.0 + i * 35.0
		var m := facade_mat({"facade": Color(0.05, 0.06, 0.08), "glass_frac": 0.82, "lit_chance": 0.34, "cool_ratio": 0.55})
		tower(vert, Vector3(x, -1, 292), Vector3(30, 72, 26), m)
		tower(vert, Vector3(x + [3.0, -3.0, 2.0][i], 71, 292 + [6.0, -5.0, 3.0][i]), Vector3(30, 80, 26), m)
	# tallest: slab with a stepped crown
	var tall := facade_mat({"facade": Color(0.1, 0.11, 0.13), "glass_frac": 0.7, "lit_chance": 0.28, "cool_ratio": 0.6})
	tower(g, Vector3(-250, -1, 305), Vector3(32, 150, 24), tall)
	tower(g, Vector3(-250, 149, 305), Vector3(26, 9, 19), tall)
	tower(g, Vector3(-250, 158, 305), Vector3(18, 7, 14), tall)
	cb.part(g, cb.box(Vector3(18.2, 0.4, 14.2)), Vector3(-250, 164.8, 305), cb.glow(Color("dfe8ff"), 3.0))
	# slim residential tower with a lit crown
	var slim := facade_mat({"facade": Color(0.12, 0.12, 0.12), "glass_frac": 0.6, "col_w": 1.5, "lit_chance": 0.45, "cool_ratio": 0.2})
	tower(g, Vector3(-292, -1, 335), Vector3(24, 158, 24), slim)
	cb.part(g, cb.box(Vector3(24.4, 3.0, 24.4)), Vector3(-292, 155, 335), cb.glow(Color("ffe2b0"), 1.6))
	# brown tower with a cantilevered top
	var brown := facade_mat({"facade": Color(0.22, 0.13, 0.09), "glass_frac": 0.55, "lit_chance": 0.4, "cool_ratio": 0.1})
	tower(g, Vector3(-215, -1, 345), Vector3(24, 118, 22), brown)
	tower(g, Vector3(-221, 117, 345), Vector3(30, 22, 22), brown)
	# port centre with a curved lit cap
	var port := facade_mat({"facade": Color(0.08, 0.1, 0.12), "glass_frac": 0.78, "lit_chance": 0.3, "cool_ratio": 0.5})
	tower(g, Vector3(-335, -1, 300), Vector3(34, 118, 26), port)
	var cap := cb.cyl(17.0, 26.0)
	cap.radial_segments = 24
	cb.part(g, cap, Vector3(-335, 117, 300), port, Vector3(90, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the leaning telecom building with an LED-dot facade, right next to the bridge landing
	var kpn := _group("led_tower")
	tower(kpn, Vector3(-15, -1, 276), Vector3(46, 96, 22), facade_mat({"led_grid": 1.0, "facade": Color(0.04, 0.05, 0.06)}), Vector3(-6, 0, 0))
	tower(kpn, Vector3(-15, -1, 288), Vector3(40, 88, 18), facade_mat({"facade": Color(0.18, 0.18, 0.2), "lit_chance": 0.3}))
	# filler behind
	for i in 7:
		var x := _rng.randf_range(-360, -120)
		tower(g, Vector3(x, -1, _rng.randf_range(360, 420)), Vector3(_rng.randf_range(18, 30), _rng.randf_range(45, 100), 20),
			facade_mat({"lit_chance": _rng.randf_range(0.2, 0.4), "cool_ratio": 0.4}))


# ---------- city centre side (west of the bridge) ----------

func _west_centre() -> void:
	var g := _group("west_centre")
	# red-striped tower with a cantilever on top
	var red := facade_mat({"facade": Color(0.16, 0.05, 0.04), "bands": 3.0, "band_color": Color(0.75, 0.1, 0.07), "glass_frac": 0.62, "lit_chance": 0.38, "cool_ratio": 0.1})
	tower(g, Vector3(22, -1, 302), Vector3(22, 104, 22), red)
	tower(g, Vector3(28, 103, 302), Vector3(32, 20, 22), red)
	# twin dark-glass office towers
	var dark := facade_mat({"facade": Color(0.03, 0.05, 0.06), "glass": Color(0.02, 0.05, 0.06), "glass_frac": 0.92, "mullion": 0.05, "lit_chance": 0.22, "cool_ratio": 0.8})
	tower(g, Vector3(180, -1, 340), Vector3(30, 151, 24), dark)
	tower(g, Vector3(212, -1, 345), Vector3(28, 93, 24), dark)
	cb.part(g, cb.sphere(0.7), Vector3(180, 151.5, 340), cb.glow(Color("ff2a1a"), 8.0))
	# a few more office and apartment towers
	for spec in [[-40.0, 335.0, 62.0], [-20.0, 365.0, 88.0], [70.0, 350.0, 74.0], [130.0, 380.0, 96.0], [300.0, 330.0, 55.0], [10.0, 400.0, 110.0]]:
		tower(g, Vector3(spec[0], -1, spec[1]), Vector3(_rng.randf_range(20, 30), spec[2], _rng.randf_range(18, 26)),
			facade_mat({"lit_chance": _rng.randf_range(0.25, 0.45), "cool_ratio": _rng.randf_range(0.1, 0.5)}))


# ---------- light on the water ----------

func _reflections() -> void:
	var g := _group("reflections")
	var warm: Array[Transform3D] = []
	var cool: Array[Transform3D] = []
	for i in 60:
		var x := _rng.randf_range(-340, 360)
		var t := Transform3D(Basis().scaled(Vector3(_rng.randf_range(0.6, 2.0), 1, _rng.randf_range(18, 50))), Vector3(x, -1.09, BANK_Z - _rng.randf_range(12, 40)))
		(cool if _rng.randf() < 0.35 else warm).append(t)
	# the bridge's deck lamps and the pylon floodlight streak across the river
	for z in range(20, 240, 16):
		for sx in [-12.0, 12.0]:
			cool.append(Transform3D(Basis().scaled(Vector3(0.8, 1, 9)), Vector3(BRIDGE_X + sx, -1.09, z)))
	for pair in [[warm, Color("ffb46a")], [cool, Color("bcd2ff")]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = cb.box(Vector3(1, 0.02, 1))
		var arr: Array = pair[0]
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = cb.glow(pair[1], 1.4)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mmi)
