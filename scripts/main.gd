extends Node3D
## Studio Grind – prototype v0.5
## Title screen → bedroom studio → phone DMs → rapper session in the booth → rating & payout.

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const VERSION := "v0.9 prototype"
const DAWN := 30 * 60  # 06:00 the next morning
const BOOTH_LOOK := Vector3(1.45, 1.2, -1.6)
const CITY_ORIGIN := Vector3(0, 0, 700)  # the street lives far away from the flat interior
const HOME_SPOT := Vector3(-1.0, 0.05, 1.85)

var player  # player.gd (CharacterBody3D)
var room: RoomBuilder
var sequencer: Sequencer
var game: GameState
var session: Session
var chaos: Chaos
var loopr: LooprUI
var screen_ui: LooprUI
var phone: PhoneUI
var results: ResultsUI
var city: CityBuilder
var city_ui: CityUI
var talk_ui: TalkUI
var _talk_npc: NPC
var _flyers_day := -1
var _flyers_today := 0
var _cat_day := -1
var in_city := false
var _monitor_vp: SubViewport
var _fade: ColorRect

var hud: CanvasLayer
var crosshair: Label
var prompt: PanelContainer
var prompt_text: Label
var stats_label: Label
var noise_bar: ProgressBar
var toast_label: Label
var clock_label: Label
var _toast_time := 0.0
var _clock_acc := 0.0

var in_menu := false
var menu_layer: CanvasLayer
var menu_cam: Camera3D
var _menu_press: Label
var _t := 0.0


func _ready() -> void:
	room = RoomBuilder.new()
	room.name = "Room"
	add_child(room)
	room.build()
	room.solid(Vector3(0.95, 2.05, 0.2), Vector3(-1.2, 1.03, 2.5), "door_out", "Go outside  (Zuidkade)")

	city = CityBuilder.new()
	city.name = "City"
	city.position = CITY_ORIGIN
	add_child(city)
	city.build_city()
	_set_city_active(false)

	game = GameState.new()
	game.name = "GameState"
	add_child(game)
	if DisplayServer.get_name() == "headless":
		game.persist = false
	game.load_game()

	sequencer = Sequencer.new()
	sequencer.name = "Sequencer"
	add_child(sequencer)

	session = Session.new()
	session.name = "Session"
	add_child(session)
	session.setup(self, sequencer, game)
	session.finished.connect(_on_session_finished)
	session.take_judged.connect(_on_take_judged)
	session.state_changed.connect(_on_session_state)

	chaos = Chaos.new()
	chaos.name = "Chaos"
	add_child(chaos)
	chaos.setup(self, sequencer, game)
	chaos.toast.connect(show_toast)
	chaos.pc_crash.connect(_on_pc_crash)
	room.apply_upgrades(game.upgrades)

	_build_monitor_screen()

	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.position = Vector3(0.3, 0.05, 1.0)
	player.rotation.y = deg_to_rad(20)
	add_child(player)
	player.interacted.connect(_on_interacted)
	player.interact_empty.connect(_on_interact_empty)
	city.set_player(player)
	city.game = game

	_build_hud()

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	loopr = LooprUI.new()
	layer.add_child(loopr)
	loopr.setup(sequencer)
	loopr.bind_session(session)
	loopr.bind_game(game)
	loopr.record_pressed.connect(_on_record_pressed)
	loopr.finish_pressed.connect(_on_finish_pressed)
	loopr.visible = false

	phone = PhoneUI.new()
	layer.add_child(phone)
	phone.build()
	phone.visible = false
	phone.book_requested.connect(_on_book)
	phone.buy_requested.connect(_on_buy)
	phone.hints_toggled.connect(func(easy): session.easy_mode = easy; loopr.update_session())

	city_ui = CityUI.new()
	layer.add_child(city_ui)
	city_ui.visible = false
	city_ui.closed.connect(func(): _set_ui_mode(false))
	city_ui.message.connect(show_toast)
	city_ui.upgrades_changed.connect(func(): room.apply_upgrades(game.upgrades))

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 30
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)

	talk_ui = TalkUI.new()
	layer.add_child(talk_ui)
	talk_ui.visible = false
	talk_ui.chosen.connect(_on_talk_chosen)
	talk_ui.closed.connect(_end_talk)

	results = ResultsUI.new()
	layer.add_child(results)
	results.visible = false
	results.closed.connect(_on_results_closed)

	game.changed.connect(_update_stats)
	_update_stats()

	if DisplayServer.get_name() != "headless":
		show_menu()


