extends Node3D
## Studio Grind – prototype v0.5
## Title screen → bedroom studio → phone DMs → rapper session in the booth → rating & payout.

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const VERSION := "v0.12.1 prototype"
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
var call_ui: CallUI
var zoef := {}  # active delivery (Zoef app)
var estep: EStep
var _zoef_marker: Node3D
var _batt_warned := false
var _banner: PanelContainer
var _banner_from: Label
var _banner_text: Label
var _banner_t := 0.0
var _sfx: AudioStreamPlayer
var _talk_npc: NPC
var _flyers_day := -1
var _flyers_today := 0
var _cat_day := -1
var in_city := false
var area := "room"  # room | zuidkade | centraal | markt | haven | metro
var districts := {}  # id -> DistrictBuilder
var transit: Transit
var _talk_mode := ""  # "" (people) | metro | tram | food | club
var _tram_entry := {}
var _tram_builder: CityBuilder
var _pending_ride := {}
var umbrella_open := false
var _sprint_secs := 0.0
var _hotbar: Label
var _energy_bar: ProgressBar
var _tint: ColorRect
var _lpf_idx := -1
var _lpf: AudioEffectLowPassFilter
var fishing: Fishing
var trial: TimeTrial
var _fish_line: MeshInstance3D  # chosen destination, waiting for "check in or not"
const DISTRICT_ORIGINS := {"centraal": Vector3(0, 0, 1500), "markt": Vector3(0, 0, 2200), "haven": Vector3(0, 0, 2900)}
const METRO_ORIGIN := Vector3(0, -80, 3600)
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
	for id in DISTRICT_ORIGINS:
		var d := DistrictBuilder.new()
		d.name = "District_" + id
		d.position = DISTRICT_ORIGINS[id]
		add_child(d)
		d.build_district(id)
		districts[id] = d
	transit = Transit.new()
	transit.position = METRO_ORIGIN
	add_child(transit)
	transit.main = self
	transit.build_station()
	transit.ride_finished.connect(_on_ride_finished)
	fishing = Fishing.new()
	fishing.name = "Fishing"
	add_child(fishing)
	fishing.caught.connect(_on_catch)
	fishing.missed.connect(func(): show_toast("It got away..."))
	fishing.ended.connect(_on_fishing_ended)
	_fish_line = MeshInstance3D.new()
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.85, 0.85, 0.9, 0.6)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lc := CylinderMesh.new()
	lc.top_radius = 0.0025
	lc.bottom_radius = 0.0025
	lc.height = 1.0
	_fish_line.mesh = lc
	_fish_line.material_override = lm
	_fish_line.visible = false
	add_child(_fish_line)

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
	player.crashed.connect(_on_crash)
	city.set_player(player)
	city.game = game
	trial = TimeTrial.new()
	city.add_child(trial)
	trial.build(city)
	trial.player = player
	trial.update_board(game)
	trial.armed_up.connect(func(): show_toast("KADE RUN: ride through the gate. The clock starts when you cross the line."))
	trial.started.connect(_on_trial_started)
	trial.gate_passed.connect(func(i: int, n: int): _play_sfx(AmbienceSynth.beep()); show_toast("Gate %d/%d  ·  %.1f s" % [i, n, trial.t]))
	trial.finished.connect(_on_trial_finished)
	trial.aborted.connect(func(reason: String): show_toast(reason))
	for d in districts.values():
		d.set_player(player)
		d.game = game
	_activate_area("room")

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
	phone.ctx = self
	phone.quality_toggled.connect(_toggle_quality)
	phone.furniture_changed.connect(func(): room.apply_furniture(game.placed))
	phone.step_bought.connect(_on_step_bought)
	phone.zoef_requested.connect(_on_zoef)

	call_ui = CallUI.new()
	layer.add_child(call_ui)
	call_ui.build()
	call_ui.answered.connect(_on_call_answered)
	call_ui.declined.connect(_on_call_declined)
	call_ui.missed.connect(_on_call_missed)

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

	_lpf = AudioEffectLowPassFilter.new()
	_lpf.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(0, _lpf)
	_lpf_idx = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _lpf_idx, false)
	game.changed.connect(_update_stats)
	_update_stats()
	if game.inbox.is_empty():
		game.nightly_messages()
	game.notified.connect(_on_notified)
	game.goal_completed.connect(_on_goal)
	game.leveled.connect(func(lv):
		_play_sfx(AmbienceSynth.cash())
		show_toast("LEVEL UP! Producer level %d  (+€%d)" % [lv, 25 * lv]))
	room.apply_plaques(game.plaques())
	room.apply_furniture(game.placed)
	_spawn_step()

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
	var target: Object = null if _ui_open() or transit.is_riding() else player.hover_target()
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
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t * 2.0, 0.0, 1.0)
		_banner.position = Vector2((vp.x - _banner.size.x) / 2.0, 18)
	if _toast_time > 0.0:
		_toast_time -= delta
		toast_label.modulate.a = clampf(_toast_time, 0.0, 1.0)
		toast_label.position = Vector2((vp.x - toast_label.size.x) / 2.0, vp.y - 140)


func _tick_clock(delta: float) -> void:
	_clock_acc += delta
	while _clock_acc >= 1.0:
		_clock_acc -= 1.0
		game.minutes += 1
		var ab := builder_for(area)
		if ab:
			ab.update_hours(game.minutes)
		_check_pending()
		_maybe_call()
		game.check_goals()
		_vitals_tick()
	var line := "DAY %d   ·   %s   ·   %s" % [game.day, game.clock_text(), area_title()]
	if player and player.riding:
		line += "\nE-STEP  %d km/h  ·  battery %d%%" % [int(round(player.riding.speed * 3.6)), int(ceil(float(game.estep.battery)))]
	if trial and trial.running:
		line += "\nKADE RUN  ·  %.1f s  ·  gate %d/%d" % [trial.t, trial.next + 1, TimeTrial.GATES.size()]
	if not zoef.is_empty():
		var left := int(zoef.until) - game.minutes
		line += "\nZOEF  ·  %s  ·  %s" % [("deliver to " + str(zoef.address)) if zoef.picked else "pick up at Snackbar De Hoek", ("%d:%02d left" % [left / 60, left % 60]) if left >= 0 else "LATE"]
	var fx := Vitals.status_text(game)
	if fx != "":
		line += "\n" + fx
	if not game.pending.is_empty():
		line += "\n%s arrives at %s" % [Rappers.by_id(str(game.pending.rapper)).get("name", "?"), game.clock_text_at(int(game.pending.until))]
	clock_label.text = line
	if game.minutes >= game.dawn_minutes() and not session.is_active() and not results.visible and not city_ui.visible:
		if in_city:
			travel(false)
			show_toast("The sun comes up. You stumble home and crash on your bed...")
		else:
			show_toast("Sunrise. You pass out on your keyboard...")
		go_to_sleep()


