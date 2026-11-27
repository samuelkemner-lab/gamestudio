class_name LooprUI
extends Control
## LOOPR: the in-game DAW. v0.1 = Channel Rack (step sequencer) + Mixer.

signal close_requested
signal record_pressed
signal finish_pressed

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
var game: GameState
var kit_opt: OptionButton
var inst_opt: OptionButton
var save_btn: Button
var roll_buttons: Array = []  # [step][semitone] -> Button
var roll_rows: Array = []  # row label panels
var _crash: Control
var _syncing := false
var step_buttons: Array = []  # [track][step] -> Button
var playhead: Array[ColorRect] = []
var play_button: Button
var bpm_box: SpinBox
var session: Session
var _sess_bar: PanelContainer
var _sess_name: Label
var _sess_brief: Label
var _sess_takes: Label
var _sess_last: Label
var _rec_btn: Button
var _fin_btn: Button


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
	root.add_child(_build_session_bar())

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
	var roll := _build_piano_roll()
	roll.name = "Piano Roll"
	tabs.add_child(roll)
	var mixer := _build_mixer()
	mixer.name = "Mixer"
	tabs.add_child(mixer)
	_build_crash_overlay()

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
	sub.text = "v0.5  //  bedroom edition"
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

	var reset_btn := _button("DEMO", PANEL_LIGHT)
	reset_btn.custom_minimum_size = Vector2(90, 44)
	reset_btn.pressed.connect(func():
		seq.load_default_pattern())
	bar.add_child(reset_btn)

	var kit_lbl := Label.new()
	kit_lbl.text = "KIT"
	kit_lbl.add_theme_color_override("font_color", TEXT_DIM)
	kit_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(kit_lbl)
	kit_opt = _option()
	kit_opt.item_selected.connect(func(i: int):
		if not _syncing:
			seq.set_kit(kit_opt.get_item_metadata(i)))
	bar.add_child(kit_opt)

	save_btn = _button("SAVE", Color("1f9e6e"))
	save_btn.custom_minimum_size = Vector2(110, 44)
	save_btn.pressed.connect(func():
		seq.save_snapshot()
		refresh_grid())
	bar.add_child(save_btn)

	bar.add_child(_spacer())

	var hint := Label.new()
	hint.text = "[SPACE] play   [CTRL+S] save   [ESC] leave"
	hint.add_theme_color_override("font_color", TEXT_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(hint)
	return bar


func _option() -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(120, 44)
	o.add_theme_stylebox_override("normal", _box(PANEL_LIGHT, 8))
	o.add_theme_stylebox_override("hover", _box(PANEL_LIGHT.lightened(0.1), 8))
	o.add_theme_stylebox_override("pressed", _box(PANEL_LIGHT.darkened(0.1), 8))
	o.add_theme_color_override("font_color", TEXT)
	return o


## Kits and instruments come from the shop.
func bind_game(gs: GameState) -> void:
	game = gs
	gs.changed.connect(refresh_options)
	refresh_options()


func refresh_options() -> void:
	_syncing = true
	var ups: Array = game.upgrades if game else []
	kit_opt.clear()
	for k in Shop.kits_owned(ups):
		kit_opt.add_item(k.capitalize())
		kit_opt.set_item_metadata(kit_opt.item_count - 1, k)
		if k == seq.kit_id:
			kit_opt.select(kit_opt.item_count - 1)
	inst_opt.clear()
	for k in Shop.instruments_owned(ups):
		inst_opt.add_item(k.capitalize())
		inst_opt.set_item_metadata(inst_opt.item_count - 1, k)
		if k == seq.instrument:
			inst_opt.select(inst_opt.item_count - 1)
	_syncing = false


# ---------- Session bar (rapper brief + record) ----------

func _build_session_bar() -> Control:
	_sess_bar = PanelContainer.new()
	_sess_bar.add_theme_stylebox_override("panel", _box(PANEL_LIGHT, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_sess_bar.add_child(row)
	var who := VBoxContainer.new()
	who.custom_minimum_size.x = 200
	_sess_name = Label.new()
	_sess_name.add_theme_font_size_override("font_size", 20)
	_sess_name.add_theme_color_override("font_color", TEXT)
	who.add_child(_sess_name)
	_sess_takes = Label.new()
	_sess_takes.add_theme_color_override("font_color", Color("ff3d7f"))
	who.add_child(_sess_takes)
	row.add_child(who)
	_sess_brief = Label.new()
	_sess_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sess_brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sess_brief.add_theme_color_override("font_color", TEXT_DIM)
	_sess_brief.add_theme_font_size_override("font_size", 15)
	row.add_child(_sess_brief)
	_sess_last = Label.new()
	_sess_last.add_theme_font_size_override("font_size", 22)
	_sess_last.add_theme_color_override("font_color", Color("f2c14e"))
	_sess_last.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_sess_last)
	_rec_btn = _button("●  RECORD TAKE", Color("ff3d7f"))
	_rec_btn.custom_minimum_size = Vector2(170, 46)
	_rec_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rec_btn.pressed.connect(func(): record_pressed.emit())
	row.add_child(_rec_btn)
	_fin_btn = _button("✓  FINISH", Color("1f9e6e"))
	_fin_btn.custom_minimum_size = Vector2(130, 46)
	_fin_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fin_btn.add_theme_stylebox_override("disabled", _box(Color("1f9e6e").darkened(0.6), 8))
	_fin_btn.pressed.connect(func(): finish_pressed.emit())
	row.add_child(_fin_btn)
	_sess_bar.visible = false
	return _sess_bar


func bind_session(s: Session) -> void:
	session = s
	s.state_changed.connect(func(_st): update_session())
	s.take_judged.connect(func(_r): update_session())
	update_session()


func update_session() -> void:
	if session == null:
		return
	var active := session.state in [Session.State.WAITING, Session.State.RECORDING, Session.State.REVIEW, Session.State.ARRIVING]
	_sess_bar.visible = active
	if not active:
		return
	var r := session.rapper
	_sess_name.text = "%s  ·  %s" % [r.name, r.style]
	_sess_takes.text = "patience  " + "♥".repeat(session.takes_left) + "♡".repeat(int(r.patience) - session.takes_left)
	_sess_brief.text = session.brief()
	_sess_last.text = UIKit.stars(int(session.best.stars)) if not session.best.is_empty() else ""
	var st := session.state
	_rec_btn.disabled = not (st == Session.State.WAITING or st == Session.State.REVIEW) or session.takes_left <= 0
	_rec_btn.text = "●  RECORDING..." if st == Session.State.RECORDING else ("●  RECORD TAKE" if session.takes_done == 0 else "●  RETAKE")
	_fin_btn.disabled = st != Session.State.REVIEW


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
	for s in roll_buttons.size():
		for n in Sequencer.NOTE_RANGE:
			roll_buttons[s][n].set_pressed_no_signal(seq.has_note(s, n))
	if bpm_box and absf(bpm_box.value - seq.bpm) > 0.1:
		bpm_box.set_value_no_signal(seq.bpm)
	if save_btn:
		save_btn.text = "SAVE  ●" if seq.dirty else "SAVED"


# ---------- Piano roll ----------

func _build_piano_roll() -> Control:
	var wrap := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		wrap.add_theme_constant_override("margin_" + side, 18)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	wrap.add_child(col)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = "INSTRUMENT"
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tools.add_child(l)
	inst_opt = _option()
	inst_opt.item_selected.connect(func(i: int):
		if not _syncing:
			seq.set_instrument(inst_opt.get_item_metadata(i))
			seq.preview_note(0))
	tools.add_child(inst_opt)
	var clr := _button("CLEAR MELODY", PANEL_LIGHT)
	clr.custom_minimum_size = Vector2(150, 40)
	clr.pressed.connect(func():
		for st in Sequencer.STEPS:
			for n in Sequencer.NOTE_RANGE:
				if seq.has_note(st, n):
					seq.set_note(st, n, false))
	tools.add_child(clr)
	var tip := Label.new()
	tip.text = "Highlighted rows = C minor (sad/dark). Click to place notes."
	tip.add_theme_color_override("font_color", TEXT_DIM)
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tools.add_child(tip)
	col.add_child(tools)

	for s in Sequencer.STEPS:
		var arr: Array = []
		arr.resize(Sequencer.NOTE_RANGE)
		roll_buttons.append(arr)
	var note_col := Color("b05cff")
	for n in range(Sequencer.NOTE_RANGE - 1, -1, -1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var in_scale := n in Sequencer.MINOR
		var black: bool = str(Sequencer.NOTE_NAMES[n]).ends_with("#")
		var name_btn := _button("%s%d" % [Sequencer.NOTE_NAMES[n], 5 if n == 12 else 4], Color("3a2f5c") if in_scale else (Color("14111f") if black else PANEL_LIGHT))
		name_btn.custom_minimum_size = Vector2(70, 30)
		name_btn.add_theme_font_size_override("font_size", 13)
		name_btn.pressed.connect(seq.preview_note.bind(n))
		row.add_child(name_btn)
		for s in Sequencer.STEPS:
			var b := Button.new()
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(46, 30)
			var off := Color("2b2346") if in_scale else (Color("15121f") if black else Color("1f1a30"))
			if (s / 4) % 2 == 1:
				off = off.darkened(0.15)
			b.add_theme_stylebox_override("normal", _box(off, 4))
			b.add_theme_stylebox_override("hover", _box(off.lightened(0.15), 4))
			b.add_theme_stylebox_override("pressed", _box(note_col, 4))
			b.add_theme_stylebox_override("hover_pressed", _box(note_col.lightened(0.2), 4))
			b.toggled.connect(func(on: bool):
				seq.set_note(s, n, on)
				if on and not seq.playing:
					seq.preview_note(n))
			row.add_child(b)
			roll_buttons[s][n] = b
			if s % 4 == 3 and s < Sequencer.STEPS - 1:
				row.add_child(_gap())
		col.add_child(row)
	return wrap


# ---------- PC crash ----------

func _build_crash_overlay() -> void:
	_crash = PanelContainer.new()
	_crash.add_theme_stylebox_override("panel", _box(Color("1f3fbf"), 0))
	_crash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var c := CenterContainer.new()
	_crash.add_child(c)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	c.add_child(col)
	for line in [[":(", 120], ["LOOPR.exe has stopped responding", 34], ["Your unsaved changes are gone. Your laptop is older than you.", 20], ["Tip: press SAVE (or Ctrl+S) every now and then.", 20]]:
		var lb := Label.new()
		lb.text = line[0]
		lb.add_theme_font_size_override("font_size", line[1])
		lb.add_theme_color_override("font_color", Color.WHITE)
		col.add_child(lb)
	var ok := _button("REBOOT", Color("15309a"))
	ok.custom_minimum_size = Vector2(180, 48)
	ok.pressed.connect(func(): _crash.visible = false)
	col.add_child(ok)
	_crash.visible = false
	add_child(_crash)


func show_crash() -> void:
	_crash.visible = true


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
	row.add_child(_channel_strip("Keys", AudioServer.get_bus_index("Keys"), Color("e879f9")))
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
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_stylebox_override("disabled", _box(color.darkened(0.6), 8))
	return b


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _gap() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(10, 0)
	return c
