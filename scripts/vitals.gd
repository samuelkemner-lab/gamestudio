class_name Vitals
extends RefCounted
## Energy, consumables and their effects. Everything gives something and costs something.
## Times are in game minutes (1 real second = 1 game minute; a night is ~480 minutes).
## State lives in GameState: energy (0..100), effects {name: minutes left}, items {id: count}, night counters.
## main.gd ticks this every game minute and applies `mods()` to the player, camera, screen tint and audio.

const ITEMS := {
	"joint": {"name": "Joint", "max": 5, "desc": "Slow, warm, muffled. Next rapper: +1 take. Munchies later."},
	"raket": {"name": "RAKET", "max": 6, "desc": "Energy drink. Sprint faster, stay up longer. Then you crash."},
	"pils": {"name": "Pils", "max": 6, "desc": "Courage. Wobbly. Don't ride your step after a few."},
	"water": {"name": "Water", "max": 6, "desc": "Sobers you up, ends the crash. Boring but it works."},
	"brood": {"name": "Bread", "max": 6, "desc": "Feed the pigeons (or yourself, it kills the munchies)."},
	"kraslot": {"name": "Scratch card", "max": 10, "desc": "€2. Odds on the back. Scratch with the hotbar key."},
	"keelspray": {"name": "Throat spray", "max": 5, "desc": "Give it to a rapper before a take: +5 on that take."},
	"hengel": {"name": "Fishing rod", "max": 1, "desc": "Fish at the quay railing. You never know what bites."},
	"paraplu": {"name": "Umbrella", "max": 1, "desc": "[U] to open. Rain stops draining your energy."},
	"vis": {"name": "Fish", "max": 10, "desc": "Fresh from the Maas. Ome Kees at the snackbar buys them."},
}
const HOTBAR := ["joint", "raket", "pils", "water", "brood", "kraslot"]  # keys 1–6

const HIGH := 90
const MUNCHIES := 60
const RAKET := 90
const CRASH := 45
const HEART := 60
const DRUNK_PER_BEER := 45
const DRUNK_MAX := 160
const COMA := 18
const JITTER := 60


# ---------- inventory ----------

static func add_item(gs: GameState, id: String, n := 1) -> bool:
	var it: Dictionary = ITEMS.get(id, {})
	if it.is_empty():
		return false
	var have := int(gs.items.get(id, 0))
	if have >= int(it.max):
		return false
	gs.items[id] = mini(have + n, int(it.max))
	gs.changed.emit()
	return true


static func count(gs: GameState, id: String) -> int:
	return int(gs.items.get(id, 0))


static func take(gs: GameState, id: String) -> bool:
	if count(gs, id) <= 0:
		return false
	gs.items[id] = count(gs, id) - 1
	if int(gs.items[id]) <= 0:
		gs.items.erase(id)
	return true


# ---------- using things ----------

static func _fx(gs: GameState, name: String, minutes: int) -> void:
	gs.effects[name] = maxi(int(gs.effects.get(name, 0)), minutes)


static func has(gs: GameState, name: String) -> bool:
	return int(gs.effects.get(name, 0)) > 0


static func energy_add(gs: GameState, v: float) -> void:
	gs.energy = clampf(gs.energy + v, 0.0, 100.0)


## Consume one item from the inventory (or `free` = served at a counter). Returns a line for the toast.
static func use(gs: GameState, id: String, free := false) -> String:
	if not free and not take(gs, id):
		return ""
	var line := ""
	match id:
		"joint":
			_fx(gs, "high", HIGH)
			gs.effects.erase("fed")
			gs.add_buff("chill", 1)
			energy_add(gs, -8)
			line = "You light up. Everything slows down... warm... nice. (Next rapper: +1 take)"
		"raket":
			gs.night.raket = int(gs.night.get("raket", 0)) + 1
			_fx(gs, "raket", RAKET)
			gs.effects.erase("crash")
			energy_add(gs, 30)
			gs.add_buff("awake", 30)
			line = "*pssht* RAKET. Your eyes open wide. Sprint like the wind."
			if int(gs.night.raket) >= 3:
				_fx(gs, "heart", HEART)
				line = "Third can. Your heart is pounding in your ears..."
		"pils":
			gs.night.beers = int(gs.night.get("beers", 0)) + 1
			gs.effects["drunk"] = mini(int(gs.effects.get("drunk", 0)) + DRUNK_PER_BEER, DRUNK_MAX)
			energy_add(gs, -4)
			line = ["*pop* Proost.", "Another one. The floor is a bit wavy.", "Okay. That's... a lot of pils."][mini(int(gs.night.beers) - 1, 2)]
		"water":
			gs.effects["drunk"] = maxi(int(gs.effects.get("drunk", 0)) - 70, 0)
			for e in ["crash", "heart", "coma", "jitter"]:
				gs.effects.erase(e)
			energy_add(gs, 3)
			line = "Ice-cold water. Your head clears up."
		"brood":
			eat(gs, false)
			line = "You eat the bread yourself. The munchies are gone. The pigeons judge you."
	_clean(gs)
	gs.changed.emit()
	return line


