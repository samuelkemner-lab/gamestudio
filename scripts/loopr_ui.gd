class_name LooprUI
extends Control
## LOOPR: the in-game DAW. v0.1 = Channel Rack (step sequencer) + Mixer.

signal close_requested

const BG := Color("120f1c")
const PANEL := Color("1c1730")
const PANEL_LIGHT := Color("2a2347")
const STEP_OFF_A := Color("2b2540")
const STEP_OFF_B := Color("221d35")
const ACCENT := Color("a855f7")
const TEXT := Color("e9e4ff")
const TEXT_DIM := Color("8f86b3")
const TRACK_COLORS: Array[Color] = [
	Color("f43f5e"), Color("f59e0b"), Color("22d3ee"), Color("a3e635"), Color("a855f7"),
]

var seq: Sequencer
var step_buttons: Array = []  # [track][step] -> Button
var playhead: Array[ColorRect] = []
var play_button: Button
var bpm_box: SpinBox


func setup(sequencer: Sequencer) -> void:
	seq = sequencer
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _box(BG, 0))
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	root.add_child(_build_top_bar())

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", _box(PANEL, 10))
	tabs.add_theme_color_override("font_selected_color", TEXT)
	tabs.add_theme_color_override("font_unselected_color", TEXT_DIM)
	tabs.add_theme_font_size_override("font_size", 18)
	root.add_child(tabs)

	var rack := _build_channel_rack()
	rack.name = "Channel Rack"
	tabs.add_child(rack)
	var mixer := _build_mixer()
	mixer.name = "Mixer"
	tabs.add_child(mixer)

	seq.step_changed.connect(_on_step_changed)
	seq.play_state_changed.connect(_on_play_state_changed)
	seq.pattern_changed.connect(refresh_grid)
	refresh_grid()


# ---------- Top bar ----------

func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)

	var logo := Label.new()
	logo.text = "LOOPR"
	logo.add_theme_font_size_override("font_size", 34)
	logo.add_theme_color_override("font_color", ACCENT)
	bar.add_child(logo)

	var sub := Label.new()
	sub.text = "v0.2  //  bedroom edition"
	sub.add_theme_color_override("font_color", TEXT_DIM)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(sub)

	bar.add_child(_spacer())

	play_button = _button("PLAY", ACCENT)
	play_button.custom_minimum_size = Vector2(110, 44)
	play_button.pressed.connect(func(): seq.toggle_play())
	bar.add_child(play_button)

	var bpm_label := Label.new()
	bpm_label.text = "BPM"
	bpm_label.add_theme_color_override("font_color", TEXT_DIM)
	bpm_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(bpm_label)

	bpm_box = SpinBox.new()
	bpm_box.min_value = 60
	bpm_box.max_value = 200
	bpm_box.value = seq.bpm
	bpm_box.custom_minimum_size = Vector2(110, 44)
	bpm_box.value_changed.connect(func(v: float): seq.bpm = v)
	bar.add_child(bpm_box)

	var clear_btn := _button("CLEAR", PANEL_LIGHT)
	clear_btn.custom_minimum_size = Vector2(100, 44)
	clear_btn.pressed.connect(func():
		seq.clear())
	bar.add_child(clear_btn)

	var reset_btn := _button("DEMO BEAT", PANEL_LIGHT)
	reset_btn.custom_minimum_size = Vector2(130, 44)
	reset_btn.pressed.connect(func():
		seq.load_default_pattern())
	bar.add_child(reset_btn)

	bar.add_child(_spacer())

	var hint := Label.new()
	hint.text = "[SPACE] play/stop    [ESC] leave desk"
	hint.add_theme_color_override("font_color", TEXT_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(hint)
	return bar


# ---------- Channel rack ----------

func _build_channel_rack() -> Control:
	var wrap := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		wrap.add_theme_constant_override("margin_" + side, 24)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	wrap.add_child(col)

	# Playhead row
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 6)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(150, 8)
	head_row.add_child(pad)
	for s in Sequencer.STEPS:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(46, 8)
		dot.color = STEP_OFF_B
		head_row.add_child(dot)
		playhead.append(dot)
		if s % 4 == 3 and s < Sequencer.STEPS - 1:
			head_row.add_child(_gap())
	col.add_child(head_row)

	for t in Sequencer.TRACKS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var name_btn := _button(Sequencer.TRACKS[t], PANEL_LIGHT)
		name_btn.custom_minimum_size = Vector2(150, 46)
		name_btn.add_theme_color_override("font_color", TRACK_COLORS[t])
		name_btn.tooltip_text = "Preview sound"
		name_btn.pressed.connect(seq.preview.bind(t))
		row.add_child(name_btn)

		var buttons: Array = []
		for s in Sequencer.STEPS:
			var b := Button.new()
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(46, 46)
			var off := STEP_OFF_A if (s / 4) % 2 == 0 else STEP_OFF_B
			b.add_theme_stylebox_override("normal", _box(off, 6))
			b.add_theme_stylebox_override("hover", _box(off.lightened(0.15), 6))
			b.add_theme_stylebox_override("pressed", _box(TRACK_COLORS[t], 6))
			b.add_theme_stylebox_override("hover_pressed", _box(TRACK_COLORS[t].lightened(0.2), 6))
			b.toggled.connect(_on_step_toggled.bind(t, s))
			row.add_child(b)
			buttons.append(b)
			if s % 4 == 3 and s < Sequencer.STEPS - 1:
				row.add_child(_gap())
		step_buttons.append(buttons)
		col.add_child(row)

	var tip := Label.new()
	tip.text = "Click a step to place a hit. Click a track name to hear its sound."
	tip.add_theme_color_override("font_color", TEXT_DIM)
	col.add_child(tip)
	return wrap


