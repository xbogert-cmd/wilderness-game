class_name Weir extends Node2D
## A fish weir: a fence of stakes driven across a creek in a V, with a gap at the point. Fish
## moving up or down the creek are funnelled through the gap, and a fish trap set there (or
## anywhere close) catches two or three times as many. A big flood can take it out.

var world: World
var floods_seen := 0

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("structure")
	add_to_group("weir")
	z_as_relative = false
	z_index = 9
	GameClock.ticked.connect(_on_tick)

func _on_tick(_dh: float) -> void:
	if not is_queued_for_deletion():
		FishTrap.flood_took(self, "fish weir")

func load_state(d: Dictionary, _elapsed: float) -> void:
	floods_seen = int(d.get("floods", GameClock.weather.floods))
	var i := world.terrain.water_index(float(d.x))
	global_position = Vector2(float(d.x), world.terrain.surface_of(i, false) if i >= 0 else world.terrain.height_at(float(d.x)))

func to_state() -> Dictionary:
	return {"kind": "weir", "x": global_position.x, "floods": floods_seen}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.weir.width

func interact_pos() -> Vector2:
	return global_position

func interact_label(_p: Player) -> String:
	var traps := get_tree().get_nodes_in_group("structure").filter(func(s): return s is FishTrap and s.variety == "fish_trap" and absf(s.global_position.x - global_position.x) < FishTrap.WEIR_R)
	return "Fish weir  (%s)" % ("funnelling fish into your trap" if traps else "set a fish trap by it")

func interact(_p: Player) -> void:
	pass

func _draw() -> void:
	var stake := Palette.BARK_DARK
	var half := width() * 0.5
	for k in 11: # stakes sticking up out of the current, shorter toward the gap in the middle
		var x := -half + k * half * 2.0 / 10.0
		if absf(x) < 10.0:
			continue
		var top := -26.0 - absf(x) * 0.12
		draw_line(Vector2(x, 26), Vector2(x, top), stake.darkened(0.1 if k % 2 else 0.0), 4.0)
	draw_line(Vector2(-half, -8), Vector2(-10, -6), stake, 2.0) # wattle woven between
	draw_line(Vector2(10, -6), Vector2(half, -8), stake, 2.0)
	for k in 5: # water piling against it
		draw_arc(Vector2(-half + 10.0 + k * half * 0.45, 0), 6.0, PI, TAU, 6, Color(0.9, 0.95, 1.0, 0.45), 1.5)
