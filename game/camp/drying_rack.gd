class_name DryingRack extends Node2D
## Poles and a crossbar for drying meat and fish into jerky that keeps for weeks. Strips
## darken as they dry; drying is faster beside a fire and stalls in the rain. Hanging meat
## doesn't spoil. Catches up on hours spent away.

const SLOTS := 8
const DRY_HOURS := 12.0
const FIRE_REACH := 420.0
const DRYABLE := ["venison_raw", "trout_raw", "whitefish_raw", "salmon_raw", "grayling_raw", "catfish_raw", "perch_raw"]

var world: World
var pieces: Array = [] ## hours dried, one per strip

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
	pieces = d.get("pieces", []).map(func(h): return float(h))
	_on_tick(elapsed)

func to_state() -> Dictionary:
	return {"kind": "drying_rack", "x": global_position.x, "pieces": pieces}

func can_unload() -> bool:
	return true

func width() -> float:
	return Builds.STRUCTURES.drying_rack.width

func _rate() -> float:
	var r := 1.0
	for f in get_tree().get_nodes_in_group("heat"):
		if f is Campfire and f.lit and absf(f.global_position.x - global_position.x) < FIRE_REACH:
			r = 1.6 # smoke and warmth
	if not world.sheltered_at(global_position.x):
		r *= 1.0 - 0.85 * GameClock.weather.rain()
	return r

func _on_tick(dh: float) -> void:
	if pieces.is_empty():
		return
	var r := _rate()
	for i in pieces.size():
		pieces[i] = minf(pieces[i] + dh * r, DRY_HOURS)
	queue_redraw()

func dried() -> int:
	return pieces.filter(func(h): return h >= DRY_HOURS).size()

func interact_pos() -> Vector2:
	return global_position

func prompt_point(_p: Player) -> Vector2:
	return global_position + Vector2(0, -175)

func _raw(p: Player) -> ItemStack:
	return p.held if p.held and p.held.def.id in DRYABLE else null

## Raw meat or fish in the pack: carried back from the field, it goes straight up.
func _packed(p: Player) -> ItemStack:
	return p.backpack.find(func(s): return s.def.id in DRYABLE)

func interact_options(p: Player) -> Array:
	var out := []
	var raw := _raw(p)
	var room := SLOTS - pieces.size()
	if raw and room > 0:
		out.append(["Hang %s to dry  (%d/%d)" % [raw.def.name.to_lower(), pieces.size(), SLOTS], _hang.bind(p, raw)])
	if dried() > 0:
		out.append(["Take jerky  (%d)" % dried(), _take.bind(p)])
	var packed := _packed(p)
	if packed and room > 0:
		out.append(["Hang %d %s from your pack" % [mini(packed.count, room), packed.def.name.to_lower()], _hang.bind(p, packed)])
	if out.is_empty():
		out.append([interact_title(p) + "  (bring raw meat or fish)" if pieces.is_empty() else interact_title(p), Callable()])
	return out

func interact_title(_p: Player) -> String:
	if pieces.is_empty():
		return "Drying rack"
	var left: float = DRY_HOURS - pieces.max()
	return "Drying rack  (%d strips, about %d h to go)" % [pieces.size(), ceili(left / maxf(_rate(), 0.2))] if left > 0.0 else "Drying rack  (%d strips, dry)" % pieces.size()

func interact_label(p: Player) -> String:
	return Player.first_label(interact_options(p))

func interact(p: Player) -> void:
	Player.run_first(interact_options(p))

func _hang(p: Player, raw: ItemStack) -> void:
	var n := mini(raw.count, SLOTS - pieces.size())
	for i in n:
		pieces.append(0.0)
	raw.count -= n
	if raw.count <= 0:
		if p.held == raw:
			p.held = null
		else:
			p.backpack.remove(raw)
	queue_redraw()

func _take(p: Player) -> void:
	var k := dried()
	if k > 0 and p.receive(ItemStack.make("jerky", GameClock.clock.hours, k)):
		pieces = pieces.filter(func(h): return h < DRY_HOURS)
		queue_redraw()

func _draw() -> void:
	var post := Palette.BARK_DARK
	var half := width() * 0.5 - 10.0
	for sx in [-half, half]:
		draw_line(Vector2(sx, 4), Vector2(sx * 0.8, -150), post, 7.0)
	draw_line(Vector2(-half, -140), Vector2(half, -140), Palette.BARK, 6.0)
	draw_line(Vector2(-half, -95), Vector2(half, -95), Palette.BARK, 5.0)
	for i in pieces.size():
		var k: float = pieces[i] / DRY_HOURS
		var c := Color("a64a3f").lerp(Color("4a2a1e"), k) # red and wet to dark and dry
		var x := -half + 18.0 + i * (half * 2.0 - 36.0) / (SLOTS - 1)
		var bar := -140.0 if i % 2 == 0 else -95.0
		var len := 38.0 * (1.0 - 0.25 * k) # strips shrink as they dry
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, bar + 2), Vector2(x + 5, bar + 2), Vector2(x + 3, bar + len), Vector2(x - 4, bar + len - 3)]), c)
