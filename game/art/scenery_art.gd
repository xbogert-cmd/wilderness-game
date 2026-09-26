class_name SceneryArt extends RefCounted
## Procedural placeholder scenery. Every builder returns a Node2D with its origin at the base.
## Temporary: see assets/ASSET_MANIFEST.md for intended replacements.

const SHADER := preload("res://game/art/scenery.gdshader")
## What a polygon is, carried in UV.x so the one shader can treat it by season.
const PLAIN := 0.0
const GRASS := 0.5 ## goes straw-coloured in autumn
const LEAF := 1.0 ## deciduous: turns gold, then falls
const SNOW := 2.0 ## a snow cap: only visible under lying snow
const GROUND := 3.0 ## open ground: whitens under snow
const WATER := 4.0 ## open water: ices over when the creek freezes
## Polygon2D only passes per-vertex UVs to its shader when it has a texture, so every
## scenery polygon gets this plain white pixel (sway and the kind tag live in the UVs).
static var WHITE: ImageTexture:
	get:
		if WHITE == null:
			var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			WHITE = ImageTexture.create_from_image(img)
		return WHITE

static func material(haze: float, sway: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("haze", haze)
	m.set_shader_parameter("sway", sway)
	return m

## sway_h > 0: vertices sway proportionally to their height above y=0.
static func poly(points: PackedVector2Array, color: Color, mat: Material, sway_h := 0.0, kind := PLAIN) -> Polygon2D:
	return multi([points], color, mat, sway_h, kind)

## Several separate shapes in one node (one draw call), e.g. all the snow caps of a tree.
static func multi(shapes: Array, color: Color, mat: Material, sway_h := 0.0, kind := PLAIN) -> Polygon2D:
	var pts := PackedVector2Array()
	var uv := PackedVector2Array()
	var polys := []
	for shape: PackedVector2Array in shapes:
		var idx := PackedInt32Array()
		for v in shape:
			idx.append(pts.size())
			pts.append(v)
			uv.append(Vector2(kind, clampf(1.0 + v.y / sway_h, 0.0, 1.0) if sway_h > 0.0 else 1.0))
		polys.append(idx)
	var p := Polygon2D.new()
	p.polygon = pts
	if shapes.size() > 1:
		p.polygons = polys
	p.uv = uv
	p.texture = WHITE
	p.color = color
	p.material = mat
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
	var caps: Array[PackedVector2Array] = []
	n.add_child(poly(_fir_outline(rng, base, h, w, caps), dark, mat, h))
	if light != dark:
		var hl := _fir_outline(rng, base - h * 0.05, h * 0.95, w * 0.75)
		n.add_child(poly(offset(hl, Vector2(w * 0.18, 0)), light, mat, h))
	n.add_child(multi(caps, Color.WHITE, mat, h, SNOW))
	return n

## A mound of snow sitting on top of a round shape.
static func _cap(center: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		var a := PI + PI * i / 9.0
		out.append(center + Vector2(cos(a) * r * 0.78, sin(a) * r * 0.3 - r * 0.72))
	return out

## Snow caps, if asked for, lie along the upper edge of each tier (outer tip up to the notch).
static func _fir_outline(rng: RandomNumberGenerator, base_y: float, h: float, w: float, caps: Array[PackedVector2Array] = []) -> PackedVector2Array:
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
		var c := th * 0.12
		for side in [[rr, 1.0], [rl, -1.0]]:
			var outer := Vector2(side[0] * side[1], y + th * 0.3)
			var inner := Vector2(side[0] * 0.42 * side[1], y - th * 0.45)
			var mid := inner.lerp(outer, 0.5)
			# A thin drift on the bough's upper edge, thickest near the trunk, thinning to the tip.
			caps.append(PackedVector2Array([inner - Vector2(0, c * 0.6), mid - Vector2(0, c * 0.45), outer.lerp(inner, 0.08) - Vector2(0, c * 0.1),
				outer.lerp(inner, 0.12) + Vector2(0, c * 0.2), mid + Vector2(0, c * 0.4), inner + Vector2(0, c * 0.6)]))
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
		centers.append([Vector2(lean + rng.randf_range(-w * 0.6, w * 0.6), -h * rng.randf_range(0.55, 0.92)), w * rng.randf_range(0.32, 0.5)])
	var branches := [] # bare branches, seen once the leaves fall
	for cr in centers:
		var from := Vector2(lean * 0.6, -h * 0.5)
		var to: Vector2 = cr[0]
		var side := (to - from).orthogonal().normalized() * tw * 0.35
		branches.append(PackedVector2Array([from - side, from + side, to + side * 0.3, to - side * 0.3]))
	n.add_child(multi(branches, bark.darkened(0.25), mat, h))
	for cr in centers:
		n.add_child(poly(blob(cr[0], cr[1], rng), dark, mat, h, LEAF))
	if light != dark:
		for cr in centers:
			n.add_child(poly(blob(cr[0] + Vector2(cr[1] * 0.2, -cr[1] * 0.25), cr[1] * 0.6, rng), light, mat, h, LEAF))
	return n

static func bush(rng: RandomNumberGenerator, w: float, color: Color, mat: Material) -> Node2D:
	var n := Node2D.new()
	var caps: Array[PackedVector2Array] = []
	for i in rng.randi_range(3, 5):
		var r := w * rng.randf_range(0.25, 0.4)
		var c := Vector2(rng.randf_range(-w * 0.4, w * 0.4), -r * 0.7)
		n.add_child(poly(blob(c, r, rng), color, mat, w * 0.8))
		caps.append(_cap(c, r))
	n.add_child(multi(caps, Color.WHITE, mat, w * 0.8, SNOW))
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
	n.add_child(poly(_cap(Vector2(0, -h * 0.3), w * 0.62), Color.WHITE, mat, 0.0, SNOW))
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
		n.add_child(poly(PackedVector2Array([Vector2.ZERO, mid + side, tip, mid - side]), color, mat, h, GRASS))
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
			uv.append_array([Vector2(GRASS, 1), Vector2(GRASS, 1), Vector2(GRASS, 0)])
			polys.append(PackedInt32Array([k, k + 1, k + 2]))
	var p := Polygon2D.new()
	p.polygon = pts
	p.uv = uv
	p.polygons = polys
	p.texture = WHITE
	p.color = color
	p.material = mat
	return p

## Cattails and reeds in a clump: thin blades, a few brown seed heads.
static func reeds(rng: RandomNumberGenerator, w: float, mat: Material) -> Node2D:
	var n := Node2D.new()
	var blades := []
	var heads := []
	for i in rng.randi_range(9, 15):
		var x := rng.randf_range(-w * 0.5, w * 0.5)
		var h := rng.randf_range(110.0, 190.0)
		var tip := Vector2(x + rng.randf_range(-14, 14), -h)
		blades.append(PackedVector2Array([Vector2(x - 2.0, 4), Vector2(x + 2.0, 4), tip]))
		if rng.randf() < 0.45:
			var hc := Vector2(x, -h * 0.82)
			heads.append(PackedVector2Array([hc + Vector2(-4, -14), hc + Vector2(4, -14), hc + Vector2(4, 14), hc + Vector2(-4, 14)]))
	n.add_child(multi(blades, Color("6f7d42"), mat, 190.0, GRASS))
	if heads:
		n.add_child(multi(heads, Color("5a3f2a"), mat, 190.0))
	return n

## A fire-killed tree: a charred trunk and a few broken stubs, no foliage.
static func snag(rng: RandomNumberGenerator, h: float, mat: Material) -> Node2D:
	var n := Node2D.new()
	var tw := maxf(h * 0.026, 3.0)
	var lean := rng.randf_range(-0.05, 0.05) * h
	var char_c := Color("2a2522")
	n.add_child(poly(PackedVector2Array([Vector2(-tw, 4), Vector2(tw, 4), Vector2(lean + tw * 0.3, -h), Vector2(lean - tw * 0.3, -h * 0.97)]), char_c, mat, h))
	var stubs := []
	for i in rng.randi_range(3, 6):
		var t := rng.randf_range(0.3, 0.85)
		var y := -h * t
		var x := lean * t
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var l := rng.randf_range(0.06, 0.14) * h
		stubs.append(PackedVector2Array([Vector2(x, y), Vector2(x, y - tw), Vector2(x + side * l, y - l * 0.5 - tw * 0.5), Vector2(x + side * l, y - l * 0.5)]))
	n.add_child(multi(stubs, char_c, mat, h))
	n.add_child(poly(PackedVector2Array([Vector2(-tw * 0.9, -h * 0.1), Vector2(-tw * 0.3, -h * 0.35), Vector2(-tw * 0.2, -h * 0.1)]), Color("8a7a6a"), mat, h)) # silvered weathering
	return n

## Fireweed: tall stems with a spike of pink flowers, first to come back after a fire.
static func fireweed(rng: RandomNumberGenerator, w: float, mat: Material) -> Node2D:
	var n := Node2D.new()
	var stems := []
	var flowers := []
	for i in rng.randi_range(4, 8):
		var x := rng.randf_range(-w * 0.5, w * 0.5)
		var h := rng.randf_range(70.0, 130.0)
		stems.append(PackedVector2Array([Vector2(x - 1.5, 4), Vector2(x + 1.5, 4), Vector2(x, -h)]))
		for k in 4:
			flowers.append(blob(Vector2(x + rng.randf_range(-3, 3), -h + k * 9.0), 4.5 - k * 0.6, rng, 6, 0.2))
	n.add_child(multi(stems, Color("5d6e3a"), mat, 130.0, GRASS))
	n.add_child(multi(flowers, Color("c0569a"), mat, 130.0, LEAF))
	return n
