class_name LooprUI
extends Control
## LOOPR: the in-game DAW.
## Channel Rack (paint, velocity, rolls) · Piano Roll (melody + 808 lane) · Playlist · Mixer.

signal close_requested
signal record_pressed
signal finish_pressed

const VERSION := "v0.6"
const BG := Color("120f1c")
const PANEL := Color("1c1730")
const PANEL_LIGHT := Color("2a2347")
const STEP_OFF_A := Color("2b2540")
const STEP_OFF_B := Color("221d35")
const ACCENT := Color("a855f7")
const TEXT := Color("e9e4ff")
const TEXT_DIM := Color("8f86b3")
const OK := Color("22c55e")
const WARN := Color("facc15")
const BAD := Color("ef4444")
const TRACK_COLORS: Array[Color] = [
	Color("f43f5e"), Color("f59e0b"), Color("22d3ee"), Color("a3e635"), Color("a855f7"),
]
const KEYS_COLOR := Color("e879f9")
const NOTE_COLOR := Color("b05cff")
const PAT_COLORS: Array[Color] = [Color("a855f7"), Color("22d3ee"), Color("f59e0b"), Color("f43f5e")]
const TOOL_TIPS := {
	"draw": "Click or drag to paint hits. Right-click (or drag) erases. Click a track name to hear it.",
	"vel": "VELOCITY: click or drag inside a step to set how hard it hits. Low = ghost note.",
	"roll": "ROLL: click a step to cycle 1–4 hits inside it (hi-hat rolls). Right-click resets.",
}

var seq: Sequencer
var game: GameState
var session: Session

var rack: LooprGrid
var roll: LooprGrid
var playlist: LooprGrid
var tool := "draw"
var lane := "melody"  # piano roll lane: "melody" | "808"

var kit_opt: OptionButton
var inst_opt: OptionButton
var save_btn: Button
var play_button: Button
var mode_btn: Button
var undo_btn: Button
var bpm_box: SpinBox
var swing_slider: HSlider
var swing_label: Label
var glide_btn: Button
var peak_label: Label
var song_label: Label
var tool_tip: Label
var tabs: TabContainer
var _pat_btns: Array[Button] = []
var _tool_btns := {}
var _lane_btns := {}
var _strips: Array = []  # [{bus, meter, key, fader, pan, verb, locut, mute, solo, db}]
var _crash: Control
var _syncing := false
var _paint_on := true
var _paint_roll := 2
var _sync_t := 0.0

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
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_session_bar())
	root.add_child(_build_pattern_bar())

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", _box(PANEL, 10))
	tabs.add_theme_color_override("font_selected_color", TEXT)
	tabs.add_theme_color_override("font_unselected_color", TEXT_DIM)
	tabs.add_theme_font_size_override("font_size", 18)
	root.add_child(tabs)

	var rack_page := _build_channel_rack()
	rack_page.name = "Channel Rack"
	tabs.add_child(rack_page)
	var roll_page := _build_piano_roll()
	roll_page.name = "Piano Roll"
	tabs.add_child(roll_page)
	var pl_page := _build_playlist()
	pl_page.name = "Playlist"
	tabs.add_child(pl_page)
	var mixer := _build_mixer()
	mixer.name = "Mixer"
	tabs.add_child(mixer)
	_build_crash_overlay()

	seq.step_changed.connect(_on_step_changed)
	seq.play_state_changed.connect(_on_play_state_changed)
	seq.pattern_changed.connect(refresh_grid)
	seq.pattern_selected.connect(func(_i): refresh_grid())
	refresh_grid()


# ---------- Top bar ----------

