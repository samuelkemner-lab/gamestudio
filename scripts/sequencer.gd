class_name Sequencer
extends Node
## LOOPR audio core: 16-step drum pattern, one audio bus per track.

signal step_changed(step: int)
signal play_state_changed(is_playing: bool)
signal pattern_changed

const TRACKS: Array[String] = ["Kick", "Snare", "Hi-hat", "Clap", "808"]
const STEPS := 16

var bpm := 140.0
var playing := false
var pattern: Array = []  # pattern[track][step] -> bool
var current_step := -1

var _acc := 0.0
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_setup_buses()
	var streams := [
		DrumSynth.kick(), DrumSynth.snare(), DrumSynth.hihat(),
		DrumSynth.clap(), DrumSynth.bass808(),
	]
	for i in TRACKS.size():
		var row: Array = []
		row.resize(STEPS)
		row.fill(false)
		pattern.append(row)
		var p := AudioStreamPlayer.new()
		p.stream = streams[i]
		p.bus = TRACKS[i]
		p.max_polyphony = 4
		add_child(p)
		_players.append(p)
	load_default_pattern()


func _setup_buses() -> void:
	for track_name in TRACKS:
		if AudioServer.get_bus_index(track_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, track_name)
			AudioServer.set_bus_send(idx, "Master")


func load_default_pattern() -> void:
	clear()
	for s in [0, 7, 10]:
		pattern[0][s] = true
	for s in [4, 12]:
		pattern[1][s] = true
	for s in range(0, STEPS, 2):
		pattern[2][s] = true
	pattern[2][11] = true
	pattern[3][12] = true
	for s in [0, 10]:
		pattern[4][s] = true
	pattern_changed.emit()


func clear() -> void:
	for row in pattern:
		row.fill(false)
	pattern_changed.emit()


func toggle(track: int, step: int) -> bool:
	pattern[track][step] = not pattern[track][step]
	pattern_changed.emit()
	return pattern[track][step]


func set_step(track: int, step: int, on: bool) -> void:
	pattern[track][step] = on
	pattern_changed.emit()


func step_length() -> float:
	return 60.0 / bpm / 4.0


func play() -> void:
	playing = true
	_acc = 0.0
	current_step = -1
	_advance()
	play_state_changed.emit(true)


func stop() -> void:
	playing = false
	current_step = -1
	step_changed.emit(-1)
	play_state_changed.emit(false)


func toggle_play() -> void:
	if playing:
		stop()
	else:
		play()


func preview(track: int) -> void:
	_players[track].play()


func _process(delta: float) -> void:
	if not playing:
		return
	_acc += delta
	var len := step_length()
	while _acc >= len:
		_acc -= len
		_advance()


func _advance() -> void:
	current_step = (current_step + 1) % STEPS
	for i in TRACKS.size():
		if pattern[i][current_step]:
			if TRACKS[i] == "808":
				_players[i].stop()  # 808 choke: a new note cuts the tail
			_players[i].play()
	step_changed.emit(current_step)


# --- Mixer ---

func bus_index(track: int) -> int:
	return AudioServer.get_bus_index(TRACKS[track])


func set_volume(bus_idx: int, linear: float) -> void:
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(linear, 0.0001)))


func get_volume(bus_idx: int) -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))


func set_mute(bus_idx: int, muted: bool) -> void:
	AudioServer.set_bus_mute(bus_idx, muted)
