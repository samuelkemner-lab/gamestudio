extends SceneTree
## Renders screenshots for visual checks (needs a display, e.g. xvfb-run).
## godot --path . -s tests/screenshot.gd -- <out_dir>


func _initialize() -> void:
	_run.call_deferred()


func _save(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	var out := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame

	# View toward the desk
	main.player.position = Vector3(-0.3, 0.05, 0.3)
	main.player.rotation.y = deg_to_rad(10)
	main.player.camera.rotation.x = deg_to_rad(-12)
	await _save(out + "/shot_room.png")

	# Look at the monitor from the chair
	main.player.position = Vector3(-0.7, 0.05, -1.2)
	main.player.rotation.y = 0.0
	main.player.camera.rotation.x = deg_to_rad(-18)
	for i in 5:
		await physics_frame
	await _save(out + "/shot_desk.png")

	main.open_loopr()
	main.sequencer.play()
	for i in 8:
		await process_frame
	await _save(out + "/shot_loopr.png")

	var tabs: TabContainer = main.loopr.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 1
	await _save(out + "/shot_mixer.png")
	quit()
