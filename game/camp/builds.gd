class_name Builds extends RefCounted
## Build and recipe definitions (data). Structures are placed as blueprints and need
## physical materials delivered; small items are crafted from the pack's recipe list.
## Material keys: item ids come from the pack; "short"/"medium"/"long" are carried logs.

const STRUCTURES := {
	"campfire": {"name": "Campfire", "width": 90.0, "h": 30.0, "needs": {"sticks": 3}, "hours": 0.2, "seconds": 2.0},
	"lean_to": {"name": "Lean-to", "width": 260.0, "h": 170.0, "needs": {"long": 2, "medium": 4}, "hours": 1.0, "seconds": 4.0},
	"woodpile": {"name": "Woodpile", "width": 170.0, "h": 110.0, "needs": {"sticks": 4}, "hours": 0.3, "seconds": 2.0},
	"tripod": {"name": "Pot tripod", "width": 90.0, "h": 130.0, "needs": {"sticks": 3}, "hours": 0.2, "seconds": 2.0, "on": "campfire"},
	"hide_frame": {"name": "Hide frame", "width": 140.0, "h": 185.0, "needs": {"medium": 2, "sticks": 2}, "hours": 0.5, "seconds": 3.0},
	"drying_rack": {"name": "Drying rack", "width": 180.0, "h": 155.0, "needs": {"medium": 2, "sticks": 4}, "hours": 0.5, "seconds": 3.0},
	"workbench": {"name": "Workbench", "width": 170.0, "h": 110.0, "needs": {"medium": 2, "sticks": 2}, "hours": 0.6, "seconds": 3.0},
	"chest": {"name": "Storage chest", "width": 120.0, "h": 75.0, "needs": {"medium": 1, "sticks": 3}, "hours": 0.5, "seconds": 2.5},
	"bait": {"name": "Bait pile", "width": 60.0, "h": 30.0, "needs": {"berries": 4}, "hours": 0.05, "seconds": 1.0},
	"blind": {"name": "Hunting blind", "width": 160.0, "h": 105.0, "needs": {"sticks": 6}, "hours": 0.4, "seconds": 2.5},
	"snare": {"name": "Snare", "width": 40.0, "h": 30.0, "needs": {"snare": 1}, "hours": 0.1, "seconds": 1.0},
	"sled": {"name": "Sled", "width": 190.0, "h": 60.0, "needs": {"medium": 1, "sticks": 6}, "hours": 1.0, "seconds": 3.5, "loose": true},
	"stones": {"name": "Stepping stones", "width": 200.0, "h": 40.0, "needs": {}, "hours": 2.0, "seconds": 4.0, "water": "ford"}, # rocks rolled up out of the creek bed
	"bridge": {"name": "Log bridge", "width": 200.0, "h": 60.0, "needs": {"long": 4, "medium": 2}, "hours": 3.0, "seconds": 5.0, "water": "span"},
	"cabin": {"name": "Log cabin", "width": 440.0, "h": 340.0, "needs": {"long": 6, "medium": 6, "sticks": 4}, "hours": 8.0, "seconds": 8.0},
	"smokehouse": {"name": "Smokehouse", "width": 170.0, "h": 245.0, "needs": {"medium": 3, "short": 4, "sticks": 4}, "hours": 3.0, "seconds": 5.0},
	"cache": {"name": "Raised cache", "width": 230.0, "h": 430.0, "needs": {"long": 2, "medium": 3, "short": 2, "sticks": 6}, "hours": 4.0, "seconds": 6.0},
	"fish_trap": {"name": "Fish trap", "width": 80.0, "h": 70.0, "needs": {"sticks": 6, "#cord": 1}, "hours": 0.5, "seconds": 3.0, "water": "fish"},
	"weir": {"name": "Fish weir", "width": 150.0, "h": 60.0, "needs": {"sticks": 10, "short": 2}, "hours": 2.0, "seconds": 4.0, "water": "creek"},
	"net": {"name": "Gill net", "width": 180.0, "h": 60.0, "needs": {"#cord": 3, "sticks": 2}, "hours": 0.5, "seconds": 3.0, "water": "still"},
	"bear_bag": {"name": "Bear bag", "width": 60.0, "h": 420.0, "needs": {"hide": 1, "#cord": 1}, "hours": 0.3, "seconds": 3.0, "on": "tree"},
}