func area_title() -> String:
	match area:
		"room":
			return "KADE 17"
		"metro":
			return "METRO · " + Transit.station_name(transit.station).to_upper()
	return Transit.station_name(area).to_upper()


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
	if transit.is_riding():
		return
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
		"metro_in":
			enter_metro(str(target.get_meta("station", "zuidkade")))
		"metro_out":
			exit_metro()
		"metro_board":
			_ride_menu("metro")
		"tram_board":
			_tram_entry = target.get_meta("tram")
			_tram_builder = target.get_meta("builder")
			_ride_menu("tram")
		"kiosk", "busk", "station_hall", "market_hall":
			_district_spot(str(target.get_meta("interact")))
		"shop":
			var id := str(target.get_meta("shop_id"))
			var b: CityBuilder = target.get_meta("builder", city)
			if b != city:
				if not b.is_open(id, game.minutes):
					show_toast("Closed. Opens again tomorrow night (closes at %s)." % b.closing_text(id))
				else:
					_district_shop(id)
				return
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
		"fish":
			start_fishing(target)
		"trial":
			var best := float(game.records.get("trial_best", 0.0))
			show_toast("KADE RUN: quay → side street → main road. Mo %.0f s · Jesse %.0f s · Bilal %.0f s · you %s.%s" % [
				TimeTrial.RIVALS[0].time, TimeTrial.RIVALS[1].time, TimeTrial.RIVALS[2].time,
				("%.1f s" % best) if best > 0.0 else "--", "" if game.estep.owned else " You need an e-step (GEAR app)."])
		"estep":
			player.mount(target.get_meta("estep"))
			show_toast("W go · S brake · A/D steer · B bell · E/SPACE get off")
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
		["Offer a cold drink  (+1 take)" if game.placed.get("front", "") == "mini_fridge" else "Offer a drink  (needs a mini fridge)", "drink", not session.drink_given and game.placed.get("front", "") == "mini_fridge"],
		["Give throat spray  (+5 on next take, %d left)" % Vitals.count(game, "keelspray"), "spray", Vitals.count(game, "keelspray") > 0],
		["Small talk", "chat"],
	])
	_set_ui_mode(true)


func _on_talk_chosen(id: String) -> void:
	if _talk_mode != "":
		var mode := _talk_mode
		_talk_mode = ""
		_set_ui_mode(false)
		_on_menu_choice(mode, id)
		return
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
			"spray":
				if Vitals.take(game, "keelspray"):
					session.hype += 5
					n.say(StreetTalk._pick(["*sprays* Ahh, smooth. Okay, I'm ready.", "Honey-lemon? Respect. Voice is clean now.", "*cough* ...okay that actually helps."]), 3.0)
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
	var mode := _talk_mode
	_talk_mode = ""
	_set_ui_mode(false)
	if mode == "inspect":
		_resolve_inspection("pay")  # walking away from an inspector = you pay
	if _talk_npc and _talk_npc != session.npc:
		_talk_npc.pause_route(1.0)
	_talk_npc = null


# ---------- Outside world ----------

func _set_city_active(on: bool) -> void:
	_activate_area("zuidkade" if on else "room")


func builder_for(id: String) -> CityBuilder:
	return city if id == "zuidkade" else districts.get(id, null)


## Show/process only the place you're in. All outdoor places share the Zuidkade night environment.
func _activate_area(id: String) -> void:
	area = id
	in_city = id != "room"
	var outdoor := id != "room"
	room.visible = not outdoor
	room.process_mode = Node.PROCESS_MODE_DISABLED if outdoor else Node.PROCESS_MODE_INHERIT
	if _monitor_vp:
		_monitor_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if outdoor else SubViewport.UPDATE_ALWAYS
	city.visible = id == "zuidkade"
	city.process_mode = Node.PROCESS_MODE_INHERIT if id == "zuidkade" else Node.PROCESS_MODE_DISABLED
	for k in districts:
		var d: DistrictBuilder = districts[k]
		d.visible = id == k
		d.process_mode = Node.PROCESS_MODE_INHERIT if id == k else Node.PROCESS_MODE_DISABLED
	if transit:
		transit.visible = id == "metro"
	# indoor and outdoor each have their own light / post setup
	room.world_env.environment = city.city_env if outdoor else room.room_env
	room.world_env.camera_attributes = city.cam_attr if outdoor else null
	if player:
		player.surface = "wood" if not outdoor else ("stone" if id == "metro" else ("wet" if game.weather == "rain" else "stone"))
	if outdoor:
		city.apply_weather(game.weather)
		var b := builder_for(id)
		if b:
			if b != city:
				b.apply_weather(game.weather)
			b.update_hours(game.minutes)
	city.set_audio_active(id == "zuidkade")
	for k in districts:
		(districts[k] as DistrictBuilder).set_audio_active(id == k)
	if transit:
		if id == "metro":
			transit.player_arrived()
		else:
			transit.player_left()


## Instant move between the flat and the street (fades are done by go_outside / go_home).
func travel(to_city: bool) -> void:
	sequencer.stop()
	if transit.is_riding():
		transit.cancel_ride()
	if not to_city:
		_leave_city()
	_set_city_active(to_city)
	if to_city:
		player.global_position = city.spawn_point()
		player.rotation.y = PI  # face the street
	else:
		player.global_position = HOME_SPOT
		player.rotation.y = 0.0
	player.camera.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	if not to_city:
		_check_pending()
	elif estep and game.estep.home:
		game.estep.home = false
		_park_step_at_home()


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
	if not phone.visible:
		phone.store_discount = 0.0
	if phone.visible:
		phone.go_home()
		phone.refresh(game, session)
	_set_ui_mode(phone.visible)


# ---------- Day cycle, shop, crashes ----------

