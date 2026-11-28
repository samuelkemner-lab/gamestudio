class_name CityUI
extends Control
## Shop counters in town: music store, coffeeshop, snackbar, night shop, casino, pro studio.

signal closed
signal message(text: String)
signal upgrades_changed
signal arcade_requested

const MUSIC_DISCOUNT := 0.85
const FISH_PRICE := 4  # cash price in the store vs. the online shop on your phone

const MENUS := {
	"coffeeshop": {
		"title": "GROENE WOLK", "color": Color("4ade80"),
		"intro": "Coffeeshop. 18+ only, the guy at the counter checks your ID twice. It smells like a festival in here.",
		"items": [
			{"id": "preroll", "name": "Pre-roll \"Maas Haze\"", "price": 15, "item": "joint",
				"desc": "Smoke it with [1]: you walk slower, everything gets warm and muffled, your next rapper gets +1 take. Munchies after."},
		],
	},
	"snackbar": {
		"title": "SNACKBAR DE HOEK", "color": Color("fbbf24"),
		"intro": "Ome Kees has been frying since 1987. \"Wat mag het zijn, jongen?\"",
		"items": [
			{"id": "kapsalon", "name": "Kapsalon", "price": 9, "buff": "awake", "amount": 60, "food": "big",
				"desc": "Fries, shawarma, cheese, salad, garlic sauce. Awake one hour longer, munchies gone. Food coma for a bit."},
			{"id": "frikandel", "name": "Frikandel speciaal", "price": 4, "buff": "awake", "amount": 30, "food": "small",
				"desc": "Curry, mayo, onions. +30 minutes before you pass out, munchies gone."},
		],
	},
	"nightshop": {
		"title": "NACHTWINKEL", "color": Color("f472b6"),
		"intro": "Open 24/7. Fluorescent lights, a cat on the counter, and a guy who has seen everything.",
		"items": [
			{"id": "raket", "name": "RAKET energy drink", "price": 3, "item": "raket",
				"desc": "[2] Sprint 35% faster, +30 energy, awake longer. Then you crash. Three cans = heart racing."},
			{"id": "pils", "name": "Pils (can)", "price": 2, "item": "pils",
				"desc": "[3] Courage at the open mic and with excuses. Wobbly walking. Never ride your step after a few."},
			{"id": "water", "name": "Water", "price": 1, "item": "water",
				"desc": "[4] Sobers you up, ends the crash."},
			{"id": "brood", "name": "Bread", "price": 1, "item": "brood",
				"desc": "[5] Feed the pigeons. They'll follow you around."},
			{"id": "kraslot", "name": "Scratch card \"Maas Miljoen\"", "price": 2, "item": "kraslot",
				"desc": "[6] Odds: €2 1 in 5 · €5 1 in 25 · €20 1 in 100 · €100 1 in 500 · €1000 1 in 10,000. Pays back ~55%."},
			{"id": "keelspray", "name": "Throat spray", "price": 4, "item": "keelspray",
				"desc": "Give it to a rapper before a take (talk to them): +5 on that take."},
			{"id": "hengel", "name": "Telescopic fishing rod", "price": 15, "item": "hengel",
				"desc": "Fish at the quay railing. Eels, bikes, and sometimes something very interesting."},
			{"id": "paraplu", "name": "Umbrella", "price": 12, "item": "paraplu",
				"desc": "[U] open/close. Rain stops draining your energy."},
			{"id": "stroopwafels", "name": "Stroopwafels for the neighbours", "price": 8, "buff": "gift", "amount": 1,
				"desc": "A peace offering. Noise meter back to zero, and it rises 30% slower tonight."},
		],
	},
}

var game: GameState
var shop_id := ""
var _panel: PanelContainer
var _col: VBoxContainer
var _wallet: Label
var _rng := RandomNumberGenerator.new()
# casino widgets
var _reels: Array[Label] = []
var _slot_result: Label
var _roul_result: Label
var _roul_bet := 10
var _bet_btns: Array[Button] = []
var _spinning := false


func _ready() -> void:
	_rng.randomize()


