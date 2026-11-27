class_name Props
extends RefCounted
## Physics props you can pick up [E], throw [LMB] or drop [RMB]: cans, bottles, boxes, a ball, cones.
## They clink when they land, and people get angry when you hit them.


static func _mat(c: Color, rough := 0.4, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _body(label: String, mass: float, shape: Shape3D, mesh: Mesh, m: Material, bottle := false) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = mass
	b.set_meta("interact", "grab")
	b.set_meta("label", "Pick up (%s)   ·   LMB throw" % label)
	var col := CollisionShape3D.new()
	col.shape = shape
	b.add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	b.add_child(mi)
	b.contact_monitor = true
	b.max_contacts_reported = 2
	b.continuous_cd = true
	var snd := AudioStreamPlayer3D.new()
	snd.stream = AmbienceSynth.clink(bottle)
	snd.unit_size = 4.0
	b.add_child(snd)
	b.body_entered.connect(func(other: Node):
		var speed := b.linear_velocity.length()
		if speed > 1.2 and not snd.playing:
			snd.volume_db = linear_to_db(clampf(speed / 8.0, 0.15, 1.0))
			snd.play()
		if other.has_meta("npc") and speed > 3.0:
			var n: NPC = other.get_meta("npc")
			n.memory.annoyed = int(n.memory.annoyed) + 1
			n.face(b.global_position - b.linear_velocity)
			n.react("hit", StreetTalk._pick(StreetTalk.HIT), 3.0))
	return b


static func can(color: Color) -> RigidBody3D:
	var shape := CylinderShape3D.new()
	shape.radius = 0.033
	shape.height = 0.12
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.033
	mesh.bottom_radius = 0.033
	mesh.height = 0.12
	return _body("can", 0.05, shape, mesh, _mat(color, 0.3, 0.7))


static func bottle() -> RigidBody3D:
	var shape := CylinderShape3D.new()
	shape.radius = 0.035
	shape.height = 0.26
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.014
	mesh.bottom_radius = 0.036
	mesh.height = 0.26
	var m := _mat(Color(0.15, 0.35, 0.18, 0.75), 0.05)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _body("bottle", 0.3, shape, mesh, m, true)


static func box(size: Vector3, color: Color) -> RigidBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var mesh := BoxMesh.new()
	mesh.size = size
	return _body("box", 1.5, shape, mesh, _mat(color, 0.95))


static func ball() -> RigidBody3D:
	var shape := SphereShape3D.new()
	shape.radius = 0.11
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	var b := _body("ball", 0.43, shape, mesh, _mat(Color("e0e0e0"), 0.6))
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.65
	b.physics_material_override = pm
	return b


static func cone() -> RigidBody3D:
	var shape := CylinderShape3D.new()
	shape.radius = 0.16
	shape.height = 0.7
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.17
	mesh.height = 0.7
	return _body("traffic cone", 2.0, shape, mesh, _mat(Color("ff6a1a"), 0.6))
