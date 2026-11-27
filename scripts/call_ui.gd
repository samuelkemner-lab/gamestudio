class_name CallUI
extends Control
## Incoming call card (top right) + ringtone, shown even when the phone is in your pocket.
## [Y] answer, [N] decline; after RING_TIME seconds it becomes a missed call.

signal answered(rapper: Dictionary)
signal declined(rapper: Dictionary)
signal missed(rapper: Dictionary)

const RING_TIME := 15.0

var rapper := {}
var ringing := false
var _t := 0.0
var _panel: PanelContainer
var _name: Label
var _avatar: PanelContainer
var _ring: AudioStreamPlayer


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.06, 0.05, 0.1, 0.96), 22, Color("35c759"), 2, 16))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -180
	_panel.offset_right = 180
	_panel.offset_top = 96
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	_avatar = PanelContainer.new()
	_avatar.custom_minimum_size = Vector2(56, 56)
	row.add_child(_avatar)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UIKit.label("INCOMING CALL", 12, Color("35c759")))
	_name = UIKit.label("", 22, UIKit.TEXT)
	col.add_child(_name)
	var btns := HBoxContainer.new()
	var yes := UIKit.button("[Y] Answer", Color("2a9d4b"), 14)
	yes.pressed.connect(answer)
	var no := UIKit.button("[N] Decline", Color("b0303f"), 14)
	no.pressed.connect(decline)
	btns.add_child(yes)
	btns.add_child(no)
	col.add_child(btns)
	_ring = AudioStreamPlayer.new()
	_ring.stream = AmbienceSynth.ringtone()
	_ring.volume_db = -8.0
	add_child(_ring)
	visible = false


func ring(r: Dictionary) -> void:
	rapper = r
	ringing = true
	_t = 0.0
	_name.text = str(r.name)
	_avatar.add_theme_stylebox_override("panel", UIKit.box(r.get("accent", UIKit.ACCENT), 28, Color(), 0, 0))
	visible = true
	if is_inside_tree():
		_ring.play()


func answer() -> void:
	if not ringing:
		return
	_stop()
	answered.emit(rapper)


func decline() -> void:
	if not ringing:
		return
	_stop()
	declined.emit(rapper)


func _stop() -> void:
	ringing = false
	visible = false
	_ring.stop()


func _process(delta: float) -> void:
	if not ringing:
		return
	_t += delta
	# phone buzz: the card shakes a little
	_panel.position.x = _panel.position.x + sin(_t * 60.0) * 0.6
	if _t >= RING_TIME:
		_stop()
		missed.emit(rapper)
