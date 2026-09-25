class_name WorldItem extends Node2D
## A packable item lying on the ground.

var world: World
var stack: ItemStack

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	z_as_relative = false
	z_index = 4

func load_state(d: Dictionary, _elapsed: float) -> void:
	stack = ItemStack.from_dict(d.stack)
	if stack.def.has("food"):
		add_to_group("food_scent") # meat on the ground draws wolves; the bear eats anything
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)) + 2.0)
	queue_redraw()

func to_state() -> Dictionary:
	return {"kind": "item", "x": global_position.x, "stack": stack.to_dict()}

func can_unload() -> bool:
	return true

func appeals(kind: String) -> bool:
	return stack.def.has("raw") or kind == "black_bear"

func gnaw(_amount: float, _kind: String) -> bool:
	queue_free() # gone in a mouthful
	return false

func interact_pos() -> Vector2:
	return global_position

func interact_label(_p: Player) -> String:
	return "Pick up " + stack.label(GameClock.clock.hours)

func interact(p: Player) -> void:
	if p.receive(stack, false):
		queue_free()

func _draw() -> void:
	var c := stack.def.color
	if stack.def.id == "sticks":
		for i in mini(stack.count + 1, 4):
			var y := -3.0 - i * 3.0
			draw_line(Vector2(-22 + i * 3, y), Vector2(20 - i * 4, y - 2 + i), c.darkened(0.1 * i), 4.0)
		return
	const CELL := 14.0
	var sz := Vector2(stack.def.size())
	var flat := sz.y > sz.x # tall things lie on their side
	var box := (Vector2(sz.y, sz.x) if flat else sz) * CELL
	ItemIcons.draw(self, stack, Vector2(-box.x / 2.0, -box.y), CELL, flat)
