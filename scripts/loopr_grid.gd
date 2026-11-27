class_name LooprGrid
extends Control
## One custom-drawn grid for LOOPR (Channel Rack, Piano Roll, Playlist).
## Draws row labels, a column header with the playhead and all cells in one go,
## and supports click-and-drag painting like a real DAW.

signal stroke_started(row: int, col: int, button: int)
signal cell_pressed(row: int, col: int, button: int, frac: Vector2)
signal cell_dragged(row: int, col: int, button: int, frac: Vector2)
signal label_pressed(row: int)

var rows := 1
var cols := 16
var cell := Vector2(56, 48)
var gap := 3.0
var group := 4  # extra space every N columns (0 = none)
var group_gap := 10.0
var label_w := 150.0
var header_h := 20.0
var radius := 6.0

## row_info.call(row) -> {name: String, color: Color, base: Color}
var row_info: Callable
## cell_info.call(row, col) -> {on: bool, color: Color, base: Color, fill: float (0..1), text: String}
var cell_info: Callable
## header_text.call(col) -> String
var header_text: Callable
## extra_draw.call(grid, rect: Rect2, row, col) for custom content (mini previews)
var extra_draw: Callable
var playhead := -1
var playhead_color := Color("a855f7")
var header_color := Color("8f86b3")

var _drag_button := 0
var _last_cell := Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resize()


func configure(p_rows: int, p_cols: int, p_cell: Vector2) -> void:
	rows = p_rows
	cols = p_cols
	cell = p_cell
	_resize()


func _resize() -> void:
	custom_minimum_size = Vector2(label_w + _col_x(cols) + 4, header_h + rows * (cell.y + gap))
	queue_redraw()


func _col_x(c: int) -> float:
	var groups := (c / group) if group > 0 else 0
	if group > 0 and c > 0 and c % group == 0 and c == cols:
		groups -= 1
	return c * (cell.x + gap) + groups * group_gap


func cell_rect(r: int, c: int) -> Rect2:
	return Rect2(Vector2(label_w + _col_x(c), header_h + r * (cell.y + gap)), cell)


func cell_at(p: Vector2) -> Vector2i:
	if p.y < header_h:
		return Vector2i(-1, -1)
	var r := int((p.y - header_h) / (cell.y + gap))
	if r < 0 or r >= rows:
		return Vector2i(-1, -1)
	for c in cols:
		var rect := cell_rect(r, c).grow_individual(gap * 0.5, 0, gap * 0.5 + (group_gap if group > 0 and c % group == group - 1 else 0.0), 0)
		if p.x >= rect.position.x and p.x < rect.end.x:
			return Vector2i(r, c)
	return Vector2i(r, -2) if p.x < label_w else Vector2i(-1, -1)


func set_playhead(c: int) -> void:
	if c != playhead:
		playhead = c
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	# header
	if header_h > 0:
		for c in cols:
			var hx := label_w + _col_x(c)
			var hr := Rect2(hx, 2, cell.x, header_h - 7)
			draw_rect(hr, playhead_color if c == playhead else Color(1, 1, 1, 0.05))
			if header_text.is_valid():
				var t: String = header_text.call(c)
				if t != "":
					draw_string(font, Vector2(hx + 4, header_h - 9), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, header_color if c != playhead else Color.WHITE)
	for r in rows:
		var info: Dictionary = row_info.call(r) if row_info.is_valid() else {}
		var ly := header_h + r * (cell.y + gap)
		if label_w > 0:
			var lr := Rect2(0, ly, label_w - 10, cell.y)
			draw_style_box(_sb(info.get("base", Color("2a2347"))), lr)
			var fs := clampi(int(cell.y * 0.38), 11, 18)
			draw_string(font, Vector2(10, ly + cell.y * 0.5 + fs * 0.35), str(info.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, label_w - 20, fs, info.get("color", Color.WHITE))
		for c in cols:
			var rect := cell_rect(r, c)
			var ci: Dictionary = cell_info.call(r, c)
			var base: Color = ci.get("base", Color("2b2540"))
			if c == playhead:
				base = base.lightened(0.12)
			draw_style_box(_sb(base), rect)
			if ci.get("on", false):
				var col: Color = ci.get("color", Color.WHITE)
				var fill: float = ci.get("fill", 1.0)
				if fill >= 0.999:
					draw_style_box(_sb(col), rect)
				else:
					draw_style_box(_sb(col.darkened(0.55)), rect)
					var h := maxf(rect.size.y * fill, 4.0)
					var fr := Rect2(rect.position.x, rect.end.y - h, rect.size.x, h)
					draw_style_box(_sb(col), fr)
				if c == playhead:
					draw_style_box(_sb(Color(1, 1, 1, 0.25)), rect)
			var txt: String = ci.get("text", "")
			if txt != "":
				var fs2 := clampi(int(cell.y * 0.34), 10, 16)
				draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + fs2 * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs2, ci.get("text_color", Color(0.05, 0.03, 0.1)))
			if extra_draw.is_valid():
				extra_draw.call(self, rect, r, c)


func _sb(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	return sb


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			var at := cell_at(mb.position)
			if at.y == -2:
				label_pressed.emit(at.x)
				accept_event()
				return
			if at.x < 0:
				return
			_drag_button = mb.button_index
			_last_cell = at
			stroke_started.emit(at.x, at.y, mb.button_index)
			cell_pressed.emit(at.x, at.y, mb.button_index, _frac(at, mb.position))
			accept_event()
		elif not mb.pressed and mb.button_index == _drag_button:
			_drag_button = 0
			_last_cell = Vector2i(-1, -1)
	elif event is InputEventMouseMotion and _drag_button != 0:
		var at := cell_at(event.position)
		if at.x < 0 or at.y < 0:
			return
		cell_dragged.emit(at.x, at.y, _drag_button, _frac(at, event.position))
		_last_cell = at
		accept_event()


func is_new_cell(r: int, c: int) -> bool:
	return Vector2i(r, c) != _last_cell


func _frac(at: Vector2i, p: Vector2) -> Vector2:
	var rect := cell_rect(at.x, at.y)
	return ((p - rect.position) / rect.size).clamp(Vector2.ZERO, Vector2.ONE)
