class_name ZoneAuthoring
extends RefCounted

## Authoring operations shared by both zones modes
## (design_docs/engine/active_zones.md §11, §11.2).
##
## The model is one document for two editors; the *gestures* over it were two
## implementations, and they had already drifted: the map editor built its drag
## rectangle as `Rect2i(start, finish - start + ONE)`, which collapses to a
## single cell whenever the author drags up or left, and it deleted areas without
## touching the anchors they owned — the orphaning §7.7 forbids. Both were
## already solved correctly next door. So the rules live here, once, and the two
## controllers keep only their own UI.
##
## Everything here is pure: cells and records in, records out. No node, no
## editor, no undo stack — the caller snapshots and pushes its own command.


## The rectangle an author meant by dragging from one cell to another, clamped to
## the board. Both ends are inclusive: dragging within one cell yields that cell,
## and the direction of the drag never matters.
static func rect_from_drag(from_cell: Vector2i, to_cell: Vector2i, min_cell: Vector2i, max_cell: Vector2i) -> Rect2i:
	var start := Vector2i(
		clampi(from_cell.x, min_cell.x, max_cell.x), clampi(from_cell.y, min_cell.y, max_cell.y))
	var finish := Vector2i(
		clampi(to_cell.x, min_cell.x, max_cell.x), clampi(to_cell.y, min_cell.y, max_cell.y))
	return Rect2i(start, Vector2i.ONE).merge(Rect2i(finish, Vector2i.ONE))


## An id of the form `prefix_N` that `taken` does not already claim. The callable
## takes a `StringName` and returns whether it is in use — ids are unique across
## areas, anchors *and* routes (§7.1), and only the caller knows where to look.
static func unique_id(prefix: String, taken: Callable) -> StringName:
	var number := 1
	while taken.call(StringName("%s_%d" % [prefix, number])):
		number += 1
	return StringName("%s_%d" % [prefix, number])


## Removes an area together with everything that points at it: the anchors it
## owns, and the route stops those anchors were. Returns the ids removed, so a
## caller can report "и 3 точки" instead of silently swallowing them.
##
## §7.7 is the reason this exists at all: deleting an area must never leave a
## point owned by an id that is gone. The building editor also drops fixtures,
## which a map has none of — that stays in its own controller.
static func remove_area_cascade(
	areas: Array[ZoneAreaRecord],
	anchors: Array[ZoneAnchorRecord],
	routes: Array[ZoneRouteRecord],
	area_id: StringName,
) -> Array[StringName]:
	var removed: Array[StringName] = []
	for index in range(areas.size() - 1, -1, -1):
		if areas[index].id == area_id:
			areas.remove_at(index)
			removed.append(area_id)
	var orphaned: Array[StringName] = []
	for index in range(anchors.size() - 1, -1, -1):
		if anchors[index].owner_id == area_id:
			orphaned.append(anchors[index].id)
			removed.append(anchors[index].id)
			anchors.remove_at(index)
	remove_route_stops(routes, orphaned)
	removed.append_array(remove_queues_targeting(anchors, routes, orphaned))
	return removed


## Removes one anchor and everything that referenced it — route stops and the
## queue places that led to it. A queue whose slot is gone is a point the engine
## can do nothing with, so it goes with it.
static func remove_anchor_cascade(
	anchors: Array[ZoneAnchorRecord],
	routes: Array[ZoneRouteRecord],
	anchor_id: StringName,
) -> Array[StringName]:
	var removed: Array[StringName] = []
	for index in range(anchors.size() - 1, -1, -1):
		if anchors[index].id == anchor_id:
			anchors.remove_at(index)
			removed.append(anchor_id)
	remove_route_stops(routes, [anchor_id])
	removed.append_array(remove_queues_targeting(anchors, routes, [anchor_id]))
	return removed


## Drops the given stops from every route, and drops a route that no longer has
## anything to walk. A one-stop route is not a route; leaving it would show the
## author a line in the list that does nothing.
static func remove_route_stops(routes: Array[ZoneRouteRecord], anchor_ids: Array[StringName]) -> void:
	if anchor_ids.is_empty():
		return
	for index in range(routes.size() - 1, -1, -1):
		var route := routes[index]
		var kept: Array[StringName] = []
		for stop in route.stops:
			if stop not in anchor_ids:
				kept.append(stop)
		route.stops = kept
		if route.stops.size() < 2:
			routes.remove_at(index)


static func remove_queues_targeting(
	anchors: Array[ZoneAnchorRecord],
	routes: Array[ZoneRouteRecord],
	slot_ids: Array[StringName],
) -> Array[StringName]:
	if slot_ids.is_empty():
		return []
	var removed: Array[StringName] = []
	for index in range(anchors.size() - 1, -1, -1):
		var anchor := anchors[index]
		if anchor.is_queue() and anchor.target_id in slot_ids:
			removed.append(anchor.id)
			anchors.remove_at(index)
	remove_route_stops(routes, removed)
	return removed


## Next free place in the line leading to a slot (§5.2: 0 is the head).
static func next_queue_index(anchors: Array[ZoneAnchorRecord], target_id: StringName) -> int:
	var next := 0
	for anchor in anchors:
		if anchor.is_queue() and anchor.target_id == target_id:
			next = maxi(next, anchor.index + 1)
	return next
