class_name Glow extends Sprite2D
## A soft halo in the air round a light (fire, torch, lantern, flare), added onto
## what's behind it, so flames glow instead of just lighting the ground. Follows its light's
## colour, strength and visibility.

static var _tex: GradientTexture2D
var light: PointLight2D
var size := 1.0

## A halo on this light.
static func on(l: PointLight2D, px := 260.0) -> void:
	var g := Glow.new()
	g.light = l
	g.size = px
	l.add_child(g)

func _ready() -> void:
	if _tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.add_point(0.25, Color(1, 1, 1, 0.45))
		grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0))
		_tex = GradientTexture2D.new()
		_tex.gradient = grad
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(0.5, 0.0)
		_tex.width = 128
		_tex.height = 128
	texture = _tex
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	scale = Vector2.ONE * size / 64.0
	z_as_relative = false
	z_index = 25

func _process(_delta: float) -> void:
	visible = light.visible and light.energy > 0.01
	var night := 1.0 - GameClock.clock.daylight()
	var c := light.color
	c.a = clampf(light.energy * (0.18 + 0.5 * night), 0.0, 0.9) # (the dark dims everything: brighter at night to show)
	modulate = c