func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)

	var logo := Label.new()
	logo.text = "LOOPR"
	logo.add_theme_font_size_override("font_size", 34)
	logo.add_theme_color_override("font_color", ACCENT)
	bar.add_child(logo)
	var sub := _dim(VERSION)
	bar.add_child(sub)
	bar.add_child(_gap(8))

	play_button = _button("PLAY", ACCENT)
	play_button.custom_minimum_size = Vector2(100, 44)
	play_button.pressed.connect(func(): seq.toggle_play())
	bar.add_child(play_button)

	mode_btn = _button("PAT", PANEL_LIGHT)
	mode_btn.custom_minimum_size = Vector2(90, 44)
	mode_btn.tooltip_text = "PAT loops the pattern you edit. SONG plays the Playlist."
	mode_btn.pressed.connect(func():
		seq.set_song_mode(not seq.song_mode)
		refresh_grid())
	bar.add_child(mode_btn)

	bar.add_child(_dim("BPM"))
	bpm_box = SpinBox.new()
	bpm_box.min_value = 60
	bpm_box.max_value = 200
	bpm_box.value = seq.bpm
	bpm_box.custom_minimum_size = Vector2(100, 44)
	bpm_box.value_changed.connect(func(v: float):
		if not _syncing:
			seq.bpm = v)
	bar.add_child(bpm_box)

	bar.add_child(_dim("SWING"))
	swing_slider = HSlider.new()
	swing_slider.min_value = 0.0
	swing_slider.max_value = 0.6
	swing_slider.step = 0.01
	swing_slider.custom_minimum_size = Vector2(140, 44)
	swing_slider.focus_mode = Control.FOCUS_NONE
	swing_slider.value_changed.connect(func(v: float):
		swing_label.text = "%d%%" % int(round(v * 100))
		if not _syncing:
			seq.set_swing(v))
	bar.add_child(swing_slider)
	swing_label = _dim("0%")
	swing_label.custom_minimum_size.x = 40
	bar.add_child(swing_label)

	undo_btn = _button("UNDO", PANEL_LIGHT)
	undo_btn.custom_minimum_size = Vector2(80, 44)
	undo_btn.pressed.connect(func(): seq.undo())
	bar.add_child(undo_btn)

	save_btn = _button("SAVE", Color("1f9e6e"))
	save_btn.custom_minimum_size = Vector2(100, 44)
	save_btn.pressed.connect(func():
		seq.save_snapshot()
		refresh_grid())
	bar.add_child(save_btn)

	bar.add_child(_spacer())
	var hint := _dim("[SPACE] play  [1-4] pattern  [CTRL+Z] undo  [CTRL+S] save  [ESC] leave")
	hint.add_theme_font_size_override("font_size", 13)
	bar.add_child(hint)
	return bar


# ---------- Pattern bar ----------

func _build_pattern_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.add_child(_dim("PATTERN"))
	for i in Sequencer.PATTERNS:
		var b := _button(Sequencer.PATTERN_NAMES[i], PANEL_LIGHT)
		b.custom_minimum_size = Vector2(52, 38)
		b.add_theme_color_override("font_color", PAT_COLORS[i])
		b.pressed.connect(seq.select_pattern.bind(i))
		bar.add_child(b)
		_pat_btns.append(b)
	var clone := _button("CLONE →", PANEL_LIGHT)
	clone.custom_minimum_size = Vector2(100, 38)
	clone.tooltip_text = "Copy this pattern into the next slot to build a variation."
	clone.pressed.connect(func(): seq.clone_to_next())
	bar.add_child(clone)
	bar.add_child(_gap(10))
	var clear_btn := _button("CLEAR", PANEL_LIGHT)
	clear_btn.custom_minimum_size = Vector2(80, 38)
	clear_btn.pressed.connect(func(): seq.clear())
	bar.add_child(clear_btn)
	var demo := _button("DEMO", PANEL_LIGHT)
	demo.custom_minimum_size = Vector2(80, 38)
	demo.pressed.connect(func(): seq.load_default_pattern())
	bar.add_child(demo)
	bar.add_child(_spacer())
	peak_label = Label.new()
	peak_label.add_theme_font_size_override("font_size", 16)
	peak_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(peak_label)
	return bar


# ---------- Options (kits / instruments from the shop) ----------

