class_name StorageChest extends Node2D
## A lidded log chest for keeping gear at camp. E opens it beside the pack: drag between them.
## Holds a pack-sized grid. Food in it keeps better in the cold (frozen solid below zero).
## Left out away from camp, a chest with food in it gets raided: the bear, in its country and
## out of its den, tears in and takes all of it; elsewhere mice and packrats get at some. Food
## that has to be left away from camp belongs up off the ground: a raised cache or a bear bag.
## variety "shelves" is the root cellar's shelves: cool all year, and nothing gets in.

const RAID_BEAR := 0.03 ## chance per hour, food left out in bear country (not in winter)
const RAID_CRITTER := 0.01 ## chance per hour anywhere else (half that in winter)
const QUIET_R := 2000.0 ## nothing raids with you this close

var world: World
var store := Backpack.new()
var variety := "chest" ## "chest", or "shelves" (the root cellar)
var raided := "" ## what happened while you were away, told when you next open it
var _below := NAN ## y down in the cellar (NAN: on the ground)

func _ready() -> void:
	add_to_group("persist")
	add_to_group("chest")
	z_as_relative = false
	z_index = 2
	GameClock.ticked.connect(_on_tick)

func load_state(d: Dictionary, elapsed: float) -> void:
	variety = d.get("variety", "chest")
	if variety == "chest": # (the cellar shelves are opened from the shelves themselves)
		add_to_group("interactable")
		add_to_group("camp") # gets a key popup
		add_to_group("structure")
	_below = float(d.get("y", NAN))
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)) if is_nan(_below) else _below)
	if d.has("store"):
		store.from_dict(d.store)
	raided = d.get("raided", "")
	if elapsed > 0.0:
		_on_tick.call_deferred(elapsed) # once the camp around it has loaded too

func to_state() -> Dictionary:
	var d := {"kind": "chest", "variety": variety, "x": global_position.x, "store": store.to_dict(), "raided": raided}
	if not is_nan(_below):
		d.y = global_position.y
	return d

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.chest.width

func _on_tick(dh: float) -> void:
	if not is_instance_valid(self) or is_queued_for_deletion() or store.entries.is_empty():
		return
	age(store, dh, keep_rate(world, global_position.x, variety == "shelves"))
	if variety == "chest":
		var r := raid_check(self, store, dh)
		if r != "":
			raided = r

## How fast food spoils in a store here, as a share of the usual: the cold keeps it.
static func keep_rate(w: World, x: float, cellar := false) -> float:
	var t := GameClock.weather.air_temp_c(GameClock.clock) + Terrain.temp_offset(x)
	var r := 1.0
	if t <= -2.0:
		r = 0.2 # frozen
	elif t < 4.0:
		r = 0.5
	elif t < 10.0:
		r = 0.8
	return minf(r, 0.35) if cellar else r

## Food in a store ages at rate (1 = as usual) over dh hours.
static func age(s: Backpack, dh: float, rate: float) -> void:
	if rate >= 1.0:
		return
	for st in s.all_stacks():
		if st.def.spoil_hours > 0.0:
			st.made_hour += dh * (1.0 - rate)

## Something might get into food stored at x over dh hours (nothing does near camp or with you
## close by). Returns a note on what happened, or "".
static func raid_check(n: Node2D, s: Backpack, dh: float) -> String:
	var foods := s.all_stacks().filter(func(st): return st.def.food > 0.0 and not st.def.id in ["tinned_beans", "preserves"])
	if foods.is_empty():
		return ""
	var x := n.global_position.x
	var p: Player = n.get_tree().get_first_node_in_group("player")
	if Predator.safe_at(n.get_tree(), x) or (p and absf(p.global_position.x - x) < QUIET_R):
		return ""
	var winter := GameClock.clock.season() == 3
	var bear_country := x > Wildlife.BEAR_RANGE.x - 2500.0 and x < Wildlife.BEAR_RANGE.y + 2500.0 and not winter
	var rate := RAID_BEAR if bear_country else RAID_CRITTER * (0.5 if winter else 1.0)
	if randf() >= 1.0 - pow(1.0 - rate, dh):
		return ""
	if bear_country:
		for st in foods:
			s.remove(st)
		var w: World = n.get("world")
		for k in 8:
			w.tracks.add(x + (k - 4) * 60.0, "bear", 1 if k % 2 == 0 else -1)
		Journal.note("raid", "A bear got into food I'd left out: the lid torn open, the food gone, tracks all round. Food left away from camp has to be up off the ground, on a raised cache or hung in a bear bag.")
		return "The lid's been torn half off. Claw marks, bear tracks all round, and every bit of food gone."
	var st: ItemStack = foods[randi() % foods.size()]
	var lost := maxi(1, st.count / 2)
	if lost >= st.count:
		s.remove(st)
	else:
		st.count -= lost
	Journal.note("raid_small", "Mice or packrats got into food I left out. Food left away from camp keeps better up off the ground: a raised cache, or a bag hung from a branch.")
	return "Droppings and gnawed wrappings: something small has been at the %s." % st.def.name.to_lower()

func interact_pos() -> Vector2:
	return global_position

func interact_label(_p: Player) -> String:
	var n := store.entries.size()
	return "Open the chest  (%s)%s" % ["empty" if n == 0 else "%d item%s" % [n, "" if n == 1 else "s"], "  · something's been at it" if raided != "" else ""]

func interact(p: Player) -> void:
	open_store(self, store, p)
	if raided != "":
		p.message.emit(raided)
		raided = ""
		queue_redraw()

## Opens a store beside the pack.
static func open_store(n: Node, s: Backpack, _p: Player) -> void:
	var ui: BackpackUI = n.get_tree().get_first_node_in_group("backpack_ui")
	if ui and not ui.visible:
		ui.storage = s
		ui.toggle()

func _draw() -> void:
	if variety != "chest":
		return
	var wood := Palette.BARK.lightened(0.1)
	draw_rect(Rect2(-50, -52, 100, 52), wood)
	for y in [-40.0, -26.0, -12.0]:
		draw_line(Vector2(-50, y), Vector2(50, y), Palette.BARK_DARK, 1.5)
	if raided.begins_with("The lid"): # torn half off
		draw_set_transform(Vector2(40, -62), 0.5)
		draw_rect(Rect2(-94, 0, 108, 12), wood.darkened(0.15))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		for k in 3:
			draw_line(Vector2(-30 + k * 9, -48), Vector2(-20 + k * 9, -20), Palette.BARK_DARK.darkened(0.3), 2.0) # claw marks
	else:
		draw_rect(Rect2(-54, -62, 108, 12), wood.darkened(0.15)) # lid
		for sx in [-38.0, 38.0]: # strap hinges
			draw_rect(Rect2(sx - 4, -62, 8, 62), Color(0.3, 0.26, 0.22))
		draw_rect(Rect2(-6, -54, 12, 10), Color("9aa0a6")) # hasp
	if GameClock.weather.snow_cm > 2.0:
		draw_rect(Rect2(-56, -68, 112, 7), Color(0.94, 0.96, 0.99))
