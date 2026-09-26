class_name Ambience extends Node2D
## Layered ambience driven by place, clock, season and weather, so the soundscape carries
## information: every biome sounds like itself (meadowlarks on the sage, frogs in the marsh,
## a canyon wren's falling song off the rock, wind roaring on the ridge), birds fall silent
## before rain, insects and frogs only sing when it's warm, winter goes quiet, and walking from
## one country into the next blends one into the other. The creek is heard from where it is,
## the falls drown out everything near them, and canyons and caves echo.
## Beds are looping recordings (assets/audio/amb, the originals in the root); calls are one-
## shots (assets/audio/sfx) dropped in now and then around you.

const FADE := 0.4 ## gain change per second
const BLEND := [[-1600.0, 0.1], [-800.0, 0.2], [0.0, 0.4], [800.0, 0.2], [1600.0, 0.1]] ## sampled around you
const OLD_BEDS := ["forest_day", "dusk", "night_crickets", "wind_trees"] ## in assets/audio/
## What each bed is, for the seasons: birds are loudest in spring and sparse in winter,
## insects and frogs need warmth, wind is a little stronger in winter.
const KIND := {
	"forest_day": "bird", "dusk": "bird", "marsh_day": "bird", "meadow_day": "bird", "foothills_day": "bird",
	"sage_day": "bird", "alpine_day": "bird", "prairie": "insect", "night_crickets": "insect", "field_crickets": "insect",
	"cicadas": "insect", "desert_day": "insect", "nighthawks": "insect", "marsh_night": "frog", "frogs_close": "frog",
	"toads": "frog", "wind_trees": "wind", "wind_strong": "wind", "wind_whistle": "wind", "wind_grass": "wind",
	"wind_creak": "wind", "wind_cottonwood": "wind", "wind_aspen": "wind", "oldgrowth_day": "wind",
	"drips": "still", "oldgrowth_night": "still",
}
## biome -> {day, dusk, night: {bed: gain}, wind: {bed: gain} (scaled by the wind),
## calls: [[takes, count, when (day/dusk/night/any), per minute, kind]]}
const PROFILES := {
	"valley": {"day": {"forest_day": 0.9}, "dusk": {"dusk": 0.7}, "night": {"night_crickets": 0.6}, "wind": {"wind_trees": 1.0},
		"calls": [["woodpecker", 4, "day", 0.8, "bird"], ["jay", 3, "day", 0.4, "bird"], ["owl_gh", 1, "night", 0.6, "bird"]]},
	"river": {"day": {"forest_day": 0.5, "marsh_day": 0.35}, "dusk": {"dusk": 0.6}, "night": {"night_crickets": 0.5, "frogs_close": 0.3}, "wind": {"wind_cottonwood": 1.0},
		"calls": [["ducks", 2, "day", 1.0, "bird"], ["geese", 2, "day", 0.3, "migrant"], ["owl_gh", 1, "night", 0.5, "bird"]]},
	"marsh": {"day": {"marsh_day": 0.9}, "dusk": {"marsh_day": 0.5, "dusk": 0.3}, "night": {"marsh_night": 0.8, "frogs_close": 0.5}, "wind": {"wind_grass": 0.8},
		"calls": [["geese", 2, "day", 0.9, "migrant"], ["ducks", 2, "any", 0.8, "bird"]]},
	"meadow": {"day": {"meadow_day": 0.8, "prairie": 0.35, "field_crickets": 0.35}, "dusk": {"dusk": 0.5}, "night": {"night_crickets": 0.7}, "wind": {"wind_grass": 1.0},
		"calls": [["hawk", 3, "day", 0.2, "bird"], ["coyote", 2, "night", 0.4, "any"], ["coyotes", 3, "night", 0.15, "any"]]},
	"sage": {"day": {"sage_day": 0.7}, "dusk": {"nighthawks": 0.5}, "night": {"night_crickets": 0.45, "nighthawks": 0.2}, "wind": {"wind_grass": 0.6, "wind_whistle": 0.4},
		"calls": [["hawk", 3, "day", 0.3, "bird"], ["raven", 3, "day", 0.3, "any"], ["coyotes", 3, "night", 0.5, "any"], ["coyote", 2, "night", 0.5, "any"]]},
	"desert": {"day": {"desert_day": 0.6, "cicadas": 0.4}, "dusk": {"nighthawks": 0.4}, "night": {"toads": 0.25, "night_crickets": 0.25}, "wind": {"wind_whistle": 0.7},
		"calls": [["hawk", 3, "day", 0.5, "bird"], ["raven", 3, "day", 0.3, "any"], ["coyotes", 3, "night", 0.6, "any"], ["coyote", 2, "dusk", 0.6, "any"]]},
	"canyon": {"day": {"desert_day": 0.35}, "dusk": {"nighthawks": 0.3}, "night": {"night_crickets": 0.3}, "wind": {"wind_whistle": 1.0, "wind_cottonwood": 0.3},
		"calls": [["canyon_wren", 1, "day", 1.0, "bird"], ["raven", 3, "day", 0.6, "any"], ["bats", 1, "dusk", 1.0, "insect"], ["coyote", 2, "night", 0.3, "any"]]},
	"foothills": {"day": {"foothills_day": 0.85}, "dusk": {"dusk": 0.6}, "night": {"night_crickets": 0.5}, "wind": {"wind_trees": 1.0},
		"calls": [["jay", 3, "day", 1.0, "bird"], ["squirrel", 3, "day", 0.7, "any"], ["woodpecker", 4, "day", 0.4, "bird"], ["owl_gh", 1, "night", 0.8, "bird"]]},
	"ridge": {"day": {"alpine_day": 0.3}, "dusk": {"dusk": 0.2}, "night": {}, "wind": {"wind_strong": 1.0},
		"calls": [["raven", 3, "day", 0.8, "any"]]},
	"burn": {"day": {"alpine_day": 0.12}, "dusk": {}, "night": {}, "wind": {"wind_creak": 0.9, "wind_whistle": 0.3},
		"calls": [["woodpecker", 4, "day", 1.2, "bird"], ["flicker", 4, "day", 0.4, "bird"], ["owl_gh", 1, "night", 0.2, "bird"]]},
	"alpine": {"day": {"alpine_day": 0.5}, "dusk": {}, "night": {}, "wind": {"wind_strong": 1.2},
		"calls": [["marmot", 3, "day", 1.0, "summer"], ["pika", 3, "day", 1.2, "summer"], ["hawk", 3, "day", 0.2, "bird"], ["ice", 1, "any", 1.0, "ice"], ["ice2", 1, "any", 0.8, "ice"]]},
	"boulders": {"day": {"alpine_day": 0.35}, "dusk": {}, "night": {"night_crickets": 0.15}, "wind": {"wind_whistle": 0.8},
		"calls": [["marmot", 3, "day", 1.0, "summer"], ["pika", 3, "day", 0.8, "summer"], ["rockfall", 5, "any", 0.25, "any"]]},
	"oldgrowth": {"day": {"drips": 0.3, "forest_day": 0.25}, "dusk": {"dusk": 0.3}, "night": {"oldgrowth_night": 0.6, "drips": 0.3}, "wind": {"oldgrowth_day": 0.7, "wind_trees": 0.3},
		"calls": [["thrush", 3, "day", 1.2, "bird"], ["woodpecker", 4, "day", 0.4, "bird"], ["squirrel", 3, "day", 0.4, "any"], ["owl_gh", 1, "night", 0.8, "bird"]]},
	"grove": {"day": {"forest_day": 0.7}, "dusk": {"dusk": 0.6}, "night": {"night_crickets": 0.5}, "wind": {"wind_aspen": 1.0},
		"calls": [["flicker", 4, "day", 1.0, "bird"], ["jay", 3, "day", 0.3, "bird"], ["woodpecker", 4, "day", 0.4, "bird"], ["owl_gh", 1, "night", 0.6, "bird"], ["elk", 1, "dusk", 1.2, "rut"], ["elk", 1, "night", 0.5, "rut"]]},
}
const SPACE := {"canyon": 0.45, "oldgrowth": 0.18, "boulders": 0.15, "ridge": 0.1, "alpine": 0.1} ## how much it echoes

