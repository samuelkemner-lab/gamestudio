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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var seq: Sequencer = main.get_node("Sequencer")
	check(seq != null, "sequencer exists")
	check(seq.pattern.size() == 5, "5 tracks")
	check(seq.pattern[0].size() == 16, "16 steps")
	for t in 5:
		check(AudioServer.get_bus_index(Sequencer.TRACKS[t]) != -1, "bus " + Sequencer.TRACKS[t])

	# LOOPR opens and closes
	main.open_loopr()
	check(main.loopr.visible, "LOOPR opens")
	check(not main.player.enabled, "player frozen while in LOOPR")
	main.close_loopr()
	check(not main.loopr.visible and main.player.enabled, "LOOPR closes")

	# Toggling a step through the UI updates the pattern
	seq.clear()
	main.loopr.refresh_grid()
	main.loopr.step_buttons[1][3].button_pressed = true
	check(seq.pattern[1][3], "UI step toggle writes pattern")

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

	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
