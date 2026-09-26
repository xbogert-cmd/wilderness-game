class_name Plant extends Node2D
## A wild plant worth knowing. Until you've picked one of a kind it's just "an unknown plant"
## with a description of its look; once picked you know it, and after that the prompt names it
## before you gather, so you can leave what you don't want. Water hemlock looks a lot like
## yarrow, and is deadly to eat. Most die back in winter; rose hips and willow bark don't.
## Grows back over a season of growing weather (per-chunk "picked" table, like berry bushes).

## id -> [name, what it looks like before you know it, where, winter-hardy, journal entry]
const SPECIES := {
	"yarrow": ["Yarrow", "feathery leaves, flat clusters of tiny white flowers", "dry", false,
		"Yarrow: feathery leaves, flat white flower heads. Chewed and pressed into a wound it stops the bleeding and keeps it clean."],
	"water_hemlock": ["Water hemlock", "tall, purple-streaked stems, white flower umbrellas", "wet", false,
		"Water hemlock: grows by water, tall with purple-streaked stems and white umbrellas of flowers. Looks like yarrow from a distance. Deadly poison: never eat it."],
	"mint": ["Wild mint", "low square stems, toothed leaves, little lilac whorls", "wet", false,
		"Wild mint: low, by the water, smells sharp when crushed. Settles a sick stomach."],
	"willow": ["Willow", "a thin shrub with long narrow leaves and red stems", "wet", true,
		"Willow: the inner bark, chewed, eases a fever. Strips off any time of year."],
	"rose": ["Wild rose", "a thorny shrub with pink flowers or red hips", "any", true,
		"Wild rose: the hips stay on through winter. Tart, a little food, good for you."],
	"arnica": ["Arnica", "a single yellow daisy on a hairy stem", "high", false,
		"Arnica: yellow daisies in the high country. Rubbed on a sprain it takes the swelling down."],
	"chanterelle": ["Chanterelles", "golden trumpet-shaped mushrooms in the moss", "forest", false,
		"Chanterelles: golden, trumpet-shaped, ridges running down the stem instead of gills, smelling of apricots. Good eating."],
	"fly_agaric": ["Fly agaric", "a red mushroom cap flecked with white", "forest", false,
		"Fly agaric: the red mushroom with white flecks from the storybooks. Poisonous. Leave it be."],
	"prickly_pear": ["Prickly pear", "a low cactus of flat spiny pads, red-purple fruit on the rims", "dry", true,
		"Prickly pear: flat spiny pads in the dry country. The fruit is sweet once the spines are rubbed off."],
	"yucca": ["Yucca", "a spiky rosette of stiff, sword-like leaves", "dry", true,
		"Yucca: stiff sword-shaped leaves full of strong fibers. Strip them and twist the fiber into cord."],
}
const ACTION := {"yarrow": "Pick yarrow", "water_hemlock": "Pick water hemlock  (poisonous)", "mint": "Pick wild mint",
	"willow": "Strip willow bark", "rose": "Pick rose hips", "arnica": "Pick arnica", "chanterelle": "Pick chanterelles",
	"fly_agaric": "Pick fly agaric  (poisonous)", "prickly_pear": "Pick prickly pears", "yucca": "Strip yucca fiber"}
const ITEM := {"yarrow": "yarrow", "water_hemlock": "water_hemlock", "mint": "mint", "willow": "willow_bark", "rose": "rose_hips", "arnica": "arnica",
	"chanterelle": "chanterelle", "fly_agaric": "fly_agaric", "prickly_pear": "prickly_pear", "yucca": "yucca_fiber"}

var chunk: Chunk
var n := 0
var species := "yarrow"
var picked_hour := -INF

func setup(c: Chunk, id: int, sp: String, picked: float) -> void:
	chunk = c
	n = id
	species = sp
	picked_hour = picked

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("camp") # a key popup: it names what you know
	add_to_group("plant")
	z_as_relative = false
	z_index = 2

