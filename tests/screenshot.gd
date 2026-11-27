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
	main.chaos.crashes_enabled = false
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
		main.call_ui.ring(Rappers.LIL_TEAR)
		main.toggle_phone()
		await _save(out + "/shot_phone.png")
		main.call_ui.decline()
		main.phone.open_thread("Lil Tear")
		await _save(out + "/shot_phone_chat.png")
		main.phone.open_app("huisraad")
		await _save(out + "/shot_phone_huisraad.png")
		main.phone.open_app("ruilmarkt")
		await _save(out + "/shot_phone_ruilmarkt.png")
		main.game.deliveries = 1
		main.game.check_goals()
		main.phone.open_app("goals")
		await _save(out + "/shot_phone_goals.png")
		main.toggle_phone()

	if want.call("furnished"):
		main.game.money = 2000
		for id in ["sofa", "rug_persian", "glass_table", "tv_console", "led_panel", "lamp_warm"]:
			main.game.buy_furniture(id)
		main.room.apply_furniture(main.game.placed)
		main.player.position = Vector3(1.1, 0.05, -1.5)
		main.player.rotation.y = deg_to_rad(128.0)
		main.player.camera.rotation.x = deg_to_rad(-12.0)
		for i in 20:
			await process_frame
		await _save(out + "/shot_furnished.png")

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

	if want.call("roll"):
		var sq: Sequencer = main.sequencer
		for i in 8:
			sq.set_note(i * 2, [0, 3, 7, 10, 12, 10, 7, 3][i], true)
		main.open_loopr()
		var tabs2: TabContainer = main.loopr.find_children("*", "TabContainer", true, false)[0]
		tabs2.current_tab = 1
		await _save(out + "/shot_roll.png")
		main.loopr.show_crash()
		await _save(out + "/shot_crash.png")
		main.loopr._crash.visible = false
		tabs2.current_tab = 0
		main.close_loopr()

	if want.call("shop"):
		main.game.money = 400
		main.toggle_phone()
		main.phone.open_app("gear")
		await _save(out + "/shot_shop.png")
		main.toggle_phone()

	if want.call("upgrades"):
		main.game.money = 5000
		for it in Shop.ITEMS:
			main.game.buy(it.id)
		main.room.apply_upgrades(main.game.upgrades)
		main.player.position = Vector3(-1.3, 0.05, 2.1)
		main.player.rotation.y = deg_to_rad(-28)
		main.player.camera.rotation.x = deg_to_rad(-12)
		for i in 8:
			await physics_frame
		await _save(out + "/shot_upgrades.png")
		main.player.position = Vector3(-0.2, 0.05, -0.2)
		main.player.rotation.y = deg_to_rad(-95)
		main.player.camera.rotation.x = deg_to_rad(-4)
		for i in 8:
			await physics_frame
		await _save(out + "/shot_neon.png")

	if want.call("night"):
		main.game.record_track("lil_tear", 4, 82)
		main.go_to_sleep()
		await _save(out + "/shot_night.png")
		main.results.visible = false
		main._set_ui_mode(false)

	var city_views: Array = []
	for n in only:
		if str(n).begins_with("city_"):
			city_views.append(str(n))
	if want.call("city") or city_views.size() > 0:
		if "city_step" in city_views:
			main.game.estep.owned = true
			main._spawn_step()
		main.travel(true)
		var c: CityBuilder = main.city
		if "city_step" in city_views:
			var sp: Vector3 = main.estep.position
			main.player.global_position = c.to_global(sp + Vector3(-1.6, 0.05, 2.6))
			main.player.look_at(c.to_global(sp + Vector3(0, 1.0, 0)), Vector3.UP)
			main.player.rotation.x = 0.0
			main.player.camera.rotation.x = deg_to_rad(-18.0)
			for i in 40:
				await process_frame
			await _save(out + "/shot_city_step.png")
			main.player.mount(main.estep)
			main.player.global_position = c.to_global(Vector3(-30, 0.05, -1.7))
			main.player.rotation.y = deg_to_rad(-90.0)
			main.estep.speed = 6.0
			for i in 40:
				await process_frame
			await _save(out + "/shot_city_ride.png")
			main.player.dismount()
		# [name, local pos, yaw deg, pitch deg]
		for v in [
			["city_home", Vector3(-42, 0.05, -6.5), 180.0, -2.0],
			["city_street", Vector3(-66, 0.05, 1.5), -80.0, 2.0],
			["city_shops", Vector3(-22, 0.05, 1.0), 0.0, 8.0],
			["city_casino", Vector3(-50, 0.05, -7.5), 180.0, 9.0],
			["city_east", Vector3(14, 0.05, 8.0), 25.0, 4.0],
			["city_quay", Vector3(24, 0.05, 37.5), 165.0, 3.0],
			["city_skyline", Vector3(10, 0.05, 38.6), 175.0, 7.0],
			["city_bridge", Vector3(-30, 0.05, 38.6), 120.0, 14.0],
			["city_alley", Vector3(20, 0.05, 30.0), 0.0, 4.0],
			["city_rain", Vector3(-30, 0.05, 8.2), -60.0, 3.0],
		]:
			if city_views.size() > 0 and not v[0] in city_views:
				continue
			if v[0] == "city_rain":
				c.apply_weather("rain")
			main.player.global_position = c.to_global(v[1])
			main.player.rotation.y = deg_to_rad(v[2])
			main.player.camera.rotation.x = deg_to_rad(v[3])
			for i in 40:
				await process_frame
			await _save(out + "/shot_%s.png" % v[0])
		if city_views.size() > 0:
			main.travel(false)
			quit()
			return
		main.game.money = 420
		main.open_shop("casino")
		await main.city_ui.spin_slots(50)
		await _save(out + "/shot_city_casino_ui.png")
		main.city_ui.close()
		main.open_shop("music")
		await _save(out + "/shot_city_music_ui.png")
		main.city_ui.close()
		main.open_shop("snackbar")
		await _save(out + "/shot_city_snack_ui.png")
		main.city_ui.close()
		main.travel(false)

	# metro, tram and the new districts: names start with "t_"
	var tviews: Array = []
	for n in only:
		if str(n).begins_with("t_"):
			tviews.append(str(n))
	if tviews.size() > 0:
		var tr: Transit = main.transit
		var pl = main.player
		var settle := func(n: int) -> void:
			for i in n:
				await process_frame
		if "t_entrance" in tviews:
			main.travel(true)
			var ep: Vector3 = main.city.metro_exit_point()
			pl.global_position = ep + Vector3(-5.0, 0, -3.5)
			pl.look_at(main.city.metro_entrance.global_position + Vector3(0, 1.2, 0), Vector3.UP)
			pl.rotation.x = 0.0
			pl.camera.rotation.x = deg_to_rad(4.0)
			await settle.call(40)
			await _save(out + "/shot_t_entrance.png")
		if "t_platform" in tviews or "t_depart" in tviews or "t_tunnel" in tviews:
			main.travel(true)
			main.enter_metro("zuidkade")
			await settle.call(50)
			tr.next_in = 0.0
			for k in 600:
				tr._cycle(0.05)
				if tr.state == "dwell" and tr.door_f > 0.95:
					break
			tr.t = 0.0
			if "t_platform" in tviews:
				pl.global_position = tr.to_global(Vector3(-6.0, 0.05, 7.2))
				pl.rotation.y = deg_to_rad(-35.0)
				pl.camera.rotation.x = deg_to_rad(-4.0)
				await settle.call(40)
				await _save(out + "/shot_t_platform.png")
			main._board("metro", "centraal")
			# freeze the automatic ride so we can photograph its stages
			tr.set_process(false)
			if "t_depart" in tviews:
				tr.door_f = 0.0
				RoomBuilder.set_doors(tr.train_doors, 0.0)
				tr.state = "departing"
				tr.t = 3.2
				tr.train.position.x = 0.5 * Transit.ACCEL * tr.t * tr.t
				tr._ride_update(0.0)
				pl.camera.rotation.x = deg_to_rad(-2.0)
				await settle.call(30)
				await _save(out + "/shot_t_depart.png")
			if "t_tunnel" in tviews:
				tr.state = "departing"
				tr.train.position.x = 120.0
				tr._ride_update(0.0)
				pl.rotation.y += deg_to_rad(30.0)
				await settle.call(30)
				await _save(out + "/shot_t_tunnel.png")
			tr.set_process(true)
			tr.skip_ride()
			main.exit_metro()
			await settle.call(50)
		if "t_tramstop" in tviews or "t_tram_inside" in tviews:
			main.travel(true)
			var e: Dictionary = main.city.tram4
			(e.node as Node3D).position.x = main.city.tram_stop_x
			e.served = false
			e.dwell = 14.0
			e.door_f = 1.0
			RoomBuilder.set_doors(e.doors, 1.0, -1.0)
			main.city.set_process(false)
			if "t_tramstop" in tviews:
				pl.global_position = main.city.to_global(Vector3(-16.0, 0.05, 8.3))
				pl.look_at(main.city.to_global(Vector3(-8.0, 1.6, 2.2)), Vector3.UP)
				pl.rotation.x = 0.0
				pl.camera.rotation.x = deg_to_rad(-3.0)
				await settle.call(40)
				await _save(out + "/shot_t_tramstop.png")
			if "t_tram_inside" in tviews:
				main._tram_entry = e
				main._tram_builder = main.city
				main._board("tram", "centraal")
				main.transit._ride_update(0.0)
				pl.rotation.y += deg_to_rad(-25.0)
				pl.camera.rotation.x = deg_to_rad(-2.0)
				await settle.call(40)
				await _save(out + "/shot_t_tram_inside.png")
				main.transit.cancel_ride()
			main.city.set_process(true)
		for spec in [["t_centraal", "centraal", Vector3(0.0, 0.05, 4.0), 10.0, 14.0], ["t_markt", "markt", Vector3(22.0, 0.05, 4.0), 70.0, 8.0],
				["t_markt_shops", "markt", Vector3(-18.0, 0.05, 1.0), 180.0, 6.0],
				["t_haven", "haven", Vector3(-5.0, 0.05, 15.0), 160.0, 8.0], ["t_haven_water", "haven", Vector3(0.0, 0.05, 13.0), 0.0, 6.0]]:
			if not spec[0] in tviews:
				continue
			main._activate_area(spec[1])
			var d: DistrictBuilder = main.districts[spec[1]]
			pl.global_position = d.to_global(spec[2])
			pl.rotation.y = deg_to_rad(spec[3])
			pl.camera.rotation.x = deg_to_rad(spec[4])
			await settle.call(60)
			await _save(out + "/shot_%s.png" % spec[0])
		quit()
		return

	if want.call("daw"):
		var sq: Sequencer = main.sequencer
		sq.stop()
		sq.select_pattern(0)
		sq.clear()
		sq.bpm = 142
		for st in [0, 10]:
			sq.set_step(0, st, true)
		sq.set_step(1, 8, true)
		for st in range(0, 16, 2):
			sq.set_step(2, st, true)
		sq.set_velocity(2, 2, 0.45)
		sq.set_velocity(2, 6, 0.55)
		sq.set_roll(2, 7, 3)
		sq.set_roll(2, 14, 4)
		sq.set_roll(2, 15, 2)
		sq.set_velocity(1, 13, 0.3)
		for b in [[0, 0], [3, 3], [6, 7], [10, 5], [13, 3]]:
			sq.set_bass(b[0], b[1], true)
		sq.set_glide(true)
		for n in [[0, 7], [0, 3], [4, 8], [8, 10], [8, 3], [12, 7]]:
			sq.set_note(n[0], n[1], true)
		sq.set_swing(0.12)
		sq.clone_to_next()
		sq.set_roll(2, 4, 3)
		sq.set_step(3, 8, true)
		sq.select_pattern(0)
		for b in [[0, 0], [1, 0], [2, 1], [3, 1], [4, 0], [5, 1]]:
			sq.set_bar(b[0], b[1])
		sq.set_reverb(AudioServer.get_bus_index("Keys"), 0.35)
		sq.set_volume(sq.bus_index(0), 0.7)
		sq.set_pan(sq.bus_index(2), 0.3)
		sq.set_locut(sq.bus_index(2), true)
		main.open_loopr()
		main.loopr.set_tool("vel")
		sq.play()
		for i in 20:
			await process_frame
		var tabs3: TabContainer = main.loopr.tabs
		await _save(out + "/shot_daw_rack.png")
		main.loopr.set_tool("draw")
		tabs3.current_tab = 1
		main.loopr.set_lane("808")
		for i in 4:
			await process_frame
		await _save(out + "/shot_daw_808.png")
		main.loopr.set_lane("melody")
		tabs3.current_tab = 2
		sq.set_song_mode(true)
		for i in 10:
			await process_frame
		await _save(out + "/shot_daw_playlist.png")
		sq.set_song_mode(false)
		tabs3.current_tab = 3
		for i in 6:
			await process_frame
		await _save(out + "/shot_daw_mixer.png")
		sq.stop()
		tabs3.current_tab = 0
		main.close_loopr()

	if only.size() == 0 or only.has("loopr"):
		main.open_loopr()
		for i in 8:
			await process_frame
		await _save(out + "/shot_loopr.png")
		var tabs: TabContainer = main.loopr.find_children("*", "TabContainer", true, false)[0]
		tabs.current_tab = 1
		await _save(out + "/shot_mixer.png")
	quit()
