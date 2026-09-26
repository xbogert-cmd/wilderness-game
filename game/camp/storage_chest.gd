class_name StorageChest extends Node2D
## A lidded log chest for keeping gear at camp. E opens it beside the pack: drag between them.
## Holds a pack-sized grid.

var world: World
var store := Backpack.new()

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	add_to_group("chest")
	z_as_relative = false
	z_index = 2

func load_state(d: Dictionary, _elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	if d.has("store"):
		store.from_dict(d.store)

func to_state() -> Dictionary:
	return {"kind": "chest", "x": global_position.x, "store": store.to_dict()}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.chest.width

func interact_pos() -> Vector2:
	return global_position

func interact_label(_p: Player) -> String:
	var n := store.entries.size()
	return "Open the chest  (%s)" % ("empty" if n == 0 else "%d item%s" % [n, "" if n == 1 else "s"])

func interact(_p: Player) -> void:
	var ui: BackpackUI = get_tree().get_first_node_in_group("backpack_ui")
	if ui and not ui.visible:
		ui.storage = store
		ui.toggle()

func _draw() -> void:
	var wood := Palette.BARK.lightened(0.1)
	draw_rect(Rect2(-50, -52, 100, 52), wood)
	for y in [-40.0, -26.0, -12.0]:
		draw_line(Vector2(-50, y), Vector2(50, y), Palette.BARK_DARK, 1.5)
	draw_rect(Rect2(-54, -62, 108, 12), wood.darkened(0.15)) # lid
	for sx in [-38.0, 38.0]: # strap hinges
		draw_rect(Rect2(sx - 4, -62, 8, 62), Color(0.3, 0.26, 0.22))
	draw_rect(Rect2(-6, -54, 12, 10), Color("9aa0a6")) # hasp
	if GameClock.weather.snow_cm > 2.0:
		draw_rect(Rect2(-56, -68, 112, 7), Color(0.94, 0.96, 0.99))
