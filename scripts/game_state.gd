class_name GameState
extends Node
## Player progress: money, reputation, street cred, released tracks. Saved to user://.

signal changed
signal notified(from: String, text: String)  # new message: phone banner
signal goal_completed(goal: Dictionary)
signal leveled(level: int)

const RENT := 100  # per week, due every 7th night
const PLAQUES := [[25000, "gold"], [100000, "platinum"], [500000, "diamond"]]

const SAVE_PATH := "user://studio_grind_save.json"

var money := 50
var reputation := 0
var street_cred := 0
var sessions := 0
var tracks: Array = []  # [{rapper, stars, score}]
var noise := 0.0  # 0..100, neighbours call the cops at 100
var persist := true
var day := 1
var minutes := 22 * 60  # in-game clock, starts 22:00
var upgrades: Array = []
var booked_today: Array = []
var total_streams := 0
# City buffs: chill = next rapper +1 patience, awake = minutes you stay up past 06:00,
# gift = neighbours got stroopwafels (noise rises slower tonight)
var buffs := {"chill": 0, "awake": 0, "gift": false}
var casino_net := 0
var weather := "rain"  # "dry" | "rain" | "mist"  (Rotterdam in November: it rains a lot)
# GRIND OS (phone)
var inbox: Array = []  # [{from, text, day, time, read, me}]
var call_log: Array = []  # [{from, day, time, kind: answered/missed/declined}]
var pending := {}  # rapper on the way after a call: {rapper, until}
var calls_tonight := 0
# Home (Huisraad): owned furniture ids, slot -> placed id
var furniture: Array = []
var placed := {}
# E-step: owned, battery 0..100, home (= taken upstairs, charges overnight), upgrades
var estep := {"owned": false, "battery": 100.0, "home": true, "motor": false, "big_battery": false}
var deliveries := 0
var night_noise_peak := 0.0
# Progression (P5): producer XP/level, release streak, goals, misc stats
var xp := 0
var streak := 0
var last_release_day := -10
var goals_done: Array = []
var stats := {"hot_sessions": 0}
# Vitals: energy 0..100, active effects {name: minutes}, inventory {item: count}, per-night counters
var energy := 100.0
var effects := {}
var items := {}
var night := {}

const MAMA := ["Are you eating well, jongen? x Mama", "Your aunt says she saw you on the internet. Is that good?",
	"Sunday dinner at 5. Bring that rapper friend, he looks hungry.", "Did you sleep at all this week? Answer me.",
	"I put a pan of soup by your door. Don't let it go bad."]
const RAPPER_AGAIN := {
	"big_earl": ["u free tonight? got a new verse, real hip hop", "yo producer. same time? bring the dusty drums"],
	"lil_tear": ["cant sleep again. can we make something sad", "my ex liked my last story. i need a song NOW"],
	"ghost": ["studio tonight. dont be late", "got a new flow. need a cold beat"],
	"spike": ["BRO TONIGHT?? i need ENERGY", "yo the crowd wants more. lets cook"],
}


func add(money_delta: int, rep_delta: int, cred_delta: int) -> void:
	money += money_delta
	reputation = maxi(reputation + rep_delta, 0)
	street_cred = maxi(street_cred + cred_delta, 0)
	changed.emit()
	save()


## song = arranged in the Playlist (4+ bars, 2+ patterns): a full song streams 1.5x better.
func record_track(rapper_id: String, stars: int, score: int, song: bool = false) -> void:
	sessions += 1
	# release streak: one track a night keeps it going (one missed night is forgiven)
	if day != last_release_day:
		streak = streak + 1 if day - last_release_day <= 2 else 1
		last_release_day = day
	tracks.append({"rapper": rapper_id, "stars": stars, "score": score, "day": day, "streams": 0, "song": song})
	save()


## Minute (from 00:00 day 1 base) at which you pass out. Snacks keep you up longer.
func dawn_minutes() -> int:
	return 30 * 60 + int(buffs.get("awake", 0)) + Furniture.comfort_minutes(room_stats())


