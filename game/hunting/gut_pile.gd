class_name GutPile extends Node2D
## What's left after butchering in the field. It smells, and wolves and the bear come for it
## (not at camp, where nothing wild comes). Gone in a day and a half either way.

const LASTS_HOURS := 36.0

var world: World
var hour := 0.0 ## when it was left
var amount := 1.0
var _ravens: Ravens

func _ready() -> void:
	add_to_group("persist")
	add_to_group("food_scent")
	z_as_relative = false
	z_index = 3
	_ravens = Ravens.new()
	add_child(_ravens)
	GameClock.ticked.connect(_on_tick)

func load_state(d: Dictionary, elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.ground_y(float(d.x)))
	hour = float(d.get("hour", GameClock.clock.hours))
	amount = float(d.get("amount", 1.0))
	_ravens.since = hour
	if elapsed > 1.0:
		_scavenge.call_deferred(elapsed)
	_on_tick(0.0)

func _scavenge(elapsed: float) -> void:
	if not Predator.safe_at(get_tree(), global_position.x):
		gnaw(elapsed * 0.15, "wolf")

func to_state() -> Dictionary:
	return {"kind": "gut_pile", "x": global_position.x, "hour": hour, "amount": amount}

func can_unload() -> bool:
	return true

func appeals(_kind: String) -> bool:
	return amount > 0.05

func gnaw(n: float, _kind: String) -> bool:
	amount -= n * 0.5
	if amount <= 0.0:
		queue_free()
		return false
	queue_redraw()
	return true

func _on_tick(_dh: float) -> void:
	if GameClock.clock.hours - hour > LASTS_HOURS:
		queue_free()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var s := sqrt(clampf(amount, 0.2, 1.0))
	draw_colored_polygon(SceneryArt.blob(Vector2(0, -6), 26.0 * s, rng, 9, 0.35), Color("6e2a24"))
	draw_colored_polygon(SceneryArt.blob(Vector2(10, -9), 13.0 * s, rng, 7, 0.3), Color("8e4a3a"))
	draw_colored_polygon(SceneryArt.blob(Vector2(-12, -5), 10.0 * s, rng, 7, 0.3), Color("5a3a3a"))
