class_name PhoneUI
extends Control
## GRIND OS: the player's phone. Home screen with app icons and badges; apps for messages,
## calls, streams, studio gear, furniture, second-hand deals, the delivery side job and settings.

signal book_requested(rapper: Dictionary)
signal buy_requested(item_id: String)
signal hints_toggled(easy: bool)
signal quality_toggled
signal furniture_changed
signal step_bought(item_id: String)
signal zoef_requested(action: String)  # "start" | "cancel"

const APPS := [
	{"id": "messages", "name": "Messages", "color": Color("2fbf71"), "glyph": "bubble"},
	{"id": "phone", "name": "Phone", "color": Color("35c759"), "glyph": "handset"},
	{"id": "wavr", "name": "WAVR", "color": Color("ff6a2b"), "glyph": "wave"},
	{"id": "gear", "name": "Gear", "color": Color("7a5cff"), "glyph": "cog"},
	{"id": "huisraad", "name": "Huisraad", "color": Color("e0a43a"), "glyph": "sofa"},
	{"id": "ruilmarkt", "name": "Ruilmarkt", "color": Color("2a8bd8"), "glyph": "tag"},
	{"id": "zoef", "name": "Zoef", "color": Color("ff3d7f"), "glyph": "bag"},
	{"id": "goals", "name": "Goals", "color": Color("f2c14e"), "glyph": "trophy"},
	{"id": "settings", "name": "Settings", "color": Color("6b6880"), "glyph": "sliders"},
]