func _option() -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(120, 38)
	o.add_theme_stylebox_override("normal", _box(PANEL_LIGHT, 8))
	o.add_theme_stylebox_override("hover", _box(PANEL_LIGHT.lightened(0.1), 8))
	o.add_theme_stylebox_override("pressed", _box(PANEL_LIGHT.darkened(0.1), 8))
	o.add_theme_color_override("font_color", TEXT)
	return o


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
	_sess_brief.add_theme_font_size_override("font_size", 14)
	row.add_child(_sess_brief)
	_sess_last = Label.new()
	_sess_last.add_theme_font_size_override("font_size", 22)
	_sess_last.add_theme_color_override("font_color", Color("f2c14e"))
	_sess_last.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_sess_last)
	_rec_btn = _button("●  RECORD TAKE", Color("ff3d7f"))
	_rec_btn.custom_minimum_size = Vector2(170, 46)
	_rec_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rec_btn.tooltip_text = "The rapper records over the pattern you're on."
	_rec_btn.pressed.connect(func(): record_pressed.emit())
	row.add_child(_rec_btn)
	_fin_btn = _button("✓  FINISH", Color("1f9e6e"))
	_fin_btn.custom_minimum_size = Vector2(130, 46)
	_fin_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fin_btn.add_theme_stylebox_override("disabled", _box(Color("1f9e6e").darkened(0.6), 8))
	_fin_btn.tooltip_text = "Release the best take. Arrange it in the Playlist first for more streams."
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
	var wrap := _page_margin(20)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	wrap.add_child(col)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.add_child(_dim("TOOL"))
	for t in [["draw", "✎ DRAW"], ["vel", "▮ VELOCITY"], ["roll", "≡ ROLL"]]:
		var b := _button(t[1], PANEL_LIGHT)
		b.custom_minimum_size = Vector2(120, 38)
		b.pressed.connect(set_tool.bind(t[0]))
		tools.add_child(b)
		_tool_btns[t[0]] = b
	tools.add_child(_gap(16))
	tools.add_child(_dim("KIT"))
	kit_opt = _option()
	kit_opt.item_selected.connect(func(i: int):
		if not _syncing:
			seq.set_kit(kit_opt.get_item_metadata(i)))
	tools.add_child(kit_opt)
	col.add_child(tools)

	rack = LooprGrid.new()
	rack.label_w = 150
	rack.configure(Sequencer.TRACKS.size(), Sequencer.STEPS, Vector2(72, 74))
	rack.row_info = func(r: int) -> Dictionary:
		return {"name": Sequencer.TRACKS[r], "color": TRACK_COLORS[r], "base": PANEL_LIGHT}
	rack.cell_info = _rack_cell
	rack.header_text = func(c: int) -> String: return str(c + 1) if c % 4 == 0 else ""
	rack.stroke_started.connect(func(_r, _c, _b): seq.checkpoint())
	rack.cell_pressed.connect(_on_rack_pressed)
	rack.cell_dragged.connect(_on_rack_dragged)
	rack.label_pressed.connect(func(r: int): seq.preview(r))
	col.add_child(rack)

	tool_tip = _dim(TOOL_TIPS.draw)
	col.add_child(tool_tip)
	set_tool("draw")
	return wrap


func set_tool(t: String) -> void:
	tool = t
	for k in _tool_btns.keys():
		var b: Button = _tool_btns[k]
		b.add_theme_stylebox_override("normal", _box(ACCENT if k == t else PANEL_LIGHT, 8))
	if tool_tip:
		tool_tip.text = TOOL_TIPS[t]
	if rack:
		rack.queue_redraw()


func _rack_cell(r: int, c: int) -> Dictionary:
	var on: bool = seq.pattern[r][c]
	var vel: float = seq.velocity[r][c]
	var rl: int = seq.rolls[r][c]
	var show_vel := tool == "vel" or absf(vel - Sequencer.DEFAULT_VEL) > 0.01
	return {
		"on": on,
		"color": TRACK_COLORS[r],
		"base": STEP_OFF_A if (c / 4) % 2 == 0 else STEP_OFF_B,
		"fill": vel if show_vel else 1.0,
		"text": ("×%d" % rl) if on and rl > 1 else "",
	}


