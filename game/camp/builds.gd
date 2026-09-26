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
	"bridge": {"name": "Log bridge", "width": 200.0, "h": 60.0, "needs": {"long": 4, "medium": 2}, "hours": 3.0, "seconds": 5.0, "water": true},
	"cabin": {"name": "Log cabin", "width": 440.0, "h": 340.0, "needs": {"long": 6, "medium": 6, "sticks": 4}, "hours": 8.0, "seconds": 8.0},
}

const RECIPES := {
	"splint": {"needs": {"sticks": 2, "bandage": 1}, "hours": 0.25, "seconds": 2.0},
	"vine_cord": {"needs": {"vine": 3}, "hours": 0.3, "seconds": 2.0},
	"fishing_pole": {"needs": {"sticks": 2, "#line": 1}, "hours": 0.3, "seconds": 2.5}, # line & hooks, or vine cord and a carved hook
	# "bench": needs a workbench close by.
	"bow": {"needs": {"sticks": 3, "#cord": 1}, "hours": 1.0, "seconds": 3.0, "bench": true}, # paracord or vine cord
	"arrows": {"needs": {"sticks": 2}, "hours": 0.5, "seconds": 2.5, "count": 4, "bench": true},
	"hide_coat": {"needs": {"hide": 2, "#cord": 1}, "hours": 2.0, "seconds": 4.0, "bench": true},
	"deer_call": {"needs": {"sticks": 1}, "hours": 0.5, "seconds": 2.5, "bench": true},
	"snare": {"needs": {"#cord": 1, "sticks": 1}, "hours": 0.3, "seconds": 2.0, "count": 2},
	"spear": {"needs": {"sticks": 3}, "hours": 1.0, "seconds": 3.0, "bench": true},
	# Clothing. Buckskin is fair-weather gear; wolf and bear fur are what gets you through winter.
	"buckskin_leggings": {"needs": {"hide": 1, "#cord": 1}, "hours": 1.5, "seconds": 3.5, "bench": true},
	"wolf_hat": {"needs": {"wolf_fur": 1}, "hours": 1.0, "seconds": 3.0, "bench": true},
	"wolf_mittens": {"needs": {"wolf_fur": 1}, "hours": 1.0, "seconds": 3.0, "bench": true},
	"wolf_leggings": {"needs": {"wolf_fur": 2, "#cord": 1}, "hours": 2.0, "seconds": 4.0, "bench": true},
	"bear_coat": {"needs": {"bear_fur": 1, "#cord": 1}, "hours": 3.0, "seconds": 4.5, "bench": true},
	"snowshoes": {"needs": {"sticks": 4, "hide": 1, "#cord": 1}, "hours": 1.5, "seconds": 3.5, "bench": true},
}

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
	"cabin": "the warmest shelter: a real home",
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
		var nice: String = ("%s logs" % k) if is_log(k) else (k.substr(1) if k.begins_with("#") else Items.get_def(k).name.to_lower())
		parts.append("%s %d/%d" % [nice, have.get(k, 0), needs[k]])
	return ", ".join(parts)