var app := ""  # "" = home screen
var thread := ""  # open chat in Messages
var ctx: Object  # main.gd: in_city, zoef
var _gs: GameState
var _session: Session
var _easy := true
var _screen: VBoxContainer
var _status_time: Label


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var phone := PanelContainer.new()
	phone.add_theme_stylebox_override("panel", UIKit.box(Color("08070d"), 44, Color("2b2833"), 6, 14))
	phone.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	phone.offset_left = -500
	phone.offset_right = -70
	phone.offset_top = -410
	phone.offset_bottom = 410
	add_child(phone)
	var screen_panel := PanelContainer.new()
	screen_panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, 34, Color(), 0, 16))
	phone.add_child(screen_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	screen_panel.add_child(col)

	var status := HBoxContainer.new()
	_status_time = UIKit.label("22:00", 13, UIKit.TEXT)
	status.add_child(_status_time)
	status.add_child(_spacer())
	status.add_child(UIKit.label("●●●  5G   ▮▮▮", 12, UIKit.DIM))
	col.add_child(status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_screen = VBoxContainer.new()
	_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen.add_theme_constant_override("separation", 10)
	scroll.add_child(_screen)

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	var home := UIKit.button("   ⌂  Home   ", UIKit.PANEL_LIGHT, 14)
	home.pressed.connect(go_home)
	foot.add_child(home)
	foot.add_child(_spacer())
	foot.add_child(UIKit.label("[TAB] close", 13, UIKit.DIM))
	col.add_child(foot)


func refresh(gs: GameState, session: Session) -> void:
	_gs = gs
	_session = session
	_render()


func go_home() -> void:
	app = ""
	thread = ""
	_render()


func open_app(id: String) -> void:
	app = id
	thread = ""
	_render()


func open_thread(from: String) -> void:
	app = "messages"
	thread = from
	if _gs:
		_gs.mark_read(from)
	_render()


func _render() -> void:
	if _gs == null:
		return
	_status_time.text = _gs.clock_text()
	for c in _screen.get_children():
		c.queue_free()
	match app:
		"":
			_home()
		"messages":
			_messages()
		"phone":
			_calls()
		"wavr":
			_wavr()
		"gear":
			_gear()
		"huisraad":
			_huisraad()
		"ruilmarkt":
			_ruilmarkt()
		"zoef":
			_zoef()
		"goals":
			_goals()
		"settings":
			_settings()


# ---------- building blocks ----------

func _spacer() -> Control:
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sp


func _card(color := UIKit.PANEL) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(color, 16, Color(), 0, 12))
	return card


func _header(title: String, sub := "") -> void:
	var row := HBoxContainer.new()
	var back := UIKit.button("‹", UIKit.PANEL_LIGHT, 18)
	back.custom_minimum_size = Vector2(40, 36)
	back.pressed.connect(func():
		if app == "messages" and thread != "":
			thread = ""
			_render()
		else:
			go_home())
	row.add_child(back)
	var t := UIKit.label("  " + title, 26, UIKit.TEXT)
	row.add_child(t)
	_screen.add_child(row)
	if sub != "":
		_screen.add_child(UIKit.label(sub, 13, UIKit.CYAN))


func _stats_line() -> String:
	return "€%d  ·  REP %d  ·  CRED %d" % [_gs.money, _gs.reputation, _gs.street_cred]


func badge_for(id: String) -> int:
	match id:
		"messages":
			return _gs.unread()
		"phone":
			var n := 0
			for c in _gs.call_log:
				if c.kind == "missed" and int(c.day) == _gs.day:
					n += 1
			return n
	return 0


# ---------- home ----------

func _home() -> void:
	var clock := UIKit.label(_gs.clock_text(), 64, UIKit.TEXT)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.add_child(clock)
	var wx: String = {"rain": "Rain", "mist": "Mist", "dry": "Dry"}.get(_gs.weather, "")
	var date := UIKit.label("Night %d  ·  Rotterdam-Zuid  ·  %s, 7°" % [_gs.day, wx], 14, UIKit.DIM)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.add_child(date)
	var st := UIKit.label(_stats_line() + "  ·  LVL %d%s" % [_gs.level(), "  ·  streak %d" % _gs.streak if _gs.streak >= 2 else ""], 14, UIKit.GOLD)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.add_child(st)
	if not _gs.pending.is_empty():
		var r := Rappers.by_id(str(_gs.pending.rapper))
		var p := _card(Color("3a1f2e"))
		p.add_child(UIKit.wrap_label("%s is on the way to your studio. Be home before %s!" % [r.get("name", "?"), _clock(int(_gs.pending.until))], 14, UIKit.POP, 330))
		_screen.add_child(p)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	_screen.add_child(sp)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	for a in APPS:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		var icon := AppIcon.new()
		icon.color = a.color
		icon.glyph = a.glyph
		icon.badge = badge_for(a.id)
		icon.custom_minimum_size = Vector2(72, 72)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		var id: String = a.id
		icon.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				open_app(id))
		cell.add_child(icon)
		var l := UIKit.label(a.name, 12, UIKit.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		grid.add_child(cell)
	var center := CenterContainer.new()
	center.add_child(grid)
	_screen.add_child(center)


func _clock(m: int) -> String:
	var mm := m % (24 * 60)
	return "%02d:%02d" % [mm / 60, mm % 60]


# ---------- Messages ----------

func _messages() -> void:
	if thread != "":
		_chat(thread)
		return
	_header("Messages")
	var threads := _gs.threads()
	if threads.is_empty():
		_screen.add_child(UIKit.wrap_label("No messages yet.", 15, UIKit.DIM, 330))
	for from in threads:
		var last: Dictionary = {}
		for i in range(_gs.inbox.size() - 1, -1, -1):
			if _gs.inbox[i].from == from:
				last = _gs.inbox[i]
				break
		var card := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		row.add_child(_avatar(from))
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := HBoxContainer.new()
		head.add_child(UIKit.label(from, 16, UIKit.TEXT))
		head.add_child(_spacer())
		head.add_child(UIKit.label(str(last.get("time", "")), 12, UIKit.DIM))
		body.add_child(head)
		var prev := str(last.get("text", ""))
		body.add_child(UIKit.label(prev.substr(0, 38) + ("…" if prev.length() > 38 else ""), 13, UIKit.DIM))
		row.add_child(body)
		var un := _gs.unread(from)
		if un > 0:
			row.add_child(UIKit.label(" %d " % un, 14, UIKit.POP))
		var f: String = from
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				open_thread(f))
		_screen.add_child(card)


func _avatar(from: String) -> Control:
	var r := _rapper_named(from)
	var c: Color = r.get("accent", Color("4a4560"))
	var avatar := PanelContainer.new()
	avatar.add_theme_stylebox_override("panel", UIKit.box(c, 22, Color(), 0, 0))
	avatar.custom_minimum_size = Vector2(44, 44)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var initial := UIKit.label(from.substr(0, 1), 20, UIKit.BG)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(initial)
	return avatar


func _rapper_named(n: String) -> Dictionary:
	for r in Rappers.all():
		if r.name == n:
			return r
	return {}


