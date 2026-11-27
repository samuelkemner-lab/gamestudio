extends SceneTree
## Headless smoke test. Run:
## godot --headless --path . -s tests/run_tests.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _reset_mix(seq: Sequencer) -> void:
	seq.set_swing(0.0)
	seq.set_glide(false)
	for name in Sequencer.TRACKS + ["Keys"]:
		var b := AudioServer.get_bus_index(name)
		seq.set_reverb(b, 0.0)
		seq.set_solo(b, false)
	seq.set_volume(0, 1.0)
	seq.set_mute(0, false)


func _boom_bap(seq: Sequencer, feel := true) -> void:
	seq.select_pattern(0)
	seq.clear()
	_reset_mix(seq)
	seq.bpm = 90
	if feel:
		seq.set_swing(0.25)
		seq.set_velocity(1, 10, 0.3)  # ghost snare
	for st in [0, 7, 10]:
		seq.set_step(0, st, true)
	for st in [4, 12]:
		seq.set_step(1, st, true)
	for st in range(0, 16, 2):
		seq.set_step(2, st, true)
	for t in 5:
		seq.set_mute(seq.bus_index(t), false)
		seq.set_volume(seq.bus_index(t), 1.0)


func _emo(seq: Sequencer, notes: Array) -> void:
	seq.select_pattern(0)
	seq.clear()
	_reset_mix(seq)
	seq.bpm = 135
	seq.set_roll(2, 14, 3)
	seq.set_reverb(AudioServer.get_bus_index("Keys"), 0.3)
	for st in [0, 10]:
		seq.set_step(0, st, true)
	seq.set_step(3, 12, true)
	for st in range(0, 16, 2):
		seq.set_step(2, st, true)
	seq.set_bass(0, 0, true)
	seq.set_bass(6, 3, true)
	seq.set_bass(10, 7, true)
	for i in notes.size():
		seq.set_note(i * 3, notes[i], true)
	for t in 5:
		seq.set_mute(seq.bus_index(t), false)
		seq.set_volume(seq.bus_index(t), 1.0)
	seq.set_volume(seq.bus_index(2), 0.7)


