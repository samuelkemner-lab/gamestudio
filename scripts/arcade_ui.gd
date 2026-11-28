class_name ArcadeUI
extends Control
## BEAT DROP: the rhythm cabinet in Snackbar De Hoek. Four lanes (D F J K or the arrow keys), notes fall onto
## the line on a 110 BPM groove. Perfect = 300, good = 100, combo multiplies (max ×4). €1 a game.
## The machine's high-score table pays out once per name you beat.

signal finished(score: int)
signal closed

const BPM := 110.0
const BEATS := 48
const LEAD := 1.3  # seconds a note takes to fall from the top to the line
const PERFECT := 0.05
const GOOD := 0.12
const KEYS := [KEY_D, KEY_F, KEY_J, KEY_K]
const ARROWS := [KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT]
const CHILL_SCORE := 20000  # warm fingers: +1 take with your next rapper (once a night)
const LANE_COL := [Color("ff3d7f"), Color("25d9f5"), Color("f2c14e"), Color("3ddc84")]
const TABLE := [
	{"name": "KEES", "score": 50000, "money": 25},
	{"name": "DJ R", "score": 30000, "money": 10},
	{"name": "MO", "score": 15000, "money": 5},
]

var playing := false
var t := 0.0
var score := 0
var combo := 0
var best_combo := 0
var notes: Array = []  # {t, lane, state: "" | "hit" | "miss"}
var counts := {"perfect": 0, "good": 0, "miss": 0}
var _next_beat := 0
var _flash := ["", 0.0]
var _lane_flash := [0.0, 0.0, 0.0, 0.0]
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _kick: AudioStream
var _hat: AudioStream
var _ticks: Array = []
var _info: Label
var _result: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	_kick = DrumSynth.kick()
	_hat = DrumSynth.hihat()
	for f in [660.0, 880.0, 1100.0, 1320.0]:
		_ticks.append(AmbienceSynth.tick(f))
	_info = UIKit.label("", 16, UIKit.TEXT)
	add_child(_info)
	_result = UIKit.label("", 22, UIKit.GOLD)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_result)


