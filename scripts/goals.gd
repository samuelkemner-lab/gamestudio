class_name Goals
extends RefCounted
## Always three active goals (in catalogue order), so there's never an "and now what?" moment.
## Progress is read from the game state; completing one pays out and the next one slides in.

const LIST := [
	{"id": "first_track", "text": "Release your first track", "target": 1, "money": 30, "rep": 1, "xp": 30},
	{"id": "first_delivery", "text": "Do your first Zoef delivery", "target": 1, "money": 15, "rep": 0, "xp": 20},
	{"id": "furnish_1", "text": "Buy your first piece of furniture (Huisraad)", "target": 1, "money": 20, "rep": 0, "xp": 20},
	{"id": "buy_step", "text": "Buy an e-step (Ruilmarkt)", "target": 1, "money": 25, "rep": 1, "xp": 30},
	{"id": "hot_session", "text": "Answer a rapper's call and finish the session", "target": 1, "money": 30, "rep": 1, "xp": 40},
	{"id": "deliveries_5", "text": "Do 5 deliveries", "target": 5, "money": 40, "rep": 0, "xp": 50},
	{"id": "four_star", "text": "Make a 4-star track", "target": 1, "money": 40, "rep": 2, "xp": 50},
	{"id": "boxes_gone", "text": "Get rid of the moving boxes (front wall)", "target": 1, "money": 20, "rep": 1, "xp": 30},
	{"id": "full_song", "text": "Release a full song (arrange it in the Playlist)", "target": 1, "money": 50, "rep": 2, "xp": 60},
	{"id": "streak_3", "text": "Release a track 3 nights in a row", "target": 3, "money": 60, "rep": 2, "xp": 80},
	{"id": "vibe_15", "text": "Reach VIBE 15 in your studio", "target": 15, "money": 60, "rep": 2, "xp": 60},
	{"id": "rappers_3", "text": "Work with 3 different rappers", "target": 3, "money": 50, "rep": 3, "xp": 80},
	{"id": "streams_25k", "text": "Hit 25,000 total streams (gold plaque)", "target": 25000, "money": 100, "rep": 3, "xp": 120},
	{"id": "five_star", "text": "Make a 5-star track", "target": 1, "money": 100, "rep": 3, "xp": 150},
	{"id": "deliveries_20", "text": "Do 20 deliveries", "target": 20, "money": 100, "rep": 1, "xp": 120},
	{"id": "furnish_all", "text": "Fill every furniture slot", "target": 6, "money": 120, "rep": 3, "xp": 150},
	{"id": "streams_100k", "text": "Hit 100,000 total streams (platinum)", "target": 100000, "money": 250, "rep": 5, "xp": 300},
]


static func item(id: String) -> Dictionary:
	for g in LIST:
		if g.id == id:
			return g
	return {}


## Current progress towards a goal (clamped by the caller).
static func progress(id: String, gs: GameState) -> int:
	match id:
		"first_track":
			return gs.tracks.size()
		"first_delivery", "deliveries_5", "deliveries_20":
			return gs.deliveries
		"furnish_1":
			return gs.furniture.size()
		"buy_step":
			return 1 if gs.estep.owned else 0
		"hot_session":
			return int(gs.stats.get("hot_sessions", 0))
		"four_star":
			return 1 if gs.tracks.any(func(t): return int(t.stars) >= 4) else 0
		"five_star":
			return 1 if gs.tracks.any(func(t): return int(t.stars) >= 5) else 0
		"boxes_gone":
			return 1 if gs.placed.has("front") else 0
		"full_song":
			return 1 if gs.tracks.any(func(t): return t.get("song", false)) else 0
		"streak_3":
			return gs.streak
		"vibe_15":
			return int(gs.room_stats().vibe)
		"rappers_3":
			var seen := {}
			for t in gs.tracks:
				seen[str(t.rapper)] = true
			return seen.size()
		"streams_25k", "streams_100k":
			return gs.total_streams
		"furnish_all":
			return gs.placed.size()
	return 0


## The three goals you're working on now.
static func active(gs: GameState) -> Array:
	var out: Array = []
	for g in LIST:
		if not g.id in gs.goals_done:
			out.append(g)
			if out.size() == 3:
				break
	return out