func _on_rack_pressed(r: int, c: int, button: int, frac: Vector2) -> void:
	match tool:
		"draw":
			if button == MOUSE_BUTTON_LEFT:
				_paint_on = not seq.pattern[r][c]
			else:
				_paint_on = false
			seq.set_step(r, c, _paint_on)
			if _paint_on and not seq.playing:
				seq.preview(r)
		"vel":
			if button == MOUSE_BUTTON_LEFT:
				seq.set_velocity(r, c, 1.0 - frac.y)
			elif seq.pattern[r][c]:
				seq.set_velocity(r, c, Sequencer.DEFAULT_VEL)
		"roll":
			if button == MOUSE_BUTTON_LEFT:
				_paint_roll = seq.cycle_roll(r, c)
			else:
				_paint_roll = 1
				if seq.pattern[r][c]:
					seq.set_roll(r, c, 1)


func _on_rack_dragged(r: int, c: int, _button: int, frac: Vector2) -> void:
	match tool:
		"draw":
			if rack.is_new_cell(r, c) and seq.pattern[r][c] != _paint_on:
				seq.set_step(r, c, _paint_on)
		"vel":
			if seq.pattern[r][c] or rack.is_new_cell(r, c):
				seq.set_velocity(r, c, 1.0 - frac.y)
		"roll":
			if rack.is_new_cell(r, c) and (seq.pattern[r][c] or _paint_roll > 1):
				seq.set_roll(r, c, _paint_roll)


# ---------- Piano roll ----------

func _build_piano_roll() -> Control:
	var wrap := _page_margin(16)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	wrap.add_child(col)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.add_child(_dim("LANE"))
	for l in [["melody", "MELODY"], ["808", "808"]]:
		var b := _button(l[1], PANEL_LIGHT)
		b.custom_minimum_size = Vector2(100, 38)
		b.pressed.connect(set_lane.bind(l[0]))
		tools.add_child(b)
		_lane_btns[l[0]] = b
	tools.add_child(_gap(12))
	tools.add_child(_dim("INSTRUMENT"))
	inst_opt = _option()
	inst_opt.item_selected.connect(func(i: int):
		if not _syncing:
			seq.set_instrument(inst_opt.get_item_metadata(i))
			seq.preview_note(0))
	tools.add_child(inst_opt)
	glide_btn = _button("808 GLIDE: OFF", PANEL_LIGHT)
	glide_btn.custom_minimum_size = Vector2(160, 38)
	glide_btn.tooltip_text = "Slide the 808 from one note to the next (drill / rage)."
	glide_btn.pressed.connect(func():
		seq.checkpoint()
		seq.set_glide(not seq.glide))
	tools.add_child(glide_btn)
	var clr := _button("CLEAR LANE", PANEL_LIGHT)
	clr.custom_minimum_size = Vector2(120, 38)
	clr.pressed.connect(_clear_lane)
	tools.add_child(clr)
	tools.add_child(_gap(8))
	var tip := _dim("Highlighted rows = C minor (sad / dark). Drag to paint, right-click erases.")
	tip.add_theme_font_size_override("font_size", 13)
	tools.add_child(tip)
	col.add_child(tools)

	roll = LooprGrid.new()
	roll.label_w = 80
	roll.header_h = 16
	roll.radius = 4
	roll.gap = 2
	roll.configure(Sequencer.NOTE_RANGE, Sequencer.STEPS, Vector2(76, 38))
	roll.row_info = _roll_row
	roll.cell_info = _roll_cell
	roll.header_text = func(c: int) -> String: return str(c + 1) if c % 4 == 0 else ""
	roll.stroke_started.connect(func(_r, _c, _b): seq.checkpoint())
	roll.cell_pressed.connect(_on_roll_pressed)
	roll.cell_dragged.connect(_on_roll_dragged)
	roll.label_pressed.connect(func(r: int): _preview_lane(Sequencer.NOTE_RANGE - 1 - r))
	col.add_child(roll)
	set_lane("melody")
	return wrap