## The monitor in the room shows LOOPR live (same sequencer, mirrored).
func _build_monitor_screen() -> void:
	var vp := SubViewport.new()
	vp.name = "MonitorViewport"
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_monitor_vp = vp
	vp.gui_disable_input = true
	add_child(vp)
	screen_ui = LooprUI.new()
	vp.add_child(screen_ui)
	screen_ui.setup(sequencer)
	screen_ui.bind_session(session)
	screen_ui.bind_game(game)
	room.screen_material.albedo_texture = vp.get_texture()


func _process(delta: float) -> void:
	_t += delta
	if in_menu:
		_update_menu(delta)
		return
	var vp := get_viewport().get_visible_rect().size
	crosshair.position = Vector2(0, vp.y / 2.0 - 16)
	crosshair.size = Vector2(vp.x, 32)
	var target: Object = null if _ui_open() else player.hover_target()
	prompt.visible = target != null
	if target:
		prompt_text.text = _prompt_for(target)
		prompt.reset_size()
		prompt.position = Vector2((vp.x - prompt.size.x) / 2.0, vp.y / 2.0 + 44)
	noise_bar.value = game.noise
	noise_bar.visible = game.noise > 1.0
	var fill := noise_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = UIKit.CYAN.lerp(UIKit.POP, game.noise / 100.0)
	_tick_clock(delta)
	if _toast_time > 0.0:
		_toast_time -= delta
		toast_label.modulate.a = clampf(_toast_time, 0.0, 1.0)
		toast_label.position = Vector2((vp.x - toast_label.size.x) / 2.0, vp.y - 140)


func _tick_clock(delta: float) -> void:
	_clock_acc += delta
	while _clock_acc >= 1.0:
		_clock_acc -= 1.0
		game.minutes += 1
		if in_city:
			city.update_hours(game.minutes)
	clock_label.text = "DAY %d   ·   %s   ·   %s" % [game.day, game.clock_text(), "ZUIDKADE" if in_city else "KADE 17"]
	if game.minutes >= game.dawn_minutes() and not session.is_active() and not results.visible and not city_ui.visible:
		if in_city:
			travel(false)
			show_toast("The sun comes up. You stumble home and crash on your bed...")
		else:
			show_toast("Sunrise. You pass out on your keyboard...")
		go_to_sleep()


func _prompt_for(target: Object) -> String:
	if target.get_meta("interact") == "mic" and session.npc and session.state in [Session.State.WAITING, Session.State.REVIEW]:
		return "Talk to %s" % session.rapper.name
	return str(target.get_meta("label"))


func _ui_open() -> bool:
	return loopr.visible or phone.visible or results.visible or city_ui.visible or talk_ui.visible


func _input(event: InputEvent) -> void:
	if in_menu:
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
			start_game()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			if loopr.visible:
				close_loopr()
			elif city_ui.visible:
				city_ui.close()
			elif phone.visible:
				toggle_phone()
			elif not results.visible:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
		KEY_SPACE:
			if loopr.visible and session.state != Session.State.RECORDING:
				sequencer.toggle_play()
				get_viewport().set_input_as_handled()
		KEY_S:
			if loopr.visible and event.ctrl_pressed:
				sequencer.save_snapshot()
				loopr.refresh_grid()
				show_toast("Project saved.")
				get_viewport().set_input_as_handled()
		KEY_Z:
			if loopr.visible and event.ctrl_pressed:
				if sequencer.undo():
					show_toast("Undo.")
				get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3, KEY_4:
			if loopr.visible and not event.ctrl_pressed:
				sequencer.select_pattern(event.physical_keycode - KEY_1)
				get_viewport().set_input_as_handled()
		KEY_F9:
			city.apply_quality(not city.quality_high)
			room.room_env.ssil_enabled = city.quality_high
			room.room_env.volumetric_fog_enabled = city.quality_high
			show_toast("Graphics: %s" % ("HIGH" if city.quality_high else "LOW (faster)"))
			get_viewport().set_input_as_handled()
		KEY_TAB:
			if not loopr.visible and not results.visible:
				toggle_phone()
				get_viewport().set_input_as_handled()


