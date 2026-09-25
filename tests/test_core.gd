extends RefCounted

var t # runner

func test_clock_rollover() -> void:
	var c := Clock.new()
	c.hours = 0.0
	var dh := c.advance(c.day_length_sec) # one real day
	t.near(dh, 24.0, "one day length = 24h")
	t.ok(c.day() == 1, "day 1")
	c.hours = 0.0
	t.ok(c.season() == 2 and c.season_name() == "early autumn", "the journey starts in early autumn")
	c.hours = 24.0 * c.days_per_season
	t.ok(c.season() == 3, "then winter")
	c.hours = 24.0 * c.days_per_season * 4
	t.ok(c.season() == 2, "seasons wrap")
	c.hours = 24.0 * c.days_per_season * 1.5 + 13.0 # midwinter noon
	var winter_day := c.sunset() - c.sunrise()
	t.near(c.solar_hour(), Clock.NOON, "noon stays noon for the sky", 0.01)
	c.hours = 24.0 * c.days_per_season * 3.5 # midsummer
	t.ok(c.sunset() - c.sunrise() > winter_day + 5.0, "summer days are much longer than winter's")

func test_daylight() -> void:
	var c := Clock.new()
	c.hours = 13.0
	t.near(c.daylight(), 1.0, "noon bright", 0.01)
	c.hours = 2.0
	t.near(c.daylight(), 0.0, "2am dark")
	t.ok(c.is_night())

func test_weather_deterministic() -> void:
	var a := Weather.new(42)
	var b := Weather.new(42)
	for i in 500:
		a.step(0.1)
		b.step(0.1)
	t.ok(a.kind == b.kind and a.hours_left == b.hours_left, "same seed same weather")

func test_rain_always_warned() -> void:
	var w := Weather.new(7)
	var warned := false
	var rains := 0
	var prev := w.kind
	for i in 20000:
		if w.storm_warning():
			warned = true
		w.step(0.05)
		if w.kind == Weather.Kind.RAIN and prev != Weather.Kind.RAIN:
			t.ok(warned, "rain at step %d had no warning" % i)
			rains += 1
		if w.kind != prev:
			warned = false
		prev = w.kind
	t.ok(rains > 3, "rain happens sometimes (%d)" % rains)

func test_weather_roundtrip() -> void:
	var a := Weather.new(3)
	for i in 50: a.step(0.3)
	var b := Weather.new(99)
	b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	for i in 200:
		a.step(0.3)
		b.step(0.3)
	t.ok(a.kind == b.kind and is_equal_approx(a.hours_left, b.hours_left), "rng survives save")

func test_hunger_and_starving() -> void:
	var c := Condition.new()
	c.tick(10.0, {})
	t.near(c.hunger, 70.0, "hunger drains")
	c.hunger = 0.0
	var h := c.health
	c.tick(1.0, {})
	t.ok(c.health < h, "starving hurts")

func test_rain_wets_shelter_protects() -> void:
	var open := Condition.new()
	var roof := Condition.new()
	open.tick(0.5, {"precip": 1.0})
	roof.tick(0.5, {"precip": 1.0, "sheltered": true})
	t.ok(open.wetness > 0.3, "rain wets")
	t.near(roof.wetness, 0.0, "shelter keeps dry")

func test_fire_warms_and_dries() -> void:
	var c := Condition.new()
	c.wetness = 1.0
	c.warmth = 10.0
	c.tick(1.0, {"air_c": 2.0, "heat": 1.0})
	t.ok(c.wetness < 1.0, "fire dries")
	t.ok(c.warmth > 10.0, "fire warms")

func test_cold_wet_night_hurts() -> void:
	var c := Condition.new()
	c.wetness = 1.0
	for i in 60: c.tick(0.1, {"air_c": -2.0})
	t.ok(c.health < 100.0, "hypothermia damages")

func test_leg_injury() -> void:
	var c := Condition.new()
	c.injure("legs", "sprain", 0.6)
	var raw := c.move_speed_mult()
	t.ok(raw < 0.8, "sprain slows")
	c.treat("legs")
	t.ok(c.move_speed_mult() > raw, "splint helps")
	c.tick(200.0, {"air_c": 20.0})
	c.hunger = 100.0
	t.ok(not c.injuries.has("legs"), "heals eventually")

func test_condition_roundtrip() -> void:
	var a := Condition.new()
	a.injure("arms", "cut", 0.3)
	a.tick(3.0, {"precip": 1.0})
	var b := Condition.new()
	b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	t.near(b.wetness, a.wetness, "wetness")
	t.near(b.severity("arms"), a.severity("arms"), "injury")

func test_fatigue_builds_awake_and_sleep_restores() -> void:
	var c := Condition.new()
	for i in 18: c.tick(1.0, {"air_c": 18.0})
	t.ok(c.fatigue > 90.0, "a long day is exhausting (%.0f)" % c.fatigue)
	var good := Condition.new()
	var poor := Condition.new()
	good.fatigue = 90.0
	poor.fatigue = 90.0
	for i in 4:
		good.tick(1.0, {"air_c": 18.0, "sleeping": true, "sleep_quality": 1.0})
		poor.tick(1.0, {"air_c": 18.0, "sleeping": true, "sleep_quality": 0.3})
	t.ok(good.fatigue < poor.fatigue - 20.0, "better sleep restores more (%.0f vs %.0f)" % [good.fatigue, poor.fatigue])
	t.ok(c.to_dict().has("fatigue"), "fatigue saved")

func test_sleeping_bag_insulates() -> void:
	var bag := Condition.new()
	var none := Condition.new()
	for i in 20:
		bag.tick(0.3, {"air_c": 2.0, "sleeping": true, "insulation_c": 8.0})
		none.tick(0.3, {"air_c": 2.0, "sleeping": true})
	t.ok(bag.warmth > none.warmth + 10.0, "bag keeps you warmer (%.0f vs %.0f)" % [bag.warmth, none.warmth])

func test_snow_lies_and_melts() -> void:
	var w := Weather.new(3)
	w.precip = 1.0
	w._ground(2.0, -6.0) # two hours of heavy snow in the cold
	t.ok(w.snowfall() > 0.9 and w.rain() < 0.1, "falls as snow below freezing")
	t.near(w.snow_cm, 2.0 * Weather.SNOW_CM_PER_HOUR, "lies at the snowfall rate", 0.5)
	w.precip = 0.0
	w._ground(10.0, 5.0)
	t.ok(w.snow_cm == 0.0 and w.rain() == 0.0, "melts away in a thaw")
	w._ground(8.0, -10.0)
	t.ok(w.ice > 0.5, "a long hard cold freezes the creek (%.2f)" % w.ice)
	w._ground(20.0, 6.0)
	t.ok(w.ice == 0.0, "and it thaws")