const RECIPES := {
	"splint": {"needs": {"sticks": 2, "bandage": 1}, "hours": 0.25, "seconds": 2.0},
	"vine_cord": {"needs": {"#fibre": 3}, "hours": 0.3, "seconds": 2.0},
	"fishing_pole": {"needs": {"sticks": 2, "#line": 1}, "hours": 0.3, "seconds": 2.5}, # line & hooks, or vine cord and a carved hook
	# "bench": needs a workbench close by.
	"bow": {"needs": {"sticks": 3, "#cord": 1}, "hours": 1.0, "seconds": 3.0, "bench": true}, # paracord or vine cord
	"arrows": {"needs": {"sticks": 2}, "hours": 0.5, "seconds": 2.5, "count": 4, "bench": true},
	"hide_coat": {"needs": {"hide": 2, "#cord": 1}, "hours": 2.0, "seconds": 4.0, "bench": true},
	"deer_call": {"needs": {"sticks": 1}, "hours": 0.5, "seconds": 2.5, "bench": true},
	"snare": {"needs": {"#cord": 1, "sticks": 1}, "hours": 0.3, "seconds": 2.0, "count": 2},
	"spear": {"needs": {"sticks": 3}, "hours": 1.0, "seconds": 3.0, "bench": true},
	"fish_spear": {"needs": {"sticks": 2, "#cord": 1}, "hours": 0.8, "seconds": 3.0, "bench": true}, # a three-pronged leister
	# Clothing. Buckskin is fair-weather gear; wolf and bear fur are what gets you through winter.
	"buckskin_leggings": {"needs": {"hide": 1, "#cord": 1}, "hours": 1.5, "seconds": 3.5, "bench": true},
	"wolf_hat": {"needs": {"#fur": 1}, "hours": 1.0, "seconds": 3.0, "bench": true},
	"wolf_mittens": {"needs": {"#fur": 1}, "hours": 1.0, "seconds": 3.0, "bench": true},
	"wolf_leggings": {"needs": {"wolf_fur": 2, "#cord": 1}, "hours": 2.0, "seconds": 4.0, "bench": true},
	"bear_coat": {"needs": {"bear_fur": 1, "#cord": 1}, "hours": 3.0, "seconds": 4.5, "bench": true},
	"snowshoes": {"needs": {"sticks": 4, "hide": 1, "#cord": 1}, "hours": 1.5, "seconds": 3.5, "bench": true},
}

## Recipe book chapters, in order.
const GROUPS := {
	"Basics": ["vine_cord", "splint", "snare"],
	"Fishing": ["fishing_pole", "fish_spear"],
	"Hunting": ["bow", "arrows", "spear", "deer_call"],
	"Clothing": ["hide_coat", "buckskin_leggings", "wolf_hat", "wolf_mittens", "wolf_leggings", "bear_coat", "snowshoes"],
}
## Build book chapters, in order.
const BUILD_GROUPS := {
	"Camp": ["campfire", "tripod", "lean_to", "woodpile", "chest", "cabin"],
	"Work": ["workbench", "hide_frame", "drying_rack", "smokehouse", "sled", "stones", "bridge"],
	"Food storage": ["cache", "bear_bag"],
	"Fishing": ["fish_trap", "weir", "net"],
	"Hunting": ["blind", "bait", "snare"],
}

## "#tag" makings: what they're called and which item pictures them.
const TAGS := {
	"#cord": ["cord", "cordage"],
	"#line": ["fishing line", "fishing_kit"],
	"#fibre": ["vines or yucca fiber", "vine"],
	"#fur": ["wolf or coyote fur", "wolf_fur"],
}

