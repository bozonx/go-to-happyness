class_name TestZoneOverlayIndex
extends RefCounted

## Domain tests for the active-zone overlay index (active_zones.md §4, §18):
## that a forest rectangle prices its cells, that overlapping overlays multiply,
## that a `deny visitor` marks the cell, and that non-overlay regions are inert.

const BOARD_CELLS := 16


static func run_all() -> void:
	_test_overlay_cost_prices_cells()
	_test_overlapping_overlays_multiply_cost()
	_test_deny_visitor_marks_cell()
	_test_region_is_inert()
	print("    [PASS] Zone Overlay Index Tests")


static func _layer() -> MapZoneLayer:
	return MapZoneLayer.new()


## An overlay with `cost: 2.0` over a 2×1 footprint prices both cells by 2.
static func _test_overlay_cost_prices_cells() -> void:
	var zones := _layer()
	var forest := ZoneAreaRecord.new()
	forest.id = &"forest"
	forest.role = ZoneAreaRecord.ROLE_OVERLAY
	forest.effects = {ZoneEffects.KEY_COST: 2.0}
	forest.add_rect(Rect2i(2, 3, 2, 1))
	zones.areas.append(forest)

	var index := ZoneOverlayIndex.new()
	index.rebuild(zones, BOARD_CELLS)
	assert(is_equal_approx(index.cost_at(Vector2i(2, 3)), 2.0))
	assert(is_equal_approx(index.cost_at(Vector2i(3, 3)), 2.0))
	# A cell the overlay does not cover reads as no-cost.
	assert(is_equal_approx(index.cost_at(Vector2i(8, 8)), 1.0))


## Two overlays over one cell multiply their costs (§4.2): 2.0 × 1.5 = 3.0.
static func _test_overlapping_overlays_multiply_cost() -> void:
	var zones := _layer()
	var first := ZoneAreaRecord.new()
	first.id = &"forest"
	first.role = ZoneAreaRecord.ROLE_OVERLAY
	first.effects = {ZoneEffects.KEY_COST: 2.0}
	first.add_rect(Rect2i(2, 3, 2, 1))
	zones.areas.append(first)
	var second := ZoneAreaRecord.new()
	second.id = &"mud"
	second.role = ZoneAreaRecord.ROLE_OVERLAY
	second.effects = {ZoneEffects.KEY_COST: 1.5}
	second.add_rect(Rect2i(2, 3, 1, 1))
	zones.areas.append(second)

	var index := ZoneOverlayIndex.new()
	index.rebuild(zones, BOARD_CELLS)
	assert(is_equal_approx(index.cost_at(Vector2i(2, 3)), 3.0), "overlays multiply: %f" % index.cost_at(Vector2i(2, 3)))


## An overlay that denies the visitor audience marks the cell. Until a tag
## issuer exists this is the only audience the engine asks about (§12).
static func _test_deny_visitor_marks_cell() -> void:
	var zones := _layer()
	var staff_only := ZoneAreaRecord.new()
	staff_only.id = &"back_room"
	staff_only.role = ZoneAreaRecord.ROLE_OVERLAY
	staff_only.deny = [ZoneAccess.AUDIENCE_VISITOR]
	staff_only.add_rect(Rect2i(5, 5, 2, 2))
	zones.areas.append(staff_only)

	var index := ZoneOverlayIndex.new()
	index.rebuild(zones, BOARD_CELLS)
	assert(index.denies_visitor(Vector2i(5, 5)))
	assert(not index.denies_visitor(Vector2i(0, 0)))
	# A cell that is merely denied (no cost) still reads cost 1.0: denial is a
	# planning filter, not a price (§4.1).
	assert(is_equal_approx(index.cost_at(Vector2i(5, 5)), 1.0))


## A `region` is a name for rules, not a cost or a right; it leaves the index
## empty. This is what keeps a named trigger area from silently slowing routing.
static func _test_region_is_inert() -> void:
	var zones := _layer()
	var gate := ZoneAreaRecord.new()
	gate.id = &"gate_yard"
	gate.role = ZoneAreaRecord.ROLE_REGION
	gate.effects = {ZoneEffects.KEY_COST: 5.0} # ignored: regions carry no effect
	gate.deny = [ZoneAccess.AUDIENCE_VISITOR] # ignored for the same reason
	gate.add_rect(Rect2i(0, 0, 4, 4))
	zones.areas.append(gate)

	var index := ZoneOverlayIndex.new()
	index.rebuild(zones, BOARD_CELLS)
	assert(is_equal_approx(index.cost_at(Vector2i(1, 1)), 1.0))
	assert(not index.denies_visitor(Vector2i(1, 1)))