func set_lane(l: String) -> void:
	lane = l
	for k in _lane_btns.keys():
		var b: Button = _lane_btns[k]
		b.add_theme_stylebox_override("normal", _box(ACCENT if k == l else PANEL_LIGHT, 8))
	inst_opt.disabled = l != "melody"
	glide_btn.disabled = l != "808"
	if roll:
		roll.queue_redraw()


func _roll_row(r: int) -> Dictionary:
	var n := Sequencer.NOTE_RANGE - 1 - r
	var in_scale: bool = n in Sequencer.MINOR
	var black: bool = str(Sequencer.NOTE_NAMES[n]).ends_with("#")
	var octave := (5 if n == 12 else 4) if lane == "melody" else (2 if n == 12 else 1)
	return {
		"name": "%s%d" % [Sequencer.NOTE_NAMES[n], octave],
		"color": TEXT,
		"base": Color("3a2f5c") if in_scale else (Color("14111f") if black else PANEL_LIGHT),
	}


func _roll_cell(r: int, c: int) -> Dictionary:
	var n := Sequencer.NOTE_RANGE - 1 - r
	var in_scale: bool = n in Sequencer.MINOR
	var black: bool = str(Sequencer.NOTE_NAMES[n]).ends_with("#")
	var base := Color("2b2346") if in_scale else (Color("15121f") if black else Color("1f1a30"))
	if (c / 4) % 2 == 1:
		base = base.darkened(0.15)
	var on := seq.has_note(c, n) if lane == "melody" else seq.has_bass(c, n)
	var ghost := lane == "808" and seq.has_note(c, n)  # melody shown faintly behind the 808 lane
	return {
		"on": on or ghost,
		"color": (NOTE_COLOR if lane == "melody" else TRACK_COLORS[Sequencer.BASS]) if on else Color(NOTE_COLOR, 0.25),
		"base": base,
	}


func _preview_lane(n: int) -> void:
	if lane == "melody":
		seq.preview_note(n)
	else:
		seq.preview_bass(n)


func _on_roll_pressed(r: int, c: int, button: int, _frac: Vector2) -> void:
	var n := Sequencer.NOTE_RANGE - 1 - r
	if lane == "melody":
		_paint_on = button == MOUSE_BUTTON_LEFT and not seq.has_note(c, n)
		seq.set_note(c, n, _paint_on)
	else:
		_paint_on = button == MOUSE_BUTTON_LEFT and not seq.has_bass(c, n)
		if _paint_on or seq.has_bass(c, n):
			seq.set_bass(c, n, _paint_on)
	if _paint_on and not seq.playing:
		_preview_lane(n)


func _on_roll_dragged(r: int, c: int, _button: int, _frac: Vector2) -> void:
	if not roll.is_new_cell(r, c):
		return
	var n := Sequencer.NOTE_RANGE - 1 - r
	if lane == "melody":
		if seq.has_note(c, n) != _paint_on:
			seq.set_note(c, n, _paint_on)
			if _paint_on and not seq.playing:
				seq.preview_note(n)
	else:
		if _paint_on and not seq.has_bass(c, n):
			seq.set_bass(c, n, true)
		elif not _paint_on and seq.has_bass(c, n):
			seq.set_bass(c, n, false)


func _clear_lane() -> void:
	seq.checkpoint()
	for st in Sequencer.STEPS:
		if lane == "melody":
			for n in Sequencer.NOTE_RANGE:
				if seq.has_note(st, n):
					seq.set_note(st, n, false)
		elif seq.pattern[Sequencer.BASS][st]:
			seq.set_bass(st, seq.bass[st], false)


# ---------- Playlist ----------

