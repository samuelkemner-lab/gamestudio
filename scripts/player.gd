extends CharacterBody3D
## First-person player.
## WASD + mouse, [Shift] sprint, [Ctrl] hold / [C] toggle crouch, [Z] prone, [Space] jump,
## [E] interact / pick up, [LMB] throw, [RMB] drop, [F] phone flashlight.
## Seats and the bed lock the body in a pose (mouse look still works, [Space] gets up).

signal interacted(target: Object)
signal interact_empty  # E pressed while looking at nothing (e.g. lying in bed → sleep)
signal thrown(body: RigidBody3D)
signal crashed(speed: float, collider: Object)  # fell off the e-step

enum Posture { STAND, CROUCH, PRONE }

const WALK := 3.2
const SPRINT := 5.6
const CROUCH_SPEED := 1.5
const PRONE_SPEED := 0.7
const SENSITIVITY := 0.0025
const GRAVITY := 9.8
const JUMP := 4.2
const CAM_H := [1.6, 1.05, 0.38]
const COL_H := [1.7, 1.15, 0.6]

var enabled := true
var camera: Camera3D
var ray: RayCast3D
var posture := Posture.STAND
var sprinting := false
var surface := "wood"  # "wood" | "stone" | "wet" (set by main)
var pose := ""  # "" free, "seat", "bed"
var held: RigidBody3D
var riding: EStep  # on the e-step
var _crash_roll := 0.0
var flashlight: SpotLight3D

var _bob_t := 0.0
var _step_phase := 0.0
var _crouch_toggle := false
var _col: CollisionShape3D
var _cap: CapsuleShape3D
var _head_ray: RayCast3D
var _vignette: TextureRect
var _steps := {}
var _step_player: AudioStreamPlayer
var _fx_player: AudioStreamPlayer
var _was_on_floor := true
var _fall_speed := 0.0
var _land_dip := 0.0
var _pose_exit := Vector3.ZERO
var _pose_cam_h := 1.6


func _ready() -> void:
	_col = CollisionShape3D.new()
	_cap = CapsuleShape3D.new()
	_cap.radius = 0.3
	_cap.height = 1.7
	_col.shape = _cap
	_col.position.y = 0.85
	add_child(_col)

	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 0)
	camera.fov = 75.0
	camera.current = true
	add_child(camera)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.4)
	ray.add_exception(self)
	camera.add_child(ray)

	# is there room above us to stand up?
	_head_ray = RayCast3D.new()
	_head_ray.position = Vector3(0, 0.3, 0)
	_head_ray.target_position = Vector3(0, 1.5, 0)
	_head_ray.add_exception(self)
	add_child(_head_ray)

	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.18, -0.12, -0.1)
	flashlight.light_color = Color("f2f6ff")
	flashlight.light_energy = 2.2
	flashlight.spot_range = 14.0
	flashlight.spot_angle = 26.0
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera.add_child(flashlight)

	_build_vignette()
	_step_player = AudioStreamPlayer.new()
	_step_player.volume_db = -10.0
	add_child(_step_player)
	_fx_player = AudioStreamPlayer.new()
	_fx_player.volume_db = -6.0
	add_child(_fx_player)
	for s in ["wood", "stone", "wet"]:
		_steps[s] = [AmbienceSynth.step(s, 0), AmbienceSynth.step(s, 1), AmbienceSynth.step(s, 2)]


## Crouching darkens the edges of the screen (you feel sneaky).
func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.0, 0.0, 0.02, 0.85))
	g.add_point(0.55, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	layer.add_child(_vignette)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.45)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif held and event.button_index == MOUSE_BUTTON_LEFT:
			throw_held()
		elif held and event.button_index == MOUSE_BUTTON_RIGHT:
			drop_held()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				if riding:
					dismount()
					return
				if held:
					drop_held()
					return
				var target := hover_target()
				if target and target.get_meta("interact") == "grab" and target is RigidBody3D:
					pick_up(target)
				elif target:
					interacted.emit(target)
				else:
					interact_empty.emit()
			KEY_C:
				if pose == "" and not riding:
					_crouch_toggle = not _crouch_toggle
					if _crouch_toggle and posture == Posture.STAND:
						set_posture(Posture.CROUCH)
					elif not _crouch_toggle and posture == Posture.CROUCH:
						set_posture(Posture.STAND)
			KEY_Z:
				if pose == "" and not riding and not event.ctrl_pressed:
					set_posture(Posture.STAND if posture == Posture.PRONE else Posture.PRONE)
			KEY_B:
				if riding:
					riding.ring_bell()
			KEY_SPACE:
				if riding:
					dismount()
				elif pose != "":
					leave_pose()
				elif posture == Posture.PRONE:
					set_posture(Posture.CROUCH)
				elif posture == Posture.CROUCH:
					set_posture(Posture.STAND)
				elif is_on_floor():
					velocity.y = JUMP
			KEY_F:
				flashlight.visible = not flashlight.visible
				_play_fx(AmbienceSynth.tick(2600.0 if flashlight.visible else 1900.0))


