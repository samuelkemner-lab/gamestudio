class_name NPC
extends Node3D
## A character in the world (rapper, cop): Kenney Mini Character + accessories,
## animations, walking along a path, speech bubble with babble voice.

signal arrived

const MODEL_PATH := "res://assets/models/quaternius_characters/%s.glb"
const SCALE := 0.92
const ANIM := {
	"idle": "CharacterArmature|Idle_Neutral",
	"walk": "CharacterArmature|Walk",
	"wave": "CharacterArmature|Wave",
	"rap": "CharacterArmature|Idle_Gun_Pointing",
	"yes": "CharacterArmature|Wave",
	"no": "CharacterArmature|HitRecieve",
	"interact": "CharacterArmature|Interact",
	"run": "CharacterArmature|Run",
	"hit": "CharacterArmature|HitRecieve_2",
	"dap": "CharacterArmature|Punch_Right",
}

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
var body: StaticBody3D  # what the player's ray hits / bumps into
var display_name := ""
var memory := {"talks": 0, "flyer": false, "heard_track": false, "annoyed": 0, "dapped": false}
var walk_anim := "walk"
var _paused_path: Array[Vector3] = []
var _paused := 0.0
var _dance := 0.0
var _react_cd := {}


func setup(d: Dictionary) -> void:
	data = d
	_model = load(MODEL_PATH % d.model).instantiate()
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	anim = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for key in ["idle", "walk", "rap"]:
		if anim.has_animation(ANIM[key]):
			anim.get_animation(ANIM[key]).loop_mode = Animation.LOOP_LINEAR
	anim.animation_finished.connect(func(_n): play("idle"))
	_recolor_clothes(d.get("recolor", {}))
	_add_accessory(d.get("accessory", ""), d.get("accent", Color.WHITE))
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.position = Vector3(0, 2.05, 0)
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
	voice.position = Vector3(0, 1.55, 0)
	voice.unit_size = 4.0
	voice.max_polyphony = 2
	add_child(voice)
	_syllables = VoiceSynth.bank(d.get("voice_hz", 140.0))
	play("idle")
	display_name = str(d.get("name", ""))
	body = StaticBody3D.new()
	body.name = "Body"
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.88
	body.add_child(col)
	body.set_meta("interact", str(d.get("interact", "npc")))
	body.set_meta("label", "Talk to %s" % display_name if display_name != "" else "Talk")
	body.set_meta("npc", self)
	add_child(body)


func _recolor_clothes(map: Dictionary) -> void:
	if map.is_empty():
		return
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var src := m3.mesh.surface_get_material(i)
			if src and map.has(src.resource_name):
				var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.albedo_color = map[src.resource_name]
				m3.set_surface_override_material(i, m)


## Bone attachments live inside the armature (scale 100): props go in a 0.01-scaled holder,
## so they can be authored in metres. Bone space: +Y up the bone, +Z forward.
func _holder(bone: String) -> Node3D:
	var skel: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	var h := Node3D.new()
	h.scale = Vector3.ONE * 0.01
	att.add_child(h)
	return h


func _add_accessory(kind: String, accent: Color) -> void:
	# Every rapper holds a mic in the right hand (pedestrians, cops and inspectors don't)
	if not kind in ["", "cop", "inspector"]:
		var hand := _holder("Wrist.R")
		_part(hand, _cyl(0.022, 0.13, 0.016), Vector3(0, 0.09, 0.03), _mat(Color("1a1a20"), 0.4))
		var ball := SphereMesh.new()
		ball.radius = 0.033
		ball.height = 0.066
		_part(hand, ball, Vector3(0, 0.17, 0.03), _mat(Color("b8bcc6"), 0.25, 0.7))
	if kind == "":
		return
	var head := _holder("Head")
	var chest := _holder("Chest")
	var black := _mat(Color("15141b"), 0.6)
	var gold := _mat(Color("f2c14e"), 0.25, 0.7)
	var silver := _mat(Color("d8dde6"), 0.2, 0.8)
	match kind:
		"bucket_hat":
			_part(head, _cyl(0.125, 0.1, 0.105), Vector3(0, 0.215, 0.0), _mat(Color("6b5a3b"), 0.9))
			_part(head, _cyl(0.17, 0.012, 0.15), Vector3(0, 0.165, 0.0), _mat(Color("5e4f33"), 0.9))
			_chain(chest, gold, 0.11)
		"beanie":
			var phones := TorusMesh.new()
			phones.inner_radius = 0.075
			phones.outer_radius = 0.095
			_part(chest, phones, Vector3(0, 0.2, 0.02), _mat(Color("f4efff"), 0.4), Vector3(8, 0, 0))
		"drill":
			_part(head, _box(Vector3(0.17, 0.09, 0.06)), Vector3(0, 0.045, 0.085), _mat(Color("1d1c26"), 0.95))
			_part(head, _cyl(0.115, 0.07, 0.11), Vector3(0, 0.2, -0.005), black)
			_part(head, _box(Vector3(0.15, 0.012, 0.12)), Vector3(0, 0.17, 0.11), black)
			_chain(chest, silver, 0.1)
		"inspector":
			# navy cap with a gold badge + card reader in the hand
			var navy := _mat(Color("1b2540"), 0.7)
			_part(head, _cyl(0.118, 0.07, 0.112), Vector3(0, 0.2, -0.005), navy)
			_part(head, _box(Vector3(0.16, 0.012, 0.1)), Vector3(0, 0.168, 0.1), _mat(Color("0d0f18"), 0.4))
			_part(head, _box(Vector3(0.04, 0.03, 0.01)), Vector3(0, 0.215, 0.114), gold)
			_part(chest, _box(Vector3(0.07, 0.025, 0.01)), Vector3(0.07, 0.1, 0.135), gold)
			var hand := _holder("Wrist.R")
			_part(hand, _box(Vector3(0.07, 0.12, 0.025)), Vector3(0, 0.09, 0.04), _mat(Color("202228"), 0.5))
			_part(hand, _box(Vector3(0.05, 0.04, 0.005)), Vector3(0, 0.11, 0.054), _glow(Color("3dff8a")))
		"punk":
			_chain(chest, silver, 0.1)
			_part(chest, _box(Vector3(0.05, 0.05, 0.01)), Vector3(0.08, 0.1, 0.13), _glow(accent))


