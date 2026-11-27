class_name RoomBuilder
extends Node3D
## Builds the bedroom studio following docs/ART_DIRECTION.md.
## Furniture: Kenney Furniture Kit (CC0), recoloured to the night palette.
## City: Kenney City Kit Commercial (CC0) + procedural far skyline.
## Custom procedural props where no kit model exists (booth, mic, MIDI pad, posters...).

const KIT := "res://assets/models/kenney_furniture/%s.glb"
const CITY := "res://assets/models/kenney_city/%s.glb"
const S := 2.0  # Kenney furniture kit -> metres
const DESK_TOP := 0.77

const PAL := {
	"wall": Color("221f2e"),
	"wall_trim": Color("2e2a3d"),
	"ceiling": Color("15131d"),
	"floor_wood": Color("4a3428"),
	"wood": Color("5e4232"),
	"wood_dark": Color("3d2a20"),
	"metal": Color("2a2a33"),
	"metal_mid": Color("444452"),
	"plastic_black": Color("121117"),
	"fabric_purple": Color("3a2756"),
	"fabric_blue": Color("3a4a7a"),
	"fabric_grey": Color("4a4560"),
	"sheet": Color("cfcbe0"),
	"rug": Color("3a2f55"),
	"warm": Color("ffb070"),
	"cool": Color("6f8cff"),
	"neon_purple": Color("b05cff"),
	"neon_cyan": Color("25d9f5"),
	"pop": Color("ff3d7f"),
	"cardboard": Color("a07850"),
	"plant": Color("3f8a5c"),
	"foam": Color("26222f"),
}

var screen_material: StandardMaterial3D
var room_env: Environment
var world_env: WorldEnvironment
var fan: Node3D
var upgrade_nodes := {}
var _noise_cache := {}
var _base_remap := {}


func build() -> void:
	_base_remap = {
		"wood": mat(PAL.wood, 0.6, "wood", 1.0),
		"woodDark": mat(PAL.wood_dark, 0.6, "wood", 1.0),
		"metal": mat(PAL.metal, 0.35, ""),
		"metalLight": mat(Color("8a8a98"), 0.3, ""),
		"metalMedium": mat(PAL.metal_mid, 0.4, ""),
		"metalDark": mat(Color("17171d"), 0.4, ""),
		"carpet": mat(PAL.fabric_purple, 1.0, "fabric", 5.0),
		"carpetDarker": mat(Color("2a1f40"), 1.0, "fabric", 5.0),
		"carpetWhite": mat(PAL.sheet, 1.0, "fabric", 5.0),
		"plant": mat(PAL.plant, 0.8, ""),
		"lamp": glow(Color("ffc890"), 0.7),
		"glass": _glass(),
		"_defaultMat": mat(Color("2a2633"), 0.6, ""),
	}
	_environment()
	_shell()
	_window_and_city()
	_desk_setup()
	_chair()
	_booth_corner()
	_bed_area()
	_left_wall()
	_front_wall()
	_floor_clutter()
	_lighting()
	_street_sweep()
	_switch_and_props()
	_dust()
	_upgrade_props()


var led_lights: Array[Light3D] = []
var led_mats: Array[StandardMaterial3D] = []
var lights_on := true
var _sweep: SpotLight3D
var _sweep_t := 6.0


## Light switch by the door (LED strips on/off) and things to pick up and throw around.
func _switch_and_props() -> void:
	part(self, box(Vector3(0.08, 0.12, 0.015)), Vector3(-0.55, 1.25, 2.585), mat(Color("e8e4da"), 0.5, ""))
	part(self, box(Vector3(0.03, 0.05, 0.02)), Vector3(-0.55, 1.25, 2.575), mat(Color("d0ccc2"), 0.5, ""))
	solid(Vector3(0.2, 0.2, 0.1), Vector3(-0.55, 1.25, 2.54), "switch", "Light switch")
	var spots := [[Props.can(Color("c8ff3d")), Vector3(-0.2, 0.8, -1.95)], [Props.can(Color("ff3d7f")), Vector3(0.6, 0.1, 1.0)],
		[Props.bottle(), Vector3(1.75, 0.95, 0.55)], [Props.box(Vector3(0.3, 0.22, 0.25), PAL.cardboard), Vector3(1.2, 0.15, 2.1)],
		[Props.ball(), Vector3(-1.4, 0.2, 1.2)]]
	for sp in spots:
		var b: RigidBody3D = sp[0]
		b.position = sp[1]
		add_child(b)


func toggle_lights() -> void:
	lights_on = not lights_on
	for l in led_lights:
		l.visible = lights_on
	for m in led_mats:
		m.emission_energy_multiplier = float(m.get_meta("on_energy")) if lights_on else 0.0


## A car passes seven floors down: its headlights sweep across the ceiling.
func _street_sweep() -> void:
	_sweep = SpotLight3D.new()
	_sweep.position = Vector3(3.4, 0.4, -0.6)
	_sweep.light_color = Color("fff1d8")
	_sweep.light_energy = 0.0
	_sweep.spot_range = 9.0
	_sweep.spot_angle = 22.0
	_sweep.shadow_enabled = true
	add_child(_sweep)


func _process_sweep(delta: float) -> void:
	if not _sweep:
		return
	_sweep_t -= delta
	if _sweep_t <= 0.0:
		_sweep_t = randf_range(14.0, 26.0)
	var p := clampf((3.2 - _sweep_t) / 3.2, 0.0, 1.0) if _sweep_t < 3.2 else 0.0
	# light rises from the window sill, sweeps across the ceiling from front to back
	_sweep.rotation_degrees = Vector3(28.0, 90.0 + lerpf(-35.0, 35.0, p), 0.0)
	_sweep.light_energy = sin(p * PI) * 2.2


