class_name SteppingStones extends Node2D
## Flat rocks rolled out of the creek bed into a line from bank to bank, their tops just out
## of the water: cross with dry feet. When the creek comes up in flood it runs over them and
## you're back to wading (or not crossing at all).

const TOP := 12.0 ## how far the tops stand out of the water at its usual level

var world: World
var water := 0 ## index into Terrain.WATERS
var top_y := 0.0 ## world y of the stone tops
var _x0 := 0.0
var _x1 := 0.0
var _body: CollisionShape2D
var _drowned := false
var _rocks: Array = [] ## [x, bed y, half width, shade], local

func _ready() -> void:
	add_to_group("persist")
	add_to_group("structure")
	z_as_relative = false
	z_index = 6 # under the water's surface sheen

func load_state(d: Dictionary, _elapsed: float) -> void:
	var x := float(d.x)
	water = world.terrain.water_index(x)
	if water < 0:
		water = world.terrain.water_index(x, 800.0)
	var wd: Dictionary = Terrain.WATERS[water]
	top_y = world.terrain.surface_of(water, false) - TOP
	global_position = Vector2(wd.x, top_y)
	_x0 = wd.x
	while world.terrain.height_at(_x0) > top_y and _x0 > wd.x - wd.half - 200.0: # out to where the bank's as high as the tops
		_x0 -= 5.0
	_x1 = wd.x
	while world.terrain.height_at(_x1) > top_y and _x1 < wd.x + wd.half + 200.0:
		_x1 += 5.0
	var body := StaticBody2D.new()
	_body = CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(_x0 - 10.0 - wd.x, 0)
	seg.b = Vector2(_x1 + 10.0 - wd.x, 0)
	_body.shape = seg
	_body.one_way_collision = true # wading underneath, you don't bump into them
	body.add_child(_body)
	add_child(body)
	var n := maxi(int((_x1 - _x0 - 40.0) / 62.0), 2)
	var r := RandomNumberGenerator.new()
	r.seed = int(global_position.x)
	for k in n:
		var rx := lerpf(_x0 + 30.0, _x1 - 30.0, (k + 0.5) / n)
		_rocks.append([rx - global_position.x, world.terrain.height_at(rx) - global_position.y, r.randf_range(20.0, 27.0), r.randf_range(0.0, 0.2)])
	queue_redraw()

func to_state() -> Dictionary:
	return {"kind": "stones", "x": global_position.x}

func can_unload() -> bool:
	return true

func width() -> float:
	return _x1 - _x0

## Under water: the creek's up over them.
func drowned() -> bool:
	return world.terrain.surface_of(water) < top_y + 3.0

func _process(_delta: float) -> void:
	if _body and drowned() != _drowned:
		_drowned = drowned()
		_body.set_deferred("disabled", _drowned)
		var p: Player = get_tree().get_first_node_in_group("player")
		if _drowned and p and absf(p.global_position.x - global_position.x) < width() * 0.5 + 800.0:
			p.message.emit("The creek's up over the stepping stones.")

func _draw() -> void:
	var r := RandomNumberGenerator.new()
	for rk in _rocks:
		var x: float = rk[0]
		var bed: float = rk[1]
		var wdt: float = rk[2]
		r.seed = int(x * 13.0)
		var rock := Color(0.52, 0.5, 0.46).darkened(rk[3])
		# rocks piled up from the bed, the top one broad and flat, just out of the water
		var y := bed
		while y > 30.0:
			var rr := r.randf_range(14.0, 22.0)
			draw_colored_polygon(Transform2D(0.0, Vector2(1.3, 0.8), 0.0, Vector2(x + r.randf_range(-8.0, 8.0), y - rr * 0.5)) * SceneryArt.blob(Vector2.ZERO, rr, r, 9, 0.15), rock.darkened(0.3))
			y -= rr * 1.1
		var top := Transform2D(0.0, Vector2(1.0, 0.55), 0.0, Vector2(x, 13.0)) * SceneryArt.blob(Vector2.ZERO, wdt + 3.0, r, 12, 0.1)
		draw_colored_polygon(top, rock)
		draw_colored_polygon(Transform2D(0.0, Vector2(0.8, 0.22), 0.0, Vector2(x - 2.0, 2.0)) * SceneryArt.blob(Vector2.ZERO, wdt, r, 10, 0.08), rock.lightened(0.22)) # the dry top
		draw_line(Vector2(x - wdt, TOP - 1.0), Vector2(x + wdt, TOP - 1.0), Color(0.33, 0.4, 0.28, 0.55), 2.5) # a waterline of weed