## Where to get each making: shown in the books under anything you're short of.
const SOURCES := {
	"sticks": "Fallen sticks lie all through the woods: walk over them and press E. A wagon's boards or an old fire ring give a few too.",
	"short": "Fell a tree with the hatchet, then stand at the trunk and cut it into lengths (E). Carry logs on your shoulder (F) or pull them on a sled.",
	"medium": "Fell a tree with the hatchet, then stand at the trunk and cut it into lengths (E). Carry logs on your shoulder (F) or pull them on a sled.",
	"long": "Fell a tree with the hatchet, then cut a long log from the trunk (E). Heavy: carry it slowly on your shoulder, or on a sled in winter.",
	"#cord": "The paracord in your kit. Or twist your own: three vines (or yucca fiber) make vine cord (Basics).",
	"#line": "The line and hooks in your fishing kit, or vine cord with a carved hook.",
	"#fibre": "Vine tangles trail over the ground in the woods and valleys (they grow back in a season). Yucca grows out in the dry country to the west.",
	"bandage": "You start with a roll. More turn up in old camps and cellars.",
	"hide": "Tanned hide: skin a deer (knife, at the carcass), stretch the raw hide on a hide frame, and it's cured in about 18 hours.",
	"wolf_fur": "Kill a wolf (an arrow to the chest), skin it with the knife, and cure the pelt on a hide frame.",
	"#fur": "Cured wolf or coyote fur: skin one (knife, at the carcass) and cure the pelt on a hide frame. Coyotes hang round the open country at night and come to anything dead.",
	"bear_fur": "Bring down the bear (two good arrows), skin it, and cure the hide on a hide frame (about 30 hours).",
	"berries": "Serviceberry bushes in the valley and meadows: E to pick. They grow back in about three days.",
	"snare": "Make snares in the recipe book (Basics): cord and a stick make two.",
}

static func source(key: String) -> String:
	return SOURCES.get(key, "")

## A making's name for the books: "medium logs", "cord", "tanned hide".
static func nice(key: String) -> String:
	if is_log(key):
		return "%s logs" % key
	if key.begins_with("#"):
		return TAGS[key][0] if TAGS.has(key) else key.substr(1)
	return Items.get_def(key).name.to_lower()

## One line on what each build is for, shown in the build menu.
const WHAT := {
	"campfire": "heat, light, cooking; nothing wild comes near",
	"lean_to": "shelter to sleep in: makes camp",
	"woodpile": "stacks short logs; feeds a fire nearby",
	"tripod": "over a campfire: hang the pot to boil water",
	"hide_frame": "cures raw hides and pelts",
	"drying_rack": "dries meat and fish into jerky",
	"workbench": "bows, arrows, spear, clothing, repairs",
	"chest": "stores gear at camp",
	"bait": "draws deer (and the bear)",
	"blind": "hide from deer while you hunt",
	"snare": "catches rabbits overnight",
	"sled": "pull logs, a deer, or gear over snow",
	"bridge": "across a creek or the river: walk over dry",
	"stones": "rocks rolled out of the creek bed into a line across it: cross a creek with dry feet, until it floods over them. No materials, just work",
	"cabin": "the warmest shelter: a real home",
	"smokehouse": "smokes meat and fish that keep over a month, in any weather",
	"cache": "a food store up on posts: nothing raids it; food freezes and keeps",
	"bear_bag": "food hung high from a tree branch, out of reach",
	"fish_trap": "a basket in the current: catches fish while you're away, alive",
	"weir": "stakes across a creek that funnel fish into a trap beside it",
	"net": "strung across a river, lake, pond or pool: catches more, but check it often",
}

## Cooked in the pot hanging over a lit fire, from the pot's water and ingredients gathered
## from the pack and nearby chests. Unboiled water is fine: it boils while it cooks.
## "#meat" is any meat or fish; "#veg" is berries, rose hips or beans.
const POT_RECIPES := {
	"stew": {"needs": {"#meat": 2, "#veg": 1}, "water": 0.75, "hours": 1.0, "seconds": 4.0, "count": 3},
	"mint_tea": {"needs": {"mint": 2}, "water": 0.5, "hours": 0.3, "seconds": 2.5, "count": 2},
	"willow_tea": {"needs": {"willow_bark": 2}, "water": 0.5, "hours": 0.4, "seconds": 2.5, "count": 2},
}

static func is_log(key: String) -> bool:
	return key in WorldLog.SIZES

static func needs_text(needs: Dictionary, have: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in needs:
		parts.append("%s %d/%d" % [nice(k), have.get(k, 0), needs[k]])
	return ", ".join(parts)