func _process(delta: float) -> void:
	_process_sweep(delta)
	if fan:
		fan.rotate_y(delta * 2.2)


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
			ramp.set_color(0, Color(0.8, 0.8, 0.82))
		"wood":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.02
			ramp.set_color(0, Color(0.74, 0.72, 0.7))
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


func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.4, 0.6, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.2
	return m


# ================= Mesh + model helpers =================

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
	var m: Material = glow(color, energy) if energy > 0.0 else mat(color, 0.9, "")
	return part(parent, t, pos, m, rot)


func group(name: String, pos := Vector3.ZERO, rot_y := 0.0) -> Node3D:
	var g := Node3D.new()
	g.name = name
	g.position = pos
	g.rotation_degrees.y = rot_y
	add_child(g)
	return g


func solid(size: Vector3, pos: Vector3, meta := "", label := "", rot_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees.y = rot_y
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


func _bounds(n: Node, xf: Transform3D, out: Dictionary) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var a: AABB = t * (n as MeshInstance3D).get_aabb()
		out["aabb"] = a if not out.has("aabb") else (out["aabb"] as AABB).merge(a)
	for c in n.get_children():
		_bounds(c, t, out)


func _recolor(n: Node, remap: Dictionary) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name if src else ""
			var m: Material = remap.get(key, _base_remap.get(key, null))
			if m:
				mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_recolor(c, remap)


## Places a kit model with its footprint centred on `pos` and its bottom on pos.y.
## `scl` is a float or Vector3. Returns the pivot; meta "size" = scaled size.
func kit(parent: Node3D, model: String, pos: Vector3, rot_y := 0.0, scl: Variant = S, remap := {}, path_fmt := KIT) -> Node3D:
	var ps: PackedScene = load(path_fmt % model)
	var inst: Node3D = ps.instantiate()
	var info := {}
	_bounds(inst, Transform3D(), info)
	var a: AABB = info.get("aabb", AABB())
	var s: Vector3 = scl if scl is Vector3 else Vector3.ONE * float(scl)
	var pivot := Node3D.new()
	pivot.name = model
	pivot.position = pos
	pivot.rotation_degrees.y = rot_y
	pivot.scale = s
	parent.add_child(pivot)
	inst.position = Vector3(-(a.position.x + a.size.x / 2.0), -a.position.y, -(a.position.z + a.size.z / 2.0))
	pivot.add_child(inst)
	_recolor(inst, remap)
	pivot.set_meta("size", a.size * s)
	return pivot


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
	env.tonemap_exposure = 1.6
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
	room_env = env
	world_env = we


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

	# Door (front wall) with a hand-made sign
	part(shell, box(Vector3(0.92, 2.06, 0.06)), Vector3(-1.2, 1.03, 2.6), mat(PAL.wall_trim, 0.6, ""))
	part(shell, box(Vector3(0.82, 2.0, 0.04)), Vector3(-1.2, 1.0, 2.58), mat(Color("2c2838"), 0.6, "wood", 1.0))
	part(shell, cyl(0.02, 0.12), Vector3(-0.88, 1.0, 2.54), mat(Color("8a8a95"), 0.3, ""), Vector3(90, 0, 0))
	part(shell, box(Vector3(0.38, 0.3, 0.005)), Vector3(-1.2, 1.55, 2.557), mat(Color("f2efe6"), 0.9, ""))
	text3d(shell, "DO NOT DISTURB", Vector3(-1.2, 1.62, 2.553), PAL.pop, 0.0007, Vector3(0, 180, 0), 0.0)
	text3d(shell, "RECORDING", Vector3(-1.2, 1.5, 2.553), Color("1a1a22"), 0.0011, Vector3(0, 180, 0), 0.0)

	# Neon LED strips (light comes from _lighting)
	for spec in [[Vector3(4.2, 0.025, 0.03), Vector3(0, 2.57, -2.58), PAL.neon_purple, 5.0],
			[Vector3(0.03, 0.025, 5.2), Vector3(-2.08, 2.57, 0), PAL.neon_cyan, 4.0],
			[Vector3(0.03, 0.025, 2.4), Vector3(2.08, 2.57, 1.4), PAL.neon_purple, 5.0]]:
		var lm := glow(spec[2], spec[3])
		lm.set_meta("on_energy", spec[3])
		led_mats.append(lm)
		part(shell, box(spec[0]), spec[1], lm)

	# Rug + ceiling fan
	kit(shell, "rugRounded", Vector3(0.05, 0, 0.35), 90, 1.8, {
		"carpet": mat(PAL.rug, 1.0, "fabric", 6.0),
		"carpetDarker": mat(Color("5a2a55"), 1.0, "fabric", 6.0),
	})
	fan = kit(shell, "ceilingFan", Vector3.ZERO, 0, S, {"wood": mat(PAL.wood_dark, 0.6, "wood")})
	var fs: Vector3 = fan.get_meta("size")
	fan.position = Vector3(0.0, 2.6 - fs.y, 0.4)


# ================= Window + skyline =================

func _window_and_city() -> void:
	var win := group("Window")
	var frame := mat(Color("d8d4e0"), 0.5, "")
	part(win, box(Vector3(0.12, 0.05, 1.5)), Vector3(2.1, 2.05, -0.6), frame)
	part(win, box(Vector3(0.2, 0.05, 1.55)), Vector3(2.05, 0.95, -0.6), frame)  # sill
	part(win, box(Vector3(0.12, 1.1, 0.05)), Vector3(2.1, 1.5, -1.32), frame)
	part(win, box(Vector3(0.12, 1.1, 0.05)), Vector3(2.1, 1.5, 0.12), frame)
	part(win, box(Vector3(0.06, 1.1, 0.04)), Vector3(2.12, 1.5, -0.6), frame)

	# Curtains (folds = several cylinders) + rod
	var curtain := mat(Color("1f2a48"), 1.0, "fabric", 4.0)
	for side in [-1.55, 0.32]:
		for i in 4:
			part(win, cyl(0.045, 2.15), Vector3(2.03 - (i % 2) * 0.03, 1.38, side + i * 0.065), curtain)
	part(win, cyl(0.012, 2.3), Vector3(2.04, 2.47, -0.6), mat(PAL.metal, 0.3, ""), Vector3(90, 0, 0))

	# Small plants + a can on the sill
	kit(win, "plantSmall1", Vector3(2.02, 0.975, -0.25), 0, 1.8, {"wood": mat(Color("c26a4a"), 0.8, "")})
	kit(win, "plantSmall3", Vector3(2.02, 0.975, -1.05), 40, 1.8, {"wood": mat(Color("d6d0c4"), 0.7, "")})
	part(win, cyl(0.033, 0.12), Vector3(2.0, 1.035, -0.85), mat(Color("c8ff3d"), 0.3, ""))

	# Mid layer: Kenney city buildings, windows glow via emission of the colormap
	var city := group("City")
	var cmap: Texture2D = load("res://assets/models/kenney_city/Textures/colormap.png")
	var shader: Shader = load("res://assets/shaders/night_building.gdshader")
	var bmat := ShaderMaterial.new()
	bmat.shader = shader
	bmat.set_shader_parameter("colormap", cmap)
	var models := ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c",
		"building-skyscraper-d", "building-skyscraper-e", "building-a", "building-e", "building-h",
		"building-i", "building-j", "building-k", "building-l", "building-n"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 60:
		var m: String = models[rng.randi() % models.size()]
		var x := rng.randf_range(34.0, 80.0)
		var z := rng.randf_range(-50.0, 46.0)
		var sc := rng.randf_range(5.0, 7.5)
		var remap := {"colormap": bmat}
		var b := kit(city, m, Vector3(x, -14.0, z), rng.randi_range(0, 3) * 90.0, sc, remap, CITY)
		for mi in b.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Far layer: procedural silhouettes with window lights
	var far := mat(Color("0d0c17"), 0.9, "")
	var warm_lights: Array[Transform3D] = []
	var cool_lights: Array[Transform3D] = []
	for i in 70:
		var w := rng.randf_range(4.0, 9.0)
		var d := rng.randf_range(4.0, 9.0)
		var h := rng.randf_range(14.0, 55.0)
		var x := rng.randf_range(60.0, 110.0)
		var z := rng.randf_range(-70.0, 60.0)
		var bld := part(city, box(Vector3(d, h, w)), Vector3(x, h / 2.0 - 14.0, z), far)
		bld.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var face_x := x - d / 2.0 - 0.02
		for row in range(1, int(h / 1.6)):
			for col in range(int(w / 1.2)):
				if rng.randf() < 0.38:
					var t := Transform3D(Basis(), Vector3(face_x, row * 1.6 - 14.0, z - w / 2.0 + 0.6 + col * 1.2))
					if rng.randf() < 0.7:
						warm_lights.append(t)
					else:
						cool_lights.append(t)
	_multimesh(city, warm_lights, glow(Color("ffc27a"), 2.5))
	_multimesh(city, cool_lights, glow(Color("8fb0ff"), 2.0))

	# Street level: sodium-orange glow lines far below
	part(city, box(Vector3(200, 0.1, 200)), Vector3(60, -14.05, 0), mat(Color("0a0910"), 1.0, ""))
	for z in [-22.0, -6.0, 10.0, 26.0]:
		part(city, box(Vector3(120, 0.05, 0.6)), Vector3(60, -13.95, z), glow(Color("ff9a3c"), 2.5))
	for x in [14.0, 30.0, 52.0]:
		part(city, box(Vector3(0.6, 0.05, 120)), Vector3(x, -13.95, 0), glow(Color("ff9a3c"), 2.5))
	# Harbour crane + aircraft warning lights
	var crane := mat(Color("141320"), 0.9, "")
	part(city, box(Vector3(0.8, 30.0, 0.8)), Vector3(48.0, 1.0, 6.0), crane)
	part(city, box(Vector3(0.7, 0.7, 22.0)), Vector3(48.0, 16.0, 0.0), crane)
	part(city, sphere(0.35), Vector3(48.0, 16.6, 10.5), glow(Color("ff3030"), 8.0))
	part(city, sphere(0.35), Vector3(36.0, 18.0, -12.0), glow(Color("ff3030"), 8.0))
	# Moon
	part(city, sphere(2.5), Vector3(80.0, 30.0, -8.0), glow(Color("dfe6ff"), 3.0))


func _multimesh(parent: Node3D, transforms: Array[Transform3D], material: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box(Vector3(0.05, 0.7, 0.55))
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
	var d := group("Desk", Vector3(-0.7, 0, -2.2))
	var black := mat(PAL.plastic_black, 0.4, "")
	var t := DESK_TOP

	kit(d, "desk", Vector3.ZERO, 0, S, {"wood": mat(PAL.wood_dark, 0.5, "wood", 1.0)})
	solid(Vector3(1.46, 0.77, 0.78), Vector3(-0.7, 0.385, -2.2))

	# Monitor (LOOPR runs on it via SubViewport)
	part(d, box(Vector3(0.26, 0.012, 0.18)), Vector3(0, t + 0.006, -0.2), black)
	part(d, box(Vector3(0.04, 0.26, 0.03)), Vector3(0, t + 0.13, -0.23), black)
	part(d, box(Vector3(0.86, 0.5, 0.035)), Vector3(0, t + 0.38, -0.21), black)
	screen_material = StandardMaterial3D.new()
	screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_material.albedo_color = Color(1.15, 1.15, 1.2)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.82, 0.46)
	part(d, quad, Vector3(0, t + 0.38, -0.191), screen_material)
	part(d, box(Vector3(0.7, 0.02, 0.02)), Vector3(0, t + 0.6, -0.24), glow(PAL.neon_purple, 3.0))  # bias light
	solid(Vector3(0.86, 0.5, 0.06), Vector3(-0.7, t + 0.38, -2.41), "pc", "Open LOOPR")

	# Speakers on foam pads (kit speakers, recoloured black)
	for x in [-0.6, 0.6]:
		part(d, box(Vector3(0.2, 0.03, 0.22)), Vector3(x, t + 0.015, -0.12), mat(PAL.foam, 1.0, "fabric"))
		kit(d, "speakerSmall", Vector3(x, t + 0.03, -0.12), -x * 15.0, 1.3, {
			"wood": black, "metalMedium": mat(Color("2c2c36"), 0.5, "")})
		part(d, box(Vector3(0.13, 0.006, 0.006)), Vector3(x, t + 0.07, -0.025), glow(PAL.neon_cyan, 2.0), Vector3(0, -x * 15.0, 0))

	# Keyboard + mouse (kit)
	kit(d, "computerKeyboard", Vector3(-0.02, t, 0.12), 0, 1.6, {
		"metalDark": black, "metalMedium": mat(Color("3a3646"), 0.5, "")})
	part(d, box(Vector3(0.26, 0.004, 0.22)), Vector3(-0.42, t + 0.002, 0.14), mat(Color("1b1726"), 1.0, "fabric"))
	kit(d, "computerMouse", Vector3(-0.42, t + 0.004, 0.14), 0, 1.6, {"metalDark": black})

	# MIDI pad with 4x4 glowing pads + knobs
	var pad := Node3D.new()
	pad.position = Vector3(0.45, t, 0.12)
	pad.rotation_degrees.y = -10
	d.add_child(pad)
	part(pad, box(Vector3(0.26, 0.03, 0.22)), Vector3(0, 0.015, 0), black)
	var pad_cols := [PAL.neon_purple, PAL.neon_cyan, PAL.pop, PAL.warm]
	for r in 4:
		for c in 4:
			part(pad, box(Vector3(0.04, 0.008, 0.04)), Vector3(-0.075 + c * 0.05, 0.034, -0.045 + r * 0.045),
				glow(pad_cols[(r + c) % 4], 0.8))
	for k in 4:
		part(pad, cyl(0.009, 0.014), Vector3(-0.075 + k * 0.05, 0.037, -0.09), mat(Color("9aa0ad"), 0.3, ""))

	# Headphones resting on the desk
	var hp := Node3D.new()
	hp.position = Vector3(-0.58, t + 0.03, 0.02)
	hp.rotation_degrees = Vector3(0, 25, 0)
	d.add_child(hp)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.075
	torus.outer_radius = 0.09
	part(hp, torus, Vector3(0, 0.02, 0), black, Vector3(90, 0, 0), Vector3(1, 1, 0.6))
	for x in [-0.085, 0.085]:
		part(hp, cyl(0.045, 0.035), Vector3(x, -0.01, 0), mat(Color("1e1c26"), 0.6, ""), Vector3(0, 0, 90))
		part(hp, cyl(0.03, 0.037), Vector3(x, -0.01, 0), mat(PAL.fabric_purple, 1.0, "fabric"), Vector3(0, 0, 90))

	# Articulated desk lamp (warm key light)
	var lamp := Node3D.new()
	lamp.position = Vector3(-0.66, t, -0.24)
	d.add_child(lamp)
	var lamp_m := mat(Color("2a2633"), 0.4, "")
	part(lamp, cyl(0.07, 0.02), Vector3(0, 0.01, 0), lamp_m)
	part(lamp, cyl(0.011, 0.42), Vector3(0.03, 0.21, 0.04), lamp_m, Vector3(10, 0, -10))
	part(lamp, cyl(0.011, 0.3), Vector3(0.12, 0.44, 0.14), lamp_m, Vector3(60, 0, -35))
	part(lamp, cyl(0.025, 0.11, 0.075), Vector3(0.22, 0.48, 0.25), lamp_m, Vector3(150, 0, -30))
	part(lamp, sphere(0.03), Vector3(0.235, 0.45, 0.275), glow(PAL.warm, 6.0))
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.24, 0.44, 0.28)
	spot.light_color = PAL.warm
	spot.light_energy = 5.0
	spot.spot_range = 2.2
	spot.spot_angle = 55.0
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 1.5
	lamp.add_child(spot)
	spot.basis = Basis.looking_at(Vector3(0.15, -1.0, 0.35).normalized())

	# Energy drinks, notebook with lyrics
	part(d, cyl(0.033, 0.12), Vector3(-0.4, t + 0.06, -0.06), mat(PAL.pop, 0.3, ""))
	part(d, cyl(0.033, 0.12), Vector3(-0.32, t + 0.06, -0.14), mat(PAL.neon_cyan, 0.3, ""))
	part(d, cyl(0.033, 0.12), Vector3(0.3, t + 0.06, -0.26), mat(Color("c8ff3d"), 0.3, ""))
	part(d, cyl(0.033, 0.12), Vector3(0.62, t + 0.033, 0.26), mat(PAL.pop, 0.3, ""), Vector3(0, 40, 90))
	part(d, box(Vector3(0.2, 0.012, 0.27)), Vector3(0.2, t + 0.006, 0.2), mat(Color("e8e2d0"), 0.9, "fabric"), Vector3(0, 18, 0))
	text3d(d, "bars v3\n- no sleep\n- 808 heart", Vector3(0.2, t + 0.014, 0.2), Color("2a2340"), 0.0006, Vector3(-90, 18, 0), 0.0)

	# Trash can with crumpled lyric sheets
	kit(self, "trashcan", Vector3(0.22, 0, -2.35), 0, 1.0, {"metal": mat(Color("2c2a36"), 0.4, "")})
	for p in [Vector3(0.2, 0.44, -2.33), Vector3(0.26, 0.45, -2.37), Vector3(0.44, 0.035, -2.1)]:
		part(self, sphere(0.035), p, mat(Color("ebe6da"), 0.9, "fabric"))

	# Plant in the back-left corner
	kit(self, "pottedPlant", Vector3(-1.82, 0, -2.3), 30, 1.8, {
		"wood": mat(Color("d6d0c4"), 0.7, ""), "woodDark": mat(Color("2a2018"), 1.0, "")})
	solid(Vector3(0.45, 1.2, 0.45), Vector3(-1.82, 0.6, -2.3))


