class_name ItemIcons
## Procedural item pictures, used by the pack grid and by items lying on the ground.
## Each is drawn inside the item's own unrotated box (w×h); rot turns it a quarter clockwise
## to match Backpack.cells(). Placeholder art like the rest (see ASSET_MANIFEST.md).

const STEEL := Color("9aa0a6")
const HAFT := Color("8a6a4a")
const DARK := Color("2a2622")

static func draw(ci: CanvasItem, s: ItemStack, pos: Vector2, cell: float, rot := false, alpha := 1.0) -> void:
	var d := s.def
	var box := Vector2(d.size()) * cell
	if rot:
		ci.draw_set_transform(pos + Vector2(box.y, 0), PI * 0.5)
	else:
		ci.draw_set_transform(pos)
	var a := func(c: Color) -> Color: return Color(c, c.a * alpha)
	var w := box.x
	var h := box.y
	var u := minf(w, h)
	var c: Color = d.color
	match d.id:
		"axe":
			ci.draw_line(Vector2(w * 0.5, h * 0.12), Vector2(w * 0.5, h * 0.94), a.call(HAFT), u * 0.16)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.4, h * 0.08), Vector2(w * 0.62, h * 0.08),
				Vector2(w * 0.9, h * 0.02), Vector2(w * 0.94, h * 0.3), Vector2(w * 0.62, h * 0.22), Vector2(w * 0.4, h * 0.22)]), a.call(STEEL))
			ci.draw_line(Vector2(w * 0.9, h * 0.03), Vector2(w * 0.93, h * 0.29), a.call(STEEL.lightened(0.4)), 2.0)
		"knife":
			ci.draw_rect(Rect2(w * 0.38, h * 0.58, w * 0.24, h * 0.36), a.call(Color("3a2a20")))
			ci.draw_rect(Rect2(w * 0.3, h * 0.55, w * 0.4, h * 0.05), a.call(STEEL.darkened(0.3)))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.38, h * 0.55), Vector2(w * 0.38, h * 0.18),
				Vector2(w * 0.5, h * 0.05), Vector2(w * 0.64, h * 0.3), Vector2(w * 0.62, h * 0.55)]), a.call(c.lightened(0.25)))
		"water_bottle":
			var body := Rect2(w * 0.24, h * 0.18, w * 0.52, h * 0.76)
			ci.draw_rect(body, a.call(c))
			ci.draw_rect(Rect2(w * 0.36, h * 0.06, w * 0.28, h * 0.12), a.call(DARK))
			ci.draw_rect(Rect2(body.position + Vector2(w * 0.06, h * 0.08), Vector2(w * 0.08, h * 0.5)), a.call(c.lightened(0.35)))
			var k := s.water / d.capacity if d.capacity > 0.0 else 0.0
			if k > 0.0:
				var wr := Rect2(body.position.x, body.end.y - body.size.y * k, body.size.x, body.size.y * k).grow(-3)
				ci.draw_rect(wr, a.call(Color("7fc3e0") if s.water_clean else Color("8a7a52")))
		"cook_pot":
			ci.draw_arc(Vector2(w * 0.5, h * 0.36), w * 0.34, PI, TAU, 16, a.call(STEEL.darkened(0.2)), 2.5)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.12, h * 0.4), Vector2(w * 0.88, h * 0.4),
				Vector2(w * 0.82, h * 0.9), Vector2(w * 0.18, h * 0.9)]), a.call(c))
			ci.draw_rect(Rect2(w * 0.08, h * 0.36, w * 0.84, h * 0.07), a.call(c.lightened(0.25)))
			if s.water > 0.0:
				ci.draw_rect(Rect2(w * 0.16, h * 0.46, w * 0.68, h * 0.05), a.call(Color("7fc3e0") if s.water_clean else Color("8a7a52")))
		"lighter":
			ci.draw_rect(Rect2(w * 0.3, h * 0.34, w * 0.4, h * 0.56), a.call(c))
			ci.draw_rect(Rect2(w * 0.3, h * 0.2, w * 0.4, h * 0.14), a.call(STEEL))
			ci.draw_circle(Vector2(w * 0.58, h * 0.16), u * 0.07, a.call(DARK))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.4, h * 0.19), Vector2(w * 0.45, h * 0.04), Vector2(w * 0.52, h * 0.19)]), a.call(Color("f0b050")))
		"sleeping_bag":
			var r := Rect2(w * 0.06, h * 0.18, w * 0.88, h * 0.64)
			ci.draw_rect(r, a.call(c))
			ci.draw_circle(Vector2(r.end.x, r.get_center().y), r.size.y * 0.5, a.call(c))
			ci.draw_arc(Vector2(r.end.x, r.get_center().y), r.size.y * 0.3, 0.0, TAU, 20, a.call(c.darkened(0.35)), 2.0)
			ci.draw_arc(Vector2(r.end.x, r.get_center().y), r.size.y * 0.12, 0.0, TAU, 12, a.call(c.darkened(0.35)), 2.0)
			for x in [0.3, 0.62]:
				ci.draw_rect(Rect2(w * x, r.position.y - 2, w * 0.05, r.size.y + 4), a.call(DARK))
		"bandage":
			ci.draw_rect(Rect2(w * 0.5, h * 0.62, w * 0.4, h * 0.14), a.call(c.darkened(0.08)))
			ci.draw_circle(Vector2(w * 0.45, h * 0.52), u * 0.3, a.call(c))
			ci.draw_arc(Vector2(w * 0.45, h * 0.52), u * 0.18, 0.0, TAU, 16, a.call(c.darkened(0.2)), 1.5)
			ci.draw_circle(Vector2(w * 0.45, h * 0.52), u * 0.07, a.call(c.darkened(0.3)))
		"splint":
			for x in [0.3, 0.56]:
				ci.draw_rect(Rect2(w * x, h * 0.06, w * 0.14, h * 0.88), a.call(c))
			for y in [0.25, 0.7]:
				ci.draw_rect(Rect2(w * 0.22, h * y, w * 0.56, h * 0.06), a.call(Color("e8e2d0")))
		"jerky":
			for i in 3:
				var y := h * (0.28 + i * 0.2)
				var pts := PackedVector2Array()
				for j in 6:
					pts.append(Vector2(w * (0.15 + j * 0.14), y + (sin(j * 1.7 + i) * u * 0.05)))
				ci.draw_polyline(pts, a.call(c.darkened(i * 0.12)), u * 0.14)
		"berries":
			ci.draw_line(Vector2(w * 0.5, h * 0.12), Vector2(w * 0.5, h * 0.4), a.call(HAFT), 2.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5, h * 0.2), Vector2(w * 0.8, h * 0.1), Vector2(w * 0.66, h * 0.3)]), a.call(Color("6f8a4a")))
			for p in [Vector2(0.38, 0.5), Vector2(0.6, 0.48), Vector2(0.48, 0.68), Vector2(0.3, 0.72), Vector2(0.68, 0.7)]:
				ci.draw_circle(Vector2(w * p.x, h * p.y), u * 0.12, a.call(c))
				ci.draw_circle(Vector2(w * p.x - u * 0.04, h * p.y - u * 0.04), u * 0.03, a.call(c.lightened(0.5)))
		"sticks":
			for i in mini(s.count, 4):
				var y := h * (0.3 + i * 0.14)
				ci.draw_line(Vector2(w * 0.06, y + h * 0.1), Vector2(w * 0.94, y - h * 0.08 + i * 2), a.call(c.darkened(0.1 * i)), u * 0.1)
			ci.draw_line(Vector2(w * 0.3, h * 0.4), Vector2(w * 0.38, h * 0.22), a.call(c), u * 0.06)
		"fishing_kit":
			ci.draw_rect(Rect2(w * 0.14, h * 0.24, w * 0.72, h * 0.56), a.call(c))
			ci.draw_rect(Rect2(w * 0.14, h * 0.24, w * 0.72, h * 0.56), a.call(c.darkened(0.4)), false, 1.5)
			ci.draw_arc(Vector2(w * 0.5, h * 0.58), u * 0.1, 0.0, PI, 8, a.call(DARK), 2.0)
			ci.draw_line(Vector2(w * 0.6, h * 0.58), Vector2(w * 0.6, h * 0.36), a.call(DARK), 2.0)
		"fishing_pole":
			ci.draw_line(Vector2(w * 0.5, h * 0.97), Vector2(w * 0.5, h * 0.03), a.call(c), u * 0.1)
			ci.draw_line(Vector2(w * 0.5, h * 0.97), Vector2(w * 0.5, h * 0.75), a.call(c.darkened(0.35)), u * 0.16)
			ci.draw_circle(Vector2(w * 0.66, h * 0.72), u * 0.12, a.call(STEEL))
			ci.draw_line(Vector2(w * 0.66, h * 0.72), Vector2(w * 0.54, h * 0.03), a.call(Color(1, 1, 1, 0.5)), 1.0)
		"cordage":
			for i in 3:
				ci.draw_arc(Vector2(w * 0.5, h * 0.5), u * (0.18 + i * 0.1), 0.0, TAU, 18, a.call(c.darkened(i * 0.15)), u * 0.08)
			ci.draw_line(Vector2(w * 0.72, h * 0.62), Vector2(w * 0.9, h * 0.88), a.call(c), u * 0.07)
		"bow":
			var pts := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				pts.append(Vector2(w * (0.3 + 0.38 * sin(t * PI)), h * (0.04 + 0.92 * t)))
			ci.draw_polyline(pts, a.call(c), u * 0.14)
			ci.draw_line(pts[0], pts[12], a.call(Color(0.9, 0.88, 0.8)), 1.2)
			ci.draw_rect(Rect2(w * 0.58, h * 0.45, w * 0.16, h * 0.1), a.call(DARK))
		"arrows":
			for i in mini(s.count, 3):
				var x := w * (0.3 + i * 0.2)
				ci.draw_line(Vector2(x, h * 0.1), Vector2(x, h * 0.92), a.call(c), 2.0)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 4, h * 0.12), Vector2(x, h * 0.03), Vector2(x + 4, h * 0.12)]), a.call(DARK))
				ci.draw_line(Vector2(x, h * 0.8), Vector2(x, h * 0.93), a.call(Color("d8d0c0")), 6.0)
		"venison_raw", "venison_cooked":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.08, h * 0.45), Vector2(w * 0.3, h * 0.2), Vector2(w * 0.75, h * 0.22),
				Vector2(w * 0.93, h * 0.5), Vector2(w * 0.7, h * 0.8), Vector2(w * 0.25, h * 0.78)]), a.call(c))
			ci.draw_arc(Vector2(w * 0.55, h * 0.5), u * 0.22, 0.0, TAU, 14, a.call(c.lightened(0.35) if d.id == "venison_raw" else c.darkened(0.3)), 2.0)
			if d.id == "venison_cooked":
				for i in 3:
					ci.draw_line(Vector2(w * (0.3 + i * 0.18), h * 0.28), Vector2(w * (0.22 + i * 0.18), h * 0.72), a.call(Color(0.2, 0.12, 0.06, 0.7)), 2.5)
		"whetstone":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.12, h * 0.55), Vector2(w * 0.3, h * 0.36), Vector2(w * 0.86, h * 0.4),
				Vector2(w * 0.9, h * 0.6), Vector2(w * 0.7, h * 0.72), Vector2(w * 0.2, h * 0.7)]), a.call(c))
			ci.draw_line(Vector2(w * 0.3, h * 0.42), Vector2(w * 0.84, h * 0.46), a.call(c.lightened(0.3)), 2.0)
			if s.uses_left < d.uses:
				var worn := 1.0 - float(s.uses_left) / d.uses
				ci.draw_line(Vector2(w * 0.4, h * 0.5), Vector2(w * (0.4 + 0.4 * worn), h * 0.52), a.call(c.darkened(0.3)), 3.0)
		"deer_call":
			ci.draw_rect(Rect2(w * 0.12, h * 0.4, w * 0.56, h * 0.22), a.call(c))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.66, h * 0.36), Vector2(w * 0.9, h * 0.28), Vector2(w * 0.9, h * 0.74), Vector2(w * 0.66, h * 0.66)]), a.call(c.darkened(0.2)))
			ci.draw_line(Vector2(w * 0.1, h * 0.51), Vector2(w * 0.04, h * 0.51), a.call(DARK), 3.0)
			ci.draw_line(Vector2(w * 0.3, h * 0.4), Vector2(w * 0.3, h * 0.62), a.call(DARK), 1.5)
		"vine":
			for k in mini(s.count, 3):
				var pts := PackedVector2Array()
				for i in 9:
					var t := i / 8.0
					pts.append(Vector2(w * (0.12 + 0.76 * t), h * (0.3 + k * 0.2) + sin(t * 9.0 + k) * h * 0.08))
				ci.draw_polyline(pts, a.call(c.lightened(0.1 * k)), 2.0)
				ci.draw_circle(pts[3], u * 0.06, a.call(Color("6f8a3e")))
		"vine_cord":
			ci.draw_arc(Vector2(w * 0.5, h * 0.5), u * 0.3, 0.0, TAU, 16, a.call(c), u * 0.1)
			ci.draw_arc(Vector2(w * 0.5, h * 0.5), u * 0.18, 0.0, TAU, 12, a.call(c.darkened(0.2)), u * 0.08)
			for i in 6: # the twist
				var ang := i * TAU / 6.0
				ci.draw_line(Vector2(w * 0.5, h * 0.5) + Vector2.from_angle(ang) * u * 0.24, Vector2(w * 0.5, h * 0.5) + Vector2.from_angle(ang + 0.5) * u * 0.34, a.call(c.darkened(0.35)), 1.0)
		"deer_hide", "hide":
			var pts := PackedVector2Array([Vector2(0.2, 0.12), Vector2(0.42, 0.2), Vector2(0.62, 0.1), Vector2(0.84, 0.2),
				Vector2(0.78, 0.5), Vector2(0.88, 0.84), Vector2(0.6, 0.8), Vector2(0.38, 0.9), Vector2(0.12, 0.82), Vector2(0.22, 0.5)])
			for i in pts.size():
				pts[i] *= Vector2(w, h)
			ci.draw_colored_polygon(pts, a.call(c))
			if d.id == "deer_hide":
				ci.draw_colored_polygon(PackedVector2Array([pts[0].lerp(pts[5], 0.25), pts[2].lerp(pts[7], 0.3), pts[4].lerp(pts[8], 0.35)]), a.call(Color("b06a5c")))
			else:
				ci.draw_polyline(pts + PackedVector2Array([pts[0]]), a.call(c.darkened(0.25)), 1.5)
		"hide_coat":
			var body := PackedVector2Array([Vector2(0.3, 0.08), Vector2(0.7, 0.08), Vector2(0.95, 0.22), Vector2(0.95, 0.6), Vector2(0.8, 0.6),
				Vector2(0.78, 0.95), Vector2(0.22, 0.95), Vector2(0.2, 0.6), Vector2(0.05, 0.6), Vector2(0.05, 0.22)])
			for i in body.size():
				body[i] *= Vector2(w, h)
			ci.draw_colored_polygon(body, a.call(c))
			ci.draw_line(Vector2(w * 0.5, h * 0.12), Vector2(w * 0.5, h * 0.95), a.call(c.darkened(0.3)), 1.5)
			for y in [0.62, 0.8, 0.93]: # fringe
				ci.draw_line(Vector2(w * 0.22, h * y), Vector2(w * 0.78, h * y), a.call(c.darkened(0.15)), 1.0)
		"trout_raw", "trout_cooked", "whitefish_raw", "whitefish_cooked":
			_fish(ci, a, w, h, c, d.id.begins_with("trout"), d.id.ends_with("cooked"))
		_:
			ci.draw_rect(Rect2(Vector2.ZERO, box).grow(-4), a.call(c))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

