class_name PhoneUI
extends Control
## The player's phone: DMs (book sessions), Shop (upgrades), Tracks (streams), hint mode.

signal book_requested(rapper: Dictionary)
signal buy_requested(item_id: String)
signal hints_toggled(easy: bool)

var _list: VBoxContainer
var _stats: Label
var _title: Label
var _hint_btn: Button
var _tab_btns := {}
var _easy := true
var tab := "dms"
var _gs: GameState
var _session: Session


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var phone := PanelContainer.new()
	phone.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, 34, Color("3a2f5c"), 3, 18))
	phone.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	phone.offset_left = -510
	phone.offset_right = -70
	phone.offset_top = -400
	phone.offset_bottom = 400
	add_child(phone)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	phone.add_child(col)

	var status := HBoxContainer.new()
	status.add_child(UIKit.label("STUDIO GRIND OS", 13, UIKit.DIM))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(sp)
	status.add_child(UIKit.label("▮▮▮  12%", 13, UIKit.POP))
	col.add_child(status)

	_title = UIKit.label("Messages", 30, UIKit.TEXT)
	col.add_child(_title)
	_stats = UIKit.label("", 14, UIKit.CYAN)
	col.add_child(_stats)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for t in [["dms", "DMs"], ["shop", "Shop"], ["tracks", "Tracks"]]:
		var b := UIKit.button(t[1], UIKit.PANEL_LIGHT, 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			tab = t[0]
			_render())
		tabs.add_child(b)
		_tab_btns[t[0]] = b
	col.add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var foot := HBoxContainer.new()
	_hint_btn = UIKit.button("", UIKit.PANEL_LIGHT, 14)
	_hint_btn.pressed.connect(func():
		_easy = not _easy
		_update_hint_btn()
		hints_toggled.emit(_easy))
	foot.add_child(_hint_btn)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp2)
	foot.add_child(UIKit.label("[TAB] close", 14, UIKit.DIM))
	col.add_child(foot)
	_update_hint_btn()


func _update_hint_btn() -> void:
	_hint_btn.text = "Hints: EASY" if _easy else "Hints: PRO"


func refresh(gs: GameState, session: Session) -> void:
	_gs = gs
	_session = session
	_render()


func _render() -> void:
	if _gs == null:
		return
	_stats.text = "Day %d  ·  %s  ·  €%d  ·  REP %d  ·  CRED %d" % [_gs.day, _gs.clock_text(), _gs.money, _gs.reputation, _gs.street_cred]
	for k in _tab_btns.keys():
		var b: Button = _tab_btns[k]
		b.add_theme_stylebox_override("normal", UIKit.box(UIKit.ACCENT if k == tab else UIKit.PANEL_LIGHT, 10, Color(), 0, 14))
	for c in _list.get_children():
		c.queue_free()
	match tab:
		"dms":
			_title.text = "Messages"
			for r in Rappers.all():
				_list.add_child(_dm_card(r))
		"shop":
			_title.text = "Studio Shop"
			for it in Shop.ITEMS:
				_list.add_child(_shop_card(it))
		"tracks":
			_title.text = "Your Tracks"
			_list.add_child(UIKit.label("%d total streams" % _gs.total_streams, 18, UIKit.GOLD))
			if _gs.tracks.is_empty():
				_list.add_child(UIKit.wrap_label("Nothing released yet. Book a rapper in DMs and finish a session.", 15, UIKit.DIM, 360))
			for i in range(_gs.tracks.size() - 1, -1, -1):
				_list.add_child(_track_card(_gs.tracks[i]))


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL, 16, Color(), 0, 14))
	return card


func _spacer() -> Control:
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sp


func _dm_card(r: Dictionary) -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var avatar := PanelContainer.new()
	avatar.add_theme_stylebox_override("panel", UIKit.box(r.accent, 26, Color(), 0, 0))
	avatar.custom_minimum_size = Vector2(52, 52)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var initial := UIKit.label(r.name.substr(0, 1), 24, UIKit.BG)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(initial)
	row.add_child(avatar)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	row.add_child(body)
	var head := HBoxContainer.new()
	head.add_child(UIKit.label(r.name, 18, UIKit.TEXT))
	head.add_child(_spacer())
	head.add_child(UIKit.label(r.style, 13, r.accent))
	body.add_child(head)
	body.add_child(UIKit.wrap_label(r.dm, 14, UIKit.DIM, 270))

	var actions := HBoxContainer.new()
	actions.add_child(UIKit.label("pays ~€%d" % r.pay, 14, UIKit.GOLD))
	actions.add_child(_spacer())
	if not _session.unlocked(r):
		var need := []
		if int(r.get("min_cred", 0)) > 0:
			need.append("%d cred" % r.min_cred)
		if int(r.get("min_rep", 0)) > 0:
			need.append("%d rep" % r.min_rep)
		actions.add_child(UIKit.label("LOCKED · needs " + " + ".join(need), 14, UIKit.POP))
	elif r.id in _gs.booked_today:
		actions.add_child(UIKit.label("seen today · back tomorrow", 14, UIKit.DIM))
	else:
		var b := UIKit.button("BOOK", UIKit.ACCENT, 14)
		b.disabled = _session.is_active()
		b.pressed.connect(func(): book_requested.emit(r))
		actions.add_child(b)
	body.add_child(actions)
	return card


func _shop_card(it: Dictionary) -> Control:
	var card := _card()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	card.add_child(body)
	var head := HBoxContainer.new()
	head.add_child(UIKit.label(it.name, 18, UIKit.TEXT))
	head.add_child(_spacer())
	head.add_child(UIKit.label("€%d" % it.price, 16, UIKit.GOLD))
	body.add_child(head)
	body.add_child(UIKit.wrap_label(it.desc, 14, UIKit.DIM, 360))
	var actions := HBoxContainer.new()
	actions.add_child(_spacer())
	if _gs.has(it.id):
		actions.add_child(UIKit.label("OWNED", 14, UIKit.CYAN))
	else:
		var b := UIKit.button("BUY", UIKit.ACCENT, 14)
		b.disabled = _gs.money < int(it.price)
		b.pressed.connect(func():
			buy_requested.emit(it.id)
			_render())
		actions.add_child(b)
	body.add_child(actions)
	return card


func _track_card(t: Dictionary) -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	card.add_child(row)
	var r := Rappers.by_id(str(t.rapper))
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(UIKit.label("%s  –  track #%d" % [r.get("name", "?"), _gs.tracks.find(t) + 1], 16, UIKit.TEXT))
	body.add_child(UIKit.label("released day %d" % int(t.get("day", 1)), 13, UIKit.DIM))
	row.add_child(body)
	var right := VBoxContainer.new()
	right.add_child(UIKit.label(UIKit.stars(int(t.stars)), 18, UIKit.GOLD))
	right.add_child(UIKit.label("%d streams" % int(t.get("streams", 0)), 13, UIKit.CYAN))
	row.add_child(right)
	return card