# ================= Chair =================

func _chair() -> void:
	var c := group("Chair", Vector3(-0.66, 0, -1.45), 192.0)
	kit(c, "chairDesk", Vector3.ZERO, 0, S, {
		"carpet": mat(PAL.fabric_purple, 0.95, "fabric", 5.0),
		"metalMedium": mat(PAL.plastic_black, 0.4, ""),
	})
	# Hoodie thrown over the backrest
	var hoodie := mat(Color("55526a"), 1.0, "fabric", 6.0)
	part(c, box(Vector3(0.5, 0.28, 0.06)), Vector3(0, 1.08, -0.24), hoodie, Vector3(15, 0, 4))
	part(c, capsule(0.05, 0.4), Vector3(0.2, 0.86, -0.27), hoodie, Vector3(0, 0, 8))
	solid(Vector3(0.5, 0.55, 0.5), Vector3(-0.66, 0.28, -1.45), "chair", "Sit down")


# ================= Booth corner =================

func _booth_corner() -> void:
	var b := group("Booth", Vector3(1.45, 0, -2.2))
	# Mattress against the wall = "vocal booth", with tufting
	part(b, box(Vector3(1.0, 1.75, 0.16)), Vector3(0, 0.9, -0.35), mat(PAL.fabric_grey, 1.0, "fabric", 5.0))
	for r in 4:
		for col in 3:
			part(b, sphere(0.018), Vector3(-0.3 + col * 0.3, 0.35 + r * 0.38, -0.27), mat(Color("35314a"), 1.0, ""))
	text3d(b, "BOOTH", Vector3(0, 1.62, -0.265), PAL.neon_cyan, 0.0014, Vector3.ZERO, 2.0)
	part(b, box(Vector3(0.32, 0.11, 0.05)), Vector3(0, 2.0, -0.4), mat(PAL.plastic_black, 0.4, ""))
	text3d(b, "ON AIR", Vector3(0, 2.0, -0.372), Color("ff3030"), 0.0009, Vector3.ZERO, 3.0)
	part(b, box(Vector3(1.0, 0.02, 0.02)), Vector3(0, 0.05, -0.27), glow(PAL.neon_cyan, 4.0))
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
	var cable := mat(Color("0a0a0e"), 0.5, "")
	part(mic, cyl(0.007, 0.6), Vector3(-0.3, 0.008, 0.05), cable, Vector3(90, 80, 0))
	part(mic, cyl(0.007, 0.5), Vector3(-0.72, 0.008, -0.05), cable, Vector3(90, 60, 0))
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
			part(p, box(Vector3(0.12 if deep else 0.07, 0.12, 0.12)), Vector3(0.0 if deep else 0.025, -0.18 + r * 0.12, -0.18 + c * 0.12), dark if deep else light)


