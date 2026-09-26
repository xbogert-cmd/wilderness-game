class_name Condition extends RefCounted
## Player survival state. Meters are "fullness": 100 = good, 0 = empty.
## Pure logic; the HUD and player scene only read it.

signal injured(region: String, kind: String)

const REGIONS: PackedStringArray = ["head", "torso", "arms", "legs"]

var t: Tuning
var health := 100.0
var stamina := 100.0
var hunger := 100.0
var thirst := 100.0
var warmth := 50.0 ## 0 freezing, 50 comfortable, 100 overheated
var wetness := 0.0 ## 0..1
var fatigue := 0.0 ## 0 rested, 100 exhausted
var injuries := {} ## region -> {"kind": String, "severity": float 0..1, "treated": bool}
## Illness, infection and frostbite: slow, with plenty of warning, and treatable; but left
## alone for a couple of days any of them can kill.
var sickness := 0.0 ## 0..1 gut sickness (bad water, spoiled or raw food, poison plants)
var incubating := 0.0 ## sickness still to come on (it starts a few hours after the cause)
var infection := 0.0 ## 0..1, from an open wound left unbandaged; fever above FEVER_AT
var fever_relief := 0.0 ## hours of willow bark easing the fever
const FEVER_AT := 0.35
const INCUBATE_PER_HOUR := 0.12 ## how fast queued sickness comes on

func _init(tuning: Tuning = null) -> void:
	t = tuning if tuning else Tuning.new()

## Advance by game hours. env keys (all optional):
## air_c, precip, sheltered, heat (0..1 fire proximity), exertion (0..1), wading (0..1),
## sleeping, sleep_quality (0..1), insulation_c (extra felt warmth, e.g. a sleeping bag)
func tick(dh: float, env: Dictionary) -> void:
	var exertion: float = env.get("exertion", 0.0)
	var sleeping: bool = env.get("sleeping", false)
	var heat: float = env.get("heat", 0.0)
	_ail(dh, sleeping, heat, env)
	var sick := 1.0 + 0.8 * sickness # a sick stomach drains you
	hunger = maxf(hunger - t.hunger_per_hour * dh * (1.0 + exertion) * sick, 0.0)
	var sweat := 1.5 if warmth > 80.0 or infection > FEVER_AT else 1.0 # overdressed, or a fever: you sweat it out
	thirst = maxf(thirst - t.thirst_per_hour * dh * (1.0 + exertion) * sweat * sick, 0.0)

	var rain: float = 0.0 if env.get("sheltered", false) else env.get("precip", 0.0)
	var wet_in: float = rain * t.rain_wet_per_hour + env.get("wading", 0.0) * t.wade_wet_per_hour
	var dry := t.dry_per_hour * (1.0 + heat * 4.0)
	wetness = clampf(wetness + (wet_in - dry) * dh, 0.0, 1.0)

	var felt: float = env.get("air_c", 15.0) + heat * t.fire_heat_c - wetness * 10.0 + t.clothing_c + env.get("insulation_c", 0.0) \
		+ exertion * 6.0 # working hard keeps you warm (and hungry)
	var target := clampf(50.0 + (felt - 20.0) * 2.5, 0.0, 100.0)
	warmth = move_toward(warmth, target, t.warmth_rate_per_hour * dh)

	var quality: float = env.get("sleep_quality", 1.0)
	if sleeping:
		fatigue = maxf(fatigue - t.sleep_recovery_per_hour * quality * dh, 0.0)
	else:
		fatigue = minf(fatigue + t.fatigue_per_hour * (1.0 + 0.5 * exertion) * dh, 100.0)

	var drain := 0.0
	if hunger <= 0.0: drain += t.starving_damage_per_hour
	if thirst <= 0.0: drain += t.dehydration_damage_per_hour
	if warmth < 15.0: drain += t.cold_damage_per_hour * (15.0 - warmth) / 15.0
	if sickness > 0.5: drain += 1.6 * (sickness - 0.3)
	if infection > FEVER_AT: drain += 2.4 * infection * (0.5 if fever_relief > 0.0 else 1.0)
	if drain > 0.0:
		health = maxf(health - drain * dh, 0.0)
	elif hunger > 40.0 and thirst > 40.0 and warmth > 30.0:
		health = minf(health + t.regen_per_hour * dh * (t.sleep_regen_mult * quality if sleeping else 1.0), 100.0)

	var comfy := hunger > 30.0 and thirst > 30.0 and warmth > 30.0
	for region in injuries.keys():
		var inj: Dictionary = injuries[region]
		var rate := t.injury_heal_per_hour * (t.treated_heal_mult if inj.treated else 1.0)
		rate *= (1.0 if comfy else 0.3) * (2.0 if sleeping else 1.0)
		inj.severity -= rate * dh
		if inj.severity <= 0.0:
			injuries.erase(region)

