class_name LogBridge extends Node2D
## Logs laid bank to bank over a creek or the river, on posts. Walk across dry.
## Built over whichever water it was placed on; the deck is one straight span.

const OVERHANG := 90.0 ## past each bank

var world: World
var water := 0 ## index into Terrain.WATERS
var _a := Vector2.ZERO ## deck ends, local
var _b := Vector2.ZERO

func _ready() -> void:
	add_to_group("persist")
	add_to_group("structure")
	z_as_relative = false
	z_index = 3

func load_state(d: Dictionary, _elapsed: float) -> void:
	var x := float(d.x)
	water = world.terrain.water_index(x)
	if water < 0: # placed a little off: find the nearest water
		water = world.terrain.water_index(x, 800.0)
	var wd: Dictionary = Terrain.WATERS[water]
	global_position = Vector2(wd.x, world.terrain.surface_of(water, false))
	var x0: float = wd.x - wd.half - OVERHANG
	var x1: float = wd.x + wd.half + OVERHANG
	_a = Vector2(x0, world.terrain.height_at(x0) - 6.0) - global_position
	_b = Vector2(x1, world.terrain.height_at(x1) - 6.0) - global_position
	var body := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = _a
	seg.b = _b
	c.shape = seg
	body.add_child(c)
	add_child(body)
	queue_redraw()

func to_state() -> Dictionary:
	return {"kind": "bridge", "x": global_position.x}

func can_unload() -> bool:
	return true

func width() -> float:
	return absf(_b.x - _a.x)

func _draw() -> void:
	var bark := Palette.BARK
	var n := int(width() / 280.0) + 1
	for k in n: # posts down into the water
		var p := _a.lerp(_b, (k + 0.5) / n)
		draw_line(p, Vector2(p.x, p.y + 260.0), Palette.BARK_DARK, 12.0)
	draw_line(_a + Vector2(0, 8), _b + Vector2(0, 8), bark.darkened(0.2), 18.0) # the far logs
	draw_line(_a, _b, bark.lightened(0.08), 16.0) # the near log, walked on
	for k in int(width() / 60.0): # bark texture and lashings
		var p := _a.lerp(_b, k / (width() / 60.0))
		draw_line(p + Vector2(-8, -3), p + Vector2(10, -2), bark.darkened(0.25), 2.0)
	for p in [_a, _b]:
		draw_circle(p, 10.0, Color("cfae7e"))
		draw_circle(p, 7.0, Color("b8965e"))
