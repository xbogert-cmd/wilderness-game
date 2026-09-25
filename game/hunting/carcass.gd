class_name Carcass extends Node2D
## A downed animal. Field dress it with a knife for meat, which ages from the moment of the
## kill. Left alone, it's gone after a few days.

const DRESS_SECONDS := 4.0
const DRESS_HOURS := 0.75
const MEAT := 4
const GONE_AFTER := 72.0

var world: World
var species := "mule_deer"
var facing := 1
var hour := 0.0 ## when it was killed
var arrows := 0

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup, like cutting a felled trunk
	z_as_relative = false
	z_index = 3

func _enter_tree() -> void:
	Journal.note("first_kill", "Took my first deer. Meat for days if I can keep it from spoiling, and a hide worth curing.")

func load_state(d: Dictionary, _elapsed: float) -> void:
	species = d.species
	facing = int(d.facing)
	hour = float(d.hour)
	arrows = int(d.get("arrows", 0))
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	if GameClock.clock.hours - hour > GONE_AFTER:
		queue_free()
	queue_redraw()

func to_state() -> Dictionary:
	return {"kind": "carcass", "x": global_position.x, "facing": facing, "species": species, "hour": hour, "arrows": arrows}

func can_unload() -> bool:
	return true

func interact_pos() -> Vector2:
	return global_position + Vector2(0, -30)

static func has_knife(p: Player) -> bool:
	return p.backpack.count_of("knife") > 0 or (p.held != null and p.held.def.has("knife"))

func interact_label(p: Player) -> String:
	return "Field dress" if has_knife(p) else "Field dress (needs a knife)"

func interact(p: Player) -> void:
	if not has_knife(p):
		p.message.emit("You need a knife to field dress it.")
		return
	p.work(DRESS_SECONDS, DRESS_HOURS, "Field dressing", func():
		var meat := ItemStack.make("venison_raw", hour, MEAT) # ages from the kill
		if not p.receive(meat):
			world.spawn({"kind": "item", "x": global_position.x + 40.0, "stack": meat.to_dict()})
		var hide := ItemStack.make("deer_hide", hour) # rots unless it gets onto a hide frame
		if not p.receive(hide):
			world.spawn({"kind": "item", "x": global_position.x - 40.0, "stack": hide.to_dict()})
		if arrows > 0:
			p.receive(ItemStack.make("arrows", GameClock.clock.hours, arrows))
		queue_free())

func _def() -> SpeciesDef:
	for d: SpeciesDef in Wildlife.SPECIES:
		if d.id == species:
			return d
	return Wildlife.SPECIES[0]

## Lying on its side, legs out toward facing.
func _draw() -> void:
	var d := _def()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0) * d.size)
	for k in 2:
		var hip := Vector2(-40 + k * 70, -18)
		draw_line(hip, hip + Vector2(34, 10), d.body_color.darkened(0.3), 8.0)
		draw_line(hip + Vector2(34, 10), hip + Vector2(60, 12), d.body_color.darkened(0.3), 5.0)
	var body := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		body.append(Vector2(cos(a) * 64.0 - 6.0, sin(a) * 22.0 - 22.0))
	draw_colored_polygon(body, d.body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -6), Vector2(40, -8), Vector2(30, -2), Vector2(-30, -1)]), d.belly_color)
	draw_circle(Vector2(-62, -24), 11.0, d.rump_color)
	draw_line(Vector2(50, -24), Vector2(84, -10), d.body_color, 14.0) # neck along the ground
	draw_circle(Vector2(90, -9), 10.0, d.body_color)
	draw_colored_polygon(PackedVector2Array([Vector2(96, -16), Vector2(116, -8), Vector2(96, -2)]), d.body_color)
	draw_circle(Vector2(116, -7), 3.5, d.dark_color)
	draw_colored_polygon(PackedVector2Array([Vector2(84, -16), Vector2(74, -34), Vector2(90, -18)]), d.body_color.darkened(0.15))
	for i in arrows:
		var at := Vector2(10 - i * 18, -34)
		draw_line(at, at + Vector2(-16, -30), Color("b0966b"), 2.0)
		draw_line(at + Vector2(-14, -26), at + Vector2(-18, -32), Color("d8d0c0"), 4.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
