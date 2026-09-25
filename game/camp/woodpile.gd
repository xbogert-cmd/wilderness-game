class_name Woodpile extends Node2D
## A holder for short logs so firewood isn't scattered around camp. Logs are shown end-on,
## stacked in a pyramid whose shape follows how many there are: the bottom row is the
## narrowest that could hold them all as a triangle, and rows fill from the bottom up.

const CAPACITY := 15 ## a five-log bottom row
const R := 14.0 ## log end radius

var world: World
var logs := 0

var _snowy := false

func _process(_delta: float) -> void:
	if (GameClock.weather.snow_cm > 2.0) != _snowy:
		_snowy = not _snowy
		queue_redraw()

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	add_to_group("woodpile")
	z_as_relative = false
	z_index = 2

func load_state(d: Dictionary, _elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	logs = int(d.get("logs", 0))
	queue_redraw()

func to_state() -> Dictionary:
	return {"kind": "woodpile", "x": global_position.x, "logs": logs}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.woodpile.width

func interact_pos() -> Vector2:
	return global_position

func prompt_point(_p: Player) -> Vector2:
	return global_position + Vector2(0, -40.0 - _rows(logs).size() * R * 1.75)

func interact_label(p: Player) -> String:
	if p.carrying:
		if p.carrying.size != "short":
			return "Woodpile: only short logs stack here"
		return "Stack log  (%d/%d)" % [logs, CAPACITY] if logs < CAPACITY else "Woodpile is full"
	if logs > 0 and p.held == null:
		return "Take a log  (%d left)" % logs
	return "Woodpile  (%d/%d logs)" % [logs, CAPACITY]

func interact(p: Player) -> void:
	if p.carrying:
		if p.carrying.size == "short" and logs < CAPACITY:
			var lg := p.carrying
			p.drop_carried()
			lg.queue_free()
			logs += 1
			queue_redraw()
		return
	if logs > 0 and p.held == null:
		logs -= 1
		queue_redraw()
		var lg := world.spawn({"kind": "log", "size": "short", "x": global_position.x, "y": global_position.y - 80.0}) as WorldLog
		p.carrying = lg
		lg.pick_up(p)

## Takes one log for a fire nearby. Returns false if empty.
func take_one() -> bool:
	if logs <= 0:
		return false
	logs -= 1
	queue_redraw()
	return true

## Logs per row, bottom first.
static func _rows(n: int) -> PackedInt32Array:
	var b := 1
	while b * (b + 1) / 2 < n:
		b += 1
	var rows := PackedInt32Array()
	var left := n
	while left > 0:
		var k := mini(b - rows.size(), left)
		rows.append(k)
		left -= k
	return rows

func _draw() -> void:
	var rows := _rows(logs)
	var bark := Palette.BARK_DARK
	# Two stakes at the ends and a pair of rails keep the stack off the wet ground.
	var half := width() * 0.5 - 8.0
	var stake_h := 40.0 + maxf(rows.size(), 2) * R * 1.75
	for sx in [-half, half]:
		draw_line(Vector2(sx, 6), Vector2(sx, -stake_h), bark, 7.0)
	draw_rect(Rect2(-half, -6, half * 2.0, 6), Palette.BARK)
	var rng := RandomNumberGenerator.new()
	var k := 0
	for row in rows.size():
		var count := rows[row]
		var y := -6.0 - R - row * R * 1.74
		for i in count:
			rng.seed = k * 7919 + 13
			var x := (i - (count - 1) * 0.5) * R * 2.02
			var r := R * rng.randf_range(0.88, 1.06)
			_log_end(Vector2(x, y), r, rng)
			if GameClock.weather.snow_cm > 2.0 and (row == rows.size() - 1 or i == 0 or i == count - 1):
				draw_arc(Vector2(x, y), r, PI * 1.12, PI * 1.88, 8, Color(0.94, 0.96, 0.99), 4.0) # snow on the exposed tops
			k += 1

## One log seen end-on: bark ring, pale face, growth rings, a check crack.
func _log_end(c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var face := Color("d9b98a").lerp(Color("e8d2a8"), rng.randf())
	draw_circle(c, r, Palette.BARK.darkened(rng.randf_range(0.0, 0.25)))
	draw_circle(c, r - 3.0, face)
	var core := c + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
	for ring in [0.66, 0.4]:
		draw_arc(core, (r - 3.0) * ring, 0.0, TAU, 18, face.darkened(0.14), 1.2)
	draw_circle(core, 1.6, face.darkened(0.3))
	var a := rng.randf() * TAU
	draw_line(core, core + Vector2.from_angle(a) * (r - 4.0), face.darkened(0.3), 1.2)
