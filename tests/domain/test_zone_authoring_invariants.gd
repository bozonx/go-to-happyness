extends RefCounted

## Focused checks for invariants enforced by both the zones editor and blueprint
## loading. Kept separate from the broad building-editor suite so regressions in
## zone authoring are reported directly.


static func run_all() -> void:
	print("--- Running test_zone_authoring_invariants.gd ---")
	_test_single_cell_erase()
	_test_authoring_bounds()
	_test_function_scope_and_queue_positions()
	_test_drag_rectangle_is_direction_free()
	_test_area_delete_cascades()
	print("--- test_zone_authoring_invariants.gd PASSED ---")


## The gesture both editors share. A drag is a rectangle between two cells, and
## which corner the author started from is not information: the map editor used
## to build `Rect2i(start, finish - start + ONE)`, which collapses to one cell for
## every drag that goes up or left.
static func _test_drag_rectangle_is_direction_free() -> void:
	var min_cell := Vector2i(-8, -8)
	var max_cell := Vector2i(7, 7)
	var forward := ZoneAuthoring.rect_from_drag(Vector2i(-1, -1), Vector2i(2, 2), min_cell, max_cell)
	var backward := ZoneAuthoring.rect_from_drag(Vector2i(2, 2), Vector2i(-1, -1), min_cell, max_cell)
	assert(forward == Rect2i(-1, -1, 4, 4), "forward drag covers both ends: %s" % forward)
	assert(forward == backward, "the direction of a drag does not change the rectangle")
	var single := ZoneAuthoring.rect_from_drag(Vector2i(3, 3), Vector2i(3, 3), min_cell, max_cell)
	assert(single == Rect2i(3, 3, 1, 1), "a click is one cell")
	var clamped := ZoneAuthoring.rect_from_drag(Vector2i(-99, -99), Vector2i(99, 99), min_cell, max_cell)
	assert(clamped == Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE), "a drag off the board is clamped to it")


## §7.7: deleting an area takes what it owned with it. Silent orphaning is the
## failure this rule exists to prevent — a point owned by an id that is gone is
## invisible in the editor and dangling in the file.
static func _test_area_delete_cascades() -> void:
	var areas: Array[ZoneAreaRecord] = []
	var anchors: Array[ZoneAnchorRecord] = []
	var routes: Array[ZoneRouteRecord] = []

	var area := ZoneAreaRecord.new()
	area.id = &"yard"
	area.add_rect(Rect2i(0, 0, 4, 4))
	areas.append(area)

	var slot := ZoneAnchorRecord.new()
	slot.id = &"post"
	slot.owner_id = &"yard"
	slot.role = ZoneAnchorRecord.ROLE_SLOT
	anchors.append(slot)

	var queue := ZoneAnchorRecord.new()
	queue.id = &"line_1"
	queue.role = ZoneAnchorRecord.ROLE_QUEUE
	queue.target_id = &"post"
	anchors.append(queue)

	var elsewhere := ZoneAnchorRecord.new()
	elsewhere.id = &"far_post"
	elsewhere.role = ZoneAnchorRecord.ROLE_WAYPOINT
	anchors.append(elsewhere)

	var route := ZoneRouteRecord.new()
	route.id = &"patrol"
	route.stops = [&"post", &"far_post"]
	routes.append(route)

	var removed := ZoneAuthoring.remove_area_cascade(areas, anchors, routes, &"yard")
	assert(areas.is_empty(), "the area is gone")
	assert(anchors.size() == 1 and anchors[0].id == &"far_post",
		"the point it owned and the queue leading to that point went with it")
	assert(&"post" in removed and &"line_1" in removed, "the cascade reports what it took: %s" % [removed])
	assert(routes.is_empty(), "a route left with one stop is not a route")


static func _test_single_cell_erase() -> void:
	var area := ZoneAreaRecord.new()
	area.add_rect(Rect2i(0, 0, 3, 3))
	assert(area.remove_cell(Vector2i(1, 1)))
	assert(area.cell_count() == 8)
	assert(not area.contains_cell(Vector2i(1, 1)))
	for cell in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]:
		assert(area.contains_cell(cell))


static func _test_authoring_bounds() -> void:
	var bp := _blueprint()
	var room := ZoneAreaRecord.new()
	room.id = &"outside_room"
	room.add_rect(Rect2i(2, 2, 2, 1))
	bp.areas.append(room)
	var point := ZoneAnchorRecord.new()
	point.id = &"outside_point"
	point.role = ZoneAnchorRecord.ROLE_SLOT
	point.pos = Vector3(-0.5, 0.0, 1.5)
	bp.anchors.append(point)
	assert(_has_error(bp.zone_validation_errors(), "выходит за границы здания"))
	assert(_has_error(bp.zone_validation_errors(), "outside_point стоит за пределами"))
	point.role = ZoneAnchorRecord.ROLE_DOOR
	assert(not _has_error(bp.zone_validation_errors(), "outside_point стоит за пределами"))


static func _test_function_scope_and_queue_positions() -> void:
	var bp := _blueprint()
	var room := ZoneAreaRecord.new()
	room.id = &"room"
	room.add_rect(Rect2i(0, 0, 3, 3))
	bp.areas.append(room)
	var slot := ZoneAnchorRecord.new()
	slot.id = &"slot"
	slot.role = ZoneAnchorRecord.ROLE_SLOT
	slot.owner_id = room.id
	slot.pos = Vector3(1.5, 0.0, 1.5)
	slot.activity = &"core:cook"
	bp.anchors.append(slot)
	for queue_id in [&"queue_a", &"queue_b"]:
		var queue := ZoneAnchorRecord.new()
		queue.id = queue_id
		queue.role = ZoneAnchorRecord.ROLE_QUEUE
		queue.owner_id = room.id
		queue.pos = Vector3(0.5, 0.0, 0.5)
		queue.target_id = slot.id
		queue.index = 0
		bp.anchors.append(queue)
	assert(_has_error(bp.zone_validation_errors(), "занимают одно место"))
	slot.function = &"core:party_leader"
	assert(_has_error(bp.zone_validation_errors(), "неприменима к точке slot"))
	bp.anchors[1].activity = &"core:cook"
	assert(_has_error(bp.zone_validation_errors(), "Действие можно назначить только месту"))


static func _blueprint() -> BuildingBlueprint:
	var bp := BuildingBlueprint.new()
	bp.id = &"zone_authoring_test"
	bp.name = "Zone authoring test"
	bp.footprint = Vector2i(3, 3)
	bp.grid_bounds = Vector3i(3, 2, 3)
	return bp


static func _has_error(errors: Array[String], fragment: String) -> bool:
	return errors.any(func(error: String) -> bool: return error.contains(fragment))