func open(id: String, gs: GameState) -> void:
	game = gs
	shop_id = id
	for c in get_children():
		c.queue_free()
	_reels.clear()
	_bet_btns.clear()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var colour := _colour(id)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.BG, 24, colour, 2, 30))
	_panel.custom_minimum_size = Vector2(820 if id == "casino" else 700, 0)
	add_child(_panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 12)
	_panel.add_child(_col)
	var head := HBoxContainer.new()
	_col.add_child(head)
	head.add_child(UIKit.label(_title(id), 30, colour))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_wallet = UIKit.label("", 20, UIKit.GOLD)
	head.add_child(_wallet)
	match id:
		"music":
			_music()
		"casino":
			_casino()
		"studio":
			_studio()
		_:
			_menu(MENUS.get(id, {}))
	var leave := UIKit.button("LEAVE  [ESC]", UIKit.PANEL_LIGHT, 16)
	leave.pressed.connect(close)
	_col.add_child(leave)
	_refresh_wallet()
	visible = true
	_panel.reset_size()
	_panel.position = (get_viewport_rect().size - _panel.size) / 2.0


func close() -> void:
	if _spinning:
		return
	visible = false
	closed.emit()


func _title(id: String) -> String:
	match id:
		"music": return "WAX & WIRES"
		"casino": return "LUCKY STACK"
		"studio": return "MAAS SOUND STUDIOS"
	return str(MENUS.get(id, {}).get("title", id.to_upper()))


func _colour(id: String) -> Color:
	match id:
		"music": return Color("25d9f5")
		"casino": return Color("ffcc4d")
		"studio": return Color("a78bfa")
	return MENUS.get(id, {}).get("color", UIKit.ACCENT)


func _refresh_wallet() -> void:
	if _wallet:
		_wallet.text = "€ %d" % game.money


func _row(name: String, desc: String, right: Control) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL, 12, Color(), 0, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_child(UIKit.label(name, 17, UIKit.TEXT))
	txt.add_child(UIKit.wrap_label(desc, 13, UIKit.DIM, 420))
	row.add_child(txt)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	_col.add_child(card)


# ---------- Music store ----------

static func store_price(id: String) -> int:
	return int(round(int(Shop.item(id).price) * MUSIC_DISCOUNT))


func _music() -> void:
	_col.add_child(UIKit.wrap_label("Second-hand gear, new synths, drum kits on USB sticks. Cash price here is 15% cheaper than ordering on your phone.", 14, UIKit.DIM, 640))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_col.add_child(scroll)
	var keep := _col
	_col = list
	for it in Shop.ITEMS:
		var id: String = it.id
		var price := store_price(id)
		var owned := game.has(id)
		var b := UIKit.button("OWNED" if owned else "BUY  €%d" % price, UIKit.PANEL_LIGHT if owned else UIKit.CYAN.darkened(0.35), 15)
		b.custom_minimum_size.x = 130
		b.disabled = owned or game.money < price
		b.pressed.connect(func():
			if game.buy_at(id, price):
				message.emit("Bought %s for €%d cash." % [it.name, price])
				upgrades_changed.emit()
				open("music", game))
		_row("%s   (online €%d)" % [it.name, it.price], it.desc, b)
	_col = keep


# ---------- Coffeeshop / snackbar / night shop ----------

func _menu(m: Dictionary) -> void:
	_col.add_child(UIKit.wrap_label(str(m.get("intro", "")), 14, UIKit.DIM, 620))
	for it in m.get("items", []):
		var b := UIKit.button("BUY  €%d" % it.price, Color(m.color).darkened(0.45), 15)
		b.custom_minimum_size.x = 120
		var maxed := _buff_maxed(it)
		if it.has("item"):
			var have := Vitals.count(game, str(it.item))
			maxed = have >= int(Vitals.ITEMS[it.item].max)
			b.text = "BUY  €%d" % it.price if not maxed else ("HAVE IT" if int(Vitals.ITEMS[it.item].max) == 1 else "FULL")
			if have > 0 and not maxed:
				b.text += "  (%d)" % have
		elif maxed:
			b.text = "HAVE IT"
		b.disabled = maxed or game.money < int(it.price)
		b.pressed.connect(func():
			if game.spend(int(it.price)):
				if it.has("item"):
					Vitals.add_item(game, str(it.item))
					message.emit("%s in your pocket." % str(Vitals.ITEMS[it.item].name))
				else:
					game.add_buff(str(it.buff), int(it.amount))
					if it.has("food"):
						Vitals.eat(game, str(it.food) == "big")
					message.emit(_buff_text(it))
				open(shop_id, game))
		_row(str(it.name), str(it.desc), b)
	if shop_id == "snackbar" and Vitals.count(game, "vis") > 0:
		var n := Vitals.count(game, "vis")
		var sell := UIKit.button("SELL  €%d" % (n * FISH_PRICE), Color("2f6b9a"), 15)
		sell.custom_minimum_size.x = 120
		sell.pressed.connect(func():
			sell_fish()
			open(shop_id, game))
		_row("Your catch (%d fish)" % n, "\"Uit de Maas? Ach, voor de kibbeling is het goed genoeg.\" Ome Kees pays €%d a fish." % FISH_PRICE, sell)
	if shop_id == "snackbar":
		var play := UIKit.button("PLAY  €1", Color("7a5cff"), 15)
		play.custom_minimum_size.x = 120
		play.disabled = game.money < 1
		play.pressed.connect(func(): arcade_requested.emit())
		var hi := int(game.records.get("arcade_high", 0))
		_row("BEAT DROP  (arcade cabinet by the window)", "Four lanes, D F J K. Beat the names on the machine for prizes. Your high score: %s" % (str(hi) if hi > 0 else "--"), play)
	var status := _status_text()
	if status != "":
		_col.add_child(UIKit.label(status, 14, UIKit.CYAN))


