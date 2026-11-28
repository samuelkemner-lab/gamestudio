class_name Fishing
extends Node3D
## Fishing at the quay railing: cast, wait for the bobber to dip, press E in time.
## Catches: fish (sell to the snackbar), junk, old bikes, soggy wallets, the odd safe, and once in a
## while a rapper's lost phone with an unreleased demo on it.

signal caught(result: Dictionary)
signal missed
signal ended

const BITE_WINDOW := 1.3
const FISH := ["paling (eel)", "baars (perch)", "snoekbaars (zander)", "karper (carp)", "brasem (bream)"]
const JUNK := ["an old boot", "a crushed can", "a traffic cone", "a shopping cart wheel", "half a scooter mirror"]

var active := false
var phase := ""  # wait | bite
var t := 0.0
var wait := 5.0
var bobber: Node3D
var _base_y := 0.0
var _sfx: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	bobber = Node3D.new()
	add_child(bobber)
	var top := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	top.mesh = sm
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("e8302a")
	red.emission_enabled = true
	red.emission = Color("ff4030")
	red.emission_energy_multiplier = 1.2
	top.material_override = red
	top.position.y = 0.05
	bobber.add_child(top)
	var bot := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.055
	bm.height = 0.09
	bot.mesh = bm
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("eeeeee")
	bot.material_override = white
	bobber.add_child(bot)
	bobber.visible = false
	_sfx = AudioStreamPlayer3D.new()
	_sfx.unit_size = 6.0
	add_child(_sfx)


## Start at a spot; `water_point` is where the bobber lands (global).
func cast(water_point: Vector3) -> void:
	active = true
	bobber.global_position = water_point
	_base_y = water_point.y
	bobber.visible = true
	_new_wait()
	_play(AmbienceSynth.plop())


func _new_wait() -> void:
	phase = "wait"
	t = 0.0
	wait = _rng.randf_range(4.0, 11.0)


func stop() -> void:
	active = false
	phase = ""
	bobber.visible = false
	ended.emit()


## E pressed while fishing: hook it if it's biting, otherwise reel in.
func strike() -> Dictionary:
	if phase == "bite":
		var res := roll(_rng.randf())
		_play(AmbienceSynth.splash())
		caught.emit(res)
		_new_wait()
		bobber.global_position.y = _base_y
		return res
	stop()
	return {}


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	var y := _base_y + sin(t * 2.2) * 0.02
	match phase:
		"wait":
			# little nibbles before the real bite
			if t > wait - 1.5 and fmod(t, 0.5) < 0.1:
				y -= 0.03
			if t >= wait:
				phase = "bite"
				t = 0.0
				_play(AmbienceSynth.splash())
		"bite":
			y = _base_y - 0.14 + sin(t * 30.0) * 0.03
			if t > BITE_WINDOW:
				missed.emit()
				_new_wait()
	bobber.global_position.y = y


func _play(stream: AudioStream) -> void:
	if not is_inside_tree():
		return
	_sfx.global_position = bobber.global_position
	_sfx.stream = stream
	_sfx.play()


## Loot table (r in 0..1): 50% fish, 22% junk, 12% old bike, 8% wallet, 5% safe, 3% a rapper's phone.
static func roll(r: float) -> Dictionary:
	var pick := int(r * 1000.0)
	if r < 0.5:
		return {"kind": "fish", "name": FISH[pick % FISH.size()], "money": 0}
	if r < 0.72:
		return {"kind": "junk", "name": JUNK[pick % JUNK.size()], "money": 0}
	if r < 0.84:
		return {"kind": "bike", "name": "an old bike (classic Rotterdam)", "money": 10}
	if r < 0.92:
		return {"kind": "wallet", "name": "a soggy wallet", "money": 5 + pick % 21}
	if r < 0.97:
		return {"kind": "safe", "name": "a rusty little safe", "money": 40 + (pick * 7) % 111}
	return {"kind": "phone", "name": "a waterproof phone", "money": 0}
