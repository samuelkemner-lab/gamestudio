class_name LooprMeter
extends Control
## Vertical level meter: green → yellow → red, with a peak-hold line and a clip LED.

var level := 0.0  # 1.0 = 0 dBFS
var clip := false
var _hold := 0.0
var _hold_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(v: float, is_clipping: bool, delta: float) -> void:
	level = v
	clip = is_clipping
	if v >= _hold:
		_hold = v
		_hold_t = 1.0
	else:
		_hold_t -= delta
		if _hold_t <= 0.0:
			_hold = maxf(_hold - delta * 0.6, v)
	queue_redraw()


## dB → 0..1 meter height (-48 dB .. +6 dB)
static func height_of(v: float) -> float:
	if v <= 0.0001:
		return 0.0
	return clampf((linear_to_db(v) + 48.0) / 54.0, 0.0, 1.0)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color("0c0a14"))
	var led_h := 10.0
	var body := Rect2(2, led_h + 4, size.x - 4, size.y - led_h - 6)
	var h := height_of(level) * body.size.y
	var zero_y := body.end.y - height_of(1.0) * body.size.y
	var warn_y := body.end.y - height_of(db_to_linear(-6.0)) * body.size.y
	if h > 0.0:
		var top := body.end.y - h
		# green part
		var g_top := maxf(top, warn_y)
		draw_rect(Rect2(body.position.x, g_top, body.size.x, body.end.y - g_top), Color("22c55e"))
		if top < warn_y:
			var y_top := maxf(top, zero_y)
			draw_rect(Rect2(body.position.x, y_top, body.size.x, warn_y - y_top), Color("facc15"))
		if top < zero_y:
			draw_rect(Rect2(body.position.x, top, body.size.x, zero_y - top), Color("ef4444"))
	# 0 dB line and peak hold
	draw_line(Vector2(0, zero_y), Vector2(size.x, zero_y), Color(1, 1, 1, 0.35), 1.0)
	if _hold > 0.0001:
		var hy := body.end.y - height_of(_hold) * body.size.y
		draw_line(Vector2(body.position.x, hy), Vector2(body.end.x, hy), Color(1, 1, 1, 0.8), 2.0)
	draw_rect(Rect2(2, 2, size.x - 4, led_h), Color("ef4444") if clip else Color("3a1018"))
