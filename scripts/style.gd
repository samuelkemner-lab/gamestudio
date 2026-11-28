class_name Style
extends RefCounted
## How you look: clothes (one per slot) + a fresh haircut = DRIP.
## Drip gets you past the bouncer at De Kraan (4+), adds to your open mic score, gets you recognised
## on the street sooner and makes rappers pay a little more (+1% per point, max +10%).

const CLOTHES := [
	{"id": "bucket_hat", "slot": "head", "name": "Bucket hat", "price": 25, "drip": 2},
	{"id": "fitted_cap", "slot": "head", "name": "Fitted cap", "price": 35, "drip": 3},
	{"id": "black_hoodie", "slot": "top", "name": "Black hoodie", "price": 40, "drip": 2},
	{"id": "puffer", "slot": "top", "name": "Puffer jacket", "price": 120, "drip": 5},
	{"id": "silver_chain", "slot": "neck", "name": "Silver chain", "price": 60, "drip": 3},
	{"id": "iced_chain", "slot": "neck", "name": "Iced-out chain (it's fake)", "price": 95, "drip": 5},
	{"id": "white_kicks", "slot": "feet", "name": "Clean white sneakers", "price": 90, "drip": 4},
]
const CUTS := {"fade": {"name": "Fresh fade", "price": 15, "nights": 2, "drip": 2}, "lineup": {"name": "Line-up", "price": 8, "nights": 1, "drip": 1}}
const CLUB_MIN := 4


static func item(id: String) -> Dictionary:
	for c in CLOTHES:
		if c.id == id:
			return c
	return {}


static func fresh(gs: GameState) -> int:
	return int(gs.stats.get("fresh_drip", 0)) if gs.day <= int(gs.stats.get("fresh_until", -1)) else 0


static func drip(gs: GameState) -> int:
	var d := fresh(gs)
	for slot in gs.outfit:
		d += int(item(str(gs.outfit[slot])).get("drip", 0))
	return d


## Buy (and wear) a piece, or put on/take off one you own.
static func buy_or_wear(gs: GameState, id: String) -> bool:
	var it := item(id)
	if it.is_empty():
		return false
	if not id in gs.clothes:
		if not gs.spend(int(it.price)):
			return false
		gs.clothes.append(id)
		gs.outfit[it.slot] = id
	elif gs.outfit.get(it.slot, "") == id:
		gs.outfit.erase(it.slot)
	else:
		gs.outfit[it.slot] = id
	gs.changed.emit()
	gs.save()
	return true


static func haircut(gs: GameState, kind: String) -> bool:
	var c: Dictionary = CUTS.get(kind, {})
	if c.is_empty() or not gs.spend(int(c.price)):
		return false
	gs.stats.fresh_until = gs.day + int(c.nights) - 1
	gs.stats.fresh_drip = int(c.drip)
	gs.add(0, 1, 0)
	return true


static func pay_mult(gs: GameState) -> float:
	return 1.0 + minf(drip(gs), 10) / 100.0
