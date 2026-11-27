extends CharacterBody3D
## First-person player: WASD + mouse look, [E] to interact.

signal interacted(target: Object)

const SPEED := 3.2
const SENSITIVITY := 0.0025
const GRAVITY := 9.8

var enabled := true
var camera: Camera3D
var ray: RayCast3D


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)

	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 0)
	camera.fov = 75.0
	camera.current = true
	add_child(camera)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.2)
	ray.add_exception(self)
	camera.add_child(ray)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		var target := hover_target()
		if target:
			interacted.emit(target)


func hover_target() -> Object:
	if ray.is_colliding():
		var c := ray.get_collider()
		if c and c.has_meta("interact"):
			return c
	return null


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var dir := Vector3.ZERO
	if enabled:
		var input := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		)
		dir = (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()