func refresh_grid() -> void:
	for t in step_buttons.size():
		for s in Sequencer.STEPS:
			step_buttons[t][s].set_pressed_no_signal(seq.pattern[t][s])


func _on_step_toggled(on: bool, track: int, step: int) -> void:
	seq.set_step(track, step, on)
	if on and not seq.playing:
		seq.preview(track)


func _on_step_changed(step: int) -> void:
	for i in playhead.size():
		playhead[i].color = ACCENT if i == step else STEP_OFF_B


func _on_play_state_changed(is_playing: bool) -> void:
	play_button.text = "STOP" if is_playing else "PLAY"


# ---------- Mixer ----------

func _build_mixer() -> Control:
	var wrap := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		wrap.add_theme_constant_override("margin_" + side, 24)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	wrap.add_child(row)

	for t in Sequencer.TRACKS.size():
		row.add_child(_channel_strip(Sequencer.TRACKS[t], seq.bus_index(t), TRACK_COLORS[t]))
	row.add_child(_channel_strip("MASTER", 0, ACCENT))
	return wrap


func _channel_strip(title: String, bus_idx: int, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL_LIGHT, 10))
	panel.custom_minimum_size = Vector2(120, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	var name := Label.new()
	name.text = title
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_color_override("font_color", color)
	col.add_child(name)

	var db_label := Label.new()
	db_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	db_label.add_theme_color_override("font_color", TEXT_DIM)

	var slider := VSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.25
	slider.step = 0.01
	slider.value = seq.get_volume(bus_idx)
	slider.custom_minimum_size = Vector2(40, 300)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float):
		seq.set_volume(bus_idx, v)
		db_label.text = _db_text(v))
	col.add_child(slider)

	db_label.text = _db_text(slider.value)
	col.add_child(db_label)

	var mute := _button("MUTE", BG)
	mute.toggle_mode = true
	mute.add_theme_stylebox_override("pressed", _box(Color("f43f5e"), 6))
	mute.toggled.connect(func(on: bool): seq.set_mute(bus_idx, on))
	col.add_child(mute)
	return panel


func _db_text(linear: float) -> String:
	if linear <= 0.001:
		return "-inf dB"
	return "%+.1f dB" % linear_to_db(linear)


# ---------- Helpers ----------

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _box(color, 8))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.15), 8))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), 8))
	b.add_theme_color_override("font_color", TEXT)
	return b


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _gap() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(10, 0)
	return c
