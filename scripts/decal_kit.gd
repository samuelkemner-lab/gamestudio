class_name DecalKit
extends RefCounted
## REALISM R2: procedural decal textures (the "used" layer): chewing gum, oil stains, cracks,
## manhole covers, storm drains, wall grime. Generated once at startup, all original work.

static var _cache := {}


static func tex(kind: String) -> ImageTexture:
	if _cache.has(kind):
		return _cache[kind]
	var img: Image
	match kind:
		"gum":
			img = _gum()
		"oil":
			img = _oil()
		"crack":
			img = _crack()
		"manhole":
			img = _manhole()
		"drain":
			img = _drain()
		"grime":
			img = _grime()
		"tag":
			img = _tag()
		_:
			img = _oil()
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[kind] = t
	return t


static func _blank(n: int) -> Image:
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Old chewing gum: flat grey-black dots spread over a patch of pavement.
static func _gum() -> Image:
	var n := 256
	var img := _blank(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 70:
		var c := Vector2(rng.randf_range(8, n - 8), rng.randf_range(8, n - 8))
		var r := rng.randf_range(1.5, 4.0)
		var shade := rng.randf_range(0.12, 0.35)
		for y in range(int(c.y - r - 1), int(c.y + r + 2)):
			for x in range(int(c.x - r - 1), int(c.x + r + 2)):
				var d := Vector2(x, y).distance_to(c)
				if d <= r:
					var a := clampf((r - d) * 1.5, 0.0, 0.85)
					img.set_pixel(x, y, Color(shade, shade, shade * 1.05, a))
	return img


## Oil / water stain: irregular soft dark blotch.
static func _oil() -> Image:
	var n := 128
	var img := _blank(n)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.045
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0, y - n / 2.0).length() / (n / 2.0)
			var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - d) * 1.6 - (1.0 - v) * 0.9, 0.0, 1.0) * 0.7
			img.set_pixel(x, y, Color(0.03, 0.03, 0.035, a))
	return img


## Hairline cracks: a few random walks.
static func _crack() -> Image:
	var n := 256
	var img := _blank(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for branch in 5:
		var p := Vector2(n / 2.0, n / 2.0) + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for step in 120:
			dir = dir.rotated(rng.randf_range(-0.5, 0.5)).normalized()
			p += dir * 1.5
			if p.x < 1 or p.y < 1 or p.x > n - 2 or p.y > n - 2:
				break
			var w := 1.0 if step < 80 else 0.6
			for oy in [-1, 0, 1]:
				for ox in [-1, 0, 1]:
					var a := (0.75 if ox == 0 and oy == 0 else 0.25) * w
					var q := Vector2i(int(p.x) + ox, int(p.y) + oy)
					var cur := img.get_pixelv(q)
					img.set_pixelv(q, Color(0.02, 0.02, 0.025, maxf(cur.a, a)))
	return img


## Cast-iron manhole cover with a grid pattern and a rusty rim.
static func _manhole() -> Image:
	var n := 128
	var img := _blank(n)
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(c)
			if d > 60:
				continue
			var col := Color(0.16, 0.16, 0.17, 1.0)
			if d > 54:
				col = Color(0.28, 0.2, 0.15, 1.0)  # rust rim
			elif (x / 6 + y / 6) % 2 == 0:
				col = Color(0.11, 0.11, 0.12, 1.0)
			if absf(d - 30.0) < 1.5:
				col = Color(0.08, 0.08, 0.09, 1.0)
			img.set_pixel(x, y, col)
	return img


## Storm drain grate at the kerb.
static func _drain() -> Image:
	var n := 128
	var img := _blank(n)
	for y in range(16, 112):
		for x in range(4, 124):
			var slot := (x % 10) < 6 and y > 24 and y < 104
			var col := Color(0.03, 0.03, 0.035, 1.0) if slot else Color(0.2, 0.19, 0.19, 1.0)
			img.set_pixel(x, y, col)
	return img


## Dirt at the bottom of walls / under windows: dark at one edge, streaky, fading out.
static func _grime() -> Image:
	var n := 128
	var img := _blank(n)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.08
	for y in n:
		for x in n:
			var streak := noise.get_noise_2d(x * 0.25, y * 2.0) * 0.5 + 0.5
			var a := pow(1.0 - float(y) / n, 1.6) * (0.35 + 0.5 * streak)
			img.set_pixel(x, y, Color(0.05, 0.045, 0.04, clampf(a, 0.0, 0.8)))
	return img


## Graffiti tag (original squiggles, no real names): thick spray strokes with a dark outline.
static func _tag() -> Image:
	var n := 256
	var img := _blank(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var col := Color.from_hsv(rng.randf(), 0.7, 0.85)
	for pass_i in 2:
		var p := Vector2(30, 140)
		var a := 0.0
		for i in 260:
			a += rng.randf_range(-0.35, 0.35) + sin(i * 0.12) * 0.2
			p += Vector2.from_angle(a) * 1.6 + Vector2(0.9, 0)
			p.y = clampf(p.y, 40, 216)
			if p.x > 230:
				break
			var r := 7.0 if pass_i == 0 else 4.5
			var c := Color(0.05, 0.05, 0.06, 0.9) if pass_i == 0 else col
			for oy in range(-int(r), int(r) + 1):
				for ox in range(-int(r), int(r) + 1):
					if ox * ox + oy * oy <= r * r:
						var q := Vector2i(int(p.x) + ox, int(p.y) + oy)
						if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
							img.set_pixelv(q, c)
	return img


## A Decal node facing down (ground). For walls, rotate it so -Y points into the wall.
static func make(kind: String, size: Vector3, modulate := Color.WHITE) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex(kind)
	d.size = size
	d.modulate = modulate
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.cull_mask = 1
	return d