func _chat(from: String) -> void:
	_header(from)
	_gs.mark_read(from)
	for m in _gs.inbox:
		if m.from != from:
			continue
		var row := HBoxContainer.new()
		var bubble := PanelContainer.new()
		var mine: bool = m.get("me", false)
		bubble.add_theme_stylebox_override("panel", UIKit.box(Color("4b2a8a") if mine else UIKit.PANEL_LIGHT, 14, Color(), 0, 10))
		var v := VBoxContainer.new()
		v.add_child(UIKit.wrap_label(str(m.text), 14, UIKit.TEXT, 250))
		v.add_child(UIKit.label("night %d · %s" % [int(m.day), str(m.time)], 10, UIKit.DIM))
		bubble.add_child(v)
		if mine:
			row.add_child(_spacer())
		row.add_child(bubble)
		_screen.add_child(row)
	var r := _rapper_named(from)
	if r.is_empty():
		return
	var actions := HBoxContainer.new()
	actions.add_child(UIKit.label("pays ~€%d · %s" % [int(r.pay), str(r.style)], 13, UIKit.GOLD))
	actions.add_child(_spacer())
	if not _session.unlocked(r):
		actions.add_child(UIKit.label("LOCKED", 14, UIKit.POP))
	elif r.id in _gs.booked_today:
		actions.add_child(UIKit.label("seen tonight", 14, UIKit.DIM))
	elif not _gs.pending.is_empty() and str(_gs.pending.rapper) == r.id:
		actions.add_child(UIKit.label("on the way", 14, UIKit.CYAN))
	else:
		var b := UIKit.button("INVITE", UIKit.ACCENT, 14)
		b.disabled = _session.is_active() or not _gs.pending.is_empty()
		b.pressed.connect(func():
			book_requested.emit(r)
			_render())
		actions.add_child(b)
	_screen.add_child(actions)


# ---------- Phone ----------

func _calls() -> void:
	_header("Phone", "Recent calls")
	if _gs.call_log.is_empty():
		_screen.add_child(UIKit.wrap_label("No calls yet. Rappers call when they need a studio. Answer fast.", 15, UIKit.DIM, 330))
	for i in range(_gs.call_log.size() - 1, -1, -1):
		var c: Dictionary = _gs.call_log[i]
		var card := _card()
		var row := HBoxContainer.new()
		card.add_child(row)
		var col: Color = {"answered": UIKit.CYAN, "missed": UIKit.POP, "declined": UIKit.DIM}.get(str(c.kind), UIKit.DIM)
		row.add_child(UIKit.label(str(c.from), 16, col))
		row.add_child(_spacer())
		row.add_child(UIKit.label("%s · night %d · %s" % [str(c.kind), int(c.day), str(c.time)], 12, UIKit.DIM))
		_screen.add_child(card)


# ---------- WAVR ----------

func _wavr() -> void:
	_header("WAVR", "%d total streams" % _gs.total_streams)
	if _gs.tracks.is_empty():
		_screen.add_child(UIKit.wrap_label("Nothing released yet. Invite a rapper in Messages and finish a session.", 15, UIKit.DIM, 330))
	for i in range(_gs.tracks.size() - 1, -1, -1):
		var t: Dictionary = _gs.tracks[i]
		var card := _card()
		var row := HBoxContainer.new()
		card.add_child(row)
		var r := Rappers.by_id(str(t.rapper))
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(UIKit.label("%s  –  track #%d" % [r.get("name", "?"), i + 1], 16, UIKit.TEXT))
		body.add_child(UIKit.label("released night %d%s" % [int(t.get("day", 1)), "  ·  full song" if t.get("song", false) else ""], 12, UIKit.DIM))
		row.add_child(body)
		var right := VBoxContainer.new()
		right.add_child(UIKit.label(UIKit.stars(int(t.stars)), 16, UIKit.GOLD))
		right.add_child(UIKit.label("%d streams" % int(t.get("streams", 0)), 12, UIKit.CYAN))
		row.add_child(right)
		_screen.add_child(card)


# ---------- Gear ----------

func _gear() -> void:
	_header("Gear", _stats_line())
	for it in Shop.ITEMS:
		var owned := _gs.has(it.id)
		var gid: String = it.id
		var on_buy := func():
			buy_requested.emit(gid)
			_render()
		_screen.add_child(_buy_card(it.name, it.desc, int(it.price), "OWNED" if owned else "", on_buy))


