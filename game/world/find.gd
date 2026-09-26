class_name Find extends Node2D
## Small things scattered through the country, each where it would really be: bleached bones
## and a cow skull out on the flats, a shed antler in the meadow grass, an old fire ring, a
## wagon wheel sinking into the sage, a glass bottle half-buried by the river, a brass survey
## benchmark set in a high rock, a squirrel's hoard in a hollow log, a rusted trap on its chain.
## Most are just there to come across; some can be searched once (the chunk's "found" table).

## kind -> [biomes it turns up in, what searching it is called ("" = just scenery)]
const KINDS := {
	"bones": [["sage", "meadow", "valley", "foothills", "burn", "alpine", "desert", "canyon", "boulders", "grove", "river"], ""],
	"skull": [["sage", "desert", "canyon"], ""],
	"antler": [["meadow", "valley", "foothills", "grove", "oldgrowth", "river", "burn"], ""],
	"cairn": [["alpine", "boulders", "desert", "canyon", "ridge"], ""],
	"fence": [["sage", "meadow", "desert"], ""],
	"fire_ring": [["valley", "river", "meadow", "foothills", "oldgrowth", "grove", "desert", "canyon", "sage", "marsh"], "Search the old fire ring"],
	"wagon": [["sage", "desert", "meadow", "canyon"], "Pull boards off the old wagon"],
	"bottle": [["river", "marsh", "valley", "sage", "meadow", "desert", "canyon"], "Dig out the glass bottle"],
	"benchmark": [["ridge", "alpine", "boulders", "canyon", "foothills", "desert"], "Read the brass marker"],
	"hollow_log": [["oldgrowth", "valley", "foothills", "grove", "river", "desert"], "Reach into the hollow log"],
	"trap": [["river", "marsh", "valley", "oldgrowth"], "Look at the rusted trap"],
	"grave": [["sage", "desert", "meadow", "canyon"], "Read the marker"],
}
const NAMES := ["ANNA LIND", "W. HOLLIS", "BABY GIRL", "T. McCANN", "UNKNOWN", "SAM DRAKE", "MARY ORR"]

var chunk: Chunk
var n := 0
var kind := "bones"

func setup(c: Chunk, id: int, k: String) -> void:
	chunk = c
	n = id
	kind = k

func _ready() -> void:
	z_as_relative = false
	z_index = 2
	if KINDS[kind][1] != "":
		add_to_group("interactable")
		add_to_group("camp")

## Picks something that belongs in this country (or "" if nothing does).
static func pick_for(biome: String, rng: RandomNumberGenerator) -> String:
	var pool := KINDS.keys().filter(func(k): return biome in KINDS[k][0])
	return pool[rng.randi() % pool.size()] if pool else ""

func found() -> bool:
	return chunk.world.chunk_state(chunk.index).get("found", {}).has(str(n))

func _mark() -> void:
	var st := chunk.world.chunk_state(chunk.index)
	if not st.has("found"):
		st.found = {}
	st.found[str(n)] = GameClock.clock.hours
	queue_redraw()

func interact_pos() -> Vector2:
	return global_position + Vector2(0, -20)

func interact_label(_p: Player) -> String:
	if kind in ["bottle", "hollow_log", "wagon", "fire_ring"] and found():
		return ""
	return KINDS[kind][1]