# ---------- Progression ----------

func level() -> int:
	return int(sqrt(xp / 60.0)) + 1


## XP for the next level (total).
func level_xp(lv: int) -> int:
	return (lv - 1) * (lv - 1) * 60


func add_xp(n: int) -> void:
	var before := level()
	xp += n
	var now := level()
	if now > before:
		money += 25 * now
		leveled.emit(now)
	changed.emit()


## Streams multiplier from the release streak: +10% per night in a row (max +50%).
func streak_mult() -> float:
	return 1.0 + minf(maxf(streak - 1, 0) * 0.1, 0.5)


func plaques() -> Array:
	var out: Array = []
	for p in PLAQUES:
		if total_streams >= int(p[0]):
			out.append(p[1])
	return out


## Pays out every goal that's done. Returns the completed ones.
func check_goals() -> Array:
	var done: Array = []
	for g in Goals.active(self):
		if Goals.progress(g.id, self) >= int(g.target):
			goals_done.append(g.id)
			money += int(g.money)
			reputation += int(g.rep)
			done.append(g)
	for g in done:
		add_xp(int(g.xp))
		goal_completed.emit(g)
	if not done.is_empty():
		changed.emit()
		save()
	return done


func room_stats() -> Dictionary:
	return Furniture.stats(placed)


# ---------- Phone ----------

func message(from: String, text: String, me := false) -> void:
	inbox.append({"from": from, "text": text, "day": day, "time": clock_text(), "read": me, "me": me})
	if inbox.size() > 200:
		inbox = inbox.slice(inbox.size() - 200)
	if not me:
		notified.emit(from, text)
	changed.emit()


func unread(from := "") -> int:
	var n := 0
	for m in inbox:
		if not m.read and (from == "" or m.from == from):
			n += 1
	return n


func mark_read(from: String) -> void:
	for m in inbox:
		if m.from == from:
			m.read = true
	changed.emit()


## Contacts ordered by latest message.
func threads() -> Array:
	var order: Array = []
	for i in range(inbox.size() - 1, -1, -1):
		var f: String = inbox[i].from
		if not f in order:
			order.append(f)
	return order


func log_call(from: String, kind: String) -> void:
	call_log.append({"from": from, "day": day, "time": clock_text(), "kind": kind})
	if call_log.size() > 60:
		call_log = call_log.slice(call_log.size() - 60)
	changed.emit()


## New night: rappers who are unlocked DM you, plus life happening around you.
func nightly_messages() -> void:
	for r in Rappers.all():
		if street_cred >= int(r.get("min_cred", 0)) and reputation >= int(r.get("min_rep", 0)):
			var again: Array = RAPPER_AGAIN.get(r.id, [])
			var first := true
			for m in inbox:
				if m.from == r.name:
					first = false
					break
			message(r.name, r.dm if first or again.is_empty() else again[randi() % again.size()])
	if day == 1:
		message("Zoef", "Earn cash on your own schedule. Open Zoef and go online to deliver food in your area.")
		message("Ruilmarkt", "Welcome! There's a used e-step for sale near you. Check the app.")
	elif randf() < 0.45:
		message("Mama", MAMA[randi() % MAMA.size()])
	if night_noise_peak > 70.0:
		message("Buurman Henk", "Some of us start work at 7. Just saying. Henk (no. 15)")
	night_noise_peak = 0.0


# ---------- Furniture ----------

func buy_furniture(id: String, price := -1) -> bool:
	var it := Furniture.item(id)
	var cost := int(it.get("price", 0)) if price < 0 else price
	if it.is_empty() or id in furniture or money < cost:
		return false
	money -= cost
	furniture.append(id)
	placed[it.slot] = id  # new stuff goes straight into the room
	changed.emit()
	save()
	return true


func place(id: String) -> void:
	var it := Furniture.item(id)
	if it.is_empty() or not id in furniture:
		return
	if placed.get(it.slot, "") == id:
		placed.erase(it.slot)  # put it back in storage
	else:
		placed[it.slot] = id
	changed.emit()
	save()