func go_to_sleep() -> void:
	sequencer.stop()
	if in_city:
		_leave_city()
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
	if not session.can_book(r) or not game.pending.is_empty():
		return
	game.message(str(r.name), "studio's open tonight. pull up to Kade 17", true)
	if in_city:
		_set_pending(r, false)
		return
	session.book(r)
	if phone.visible:
		toggle_phone()
	show_toast("%s is on the way up. Cook a beat in LOOPR while you wait." % r.name)


## Invited/answered while you were out: they head to your place, you have 40 minutes to get home.
func _set_pending(r: Dictionary, hot: bool) -> void:
	game.pending = {"rapper": r.id, "until": game.minutes + 40, "hot": hot}
	game.message(str(r.name), "omw. be at ur door at %s. dont make me wait outside" % game.clock_text_at(game.minutes + 40))
	show_toast("%s is coming to your studio. Be home before %s!" % [r.name, game.clock_text_at(game.minutes + 40)])


func _check_pending() -> void:
	if game.pending.is_empty():
		return
	var r := Rappers.by_id(str(game.pending.rapper))
	if not in_city and not session.is_active():
		var hot: bool = game.pending.get("hot", false)
		game.pending = {}
		session.book(r)
		session.hot = hot
		show_toast("%s is right on time. Session on%s." % [r.name, "  (hot session: +15% pay)" if hot else ""])
	elif game.minutes > int(game.pending.until):
		game.pending = {}
		game.booked_today.append(r.id)
		game.add(0, -1, 0)
		game.message(str(r.name), "waited outside ur door for nothing. not cool.")
		show_toast("%s gave up waiting.  −1 REP" % r.name)


# ---------- Calls ----------

func _maybe_call(force := false) -> void:
	if in_menu or session.is_active() or not game.pending.is_empty() or call_ui.ringing or results.visible:
		return
	var m := game.minutes
	if not force and (game.calls_tonight >= 2 or m < 22 * 60 + 15 or m > 26 * 60 + 30 or randf() > 0.025):
		return
	var pool: Array = Rappers.all().filter(func(r): return session.can_book(r))
	if pool.is_empty():
		return
	call_ui.ring(pool[randi() % pool.size()])


func _on_call_answered(r: Dictionary) -> void:
	game.calls_tonight += 1
	game.log_call(str(r.name), "answered")
	if not session.can_book(r):
		return
	if in_city:
		_set_pending(r, true)
	else:
		session.book(r)
		session.hot = true
		show_toast("%s: \"I'm downstairs. Let's cook.\"   Hot session: +15%% pay" % r.name)


func _on_call_declined(r: Dictionary) -> void:
	game.calls_tonight += 1
	game.log_call(str(r.name), "declined")
	game.message(str(r.name), "ok. ur loss")


func _on_call_missed(r: Dictionary) -> void:
	game.calls_tonight += 1
	game.log_call(str(r.name), "missed")
	game.message(str(r.name), "called u. u dont pick up?? hit me if ur free")


func _on_goal(g: Dictionary) -> void:
	_banner_from.text = "GOAL COMPLETE"
	var reward := []
	if int(g.money) > 0:
		reward.append("+€%d" % int(g.money))
	if int(g.rep) > 0:
		reward.append("+%d REP" % int(g.rep))
	reward.append("+%d XP" % int(g.xp))
	_banner_text.text = "%s   %s" % [g.text, "  ".join(reward)]
	_banner_t = 5.0
	_play_sfx(AmbienceSynth.cash())


func _on_notified(from: String, text: String) -> void:
	if in_menu:
		return
	_banner_from.text = "MESSAGE  ·  " + from
	_banner_text.text = text.substr(0, 70) + ("…" if text.length() > 70 else "")
	_banner_t = 4.5
	_play_sfx(AmbienceSynth.ping())
	if phone.visible:
		phone._render()


