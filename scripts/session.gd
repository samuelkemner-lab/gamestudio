class_name Session
extends Node
## One studio session: rapper arrives → you cook a beat → record takes → rating → payout.

signal state_changed(state: int)
signal take_judged(result: Dictionary)
signal finished(summary: Dictionary)

enum State { IDLE, ARRIVING, WAITING, RECORDING, REVIEW, LEAVING }

const DOOR := Vector3(-1.2, 0, 2.2)
const PATH_IN: Array[Vector3] = [Vector3(-0.9, 0, 1.4), Vector3(0.25, 0, 0.55), Vector3(0.95, 0, -0.45), Vector3(1.45, 0, -1.12)]
const MIC := Vector3(1.4, 0, -2.2)
const TAKE_STEPS := 32
const FLOWS := {
	"Boom bap": [0, 2, 3, 4, 6, 8, 10, 11, 12, 14],
	"Emo / autotune": [0, 3, 6, 8, 11, 14],
	"Drill": [0, 1, 3, 4, 6, 7, 9, 10, 12, 13, 15],
}

var state := State.IDLE
var rapper := {}
var npc: NPC
var takes_left := 0
var takes_done := 0
var best := {}
var last := {}
var easy_mode := true

var _world: Node3D
var _seq: Sequencer
var _gs: GameState
var _take_steps := 0
var _wait_timer := 0.0


func setup(world: Node3D, seq: Sequencer, gs: GameState) -> void:
	_world = world
	_seq = seq
	_gs = gs
	if AudioServer.get_bus_index("Vocal") == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Vocal")
		AudioServer.set_bus_send(idx, "Master")
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.35
		rev.wet = 0.18
		AudioServer.add_bus_effect(idx, rev)
	_seq.step_changed.connect(_on_step)


func is_active() -> bool:
	return state != State.IDLE


func can_book(r: Dictionary) -> bool:
	return state == State.IDLE and _gs.street_cred >= int(r.min_cred)


func book(r: Dictionary) -> void:
	if not can_book(r):
		return
	rapper = r
	takes_left = int(r.patience)
	takes_done = 0
	best = {}
	last = {}
	npc = NPC.new()
	npc.name = "Rapper"
	_world.add_child(npc)
	npc.setup(r)
	npc.voice.bus = "Vocal"
	npc.global_position = DOOR
	npc.walk_path(PATH_IN)
	npc.arrived.connect(_on_arrived, CONNECT_ONE_SHOT)
	_set_state(State.ARRIVING)


func brief() -> String:
	if rapper.is_empty():
		return ""
	return rapper.brief_easy if easy_mode else rapper.brief_pro


func record_take() -> bool:
	if not (state == State.WAITING or state == State.REVIEW) or takes_left <= 0:
		return false
	takes_left -= 1
	takes_done += 1
	_take_steps = 0
	npc.face(MIC)
	npc.say(rapper.lines.recording, 2.5)
	npc.set_rapping(true)
	_set_state(State.RECORDING)
	_seq.stop()
	_seq.play()
	return true


func _on_step(step: int) -> void:
	if state != State.RECORDING or step < 0:
		return
	_take_steps += 1
	var flow: Array = FLOWS.get(rapper.style, FLOWS["Boom bap"])
	if step in flow and _take_steps > 1:
		npc.rap_syllable()
	if _take_steps >= TAKE_STEPS:
		end_take()


func end_take() -> void:
	if state != State.RECORDING:
		return
	_seq.stop()
	npc.set_rapping(false)
	last = Judge.evaluate(_seq, rapper)
	if best.is_empty() or last.score > best.score:
		best = last
	var stars: int = last.stars
	if stars >= 4:
		npc.say(rapper.lines.great, 4.5)
		npc.play("emote-yes")
	elif stars == 3:
		npc.say(rapper.lines.ok, 4.5)
	else:
		npc.say(rapper.lines.bad, 4.5)
		npc.play("emote-no")
	take_judged.emit(last)
	if takes_left <= 0 and int(best.stars) <= 2:
		_storm_out()
	else:
		_set_state(State.REVIEW)


## Accept the best take: get paid, release the track.
func finish() -> Dictionary:
	if state != State.REVIEW or best.is_empty():
		return {}
	var stars: int = best.stars
	var rw := Judge.reward(rapper, stars)
	_gs.add(rw.money, rw.rep, rw.cred)
	_gs.record_track(rapper.id, stars, best.score)
	npc.say(rapper.lines.pay, 3.5)
	var summary := {
		"rapper": rapper, "stars": stars, "score": best.score, "notes": best.notes,
		"money": rw.money, "tip": rw.tip, "rep": rw.rep, "cred": rw.cred, "stormed_out": false,
		"takes": takes_done,
	}
	_leave()
	finished.emit(summary)
	return summary


func _storm_out() -> void:
	npc.say(rapper.lines.angry, 4.0)
	_gs.add(0, -2, 0)
	var summary := {
		"rapper": rapper, "stars": int(best.stars), "score": int(best.score), "notes": best.notes,
		"money": 0, "tip": 0, "rep": -2, "cred": 0, "stormed_out": true, "takes": takes_done,
	}
	_leave()
	finished.emit(summary)


func _leave() -> void:
	_set_state(State.LEAVING)
	var back: Array[Vector3] = []
	for i in range(PATH_IN.size() - 2, -1, -1):
		back.append(PATH_IN[i])
	back.append(DOOR)
	var leaving := npc
	get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(leaving):
			leaving.walk_path(back)
			leaving.arrived.connect(func():
				leaving.queue_free()
				if npc == leaving:
					npc = null
					rapper = {}
					_set_state(State.IDLE), CONNECT_ONE_SHOT))


func _on_arrived() -> void:
	npc.face(MIC + Vector3(-1.6, 0, 1.2))  # half-turn towards the desk
	npc.say(rapper.lines.hello, 4.5)
	_wait_timer = 25.0
	_set_state(State.WAITING)


func _process(delta: float) -> void:
	if state == State.WAITING:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_wait_timer = 30.0
			npc.say(rapper.lines.wait, 3.5)


func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)
