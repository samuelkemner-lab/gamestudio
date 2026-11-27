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


func add(money_delta: int, rep_delta: int, cred_delta: int) -> void:
	money += money_delta
	reputation = maxi(reputation + rep_delta, 0)
	street_cred = maxi(street_cred + cred_delta, 0)
	changed.emit()
	save()


func record_track(rapper_id: String, stars: int, score: int) -> void:
	sessions += 1
	tracks.append({"rapper": rapper_id, "stars": stars, "score": score})
	save()


func reset() -> void:
	money = 50
	reputation = 0
	street_cred = 0
	sessions = 0
	tracks = []
	noise = 0.0
	changed.emit()


func save() -> void:
	if not persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"money": money, "reputation": reputation, "street_cred": street_cred,
			"sessions": sessions, "tracks": tracks,
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
	changed.emit()