static func _fish(ci: CanvasItem, a: Callable, w: float, h: float, c: Color, trout: bool, cooked: bool) -> void:
	var body := PackedVector2Array()
	for i in 17:
		var t := i / 16.0 * TAU
		body.append(Vector2(w * (0.44 + 0.36 * cos(t)), h * (0.5 + 0.3 * sin(t))))
	ci.draw_colored_polygon(body, a.call(c))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.1, h * 0.5), Vector2(w * 0.01, h * 0.18),
		Vector2(w * 0.01, h * 0.82)]), a.call(c.darkened(0.15)))
	if cooked:
		for i in 3:
			var x := w * (0.3 + i * 0.16)
			ci.draw_line(Vector2(x, h * 0.28), Vector2(x - w * 0.06, h * 0.72), a.call(Color(0.2, 0.12, 0.06, 0.7)), 2.5)
		return
	if trout:
		ci.draw_line(Vector2(w * 0.16, h * 0.52), Vector2(w * 0.74, h * 0.52), a.call(Color("c87a70")), h * 0.1)
		for i in 7:
			ci.draw_circle(Vector2(w * (0.2 + i * 0.08), h * (0.34 + (i % 2) * 0.08)), 1.8, a.call(DARK))
	ci.draw_circle(Vector2(w * 0.7, h * 0.44), maxf(h * 0.06, 2.0), a.call(DARK))
	ci.draw_arc(Vector2(w * 0.64, h * 0.5), h * 0.2, -0.9, 0.9, 6, a.call(c.darkened(0.3)), 1.5)
