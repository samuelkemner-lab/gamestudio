class_name Sequencer
extends Node
## LOOPR audio core.
## - 4 patterns (A–D). Each pattern: 16 drum steps per track with velocity and rolls,
##   a 16-step melody (piano roll) and a pitched 808 lane.
## - Playlist: 8 bars, each bar plays one pattern. PAT mode loops the pattern you edit,
##   SONG mode plays the arrangement.
## - Swing, 808 glide, undo, one audio bus per track with low cut, reverb and pan.
## - A deterministic level model drives the meters and the clip warning (also used by the judge).

signal step_changed(step: int)
signal bar_changed(bar: int)
signal play_state_changed(is_playing: bool)
signal pattern_changed
signal pattern_selected(index: int)

const TRACKS: Array[String] = ["Kick", "Snare", "Hi-hat", "Clap", "808"]
const BASS := 4  # index of the 808 track
const STEPS := 16
const PATTERNS := 4
const PATTERN_NAMES := ["A", "B", "C", "D"]
const BARS := 8
const NOTE_RANGE := 13  # one octave + top note
const NOTE_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B", "C"]
const MINOR := [0, 2, 3, 5, 7, 8, 10, 12]
const DEFAULT_VEL := 0.8
const GHOST_VEL := 0.5  # below this a hit counts as a ghost note
const BASS_DEFAULT := 8  # G#1: the 808's natural pitch
const MAX_ROLL := 4
const MAX_UNDO := 40

# Level model: peak amplitude of one hit at default velocity and fader 1.0.
const AMP := {"Kick": 0.40, "Snare": 0.30, "Hi-hat": 0.10, "Clap": 0.22, "808": 0.36}
const KEYS_AMP := 0.15

# Effect slots on every track bus.
const FX_LOCUT := 0
const FX_REVERB := 1
const FX_PAN := 2

var bpm := 140.0
var swing := 0.0  # 0..0.6, delays every second 16th
var glide := false  # 808 slides between notes
var playing := false
var song_mode := false

var patterns: Array = []  # Array of pattern dicts
var current_pattern := 0
# References into patterns[current_pattern] (what the UI and the judge read):
var pattern: Array = []  # [track][step] -> bool
var velocity: Array = []  # [track][step] -> 0.1..1.0
var rolls: Array = []  # [track][step] -> 1..4 hits inside the step
var melody: Array = []  # [step] -> Array of semitones
var bass: Array = []  # [step] -> 808 semitone (0 = C1 .. 12 = C2)

var playlist: Array = []  # [bar] -> pattern index or -1
var instrument := "keys"
var kit_id := "default"
var current_step := -1
var play_bar := 0
var dirty := false  # unsaved changes (for the pc-crash event)

# Live meters (0..1+, 1.0 = 0 dBFS)
var levels := {}
var master_level := 0.0
var clip_timer := 0.0

var _saved := {}
var _undo: Array = []
var _acc := 0.0
var _pending: Array = []  # [[seconds_left, Callable]]
var _players: Array[AudioStreamPlayer] = []
var _keys: Array[AudioStreamPlayer] = []
var _key_rr := 0
var _last_bass := -1
var _muted := {}
var _solo := {}


func _ready() -> void:
	_setup_buses()
	for i in TRACKS.size():
		var p := AudioStreamPlayer.new()
		p.bus = TRACKS[i]
		p.max_polyphony = 6
		add_child(p)
		_players.append(p)
	set_kit("default")
	for i in 8:
		var k := AudioStreamPlayer.new()
		k.bus = "Keys"
		add_child(k)
		_keys.append(k)
	set_instrument("keys")
	for i in PATTERNS:
		patterns.append(_empty_pattern())
	playlist.resize(BARS)
	playlist.fill(-1)
	for name in TRACKS + ["Keys"]:
		levels[name] = 0.0
	_bind(0)
	load_default_pattern()
	_undo.clear()
	save_snapshot()


func _empty_pattern() -> Dictionary:
	var d := {"pattern": [], "velocity": [], "rolls": [], "melody": [], "bass": []}
	for t in TRACKS.size():
		var on: Array = []
		on.resize(STEPS)
		on.fill(false)
		var vel: Array = []
		vel.resize(STEPS)
		vel.fill(DEFAULT_VEL)
		var rl: Array = []
		rl.resize(STEPS)
		rl.fill(1)
		d.pattern.append(on)
		d.velocity.append(vel)
		d.rolls.append(rl)
	for s in STEPS:
		d.melody.append([])
		d.bass.append(BASS_DEFAULT)
	return d


