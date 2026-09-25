class_name Cave extends Node2D
## The rock shelter in the foothills: an outcrop the path runs under. Dry, dim and a little
## warmer than outside, so it counts as shelter; someone camped here before, and left a cache.
## Drawn in layers: the outcrop's bulk behind everything, its ceiling lip in front of the
## player, and a shade over the interior.

const HOLDS_C := 5.0 ## rock keeps it about this warm inside
const WARMTH := 0.3
const CEILING := 280.0 ## px above the floor

var world: World
var chunk_index := 0
var _front: Node2D

func _ready() -> void:
	position = Vector2(Terrain.CAVE_X, world.terrain.cave_y)
	add_to_group("shelter")
	add_to_group("heat")
	add_to_group("interactable")
	add_to_group("camp") # the cache gets a key popup
	add_to_group("landmark")
	z_as_relative = false
	z_index = -5 # the bulk and back wall sit behind the player
	_front = Node2D.new()
	_front.z_as_relative = false
	_front.z_index = 9 # the ceiling lip and interior shade go over the player
	_front.draw.connect(_draw_front)
	add_child(_front)

func covers(x: float) -> bool:
	return absf(x - global_position.x) < Terrain.CAVE_HALF - 40.0

func heat_at(p: Vector2) -> float:
	if not covers(p.x) or absf(p.y - global_position.y) > 400.0:
		return 0.0
	var outside := GameClock.weather.air_temp_c(GameClock.clock)
	return clampf((HOLDS_C - outside) / GameClock.tuning.fire_heat_c, 0.0, WARMTH)

func searched() -> bool:
	return world.chunk_state(chunk_index).get("cave_searched", false)

func interact_pos() -> Vector2:
	return global_position + Vector2(Terrain.CAVE_HALF - 150.0, 0) # the cache, at the back

func interact_label(_p: Player) -> String:
	return "" if searched() else "Search the old camp"

func interact(p: Player) -> void:
	world.chunk_state(chunk_index)["cave_searched"] = true
	for s in [ItemStack.make("fishing_kit", GameClock.clock.hours), ItemStack.make("arrows", GameClock.clock.hours, 3), ItemStack.make("whetstone", GameClock.clock.hours)]:
		if not p.receive(s):
			world.spawn({"kind": "item", "x": p.global_position.x, "stack": s.to_dict()})
	Journal.note("cave_page", "A torn page, weighted under a stone in the rock shelter: \"...dry here even in the October rain. The deer come up the draw below at dusk, always from the creek side. Heard wolves two nights running. Moving up to the tower tomorrow.\"")
	p.message.emit("An old cache under a flat stone: line and hooks, three arrows, a whetstone, and a torn page.")
	_front.queue_redraw()

func _process(_delta: float) -> void:
	var p: Player = get_tree().get_first_node_in_group("player")
	if p and covers(p.global_position.x):
		Journal.note("cave", "Found a rock shelter in the foothills, east of the creek. Dry, out of the wind, and a little warmer than outside. Someone has camped here before.")

func _rock(rng: RandomNumberGenerator, a: Vector2, b: Vector2, bumps: int, amp: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in bumps + 1:
		var t := float(i) / bumps
		out.append(a.lerp(b, t) + Vector2(0, -sin(t * PI) * amp * rng.randf_range(0.6, 1.1)))
	return out

## Behind the player: the outcrop's bulk (flanks down to the ground) and the dark back wall.
func _draw() -> void:
	var h := Terrain.CAVE_HALF
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var top := _rock(rng, Vector2(-h - 420.0, 10), Vector2(h + 420.0, 10), 14, 820.0)
	draw_colored_polygon(top, Palette.ROCK.darkened(0.18))
	draw_colored_polygon(_rock(rng, Vector2(-h - 300.0, 10), Vector2(h + 260.0, 10), 10, 620.0), Palette.ROCK.darkened(0.05))
	# Back wall of the shelter, in deep shade.
	draw_colored_polygon(PackedVector2Array([Vector2(-h, 4), Vector2(-h + 40, -CEILING + 10), Vector2(h - 40, -CEILING + 20), Vector2(h, 4)]), Color(0.12, 0.11, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-h + 60, 4), Vector2(-h + 110, -CEILING + 60), Vector2(h - 90, -CEILING + 70), Vector2(h - 50, 4)]), Color(0.17, 0.15, 0.13))
	# An old fire ring and scattered bones.
	for i in 7:
		draw_circle(Vector2(-80 + i * 22.0, -5), 9.0, Palette.ROCK.darkened(0.3))
	draw_rect(Rect2(-60, -10, 80, 6), Color(0.1, 0.09, 0.08))
	draw_line(Vector2(140, -4), Vector2(186, -10), Color("d8d0bc"), 4.0)
	draw_circle(Vector2(196, -9), 6.0, Color("d8d0bc"))

## Over the player: the ceiling lip across the opening, and the shade inside.
func _draw_front() -> void:
	var h := Terrain.CAVE_HALF
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var lip := _rock(rng, Vector2(-h - 60, -CEILING - 110), Vector2(h + 60, -CEILING - 110), 12, 90.0) # ragged top, merging into the bulk
	var under := _rock(rng, Vector2(h + 40, -CEILING + 10), Vector2(-h - 40, -CEILING + 10), 9, -34.0)
	lip.append_array(under)
	_front.draw_colored_polygon(lip, Palette.ROCK.darkened(0.12))
	var night := 1.0 - GameClock.clock.daylight()
	_front.draw_colored_polygon(PackedVector2Array([Vector2(-h + 20, -CEILING + 20), Vector2(h - 20, -CEILING + 20), Vector2(h - 60, 6), Vector2(-h + 60, 6)]), Color(0.05, 0.05, 0.06, 0.32 + 0.1 * night))
	if not searched():
		_front.draw_rect(Rect2(h - 190, -26, 44, 26), Color("6b5a44")) # a weathered tin under a flat stone
		_front.draw_colored_polygon(SceneryArt.blob(Vector2(h - 168, -30), 20.0, rng, 7, 0.2), Palette.ROCK_LIGHT)
