extends Control
## Procedurally painted background for the main menu: dark sky gradient, moonlight,
## distant trees, a house silhouette with a dim flickering window, and slow drifting mist.
## Entirely drawn in _draw() — zero external art.

var _time: float = 0.0
var _window_flicker: float = 1.0
var _mist_seeds: Array[Dictionary] = []

func _ready() -> void:
	set_process(true)
	# Wait a frame so size is non-zero.
	await get_tree().process_frame
	_init_mist()

func _init_mist() -> void:
	_mist_seeds.clear()
	var w: float = max(1.0, size.x)
	var h: float = max(1.0, size.y)
	for i in 14:
		_mist_seeds.append({
			"pos": Vector2(randf() * w, h * randf_range(0.4, 0.9)),
			"r": randf_range(60, 180),
			"a": randf_range(0.04, 0.09),
			"vx": randf_range(-6, 6),
		})

func _process(delta: float) -> void:
	_time += delta
	if randf() < 0.03:
		_window_flicker = randf_range(0.6, 1.0)
	for seed in _mist_seeds:
		seed.pos.x += seed.vx * delta
		if seed.pos.x > size.x + 200:
			seed.pos.x = -200
		elif seed.pos.x < -200:
			seed.pos.x = size.x + 200
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	# Sky gradient (dark navy -> black).
	var steps := 24
	for i in steps:
		var t := float(i) / steps
		var c := Color(0.04, 0.05, 0.08).lerp(Color(0.01, 0.01, 0.02), t)
		draw_rect(Rect2(0, i * h / steps, w, h / steps + 1), c)
	# Moon
	var moon_center := Vector2(w * 0.78, h * 0.22)
	draw_circle(moon_center, 36.0, Color(0.9, 0.88, 0.78, 0.35))
	draw_circle(moon_center, 24.0, Color(0.95, 0.93, 0.85, 0.85))
	# Horizon trees (jagged silhouette)
	var horizon_y := h * 0.62
	var tree_points: PackedVector2Array = []
	tree_points.append(Vector2(0, h))
	var x := 0.0
	while x <= w:
		var noise := sin(x * 0.013 + 1.3) * 10 + sin(x * 0.07) * 6 + cos(x * 0.03 + 2.1) * 14
		tree_points.append(Vector2(x, horizon_y + noise))
		x += 6.0
	tree_points.append(Vector2(w, h))
	draw_polygon(tree_points, PackedColorArray([Color(0.015, 0.02, 0.025)]))
	# House silhouette
	var house_cx := w * 0.5
	var house_base_y := h * 0.74
	var house_w := min(w * 0.28, 420.0)
	var house_h := house_w * 0.52
	var roof_h := house_w * 0.3
	var house_poly: PackedVector2Array = PackedVector2Array([
		Vector2(house_cx - house_w / 2, house_base_y),
		Vector2(house_cx - house_w / 2, house_base_y - house_h),
		Vector2(house_cx, house_base_y - house_h - roof_h),
		Vector2(house_cx + house_w / 2, house_base_y - house_h),
		Vector2(house_cx + house_w / 2, house_base_y),
	])
	draw_polygon(house_poly, PackedColorArray([Color(0.02, 0.015, 0.015)]))
	# Door
	draw_rect(Rect2(house_cx - 18, house_base_y - 70, 36, 70), Color(0.0, 0.0, 0.0))
	# Lit window
	var win_rect := Rect2(house_cx + house_w / 2 - 70, house_base_y - house_h + 20, 36, 36)
	draw_rect(win_rect, Color(0.1, 0.03, 0.02))
	var glow := Color(0.95, 0.5, 0.2, 0.55 * _window_flicker)
	draw_rect(win_rect.grow(2), glow)
	draw_rect(Rect2(win_rect.position + Vector2(4, 4), win_rect.size - Vector2(8, 8)), Color(1.0, 0.7, 0.4, 0.9 * _window_flicker))
	# A dark window (unlit)
	var win_rect2 := Rect2(house_cx - house_w / 2 + 34, house_base_y - house_h + 20, 36, 36)
	draw_rect(win_rect2, Color(0.03, 0.02, 0.02))
	# Mist blobs
	for seed in _mist_seeds:
		draw_circle(seed.pos, seed.r, Color(0.5, 0.5, 0.55, seed.a))
	# Vignette
	var v_steps := 10
	for i in v_steps:
		var alpha := 0.04 + 0.03 * i
		var inset := i * 20.0
		draw_rect(Rect2(inset, inset, w - inset * 2, h - inset * 2), Color(0, 0, 0, alpha), false, 2.0)