## Food: kills the munchies, gives energy; a big meal (kapsalon, döner) makes you sluggish for a bit.
static func eat(gs: GameState, big: bool) -> void:
	gs.effects.erase("munchies")
	gs.effects["fed"] = 120
	energy_add(gs, 15 if big else 6)
	if big:
		_fx(gs, "coma", COMA)
	gs.changed.emit()


static func coffee(gs: GameState) -> void:
	gs.night.coffee = int(gs.night.get("coffee", 0)) + 1
	energy_add(gs, 20)
	if int(gs.night.coffee) >= 3:
		_fx(gs, "jitter", JITTER)
	gs.changed.emit()


# ---------- time passes ----------

## One game minute. `outdoors_rain_unsheltered`: out in the rain without an umbrella.
static func tick(gs: GameState, wet := false, sprint_secs := 0.0) -> Array:
	var events: Array = []
	var drain := 0.1
	if wet:
		drain *= 1.8
	if has(gs, "heart"):
		drain *= 2.0
	if int(gs.room_stats().comfort) >= 10:
		drain *= 0.85
	if not has(gs, "raket"):
		drain += sprint_secs * 0.3
	energy_add(gs, -drain)
	var ended: Array = []
	for k in gs.effects.keys():
		gs.effects[k] = int(gs.effects[k]) - 1
		if int(gs.effects[k]) <= 0:
			ended.append(k)
	for k in ended:
		gs.effects.erase(k)
		match k:
			"high":
				if not has(gs, "fed"):
					_fx(gs, "munchies", MUNCHIES)
					events.append("munchies")
			"raket":
				_fx(gs, "crash", CRASH)
				events.append("crash")
	if gs.energy <= 20.0 and not gs.night.get("tired_told", false):
		gs.night.tired_told = true
		events.append("tired")
	return events


static func _clean(gs: GameState) -> void:
	for k in gs.effects.keys():
		if int(gs.effects[k]) <= 0:
			gs.effects.erase(k)


# ---------- what it does to you ----------

static func drunk_level(gs: GameState) -> float:
	return clampf(float(gs.effects.get("drunk", 0)) / 120.0, 0.0, 1.0)


## Modifiers for the player and the screen this frame.
static func mods(gs: GameState) -> Dictionary:
	var walk := 1.0
	var sprint := 1.0
	var can_sprint := true
	var sway := 0.0
	var shake := 0.0
	var tint := Color(0, 0, 0, 0)
	var lowpass := 0.0  # cutoff Hz, 0 = off
	if has(gs, "high"):
		walk *= 0.75
		sway += 0.6
		tint = Color(1.0, 0.72, 0.38, 0.13)
		lowpass = 2600.0
	if has(gs, "munchies"):
		walk *= 0.85
	if has(gs, "raket"):
		sprint *= 1.35
		tint = Color(0.6, 0.9, 1.0, 0.05) if tint.a == 0.0 else tint
	if has(gs, "crash"):
		walk *= 0.8
		can_sprint = false
		shake += 0.25
		tint = Color(0.45, 0.45, 0.5, 0.16)
	if has(gs, "heart"):
		shake += 0.15
		tint = Color(0.9, 0.1, 0.15, 0.1)
	if has(gs, "coma"):
		walk *= 0.85
	if has(gs, "jitter"):
		shake += 0.35
	var dl := drunk_level(gs)
	if dl > 0.0:
		sway += dl
		if dl > 0.8:
			walk *= 0.9
		if lowpass == 0.0 and dl > 0.5:
			lowpass = 7000.0
		if tint.a == 0.0:
			tint = Color(1.0, 0.85, 0.55, 0.06 * dl)
	if gs.energy < 5.0:
		walk *= 0.7
		can_sprint = false
	elif gs.energy < 20.0:
		walk *= 0.85
	return {"walk": walk, "sprint": sprint, "can_sprint": can_sprint, "sway": sway, "wobble": dl, "shake": shake, "tint": tint, "lowpass": lowpass}


## Open mic courage: 1–2 beers help, 3+ and you slur.
static func stage_bonus(gs: GameState) -> int:
	var beers := int(gs.night.get("beers", 0))
	if not has(gs, "drunk") or beers == 0:
		return 0
	return 10 if beers <= 2 else -10


static func status_text(gs: GameState) -> String:
	var names := {"high": "high", "munchies": "munchies", "raket": "RAKET", "crash": "crash", "heart": "heart racing",
		"coma": "food coma", "jitter": "jittery", "drunk": "tipsy" if drunk_level(gs) < 0.6 else "drunk"}
	var parts: Array = []
	for k in names:
		if has(gs, k):
			parts.append("%s %d:%02d" % [names[k], int(gs.effects[k]) / 60, int(gs.effects[k]) % 60])
	if gs.energy < 20.0:
		parts.append("TIRED" if gs.energy >= 5.0 else "EXHAUSTED")
	return "  ·  ".join(parts)
