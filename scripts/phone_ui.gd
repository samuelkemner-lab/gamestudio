class_name PhoneUI
extends Control
## The player's phone: DMs from rappers who want a session, stats, hint mode.

signal book_requested(rapper: Dictionary)
signal hints_toggled(easy: bool)

var _list: VBoxContainer
var _stats: Label
var _hint_btn: Button
var _easy := true


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
	phone.custom_minimum_size = Vector2(430, 760)
	phone.offset_left = -500
	phone.offset_right = -70
	phone.offset_top = -380
	phone.offset_bottom = 380
	add_child(phone)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	phone.add_child(col)

	var status := HBoxContainer.new()
	status.add_child(UIKit.label("3:07", 14, UIKit.TEXT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(sp)
	status.add_child(UIKit.label("▮▮▮  12%", 14, UIKit.POP))
	col.add_child(status)

	col.add_child(UIKit.label("Messages", 30, UIKit.TEXT))
	_stats = UIKit.label("", 15, UIKit.CYAN)
	col.add_child(_stats)

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
	_stats.text = "€%d   ·   REP %d   ·   CRED %d   ·   %d tracks" % [gs.money, gs.reputation, gs.street_cred, gs.sessions]
	for c in _list.get_children():
		c.queue_free()
	for r in Rappers.all():
		_list.add_child(_card(r, gs, session))


func _card(r: Dictionary, gs: GameState, session: Session) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL, 16, Color(), 0, 14))
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
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UIKit.label(r.style, 13, r.accent))
	body.add_child(head)
	body.add_child(UIKit.wrap_label(r.dm, 14, UIKit.DIM, 260))

	var actions := HBoxContainer.new()
	actions.add_child(UIKit.label("pays ~€%d" % r.pay, 14, UIKit.GOLD))
	var sp3 := Control.new()
	sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(sp3)
	if gs.street_cred < int(r.min_cred):
		actions.add_child(UIKit.label("LOCKED · needs %d cred" % r.min_cred, 14, UIKit.POP))
	else:
		var b := UIKit.button("BOOK", UIKit.ACCENT, 14)
		b.disabled = session.is_active()
		b.pressed.connect(func(): book_requested.emit(r))
		actions.add_child(b)
	body.add_child(actions)
	return card