func _play_sfx(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()


# ---------- E-step ----------

func _spawn_step() -> void:
	if not game.estep.owned or estep != null:
		return
	estep = EStep.new()
	estep.data = game.estep
	estep.build()
	city.add_child(estep)
	var pos = game.estep.get("pos", null)
	if game.estep.home or not (pos is Array):
		_park_step_at_home()
	else:
		estep.position = Vector3(pos[0], 0.0, pos[1])
		estep.rotation.y = float(pos[2])


func _home_door_local() -> Vector3:
	return city._shop_reg("home").get("door_out", city.spawn_local)


func _park_step_at_home() -> void:
	if estep == null:
		return
	estep.position = _home_door_local() + Vector3(1.6, -0.05, -0.4)
	estep.rotation.y = PI * 0.5
	estep.update_label()


## Leaving the street (home or sleep): get off the step; parked near your door = taken upstairs to charge.
func _leave_city() -> void:
	if player.riding:
		player.dismount()
	if estep:
		var near := estep.position.distance_to(_home_door_local()) < 14.0
		game.estep.home = near
		game.estep.pos = [estep.position.x, estep.position.z, estep.rotation.y]
	if not zoef.is_empty():
		_zoef_clear()
		show_toast("Order cancelled. The kapsalon went cold.")


func _on_step_bought(id: String) -> void:
	if id == "estep":
		_spawn_step()
		show_toast("Bought! Your e-step is parked by the front door of Kade 17.")
	else:
		show_toast("E-step upgraded: %s" % ("Motor tune (31 km/h)" if id == "step_motor" else "Big battery (2× range)"))


func _step_update() -> void:
	if player.riding == null:
		return
	var b := float(game.estep.battery)
	if b <= 20.0 and not _batt_warned:
		_batt_warned = true
		show_toast("E-step battery low (%d%%). Park it by your door to charge overnight." % int(b))
	if b <= 0.0 and _batt_warned:
		_batt_warned = false
		game.estep.battery = 0.0
		show_toast("Battery dead. Kick-push it home...")
	if b > 25.0:
		_batt_warned = false


func _on_crash(speed: float, collider: Object) -> void:
	if collider and collider.has_meta("npc"):
		var n: NPC = collider.get_meta("npc")
		n.memory.annoyed = int(n.memory.annoyed) + 2
		n.face(player.global_position)
		n.react("hit", StreetTalk._pick(["AU! Are you crazy?!", "Watch where you're riding!", "Sidewalk is for WALKING!"]), 2.5)
		game.add(0, -1, 0)
		show_toast("You crashed into %s.  −1 REP" % n.display_name)
	else:
		show_toast("You ate pavement at %d km/h. Ouch." % int(round(speed * 3.6)))


# ---------- Zoef (delivery side job) ----------

const ZOEF_FOOD := ["kapsalon", "2x frikandel speciaal", "döner box", "bami schijf + fries", "pizza margherita", "loempia + sate", "broodje kroket"]


func _on_zoef(action: String) -> void:
	if action == "cancel":
		_zoef_clear()
		show_toast("Order cancelled.")
		return
	if area != "zuidkade" or not zoef.is_empty():
		return
	var pick: Vector3 = city._shop_reg("snackbar").get("door_out", Vector3.ZERO)
	var side := -1 if randf() < 0.5 else 1
	var x := 0.0
	for i in 20:
		x = snappedf(randf_range(-62.0, 62.0), 1.0)
		if absf(x - pick.x) > 14.0:
			break
	var drop := Vector3(x, 0.05, side * (CityBuilder.LINE - 0.8))
	var d1 := city.to_local(player.global_position).distance_to(pick)
	var d2 := pick.distance_to(drop)
	var limit := int((d1 + d2) / 3.0) + 15
	zoef = {
		"food": ZOEF_FOOD[randi() % ZOEF_FOOD.size()],
		"address": "%s %d" % ["Zuidkade" if side < 0 else "Maasstraat", int(absf(x + 70.0) / 3.0) + 1],
		"pick": pick, "drop": drop, "picked": false,
		"until": game.minutes + limit, "limit": limit,
		"pay": clampi(int(5.0 + d2 * 0.07), 6, 14),
	}
	_zoef_place_marker(pick, "PICK UP\n" + str(zoef.food), UIKit.GOLD)
	if phone.visible:
		toggle_phone()
	show_toast("Zoef: pick up %s at Snackbar De Hoek. %d min." % [zoef.food, limit])


func _zoef_place_marker(local: Vector3, text: String, col: Color) -> void:
	if _zoef_marker:
		_zoef_marker.queue_free()
	var m := Node3D.new()
	m.name = "ZoefMarker"
	m.position = Vector3(local.x, 0, local.z)
	var beam := MeshInstance3D.new()
	var cylm := CylinderMesh.new()
	cylm.top_radius = 0.35
	cylm.bottom_radius = 0.35
	cylm.height = 30.0
	beam.mesh = cylm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(col, 0.28)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.position.y = 15.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(beam)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.1
	tm.outer_radius = 1.3
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = col
	ring.material_override = rm
	ring.position.y = 0.08
	m.add_child(ring)
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true
	lbl.pixel_size = 0.0012
	lbl.font_size = 28
	lbl.outline_size = 8
	lbl.modulate = col
	lbl.position.y = 2.6
	m.add_child(lbl)
	city.add_child(m)
	_zoef_marker = m


func _zoef_clear() -> void:
	zoef = {}
	if _zoef_marker:
		_zoef_marker.queue_free()
		_zoef_marker = null


func _zoef_update() -> void:
	if zoef.is_empty():
		return
	var here := city.to_local(player.global_position)
	here.y = 0.0
	if not zoef.picked:
		var p: Vector3 = zoef.pick
		if here.distance_to(Vector3(p.x, 0, p.z)) < 2.6:
			zoef.picked = true
			_zoef_place_marker(zoef.drop, "DELIVER\n" + str(zoef.address), UIKit.CYAN)
			_play_fx_ping()
			show_toast("Picked up %s. Deliver to %s." % [zoef.food, zoef.address])
		return
	var d: Vector3 = zoef.drop
	if here.distance_to(Vector3(d.x, 0, d.z)) < 2.6:
		complete_delivery()


## Pay out: full pay on time (half when late), tip for speed, +30% tips in the rain.
func complete_delivery() -> Dictionary:
	var left := int(zoef.until) - game.minutes
	var pay := int(zoef.pay) if left >= 0 else int(zoef.pay) / 2
	var tip := randi() % 3
	if left > int(zoef.limit) * 0.4:
		tip += 2
	if game.weather == "rain":
		tip = int(ceil(tip * 1.3))
	game.deliveries += 1
	game.add(pay + tip, 0, 0)
	game.add_xp(10)
	_play_sfx(AmbienceSynth.cash())
	show_toast("Delivered! €%d%s%s" % [pay, "  +€%d tip" % tip if tip > 0 else "", "  (late: half pay)" if left < 0 else ""])
	var res := {"pay": pay, "tip": tip, "late": left < 0}
	_zoef_clear()
	return res


func _play_fx_ping() -> void:
	_play_sfx(AmbienceSynth.ping())


# ---------- Vitals: energy, consumables, effects ----------

func use_item(id: String) -> void:
	if Vitals.count(game, id) <= 0:
		show_toast("No %s in your pocket. (Night shop / coffeeshop)" % str(Vitals.ITEMS[id].name).to_lower())
		return
	match id:
		"kraslot":
			Vitals.take(game, "kraslot")
			scratch_card()
			return
		"brood":
			var flock := _nearest_flock()
			if flock and flock.feed(35.0):
				Vitals.take(game, "brood")
				show_toast("You crumble the bread. The pigeons decide you're their new best friend.")
				return
	var line := Vitals.use(game, id)
	_play_sfx({"joint": AmbienceSynth.lighter(), "raket": AmbienceSynth.pssht(), "pils": AmbienceSynth.gulp(), "water": AmbienceSynth.gulp()}.get(id, AmbienceSynth.gulp()))
	show_toast(line)


func _nearest_flock() -> PigeonFlock:
	if area != "zuidkade":
		return null
	for f in city.flocks:
		if f.global_position.distance_to(player.global_position) < 9.0:
			return f
	return null


func toggle_umbrella() -> void:
	if Vitals.count(game, "paraplu") <= 0:
		show_toast("You don't have an umbrella. (Night shop, €12)")
		return
	umbrella_open = not umbrella_open
	player.set_umbrella(umbrella_open)


## Maas Miljoen scratch card: odds printed on the back, pays back about 55%.
func scratch_card(r := -1.0) -> int:
	var v := randf() if r < 0.0 else r
	var prize := 0
	if v < 0.0001:
		prize = 1000
	elif v < 0.0021:
		prize = 100
	elif v < 0.0121:
		prize = 20
	elif v < 0.0521:
		prize = 5
	elif v < 0.2521:
		prize = 2
	var syms := ["€2", "€5", "€20", "€100", "€1000"]
	var shown: Array = []
	if prize > 0:
		shown = ["€%d" % prize, "€%d" % prize, "€%d" % prize]
	else:
		shown = [syms[randi() % 5], syms[randi() % 5], syms[randi() % 5]]
		if shown[0] == shown[1] and shown[1] == shown[2]:
			shown[2] = syms[(syms.find(shown[2]) + 1) % 5]
	game.stats.scratch_spent = int(game.stats.get("scratch_spent", 0)) + 2
	if prize > 0:
		game.add(prize, 0, 0)
		game.stats.scratch_won = int(game.stats.get("scratch_won", 0)) + prize
		_play_sfx(AmbienceSynth.cash())
	if not DisplayServer.get_name() == "headless":
		_talk_npc = null
		_talk_mode = "scratch"
		talk_ui.open("Maas Miljoen", "[ %s ]   [ %s ]   [ %s ]" % shown, [["You win €%d!" % prize if prize > 0 else "Nothing. Next time...", "ok"]])
		_set_ui_mode(true)
	return prize


func _vitals_tick() -> void:
	var outdoors := in_city and area != "metro"
	var wet := outdoors and game.weather == "rain" and not umbrella_open and not transit.is_riding()
	var events := Vitals.tick(game, wet, _sprint_secs)
	_sprint_secs = 0.0
	for e in events:
		match e:
			"munchies":
				show_toast("The munchies hit. You need food. (Snackbar, döner, bread...)")
			"crash":
				show_toast("The RAKET wears off. Your legs feel like concrete. (Water helps)")
			"tired":
				show_toast("You're running on fumes. Coffee, RAKET or food. Or bed.")
	# drunk on a step near the police car by the casino
	if area == "zuidkade" and player.riding and Vitals.drunk_level(game) > 0.3 and not game.night.get("dui", false):
		if city.to_local(player.global_position).distance_to(Vector3(-38.5, 0, 4.7)) < 14.0:
			game.night.dui = true
			player.dismount()
			_fine(80, -1)
			show_toast("Officer Dekker: \"Off the step. You're drunk.\" €80 fine.  −1 REP")


func _apply_vitals(delta: float) -> void:
	if player == null:
		return
	if player.sprinting:
		_sprint_secs += delta
	var m := Vitals.mods(game)
	player.speed_mult = m.walk
	player.sprint_mult = m.sprint
	player.can_sprint = m.can_sprint
	player.sway = m.sway
	player.wobble = m.wobble
	player.shake = m.shake
	player.crash_speed = 2.5 if Vitals.drunk_level(game) > 0.3 else 3.8
	var tint: Color = m.tint
	if Vitals.has(game, "heart"):
		tint.a *= 0.6 + 0.4 * sin(_t * 9.0)
	_tint.color = _tint.color.lerp(tint, clampf(delta * 2.0, 0.0, 1.0))
	var lp: float = m.lowpass
	AudioServer.set_bus_effect_enabled(0, _lpf_idx, lp > 0.0)
	if lp > 0.0:
		_lpf.cutoff_hz = lp
	_energy_bar.value = game.energy
	var fill := _energy_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = Color("ff3d4a").lerp(Color("3ddc84"), game.energy / 100.0)
	var parts: Array = []
	for i in Vitals.HOTBAR.size():
		var id: String = Vitals.HOTBAR[i]
		var n := Vitals.count(game, id)
		if n > 0:
			parts.append("%d %s ×%d" % [i + 1, Vitals.ITEMS[id].name, n])
	if Vitals.count(game, "paraplu") > 0:
		parts.append("U umbrella%s" % (" (open)" if umbrella_open else ""))
	_hotbar.text = "   ".join(parts)


# ---------- Fishing ----------

func start_fishing(spot: Node3D) -> void:
	if Vitals.count(game, "hengel") <= 0:
		show_toast("You need a fishing rod. (Night shop, €15)")
		return
	var b: Node3D = spot.get_meta("builder")
	player.enter_pose("fish", b.to_global(spot.get_meta("stand")), PI, 1.6, -0.3)
	player.set_rod(true)
	fishing.cast(b.to_global(spot.get_meta("water")))
	show_toast("Waiting for a bite... [E] when the bobber dips  ·  [SPACE] stop")


func _on_catch(res: Dictionary) -> void:
	game.stats.catches = int(game.stats.get("catches", 0)) + 1
	game.add_xp(3)
	match str(res.kind):
		"fish":
			if Vitals.add_item(game, "vis"):
				show_toast("You caught a %s! (Ome Kees at the snackbar buys fish)" % res.name)
			else:
				show_toast("A %s. Your bag is full, you let it go." % res.name)
		"junk":
			show_toast("You reel in %s. Into the bin it goes." % res.name)
		"bike":
			game.add(int(res.money), 0, 0)
			show_toast("You fish up %s! Someone on the Ruilmarkt pays €%d for it." % [res.name, int(res.money)])
		"wallet":
			game.add(int(res.money), 0, 0)
			show_toast("%s with €%d in it. No ID. Finders keepers." % [str(res.name).capitalize(), int(res.money)])
		"safe":
			game.add(int(res.money), 0, 0)
			_play_sfx(AmbienceSynth.cash())
			show_toast("%s! You pry it open: €%d." % [str(res.name).capitalize(), int(res.money)])
		"phone":
			var r: Dictionary = Rappers.all()[randi() % Rappers.all().size()]
			game.add(0, 3, 2)
			game.message(str(r.name), "YO you found my phone in the maas?? the unreleased demo is on there. respect. i owe you")
			show_toast("%s... with an unreleased demo of %s on it! You give it back.  +3 REP  +2 CRED" % [str(res.name).capitalize(), r.name])


func _on_fishing_ended() -> void:
	player.set_rod(false)
	_fish_line.visible = false
	if player.pose == "fish":
		player.leave_pose()


func _update_fish_line() -> void:
	if not fishing.active:
		return
	if player.pose != "fish":
		fishing.stop()
		return
	var a: Vector3 = player.rod_tip()
	var b: Vector3 = fishing.bobber.global_position + Vector3(0, 0.08, 0)
	_fish_line.visible = true
	_fish_line.global_position = (a + b) / 2.0
	_fish_line.global_basis = Basis(Quaternion(Vector3.UP, (b - a).normalized())).scaled(Vector3(1, a.distance_to(b), 1))


# ---------- Metro & tram ----------

func fade_through(f: Callable) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		f.call()
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.3)
	await tw.finished
	f.call()
	await get_tree().create_timer(0.12).timeout
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.45)