## A fixed groove with fills that get busier towards the end. Same seed = same chart.
static func chart(seed_val: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var out: Array = []
	var beat := 60.0 / BPM
	var lane := 0
	for b in range(4, BEATS):  # one bar count-in
		var steps := [0.0]
		var density := float(b) / BEATS
		if rng.randf() < 0.25 + density * 0.55:
			steps.append(0.5)
		if density > 0.6 and rng.randf() < 0.3:
			steps.append(0.75)
		for s in steps:
			lane = (lane + rng.randi_range(1, 3)) % 4
			out.append({"t": 1.0 + (b + s) * beat, "lane": lane, "state": ""})
	return out


static func grade(dt: float) -> String:
	if absf(dt) <= PERFECT:
		return "perfect"
	if absf(dt) <= GOOD:
		return "good"
	return "miss"


static func mult(c: int) -> int:
	return mini(1 + c / 10, 4)


static func max_score(n: Array) -> int:
	var s := 0
	for i in n.size():
		s += 300 * mult(i)
	return s


func open(seed_val := -1) -> void:
	notes = chart(seed_val if seed_val >= 0 else randi())
	t = 0.0
	score = 0
	combo = 0
	best_combo = 0
	counts = {"perfect": 0, "good": 0, "miss": 0}
	_next_beat = 0
	_flash = ["", 0.0]
	_result.text = ""
	playing = true
	visible = true


func quit() -> void:
	playing = false
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: Key = event.physical_keycode
	if k == KEY_ESCAPE or (not playing and k in [KEY_SPACE, KEY_ENTER, KEY_E]):
		quit()
	elif playing:
		var lane := KEYS.find(k)
		if lane < 0:
			lane = ARROWS.find(k)
		if lane >= 0:
			hit(lane)
	get_viewport().set_input_as_handled()


## Press a lane: grades the nearest open note in that lane (within the good window).
func hit(lane: int) -> String:
	_lane_flash[lane] = 0.12
	var best_i := -1
	var best_dt := 99.0
	for i in notes.size():
		var n: Dictionary = notes[i]
		if n.state != "" or n.lane != lane:
			continue
		var dt: float = t - n.t
		if absf(dt) < absf(best_dt):
			best_dt = dt
			best_i = i
		if n.t > t + GOOD:
			break
	var g := grade(best_dt) if best_i >= 0 else "miss"
	if g == "miss":
		if best_i >= 0 and absf(best_dt) < GOOD * 2.0:
			notes[best_i].state = "miss"
			counts.miss += 1
		combo = 0
		_flash = ["MISS", 0.4]
		return g
	notes[best_i].state = "hit"
	counts[g] += 1
	score += (300 if g == "perfect" else 100) * mult(combo)
	combo += 1
	best_combo = maxi(best_combo, combo)
	_flash = [g.to_upper(), 0.4]
	_play(_ticks[lane], -6.0)
	return g


func _process(delta: float) -> void:
	if not visible:
		return
	for i in 4:
		_lane_flash[i] = maxf(_lane_flash[i] - delta, 0.0)
	_flash[1] = maxf(float(_flash[1]) - delta, 0.0)
	if playing:
		t += delta
		var beat := 60.0 / BPM
		while 1.0 + _next_beat * beat * 0.5 <= t and _next_beat < BEATS * 2:
			_play(_kick if _next_beat % 2 == 0 else _hat, -4.0 if _next_beat % 2 == 0 else -14.0)
			_next_beat += 1
		for n in notes:
			if n.state == "" and t - float(n.t) > GOOD:
				n.state = "miss"
				counts.miss += 1
				combo = 0
		if t > 1.0 + BEATS * beat + 1.0:
			_finish()
	_layout()
	queue_redraw()


func _finish() -> void:
	playing = false
	var lines := ["GAME OVER", "SCORE %d   ·   best combo %d" % [score, best_combo],
		"perfect %d  ·  good %d  ·  miss %d" % [counts.perfect, counts.good, counts.miss], "", "[E] / [SPACE] close"]
	_result.text = "\n".join(lines)
	finished.emit(score)


func _play(s: AudioStream, db: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var p := _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = s
	p.volume_db = db
	p.play()


func _rect() -> Rect2:
	var vp := get_viewport_rect().size
	var h := minf(vp.y * 0.86, 680.0)
	var w := h * 0.62
	return Rect2((vp.x - w) / 2.0, (vp.y - h) / 2.0, w, h)


func _layout() -> void:
	var r := _rect()
	_info.text = "BEAT DROP\nSCORE %d\nCOMBO %d  ×%d" % [score, combo, mult(combo)]
	_info.position = r.position + Vector2(r.size.x + 24, 8)
	_result.reset_size()
	_result.position = Vector2(r.position.x + (r.size.x - _result.size.x) / 2.0, r.position.y + r.size.y * 0.32)


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.01, 0.0, 0.03, 0.82))
	var r := _rect()
	draw_rect(r.grow(10), Color("2a2347"))
	draw_rect(r, Color("07050d"))
	var lw := r.size.x / 4.0
	var line_y := r.position.y + r.size.y * 0.86
	for i in 4:
		var x := r.position.x + i * lw
		var c: Color = LANE_COL[i]
		draw_rect(Rect2(x + 2, r.position.y, lw - 4, r.size.y), Color(c, 0.05 + _lane_flash[i] * 2.0))
		draw_rect(Rect2(x + 6, line_y - 6, lw - 12, 12), Color(c, 0.35 + _lane_flash[i] * 4.0))
		var key_name: String = ["D", "F", "J", "K"][i]
		draw_string(get_theme_default_font(), Vector2(x + lw / 2.0 - 6, r.end.y - 16), key_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(c, 0.8))
	var span := line_y - r.position.y
	for n in notes:
		if n.state == "hit":
			continue
		var dt: float = float(n.t) - t
		if dt > LEAD or dt < -0.3:
			continue
		var y := line_y - dt / LEAD * span
		var c: Color = LANE_COL[n.lane]
		if n.state == "miss":
			c = Color(0.3, 0.3, 0.35)
		draw_rect(Rect2(r.position.x + n.lane * lw + 8, y - 9, lw - 16, 18), c)
	if float(_flash[1]) > 0.0:
		var f := get_theme_default_font()
		var txt: String = _flash[0]
		var col := UIKit.GOLD if txt == "PERFECT" else (UIKit.CYAN if txt == "GOOD" else UIKit.POP)
		draw_string(f, Vector2(r.position.x, line_y - 60), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Color(col, minf(float(_flash[1]) * 3.0, 1.0)))


## Score a finished game against the machine's table (each name pays once) and your own high score.
static func result(gs: GameState, final_score: int) -> Dictionary:
	var high := int(gs.records.get("arcade_high", 0))
	var is_high := final_score > high
	if is_high:
		gs.records.arcade_high = final_score
	var beaten: Array = gs.records.get("arcade_beaten", [])
	var new_names: Array = []
	var money := 0
	for e in TABLE:
		if final_score > int(e.score) and not e.name in beaten:
			beaten.append(e.name)
			new_names.append(e.name)
			money += int(e.money)
	gs.records.arcade_beaten = beaten
	gs.stats.arcade_games = int(gs.stats.get("arcade_games", 0)) + 1
	var chill := final_score >= CHILL_SCORE and int(gs.stats.get("arcade_chill_day", -1)) != gs.day
	if chill:
		gs.stats.arcade_chill_day = gs.day
		gs.add_buff("chill", 1)
	gs.add(money, 0, 0)
	return {"score": final_score, "high": is_high, "new_names": new_names, "money": money, "chill": chill}
