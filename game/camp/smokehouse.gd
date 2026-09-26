class_name Smokehouse extends Node2D
## A little plank shed with a smudge fire on the floor. Hang raw meat and fish on the racks
## inside, keep the smudge fed with sticks, and in about ten hours of smoke it's smoked meat or
## fish that keeps for well over a month. It smokes in any weather (it's roofed), holds more
## than the drying rack, and what hangs in it doesn't spoil. Smoke drifts from the roof vent
## while the fire's going. Catches up on hours spent away.

const SLOTS := 12
const SMOKE_HOURS := 10.0
const HOURS_PER_STICK := 3.0
const MAX_FUEL := 24.0
const SMOKABLE := ["venison_raw", "rabbit_raw", "trout_raw", "whitefish_raw"]

var world: World
var pieces: Array = [] ## [raw id, hours smoked]
var fuel := 0.0 ## hours of smudge left
var _smoke: CPUParticles2D

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	z_as_relative = false
	z_index = 2
	GameClock.ticked.connect(_on_tick)
	_smoke = CPUParticles2D.new()
	_smoke.amount = 26
	_smoke.lifetime = 5.0
	_smoke.position = Vector2(0, -236)
	_smoke.direction = Vector2(0, -1)
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 25.0
	_smoke.initial_velocity_max = 45.0
	_smoke.scale_amount_min = 1.0
	_smoke.scale_amount_max = 2.6
	_smoke.color = Color(0.72, 0.72, 0.7, 0.28)
	_smoke.texture = Underground.light_texture() # soft round puffs
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	_smoke.color_ramp = fade
	add_child(_smoke)

func load_state(d: Dictionary, elapsed: float) -> void:
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	pieces = d.get("pieces", []).map(func(p): return [str(p[0]), float(p[1])])
	fuel = float(d.get("fuel", 0.0))
	_on_tick(elapsed)

func to_state() -> Dictionary:
	return {"kind": "smokehouse", "x": global_position.x, "pieces": pieces, "fuel": fuel}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.smokehouse.width

func smoking() -> bool:
	return fuel > 0.0 and pieces.any(func(p): return p[1] < SMOKE_HOURS)

func _on_tick(dh: float) -> void:
	if smoking():
		var t := minf(dh, fuel)
		fuel -= t
		for p in pieces:
			p[1] = minf(p[1] + t, SMOKE_HOURS)
		if smoked() > 0:
			Journal.note("smoked", "The smokehouse works: ten hours of slow smoke and the meat comes out dark and dry. It keeps for well over a month.")
	queue_redraw()

func _process(_delta: float) -> void:
	_smoke.emitting = smoking()
	if _smoke.emitting:
		queue_redraw() # the coals flicker
	_smoke.gravity = Vector2(GameClock.weather.wind_dir * GameClock.weather.wind * 60.0, -8.0) # leans with the wind

func smoked() -> int:
	return pieces.filter(func(p): return p[1] >= SMOKE_HOURS).size()

static func product(raw_id: String) -> String:
	return "smoked_fish" if raw_id in ["trout_raw", "whitefish_raw"] else "smoked_meat"

func interact_pos() -> Vector2:
	return global_position

func prompt_point(_p: Player) -> Vector2:
	return global_position + Vector2(0, -250)

func _raw(p: Player) -> ItemStack:
	if p.held and p.held.def.id in SMOKABLE:
		return p.held
	return p.backpack.find(func(s): return s.def.id in SMOKABLE)

func interact_options(p: Player) -> Array:
	var out := []
	var raw := _raw(p)
	var room := SLOTS - pieces.size()
	if raw and room > 0:
		out.append(["Hang %d %s in the smoke  (%d/%d)" % [mini(raw.count, room), raw.def.name.to_lower(), pieces.size(), SLOTS], _hang.bind(p, raw)])
	if smoked() > 0:
		out.append(["Take the smoked meat and fish  (%d)" % smoked(), _take.bind(p)])
	var sticks := p.backpack.count_of("sticks")
	if fuel < MAX_FUEL - HOURS_PER_STICK:
		if sticks > 0:
			out.append(["Feed the smudge fire  (a stick smokes %d h; %d h of smoke left)" % [int(HOURS_PER_STICK), ceili(fuel)], _feed.bind(p)])
		else:
			out.append(["The smudge needs sticks  (%d h of smoke left)" % ceili(fuel), Callable()])
	if out.is_empty() or (pieces.is_empty() and raw == null):
		out.append([interact_title(p) + "  (bring raw meat or fish)", Callable()])
	return out