func _on_interacted(target: Object) -> void:
	match target.get_meta("interact"):
		"pc":
			open_loopr()
		"mic":
			if session.npc and session.state in [Session.State.WAITING, Session.State.REVIEW]:
				session.npc.say(session.rapper.brief_pro.trim_prefix("\"").trim_suffix("\""), 5.0)
			elif not session.is_active():
				show_toast("Nobody's here. Check your phone for DMs  [TAB]")
		"door_out":
			if session.is_active():
				show_toast("%s is still in your studio. Finish the session first." % session.rapper.get("name", "Someone"))
			else:
				go_outside()
		"shop":
			var id := str(target.get_meta("shop_id"))
			if id == "home":
				go_home()
			elif not city.is_open(id, game.minutes):
				show_toast("Closed. %s closes at %s. Come back tomorrow night." % [str(target.get_meta("label")).trim_prefix("Enter ").get_slice(" (", 0), city.closing_text(id)])
			else:
				open_shop(id)
		"bed":
			player.enter_pose("bed", room.global_position + Vector3(1.56, 0.3, 1.05), PI, 0.55, 1.3)
			show_toast("[E] sleep (end the night)   ·   [SPACE] get up")
		"chair":
			player.enter_pose("seat", room.global_position + Vector3(-0.66, 0.05, -1.4), 0.0, 1.12, -0.15)
			show_toast("[E] on the PC to open LOOPR   ·   [SPACE] stand up")
		"seat":
			var body := target as Node3D
			player.enter_pose("seat", body.global_position, float(target.get_meta("yaw", 0.0)), 0.95)
			show_toast("[SPACE] stand up")
		"switch":
			room.toggle_lights()
			player._play_fx(AmbienceSynth.tick(1400.0))
		"cat":
			city.cat.pet()
			if _cat_day != game.day:
				_cat_day = game.day
				game.add_buff("chill", 1)
				show_toast("The cat purrs. You feel calmer.  (+1 take with your next rapper)")
		"npc":
			var n: NPC = target.get_meta("npc")
			if session.npc and n == session.npc:
				_talk_rapper()
			elif n.display_name == "":
				n.face(player.global_position)
				n.say("Move along. Nothing to see here.", 3.0)
			else:
				_talk_pedestrian(n)


func _on_interact_empty() -> void:
	if player.pose == "bed":
		if session.is_active():
			show_toast("You can't sleep now, %s is still here." % session.rapper.get("name", "someone"))
		else:
			player.leave_pose()
			go_to_sleep()


# ---------- Talking to people ----------

func _talk_pedestrian(n: NPC) -> void:
	_talk_npc = n
	n.pause_route(60.0)
	n.face(player.global_position)
	n.play("idle")
	var sub := "%s  ·  %s" % [str(n.data.get("persona", "local")).capitalize(), "knows you" if int(n.memory.talks) > 0 else "stranger"]
	talk_ui.open(n.display_name, sub, [
		["Talk", "talk"],
		["Hand out a flyer", "flyer", not n.memory.flyer],
		["Play your latest track", "track"],
		["Dap them up", "dap", not n.memory.dapped],
	])
	_set_ui_mode(true)


func _talk_rapper() -> void:
	var r := session.rapper
	if session.state == Session.State.RECORDING:
		session.npc.say("Shh! I'm recording!", 2.0)
		return
	if not session.state in [Session.State.WAITING, Session.State.REVIEW]:
		return
	_talk_npc = session.npc
	talk_ui.open(str(r.name), "%s  ·  %d takes left" % [str(r.style), session.takes_left], [
		["What do you want on this beat?", "brief"],
		["Hype them up  (+5 on next take)", "hype", session.hype == 0],
		["Offer a drink  (+1 take)", "drink", not session.drink_given],
		["Small talk", "chat"],
	])
	_set_ui_mode(true)