func interact(p: Player) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([n, chunk.index, kind])
	match kind:
		"fire_ring":
			_mark()
			var roll := rng.randf()
			if roll < 0.2:
				_give(p, "tinned_beans", 1, "Under the ashes and a rusted grate: a tin of beans someone left behind.")
			elif roll < 0.35:
				_give(p, "matches", 1, "A little tin pushed between the stones, and in it a box of matches, dry.")
			else:
				_give(p, "sticks", 2, "Only charcoal and a few half-burned sticks. Still, it'll burn.")
		"wagon":
			_mark()
			_give(p, "sticks", 3, "The boards come away rotten at the ends, dry in the middle. Firewood.")
		"bottle":
			_mark()
			_give(p, "glass_bottle", 1, "An old glass bottle, thick and green, not a chip in it. Rinsed out it'll hold water.")
		"hollow_log":
			_mark()
			if rng.randf() < 0.6:
				_give(p, "pine_nuts", 3, "A squirrel's hoard: a pile of pine nuts in the dry heart of the log.")
			else:
				p.message.emit("Leaves, a few old shells. Something's been here before you.")
		"benchmark":
			p.message.emit("A brass disc set into the rock: U.S. GEOLOGICAL SURVEY · BENCH MARK · ELEV %d FT · 1958. Someone has scratched an arrow beside it, pointing east." % (5200 + (n * 37 + chunk.index * 211) % 3400))
			Journal.note("benchmark", "Brass survey markers set in the rock here and there, U.S. Geological Survey, 1958. The survey has been over this whole country. On some of them someone has scratched an arrow, always pointing east.")
		"trap":
			p.message.emit("An old leg-hold trap rusted shut on its chain. Stamped into the pan: J.T.")
			Journal.note("old_traps", "Old steel traps rusting on their chains along the water. The pans are stamped J.T.: the trapper from the Sweetwater camp ran a long line.")
		"grave":
			var who: String = NAMES[(n + chunk.index * 3) % NAMES.size()]
			p.message.emit("A weathered board over a low mound of stones: %s. %d." % [who, 1880 + (n * 13 + chunk.index * 7) % 45])
			Journal.note("graves", "Lone graves out on the dry flats, stones piled so the coyotes couldn't dig. People crossed this country long before me, and not all of them made it.")

