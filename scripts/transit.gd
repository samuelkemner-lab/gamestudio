class_name Transit
extends RoomBuilder
## Public transport: one underground metro line with 4 stations and tram line 4 on the street.
##
## Metro: one platform set is built once and re-dressed per station (name boards, accent colour,
## departure board). Trains run on a timer: arrive from the west tunnel, doors open, dwell, close,
## leave east. Board with E at the open doors → pick a stop → you sit down, the doors close, the
## train pulls out, the tunnel lights rush past; a short fade later you roll into the next station
## and step out onto the platform.
## Tram: the line-4 tram stops at each street stop (CityBuilder._tram_stop). Board → sit → it drives
## off down the street → fade → the tram of the destination district pulls into its stop.

signal ride_started(dest: String)
signal ride_finished(dest: String)

const STATIONS := {
	"zuidkade": {"name": "Zuidkade", "accent": Color("1fb5a5"), "tram": true},
	"centraal": {"name": "Centraal", "accent": Color("e3261c"), "tram": true},
	"markt": {"name": "Marktplein", "accent": Color("f2b630"), "tram": true},
	"haven": {"name": "Havenkwartier", "accent": Color("2f7de1"), "tram": false},
}
const LINE_ORDER := ["zuidkade", "centraal", "markt", "haven"]
const FARE := 2
const PLAT_HALF := 32.0  # platform runs x -32..32
const TRAIN_HALF := 19.8
const V_IN := 16.0  # m/s entering the station
const DECEL := 2.0
const ACCEL := 2.3
const DWELL := 16.0

var main: Node  # main.gd
var station := "zuidkade"  # which station the platform is dressed as
var train: Node3D
var train_doors: Array = []
var board_body: StaticBody3D
var exit_body: StaticBody3D
var state := "away"  # away | arriving | dwell | departing
var t := 0.0
var next_in := 6.0
var door_f := 0.0
var ride := {}  # {kind: metro|tram, dest, phase, ...}
var _accent_mats: Array[StandardMaterial3D] = []
var _name_labels: Array[MeshInstance3D] = []
var _board_label: MeshInstance3D
var _train_dest: MeshInstance3D
var _rumble: AudioStreamPlayer3D
var _chime: AudioStreamPlayer3D
var _hum: AudioStreamPlayer
var _arrive_from := -64.0
var _arr_phase := "brake"


func build_station() -> void:
	name = "Metro"
	_platform()
	_tunnels()
	_train()
	dress("zuidkade")


# ================= Platform =================

