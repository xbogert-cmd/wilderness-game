class_name Blueprint extends Node2D
## A placed, unbuilt structure. Deliver materials with E (carried logs, or items from the
## pack), then assemble it, which takes game time.

var world: World
var build_id := "campfire"
var delivered := {}

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	add_to_group("camp") # gets a key popup
	add_to_group("structure")
	z_as_relative = false
	z_index = 2

func def() -> Dictionary:
	return Builds.STRUCTURES[build_id]

func width() -> float:
	return def().width

func load_state(d: Dictionary, _elapsed: float) -> void:
	build_id = d.build
	delivered = d.get("delivered", {})
	for k in delivered:
		delivered[k] = int(delivered[k])
	global_position = Vector2(float(d.x), world.terrain.height_at(float(d.x)))
	if def().has("water") and world.terrain.water_index(global_position.x) >= 0: # a bridge's outline sits at bank height
		global_position.y = world.terrain.surface_of(world.terrain.water_index(global_position.x)) - 40.0

func to_state() -> Dictionary:
	return {"kind": "blueprint", "build": build_id, "x": global_position.x, "delivered": delivered}

func can_unload() -> bool:
	return true

func complete() -> bool:
	for k in def().needs:
		if delivered.get(k, 0) < def().needs[k]:
			return false
	return true

func interact_pos() -> Vector2: # anywhere along a wide one (a bridge's is the whole span)
	var p: Player = get_tree().get_first_node_in_group("player")
	var half := maxf(width(), _span()) * 0.5
	return Vector2(clampf(p.global_position.x, global_position.x - half, global_position.x + half), global_position.y) if p else global_position

func _span() -> float:
	if not def().has("water"):
		return 0.0
	var i := world.terrain.water_index(global_position.x)
	return Terrain.WATERS[i].half * 2.0 + 180.0 if i >= 0 else 0.0

func interact_label(p: Player) -> String:
	if complete():
		return "Build %s (%.1f h)" % [def().name.to_lower(), def().hours]
	var missing := _deliverable(p)
	var status := Builds.needs_text(def().needs, delivered)
	return ("Add %s — %s" % [missing, status]) if missing != "" else ("%s blueprint — needs %s" % [def().name, status])

## What the player could hand over right now, or "".
func _deliverable(p: Player) -> String:
	for k in def().needs:
		if delivered.get(k, 0) >= def().needs[k]:
			continue
		if Builds.is_log(k):
			if p.carrying and p.carrying.size == k:
				return "%s log" % k
		elif p.backpack.count_of(k) > 0 or (p.held and p.held.def.id == k):
			return Items.get_def(k).name.to_lower()
		elif Supply.have(p, k, global_position.x) > 0:
			return Items.get_def(k).name.to_lower() + " from the chest"
	return ""

func interact(p: Player) -> void:
	if complete():
		var d := def()
		p.work(d.seconds, d.hours, "Building", _finish)
		return
	for k in def().needs:
		var want: int = def().needs[k] - delivered.get(k, 0)
		if want <= 0:
			continue
		if Builds.is_log(k):
			if p.carrying and p.carrying.size == k:
				var lg := p.carrying
				p.drop_carried()
				lg.queue_free()
				delivered[k] = delivered.get(k, 0) + 1
				queue_redraw()
				return
		else:
			var n := mini(want, p.backpack.count_of(k))
			if p.held and p.held.def.id == k:
				p.stow() # held items count too
				n = mini(want, p.backpack.count_of(k))
			if n > 0 and p.backpack.take(k, n):
				delivered[k] = delivered.get(k, 0) + n
				queue_redraw()
				return
	for k in def().needs: # not in the pack: fetch it from a chest nearby
		var want: int = def().needs[k] - delivered.get(k, 0)
		if want > 0 and not Builds.is_log(k):
			var n := mini(want, Supply.have(p, k, global_position.x))
			if n > 0:
				Supply.gather(p, {k: n}, global_position.x, func():
					delivered[k] = delivered.get(k, 0) + n
					queue_redraw())
				return
	p.message.emit("You don't have what this needs: " + Builds.needs_text(def().needs, delivered))

func _finish() -> void:
	if def().get("on") == "tree": # the bear bag, hung from the tree it was placed at
		var t := Blueprint.host_at(get_tree(), "tree", global_position.x)
		world.spawn({"kind": build_id, "x": global_position.x, "height": t.height if t else 1200.0})
	elif def().has("on"): # an add-on to something already built (the tripod over a fire)
		var host := Blueprint.host_at(get_tree(), def().on, global_position.x)
		if host:
			host.set(build_id, true)
			host.queue_redraw()
	else:
		world.spawn({"kind": build_id, "x": global_position.x, "fresh": true})
	queue_free()

## The built structure an add-on attaches to: a campfire for "campfire".
## For "tree": a standing tree tall enough to hang a bag from, without one already.
static func host_at(tree: SceneTree, kind: String, x: float, reach := 40.0) -> Node2D:
	var best: Node2D = null
	var pool := tree.get_nodes_in_group("choppable") if kind == "tree" else tree.get_nodes_in_group("structure")
	for s in pool:
		var ok: bool = s is Campfire if kind == "campfire" else (s is ChoppableTree and s.height >= 1000.0 and not s.felled \
			and not tree.get_nodes_in_group("bear_bag").any(func(b): return absf(b.global_position.x - s.global_position.x) < 20.0))
		if ok and absf(s.global_position.x - x) < reach:
			if best == null or absf(s.global_position.x - x) < absf(best.global_position.x - x):
				best = s
	return best

func _draw() -> void:
	var w := maxf(width(), _span())
	var c := Color(0.95, 0.9, 0.7, 0.55)
	var h: float = def().h
	draw_rect(Rect2(-w * 0.5, -h, w, h), c, false, 2.0)
	for i in int(w / 20.0):
		draw_line(Vector2(-w * 0.5 + i * 20.0, 0), Vector2(-w * 0.5 + i * 20.0 + 10.0, 0), c, 2.0)
