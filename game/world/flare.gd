class_name Flare extends Node2D
## A signal flare: shoots up, bursts red, and drifts down under its own light for a while.
## Anything wild close by scatters from it.

const RISE := 1400.0
const HANG := 11.0 ## seconds lit

var _v := -1500.0
var _t := 0.0
var _light: PointLight2D

func _ready() -> void:
	z_as_relative = false
	z_index = 9
	_light = PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	_light.texture = tex
	_light.texture_scale = 14.0
	_light.color = Color(1.0, 0.35, 0.25)
	_light.energy = 0.0
	add_child(_light)
	for p in get_tree().get_nodes_in_group("predators"):
		if absf(p.position.x - global_position.x) < 1600.0:
			p.flee(global_position.x)

func _process(delta: float) -> void:
	_t += delta
	if _v < 0.0: # climbing, slowing
		position.y += _v * delta
		_v += 1100.0 * delta
	else: # burning, drifting down with the wind
		position.y += 45.0 * delta
		position.x += GameClock.weather.wind_dir * 30.0 * GameClock.weather.wind * delta
	var lit := _v >= 0.0
	_light.energy = (1.3 + 0.2 * sin(_t * 23.0)) * clampf((HANG + 1.5 - _t) / 3.0, 0.0, 1.0) if lit else 0.0
	if _t > HANG + 1.5:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if _v < 0.0:
		draw_line(Vector2.ZERO, Vector2(0, 40), Color(1.0, 0.8, 0.6, 0.6), 3.0) # the streak going up
		return
	var k := clampf((HANG + 1.5 - _t) / 3.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.45, 0.35, k))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.8, k))
	for i in 5: # a smoke trail above it
		draw_circle(Vector2(sin(_t + i) * 4.0, -12.0 - i * 14.0), 4.0 + i * 1.5, Color(0.8, 0.75, 0.75, 0.18 * k))
