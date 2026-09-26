class_name Animal extends Node2D
## Generic animal brain: routine (graze, wander, bed down) plus awareness built from what it
## hears and sees. Enough awareness makes it stop and look; more makes it bolt away. It calms
## once it has put flee_distance between itself and the threat. It never chases.
## A deer that's been spooked leaves the area: it keeps going away from where it was scared and
## is let go once out of sight, and it keeps clear of camps, where people are.
## Hunting: shot() wounds it (it runs, bleeds, then drops); kill() takes it outright.
## Wolves hunt it too: hunted() sets it running from them; deep snow bogs it down, and a deer a
## chase is going to end for tires; taken() is the end, a torn carcass for the pack.

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
var bed_x := NAN ## game trail ends (NAN: no trail, wander around home_x)
var feed_x := NAN
var _calls := [] ## hours of recent calls heard, to grow wary of a caller
var _lure_x := 0.0 ## where a call came from
var _lure_until := -INF
const CALL_WINDOW := 1.5 ## game hours: this many calls inside it and it gets suspicious
const CALLS_TOLERATED := 2
var _timer := 0.0
var _since_print := 0.0
var wound := -1.0 ## seconds until a wounded animal drops; -1 = unhurt
var _limp := 1.0 ## flee speed multiplier while wounded
var _arrows := 0 ## arrows in it, drawn on the carcass
var _since_blood := 0.0
var _rng := RandomNumberGenerator.new()
var leaving := false ## spooked: heading away for good; Wildlife lets it go once out of sight
var _spooked_x := 0.0
const CAMP_BERTH := 800.0 ## deer keep this far from a camp or fire
var _threat_x := NAN ## a wolf on its heels (NAN: it's you it's running from)
var _threat_t := 0.0 ## seconds since the wolves last pressed it
var _chased := 0.0 ## seconds of the chase so far
var _doomed := false

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
	return active_at(def, GameClock.clock.hour_of_day())

static func active_at(species: SpeciesDef, h: float) -> bool:
	for r in species.active_hours:
		if h >= r.x and h < r.y:
			return true
	return false

## Where it's heading when calm: a bait pile it can smell, else its end of the game trail.
func _goal() -> float:
	if leaving:
		return clampf(position.x + signf(position.x - _spooked_x) * 3000.0, Terrain.WORLD_MIN + EDGE, Terrain.WORLD_MAX - EDGE)
	if GameClock.clock.hours < _lure_until:
		return _lure_x
	if _active():
		var bait := BaitPile.nearest(get_tree(), position.x)
		if bait:
			return bait.global_position.x
	if is_nan(bed_x):
		return home_x
	return feed_x if _active() else bed_x

func _physics_process(delta: float) -> void:
	if wound >= 0.0:
		wound -= delta
		if wound <= 0.0:
			_die()
			return
	_perceive(delta)
	match state:
		State.GRAZE, State.BEDDED, State.ALERT:
			speed = move_toward(speed, 0.0, 400.0 * delta)
		State.WALK:
			speed = def.walk_speed
		State.FLEE:
			var tired := 0.72 if _doomed and _chased > 4.0 else 1.0 # it can't keep ahead of them
			speed = move_toward(speed, def.flee_speed * _limp * tired * Predator.snow_drag(true), 900.0 * delta)
			var from := player.global_position.x if is_nan(_threat_x) else _threat_x
			facing = 1 if position.x >= from else -1
	if not is_nan(_threat_x):
		_threat_t += delta
		_chased += delta
		if _threat_t > 2.0: # they've given up
			_threat_x = NAN
			_chased = 0.0
	_timer -= delta
	if _timer <= 0.0:
		_routine()
	var step := speed * facing * delta
	var nx := clampf(position.x + step, Terrain.WORLD_MIN + EDGE, Terrain.WORLD_MAX - EDGE)
	if state != State.FLEE and near_camp(nx) and not near_camp(position.x): # turn away from camp
		nx = position.x
		facing = -facing
		if not leaving:
			home_x = position.x + facing * def.home_range
	if nx != position.x + step and state == State.FLEE:
		facing = -facing # cornered against the ridge: break past rather than freeze
	position.x = nx
	position.y = world.ground_y(position.x)
	_since_print += absf(step)
	_since_blood += absf(step)
	if wound >= 0.0 and _since_blood > 45.0:
		_since_blood = 0.0
		tracks.add(position.x, "blood", facing)
	if _since_print > def.stride:
		_since_print = 0.0
		tracks.add(position.x + facing * 20.0, def.track, facing)
		tracks.add(position.x - facing * 35.0, def.track, facing)
		if state == State.FLEE:
			Sfx.play_at(self, global_position, Sfx.hoof(), -6.0, 1.5)