func _give(p: Player, id: String, count: int, text: String) -> void:
	var s := ItemStack.make(id, GameClock.clock.hours, count)
	if not p.receive(s, false):
		chunk.world.spawn({"kind": "item", "x": global_position.x + 30.0, "stack": s.to_dict()})
	p.message.emit(text)

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([n, kind])
	var bone := Color("d8d0bc")
	var wood := Color("6a5a48")
	match kind:
		"bones":
			for k in 5:
				var a := Vector2(rng.randf_range(-60, 60), -rng.randf_range(0, 4))
				draw_line(a, a + Vector2.from_angle(rng.randf_range(-0.4, 0.4) + (PI if k % 2 else 0.0)) * rng.randf_range(18, 34), bone.darkened(rng.randf() * 0.15), 4.0)
			for k in 4: # ribs
				draw_arc(Vector2(10 + k * 12, 2), 16.0, PI * 1.1, PI * 1.9, 6, bone, 3.0)
		"skull": # a steer skull, horns and all
			draw_colored_polygon(PackedVector2Array([Vector2(-16, -2), Vector2(16, -2), Vector2(12, -26), Vector2(-12, -26)]), bone)
			draw_line(Vector2(-12, -22), Vector2(-46, -34), bone.darkened(0.1), 5.0)
			draw_line(Vector2(12, -22), Vector2(46, -34), bone.darkened(0.1), 5.0)
			draw_circle(Vector2(-6, -16), 4.0, Color(0.15, 0.12, 0.1))
			draw_circle(Vector2(6, -16), 4.0, Color(0.15, 0.12, 0.1))
		"antler":
			var base := Vector2(0, -3)
			draw_line(base, base + Vector2(60, -16), bone.darkened(0.2), 5.0)
			for k in 3:
				var t := base + Vector2(18 + k * 16, -5 - k * 4)
				draw_line(t, t + Vector2(8, -18), bone.darkened(0.15), 4.0)
		"cairn":
			var y := 0.0
			for k in 5:
				var r := 26.0 - k * 4.0
				draw_colored_polygon(Transform2D(0.0, Vector2(1, 0.6), 0.0, Vector2(rng.randf_range(-4, 4), y - r * 0.5)) * SceneryArt.blob(Vector2.ZERO, r, rng, 8, 0.2), Palette.ROCK.darkened(rng.randf_range(0.0, 0.2)))
				y -= r * 1.1
		"fence": # a few grey posts still standing, a sag of wire
			var prev := Vector2.INF
			for k in 4:
				var top := Vector2(-120 + k * 80, -rng.randf_range(60, 85))
				draw_line(Vector2(top.x, 4), top, wood.darkened(0.1), 6.0)
				if prev != Vector2.INF and k != 2:
					draw_line(prev + Vector2(0, 12), top + Vector2(0, 12), Color(0.4, 0.38, 0.36, 0.8), 1.2)
					draw_line(prev + Vector2(0, 34), top + Vector2(0, 30), Color(0.4, 0.38, 0.36, 0.8), 1.2)
				prev = top
		"fire_ring":
			for k in 8:
				draw_colored_polygon(SceneryArt.blob(Vector2(-56 + k * 16, -4), 9.0, rng, 6, 0.25), Palette.ROCK.darkened(0.25))
			draw_rect(Rect2(-40, -6, 80, 5), Color(0.12, 0.11, 0.1))
		"wagon": # a wheel half sunk in the ground and a few boards
			draw_arc(Vector2(0, -30), 52.0, PI * 0.95, TAU * 1.02, 18, wood, 7.0)
			for k in 6:
				var ang := PI + k * PI / 6.0
				draw_line(Vector2(0, -30), Vector2(0, -30) + Vector2.from_angle(ang) * 50.0, wood.darkened(0.1), 4.0)
			draw_circle(Vector2(0, -30), 9.0, wood.darkened(0.3))
			if not found():
				for k in 3:
					draw_line(Vector2(60 + k * 8, 2 - k * 6), Vector2(170 + k * 6, -6 - k * 8), wood.lightened(0.05 * k), 9.0)
		"bottle":
			if not found():
				draw_colored_polygon(PackedVector2Array([Vector2(-14, 2), Vector2(10, 2), Vector2(14, -8), Vector2(28, -12), Vector2(28, -17), Vector2(12, -15), Vector2(-14, -12)]), Color(0.3, 0.55, 0.4, 0.85))
				draw_line(Vector2(-8, -9), Vector2(6, -9), Color(0.8, 0.95, 0.85, 0.7), 1.5)
		"benchmark": # a boulder with the brass disc on it
			draw_colored_polygon(SceneryArt.blob(Vector2(0, -26), 40.0, rng, 9, 0.2), Palette.ROCK.darkened(0.05))
			draw_circle(Vector2(6, -40), 7.0, Color("b08a3a"))
			draw_circle(Vector2(6, -40), 3.0, Color("8a6a2a"))
		"hollow_log":
			draw_colored_polygon(PackedVector2Array([Vector2(-120, 4), Vector2(110, 4), Vector2(104, -48), Vector2(-116, -50)]), Palette.BARK)
			draw_circle(Vector2(110, -22), 26.0, Palette.BARK.darkened(0.1))
			draw_circle(Vector2(110, -22), 17.0, Color(0.1, 0.08, 0.06))
			draw_line(Vector2(-100, -46), Vector2(80, -48), Color("4d6a32"), 5.0)
		"trap":
			draw_arc(Vector2(0, -6), 16.0, PI, TAU, 10, Color("5a4a40"), 3.0)
			draw_line(Vector2(-18, -2), Vector2(18, -2), Color("5a4a40"), 3.0)
			draw_polyline(PackedVector2Array([Vector2(18, -2), Vector2(34, 0), Vector2(48, -3), Vector2(60, 0)]), Color("6a5a50"), 2.0)
			draw_line(Vector2(62, 2), Vector2(62, -18), wood, 4.0)
		"grave": # a low mound of stones and a leaning board
			for k in 7:
				draw_colored_polygon(SceneryArt.blob(Vector2(-40 + k * 13, -6 - (3 - absf(k - 3)) * 4.0), 11.0, rng, 6, 0.25), Palette.ROCK.darkened(rng.randf_range(0.0, 0.2)))
			draw_line(Vector2(-54, 4), Vector2(-60, -66), wood.darkened(0.1), 6.0)
			draw_line(Vector2(-76, -48), Vector2(-42, -50), wood.darkened(0.1), 5.0)