func _buy_card(title: String, desc: String, price: int, status: String, on_buy: Callable, extra := "", btn := "BUY", owned := false) -> PanelContainer:
	var card := _card()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	card.add_child(body)
	var head := HBoxContainer.new()
	head.add_child(UIKit.label(title, 16, UIKit.TEXT))
	head.add_child(_spacer())
	head.add_child(UIKit.label("€%d" % price, 15, UIKit.GOLD))
	body.add_child(head)
	body.add_child(UIKit.wrap_label(desc, 13, UIKit.DIM, 330))
	var actions := HBoxContainer.new()
	if extra != "":
		actions.add_child(UIKit.label(extra, 12, UIKit.CYAN))
	actions.add_child(_spacer())
	if status != "":
		actions.add_child(UIKit.label(status, 13, UIKit.CYAN))
	else:
		var b := UIKit.button(btn, UIKit.ACCENT, 13)
		b.disabled = _gs.money < price and not owned
		b.pressed.connect(on_buy)
		actions.add_child(b)
	body.add_child(actions)
	return card


# ---------- Huisraad (furniture) ----------

func _huisraad() -> void:
	var st := _gs.room_stats()
	_header("Huisraad", "VIBE %d  ·  ACOUSTICS %d  ·  COMFORT %d   (€%d)" % [st.vibe, st.acoustics, st.comfort, _gs.money])
	_screen.add_child(UIKit.wrap_label("VIBE: +%d%% session pay%s.  ACOUSTICS: noise rises %d%% slower.  COMFORT: you stay up %d min longer." % [
		int(round((Furniture.pay_mult(st) - 1.0) * 100.0)), ", rappers +1 take" if int(st.vibe) >= 12 else " (12+: rappers +1 take)",
		int(round((1.0 - Furniture.noise_mult(st)) * 100.0)), Furniture.comfort_minutes(st)], 12, UIKit.DIM, 330))
	for slot in Furniture.SLOTS:
		_screen.add_child(UIKit.label(Furniture.SLOTS[slot], 15, UIKit.ACCENT))
		for it in Furniture.in_slot(slot):
			var id: String = it.id
			var stat_txt := "+%d VIBE  +%d AC  +%d COMF" % [it.vibe, it.acoustics, it.comfort]
			if id in _gs.furniture:
				var in_room: bool = _gs.placed.get(slot, "") == id
				var on_place := func():
					_gs.place(id)
					furniture_changed.emit()
					_render()
				_screen.add_child(_buy_card(it.name, it.desc, int(it.price), "", on_place, stat_txt, "IN ROOM ✓" if in_room else "PLACE", true))
			else:
				var on_buy := func():
					if _gs.buy_furniture(id):
						furniture_changed.emit()
					_render()
				_screen.add_child(_buy_card(it.name, it.desc, int(it.price), "", on_buy, stat_txt))


# ---------- Ruilmarkt (second hand) ----------

## Tonight's deal: one furniture item you don't own, 30% off. Changes every night.
func deal() -> Dictionary:
	var pool: Array = Furniture.ITEMS.filter(func(it): return not it.id in _gs.furniture)
	if pool.is_empty():
		return {}
	var it: Dictionary = pool[(_gs.day * 7 + 3) % pool.size()]
	return {"item": it, "price": int(round(int(it.price) * 0.7))}


func _ruilmarkt() -> void:
	_header("Ruilmarkt", "Second hand near you  ·  €%d" % _gs.money)
	for it in GameState.STEP_ITEMS:
		var id: String = it.id
		var locked: bool = it.has("needs") and not _gs.step_owned(it.needs)
		var status := "SOLD TO YOU" if _gs.step_owned(id) else ("needs the e-step" if locked else "")
		var on_buy := func():
			if _gs.buy_step_item(id):
				step_bought.emit(id)
			_render()
		_screen.add_child(_buy_card(it.name, it.desc, int(it.price), status, on_buy))
	var d := deal()
	if not d.is_empty():
		_screen.add_child(UIKit.label("Tonight's deal (−30%)", 15, UIKit.ACCENT))
		var it: Dictionary = d.item
		var price: int = d.price
		var deal_id: String = it.id
		var on_deal := func():
			if _gs.buy_furniture(deal_id, price):
				furniture_changed.emit()
			_render()
		_screen.add_child(_buy_card(it.name + " (used)", it.desc, price, "", on_deal, "+%d VIBE  +%d AC  +%d COMF" % [it.vibe, it.acoustics, it.comfort]))