func _build_playlist() -> Control:
	var wrap := _page_margin(20)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	wrap.add_child(col)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	var song_btn := _button("▶ PLAY SONG", ACCENT)
	song_btn.custom_minimum_size = Vector2(140, 38)
	song_btn.pressed.connect(func():
		seq.set_song_mode(true)
		if not seq.playing:
			seq.play()
		refresh_grid())
	tools.add_child(song_btn)
	var clr := _button("CLEAR SONG", PANEL_LIGHT)
	clr.custom_minimum_size = Vector2(130, 38)
	clr.pressed.connect(func():
		seq.checkpoint()
		for b in Sequencer.BARS:
			seq.set_bar(b, -1))
	tools.add_child(clr)
	tools.add_child(_gap(10))
	song_label = Label.new()
	song_label.add_theme_font_size_override("font_size", 16)
	song_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tools.add_child(song_label)
	col.add_child(tools)

	playlist = LooprGrid.new()
	playlist.label_w = 150
	playlist.header_h = 24
	playlist.radius = 8
	playlist.gap = 6
	playlist.configure(Sequencer.PATTERNS, Sequencer.BARS, Vector2(160, 104))
	playlist.row_info = func(r: int) -> Dictionary:
		var empty := seq.pattern_is_empty(r)
		var nm: String = ("%s  · empty" if empty else "Pattern %s") % Sequencer.PATTERN_NAMES[r]
		return {"name": nm, "color": PAT_COLORS[r], "base": PANEL_LIGHT if r != seq.current_pattern else PANEL_LIGHT.lightened(0.12)}
	playlist.cell_info = func(r: int, c: int) -> Dictionary:
		return {"on": seq.playlist[c] == r, "color": PAT_COLORS[r].darkened(0.25), "base": STEP_OFF_A if (c / 4) % 2 == 0 else STEP_OFF_B}
	playlist.header_text = func(c: int) -> String: return "BAR %d" % (c + 1)
	playlist.extra_draw = _draw_mini_pattern
	playlist.stroke_started.connect(func(_r, _c, _b): seq.checkpoint())
	playlist.cell_pressed.connect(_on_playlist_pressed)
	playlist.cell_dragged.connect(_on_playlist_dragged)
	playlist.label_pressed.connect(func(r: int): seq.select_pattern(r))
	col.add_child(playlist)

	var tip := _dim("Paint patterns into bars. Click a pattern name to edit it. Takes are always recorded over the pattern you're on; the Playlist decides what you release.")
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 1200
	col.add_child(tip)
	return wrap


func _draw_mini_pattern(g: LooprGrid, rect: Rect2, r: int, c: int) -> void:
	var on: bool = seq.playlist[c] == r
	var d: Dictionary = seq.patterns[r]
	var inner := rect.grow(-8)
	var dw := inner.size.x / Sequencer.STEPS
	var dh := inner.size.y / Sequencer.TRACKS.size()
	for t in Sequencer.TRACKS.size():
		for s in Sequencer.STEPS:
			if d.pattern[t][s]:
				var dot := Rect2(inner.position + Vector2(s * dw, t * dh), Vector2(dw - 1, dh - 2))
				var colr := TRACK_COLORS[t] if on else Color(TRACK_COLORS[t], 0.18)
				g.draw_rect(dot, colr)


func _on_playlist_pressed(r: int, c: int, button: int, _frac: Vector2) -> void:
	_paint_on = button == MOUSE_BUTTON_LEFT and seq.playlist[c] != r
	seq.set_bar(c, r if _paint_on else -1)


func _on_playlist_dragged(r: int, c: int, _button: int, _frac: Vector2) -> void:
	if not playlist.is_new_cell(r, c):
		return
	if _paint_on and seq.playlist[c] != r:
		seq.set_bar(c, r)
	elif not _paint_on and seq.playlist[c] == r:
		seq.set_bar(c, -1)


# ---------- Mixer ----------

func _build_mixer() -> Control:
	var wrap := _page_margin(18)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	wrap.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	for t in Sequencer.TRACKS.size():
		row.add_child(_channel_strip(Sequencer.TRACKS[t], seq.bus_index(t), TRACK_COLORS[t], Sequencer.TRACKS[t]))
	row.add_child(_channel_strip("Keys", AudioServer.get_bus_index("Keys"), KEYS_COLOR, "Keys"))
	row.add_child(_channel_strip("MASTER", 0, ACCENT, ""))
	var tip := _dim("Meter in the red = clipping. Rappers hear it. REVERB = space, LO-CUT = less mud on hats/keys, PAN = left/right.")
	tip.add_theme_font_size_override("font_size", 13)
	col.add_child(tip)
	return wrap