func sell_fish() -> int:
	var n := Vitals.count(game, "vis")
	if n <= 0:
		return 0
	game.items.erase("vis")
	game.add(n * FISH_PRICE, 0, 0)
	message.emit("Sold %d fish to Ome Kees for €%d." % [n, n * FISH_PRICE])
	return n * FISH_PRICE


func _buff_maxed(it: Dictionary) -> bool:
	match str(it.get("buff", "")):
		"chill":
			return int(game.buffs.chill) >= 1
		"awake":
			return int(game.buffs.awake) >= 120
		"gift":
			return bool(game.buffs.gift)
	return false


func _buff_text(it: Dictionary) -> String:
	match str(it.get("buff", "")):
		"chill":
			return "In your pocket. The next rapper will be extra patient."
		"awake":
			return "You feel awake. You can stay up until %s." % _dawn_text()
		"gift":
			return "The neighbours love you (for tonight). Noise reset."
	return ""


func _dawn_text() -> String:
	var m := game.dawn_minutes() % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


func _status_text() -> String:
	var parts: Array[String] = []
	if int(game.buffs.chill) > 0:
		parts.append("chill vibes ready")
	if int(game.buffs.awake) > 0:
		parts.append("awake until %s" % _dawn_text())
	if game.buffs.gift:
		parts.append("neighbours happy")
	return "" if parts.is_empty() else "Active: " + ", ".join(parts)


# ---------- Pro studio (future progression) ----------

func _studio() -> void:
	_col.add_child(UIKit.wrap_label("The A-room: a real console, a booth with a window, monitors that cost more than your flat. Big artists record here.", 15, UIKit.DIM, 620))
	var need := 40
	var ok := game.reputation >= need
	_col.add_child(UIKit.label("Renting the A-room unlocks at %d REP  (you: %d)" % [need, game.reputation], 17, UIKit.CYAN if ok else UIKit.POP))
	var b := UIKit.button("COMING SOON", UIKit.PANEL_LIGHT, 15)
	b.disabled = true
	_col.add_child(b)


# ---------- Casino ----------

