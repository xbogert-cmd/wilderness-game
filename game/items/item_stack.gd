class_name ItemStack extends RefCounted
## One concrete item (or stack) in the world, the pack, or the player's hands.

enum Fresh { FRESH, STALE, SPOILED }
const FRESH_NAMES: PackedStringArray = ["Fresh", "Stale", "Spoiled"]
const FOOD_MULT: PackedFloat32Array = [1.0, 0.7, 0.25]
const SIP := 0.25 ## litres per drink
const THIRST_PER_SIP := 20.0

var def: ItemDef
var count := 1
var made_hour := 0.0
var water := 0.0 ## litres held (containers)
var water_clean := true
var uses_left := 0
var sharpness := 1.0 ## 1 = sharp. Separate from structural condition.
var condition := 1.0

static func make(id: String, hour := 0.0, n := 1) -> ItemStack:
	var s := ItemStack.new()
	s.def = Items.get_def(id)
	s.count = n
	s.made_hour = hour
	s.uses_left = s.def.uses
	return s

func freshness(now: float) -> int:
	if def.spoil_hours <= 0.0:
		return Fresh.FRESH
	var age := now - made_hour
	if age >= def.spoil_hours: return Fresh.SPOILED
	if age >= def.spoil_hours * 0.5: return Fresh.STALE
	return Fresh.FRESH

func weight() -> float:
	return def.weight * count + water

func label(now: float) -> String:
	var s := def.name
	if count > 1:
		s += " x%d" % count
	if def.has("food") and def.spoil_hours > 0.0:
		s += " (%s)" % FRESH_NAMES[freshness(now)]
	if def.capacity > 0.0:
		s += " — empty" if water <= 0.001 else " — %.2f L %s" % [water, "clean" if water_clean else "DIRTY"]
	if def.uses > 0:
		s += " (%d left)" % uses_left
	return s

## Adds water; refuses (returns 0) rather than silently mixing clean and dirty.
func add_water(litres: float, clean: bool) -> float:
	if def.capacity <= 0.0 or (water > 0.001 and water_clean != clean):
		return 0.0
	var took := minf(litres, def.capacity - water)
	if water <= 0.001:
		water_clean = clean
	water += took
	return took

## Pours all it can into another container. Returns an error message, or "" on success.
func pour_into(other: ItemStack) -> String:
	if water <= 0.001:
		return "%s is empty." % def.name
	if other.def.capacity <= 0.0:
		return "%s can't hold water." % other.def.name
	if other.water > 0.001 and other.water_clean != water_clean:
		return "That would mix clean and dirty water. Empty the %s first." % other.def.name.to_lower()
	var moved := other.add_water(water, water_clean)
	if moved <= 0.0:
		return "%s is full." % other.def.name
	water -= moved
	return ""

func to_dict() -> Dictionary:
	return {"id": def.id, "n": count, "made": made_hour, "water": water, "clean": water_clean,
		"uses": uses_left, "sharp": sharpness, "cond": condition}

static func from_dict(d: Dictionary) -> ItemStack:
	var s := ItemStack.make(d.id, float(d.made), int(d.n))
	s.water = float(d.water)
	s.water_clean = bool(d.clean)
	s.uses_left = int(d.uses)
	s.sharpness = float(d.sharp)
	s.condition = float(d.cond)
	return s
