class_name RaisedCache extends Node2D
## A food cache up on four tall posts, the way trappers kept meat through the winter: a roofed
## box on a deck well out of reach of bears and wolves, with a pole ladder up one side. Climb
## the ladder (E), stand on the deck, open the box; climb back down or just hop off (S). Food
## in it is never raided, and in the cold it freezes and keeps.

const DECK_Y := -280.0 ## the deck, above the ground
const HALF := 95.0 ## half the deck's width
const LADDER_X := -HALF - 18.0

var world: World
var store := Backpack.new()

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	add_to_group("deck")
	z_as_relative = false
	z_index = 2
	GameClock.ticked.connect(_on_tick)
	var body := StaticBody2D.new() # the deck: stand on it, drop through it with S
	body.collision_layer = 1 << (Underground.PLATFORM_LAYER - 1)
	body.collision_mask = 0
	var c := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(-HALF, DECK_Y)
	seg.b = Vector2(HALF, DECK_Y)
	c.shape = seg
	c.one_way_collision = true
	body.add_child(c)
	add_child(body)

func load_state(d: Dictionary, elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	if d.has("store"):
		store.from_dict(d.store)
	if elapsed > 0.0:
		_on_tick(elapsed)

func to_state() -> Dictionary:
	return {"kind": "cache", "x": global_position.x, "store": store.to_dict()}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.cache.width

func _on_tick(dh: float) -> void:
	StorageChest.age(store, dh, StorageChest.keep_rate(world, global_position.x))

## The deck's height at x (world), if near_y is up there; NAN otherwise.
func deck_at(x: float, near_y: float) -> float:
	var y := global_position.y + DECK_Y
	return y if absf(x - global_position.x) <= HALF + 4.0 and absf(near_y - y) < 70.0 else NAN

func up_top(p: Player) -> bool:
	return p.global_position.y < global_position.y + DECK_Y + 40.0 and absf(p.global_position.x - global_position.x) < HALF + 30.0

func interact_pos() -> Vector2:
	var p: Player = get_tree().get_first_node_in_group("player")
	if p and up_top(p):
		return global_position + Vector2(0, DECK_Y)
	return global_position + Vector2(LADDER_X, 0)

func prompt_point(p: Player) -> Vector2:
	return interact_pos() + Vector2(0, -120 if up_top(p) else -60)

func interact_options(p: Player) -> Array:
	if up_top(p):
		var n := store.entries.size()
		return [["Open the cache  (%s)" % ("empty" if n == 0 else "%d item%s" % [n, "" if n == 1 else "s"]), StorageChest.open_store.bind(self, store, p)],
			["Climb down the ladder  (or %s to hop off)" % Keys.label("move_down"), _down.bind(p)]]
	return [["Climb up to the cache", _up.bind(p)]]

func interact_title(_p: Player) -> String:
	return "Raised cache"

func interact_label(p: Player) -> String:
	return Player.first_label(interact_options(p))

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

func _up(p: Player) -> void:
	if p.carrying or p.hauling or p.pulling:
		p.message.emit("Not with your hands full.")
		return
	var g := global_position
	var top := g.y + DECK_Y - 2.0
	p.climb(PackedVector2Array([p.global_position, Vector2(g.x + LADDER_X, g.y - 2.0), Vector2(g.x + LADDER_X, top), Vector2(g.x + LADDER_X + 60.0, top)]))
	Journal.note("cache", "Built a raised cache: a box on tall posts, out of reach. Food up there is safe from bears and wolves, and in the cold it freezes and keeps.")

func _down(p: Player) -> void:
	var g := global_position
	var top := g.y + DECK_Y - 2.0
	p.climb(PackedVector2Array([p.global_position, Vector2(g.x + LADDER_X, top), Vector2(g.x + LADDER_X, g.y - 2.0), Vector2(g.x + LADDER_X - 50.0, world.terrain.height_at(g.x + LADDER_X - 50.0) - 2.0)]))

func _draw() -> void:
	var post := Palette.BARK_DARK
	var wood := Palette.BARK.lightened(0.1)
	for sx in [-HALF + 14.0, HALF - 14.0, -HALF + 40.0, HALF - 40.0]: # four posts (two behind)
		var back := absf(sx) < HALF - 20.0
		draw_line(Vector2(sx, 6), Vector2(sx, DECK_Y), post.darkened(0.2 if back else 0.0), 9.0 if not back else 7.0)
	for sx in [-HALF + 14.0, HALF - 14.0]: # tin wrapped round the posts: nothing climbs past it
		draw_rect(Rect2(sx - 6, -150, 12, 34), Color("9aa0a6"))
	draw_rect(Rect2(-HALF - 6, DECK_Y - 4, HALF * 2.0 + 12.0, 12), wood) # deck
	draw_rect(Rect2(-HALF + 20, DECK_Y - 100, HALF * 2.0 - 40.0, 96), wood.darkened(0.1)) # the box
	for y in [DECK_Y - 70.0, DECK_Y - 40.0]:
		draw_line(Vector2(-HALF + 20, y), Vector2(HALF - 20, y), post, 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-HALF + 6, DECK_Y - 98), Vector2(0, DECK_Y - 140), Vector2(HALF - 6, DECK_Y - 98)]), post) # roof
	draw_rect(Rect2(-18, DECK_Y - 76, 36, 56), wood.darkened(0.25)) # door
	# the ladder: two poles and rungs
	for lx in [LADDER_X - 12.0, LADDER_X + 12.0]:
		draw_line(Vector2(lx, 6), Vector2(lx, DECK_Y - 10.0), post, 5.0)
	var y := -20.0
	while y > DECK_Y:
		draw_line(Vector2(LADDER_X - 12.0, y), Vector2(LADDER_X + 12.0, y), post, 4.0)
		y -= 34.0
	if GameClock.weather.snow_cm > 2.0:
		draw_polyline(PackedVector2Array([Vector2(-HALF + 4, DECK_Y - 100), Vector2(0, DECK_Y - 146), Vector2(HALF - 4, DECK_Y - 100)]), Color(0.94, 0.96, 0.99), 6.0)
		draw_rect(Rect2(-HALF - 6, DECK_Y - 9, HALF * 2.0 + 12.0, 5), Color(0.94, 0.96, 0.99))
