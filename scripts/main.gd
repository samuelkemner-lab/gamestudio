extends Node3D
## Studio Grind – prototype v0.3
## Title screen, bedroom studio (docs/ART_DIRECTION.md), first-person player, LOOPR at the desk.

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const VERSION := "v0.3 prototype"

var player  # player.gd (CharacterBody3D)
var room: RoomBuilder
var sequencer: Sequencer
var loopr: LooprUI
var screen_ui: LooprUI
var hud: CanvasLayer
var crosshair: Label
var prompt: PanelContainer
var prompt_key: Label
var prompt_text: Label

var in_menu := false
var menu_layer: CanvasLayer
var menu_cam: Camera3D
var _menu_press: Label
var _t := 0.0


func _ready() -> void:
	room = RoomBuilder.new()
	room.name = "Room"
	add_child(room)
	room.build()

	sequencer = Sequencer.new()
	sequencer.name = "Sequencer"
	add_child(sequencer)

	_build_monitor_screen()

	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.position = Vector3(0.3, 0.05, 1.0)
	player.rotation.y = deg_to_rad(20)
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
		show_menu()


## The monitor in the room shows LOOPR live (same sequencer, mirrored).
func _build_monitor_screen() -> void:
	var vp := SubViewport.new()
	vp.name = "MonitorViewport"
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_disable_input = true
	add_child(vp)
	screen_ui = LooprUI.new()
	vp.add_child(screen_ui)
	screen_ui.setup(sequencer)
	room.screen_material.albedo_texture = vp.get_texture()


func _process(delta: float) -> void:
	_t += delta
	if in_menu:
		_update_menu(delta)
		return
	var vp := get_viewport().get_visible_rect().size
	crosshair.position = Vector2(0, vp.y / 2.0 - 16)
	crosshair.size = Vector2(vp.x, 32)
	var target: Object = null if loopr.visible else player.hover_target()
	prompt.visible = target != null
	if target:
		prompt_text.text = str(target.get_meta("label"))
		prompt.reset_size()
		prompt.position = Vector2((vp.x - prompt.size.x) / 2.0, vp.y / 2.0 + 44)
		crosshair.add_theme_color_override("font_color", Color("c4b5fd"))
	else:
		crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))


func _input(event: InputEvent) -> void:
	if in_menu:
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
			start_game()
			get_viewport().set_input_as_handled()
		return
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
	hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_loopr() -> void:
	loopr.visible = false
	player.enabled = true
	hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------- Title screen ----------

func show_menu() -> void:
	in_menu = true
	player.enabled = false
	hud.visible = false
	menu_cam = Camera3D.new()
	menu_cam.fov = 62.0
	add_child(menu_cam)
	menu_cam.current = true
	sequencer.play()

	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(root)

	# Left-side darkening so the title reads
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.02, 0.07, 0.95))
	grad.set_color(1, Color(0.03, 0.02, 0.07, 0.0))
	grad.add_point(0.6, Color(0.03, 0.02, 0.07, 0.85))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = gtex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 900
	root.add_child(shade)

	var box := VBoxContainer.new()
	box.position = Vector2(90, 250)
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)

	var kicker := _menu_label("A BEDROOM PRODUCER STORY", 18, Color("25d9f5"))
	box.add_child(kicker)
	var title := _menu_label("STUDIO\nGRIND", 120, Color("f4efff"))
	title.add_theme_constant_override("line_spacing", -38)
	title.add_theme_color_override("font_outline_color", Color("b05cff"))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_shadow_color", Color(0.69, 0.36, 1.0, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 28)
	box.add_child(title)
	box.add_child(_menu_label("from bedroom beats to the big stage", 22, Color("c4b5fd")))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	box.add_child(spacer)
	_menu_press = _menu_label("PRESS ANY KEY", 22, Color("ffffff"))
	box.add_child(_menu_press)

	var ver := _menu_label(VERSION, 14, Color(1, 1, 1, 0.4))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(90, -50)
	ver.offset_top = -50
	root.add_child(ver)


func _menu_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _update_menu(_delta: float) -> void:
	# Slow cinematic drift across the room, looking at the desk
	var a := _t * 0.12
	menu_cam.position = Vector3(0.95 + sin(a) * 0.45, 1.55 + sin(a * 0.7) * 0.08, 1.75 + cos(a) * 0.2)
	menu_cam.look_at(Vector3(-0.75, 1.05, -2.1), Vector3.UP)
	_menu_press.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 3.0))


func start_game() -> void:
	if not in_menu:
		return
	in_menu = false
	sequencer.stop()
	menu_layer.queue_free()
	menu_cam.queue_free()
	player.camera.current = true
	player.enabled = true
	hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------- HUD ----------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	var title := Label.new()
	title.text = "STUDIO GRIND"
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("e9e4ff"))
	title.add_theme_color_override("font_outline_color", Color("1a1030"))
	title.add_theme_constant_override("outline_size", 6)
	hud.add_child(title)

	var controls := Label.new()
	controls.text = "WASD move  ·  E interact  ·  ESC free mouse"
	controls.position = Vector2(24, 44)
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0, 0.6))
	hud.add_child(controls)

	crosshair = Label.new()
	crosshair.text = "·"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.add_theme_color_override("font_outline_color", Color.BLACK)
	crosshair.add_theme_constant_override("outline_size", 4)
	hud.add_child(crosshair)

	# Interaction prompt: [E] keycap + action
	prompt = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.13, 0.82)
	sb.border_color = Color("b05cff")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	prompt.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	prompt.add_child(row)
	var key_panel := PanelContainer.new()
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color("f4efff")
	ksb.set_corner_radius_all(6)
	ksb.content_margin_left = 9
	ksb.content_margin_right = 9
	ksb.content_margin_top = 1
	ksb.content_margin_bottom = 1
	key_panel.add_theme_stylebox_override("panel", ksb)
	prompt_key = Label.new()
	prompt_key.text = "E"
	prompt_key.add_theme_font_size_override("font_size", 18)
	prompt_key.add_theme_color_override("font_color", Color("120f1c"))
	key_panel.add_child(prompt_key)
	row.add_child(key_panel)
	prompt_text = Label.new()
	prompt_text.add_theme_font_size_override("font_size", 18)
	prompt_text.add_theme_color_override("font_color", Color("f4efff"))
	row.add_child(prompt_text)
	prompt.visible = false
	hud.add_child(prompt)
