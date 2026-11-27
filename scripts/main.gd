extends Node3D
## Studio Grind – prototype v0.2
## Bedroom studio (see docs/ART_DIRECTION.md), first-person player, LOOPR at the desk.

const PLAYER_SCRIPT := preload("res://scripts/player.gd")

var player  # player.gd (CharacterBody3D)
var room: RoomBuilder
var sequencer: Sequencer
var loopr: LooprUI
var screen_ui: LooprUI
var hud_hint: Label
var crosshair: Label


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
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "STUDIO GRIND"
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("e9e4ff"))
	title.add_theme_color_override("font_outline_color", Color("1a1030"))
	title.add_theme_constant_override("outline_size", 6)
	layer.add_child(title)

	var controls := Label.new()
	controls.text = "WASD move  ·  E interact  ·  ESC free mouse"
	controls.position = Vector2(24, 44)
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0, 0.6))
	layer.add_child(controls)

	crosshair = Label.new()
	crosshair.text = "·"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.add_theme_color_override("font_outline_color", Color.BLACK)
	crosshair.add_theme_constant_override("outline_size", 4)
	layer.add_child(crosshair)

	hud_hint = Label.new()
	hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_hint.add_theme_font_size_override("font_size", 20)
	hud_hint.add_theme_color_override("font_color", Color("e9e4ff"))
	hud_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_hint.add_theme_constant_override("outline_size", 8)
	layer.add_child(hud_hint)
