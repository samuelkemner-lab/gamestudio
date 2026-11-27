class_name NPC
extends Node3D
## A character in the world (rapper, cop): Kenney Mini Character + accessories,
## animations, walking along a path, speech bubble with babble voice.

signal arrived

const MODEL_PATH := "res://assets/models/kenney_characters/%s.glb"
const SCALE := 2.4

var data: Dictionary
var anim: AnimationPlayer
var bubble: Label3D
var voice: AudioStreamPlayer3D
var speed := 1.15
var _syllables := []
var _path: Array[Vector3] = []
var _bubble_time := 0.0
var _babble_left := 0
var _babble_timer := 0.0
var _bob := false
var _t := 0.0
var _model: Node3D


func setup(d: Dictionary) -> void:
	data = d
	_model = load(MODEL_PATH % d.model).instantiate()
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	anim = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ["idle", "walk", "holding-right", "sit"]:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_add_accessory(d.get("accessory", ""), d.get("accent", Color.WHITE))
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.position = Vector3(0, 1.9, 0)
	bubble.font_size = 40
	bubble.pixel_size = 0.0021
	bubble.outline_size = 14
	bubble.outline_modulate = Color(0.05, 0.03, 0.1, 0.95)
	bubble.modulate = Color("f4efff")
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 640.0
	bubble.no_depth_test = true
	bubble.fixed_size = false
	bubble.visible = false
	add_child(bubble)

	voice = AudioStreamPlayer3D.new()
	voice.position = Vector3(0, 1.4, 0)
	voice.unit_size = 4.0
	voice.max_polyphony = 2
	add_child(voice)
	_syllables = VoiceSynth.bank(d.get("voice_hz", 140.0))
	play("idle")


func _add_accessory(kind: String, accent: Color) -> void:
	if kind == "":
		return
	var skel: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
	var head := BoneAttachment3D.new()
	head.bone_name = "head"
	skel.add_child(head)
	var torso := BoneAttachment3D.new()
	torso.bone_name = "torso"
	skel.add_child(torso)
	var black := _mat(Color("15141b"), 0.6)
	var gold := _mat(Color("f2c14e"), 0.25, 0.6)
	match kind:
		"bucket_hat":
			_part(head, _cyl(0.2, 0.12, 0.17), Vector3(0, 0.33, 0.02), _mat(Color("6b5a3b"), 0.9))
			_part(head, _cyl(0.235, 0.015, 0.215), Vector3(0, 0.272, 0.02), _mat(Color("5e4f33"), 0.9))
			var chain := TorusMesh.new()
			chain.inner_radius = 0.095
			chain.outer_radius = 0.11
			_part(torso, chain, Vector3(0, 0.09, 0.07), gold, Vector3(-65, 0, 0))
			_part(torso, SphereMesh.new(), Vector3(0, 0.03, 0.12), gold, Vector3.ZERO, Vector3.ONE * 0.05)
		"beanie":
			var b := SphereMesh.new()
			b.radius = 0.2
			b.height = 0.16
			_part(head, b, Vector3(0, 0.31, 0.02), _mat(accent.darkened(0.35), 0.95), Vector3.ZERO, Vector3(1.08, 1.0, 1.08))
			var phones := TorusMesh.new()
			phones.inner_radius = 0.1
			phones.outer_radius = 0.125
			_part(torso, phones, Vector3(0, 0.12, 0.0), _mat(Color("f4efff"), 0.4), Vector3(0, 0, 0))
		"drill":
			_part(head, _cyl(0.2, 0.07, 0.2), Vector3(0, 0.315, 0.02), black)
			_part(head, _box(Vector3(0.24, 0.012, 0.16)), Vector3(0, 0.285, 0.2), black)
			_part(head, _box(Vector3(0.34, 0.1, 0.025)), Vector3(0, 0.045, 0.2), _mat(Color("1d1c26"), 0.95))  # face mask
			_part(head, _box(Vector3(0.02, 0.02, 0.01)), Vector3(0.1, 0.18, 0.23), _glow(accent))
			var chain2 := TorusMesh.new()
			chain2.inner_radius = 0.09
			chain2.outer_radius = 0.1
			_part(torso, chain2, Vector3(0, 0.09, 0.07), _mat(Color("d8dde6"), 0.2, 0.8), Vector3(-65, 0, 0))


func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(c: Color) -> StandardMaterial3D:
	var m := _mat(c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	return m


func _cyl(r: float, h: float, top: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = top
	c.height = h
	return c


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)


# ---------- Behaviour ----------

func play(name: String) -> void:
	if anim.has_animation(name) and anim.current_animation != name:
		anim.play(name, 0.25)


func walk_path(points: Array[Vector3]) -> void:
	_path = points.duplicate()
	play("walk")


func is_walking() -> bool:
	return not _path.is_empty()


func face(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(d.x, d.z)


## Bob along with the beat while rapping.
func set_rapping(on: bool) -> void:
	_bob = on
	play("holding-right" if on else "idle")


func say(text: String, seconds := 4.0) -> void:
	bubble.text = text
	bubble.visible = true
	_bubble_time = seconds
	_babble_left = clampi(text.length() / 4, 3, 14)
	_babble_timer = 0.0


func rap_syllable() -> void:
	if _syllables.is_empty():
		return
	voice.stream = _syllables[randi() % _syllables.size()]
	voice.pitch_scale = randf_range(0.95, 1.08)
	voice.play()


func _process(delta: float) -> void:
	_t += delta
	if not _path.is_empty():
		var target := _path[0]
		var to := target - global_position
		to.y = 0.0
		if to.length() < 0.05:
			_path.pop_front()
			if _path.is_empty():
				play("idle")
				arrived.emit()
		else:
			var step := to.normalized() * speed * delta
			global_position += step if step.length() < to.length() else to
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 10.0 * delta)
	if _bob:
		_model.position.y = absf(sin(_t * 7.3)) * 0.04
	else:
		_model.position.y = 0.0
	if bubble.visible:
		_bubble_time -= delta
		if _bubble_time <= 0.0:
			bubble.visible = false
	if _babble_left > 0:
		_babble_timer -= delta
		if _babble_timer <= 0.0:
			_babble_left -= 1
			_babble_timer = randf_range(0.07, 0.13)
			rap_syllable()
