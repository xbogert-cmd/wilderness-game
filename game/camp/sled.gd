class_name Sled extends Node2D
## A pull sled: runners and slats, built at camp. Load it with logs (up to four), a whole
## carcass, or gear (a pack-sized load), and pull it behind you. It glides over snow and
## drags on bare ground. E for the choices; F lets go.

const MAX_LOGS := 4
const OFFSET := 150.0 ## behind the puller

var world: World
var logs: Array = [] ## log sizes, loaded
var carcass := {} ## a whole carcass's state, loaded
var store := Backpack.new()
var puller: Player

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # key popup and choices
	add_to_group("sled")
	add_to_group("chest") # its load counts for crafting nearby, like a chest
	z_as_relative = false
	z_index = 3

func load_state(d: Dictionary, _elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.ground_y(float(d.x)))
	logs = d.get("logs", []).duplicate()
	carcass = d.get("carcass", {}).duplicate(true)
	if d.has("store"):
		store.from_dict(d.store)
	queue_redraw()

func to_state() -> Dictionary:
	return {"kind": "sled", "x": global_position.x, "logs": logs, "carcass": carcass, "store": store.to_dict()}

func can_unload() -> bool:
	return puller == null

## Over snow it runs nearly at a walk; on bare ground it drags, more so loaded.
func speed_mult() -> float:
	var load := logs.size() * 0.06 + (0.12 if carcass else 0.0)
	return (0.88 if GameClock.weather.snow_cm > 5.0 else 0.55) - load

func interact_pos() -> Vector2:
	return global_position + Vector2(0, -20)

func interact_title(_p: Player) -> String:
	var bits: PackedStringArray = []
	if logs:
		bits.append("%d log%s" % [logs.size(), "" if logs.size() == 1 else "s"])
	if carcass:
		bits.append("a " + ("deer" if carcass.species == "mule_deer" else carcass.species.replace("black_", "")))
	if store.entries:
		bits.append("gear")
	return "Sled  (%s)" % (", ".join(bits) if bits else "empty")

func interact_options(p: Player) -> Array:
	if puller:
		return [["Let go of the sled", p.drop_haul]]
	var out := []
	if p.carrying and logs.size() < MAX_LOGS:
		out.append(["Load the %s log" % p.carrying.size, _load_log.bind(p)])
	if p.hauling and not carcass:
		out.append(["Load the carcass", _load_carcass.bind(p)])
	if p.carrying == null and p.hauling == null:
		out.append(["Pull the sled", p.start_pull.bind(self)])
	if logs and p.carrying == null and p.hauling == null:
		out.append(["Unload a %s log" % logs[-1], _unload_log.bind(p)])
	if carcass and p.hauling == null:
		out.append(["Unload the carcass", _unload_carcass])
	out.append(["Open the load", _open])
	return out

func interact_label(p: Player) -> String:
	return Player.first_label(interact_options(p))

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

func _load_log(p: Player) -> void:
	var lg := p.carrying
	p.drop_carried()
	logs.append(lg.size)
	lg.queue_free()
	queue_redraw()

func _unload_log(p: Player) -> void:
	var size: String = logs.pop_back()
	var lg := world.spawn({"kind": "log", "size": size, "x": global_position.x, "y": global_position.y - 70.0}) as WorldLog
	p.carrying = lg
	lg.pick_up(p)
	queue_redraw()

func _load_carcass(p: Player) -> void:
	var c := p.hauling
	p.drop_haul()
	carcass = c.to_state()
	c.queue_free()
	queue_redraw()

func _unload_carcass() -> void:
	var d := carcass.duplicate(true)
	d.x = global_position.x + 170.0
	world.spawn(d)
	carcass = {}
	queue_redraw()

func _open() -> void:
	var ui: BackpackUI = get_tree().get_first_node_in_group("backpack_ui")
	if ui and not ui.visible:
		ui.storage = store
		ui.toggle()

func _physics_process(_delta: float) -> void:
	if puller == null:
		return
	var x := puller.global_position.x - puller.facing * OFFSET
	global_position = Vector2(x, world.ground_y(x))
	scale.x = puller.facing
	queue_redraw()

func _draw() -> void:
	var wood := Palette.BARK.lightened(0.12)
	# Runners curling up at the front (toward the puller), slats, a tow rope.
	draw_line(Vector2(-90, -4), Vector2(80, -4), wood.darkened(0.25), 6.0)
	draw_arc(Vector2(80, -26), 22.0, PI * 0.5, -PI * 0.4, 8, wood.darkened(0.25), 6.0)
	for k in 6:
		var x := -80.0 + k * 30.0
		draw_line(Vector2(x, -4), Vector2(x, -18), wood.darkened(0.1), 4.0)
	draw_rect(Rect2(-92, -24, 176, 8), wood)
	if puller:
		var hand := puller.global_position + Vector2(0, -95) - global_position
		hand.x *= scale.x
		draw_line(Vector2(96, -40), hand, Color("b8b08a"), 2.0)
	var y := -26.0
	for i in logs.size(): # logs stacked end-on on the deck
		var r := 14.0
		var c := Vector2(-60.0 + (i % 2) * 30.0, y - r - (i / 2) * 24.0)
		draw_circle(c, r, Palette.BARK)
		draw_circle(c, r - 4.0, Color("d9b98a"))
	if carcass:
		var d: SpeciesDef = Wildlife.SPECIES[0]
		for s in Wildlife.SPECIES + Wildlife.PREDATORS:
			if s.id == carcass.species:
				d = s
		var body := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			body.append(Vector2(10 + cos(a) * 60.0, y - 18.0 + sin(a) * 18.0))
		draw_colored_polygon(body, d.body_color)
		draw_line(Vector2(66, y - 20), Vector2(96, y - 8), d.body_color, 10.0)
	if store.entries: # a lashed bundle of gear
		draw_rect(Rect2(20, y - 30, 50, 30), Palette.BEDROLL.darkened(0.2))
		draw_line(Vector2(20, y - 15), Vector2(70, y - 15), Color("b8b08a"), 2.0)
