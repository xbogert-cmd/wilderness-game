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

func _init(tuning: Tuning = null) -> void:
	t = tuning if tuning else Tuning.new()

## Advance by game hours. env keys (all optional):
## air_c, precip, sheltered, heat (0..1 fire proximity), exertion (0..1), wading (0..1),
## sleeping, sleep_quality (0..1), insulation_c (extra felt warmth, e.g. a sleeping bag)
func tick(dh: float, env: Dictionary) -> void:
	var exertion: float = env.get("exertion", 0.0)
	var sleeping: bool = env.get("sleeping", false)
	var heat: float = env.get("heat", 0.0)
	hunger = maxf(hunger - t.hunger_per_hour * dh * (1.0 + exertion), 0.0)
	thirst = maxf(thirst - t.thirst_per_hour * dh * (1.0 + exertion), 0.0)

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

## Real-time stamina (moment-to-moment actions, not game hours).
func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	return true

func recover_stamina(real_sec: float) -> void:
	var mult := (0.5 if hunger < 20.0 or thirst < 20.0 else 1.0) * (0.5 if fatigue > 80.0 else 1.0)
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
		"warmth": warmth, "wetness": wetness, "fatigue": fatigue, "injuries": injuries.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	health = float(d.health)
	stamina = float(d.stamina)
	hunger = float(d.hunger)
	thirst = float(d.thirst)
	warmth = float(d.warmth)
	wetness = float(d.wetness)
	fatigue = float(d.get("fatigue", 0.0))
	injuries = (d.injuries as Dictionary).duplicate(true)