func enter_metro(st: String) -> void:
	if player.riding:
		player.dismount()
	fade_through(func():
		_activate_area("metro")
		transit.dress(st)
		player.global_position = transit.to_global(Vector3(24.0, 0.05, 6.6))
		player.rotation.y = 0.0
		player.camera.rotation.x = 0.0
		player.velocity = Vector3.ZERO
		show_toast("Metro %s. Board at the open doors (€%d check-in), or take the escalator back up." % [Transit.station_name(st), Transit.FARE]))


func exit_metro() -> void:
	var st := transit.station
	fade_through(func():
		_activate_area(st)
		var b := builder_for(st)
		player.global_position = b.metro_exit_point()
		player.rotation.y = b.metro_exit_yaw()
		player.camera.rotation.x = 0.0
		player.velocity = Vector3.ZERO
		if st == "zuidkade" and estep and game.estep.home:
			game.estep.home = false
			_park_step_at_home()
		show_toast(_arrival_hint(st)))


## Called by Transit under the fade when the train reaches the next station.
func metro_arrive(_dest: String) -> void:
	pass


func go_tram_area(dest: String) -> CityBuilder:
	_activate_area(dest)
	if dest == "zuidkade" and estep and game.estep.home:
		game.estep.home = false
		_park_step_at_home()
	return builder_for(dest)


