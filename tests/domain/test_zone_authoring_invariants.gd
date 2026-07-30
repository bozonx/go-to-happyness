extends RefCounted

## Focused checks for invariants enforced by both the zones editor and blueprint
## loading. Kept separate from the broad building-editor suite so regressions in
## zone authoring are reported directly.


static func run_all() -> void:
	print("--- Running test_zone_authoring_invariants.gd ---")
	_test_single_cell_erase()
	_test_authoring_bounds()
	_test_function_scope_and_queue_positions()
	print("--- test_zone_authoring_invariants.gd PASSED ---")


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
	slot.function = &"core:hero_start"
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
