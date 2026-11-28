class_name TimeTrial
extends Node3D
## KADE RUN: an e-step time trial on the Zuidkade. Rolling start at the east end of the quay, west along the water,
## up the side street and west down the main road (traffic included). Beat the local riders for cash and cred.
## Lives inside the CityBuilder (local coordinates). Main connects the signals and pays out via `result()`.

signal started
signal gate_passed(index: int, total: int)
signal finished(time: float)
signal aborted(reason: String)
signal armed_up

const START := Vector3(58.0, 0, 37.2)
const GATES := [Vector3(40.0, 0, 37.2), Vector3(20.0, 0, 32.0), Vector3(20.0, 0, 18.0), Vector3(20.0, 0, 2.0),
	Vector3(-10.0, 0, -2.5), Vector3(-50.0, 0, -2.5)]
const RADIUS := 3.6  # how close counts as "through"
const HALF := 2.8  # visual half width of a gate (clears the tram on the main road)
const MAX_TIME := 120.0
const RIVALS := [
	{"name": "Mo", "time": 36.0, "money": 15, "cred": 0, "rep": 0},
	{"name": "Jesse", "time": 28.0, "money": 30, "cred": 1, "rep": 0},
	{"name": "Bilal, the Kade King", "time": 21.0, "money": 75, "cred": 3, "rep": 2},
]

var player: Node3D
var running := false
var armed := false
var t := 0.0
var next := 0
var _gates: Array[Node3D] = []
var _board: MeshInstance3D
var _cool := 0.0


func build(b: RoomBuilder) -> void:
	name = "KadeRun"
	# start gate with a banner and the leaderboard
	var start := Node3D.new()
	start.position = START
	start.rotation.y = PI / 2.0  # gate faces west, along the quay
	add_child(start)
	var post := b.mat(Color("1d1f24"), 0.4, "")
	for side in [-1.0, 1.0]:
		b.part(start, b.box(Vector3(0.18, 3.2, 0.18)), Vector3(side * 2.6, 1.6, 0), post)
	b.part(start, b.box(Vector3(5.6, 0.7, 0.08)), Vector3(0, 3.1, 0), b.mat(Color("101216"), 0.6, ""))
	b.text3d(start, "KADE RUN", Vector3(0, 3.15, 0.06), Color("3ddc84"), 0.006, Vector3.ZERO, 3.0)
	b.text3d(start, "KADE RUN", Vector3(0, 3.15, -0.06), Color("3ddc84"), 0.006, Vector3(0, 180, 0), 3.0)
	# chequered start line on the stones
	for k in 8:
		b.part(start, b.box(Vector3(0.6, 0.02, 0.3)), Vector3(-2.1 + k * 0.6, 0.13, 0.15 if k % 2 == 0 else -0.15), b.glow(Color("e8e8e8") if k % 2 == 0 else Color("202020"), 0.4))
	var info := b.solid(Vector3(1.0, 1.4, 0.3), START + Vector3(0, 0.7, -2.9), "trial", "KADE RUN  ·  e-step time trial")
	info.set_meta("trial", self)
	b.part(self, b.box(Vector3(1.0, 1.4, 0.12)), START + Vector3(0, 0.9, -2.9), b.mat(Color("15171c"), 0.5, ""))
	_board = b.text3d(self, "", START + Vector3(0, 1.0, -2.83), Color("d8ffe6"), 0.0024, Vector3(0, 0, 0), 2.0)
	# checkpoint gates: two glowing posts and a bar, turned across the route
	var prev := START
	for i in GATES.size():
		var p: Vector3 = GATES[i]
		var g := Node3D.new()
		g.position = p
		var dir := (p - prev)
		g.rotation.y = atan2(dir.x, dir.z)
		var last := i == GATES.size() - 1
		var col := Color("ff3aa0") if last else Color("3ab8ff")
		for side in [-1.0, 1.0]:
			b.part(g, b.box(Vector3(0.16, 2.8, 0.16)), Vector3(side * HALF, 1.4, 0), b.glow(col, 2.5))
		b.part(g, b.box(Vector3(HALF * 2.0, 0.12, 0.12)), Vector3(0, 2.8, 0), b.glow(col, 2.5))
		if last:
			b.text3d(g, "FINISH", Vector3(0, 3.2, 0), col, 0.005, Vector3(0, 180, 0), 3.0)
		g.visible = false
		add_child(g)
		_gates.append(g)
		prev = p
	update_board(null)


func update_board(gs: GameState) -> void:
	var lines := ["KADE RUN"]
	for r in RIVALS:
		lines.append("%s  %.1f s" % [str(r.name).get_slice(",", 0), r.time])
	var best := float(gs.records.get("trial_best", 0.0)) if gs else 0.0
	lines.append("YOU  %s" % ("%.1f s" % best if best > 0.0 else "--"))
	lines.append("ride through the gate")
	(_board.mesh as TextMesh).text = "\n".join(lines)


func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	_cool = maxf(_cool - delta, 0.0)
	var riding: bool = player.get("riding") != null
	var lp := to_local(player.global_position)
	lp.y = 0.0
	if not running:
		var d := lp.distance_to(START)
		if riding and d < 3.0 and _cool <= 0.0:
			if not armed:
				armed_up.emit()
			armed = true
		elif armed and (not riding or d > 6.0):
			armed = false
		elif armed and riding and d > 3.0 and (lp - START).dot(GATES[0] - START) > 0.0:
			begin()
		return
	if not riding:
		abort("Off the step: run over. Ride through the start gate to try again.")
		return
	t += delta
	if t > MAX_TIME:
		abort("Two minutes and still not there. Run abandoned.")
		return
	if lp.distance_to(GATES[next]) < RADIUS:
		_gates[next].visible = false
		next += 1
		if next >= GATES.size():
			running = false
			_cool = 4.0
			finished.emit(t)
			return
		_gates[next].visible = true
		gate_passed.emit(next, GATES.size())


func begin() -> void:
	armed = false
	running = true
	t = 0.0
	next = 0
	for g in _gates:
		g.visible = false
	_gates[0].visible = true
	started.emit()


func abort(reason: String) -> void:
	running = false
	armed = false
	_cool = 3.0
	for g in _gates:
		g.visible = false
	aborted.emit(reason)


## Score a finished run: personal best and first-time wins over each rival (paid once).
static func result(gs: GameState, time: float) -> Dictionary:
	var best := float(gs.records.get("trial_best", 0.0))
	var pb := best <= 0.0 or time < best
	if pb:
		gs.records.trial_best = snappedf(time, 0.01)
	var beaten: Array = gs.records.get("trial_beaten", [])
	var new_wins: Array = []
	var money := 0
	var cred := 0
	var rep := 0
	var place := RIVALS.size() + 1
	for i in RIVALS.size():
		var r: Dictionary = RIVALS[i]
		if time < float(r.time):
			place = mini(place, RIVALS.size() - i)
			if not r.name in beaten:
				beaten.append(r.name)
				new_wins.append(r.name)
				money += int(r.money)
				cred += int(r.cred)
				rep += int(r.rep)
	gs.records.trial_beaten = beaten
	gs.stats.trial_runs = int(gs.stats.get("trial_runs", 0)) + 1
	gs.add_xp(5)
	gs.add(money, rep, cred)
	return {"time": time, "pb": pb, "place": place, "new_wins": new_wins, "money": money, "cred": cred, "rep": rep}
