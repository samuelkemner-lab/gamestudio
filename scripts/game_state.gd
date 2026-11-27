class_name GameState
extends Node
## Player progress: money, reputation, street cred, released tracks. Saved to user://.

signal changed

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


func add(money_delta: int, rep_delta: int, cred_delta: int) -> void:
	money += money_delta
	reputation = maxi(reputation + rep_delta, 0)
	street_cred = maxi(street_cred + cred_delta, 0)
	changed.emit()
	save()


## song = arranged in the Playlist (4+ bars, 2+ patterns): a full song streams 1.5x better.
func record_track(rapper_id: String, stars: int, score: int, song: bool = false) -> void:
	sessions += 1
	tracks.append({"rapper": rapper_id, "stars": stars, "score": score, "day": day, "streams": 0, "song": song})
	save()


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
	day += 1
	minutes = 22 * 60
	noise = 0.0
	booked_today.clear()
	changed.emit()
	save()
	return {"day": day, "earned": earned, "streams": streams_night, "lines": lines, "leak": leak}


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
	changed.emit()
