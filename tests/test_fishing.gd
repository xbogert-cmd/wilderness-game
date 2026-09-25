extends RefCounted

var t

func _strike_when_in_zone(f: FishFight) -> int:
	for i in 2000:
		f.step(1.0 / 120.0)
		if f.in_zone():
			return f.strike()
	return -1

func _strike_when_outside(f: FishFight) -> int:
	for i in 2000:
		f.step(1.0 / 120.0)
		if absf(f.needle - f.zone) > f.zone_half() + 0.05:
			return f.strike()
	return -1

func test_good_timing_lands_the_fish() -> void:
	for kind in FishFight.SPECIES:
		var f := FishFight.new(kind, 3)
		var r := FishFight.Result.NONE
		var strikes := 0
		while r != FishFight.Result.LANDED and strikes < 20:
			r = _strike_when_in_zone(f)
			strikes += 1
		t.ok(r == FishFight.Result.LANDED, "%s landed" % kind)
		t.ok(strikes == f.spec.hits, "%s needs exactly %d good strikes (took %d)" % [kind, f.spec.hits, strikes])

func test_three_misses_lose_it() -> void:
	var f := FishFight.new("whitefish", 5)
	t.ok(_strike_when_outside(f) == FishFight.Result.MISS, "first miss")
	t.ok(_strike_when_outside(f) == FishFight.Result.MISS, "second miss")
	t.ok(_strike_when_outside(f) == FishFight.Result.ESCAPED, "third miss: it throws the hook")

func test_species_feel_different() -> void:
	var trout := FishFight.new("trout", 1)
	var white := FishFight.new("whitefish", 1)
	t.ok(trout.speed() > white.speed() and trout.zone_half() < white.zone_half(), "trout is quicker with a smaller window")

func test_ease_slows_it_down() -> void:
	t.ok(FishFight.new("trout", 1, 0.6).speed() < FishFight.new("trout", 1).speed(), "accessibility setting slows the needle")

func test_needle_stays_on_the_line() -> void:
	var f := FishFight.new("trout", 9)
	for i in 5000:
		f.step(1.0 / 60.0)
		if i % 500 == 0:
			t.ok(f.needle >= 0.0 and f.needle <= 1.0 and f.zone >= 0.0 and f.zone <= 1.0, "bounds")