# ---------- E-step ----------

const STEP_ITEMS := [
	{"id": "estep", "name": "Used e-step", "price": 120, "desc": "\"Works fine, battery ok-ish, small scratch.\" 22 km/h. Picks you up from your front door."},
	{"id": "step_motor", "name": "Motor tune (e-step)", "price": 90, "desc": "Someone's cousin unlocks the speed limiter. 31 km/h.", "needs": "estep"},
	{"id": "step_battery", "name": "Big battery (e-step)", "price": 70, "desc": "Twice the range before you have to kick-push.", "needs": "estep"},
]


func step_owned(id: String) -> bool:
	match id:
		"estep":
			return bool(estep.owned)
		"step_motor":
			return bool(estep.motor)
		"step_battery":
			return bool(estep.big_battery)
	return false


func buy_step_item(id: String) -> bool:
	var it: Dictionary = {}
	for x in STEP_ITEMS:
		if x.id == id:
			it = x
	if it.is_empty() or step_owned(id) or money < int(it.price) or (it.has("needs") and not step_owned(it.needs)):
		return false
	money -= int(it.price)
	match id:
		"estep":
			estep.owned = true
			estep.battery = 100.0
			estep.home = true
		"step_motor":
			estep.motor = true
		"step_battery":
			estep.big_battery = true
	changed.emit()
	save()
	return true


func add_buff(id: String, amount: int = 1) -> void:
	match id:
		"chill":
			buffs.chill = mini(int(buffs.chill) + amount, 1)  # max one in the pocket
		"awake":
			buffs.awake = mini(int(buffs.awake) + amount, 120)
		"gift":
			buffs.gift = true
			noise = 0.0
	changed.emit()
	save()


## Pays `price` instead of the list price (cash price in the music store).
func buy_at(upgrade: String, price: int) -> bool:
	var it: Dictionary = Shop.item(upgrade)
	if it.is_empty() or has(upgrade) or money < price:
		return false
	money -= price
	upgrades.append(upgrade)
	changed.emit()
	save()
	return true


func spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	changed.emit()
	save()
	return true


## New night, new weather: ~40% rain, ~20% mist, otherwise dry (but the streets stay damp).
func roll_weather(r := -1.0) -> void:
	var v := randf() if r < 0.0 else r
	weather = "rain" if v < 0.4 else ("mist" if v < 0.6 else "dry")


func has(upgrade: String) -> bool:
	return upgrade in upgrades


func buy(upgrade: String) -> bool:
	var it: Dictionary = Shop.item(upgrade)
	if it.is_empty() or has(upgrade) or money < int(it.price):
		return false
	money -= int(it.price)
	upgrades.append(upgrade)
	changed.emit()
	save()
	return true


func clock_text_at(m: int) -> String:
	var mm := m % (24 * 60)
	return "%02d:%02d" % [mm / 60, mm % 60]


func clock_text() -> String:
	var m := minutes % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## Sleep → next day: streaming royalties for every released track, maybe a leak.
