extends Node3D
## Studio Grind – prototype v0.1
## Bedroom studio (greybox + neon), first-person player, LOOPR at the desk.

const PLAYER_SCRIPT := preload("res://scripts/player.gd")

var player  # player.gd (CharacterBody3D)
var sequencer: Sequencer
var loopr: LooprUI
var hud_hint: Label
var crosshair: Label


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_furniture()

	sequencer = Sequencer.new()
	sequencer.name = "Sequencer"
	add_child(sequencer)

	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.position = Vector3(0.4, 0.05, 1.4)
	player.rotation.y = deg_to_rad(15)
	add_child(player)
	player.interacted.connect(_on_interacted)

	_build_hud()

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	loopr = LooprUI.new()
	layer.add_child(loopr)
	loopr.setup(sequencer)
	loopr.visible = false

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	crosshair.position = Vector2(0, vp.y / 2.0 - 16)
	crosshair.size = Vector2(vp.x, 32)
	hud_hint.position = Vector2(0, vp.y / 2.0 + 50)
	hud_hint.size = Vector2(vp.x, 32)
	if loopr.visible:
		hud_hint.text = ""
		return
	var target: Object = player.hover_target()
	hud_hint.text = "[E]  " + str(target.get_meta("label")) if target else ""


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_ESCAPE:
		if loopr.visible:
			close_loopr()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_SPACE and loopr.visible:
		sequencer.toggle_play()
		get_viewport().set_input_as_handled()


func _on_interacted(target: Object) -> void:
	if target.get_meta("interact") == "pc":
		open_loopr()


func open_loopr() -> void:
	loopr.visible = true
	player.enabled = false
	crosshair.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_loopr() -> void:
	loopr.visible = false
	player.enabled = true
	crosshair.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------- World building (greybox, replaced by low-poly assets later) ----------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07060d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2a1f4d")
	env.ambient_light_energy = 0.55
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _box(size: Vector3, pos: Vector3, color: Color, solid := true, emission := 0.0) -> Node3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _mat(color, emission)
	if not solid:
		mesh.position = pos
		add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.add_child(mesh)
	add_child(body)
	return body


func _build_room() -> void:
	var wall := Color("2b2738")
	_box(Vector3(4.4, 0.1, 5.4), Vector3(0, -0.05, 0), Color("3a2f2a"))  # floor
	_box(Vector3(4.4, 0.1, 5.4), Vector3(0, 2.65, 0), Color("1f1c29"))  # ceiling
	_box(Vector3(4.4, 2.6, 0.1), Vector3(0, 1.3, -2.65), wall)  # back wall
	_box(Vector3(4.4, 2.6, 0.1), Vector3(0, 1.3, 2.65), wall)  # front wall
	_box(Vector3(0.1, 2.6, 5.4), Vector3(-2.15, 1.3, 0), wall)  # left wall
	_box(Vector3(0.1, 2.6, 5.4), Vector3(2.15, 1.3, 0), wall)  # right wall

	# Neon LED strips along the ceiling edges
	var purple := Color("a855f7")
	var blue := Color("3b82f6")
	_box(Vector3(4.2, 0.04, 0.04), Vector3(0, 2.56, -2.58), purple, false, 6.0)
	_box(Vector3(0.04, 0.04, 5.2), Vector3(-2.08, 2.56, 0), blue, false, 6.0)
	_box(Vector3(0.04, 0.04, 5.2), Vector3(2.08, 2.56, 0), purple, false, 6.0)

	for spec in [[Vector3(-1.2, 2.2, -1.6), purple], [Vector3(1.4, 2.2, 1.0), blue]]:
		var light := OmniLight3D.new()
		light.position = spec[0]
		light.light_color = spec[1]
		light.light_energy = 2.2
		light.omni_range = 5.0
		add_child(light)

	# Window with city lights (fictional Rotterdam-like skyline later)
	_box(Vector3(0.05, 1.0, 1.4), Vector3(2.09, 1.55, -0.6), Color("1e3a8a"), false, 1.5)


func _build_furniture() -> void:
	# Desk + gaming chair
	_box(Vector3(1.6, 0.06, 0.7), Vector3(-0.7, 0.75, -2.2), Color("17141f"))
	_box(Vector3(0.06, 0.72, 0.6), Vector3(-1.45, 0.36, -2.2), Color("17141f"))
	_box(Vector3(0.06, 0.72, 0.6), Vector3(0.05, 0.36, -2.2), Color("17141f"))
	_box(Vector3(0.5, 0.08, 0.5), Vector3(-0.7, 0.48, -1.55), Color("2b1d3d"))
	_box(Vector3(0.5, 0.65, 0.08), Vector3(-0.7, 0.85, -1.3), Color("2b1d3d"))

	# Monitor = interactable PC
	var screen := _box(Vector3(0.75, 0.42, 0.04), Vector3(-0.7, 1.08, -2.42), Color("7c3aed"), true, 2.5)
	screen.set_meta("interact", "pc")
	screen.set_meta("label", "Open LOOPR")
	_box(Vector3(0.06, 0.25, 0.06), Vector3(-0.7, 0.86, -2.45), Color("0d0b14"), false)

	# Speakers
	_box(Vector3(0.18, 0.28, 0.2), Vector3(-1.3, 0.92, -2.35), Color("0d0b14"))
	_box(Vector3(0.18, 0.28, 0.2), Vector3(-0.1, 0.92, -2.35), Color("0d0b14"))

	# Keyboard + MIDI pad
	_box(Vector3(0.45, 0.02, 0.15), Vector3(-0.7, 0.79, -2.0), Color("0d0b14"), false)
	_box(Vector3(0.25, 0.03, 0.2), Vector3(-0.2, 0.79, -2.05), Color("22d3ee"), false, 0.8)

	# Bed (the "booth" for now: mattress against the wall)
	_box(Vector3(1.0, 0.4, 2.0), Vector3(1.55, 0.2, 1.5), Color("1e1b4b"))
	_box(Vector3(1.0, 1.6, 0.15), Vector3(1.55, 0.8, -1.9), Color("3f3a5c"))  # mattress on wall
	var mic := _box(Vector3(0.06, 1.5, 0.06), Vector3(1.55, 0.75, -1.5), Color("9ca3af"))
	mic.set_meta("interact", "mic")
	mic.set_meta("label", "Recording booth (coming soon)")

	# Posters (own designs later, no real artists)
	_box(Vector3(0.6, 0.8, 0.02), Vector3(-1.6, 1.7, -2.59), Color("f43f5e"), false, 0.4)
	_box(Vector3(0.02, 0.7, 0.5), Vector3(-2.09, 1.6, 1.0), Color("22d3ee"), false, 0.4)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "STUDIO GRIND  //  prototype v0.1"
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("c4b5fd"))
	layer.add_child(title)

	var controls := Label.new()
	controls.text = "WASD move   •   mouse look   •   E interact   •   ESC free mouse"
	controls.position = Vector2(24, 46)
	controls.add_theme_color_override("font_color", Color("8f86b3"))
	layer.add_child(controls)

	crosshair = Label.new()
	crosshair.text = "•"
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 22)
	layer.add_child(crosshair)

	hud_hint = Label.new()
	hud_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_hint.add_theme_constant_override("outline_size", 8)
	hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_hint.add_theme_font_size_override("font_size", 20)
	hud_hint.add_theme_color_override("font_color", Color("e9e4ff"))
	layer.add_child(hud_hint)