func set_posture(p: int) -> bool:
	if p < posture or (p == Posture.STAND and posture != Posture.STAND):
		# getting up needs head room
		_head_ray.target_position = Vector3(0, COL_H[p] - 0.3, 0)
		_head_ray.force_raycast_update()
		if _head_ray.is_colliding():
			return false
	posture = p
	_cap.height = COL_H[p]
	_cap.radius = 0.3 if p != Posture.PRONE else 0.28
	_col.position.y = COL_H[p] / 2.0
	if p != Posture.CROUCH:
		_crouch_toggle = false
	return true


## Snap the view towards a world point (e.g. the booth when a take starts).
func look_at_point(p: Vector3) -> void:
	var d := p - global_position
	rotation.y = atan2(-d.x, -d.z)
	var flat := Vector2(d.x, d.z).length()
	camera.rotation.x = clampf(atan2(p.y - (global_position.y + 1.6), flat), -1.2, 1.2)


func hover_target() -> Object:
	if ray.is_colliding():
		var c := ray.get_collider()
		if c and c.has_meta("interact"):
			return c
	return null


# ---------- Seats and bed ----------

## Sit (or lie) somewhere: body locked at `pos` facing `yaw`, camera at `cam_h`.
func enter_pose(kind: String, pos: Vector3, yaw: float, cam_h: float, pitch := 0.0) -> void:
	if held:
		drop_held()
	set_posture(Posture.STAND)
	_pose_exit = global_position
	pose = kind
	_pose_cam_h = cam_h
	_col.disabled = true
	velocity = Vector3.ZERO
	global_position = pos
	rotation.y = yaw
	camera.rotation.x = pitch


func leave_pose() -> void:
	if pose == "":
		return
	pose = ""
	_col.disabled = false
	global_position = _pose_exit
	camera.rotation.x = 0.0


# ---------- Picking things up ----------

func pick_up(b: RigidBody3D) -> void:
	held = b
	b.gravity_scale = 0.0
	b.linear_damp = 8.0
	b.angular_damp = 6.0
	add_collision_exception_with(b)


func drop_held() -> void:
	if not held:
		return
	var b := held
	held = null
	b.gravity_scale = 1.0
	b.linear_damp = 0.1
	b.angular_damp = 0.5
	remove_collision_exception_with(b)


func throw_held() -> void:
	var b := held
	drop_held()
	b.linear_velocity = -camera.global_transform.basis.z * 8.5 + Vector3.UP * 1.2 + velocity * 0.5
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	thrown.emit(b)


func _hold_update() -> void:
	if not held or not is_instance_valid(held):
		held = null
		return
	var target := camera.global_position - camera.global_transform.basis.z * 1.0 + Vector3(0, -0.15, 0)
	var to := target - held.global_position
	if to.length() > 2.5:
		drop_held()
		return
	held.linear_velocity = to * 14.0


# ---------- Movement ----------

func _physics_process(delta: float) -> void:
	if pose != "":
		camera.position = camera.position.lerp(Vector3(0, _pose_cam_h, 0), 10.0 * delta)
		_vignette.modulate.a = lerpf(_vignette.modulate.a, 0.0, 6.0 * delta)
		return
	if riding:
		_ride(delta)
		return
	_crash_roll = lerpf(_crash_roll, 0.0, 3.0 * delta)
	camera.rotation.z = lerpf(camera.rotation.z, _crash_roll, 8.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	var dir := Vector3.ZERO
	sprinting = false
	if enabled:
		var input := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		)
		dir = (transform.basis * Vector3(input.x, 0, input.y)).normalized()
		# hold Ctrl to crouch (C toggles)
		var want_crouch := Input.is_physical_key_pressed(KEY_CTRL) or _crouch_toggle
		if posture != Posture.PRONE:
			if want_crouch and posture == Posture.STAND:
				set_posture(Posture.CROUCH)
			elif not want_crouch and posture == Posture.CROUCH:
				set_posture(Posture.STAND)
		sprinting = Input.is_physical_key_pressed(KEY_SHIFT) and posture == Posture.STAND and input.y < 0.0 and not held
	var speed: float = [WALK, CROUCH_SPEED, PRONE_SPEED][posture]
	if sprinting:
		speed = SPRINT
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
	_hold_update()

	# landing
	if is_on_floor() and not _was_on_floor and _fall_speed > 2.5:
		_land_dip = clampf(_fall_speed * 0.03, 0.05, 0.25)
		_play_fx(AmbienceSynth.land())
	if is_on_floor():
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()
	_land_dip = lerpf(_land_dip, 0.0, 8.0 * delta)

	# head bob + footsteps
	var moving := dir.length() > 0.1 and is_on_floor()
	var bob_speed := 9.0 * (speed / WALK) * (0.8 if posture != Posture.STAND else 1.0)
	if moving:
		_bob_t += delta * bob_speed
		var phase: float = floor(_bob_t / PI)
		if phase != _step_phase:
			_step_phase = phase
			_footstep()
	var amp := 0.03 * (1.6 if sprinting else 1.0) * (0.5 if posture == Posture.PRONE else 1.0)
	var target_y: float = CAM_H[posture] + (sin(_bob_t) * amp if moving else 0.0) - _land_dip
	var target_x := cos(_bob_t * 0.5) * 0.02 if moving else 0.0
	camera.position.y = lerpf(camera.position.y, target_y, 10.0 * delta)
	camera.position.x = lerpf(camera.position.x, target_x, 12.0 * delta)
	camera.fov = lerpf(camera.fov, 82.0 if sprinting and moving else 75.0, 6.0 * delta)
	var vig := 0.0 if posture == Posture.STAND else (0.75 if posture == Posture.CROUCH else 1.0)
	_vignette.modulate.a = lerpf(_vignette.modulate.a, vig, 6.0 * delta)