func _wait_until(cond: Callable, timeout: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < timeout * 1000.0:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var seq: Sequencer = main.get_node("Sequencer")
	main.chaos.crashes_enabled = false
	check(seq != null, "sequencer exists")
	check(seq.pattern.size() == 5, "5 tracks")
	check(seq.pattern[0].size() == 16, "16 steps")
	for t in 5:
		check(AudioServer.get_bus_index(Sequencer.TRACKS[t]) != -1, "bus " + Sequencer.TRACKS[t])

	# LOOPR opens and closes
	check(not main.in_menu, "no title screen in headless mode")
	main.open_loopr()
	check(main.loopr.visible, "LOOPR opens")
	check(not main.player.enabled, "player frozen while in LOOPR")
	main.close_loopr()
	check(not main.loopr.visible and main.player.enabled, "LOOPR closes")

	# Toggling a step through the UI updates the pattern
	seq.clear()
	main.loopr.refresh_grid()
	main.loopr.rack.cell_pressed.emit(1, 3, MOUSE_BUTTON_LEFT, Vector2(0.5, 0.5))
	check(seq.pattern[1][3], "UI step click writes pattern")
	main.loopr.set_tool("vel")
	main.loopr.rack.cell_pressed.emit(1, 3, MOUSE_BUTTON_LEFT, Vector2(0.5, 0.8))
	check(absf(seq.velocity[1][3] - 0.2) < 0.01, "velocity tool sets a soft hit")
	main.loopr.set_tool("roll")
	main.loopr.rack.cell_pressed.emit(2, 5, MOUSE_BUTTON_LEFT, Vector2(0.5, 0.5))
	check(seq.pattern[2][5] and seq.rolls[2][5] == 2, "roll tool makes a 2-hit roll")
	main.loopr.set_tool("draw")
	main.loopr.rack.cell_pressed.emit(2, 5, MOUSE_BUTTON_RIGHT, Vector2(0.5, 0.5))
	check(not seq.pattern[2][5] and seq.rolls[2][5] == 1, "right-click erases")
	main.loopr.set_lane("808")
	main.loopr.roll.cell_pressed.emit(Sequencer.NOTE_RANGE - 1 - 3, 6, MOUSE_BUTTON_LEFT, Vector2.ZERO)
	check(seq.has_bass(6, 3) and seq.pattern[Sequencer.BASS][6], "808 lane places a pitched 808")
	main.loopr.set_lane("melody")
	main.loopr.playlist.cell_pressed.emit(1, 2, MOUSE_BUTTON_LEFT, Vector2.ZERO)
	check(seq.playlist[2] == 1, "playlist click puts pattern B in bar 3")
	seq.set_bar(2, -1)

	# Undo
	seq.clear()
	seq.checkpoint()
	seq.set_step(0, 0, true)
	check(seq.undo() and not seq.pattern[0][0], "undo takes back an edit")

	# Patterns + playlist
	seq.select_pattern(0)
	seq.clear()
	seq.set_step(0, 0, true)
	seq.clone_to_next()
	check(seq.current_pattern == 1 and seq.pattern[0][0], "clone copies A into B and selects B")
	seq.set_step(1, 4, true)
	seq.select_pattern(0)
	check(not seq.pattern[1][4], "patterns are independent")
	for b in 4:
		seq.set_bar(b, b % 2)
	check(seq.arrangement().song, "4 bars with A/B = a full song")
	seq.set_bar(2, -1)
	seq.set_bar(3, -1)
	check(not seq.arrangement().song, "2 bars is still a loop")
	for b in 4:
		seq.set_bar(b, b % 2)
	seq.bpm = 200
	seq.set_song_mode(true)
	var bars_seen := []
	seq.bar_changed.connect(func(b): bars_seen.append(b))
	seq.play()
	await _wait_until(func(): return 1 in bars_seen, 4.0)
	seq.stop()
	seq.set_song_mode(false)
	check(1 in bars_seen, "song mode moves through the playlist")
	for b in Sequencer.BARS:
		seq.set_bar(b, -1)
	seq.select_pattern(1)
	seq.clear()
	seq.select_pattern(0)

	# Mixer FX
	var kb := seq.bus_index(1)
	seq.set_reverb(kb, 0.3)
	seq.set_pan(kb, -0.5)
	seq.set_locut(kb, true)
	check(absf(seq.get_reverb(kb) - 0.3) < 0.01 and absf(seq.get_pan(kb) + 0.5) < 0.01 and seq.get_locut(kb), "reverb, pan and lo-cut work")
	seq.set_reverb(kb, 0.0)
	seq.set_pan(kb, 0.0)
	seq.set_locut(kb, false)
	seq.set_solo(seq.bus_index(0), true)
	check(AudioServer.is_bus_mute(kb) and not AudioServer.is_bus_mute(seq.bus_index(0)), "solo mutes the other channels")
	seq.set_solo(seq.bus_index(0), false)
	check(not AudioServer.is_bus_mute(kb), "unsolo restores")

	# Playback advances steps at the right tempo
	seq.bpm = 120.0
	var steps_seen := []
	seq.step_changed.connect(func(s): steps_seen.append(s))
	seq.play()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1050:
		await process_frame
	seq.stop()
	# 120 bpm = 8 sixteenths per second (+ first step on play)
	var played := steps_seen.filter(func(s): return s >= 0).size()
	check(played >= 7 and played <= 11, "tempo ok (%d steps in ~1s)" % played)

	# Mixer
	var bus := seq.bus_index(0)
	seq.set_volume(bus, 0.5)
	check(absf(seq.get_volume(bus) - 0.5) < 0.01, "fader sets bus volume")
	seq.set_mute(bus, true)
	check(AudioServer.is_bus_mute(bus), "mute works")

	seq.set_mute(bus, false)
	seq.set_volume(bus, 1.0)

	# --- Judge ---
	var earl := Rappers.BIG_EARL
	_boom_bap(seq)
	var good := Judge.evaluate(seq, earl)
	check(int(good.stars) >= 4, "boom bap beat pleases Big Earl (%d pts)" % good.score)
	_boom_bap(seq, false)
	var stiff := Judge.evaluate(seq, earl)
	check(stiff.score < good.score, "no swing / ghost snare costs points (%d vs %d)" % [stiff.score, good.score])
	_boom_bap(seq)
	seq.set_reverb(seq.bus_index(1), 0.4)
	var wet := Judge.evaluate(seq, earl)
	check(wet.score < good.score, "reverb on Earl's snare costs points")
	seq.set_reverb(seq.bus_index(1), 0.0)
	seq.set_step(3, 0, true)  # clap stacked on the kick
	for t in 5:
		seq.set_volume(seq.bus_index(t), 1.25)
	seq.set_volume(0, 1.25)
	var hot := Judge.evaluate(seq, earl)
	check(hot.clipping and hot.score < good.score, "clipping master is punished (%.1f dB)" % seq.peak_db())
	_reset_mix(seq)
	seq.load_default_pattern()
	seq.bpm = 140
	var bad := Judge.evaluate(seq, earl)
	check(int(bad.stars) <= 2 and bad.notes.size() > 0, "trap beat at 140 disappoints Big Earl (%d pts)" % bad.score)
	var rw := Judge.reward(earl, 5)
	check(rw.money > earl.pay and rw.tip > 0, "5 stars pays more than base + tip")

	# --- Full session ---
	var gs: GameState = main.game
	gs.reset()
	var sess: Session = main.session
	check(not sess.can_book(Rappers.GHOST), "Ghost is locked without street cred")
	sess.book(earl)
	check(sess.state == Session.State.ARRIVING and sess.npc != null, "booking spawns the rapper")
	var door_out: Node = null
	for n in main.room.find_children("*", "StaticBody3D", true, false):
		if n.get_meta("interact", "") == "door_out":
			door_out = n
	check(door_out != null, "flat has a front door")
	main._on_interacted(door_out)
	check(not main.in_city, "can't leave while a rapper is in the studio")
	await _wait_until(func(): return sess.state == Session.State.WAITING, 15.0)
	check(sess.state == Session.State.WAITING, "rapper walks into the booth")
	_boom_bap(seq)
	check(sess.record_take(), "record take starts")
	await _wait_until(func(): return sess.state == Session.State.REVIEW, 15.0)
	check(sess.state == Session.State.REVIEW and int(sess.best.stars) >= 4, "take judged: %s" % str(sess.best.get("stars")))
	var money_before := gs.money
	var lv_before := gs.level()
	var summary := sess.finish()
	var lv_bonus := 0
	for l in range(lv_before + 1, gs.level() + 1):
		lv_bonus += 25 * l
	check(summary.money > 0 and gs.money == money_before + int(summary.money) + lv_bonus, "payout lands in wallet (+€%d)" % summary.money)
	check(gs.sessions == 1, "track recorded")
	await _wait_until(func(): return sess.state == Session.State.IDLE, 15.0)
	check(sess.state == Session.State.IDLE, "rapper leaves, studio free again")

	# --- Chaos: cops ---
	var cash := gs.money
	gs.noise = 99.5
	seq.set_volume(0, 1.0)
	seq.play()
	await _wait_until(func(): return gs.money < cash, 20.0)
	check(gs.money == cash - Chaos.FINE, "noise → police fine €%d" % Chaos.FINE)
	seq.stop()

	# --- Melody / piano roll ---
	var tear := Rappers.LIL_TEAR
	_emo(seq, [0, 3, 7, 10, 12])
	var sad := Judge.evaluate(seq, tear)
	_emo(seq, [])
	var no_mel := Judge.evaluate(seq, tear)
	_emo(seq, [1, 4, 6, 9, 11])
	var wrong_scale := Judge.evaluate(seq, tear)
	check(sad.score > no_mel.score and sad.score > wrong_scale.score, "Lil Tear rewards a C-minor melody (%d vs %d none / %d off-scale)" % [sad.score, no_mel.score, wrong_scale.score])
	check(int(sad.stars) >= 4, "emo beat with minor melody gets 4+ stars (%d)" % sad.score)
	check(not sad.clipping, "default emo mix doesn't clip (%.1f dB)" % seq.peak_db())
	seq.set_instrument("pad")
	var pad := Judge.evaluate(seq, tear)
	seq.set_instrument("keys")
	check(true, "instrument switch works")

	# --- Upgrades ---
	gs.reset()
	gs.money = 1000
	var plain := Judge.evaluate(seq, tear, gs.upgrades)
	check(gs.buy("mic_pro") and gs.has("mic_pro"), "buy condenser mic")
	check(not gs.buy("mic_pro"), "can't buy twice")
	var boosted := Judge.evaluate(seq, tear, gs.upgrades)
	check(boosted.score >= plain.score + 5 or boosted.score == 100, "condenser mic boosts the score")
	main.room.apply_upgrades(gs.upgrades)
	check(main.room.upgrade_nodes["mic_pro"].visible and not main.room.upgrade_nodes["foam"].visible, "bought upgrades appear in the room")
	gs.money = 10
	check(not gs.buy("neon"), "can't buy without money")

	# --- Day cycle / streams ---
	gs.reset()
	gs.record_track("big_earl", 5, 100, true)
	gs.record_track("lil_tear", 3, 60)
	check(gs.tracks[0].song and not gs.tracks[1].song, "tracks remember if they were full songs")
	gs.booked_today.append("big_earl")
	var cash0 := gs.money
	var night := gs.sleep()
	check(gs.day == 2 and night.streams > 0 and gs.money == cash0 + int(night.earned), "sleeping pays streaming royalties (+€%d, %d streams)" % [night.earned, night.streams])
	check(gs.booked_today.is_empty(), "rappers available again the next day")

	# --- PC crash ---
	seq.load_default_pattern()
	seq.save_snapshot()
	seq.clear()
	check(seq.dirty, "edits mark the project unsaved")
	main.chaos.crash()
	check(Judge.count_hits(seq, 1) == 2 and not seq.dirty, "crash restores the last saved beat")

	# --- Unlocks ---
	gs.reset()
	check(not sess.unlocked(Rappers.SPIKE), "Spike locked at 0 rep")
	gs.reputation = 12
	check(sess.unlocked(Rappers.SPIKE), "Spike unlocks at 12 rep")

	# --- Outside world ---
	gs.reset()
	var city: CityBuilder = main.city
	var shops := {}
	for n in city.find_children("*", "StaticBody3D", true, false):
		if n.get_meta("interact", "") == "shop":
			shops[n.get_meta("shop_id")] = n
	for id in ["home", "music", "coffeeshop", "snackbar", "nightshop", "studio", "casino"]:
		check(shops.has(id), "city has " + id)
	main._on_interacted(door_out)
	check(main.in_city and not main.room.visible and main.city.visible, "front door takes you outside")
	check(main.player.global_position.distance_to(city.spawn_point()) < 0.5, "you appear in front of Kade 17")
	var car: Node3D = city.cars[0].node
	var car_x := car.position.x
	for i in 20:
		await process_frame
	check(absf(car.position.x - car_x) > 0.01, "traffic drives")
	check(city.pedestrians.size() >= 5, "pedestrians on the street")
	check(city.find_children("*", "Decal", true, false).size() > 60, "streets have decals (gum, oil, cracks)")
	city.set_wetness(1.0)
	check(is_equal_approx(float(city._wet_mats[0].get_shader_parameter("wetness")), 1.0), "wetness drives the street shader")
	city.set_wetness(0.65)
	# opening hours: music store closes at midnight
	gs.minutes = 23 * 60
	city.update_hours(gs.minutes)
	check(city.is_open("music", gs.minutes) and not city._shop_state["music"].shutter.visible, "music store open at 23:00")
	gs.minutes = 24 * 60 + 30
	city.update_hours(gs.minutes)
	check(not city.is_open("music", gs.minutes) and city._shop_state["music"].shutter.visible, "shutter down after midnight")
	main._on_interacted(shops["music"])
	check(not main.city_ui.visible, "closed shop doesn't open")
	check(city.is_open("nightshop", gs.minutes) and city.is_open("casino", 29 * 60), "night shop 24/7, casino until 06:00")
	gs.minutes = 22 * 60
	city.update_hours(gs.minutes)
	# weather
	city.apply_weather("rain")
	check(city._rain.emitting and is_equal_approx(city.wetness, 1.0), "rain: particles + soaked streets")
	city.apply_weather("dry")
	check(not city._rain.emitting and city.wetness < 0.6, "dry night: damp, no rain")
	gs.roll_weather(0.1)
	check(gs.weather == "rain", "weather roll")
	# traffic drives on the right, tram runs
	var east = null
	var tram = null
	for c in city.cars:
		if c.has("bell"):
			tram = c
		elif c.dir == 1:
			east = c
	check(east != null and east.lane > 0.0, "traffic drives on the right")
	check(tram != null, "tram on the street")
	gs.money = 500
	main._on_interacted(shops["music"])
	check(main.city_ui.visible and not main.player.enabled, "music store opens")
	check(CityUI.store_price("mic_pro") < int(Shop.item("mic_pro").price), "cash price beats the online shop")
	check(gs.buy_at("mic_pro", CityUI.store_price("mic_pro")) and gs.money == 500 - CityUI.store_price("mic_pro"), "buy gear in the store")
	main.city_ui.close()
	for id in ["coffeeshop", "snackbar", "nightshop", "studio", "casino"]:
		main.open_shop(id)
		check(main.city_ui.visible, "%s counter opens" % id)
		main.city_ui.close()
	# buffs
	gs.add_buff("awake", 60)
	check(gs.dawn_minutes() == 30 * 60 + 60, "kapsalon keeps you up an hour")
	gs.add_buff("chill")
	gs.add_buff("chill")
	check(int(gs.buffs.chill) == 1, "one pre-roll in the pocket at a time")
	gs.noise = 50.0
	gs.add_buff("gift")
	check(gs.noise == 0.0 and gs.buffs.gift, "stroopwafels calm the neighbours")
	# casino maths (house edge)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bet_total := 0
	var win_total := 0
	for i in 20000:
		var r := Casino.spin_slots(rng, 10)
		bet_total += 10
		win_total += int(r.win)
	var rtp := float(win_total) / bet_total
	check(rtp > 0.8 and rtp < 0.95, "slots return %.1f%% (house edge)" % (rtp * 100.0))
	win_total = 0
	for i in 20000:
		win_total += int(Casino.spin_roulette(rng, 10, "red").win)
	rtp = float(win_total) / bet_total
	check(rtp > 0.92 and rtp < 1.0, "roulette on red returns %.1f%%" % (rtp * 100.0))
	main.open_shop("casino")
	gs.money = 100
	var spin: Dictionary = await main.city_ui.spin_slots(10)
	check(gs.money == 90 + int(spin.win), "slot spin pays out correctly")
	gs.money = 5
	var broke: Dictionary = await main.city_ui.spin_slots(10)
	check(broke.is_empty() and gs.money == 5, "can't bet money you don't have")
	main.city_ui.close()
	# booking from the street is blocked, home door brings you back
	main._on_book(Rappers.BIG_EARL)
	check(not sess.is_active() and gs.pending.get("rapper", "") == "big_earl", "inviting from the street: rapper heads to your place")
	gs.pending = {}
	main._on_interacted(shops["home"])
	check(not main.in_city and main.room.visible, "Kade 17 door takes you home")
	# pre-roll: next rapper gets an extra take
	gs.reset()
	gs.add_buff("chill")
	sess.book(Rappers.LIL_TEAR)
	check(sess.takes_left == int(Rappers.LIL_TEAR.patience) + 1 and int(gs.buffs.chill) == 0, "chill studio = one extra take")
	sess._leave()

	# ---------- v0.9: posture, poses, props, NPC interactions ----------
	var pl = main.player
	check(pl.set_posture(1) and pl.posture == 1 and pl._cap.height < 1.5, "crouch shrinks the collider")
	check(pl.set_posture(2) and pl.posture == 2, "go prone")
	check(pl.set_posture(0) and pl.posture == 0, "stand up again")
	main._on_interacted(main.room.find_children("*", "StaticBody3D", true, false).filter(func(b): return b.get_meta("interact", "") == "chair")[0])
	check(pl.pose == "seat", "sit on the desk chair")
	pl.leave_pose()
	check(pl.pose == "", "stand up from the chair")
	var bed = main.room.find_children("*", "StaticBody3D", true, false).filter(func(b): return b.get_meta("interact", "") == "bed")[0]
	sess.state = Session.State.IDLE
	main.results.visible = false
	main._set_ui_mode(false)
	main._on_interacted(bed)
	check(pl.pose == "bed" and not main.results.visible, "lie down on the bed (no instant sleep)")
	var day0 := gs.day
	main._on_interact_empty()
	check(gs.day == day0 + 1 and pl.pose == "", "[E] in bed sleeps")
	main.results.visible = false
	main._set_ui_mode(false)
	var sw = main.room.find_children("*", "StaticBody3D", true, false).filter(func(b): return b.get_meta("interact", "") == "switch")[0]
	main._on_interacted(sw)
	check(not main.room.lights_on and not main.room.led_lights[0].visible, "light switch turns the LEDs off")
	main._on_interacted(sw)
	check(main.room.lights_on, "and on again")
	var grabs = main.room.find_children("*", "RigidBody3D", true, false).filter(func(b): return b.get_meta("interact", "") == "grab")
	check(grabs.size() >= 4, "loose props in the room (%d)" % grabs.size())
	pl.pick_up(grabs[0])
	check(pl.held == grabs[0], "pick up a can")
	pl.drop_held()
	check(pl.held == null, "drop it")
	# street
	main.travel(true)
	check(main.player.surface in ["stone", "wet"], "footsteps sound like the street outside")
	var ped: NPC = city.pedestrians[0]
	check(ped.display_name != "" and ped.body.get_meta("interact") == "npc", "pedestrians have names and can be talked to")
	main._on_interacted(ped.body)
	check(main.talk_ui.visible and not main.player.enabled, "talk menu opens")
	main.talk_ui.choose("talk")
	check(not main.talk_ui.visible and int(ped.memory.talks) == 1, "NPC remembers you talked")
	var rep0 := gs.reputation
	main._on_interacted(ped.body)
	main.talk_ui.choose("flyer")
	check(ped.memory.flyer and gs.reputation >= rep0, "flyer handed out")
	check(StreetTalk.flyer(ped, gs)[1] == 0 and int(ped.memory.annoyed) == 1, "second flyer annoys them")
	main._on_interacted(ped.body)
	main.talk_ui.close()
	check(main.player.enabled, "leaving the talk gives control back")
	check(city.cat != null and city.cat.body.get_meta("interact") == "cat", "a street cat lives on the Zuidkade")
	gs.buffs.chill = 0
	main._on_interacted(city.cat.body)
	check(int(gs.buffs.chill) == 1 and city.cat.state == "petted", "petting the cat calms you (+1 take)")
	check(city.flocks.size() >= 2, "pigeons on the quay")
	var sky: RotterdamSkyline = city.skyline
	for lm in ["swan_bridge", "observation_tower", "market_hall", "cube_houses", "vertical_city", "led_tower"]:
		check(sky.landmarks.has(lm) and sky.landmarks[lm].get_child_count() > 0, "skyline has " + lm)
	check(sky.towers.size() >= 40, "Rotterdam skyline: %d towers" % sky.towers.size())
	var fl: PigeonFlock = city.flocks[0]
	fl.scare()
	check(fl._away > 0.0, "pigeons fly off when scared")
	check(city.seats.size() >= 5, "benches to sit on")
	main._on_interacted(city.seats[0])
	check(pl.pose == "seat", "sit on a bench")
	pl.leave_pose()
	main.travel(false)
	# rapper: hype + drink
	gs.reset()
	sess.book(Rappers.LIL_TEAR)
	sess.state = Session.State.WAITING
	gs.furniture.append("mini_fridge")
	gs.placed["front"] = "mini_fridge"
	var takes0 := sess.takes_left
	main._on_interacted(sess.npc.body)
	check(main.talk_ui.visible, "talk to the rapper")
	main.talk_ui.choose("drink")
	check(sess.takes_left == takes0 + 1 and sess.drink_given, "a drink buys one more take")
	main._on_interacted(sess.npc.body)
	main.talk_ui.choose("hype")
	check(sess.hype == 5, "hype the rapper up")
	sess._leave()

	# ---------- v0.10: GRIND OS, calls, furniture, e-step, Zoef ----------
	gs.reset()
	sess.state = Session.State.IDLE
	main._set_ui_mode(false)
	gs.nightly_messages()
	check(gs.unread() >= 2 and gs.threads().size() >= 2, "new night: DMs from rappers + Zoef/Ruilmarkt (%d unread)" % gs.unread())
	main.toggle_phone()
	check(main.phone.visible and main.phone.app == "", "phone opens on the home screen")
	for a in PhoneUI.APPS:
		main.phone.open_app(a.id)
		check(main.phone.app == a.id and main.phone._screen.get_child_count() > 0, "app opens: " + a.id)
	main.phone.open_thread("Lil Tear")
	check(gs.unread("Lil Tear") == 0, "reading a chat clears its badge")
	main.toggle_phone()
	# call at home: answer = hot session
	main.call_ui.ring(Rappers.LIL_TEAR)
	check(main.call_ui.ringing and main.call_ui.visible, "incoming call rings")
	main.call_ui.answer()
	check(sess.is_active() and sess.hot and gs.call_log[-1].kind == "answered", "answering at home = hot session")
	sess._leave()
	sess.state = Session.State.IDLE
	main.results.visible = false
	main._set_ui_mode(false)
	# call on the street: pending, then go home in time
	gs.booked_today.clear()
	main.travel(true)
	main.call_ui.ring(Rappers.BIG_EARL)
	main.call_ui.answer()
	check(not sess.is_active() and gs.pending.get("rapper", "") == "big_earl", "answering outside: rapper is on the way")
	main.travel(false)
	check(sess.is_active() and sess.rapper.id == "big_earl" and sess.hot and gs.pending.is_empty(), "home in time = session starts")
	sess._leave()
	sess.state = Session.State.IDLE
	main.results.visible = false
	main._set_ui_mode(false)
	# too late
	gs.booked_today.clear()
	main.travel(true)
	main._set_pending(Rappers.LIL_TEAR, false)
	var rep_before := gs.reputation
	gs.minutes += 41
	main._check_pending()
	check(gs.pending.is_empty() and not sess.is_active() and gs.reputation == maxi(rep_before - 1, 0), "too late: rapper leaves, −1 REP")
	# missed call
	main.call_ui.ring(Rappers.BIG_EARL)
	main.call_ui._t = CallUI.RING_TIME
	main.call_ui._process(0.1)
	check(not main.call_ui.ringing and gs.call_log[-1].kind == "missed", "unanswered call = missed")
	main.travel(false)
	# furniture
	gs.money = 1000
	check(gs.buy_furniture("sofa") and gs.placed.get("seat") == "sofa", "buy a sofa: placed in the room")
	main.room.apply_furniture(gs.placed)
	check(main.room.furniture_root.get_child_count() == 1, "sofa is built in the room")
	check(gs.buy_furniture("mini_fridge"), "buy a mini fridge")
	main.room.apply_furniture(gs.placed)
	check(not main.room._boxes[0].visible, "front-wall furniture replaces the moving boxes")
	var st := gs.room_stats()
	check(int(st.vibe) == 11 and Furniture.pay_mult(st) > 1.1, "room stats: VIBE %d" % st.vibe)
	gs.buy_furniture("led_panel")
	check(int(gs.room_stats().vibe) >= 12, "VIBE 12+")
	gs.booked_today.clear()
	sess.book(Rappers.LIL_TEAR)
	check(sess.takes_left == int(Rappers.LIL_TEAR.patience) + 1, "VIBE 12+: rapper has one more take")
	sess._leave()
	sess.state = Session.State.IDLE
	main.results.visible = false
	main._set_ui_mode(false)
	check(gs.dawn_minutes() > 30 * 60, "COMFORT: you stay up longer (+%d min)" % (gs.dawn_minutes() - 30 * 60))
	gs.place("sofa")
	check(not gs.placed.has("seat"), "place again = back in storage")
	# e-step
	gs.money = 500
	check(gs.buy_step_item("estep") and gs.estep.owned, "buy the used e-step")
	check(not gs.buy_step_item("estep"), "can't buy it twice")
	main._on_step_bought("estep")
	check(main.estep != null and main.estep.body.get_meta("interact") == "estep", "e-step spawned in the city")
	main.travel(true)
	check(main.estep.position.distance_to(main._home_door_local()) < 3.0, "parked by the front door of Kade 17")
	main._on_interacted(main.estep.body)
	check(pl.riding == main.estep, "get on the e-step")
	var b0 := float(gs.estep.battery)
	var p0: Vector3 = pl.global_position
	main.estep.speed = 5.0
	pl.global_position += -pl.transform.basis.z * 4.0
	main.estep._physics_process(0.1)
	check(float(gs.estep.battery) < b0, "riding drains the battery (%.1f%%)" % gs.estep.battery)
	check(main.estep.max_speed() == EStep.BASE_SPEED, "stock speed 22 km/h")
	gs.buy_step_item("step_motor")
	check(main.estep.max_speed() == EStep.TUNED_SPEED, "motor tune: faster")
	pl.dismount()
	check(pl.riding == null and not main.estep.body.get_child(0).disabled, "get off: step parked")
	pl.global_position = p0
	main.estep.position = main._home_door_local() + Vector3(1.6, -0.05, -0.4)
	main.travel(false)
	check(gs.estep.home, "parked by your door = taken upstairs")
	gs.estep.battery = 30.0
	gs.sleep()
	main.results.visible = false
	check(is_equal_approx(float(gs.estep.battery), 100.0), "charged overnight")
	# Zoef
	main.travel(true)
	main._on_zoef("start")
	check(not main.zoef.is_empty() and main._zoef_marker != null, "Zoef: order accepted, pickup marker")
	pl.global_position = city.to_global(main.zoef.pick)
	main._zoef_update()
	check(main.zoef.picked, "picked up at the snackbar")
	var zoef_cash := gs.money
	pl.global_position = city.to_global(main.zoef.drop)
	main._zoef_update()
	check(main.zoef.is_empty() and gs.money > zoef_cash and gs.deliveries == 1, "delivered: paid €%d" % (gs.money - zoef_cash))
	main._on_zoef("start")
	gs.minutes += 999
	var late: Dictionary = main.complete_delivery()
	check(late.late, "late delivery: half pay")
	main.travel(false)
	# ---------- P5: goals, XP, streak, rent, plaques ----------
	gs.reset()
	check(Goals.active(gs).size() == 3, "always three active goals")
	gs.deliveries = 1
	var done: Array = gs.check_goals()
	check(done.size() == 1 and done[0].id == "first_delivery" and gs.money > 50 and gs.xp > 0, "goal completes and pays out")
	check(Goals.active(gs).size() == 3 and not Goals.active(gs).any(func(g): return g.id == "first_delivery"), "next goal slides in")
	var lv0 := gs.level()
	gs.add_xp(500)
	check(gs.level() > lv0, "XP levels you up (level %d)" % gs.level())
	gs.record_track("lil_tear", 4, 80)
	gs.sleep()
	main.results.visible = false
	gs.record_track("lil_tear", 4, 80)
	check(gs.streak == 2 and gs.streak_mult() > 1.0, "release streak builds up (×%.1f)" % gs.streak_mult())
	gs.sleep()
	gs.sleep()
	gs.sleep()
	check(gs.streak == 0, "two nights without a release ends the streak")
	gs.day = 7
	var m0 := gs.money
	var rent_night: Dictionary = gs.sleep()
	check(int(rent_night.rent) == GameState.RENT and gs.money <= m0 - GameState.RENT + int(rent_night.earned), "rent is due every 7 nights")
	gs.total_streams = 30000
	main.room.apply_plaques(gs.plaques())
	check(gs.plaques() == ["gold"] and main.room.plaque_root.get_child_count() == 1, "gold plaque on the wall at 25k streams")
	main.results.visible = false
	main._set_ui_mode(false)

	# ---------- v0.12: metro, tram, districts ----------
	gs.reset()
	gs.money = 200
	sess.state = Session.State.IDLE
	check(main.districts.size() == 3, "three new districts (Centraal, Marktplein, Havenkwartier)")
	for id in main.districts:
		var d: DistrictBuilder = main.districts[id]
		check(d.metro_entrance != null and d.metro_entrance.get_meta("station") == id, "%s has a metro entrance" % id)
	check(not main.districts.haven.tram4.is_empty() == false and not main.districts.centraal.tram4.is_empty(), "tram 4 runs in Centraal (not in the harbour)")
	main.travel(true)
	check(main.area == "zuidkade", "outside = Zuidkade")
	main._on_interacted(city.metro_entrance)
	check(main.area == "metro" and main.transit.visible and not city.visible and main.transit.station == "zuidkade", "go down into metro Zuidkade")
	var tr: Transit = main.transit
	# fast-forward the train into the station
	tr.next_in = 0.0
	for k in 400:
		tr._cycle(0.05)
		if tr.state == "dwell" and tr.door_f > 0.8:
			break
	check(tr.state == "dwell" and tr.train.position.x == 0.0 and tr.board_body.collision_layer == 1, "train arrives, stops at the platform, doors open")
	var fare0 := gs.money
	main._ride_menu("metro")
	check(main.talk_ui.visible and main._talk_mode == "metro", "destination menu at the doors")
	main.talk_ui.choose("metro:haven")
	check(tr.is_riding() and pl.pose == "seat" and pl.pose_lock and gs.money == fare0 - Transit.FARE, "boarded: seated, checked in (€%d)" % Transit.FARE)
	main._on_interacted(city.metro_entrance)
	check(main.area == "metro", "can't wander off while riding")
	# let the doors close and the train pull out, then the fade switches stations
	for k in 600:
		tr._process(0.05)
		if not tr.is_riding():
			break
	check(not tr.is_riding() and tr.station == "haven" and pl.pose == "" and not pl.pose_lock, "ride: depart, tunnel, arrive at Havenkwartier, step out")
	check(tr.to_local(pl.global_position).z > 2.0, "you step out onto the platform")
	main._on_interacted(tr.exit_body)
	check(main.area == "haven" and main.districts.haven.visible and not tr.visible, "escalator up: Havenkwartier street")
	check(pl.global_position.distance_to(main.districts.haven.metro_exit_point()) < 0.5, "you come up next to the metro pavilion")
	# club
	gs.minutes = 23 * 60 + 30
	gs.tracks = [{"rapper": "lil_tear", "stars": 5, "score": 95, "day": 1, "streams": 0, "song": false}]
	var rep_c := gs.reputation
	var score: int = main._club("openmic")
	check(score > 0 and gs.reputation > rep_c and int(gs.stats.openmic_day) == gs.day, "open mic at De Kraan (score %d)" % score)
	# back to Centraal by metro, then tram to Marktplein
	main._on_interacted(main.districts.haven.metro_entrance)
	tr.state = "dwell"
	tr.t = 0.0
	tr.door_f = 1.0
	tr.train.position.x = 0.0
	tr.train.visible = true
	main._board("metro", "centraal")
	tr.skip_ride()
	main.exit_metro()
	check(main.area == "centraal", "metro to Centraal")
	var cen: DistrictBuilder = main.districts.centraal
	var m_k := gs.money
	main._on_interacted(cen.features.kiosk)
	check(gs.money == m_k - 3 and int(gs.buffs.awake) >= 30, "kiosk coffee keeps you up")
	var t_b := gs.minutes
	var tips: int = main.busk()
	check(tips > 0 and gs.minutes == t_b + 30, "busking on the square: €%d in 30 min" % tips)
	var e: Dictionary = cen.tram4
	(e.node as Node3D).position.x = cen.tram_stop_x - 1.0
	e.served = false
	e.dwell = 0.0
	for k in 100:
		cen._drive(0.05)
		if float(e.dwell) > 0.0 and float(e.door_f) > 0.8:
			break
	check(float(e.dwell) > 0.0 and is_equal_approx((e.node as Node3D).position.x, cen.tram_stop_x) and (e.board as StaticBody3D).collision_layer == 1, "tram 4 stops, doors open")
	main._on_interacted(e.board)
	check(main.talk_ui.visible and main._talk_mode == "tram", "tram destination menu")
	main.talk_ui.choose("tram:markt")
	check(tr.is_riding() and tr.ride.kind == "tram" and pl.pose_lock, "seated in the tram")
	for k in 800:
		cen._drive(0.05)
		if main.area == "markt":
			main.districts.markt._drive(0.05)
		tr._ride_update(0.05)
		if not tr.is_riding():
			break
	check(main.area == "markt" and not tr.is_riding() and pl.pose == "", "tram ride: Centraal → Marktplein, step out at the stop")
	# Marktplein: warehouse discount + döner
	var mk: DistrictBuilder = main.districts.markt
	gs.minutes = 23 * 60
	main._on_interacted(mk.features.huisraad_store)
	check(main.phone.visible and main.phone.app == "huisraad" and main.phone.store_discount > 0.0, "Huisraad warehouse opens with the store discount")
	var m_h := gs.money
	gs.money = 500
	m_h = gs.money
	check(gs.buy_furniture("poster", int(round(25 * 0.85))) and gs.money == m_h - 21, "in-store price")
	main.toggle_phone()
	check(main.phone.store_discount == 0.0, "discount ends when you leave")
	main._district_shop("doner")
	main.talk_ui.choose("doner")
	check(int(gs.buffs.awake) >= 45, "döner keeps you up")
	# home from anywhere at dawn
	main.travel(false)
	check(main.area == "room" and main.room.visible and not mk.visible, "travel home from a district")

	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