func _arrival_hint(st: String) -> String:
	match st:
		"centraal":
			return "Centraal. Kiosk, busking spot and taxis on the square."
		"markt":
			return "Marktplein. Huisraad warehouse (furniture −15%) and Döner Palace."
		"haven":
			return "Havenkwartier. Club De Kraan: open mic night, 23:00–05:00."
	return "Zuidkade. Home is just down the street (Kade 17)."


func _on_ride_finished(dest: String) -> void:
	if area == "metro":
		show_toast("%s. Mind the gap. Take the escalator (EXIT) up to the street." % Transit.station_name(dest))
	else:
		show_toast(_arrival_hint(dest))


func _ride_menu(kind: String) -> void:
	var here: String = transit.station if kind == "metro" else _tram_builder.station_id
	var opts: Array = []
	for id in Transit.LINE_ORDER:
		if id == here or (kind == "tram" and not Transit.STATIONS[id].tram):
			continue
		var stops := transit.stops_between(here, id)
		opts.append(["%s  (%d stop%s)" % [Transit.station_name(id), stops, "" if stops == 1 else "s"], kind + ":" + id, game.money >= Transit.FARE])
	_talk_npc = null
	_talk_mode = kind
	talk_ui.open("Metro → " + transit.terminus() if kind == "metro" else "Tram 4", "Check in: €%d  ·  you have €%d" % [Transit.FARE, game.money], opts)
	_set_ui_mode(true)


func _on_menu_choice(mode: String, id: String) -> void:
	match mode:
		"metro", "tram":
			_checkin_menu(mode, id.get_slice(":", 1))
		"checkin":
			_board(_pending_ride.kind, _pending_ride.dest, id == "checkin")
		"inspect":
			_resolve_inspection(id)
		"food":
			var cost := 6 if id == "doner" else 9
			if game.spend(cost):
				game.add_buff("awake", 45 if id == "doner" else 60)
				Vitals.eat(game, true)
				_play_sfx(AmbienceSynth.cash())
				show_toast("%s. You'll stay up %d min longer tonight." % ["Döner box" if id == "doner" else "Kapsalon", 45 if id == "doner" else 60])
		"club":
			_club(id)
		"scratch":
			pass
		"barber":
			if Style.haircut(game, id):
				_play_sfx(AmbienceSynth.cash())
				show_toast("%s. Drip %d now. People will notice." % [Style.CUTS[id].name, Style.drip(game)])
		"drip":
			if Style.buy_or_wear(game, id):
				_play_sfx(AmbienceSynth.cash())
				_drip_menu()
		"bouncer":
			if id == "bribe" and game.spend(10):
				game.stats.club_pass_day = game.day
				show_toast("Mo pockets it without looking. \"Go on then.\"")
				_district_shop("club")


func _checkin_menu(kind: String, dest: String) -> void:
	_pending_ride = {"kind": kind, "dest": dest}
	_talk_npc = null
	_talk_mode = "checkin"
	talk_ui.open("Card reader", "%s → %s  ·  you have €%d" % ["Metro" if kind == "metro" else "Tram 4", Transit.station_name(dest), game.money], [
		["Check in  (€%d)" % Transit.FARE, "checkin", game.money >= Transit.FARE],
		["Don't check in  (free, €%d fine if they catch you)" % Transit.FINE, "dodge"]])
	_set_ui_mode(true)


func _board(kind: String, dest: String, checked_in := true) -> void:
	if kind == "metro" and not (transit.state == "dwell" and transit.door_f > 0.5):
		show_toast("Too late, the doors are closing. Wait for the next one.")
		return
	if kind == "tram" and float(_tram_entry.get("dwell", 0.0)) < 1.0:
		show_toast("Too late, the tram is leaving.")
		return
	if checked_in:
		if not game.spend(Transit.FARE):
			show_toast("Not enough money for a ticket (€%d)." % Transit.FARE)
			return
		_play_sfx(AmbienceSynth.beep())
	else:
		game.stats.dodges = int(game.stats.get("dodges", 0)) + 1
	if kind == "metro":
		transit.board_metro(dest, checked_in)
	else:
		transit.board_tram(_tram_entry, _tram_builder, dest, checked_in)
	if checked_in:
		show_toast("*beep* Checked in (€%d). Next stop: %s." % [Transit.FARE, Transit.station_name(dest)])
	else:
		show_toast("You walk right past the card reader. Next stop: %s. Fingers crossed..." % Transit.station_name(dest))


# ---------- Ticket inspection ----------

