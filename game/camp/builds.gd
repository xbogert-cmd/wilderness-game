class_name Builds extends RefCounted
## Build and recipe definitions (data). Structures are placed as blueprints and need
## physical materials delivered; small items are crafted from the pack's recipe list.
## Material keys: item ids come from the pack; "short"/"medium"/"long" are carried logs.

const STRUCTURES := {
	"campfire": {"name": "Campfire", "width": 90.0, "h": 30.0, "needs": {"sticks": 3}, "hours": 0.2, "seconds": 2.0},
	"lean_to": {"name": "Lean-to", "width": 260.0, "h": 170.0, "needs": {"long": 2, "medium": 4}, "hours": 1.0, "seconds": 4.0},
	"woodpile": {"name": "Woodpile", "width": 170.0, "h": 110.0, "needs": {"sticks": 4}, "hours": 0.3, "seconds": 2.0},
}

const RECIPES := {
	"splint": {"needs": {"sticks": 2, "bandage": 1}, "hours": 0.25, "seconds": 2.0},
	"fishing_pole": {"needs": {"sticks": 2, "fishing_kit": 1}, "hours": 0.3, "seconds": 2.5},
	"bow": {"needs": {"sticks": 3, "cordage": 1}, "hours": 1.0, "seconds": 3.0},
	"arrows": {"needs": {"sticks": 2}, "hours": 0.5, "seconds": 2.5, "count": 4},
}

static func is_log(key: String) -> bool:
	return key in WorldLog.SIZES

static func needs_text(needs: Dictionary, have: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in needs:
		var nice: String = ("%s logs" % k) if is_log(k) else Items.get_def(k).name.to_lower()
		parts.append("%s %d/%d" % [nice, have.get(k, 0), needs[k]])
	return ", ".join(parts)