func _bind(i: int) -> void:
	current_pattern = i
	var d: Dictionary = patterns[i]
	pattern = d.pattern
	velocity = d.velocity
	rolls = d.rolls
	melody = d.melody
	bass = d.bass


func _setup_buses() -> void:
	for track_name in TRACKS + ["Keys"]:
		var idx := AudioServer.get_bus_index(track_name)
		if idx == -1:
			idx = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, track_name)
			AudioServer.set_bus_send(idx, "Master")
		if AudioServer.get_bus_effect_count(idx) == 0:
			var hp := AudioEffectHighPassFilter.new()
			hp.cutoff_hz = 180.0
			AudioServer.add_bus_effect(idx, hp, FX_LOCUT)
			AudioServer.set_bus_effect_enabled(idx, FX_LOCUT, false)
			var rev := AudioEffectReverb.new()
			rev.room_size = 0.6
			rev.damping = 0.4
			rev.wet = 0.0
			rev.dry = 1.0
			AudioServer.add_bus_effect(idx, rev, FX_REVERB)
			AudioServer.set_bus_effect_enabled(idx, FX_REVERB, false)
			AudioServer.add_bus_effect(idx, AudioEffectPanner.new(), FX_PAN)
	# Protect ears and speakers: the meters still show when you'd clip.
	if AudioServer.get_bus_effect_count(0) == 0 and ClassDB.class_exists("AudioEffectHardLimiter"):
		var lim: AudioEffect = ClassDB.instantiate("AudioEffectHardLimiter")
		AudioServer.add_bus_effect(0, lim)


# ---------- Patterns ----------

func select_pattern(i: int) -> void:
	_bind(clampi(i, 0, PATTERNS - 1))
	pattern_selected.emit(current_pattern)
	pattern_changed.emit()


## Copy the current pattern into the next one and switch to it (to build a variation).
func clone_to_next() -> int:
	var dst := (current_pattern + 1) % PATTERNS
	checkpoint()
	patterns[dst] = patterns[current_pattern].duplicate(true)
	dirty = true
	select_pattern(dst)
	return dst


func pattern_is_empty(i: int) -> bool:
	var d: Dictionary = patterns[i]
	for row in d.pattern:
		if true in row:
			return false
	for st in d.melody:
		if not st.is_empty():
			return false
	return true


func load_default_pattern() -> void:
	checkpoint()
	_clear_current()
	for s in [0, 7, 10]:
		pattern[0][s] = true
	for s in [4, 12]:
		pattern[1][s] = true
	for s in range(0, STEPS, 2):
		pattern[2][s] = true
	pattern[2][11] = true
	velocity[2][11] = 0.45
	pattern[3][12] = true
	for s in [0, 10]:
		pattern[4][s] = true
	dirty = true
	pattern_changed.emit()


func clear() -> void:
	checkpoint()
	_clear_current()
	dirty = true
	pattern_changed.emit()


func _clear_current() -> void:
	for t in TRACKS.size():
		pattern[t].fill(false)
		velocity[t].fill(DEFAULT_VEL)
		rolls[t].fill(1)
	for s in STEPS:
		melody[s].clear()
		bass[s] = BASS_DEFAULT


func toggle(track: int, step: int) -> bool:
	set_step(track, step, not pattern[track][step])
	return pattern[track][step]


func set_step(track: int, step: int, on: bool) -> void:
	pattern[track][step] = on
	if not on:
		velocity[track][step] = DEFAULT_VEL
		rolls[track][step] = 1
	dirty = true
	pattern_changed.emit()


func set_velocity(track: int, step: int, v: float) -> void:
	velocity[track][step] = clampf(v, 0.1, 1.0)
	if not pattern[track][step]:
		pattern[track][step] = true
	dirty = true
	pattern_changed.emit()


## Cycles 1 → 2 → 3 → 4 → 1 hits inside one step (hi-hat rolls).
func cycle_roll(track: int, step: int) -> int:
	var r: int = rolls[track][step] % MAX_ROLL + 1
	rolls[track][step] = r
	pattern[track][step] = true
	dirty = true
	pattern_changed.emit()
	return r


func set_roll(track: int, step: int, r: int) -> void:
	rolls[track][step] = clampi(r, 1, MAX_ROLL)
	pattern[track][step] = true
	dirty = true
	pattern_changed.emit()