# ================= Bed area =================

func _bed_area() -> void:
	var b := group("Bed")
	var bed := kit(b, "bedSingle", Vector3(1.56, 0, 1.6), 0, Vector3(1.8, 1.8, 1.78), {
		"carpet": mat(PAL.fabric_blue, 1.0, "fabric", 5.0),
		"wood": mat(PAL.wood_dark, 0.6, "wood", 1.0),
		"carpetWhite": mat(PAL.sheet, 1.0, "fabric", 5.0),
	})
	var bs: Vector3 = bed.get_meta("size")
	solid(Vector3(bs.x, 0.5, bs.z), Vector3(1.56, 0.25, 1.6), "bed", "Lie down")
	# Extra pillow + phone with screen on
	kit(b, "pillowLong", Vector3(1.5, 0.48, 0.92), 8, 1.5, {"carpet": mat(PAL.pop.darkened(0.45), 1.0, "fabric", 5.0)})
	part(b, box(Vector3(0.075, 0.01, 0.15)), Vector3(1.35, 0.53, 1.7), mat(PAL.plastic_black, 0.3, ""), Vector3(0, 25, 0))
	part(b, box(Vector3(0.068, 0.002, 0.14)), Vector3(1.35, 0.536, 1.7), glow(Color("9b8cff"), 1.5), Vector3(0, 25, 0))

	# Nightstand + warm table lamp + mug
	var ns := kit(b, "cabinetBedDrawerTable", Vector3(1.8, 0, 0.32), -90, S, {
		"wood": mat(PAL.wood_dark, 0.6, "wood", 1.0), "_defaultMat": mat(Color("4a3428"), 0.6, "")})
	var nh: float = (ns.get_meta("size") as Vector3).y
	kit(b, "lampSquareTable", Vector3(1.85, nh, 0.42), 0, 1.6, {"metal": mat(PAL.metal, 0.35, "")})
	part(b, cyl(0.04, 0.09), Vector3(1.72, nh + 0.045, 0.2), mat(Color("e8e2d0"), 0.6, ""))


