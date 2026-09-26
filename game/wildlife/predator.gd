class_name Predator extends Node2D
## Wolves and the bear. They live off what's left lying around: a carcass, a gut pile, meat on
## the ground, a rabbit in a snare, and (the bear) bait. They never come near your camp or a
## fire, and a torch in your hand keeps them off. They follow their noses: food scent carries
## downwind, and so does the smell of raw meat you're carrying.
## Wolves run in a small pack and mostly at night (all day in winter). Bold ones stalk a player
## who is hurt or carrying meat after dark, lunge, and back off; hurt one and the pack scatters.
## The bear keeps to the foothills and sleeps through winter. Come too close, or near its food,
## and it bluff-charges; push it (or hurt it) and the next charge is real.

enum State { ROAM, SEEK, FEED, SHADOW, STALK, LUNGE, BACK_OFF, BLUFF, FLEE }
const STATE_NAMES: PackedStringArray = ["roam", "seek", "feed", "shadow", "stalk", "lunge", "back off", "bluff", "flee"]
const SAFE_R := 900.0 ## camps and fires: nothing wild comes this close
const TORCH_R := 600.0 ## a flame in your hand
const BRACED_R := 330.0 ## a spear or torch pointed at it: it won't come closer than this
const KINDS := {
	"wolf": {"hp": 1.0, "trot": 170.0, "run": 540.0, "bite": 11.0, "reach": 85.0, "region": "legs"},
	"black_bear": {"hp": 2.2, "trot": 85.0, "run": 470.0, "bite": 32.0, "reach": 130.0, "region": "torso"},
}
const EAT_PER_SEC := 0.05 ## portions of meat a feeding animal gets through

var def: SpeciesDef
var world: World
var player: Player
var tracks: Tracks
var pack: Array = [] ## wolves that hunt together (shared array, includes self)
var state: int = State.ROAM
var hp := 1.0
var facing := 1
var speed := 0.0
var home_x := 0.0
var angry := false ## the bear, once hurt or pushed: its next charge is no bluff
var arrows := 0
var food: Node:
	get: return food if is_instance_valid(food) and not food.is_queued_for_deletion() else null
var _target_x := 0.0
var _timer := 0.0
var _think := 0.0
var _threat_x := 0.0
var _warned := -INF ## real seconds (Time) of the last bluff
var _hit := false ## this lunge has landed
var strike_t := 0.0 ## seconds left of a landed bite or swipe (the rig clamps the jaws, swings the paw)
var _since_print := 0.0
var _howl := 0.0
var _rng := RandomNumberGenerator.new()

func setup(species: SpeciesDef, x: float, seed_value: int) -> void:
	def = species
	_rng.seed = seed_value
	hp = stat("hp")
	home_x = x
	_target_x = x
	position = Vector2(x, 0)
	facing = 1 if _rng.randf() < 0.5 else -1
	_howl = _rng.randf_range(10.0, 60.0)

func _ready() -> void:
	add_to_group("predators")
	z_index = -4 # in the plane, behind the player
	var rig := PredatorRig.new()
	rig.animal = self
	add_child(rig)

func stat(k: String) -> Variant:
	return KINDS[def.id][k]

func is_wolf() -> bool:
	return def.id == "wolf"

# --- Where it may go ------------------------------------------------------------

## Near a camp or a fire (lit or not): off limits.
static func safe_at(tree: SceneTree, x: float) -> bool:
	for n in tree.get_nodes_in_group("camp_safe"):
		if not n.is_queued_for_deletion() and absf(n.global_position.x - x) < SAFE_R:
			return true
	return false

func _torch_near(x: float) -> bool:
	return player.holding("torch") and absf(player.global_position.x - x) < TORCH_R and not player.dead

func _off_limits(x: float) -> bool:
	return safe_at(get_tree(), x) or _torch_near(x)

## A spear or torch held toward it.
func _braced() -> bool:
	return (player.holding("spear") or player.holding("torch")) and player.facing == int(signf(position.x - player.global_position.x))

func _night() -> bool:
	return GameClock.clock.daylight() < 0.25

# --- Senses ------------------------------------------------------------------------

## The nearest food it can smell, not inside a camp. Scent carries farther downwind.
func _find_food() -> Node:
	var best: Node = null
	var best_d := INF
	var w := GameClock.weather
	for n in get_tree().get_nodes_in_group("food_scent"):
		if n.is_queued_for_deletion() or not n.appeals(def.id):
			continue
		var dx: float = n.global_position.x - position.x
		var reach := def.scent * (1.0 + w.wind * 0.8 if signf(-dx) == float(w.wind_dir) else 0.75)
		if absf(dx) < reach and absf(dx) < best_d and not safe_at(get_tree(), n.global_position.x):
			best = n
			best_d = absf(dx)
	return best

## Raw meat on you (or a carcass in tow, or an open wound) smells like food to a wolf.
func _smells_player() -> bool:
	if not is_wolf() or player.dead:
		return false
	var d := absf(player.global_position.x - position.x)
	return d < def.scent * 0.8 and player.smells_of_meat() and player.under < 0.3

