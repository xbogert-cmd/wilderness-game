class_name Lookout extends Node2D
## The fire lookout on the summit: four timber legs, a ladder, a catwalk with a railing and a
## glassed cab. Climb it (E at the ladder) for the view: the camera pulls back over the valley
## and the whole map fills in. The cab is a sheltered place to sleep. The last keeper left
## supplies and a logbook.

const FLOOR := -780.0 ## catwalk height above the summit
const DECK := 175.0 ## catwalk half-width
const LADDER_X := 150.0
const VIEW_ZOOM := 0.5

var world: World
var chunk_index := 0
var _cache: LookoutCache
var _front: Node2D

func _ready() -> void:
	position = Vector2(Terrain.LOOKOUT_X, world.terrain.summit_y)
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("shelter")
	add_to_group("landmark")
	z_as_relative = false
	z_index = -5 # legs, ladder and cab behind the player
	var body := StaticBody2D.new()
	for seg in [[Vector2(-DECK, FLOOR), Vector2(DECK, FLOOR)], [Vector2(-DECK, FLOOR), Vector2(-DECK, FLOOR - 110)], [Vector2(DECK, FLOOR), Vector2(DECK, FLOOR - 110)]]:
		var c := CollisionShape2D.new()
		var s := SegmentShape2D.new()
		s.a = seg[0]
		s.b = seg[1]
		c.shape = s
		body.add_child(c)
	add_child(body)
	_cache = LookoutCache.new()
	_cache.lookout = self
	_cache.position = Vector2(-40, FLOOR)
	add_child(_cache)
	_front = Node2D.new()
	_front.z_as_relative = false
	_front.z_index = 9
	_front.draw.connect(_draw_rail)
	add_child(_front)

func on_top(p: Player) -> bool:
	return absf(p.global_position.x - global_position.x) < DECK + 20.0 and p.global_position.y < global_position.y + FLOOR + 60.0

## Only the cab shelters, and only when you're up in it.
func covers(x: float) -> bool:
	var p: Player = get_tree().get_first_node_in_group("player")
	return p != null and on_top(p) and absf(x - global_position.x) < DECK - 30.0

func _process(_delta: float) -> void:
	var p: Player = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var cam := get_viewport().get_camera_2d() as FollowCamera
	var up := on_top(p)
	if cam:
		cam.view_zoom = VIEW_ZOOM if up else 0.0
	if up:
		world.reveal_all()
		Journal.note("lookout", "Climbed the fire lookout on the east ridge. From the catwalk the whole valley lies open: the creek, the foothills, the rock shelter, and my own smoke, if the fire is lit. The cab is dry and out of the wind.")
	elif absf(p.global_position.x - global_position.x) < 1600.0:
		Journal.note("ridge", "Reached the summit ridge. The lookout tower stands right above me, taller than it looked from the valley.")

func interact_pos() -> Vector2:
	var p: Player = get_tree().get_first_node_in_group("player")
	return global_position + (Vector2(LADDER_X, FLOOR) if p and on_top(p) else Vector2(LADDER_X, 0))

func interact_label(p: Player) -> String:
	return "Climb down" if on_top(p) else "Climb the lookout tower"

func interact(p: Player) -> void:
	var down := on_top(p)
	p.work(2.5, 0.05, "Climbing down" if down else "Climbing the ladder", func():
		p.global_position = global_position + (Vector2(LADDER_X + 40.0, -4.0) if down else Vector2(LADDER_X - 30.0, FLOOR - 4.0))
		p.velocity = Vector2.ZERO)

