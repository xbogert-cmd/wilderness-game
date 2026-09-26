class_name Fishing extends Node2D
## One fishing session: cast → wait (watch the bobber) → hook when it plunges → reel (FishFight).
## Every step runs off the same click, so the player only needs to read the water.

enum State { IDLE, CAST, WAIT, BITE, REEL }
const CAST_TIME := 0.6
const MIN_CAST := 140.0
const MAX_CAST := 520.0

var player: Player
var world: World
var state: int = State.IDLE
var fight: FishFight
var bobber := Vector2.ZERO
var _from := Vector2.ZERO
var _t := 0.0
var _wait := 0.0
var _species := "trout"
var _nibble := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 8
	_rng.randomize()

func tip() -> Vector2:
	return player.global_position + Vector2(player.facing * 108.0, -225.0)

func press() -> void:
	match state:
		State.IDLE: _cast()
		State.WAIT: _reel_in("You reel in an empty line.")
		State.BITE: _hook()
		State.REEL: _strike()

func _cast() -> void:
	var aim := player.aim_point().x
	var dist := clampf((aim - player.global_position.x) * player.facing, MIN_CAST, MAX_CAST)
	var x := player.global_position.x + player.facing * dist
	var s := world.terrain.water_surface_at(x)
	if s == INF:
		player.message.emit("Cast toward open water.")
		return
	var creek := Creek.at(get_tree(), x)
	if creek and not creek.w().fish:
		player.message.emit("Nothing but minnows in this %s." % creek.kind())
		return
	if Creek.frozen() and not (creek and creek.hole_open()):
		player.message.emit("The %s is frozen. Chop a hole in the ice first." % (creek.kind() if creek else "water"))
		return
	if player.wade_depth > 60.0:
		player.message.emit("Too deep to cast from here.")
		return
	player.swing = 0.0 # the overhead cast reuses the tool swing
	state = State.CAST
	_t = 0.0
	_from = tip()
	bobber = Vector2(x, s)
	var depth := world.terrain.height_at(x) - s
	_species = "trout" if _rng.randf() < (0.7 if depth > 70.0 else 0.35) else "whitefish"
	_wait = -log(1.0 - _rng.randf() * 0.98) * GameClock.tuning.bite_mean_sec * _conditions() # exponential: most bites come soon, a few make you wait

## <1 = fish bite sooner. Dawn and dusk feed best; overcast and drizzle help; cold seasons slow.
func _conditions() -> float:
	var h := GameClock.clock.hour_of_day()
	var k := 1.3
	if (h > 5.0 and h < 9.0) or (h > 17.5 and h < 21.0): k = 0.6
	elif h < 5.0 or h > 21.0: k = 1.6
	match GameClock.weather.kind:
		Weather.Kind.OVERCAST, Weather.Kind.DRIZZLE: k *= 0.8
		Weather.Kind.RAIN: k *= 1.15
	return k * [0.9, 0.85, 1.0, 2.0][GameClock.clock.season()]

func force_bite(species := "") -> void: ## for scripted checks
	if species != "":
		_species = species
	_wait = 0.0

func _hook() -> void:
	state = State.REEL
	fight = FishFight.new(_species, _rng.randi(), GameClock.tuning.fishing_ease)
	player.message.emit("Hooked! Strike when the needle is in the green.")

func _strike() -> void:
	match fight.strike():
		FishFight.Result.LANDED:
			var cm := fight.length_cm()
			var fish := ItemStack.make(fight.spec.item, GameClock.clock.hours)
			Sfx.play_at(self, bobber, Sfx.splash(), -2.0)
			_reel_in("Landed a %d cm %s." % [cm, fight.spec.name])
			player.receive(fish)
		FishFight.Result.ESCAPED:
			_reel_in("The %s throws the hook." % fight.spec.name)

func _reel_in(msg: String) -> void:
	state = State.IDLE
	fight = null
	player.message.emit(msg)

func _process(delta: float) -> void:
	var rod := player.held != null and player.held.def.has("rod")
	if state != State.IDLE and (not rod or player.dead or player.sleeping or absf(player.velocity.x) > 5.0):
		_reel_in("You reel in.")
	match state:
		State.CAST:
			_t += delta
			if _t >= CAST_TIME:
				state = State.WAIT
		State.WAIT:
			_wait -= delta
			_nibble = maxf(_nibble - delta, 0.0)
			if _rng.randf() < 0.25 * delta:
				_nibble = 0.35 # a fake-out twitch: read the water
			if _wait <= 0.0:
				state = State.BITE
				_t = 0.0
				Sfx.play_at(self, bobber, Sfx.splash(), -10.0, 1.3)
		State.BITE:
			_t += delta
			if _t > GameClock.tuning.hook_window_sec:
				state = State.WAIT
				_wait = _rng.randf_range(4.0, 12.0)
				player.message.emit("It stole the bait. Wait for the next bite.")
		State.REEL:
			fight.step(delta)
	queue_redraw()

func _bobber_pos() -> Vector2:
	match state:
		State.CAST:
			var k := _t / CAST_TIME
			return _from.lerp(bobber, k) + Vector2(0, -sin(k * PI) * 160.0)
		State.BITE:
			return bobber + Vector2(0, 10.0 + sin(_t * 40.0) * 3.0)
		State.REEL:
			return bobber + Vector2(sin(Time.get_ticks_msec() * 0.02) * 6.0, 8.0)
	return bobber + Vector2(0, sin(Time.get_ticks_msec() * 0.003) * 1.5 + _nibble * 12.0)

func _draw() -> void:
	if state == State.IDLE:
		return
	var a := tip()
	var b := _bobber_pos()
	var sag := (a + b) * 0.5 + Vector2(0, 40.0 if state == State.WAIT else 10.0)
	var line := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		line.append(a.lerp(sag, k).lerp(sag.lerp(b, k), k))
	draw_polyline(line, Color(0.9, 0.9, 0.85, 0.6), 1.2)
	draw_circle(b + Vector2(0, -3), 5.0, Color("d8d4c8"))
	draw_circle(b + Vector2(0, -6), 3.5, Color("c0392b"))
	if state == State.BITE:
		for r in [14.0, 26.0]:
			draw_arc(bobber, r + fmod(_t * 40.0, 12.0), PI, TAU, 16, Color(1, 1, 1, 0.5), 1.5)
		draw_string(ThemeDB.fallback_font, bobber + Vector2(-6, -40), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 0.92, 0.6))
