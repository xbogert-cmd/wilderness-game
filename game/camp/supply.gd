class_name Supply extends RefCounted
## Crafting and cooking at camp draw on everything close by: the pack first, then any storage
## chest near the station. Things that come out of a chest are fetched for real: the player
## walks over, rummages, and walks back before the work starts.

const REACH := 900.0 ## chests this close to the station count

## Storage chests near x.
static func chests(tree: SceneTree, x: float) -> Array:
	return tree.get_nodes_in_group("chest").filter(func(c): return not c.is_queued_for_deletion() and absf(c.global_position.x - x) < REACH)

## How many of id (or #tag) the player could use here: pack, hands, nearby chests.
static func have(p: Player, id: String, station_x: float) -> int:
	var n := p.backpack.count_of(id) + (p.held.count if p.held and Backpack.matches(p.held, id) else 0)
	for c in chests(p.get_tree(), station_x):
		n += c.store.count_of(id)
	return n

static func can(p: Player, needs: Dictionary, station_x: float) -> bool:
	for k in needs:
		if have(p, k, station_x) < needs[k]:
			return false
	return true

## Takes what needs out of the pack (and hands) now, walks to each chest still needed and takes
## the rest, comes back to station_x, then calls done. False if it can't all be found.
static func gather(p: Player, needs: Dictionary, station_x: float, done: Callable) -> bool:
	if not can(p, needs, station_x):
		return false
	var left := {}
	for k in needs:
		var want: int = needs[k]
		if p.held and Backpack.matches(p.held, k) and want > 0: # held items count too
			p.stow()
		var from_pack := mini(want, p.backpack.count_of(k))
		p.backpack.take(k, from_pack)
		if want - from_pack > 0:
			left[k] = want - from_pack
	if left.is_empty():
		done.call()
		return true
	var steps := []
	for c in chests(p.get_tree(), station_x):
		var take := {}
		for k in left:
			var n := mini(left[k], c.store.count_of(k))
			if n > 0:
				take[k] = n
				left[k] -= n
		if take.is_empty():
			continue
		steps.append({"x": c.global_position.x, "wait": 0.8, "label": "Fetching from the chest", "do": func():
			for k in take:
				c.store.take(k, take[k])})
		if left.values().all(func(v): return v <= 0):
			break
	steps.append({"x": station_x, "wait": 0.0, "label": "", "do": done})
	p.errand(steps)
	return true