func interact_title(_p: Player) -> String:
	if pieces.is_empty():
		return "Smokehouse"
	var left: float = SMOKE_HOURS - pieces.map(func(p): return p[1]).min()
	if left <= 0.0:
		return "Smokehouse  (%d smoked)" % pieces.size()
	return "Smokehouse  (%d hanging, %s)" % [pieces.size(), "about %d h to go" % ceili(left) if fuel > 0.0 else "the fire's out"]

func interact_label(p: Player) -> String:
	return Player.first_label(interact_options(p))

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

func _hang(p: Player, raw: ItemStack) -> void:
	var n := mini(raw.count, SLOTS - pieces.size())
	for i in n:
		pieces.append([raw.def.id, 0.0])
	raw.count -= n
	if raw.count <= 0:
		if p.held == raw:
			p.held = null
		else:
			p.backpack.remove(raw)
	if fuel <= 0.0:
		p.message.emit("Hung up. Now it needs smoke: feed the smudge fire with sticks.")
	queue_redraw()

func _feed(p: Player) -> void:
	var n := mini(p.backpack.count_of("sticks"), int((MAX_FUEL - fuel) / HOURS_PER_STICK))
	if n > 0 and p.backpack.take("sticks", n):
		fuel += n * HOURS_PER_STICK
		p.message.emit("You bank %d stick%s on the smudge. Thick smoke curls up through the racks." % [n, "" if n == 1 else "s"])
		queue_redraw()

func _take(p: Player) -> void:
	for id in ["smoked_meat", "smoked_fish"]:
		var ready := pieces.filter(func(pc): return pc[1] >= SMOKE_HOURS and product(pc[0]) == id)
		if ready and p.receive(ItemStack.make(id, GameClock.clock.hours, ready.size())):
			pieces = pieces.filter(func(pc): return not ready.has(pc))
	queue_redraw()

func _draw() -> void:
	var plank := Palette.BARK.lightened(0.08)
	var dark := Palette.BARK_DARK
	var w := 150.0
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5, -170), Vector2(0, -215), Vector2(-w * 0.5, -170)]), plank)
	for k in 7: # vertical boards
		var x := -w * 0.5 + 10.0 + k * (w - 20.0) / 6.0
		draw_line(Vector2(x, 0), Vector2(x, -175 - (40.0 - absf(x) * 0.53)), plank.darkened(0.18), 1.5)
	draw_polyline(PackedVector2Array([Vector2(-w * 0.5 - 14, -164), Vector2(0, -222), Vector2(w * 0.5 + 14, -164)]), dark, 9.0) # roof
	draw_rect(Rect2(-14, -236, 28, 18), dark) # the vent
	draw_rect(Rect2(-18, -240, 36, 6), dark.lightened(0.1))
	draw_rect(Rect2(-34, -120, 68, 120), plank.darkened(0.3)) # door
	draw_line(Vector2(-34, -60), Vector2(34, -60), dark, 3.0)
	if smoking(): # coals glowing under the door
		var f := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004)
		draw_rect(Rect2(-30, -8, 60, 6), Color(1.0, 0.45, 0.12, 0.5 + 0.3 * f))
	for i in mini(pieces.size(), 6): # what's hanging shows over the half-door
		var k: float = pieces[i][1] / SMOKE_HOURS
		var fish: bool = pieces[i][0] in ["trout_raw", "whitefish_raw"]
		var c := (Color("b0a080") if fish else Color("a64a3f")).lerp(Color("5a3420"), k)
		var x := -26.0 + i * 10.4
		draw_line(Vector2(x, -118), Vector2(x, -104), Color(0.3, 0.26, 0.22), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, -104), Vector2(x + 4, -104), Vector2(x + 3, -80), Vector2(x - 3, -83)]), c)
	if GameClock.weather.snow_cm > 2.0:
		draw_polyline(PackedVector2Array([Vector2(-w * 0.5 - 12, -170), Vector2(0, -228), Vector2(w * 0.5 + 12, -170)]), Color(0.94, 0.96, 0.99), 6.0)