func _on_talk_chosen(id: String) -> void:
	var n := _talk_npc
	_set_ui_mode(false)
	if n == null:
		return
	if n == session.npc:
		match id:
			"brief":
				n.say(str(session.rapper.brief_pro).trim_prefix("\"").trim_suffix("\""), 5.0)
			"hype":
				session.hype = 5
				n.play("wave")
				n.say(StreetTalk._pick(["Yeah, YEAH! Let's go!", "You right, this one's the one.", "Okay okay, I feel it now."]), 3.0)
			"drink":
				session.drink_given = true
				session.takes_left += 1
				n.say(StreetTalk._pick(["Ah, thanks man. Okay, one more take then.", "Cheers. I'm good for another one.", "That's what I needed."]), 3.0)
				show_toast("+1 take (%d left)" % session.takes_left)
			"chat":
				n.say(StreetTalk.rapper_chat(session.rapper), 4.5)
		_talk_npc = null
		return
	match id:
		"talk":
			n.say(StreetTalk.greet(n, game, game.weather, game.minutes), 4.0)
		"flyer":
			if _flyers_day != game.day:
				_flyers_day = game.day
				_flyers_today = 0
			var res: Array = StreetTalk.flyer(n, game)
			n.say(res[0], 4.0)
			var rep := int(res[1]) if _flyers_today < 5 else 0
			_flyers_today += 1
			if rep > 0 or bool(res[2]):
				game.add(0, rep, 0)
				show_toast("+%d REP%s" % [rep, "  ·  a new rapper might DM you" if res[2] else ""])
		"track":
			var t: Array = StreetTalk.play_track(n, game)
			n.say(t[0], 4.0)
			match str(t[1]):
				"love":
					n.dance(5.0)
				"bad":
					n.react("hit", "", 1.5)
			if int(t[2]) > 0:
				game.add(0, int(t[2]), 0)
				show_toast("+%d REP" % int(t[2]))
		"dap":
			var line := StreetTalk.dap(n)
			n.say(line, 2.5)
			if n.memory.dapped:
				n.dap()
				player._play_fx(AmbienceSynth.tick(900.0))
	n.pause_route(4.5)
	_talk_npc = null


func _end_talk() -> void:
	_set_ui_mode(false)
	if _talk_npc and _talk_npc != session.npc:
		_talk_npc.pause_route(1.0)
	_talk_npc = null


# ---------- Outside world ----------

func _set_city_active(on: bool) -> void:
	in_city = on
	city.visible = on
	city.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	room.visible = not on
	room.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if _monitor_vp:
		_monitor_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if on else SubViewport.UPDATE_ALWAYS
	# indoor and outdoor each have their own light / post setup
	room.world_env.environment = city.city_env if on else room.room_env
	room.world_env.camera_attributes = city.cam_attr if on else null
	if player:
		player.surface = ("wet" if game.weather == "rain" else "stone") if on else "wood"
	if on:
		city.apply_weather(game.weather)
		city.update_hours(game.minutes)
	city.set_audio_active(on)


## Instant move between the flat and the street (fades are done by go_outside / go_home).
func travel(to_city: bool) -> void:
	sequencer.stop()
	_set_city_active(to_city)
	if to_city:
		player.global_position = city.spawn_point()
		player.rotation.y = PI  # face the street
	else:
		player.global_position = HOME_SPOT
		player.rotation.y = 0.0
	player.camera.rotation.x = 0.0
	player.velocity = Vector3.ZERO


func _fade_travel(to_city: bool, text: String) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		travel(to_city)
		show_toast(text)
		return
	player.enabled = false
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.3)
	await tw.finished
	travel(to_city)
	await get_tree().create_timer(0.15).timeout
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.45)
	player.enabled = not _ui_open()
	show_toast(text)


func go_outside() -> void:
	_fade_travel(true, "Zuidkade. The city never sleeps. Neither do you.")


func go_home() -> void:
	_fade_travel(false, "Back in the studio. Seven floors up, zero sleep.")


func open_shop(id: String) -> void:
	city_ui.open(id, game)
	_set_ui_mode(true)