## Legs, braces, ladder and the cab (behind the player).
func _draw() -> void:
	var wood := Palette.BARK
	var dark := Palette.BARK_DARK
	for sx in [-150.0, -60.0, 60.0, 150.0]: # legs, splayed toward the ground
		draw_line(Vector2(sx * 1.25, 4), Vector2(sx * 0.9, FLOOR), dark if absf(sx) < 100.0 else wood, 12.0)
	for k in 4: # cross-bracing
		var y0 := FLOOR * k / 4.0
		var y1 := FLOOR * (k + 1) / 4.0
		var w0 := lerpf(187.0, 135.0, k / 4.0)
		var w1 := lerpf(187.0, 135.0, (k + 1) / 4.0)
		draw_line(Vector2(-w0, y0), Vector2(w1, y1), dark, 5.0)
		draw_line(Vector2(w0, y0), Vector2(-w1, y1), dark, 5.0)
		draw_line(Vector2(-w1, y1), Vector2(w1, y1), wood, 6.0)
	for side in [-10.0, 10.0]: # ladder
		draw_line(Vector2(LADDER_X + side, 4), Vector2(LADDER_X + side, FLOOR), wood.lightened(0.15), 4.0)
	var y := 0.0
	while y > FLOOR:
		draw_line(Vector2(LADDER_X - 10, y), Vector2(LADDER_X + 10, y), wood.lightened(0.15), 3.0)
		y -= 34.0
	# The cab: plank walls, a band of windows, and a pyramid roof.
	var cab := Rect2(-130, FLOOR - 190, 260, 190)
	draw_rect(cab, wood.lightened(0.05))
	var night := 1.0 - GameClock.clock.daylight()
	var glass := Color(0.62, 0.72, 0.78).lerp(Color(0.12, 0.13, 0.16), night)
	draw_rect(Rect2(-118, FLOOR - 176, 236, 86), glass)
	for i in 5:
		draw_line(Vector2(-118 + i * 59.0, FLOOR - 176), Vector2(-118 + i * 59.0, FLOOR - 90), dark, 4.0)
	for i in 6:
		draw_line(Vector2(-130, FLOOR - 70 + i * 12.0), Vector2(130, FLOOR - 70 + i * 12.0), wood.darkened(0.15), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-160, FLOOR - 186), Vector2(160, FLOOR - 186), Vector2(0, FLOOR - 270)]), dark)
	draw_rect(Rect2(-DECK - 10, FLOOR - 6, (DECK + 10) * 2.0, 12), wood)
	if GameClock.weather.snow_cm > 2.0:
		draw_colored_polygon(PackedVector2Array([Vector2(-160, FLOOR - 186), Vector2(0, FLOOR - 270), Vector2(160, FLOOR - 186), Vector2(150, FLOOR - 196), Vector2(0, FLOOR - 282), Vector2(-150, FLOOR - 196)]), Color(0.94, 0.96, 0.99))

## The railing, over the player on the catwalk.
func _draw_rail() -> void:
	var wood := Palette.BARK.lightened(0.1)
	_front.draw_line(Vector2(-DECK, FLOOR - 70), Vector2(DECK, FLOOR - 70), wood, 5.0)
	_front.draw_line(Vector2(-DECK, FLOOR - 35), Vector2(DECK, FLOOR - 35), wood, 3.0)
	for i in 8:
		var x := -DECK + i * DECK * 2.0 / 7.0
		_front.draw_line(Vector2(x, FLOOR), Vector2(x, FLOOR - 70), wood, 4.0)


class LookoutCache extends Node2D:
	## The keeper's cupboard in the cab: supplies once, and the logbook.
	var lookout: Lookout

	func _ready() -> void:
		add_to_group("interactable")
		add_to_group("camp") # gets a key popup

	func _searched() -> bool:
		return lookout.world.chunk_state(lookout.chunk_index).get("lookout_searched", false)

	func interact_pos() -> Vector2:
		return global_position

	func interact_label(_p: Player) -> String:
		return "" if _searched() else "Search the keeper's cupboard"

	func interact(p: Player) -> void:
		lookout.world.chunk_state(lookout.chunk_index)["lookout_searched"] = true
		var h := GameClock.clock.hours
		for s in [ItemStack.make("jerky", h, 4), ItemStack.make("bandage", h, 2), ItemStack.make("lighter", h), ItemStack.make("arrows", h, 4)]:
			if not p.receive(s):
				lookout.world.spawn({"kind": "item", "x": p.global_position.x, "stack": s.to_dict()})
		p.message.emit("The keeper's cupboard: jerky, bandages, a lighter, arrows, and the lookout's logbook.")
		Journal.note("log_1", "Lookout logbook, first page kept: \"Sept 12. Smoke to the northwest, a lightning start. Reported. Elk bugling in the draw below the rock shelter all week.\"")
		Journal.note("log_2", "Lookout logbook: \"Oct 2. First snow on the ridge overnight, gone by noon. Creek running low and clear. Deer come up the game trail west of the tower at dusk, reliable as a clock.\"")
		Journal.note("log_3", "Lookout logbook, last entry: \"Oct 19. Lights again last night, far up the valley past the edge of the map, where nobody lives. Not fire. Relief is late. Going down to the rock shelter to wait out the storm.\" Nothing after that.")