func _channel_strip(title: String, bus_idx: int, color: Color, level_key: String) -> Control:
	var is_master := level_key == ""
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL_LIGHT, 10))
	panel.custom_minimum_size = Vector2(176 if is_master else 158, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var name := Label.new()
	name.text = title
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_color_override("font_color", color)
	name.add_theme_font_size_override("font_size", 17)
	col.add_child(name)

	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 10)
	col.add_child(mid)
	var meter := LooprMeter.new()
	meter.custom_minimum_size = Vector2(22 if is_master else 16, 360)
	mid.add_child(meter)
	var fader := VSlider.new()
	fader.min_value = 0.0
	fader.max_value = 1.25
	fader.step = 0.01
	fader.value = seq.get_volume(bus_idx)
	fader.custom_minimum_size = Vector2(36, 360)
	fader.focus_mode = Control.FOCUS_NONE
	mid.add_child(fader)

	var db_label := _dim(_db_text(fader.value))
	db_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(db_label)
	fader.value_changed.connect(func(v: float):
		db_label.text = _db_text(v)
		if not _syncing:
			seq.set_volume(bus_idx, v))

	var strip := {"bus": bus_idx, "meter": meter, "key": level_key, "fader": fader, "db": db_label}
	if not is_master:
		var pan_l := _dim("PAN  C")
		pan_l.add_theme_font_size_override("font_size", 12)
		col.add_child(pan_l)
		var pan := HSlider.new()
		pan.min_value = -1.0
		pan.max_value = 1.0
		pan.step = 0.05
		pan.focus_mode = Control.FOCUS_NONE
		pan.value_changed.connect(func(v: float):
			pan_l.text = "PAN  " + ("C" if absf(v) < 0.03 else ("L%d" % int(-v * 100) if v < 0 else "R%d" % int(v * 100)))
			if not _syncing:
				seq.set_pan(bus_idx, v))
		col.add_child(pan)
		var verb_l := _dim("REVERB  0%")
		verb_l.add_theme_font_size_override("font_size", 12)
		col.add_child(verb_l)
		var verb := HSlider.new()
		verb.min_value = 0.0
		verb.max_value = 0.6
		verb.step = 0.01
		verb.focus_mode = Control.FOCUS_NONE
		verb.value_changed.connect(func(v: float):
			verb_l.text = "REVERB  %d%%" % int(round(v * 100))
			if not _syncing:
				seq.set_reverb(bus_idx, v))
		col.add_child(verb)
		var locut := _button("LO-CUT", BG)
		locut.toggle_mode = true
		locut.add_theme_stylebox_override("pressed", _box(Color("0ea5e9"), 6))
		locut.toggled.connect(func(on: bool):
			if not _syncing:
				seq.set_locut(bus_idx, on))
		col.add_child(locut)
		strip.merge({"pan": pan, "verb": verb, "locut": locut})
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	col.add_child(btns)
	var mute := _button("MUTE", BG)
	mute.toggle_mode = true
	mute.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute.add_theme_stylebox_override("pressed", _box(BAD, 6))
	mute.toggled.connect(func(on: bool):
		if not _syncing:
			seq.set_mute(bus_idx, on))
	btns.add_child(mute)
	strip["mute"] = mute
	if not is_master:
		var solo := _button("SOLO", BG)
		solo.toggle_mode = true
		solo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		solo.add_theme_stylebox_override("pressed", _box(WARN.darkened(0.2), 6))
		solo.toggled.connect(func(on: bool):
			if not _syncing:
				seq.set_solo(bus_idx, on))
		btns.add_child(solo)
		strip["solo"] = solo
	_strips.append(strip)
	return panel


func _db_text(linear: float) -> String:
	if linear <= 0.001:
		return "-inf dB"
	return "%+.1f dB" % linear_to_db(linear)


