class_name HideFrame extends Node2D
## Two posts and a crossbar. A raw hide or pelt laced onto it cures over the next day into
## soft tanned leather or fur; the colour follows its progress. Catches up on hours spent away.

const STRETCH_SECONDS := 3.0
const STRETCH_HOURS := 0.5
const CURE_HOURS := 18.0
## raw -> [cured item, hours to cure, name, colour raw, colour cured]
const KINDS := {
	"deer_hide": ["hide", 18.0, "deer hide", Color("946b59"), Color("bd9e73")],
	"wolf_pelt": ["wolf_fur", 18.0, "wolf pelt", Color("6e6860"), Color("9a938a")],
	"coyote_pelt": ["coyote_fur", 14.0, "coyote pelt", Color("8f7a5c"), Color("c7ad87")],
	"bear_hide": ["bear_fur", 30.0, "bear hide", Color("4a3526"), Color("5e4431")],
}

var world: World
var curing := false
var cured := 0.0 ## hours so far
var kind := "deer_hide" ## what's laced on

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
	kind = d.get("hide", "deer_hide")
	_on_tick(elapsed)

func to_state() -> Dictionary:
	return {"kind": "hide_frame", "x": global_position.x, "curing": curing, "cured": cured, "hide": kind}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.hide_frame.width

func cure_hours() -> float:
	return KINDS[kind][1]

func done() -> bool:
	return curing and cured >= cure_hours()

func _on_tick(dh: float) -> void:
	if curing and cured < cure_hours():
		cured = minf(cured + dh, cure_hours())
		queue_redraw()

func interact_pos() -> Vector2:
	return global_position

func prompt_point(_p: Player) -> Vector2:
	return global_position + Vector2(0, -200)

func _raw(p: Player, id: String) -> ItemStack:
	if p.held and p.held.def.id == id:
		return p.held
	return p.backpack.find(func(s): return s.def.id == id)

func interact_options(p: Player) -> Array:
	if done():
		return [["Take the " + Items.get_def(KINDS[kind][0]).name.to_lower(), _take.bind(p)]]
	if curing:
		return [["%s curing  (%d h to go)" % [KINDS[kind][2].capitalize(), ceili(cure_hours() - cured)], Callable()]]
	var out := []
	for id in KINDS:
		var raw := _raw(p, id)
		if raw:
			out.append(["Stretch the %s" % KINDS[id][2], _stretch.bind(p, raw)])
	if out.is_empty():
		out.append(["Hide frame  (bring a raw hide or pelt)", Callable()])
	return out

func interact_title(_p: Player) -> String:
	return "Hide frame"

func interact_label(p: Player) -> String:
	return Player.first_label(interact_options(p))

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

func _take(p: Player) -> void:
	if p.receive(ItemStack.make(KINDS[kind][0], GameClock.clock.hours)):
		curing = false
		cured = 0.0
		queue_redraw()

func _stretch(p: Player, raw: ItemStack) -> void:
	if raw.freshness(GameClock.clock.hours) == ItemStack.Fresh.SPOILED:
		p.message.emit("This hide has rotted. It's no good now.")
		return
	if p.held == raw:
		p.held = null
	else:
		p.backpack.take(raw.def.id, 1)
	p.work(STRETCH_SECONDS, STRETCH_HOURS, "Lacing and scraping the hide", func():
		kind = raw.def.id
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
	var k := cured / cure_hours()
	var c: Color = KINDS[kind][3].lerp(KINDS[kind][4], k) # raw to cured
	var hide := PackedVector2Array([Vector2(-40, -160), Vector2(-10, -150), Vector2(22, -162), Vector2(44, -150),
		Vector2(40, -100), Vector2(46, -52), Vector2(16, -42), Vector2(-14, -48), Vector2(-44, -40), Vector2(-38, -100)])
	draw_colored_polygon(hide, c)
	for p in hide: # lacing to the frame
		var edge := Vector2(signf(p.x) * 56.0, p.y) if absf(p.x) > 30.0 else Vector2(p.x, -170.0 if p.y < -100.0 else -30.0)
		draw_line(p, edge, Color(0.25, 0.2, 0.15), 1.2)
