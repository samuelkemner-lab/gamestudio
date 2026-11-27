class_name RoomBuilder
extends Node3D
## Builds the bedroom studio following docs/ART_DIRECTION.md.
## Everything is procedural (no external assets yet): layered props,
## noise-textured materials, warm key / cool fill / neon accent lighting.

const PAL := {
	"wall": Color("221f2e"),
	"wall_trim": Color("2e2a3d"),
	"ceiling": Color("15131d"),
	"floor_wood": Color("4a3428"),
	"wood_dark": Color("3d2a20"),
	"metal": Color("1a1a20"),
	"plastic_black": Color("121117"),
	"fabric_purple": Color("2e2142"),
	"fabric_blue": Color("2d3a5c"),
	"fabric_grey": Color("4a4560"),
	"rug": Color("3a2f55"),
	"warm": Color("ffb070"),
	"cool": Color("6f8cff"),
	"neon_purple": Color("b05cff"),
	"neon_cyan": Color("25d9f5"),
	"pop": Color("ff3d7f"),
	"cardboard": Color("a07850"),
	"plant": Color("2f6b4a"),
	"foam": Color("26222f"),
}

var screen_material: StandardMaterial3D
var _noise_cache := {}


func build() -> void:
	_environment()
	_shell()
	_window_and_city()
	_desk_setup()
	_chair()
	_booth_corner()
	_bed_area()
	_left_wall()
	_floor_clutter()
	_lighting()


# ================= Materials =================

func _noise(kind: String) -> NoiseTexture2D:
	if _noise_cache.has(kind):
		return _noise_cache[kind]
	var n := FastNoiseLite.new()
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var ramp := Gradient.new()
	match kind:
		"fabric":
			n.frequency = 0.12
			ramp.set_color(0, Color(0.78, 0.78, 0.8))
		"wood":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.02
			ramp.set_color(0, Color(0.7, 0.68, 0.66))
		_:
			n.frequency = 0.05
			ramp.set_color(0, Color(0.86, 0.86, 0.88))
	ramp.set_color(1, Color(1, 1, 1))
	tex.noise = n
	tex.color_ramp = ramp
	_noise_cache[kind] = tex
	return tex


