class_name Tips extends Node
## One-time hints, shown the first time each situation comes up. Replaces most on-screen
## popups: you learn a control once, then the world stays uncluttered. Seen tips are saved.

const CHECK_EVERY := 0.4

var player: Player
var hud: Hud
var seen := {}
var _t := 0.0
var _age := 0.0

## [id, condition, text]; text may use {interact}, {use}, {lift}, {backpack}, {build}, {rest},
## {crouch}, {slot_1}, {slot_2} which become the player's actual keys.
func _rules() -> Array:
	var p := player
	var c := p.cond
	var f := p.focus
	return [
		["start", _age > 3.0, "The valley's quiet this morning. Your hatchet and knife are strapped to your pack: {slot_1} and {slot_2} draw them."],
		["pack", _age > 25.0, "{backpack} opens your pack. Everything you carry lives there."],
		["sign", f is TrailSign, "A trail sign. Press {interact} to read it."],
		["sticks", f is WorldItem and f.stack.def.id == "sticks", "Fallen sticks. Press {interact} to pick them up. Fires need them."],
		["item", f is WorldItem, "Press {interact} to pick things up."],
		["chop", p.chop_target is ChoppableTree, "Click ({use}) to chop. The tree falls away from you."],
		["trunk", p.chop_target is FelledTrunk, "Strip the branches, then aim at a mark and click to cut a log to that length."],
		["log", p.carrying == null and p.nearest_log() != null, "{lift} lifts a log. Long logs drag behind you."],
		["creek", f is Creek, "{interact} to drink here, or fill a container you're holding. Creek water is dirty: boil it first."],
		["berries", f is BerryBush, "Serviceberries. {interact} to pick them."],
		["tracks", f is Tracks, "Tracks in the mud. {interact} to read how old they are and which way they went."],
		["deer", _deer_near(), "Deer. Crouch ({crouch}) and move slowly to get closer. Running will spook them."],
		["stalk", _deer_near() and p.held != null and p.held.def.has("knife"), "Creep up behind a grazing deer and click to take it with the knife. If it looks up, it's gone."],
		["bow", p.held != null and p.held.def.has("bow"), "Hold click to draw, release to loose. Arrows drop over distance; the chest is the shot."],
		["arrows", p.backpack.count_of("cordage") > 0 and p.backpack.count_of("sticks") >= 3, "You have cord and sticks: open the pack ({backpack}) to craft a bow, then arrows."],
		["blood", f is Tracks and f._nearest(p).get("s") == "blood", "Blood. A wounded animal went this way. Follow it, it won't run far."],
		["thirst", c.thirst < 45.0, "You're thirsty. Open the pack ({backpack}), select your bottle, and drink."],
		["hunger", c.hunger < 50.0, "You're hungry. Open the pack ({backpack}) and eat something."],
		["dusk", GameClock.clock.hour_of_day() > 18.0 and p.camp_x < 0.0, "Evening's coming. Press {build} to plan a campfire, then a lean-to to sleep in."],
		["tired", c.fatigue > 60.0, "You're tired. Sleep under a shelter ({rest})."],
		["cold", c.warmth < 35.0, "You're cold. A fire warms and dries you."],
		["snow", GameClock.weather.snow_cm > 2.0, "Snow. Every animal leaves tracks in it now, and so do you. Deep snow slows you down."],
		["ice", Creek.frozen() and f is Creek, "The creek has frozen over. Chop a hole ({interact}) to reach the water, or pack the pot with snow and melt it."],
		["hide", p.backpack.count_of("deer_hide") > 0, "A raw hide rots in a couple of days. Build a hide frame ({build}) and stretch it there to cure."],
		["tripod", f is Campfire and p.held != null and p.held.def.has("pot") and not f.tripod, "To boil water, build a pot tripod ({build}) over the fire and hang the pot from it."],
		["dry", p.backpack.count_of("venison_raw") + p.backpack.count_of("trout_raw") > 2, "Raw meat spoils fast. A drying rack ({build}) turns it into jerky that keeps for weeks."],
		["vines", f is VineTangle, "Wild vines. {interact} to gather them; three twist into cord for a bow string or a fishing line."],
		["blind", HuntingBlind.hiding(p), "Crouched in the blind, deer can barely see or hear you. Wait for one to wander past."],
		["wind", _deer_near() and GameClock.weather.wind > 0.1, "Mind the wind (bottom right): a deer downwind of you smells you long before it sees you. Come at it from downwind."],
		["trail", Chunk.on_trail(p.global_position.x), "A game trail: deer walk this line between their bedding cover and feeding ground, mostly at dawn and dusk. A good place for a blind."],
		["call", p.held != null and p.held.def.has("call"), "Click to bleat. Curious deer come to look; call more than twice in a short while and they turn wary."],
		["bench", p.backpack.count_of("sticks") >= 3 and p.backpack.count_of("cordage") > 0 and get_tree().get_nodes_in_group("workbench").is_empty(), "Bows, arrows and coats are made at a workbench ({build}). Build one at camp."],
		["whet", p.held != null and (p.held.def.has("axe") or p.held.def.has("knife")) and p.held.sharpness < 0.7, "Your edge is going dull. A whetstone (look along the creek) brings it back: select the tool in the pack."],
		["woodpile", p.carrying != null and p.carrying.size == "short", "Short logs keep best in a woodpile ({build}). At a fire close by, {interact} feeds it a log straight from the pile."],
		["rod", p.backpack.count_of("fishing_pole") > 0, "Hold the pole (select it in your pack), then click toward the creek to cast."],
		["fire", f is Campfire and not f.lit, "Press {interact} to light the fire. Feed it sticks or logs to keep it going."],
		["choices", f != null and f.is_in_group("camp") and Player.choices_of(f, p).size() > 1, "More than one thing to do here: {interact} shows the choices, then press a number."],
		["wolves", _near("wolf", 2200.0), "Wolves. They're after food: anything dead left lying out. They won't come near camp, a fire or a torch; hurt one and the pack scatters."],
		["bear", _near("black_bear", 2200.0), "A black bear. Don't walk up on it or its food: it charges to warn you. Back away. Push it and the next charge is real."],
		["torch", p.holding("torch"), "A torch lights the dark, and nothing wild comes near the flame. Click to wave it. Put it away and it goes out."],
		["spear", p.holding("spear"), "Click to thrust. Face a wolf or the bear with the spear and it won't close in."],
		["butcher", f is Carcass and f.deer() and not f.dressed, "Butcher it here and the meat goes in your pack, but the gut pile draws wolves. Or drag the whole deer home to camp."],
		["wear", p.backpack.find(func(s): return s.def.slot != "") != null, "Clothing only warms you when you wear it: open the pack ({backpack}) and drag it onto a clothing slot."],
		["snare", p.backpack.count_of("snare") > 0, "Set a snare from the build menu ({build}) and check it at dawn. A rabbit left hanging too long gets taken."],
	]

func _near(species: String, reach: float) -> bool:
	return get_tree().get_nodes_in_group("predators").any(func(a): return a.def.id == species and absf(a.position.x - player.global_position.x) < reach)

func _deer_near() -> bool:
	for a in get_tree().get_nodes_in_group("animals"):
		if absf(a.position.x - player.global_position.x) < 1100.0:
			return true
	return false

func _process(delta: float) -> void:
	_age += delta
	_t -= delta
	if _t > 0.0 or player.sleeping or player.dead or get_tree().paused:
		return
	_t = CHECK_EVERY
	for r in _rules():
		if r[1] and not seen.has(r[0]):
			seen[r[0]] = true
			hud.tip(_keys(r[2]))
			return # one at a time

static func _keys(text: String) -> String:
	for a in ["interact", "use", "lift", "backpack", "build", "rest", "crouch", "slot_1", "slot_2"]:
		text = text.replace("{%s}" % a, "[%s]" % Keys.label(a))
	return text
