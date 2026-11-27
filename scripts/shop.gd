class_name Shop
extends RefCounted
## Studio upgrades. Bought with money from sessions; most change gameplay, some show up in the room.

const ITEMS := [
	{"id": "foam", "name": "Acoustic foam", "price": 90,
		"desc": "Panels all over the walls. Noise rises 40% slower. The neighbours thank you."},
	{"id": "mic_pro", "name": "Condenser mic", "price": 140,
		"desc": "A real studio mic. Every take scores +6."},
	{"id": "monitors", "name": "Studio monitors", "price": 100,
		"desc": "Hear what you're doing. Every take scores +3."},
	{"id": "kit_dusty", "name": "Dusty drum kit", "price": 70,
		"desc": "Vinyl crackle drums. +8 with boom bap rappers when selected."},
	{"id": "kit_drill", "name": "Drill drum kit", "price": 110,
		"desc": "Crisp hats, sliding 808. +8 with drill and rage rappers when selected."},
	{"id": "inst_pluck", "name": "Pluck synth", "price": 40,
		"desc": "Bright plucky lead for the piano roll."},
	{"id": "inst_bell", "name": "Bell synth", "price": 50,
		"desc": "Cold bell melodies. Drill rappers love it."},
	{"id": "inst_pad", "name": "Pad synth", "price": 60,
		"desc": "Dreamy, sad pads. Emo rappers love it."},
	{"id": "neon", "name": "Neon sign", "price": 120,
		"desc": "Your name in lights. +1 Street Cred every session."},
]


static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it.id == id:
			return it
	return {}


static func kits_owned(upgrades: Array) -> Array:
	var out := ["default"]
	if "kit_dusty" in upgrades:
		out.append("dusty")
	if "kit_drill" in upgrades:
		out.append("drill")
	return out


static func instruments_owned(upgrades: Array) -> Array:
	var out := ["keys"]
	for id in ["pluck", "bell", "pad"]:
		if "inst_" + id in upgrades:
			out.append(id)
	return out
