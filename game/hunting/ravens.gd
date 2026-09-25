class_name Ravens extends Node2D
## A few ravens wheeling high over something dead: by day, from about half an hour after the
## kill. They're the first sign of a carcass, for you and for anything else looking for one.

const HEIGHT := 520.0

var since := 0.0 ## hour the thing died or was left
var active := true ## the owner says there's still something here worth circling
var _t := 0.0
var _caw := 8.0

func _ready() -> void:
	z_as_relative = false
	z_index = 1

func _process(delta: float) -> void:
	_t += delta
	visible = active and GameClock.clock.daylight() > 0.2 and GameClock.clock.hours - since > 0.3
	if not visible:
		return
	_caw -= delta
	if _caw <= 0.0:
		_caw = randf_range(14.0, 34.0)
		var p: Player = get_tree().get_first_node_in_group("player")
		if p and absf(p.global_position.x - global_position.x) < 2600.0:
			Sfx.play_at(self, global_position + Vector2(0, -HEIGHT), Sfx.caw(), -4.0)
	queue_redraw()

func _draw() -> void:
	for i in 3:
		var a := _t * (0.35 + i * 0.07) + i * 2.1
		var r := 90.0 + i * 40.0
		var c := Vector2(cos(a) * r, -HEIGHT - i * 50.0 + sin(a) * r * 0.25)
		var flap := sin(_t * 5.0 + i) * 6.0
		var col := Color(0.08, 0.08, 0.09)
		draw_line(c, c + Vector2(-13, -4 - flap), col, 3.0)
		draw_line(c, c + Vector2(13, -4 - flap), col, 3.0)
		draw_circle(c, 3.0, col)
