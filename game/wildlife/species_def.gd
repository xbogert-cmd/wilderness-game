class_name SpeciesDef extends Resource
## Data for one animal species. Behaviour lives in Animal; drawing in a species rig.

@export var id := ""
@export var name := ""
@export var rig := "deer" ## which rig draws it
@export var track := "deer" ## footprint kind
@export_group("Movement")
@export var walk_speed := 55.0
@export var flee_speed := 540.0
@export var stride := 70.0 ## px between prints
@export var home_range := 700.0 ## wanders this far from home while calm
@export_group("Senses (px at full strength)")
@export var sight := 950.0
@export var hearing := 1500.0
@export var alert_at := 0.45 ## awareness to stop and look
@export var flee_at := 1.0 ## awareness to bolt
@export var flee_distance := 2200.0 ## calms once this far from the threat; never chases or flees map-wide
@export_group("Life")
@export var group_min := 1
@export var group_max := 3
@export var groups_per_chunk := 1 ## sparse on purpose: meeting deer should feel like an event
@export var active_hours: PackedVector2Array = [Vector2(4.5, 10.5), Vector2(15.5, 22.0)] ## grazing/wandering; bedded otherwise
@export_group("Look")
@export var body_color := Color("8a7a66")
@export var belly_color := Color("c9bba4")
@export var rump_color := Color("e8e2d6")
@export var dark_color := Color("3a3028")
@export var size := 1.0