## Wolves only close in after dark on someone who's hurt or carrying meat, and not at a camp.
func _bold() -> bool:
	return is_wolf() and _night() and (player.cond.health < 55.0 or player.smells_of_meat()) \
		and not _off_limits(player.global_position.x) and not player.sleeping and player.under < 0.3

# --- Brain -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if player == null or def == null:
		return
	_think -= delta
	_timer -= delta
	strike_t = maxf(strike_t - delta, 0.0)
	if _think <= 0.0:
		_think = 0.4
		_decide()
	_act(delta)
	_move(delta)
	if is_wolf() and _night():
		_howl -= delta
		if _howl <= 0.0:
			_howl = _rng.randf_range(50.0, 140.0)
			if pack.is_empty() or pack[0] == self:
				howl()

func _decide() -> void:
	var px := player.global_position.x
	var d := absf(px - position.x)
	if player.sleeping and d < 900.0 and not _off_limits(px) and player.under < 0.3:
		player.wake("Something is moving close by. You're awake at once.")
	if state == State.FLEE:
		if _timer <= 0.0 and absf(position.x - _threat_x) > 1600.0 and not _off_limits(position.x):
			state = State.ROAM
			home_x = position.x
			angry = false
		return
	if _off_limits(position.x):
		flee(player.global_position.x if _torch_near(position.x) else _nearest_safe_x())
		return
	if state in [State.LUNGE, State.BACK_OFF, State.BLUFF]:
		return
	if not is_wolf() and not player.dead and not _off_limits(px) and player.under < 0.3:
		var guarding := state == State.FEED
		if d < 420.0 or (guarding and d < 650.0):
			var pushed := Time.get_ticks_msec() / 1000.0 - _warned < 25.0 # came back after the warning
			if angry or pushed:
				_start(State.LUNGE, 1.6)
			else:
				_start(State.BLUFF, 1.4)
			return
	if _bold() and d < 1500.0:
		if state != State.STALK:
			_start(State.STALK, 0.0)
		return
	if state == State.STALK:
		state = State.ROAM
	if state == State.FEED and food:
		return
	var f := _find_food()
	if f:
		food = f
		if state != State.FEED:
			state = State.SEEK
		return
	if _smells_player():
		state = State.SHADOW
		return
	if state != State.ROAM:
		state = State.ROAM
		_target_x = position.x

func _nearest_safe_x() -> float:
	var best := position.x
	var bd := INF
	for n in get_tree().get_nodes_in_group("camp_safe"):
		var dd := absf(n.global_position.x - position.x)
		if dd < bd:
			bd = dd
			best = n.global_position.x
	return best

func _start(s: int, t: float) -> void:
	state = s
	_timer = t
	_hit = false
	if s == State.BLUFF or (s == State.LUNGE and not is_wolf()):
		Sfx.play_at(self, global_position + Vector2(facing * 80.0, -120.0), Sfx.roar() if not is_wolf() else Sfx.growl(), 2.0)
	elif s == State.STALK and is_wolf():
		Sfx.play_at(self, global_position + Vector2(facing * 60.0, -60.0), Sfx.growl(), -6.0)

func _act(delta: float) -> void:
	var px := player.global_position.x
	var toward := int(signf(px - position.x)) if px != position.x else facing
	var trot: float = stat("trot")
	var run: float = stat("run")
	match state:
		State.ROAM:
			speed = trot * 0.6
			if absf(_target_x - position.x) < 60.0 or _timer <= 0.0:
				_target_x = clampf(home_x + _rng.randf_range(-def.home_range, def.home_range), Terrain.WORLD_MIN + Animal.EDGE, Terrain.WORLD_MAX - Animal.EDGE)
				_timer = _rng.randf_range(8.0, 16.0)
			facing = int(signf(_target_x - position.x)) if absf(_target_x - position.x) > 5.0 else facing
		State.SEEK:
			var f := food
			if f == null:
				state = State.ROAM
				return
			var dx: float = f.global_position.x + _spread() - position.x
			facing = int(signf(dx)) if absf(dx) > 5.0 else facing
			speed = trot * 1.5 if absf(dx) > 40.0 else 0.0
			if absf(dx) <= 40.0:
				state = State.FEED
		State.FEED:
			speed = move_toward(speed, 0.0, 600.0 * delta)
			var f := food
			if f == null or not f.gnaw(EAT_PER_SEC * delta, def.id):
				food = null
				state = State.ROAM
		State.SHADOW: # hang back where you can just about see it
			var side := signf(position.x - px) if position.x != px else 1.0
			var want := px + side * 950.0
			var dx := want - position.x
			facing = int(signf(dx)) if absf(dx) > 40.0 else -int(side)
			speed = trot if absf(dx) > 40.0 else 0.0
		State.STALK:
			facing = toward
			var d := absf(px - position.x)
			var hold := BRACED_R if _braced() else 260.0
			speed = trot * 0.8 if d > hold else 0.0
			if d <= 280.0 and not _braced() and _timer <= 0.0:
				_start(State.LUNGE, 1.2)
		State.LUNGE:
			facing = toward
			var d := absf(px - position.x)
			if _hit: # hangs on (the wolf) or follows through (the bear), then breaks off
				speed = move_toward(speed, 0.0, 3000.0 * delta)
				if _timer <= 0.0:
					_start(State.BACK_OFF, _rng.randf_range(2.0, 3.5))
			else:
				speed = run
				if d < stat("reach") and absf(player.global_position.y - position.y) < 160.0:
					_hit = true
					_timer = 0.45
					strike_t = 0.45
					_bite()
				elif _timer <= 0.0 or _off_limits(px):
					_start(State.BACK_OFF, _rng.randf_range(2.0, 3.5))
		State.BACK_OFF:
			facing = -toward
			speed = run * 0.45
			if _timer <= 0.0:
				state = State.STALK if is_wolf() else (State.FEED if food else State.ROAM)
				_timer = _rng.randf_range(2.0, 4.0) # a pause before the next rush
				if not is_wolf():
					facing = toward
		State.BLUFF: # charge, pull up short, huff and swat the ground
			facing = toward
			var d := absf(px - position.x)
			speed = run * 0.85 if d > 170.0 and _timer > 0.6 else move_toward(speed, 0.0, 2000.0 * delta)
			if _timer <= -1.6:
				_warned = Time.get_ticks_msec() / 1000.0
				_start(State.BACK_OFF, 1.5)
		State.FLEE:
			facing = int(signf(position.x - _threat_x)) if position.x != _threat_x else facing
			speed = run