# ---------- Zoef (delivery side job) ----------

func _zoef() -> void:
	_header("Zoef", "Deliveries done: %d" % _gs.deliveries)
	var z: Dictionary = ctx.get("zoef") if ctx else {}
	var card := _card()
	var v := VBoxContainer.new()
	card.add_child(v)
	if z.is_empty():
		v.add_child(UIKit.wrap_label("Pick up at Snackbar De Hoek, drop it at the door. €6–14 per ride + tip. Faster = more money. Rain = +30% tips. An e-step helps a lot.", 13, UIKit.DIM, 330))
		var b := UIKit.button("GO ONLINE · FIND A RIDE", UIKit.ACCENT, 14)
		b.disabled = not (ctx and ctx.get("in_city"))
		b.pressed.connect(func():
			zoef_requested.emit("start")
			_render())
		v.add_child(b)
		if not (ctx and ctx.get("in_city")):
			v.add_child(UIKit.label("Go outside to start delivering.", 12, UIKit.POP))
	else:
		v.add_child(UIKit.label("Active order: " + str(z.food), 16, UIKit.TEXT))
		v.add_child(UIKit.label(("Picked up → deliver to " if z.picked else "Pick up at Snackbar De Hoek → ") + str(z.address), 13, UIKit.CYAN))
		v.add_child(UIKit.label("Pays €%d  ·  %d min left" % [int(z.pay), maxi(int(z.until) - _gs.minutes, 0)], 13, UIKit.GOLD))
		var c := UIKit.button("CANCEL ORDER", UIKit.PANEL_LIGHT, 13)
		c.pressed.connect(func():
			zoef_requested.emit("cancel")
			_render())
		v.add_child(c)
	_screen.add_child(card)


# ---------- Goals ----------

func _goals() -> void:
	var lv := _gs.level()
	_header("Goals", "Producer level %d  ·  %d XP" % [lv, _gs.xp])
	var bar := ProgressBar.new()
	bar.min_value = _gs.level_xp(lv)
	bar.max_value = _gs.level_xp(lv + 1)
	bar.value = _gs.xp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.add_theme_stylebox_override("background", UIKit.box(Color(1, 1, 1, 0.08), 5, Color(), 0, 0))
	bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.GOLD, 5, Color(), 0, 0))
	_screen.add_child(bar)
	var next_rent := 7 - ((_gs.day - 1) % 7)
	_screen.add_child(UIKit.label("Release streak: %d night%s (streams ×%.1f)  ·  rent €%d in %d night%s" % [
		_gs.streak, "" if _gs.streak == 1 else "s", _gs.streak_mult(), GameState.RENT, next_rent, "" if next_rent == 1 else "s"], 12, UIKit.CYAN))
	for g in Goals.active(_gs):
		var card := _card()
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(UIKit.wrap_label(str(g.text), 15, UIKit.TEXT, 330))
		var cur := mini(Goals.progress(g.id, _gs), int(g.target))
		var pb := ProgressBar.new()
		pb.max_value = int(g.target)
		pb.value = cur
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 8)
		pb.add_theme_stylebox_override("background", UIKit.box(Color(1, 1, 1, 0.08), 4, Color(), 0, 0))
		pb.add_theme_stylebox_override("fill", UIKit.box(UIKit.CYAN, 4, Color(), 0, 0))
		v.add_child(pb)
		var reward := "€%d" % int(g.money)
		if int(g.rep) > 0:
			reward += "  ·  +%d REP" % int(g.rep)
		v.add_child(UIKit.label("%d / %d    reward: %s  ·  +%d XP" % [cur, int(g.target), reward, int(g.xp)], 12, UIKit.GOLD))
		_screen.add_child(card)
	_screen.add_child(UIKit.label("Completed: %d / %d" % [_gs.goals_done.size(), Goals.LIST.size()], 12, UIKit.DIM))
	var pl := _gs.plaques()
	if not pl.is_empty():
		_screen.add_child(UIKit.label("On your wall: " + ", ".join(pl.map(func(x): return str(x).capitalize() + " plaque")), 12, UIKit.GOLD))


