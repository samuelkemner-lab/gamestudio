class_name Rappers
extends RefCounted
## The rappers that can book a session. Pure data: looks, voice, taste, patience, lines.
## wants[track] = [min_hits, max_hits] in the 16-step pattern.
## signature = steps that must be hit on a track (the groove they recognise).
## mix[track] = "loud" | "quiet" | "off".

const BIG_EARL := {
	"id": "big_earl",
	"name": "Big Earl",
	"style": "Boom bap",
	"model": "character-male-b",
	"accessory": "bucket_hat",
	"accent": Color("e0a03a"),
	"voice_hz": 105.0,
	"patience": 4,
	"min_cred": 0,
	"pay": 60,
	"cred_gain": 1,
	"bpm": [84, 96],
	"wants": {"Kick": [2, 5], "Snare": [2, 3], "Hi-hat": [4, 9], "Clap": [0, 2], "808": [0, 0]},
	"signature": {"Snare": [4, 12]},
	"mix": {"Kick": "loud", "Snare": "loud", "808": "off"},
	"brief_easy": "Wants 84–96 BPM, snare on 2 and 4 (steps 5 and 13), no 808. Kick and snare up front.",
	"brief_pro": "\"Real hip hop, young blood. Slow it down, let that snare crack. Keep that 808 nonsense away from me.\"",
	"dm": "yo. heard u got a studio. i got 16 bars about the old days. no trap stuff pls",
	"lines": {
		"hello": "Bedroom studio, huh? ...Respect. Let's see what you got.",
		"wait": "Take your time. Real music takes time.",
		"recording": "Check one two... aight, run it.",
		"great": "NOW that's what I'm talking about! Golden era vibes!",
		"ok": "It's alright. Little more knock in that snare though.",
		"bad": "Nah nephew. What is this? Where's the BOOM? Where's the BAP?",
		"angry": "I'm too old for this. I'm out.",
		"pay": "Here's your money, kid. Keep that dusty sound alive.",
	},
}

const LIL_TEAR := {
	"id": "lil_tear",
	"name": "Lil Tear",
	"style": "Emo / autotune",
	"model": "character-female-f",
	"accessory": "beanie",
	"accent": Color("c084fc"),
	"voice_hz": 245.0,
	"patience": 3,
	"min_cred": 0,
	"pay": 80,
	"cred_gain": 1,
	"bpm": [125, 145],
	"wants": {"Kick": [2, 4], "Snare": [0, 2], "Hi-hat": [5, 12], "Clap": [1, 3], "808": [2, 4]},
	"signature": {"Clap": [12]},
	"mix": {"808": "loud", "Hi-hat": "quiet"},
	"brief_easy": "Wants 125–145 BPM, a clap on step 13, soft hi-hats, 2–4 big 808 hits. Keep the kick simple.",
	"brief_pro": "\"I want it to sound like crying in the rain but like... in a cool way? Big 808. Soft hats.\"",
	"dm": "heyyy i just got dumped and i need to make a song about it tonight. sad beat pls :(",
	"lines": {
		"hello": "omg your room is so aesthetic. okay okay let's make something sad",
		"wait": "can you make it sound more... purple?",
		"recording": "put the autotune on max. like MAX max.",
		"great": "WAIT. i'm literally crying. this is the one!!",
		"ok": "it's cute but it doesn't hurt enough yet",
		"bad": "this sounds like a happy birthday song. i hate it",
		"angry": "you don't get my vision. bye.",
		"pay": "sending you the bag. you're my producer now fr",
	},
}

const GHOST := {
	"id": "ghost",
	"name": "Ghost",
	"style": "Drill",
	"model": "character-male-f",
	"accessory": "drill",
	"accent": Color("25d9f5"),
	"voice_hz": 120.0,
	"patience": 2,
	"min_cred": 8,
	"pay": 150,
	"cred_gain": 4,
	"bpm": [138, 146],
	"wants": {"Kick": [1, 3], "Snare": [1, 2], "Hi-hat": [9, 16], "Clap": [0, 2], "808": [3, 6]},
	"signature": {"Snare": [8]},
	"mix": {"808": "loud", "Kick": "quiet"},
	"brief_easy": "Wants 138–146 BPM, ONE snare on step 9 (half-time), 9+ hi-hats, 3–6 loud 808s, quiet kick.",
	"brief_pro": "\"Make it cold. Sliding 808s, hats going crazy. Don't waste my time, bro.\"",
	"dm": "wagwan. heard ur beats are tapped. i got bars. dont waste my time",
	"lines": {
		"hello": "...So you're the producer? Hm. Let's see.",
		"wait": "Tick tock, bro.",
		"recording": "Run it.",
		"great": "Yo this is COLD. You're actually tapped, bro.",
		"ok": "It's mid. Make it harder.",
		"bad": "Bro what is this. You're wasting my time.",
		"angry": "I'm gone. Don't hit my line again.",
		"pay": "Here. You're on the team now.",
	},
}

const COP := {
	"id": "cop",
	"name": "Officer Dekker",
	"model": "character-male-c",
	"accessory": "",
	"voice_hz": 140.0,
}


static func all() -> Array:
	return [BIG_EARL, LIL_TEAR, GHOST]


static func by_id(id: String) -> Dictionary:
	for r in all():
		if r.id == id:
			return r
	return {}
