class_name Predator extends Node2D
## Wolves and the bear. They live off what's left lying around: a carcass, a gut pile, meat on
## the ground, a rabbit in a snare, and (the bear) bait. They never come near your camp or a
## fire, and a torch in your hand keeps them off. They follow their noses: food scent carries
## downwind, and so does the smell of raw meat you're carrying.
## Wolves run in a small pack and mostly at night. In winter they're out all day and range
## far: packs travel the country, and hunger makes them bolder. Bold ones stalk a player who
## is hurt or carrying meat after dark, lunge, and back off; hurt one and the pack scatters.
## The bear keeps to the foothills, hungry and nosing far for food in spring and autumn. Come
## too close, or near its food, and it bluff-charges; push it (or hurt it) and the next charge
## is real. In winter it sleeps in the den in the cave's upper gallery: noise and light close
## by rouse it, and a woken bear defends its den (it never leaves the gallery).

enum State { ROAM, SEEK, FEED, SHADOW, STALK, LUNGE, BACK_OFF, BLUFF, FLEE, SLEEP }
const STATE_NAMES: PackedStringArray = ["roam", "seek", "feed", "shadow", "stalk", "lunge", "back off", "bluff", "flee", "sleep"]
const SAFE_R := 900.0 ## camps and fires: nothing wild comes this close
const TORCH_R := 600.0 ## a flame in your hand
const BRACED_R := 330.0 ## a spear or torch pointed at it: it won't come closer than this
const KINDS := {
	"wolf": {"hp": 1.0, "trot": 170.0, "run": 540.0, "bite": 11.0, "reach": 85.0, "region": "legs"},
	"black_bear": {"hp": 2.2, "trot": 85.0, "run": 470.0, "bite": 32.0, "reach": 130.0, "region": "torso"},
}
const EAT_PER_SEC := 0.05 ## portions of meat a feeding animal gets through
const DEN := Vector2(830.0, 400.0) ## where the bear beds down, in the cave's layout
const DEN_SPAN := Vector2(450.0, 1330.0) ## the gallery floor a woken bear keeps to (layout x)
const ROUSE_R := 520.0 ## a sleeping bear can be disturbed from this close

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
var travel := 0.0 ## a winter pack on the move: the way it's heading (0 = keeping to home)
var den: Underground ## the bear asleep in its winter den (null otherwise)
var rouse := 0.0 ## how near a sleeping bear is to waking, 0..1
var _stirred := false
var _calm := 0.0
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
	if den:
		z_as_relative = false
		z_index = 2 # in front of the cave walls, behind the player
	var rig := PredatorRig.new()
	rig.animal = self
	add_child(rig)

func stat(k: String) -> Variant:
	return KINDS[def.id][k]

func is_wolf() -> bool:
	return def.id == "wolf"

## Beds the bear down in the cave den for the winter (before it's added to the tree).
func bed_down(u: Underground) -> void:
	den = u
	state = State.SLEEP
	facing = -1
	position = u.global_position + Vector2(DEN.x * u.dir, DEN.y)
	home_x = position.x

## How far it wanders from home: wider in winter (wolves) and autumn (the bear, fattening up).
func _range() -> float:
	var s := GameClock.clock.season()
	if is_wolf():
		return def.home_range * (2.0 if s == 3 else 1.0)
	return def.home_range * (1.5 if s == 2 else 1.0)

## Scent reach: a bear just out of its den, or fattening for winter, follows its nose far.
func _hunger() -> float:
	var y := GameClock.clock.year_pos()
	if is_wolf():
		return 1.25 if y >= 0.75 else 1.0 # winter
	if y < 0.125: # early spring, just out of the den
		return 1.5
	return 1.3 if y >= 0.5 and y < 0.75 else 1.0 # autumn

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
	if den: # cornered in its den, it holds its ground
		return false
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
		var reach := def.scent * _hunger() * (1.0 + w.wind * 0.8 if signf(-dx) == float(w.wind_dir) else 0.75)
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
	var starving := GameClock.clock.season() == 3 # winter hunger: a smaller wound will do
	return is_wolf() and _night() and (player.cond.health < (70.0 if starving else 55.0) or player.smells_of_meat()) \
		and not _off_limits(player.global_position.x) and not player.sleeping and player.under < 0.3

# --- Brain -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if player == null or def == null:
		return
	_think -= delta
	_timer -= delta
	strike_t = maxf(strike_t - delta, 0.0)
	if state == State.SLEEP:
		_doze(delta)
		return
	if _think <= 0.0:
		_think = 0.4
		_decide()
	_act(delta)
	_move(delta)
	if is_wolf() and _night():
		_howl -= delta
		if _howl <= 0.0:
			_howl = _rng.randf_range(50.0, 140.0) * (0.5 if GameClock.clock.season() == 3 else 1.0)
			if pack.is_empty() or pack[0] == self:
				howl()

