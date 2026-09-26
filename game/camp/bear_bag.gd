class_name BearBag extends Node2D
## A food bag hung from a tree the way backcountry travelers do it: a rope thrown over a high
## branch well out from the trunk, the bag hauled up high, the rope's end tied off round the
## trunk. The rope and bag are simulated (a chain of points under gravity, pushed by the wind),
## so the bag dangles and sways, swings harder in a gust, and bumps down as you let it out.
## At the trunk: lower it (it comes down to you), open it, haul it back up. Up high nothing gets
## it; left down on the ground it's fair game, and if the tree's felled the bag comes down with
## it. Food inside keeps like any store outdoors (it freezes in the cold).

const N := 14 ## points along the hanging rope
const RAISED := 400.0 ## how high the bag hangs when hauled up (its bottom, above the ground)
const TIE_Y := -110.0 ## where the rope's tied off round the trunk
const REEL := 150.0 ## px per second, letting it out or hauling it in
const BAG := Vector2(46, 62) ## sack size

var world: World
var store := Backpack.new()
var side := 1.0 ## which side of the trunk the branch reaches out to
var anchor := Vector2(140, -620) ## where the rope goes over the branch (local)
var lowered := false
var fallen := false ## the tree came down: the bag lies on the ground
var raided := ""
var _pts: PackedVector2Array ## local, [0] at the branch, [N-1] the bag's knot
var _old: PackedVector2Array
var _len := 0.0 ## rope let out below the branch
var _want := 0.0
var _gust := 0.0
var _t := 0.0

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	add_to_group("bear_bag")
	z_as_relative = false
	z_index = 3 # in front of the tree it hangs from
	GameClock.ticked.connect(_on_tick)

## Hangs from a tree of this height (the branch is about halfway up, well out from the trunk).
func _shape(height: float) -> void:
	anchor = Vector2(side * clampf(height * 0.12, 130.0, 170.0), -clampf(height * 0.55, 600.0, 820.0))

