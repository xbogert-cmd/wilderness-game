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
	return [
		["start", _age > 3.0, "The valley's quiet this morning. Your hatchet and knife are strapped to your pack: {slot_1} and {slot_2} draw them."],
		["pack", _age > 25.0, "{backpack} opens your pack. Everything you carry lives there."],
		["sign", p.focus is TrailSign, "A trail sign. Press {interact} to read it."],
		["sticks", p.focus is WorldItem and p.focus.stack.def.id == "sticks", "Fallen sticks. Press {interact} to pick them up. Fires need them."],
		["item", p.focus is WorldItem, "Press {interact} to pick things up."],
		["chop", p.chop_target is ChoppableTree, "Click ({use}) to chop. The tree falls away from you."],
		["trunk", p.chop_target is FelledTrunk, "Strip the branches, then aim at a mark and click to cut a log to that length."],
		["log", p.carrying == null and p.nearest_log() != null, "{lift} lifts a log. Long logs drag behind you."],
		["creek", p.focus is Creek, "{interact} to drink here, or fill a container you're holding. Creek water is dirty: boil it first."],
		["berries", p.focus is BerryBush, "Serviceberries. {interact} to pick them."],
		["tracks", p.focus is Tracks, "Tracks in the mud. {interact} to read how old they are and which way they went."],
		["deer", _deer_near(), "Deer. Crouch ({crouch}) and move slowly to get closer. Running will spook them."],
		["thirst", c.thirst < 45.0, "You're thirsty. Open the pack ({backpack}), select your bottle, and drink."],
		["hunger", c.hunger < 50.0, "You're hungry. Open the pack ({backpack}) and eat something."],
		["dusk", GameClock.clock.hour_of_day() > 18.0 and p.camp_x < 0.0, "Evening's coming. Press {build} to plan a campfire, then a lean-to to sleep in."],
		["tired", c.fatigue > 60.0, "You're tired. Sleep under a shelter ({rest})."],
		["cold", c.warmth < 35.0, "You're cold. A fire warms and dries you."],
		["rod", p.backpack.count_of("fishing_pole") > 0, "Hold the pole (select it in your pack), then click toward the creek to cast."],
		["fire", p.focus is Campfire and not p.focus.lit, "Press {interact} to light the fire. Feed it sticks or logs to keep it going."],
	]

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