# ================= Left wall =================

func _left_wall() -> void:
	var w := group("LeftWall")
	# Poster above the desk
	var poster := Node3D.new()
	poster.position = Vector3(-0.7, 1.9, -2.585)
	w.add_child(poster)
	part(poster, box(Vector3(0.64, 0.82, 0.015)), Vector3.ZERO, mat(Color("0c0a12"), 0.5, ""))
	part(poster, box(Vector3(0.58, 0.76, 0.01)), Vector3(0, 0, 0.006), mat(Color("2a1033"), 0.9, "fabric", 3.0))
	part(poster, sphere(0.16), Vector3(0, 0.1, 0.012), glow(PAL.pop, 1.2), Vector3.ZERO, Vector3(1, 1, 0.05))
	text3d(poster, "LIL GRIND", Vector3(0, -0.18, 0.013), Color("ffd0e0"), 0.0016, Vector3.ZERO, 1.5)
	text3d(poster, "BEDROOM TAPE VOL 1", Vector3(0, -0.27, 0.013), PAL.neon_cyan, 0.0007, Vector3.ZERO, 1.5)

	# Second poster on the left wall
	var p2 := Node3D.new()
	p2.position = Vector3(-2.09, 1.7, 0.05)
	p2.rotation_degrees.y = 90
	w.add_child(p2)
	part(p2, box(Vector3(0.5, 0.7, 0.012)), Vector3.ZERO, mat(Color("102a33"), 0.9, "fabric", 3.0))
	text3d(p2, "NO\nSLEEP\nALL\nBEATS", Vector3(0, 0.02, 0.01), PAL.neon_cyan, 0.0018, Vector3.ZERO, 1.2)

	# Low bookcase with vinyl, books and a boombox
	var bc := kit(w, "bookcaseOpenLow", Vector3(-1.85, 0, 1.0), 90, S, {"wood": mat(PAL.wood_dark, 0.6, "wood", 1.0)})
	var bch: float = (bc.get_meta("size") as Vector3).y
	solid(Vector3(0.5, bch, 0.8), Vector3(-1.85, bch / 2.0, 1.0))
	kit(w, "radio", Vector3(-1.86, bch, 0.85), 90, 1.4, {
		"wood": mat(PAL.plastic_black, 0.4, ""), "metalMedium": mat(Color("2c2c36"), 0.5, "")})
	var rec_cols := [Color("1a1a22"), PAL.pop, Color("2a2a3a"), PAL.warm, Color("1a1a22"), PAL.neon_purple]
	for i in 6:
		part(w, cyl(0.15, 0.012), Vector3(-1.95, bch + 0.15, 1.18 + i * 0.03), mat(rec_cols[i], 0.5, ""), Vector3(90, 0, 8))
	kit(w, "books", Vector3(-1.85, 0.06, 0.82), 90, S)
	kit(w, "books", Vector3(-1.85, 0.42, 1.15), 90, S, {"carpetDarker": mat(Color("2d3a5c"), 0.8, "")})

	# Warm string lights on the left wall (bulbs + wire)
	var pts := 16
	var wire := mat(Color("0a0a0e"), 0.5, "")
	var prev := Vector3.ZERO
	for i in pts:
		var t := float(i) / (pts - 1)
		var p := Vector3(-2.07, 2.28 - sin(t * PI * 3.0) * 0.08 - sin(t * PI) * 0.05, lerpf(-1.0, 2.4, t))
		part(w, sphere(0.018), p, glow(PAL.warm, 5.0))
		if i > 0:
			var seg := part(w, cyl(0.003, prev.distance_to(p)), (prev + p) / 2.0, wire)
			var dir := (p - prev).normalized()
			seg.basis = Basis(Quaternion(Vector3.UP, dir))
		prev = p