## Which plants grow where: by water, in dry open ground, up high, or anywhere.
static func pick_for(biome: String, near_water: bool, rng: RandomNumberGenerator) -> String:
	var pool: Array = []
	if near_water:
		pool = ["water_hemlock", "mint", "mint", "willow", "willow", "water_hemlock"]
	match biome:
		"sage", "meadow", "valley": pool += ["yarrow", "yarrow", "rose", "rose", "yarrow"]
		"marsh", "river": pool += ["willow", "mint", "water_hemlock", "rose"]
		"foothills", "ridge", "burn": pool += ["arnica", "yarrow", "rose"]
		"alpine", "boulders": pool += ["arnica", "arnica", "yarrow"]
		"desert", "canyon": pool = ["prickly_pear", "prickly_pear", "yucca", "yucca", "rose"] if not near_water else pool + ["willow", "mint"]
		"oldgrowth": pool += ["chanterelle", "chanterelle", "fly_agaric", "fly_agaric", "mint"]
		"grove": pool += ["yarrow", "rose", "chanterelle", "arnica"]
	return pool[rng.randi() % pool.size()]

func available() -> bool:
	if GameClock.clock.growing_hours(picked_hour) < GameClock.clock.season_hours(): # a season of growing weather
		return false
	if not SPECIES[species][3] and (GameClock.clock.season() == 3 or GameClock.weather.snow_cm > 10.0):
		return false # died back for winter
	return true

func _process(_delta: float) -> void:
	var v: bool = available() or SPECIES[species][3]
	if v != visible:
		visible = v

func interact_pos() -> Vector2:
	return global_position + Vector2(0, -20)

static func known(p: Player, sp: String) -> bool:
	return p.known_plants.has(sp)

func interact_label(p: Player) -> String:
	if not available():
		return ""
	if known(p, species):
		return ACTION[species]
	return "Unknown plant: " + SPECIES[species][1]

