class_name Furniture
extends RefCounted
## Furniture for the bedroom studio (Huisraad app). One item per slot; owned items stay in storage
## and can be swapped. Room stats: VIBE (+session pay, patience), ACOUSTICS (slower noise),
## COMFORT (the night lasts longer).

const SLOTS := {
	"seat": "Seat (left wall)",
	"rug": "Rug",
	"table": "Coffee table",
	"front": "Front wall (where the boxes are)",
	"wall": "Wall art",
	"lamp": "Lamp",
}

const ITEMS := [
	{"id": "beanbag", "slot": "seat", "name": "Beanbag", "price": 45, "vibe": 3, "acoustics": 1, "comfort": 3,
		"desc": "Cheap and comfy. Rappers flop into it between takes."},
	{"id": "lounge_chair", "slot": "seat", "name": "Lounge chair", "price": 120, "vibe": 5, "acoustics": 1, "comfort": 5,
		"desc": "A proper chair. Your clients stop sitting on your bed."},
	{"id": "sofa", "slot": "seat", "name": "Studio sofa", "price": 260, "vibe": 8, "acoustics": 3, "comfort": 8,
		"desc": "The classic studio couch. Entourages fit on it. Absorbs a lot of sound."},
	{"id": "rug_round", "slot": "rug", "name": "Round shag rug", "price": 35, "vibe": 2, "acoustics": 3, "comfort": 1,
		"desc": "Soft and thick. Footsteps and bass stop bouncing around."},
	{"id": "rug_persian", "slot": "rug", "name": "Persian-style rug", "price": 90, "vibe": 4, "acoustics": 4, "comfort": 1,
		"desc": "Every real studio has one. Nobody knows why. It just works."},
	{"id": "coffee_table", "slot": "table", "name": "Coffee table", "price": 30, "vibe": 1, "acoustics": 0, "comfort": 1,
		"desc": "Somewhere to put the energy drinks."},
	{"id": "glass_table", "slot": "table", "name": "Glass table", "price": 75, "vibe": 3, "acoustics": 0, "comfort": 1,
		"desc": "Looks expensive on camera."},
	{"id": "mini_fridge", "slot": "front", "name": "Mini fridge", "price": 60, "vibe": 3, "acoustics": 0, "comfort": 2,
		"desc": "Cold drinks for your rappers: unlocks 'Offer a drink' (+1 take)."},
	{"id": "vinyl_shelf", "slot": "front", "name": "Record shelf", "price": 110, "vibe": 6, "acoustics": 3, "comfort": 0,
		"desc": "Wall of vinyl. Diffuses sound and impresses the oldheads."},
	{"id": "tv_console", "slot": "front", "name": "TV + console", "price": 180, "vibe": 7, "acoustics": 0, "comfort": 4,
		"desc": "Rappers play FIFA while you fix the mix. Everybody's happier."},
	{"id": "poster", "slot": "wall", "name": "Framed poster", "price": 25, "vibe": 2, "acoustics": 0, "comfort": 0,
		"desc": "A moody print of the bridge at night."},
	{"id": "led_panel", "slot": "wall", "name": "LED wall panel", "price": 95, "vibe": 5, "acoustics": 0, "comfort": 0,
		"desc": "Slowly shifting colours. Instant music video background."},
	{"id": "diffuser", "slot": "wall", "name": "Wooden diffuser", "price": 140, "vibe": 3, "acoustics": 6, "comfort": 0,
		"desc": "A real acoustic diffuser. Your mixes stop lying to you."},
	{"id": "lamp_warm", "slot": "lamp", "name": "Warm floor lamp", "price": 40, "vibe": 2, "acoustics": 0, "comfort": 2,
		"desc": "Cosy amber light. Less interrogation room, more studio."},
]


static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it.id == id:
			return it
	return {}


static func in_slot(slot: String) -> Array:
	return ITEMS.filter(func(it): return it.slot == slot)


## Sum of the placed items.
static func stats(placed: Dictionary) -> Dictionary:
	var s := {"vibe": 0, "acoustics": 0, "comfort": 0}
	for slot in placed:
		var it := item(str(placed[slot]))
		if it.is_empty():
			continue
		for k in s:
			s[k] += int(it[k])
	return s


## Session pay multiplier from VIBE (max +30%).
static func pay_mult(st: Dictionary) -> float:
	return 1.0 + minf(float(st.vibe), 30.0) / 100.0


## Noise rise multiplier from ACOUSTICS (max -40%).
static func noise_mult(st: Dictionary) -> float:
	return 1.0 - minf(float(st.acoustics) * 0.025, 0.4)


## Extra minutes before you pass out from COMFORT (max +45).
static func comfort_minutes(st: Dictionary) -> int:
	return mini(int(st.comfort) * 3, 45)