func set_swing(v: float) -> void:
	swing = clampf(v, 0.0, 0.6)
	dirty = true


func set_glide(on: bool) -> void:
	glide = on
	dirty = true
	pattern_changed.emit()


# ---------- Melody (piano roll) ----------

func set_note(step: int, semitone: int, on: bool) -> void:
	var notes: Array = melody[step]
	if on and not semitone in notes:
		notes.append(semitone)
	elif not on:
		notes.erase(semitone)
	dirty = true
	pattern_changed.emit()


func has_note(step: int, semitone: int) -> bool:
	return semitone in melody[step]


func note_count() -> int:
	var n := 0
	for st in melody:
		n += st.size()
	return n


func off_scale_notes(scale: Array) -> int:
	var n := 0
	for st in melody:
		for semi in st:
			if not semi in scale:
				n += 1
	return n


## 808 lane: one note per step. Placing a note also triggers the 808 on that step.
func set_bass(step: int, semitone: int, on: bool) -> void:
	if on:
		bass[step] = semitone
		pattern[BASS][step] = true
	else:
		pattern[BASS][step] = false
		bass[step] = BASS_DEFAULT
	dirty = true
	pattern_changed.emit()


func has_bass(step: int, semitone: int) -> bool:
	return pattern[BASS][step] and bass[step] == semitone


func bass_pitches() -> int:
	var seen := {}
	for s in STEPS:
		if pattern[BASS][s]:
			seen[bass[s]] = true
	return seen.size()


func ghost_notes(track: int) -> int:
	var n := 0
	for s in STEPS:
		if pattern[track][s] and velocity[track][s] < GHOST_VEL:
			n += 1
	return n


func roll_count(track: int) -> int:
	var n := 0
	for s in STEPS:
		if pattern[track][s] and rolls[track][s] > 1:
			n += 1
	return n


func preview_note(semitone: int) -> void:
	var k := _keys[_key_rr]
	_key_rr = (_key_rr + 1) % _keys.size()
	k.pitch_scale = pow(2.0, semitone / 12.0)
	k.play()
	_meter("Keys", KEYS_AMP)


func preview_bass(semitone: int) -> void:
	var p := _players[BASS]
	p.stop()
	p.pitch_scale = _bass_scale(semitone)
	p.volume_db = 0.0
	p.play()


func _bass_scale(semitone: int) -> float:
	return pow(2.0, (semitone - BASS_DEFAULT) / 12.0)


func set_instrument(id: String) -> void:
	instrument = id
	var s := DrumSynth.instrument(id)
	for k in _keys:
		k.stream = s


func set_kit(id: String) -> void:
	kit_id = id
	var streams := DrumSynth.kit(id)
	for i in TRACKS.size():
		_players[i].stream = streams[i]


# ---------- Playlist ----------

func set_bar(bar: int, pat: int) -> void:
	playlist[bar] = pat
	dirty = true
	pattern_changed.emit()


func song_length() -> int:
	for b in range(BARS - 1, -1, -1):
		if playlist[b] >= 0:
			return b + 1
	return 0


## How "finished" the song is: filled bars and how many different patterns it uses.
func arrangement() -> Dictionary:
	var bars := 0
	var used := {}
	for b in BARS:
		var p: int = playlist[b]
		if p >= 0 and not pattern_is_empty(p):
			bars += 1
			used[p] = true
	return {"bars": bars, "patterns": used.size(), "song": bars >= 4 and used.size() >= 2}


func set_song_mode(on: bool) -> void:
	song_mode = on
	if playing:
		play()


# ---------- Undo / save / crash ----------

func snapshot() -> Dictionary:
	return {
		"patterns": patterns.duplicate(true), "current": current_pattern, "playlist": playlist.duplicate(),
		"bpm": bpm, "swing": swing, "glide": glide,
		# legacy keys (tests / older saves read these)
		"pattern": pattern.duplicate(true), "melody": melody.duplicate(true),
	}


func restore(snap: Dictionary) -> void:
	if snap.has("patterns"):
		patterns = snap.patterns.duplicate(true)
		playlist = snap.playlist.duplicate()
		swing = snap.get("swing", 0.0)
		glide = snap.get("glide", false)
		_bind(int(snap.get("current", 0)))
	else:
		_bind(current_pattern)
		for t in TRACKS.size():
			for s in STEPS:
				pattern[t][s] = snap.pattern[t][s]
		for s in STEPS:
			melody[s] = snap.melody[s].duplicate()
	bpm = snap.bpm
	pattern_selected.emit(current_pattern)
	pattern_changed.emit()


