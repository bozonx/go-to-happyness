class_name TestTerrainAnchors
extends RefCounted

## `IS_ANCHOR` end to end (design_docs/engine/grid_terrain_system.md §4.4).
##
## The cascade has always refused to move an anchored column. What was missing was
## anything that wrote one, which made the rule protect nothing. These assert both
## halves at once: a footprint in `BuildingRegistry` pins its ground, releasing it
## unpins it, and while it is pinned the solver refuses an operation whose wave
## would reach it rather than applying part of it.

const BOARD_CELLS := 32


static func run_all() -> void:
	_test_a_footprint_pins_its_ground()
	_test_releasing_a_footprint_unpins_it()
	_test_overlapping_footprints_are_counted_not_flagged()
	_test_the_cascade_refuses_to_undermine_a_building()
	_test_anchors_are_a_transaction_undo_can_see()
	_test_an_existing_registry_is_caught_up_on_configure()
	print("    [PASS] Terrain Anchor Tests")


static func _make() -> Dictionary:
	var grid := TerrainGrid.new()
	grid.configure(1.0, BOARD_CELLS)
	var service := TerrainService.new()
	service.configure(grid)
	var registry := BuildingRegistry.new()
	var anchors := TerrainAnchorService.new()
	anchors.configure(service, registry)
	return {"grid": grid, "service": service, "registry": registry, "anchors": anchors}


## A 2x2 building centred on a cell corner covers exactly the four cells around it.
static func _place(registry: BuildingRegistry, cell: Vector2i, footprint := Vector2i(2, 2)) -> BuildingRecord:
	return registry.reserve(cell, Vector3(float(cell.x), 0.0, float(cell.y)), footprint)


static func _test_a_footprint_pins_its_ground() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var registry: BuildingRegistry = world["registry"]

	assert(not grid.is_anchor(Vector2i(0, 0)))
	_place(registry, Vector2i(0, 0))
	for cell: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		assert(grid.is_anchor(cell), "every column under the footprint is pinned")
	assert(not grid.is_anchor(Vector2i(1, 1)), "and nothing beside it is")


## Construction cancelled or a building demolished has to give the ground back.
## An anchor that outlives its building is a column no brush can ever move again,
## with nothing on the board to explain why.
static func _test_releasing_a_footprint_unpins_it() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var registry: BuildingRegistry = world["registry"]

	_place(registry, Vector2i(4, 4))
	assert(grid.is_anchor(Vector2i(4, 4)))
	registry.cancel_reservation(Vector2i(4, 4))
	assert(not grid.is_anchor(Vector2i(4, 4)))
	assert(not grid.is_anchor(Vector2i(3, 3)))


static func _test_overlapping_footprints_are_counted_not_flagged() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var registry: BuildingRegistry = world["registry"]
	var anchors: TerrainAnchorService = world["anchors"]

	# Two 2x2 footprints one cell apart share a column.
	_place(registry, Vector2i(0, 0))
	_place(registry, Vector2i(1, 0))
	var shared := Vector2i(0, -1)
	assert(anchors.is_anchored(shared))
	assert(grid.is_anchor(shared))

	registry.cancel_reservation(Vector2i(0, 0))
	assert(grid.is_anchor(shared), "the column the other building still stands on stays pinned")
	registry.cancel_reservation(Vector2i(1, 0))
	assert(not grid.is_anchor(shared))
	assert(anchors.anchored_cell_count() == 0)


## The point of the flag: the ground under a building may not sag, and an
## operation whose wave reaches it is refused WHOLE rather than applied in part.
static func _test_the_cascade_refuses_to_undermine_a_building() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]
	var registry: BuildingRegistry = world["registry"]

	_place(registry, Vector2i(0, 0))
	var before := grid.snapshot()

	# Digging right beside the footprint: the pit's rim would drag the anchored
	# column down with it.
	var pit: Array[Vector2i] = [Vector2i(2, 0)]
	assert(not service.apply_operation(TerrainEditOperation.offset(pit, -4)))
	assert(service.last_rejection() == CascadeSolver.REASON_ANCHOR)
	assert(grid.snapshot() == before, "a refused operation leaves the grid untouched")

	# The brush landing directly on the footprint is refused for the same reason.
	assert(not service.apply_operation(TerrainEditOperation.offset([Vector2i(0, 0)] as Array[Vector2i], 1)))
	assert(service.last_rejection() == CascadeSolver.REASON_ANCHOR)

	# Far enough away the same dig is fine, so the flag is a local guarantee and
	# not a board-wide freeze.
	assert(service.apply_operation(TerrainEditOperation.offset([Vector2i(12, 12)] as Array[Vector2i], -4)))


## Anchors go through `TerrainService` like every other write, so they are part of
## a transaction. An anchor set behind the service's back is one undo drops.
static func _test_anchors_are_a_transaction_undo_can_see() -> void:
	var world := _make()
	var grid: TerrainGrid = world["grid"]
	var service: TerrainService = world["service"]
	var registry: BuildingRegistry = world["registry"]

	_place(registry, Vector2i(6, 6))
	assert(grid.is_anchor(Vector2i(6, 6)))
	assert(service.can_undo())
	service.undo()
	assert(not grid.is_anchor(Vector2i(6, 6)))
	service.redo()
	assert(grid.is_anchor(Vector2i(6, 6)))


## A loaded save hands over a registry that already holds records. Wiring the
## service to it has to pin what is already standing, not only what comes next.
static func _test_an_existing_registry_is_caught_up_on_configure() -> void:
	var grid := TerrainGrid.new()
	grid.configure(1.0, BOARD_CELLS)
	var service := TerrainService.new()
	service.configure(grid)
	var registry := BuildingRegistry.new()
	_place(registry, Vector2i(2, 2))
	assert(not grid.is_anchor(Vector2i(2, 2)), "nothing is listening yet")

	var anchors := TerrainAnchorService.new()
	anchors.configure(service, registry)
	assert(grid.is_anchor(Vector2i(2, 2)))
	assert(anchors.anchored_cell_count() == 4)
