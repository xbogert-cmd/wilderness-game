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
		"wolf_pelt", "wolf_fur", "bear_hide", "bear_fur":
			var pts := PackedVector2Array([Vector2(0.14, 0.2), Vector2(0.32, 0.1), Vector2(0.5, 0.16), Vector2(0.7, 0.08), Vector2(0.88, 0.22),
				Vector2(0.8, 0.5), Vector2(0.92, 0.86), Vector2(0.66, 0.78), Vector2(0.5, 0.94), Vector2(0.3, 0.8), Vector2(0.08, 0.88), Vector2(0.2, 0.5)])
			for i in pts.size():
				pts[i] *= Vector2(w, h)
			ci.draw_colored_polygon(pts, a.call(c))
			for i in 9: # fur texture
				var fp := Vector2(w * (0.25 + 0.5 * fmod(i * 0.37, 1.0)), h * (0.22 + 0.6 * fmod(i * 0.61, 1.0)))
				ci.draw_line(fp, fp + Vector2(u * 0.06, u * 0.1), a.call(c.lightened(0.18)), 1.5)
			if d.id.ends_with("pelt") or d.id == "bear_hide":
				ci.draw_colored_polygon(PackedVector2Array([pts[1].lerp(pts[7], 0.3), pts[3].lerp(pts[9], 0.3), pts[5].lerp(pts[10], 0.4)]), a.call(Color("a86a5c")))
		"yarrow", "water_hemlock", "mint", "willow_bark", "rose_hips", "arnica":
			if d.id == "willow_bark": # curls of red-brown bark
				for i in 3:
					ci.draw_arc(Vector2(w * (0.3 + i * 0.2), h * 0.5), u * 0.14, PI * 0.2, PI * 1.6, 8, a.call(c.darkened(0.1 * i)), u * 0.08)
			else: # a sprig: stem, leaves, and the flower or fruit in the item's colour
				ci.draw_line(Vector2(w * 0.5, h * 0.92), Vector2(w * 0.5, h * 0.3), a.call(Color("5d6e3a")), u * 0.06)
				for k in 3:
					var y := h * (0.75 - k * 0.14)
					ci.draw_line(Vector2(w * 0.5, y), Vector2(w * (0.28 if k % 2 else 0.72), y - h * 0.06), a.call(Color("6f8a45")), u * 0.06)
				for k in (5 if d.id in ["yarrow", "water_hemlock"] else 3):
					ci.draw_circle(Vector2(w * (0.32 + k * 0.09), h * (0.24 if d.id != "rose_hips" else 0.26)), u * (0.06 if d.id != "rose_hips" else 0.1), a.call(c))
				if d.id == "water_hemlock": # purple streaks, as a warning
					ci.draw_line(Vector2(w * 0.5, h * 0.8), Vector2(w * 0.5, h * 0.6), a.call(Color("6a3a5a")), u * 0.08)
		"snowshoes":
			for k in 2:
				var cx := w * (0.3 + k * 0.4)
				ci.draw_arc(Vector2(cx, h * 0.5), u * 0.2, 0.0, TAU, 16, a.call(c), u * 0.06)
				for j in 3:
					ci.draw_line(Vector2(cx - u * 0.14, h * (0.4 + j * 0.1)), Vector2(cx + u * 0.14, h * (0.4 + j * 0.1)), a.call(Color("c8b89a")), 1.0)
		"stew":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.12, h * 0.45), Vector2(w * 0.88, h * 0.45), Vector2(w * 0.72, h * 0.85), Vector2(w * 0.28, h * 0.85)]), a.call(Color("7a6a5a")))
			ci.draw_rect(Rect2(w * 0.16, h * 0.4, w * 0.68, h * 0.08), a.call(c))
			for k in 3:
				ci.draw_arc(Vector2(w * (0.35 + k * 0.15), h * 0.28), u * 0.05, PI, TAU, 6, a.call(Color(1, 1, 1, 0.5)), 1.5)
		"mint_tea", "willow_tea":
			ci.draw_rect(Rect2(w * 0.25, h * 0.35, w * 0.45, h * 0.5), a.call(Color("c8c4b8")))
			ci.draw_rect(Rect2(w * 0.28, h * 0.38, w * 0.39, h * 0.1), a.call(c))
			ci.draw_arc(Vector2(w * 0.72, h * 0.58), u * 0.1, -PI * 0.5, PI * 0.5, 6, a.call(Color("c8c4b8")), 2.0)
		"torch":
			ci.draw_line(Vector2(w * 0.5, h * 0.96), Vector2(w * 0.5, h * 0.3), a.call(c), u * 0.2)
			ci.draw_rect(Rect2(w * 0.3, h * 0.26, w * 0.4, h * 0.12), a.call(Color("5a4a3a")))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.24, h * 0.28), Vector2(w * 0.5, h * 0.02), Vector2(w * 0.76, h * 0.28)]), a.call(Color("f0a040")))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.38, h * 0.27), Vector2(w * 0.5, h * 0.1), Vector2(w * 0.62, h * 0.27)]), a.call(Color("fde28a")))
		"spear":
			ci.draw_line(Vector2(w * 0.5, h * 0.98), Vector2(w * 0.5, h * 0.12), a.call(c), u * 0.16)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.4, h * 0.14), Vector2(w * 0.5, h * 0.01), Vector2(w * 0.6, h * 0.14)]), a.call(c.darkened(0.45)))
			ci.draw_line(Vector2(w * 0.5, h * 0.12), Vector2(w * 0.5, h * 0.18), a.call(DARK), u * 0.2)
		"snare":
			ci.draw_line(Vector2(w * 0.2, h * 0.9), Vector2(w * 0.3, h * 0.1), a.call(HAFT), u * 0.08)
			ci.draw_arc(Vector2(w * 0.58, h * 0.56), u * 0.24, 0.0, TAU, 16, a.call(c), 2.0)
			ci.draw_line(Vector2(w * 0.3, h * 0.12), Vector2(w * 0.58, h * 0.32), a.call(c), 2.0)
		"rabbit_raw", "rabbit_cooked":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.1, h * 0.6), Vector2(w * 0.3, h * 0.3), Vector2(w * 0.72, h * 0.28),
				Vector2(w * 0.9, h * 0.5), Vector2(w * 0.74, h * 0.76), Vector2(w * 0.24, h * 0.8)]), a.call(c))
			for x in [0.3, 0.7]: # legs
				ci.draw_line(Vector2(w * x, h * 0.72), Vector2(w * (x + 0.12), h * 0.92), a.call(c.darkened(0.2)), u * 0.1)
			if d.id == "rabbit_cooked":
				for i in 3:
					ci.draw_line(Vector2(w * (0.36 + i * 0.14), h * 0.34), Vector2(w * (0.3 + i * 0.14), h * 0.7), a.call(Color(0.2, 0.12, 0.06, 0.7)), 2.5)
		"wolf_hat":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.2, h * 0.7), Vector2(w * 0.26, h * 0.3), Vector2(w * 0.5, h * 0.12), Vector2(w * 0.74, h * 0.3), Vector2(w * 0.8, h * 0.7)]), a.call(c))
			ci.draw_rect(Rect2(w * 0.14, h * 0.62, w * 0.72, h * 0.22), a.call(c.lightened(0.15)))
			for x in [0.16, 0.76]: # ear flaps
				ci.draw_rect(Rect2(w * x, h * 0.7, w * 0.08, h * 0.26), a.call(c.darkened(0.1)))
		"wolf_mittens":
			for k in 2:
				var ox := w * (0.08 + k * 0.46)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(ox, h * 0.9), Vector2(ox, h * 0.34), Vector2(ox + w * 0.2, h * 0.14), Vector2(ox + w * 0.36, h * 0.34), Vector2(ox + w * 0.36, h * 0.9)]), a.call(c.darkened(0.08 * k)))
				ci.draw_circle(Vector2(ox + w * (0.02 if k == 0 else 0.34), h * 0.5), u * 0.1, a.call(c.darkened(0.15)))
				ci.draw_rect(Rect2(ox - 1, h * 0.8, w * 0.36 + 2, h * 0.14), a.call(c.lightened(0.2)))
		"buckskin_leggings", "wolf_leggings":
			for k in 2:
				var ox := w * (0.18 + k * 0.34)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(ox, h * 0.08), Vector2(ox + w * 0.3, h * 0.08), Vector2(ox + w * 0.28, h * 0.94), Vector2(ox + w * 0.04, h * 0.94)]), a.call(c.darkened(0.06 * k)))
			ci.draw_rect(Rect2(w * 0.16, h * 0.04, w * 0.68, h * 0.08), a.call(c.darkened(0.25)))
			if d.id == "buckskin_leggings":
				for y in [0.3, 0.5, 0.7, 0.9]: # fringe down the side
					ci.draw_line(Vector2(w * 0.12, h * y), Vector2(w * 0.18, h * y), a.call(c.darkened(0.2)), 1.2)
		"hide_coat", "bear_coat":
			var body := PackedVector2Array([Vector2(0.3, 0.08), Vector2(0.7, 0.08), Vector2(0.95, 0.22), Vector2(0.95, 0.6), Vector2(0.8, 0.6),
				Vector2(0.78, 0.95), Vector2(0.22, 0.95), Vector2(0.2, 0.6), Vector2(0.05, 0.6), Vector2(0.05, 0.22)])
			for i in body.size():
				body[i] *= Vector2(w, h)
			ci.draw_colored_polygon(body, a.call(c))
			ci.draw_line(Vector2(w * 0.5, h * 0.12), Vector2(w * 0.5, h * 0.95), a.call(c.darkened(0.3)), 1.5)
			if d.id == "bear_coat": # shaggy collar and cuffs
				ci.draw_rect(Rect2(w * 0.26, h * 0.06, w * 0.48, h * 0.1), a.call(c.lightened(0.2)))
				for x in [0.05, 0.8]:
					ci.draw_rect(Rect2(w * x, h * 0.52, w * 0.15, h * 0.08), a.call(c.lightened(0.2)))
			else:
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
