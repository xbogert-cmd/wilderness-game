class_name BaitPile extends Node2D
## A heap of berries set out to draw deer. While it lasts, active deer within reach drift to it
## and feed there; it shrinks as they eat and goes off after a couple of days. The bear smells
## it from a long way off, and likes it even more than the deer do.

const DRAW_REACH := 2600.0
const EAT_PER_HOUR := 0.2
const LASTS_HOURS := 48.0

var world: World
var amount := 1.0
var laid := 0.0 ## hour set out

func _ready() -> void:
	add_to_group("persist")
	add_to_group("structure")
	add_to_group("bait")
	add_to_group("food_scent")
	z_as_relative = false
	z_index = 2
	GameClock.ticked.connect(_on_tick)

func load_state(d: Dictionary, elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	amount = float(d.get("amount", 1.0))
	laid = float(d.get("laid", GameClock.clock.hours))
	_on_tick(elapsed)

func to_state() -> Dictionary:
	return {"kind": "bait", "x": global_position.x, "amount": amount, "laid": laid}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.bait.width

func appeals(kind: String) -> bool:
	return kind == "black_bear" and amount > 0.05

func gnaw(n: float, _kind: String) -> bool:
	amount -= n * 0.4
	if amount <= 0.0:
		queue_free()
		return false
	queue_redraw()
	return true

## The nearest bait still worth walking to, or null.
static func nearest(tree: SceneTree, x: float) -> BaitPile:
	var best: BaitPile = null
	for b: BaitPile in tree.get_nodes_in_group("bait"):
		var d := absf(b.global_position.x - x)
		if d < DRAW_REACH and not b.is_queued_for_deletion() and (best == null or d < absf(best.global_position.x - x)):
			best = b
	return best

func _on_tick(dh: float) -> void:
	for a in get_tree().get_nodes_in_group("animals"):
		if a.state == Animal.State.GRAZE and absf(a.position.x - global_position.x) < 80.0:
			amount -= EAT_PER_HOUR * dh
	if amount <= 0.0 or GameClock.clock.hours - laid > LASTS_HOURS:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := int(ceil(18.0 * clampf(amount, 0.0, 1.0)))
	draw_colored_polygon(SceneryArt.blob(Vector2(0, -4), 22.0 * sqrt(clampf(amount, 0.2, 1.0)), rng, 8, 0.3), Color("5d6b36"))
	for i in n:
		draw_circle(Vector2(rng.randf_range(-22, 22), rng.randf_range(-12, 0)), 3.2, Color("4a3a6a"))