func _casino() -> void:
	_col.add_child(UIKit.wrap_label("Slots and roulette, paid with your studio money. The house always wins in the long run.", 14, UIKit.DIM, 740))
	var games := HBoxContainer.new()
	games.add_theme_constant_override("separation", 16)
	_col.add_child(games)

	# Slots
	var slots := _game_card("SLOTS")
	var reel_row := HBoxContainer.new()
	reel_row.add_theme_constant_override("separation", 10)
	reel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIKit.box(Color("f2efe6"), 10, Color("d4a73a"), 3, 8))
		p.custom_minimum_size = Vector2(96, 96)
		var l := UIKit.label("7", 40, Color("7a1020"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		reel_row.add_child(p)
		_reels.append(l)
	slots.add_child(reel_row)
	_slot_result = UIKit.label("3 of a kind: 7 = 20x · BAR = 10x · other 6x · pair 1.5x", 13, UIKit.DIM)
	_slot_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slots.add_child(_slot_result)
	var bets := HBoxContainer.new()
	bets.alignment = BoxContainer.ALIGNMENT_CENTER
	bets.add_theme_constant_override("separation", 8)
	for bet in Casino.BETS:
		var b := UIKit.button("SPIN €%d" % bet, Color("7a1020"), 15)
		b.disabled = game.money < bet
		b.pressed.connect(spin_slots.bind(bet))
		bets.add_child(b)
		_bet_btns.append(b)
	slots.add_child(bets)
	games.add_child(slots.get_parent())

	# Roulette
	var roul := _game_card("ROULETTE")
	var amount := HBoxContainer.new()
	amount.alignment = BoxContainer.ALIGNMENT_CENTER
	amount.add_theme_constant_override("separation", 6)
	amount.add_child(UIKit.label("BET", 14, UIKit.DIM))
	for bet in Casino.BETS:
		var b := UIKit.button("€%d" % bet, UIKit.PANEL_LIGHT, 14)
		b.toggle_mode = true
		b.button_pressed = bet == _roul_bet
		b.pressed.connect(func():
			_roul_bet = bet
			for o in amount.get_children():
				if o is Button:
					(o as Button).set_pressed_no_signal(o == b))
		amount.add_child(b)
	roul.add_child(amount)
	var picks := HBoxContainer.new()
	picks.alignment = BoxContainer.ALIGNMENT_CENTER
	picks.add_theme_constant_override("separation", 8)
	for pick in [["RED  2x", Color("b3122e"), "red"], ["BLACK  2x", Color("1b1a22"), "black"], ["0  36x", Color("15803d"), "green"]]:
		var b := UIKit.button(pick[0], pick[1], 15)
		b.pressed.connect(spin_roulette.bind(pick[2]))
		picks.add_child(b)
		_bet_btns.append(b)
	roul.add_child(picks)
	_roul_result = UIKit.label("Pick a colour.", 18, UIKit.TEXT)
	_roul_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roul.add_child(_roul_result)
	games.add_child(roul.get_parent())
	_col.add_child(UIKit.label(_net_text(), 14, UIKit.DIM))


func _game_card(title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(Color("1a0d14"), 14, Color("d4a73a"), 1, 16))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var t := UIKit.label(title, 18, Color("ffcc4d"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


func _net_text() -> String:
	var n := game.casino_net
	return "Your casino total: %s€%d" % ["+" if n >= 0 else "-", absi(n)]


func spin_slots(bet: int) -> Dictionary:
	if _spinning or not game.spend(bet):
		return {}
	var res := Casino.spin_slots(_rng, bet)
	_spinning = true
	_set_bets_disabled(true)
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		for i in 14:
			for r in _reels:
				r.text = Casino.SYMBOLS[randi() % Casino.SYMBOLS.size()]
			await get_tree().create_timer(0.06).timeout
	for i in 3:
		_reels[i].text = res.reels[i]
	_payout(res.win, bet)
	if res.win > 0:
		_slot_result.text = ("JACKPOT! " if res.jackpot else "") + "You win €%d" % res.win
		_slot_result.add_theme_color_override("font_color", UIKit.GOLD)
	else:
		_slot_result.text = "Nothing. -€%d" % bet
		_slot_result.add_theme_color_override("font_color", UIKit.DIM)
	_spinning = false
	_set_bets_disabled(false)
	return res


func spin_roulette(choice: String) -> Dictionary:
	var bet := _roul_bet
	if _spinning or not game.spend(bet):
		return {}
	var res := Casino.spin_roulette(_rng, bet, choice)
	_spinning = true
	_set_bets_disabled(true)
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		for i in 16:
			_roul_result.text = str(randi() % 37)
			await get_tree().create_timer(0.05 + i * 0.006).timeout
	_payout(res.win, bet)
	_roul_result.text = "%d %s  ·  %s" % [res.number, str(res.colour).to_upper(), ("you win €%d" % res.win) if res.win > 0 else "you lose €%d" % bet]
	_roul_result.add_theme_color_override("font_color", UIKit.GOLD if res.win > 0 else UIKit.DIM)
	_spinning = false
	_set_bets_disabled(false)
	return res


func _payout(win: int, bet: int) -> void:
	game.casino_net += win - bet
	if win > 0:
		game.add(win, 0, 0)
	else:
		game.save()
	_refresh_wallet()


func _set_bets_disabled(on: bool) -> void:
	for b in _bet_btns:
		if is_instance_valid(b):
			b.disabled = on
	if not on:
		for i in Casino.BETS.size():
			if i < _bet_btns.size() and is_instance_valid(_bet_btns[i]):
				_bet_btns[i].disabled = game.money < Casino.BETS[i]
