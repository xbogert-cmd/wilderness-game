class_name Carcass extends Node2D
## A downed animal. A deer can be butchered where it lies (hide and as much meat as the pack
## holds; the rest waits on the carcass) or dragged home whole. Butchering leaves a gut pile.
## Anything left out draws scavengers: ravens first, then wolves (and the bear), which eat what
## they find unless it's at camp. Wolves and bears are skinned for their pelts.
## Meat ages from the moment of the kill. Left alone, a carcass is gone after a few days.

const DRESS_SECONDS := 4.0
const DRESS_HOURS := 0.75
const MEAT := 6.0 ## cuts of venison on a deer
const GONE_AFTER := 72.0
const SCAVENGED_PER_HOUR := 0.35 ## cuts lost per hour left out, unwatched, away from camp
const DRAG_OFFSET := 125.0

var world: World
var species := "mule_deer"
var facing := 1
var hour := 0.0 ## when it was killed
var arrows := 0
var meat := MEAT
var dressed := false ## butchered: meat and hide taken, gut pile left
var torn := false ## scavengers got into it: the hide is ruined
var skinned := false
var hauler: Player ## dragging it
var _ravens: Ravens

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup, like cutting a felled trunk
	add_to_group("food_scent")
	add_to_group("carcass")
	z_as_relative = false
	z_index = 3
	_ravens = Ravens.new()
	_ravens.since = hour
	add_child(_ravens)

func _enter_tree() -> void:
	match species:
		"wolf": Journal.note("first_wolf", "Killed a wolf. The pelt will make winter gear, once it's cured on the frame.")
		"black_bear": Journal.note("first_bear", "Brought down the bear. Its hide is the warmest thing in this valley, if I can cure it.")
		_: Journal.note("first_kill", "Took my first deer. Meat for days if I can keep it from spoiling, and a hide worth curing.")

func deer() -> bool:
	return species == "mule_deer"

func load_state(d: Dictionary, elapsed: float) -> void:
	species = d.species
	facing = int(d.facing)
	hour = float(d.hour)
	arrows = int(d.get("arrows", 0))
	meat = float(d.get("meat", MEAT if deer() else 0.0))
	dressed = bool(d.get("dressed", false))
	torn = bool(d.get("torn", false))
	skinned = bool(d.get("skinned", false))
	global_position = Vector2(float(d.x), world.ground_y(float(d.x)))
	if _ravens:
		_ravens.since = hour
	if GameClock.clock.hours - hour > GONE_AFTER:
		queue_free()
	elif elapsed > 1.0:
		_scavenge.call_deferred(elapsed) # once the rest of the chunk (a campfire, say) is back
	queue_redraw()

## Hours nobody was here: wolves and ravens had it, unless it lay at camp.
func _scavenge(elapsed: float) -> void:
	if is_queued_for_deletion() or Predator.safe_at(get_tree(), global_position.x) or meat <= 0.0:
		return
	gnaw(elapsed * SCAVENGED_PER_HOUR, "wolf")
	for k in 6:
		world.tracks.add(global_position.x + (k - 3) * 55.0, "wolf", 1 if k % 2 == 0 else -1)

func to_state() -> Dictionary:
	return {"kind": "carcass", "x": global_position.x, "facing": facing, "species": species, "hour": hour,
		"arrows": arrows, "meat": meat, "dressed": dressed, "torn": torn, "skinned": skinned}

func can_unload() -> bool:
	return hauler == null

## Scavengers: anything with meat on it.
func appeals(_kind: String) -> bool:
	return meat > 0.05 and hauler == null

## Eaten at by a scavenger. Returns false once there's nothing left.
func gnaw(amount: float, _kind: String) -> bool:
	if meat <= 0.0:
		return false
	meat = maxf(meat - amount, 0.0)
	if not dressed:
		torn = true
	queue_redraw()
	return meat > 0.0

func interact_pos() -> Vector2:
	return global_position + Vector2(0, -30)

static func has_knife(p: Player) -> bool:
	return p.backpack.count_of("knife") > 0 or (p.held != null and p.held.def.has("knife"))

func _name() -> String:
	return {"wolf": "wolf", "black_bear": "bear"}.get(species, "deer")

func interact_title(_p: Player) -> String:
	if deer():
		if meat <= 0.0:
			return "Deer carcass  (picked clean)"
		return "Deer carcass  (%d cuts left%s)" % [floori(meat), ", torn by scavengers" if torn and not dressed else ""] if dressed or torn else "Mule deer"
	return "Dead " + _name()

func interact_options(p: Player) -> Array:
	if hauler:
		return [["Let go of the " + _name(), p.drop_haul]]
	var knife := has_knife(p)
	var out := []
	if deer():
		if not dressed:
			out.append(["Butcher it here" if knife else "Butcher it (needs a knife)", _butcher.bind(p) if knife else Callable()])
		elif meat >= 1.0:
			out.append(["Take the rest of the meat  (%d)" % floori(meat), _take_meat.bind(p)])
	elif not skinned:
		out.append(["Skin the " + _name() if knife else "Skin it (needs a knife)", _skin.bind(p) if knife else Callable()])
	if species != "black_bear" and p.carrying == null and (meat >= 1.0 or not dressed):
		out.append(["Drag it", p.start_haul.bind(self)])
	if out.is_empty():
		out.append([interact_title(p), Callable()])
	return out

func interact_label(p: Player) -> String:
	return Player.first_label(interact_options(p))

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

func _give(p: Player, s: ItemStack, side: float) -> void:
	if not p.receive(s):
		world.spawn({"kind": "item", "x": global_position.x + side * 40.0, "stack": s.to_dict()})

