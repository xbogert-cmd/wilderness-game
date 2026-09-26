class_name Tracks extends Node2D
## Footprints pressed into soft ground (mud now, snow later), and blood drops from a wounded
## animal (on any ground). They age through readable stages and rain washes them out faster.
## One node holds them all; E examines the nearest.

const STAGES := [[2.0, "fresh"], [12.0, "a few hours old"], [36.0, "old"]]
const LIFETIME := 48.0
const MAX_PRINTS := 700
const NAMES := {"boot": "Your own boot prints", "deer": "Mule deer tracks", "blood": "Blood drops",
	"wolf": "Wolf tracks", "bear": "Bear tracks", "coyote": "Coyote tracks"}

var world: World
var prints: Array = [] ## {x, s: species, d: dir, age: hours}
var _dirty := true

func _ready() -> void:
	add_to_group("interactable")
	z_index = 3 # over the lying snow (chunks draw theirs at 2)
	GameClock.ticked.connect(_on_tick)

func add(x: float, species: String, dir: int) -> void:
	if species != "blood" and not (world.terrain.soft_at(x) or GameClock.weather.snow_cm > 2.0):
		return
	prints.append({"x": x, "s": species, "d": dir, "age": 0.0})
	if prints.size() > MAX_PRINTS:
		prints.pop_front()
	_dirty = true

func _on_tick(dh: float) -> void:
	var wash := 1.0 + 2.5 * GameClock.weather.precip # rain washes out, fresh snow fills in
	for p in prints:
		p.age += dh * wash
	var before := prints.size()
	prints = prints.filter(func(p): return p.age < LIFETIME)
	_dirty = _dirty or prints.size() != before or dh > 0.05

static func stage(age: float) -> int:
	for i in STAGES.size():
		if age < STAGES[i][0]:
			return i
	return STAGES.size()

func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		queue_redraw()

func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var cx := cam.get_screen_center_position().x if cam else 0.0
	for p in prints:
		if absf(p.x - cx) > 1600.0:
			continue
		var alpha: float = [0.75, 0.5, 0.28, 0.12][stage(p.age)]
		var in_snow := GameClock.weather.snow_cm > 2.0
		var y := world.snow_top(p.x) + (2.0 if in_snow else 3.0)
		var c := Color(0.45, 0.52, 0.66, alpha) if in_snow else Color(0.1, 0.07, 0.05, alpha) # blue-grey hollows in snow
		var d: float = p.d
		if p.s == "blood":
			var r := Color(0.45, 0.05, 0.04, alpha * 1.2)
			draw_circle(Vector2(p.x, y - 1.0), 3.6, r)
			draw_circle(Vector2(p.x + d * 8.0, y), 2.2, r)
		elif p.s == "deer": # split heart-shaped hoof, toes pointing the way it walked
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - d * 5, y), Vector2(p.x + d * 5, y - 1.5), Vector2(p.x + d * 5, y - 0.2)]), c)
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - d * 5, y + 1.2), Vector2(p.x + d * 5, y + 0.6), Vector2(p.x + d * 5, y + 2.2)]), c)
		elif p.s in ["wolf", "coyote"]: # four toes and a pad (a coyote's smaller, narrower)
			var k := 1.0 if p.s == "wolf" else 0.72
			draw_circle(Vector2(p.x, y), 3.4 * k, c)
			for t in 4:
				draw_circle(Vector2(p.x + d * 5.0 * k + (t - 1.5) * 2.4 * k, y - 1.0 - absf(t - 1.5) * 0.4), 1.4 * k, c)
		elif p.s == "bear": # a broad pad and five toes
			draw_rect(Rect2(p.x - 8.0, y - 1.5, 16.0, 4.0), c)
			for t in 5:
				draw_circle(Vector2(p.x + d * 10.0 + (t - 2) * 3.4, y - 1.5), 1.7, c)
		else: # boot: sole and heel
			draw_rect(Rect2(p.x - 7.0, y - 1.0, 9.0, 3.0), c)
			draw_rect(Rect2(p.x + d * 5.0 - 2.0, y - 0.5, 4.0, 2.5), c)

func _nearest(p: Player) -> Dictionary:
	var best := {}
	var bd := 90.0
	for t in prints:
		if t.s == "boot":
			continue # your own prints aren't worth a prompt
		var dd: float = absf(t.x - p.global_position.x)
		if dd < bd:
			bd = dd
			best = t
	return best

func interact_pos() -> Vector2:
	var p: Player = get_tree().get_first_node_in_group("player")
	var t := _nearest(p)
	return Vector2(t.x, world.terrain.height_at(t.x)) if t else Vector2(INF, INF)

func interact_label(p: Player) -> String:
	return "Examine tracks" if _nearest(p) else ""

func interact(p: Player) -> void:
	var t := _nearest(p)
	var same := prints.filter(func(o): return o.s == t.s and absf(o.x - t.x) < 600.0)
	var dirs := same.map(func(o): return o.d)
	var heading := "east" if dirs.count(1) >= dirs.count(-1) else "west"
	var age: String = "washed nearly away" if stage(t.age) >= STAGES.size() else STAGES[stage(t.age)][1]
	p.message.emit("%s, %s, heading %s. About %d marks here." % [NAMES.get(t.s, "Tracks"), age, heading, same.size()])

func to_array() -> Array:
	return prints.duplicate(true)

func from_array(a: Array) -> void:
	prints = a.duplicate(true)
	_dirty = true