## Transit: inspectors reached your seat.
func inspection(checked_in: bool) -> void:
	var insp: NPC = transit._inspector
	if checked_in:
		_play_sfx(AmbienceSynth.beep())
		if insp:
			insp.say("*beep* Thank you, enjoy your ride.", 3.0)
		show_toast("Ticket inspection. Your card beeps green. All good.")
		if DisplayServer.get_name() == "headless" or not is_inside_tree():
			transit.inspection_done()
		else:
			get_tree().create_timer(1.8).timeout.connect(func(): transit.inspection_done())
		return
	_talk_npc = null
	_talk_mode = "inspect"
	talk_ui.open("Ticket inspection", "You didn't check in. That's a €%d fine.  ·  you have €%d" % [Transit.FINE, game.money], [
		["Pay the €%d fine" % Transit.FINE, "pay"],
		["\"My card didn't beep, I swear...\"  (try an excuse)", "excuse"],
		["Wait for the doors and run for it", "run"]])
	_set_ui_mode(true)


## Pay, talk your way out (better odds with Street Cred) or bolt at the stop.
func _resolve_inspection(choice: String) -> void:
	var insp: NPC = transit._inspector
	match choice:
		"pay":
			_fine(Transit.FINE, 0)
			if insp:
				insp.say("Here's your fine. Next time: check in.", 3.0)
			show_toast("Fined €%d for riding without checking in." % Transit.FINE)
		"excuse":
			var odds := minf(0.3 + game.street_cred * 0.01 + (0.15 if Vitals.has(game, "drunk") else 0.0), 0.7)
			if randf() < odds:
				if insp:
					insp.say("Hmm. Fine. Just this once. Check in next time.", 3.5)
				show_toast("You talked your way out of it. No fine.")
			else:
				_fine(Transit.FINE, -1)
				if insp:
					insp.say("Nice try. €%d, and I'm writing down your name." % Transit.FINE, 3.5)
				show_toast("Didn't work. Fined €%d.  −1 REP" % Transit.FINE)
		"run":
			if insp:
				insp.say("Don't even think about it...", 3.0)
			show_toast("You sit still... and wait for the doors to open.")
			transit.inspection_done(true)
			return
	transit.inspection_done(false)


## Bolting out of the doors at the stop.
func run_from_inspector() -> bool:
	if randf() < 0.5:
		game.add(0, 0, 1)
		game.stats.escapes = int(game.stats.get("escapes", 0)) + 1
		show_toast("You bolt out the doors and lose them in the crowd.  +1 CRED")
		return true
	_fine(Transit.FINE + 25, -1)
	show_toast("Caught at the doors. €%d fine and a lecture.  −1 REP" % (Transit.FINE + 25))
	return false


func _fine(amount: int, rep: int) -> void:
	game.add(-amount, rep, 0)  # can push you into the red
	game.stats.fines = int(game.stats.get("fines", 0)) + 1


# ---------- District spots ----------

func _district_shop(id: String) -> void:
	match id:
		"huisraad_store":
			phone.store_discount = 0.15
			toggle_phone()
			phone.open_app("huisraad")
			show_toast("Huisraad warehouse: everything 15% cheaper in the store.")
		"doner":
			_talk_npc = null
			_talk_mode = "food"
			talk_ui.open("Döner Palace", "Open till 05:00  ·  you have €%d" % game.money, [
				["Döner box  (€6, stay up 45 min longer)", "doner", game.money >= 6],
				["Kapsalon  (€9, stay up 60 min longer)", "kapsalon", game.money >= 9]])
			_set_ui_mode(true)
		"barber":
			_talk_npc = null
			_talk_mode = "barber"
			var f := Style.fresh(game)
			talk_ui.open("Fresh Fades", ("You still look fresh (+%d drip)" % f if f > 0 else "Walk-ins welcome") + "  ·  you have €%d" % game.money, [
				["Fresh fade  (€%d, +%d drip for %d nights, +1 REP)" % [Style.CUTS.fade.price, Style.CUTS.fade.drip, Style.CUTS.fade.nights], "fade", game.money >= int(Style.CUTS.fade.price)],
				["Quick line-up  (€%d, +%d drip tonight)" % [Style.CUTS.lineup.price, Style.CUTS.lineup.drip], "lineup", game.money >= int(Style.CUTS.lineup.price)]])
			_set_ui_mode(true)
		"drip":
			_drip_menu()
		"club":
			if game.minutes < 23 * 60:
				show_toast("De Kraan opens at 23:00. The queue is already forming.")
				return
			if Style.drip(game) < Style.CLUB_MIN and int(game.stats.get("club_pass_day", -1)) != game.day:
				_talk_npc = null
				_talk_mode = "bouncer"
				talk_ui.open("Mo Kraan, bouncer", "\"Not in those clothes, chef.\"  ·  drip %d/%d  ·  you have €%d" % [Style.drip(game), Style.CLUB_MIN, game.money], [
					["Slip him a tenner  (€10)", "bribe", game.money >= 10],
					["Fair enough. (get a fit at Drip Depot or a fade at Fresh Fades)", "leave"]])
				_set_ui_mode(true)
				return
			var done_tonight: bool = int(game.stats.get("openmic_day", -1)) == game.day
			_talk_npc = null
			_talk_mode = "club"
			talk_ui.open("Club De Kraan", "Open mic tonight  ·  entry €10  ·  you have €%d" % game.money, [
				["Perform at the open mic (€10)" if not done_tonight else "You already performed tonight", "openmic", game.money >= 10 and not done_tonight],
				["Just dance for a bit (€10, chill: +1 take next session)", "dance", game.money >= 10],
				["Pils at the bar (€4)", "pils", game.money >= 4]])
			_set_ui_mode(true)


func _on_trial_started() -> void:
	_play_sfx(AmbienceSynth.chime())
	show_toast("GO! Follow the blue gates. Pink = finish.")


func _on_trial_finished(time: float) -> void:
	var r := TimeTrial.result(game, time)
	trial.update_board(game)
	_play_sfx(AmbienceSynth.cash() if int(r.money) > 0 else AmbienceSynth.chime())
	var line := "FINISH  %.2f s%s" % [time, "  ·  personal best!" if r.pb else ""]
	if not r.new_wins.is_empty():
		line += "  ·  you beat %s: +€%d%s" % [" & ".join(r.new_wins), r.money, ("  +%d CRED" % r.cred) if int(r.cred) > 0 else ""]
	elif int(r.place) == 1:
		line += "  ·  still the fastest on the Kade."
	else:
		var target: Dictionary = TimeTrial.RIVALS[TimeTrial.RIVALS.size() + 1 - int(r.place)]
		line += "  ·  %s did %.1f s. Again?" % [str(target.name).get_slice(",", 0), target.time]
	show_toast(line)