func mat(color: Color, rough := 0.85, texture := "plaster", scale := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if texture != "":
		m.albedo_texture = _noise(texture)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
	return m


func glow(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


# ================= Mesh helpers =================

func part(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func cyl(radius: float, height: float, top := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = radius
	c.top_radius = radius if top < 0.0 else top
	c.height = height
	c.radial_segments = 20
	return c


func sphere(radius: float, height := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0 if height < 0.0 else height
	s.radial_segments = 20
	s.rings = 10
	return s


func capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	return c


func text3d(parent: Node3D, text: String, pos: Vector3, color: Color, px := 0.0016, rot := Vector3.ZERO, energy := 1.5) -> MeshInstance3D:
	var t := TextMesh.new()
	t.text = text
	t.font_size = 64
	t.pixel_size = px
	t.depth = 0.004
	return part(parent, t, pos, glow(color, energy), rot)


func group(name: String, pos := Vector3.ZERO, rot_y := 0.0) -> Node3D:
	var g := Node3D.new()
	g.name = name
	g.position = pos
	g.rotation_degrees.y = rot_y
	add_child(g)
	return g


func solid(size: Vector3, pos: Vector3, meta := "", label := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	if meta != "":
		body.set_meta("interact", meta)
		body.set_meta("label", label)
	add_child(body)
	return body


# ================= Environment =================

func _environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("070818")
	sky_mat.sky_horizon_color = Color("3a2350")
	sky_mat.ground_horizon_color = Color("5a3040")
	sky_mat.ground_bottom_color = Color("0a0810")
	sky_mat.sky_curve = 0.12
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("454a63")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.45
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 2.2
	env.ssil_enabled = true
	env.ssil_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.75, 0.7, 0.95)
	env.volumetric_fog_length = 14.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ================= Room shell =================

func _shell() -> void:
	var shell := group("Shell")
	var wall_m := mat(PAL.wall, 0.95, "plaster", 1.5)
	var floor_m := mat(PAL.floor_wood, 0.6, "wood", 0.6)

	part(shell, box(Vector3(4.4, 0.1, 5.4)), Vector3(0, -0.05, 0), floor_m)
	part(shell, box(Vector3(4.4, 0.1, 5.4)), Vector3(0, 2.65, 0), mat(PAL.ceiling, 0.95))
	part(shell, box(Vector3(4.4, 2.6, 0.1)), Vector3(0, 1.3, -2.65), wall_m)
	part(shell, box(Vector3(4.4, 2.6, 0.1)), Vector3(0, 1.3, 2.65), wall_m)
	part(shell, box(Vector3(0.1, 2.6, 5.4)), Vector3(-2.15, 1.3, 0), wall_m)
	# Right wall with a window opening (z -1.3..0.1, y 0.95..2.05)
	part(shell, box(Vector3(0.1, 0.95, 5.4)), Vector3(2.15, 0.475, 0), wall_m)
	part(shell, box(Vector3(0.1, 0.55, 5.4)), Vector3(2.15, 2.325, 0), wall_m)
	part(shell, box(Vector3(0.1, 1.1, 1.4)), Vector3(2.15, 1.5, -2.0), wall_m)
	part(shell, box(Vector3(0.1, 1.1, 2.6)), Vector3(2.15, 1.5, 1.4), wall_m)

	# Colliders
	solid(Vector3(4.4, 0.1, 5.4), Vector3(0, -0.05, 0))
	solid(Vector3(4.4, 2.6, 0.1), Vector3(0, 1.3, -2.65))
	solid(Vector3(4.4, 2.6, 0.1), Vector3(0, 1.3, 2.65))
	solid(Vector3(0.1, 2.6, 5.4), Vector3(-2.15, 1.3, 0))
	solid(Vector3(0.1, 2.6, 5.4), Vector3(2.15, 1.3, 0))

	# Baseboards
	var trim := mat(PAL.wall_trim, 0.7, "")
	part(shell, box(Vector3(4.3, 0.08, 0.02)), Vector3(0, 0.04, -2.59), trim)
	part(shell, box(Vector3(4.3, 0.08, 0.02)), Vector3(0, 0.04, 2.59), trim)
	part(shell, box(Vector3(0.02, 0.08, 5.2)), Vector3(-2.09, 0.04, 0), trim)
	part(shell, box(Vector3(0.02, 0.08, 5.2)), Vector3(2.09, 0.04, 0), trim)

	# Door
	part(shell, box(Vector3(0.9, 2.05, 0.04)), Vector3(-1.2, 1.025, 2.58), mat(Color("2c2838"), 0.6, "wood", 1.0))
	part(shell, cyl(0.02, 0.12), Vector3(-0.85, 1.0, 2.54), mat(Color("8a8a95"), 0.3, ""), Vector3(90, 0, 0))
	text3d(shell, "DO NOT\nDISTURB\n(recording)", Vector3(-1.2, 1.55, 2.555), PAL.pop, 0.0011, Vector3(0, 180, 0), 1.2)

	# Rug
	part(shell, cyl(1.1, 0.012), Vector3(0.1, 0.006, 0.3), mat(PAL.rug, 1.0, "fabric", 6.0))
	part(shell, cyl(0.75, 0.014), Vector3(0.1, 0.007, 0.3), mat(Color("4a3a6e"), 1.0, "fabric", 6.0))

	# Neon LED strips (light comes from _lighting)
	part(shell, box(Vector3(4.2, 0.025, 0.03)), Vector3(0, 2.57, -2.58), glow(PAL.neon_purple, 5.0))
	part(shell, box(Vector3(0.03, 0.025, 5.2)), Vector3(-2.08, 2.57, 0), glow(PAL.neon_cyan, 4.0))
	part(shell, box(Vector3(0.03, 0.025, 2.4)), Vector3(2.08, 2.57, 1.4), glow(PAL.neon_purple, 5.0))


# ================= Window + skyline =================

func _window_and_city() -> void:
	var win := group("Window")
	var frame := mat(Color("d8d4e0"), 0.5, "")
	part(win, box(Vector3(0.12, 0.05, 1.5)), Vector3(2.1, 2.05, -0.6), frame)
	part(win, box(Vector3(0.18, 0.05, 1.55)), Vector3(2.06, 0.95, -0.6), frame)  # sill
	part(win, box(Vector3(0.12, 1.1, 0.05)), Vector3(2.1, 1.5, -1.32), frame)
	part(win, box(Vector3(0.12, 1.1, 0.05)), Vector3(2.1, 1.5, 0.12), frame)
	part(win, box(Vector3(0.06, 1.1, 0.04)), Vector3(2.12, 1.5, -0.6), frame)

	# Curtains (folds = several cylinders) + rod
	var curtain := mat(Color("1f2a48"), 1.0, "fabric", 4.0)
	for side in [-1.55, 0.32]:
		for i in 4:
			part(win, cyl(0.045, 2.15), Vector3(2.03 - (i % 2) * 0.03, 1.38, side + i * 0.065), curtain)
	part(win, cyl(0.012, 2.3), Vector3(2.04, 2.47, -0.6), mat(PAL.metal, 0.3, ""), Vector3(90, 0, 0))

	# Plant on the sill
	part(win, cyl(0.07, 0.12, 0.08), Vector3(2.02, 1.03, -0.15), mat(Color("c26a4a"), 0.8, ""))
	for i in 5:
		var a := i * 72.0
		part(win, sphere(0.05, 0.16), Vector3(2.02 + cos(deg_to_rad(a)) * 0.04, 1.15, -0.15 + sin(deg_to_rad(a)) * 0.04),
			mat(PAL.plant, 0.8, ""), Vector3(25 * cos(deg_to_rad(a)), a, 25 * sin(deg_to_rad(a))))

	# Skyline outside (fictional harbour city at night)
	var city := group("City")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bmat := mat(Color("0f0e1a"), 0.9, "")
	var warm_lights: Array[Transform3D] = []
	var cool_lights: Array[Transform3D] = []
	for i in 90:
		var w := rng.randf_range(3.0, 7.0)
		var d := rng.randf_range(3.0, 7.0)
		var h := rng.randf_range(8.0, 40.0)
		var x := rng.randf_range(22.0, 70.0)
		var z := rng.randf_range(-45.0, 40.0)
		var bld := part(city, box(Vector3(d, h, w)), Vector3(x, h / 2.0 - 14.0, z), bmat)
		bld.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var face_x := x - d / 2.0 - 0.02
		for row in range(1, int(h / 1.2)):
			for col in range(int(w / 0.9)):
				if rng.randf() < 0.42:
					var t := Transform3D(Basis(), Vector3(face_x, row * 1.2 - 14.0, z - w / 2.0 + 0.45 + col * 0.9))
					if rng.randf() < 0.7:
						warm_lights.append(t)
					else:
						cool_lights.append(t)
	_multimesh(city, warm_lights, glow(Color("ffc27a"), 2.5))
	_multimesh(city, cool_lights, glow(Color("8fb0ff"), 2.0))
	# Harbour crane silhouette + red aircraft lights
	var crane := mat(Color("141320"), 0.9, "")
	part(city, box(Vector3(0.8, 30.0, 0.8)), Vector3(30.0, 1.0, 4.0), crane)
	part(city, box(Vector3(0.7, 0.7, 20.0)), Vector3(30.0, 16.0, -1.0), crane)
	part(city, sphere(0.35), Vector3(30.0, 16.6, 8.5), glow(Color("ff3030"), 8.0))
	part(city, sphere(0.35), Vector3(40.0, 26.5, -12.0), glow(Color("ff3030"), 8.0))
	# Moon
	part(city, sphere(2.5), Vector3(80.0, 30.0, -8.0), glow(Color("dfe6ff"), 3.0))


func _multimesh(parent: Node3D, transforms: Array[Transform3D], material: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box(Vector3(0.05, 0.5, 0.4))
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


# ================= Desk setup =================

func _desk_setup() -> void:
	var d := group("Desk", Vector3(-0.7, 0, -2.25))
	var wood := mat(PAL.wood_dark, 0.55, "wood", 1.0)
	var metal := mat(PAL.metal, 0.35, "")
	var black := mat(PAL.plastic_black, 0.4, "")

	part(d, box(Vector3(1.6, 0.045, 0.7)), Vector3(0, 0.73, 0), wood)
	for x in [-0.76, 0.76]:
		for z in [-0.3, 0.3]:
			part(d, cyl(0.022, 0.71), Vector3(x, 0.355, z), metal)
	# Drawer unit
	part(d, box(Vector3(0.42, 0.55, 0.6)), Vector3(0.52, 0.3, 0), wood)
	for y in [0.42, 0.2]:
		part(d, box(Vector3(0.38, 0.18, 0.01)), Vector3(0.52, y, 0.305), mat(Color("4a3428"), 0.6, "wood"))
		part(d, box(Vector3(0.12, 0.015, 0.02)), Vector3(0.52, y + 0.05, 0.315), metal)
	solid(Vector3(1.6, 0.75, 0.7), Vector3(-0.7, 0.375, -2.25))

	# Monitor (LOOPR runs on it via SubViewport)
	part(d, box(Vector3(0.26, 0.012, 0.18)), Vector3(0, 0.758, -0.17), black)
	part(d, box(Vector3(0.04, 0.26, 0.03)), Vector3(0, 0.88, -0.2), black)
	part(d, box(Vector3(0.84, 0.5, 0.035)), Vector3(0, 1.13, -0.18), black)
	screen_material = StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_color = Color(1.15, 1.15, 1.2)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.45)
	part(d, quad, Vector3(0, 1.13, -0.161), screen_material)
	solid(Vector3(0.84, 0.5, 0.06), Vector3(-0.7, 1.13, -2.43), "pc", "Open LOOPR")

	# Speakers on foam pads
	for x in [-0.64, 0.64]:
		part(d, box(Vector3(0.18, 0.03, 0.2)), Vector3(x, 0.767, -0.1), mat(PAL.foam, 1.0, "fabric"))
		part(d, box(Vector3(0.17, 0.27, 0.2)), Vector3(x, 0.92, -0.1), black, Vector3(0, -x * 12.0, 0))
		part(d, cyl(0.06, 0.012), Vector3(x, 0.88, 0.0), mat(Color("2a2a33"), 0.5, ""), Vector3(90, -x * 12.0, 0))
		part(d, cyl(0.022, 0.012), Vector3(x, 0.99, 0.0), mat(Color("3a3a44"), 0.3, ""), Vector3(90, -x * 12.0, 0))
		part(d, box(Vector3(0.12, 0.006, 0.006)), Vector3(x, 0.8, 0.002), glow(PAL.neon_cyan, 2.0))

	# Keyboard
	part(d, box(Vector3(0.46, 0.022, 0.16)), Vector3(0, 0.764, 0.2), black)
	part(d, box(Vector3(0.43, 0.008, 0.13)), Vector3(0, 0.778, 0.2), mat(Color("2c2a36"), 0.5, ""))
	# MIDI pad with 4x4 glowing pads
	part(d, box(Vector3(0.26, 0.03, 0.22)), Vector3(0.48, 0.767, 0.16), black, Vector3(0, -10, 0))
	var pad_cols := [PAL.neon_purple, PAL.neon_cyan, PAL.pop, PAL.warm]
	for r in 4:
		for c in 4:
			var p := Vector3(0.48 - 0.075 + c * 0.05, 0.785, 0.16 - 0.075 + r * 0.05)
			part(d, box(Vector3(0.04, 0.008, 0.04)), p, glow(pad_cols[(r + c) % 4], 0.8), Vector3(0, -10, 0))
	# Mouse + pad
	part(d, box(Vector3(0.26, 0.004, 0.22)), Vector3(-0.4, 0.755, 0.18), mat(Color("1b1726"), 1.0, "fabric"))
	part(d, capsule(0.03, 0.1), Vector3(-0.4, 0.772, 0.18), black, Vector3(90, 0, 0), Vector3(1, 1, 0.5))

	# Headphones resting on desk
	var hp := Node3D.new()
	hp.position = Vector3(-0.62, 0.79, 0.15)
	hp.rotation_degrees = Vector3(0, 25, 0)
	d.add_child(hp)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.075
	torus.outer_radius = 0.09
	part(hp, torus, Vector3(0, 0.02, 0), black, Vector3(90, 0, 0), Vector3(1, 1, 0.6))
	for x in [-0.085, 0.085]:
		part(hp, cyl(0.045, 0.035), Vector3(x, -0.01, 0), mat(Color("1e1c26"), 0.6, ""), Vector3(0, 0, 90))

	# Desk lamp (warm key light)
	var lamp := Node3D.new()
	lamp.position = Vector3(-0.68, 0.752, -0.22)
	d.add_child(lamp)
	var lamp_m := mat(Color("2a2633"), 0.4, "")
	part(lamp, cyl(0.07, 0.02), Vector3.ZERO, lamp_m)
	part(lamp, cyl(0.011, 0.42), Vector3(0.03, 0.2, 0.04), lamp_m, Vector3(10, 0, -10))
	part(lamp, cyl(0.011, 0.3), Vector3(0.12, 0.43, 0.14), lamp_m, Vector3(60, 0, -35))
	part(lamp, cyl(0.025, 0.11, 0.075), Vector3(0.22, 0.47, 0.25), lamp_m, Vector3(150, 0, -30))
	part(lamp, sphere(0.03), Vector3(0.235, 0.44, 0.275), glow(PAL.warm, 6.0))
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.24, 0.43, 0.28)
	spot.light_color = PAL.warm
	spot.light_energy = 5.0
	spot.spot_range = 2.2
	spot.spot_angle = 55.0
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 1.5
	lamp.add_child(spot)
	spot.basis = Basis.looking_at(Vector3(0.15, -1.0, 0.35).normalized())

	# Energy drinks + mug + notebook with lyrics
	part(d, cyl(0.033, 0.12), Vector3(-0.45, 0.81, -0.05), mat(PAL.pop, 0.3, ""))
	part(d, cyl(0.033, 0.12), Vector3(-0.37, 0.81, -0.12), mat(PAL.neon_cyan, 0.3, ""))
	part(d, cyl(0.033, 0.12), Vector3(0.3, 0.81, -0.25), mat(Color("c8ff3d"), 0.3, ""))
	part(d, box(Vector3(0.2, 0.012, 0.27)), Vector3(0.28, 0.758, 0.12), mat(Color("e8e2d0"), 0.9, "fabric"), Vector3(0, 18, 0))
	text3d(d, "bars v3\n- no sleep\n- 808 heart", Vector3(0.28, 0.766, 0.12), Color("2a2340"), 0.0006, Vector3(-90, 18, 0), 0.0)


# ================= Chair =================

func _chair() -> void:
	var c := group("Chair", Vector3(-0.72, 0, -1.5), 12.0)
	var black := mat(PAL.plastic_black, 0.4, "")
	var seat := mat(PAL.fabric_purple, 0.95, "fabric", 5.0)
	for i in 5:
		var a := i * 72.0
		part(c, box(Vector3(0.3, 0.03, 0.045)), Vector3(cos(deg_to_rad(a)) * 0.15, 0.07, sin(deg_to_rad(a)) * 0.15), black, Vector3(0, -a, 0))
		part(c, sphere(0.028), Vector3(cos(deg_to_rad(a)) * 0.29, 0.028, sin(deg_to_rad(a)) * 0.29), black)
	part(c, cyl(0.025, 0.32), Vector3(0, 0.25, 0), mat(Color("5a5a66"), 0.25, ""))
	part(c, box(Vector3(0.52, 0.09, 0.5)), Vector3(0, 0.45, 0), seat)
	part(c, box(Vector3(0.5, 0.68, 0.09)), Vector3(0, 0.86, 0.24), seat, Vector3(-8, 0, 0))
	part(c, box(Vector3(0.07, 0.6, 0.095)), Vector3(0, 0.86, 0.239), mat(PAL.pop, 0.7, "fabric"), Vector3(-8, 0, 0))
	part(c, capsule(0.07, 0.42), Vector3(0, 1.17, 0.27), seat, Vector3(0, 0, 90))
	for x in [-0.28, 0.28]:
		part(c, box(Vector3(0.05, 0.03, 0.3)), Vector3(x, 0.66, 0.02), black)
		part(c, box(Vector3(0.03, 0.18, 0.03)), Vector3(x, 0.56, 0.1), black)
	# Hoodie thrown over the backrest
	part(c, box(Vector3(0.54, 0.3, 0.06)), Vector3(0, 1.08, 0.33), mat(Color("55526a"), 1.0, "fabric", 6.0), Vector3(-15, 0, 4))
	part(c, capsule(0.05, 0.4), Vector3(0.22, 0.85, 0.36), mat(Color("55526a"), 1.0, "fabric", 6.0), Vector3(0, 0, 8))


# ================= Booth corner =================

func _booth_corner() -> void:
	var b := group("Booth", Vector3(1.45, 0, -2.2))
	# Mattress against the wall = "vocal booth", with tufting
	part(b, box(Vector3(1.0, 1.75, 0.16)), Vector3(0, 0.9, -0.35), mat(PAL.fabric_grey, 1.0, "fabric", 5.0))
	for r in 4:
		for col in 3:
			part(b, sphere(0.018), Vector3(-0.3 + col * 0.3, 0.35 + r * 0.38, -0.27), mat(Color("35314a"), 1.0, ""))
	text3d(b, "BOOTH", Vector3(0, 1.62, -0.265), PAL.neon_cyan, 0.0014, Vector3.ZERO, 2.0)
	# Red "on air" light above the booth
	part(b, box(Vector3(0.3, 0.1, 0.04)), Vector3(0, 1.95, -0.4), mat(PAL.plastic_black, 0.4, ""))
	text3d(b, "ON AIR", Vector3(0, 1.95, -0.375), Color("ff3030"), 0.0009, Vector3.ZERO, 3.0)
	# Cyan LED strip behind the mattress (backlight)
	part(b, box(Vector3(1.0, 0.02, 0.02)), Vector3(0, 0.05, -0.27), glow(PAL.neon_cyan, 4.0))
	# Foam panels
	for z in [0.3, 0.85]:
		_foam_panel(b, Vector3(0.6, 1.5, z))

	# Mic stand + mic + pop filter
	var mic := Node3D.new()
	mic.position = Vector3(0, 0, 0.35)
	b.add_child(mic)
	var chrome := mat(Color("9aa0ad"), 0.2, "")
	part(mic, cyl(0.15, 0.025), Vector3(0, 0.012, 0), mat(PAL.plastic_black, 0.4, ""))
	part(mic, cyl(0.012, 1.45), Vector3(0, 0.74, 0), chrome)
	part(mic, cyl(0.009, 0.4), Vector3(0, 1.47, 0.12), chrome, Vector3(70, 0, 0))
	var shock := TorusMesh.new()
	shock.inner_radius = 0.042
	shock.outer_radius = 0.05
	part(mic, shock, Vector3(0, 1.52, 0.26), mat(PAL.plastic_black, 0.4, ""))
	part(mic, capsule(0.03, 0.16), Vector3(0, 1.52, 0.26), mat(Color("cfd3dc"), 0.25, ""))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.075
	ring.outer_radius = 0.085
	part(mic, ring, Vector3(0, 1.52, 0.42), mat(PAL.plastic_black, 0.4, ""), Vector3(90, 0, 0))
	var mesh_m := StandardMaterial3D.new()
	mesh_m.albedo_color = Color(0.05, 0.05, 0.08, 0.55)
	mesh_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	part(mic, cyl(0.076, 0.003), Vector3(0, 1.52, 0.42), mesh_m, Vector3(90, 0, 0))
	solid(Vector3(0.35, 1.6, 0.35), Vector3(1.45, 0.8, -1.85), "mic", "Recording booth (coming soon)")


func _foam_panel(parent: Node3D, pos: Vector3) -> void:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	var dark := mat(PAL.foam, 1.0, "fabric", 8.0)
	var light := mat(Color("332d40"), 1.0, "fabric", 8.0)
	for r in 4:
		for c in 4:
			var deep := (r + c) % 2 == 0
			part(p, box(Vector3(0.12 if deep else 0.07, 0.12, 0.12)), Vector3(-0.0 if deep else 0.025, -0.18 + r * 0.12, -0.18 + c * 0.12), dark if deep else light)


# ================= Bed area =================

func _bed_area() -> void:
	var b := group("Bed", Vector3(1.55, 0, 1.55))
	part(b, box(Vector3(1.04, 0.26, 2.04)), Vector3(0, 0.13, 0), mat(PAL.wood_dark, 0.6, "wood", 1.0))
	part(b, box(Vector3(0.98, 0.18, 1.96)), Vector3(0, 0.35, 0), mat(Color("cfcbe0"), 1.0, "fabric", 4.0))
	part(b, box(Vector3(1.02, 0.08, 1.25)), Vector3(-0.01, 0.47, 0.35), mat(PAL.fabric_blue, 1.0, "fabric", 5.0), Vector3(0, 3, 1.5))
	part(b, box(Vector3(1.0, 0.1, 0.3)), Vector3(0.0, 0.5, -0.22), mat(PAL.fabric_blue, 1.0, "fabric", 5.0), Vector3(-12, -4, 0))
	part(b, capsule(0.12, 0.62), Vector3(0, 0.5, -0.78), mat(Color("e6e2f2"), 1.0, "fabric", 5.0), Vector3(0, 0, 90), Vector3(1, 0.65, 1))
	part(b, box(Vector3(0.08, 0.6, 1.04)), Vector3(0.0, 0.3, -1.0), mat(PAL.wood_dark, 0.6, "wood"), Vector3(0, 90, 0))
	# Phone on the bed, screen on
	part(b, box(Vector3(0.075, 0.01, 0.15)), Vector3(-0.2, 0.52, 0.1), mat(PAL.plastic_black, 0.3, ""), Vector3(0, 25, 0))
	part(b, box(Vector3(0.068, 0.002, 0.14)), Vector3(-0.2, 0.526, 0.1), glow(Color("9b8cff"), 1.5), Vector3(0, 25, 0))
	solid(Vector3(1.04, 0.5, 2.04), Vector3(1.55, 0.25, 1.55))


# ================= Left wall =================

func _left_wall() -> void:
	var w := group("LeftWall")
	# Poster above desk
	var poster := Node3D.new()
	poster.position = Vector3(-0.7, 1.88, -2.585)
	w.add_child(poster)
	part(poster, box(Vector3(0.64, 0.82, 0.015)), Vector3.ZERO, mat(Color("0c0a12"), 0.5, ""))
	part(poster, box(Vector3(0.58, 0.76, 0.01)), Vector3(0, 0, 0.006), mat(Color("2a1033"), 0.9, "fabric", 3.0))
	part(poster, sphere(0.16), Vector3(0, 0.1, 0.012), glow(PAL.pop, 1.2), Vector3.ZERO, Vector3(1, 1, 0.05))
	text3d(poster, "LIL GRIND", Vector3(0, -0.18, 0.013), Color("ffd0e0"), 0.0016, Vector3.ZERO, 1.5)
	text3d(poster, "BEDROOM TAPE VOL.1", Vector3(0, -0.27, 0.013), PAL.neon_cyan, 0.0007, Vector3.ZERO, 1.5)

	# Second poster on the left wall
	var p2 := Node3D.new()
	p2.position = Vector3(-2.09, 1.65, 0.0)
	p2.rotation_degrees.y = 90
	w.add_child(p2)
	part(p2, box(Vector3(0.5, 0.7, 0.012)), Vector3.ZERO, mat(Color("102a33"), 0.9, "fabric", 3.0))
	text3d(p2, "NO\nSLEEP\nALL\nBEATS", Vector3(0, 0.02, 0.01), PAL.neon_cyan, 0.0018, Vector3.ZERO, 1.2)

	# Shelf with vinyl + books
	var shelf := Node3D.new()
	shelf.position = Vector3(-2.0, 1.25, 1.2)
	w.add_child(shelf)
	part(shelf, box(Vector3(0.22, 0.03, 1.0)), Vector3.ZERO, mat(PAL.wood_dark, 0.6, "wood"))
	var rec_cols := [Color("1a1a22"), PAL.pop, Color("2a2a3a"), PAL.warm, Color("1a1a22"), PAL.neon_purple]
	for i in 6:
		part(shelf, cyl(0.15, 0.012), Vector3(0, 0.165, -0.42 + i * 0.03), mat(rec_cols[i], 0.5, ""), Vector3(90, 0, 0))
	for i in 5:
		var h := 0.18 + (i % 3) * 0.03
		part(shelf, box(Vector3(0.16, h, 0.035)), Vector3(0, 0.015 + h / 2.0, 0.1 + i * 0.04),
			mat([Color("3b4a6b"), Color("6b3b4a"), Color("4a6b3b"), Color("2e2a3d"), Color("6b5a3b")][i], 0.8, ""))
	part(shelf, box(Vector3(0.16, 0.04, 0.2)), Vector3(0, 0.035, 0.38), mat(Color("3b4a6b"), 0.8, ""), Vector3(0, 0, 0))

	# Warm string lights on the left wall
	var pts := 16
	for i in pts:
		var t := float(i) / (pts - 1)
		var z := lerpf(-1.0, 2.4, t)
		var y := 2.28 - sin(t * PI * 3.0) * 0.08 - sin(t * PI) * 0.05
		part(w, sphere(0.018), Vector3(-2.07, y, z), glow(PAL.warm, 5.0))

	# Plant in the back-left corner
	var plant := Node3D.new()
	plant.position = Vector3(-1.85, 0, -2.3)
	w.add_child(plant)
	part(plant, cyl(0.15, 0.32, 0.17), Vector3(0, 0.16, 0), mat(Color("d6d0c4"), 0.7, ""))
	for i in 9:
		var a := i * 40.0
		var tilt := 20.0 + (i % 3) * 15.0
		part(plant, sphere(0.07, 0.42), Vector3(cos(deg_to_rad(a)) * 0.08, 0.55 + (i % 3) * 0.08, sin(deg_to_rad(a)) * 0.08),
			mat(PAL.plant.lightened((i % 3) * 0.08), 0.8, ""), Vector3(tilt * sin(deg_to_rad(a)), 0, -tilt * cos(deg_to_rad(a))))
	solid(Vector3(0.35, 0.8, 0.35), Vector3(-1.85, 0.4, -2.3))


# ================= Floor clutter =================

func _floor_clutter() -> void:
	var f := group("Clutter")
	# Beanbag
	part(f, sphere(0.45, 0.55), Vector3(-1.55, 0.27, 1.85), mat(Color("7a2a55"), 1.0, "fabric", 4.0))
	part(f, sphere(0.36, 0.3), Vector3(-1.55, 0.5, 1.9), mat(Color("8a3062"), 1.0, "fabric", 4.0))
	solid(Vector3(0.8, 0.5, 0.8), Vector3(-1.55, 0.25, 1.85))
	# Pizza box (half open)
	var pz := Node3D.new()
	pz.position = Vector3(0.6, 0, 2.05)
	pz.rotation_degrees.y = 25
	f.add_child(pz)
	part(pz, box(Vector3(0.36, 0.04, 0.36)), Vector3(0, 0.02, 0), mat(PAL.cardboard, 0.9, "fabric", 3.0))
	part(pz, box(Vector3(0.36, 0.01, 0.36)), Vector3(0, 0.13, -0.24), mat(PAL.cardboard, 0.9, "fabric", 3.0), Vector3(-55, 0, 0))
	part(pz, cyl(0.15, 0.012), Vector3(0, 0.045, 0), mat(Color("d98c3a"), 0.8, "fabric", 6.0))
	# Sneakers (fictional brand)
	for i in 2:
		var s := Node3D.new()
		s.position = Vector3(0.7 + i * 0.16, 0, 0.75 + i * 0.05)
		s.rotation_degrees.y = -20 + i * 30
		f.add_child(s)
		part(s, box(Vector3(0.11, 0.035, 0.29)), Vector3(0, 0.018, 0), mat(Color("f2f0ff"), 0.6, ""))
		part(s, capsule(0.055, 0.24), Vector3(0, 0.075, -0.01), mat(Color("e4e2ee"), 0.7, "fabric"), Vector3(90, 0, 0), Vector3(1, 1, 0.65))
		part(s, box(Vector3(0.112, 0.02, 0.12)), Vector3(0, 0.06, 0.03), mat(PAL.neon_cyan, 0.5, ""))
	# Fallen can + clothes pile + cable
	part(f, cyl(0.033, 0.12), Vector3(0.15, 0.033, -1.25), mat(PAL.pop, 0.3, ""), Vector3(0, 30, 90))
	part(f, sphere(0.25, 0.14), Vector3(1.0, 0.06, 2.35), mat(Color("3a4a3a"), 1.0, "fabric", 6.0), Vector3.ZERO, Vector3(1.3, 1, 1))
	part(f, sphere(0.18, 0.1), Vector3(0.85, 0.12, 2.3), mat(Color("5a3040"), 1.0, "fabric", 6.0))
	var cable := mat(Color("0a0a0e"), 0.5, "")
	for seg in [[Vector3(-0.3, 0.008, -2.4), 70.0, 0.8], [Vector3(0.15, 0.008, -2.1), 20.0, 0.6], [Vector3(0.45, 0.008, -1.9), 80.0, 0.5]]:
		part(f, cyl(0.008, seg[2]), seg[0], cable, Vector3(90, seg[1], 0))


# ================= Lighting =================

func _lighting() -> void:
	# Cool moonlight, only enters through the window (walls cast shadows)
	var moon := DirectionalLight3D.new()
	moon.light_color = PAL.cool
	moon.light_energy = 2.6
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 25.0
	moon.light_volumetric_fog_energy = 1.2
	add_child(moon)
	moon.basis = Basis.looking_at(Vector3(-1.0, -0.45, 0.2).normalized())

	# Neon accent lights along the LED strips
	for spec in [
		[Vector3(-0.7, 2.4, -2.35), PAL.neon_purple, 1.2, 3.2, true],
		[Vector3(-1.9, 2.4, 0.4), PAL.neon_cyan, 0.7, 3.0, false],
		[Vector3(1.9, 2.4, 1.5), PAL.neon_purple, 0.6, 2.8, false],
		[Vector3(1.45, 0.4, -1.6), PAL.neon_cyan, 0.8, 2.0, false],
	]:
		var l := OmniLight3D.new()
		l.position = spec[0]
		l.light_color = spec[1]
		l.light_energy = spec[2]
		l.omni_range = spec[3]
		l.shadow_enabled = spec[4]
		add_child(l)

	# Screen spill on the desk and the player
	var screen := OmniLight3D.new()
	screen.position = Vector3(-0.7, 1.1, -2.1)
	screen.light_color = Color("a78bfa")
	screen.light_energy = 0.9
	screen.omni_range = 1.8
	add_child(screen)

	# Warm string lights glow
	var warm := OmniLight3D.new()
	warm.position = Vector3(-1.85, 2.1, 0.7)
	warm.light_color = PAL.warm
	warm.light_energy = 0.7
	warm.omni_range = 2.8
	add_child(warm)
