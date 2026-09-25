class_name BirdFlock extends Node2D
## A few small birds feeding on the ground. Get close or make noise and they burst up and
## away into the trees: a small, readable sign that you've been noticed.

const FLUSH_DISTANCE := 260.0

var world: World
var player: Player
var birds: Array = [] ## {p: Vector2 (local), v: Vector2, hop: float}
var flushed := false
var _t := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("birds")
	z_index = 4
	_rng.randomize()
	for i in _rng.randi_range(4, 7):
		birds.append({"p": Vector2(_rng.randf_range(-70, 70), 0), "v": Vector2.ZERO, "hop": _rng.randf() * 3.0})

func _process(delta: float) -> void:
	_t += delta
	var d := absf(player.global_position.x - global_position.x)
	if not flushed and (d < FLUSH_DISTANCE * (0.4 if player.crouching else 1.0) or player.noise() * 900.0 > d):
		flush()
	for b in birds:
		if flushed:
			b.v.y -= 260.0 * delta
			b.p += b.v * delta
		else:
			b.hop -= delta
			if b.hop <= 0.0:
				b.hop = _rng.randf_range(0.8, 2.5)
				b.p.x += _rng.randf_range(-12, 12)
			b.p.y = world.terrain.height_at(global_position.x + b.p.x) - global_position.y
	if flushed and _t > 5.0:
		queue_free()
	if absf(player.global_position.x - global_position.x) > 3000.0:
		queue_free()
	queue_redraw()

func flush() -> void:
	flushed = true
	_t = 0.0
	var away := signf(global_position.x - player.global_position.x)
	for b in birds:
		b.v = Vector2(away * _rng.randf_range(160, 320), -_rng.randf_range(260, 420))

func _draw() -> void:
	var c := Color("3d3630")
	for b in birds:
		var p: Vector2 = b.p
		if flushed:
			var flap := sin(_t * 26.0 + p.x) * 7.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(-8, flap), p, p + Vector2(8, flap), p + Vector2(0, 3)]), c)
		else:
			var peck := 3.0 if fmod(_t + b.hop, 1.4) < 0.25 else 0.0
			draw_circle(p + Vector2(0, -5), 4.5, c)
			draw_circle(p + Vector2(4, -8 + peck), 2.8, c)
			draw_line(p + Vector2(-4, -5), p + Vector2(-9, -8), c, 2.0)