# ================= Front wall =================

func _front_wall() -> void:
	var f := group("FrontWall")
	# Coat rack with hoodie and cap
	kit(f, "coatRackStanding", Vector3(-0.35, 0, 2.3), 0, S, {"wood": mat(PAL.plastic_black, 0.5, "")})
	part(f, capsule(0.12, 0.6), Vector3(-0.35, 1.18, 2.3), mat(Color("2a3a2a"), 1.0, "fabric", 6.0), Vector3(0, 0, 4), Vector3(1, 1, 0.55))
	part(f, sphere(0.1, 0.09), Vector3(-0.2, 1.52, 2.28), mat(PAL.pop.darkened(0.3), 0.9, "fabric"))
	part(f, box(Vector3(0.1, 0.01, 0.08)), Vector3(-0.12, 1.49, 2.28), mat(PAL.pop.darkened(0.3), 0.9, "fabric"))
	solid(Vector3(0.4, 1.6, 0.4), Vector3(-0.35, 0.8, 2.3))

	# Merch boxes
	var cb := {"wood": mat(PAL.cardboard, 0.9, "fabric", 3.0), "woodDark": mat(PAL.cardboard.darkened(0.25), 0.9, "fabric", 3.0)}
	var b1 := kit(f, "cardboardBoxClosed", Vector3(0.45, 0, 2.3), 8, S, cb)
	var b1h: float = (b1.get_meta("size") as Vector3).y
	kit(f, "cardboardBoxClosed", Vector3(0.48, b1h, 2.3), -6, 1.7, cb)
	kit(f, "cardboardBoxOpen", Vector3(1.0, 0, 2.25), -15, S, cb)
	text3d(f, "MERCH", Vector3(0.44, b1h * 0.55, 2.085), Color("1a1a22"), 0.0012, Vector3(0, 8, 0), 0.0)
	solid(Vector3(1.2, 1.0, 0.5), Vector3(0.7, 0.5, 2.3))

	# Floor lamp in the corner (warm)
	kit(f, "lampRoundFloor", Vector3(-1.9, 0, 2.35), 0, S, {"metal": mat(PAL.metal, 0.35, "")})