## Pack members spread out around a carcass instead of stacking on one spot.
func _spread() -> float:
	var i := pack.find(self)
	return 0.0 if i <= 0 else (i * 70.0) * (1.0 if i % 2 == 0 else -1.0)

func _move(delta: float) -> void:
	var step := speed * facing * delta
	var nx := clampf(position.x + step, Terrain.WORLD_MIN + Animal.EDGE, Terrain.WORLD_MAX - Animal.EDGE)
	if state != State.FLEE and _off_limits(nx) and not _off_limits(position.x):
		nx = position.x # stop at the edge of the camp's light
		speed = 0.0
	_since_print += absf(nx - position.x)
	position.x = nx
	position.y = world.ground_y(position.x)
	if _since_print > def.stride:
		_since_print = 0.0
		tracks.add(position.x, def.track, facing)

# --- Contact -------------------------------------------------------------------------

func _bite() -> void:
	player.take_hit(stat("bite"), stat("region"), 0.35 if is_wolf() else 0.6, position.x, 260.0 if is_wolf() else 700.0)
	player.message.emit("The wolf's teeth catch your leg!" if is_wolf() else "The bear's paw knocks you sprawling!")
	Sfx.play_at(self, player.global_position + Vector2(0, -80), Sfx.growl(), 0.0, 1.2)

## Hurt by an arrow, spear or knife: a wolf's pack scatters; the bear gets angry or runs.
func hurt(amount: float, from_x: float) -> void:
	hp -= amount
	if hp <= 0.0:
		die()
		return
	if is_wolf():
		for w in pack:
			if is_instance_valid(w):
				w.flee(from_x)
		flee(from_x)
	elif hp > stat("hp") * 0.45 and absf(from_x - position.x) < 900.0:
		angry = true
		_start(State.LUNGE, 1.6)
	else:
		flee(from_x)

## Arrow strike: zone 2 is the heart and lungs (or head).
func shot(zone: int) -> void:
	arrows += 1
	hurt(1.2 if zone == 2 else 0.55, player.global_position.x)

func flee(from_x: float) -> void:
	if state == State.FLEE:
		return
	state = State.FLEE
	_threat_x = from_x
	_timer = 6.0
	food = null

## Waved at with a torch, or startled by a shout.
func scare(from_x: float) -> void:
	if is_wolf() or not angry:
		flee(from_x)

func die() -> void:
	world.spawn({"kind": "carcass", "x": position.x, "facing": facing, "species": def.id,
		"hour": GameClock.clock.hours, "arrows": arrows})
	pack.erase(self)
	for w in pack:
		if is_instance_valid(w):
			w.flee(player.global_position.x)
	queue_free()

func howl() -> void:
	Sfx.play_at(self, global_position + Vector2(facing * 50.0, -110.0), Sfx.howl(), -1.0)
	Journal.note("wolves", "Wolves howling after dark. They'll be drawn to anything dead I leave lying out, and they won't come near a fire.")

## Where a point falls on the body: 0 miss, 1 body, 2 vitals (chest or head).
func zone_at(p: Vector2) -> int:
	var l := (p - position)
	l.x *= facing
	var wolf := is_wolf()
	var head := Vector2(64, -76) if wolf else Vector2(98, -96)
	if l.distance_to(head) < (13.0 if wolf else 22.0):
		return 2
	var c := Vector2(-4, -58) if wolf else Vector2(-6, -84)
	var r := Vector2(56, 20) if wolf else Vector2(88, 40)
	var e := (l - c) / r
	if e.length() > 1.0:
		return 0
	return 2 if l.x > c.x + r.x * 0.25 else 1