var player: Player
var terrain: Terrain
var beds := {} ## name -> AudioStreamPlayer
var creek: AudioStreamPlayer2D
var music: AudioStreamPlayer
var _was_warning := false
var _cues := {} ## name -> AudioStream
var _was_night := -1 ## -1 until the first frame, so loading at night doesn't start a cue
var _heard := {} ## one-off cues already played this session
var _music_cooldown := 0.0
const MUSIC_COOLDOWN := 600.0 ## real seconds between cues: music stays rare so it means something
var _call_t := 2.0
var _creak_t := 5.0
## How wooded each country is: rain on the leaves, the dawn chorus, creaking trees.
const WOODED := {"valley": 0.8, "grove": 1.0, "oldgrowth": 1.0, "river": 0.6, "foothills": 0.6, "burn": 0.3, "meadow": 0.3, "marsh": 0.2, "ridge": 0.4, "alpine": 0.2}
var _reverbs: Array[AudioEffectReverb] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	var names := {}
	for b in PROFILES.values():
		for slot in ["day", "dusk", "night", "wind"]:
			for n in b[slot]:
				names[n] = true
	for n in names:
		beds[n] = _bed(n, &"Weather" if KIND.get(n) == "wind" else &"Ambience")
	beds["wind_storm"] = _bed("wind_storm", &"Weather")
	beds["rain"] = _bed("rain", &"Weather")
	beds["rain_forest"] = _bed("rain_forest", &"Weather") # rain on the leaves overhead
	beds["rain_roof"] = _bed("rain_roof", &"Weather") # drumming on the roof you're under
	beds["dawn_chorus"] = _bed("dawn_chorus", &"Ambience")
	creek = AudioStreamPlayer2D.new()
	creek.stream = load("res://assets/audio/creek.wav")
	creek.bus = &"Ambience"
	creek.max_distance = 3200.0
	creek.attenuation = 1.6
	add_child(creek)
	_place_creek()
	creek.play(_rng.randf() * 30.0)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/music/storm_cue.wav")
	music.bus = &"Music"
	add_child(music)
	for n in ["storm_cue", "night", "dawn", "lights"]:
		_cues[n] = load("res://assets/audio/music/%s.wav" % n)
	_setup_echo()

