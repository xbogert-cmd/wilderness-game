class_name Rabbit extends Node2D
## A cottontail near the brush at dawn and dusk. It freezes, nibbles, hops a little; come close
## (or loud) and it bolts in long hops. An arrow or a spear thrust takes it.

const HOP := 70.0
const FLEE_HOP := 190.0

var world: World
var player: Player
var facing := 1
var fleeing := false
var _hop := 0.0 ## 0..1 through a hop, -1 sitting
var _timer := 2.0
var _from := 0.0
var _to := 0.0

func _ready() -> void:
	add_to_group("small_game")
	z_index = -3
	_hop = -1.0

func _physics_process(delta: float) -> void:
	var d := absf(player.global_position.x - position.x)
	var spook := 150.0 + 700.0 * player.noise() + (200.0 if not player.crouching else 0.0)
	if d < spook and not fleeing:
		fleeing = true
		_timer = 0.0
	_timer -= delta
	if _hop < 0.0 and _timer <= 0.0:
		if fleeing:
			facing = 1 if position.x > player.global_position.x else -1
		elif randf() < 0.5:
			facing = -facing
		_from = position.x
		_to = clampf(position.x + facing * (FLEE_HOP if fleeing else HOP), Animal.EDGE, Terrain.WORLD_W - Animal.EDGE)
		if world.terrain.water_surface_at(_to) != INF and not Creek.frozen():
			_to = position.x
		_hop = 0.0
	if _hop >= 0.0:
		_hop += delta / (0.28 if fleeing else 0.4)
		position.x = lerpf(_from, _to, minf(_hop, 1.0))
		if _hop >= 1.0:
			_hop = -1.0
			_timer = 0.05 if fleeing else randf_range(1.5, 5.0)
	position.y = world.ground_y(position.x) - (sin(clampf(_hop, 0.0, 1.0) * PI) * (26.0 if fleeing else 12.0) if _hop >= 0.0 else 0.0)
	if fleeing and d > 2600.0:
		queue_free()
	queue_redraw()

## Small: anywhere on it is a kill.
func zone_at(p: Vector2) -> int:
	var l := p - position
	l.x *= facing
	return 2 if ((l - Vector2(0, -14)) / Vector2(18, 13)).length() < 1.0 or l.distance_to(Vector2(15, -24)) < 8.0 else 0

func shot(_zone: int) -> void:
	die(true)

func hurt(_amount: float, _from_x: float) -> void:
	die(false)

func die(arrow: bool) -> void:
	var h := GameClock.clock.hours
	world.spawn({"kind": "item", "x": position.x, "stack": ItemStack.make("rabbit_raw", h).to_dict()})
	if arrow:
		world.spawn({"kind": "item", "x": position.x + 30.0, "stack": ItemStack.make("arrows", h).to_dict()})
	queue_free()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	var fur := Color("8a7a66") if GameClock.weather.snow_cm < 20.0 else Color("b8ad9c")
	var stretch := 1.0 + (0.3 * sin(clampf(_hop, 0.0, 1.0) * PI) if _hop >= 0.0 else 0.0)
	draw_colored_polygon(PredatorRig._ellipse(Vector2(0, -13), 17.0 * stretch, 11.0), fur)
	draw_circle(Vector2(14, -22), 7.5, fur)
	draw_line(Vector2(12, -27), Vector2(6, -44), fur.darkened(0.1), 4.0)
	draw_line(Vector2(15, -27), Vector2(12, -45), fur, 4.0)
	draw_circle(Vector2(18, -23), 1.6, Color(0.1, 0.08, 0.06))
	draw_circle(Vector2(-16, -16), 5.0, Color("f0ece4")) # cottontail
	draw_set_transform_matrix(Transform2D.IDENTITY)
