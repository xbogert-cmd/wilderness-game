class_name FishLife extends RefCounted
## What swims where, and when. Creeks hold cutthroat trout and whitefish; the Sweetwater's slow
## pools whitefish, trout and catfish (which feed at night); the marsh pond perch; the tarn
## grayling and trout. In autumn the salmon come up the river to spawn, as far as the falls:
## the river and the Falls Pool are thick with them, and they jump.

const IN_WATER := {
	"creek": [["trout", 0.8], ["whitefish", 0.2]],
	"river": [["whitefish", 0.45], ["trout", 0.3], ["catfish", 0.25]],
	"pond": [["perch", 0.85], ["catfish", 0.15]],
	"lake": [["grayling", 0.65], ["trout", 0.35]],
	"pool": [["trout", 0.7], ["whitefish", 0.3]],
}
const RUN_WATERS := ["river", "pool"] ## where the salmon come

## Autumn's first two thirds: the salmon are running.
static func salmon_run() -> bool:
	var y := GameClock.clock.year_pos()
	return y >= 0.5 and y < 0.67

static func night() -> bool:
	return GameClock.clock.daylight() < 0.2

## One fish from this water, by the odds right now. deep: a deep spot (trout lie deep).
static func pick(kind: String, rng: RandomNumberGenerator, deep := true) -> String:
	var table: Array = IN_WATER.get(kind, IN_WATER.creek).duplicate(true)
	for e in table:
		if e[0] == "catfish":
			e[1] *= 2.5 if night() else 0.4
		elif e[0] == "trout" and kind == "creek":
			e[1] = 0.8 if deep else 0.45
	if salmon_run() and kind in RUN_WATERS:
		table.append(["salmon", 1.4])
	var total := 0.0
	for e in table:
		total += e[1]
	var r := rng.randf() * total
	for e in table:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return table[0][0]

## Bites come this much sooner (<1) here now: during the run the river's full of fish.
static func bite_mult(kind: String) -> float:
	return 0.55 if salmon_run() and kind in RUN_WATERS else 1.0