func _chain(parent: Node3D, m: Material, r: float) -> void:
	var t := TorusMesh.new()
	t.inner_radius = r - 0.008
	t.outer_radius = r
	_part(parent, t, Vector3(0, 0.12, 0.06), m, Vector3(-60, 0, 0))
	var pend := SphereMesh.new()
	pend.radius = 0.022
	pend.height = 0.044
	_part(parent, pend, Vector3(0, 0.05, 0.13), m)


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
	var a: String = ANIM.get(name, name)
	if anim.has_animation(a) and anim.current_animation != a:
		anim.play(a, 0.25)


func walk_path(points: Array[Vector3]) -> void:
	_path = points.duplicate()
	play(walk_anim)


## Stop walking for a moment (to talk, to look at you), then carry on where they were going.
func pause_route(seconds: float) -> void:
	if not _path.is_empty():
		_paused_path = _path.duplicate()
		_path.clear()
	_paused = maxf(_paused, seconds)
	if _dance <= 0.0:
		play("idle")


func resume_route() -> void:
	_paused = 0.0
	if not _paused_path.is_empty():
		_path = _paused_path.duplicate()
		_paused_path.clear()
		play(walk_anim)


func is_busy() -> bool:
	return _paused > 0.0


## Cooldown helper for reactions: true if `kind` may fire now.
func can_react(kind: String, cooldown: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_react_cd.get(kind, -999.0)) < cooldown:
		return false
	_react_cd[kind] = now
	return true


## Short reaction: an animation + a line, and a short stop.
func react(anim_key: String, line: String, stop := 2.5) -> void:
	pause_route(stop)
	if anim_key != "":
		play(anim_key)
	if line != "":
		say(line, maxf(stop, 2.5))


func dance(seconds: float) -> void:
	pause_route(seconds)
	_dance = seconds
	play("wave")


## Fist bump: reach out with the right hand, slowly.
func dap() -> void:
	pause_route(2.0)
	if anim.has_animation(ANIM["dap"]):
		anim.play(ANIM["dap"], 0.15, 0.55)


func is_walking() -> bool:
	return not _path.is_empty()


func face(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		global_rotation.y = atan2(d.x, d.z)  # global: also right when standing in a (rotated) tram or train


## Bob along with the beat while rapping.
func set_rapping(on: bool) -> void:
	_bob = on
	play("rap" if on else "idle")


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
	if _paused > 0.0:
		_paused -= delta
		if _paused <= 0.0:
			resume_route()
	if _dance > 0.0:
		_dance -= delta
		_model.position.y = absf(sin(_t * 9.0)) * 0.08
		_model.rotation.y = sin(_t * 4.5) * 0.35
		if _dance <= 0.0:
			_model.position.y = 0.0
			_model.rotation.y = 0.0
			play("idle")
	if not _path.is_empty():
		var target := _path[0]
		var to := target - global_position
		to.y = 0.0
		if to.length() < 0.05:
			_path.pop_front()
			if _path.is_empty():
				play("idle")
				arrived.emit()
		elif anim.current_animation != ANIM.get(walk_anim, ""):
			play(walk_anim)
		else:
			var step := to.normalized() * speed * delta
			global_position += step if step.length() < to.length() else to
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 10.0 * delta)
	if _dance > 0.0:
		pass
	elif _bob:
		_model.position.y = absf(sin(_t * 7.3)) * 0.025
		_model.rotation.y = sin(_t * 3.6) * 0.12
	else:
		_model.position.y = 0.0
		_model.rotation.y = 0.0
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
