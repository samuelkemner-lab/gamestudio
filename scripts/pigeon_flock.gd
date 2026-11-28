class_name PigeonFlock
extends Node3D
## A few pigeons pecking at crumbs. Walk too close (or run, or throw something) and they all
## take off with a flutter, circle away, and come back a while later.

var player: Node3D
var birds: Array = []  # [{node, wings:[l,r], home, vel, state}]
var _t := 0.0
var _away := 0.0
var _flap: AudioStreamPlayer3D
var fed := 0.0  # seconds left: they follow you and peck around your feet


## Throw bread: for a while they trust you, gather at your feet and follow you around.
func feed(seconds := 30.0) -> bool:
	if _away > 0.0:
		return false
	fed = seconds
	return true


func build(count: int, radius: float) -> void:
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color("6c6c78")
	grey.roughness = 0.9
	var neck := StandardMaterial3D.new()
	neck.albedo_color = Color("3d5a52")
	neck.metallic = 0.4
	neck.roughness = 0.4
	for i in count:
		var b := Node3D.new()
		add_child(b)
		var home := Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius))
		b.position = home
		b.rotation.y = randf() * TAU
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.06
		cap.height = 0.22
		body.mesh = cap
		body.material_override = grey
		body.rotation_degrees.x = 70.0
		body.position = Vector3(0, 0.09, 0)
		b.add_child(body)
		var head := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.035
		hs.height = 0.07
		head.mesh = hs
		head.material_override = neck
		head.position = Vector3(0, 0.17, 0.07)
		head.name = "Head"
		b.add_child(head)
		var wings: Array = []
		for sx in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var wb := BoxMesh.new()
			wb.size = Vector3(0.16, 0.01, 0.09)
			w.mesh = wb
			w.material_override = grey
			w.position = Vector3(sx * 0.08, 0.12, 0)
			w.visible = false
			b.add_child(w)
			wings.append(w)
		birds.append({"node": b, "wings": wings, "home": home, "vel": Vector3.ZERO, "phase": randf() * 10.0})
	_flap = AudioStreamPlayer3D.new()
	_flap.stream = AmbienceSynth.flap()
	_flap.unit_size = 6.0
	add_child(_flap)


func scare() -> void:
	if _away > 0.0:
		return
	_away = randf_range(22.0, 32.0)
	_flap.play()
	var ppos := player.global_position if player else global_position
	for b in birds:
		var n: Node3D = b.node
		var away := (n.global_position - ppos)
		away.y = 0.0
		b.vel = away.normalized() * randf_range(2.5, 4.0) + Vector3(randf_range(-1, 1), randf_range(3.5, 5.0), randf_range(-1, 1))
		for w in b.wings:
			w.visible = true


func _process(delta: float) -> void:
	_t += delta
	if _away > 0.0:
		_away -= delta
		for b in birds:
			var n: Node3D = b.node
			if n.visible:
				n.position += b.vel * delta
				b.vel.y = maxf(b.vel.y - delta * 0.6, 1.5)
				n.rotation.y = lerp_angle(n.rotation.y, atan2(b.vel.x, b.vel.z), 4.0 * delta)
				var flapw := sin(_t * 28.0 + b.phase) * 0.9
				b.wings[0].rotation.z = flapw
				b.wings[1].rotation.z = -flapw
				if n.position.y > 25.0:
					n.visible = false
		if _away <= 0.0:
			# they're back: land at their spots
			for b in birds:
				var n: Node3D = b.node
				n.visible = true
				n.position = b.home
				for w in b.wings:
					w.visible = false
		return
	# on the ground: peck, hop, turn
	for b in birds:
		var n: Node3D = b.node
		var head: Node3D = n.get_node("Head")
		var peck := maxf(sin(_t * 3.0 + b.phase * 3.0), 0.0)
		head.position = Vector3(0, 0.17 - peck * 0.09, 0.07 + peck * 0.05)
		if sin(_t * 0.7 + b.phase) > 0.995:
			n.rotation.y += randf_range(-1.2, 1.2)
	if fed > 0.0 and player and is_instance_valid(player):
		fed -= delta
		var target := to_local(player.global_position)
		for b in birds:
			var n: Node3D = b.node
			var spot: Vector3 = target + Vector3(cos(b.phase * 2.0), 0, sin(b.phase * 2.0)) * (0.8 + fmod(b.phase, 0.7))
			spot.y = 0.0
			var to := spot - n.position
			if to.length() > 0.15:
				n.position += to.normalized() * minf(to.length(), 1.6 * delta)
				n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.z), 6.0 * delta)
		if fed <= 0.0:
			for b in birds:
				b.home = (b.node as Node3D).position  # they settle where you left them
		return
	if player and is_instance_valid(player):
		var d := global_position.distance_to(player.global_position)
		var running: bool = "sprinting" in player and player.sprinting
		if d < 3.0 or (running and d < 7.0):
			scare()
