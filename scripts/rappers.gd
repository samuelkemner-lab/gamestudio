class_name Rappers
extends RefCounted
## The rappers that can book a session. Pure data: looks, voice, taste, patience, lines.
## wants[track] = [min_hits, max_hits] in the 16-step pattern.
## signature = steps that must be hit on a track (the groove they recognise).
## mix[track or "Keys"] = "loud" | "quiet" | "off" | "wet" (reverb) | "dry".
## feel = how it should groove: swing range, ghost notes, hi-hat rolls, moving 808, 808 glide.

const BIG_EARL := {
	"id": "big_earl",
	"name": "Big Earl",
	"style": "Boom bap",
	"model": "casual_male",
	"accessory": "bucket_hat",
	"recolor": {"LightBrown": Color("b8862c"), "LightBlue": Color("34466b"), "Red_Dark": Color("e8e2d0")},
	"accent": Color("e0a03a"),
	"voice_hz": 105.0,
	"patience": 4,
	"min_cred": 0,
	"pay": 60,
	"cred_gain": 1,
	"bpm": [84, 96],
	"wants": {"Kick": [2, 5], "Snare": [2, 3], "Hi-hat": [4, 9], "Clap": [0, 2], "808": [0, 0]},
	"signature": {"Snare": [4, 12]},
	"melody": {"notes": [0, 10], "scale": [], "instrument": "keys"},
	"kit": "dusty",
	"mix": {"Kick": "loud", "Snare": ["loud", "dry"], "808": "off"},
	"feel": {"swing": [0.15, 0.45], "ghost": {"Snare": 1}},
	"brief_easy": "Wants 84–96 BPM, snare on steps 5 and 13, no 808, kick and snare loud and dry (no reverb). Swing 15–45% and a soft ghost snare. Melody optional (keys). Dusty kit = bonus.",
	"brief_pro": "\"Real hip hop, young blood. Slow it down, let it swing, let that snare crack. Keep that 808 nonsense away from me.\"",
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
	"model": "punk_female",
	"accessory": "beanie",
	"recolor": {"Pink": Color("8b4dff")},
	"accent": Color("c084fc"),
	"voice_hz": 245.0,
	"patience": 3,
	"min_cred": 0,
	"pay": 80,
	"cred_gain": 1,
	"bpm": [125, 145],
	"wants": {"Kick": [2, 4], "Snare": [0, 2], "Hi-hat": [5, 12], "Clap": [1, 3], "808": [2, 4]},
	"signature": {"Clap": [12]},
	"melody": {"notes": [4, 14], "scale": "minor", "instrument": "pad"},
	"kit": "default",
	"mix": {"808": "loud", "Hi-hat": "quiet", "Keys": "wet"},
	"feel": {"rolls": {"Hi-hat": 1}, "bass_notes": 2},
	"brief_easy": "Wants 125–145 BPM, clap on step 13, soft hats with a roll, 2–4 loud 808s on 2+ different notes, and a sad melody (4+ notes, C minor) drenched in reverb. Pad sound = bonus.",
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
	"model": "hoodie_male",
	"accessory": "drill",
	"recolor": {"Purple": Color("17161e"), "LightBlue": Color("1f1e26")},
	"accent": Color("25d9f5"),
	"voice_hz": 120.0,
	"patience": 2,
	"min_cred": 8,
	"pay": 150,
	"cred_gain": 4,
	"bpm": [138, 146],
	"wants": {"Kick": [1, 3], "Snare": [1, 2], "Hi-hat": [9, 16], "Clap": [0, 2], "808": [3, 6]},
	"signature": {"Snare": [8]},
	"melody": {"notes": [3, 10], "scale": "minor", "instrument": "bell"},
	"kit": "drill",
	"mix": {"808": "loud", "Kick": "quiet"},
	"feel": {"rolls": {"Hi-hat": 2}, "bass_notes": 3, "glide": true},
	"brief_easy": "Wants 138–146 BPM, ONE snare on step 9, 9+ hats with 2+ rolls, 3–6 loud SLIDING 808s (glide on, 3+ notes), quiet kick, dark melody (3–10 notes, C minor). Bell + drill kit = bonus.",
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

const SPIKE := {
	"id": "spike",
	"name": "Spike",
	"style": "Rage",
	"model": "punk_male",
	"accessory": "punk",
	"recolor": {},
	"accent": Color("ff3d7f"),
	"voice_hz": 160.0,
	"patience": 3,
	"min_cred": 0,
	"min_rep": 12,
	"pay": 120,
	"cred_gain": 2,
	"bpm": [150, 170],
	"wants": {"Kick": [4, 8], "Snare": [1, 3], "Hi-hat": [6, 16], "Clap": [2, 4], "808": [3, 8]},
	"signature": {"Kick": [0], "Clap": [4, 12]},
	"melody": {"notes": [6, 16], "scale": [], "instrument": "pluck"},
	"kit": "drill",
	"mix": {"808": "loud", "Kick": "loud", "Clap": "loud"},
	"feel": {"rolls": {"Hi-hat": 2}, "bass_notes": 2, "glide": true},
	"brief_easy": "Wants 150–170 BPM, kick on step 1, claps on 5 and 13, lots of drums with hi-hat rolls, LOUD 808/kick/clap (but don't clip!), gliding 808 on 2+ notes, busy pluck melody (6+ notes).",
	"brief_pro": "\"I wanna break my speakers. FAST. LOUD. Make the plucks go crazy.\"",
	"dm": "yo i do rage music. need smth that makes the crowd go insane. u ready??",
	"lines": {
		"hello": "YOOOO this room is tiny. Let's make it shake!!",
		"wait": "Make it LOUDER. Louder than that.",
		"recording": "AAAAAH LET'S GO!",
		"great": "THE SPEAKERS ARE SCREAMING. I LOVE IT!",
		"ok": "Needs more energy bro, more chaos!",
		"bad": "Bro this is a lullaby. I'm falling asleep.",
		"angry": "BORING. I'm out.",
		"pay": "Take the money, you're insane, I love you!",
	},
}

const COP := {
	"id": "cop",
	"name": "Officer Dekker",
	"model": "swat",
	"accessory": "cop",
	"voice_hz": 140.0,
}


const INSPECTOR := {
	"id": "inspector",
	"name": "Controleur",
	"model": "business_male",
	"accessory": "inspector",
	"voice_hz": 120.0,
}


static func all() -> Array:
	return [BIG_EARL, LIL_TEAR, GHOST, SPIKE]


static func by_id(id: String) -> Dictionary:
	for r in all():
		if r.id == id:
			return r
	return {}