## Drip Depot: buy a piece (it goes straight on) or swap what you wear. One piece per slot.
func _drip_menu() -> void:
	_talk_npc = null
	_talk_mode = "drip"
	var opts := []
	for c in Style.CLOTHES:
		var owned: bool = c.id in game.clothes
		var worn: bool = game.outfit.get(c.slot, "") == c.id
		var label := "%s  (+%d drip)" % [c.name, c.drip]
		if worn:
			label += "  · wearing (take off)"
		elif owned:
			label += "  · put on"
		else:
			label += "  · €%d" % c.price
		opts.append([label, c.id, owned or game.money >= int(c.price)])
	talk_ui.open("Drip Depot", "Your drip: %d  ·  club needs %d  ·  you have €%d" % [Style.drip(game), Style.CLUB_MIN, game.money], opts)
	_set_ui_mode(true)


## Open mic: the crowd reacts to your best release and your level.
func _club(id: String) -> int:
	if id == "pils":
		if game.spend(4):
			show_toast(Vitals.use(game, "pils", true))
			_play_sfx(AmbienceSynth.gulp())
		return 0
	if not game.spend(10):
		return 0
	if id == "dance":
		game.add_buff("chill", 1)
		show_toast("You dance until your legs hurt. Chill: +1 take with your next rapper.")
		return 0
	game.stats.openmic_day = game.day
	var best := 0
	for tr in game.tracks:
		best = maxi(best, int(tr.stars))
	if best == 0:
		show_toast("You have nothing released yet. The crowd talks right over your set.")
		return 0
	var score := best * 18 + game.level() * 3 + randi() % 20 + Vitals.stage_bonus(game) + Style.drip(game)
	var rep := 0
	var cred := 0
	var tips := 0
	var line := ""
	if score >= 90:
		rep = 6
		cred = 3
		tips = 40
		line = "The whole club goes off. Phones in the air. Someone films it."
	elif score >= 65:
		rep = 4
		cred = 2
		tips = 20
		line = "Hands up at the drop. A few people ask for your name."
	elif score >= 40:
		rep = 2
		cred = 1
		tips = 5
		line = "Some heads nod. It's a start."
	else:
		line = "Polite clapping. Your beat needs more work."
	game.add(tips, rep, cred)
	game.add_xp(score / 2)
	_play_sfx(AmbienceSynth.cash())
	show_toast("%s  +%d REP  +%d CRED%s" % [line, rep, cred, "  +€%d tips" % tips if tips > 0 else ""])
	return score


func _district_spot(kind: String) -> void:
	match kind:
		"kiosk":
			if game.spend(3):
				game.add_buff("awake", 30)
				Vitals.coffee(game)
				_play_sfx(AmbienceSynth.cash())
				show_toast("Black coffee from the kiosk. +30 min, +20 energy.%s" % ("  (that's a lot of coffee: jittery)" if Vitals.has(game, "jitter") else ""))
			else:
				show_toast("Coffee is €3. You're broke.")
		"busk":
			busk()
		"station_hall":
			show_toast("No trains to other cities at night. Take the metro (M) on the square.")
		"market_hall":
			show_toast("The market hall is closed at night. The stalls open at 8:00.")


## Play your beats on the station square for 30 minutes. Tips depend on your releases, REP and weather.
func busk() -> int:
	var best := 0
	for tr in game.tracks:
		best = maxi(best, int(tr.stars))
	var tips := 3 + best * 4 + int(game.reputation / 5) + randi() % 8
	if game.weather == "rain":
		tips = int(tips * 0.5)
	game.minutes += 30
	game.add(tips, 1 if best >= 4 else 0, 0)
	game.add_xp(8)
	_play_sfx(AmbienceSynth.cash())
	show_toast("30 minutes of beats on the square. €%d in your cap%s." % [tips, " (rain keeps people walking)" if game.weather == "rain" else ""])
	return tips


func _toggle_quality() -> void:
	city.apply_quality(not city.quality_high)
	room.room_env.ssil_enabled = city.quality_high
	room.room_env.volumetric_fog_enabled = city.quality_high
	show_toast("Graphics: %s" % ("HIGH" if city.quality_high else "LOW (faster)"))


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
	room.apply_plaques(game.plaques())
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
	_energy_bar = ProgressBar.new()
	_energy_bar.max_value = 100
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(0, 8)
	_energy_bar.add_theme_stylebox_override("background", UIKit.box(Color(1, 1, 1, 0.08), 4, Color(), 0, 0))
	_energy_bar.add_theme_stylebox_override("fill", UIKit.box(Color("3ddc84"), 4, Color(), 0, 0))
	scol.add_child(_energy_bar)
	var energy_lbl := UIKit.label("energy", 11, UIKit.DIM)
	energy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scol.add_child(energy_lbl)
	var noise_lbl := UIKit.label("noise", 11, UIKit.DIM)
	noise_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scol.add_child(noise_lbl)
	clock_label = UIKit.label("", 14, UIKit.CYAN)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scol.add_child(clock_label)

	_hotbar = UIKit.label("", 14, Color(0.9, 0.88, 1.0, 0.85))
	_hotbar.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.07))
	_hotbar.add_theme_constant_override("outline_size", 6)
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hotbar.offset_left = 24
	_hotbar.offset_top = -44
	_hotbar.offset_bottom = -20
	hud.add_child(_hotbar)
	var tint_layer := CanvasLayer.new()
	tint_layer.layer = -1
	add_child(tint_layer)
	_tint = ColorRect.new()
	_tint.color = Color(0, 0, 0, 0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint_layer.add_child(_tint)

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

	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", UIKit.box(Color(0.08, 0.07, 0.12, 0.94), 18, Color("2fbf71"), 1, 12))
	var bcol := VBoxContainer.new()
	_banner.add_child(bcol)
	_banner_from = UIKit.label("", 13, Color("2fbf71"))
	bcol.add_child(_banner_from)
	_banner_text = UIKit.label("", 16, UIKit.TEXT)
	bcol.add_child(_banner_text)
	_banner.modulate.a = 0.0
	_banner.custom_minimum_size = Vector2(420, 0)
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -6.0
	add_child(_sfx)

	toast_label = UIKit.label("", 19, UIKit.TEXT)
	toast_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.07))
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.modulate.a = 0.0
	var tl := CanvasLayer.new()
	tl.layer = 30
	add_child(tl)
	tl.add_child(toast_label)
	tl.add_child(_banner)
