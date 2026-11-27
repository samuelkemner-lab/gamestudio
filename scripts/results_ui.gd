class_name ResultsUI
extends Control
## End-of-session card: stars, score, feedback, rewards.

signal closed

var _panel: PanelContainer


## Night summary after sleeping: streams per track, money, leaks.
func show_night(n: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.03, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, 24, UIKit.CYAN, 2, 32))
	_panel.custom_minimum_size = Vector2(620, 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	col.add_child(UIKit.label("YOU SLEPT. THE INTERNET DIDN'T.", 16, UIKit.CYAN))
	col.add_child(UIKit.label("Day %d" % n.day, 40, UIKit.TEXT))
	var lines: Array = n.lines
	if lines.is_empty():
		col.add_child(UIKit.wrap_label("No tracks out yet, so no streams. Release something tonight.", 16, UIKit.DIM, 540))
	for l in lines:
		var r := Rappers.by_id(str(l.rapper))
		var txt := "%s %s   %d streams   +€%d" % [r.get("name", "?"), UIKit.stars(int(l.stars)), l.streams, l.euros]
		var lb := UIKit.label(txt, 16, UIKit.POP if l.leaked else UIKit.TEXT)
		col.add_child(lb)
		if l.leaked:
			col.add_child(UIKit.label("   LEAKED! Everyone's listening, nobody's paying.", 14, UIKit.POP))
	col.add_child(UIKit.label("+%d streams  ·  +€%d" % [n.streams, n.earned], 26, UIKit.GOLD))
	var btn := UIKit.button("NEXT NIGHT", UIKit.ACCENT, 18)
	btn.pressed.connect(func():
		visible = false
		closed.emit())
	col.add_child(btn)
	visible = true
	_panel.reset_size()
	_panel.position = (get_viewport_rect().size - _panel.size) / 2.0


func show_summary(s: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, 24, UIKit.ACCENT, 2, 32))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(620, 0)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	var r: Dictionary = s.rapper
	var title := "WALKED OUT" if s.stormed_out else "TRACK RELEASED"
	col.add_child(UIKit.label(title, 16, UIKit.POP if s.stormed_out else UIKit.CYAN))
	col.add_child(UIKit.label("%s  ·  %s" % [r.name, r.style], 30, UIKit.TEXT))
	var stars := UIKit.label(UIKit.stars(int(s.stars)), 54, UIKit.GOLD)
	col.add_child(stars)
	col.add_child(UIKit.label("Score %d / 100   ·   %d take(s)" % [s.score, s.takes], 16, UIKit.DIM))

	var notes: Array = s.notes
	if notes.size() > 0:
		col.add_child(UIKit.label("Feedback", 16, UIKit.TEXT))
		for n in notes.slice(0, 4):
			col.add_child(UIKit.wrap_label("•  " + str(n), 15, UIKit.DIM, 540))
	else:
		col.add_child(UIKit.label("Flawless. Nothing to add.", 16, UIKit.DIM))

	var rewards := HBoxContainer.new()
	rewards.add_theme_constant_override("separation", 24)
	rewards.add_child(UIKit.label("%+d €" % s.money, 26, UIKit.GOLD))
	rewards.add_child(UIKit.label("%+d REP" % s.rep, 26, UIKit.ACCENT))
	rewards.add_child(UIKit.label("%+d CRED" % s.cred, 26, UIKit.CYAN))
	col.add_child(rewards)
	if int(s.tip) > 0:
		col.add_child(UIKit.label("incl. €%d tip" % s.tip, 14, UIKit.DIM))

	var btn := UIKit.button("CONTINUE", UIKit.ACCENT, 18)
	btn.pressed.connect(func():
		visible = false
		closed.emit())
	col.add_child(btn)
	visible = true
	_panel.reset_size()
	_panel.position = (get_viewport_rect().size - _panel.size) / 2.0