# ---------- Settings ----------

func _settings() -> void:
	_header("Settings")
	var h := UIKit.button("Beat hints: %s" % ("EASY" if _easy else "PRO"), UIKit.PANEL_LIGHT, 14)
	h.pressed.connect(func():
		_easy = not _easy
		hints_toggled.emit(_easy)
		_render())
	_screen.add_child(h)
	var q := UIKit.button("Graphics quality (F9)", UIKit.PANEL_LIGHT, 14)
	q.pressed.connect(func(): quality_toggled.emit())
	_screen.add_child(q)
	_screen.add_child(UIKit.label("GRIND OS 2.6  ·  Kade 17, 7th floor", 12, UIKit.DIM))


## App icon drawn in code: rounded square + simple white glyph + unread badge.
class AppIcon extends Control:
	var color := Color.WHITE
	var glyph := ""
	var badge := 0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(18)
		draw_style_box(sb, r)
		var c := size / 2.0
		var w := Color(1, 1, 1, 0.95)
		match glyph:
			"bubble":
				draw_rect(Rect2(c + Vector2(-18, -14), Vector2(36, 24)), w)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 9), c + Vector2(-2, 9), c + Vector2(-14, 18)]), w)
			"handset":
				draw_arc(c + Vector2(4, -4), 16, PI * 0.55, PI * 1.45, 16, w, 7.0)
				draw_circle(c + Vector2(-8, -16), 5, w)
				draw_circle(c + Vector2(-8, 8), 5, w)
			"wave":
				for i in 5:
					var hgt: float = [10.0, 22.0, 30.0, 18.0, 12.0][i]
					draw_rect(Rect2(c + Vector2(-20 + i * 9, -hgt / 2.0), Vector2(5, hgt)), w)
			"cog":
				for i in 8:
					var a := i * TAU / 8.0
					draw_line(c, c + Vector2(cos(a), sin(a)) * 20, w, 7.0)
				draw_circle(c, 13, w)
				draw_circle(c, 6, color)
			"sofa":
				draw_rect(Rect2(c + Vector2(-20, -4), Vector2(40, 12)), w)
				draw_rect(Rect2(c + Vector2(-16, -14), Vector2(32, 10)), w)
				draw_rect(Rect2(c + Vector2(-22, -8), Vector2(6, 16)), w)
				draw_rect(Rect2(c + Vector2(16, -8), Vector2(6, 16)), w)
				draw_rect(Rect2(c + Vector2(-18, 8), Vector2(4, 6)), w)
				draw_rect(Rect2(c + Vector2(14, 8), Vector2(4, 6)), w)
			"tag":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -6), c + Vector2(-6, -18), c + Vector2(18, -18), c + Vector2(18, 6), c + Vector2(6, 18), c + Vector2(-18, 18)]), w)
				draw_circle(c + Vector2(9, -9), 4, color)
			"bag":
				draw_rect(Rect2(c + Vector2(-16, -8), Vector2(32, 26)), w)
				draw_arc(c + Vector2(0, -8), 9, PI, TAU, 12, w, 4.0)
				draw_line(c + Vector2(-8, 4), c + Vector2(8, 4), color, 3.0)
			"trophy":
				draw_rect(Rect2(c + Vector2(-12, -18), Vector2(24, 14)), w)
				draw_circle(c + Vector2(0, -4), 12, w)
				draw_rect(Rect2(c + Vector2(-3, 6), Vector2(6, 8)), w)
				draw_rect(Rect2(c + Vector2(-11, 14), Vector2(22, 5)), w)
				draw_arc(c + Vector2(-13, -10), 6, PI * 0.5, PI * 1.5, 10, w, 3.0)
				draw_arc(c + Vector2(13, -10), 6, -PI * 0.5, PI * 0.5, 10, w, 3.0)
			"sliders":
				for i in 3:
					var y := -12 + i * 12
					draw_line(c + Vector2(-18, y), c + Vector2(18, y), w, 3.0)
					draw_circle(c + Vector2([-8.0, 10.0, -2.0][i], y), 5, w)
		if badge > 0:
			var bp := Vector2(size.x - 8, 8)
			draw_circle(bp, 11, Color("ff2d55"))
			var f := get_theme_default_font()
			var txt := str(badge)
			draw_string(f, bp + Vector2(-4 * txt.length(), 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
