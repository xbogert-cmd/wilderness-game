class_name Snare extends Node2D
## A cord noose on a spring stick, set from the build menu. Rabbits run into it, mostly around
## dawn and dusk; check it and take what's caught. A rabbit left hanging is scent for wolves,
## and out past camp it's often gone before you're back: the snare sprung, a tuft of fur.

const CATCH_PER_HOUR := 0.07
const TAKEN_PER_HOUR := 0.06 ## a caught rabbit, away from camp and unwatched

var world: World
var caught := false
var sprung := false ## robbed: reset it before it can catch again

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	add_to_group("food_scent")
	z_as_relative = false
	z_index = 3
	GameClock.ticked.connect(_advance)

func load_state(d: Dictionary, elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	caught = bool(d.get("caught", false))
	sprung = bool(d.get("sprung", false))
	if elapsed > 0.0:
		_advance.call_deferred(elapsed) # once the rest of the chunk (a campfire, say) is back
	queue_redraw()

func to_state() -> Dictionary:
	return {"kind": "snare", "x": global_position.x, "caught": caught, "sprung": sprung}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.snare.width

func _advance(dh: float) -> void:
	if sprung or dh <= 0.0 or is_queued_for_deletion():
		return
	if not caught:
		var h := GameClock.clock.hour_of_day()
		var rate := CATCH_PER_HOUR * (2.2 if (h > 4.0 and h < 9.0) or (h > 17.0 and h < 22.0) else 1.0) * (0.6 if GameClock.clock.season() == 3 else 1.0)
		if randf() < 1.0 - exp(-rate * dh):
			caught = true
			queue_redraw()
		return
	var p: Player = get_tree().get_first_node_in_group("player")
	var watched := p != null and absf(p.global_position.x - global_position.x) < 1200.0
	if not watched and not Predator.safe_at(get_tree(), global_position.x) and randf() < 1.0 - exp(-TAKEN_PER_HOUR * dh):
		gnaw(1.0, "wolf")

func appeals(kind: String) -> bool:
	return caught and kind == "wolf"

func gnaw(_amount: float, _kind: String) -> bool:
	if caught:
		caught = false
		sprung = true
		for k in 3:
			world.tracks.add(global_position.x + (k - 1) * 60.0, "wolf", 1 if k % 2 == 0 else -1)
		queue_redraw()
	return false

func interact_pos() -> Vector2:
	return global_position

func interact_title(_p: Player) -> String:
	if caught:
		return "Snare  (a rabbit!)"
	return "Snare  (sprung: a tuft of fur, and tracks)" if sprung else "Snare  (set)"

func interact_options(p: Player) -> Array:
	var out := []
	if caught:
		out.append(["Take the rabbit", _take.bind(p)])
	if sprung:
		out.append(["Reset the snare", _reset])
	out.append(["Pick up the snare", _pick_up.bind(p)])
	return out

func _take(p: Player) -> void:
	if p.receive(ItemStack.make("rabbit_raw", GameClock.clock.hours)):
		caught = false
		queue_redraw()

func _reset() -> void:
	sprung = false
	queue_redraw()

func _pick_up(p: Player) -> void:
	if caught:
		_take(p)
	if p.receive(ItemStack.make("snare", GameClock.clock.hours)):
		queue_free()

func interact_label(p: Player) -> String:
	return Player.first_label(interact_options(p))

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

func _draw() -> void:
	var stick := Palette.BARK_DARK
	var cord := Color("b8b08a")
	draw_line(Vector2(-14, 4), Vector2(-10, -26), stick, 4.0) # peg
	if sprung:
		draw_line(Vector2(6, 4), Vector2(14, -70), stick, 3.0) # the spring stick, released
		for k in 3:
			draw_circle(Vector2(-4 + k * 9, -3), 3.0, Color("9a8a78"))
		return
	var top := Vector2(28, -62) if caught else Vector2(4, -30)
	draw_polyline(PackedVector2Array([Vector2(24, 4), Vector2(30, -30), top]), stick, 3.0) # bent sapling
	if caught:
		draw_line(top, top + Vector2(0, 20), cord, 1.5)
		var b := top + Vector2(0, 36) # a rabbit hanging by the neck
		draw_colored_polygon(PackedVector2Array([b + Vector2(-8, -14), b + Vector2(8, -14), b + Vector2(10, 12), b + Vector2(-9, 14)]), Color("9a8a78"))
		draw_circle(b + Vector2(0, -16), 7.0, Color("9a8a78"))
		draw_line(b + Vector2(-2, -22), b + Vector2(-5, -34), Color("8a7a68"), 3.0)
		draw_circle(b + Vector2(0, 14), 4.0, Color("e8e2d6"))
	else:
		draw_arc(Vector2(-2, -12), 11.0, 0.0, TAU, 12, cord, 1.5) # the noose, set
		draw_line(top, Vector2(-2, -23), cord, 1.2)
