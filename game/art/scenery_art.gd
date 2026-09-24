class_name SceneryArt extends RefCounted
## Procedural placeholder scenery. Every builder returns a Node2D with its origin at the base.
## Temporary: see assets/ASSET_MANIFEST.md for intended replacements.

const SHADER := preload("res://game/art/scenery.gdshader")

static func material(haze: float, sway: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("haze", haze)
	m.set_shader_parameter("sway", sway)
	return m

## sway_h > 0: vertices sway proportionally to their height above y=0.
static func poly(points: PackedVector2Array, color: Color, mat: Material, sway_h := 0.0) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.material = mat
	var uv := PackedVector2Array()
	for v in points:
		uv.append(Vector2(0.0, clampf(1.0 + v.y / sway_h, 0.0, 1.0) if sway_h > 0.0 else 1.0))
	p.uv = uv
	return p

static func blob(center: Vector2, r: float, rng: RandomNumberGenerator, pts := 12, rough := 0.18) -> PackedVector2Array:
	var out := PackedVector2Array()
	var phase := rng.randf() * TAU
	for i in pts:
		var a := phase + TAU * i / pts
		out.append(center + Vector2.from_angle(a) * r * (1.0 + rng.randf_range(-rough, rough)))
	return out

static func offset(points: PackedVector2Array, by: Vector2, scale := 1.0, pivot := Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in points:
		out.append(pivot + (v - pivot) * scale + by)
	return out

# --- Trees -------------------------------------------------------------------

static func conifer(rng: RandomNumberGenerator, h: float, dark: Color, light: Color, trunk: Color, mat: Material) -> Node2D:
	var n := Node2D.new()
	var w := h * rng.randf_range(0.17, 0.24)
	var tw := maxf(h * 0.025, 1.5)
	n.add_child(poly(PackedVector2Array([Vector2(-tw, 4), Vector2(tw, 4), Vector2(tw * 0.25, -h), Vector2(-tw * 0.25, -h)]), trunk, mat))
	var base := -h * rng.randf_range(0.12, 0.3)
	n.add_child(poly(_fir_outline(rng, base, h, w), dark, mat, h))
	if light != dark:
		var hl := _fir_outline(rng, base - h * 0.05, h * 0.95, w * 0.75)
		n.add_child(poly(offset(hl, Vector2(w * 0.18, 0)), light, mat, h))
	return n

static func _fir_outline(rng: RandomNumberGenerator, base_y: float, h: float, w: float) -> PackedVector2Array:
	var tiers := clampi(int(h / 60.0), 5, 16)
	var th := (h + base_y) / tiers
	var right := PackedVector2Array()
	var left := PackedVector2Array()
	for i in tiers:
		var t := float(i) / tiers
		var y := lerpf(base_y, -h, t)
		var rr := w * pow(1.0 - t, 0.9) * rng.randf_range(0.8, 1.12)
		var rl := w * pow(1.0 - t, 0.9) * rng.randf_range(0.8, 1.12)
		right.append(Vector2(rr, y + th * 0.3))
		right.append(Vector2(rr * 0.42, y - th * 0.45))
		left.append(Vector2(-rl, y + th * 0.3))
		left.append(Vector2(-rl * 0.42, y - th * 0.45))
	var out := PackedVector2Array([Vector2(0, base_y)])
	out.append_array(right)
	out.append(Vector2(0, -h * 1.03))
	left.reverse()
	out.append_array(left)
	return out

static func broadleaf(rng: RandomNumberGenerator, h: float, dark: Color, light: Color, bark: Color, mat: Material) -> Node2D:
	var n := Node2D.new()
	var tw := maxf(h * 0.022, 1.5)
	var lean := rng.randf_range(-0.06, 0.06) * h
	n.add_child(poly(PackedVector2Array([Vector2(-tw, 4), Vector2(tw, 4), Vector2(lean + tw * 0.4, -h * 0.8), Vector2(lean - tw * 0.4, -h * 0.8)]), bark, mat, h))
	if bark == Palette.ASPEN_BARK and h > 150.0: # aspen eye marks
		for i in rng.randi_range(2, 4):
			var y := -rng.randf_range(0.1, 0.6) * h
			var x := lean * (-y / (h * 0.8))
			n.add_child(poly(PackedVector2Array([Vector2(x - tw * 0.7, y), Vector2(x, y - tw * 0.5), Vector2(x + tw * 0.7, y), Vector2(x, y + tw * 0.4)]), Palette.BARK_DARK, mat, h))
	var w := h * rng.randf_range(0.24, 0.32)
	var blobs := rng.randi_range(5, 8)
	var centers := []
	for i in blobs:
		var c := Vector2(lean + rng.randf_range(-w * 0.6, w * 0.6), -h * rng.randf_range(0.55, 0.92))
		var r := w * rng.randf_range(0.32, 0.5)
		centers.append([c, r])
		n.add_child(poly(blob(c, r, rng), dark, mat, h))
	if light != dark:
		for cr in centers:
			n.add_child(poly(blob(cr[0] + Vector2(cr[1] * 0.2, -cr[1] * 0.25), cr[1] * 0.6, rng), light, mat, h))
	return n

static func bush(rng: RandomNumberGenerator, w: float, color: Color, mat: Material) -> Node2D:
	var n := Node2D.new()
	for i in rng.randi_range(3, 5):
		var r := w * rng.randf_range(0.25, 0.4)
		n.add_child(poly(blob(Vector2(rng.randf_range(-w * 0.4, w * 0.4), -r * 0.7), r, rng), color, mat, w * 0.8))
	return n

static func rock(rng: RandomNumberGenerator, w: float, mat: Material) -> Node2D:
	var n := Node2D.new()
	var h := w * rng.randf_range(0.45, 0.7)
	var pts := PackedVector2Array([Vector2(-w * 0.5, 6), Vector2(w * 0.5, 6)])
	for i in 5:
		var a := PI * (i + 0.5) / 5.0
		pts.append(Vector2(cos(a) * w * 0.5 * rng.randf_range(0.8, 1.05), -sin(a) * h * rng.randf_range(0.75, 1.1)))
	n.add_child(poly(pts, Palette.ROCK, mat))
	n.add_child(poly(PackedVector2Array([Vector2(-w * 0.3, -h * 0.75), Vector2(w * 0.15, -h * 0.95), Vector2(w * 0.35, -h * 0.6), Vector2(-w * 0.1, -h * 0.55)]), Palette.ROCK_LIGHT, mat))
	return n

static func fern(rng: RandomNumberGenerator, h: float, color: Color, mat: Material) -> Node2D:
	var n := Node2D.new()
	var fronds := rng.randi_range(5, 8)
	for i in fronds:
		var a := lerpf(-2.6, -0.55, float(i) / (fronds - 1)) + rng.randf_range(-0.1, 0.1)
		var fl := h * rng.randf_range(0.7, 1.1)
		var tip := Vector2.from_angle(a) * fl
		var mid := tip * 0.5 + Vector2(0, -fl * 0.15)
		var side := tip.orthogonal().normalized() * fl * 0.07
		n.add_child(poly(PackedVector2Array([Vector2.ZERO, mid + side, tip, mid - side]), color, mat, h))
	return n

## Many grass blades in one polygon node (cheap). xs are local x positions.
static func grass(rng: RandomNumberGenerator, xs: PackedFloat32Array, ys: PackedFloat32Array, h: float, color: Color, mat: Material) -> Polygon2D:
	var pts := PackedVector2Array()
	var uv := PackedVector2Array()
	var polys := []
	for i in xs.size():
		for b in 3:
			var x := xs[i] + rng.randf_range(-6, 6)
			var bh := h * rng.randf_range(0.5, 1.0)
			var k := pts.size()
			pts.append_array([Vector2(x - 2.5, ys[i] + 4), Vector2(x + 2.5, ys[i] + 4), Vector2(x + rng.randf_range(-8, 8), ys[i] - bh)])
			uv.append_array([Vector2(0, 1), Vector2(0, 1), Vector2(0, 0)])
			polys.append(PackedInt32Array([k, k + 1, k + 2]))
	var p := Polygon2D.new()
	p.polygon = pts
	p.uv = uv
	p.polygons = polys
	p.color = color
	p.material = mat
	return p