# ================= Floor clutter =================

func _floor_clutter() -> void:
	var f := group("Clutter")
	# Beanbag + controller
	part(f, sphere(0.45, 0.55), Vector3(-1.5, 0.27, 1.95), mat(Color("7a2a55"), 1.0, "fabric", 4.0))
	part(f, sphere(0.36, 0.3), Vector3(-1.5, 0.5, 2.0), mat(Color("8a3062"), 1.0, "fabric", 4.0))
	part(f, capsule(0.035, 0.15), Vector3(-1.45, 0.66, 1.9), mat(PAL.plastic_black, 0.4, ""), Vector3(0, 30, 90))
	solid(Vector3(0.8, 0.5, 0.8), Vector3(-1.5, 0.25, 1.95))
	# Pizza box (half open)
	var pz := Node3D.new()
	pz.position = Vector3(0.55, 0, 1.95)
	pz.rotation_degrees.y = 25
	f.add_child(pz)
	part(pz, box(Vector3(0.36, 0.04, 0.36)), Vector3(0, 0.02, 0), mat(PAL.cardboard, 0.9, "fabric", 3.0))
	part(pz, box(Vector3(0.36, 0.01, 0.36)), Vector3(0, 0.13, -0.24), mat(PAL.cardboard, 0.9, "fabric", 3.0), Vector3(-55, 0, 0))
	part(pz, cyl(0.15, 0.012), Vector3(0, 0.045, 0), mat(Color("d98c3a"), 0.8, "fabric", 6.0))
	for i in 5:
		part(pz, cyl(0.02, 0.005), Vector3(cos(i * 1.3) * 0.08, 0.053, sin(i * 1.3) * 0.08), mat(Color("a0302a"), 0.8, ""))
	# Sneakers (fictional brand)
	for i in 2:
		var s := Node3D.new()
		s.position = Vector3(0.62 + i * 0.16, 0, 0.75 + i * 0.05)
		s.rotation_degrees.y = -20 + i * 30
		f.add_child(s)
		part(s, box(Vector3(0.11, 0.035, 0.29)), Vector3(0, 0.018, 0), mat(Color("f2f0ff"), 0.6, ""))
		part(s, capsule(0.055, 0.24), Vector3(0, 0.075, -0.01), mat(Color("e4e2ee"), 0.7, "fabric"), Vector3(90, 0, 0), Vector3(1, 1, 0.65))
		part(s, box(Vector3(0.112, 0.02, 0.12)), Vector3(0, 0.06, 0.03), mat(PAL.neon_cyan, 0.5, ""))
	# Clothes pile
	part(f, sphere(0.25, 0.14), Vector3(0.95, 0.06, 1.0), mat(Color("3a4a3a"), 1.0, "fabric", 6.0), Vector3.ZERO, Vector3(1.3, 1, 1))
	part(f, sphere(0.18, 0.1), Vector3(0.85, 0.12, 0.95), mat(Color("5a3040"), 1.0, "fabric", 6.0))
	# Power strip with a red LED + cables under the desk
	part(f, box(Vector3(0.3, 0.04, 0.07)), Vector3(-0.2, 0.02, -2.45), mat(Color("e0dde8"), 0.6, ""))
	part(f, sphere(0.006), Vector3(-0.12, 0.045, -2.45), glow(Color("ff3030"), 4.0))
	var cable := mat(Color("0a0a0e"), 0.5, "")
	part(f, cyl(0.007, 0.5), Vector3(-0.45, 0.008, -2.4), cable, Vector3(90, 70, 0))
	part(f, cyl(0.007, 0.4), Vector3(0.05, 0.008, -2.3), cable, Vector3(90, 20, 0))


# ================= Upgrades (hidden until bought) =================