func _bed(n: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/%s.wav" % (n if n in OLD_BEDS or n == "rain" else "amb/" + n))
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	p.play(_rng.randf() * 20.0) # desync loops so seams never line up
	return p

## Calls get their own bus (under Ambience, so its slider still rules them) and, like the
## sound effects, a reverb whose wetness follows the place: canyons and caves ring.
func _setup_echo() -> void:
	if AudioServer.get_bus_index(&"Calls") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, &"Calls")
		AudioServer.set_bus_send(i, &"Ambience")
	for bus in [&"Calls", &"SFX"]:
		var i := AudioServer.get_bus_index(bus)
		var r := AudioEffectReverb.new()
		r.room_size = 0.85
		r.damping = 0.35
		r.predelay_msec = 90.0
		r.dry = 1.0
		r.wet = 0.0
		AudioServer.add_bus_effect(i, r)
		_reverbs.append(r)

## The water sound sits on whichever creek or river is nearest (the river runs louder).
func _place_creek() -> void:
	var best := -1
	for i in Terrain.WATERS.size():
		var w: Dictionary = Terrain.WATERS[i]
		if w.kind in ["creek", "river", "pool"] and (best < 0 or absf(w.x - player.global_position.x) < absf(Terrain.WATERS[best].x - player.global_position.x)):
			best = i
	var wd: Dictionary = Terrain.WATERS[best]
	creek.position = Vector2(wd.x, terrain.surface_of(best))
	creek.volume_db = {"river": 4.0, "pool": 9.0}.get(wd.kind, 0.0) + 7.0 * GameClock.weather.flood # the pool is the falls: a roar; a flood roars too
	creek.max_distance = {"river": 4200.0, "pool": 5200.0}.get(wd.kind, 3200.0)
	creek.stream_paused = Creek.frozen() and GameClock.weather.ice > 0.9 # frozen hard: silence