func interact(p: Player) -> void:
	if not available():
		return
	var first := not known(p, species)
	var item: String = ITEM[species]
	if not p.receive(ItemStack.make(item, GameClock.clock.hours, 2), false):
		return
	picked_hour = GameClock.clock.hours
	chunk.world.mark(chunk.index, "picked", n)
	if first:
		p.known_plants[species] = true
		p.message.emit("You know this one now: %s." % SPECIES[species][0].to_lower() + ("  Poisonous: don't eat it." if species == "water_hemlock" else ""))
		Journal.note("plant_" + species, SPECIES[species][4])
	queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 31 + 7
	var stem := Color("5d6e3a")
	var leaf := Color("6f8a45")
	match species:
		"yarrow":
			for i in 3:
				var x := -10.0 + i * 10.0
				var h := rng.randf_range(48, 62)
				draw_line(Vector2(x, 2), Vector2(x, -h), stem, 2.0)
				for k in 4: # feathery leaves
					var y := -8.0 - k * 9.0
					draw_line(Vector2(x, y), Vector2(x + (6 if k % 2 else -6), y - 5), leaf, 2.0)
				for k in 7: # a flat white head
					draw_circle(Vector2(x - 7 + k * 2.4, -h - absf(k - 3) * -0.6), 2.4, Color("eeeae0"))
		"water_hemlock":
			for i in 2:
				var x := -9.0 + i * 16.0
				var h := rng.randf_range(90, 115)
				draw_line(Vector2(x, 2), Vector2(x, -h), Color("5a5a3a"), 3.0)
				for k in 3: # purple streaks
					draw_line(Vector2(x, -12.0 - k * 26.0), Vector2(x, -22.0 - k * 26.0), Color("6a3a5a"), 3.0)
				for k in 5: # an umbrella of stalks, each with a white tuft
					var tip := Vector2(x + (k - 2) * 7.0, -h - 12.0 + absf(k - 2) * 3.0)
					draw_line(Vector2(x, -h), tip, stem, 1.2)
					draw_circle(tip, 3.2, Color("eeeae0"))
				draw_line(Vector2(x, -40), Vector2(x + 16, -52), leaf, 3.0)
		"mint":
			for i in 5:
				var x := -16.0 + i * 8.0
				var h := rng.randf_range(24, 36)
				draw_line(Vector2(x, 2), Vector2(x, -h), stem, 2.0)
				for k in 3:
					var y := -6.0 - k * 9.0
					draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x - 7, y - 3), Vector2(x, y - 6)]), leaf.lightened(0.1))
					draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 7, y - 3), Vector2(x, y - 6)]), leaf)
				draw_circle(Vector2(x, -h - 2), 2.6, Color("b8a0d0"))
		"willow":
			for i in 5:
				var base := Vector2(-12.0 + i * 6.0, 2)
				var tip := base + Vector2(rng.randf_range(-22, 22), -rng.randf_range(80, 120))
				draw_line(base, tip, Color("8a3a2a"), 2.5) # red stems
				for k in 4:
					var p := base.lerp(tip, 0.35 + k * 0.17)
					draw_line(p, p + Vector2((10 if k % 2 else -10), 5), Color("8a9a55"), 2.5) # long narrow leaves
		"rose":
			for i in 4:
				var base := Vector2(-14.0 + i * 9.0, 2)
				var tip := base + Vector2(rng.randf_range(-16, 16), -rng.randf_range(45, 70))
				draw_line(base, tip, Color("5a4a30"), 2.5)
				draw_colored_polygon(SceneryArt.blob(base.lerp(tip, 0.6), 8.0, rng, 6, 0.3), leaf.darkened(0.1))
				var y := GameClock.clock.year_pos()
				var hips := y > 0.55 or y < 0.2 # late summer into spring
				if available():
					if hips:
						draw_circle(tip, 3.6, Color("b83a2a"))
					else:
						draw_circle(tip, 4.0, Color("e8a0b8"))
		"chanterelle":
			for i in 4:
				var x := -16.0 + i * 10.0
				var h := rng.randf_range(14, 24)
				draw_line(Vector2(x, 2), Vector2(x, -h), Color("d8a040"), 5.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 9, -h - 2), Vector2(x + 9, -h - 4), Vector2(x + 3, -h + 6), Vector2(x - 3, -h + 6)]), Color("e0a83a"))
		"fly_agaric":
			for i in 2:
				var x := -10.0 + i * 20.0
				var h := rng.randf_range(20, 32)
				draw_line(Vector2(x, 2), Vector2(x, -h), Color("ece2c8"), 5.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 15, -h + 2), Vector2(x - 11, -h - 9), Vector2(x, -h - 13), Vector2(x + 11, -h - 9), Vector2(x + 15, -h + 2)]), Color("c42a1e"))
				for k in 4:
					draw_circle(Vector2(x - 8 + k * 5, -h - 5 - (k % 2) * 4), 1.8, Color.WHITE)
		"prickly_pear":
			var pads := [Vector2(0, -18), Vector2(-16, -40), Vector2(14, -44), Vector2(-2, -64)]
			for i in pads.size():
				var c: Vector2 = pads[i]
				draw_colored_polygon(Transform2D(rng.randf_range(-0.4, 0.4), Vector2(1, 1.35), 0.0, c) * SceneryArt.blob(Vector2.ZERO, 14.0, rng, 10, 0.08), Color("6a8a4a").darkened(0.06 * i))
				for k in 3:
					draw_circle(c + Vector2(rng.randf_range(-8, 8), rng.randf_range(-12, 12)), 1.2, Color("e8e0b0"))
				if available() and i > 0:
					draw_circle(c + Vector2(6, -18), 5.0, Color("a02a5a"))
		"yucca":
			for i in 11:
				var a := lerpf(-2.7, -0.45, i / 10.0)
				var l := rng.randf_range(50, 80)
				draw_line(Vector2(0, 0), Vector2.from_angle(a) * l, Color("7a8a5a").darkened(0.08 * (i % 2)), 4.0)
		"arnica":
			for i in 2:
				var x := -6.0 + i * 12.0
				var h := rng.randf_range(30, 42)
				draw_line(Vector2(x, 2), Vector2(x, -h), stem, 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 6, -6), Vector2(x, -12), Vector2(x + 6, -6), Vector2(x, -2)]), leaf)
				for k in 8:
					var a := TAU * k / 8.0
					draw_line(Vector2(x, -h), Vector2(x, -h) + Vector2.from_angle(a) * 7.0, Color("e8b830"), 2.5)
				draw_circle(Vector2(x, -h), 2.8, Color("c07a20"))
