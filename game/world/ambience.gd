class_name Ambience extends Node2D
## Layered ambience driven by clock + weather. Each bed's gain is a small rule, so the
## soundscape itself carries information: birds fall silent before rain, wind builds,
## crickets take over at night, and the creek is heard from where it is.

const FADE := 0.6 ## gain change per second

var player: Player
var terrain: Terrain
var beds := {} ## name -> AudioStreamPlayer
var creek: AudioStreamPlayer2D
var owl: AudioStreamPlayer2D
var _owl_timer := 30.0
var music: AudioStreamPlayer
var _was_warning := false
var _music_cooldown := 0.0
const MUSIC_COOLDOWN := 600.0 ## real seconds between cues: music stays rare so it means something
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	for n in ["forest_day", "dusk", "night_crickets", "wind_trees"]:
		beds[n] = _bed(n, &"Ambience")
	beds["rain"] = _bed("rain", &"Weather")
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
	owl = AudioStreamPlayer2D.new()
	owl.stream = load("res://assets/audio/owl.wav")
	owl.bus = &"Ambience"
	owl.max_distance = 4000.0
	owl.volume_db = -8.0
	add_child(owl)

func _bed(n: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/%s.wav" % n)
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	p.play(_rng.randf() * 20.0) # desync loops so seams never line up
	return p

## The water sound sits on whichever creek or river is nearest (the river runs louder).
func _place_creek() -> void:
	var best := -1
	for i in Terrain.WATERS.size():
		var w: Dictionary = Terrain.WATERS[i]
		if w.kind in ["creek", "river"] and (best < 0 or absf(w.x - player.global_position.x) < absf(Terrain.WATERS[best].x - player.global_position.x)):
			best = i
	var wd: Dictionary = Terrain.WATERS[best]
	creek.position = Vector2(wd.x, terrain.surface_of(best))
	creek.volume_db = 4.0 if wd.kind == "river" else 0.0
	creek.max_distance = 4200.0 if wd.kind == "river" else 3200.0
	creek.stream_paused = Creek.frozen() and GameClock.weather.ice > 0.9 # frozen hard: silence

func _process(delta: float) -> void:
	_place_creek()
	var c := GameClock.clock
	var w := GameClock.weather
	var h := c.hour_of_day()
	var day := c.daylight()
	var twilight := exp(-pow((h - 6.3) / 1.2, 2.0)) + exp(-pow((h - 20.0) / 1.2, 2.0))
	var night := 1.0 - smoothstep(0.0, 0.15, day)
	var hush := 1.0 - (0.85 if w.storm_warning() else 0.0) # wildlife goes quiet before rain
	var rain_mask := 1.0 - w.precip * 0.8 # snow hushes the forest too
	_gain("forest_day", smoothstep(0.05, 0.4, day) * hush * rain_mask * 0.9, delta)
	_gain("dusk", clampf(twilight, 0.0, 1.0) * hush * rain_mask * 0.7, delta)
	_gain("night_crickets", night * rain_mask * (1.0 if w.air_temp_c(c) > 4.0 else 0.2) * 0.6, delta)
	_gain("wind_trees", clampf(w.wind * 1.1, 0.05, 1.0), delta)
	_gain("rain", w.rain(), delta)

	# A storm building is one of the few moments that earns music.
	_music_cooldown = maxf(_music_cooldown - delta, 0.0)
	var warning := w.storm_warning()
	if warning and not _was_warning and _music_cooldown == 0.0 and not player.sleeping and not music.playing:
		music.play()
		_music_cooldown = MUSIC_COOLDOWN
	_was_warning = warning

	_owl_timer -= delta
	if _owl_timer <= 0.0:
		_owl_timer = _rng.randf_range(35.0, 110.0)
		if night > 0.5 and w.precip < 0.3:
			owl.global_position = player.global_position + Vector2(_rng.randf_range(-2200, 2200), -500)
			owl.pitch_scale = _rng.randf_range(0.95, 1.05)
			owl.play()

func _gain(n: String, target: float, delta: float) -> void:
	var p: AudioStreamPlayer = beds[n]
	var cur := db_to_linear(p.volume_db)
	p.volume_db = linear_to_db(maxf(move_toward(cur, target, FADE * delta), 0.0001))

func _exit_tree() -> void: # release playbacks so shutdown doesn't report them as leaks
	for p in beds.values() + [creek, owl, music]:
		p.stop()
		p.stream = null
