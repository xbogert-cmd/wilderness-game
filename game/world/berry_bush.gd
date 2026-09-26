class_name BerryBush extends Node2D
## A bush; some carry serviceberries that grow back a season after picking.


var chunk: Chunk
var n := 0
var width := 120.0
var fruiting := false
var picked_hour := -INF
var _berries: Node2D

func setup(c: Chunk, id: int, art: Node2D, w: float, has_fruit: bool, picked: float) -> void:
	chunk = c
	n = id
	width = w
	fruiting = has_fruit
	picked_hour = picked
	add_child(art)
	if fruiting:
		add_to_group("interactable")
		_berries = Node2D.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = id
		for i in 9:
			var dot := Polygon2D.new()
			dot.polygon = SceneryArt.blob(Vector2(rng.randf_range(-w * 0.35, w * 0.35), -rng.randf_range(w * 0.15, w * 0.6)), 5.0, rng, 6, 0.1)
			dot.color = Color("4a3a6a")
			_berries.add_child(dot)
		add_child(_berries)

func _process(_delta: float) -> void:
	if _berries:
		_berries.visible = ripe()

## Grows back over one season of growing weather (winter doesn't count).
func ripe() -> bool:
	return GameClock.clock.growing_hours(picked_hour) >= GameClock.clock.season_hours()

func interact_pos() -> Vector2:
	return global_position

func interact_label(_p: Player) -> String:
	return "Pick serviceberries" if ripe() else ""

func interact(p: Player) -> void:
	picked_hour = GameClock.clock.hours
	chunk.world.mark(chunk.index, "picked", n)
	p.receive(ItemStack.make("berries", picked_hour, 3))