## Call once before a user edit (a click or a drag) so CTRL+Z can take it back.
func checkpoint() -> void:
	_undo.append(snapshot())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()


func can_undo() -> bool:
	return not _undo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	restore(_undo.pop_back())
	dirty = true
	pattern_changed.emit()
	return true


func save_snapshot() -> void:
	_saved = snapshot()
	dirty = false
	pattern_changed.emit()


func restore_saved() -> void:
	if not _saved.is_empty():
		restore(_saved)
	_undo.clear()
	dirty = false
	pattern_changed.emit()


# ---------- Transport ----------

func step_length() -> float:
	return 60.0 / bpm / 4.0


func play() -> void:
	playing = true
	_acc = 0.0
	_pending.clear()
	current_step = -1
	play_bar = 0
	_last_bass = -1
	_advance()
	play_state_changed.emit(true)


func stop() -> void:
	playing = false
	_pending.clear()
	current_step = -1
	step_changed.emit(-1)
	play_state_changed.emit(false)


func toggle_play() -> void:
	if playing:
		stop()
	else:
		play()


func preview(track: int) -> void:
	if track == BASS:
		preview_bass(BASS_DEFAULT)
		return
	_players[track].volume_db = 0.0
	_players[track].play()
	_meter(TRACKS[track], AMP[TRACKS[track]])


## The pattern index that is sounding right now.
func playing_pattern() -> int:
	if song_mode and song_length() > 0:
		return playlist[play_bar]
	return current_pattern


func _process(delta: float) -> void:
	# meters fall back
	var fall := exp(-delta * 7.0)
	for k in levels.keys():
		levels[k] *= fall
	master_level *= fall
	clip_timer = maxf(clip_timer - delta, 0.0)
	if not playing:
		return
	var i := _pending.size() - 1
	while i >= 0:
		_pending[i][0] -= delta
		if _pending[i][0] <= 0.0:
			var cb: Callable = _pending[i][1]
			_pending.remove_at(i)
			cb.call()
		i -= 1
	_acc += delta
	var len := step_length()
	while _acc >= len:
		_acc -= len
		_advance()


func _advance() -> void:
	current_step += 1
	if current_step >= STEPS:
		current_step = 0
		if song_mode and song_length() > 0:
			play_bar = (play_bar + 1) % song_length()
			bar_changed.emit(play_bar)
	if current_step == 0 and song_mode:
		bar_changed.emit(play_bar)
	var p := playing_pattern()
	if p >= 0:
		_trigger_step(p, current_step)
	step_changed.emit(current_step)


func _trigger_step(p: int, s: int) -> void:
	var d: Dictionary = patterns[p]
	var len := step_length()
	var offset := swing * len * 0.66 if s % 2 == 1 else 0.0
	for t in TRACKS.size():
		if not d.pattern[t][s]:
			continue
		var vel: float = d.velocity[t][s]
		var n: int = d.rolls[t][s]
		for k in n:
			var at: float = offset + k * len / n
			var v := vel * (1.0 if k == 0 else 0.85)
			if t == BASS:
				_schedule(at, _hit_bass.bind(int(d.bass[s]), v))
			else:
				_schedule(at, _hit.bind(t, v))
	for semi in d.melody[s]:
		_schedule(offset, preview_note.bind(int(semi)))
	var peak := step_peak(p, s)
	_schedule(offset, func():
		master_level = maxf(master_level, peak)
		if peak > 1.0:
			clip_timer = 1.2)


func _schedule(at: float, cb: Callable) -> void:
	if at <= 0.0005:
		cb.call()
	else:
		_pending.append([at, cb])


func _hit(t: int, vel: float) -> void:
	var p := _players[t]
	p.volume_db = linear_to_db(vel / DEFAULT_VEL)
	p.play()
	_meter(TRACKS[t], AMP[TRACKS[t]] * vel / DEFAULT_VEL)


