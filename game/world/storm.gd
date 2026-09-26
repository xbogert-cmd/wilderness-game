class_name Storm extends Node2D
## Weather you can read coming, and lightning. Before a storm the wind backs and the birds go
## quiet (Ambience), and thunder mutters far off before a thunderstorm. In one, lightning
## flashes and the thunder comes after it, later the farther off it struck; now and then it
## strikes close, and a tall tree nearby catches in the crown (TreeFire). Says so when fog
## comes down, a chinook starts, or the creeks come up.

static var flash := 0.0 ## 0..1: lightning lighting everything up (Atmosphere reads it)
const SOUND_PX_PER_SEC := 5000.0 ## how fast the thunder comes (sped up, like the world)
const NEAR := 1300.0 ## a close strike lands this far either side of you, at most

var player: Player
var world: World
var _next := 8.0 ## real seconds to the next strike
var _bolt: PackedVector2Array
var _bolt_t := 0.0
var _rng := RandomNumberGenerator.new()
var _said := {} ## which signs have been told for the weather now
var _pending: Array = [] ## thunder on its way: [seconds, stream, volume_db]

func _ready() -> void:
	_rng.randomize()
	z_as_relative = false
	z_index = 29

func _process(delta: float) -> void:
	flash = maxf(flash - delta * 3.5, 0.0)
	_bolt_t = maxf(_bolt_t - delta, 0.0)
	if _bolt_t <= 0.0 and not _bolt.is_empty():
		_bolt.clear()
		queue_redraw()
	for t in _pending:
		t[0] -= delta
		if t[0] <= 0.0:
			_boom(t[1], t[2])
	_pending = _pending.filter(func(t): return t[0] > 0.0)
	var w := GameClock.weather
	if w.thunder_far() and not player.dead:
		_next -= delta
		if _next <= 0.0:
			_next = _rng.randf_range(6.0, 20.0) if w.thunderstorm() else _rng.randf_range(15.0, 40.0)
			strike(w.thunderstorm() and _rng.randf() < 0.3 and player.under < 0.5)
	_signs(w)

## A lightning strike: close by (maybe setting a tree alight), or somewhere off in the storm.
func strike(near: bool, at_x := INF) -> void:
	var muffle := -14.0 * player.under # heard through rock
	if near:
		var x := at_x if at_x != INF else player.global_position.x + _rng.randf_range(-NEAR, NEAR)
		var tree := _tallest_near(x)
		var hit := Vector2(x, world.terrain.height_at(x))
		if tree:
			hit = tree.global_position + Vector2(0, -tree.height * 0.9)
			if not get_tree().get_nodes_in_group("heat").any(func(h): return h is TreeFire and absf(h.global_position.x - tree.global_position.x) < 200.0):
				var f := TreeFire.new()
				f.height = tree.height
				f.left = _rng.randf_range(1.0, 2.2)
				world.add_child(f)
				f.global_position = tree.global_position
		_make_bolt(hit)
		flash = 1.0
		_boom(Sfx.thunder_near(), 2.0 + muffle)
		return
	var d := _rng.randf_range(3000.0, 26000.0)
	if GameClock.weather.thunderstorm() or GameClock.clock.daylight() < 0.3: # far off, you see it flicker at night
		flash = maxf(flash, lerpf(0.55, 0.1, d / 26000.0) * (1.0 - player.under))
	_pending.append([d / SOUND_PX_PER_SEC, Sfx.thunder_far(), -4.0 - d / 2600.0 + muffle])

func _boom(stream: AudioStream, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = &"Weather"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## Lightning takes the tallest thing about: the tallest standing tree near x.
func _tallest_near(x: float) -> ChoppableTree:
	var best: ChoppableTree = null
	for t: ChoppableTree in get_tree().get_nodes_in_group("choppable"):
		if absf(t.global_position.x - x) < 500.0 and (best == null or t.height > best.height):
			best = t
	return best

func _make_bolt(to: Vector2) -> void:
	_bolt = PackedVector2Array()
	var from := Vector2(to.x + _rng.randf_range(-250.0, 250.0), player.global_position.y - 1500.0)
	var n := 14
	for i in n + 1:
		var k := float(i) / n
		var p := from.lerp(to, k)
		if i > 0 and i < n:
			p.x += _rng.randf_range(-60.0, 60.0)
		_bolt.append(p)
	_bolt_t = 0.22
	queue_redraw()

func _draw() -> void:
	if _bolt.size() < 2:
		return
	draw_polyline(_bolt, Color(0.75, 0.8, 1.0, 0.45), 14.0)
	draw_polyline(_bolt, Color(1, 1, 1), 4.0)

## Tell the player what they can see and feel coming, once each time.
func _signs(w: Weather) -> void:
	var x := player.global_position.x
	var cold := w.air_temp_c(GameClock.clock) < -2.0 # (a blizzard coming has its own tip)
	var warn := w.storm_warning() and not cold
	_sign("warn", warn, not warn, "Thunderheads are piling up and the birds have gone quiet. A storm's coming: find cover." if w.next_thunder \
		else "The wind's backing round and the sky's thickening. The birds have gone quiet: rain's coming.")
	_sign("lightning", w.thunderstorm(), not w.thunderstorm(), "Lightning! Keep off open ground and away from the tallest trees.")
	var fog := Terrain.fog_at(x) * (1.0 - player.under)
	_sign("fog", fog > 0.45, fog < 0.15, "Fog's come down. You can hardly see a stone's throw. Animals are just shapes in it, and so are you.")
	_sign("chinook", w.chinook > 0.0, w.chinook <= 0.0, "A warm wind's roaring down off the ridge: a chinook. The snow's going fast, and so will the ice. Mind the creeks.")
	_sign("flood", w.flood >= Weather.WADE_FLOOD, w.flood < 0.3, "The creeks are up: brown water bank to bank. No wading them till they drop.")
	if w.chinook > 0.0:
		Journal.note("chinook", "A chinook came down off the mountains in the dead of winter: a warm, roaring wind, and the snow went like smoke. The old-timers call it the snow-eater. Thin ice and high water after it.")
	if w.thunderstorm():
		Journal.note("lightning", "Thunderstorm. You can tell how far off the lightning is by counting to the thunder. It goes for the tallest thing about.")

## Says `text` once when `on` turns true; ready to say it again once `off`.
func _sign(key: String, on: bool, off: bool, text: String) -> void:
	if on and not _said.get(key, false):
		_said[key] = true
		player.message.emit(text)
	elif off:
		_said[key] = false
