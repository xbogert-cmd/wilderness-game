class_name Animal extends Node2D
## Generic animal brain: routine (graze, wander, bed down) plus awareness built from what it
## hears and sees. Enough awareness makes it stop and look; more makes it bolt away. It calms
## once it has put flee_distance between itself and the threat. It never chases.

enum State { GRAZE, WALK, BEDDED, ALERT, FLEE }
const STATE_NAMES: PackedStringArray = ["graze", "walk", "bedded", "alert", "flee"]
const EDGE := 700.0

var def: SpeciesDef
var world: World
var player: Player
var tracks: Tracks
var state: int = State.GRAZE
var awareness := 0.0
var facing := 1
var speed := 0.0
var home_x := 0.0
var _timer := 0.0
var _since_print := 0.0
var _rng := RandomNumberGenerator.new()

func setup(species: SpeciesDef, x: float, seed_value: int) -> void:
	def = species
	_rng.seed = seed_value
	home_x = x
	position = Vector2(x, 0)
	facing = 1 if _rng.randf() < 0.5 else -1
	state = State.GRAZE if _active() else State.BEDDED
	_timer = _rng.randf_range(2.0, 8.0)

func _ready() -> void:
	add_to_group("animals")
	z_index = -4 # in the plane, behind the player
	var rig: Node2D = DeerRig.new()
	rig.animal = self
	add_child(rig)

func _active() -> bool:
	var h := GameClock.clock.hour_of_day()
	for r in def.active_hours:
		if h >= r.x and h < r.y:
			return true
	return false

func _physics_process(delta: float) -> void:
	_perceive(delta)
	match state:
		State.GRAZE, State.BEDDED, State.ALERT:
			speed = move_toward(speed, 0.0, 400.0 * delta)
		State.WALK:
			speed = def.walk_speed
		State.FLEE:
			speed = move_toward(speed, def.flee_speed, 900.0 * delta)
			facing = 1 if position.x >= player.global_position.x else -1
	_timer -= delta
	if _timer <= 0.0:
		_routine()
	var step := speed * facing * delta
	var nx := clampf(position.x + step, EDGE, Terrain.WORLD_W - EDGE)
	if nx != position.x + step and state == State.FLEE:
		facing = -facing # cornered against the ridge: break past rather than freeze
	position.x = nx
	position.y = world.terrain.height_at(position.x)
	_since_print += absf(step)
	if _since_print > def.stride:
		_since_print = 0.0
		tracks.add(position.x + facing * 20.0, def.track, facing)
		tracks.add(position.x - facing * 35.0, def.track, facing)
		if state == State.FLEE:
			Sfx.play_at(self, global_position, Sfx.hoof(), -6.0, 1.5)

func _routine() -> void:
	_timer = _rng.randf_range(3.0, 9.0)
	match state:
		State.GRAZE:
			if not _active():
				state = State.BEDDED
			elif _rng.randf() < 0.5:
				state = State.WALK
				var toward_home := signf(home_x - position.x)
				facing = int(toward_home) if absf(home_x - position.x) > def.home_range and toward_home != 0.0 else (1 if _rng.randf() < 0.5 else -1)
		State.WALK:
			state = State.GRAZE
		State.BEDDED:
			if _active():
				state = State.GRAZE
		State.ALERT:
			if awareness < def.alert_at * 0.6:
				state = State.GRAZE

## Loud or visible players raise awareness; silence and stillness let it decay.
func _perceive(delta: float) -> void:
	var d := absf(player.global_position.x - position.x)
	var stim := 0.0
	var heard := player.noise() * def.hearing
	if heard > d:
		stim += (1.0 - d / heard) * 3.0
	var looking := facing == int(signf(player.global_position.x - position.x))
	var sight := def.sight * player.visibility() * (0.35 + 0.65 * GameClock.clock.daylight())
	sight *= (0.45 if state in [State.GRAZE, State.BEDDED] else 1.0) * (1.0 if looking else 0.55)
	if d < sight:
		stim += (1.0 - d / sight) * 2.0
	if state == State.FLEE:
		awareness = maxf(awareness - (0.5 if d > def.flee_distance else 0.0) * delta, 0.0)
		if awareness < def.alert_at * 0.6:
			state = State.WALK
			home_x = position.x # settles into a new area instead of returning straight away
			_timer = _rng.randf_range(3.0, 6.0)
		return
	awareness = awareness + stim * delta if stim > 0.0 else maxf(awareness - 0.12 * delta, 0.0)
	if awareness >= def.flee_at:
		bolt()
	elif awareness >= def.alert_at and state != State.ALERT:
		state = State.ALERT
		facing = int(signf(player.global_position.x - position.x))
		_timer = _rng.randf_range(4.0, 8.0)

func bolt(alarm := true) -> void:
	if state == State.FLEE:
		return
	if alarm: # the first to spot you snorts a warning; the rest just run
		Sfx.play_at(self, global_position + Vector2(facing * 60.0, -140.0), Sfx.snort(), 0.0)
	state = State.FLEE
	awareness = def.flee_at * 1.3
	for other in get_tree().get_nodes_in_group("animals"): # the herd follows the first to bolt
		if other != self and other.def == def and absf(other.position.x - position.x) < 900.0:
			other.bolt.call_deferred(false)