func sleep() -> Dictionary:
	var lines: Array = []
	var earned := 0
	var streams_night := 0
	var leak := -1
	if tracks.size() > 0 and randf() < 0.15:
		leak = randi() % tracks.size()
	for i in tracks.size():
		var t: Dictionary = tracks[i]
		var age := day - int(t.get("day", day))
		var base := pow(float(t.stars), 2.2) * 160.0 * (1.0 + reputation / 40.0)
		if t.get("song", false):
			base *= 1.5
		base *= streak_mult()
		var s := int(base * randf_range(0.75, 1.25) / (1.0 + age * 0.35))
		var pay_rate := 0.004
		if i == leak:
			s *= 3
			pay_rate *= 0.25
		t.streams = int(t.get("streams", 0)) + s
		var euros := int(round(s * pay_rate))
		earned += euros
		streams_night += s
		lines.append({"rapper": t.rapper, "stars": t.stars, "streams": s, "euros": euros, "leaked": i == leak})
	money += earned
	total_streams += streams_night
	if day - last_release_day >= 2:
		streak = 0  # two nights without a release: streak over
	day += 1
	var rent := 0
	if day > 1 and (day - 1) % 7 == 0:
		rent = RENT
		money -= rent
	minutes = 22 * 60
	noise = 0.0
	booked_today.clear()
	energy = 100.0
	effects = {}
	night = {}
	pending = {}
	calls_tonight = 0
	if estep.owned and estep.home:
		estep.battery = 100.0
	buffs.awake = 0
	buffs.gift = false
	roll_weather()
	nightly_messages()
	changed.emit()
	save()
	if rent > 0:
		message("Huisbaas De Vries", "Rent for this week: €%d. %s" % [rent, "Thanks, received." if money >= 0 else "You're short. Pay up before it gets awkward."])
	return {"day": day, "earned": earned, "streams": streams_night, "lines": lines, "leak": leak, "rent": rent, "streak": streak, "mult": streak_mult()}


func reset() -> void:
	money = 50
	reputation = 0
	street_cred = 0
	sessions = 0
	tracks = []
	noise = 0.0
	day = 1
	minutes = 22 * 60
	upgrades = []
	booked_today = []
	total_streams = 0
	buffs = {"chill": 0, "awake": 0, "gift": false}
	casino_net = 0
	weather = "rain"
	inbox = []
	call_log = []
	pending = {}
	calls_tonight = 0
	furniture = []
	placed = {}
	estep = {"owned": false, "battery": 100.0, "home": true, "motor": false, "big_battery": false}
	deliveries = 0
	night_noise_peak = 0.0
	xp = 0
	streak = 0
	last_release_day = -10
	goals_done = []
	stats = {"hot_sessions": 0}
	energy = 100.0
	effects = {}
	items = {}
	night = {}
	changed.emit()


func save() -> void:
	if not persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"money": money, "reputation": reputation, "street_cred": street_cred,
			"sessions": sessions, "tracks": tracks, "day": day, "upgrades": upgrades,
			"booked_today": booked_today, "total_streams": total_streams,
			"buffs": buffs, "casino_net": casino_net, "weather": weather,
			"inbox": inbox, "call_log": call_log, "furniture": furniture, "placed": placed,
			"estep": estep, "deliveries": deliveries,
			"xp": xp, "streak": streak, "last_release_day": last_release_day, "goals_done": goals_done, "stats": stats,
			"energy": energy, "effects": effects, "items": items, "night": night,
		}))


func load_game() -> void:
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if d is Dictionary:
		money = int(d.get("money", money))
		reputation = int(d.get("reputation", 0))
		street_cred = int(d.get("street_cred", 0))
		sessions = int(d.get("sessions", 0))
		tracks = d.get("tracks", [])
		day = int(d.get("day", 1))
		upgrades = d.get("upgrades", [])
		booked_today = d.get("booked_today", [])
		total_streams = int(d.get("total_streams", 0))
		var b = d.get("buffs", {})
		if b is Dictionary:
			buffs.merge(b, true)
		casino_net = int(d.get("casino_net", 0))
		weather = str(d.get("weather", weather))
		inbox = d.get("inbox", [])
		call_log = d.get("call_log", [])
		furniture = d.get("furniture", [])
		var pl = d.get("placed", {})
		if pl is Dictionary:
			placed = pl
		var st = d.get("estep", {})
		if st is Dictionary:
			estep.merge(st, true)
		deliveries = int(d.get("deliveries", 0))
		xp = int(d.get("xp", 0))
		streak = int(d.get("streak", 0))
		last_release_day = int(d.get("last_release_day", -10))
		goals_done = d.get("goals_done", [])
		var stt = d.get("stats", {})
		if stt is Dictionary:
			stats.merge(stt, true)
		energy = float(d.get("energy", 100.0))
		for key in ["effects", "items", "night"]:
			var v = d.get(key, {})
			if v is Dictionary:
				set(key, v)
	changed.emit()