## Keep every control in step with the sequencer (the room monitor mirrors this UI).
func _sync_mixer() -> void:
	_syncing = true
	for s in _strips:
		var b: int = s.bus
		s.fader.set_value_no_signal(seq.get_volume(b))
		s.db.text = _db_text(s.fader.value)
		s.mute.set_pressed_no_signal(seq.is_muted(b))
		if s.has("pan"):
			s.pan.value = seq.get_pan(b)
			s.verb.value = seq.get_reverb(b)
			s.locut.set_pressed_no_signal(seq.get_locut(b))
			s.solo.set_pressed_no_signal(seq.is_solo(b))
	if absf(swing_slider.value - seq.swing) > 0.001:
		swing_slider.value = seq.swing
	if bpm_box and absf(bpm_box.value - seq.bpm) > 0.1:
		bpm_box.set_value_no_signal(seq.bpm)
	_syncing = false
	_update_peak()


func _update_peak() -> void:
	var db := seq.peak_db()
	if db > 0.0:
		peak_label.text = "CLIPPING  +%.1f dB" % db
		peak_label.add_theme_color_override("font_color", BAD)
	elif db > -3.0:
		peak_label.text = "PEAK  %.1f dB  (hot)" % db
		peak_label.add_theme_color_override("font_color", WARN)
	else:
		peak_label.text = "PEAK  %.1f dB" % db if db > -79.0 else "PEAK  -inf"
		peak_label.add_theme_color_override("font_color", OK)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	for s in _strips:
		if s.key == "":
			s.meter.push(seq.master_level, seq.clip_timer > 0.0, delta)
		else:
			s.meter.push(seq.levels.get(s.key, 0.0), false, delta)
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.2
		_sync_mixer()


# ---------- Refresh ----------

func refresh_grid() -> void:
	if rack == null:
		return
	rack.queue_redraw()
	roll.queue_redraw()
	playlist.queue_redraw()
	for i in _pat_btns.size():
		var b := _pat_btns[i]
		var sel := i == seq.current_pattern
		b.add_theme_stylebox_override("normal", _box(PAT_COLORS[i].darkened(0.35) if sel else PANEL_LIGHT, 8))
		b.add_theme_color_override("font_color", TEXT if sel else PAT_COLORS[i])
	mode_btn.text = "SONG" if seq.song_mode else "PAT"
	mode_btn.add_theme_stylebox_override("normal", _box(Color("0e7490") if seq.song_mode else PANEL_LIGHT, 8))
	glide_btn.text = "808 GLIDE: ON" if seq.glide else "808 GLIDE: OFF"
	glide_btn.add_theme_stylebox_override("normal", _box(TRACK_COLORS[Sequencer.BASS].darkened(0.3) if seq.glide else PANEL_LIGHT, 8))
	undo_btn.disabled = not seq.can_undo()
	var a := seq.arrangement()
	if a.song:
		song_label.text = "%d bars · %d patterns  →  FULL SONG (×1.5 streams)" % [a.bars, a.patterns]
		song_label.add_theme_color_override("font_color", OK)
	else:
		song_label.text = "%d bars · %d patterns  →  needs 4+ bars and 2+ patterns for a full song" % [a.bars, a.patterns]
		song_label.add_theme_color_override("font_color", TEXT_DIM)
	if save_btn:
		save_btn.text = "SAVE  ●" if seq.dirty else "SAVED"
	_sync_mixer()


func _on_step_changed(step: int) -> void:
	var here := step >= 0 and seq.playing_pattern() == seq.current_pattern
	rack.set_playhead(step if here else -1)
	roll.set_playhead(step if here else -1)
	playlist.set_playhead(seq.play_bar if seq.playing and seq.song_mode and seq.song_length() > 0 else -1)


func _on_play_state_changed(is_playing: bool) -> void:
	play_button.text = "STOP" if is_playing else "PLAY"


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


# ---------- Helpers ----------

func _page_margin(m: int) -> MarginContainer:
	var wrap := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		wrap.add_theme_constant_override("margin_" + side, m)
	return wrap


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


func _dim(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", TEXT_DIM)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _gap(w: int = 10) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	return c
