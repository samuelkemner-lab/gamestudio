class_name Chaos
extends Node
## Noise meter → neighbours bang on the wall → cops at the door with a fine.

signal toast(text: String)
signal police_visit(fine: int)
signal pc_crash

const WARN_AT := 60.0
const POLICE_AT := 100.0
const FINE := 40
const RISE := 1.5  # per second at full master volume
const FALL := 5.0

var _seq: Sequencer
var _gs: GameState
var _world: Node3D
var _warned := false
var _cop: NPC
var _thump: AudioStreamPlayer
var enabled := true
var crashes_enabled := true
var _edits_unsaved := 0
var _restoring := false


func setup(world: Node3D, seq: Sequencer, gs: GameState) -> void:
	_world = world
	_seq = seq
	_gs = gs
	_thump = AudioStreamPlayer.new()
	_thump.stream = VoiceSynth.thump()
	_thump.volume_db = 4.0
	add_child(_thump)
	seq.pattern_changed.connect(_on_edit)


## Old laptop: the longer you work without saving, the likelier LOOPR crashes.
func _on_edit() -> void:
	if _restoring or not enabled or not crashes_enabled:
		return
	if not _seq.dirty:
		_edits_unsaved = 0
		return
	_edits_unsaved += 1
	if _edits_unsaved >= 14 and randf() < 0.025:
		crash()


func crash() -> void:
	_restoring = true
	_seq.stop()
	_seq.restore_saved()
	_restoring = false
	_edits_unsaved = 0
	pc_crash.emit()


func _process(delta: float) -> void:
	if not enabled or _cop:
		return
	var master := 0.0 if AudioServer.is_bus_mute(0) else _seq.get_volume(0)
	if _seq.playing and master > 0.3:
		var rise := RISE * (0.6 if _gs.has("foam") else 1.0)
		_gs.noise = minf(_gs.noise + rise * master * master * delta, POLICE_AT)
	else:
		_gs.noise = maxf(_gs.noise - FALL * delta, 0.0)
	if _gs.noise >= WARN_AT and not _warned:
		_warned = true
		bang()
		toast.emit("*BANG BANG* Neighbour: \"TURN IT DOWN! It's 3 AM!\"")
	elif _gs.noise < WARN_AT - 20.0:
		_warned = false
	if _gs.noise >= POLICE_AT:
		call_police()


func bang() -> void:
	_thump.play()
	get_tree().create_timer(0.28).timeout.connect(_thump.play)
	get_tree().create_timer(0.56).timeout.connect(_thump.play)


func call_police() -> void:
	if _cop:
		return
	_seq.stop()
	bang()
	toast.emit("*KNOCK KNOCK* \"Police! Open up!\"")
	_cop = NPC.new()
	_cop.name = "Cop"
	_world.add_child(_cop)
	_cop.setup(Rappers.COP)
	_cop.global_position = Session.DOOR
	var path: Array[Vector3] = [Vector3(-0.9, 0, 1.5), Vector3(-0.4, 0, 0.6)]
	_cop.walk_path(path)
	_cop.arrived.connect(_cop_arrived, CONNECT_ONE_SHOT)


func _cop_arrived() -> void:
	_cop.face(Vector3(-0.7, 0, -1.5))
	_cop.say("Noise complaint, kid. That's a €%d fine. Keep it down." % FINE, 5.0)
	_gs.add(-FINE, -1, 1)  # a little street cred for getting the cops called
	police_visit.emit(FINE)
	get_tree().create_timer(5.0).timeout.connect(func():
		var back: Array[Vector3] = [Vector3(-0.9, 0, 1.5), Session.DOOR]
		_cop.walk_path(back)
		_cop.arrived.connect(func():
			_cop.queue_free()
			_cop = null
			_gs.noise = 0.0, CONNECT_ONE_SHOT))