func load_state(d: Dictionary, elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	side = float(d.get("side", 1.0 if int(d.x) % 2 == 0 else -1.0))
	_shape(float(d.get("height", 1200.0)))
	lowered = bool(d.get("lowered", false))
	fallen = bool(d.get("fallen", false))
	raided = d.get("raided", "")
	if d.has("store"):
		store.from_dict(d.store)
	_len = _target()
	_want = _len
	_pts = PackedVector2Array()
	for i in N:
		_pts.append(anchor + Vector2(0, _len * i / (N - 1)))
	_old = _pts.duplicate()
	if elapsed > 0.0:
		_on_tick.call_deferred(elapsed)

func to_state() -> Dictionary:
	return {"kind": "bear_bag", "x": global_position.x, "side": side, "height": -anchor.y / 0.55, "lowered": lowered,
		"fallen": fallen, "store": store.to_dict(), "raided": raided}

func can_unload() -> bool:
	return true

func width() -> float:
	return 60.0 # only the trunk's footprint: it doesn't crowd the ground

## Rope needed below the branch for the bag to hang up high, or rest on the ground.
func _target() -> float:
	return (-anchor.y - (BAG.y + 6.0)) if lowered or fallen else (-anchor.y - RAISED - BAG.y)

func on_ground() -> bool:
	return fallen or (lowered and absf(_len - _target()) < 4.0)

func _on_tick(dh: float) -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	StorageChest.age(store, dh, StorageChest.keep_rate(world, global_position.x))
	if lowered or fallen: # down on the ground, anything can get at it
		var r := StorageChest.raid_check(self, store, dh)
		if r != "":
			raided = r
			queue_redraw()

## The tree this hangs from is coming down: the rope goes slack and the bag drops.
func tree_felled() -> void:
	fallen = true
	lowered = true
	_want = _target()
	_len = _want
	Journal.note("bear_bag_down", "Felled the tree my bear bag hung from. Of course the bag came down with it.")

# --- Physics -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	var p: Player = get_tree().get_first_node_in_group("player")
	if p and absf(p.global_position.x - global_position.x) > 3200.0:
		return # nobody's watching: it just hangs
	_len = move_toward(_len, _want, REEL * delta)
	if fallen:
		_len = _target()
	var seg := _len / (N - 1)
	var w := GameClock.weather
	_gust = move_toward(_gust, (sin(_t * 0.7) * 0.5 + sin(_t * 1.9 + 1.0) * 0.5) * w.wind, delta * 2.0)
	var push := Vector2(w.wind_dir * (w.wind * 90.0 + _gust * 160.0), 0.0) * (0.0 if on_ground() else 1.0)
	var ground := 0.0 # local ground under the bag
	var start := 1 if not fallen else 0
	if fallen: # the branch is gone: the rope lies across the ground from the trunk
		_pts[0] = Vector2(side * 30.0, -4.0)
	else:
		_pts[0] = anchor
	for i in range(start, N): # verlet: carry on moving, fall, get pushed by the wind
		var cur := _pts[i]
		var vel := (cur - _old[i]) * 0.985
		_old[i] = cur
		var mass := 3.0 if i == N - 1 else 1.0 # the bag is heavy; the wind moves it less
		_pts[i] = cur + vel + (Vector2(0, 900.0) + push / mass) * delta * delta
	for k in 12: # keep the links their length
		if not fallen:
			_pts[0] = anchor
		for i in N - 1:
			var a := _pts[i]
			var b := _pts[i + 1]
			var d := b - a
			var l := d.length()
			if l < 0.001:
				continue
			var diff := (l - seg) / l
			var wa := 0.0 if (i == 0 and not fallen) else 0.5
			_pts[i] += d * diff * wa
			_pts[i + 1] -= d * diff * (1.0 - wa)
		for i in N: # the ground
			var floor_y := ground - (BAG.y if i == N - 1 else 2.0)
			if _pts[i].y > floor_y:
				_pts[i].y = floor_y
				_old[i].x = lerpf(_old[i].x, _pts[i].x, 0.5) # friction
	queue_redraw()

## Where the bag's knot is, local (for checks).
func bag_pos() -> Vector2:
	return _pts[N - 1] if _pts.size() == N else anchor

# --- Using it ------------------------------------------------------------------------

func interact_pos() -> Vector2:
	return global_position

func prompt_point(_p: Player) -> Vector2:
	return global_position + Vector2(0, -160)

func interact_options(p: Player) -> Array:
	var out := []
	var n := store.entries.size()
	var what := "empty" if n == 0 else "%d item%s" % [n, "" if n == 1 else "s"]
	if fallen:
		out.append(["Open the fallen bear bag  (%s)" % what, _open.bind(p)])
	elif not lowered:
		out.append(["Lower the bear bag  (%s)" % what, _lower.bind(p)])
	elif not on_ground():
		out.append(["Letting the rope out…", Callable()])
	else:
		out.append(["Open the bear bag  (%s)" % what, _open.bind(p)])
		out.append(["Haul it back up and tie it off", _raise.bind(p)])
	return out

func interact_title(_p: Player) -> String:
	return "Bear bag"

func interact_label(p: Player) -> String:
	return Player.first_label(interact_options(p))

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

func _lower(p: Player) -> void:
	lowered = true
	_want = _target()
	p.work((_want - _len) / REEL, 0.05, "Letting the rope out", func(): pass)

func _raise(p: Player) -> void:
	lowered = false
	_want = _target()
	p.work((_len - _want) / REEL + 0.5, 0.08, "Hauling the bag up", func():
		p.message.emit("Up high and tied off: out of reach of anything that walks.")
		Journal.note("bear_bag", "Hung my food in a bear bag: a rope over a high branch, well out from the trunk, the bag hauled up out of reach and tied off. Nothing gets it up there. Left on the ground it's anyone's."))

func _open(p: Player) -> void:
	StorageChest.open_store(self, store, p)
	if raided != "":
		p.message.emit(raided)
		raided = ""

# --- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	if _pts.size() != N:
		return
	var rope := Color(0.78, 0.72, 0.58)
	if not fallen:
		var limb := anchor + Vector2(side * 36.0, -8.0)
		draw_line(Vector2(side * 8.0, anchor.y + 22.0), limb, Palette.BARK_DARK, 9.0) # the branch it's over
		draw_line(Vector2(side * 6.0, TIE_Y), anchor, rope, 2.0) # down to the tie-off
		draw_arc(Vector2(0, TIE_Y), 14.0, PI * 0.1, PI * 0.9, 8, rope, 3.0) # wrapped round the trunk
		draw_arc(Vector2(0, TIE_Y + 7.0), 14.0, PI * 0.1, PI * 0.9, 8, rope, 3.0)
	draw_polyline(_pts, rope, 2.0)
	var knot := _pts[N - 1]
	var up := (_pts[N - 2] - knot).normalized() if knot != _pts[N - 2] else Vector2.UP
	if on_ground():
		up = Vector2.UP
	var down := -up
	var across := down.orthogonal()
	var c := Color("5a6048") # canvas, waxed
	var neck := knot + down * 8.0
	var mid := knot + down * BAG.y * 0.55
	var bottom := knot + down * BAG.y
	draw_colored_polygon(PackedVector2Array([knot + across * 5.0, knot - across * 5.0, mid - across * BAG.x * 0.5,
		bottom - across * BAG.x * 0.42, bottom + across * BAG.x * 0.42, mid + across * BAG.x * 0.5]), c)
	draw_line(neck + across * 7.0, neck - across * 7.0, c.darkened(0.3), 3.0) # cinched
	draw_line(mid - across * BAG.x * 0.4, mid + across * BAG.x * 0.4, c.darkened(0.15), 1.5)
	if raided != "" and on_ground():
		for k in 3: # torn
			draw_line(mid + across * (k * 6.0 - 6.0), bottom + across * (k * 5.0 - 2.0), Color(0.2, 0.18, 0.15), 2.0)
	if GameClock.weather.snow_cm > 2.0 and not on_ground():
		draw_line(knot + across * 6.0 + down * 10.0, knot - across * 6.0 + down * 10.0, Color(0.94, 0.96, 0.99), 4.0)
