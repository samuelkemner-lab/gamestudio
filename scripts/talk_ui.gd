class_name TalkUI
extends Control
## Small interaction menu next to the person you're talking to. Mouse or keys 1-4.

signal chosen(id: String)
signal closed

var _panel: PanelContainer
var _ids: Array[String] = []
var _enabled: Array[bool] = []


func open(title: String, subtitle: String, options: Array) -> void:
	for c in get_children():
		c.queue_free()
	_ids.clear()
	_enabled.clear()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.BG, 0.94), 16, UIKit.ACCENT, 2, 20))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	col.add_child(UIKit.label(title, 22, UIKit.TEXT))
	if subtitle != "":
		col.add_child(UIKit.label(subtitle, 13, UIKit.DIM))
	for i in options.size():
		var o: Array = options[i]
		var b := UIKit.button("%d   %s" % [i + 1, o[0]], UIKit.PANEL_LIGHT, 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(320, 40)
		b.disabled = o.size() > 2 and not bool(o[2])
		var id: String = o[1]
		b.pressed.connect(func(): choose(id))
		col.add_child(b)
		_ids.append(id)
		_enabled.append(not b.disabled)
	var bye := UIKit.button("ESC   Leave", UIKit.BG, 14)
	bye.pressed.connect(close)
	col.add_child(bye)
	visible = true
	_panel.reset_size()
	var vp := get_viewport_rect().size
	_panel.position = Vector2(vp.x * 0.58, (vp.y - _panel.size.y) / 2.0)


func choose(id: String) -> void:
	visible = false
	chosen.emit(id)


func choose_index(i: int) -> void:
	if i >= 0 and i < _ids.size() and _enabled[i]:
		choose(_ids[i])


func close() -> void:
	visible = false
	closed.emit()