func _upgrade_props() -> void:
	# Acoustic foam on the left and front walls
	var foam := group("Upgrade_foam")
	for z in [-1.6, -1.05, 1.9]:
		for y in [1.25, 1.75]:
			var p := Node3D.new()
			p.position = Vector3(-2.04, y, z)
			p.rotation_degrees.y = 180
			foam.add_child(p)
			_foam_panel(p, Vector3.ZERO)
	for x in [0.0, 1.6]:
		var p := Node3D.new()
		p.position = Vector3(x, 1.6, 2.55)
		p.rotation_degrees.y = 90
		foam.add_child(p)
		_foam_panel(p, Vector3.ZERO)
	upgrade_nodes["foam"] = foam

	# Neon sign above the bed
	var neon := group("Upgrade_neon")
	part(neon, box(Vector3(1.3, 0.34, 0.03)), Vector3(2.08, 1.95, 1.45), mat(Color("0c0a12"), 0.5, ""), Vector3(0, 90, 0))
	text3d(neon, "STUDIO GRIND", Vector3(2.06, 1.95, 1.45), PAL.pop, 0.0024, Vector3(0, -90, 0), 6.0)
	var nl := OmniLight3D.new()
	nl.position = Vector3(1.8, 1.95, 1.45)
	nl.light_color = PAL.pop
	nl.light_energy = 1.2
	nl.omni_range = 2.6
	neon.add_child(nl)
	upgrade_nodes["neon"] = neon

	# Condenser mic: gold capsule on the stand in the booth
	var mic := group("Upgrade_mic_pro")
	part(mic, cyl(0.04, 0.17), Vector3(1.45, 1.52, -1.6), mat(Color("f2c14e"), 0.25, ""), Vector3(0, 0, 0))
	part(mic, sphere(0.045), Vector3(1.45, 1.62, -1.6), mat(Color("cfd3dc"), 0.2, ""))
	upgrade_nodes["mic_pro"] = mic

	# Studio monitors on floor stands next to the desk
	var mon := group("Upgrade_monitors")
	for x in [-1.75, 0.3]:
		part(mon, cyl(0.12, 0.02), Vector3(x, 0.01, -2.2), mat(PAL.plastic_black, 0.4, ""))
		part(mon, cyl(0.02, 0.95), Vector3(x, 0.48, -2.2), mat(PAL.metal, 0.3, ""))
		part(mon, box(Vector3(0.26, 0.4, 0.28)), Vector3(x, 1.16, -2.2), mat(PAL.plastic_black, 0.4, ""))
		part(mon, cyl(0.085, 0.01), Vector3(x, 1.1, -2.055), mat(Color("2a2a33"), 0.4, ""), Vector3(90, 0, 0))
		part(mon, cyl(0.03, 0.01), Vector3(x, 1.27, -2.055), mat(Color("3a3a44"), 0.3, ""), Vector3(90, 0, 0))
		part(mon, box(Vector3(0.2, 0.008, 0.008)), Vector3(x, 0.98, -2.058), glow(PAL.neon_purple, 3.0))
	upgrade_nodes["monitors"] = mon
	apply_upgrades([])


func apply_upgrades(owned: Array) -> void:
	for id in upgrade_nodes.keys():
		(upgrade_nodes[id] as Node3D).visible = id in owned


# ================= Atmosphere =================

## Slow floating dust specks: catch the lamp and moonlight.
func _dust() -> void:
	var p := GPUParticles3D.new()
	p.name = "Dust"
	p.amount = 420
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.position = Vector3(0, 1.3, 0)
	p.visibility_aabb = AABB(Vector3(-2.2, -1.4, -2.7), Vector3(4.4, 2.8, 5.4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.0, 1.2, 2.5)
	pm.gravity = Vector3(0, -0.004, 0)
	pm.initial_velocity_min = 0.005
	pm.initial_velocity_max = 0.03
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_speed_random = 0.2
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.006, 0.006)
	var dot := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = g
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = dot
	m.albedo_color = Color(1.0, 0.9, 0.8, 0.22)
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.6
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)


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

	# [position, colour, energy, range, shadow]
	for spec in [
		[Vector3(-0.7, 2.4, -2.35), PAL.neon_purple, 1.2, 3.2, true],  # LED back wall
		[Vector3(-1.9, 2.4, 0.4), PAL.neon_cyan, 0.7, 3.0, false],  # LED left wall
		[Vector3(1.9, 2.4, 1.5), PAL.neon_purple, 0.6, 2.8, false],  # LED right wall
		[Vector3(1.45, 0.4, -1.6), PAL.neon_cyan, 0.8, 2.0, false],  # booth backlight
		[Vector3(-0.7, 1.1, -2.0), Color("a78bfa"), 0.9, 1.8, false],  # monitor spill
		[Vector3(-1.85, 2.1, 0.7), PAL.warm, 0.6, 2.8, false],  # string lights
		[Vector3(1.85, 0.95, 0.42), PAL.warm, 1.1, 2.6, true],  # nightstand lamp
		[Vector3(-1.9, 1.65, 2.3), PAL.warm, 0.9, 3.0, false],  # floor lamp
		[Vector3(0.9, 2.2, 1.6), Color("7a5cff"), 0.5, 3.4, false],  # soft fill over the bed
	]:
		var l := OmniLight3D.new()
		l.position = spec[0]
		l.light_color = spec[1]
		l.light_energy = spec[2]
		l.omni_range = spec[3]
		l.shadow_enabled = spec[4]
		add_child(l)
		if led_lights.size() < 3:
			led_lights.append(l)
