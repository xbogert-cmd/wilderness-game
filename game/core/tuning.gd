class_name Tuning extends Resource
## Every gameplay tuning knob lives here. Edit data/tuning.tres, not code.

@export_group("Time")
@export var day_length_sec := 1440.0 ## real seconds per 24 game hours
@export var days_per_season := 4
@export var sleep_time_scale := 60.0 ## game-time multiplier while sleeping

@export_group("Needs (per game hour)")
@export var hunger_per_hour := 3.0
@export var thirst_per_hour := 5.0
@export var starving_damage_per_hour := 4.0
@export var dehydration_damage_per_hour := 6.0
@export var cold_damage_per_hour := 6.0
@export var regen_per_hour := 2.0
@export var sleep_regen_mult := 4.0

@export_group("Stamina (per real second)")
@export var stamina_regen_per_sec := 14.0
@export var run_stamina_per_sec := 9.0

@export_group("Warmth & wetness")
@export var clothing_c := 5.0 ## how many °C warmer the starting clothes make you feel
@export var fire_heat_c := 25.0
@export var warmth_rate_per_hour := 30.0
@export var rain_wet_per_hour := 1.2
@export var wade_wet_per_hour := 6.0
@export var dry_per_hour := 0.25

@export_group("Injury")
@export var injury_heal_per_hour := 0.02
@export var treated_heal_mult := 3.0