## The biomes around you and how much each counts: a smooth blend as you walk between them.
func blend_at(x: float) -> Dictionary:
	var out := {}
	for s in BLEND:
		var b := Terrain.biome(clampf(x + s[0], Terrain.WORLD_MIN, Terrain.WORLD_MAX))
		out[b] = out.get(b, 0.0) + s[1]
	return out

## How much the season lets a kind of sound through right now.
func season_gain(kind: String) -> float:
	var c := GameClock.clock
	var s := c.season() # 0 spring .. 3 winter
	var warm := clampf((player.air_c() - 5.0) / 8.0, 0.0, 1.0)
	match kind:
		"bird": return [1.25, 1.0, 0.75, 0.3][s]
		"migrant": return [1.2, 0.2, 1.2, 0.0][s] # geese go over in spring and autumn
		"insect": return warm * (0.0 if s == 3 else 1.0)
		"frog": return warm * [1.0, 0.9, 0.3, 0.0][s]
		"wind": return 1.15 if s == 3 else 1.0
		"summer": return 0.0 if s == 3 else (0.5 if s == 2 else 1.0) # marmots and pikas hole up
		"rut": return 1.0 if s == 2 else 0.0 # elk bugle in autumn
		"ice": return 1.0 if Creek.frozen() or s == 3 else 0.0
	return 1.0

func _process(delta: float) -> void:
	_place_creek()
	var c := GameClock.clock
	var w := GameClock.weather
	var h := c.hour_of_day()
	var day := c.daylight()
	var twilight := clampf(exp(-pow((h - 6.3) / 1.2, 2.0)) + exp(-pow((h - 20.0) / 1.2, 2.0)), 0.0, 1.0)
	var night := 1.0 - smoothstep(0.0, 0.15, day)
	var daytime := smoothstep(0.05, 0.4, day)
	var hush := 1.0 - (0.85 if w.storm_warning() else 0.0) # wildlife goes quiet before rain
	var rain_mask := 1.0 - w.precip * 0.8 # snow hushes the country too
	var below := 1.0 - 0.85 * player.under # underground the world up top goes faint
	var falls := 1.0 - 0.65 * clampf(1.0 - absf(player.global_position.x - Terrain.FALLS_X) / 2200.0, 0.0, 1.0) # the falls drown it out
	var wind := clampf(w.wind, 0.06, 1.0)
	var mix := blend_at(player.global_position.x)
	var want := {}
	for b in mix:
		var p: Dictionary = PROFILES.get(b, PROFILES.valley)
		var k: float = mix[b]
		for slot in [["day", daytime], ["dusk", twilight], ["night", night], ["wind", wind]]:
			for n in p[slot[0]]:
				want[n] = want.get(n, 0.0) + p[slot[0]][n] * slot[1] * k
	for n in beds:
		if n in ["rain", "wind_storm", "rain_forest", "rain_roof", "dawn_chorus"]:
			continue
		var kind: String = KIND.get(n, "still")
		var g: float = want.get(n, 0.0) * season_gain(kind) * below
		if kind != "wind":
			g *= falls * rain_mask * (hush if kind in ["bird", "insect"] else 1.0)
		_gain(n, minf(g, 1.0), delta)
	_gain("wind_storm", smoothstep(0.6, 1.0, w.wind) * below, delta)
	var woods := 0.0 # how much of the country round you is under trees
	for b in mix:
		woods += mix[b] * WOODED.get(b, 0.0)
	var roof := 1.0 if player.world.sheltered_at(player.global_position.x) else 0.0
	_gain("rain", w.rain() * below * (1.0 - 0.75 * woods) * (1.0 - 0.6 * roof), delta)
	_gain("rain_forest", w.rain() * below * woods * (1.0 - 0.7 * roof), delta)
	_gain("rain_roof", w.rain() * roof * below, delta)
	# The dawn chorus: every bird in the woods at once, in the half-light, spring and summer
	var dawn := smoothstep(4.6, 5.6, h) * (1.0 - smoothstep(7.0, 8.2, h))
	var singing: float = [1.0, 0.9, 0.3, 0.0][c.season()]
	_gain("dawn_chorus", dawn * singing * clampf(woods * 1.2, 0.0, 1.0) * hush * rain_mask * below * falls * 0.85, delta)
	# Trees creak and groan when the wind gets up in the woods
	_creak_t -= delta
	if _creak_t <= 0.0:
		_creak_t = _rng.randf_range(4.0, 11.0)
		if w.wind > 0.55 and woods > 0.3 and player.under < 0.3:
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			Sfx.play_at(self, player.global_position + Vector2(side * _rng.randf_range(200.0, 1400.0), -300.0),
				Sfx.pool("creak", Sfx.takes("creak", 1) + Sfx.takes("creak2", 1) + Sfx.takes("creak3", 3), 1.1, 3.0), -14.0 + 8.0 * (w.wind - 0.55), 1.0, &"Calls")
	var space := lerpf(0.0, 0.45, player.under) # a cave rings
	for b in mix:
		space += SPACE.get(b, 0.03) * mix[b] * (1.0 - player.under)
	for r in _reverbs:
		r.wet = move_toward(r.wet, space, delta * 0.3)

	_call_t -= delta
	if _call_t <= 0.0:
		_call_t = 1.0
		_maybe_call(mix, daytime, twilight, night, hush * rain_mask * below * falls)

	# Music is rare so it means something: a storm building, some nightfalls and dawns, and
	# the first time the lights are seen (or the wreck found).
	_music_cooldown = maxf(_music_cooldown - delta, 0.0)
	var warning := w.storm_warning()
	if warning and not _was_warning:
		_cue("storm_cue", 0.0)
	_was_warning = warning
	var is_night := 1 if day < 0.05 else 0
	var first := _was_night < 0
	if not first and is_night != _was_night and _rng.randf() < 0.45:
		_cue("night" if is_night == 1 else "dawn", -3.0 if is_night == 1 else -6.0)
	_was_night = is_night
	for k in ["lights_seen", "crash"]:
		if Journal.has(k) and not _heard.has(k):
			_heard[k] = true
			if not first: # (already known when the game loaded: no cue)
				_cue("lights", -2.0, true)

