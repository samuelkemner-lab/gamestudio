class_name EStep
extends Node3D
## The e-step: a procedural kick-scooter you can park, ride and charge. While ridden, the player
## (player.gd, `riding`) drives it; this node follows the player, drains the battery, hums and lights up.
## `data` is GameState.estep (owned, battery, home, motor, big_battery).

const BASE_SPEED := 6.0  # m/s (±22 km/h)
const TUNED_SPEED := 8.5  # with the motor tune
const DEAD_SPEED := 1.5  # empty battery: kick-push
const DRAIN := 0.075  # % per metre (±1.3 km per charge); half with the big battery

var data: Dictionary
var body: StaticBody3D
var rider: Node3D
var speed := 0.0
var _motor: AudioStreamPlayer3D
var _bell: AudioStreamPlayer3D
var _light: SpotLight3D
var _wheels: Array[MeshInstance3D] = []
var _last := Vector3.ZERO


func _m(c: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _part(mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
	return mi


func build() -> void:
	name = "EStep"
	var frame := _m(Color("1d1f24"), 0.45, 0.6)
	var accent := _m(Color("ff3d7f"), 0.4)
	var rubber := _m(Color("0b0b0d"), 0.9)
	# deck (forward = -Z)
	var deck := BoxMesh.new()
	deck.size = Vector3(0.17, 0.05, 0.62)
	_part(deck, Vector3(0, 0.13, 0.02), frame)
	var grip := BoxMesh.new()
	grip.size = Vector3(0.15, 0.006, 0.5)
	_part(grip, Vector3(0, 0.158, 0.04), _m(Color("2a2a30"), 1.0))
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.175, 0.012, 0.5)
	_part(stripe, Vector3(0, 0.11, 0.02), accent)
	# wheels
	for z in [-0.33, 0.36]:
		var w := CylinderMesh.new()
		w.top_radius = 0.1
		w.bottom_radius = 0.1
		w.height = 0.05
		_wheels.append(_part(w, Vector3(0, 0.1, z), rubber, Vector3(0, 0, 90)))
	# rear fender + brake light
	var fender := BoxMesh.new()
	fender.size = Vector3(0.07, 0.015, 0.2)
	_part(fender, Vector3(0, 0.21, 0.38), frame, Vector3(-12, 0, 0))
	var rear := BoxMesh.new()
	rear.size = Vector3(0.05, 0.02, 0.01)
	var red := _m(Color("ff2020"))
	red.emission_enabled = true
	red.emission = Color("ff2020")
	red.emission_energy_multiplier = 2.5
	_part(rear, Vector3(0, 0.22, 0.48), red)
	# stem + handlebar
	var stem := CylinderMesh.new()
	stem.top_radius = 0.022
	stem.bottom_radius = 0.026
	stem.height = 1.0
	_part(stem, Vector3(0, 0.62, -0.38), frame, Vector3(-8, 0, 0))
	var bar := CylinderMesh.new()
	bar.top_radius = 0.016
	bar.bottom_radius = 0.016
	bar.height = 0.52
	_part(bar, Vector3(0, 1.1, -0.45), frame, Vector3(0, 0, 90))
	for x in [-0.23, 0.23]:
		var g := CylinderMesh.new()
		g.top_radius = 0.022
		g.bottom_radius = 0.022
		g.height = 0.11
		_part(g, Vector3(x, 1.1, -0.45), rubber, Vector3(0, 0, 90))
	# display + headlight
	var disp := BoxMesh.new()
	disp.size = Vector3(0.08, 0.01, 0.05)
	var scr := _m(Color("25d9f5"))
	scr.emission_enabled = true
	scr.emission = Color("25d9f5")
	scr.emission_energy_multiplier = 1.5
	_part(disp, Vector3(0, 1.115, -0.43), scr, Vector3(-20, 0, 0))
	var lamp := SphereMesh.new()
	lamp.radius = 0.035
	lamp.height = 0.05
	var lm := _m(Color.WHITE)
	lm.emission_enabled = true
	lm.emission = Color("fff4e0")
	lm.emission_energy_multiplier = 4.0
	_part(lamp, Vector3(0, 0.95, -0.47), lm)
	_light = SpotLight3D.new()
	_light.position = Vector3(0, 0.95, -0.5)
	_light.light_color = Color("fff1dc")
	_light.light_energy = 3.0
	_light.spot_range = 16.0
	_light.spot_angle = 28.0
	_light.rotation_degrees = Vector3(-12, 0, 0)
	_light.shadow_enabled = false
	add_child(_light)
	# interaction body (also what you bump into when it's parked)
	body = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.45, 1.1, 0.95)
	col.shape = sh
	col.position = Vector3(0, 0.55, 0)
	body.add_child(col)
	body.set_meta("interact", "estep")
	body.set_meta("estep", self)
	add_child(body)
	# sounds
	_motor = AudioStreamPlayer3D.new()
	_motor.stream = AmbienceSynth.motor()
	_motor.unit_size = 3.0
	_motor.volume_db = -60.0
	add_child(_motor)
	_bell = AudioStreamPlayer3D.new()
	_bell.stream = AmbienceSynth.bell()
	add_child(_bell)
	update_label()


func max_speed() -> float:
	if float(data.get("battery", 0.0)) <= 0.0:
		return DEAD_SPEED
	return TUNED_SPEED if data.get("motor", false) else BASE_SPEED


func update_label() -> void:
	if body:
		body.set_meta("label", "Ride e-step  (battery %d%%)" % int(ceil(float(data.get("battery", 0.0)))))


func mount(p: Node3D) -> void:
	rider = p
	speed = 0.0
	_last = global_position
	body.get_child(0).disabled = true
	if is_inside_tree():
		_motor.play()


func dismount() -> void:
	rider = null
	speed = 0.0
	body.get_child(0).disabled = false
	_motor.stop()
	update_label()


func ring_bell() -> void:
	if is_inside_tree():
		_bell.play()


func _physics_process(delta: float) -> void:
	if rider == null:
		return
	# follow the rider (the player is the physics body while riding)
	global_position = rider.global_position
	rotation.y = rider.rotation.y
	var moved := Vector2(global_position.x - _last.x, global_position.z - _last.z).length()
	_last = global_position
	if moved > 0.0 and moved < 5.0:
		var drain := DRAIN * (0.5 if data.get("big_battery", false) else 1.0)
		data.battery = maxf(float(data.battery) - moved * drain, 0.0)
	for w in _wheels:
		w.rotate_x(-speed * delta / 0.1)
	_motor.pitch_scale = 0.55 + speed / 7.0
	_motor.volume_db = lerpf(-30.0, -8.0, clampf(speed / 6.0, 0.0, 1.0)) if float(data.battery) > 0.0 else -60.0
