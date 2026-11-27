class_name StreetTalk
extends RefCounted
## What people on the street say. Lines depend on their persona, whether they know you,
## the weather, the time, your reputation and how you treated them before.

const PERSONAS := {
	"student": {
		"hello": ["Hoi! Don't I know you from uni?", "Yo. I should be writing a paper right now. Anyway.", "Did you eat anything today? Me neither."],
		"again": ["You again! Still awake?", "Hé, producer! How's it going?"],
	},
	"nightshift": {
		"hello": ["Just finished my shift. Twelve hours. Kapot.", "Work at night, sleep in the day. You know that rhythm too, hè?", "Harbour, containers, all night. Nice work actually."],
		"again": ["Ah, the night owl again.", "You never sleep either, hè?"],
	},
	"business": {
		"hello": ["Sorry, in a hurry. Last train.", "I'm in marketing. Music too, kind of... playlists.", "Do you know where I can get a taxi around here?"],
		"again": ["Still no taxi.", "You again. Busy night?"],
	},
	"local": {
		"hello": ["Thirty years I live here. Used to be nothing. Now a casino.", "You hear that tram at night? Every time, that bell!", "Rotterdam, jongen. Niet lullen maar poetsen. Less talk, more work."],
		"again": ["There he is again!", "Music going well?"],
	},
	"smoker": {
		"hello": ["Just getting some fresh air. Well, fresh...", "The snackbar has the best kapsalon in Zuid. Serious.", "I should quit. Tomorrow. For real."],
		"again": ["Back for a kapsalon?", "You again! What are you making tonight?"],
	},
	"bouncer": {
		"hello": ["Name on the list? No? Joking. Go ahead.", "No trouble inside, understood?", "I've seen everything here. Everything."],
		"again": ["You again. Lucky at the tables?", "Don't gamble your whole studio away, hè."],
	},
}

const RAIN := ["Lekker weertje, hè? Not.", "I'm soaked, man.", "Left my umbrella at home. Of course."]
const LATE := ["It's late, hè. Or early.", "At this hour only the real night people are out."]
const FAMOUS := ["Wait... you're that producer from Kade 17!", "My little cousin has your track on repeat."]
const ANNOYED := ["Just leave me alone.", "You again? No thanks.", "I don't talk to people who throw cans."]
const BUMP := ["Hé, watch where you're going!", "Easy, man!", "Wow, sorry? No, YOU sorry!", "Do I know you?"]
const STARE := ["What are you looking at?", "Is there something on my face?", "Do I know you from somewhere?", "Yes? Can I help you?"]
const PRONE := ["You okay? Should I call 112?", "Uh... are you lying on the street?", "Jongen, get up. It's wet."]
const SNEAK := ["Uh... why are you sneaking behind me?", "I can see you, you know.", "Is this a prank? Where's the camera?"]
const HIT := ["Au! Doe normaal!", "Hé! Who threw that?!", "Seriously?! That hit me!"]
const FLYER_YES := ["Okay, I'll check it! Kade 17, right?", "Cool, I'll follow you.", "I know a guy who raps. I'll pass it on."]
const FLYER_NO := ["No thanks, my pockets are full of paper already.", "Another flyer... no.", "Put it with the rest."]
const FLYER_RAPPER := ["Wait, you have a studio? I rap too! I'll DM you!"]
const TRACK_LOVE := ["YOOO this is hard!", "What is this?! Send me that link!", "No man, this is actually good."]
const TRACK_OK := ["Yeah... it's okay.", "Hmm. Not bad. Bit busy maybe.", "It grows on you."]
const TRACK_BAD := ["Turn it off, please.", "Uh... is that you? Oei.", "Sounds like a ringtone from 2009."]
const TRACK_NONE := ["You didn't release anything yet? Make it first, then show it."]
const DAP := ["Respect.", "Yo!", "Altijd.", "Gang."]
const DAP_NO := ["Nah.", "I don't even know you."]
const SMOKER_CHAT := [
	["That tram drives me crazy.", "You live above the tram line. You're used to it."],
	["One more and then inside.", "You said that ten minutes ago."],
	["You heard that new track from Kade 17?", "The guy upstairs? Yeah, pretty good actually."],
	["The snackbar closes soon.", "Quick frikandel then."],
]


static func greet(n: NPC, game: GameState, weather: String, minutes: int) -> String:
	if int(n.memory.annoyed) >= 2:
		return _pick(ANNOYED)
	var persona: Dictionary = PERSONAS.get(str(n.data.get("persona", "local")), PERSONAS.local)
	var talks: int = n.memory.talks
	n.memory.talks = talks + 1
	if talks == 0 and game.reputation >= 15 and randf() < 0.5:
		return _pick(FAMOUS)
	if weather == "rain" and randf() < 0.35:
		return _pick(RAIN)
	if minutes > 27 * 60 and randf() < 0.3:
		return _pick(LATE)
	return _pick(persona.again if talks > 0 else persona.hello)


## Hand out a flyer. Returns [line, rep_gain, new_contact].
static func flyer(n: NPC, game: GameState) -> Array:
	if n.memory.flyer:
		n.memory.annoyed += 1
		return ["You already gave me a flyer.", 0, false]
	n.memory.flyer = true
	var chance := 0.35 + minf(game.reputation, 40) / 100.0
	if randf() < 0.08:
		return [_pick(FLYER_RAPPER), 1, true]
	if randf() < chance:
		return [_pick(FLYER_YES), 1, false]
	return [_pick(FLYER_NO), 0, false]


## Play your latest release from your phone speaker. Returns [line, mood, rep_gain].
static func play_track(n: NPC, game: GameState) -> Array:
	if game.tracks.is_empty():
		return [_pick(TRACK_NONE), "none", 0]
	var stars := int(game.tracks[game.tracks.size() - 1].stars)
	var first: bool = not n.memory.heard_track
	n.memory.heard_track = true
	if stars >= 4:
		return [_pick(TRACK_LOVE), "love", 1 if first else 0]
	if stars == 3:
		return [_pick(TRACK_OK), "ok", 0]
	return [_pick(TRACK_BAD), "bad", 0]


static func dap(n: NPC) -> String:
	if int(n.memory.annoyed) >= 2 or (int(n.memory.talks) == 0 and randf() < 0.25):
		return _pick(DAP_NO)
	n.memory.dapped = true
	return _pick(DAP)


## Rapper small talk in the studio, per style.
static func rapper_chat(r: Dictionary) -> String:
	match str(r.get("style", "")):
		"Boom bap":
			return _pick(["In '96 I made beats on a sampler from the kringloop.", "You young guys have everything on a laptop. We had vinyl.", "A beat has to breathe, you get me?"])
		"Emo / autotune":
			return _pick(["haven't slept in three nights but it's good for the music", "my ex is gonna hear this for sure", "can you make the lights more purple? for the vibe"])
		"Drill":
			return _pick(["My manager says I should smile more. No.", "I write everything in my notes. Twenty minutes a verse.", "Your neighbours always complain too, right?"])
		"Rage":
			return _pick(["I HAD SIX ENERGY DRINKS TODAY", "Can the bass go louder? Always louder.", "I want the windows to shake, bro!"])
	return "..."


static func _pick(a: Array) -> String:
	return str(a[randi() % a.size()])
