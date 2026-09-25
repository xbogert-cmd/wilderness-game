class_name HideFrame extends Node2D
## Two posts and a crossbar. A raw hide laced onto it cures over the next day into soft
## tanned hide; the colour follows its progress. Catches up on hours spent away.

const STRETCH_SECONDS := 3.0
const STRETCH_HOURS := 0.5
const CURE_HOURS := 18.0

var world: World
var curing := false
var cured := 0.0 ## hours so far

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	z_as_relative = false
	z_index = 2
	GameClock.ticked.connect(_on_tick)

func load_state(d: Dictionary, elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	curing = bool(d.get("curing", false))
	cured = float(d.get("cured", 0.0))
	_on_tick(elapsed)

func to_state() -> Dictionary:
	return {"kind": "hide_frame", "x": global_position.x, "curing": curing, "cured": cured}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.hide_frame.width

func done() -> bool:
	return curing and cured >= CURE_HOURS

func _on_tick(dh: float) -> void:
	if curing and cured < CURE_HOURS:
		cured = minf(cured + dh, CURE_HOURS)
		queue_redraw()

func interact_pos() -> Vector2:
	return global_position

func prompt_point(_p: Player) -> Vector2:
	return global_position + Vector2(0, -200)

func _raw_hide(p: Player) -> ItemStack:
	if p.held and p.held.def.id == "deer_hide":
		return p.held
	return p.backpack.find(func(s): return s.def.id == "deer_hide")

func interact_label(p: Player) -> String:
	if done():
		return "Take the tanned hide"
	if curing:
		return "Hide curing  (%d h to go)" % ceili(CURE_HOURS - cured)
	if _raw_hide(p):
		return "Stretch the deer hide"
	return "Hide frame  (bring a raw deer hide)"

func interact(p: Player) -> void:
	if done():
		if p.receive(ItemStack.make("hide", GameClock.clock.hours)):
			curing = false
			cured = 0.0
			queue_redraw()
		return
	if curing:
		return
	var raw := _raw_hide(p)
	if raw == null:
		return
	if raw.freshness(GameClock.clock.hours) == ItemStack.Fresh.SPOILED:
		p.message.emit("This hide has rotted. It's no good now.")
		return
	if p.held == raw:
		p.held = null
	else:
		p.backpack.take("deer_hide", 1)
	p.work(STRETCH_SECONDS, STRETCH_HOURS, "Lacing and scraping the hide", func():
		curing = true
		cured = 0.0
		queue_redraw())

func _draw() -> void:
	var post := Palette.BARK_DARK
	draw_line(Vector2(-60, 4), Vector2(-56, -180), post, 8.0)
	draw_line(Vector2(60, 4), Vector2(56, -180), post, 8.0)
	draw_line(Vector2(-66, -170), Vector2(66, -170), Palette.BARK, 7.0)
	draw_line(Vector2(-62, -30), Vector2(62, -30), Palette.BARK, 6.0)
	if not curing:
		return
	var k := cured / CURE_HOURS
	var c := Color("946b59").lerp(Color("bd9e73"), k) # raw pink-brown to buckskin
	var hide := PackedVector2Array([Vector2(-40, -160), Vector2(-10, -150), Vector2(22, -162), Vector2(44, -150),
		Vector2(40, -100), Vector2(46, -52), Vector2(16, -42), Vector2(-14, -48), Vector2(-44, -40), Vector2(-38, -100)])
	draw_colored_polygon(hide, c)
	for p in hide: # lacing to the frame
		var edge := Vector2(signf(p.x) * 56.0, p.y) if absf(p.x) > 30.0 else Vector2(p.x, -170.0 if p.y < -100.0 else -30.0)
		draw_line(p, edge, Color(0.25, 0.2, 0.15), 1.2)