func _routine() -> void:
	_timer = _rng.randf_range(3.0, 9.0)
	match state:
		State.GRAZE, State.BEDDED:
			var goal := _goal()
			var far := absf(goal - position.x) > (60.0 if goal != home_x else def.home_range)
			if far and (state == State.GRAZE or _active()):
				state = State.WALK # off along the trail (or to the bait)
				facing = int(signf(goal - position.x))
			elif state == State.GRAZE and not _active():
				state = State.BEDDED
			elif state == State.BEDDED and _active():
				state = State.GRAZE
			elif state == State.GRAZE and _rng.randf() < 0.3:
				state = State.WALK
				facing = 1 if _rng.randf() < 0.5 else -1
		State.WALK:
			var goal := _goal()
			if absf(goal - position.x) > 60.0 and goal != home_x:
				facing = int(signf(goal - position.x)) # keep going
				_timer = _rng.randf_range(4.0, 10.0)
			else:
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
	# Scent carries downwind: if the wind blows from you toward it, it smells you from far off,
	# blind or no blind.
	var w := GameClock.weather
	var scent := def.scent * (0.5 + w.wind)
	if signf(position.x - player.global_position.x) == float(w.wind_dir) and d < scent and not player.sleeping:
		stim += (1.0 - d / scent) * 2.5
	if state == State.FLEE:
		if wound >= 0.0:
			return # hurt animals keep running until they drop
		awareness = maxf(awareness - (0.5 if d > def.flee_distance else 0.0) * delta, 0.0)
		if awareness < def.alert_at * 0.6:
			state = State.WALK # and keeps on going, away from where it was scared
			leaving = true
			home_x = position.x
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
	_spooked_x = player.global_position.x
	if get_parent() is Wildlife:
		get_parent().spooked()
	for other in get_tree().get_nodes_in_group("animals"): # the herd follows the first to bolt
		if other != self and other.def == def and absf(other.position.x - position.x) < 900.0:
			other.bolt.call_deferred(false)

func near_camp(x: float) -> bool:
	for n in get_tree().get_nodes_in_group("camp_safe"):
		if absf(n.global_position.x - x) < CAMP_BERTH:
			return true
	return false

## Where a point falls on the body: 0 miss, 1 body, 2 vitals (heart-lung area or head).
func zone_at(p: Vector2) -> int:
	var l := (p - position) / def.size
	l.x *= facing
	if state != State.GRAZE and state != State.BEDDED and l.distance_to(Vector2(66, -142)) < 17.0:
		return 2 # head up
	var cy := -40.0 if state == State.BEDDED else -92.0
	var e := Vector2((l.x + 3.0) / 64.0, (l.y - cy) / 28.0)
	if e.length() > 1.0:
		return 0
	return 2 if l.x > 8.0 else 1

func shot(zone: int, arrow := true) -> void:
	if arrow:
		_arrows += 1
	if zone == 2:
		wound = _rng.randf_range(1.8, 3.0) if wound < 0.0 else minf(wound, 1.5)
		_limp = 0.9
	else:
		wound = _rng.randf_range(10.0, 16.0) if wound < 0.0 else wound * 0.5
		_limp = 0.6
	bolt()

## A doe bleat from x: curious deer come to look; too many calls and they turn wary.
func hear_call(x: float) -> void:
	if state == State.FLEE or wound >= 0.0:
		return
	var now := GameClock.clock.hours
	_calls = _calls.filter(func(h): return now - h < CALL_WINDOW)
	_calls.append(now)
	facing = int(signf(x - position.x)) if x != position.x else facing
	if _calls.size() > CALLS_TOLERATED:
		awareness = maxf(awareness, def.alert_at)
		state = State.ALERT
		_timer = _rng.randf_range(4.0, 8.0)
		return
	_lure_x = x
	_lure_until = now + 0.6
	state = State.WALK
	_timer = _rng.randf_range(6.0, 10.0)

## A clean kill at close quarters.
func kill() -> void:
	_die()

## Wolves on its heels, from x: it runs (and the herd with it). doomed: this chase ends in a kill.
func hunted(from_x: float, doomed: bool) -> void:
	_threat_x = from_x
	_threat_t = 0.0
	_doomed = doomed
	if state != State.FLEE:
		bolt(false)
		_spooked_x = from_x

## Pulled down by wolves: a torn carcass, blood in the snow.
func taken(_by_x: float) -> void:
	world.spawn({"kind": "carcass", "x": position.x, "facing": facing, "species": def.id,
		"hour": GameClock.clock.hours, "arrows": _arrows, "torn": true, "meat": Carcass.MEAT - 1.0})
	for k in 10:
		tracks.add(position.x + _rng.randf_range(-120.0, 120.0), "blood", facing)
	Journal.note("wolf_kill", "Saw wolves pull down a deer. They'll feed till they're full; drive them off it with fire and there's meat left on it.")
	queue_free()

func _die() -> void:
	world.spawn({"kind": "carcass", "x": position.x, "facing": facing, "species": def.id,
		"hour": GameClock.clock.hours, "arrows": _arrows})
	queue_free()
