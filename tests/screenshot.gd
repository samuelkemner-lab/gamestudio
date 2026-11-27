extends SceneTree
## Renders screenshots for visual checks (needs a display, e.g. xvfb-run + vulkan).
## godot --path . --rendering-driver vulkan -s tests/screenshot.gd -- <out_dir> [shot names...]

# [name, player position, yaw degrees, pitch degrees]
const SHOTS := [
	["room", Vector3(-1.3, 0.05, 2.1), -28.0, -14.0],
	["desk", Vector3(-0.55, 0.05, -1.05), 8.0, -16.0],
	["window", Vector3(0.2, 0.05, 0.6), -75.0, -6.0],
	["bed", Vector3(-0.4, 0.05, -0.6), -128.0, -18.0],
	["corner", Vector3(1.2, 0.05, -0.4), 150.0, -14.0],
	["booth", Vector3(0.3, 0.05, 0.2), -35.0, -4.0],
]


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
	var only := args.slice(1)
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40:
		await process_frame
	if only.size() == 0 or only.has("menu"):
		await _save(out + "/shot_menu.png")
	main.start_game()
	main.sequencer.play()
	for i in 10:
		await process_frame

	for s in SHOTS:
		if only.size() > 0 and not only.has(s[0]):
			continue
		main.player.position = s[1]
		main.player.rotation.y = deg_to_rad(s[2])
		main.player.camera.rotation.x = deg_to_rad(s[3])
		for i in 6:
			await physics_frame
		await _save(out + "/shot_%s.png" % s[0])

	if only.size() == 0 or only.has("loopr"):
		main.open_loopr()
		for i in 8:
			await process_frame
		await _save(out + "/shot_loopr.png")
		var tabs: TabContainer = main.loopr.find_children("*", "TabContainer", true, false)[0]
		tabs.current_tab = 1
		await _save(out + "/shot_mixer.png")
	quit()
