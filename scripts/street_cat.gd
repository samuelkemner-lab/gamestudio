class_name StreetCat
extends Node3D
## "Kees", the black-and-white stray of the Zuidkade. Wanders between spots, sits, grooms.
## Comes closer when you crouch or lie down (cats like small people), runs when you sprint.
## Pet it [E]: it purrs, follows you a bit, and once per night it calms you down.

signal petted

var player: Node3D
var spots: Array[Vector3] = []
var body: StaticBody3D
var state := "sit"
var _t := 0.0
var _timer := 3.0
var _target := Vector3.ZERO
var _follow := 0.0
var _legs: Array[Node3D] = []
var _tail: Node3D
var _torso: Node3D
var _purr: AudioStreamPlayer3D
var _heart: Label3D


func _mat(c: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func build() -> void:
	var fur := _mat(Color("161519"))
	var white := _mat(Color("e9e6df"))
	_torso = Node3D.new()
	add_child(_torso)
	var cap := CapsuleMesh.new()
	cap.radius = 0.09
	cap.height = 0.42
	_mesh(_torso, cap, Vector3(0, 0.2, 0), fur, Vector3(90, 0, 0))
	var chest := SphereMesh.new()
	chest.radius = 0.075
	chest.height = 0.14
	_mesh(_torso, chest, Vector3(0, 0.19, 0.14), white)
	var head := Node3D.new()
	head.position = Vector3(0, 0.33, 0.2)
	_torso.add_child(head)
	var hs := SphereMesh.new()
	hs.radius = 0.075
	hs.height = 0.14
	_mesh(head, hs, Vector3.ZERO, fur)
	for sx in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.03
		ear.height = 0.06
		_mesh(head, ear, Vector3(sx * 0.04, 0.07, -0.005), fur, Vector3(0, 0, -sx * 15))
		var eye := SphereMesh.new()
		eye.radius = 0.012
		eye.height = 0.024
		var em := _mat(Color("c8e04a"), 0.2)
		em.emission_enabled = true
		em.emission = Color("c8e04a")
		em.emission_energy_multiplier = 1.4  # eyes catch the street light
		_mesh(head, eye, Vector3(sx * 0.03, 0.015, 0.065), em)
	var snout := SphereMesh.new()
	snout.radius = 0.03
	snout.height = 0.05
	_mesh(head, snout, Vector3(0, -0.02, 0.065), white)
	for i in 4:
		var leg := Node3D.new()
		leg.position = Vector3((-1 if i % 2 == 0 else 1) * 0.05, 0.15, 0.13 if i < 2 else -0.13)
		_torso.add_child(leg)
		var lm := CylinderMesh.new()
		lm.top_radius = 0.018
		lm.bottom_radius = 0.016
		lm.height = 0.15
		_mesh(leg, lm, Vector3(0, -0.075, 0), white if i < 2 else fur)
		_legs.append(leg)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.24, -0.2)
	_torso.add_child(_tail)
	var tm := CylinderMesh.new()
	tm.top_radius = 0.012
	tm.bottom_radius = 0.018
	tm.height = 0.26
	_mesh(_tail, tm, Vector3(0, 0.12, -0.03), fur, Vector3(-20, 0, 0))

	body = StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.25, 0.45, 0.55)
	col.shape = bs
	col.position.y = 0.22
	body.add_child(col)
	body.set_meta("interact", "cat")
	body.set_meta("label", "Pet the cat")
	add_child(body)

	_purr = AudioStreamPlayer3D.new()
	_purr.stream = AmbienceSynth.purr()
	_purr.unit_size = 2.0
	_purr.position.y = 0.2
	add_child(_purr)
	_heart = Label3D.new()
	_heart.text = "♥"
	_heart.font_size = 64
	_heart.pixel_size = 0.004
	_heart.modulate = Color("ff6b9a")
	_heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_heart.visible = false
	add_child(_heart)


func pet() -> void:
	state = "petted"
	_timer = 3.5
	_purr.play()
	_heart.visible = true
	_heart.position = Vector3(0, 0.5, 0)
	petted.emit()


func _pick_spot() -> void:
	_target = spots[randi() % spots.size()] + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	state = "walk"


func _process(delta: float) -> void:
	_t += delta
	var ppos := player.global_position if player and is_instance_valid(player) else Vector3(9999, 0, 9999)
	var d := global_position.distance_to(ppos)
	var low := false
	var sprint := false
	if player and "posture" in player:
		low = player.posture != 0
		sprint = player.sprinting
	# reactions
	if sprint and d < 4.5 and state != "flee":
		state = "flee"
		_target = global_position + (global_position - ppos).normalized() * 6.0
		_target.y = global_position.y
	elif low and d < 6.0 and d > 0.9 and state in ["sit", "walk"]:
		state = "approach"
	var speed := 0.0
	match state:
		"sit", "petted":
			_timer -= delta
			if state == "petted":
				_heart.position.y += delta * 0.25
				if _timer <= 0.0:
					_heart.visible = false
					state = "follow"
					_follow = 10.0
			elif _timer <= 0.0:
				_pick_spot()
		"walk", "flee":
			speed = 2.6 if state == "flee" else 0.5
			if _move_to(_target, speed, delta):
				state = "sit"
				_timer = randf_range(4.0, 10.0)
		"approach":
			speed = 0.6
			if d < 0.9 or not low:
				state = "sit"
				_timer = 6.0
			else:
				_move_to(ppos, speed, delta)
		"follow":
			_follow -= delta
			if d > 1.3:
				speed = 0.9
				_move_to(ppos, speed, delta)
			if _follow <= 0.0:
				state = "sit"
				_timer = 3.0
	# animation: legs swing while walking, body lowered while sitting, tail sways
	var walking := speed > 0.0
	for i in _legs.size():
		_legs[i].rotation.x = sin(_t * speed * 12.0 + i * PI * 0.5) * 0.6 if walking else 0.0
	_torso.position.y = -0.05 if not walking else absf(sin(_t * speed * 12.0)) * 0.01
	_torso.rotation.x = deg_to_rad(-12.0) if not walking else 0.0
	_tail.rotation.z = sin(_t * (1.2 if state != "petted" else 3.0)) * 0.5


func _move_to(p: Vector3, speed: float, delta: float) -> bool:
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.1:
		return true
	global_position += to.normalized() * minf(speed * delta, to.length())
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 6.0 * delta)
	return false