func _butcher(p: Player) -> void:
	p.work(DRESS_SECONDS, DRESS_HOURS, "Butchering", func():
		dressed = true
		if torn:
			p.message.emit("Scavengers have been at it. The hide is torn and no good.")
		else:
			_give(p, ItemStack.make("deer_hide", hour), -1.0) # rots unless it gets onto a hide frame
		if arrows > 0:
			p.receive(ItemStack.make("arrows", GameClock.clock.hours, arrows))
			arrows = 0
		world.spawn({"kind": "gut_pile", "x": global_position.x - facing * 90.0, "hour": GameClock.clock.hours})
		_take_meat(p)
		queue_redraw())

## As many cuts as the pack holds, straight into it; the rest stays here.
func _take_meat(p: Player) -> void:
	if meat < 1.0:
		p.message.emit("Nothing left on it worth taking.")
		queue_free()
		return
	var packed := 0
	while meat >= 1.0:
		if not p.backpack.add(ItemStack.make("venison_raw", hour)): # ages from the kill
			break
		meat -= 1.0
		packed += 1
	if meat >= 1.0:
		p.message.emit("Packed %d cuts of venison. No room for the other %d: they're still on the carcass." % [packed, floori(meat)])
	else:
		p.message.emit("Packed %d cuts of venison." % packed)
		meat = 0.0
		queue_free()

func _skin(p: Player) -> void:
	var bear := species == "black_bear"
	p.work(5.0 if bear else 3.5, 1.5 if bear else 0.6, "Skinning the " + _name(), func():
		_give(p, ItemStack.make("bear_hide" if bear else "wolf_pelt", hour), -1.0)
		if arrows > 0:
			p.receive(ItemStack.make("arrows", GameClock.clock.hours, arrows))
		skinned = true
		queue_free())

## Dragged by the neck, head toward the player.
func grip() -> Vector2:
	return global_position + Vector2(facing * 95.0, -14.0)

func _physics_process(_delta: float) -> void:
	if hauler == null:
		return
	facing = hauler.facing
	var x := hauler.global_position.x - facing * DRAG_OFFSET
	global_position = Vector2(x, world.ground_y(x))

func _def() -> SpeciesDef:
	for d: SpeciesDef in Wildlife.SPECIES + Wildlife.PREDATORS:
		if d.id == species:
			return d
	return Wildlife.SPECIES[0]

## Lying on its side, legs out toward facing. Butchered: what's left of the meat, then bones.
func _draw() -> void:
	var d := _def()
	_ravens.visible = meat > 0.05 and hauler == null
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0) * d.size)
	if not deer():
		PredatorRig.draw_dead(self, d, skinned)
	elif dressed or meat <= 0.0:
		_remains(d)
	else:
		_deer(d)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _deer(d: SpeciesDef) -> void:
	for k in 2:
		var hip := Vector2(-40 + k * 70, -18)
		draw_line(hip, hip + Vector2(34, 10), d.body_color.darkened(0.3), 8.0)
		draw_line(hip + Vector2(34, 10), hip + Vector2(60, 12), d.body_color.darkened(0.3), 5.0)
	var body := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		body.append(Vector2(cos(a) * 64.0 - 6.0, sin(a) * 22.0 - 22.0))
	draw_colored_polygon(body, d.body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -6), Vector2(40, -8), Vector2(30, -2), Vector2(-30, -1)]), d.belly_color)
	if torn: # opened up by scavengers
		draw_colored_polygon(PackedVector2Array([Vector2(-20, -30), Vector2(26, -34), Vector2(30, -14), Vector2(-16, -10)]), Color("8a2e26"))
	draw_circle(Vector2(-62, -24), 11.0, d.rump_color)
	draw_line(Vector2(50, -24), Vector2(84, -10), d.body_color, 14.0) # neck along the ground
	draw_circle(Vector2(90, -9), 10.0, d.body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(96, -16), Vector2(116, -8), Vector2(96, -2)]), d.body_color)
	draw_circle(Vector2(116, -7), 3.5, d.dark_color)
	draw_colored_polygon(PackedVector2Array([Vector2(84, -16), Vector2(74, -34), Vector2(90, -18)]), d.body_color.darkened(0.15))
	for i in arrows:
		var at := Vector2(10 - i * 18, -34)
		draw_line(at, at + Vector2(-16, -30), Color("b0966b"), 2.0)
		draw_line(at + Vector2(-14, -26), at + Vector2(-18, -32), Color("d8d0c0"), 4.0)

## Ribs, the head and legs, and a quarter of meat for every cut still on it.
func _remains(d: SpeciesDef) -> void:
	var bone := Color("d8d0bc")
	draw_line(Vector2(-50, -8), Vector2(46, -10), bone, 5.0) # spine
	for i in 7:
		var x := -30.0 + i * 11.0
		draw_arc(Vector2(x, -8), 16.0, PI * 1.05, PI * 1.95, 6, bone, 3.0)
	draw_line(Vector2(50, -10), Vector2(84, -6), d.body_color.darkened(0.2), 10.0)
	draw_circle(Vector2(90, -7), 9.0, d.body_color.darkened(0.1))
	for k in 2:
		draw_line(Vector2(-40 + k * 70, -6), Vector2(-6 + k * 70, 4), d.body_color.darkened(0.3), 5.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in ceili(meat):
		var c := Vector2(-40 + i * 16.0, -18.0 - (i % 2) * 8.0)
		draw_colored_polygon(SceneryArt.blob(c, 12.0, rng, 7, 0.25), Color("8e3a30").darkened(0.1 * (i % 3)))