func _set_ui_mode(ui: bool) -> void:
	player.enabled = not ui
	hud.visible = not ui
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui else Input.MOUSE_MODE_CAPTURED


func open_loopr() -> void:
	loopr.visible = true
	loopr.update_session()
	_set_ui_mode(true)


func close_loopr() -> void:
	loopr.visible = false
	_set_ui_mode(false)


func toggle_phone() -> void:
	phone.visible = not phone.visible
	if phone.visible:
		phone.refresh(game, session)
	_set_ui_mode(phone.visible)


# ---------- Day cycle, shop, crashes ----------

func go_to_sleep() -> void:
	sequencer.stop()
	var night := game.sleep()
	results.show_night(night)
	_set_ui_mode(true)


func _on_buy(id: String) -> void:
	if game.buy(id):
		room.apply_upgrades(game.upgrades)
		show_toast("Bought: %s" % Shop.item(id).name)


func _on_pc_crash() -> void:
	if loopr.visible:
		loopr.show_crash()
	else:
		show_toast("Your laptop crashed. Unsaved beat lost. (Ctrl+S in LOOPR!)")


# ---------- Session flow ----------

func _on_book(r: Dictionary) -> void:
	if not session.can_book(r):
		return
	if in_city:
		show_toast("Go home first. %s won't wait on the street." % r.name)
		return
	session.book(r)
	toggle_phone()
	show_toast("%s is on the way up. Cook a beat in LOOPR while you wait." % r.name)


func _on_session_state(st: int) -> void:
	if st == Session.State.WAITING:
		show_toast("%s is in the booth. Open LOOPR, make the beat, hit RECORD TAKE." % session.rapper.name)


func _on_record_pressed() -> void:
	if session.record_take():
		close_loopr()
		player.look_at_point(BOOTH_LOOK)


func _on_take_judged(r: Dictionary) -> void:
	if session.state == Session.State.REVIEW:
		show_toast("Take %d: %s   —  open LOOPR to FINISH or try a retake" % [session.takes_done, UIKit.stars(int(r.stars))])


func _on_finish_pressed() -> void:
	close_loopr()
	session.finish()


func _on_session_finished(summary: Dictionary) -> void:
	await get_tree().create_timer(1.2).timeout
	results.show_summary(summary)
	_set_ui_mode(true)


func _on_results_closed() -> void:
	_set_ui_mode(false)
	for r in Rappers.all():
		var key := "unlock_" + str(r.id)
		if session.unlocked(r) and (int(r.get("min_cred", 0)) > 0 or int(r.get("min_rep", 0)) > 0) and not game.has_meta(key):
			game.set_meta(key, true)
			show_toast("New DM unlocked: %s (%s) wants a session  [TAB]" % [r.name, r.style])


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.reset_size()
	_toast_time = 5.0


func _update_stats() -> void:
	stats_label.text = "€ %d     REP %d     CRED %d" % [game.money, game.reputation, game.street_cred]


# ---------- Title screen ----------

func show_menu() -> void:
	in_menu = true
	player.enabled = false
	hud.visible = false
	menu_cam = Camera3D.new()
	menu_cam.fov = 62.0
	add_child(menu_cam)
	menu_cam.current = true
	sequencer.play()
	chaos.enabled = false
	sequencer.save_snapshot()

	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(root)

	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.02, 0.07, 0.95))
	grad.set_color(1, Color(0.03, 0.02, 0.07, 0.0))
	grad.add_point(0.6, Color(0.03, 0.02, 0.07, 0.85))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = gtex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 900
	root.add_child(shade)

	var box := VBoxContainer.new()
	box.position = Vector2(90, 250)
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)
	box.add_child(UIKit.label("A BEDROOM PRODUCER STORY", 18, UIKit.CYAN))
	var title := UIKit.label("STUDIO\nGRIND", 120, UIKit.TEXT)
	title.add_theme_constant_override("line_spacing", -38)
	title.add_theme_color_override("font_outline_color", UIKit.ACCENT)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_shadow_color", Color(0.69, 0.36, 1.0, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 28)
	box.add_child(title)
	box.add_child(UIKit.label("from bedroom beats to the big stage", 22, Color("c4b5fd")))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	box.add_child(spacer)
	_menu_press = UIKit.label("PRESS ANY KEY", 22, Color.WHITE)
	box.add_child(_menu_press)
	if game.sessions > 0:
		box.add_child(UIKit.label("continue  ·  €%d  ·  %d tracks" % [game.money, game.sessions], 15, UIKit.DIM))

	var ver := UIKit.label(VERSION, 14, Color(1, 1, 1, 0.4))
	ver.position = Vector2(90, 850)
	root.add_child(ver)


