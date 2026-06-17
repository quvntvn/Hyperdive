extends SceneTree
# Générateur de textures d'éclaboussures de sang (DEV TOOL, hors gameplay).
# Lance : godot --headless --script res://tools/gen_blood.gd
# Produit ~12 PNG transparents 512×512 dans assets/blood/ : blob central organique + gouttelettes
# + coulures, rouge foncé réaliste avec variation. Déterministe (seed par image) → reproductible.

const COUNT := 12
const SIZE := 512

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/blood")
	for i in COUNT:
		var rng := RandomNumberGenerator.new()
		rng.seed = 13_000 + i * 101
		var img := _make_splat(rng)
		var path := "res://assets/blood/splat_%02d.png" % (i + 1)
		img.save_png(path)
		print("saved ", path)
	quit()

func _make_splat(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := SIZE * 0.5 + rng.randf_range(-30.0, 30.0)
	var cy := SIZE * 0.5 + rng.randf_range(-30.0, 30.0)
	# Rouge foncé réaliste (≈ #5C0A0A … #7C1A14), variation par image.
	var base := Color(rng.randf_range(0.36, 0.49), rng.randf_range(0.04, 0.11), rng.randf_range(0.04, 0.09), 1.0)
	# Blob central irrégulier : rayon modulé par quelques harmoniques angulaires.
	var harmonics: Array = []
	for k in range(2, 7):
		harmonics.append({"k": k, "a": rng.randf_range(0.0, 0.20) / float(k - 1), "p": rng.randf_range(0.0, TAU)})
	var base_r := rng.randf_range(105.0, 160.0)
	var edge := rng.randf_range(8.0, 18.0)
	_stamp_blob(img, cx, cy, base_r, edge, harmonics, base, rng)
	# Gouttelettes projetées autour.
	var drops := rng.randi_range(12, 22)
	for j in drops:
		var ang := rng.randf_range(0.0, TAU)
		var dd := rng.randf_range(base_r * 0.6, base_r + 95.0)
		_stamp_circle(img, cx + cos(ang) * dd, cy + sin(ang) * dd, rng.randf_range(3.0, 22.0), rng.randf_range(2.0, 6.0), base, rng)
	# Coulures (drips) : chaîne de cercles décroissants partant du bord vers l'extérieur.
	var drips := rng.randi_range(2, 5)
	for d in drips:
		var ang2 := rng.randf_range(0.0, TAU)
		var px := cx + cos(ang2) * base_r * 0.9
		var py := cy + sin(ang2) * base_r * 0.9
		var rr := rng.randf_range(10.0, 20.0)
		var steps := rng.randi_range(4, 9)
		for s in steps:
			_stamp_circle(img, px, py, rr, 2.0, base, rng)
			px += cos(ang2) * rr * 1.1
			py += sin(ang2) * rr * 1.1
			rr *= rng.randf_range(0.72, 0.88)
			if rr < 2.0:
				break
	return img

func _stamp_blob(img: Image, cx: float, cy: float, base_r: float, edge: float, harmonics: Array, base: Color, rng: RandomNumberGenerator) -> void:
	var maxr := base_r * 1.3 + edge + 4.0
	var x0 := int(maxf(0.0, cx - maxr))
	var x1 := int(minf(float(SIZE - 1), cx + maxr))
	var y0 := int(maxf(0.0, cy - maxr))
	var y1 := int(minf(float(SIZE - 1), cy + maxr))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var dist := sqrt(dx * dx + dy * dy)
			var theta := atan2(dy, dx)
			var r := base_r
			for h in harmonics:
				r += base_r * h.a * sin(h.k * theta + h.p)
			var a := 0.0
			if dist <= r - edge:
				a = 1.0
			elif dist <= r:
				a = 1.0 - (dist - (r - edge)) / edge
			if a > 0.0:
				_put(img, x, y, base, a, rng)

func _stamp_circle(img: Image, cx: float, cy: float, radius: float, edge: float, base: Color, rng: RandomNumberGenerator) -> void:
	var maxr := radius + edge + 2.0
	var x0 := int(maxf(0.0, cx - maxr))
	var x1 := int(minf(float(SIZE - 1), cx + maxr))
	var y0 := int(maxf(0.0, cy - maxr))
	var y1 := int(minf(float(SIZE - 1), cy + maxr))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var dist := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if dist <= radius - edge:
				a = 1.0
			elif dist <= radius:
				a = 1.0 - (dist - (radius - edge)) / edge
			if a > 0.0:
				_put(img, x, y, base, a, rng)

# Compositing « over par max d'alpha » + micro-variation de teinte (réalisme, pas un aplat).
func _put(img: Image, x: int, y: int, base: Color, a: float, rng: RandomNumberGenerator) -> void:
	var cur := img.get_pixel(x, y)
	if a <= cur.a:
		return
	var v := rng.randf_range(-0.03, 0.03)
	var c := Color(clampf(base.r + v, 0.0, 1.0), clampf(base.g + v * 0.4, 0.0, 1.0), clampf(base.b + v * 0.4, 0.0, 1.0), a)
	img.set_pixel(x, y, c)