# ---------- E-step ----------

func mount(step: EStep) -> void:
	if held:
		drop_held()
	set_posture(Posture.STAND)
	_crouch_toggle = false
	riding = step
	global_position = step.global_position + Vector3(0, 0.05, 0)
	rotation.y = step.rotation.y
	velocity = Vector3.ZERO
	step.mount(self)


func dismount() -> void:
	if riding == null:
		return
	var step := riding
	riding = null
	step.global_position = Vector3(global_position.x, global_position.y - 0.05, global_position.z)
	step.rotation.y = rotation.y
	step.dismount()
	# step off to the left
	var side := -transform.basis.x * 0.75
	global_position += side
	velocity = Vector3.ZERO


## W gas, S brake, A/D (and the mouse) steer. Hit a wall or a person too fast and you fall off.
func _ride(delta: float) -> void:
	var top := riding.max_speed()
	var thr := 0.0
	var steer := 0.0
	if enabled:
		thr = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
		steer = float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))
	var sp := riding.speed
	if thr > 0.0:
		sp = move_toward(sp, top, 2.6 * delta)
	elif thr < 0.0:
		sp = move_toward(sp, 0.0, 7.0 * delta)
	else:
		sp = move_toward(sp, 0.0, 0.8 * delta)
	if sp > top:
		sp = move_toward(sp, top, 3.0 * delta)
	var k := clampf(sp / maxf(top, 0.1), 0.0, 1.0)
	rotate_y(steer * delta * lerpf(1.9, 1.15, k) * (1.0 if sp > 0.3 else 0.35))
	var fwd := -transform.basis.z
	velocity.x = fwd.x * sp
	velocity.z = fwd.z * sp
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	riding.speed = sp
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if absf(c.get_normal().y) < 0.5:
			if sp > 3.8:
				crash(c.get_collider())
				return
			riding.speed = sp * 0.4  # scrape along the wall
			break
	# camera: standing on the deck, lean into turns, FOV opens with speed
	camera.position = camera.position.lerp(Vector3(0, 1.74 + sin(Time.get_ticks_msec() * 0.03) * 0.004 * k, 0), 10.0 * delta)
	camera.rotation.z = lerpf(camera.rotation.z, steer * 0.07 * k, 5.0 * delta)
	camera.fov = lerpf(camera.fov, 75.0 + sp * 1.4, 4.0 * delta)
	_vignette.modulate.a = lerpf(_vignette.modulate.a, 0.0, 6.0 * delta)


func crash(collider: Object) -> void:
	var sp := riding.speed if riding else 0.0
	dismount()
	_crash_roll = 0.55
	_land_dip = 0.35
	camera.rotation.z = 0.55
	_play_fx(AmbienceSynth.land())
	crashed.emit(sp, collider)


func _footstep() -> void:
	var s := surface
	if s == "wet" and randf() < 0.4:
		s = "stone"  # not every step lands in a puddle
	var bank: Array = _steps.get(s, _steps["stone"])
	_step_player.stream = bank[randi() % bank.size()]
	_step_player.pitch_scale = randf_range(0.9, 1.1)
	_step_player.volume_db = (-10.0 if not sprinting else -6.0) - (8.0 if posture != Posture.STAND else 0.0)
	_step_player.play()


func _play_fx(stream: AudioStream) -> void:
	_fx_player.stream = stream
	_fx_player.play()