func _hit_bass(semi: int, vel: float) -> void:
	var p := _players[BASS]
	p.stop()  # 808 choke: a new note cuts the tail
	p.volume_db = linear_to_db(vel / DEFAULT_VEL)
	var target := _bass_scale(semi)
	if glide and _last_bass >= 0 and _last_bass != semi:
		p.pitch_scale = _bass_scale(_last_bass)
		var tw := create_tween()
		tw.tween_property(p, "pitch_scale", target, minf(step_length() * 0.9, 0.12))
	else:
		p.pitch_scale = target
	p.play()
	_last_bass = semi
	_meter("808", AMP["808"] * vel / DEFAULT_VEL)


func _meter(bus_name: String, amp: float) -> void:
	levels[bus_name] = maxf(levels.get(bus_name, 0.0), amp * _gain(bus_name))


# ---------- Level model (meters, clip warning, judge) ----------

func _gain(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0 or AudioServer.is_bus_mute(idx):
		return 0.0
	return get_volume(idx)


## Estimated peak (1.0 = 0 dBFS) of one step of a pattern, after faders and master.
func step_peak(p: int, s: int) -> float:
	var d: Dictionary = patterns[p]
	var sum := 0.0
	for t in TRACKS.size():
		if d.pattern[t][s]:
			sum += AMP[TRACKS[t]] * float(d.velocity[t][s]) / DEFAULT_VEL * _gain(TRACKS[t])
	var n: int = d.melody[s].size()
	if n > 0:
		sum += KEYS_AMP * (1.0 + 0.5 * (n - 1)) * _gain("Keys")
	return sum * (0.0 if AudioServer.is_bus_mute(0) else get_volume(0))


func peak_estimate(p: int = -1) -> float:
	if p < 0:
		p = current_pattern
	var m := 0.0
	for s in STEPS:
		m = maxf(m, step_peak(p, s))
	return m


func peak_db(p: int = -1) -> float:
	var v := peak_estimate(p)
	return -80.0 if v <= 0.0001 else linear_to_db(v)


# ---------- Mixer ----------

func bus_index(track: int) -> int:
	return AudioServer.get_bus_index(TRACKS[track])


func set_volume(bus_idx: int, linear: float) -> void:
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(linear, 0.0001)))


func get_volume(bus_idx: int) -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))


func set_mute(bus_idx: int, muted: bool) -> void:
	_muted[bus_idx] = muted
	_apply_mutes()


func is_muted(bus_idx: int) -> bool:
	return bool(_muted.get(bus_idx, false))


## Solo: only soloed channels sound (master is never affected).
func set_solo(bus_idx: int, on: bool) -> void:
	if on:
		_solo[bus_idx] = true
	else:
		_solo.erase(bus_idx)
	_apply_mutes()


func is_solo(bus_idx: int) -> bool:
	return _solo.has(bus_idx)


func _apply_mutes() -> void:
	AudioServer.set_bus_mute(0, is_muted(0))
	for name in TRACKS + ["Keys"]:
		var idx := AudioServer.get_bus_index(name)
		var m := is_muted(idx) or (not _solo.is_empty() and not _solo.has(idx))
		AudioServer.set_bus_mute(idx, m)


func set_pan(bus_idx: int, pan: float) -> void:
	var fx := AudioServer.get_bus_effect(bus_idx, FX_PAN) as AudioEffectPanner
	if fx:
		fx.pan = clampf(pan, -1.0, 1.0)


func get_pan(bus_idx: int) -> float:
	var fx := AudioServer.get_bus_effect(bus_idx, FX_PAN) as AudioEffectPanner
	return fx.pan if fx else 0.0


## Reverb send, 0..0.6.
func set_reverb(bus_idx: int, wet: float) -> void:
	var fx := AudioServer.get_bus_effect(bus_idx, FX_REVERB) as AudioEffectReverb
	if fx:
		fx.wet = clampf(wet, 0.0, 0.6)
		AudioServer.set_bus_effect_enabled(bus_idx, FX_REVERB, fx.wet > 0.001)


func get_reverb(bus_idx: int) -> float:
	var fx := AudioServer.get_bus_effect(bus_idx, FX_REVERB) as AudioEffectReverb
	if fx == null or not AudioServer.is_bus_effect_enabled(bus_idx, FX_REVERB):
		return 0.0
	return fx.wet


func set_locut(bus_idx: int, on: bool) -> void:
	AudioServer.set_bus_effect_enabled(bus_idx, FX_LOCUT, on)


func get_locut(bus_idx: int) -> bool:
	return AudioServer.get_bus_effect_count(bus_idx) > FX_LOCUT and AudioServer.is_bus_effect_enabled(bus_idx, FX_LOCUT)