func _decide() -> void:
	if den:
		_den_decide()
		return
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
			speed = trot * (0.85 if travel != 0.0 else 0.6)
			if den: # back to the bedding
				_target_x = home_x
				speed = trot * 0.5
				if absf(home_x - position.x) < 20.0:
					speed = 0.0
					facing = toward if player.underground == den else -1 # watching you
			elif travel != 0.0: # a winter pack covering ground
				if absf(_target_x - position.x) < 60.0 or _timer <= 0.0:
					_target_x = position.x + travel * _rng.randf_range(1500.0, 2500.0)
					_timer = _rng.randf_range(12.0, 20.0)
				home_x = position.x
			elif absf(_target_x - position.x) < 60.0 or _timer <= 0.0:
				_target_x = clampf(home_x + _rng.randf_range(-_range(), _range()), Terrain.WORLD_MIN + Animal.EDGE, Terrain.WORLD_MAX - Animal.EDGE)
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
	if den:
		nx = clampf(nx, den.global_position.x + DEN_SPAN.x * den.dir, den.global_position.x + DEN_SPAN.y * den.dir) if den.dir > 0.0 \
			else clampf(nx, den.global_position.x + DEN_SPAN.y * den.dir, den.global_position.x + DEN_SPAN.x * den.dir)
		position.x = nx
		position.y = world.floor_y(nx, position.y)
		return
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
	if state == State.SLEEP:
		_wake()
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
func shot(zone: int, arrow := true) -> void:
	if arrow:
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
	var c := {"kind": "carcass", "x": position.x, "facing": facing, "species": def.id,
		"hour": GameClock.clock.hours, "arrows": arrows}
	if den:
		c.y = position.y
		world.chunk_state(den.chunk_index).den_bear_killed = GameClock.clock.hours # the den stays empty this winter
	world.spawn(c)
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
	if state == State.SLEEP: # curled up low in the bedding
		var e2 := (l - Vector2(0, -40)) / Vector2(100, 42)
		return 0 if e2.length() > 1.0 else (2 if l.x > 20.0 else 1)
	var head := Vector2(64, -76) if wolf else Vector2(98, -96)
	if l.distance_to(head) < (13.0 if wolf else 22.0):
		return 2
	var c := Vector2(-4, -58) if wolf else Vector2(-6, -84)
	var r := Vector2(56, 20) if wolf else Vector2(88, 40)
	var e := (l - c) / r
	if e.length() > 1.0:
		return 0
	return 2 if l.x > c.x + r.x * 0.25 else 1

# --- The winter den -------------------------------------------------------------------

## Asleep: noise and light close by (you down in the gallery) slowly rouse it.
func _doze(delta: float) -> void:
	var d := position.distance_to(player.global_position)
	var near := player.underground == den and not player.dead and d < ROUSE_R
	var stir := 0.0
	if near:
		var moving := absf(player.velocity.x) > 5.0
		var loud := 0.03
		if player.running or player.swing >= 0.0:
			loud = 1.0
		elif moving:
			loud = 0.12 if player.crouching else 0.35
		if player.holding("torch"):
			loud += 0.3 # smoke and crackle
		stir = (1.0 - d / ROUSE_R) * loud * 0.6
		Journal.note("den_bear", "The bear is back in its den for the winter, asleep in the upper gallery of the cave. It breathes slow and deep. Quiet feet, no fire, and it might sleep on.")
	rouse = clampf(rouse + (stir - 0.05) * delta, 0.0, 1.0)
	if rouse > 0.5 and not _stirred:
		_stirred = true
		player.message.emit("The bear groans and shifts in the bedding. Its breathing has changed.")
	elif rouse < 0.25:
		_stirred = false
	if rouse >= 1.0:
		_wake()

func _wake() -> void:
	state = State.ROAM
	rouse = 0.0
	_calm = 0.0
	angry = false # groggy: a warning first (hurt it and the charge is real)
	facing = int(signf(player.global_position.x - position.x)) if player.global_position.x != position.x else facing
	player.message.emit("The bear heaves up out of the bedding, huge in the dark!")
	Sfx.play_at(self, global_position + Vector2(facing * 80.0, -120.0), Sfx.roar(), 2.0)

## Awake in the den: see you off, then settle back down once you're gone.
func _den_decide() -> void:
	var d := position.distance_to(player.global_position)
	var here := player.underground == den and not player.dead and absf(player.global_position.y - position.y) < 200.0
	if state == State.FLEE:
		if _timer <= 0.0:
			state = State.ROAM
		return
	if state in [State.LUNGE, State.BACK_OFF, State.BLUFF]:
		return
	if here and d < 650.0:
		_calm = 0.0
		if d < 420.0:
			var pushed := Time.get_ticks_msec() / 1000.0 - _warned < 25.0
			_start(State.LUNGE if angry or pushed else State.BLUFF, 1.6)
		else:
			state = State.ROAM
			facing = int(signf(player.global_position.x - position.x))
		return
	state = State.ROAM
	_calm += 0.4
	if _calm > 12.0 and absf(home_x - position.x) < 20.0: # you're gone: back to sleep
		state = State.SLEEP
		angry = false
		facing = -1
