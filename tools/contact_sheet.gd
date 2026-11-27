extends SceneTree
## Renders a labelled grid of models: xvfb-run godot --path . -s tools/contact_sheet.gd -- out.png name1 name2 ...


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var names := args.slice(1)
	root.size = Vector2i(1800, 1000)
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2f3a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.basis = Basis.looking_at(Vector3(-0.5, -1, -0.7).normalized())
	var cols := 6
	var spacing := 2.2
	for i in names.size():
		var ps: PackedScene = load("res://assets/models/kenney_furniture/%s.glb" % names[i])
		var inst: Node3D = ps.instantiate()
		inst.scale = Vector3.ONE * 2.0
		inst.position = Vector3((i % cols) * spacing, 0, (i / cols) * spacing)
		world.add_child(inst)
		var lbl := Label3D.new()
		lbl.text = names[i]
		lbl.font_size = 48
		lbl.pixel_size = 0.004
		lbl.position = inst.position + Vector3(0.5, 0.05, 0.9)
		lbl.rotation_degrees.x = -50
		world.add_child(lbl)
	var rows := ceili(names.size() / float(cols))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(rows, 3) * spacing * 1.25
	world.add_child(cam)
	var center := Vector3((cols - 1) * spacing / 2.0, 0, (rows - 1) * spacing / 2.0)
	cam.position = center + Vector3(0, 12, 9)
	cam.look_at(center, Vector3.UP)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
