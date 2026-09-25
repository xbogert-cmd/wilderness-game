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
	"blind": {"name": "Hunting blind", "width": 160.0, "h": 105.0, "needs": {"sticks": 6}, "hours": 0.4, "seconds": 2.5},
	"cabin": {"name": "Log cabin", "width": 440.0, "h": 340.0, "needs": {"long": 6, "medium": 6, "sticks": 4}, "hours": 8.0, "seconds": 8.0},
}

const RECIPES := {
	"splint": {"needs": {"sticks": 2, "bandage": 1}, "hours": 0.25, "seconds": 2.0},
	"vine_cord": {"needs": {"vine": 3}, "hours": 0.3, "seconds": 2.0},
	"fishing_pole": {"needs": {"sticks": 2, "#line": 1}, "hours": 0.3, "seconds": 2.5}, # line & hooks, or vine cord and a carved hook
	"bow": {"needs": {"sticks": 3, "#cord": 1}, "hours": 1.0, "seconds": 3.0}, # paracord or vine cord
	"arrows": {"needs": {"sticks": 2}, "hours": 0.5, "seconds": 2.5, "count": 4},
	"hide_coat": {"needs": {"hide": 2, "#cord": 1}, "hours": 2.0, "seconds": 4.0},
}

static func is_log(key: String) -> bool:
	return key in WorldLog.SIZES

static func needs_text(needs: Dictionary, have: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in needs:
		var nice: String = ("%s logs" % k) if is_log(k) else (k.substr(1) if k.begins_with("#") else Items.get_def(k).name.to_lower())
		parts.append("%s %d/%d" % [nice, have.get(k, 0), needs[k]])
	return ", ".join(parts)