## The slow ailments. Sickness comes on hours after its cause and wears off (faster asleep);
## an open cut left unbandaged festers into infection, which a bandage halts and yarrow
## cleans; bare hands (and legs in deep snow) frostbite while you're freezing.
func _ail(dh: float, sleeping: bool, heat: float, env: Dictionary) -> void:
	if incubating > 0.0:
		var k := minf(incubating, INCUBATE_PER_HOUR * dh)
		incubating -= k
		sickness = minf(sickness + k, 1.0)
	elif sickness > 0.0:
		sickness = maxf(sickness - dh * (0.05 if sleeping else 0.022), 0.0)
	var open_cut := injuries.values().any(func(i): return i.kind == "cut" and not i.treated)
	if open_cut:
		infection = minf(infection + 0.03 * dh, 1.0)
	elif infection > 0.0:
		infection = maxf(infection - dh * (0.03 if sleeping else 0.015), 0.0)
	fever_relief = maxf(fever_relief - dh, 0.0)
	if warmth < 15.0:
		var bite := 0.06 * dh * (15.0 - warmth) / 15.0
		if not env.get("hands_covered", false):
			_frost("arms", bite)
		if env.get("deep_snow", false) and not env.get("legs_covered", false):
			_frost("legs", bite)
	elif heat > 0.2: # warming by a fire brings frostbite back
		for r in injuries.keys():
			if injuries[r].kind == "frostbite":
				injuries[r].severity -= 0.08 * dh
				if injuries[r].severity <= 0.0:
					injuries.erase(r)

func _frost(region: String, amount: float) -> void:
	var cur: Dictionary = injuries.get(region, {})
	if cur and cur.kind != "frostbite":
		return # already hurt there some other way
	var sev: float = cur.get("severity", 0.0) + amount
	if not cur:
		injured.emit(region, "frostbite")
	injuries[region] = {"kind": "frostbite", "severity": minf(sev, 1.0), "treated": cur.get("treated", false)}

## Something that can turn your stomach: some chance it does, a few hours from now.
func expose(amount: float, chance: float) -> bool:
	if randf() < chance:
		incubating = minf(incubating + amount, 1.0)
		return true
	return false

## Wild plants, chewed or applied. Returns what happened, for a message.
func use_herb(id: String) -> String:
	match id:
		"yarrow":
			var cleaned := infection > 0.05 or injuries.values().any(func(i): return i.kind == "cut")
			infection = maxf(infection - 0.45, 0.0)
			for r in injuries:
				if injuries[r].kind == "cut":
					injuries[r].treated = true
			return "You press chewed yarrow into the wound. It stings, then settles." if cleaned else "Yarrow: good on a wound. You've none to treat."
		"mint":
			var had := sickness + incubating > 0.05
			sickness = maxf(sickness - 0.3, 0.0)
			incubating = maxf(incubating - 0.3, 0.0)
			return "Wild mint settles your stomach." if had else "Cool and sharp. Your stomach's fine."
		"willow_bark":
			fever_relief = 10.0
			return "Bitter willow bark. The fever eases." if infection > FEVER_AT else "Bitter. It would ease a fever."
		"rose_hips":
			hunger = minf(hunger + 6.0, 100.0)
			health = minf(health + 2.0, 100.0)
			return "Tart rose hips. A little something."
		"arnica":
			var any := false
			for r in injuries:
				if injuries[r].kind == "sprain":
					injuries[r].severity = maxf(injuries[r].severity - 0.3, 0.05)
					any = true
			return "You rub arnica into the sprain. It eases." if any else "Arnica: for sprains and bruises."
		"water_hemlock":
			health -= 30.0
			incubating = minf(incubating + 0.7, 1.0)
			return "It burns going down. Your stomach knots, hard. That was poison."
	return ""

## Real-time stamina (moment-to-moment actions, not game hours).
func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	return true

func recover_stamina(real_sec: float) -> void:
	var mult := (0.5 if hunger < 20.0 or thirst < 20.0 else 1.0) * (0.5 if fatigue > 80.0 else 1.0) * (0.6 if sickness > 0.4 or infection > FEVER_AT else 1.0)
	stamina = minf(stamina + t.stamina_regen_per_sec * mult * real_sec, 100.0)

func injure(region: String, kind: String, severity: float) -> void:
	assert(region in REGIONS)
	var cur: float = injuries.get(region, {}).get("severity", 0.0)
	injuries[region] = {"kind": kind, "severity": clampf(maxf(cur, severity), 0.0, 1.0), "treated": false}
	injured.emit(region, kind)

func treat(region: String) -> bool:
	if not injuries.has(region):
		return false
	injuries[region].treated = true
	return true

func severity(region: String) -> float:
	var inj: Dictionary = injuries.get(region, {})
	return inj.get("severity", 0.0) * (0.5 if inj.get("treated", false) else 1.0)

func move_speed_mult() -> float:
	return 1.0 - severity("legs") * 0.55

func tool_speed_mult() -> float:
	return (1.0 - severity("arms") * 0.5) * (0.8 if warmth < 20.0 else 1.0) * (0.85 if fatigue > 80.0 else 1.0)

func eat(amount: float) -> void:
	hunger = minf(hunger + amount, 100.0)

func drink(amount: float) -> void:
	thirst = minf(thirst + amount, 100.0)

func is_dead() -> bool:
	return health <= 0.0

func to_dict() -> Dictionary:
	return {"health": health, "stamina": stamina, "hunger": hunger, "thirst": thirst,
		"warmth": warmth, "wetness": wetness, "fatigue": fatigue, "injuries": injuries.duplicate(true),
		"sickness": sickness, "incubating": incubating, "infection": infection, "fever_relief": fever_relief}

func from_dict(d: Dictionary) -> void:
	health = float(d.health)
	stamina = float(d.stamina)
	hunger = float(d.hunger)
	thirst = float(d.thirst)
	warmth = float(d.warmth)
	wetness = float(d.wetness)
	fatigue = float(d.get("fatigue", 0.0))
	injuries = (d.injuries as Dictionary).duplicate(true)
	sickness = float(d.get("sickness", 0.0))
	incubating = float(d.get("incubating", 0.0))
	infection = float(d.get("infection", 0.0))
	fever_relief = float(d.get("fever_relief", 0.0))
