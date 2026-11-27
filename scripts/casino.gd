class_name Casino
extends RefCounted
## Lucky Stack casino: slots and roulette with in-game money only. Pure logic (testable).
## The house always wins in the long run: slots return ~87.5%, roulette ~97.3%.

const SYMBOLS := ["7", "BAR", "$", "♪", "★", "♥"]
const BETS := [10, 50, 100]
const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]


## Three reels. Three of a kind: 7 pays 20x, BAR 10x, others 6x. Two of a kind: 1.5x.
static func spin_slots(rng: RandomNumberGenerator, bet: int) -> Dictionary:
	var reels: Array = []
	for i in 3:
		reels.append(SYMBOLS[rng.randi() % SYMBOLS.size()])
	var mult := 0.0
	if reels[0] == reels[1] and reels[1] == reels[2]:
		mult = 20.0 if reels[0] == "7" else (10.0 if reels[0] == "BAR" else 6.0)
	elif reels[0] == reels[1] or reels[1] == reels[2] or reels[0] == reels[2]:
		mult = 1.5
	var win := int(round(bet * mult))
	return {"reels": reels, "win": win, "net": win - bet, "jackpot": mult >= 10.0}


## European wheel 0–36. choice: "red" / "black" (2x) or "green" (0 only, 36x).
static func spin_roulette(rng: RandomNumberGenerator, bet: int, choice: String) -> Dictionary:
	var n := rng.randi() % 37
	var colour := "green" if n == 0 else ("red" if n in RED else "black")
	var win := 0
	if colour == choice:
		win = bet * (36 if choice == "green" else 2)
	return {"number": n, "colour": colour, "win": win, "net": win - bet}
