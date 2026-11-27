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

	var want := func(n): return only.size() == 0 or only.has(n)

	if want.call("lineup"):
		var npcs := []
		var x := -0.35
		for r in Rappers.all():
			var n := NPC.new()
			main.add_child(n)
			n.setup(r)
			n.global_position = Vector3(x, 0, -0.1)
			n.rotation.y = deg_to_rad(-x * 18)
			n.say(r.name + "\n" + r.style, 30.0)
			npcs.append(n)
			x += 0.75
		main.player.position = Vector3(0.4, 0.05, 2.0)
		main.player.rotation.y = deg_to_rad(0)
		main.player.camera.rotation.x = deg_to_rad(-8)
		for i in 12:
			await physics_frame
		await _save(out + "/shot_lineup.png")
		for n in npcs:
			n.queue_free()

	if want.call("phone"):
		main.toggle_phone()
		await _save(out + "/shot_phone.png")
		main.toggle_phone()

	if want.call("session"):
		main.session.book(Rappers.BIG_EARL)
		var npc: NPC = main.session.npc as NPC
		npc.global_position = Session.PATH_IN.back()
		npc._path.clear()
		main.session._on_arrived()
		main.player.position = Vector3(-0.6, 0.05, -1.2)
		main.player.look_at_point(Vector3(1.45, 1.15, -1.3))
		for i in 12:
			await physics_frame
		await _save(out + "/shot_rapper.png")
		var sq: Sequencer = main.sequencer
		sq.clear()
		sq.bpm = 90
		for st in [0, 7, 10]:
			sq.set_step(0, st, true)
		for st in [4, 12]:
			sq.set_step(1, st, true)
		for st in [0, 2, 4, 6, 8, 10, 12, 14, 15]:
			sq.set_step(2, st, true)
		main.loopr.bpm_box.value = 90
		main.session.record_take()
		for i in 40:
			await process_frame
		await _save(out + "/shot_rapping.png")
		main.session.end_take()
		main.open_loopr()
		for i in 6:
			await process_frame
		await _save(out + "/shot_loopr_session.png")
		main.close_loopr()
		main.session.finish()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 1800:
			await process_frame
		await _save(out + "/shot_results.png")
		main.results.visible = false
		main._set_ui_mode(false)

	if want.call("cop"):
		main.chaos.call_police()
		var cop = main.chaos._cop
		cop.global_position = Vector3(-0.4, 0, 0.6)
		cop._path.clear()
		main.chaos._cop_arrived()
		main.player.position = Vector3(-0.6, 0.05, -1.2)
		main.player.look_at_point(Vector3(-0.4, 1.3, 0.6))
		for i in 12:
			await physics_frame
		await _save(out + "/shot_cop.png")

	if only.size() == 0 or only.has("loopr"):
		main.open_loopr()
		for i in 8:
			await process_frame
		await _save(out + "/shot_loopr.png")
		var tabs: TabContainer = main.loopr.find_children("*", "TabContainer", true, false)[0]
		tabs.current_tab = 1
		await _save(out + "/shot_mixer.png")
	quit()
