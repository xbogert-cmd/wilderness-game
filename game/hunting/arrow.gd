class_name Arrow extends Node2D
## An arrow in flight: gravity, then it strikes an animal, the ground, or water. Arrows that
## miss usually survive and can be picked up; the thud startles animals close by.
## The view is side-on but the shot travels in depth: an arrow passes animals nearer than
## the aimed distance and strikes what's there, so you hit the part you aimed at.

const GRAVITY := 900.0
const BREAK_CHANCE := 0.25
const STARTLE_RADIUS := 450.0

var world: World
var velocity := Vector2.ZERO
var arm_x := 0.0 ## the aimed distance; animals can be struck from here on
var _life := 5.0

func _ready() -> void:
	z_as_relative = false
	z_index = 6
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	var from := position
	velocity.y += GRAVITY * delta
	position += velocity * delta
	rotation = velocity.angle()
	_life -= delta
	var steps := maxi(1, int(from.distance_to(position) / 10.0))
	for i in steps: # sample the path so fast arrows can't skip through a deer
		var p := from.lerp(position, float(i + 1) / steps)
		for a in _targets():
			if (p.x - arm_x) * signf(velocity.x) < -6.0:
				break
			var z: int = a.zone_at(p)
			if z > 0:
				a.shot(z)
				queue_free()
				return
		var ground := world.terrain.height_at(p.x)
		var water := world.terrain.water_surface_at(p.x)
		if p.y >= ground or (water != INF and p.y >= water):
			_land(p, water == INF)
			return
	if _life <= 0.0 or position.x < 0.0 or position.x > Terrain.WORLD_W:
		queue_free()

## Deer, wolves, the bear, rabbits: anything an arrow can strike.
func _targets() -> Array:
	var t := get_tree()
	return t.get_nodes_in_group("animals") + t.get_nodes_in_group("predators") + t.get_nodes_in_group("small_game")

func _land(p: Vector2, on_ground: bool) -> void:
	for a: Animal in get_tree().get_nodes_in_group("animals"):
		if absf(a.position.x - p.x) < STARTLE_RADIUS:
			a.awareness += a.def.alert_at * 1.2
	if on_ground and randf() > BREAK_CHANCE:
		world.spawn({"kind": "item", "x": p.x, "stack": ItemStack.make("arrows", GameClock.clock.hours).to_dict()})
	queue_free()

func _draw() -> void:
	draw_line(Vector2(-34, 0), Vector2(8, 0), Color("b0966b"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -3), Vector2(16, 0), Vector2(8, 3)]), Color("3a3028"))
	draw_line(Vector2(-34, 0), Vector2(-24, 0), Color("d8d0c0"), 5.0)