func _update_menu(_delta: float) -> void:
	var a := _t * 0.12
	menu_cam.position = Vector3(0.95 + sin(a) * 0.45, 1.55 + sin(a * 0.7) * 0.08, 1.75 + cos(a) * 0.2)
	menu_cam.look_at(Vector3(-0.75, 1.05, -2.1), Vector3.UP)
	_menu_press.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 3.0))


func start_game() -> void:
	if not in_menu:
		return
	in_menu = false
	sequencer.stop()
	chaos.enabled = true
	menu_layer.queue_free()
	menu_cam.queue_free()
	player.camera.current = true
	_set_ui_mode(false)
	show_toast("New DMs on your phone  [TAB]")


# ---------- HUD ----------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	var title := UIKit.label("STUDIO GRIND", 20, Color("e9e4ff"))
	title.position = Vector2(24, 16)
	title.add_theme_color_override("font_outline_color", Color("1a1030"))
	title.add_theme_constant_override("outline_size", 6)
	hud.add_child(title)
	var controls := UIKit.label("WASD move  ·  SHIFT sprint  ·  CTRL crouch  ·  Z lie down  ·  F light  ·  E interact  ·  TAB phone", 14, Color(0.85, 0.8, 1.0, 0.6))
	controls.position = Vector2(24, 44)
	hud.add_child(controls)

	# Stats (top right)
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.06, 0.04, 0.12, 0.75), 12, Color("3a2f5c"), 1, 14))
	stats_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	stats_panel.offset_left = -360
	stats_panel.offset_right = -24
	stats_panel.offset_top = 16
	hud.add_child(stats_panel)
	var scol := VBoxContainer.new()
	stats_panel.add_child(scol)
	stats_label = UIKit.label("", 18, UIKit.TEXT)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scol.add_child(stats_label)
	noise_bar = ProgressBar.new()
	noise_bar.max_value = 100
	noise_bar.show_percentage = false
	noise_bar.custom_minimum_size = Vector2(0, 8)
	noise_bar.add_theme_stylebox_override("background", UIKit.box(Color(1, 1, 1, 0.08), 4, Color(), 0, 0))
	noise_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.CYAN, 4, Color(), 0, 0))
	noise_bar.tooltip_text = "Noise: the neighbours are listening"
	scol.add_child(noise_bar)
	var noise_lbl := UIKit.label("noise", 11, UIKit.DIM)
	noise_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scol.add_child(noise_lbl)
	clock_label = UIKit.label("", 14, UIKit.CYAN)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scol.add_child(clock_label)

	crosshair = UIKit.label("·", 28, Color(1, 1, 1, 0.8))
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_color_override("font_outline_color", Color.BLACK)
	crosshair.add_theme_constant_override("outline_size", 4)
	hud.add_child(crosshair)

	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", UIKit.box(Color(0.07, 0.05, 0.13, 0.82), 10, UIKit.ACCENT, 1, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	prompt.add_child(row)
	var key_panel := PanelContainer.new()
	key_panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.TEXT, 6, Color(), 0, 9))
	key_panel.add_child(UIKit.label("E", 18, Color("120f1c")))
	row.add_child(key_panel)
	prompt_text = UIKit.label("", 18, UIKit.TEXT)
	row.add_child(prompt_text)
	prompt.visible = false
	hud.add_child(prompt)

	toast_label = UIKit.label("", 19, UIKit.TEXT)
	toast_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.07))
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.modulate.a = 0.0
	var tl := CanvasLayer.new()
	tl.layer = 30
	add_child(tl)
	tl.add_child(toast_label)