## Once a second: maybe one call from the country around you (a woodpecker, a coyote...).
func _maybe_call(mix: Dictionary, daytime: float, twilight: float, night: float, mask: float) -> void:
	if mask < 0.05 or player.sleeping:
		return
	for b in mix:
		for cl in PROFILES.get(b, PROFILES.valley).calls:
			var when: float = {"day": daytime, "dusk": twilight, "night": night}.get(cl[2], 1.0)
			var chance: float = cl[3] / 60.0 * when * mix[b] * season_gain(cl[4]) * mask
			if _rng.randf() < chance:
				call_out(cl[0], cl[1])
				return

## Plays one take of a call somewhere around you, out of sight.
func call_out(takes: String, n: int) -> void:
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var at := player.global_position + Vector2(side * _rng.randf_range(500.0, 2200.0), -_rng.randf_range(100.0, 500.0))
	var db := _rng.randf_range(-10.0, -4.0)
	if takes in ["coyotes", "elk", "geese", "hawk", "rockfall"]:
		db -= 3.0 # these carry: usually heard far off
	Sfx.play_at(self, at, Sfx.pool(takes, Sfx.takes(takes, n), 1.05, 2.0), db, 1.0, &"Calls")

func _cue(n: String, db: float, urgent := false) -> void:
	if player.sleeping or music.playing or (_music_cooldown > 0.0 and not urgent):
		return
	music.stream = _cues[n]
	music.volume_db = db
	music.play()
	_music_cooldown = MUSIC_COOLDOWN

func _gain(n: String, target: float, delta: float) -> void:
	var p: AudioStreamPlayer = beds[n]
	var cur := db_to_linear(p.volume_db)
	p.volume_db = linear_to_db(maxf(move_toward(cur, target, FADE * delta), 0.0001))

func _exit_tree() -> void: # release playbacks so shutdown doesn't report them as leaks
	for p in beds.values() + [creek, music]:
		p.stop()
		p.stream = null