func _platform() -> void:
	var g := group("Platform")
	var tile := mat(Color("d9d6cf"), 0.35, "plaster", 1.5)
	var dark := mat(Color("1c1d22"), 0.8, "")
	var concrete := mat(Color("4a4b52"), 0.85, "")
	# platform slab + floor collision (top at y = 0)
	part(g, box(Vector3(PLAT_HALF * 2.0, 1.25, 7.2)), Vector3(0, -0.625, 5.5), mat(Color("8d8a86"), 0.6, "plaster", 2.0))
	solid(Vector3(PLAT_HALF * 2.0 + 4.0, 1.0, 7.2), Vector3(0, -0.5, 5.5))
	part(g, box(Vector3(PLAT_HALF * 2.0, 0.02, 0.45)), Vector3(0, 0.011, 2.15), mat(Color("e8c21f"), 0.6, ""))
	part(g, box(Vector3(PLAT_HALF * 2.0, 0.015, 0.4)), Vector3(0, 0.008, 2.6), mat(Color("b8b4aa"), 0.8, ""))
	# track bed, rails, safety wall on the far side
	part(g, box(Vector3(PLAT_HALF * 2.0, 0.1, 6.0)), Vector3(0, -1.3, -1.0), concrete)
	var rail := mat(Color("9a9ca2"), 0.25, "")
	rail.metallic = 0.85
	for rz in [-0.72, 0.72]:
		part(g, box(Vector3(900, 0.12, 0.08)), Vector3(-150, -1.17, rz), rail)
	solid(Vector3(PLAT_HALF * 2.0 + 4.0, 3.0, 0.4), Vector3(0, 0.3, 1.65))  # can't jump onto the track
	# walls + ceiling
	part(g, box(Vector3(PLAT_HALF * 2.0, 5.6, 0.3)), Vector3(0, 1.5, -3.3), tile)
	part(g, box(Vector3(PLAT_HALF * 2.0, 4.6, 0.3)), Vector3(0, 2.3, 9.2), tile)
	solid(Vector3(PLAT_HALF * 2.0, 5.0, 0.4), Vector3(0, 2.5, 9.3))
	part(g, box(Vector3(PLAT_HALF * 2.0, 0.3, 12.8)), Vector3(0, 4.45, 2.9), dark)
	for ex in [-PLAT_HALF - 0.2, PLAT_HALF + 0.2]:
		part(g, box(Vector3(0.4, 4.6, 7.2)), Vector3(ex, 2.3, 5.5), tile)
		solid(Vector3(0.4, 5.0, 7.2), Vector3(ex, 2.5, 5.5))
	# accent stripes (station colour) on both walls
	for z in [-3.12, 9.02]:
		var am := mat(Color.WHITE, 0.5, "")
		_accent_mats.append(am)
		part(g, box(Vector3(PLAT_HALF * 2.0, 0.5, 0.04)), Vector3(0, 2.6, z), am)
	# columns, light strips, benches
	for x in range(-28, 29, 8):
		part(g, box(Vector3(0.6, 4.3, 0.6)), Vector3(x, 2.15, 6.0), mat(Color("2a2c33"), 0.5, ""))
		solid(Vector3(0.6, 4.3, 0.6), Vector3(x, 2.15, 6.0))
	for z in [3.0, 7.6]:
		part(g, box(Vector3(PLAT_HALF * 2.0 - 2.0, 0.06, 0.3)), Vector3(0, 4.27, z), glow(Color("eef2ff"), 2.4))
	for x in [-20.0, -4.0, 12.0]:
		part(g, box(Vector3(2.4, 0.08, 0.5)), Vector3(x, 0.46, 8.6), mat(Color("8a8f98"), 0.3, ""))
		part(g, box(Vector3(2.4, 0.5, 0.06)), Vector3(x, 0.75, 8.85), mat(Color("8a8f98"), 0.3, ""))
		solid(Vector3(2.4, 0.5, 0.6), Vector3(x, 0.25, 8.6))
	for x in [-24.0, 0.0, 24.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(x, 3.6, 5.0)
		l.light_color = Color("e8eeff")
		l.light_energy = 1.6
		l.omni_range = 14.0
		g.add_child(l)
	# station name boards on both walls
	for x in [-24.0, -8.0, 8.0, 24.0]:
		for side in [[-3.1, 0.0], [9.0, 180.0]]:
			var z: float = side[0]
			var ry: float = side[1]
			var dz := 0.06 if ry == 0.0 else -0.06
			part(g, box(Vector3(4.2, 0.8, 0.05)), Vector3(x, 1.9, z + dz), mat(Color("15161b"), 0.5, ""))
			_name_labels.append(text3d(g, "ZUIDKADE", Vector3(x, 1.9, z + dz * 2.0), Color.WHITE, 0.006, Vector3(0, ry, 0), 1.2))
	# advertising light boxes on the track wall between the name boards
	var ads := [Color("ff5a8a"), Color("3fc0ff"), Color("ffd060")]
	for i in 3:
		var ax: float = [-16.0, 0.0, 16.0][i]
		part(g, box(Vector3(3.0, 1.9, 0.08)), Vector3(ax, 1.75, -3.08), mat(Color("15161b"), 0.5, ""))
		part(g, box(Vector3(2.8, 1.7, 0.04)), Vector3(ax, 1.75, -3.02), glow(ads[i].lerp(Color.WHITE, 0.25), 0.7))
		part(g, box(Vector3(1.6, 0.25, 0.02)), Vector3(ax, 1.35, -2.99), glow(Color("101018"), 0.0))
	# hanging departure board
	part(g, box(Vector3(5.2, 0.9, 0.12)), Vector3(0, 3.55, 4.2), mat(Color("0a0a0c"), 0.5, ""))
	for hx in [-2.2, 2.2]:
		part(g, cyl(0.02, 0.6), Vector3(hx, 4.1, 4.2), mat(Color("444"), 0.4, ""))
	_board_label = text3d(g, "", Vector3(0, 3.55, 4.28), Color("ffb547"), 0.0032, Vector3.ZERO, 3.0)
	# exit: escalator up through the back wall + check-in poles
	var ex := 26.0
	part(g, box(Vector3(2.4, 0.12, 6.5)), Vector3(ex, 2.0, 11.6), mat(Color("6c7078"), 0.3, ""), Vector3(36, 0, 0))
	part(g, box(Vector3(2.8, 4.8, 0.2)), Vector3(ex, 2.4, 9.38), mat(Color("0d0d10"), 0.9, ""))
	part(g, box(Vector3(2.6, 0.12, 0.2)), Vector3(ex, 4.1, 9.0), glow(Color("2fd06b"), 3.0))
	text3d(g, "UITGANG  ·  EXIT", Vector3(ex, 4.1, 8.88), Color.WHITE, 0.0026, Vector3(0, 180, 0), 1.2)
	for px in [ex - 1.6, ex + 1.6]:
		part(g, box(Vector3(0.18, 1.1, 0.18)), Vector3(px, 0.55, 7.6), mat(Color("c9ccd2"), 0.3, ""))
		part(g, box(Vector3(0.16, 0.2, 0.05)), Vector3(px, 1.05, 7.5), glow(Color("2fd06b"), 1.6))
	exit_body = solid(Vector3(2.8, 2.6, 1.2), Vector3(ex, 1.3, 8.6), "metro_out", "Exit to the street")
	# ambience: station hum
	_hum = AudioStreamPlayer.new()
	_hum.stream = AmbienceSynth.city(6.0)
	_hum.pitch_scale = 0.6
	_hum.volume_db = -22.0
	add_child(_hum)


## Tunnel tubes on both sides of the platform with lights every few metres (they rush past when riding).
func _tunnels() -> void:
	var g := group("Tunnels")
	var wall := mat(Color("2a2b30"), 0.95, "")
	for span in [[-640.0, -PLAT_HALF], [PLAT_HALF, 320.0]]:
		var x0: float = span[0]
		var x1: float = span[1]
		var len := x1 - x0
		var cx := (x0 + x1) / 2.0
		part(g, box(Vector3(len, 0.2, 6.2)), Vector3(cx, -1.4, -0.4), wall)
		part(g, box(Vector3(len, 0.2, 6.2)), Vector3(cx, 3.6, -0.4), wall)
		part(g, box(Vector3(len, 5.0, 0.2)), Vector3(cx, 1.1, -3.4), wall)
		part(g, box(Vector3(len, 5.0, 0.2)), Vector3(cx, 1.1, 2.6), wall)
		var lights: Array[Transform3D] = []
		var x := x0 + 4.0
		while x < x1:
			lights.append(Transform3D(Basis().scaled(Vector3(14.0, 0.3, 4.0)), Vector3(x, 2.2, -3.28)))
			lights.append(Transform3D(Basis().scaled(Vector3(14.0, 0.3, 4.0)), Vector3(x + 5.0, 2.2, 2.48)))
			x += 10.0
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box(Vector3(0.05, 0.1, 0.03))
		mm.instance_count = lights.size()
		for i in lights.size():
			mm.set_instance_transform(i, lights[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = glow(Color("ffe2b0"), 5.0)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mmi)
		for cz in [-3.25, 2.45]:
			part(g, cyl(0.04, len), Vector3(cx, 0.6, cz), mat(Color("111114"), 0.6, ""), Vector3(0, 0, 90))


# ================= Train =================

func _train() -> void:
	train = Node3D.new()
	train.name = "Train"
	add_child(train)
	var body := mat(Color("b9bec6"), 0.3, "")
	body.metallic = 0.6
	var stripe := mat(Color("e3261c"), 0.45, "")
	for k in 2:
		var holder := Node3D.new()
		holder.position = Vector3(0, 0, -9.9 + k * 19.8)
		train.add_child(holder)
		var car := carriage(holder, 19.4, 2.8, 2.35, 1.15, body, stripe, [-6.0, 0.0, 6.0], Color("eef2ff"))
		train_doors.append_array(car.doors)
	# cab front (+Z local = +X world) and rear
	for e in [-1.0, 1.0]:
		var cz: float = e * 19.9
		part(train, box(Vector3(2.8, 1.3, 0.5)), Vector3(0, 1.8, cz), body)
		part(train, box(Vector3(2.6, 1.2, 0.08)), Vector3(0, 2.9, cz + e * 0.08), mat(Color("08090c"), 0.05, ""), Vector3(e * -14.0, 0, 0))
		for hx in [-0.95, 0.95]:
			part(train, sphere(0.1), Vector3(hx, 1.55, cz + e * 0.27), glow(Color("fff3dc") if e > 0 else Color("ff2a1a"), 5.0))
	part(train, box(Vector3(1.8, 0.25, 0.05)), Vector3(0, 3.35, 20.18), mat(Color("050505"), 0.5, ""))
	_train_dest = text3d(train, "", Vector3(0, 3.35, 20.22), Color("ffb547"), 0.0032, Vector3.ZERO, 3.0)
	var hl := SpotLight3D.new()
	hl.position = Vector3(0, 1.6, 20.4)
	hl.rotation_degrees = Vector3(-4, 180, 0)
	hl.light_color = Color("fff3dc")
	hl.light_energy = 6.0
	hl.spot_range = 40.0
	hl.spot_angle = 22.0
	train.add_child(hl)
	train.rotation_degrees.y = 90.0
	train.position = Vector3(-400, -1.15, 0)
	train.visible = false
	set_doors(train_doors, 0.0)
	# E at the open doors (platform side = world +Z = local -X)
	board_body = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.4, 2.4, 38.0)
	col.shape = sh
	board_body.add_child(col)
	board_body.position = Vector3(-2.1, 2.35, 0)
	board_body.collision_layer = 0
	board_body.set_meta("interact", "metro_board")
	board_body.set_meta("label", "Board the metro")
	train.add_child(board_body)
	_rumble = AudioStreamPlayer3D.new()
	_rumble.stream = AmbienceSynth.rumble()
	_rumble.unit_size = 14.0
	_rumble.volume_db = -60.0
	train.add_child(_rumble)
	_chime = AudioStreamPlayer3D.new()
	_chime.stream = AmbienceSynth.chime()
	_chime.position = Vector3(-1.4, 2.6, 0)
	train.add_child(_chime)


# ================= Dressing =================

static func station_name(id: String) -> String:
	return str(STATIONS.get(id, {}).get("name", id))


## Next station along the line after `id` (the line runs both ways; trains here head away from Zuidkade
## until Havenkwartier, then back).
func terminus() -> String:
	return "Zuidkade" if station == "haven" else "Havenkwartier"


func dress(id: String) -> void:
	station = id
	var acc: Color = STATIONS[id].accent
	for m in _accent_mats:
		m.albedo_color = acc
	for l in _name_labels:
		(l.mesh as TextMesh).text = station_name(id).to_upper()
	(_train_dest.mesh as TextMesh).text = "→ " + terminus().to_upper()
	_update_board()


func _update_board() -> void:
	var txt := ""
	match state:
		"away":
			txt = "%s     %d min" % [terminus().to_upper(), maxi(int(ceil(next_in / 10.0)), 1)]
		"arriving":
			txt = "%s     ARRIVING" % terminus().to_upper()
		"dwell":
			txt = "%s     BOARDING" % terminus().to_upper()
		"departing":
			txt = "%s     DEPARTED" % terminus().to_upper()
	(_board_label.mesh as TextMesh).text = txt


## The player just came down the escalator: make sure a train shows up soon.
func player_arrived() -> void:
	if state == "away":
		next_in = minf(next_in, 6.0)
	if is_inside_tree():
		_hum.play()


func player_left() -> void:
	_hum.stop()


func stops_between(a: String, b: String) -> int:
	return absi(LINE_ORDER.find(a) - LINE_ORDER.find(b))


# ================= Metro cycle =================

func _process(delta: float) -> void:
	_cycle(delta)
	_ride_update(delta)


func _cycle(delta: float) -> void:
	t += delta
	match state:
		"away":
			next_in -= delta
			if next_in <= 0.0 and (ride.is_empty() or ride.kind != "metro"):
				_start_arrival(1)
		"arriving":
			# cruise through the tunnel, then brake into the platform
			var v := V_IN
			if _arr_phase == "cruise":
				var x := _arrive_from + V_IN * t
				if x >= -64.0:
					x = -64.0
					_arr_phase = "brake"
					t = 0.0
				train.position.x = x
			else:
				var tb := minf(t, V_IN / DECEL)
				train.position.x = -64.0 + V_IN * tb - 0.5 * DECEL * tb * tb
				v = maxf(V_IN - DECEL * t, 0.0)
				if t >= V_IN / DECEL:
					train.position.x = 0.0
					state = "dwell"
					t = 0.0
					if train.is_inside_tree():
						_chime.play()
			_set_rumble(v)
		"dwell":
			var dwell: float = DWELL if ride.is_empty() else (3.0 if ride.get("phase", "") == "seated" else DWELL)
			door_f = move_toward(door_f, 1.0 if t < dwell - 1.6 else 0.0, delta * 1.3)
			set_doors(train_doors, door_f, -1.0)
			board_body.collision_layer = 1 if door_f > 0.6 and t < dwell - 1.6 else 0
			_set_rumble(0.0)
			if absf(t - (dwell - 1.6)) < delta and train.is_inside_tree():
				_chime.play()
			if t >= dwell:
				door_f = 0.0
				set_doors(train_doors, 0.0)
				state = "departing"
				t = 0.0
		"departing":
			train.position.x = 0.5 * ACCEL * t * t
			_set_rumble(ACCEL * t)
			if t > 10.0:
				train.visible = false
				state = "away"
				next_in = randf_range(14.0, 24.0)
				_set_rumble(0.0)
	if Engine.get_process_frames() % 15 == 0:
		_update_board()


func _start_arrival(stops: int) -> void:
	train.visible = true
	_arrive_from = -64.0 - V_IN * (1.5 + 2.2 * (stops - 1))
	_arr_phase = "cruise"
	train.position.x = _arrive_from
	state = "arriving"
	t = 0.0
	door_f = 0.0
	set_doors(train_doors, 0.0)


func _set_rumble(v: float) -> void:
	_rumble.pitch_scale = 0.5 + v / 18.0
	_rumble.volume_db = lerpf(-60.0, -6.0, clampf(v / 10.0, 0.0, 1.0)) if v > 0.2 else -60.0
	if v > 0.2 and not _rumble.playing and _rumble.is_inside_tree():
		_rumble.play()


# ================= Rides =================

func is_riding() -> bool:
	return not ride.is_empty()


## Sit down in the metro (doors are open) heading for `dest`.
func board_metro(dest: String) -> void:
	var p = main.player
	ride = {"kind": "metro", "dest": dest, "phase": "seated", "stops": stops_between(station, dest)}
	t = minf(t, 0.5) if state == "dwell" else t
	var seat_local := Vector3(0.95, 1.15, 3.0)  # far-side bench, looking out at the platform
	p.enter_pose("seat", train.to_global(seat_local), _yaw_facing(train.global_basis * Vector3(-1, 0, 0)), 1.12)
	p.pose_lock = true
	ride.seat = seat_local
	ride_started.emit(dest)


## Sit down in a line-4 tram standing at its stop.
func board_tram(entry: Dictionary, builder: CityBuilder, dest: String) -> void:
	var p = main.player
	var tram: Node3D = entry.node
	var seat_local := Vector3(0.95, 0.42, -3.2)
	ride = {"kind": "tram", "dest": dest, "phase": "seated", "entry": entry, "builder": builder, "seat": seat_local, "start_x": tram.position.x, "t": 0.0}
	entry.dwell = minf(float(entry.dwell), 2.4)
	p.enter_pose("seat", tram.to_global(seat_local), _yaw_facing(tram.global_basis * Vector3(-1, 0, 0)), 1.15)
	p.pose_lock = true
	ride_started.emit(dest)


func _yaw_facing(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _ride_update(delta: float) -> void:
	if ride.is_empty() or main == null:
		return
	var p = main.player
	match ride.kind:
		"metro":
			p.global_position = train.to_global(ride.seat)
			p.rotation.y = _yaw_facing(train.global_basis * Vector3(-1, 0, 0))
			if ride.phase == "seated" and state == "departing" and t > 5.6:
				ride.phase = "switching"
				main.fade_through(_metro_switch)
			elif ride.phase == "arriving" and state == "dwell" and door_f > 0.85:
				_metro_step_out()
		"tram":
			var e: Dictionary = ride.entry
			var tram: Node3D = e.node
			p.global_position = tram.to_global(ride.seat)
			p.rotation.y = _yaw_facing(tram.global_basis * Vector3(-1, 0, 0))
			ride.t = float(ride.t) + delta
			if ride.phase == "seated" and (absf(tram.position.x - float(ride.start_x)) > 48.0 or float(ride.t) > 16.0):
				ride.phase = "switching"
				main.fade_through(_tram_switch)
			elif ride.phase == "arriving" and float(e.dwell) > 0.0 and float(e.door_f) > 0.85:
				_tram_step_out()


## Under the fade: re-dress the platform as the destination and roll the train in from the tunnel.
func _metro_switch() -> void:
	var stops: int = maxi(int(ride.stops), 1)
	dress(ride.dest)
	main.metro_arrive(ride.dest)
	_start_arrival(stops)
	ride.phase = "arriving"
	main.player.global_position = train.to_global(ride.seat)


func _metro_step_out() -> void:
	var p = main.player
	var dest: String = ride.dest
	# step out at the nearest door onto the platform, facing away from the train
	p.pose_lock = false
	p._pose_exit = to_global(Vector3(clampf(to_local(p.global_position).x, -14.0, 14.0), 0.05, 3.2))
	p.leave_pose()
	p.rotation.y = PI
	ride = {}
	ride_finished.emit(dest)


func _tram_switch() -> void:
	var dest: String = ride.dest
	var b: CityBuilder = main.go_tram_area(dest)
	var e: Dictionary = b.tram4
	var tram: Node3D = e.node
	tram.position.x = b.tram_stop_x - 46.0
	e.cur = 6.0
	e.dwell = 0.0
	e.served = false
	ride.entry = e
	ride.builder = b
	ride.phase = "arriving"
	main.player.global_position = tram.to_global(ride.seat)


func _tram_step_out() -> void:
	var p = main.player
	var b: CityBuilder = ride.builder
	var dest: String = ride.dest
	p.pose_lock = false
	p._pose_exit = b.to_global(Vector3(b.tram_stop_x + 2.0, 0.05, CityBuilder.ROAD_HW + 1.2))
	p.leave_pose()
	p.rotation.y = PI
	ride = {}
	ride_finished.emit(dest)


## Leaving everything (dawn): stand up and forget the ride.
func cancel_ride() -> void:
	if ride.is_empty():
		return
	main.player.pose_lock = false
	main.player.leave_pose()
	ride = {}


## Tests / skipping: finish the current ride instantly.
func skip_ride() -> void:
	if ride.is_empty():
		return
	if ride.kind == "metro":
		if ride.phase == "seated":
			_metro_switch()
		state = "dwell"
		t = 0.0
		train.position.x = 0.0
		door_f = 1.0
		_metro_step_out()
	else:
		if ride.phase == "seated":
			_tram_switch()
		var e: Dictionary = ride.entry
		(e.node as Node3D).position.x = ride.builder.tram_stop_x
		e.dwell = 10.0
		e.door_f = 1.0
		_tram_step_out()
