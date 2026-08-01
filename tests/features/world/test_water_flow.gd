class_name TestWaterFlow
extends RefCounted

## Undoable flow edits through `WaterService.set_flow` (grid_terrain_system.md §9).
##
## Flow is stored on the `WaterBody`, not on the grid cells, so it needs its own
## edit type (`WaterFlowEdit`) that rides the same undo stack and emits the same
## `edit_committed` signal. These tests prove that arrangement works: flow is
## written, undone, redone, and refused for cells that do not belong to the body.

const BOARD_CELLS := 32


static func run_all() -> void:
	_test_set_flow_writes_to_body()
	_test_set_flow_is_undoable()
	_test_set_flow_skips_other_bodies()
	_test_set_flow_clamps_strength()
	_test_set_flow_nothing_to_do()
	_test_set_flow_emits_committed()
	_test_flow_blocks_ford_after_set()
	_test_retype_keeps_authored_flow()
	print("    [PASS] Water Flow Tests")


# --- Building blocks ----------------------------------------------------------

static func _make() -> Dictionary:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD_CELLS)
	var water := WaterGrid.new()
	water.configure(terrain.cell_size, terrain.board_cells)
	var service := WaterService.new()
	service.configure(water, terrain)
	return {"terrain": terrain, "water": water, "service": service}


## Paints a small river so flow has somewhere to go.
static func _make_river(world: Dictionary) -> int:
	var terrain: TerrainGrid = world["terrain"]
	var service: WaterService = world["service"]

	# Dig a channel and paint a river body into it.
	for x in range(-2, 3):
		terrain.set_height(Vector2i(x, 0), -2)
	var body := service.create_body(WaterBody.Type.RIVER, 0)
	assert(body != null)
	assert(service.paint(
		[Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		body.id, 0))
	return body.id


# --- Tests --------------------------------------------------------------------

static func _test_set_flow_writes_to_body() -> void:
	var world := _make()
	var water: WaterGrid = world["water"]
	var service: WaterService = world["service"]
	var body_id := _make_river(world)
	var body := water.body(body_id)

	# No flow initially.
	assert(body.flow_strength_at(Vector2i(0, 0)) == 0)

	# Set flow east at strength 3.
	assert(service.set_flow([Vector2i(0, 0)], body_id, SlopeCatalog.DIR_E, 3))
	assert(body.flow_direction_at(Vector2i(0, 0)) == SlopeCatalog.DIR_E)
	assert(body.flow_strength_at(Vector2i(0, 0)) == 3)


static func _test_set_flow_is_undoable() -> void:
	var world := _make()
	var water: WaterGrid = world["water"]
	var service: WaterService = world["service"]
	var body_id := _make_river(world)
	var body := water.body(body_id)

	# Set flow, then undo it.
	service.set_flow([Vector2i(0, 0)], body_id, SlopeCatalog.DIR_E, 3)
	assert(body.flow_strength_at(Vector2i(0, 0)) == 3)

	assert(service.undo())
	assert(body.flow_strength_at(Vector2i(0, 0)) == 0)

	# Redo restores it.
	assert(service.redo())
	assert(body.flow_strength_at(Vector2i(0, 0)) == 3)


static func _test_set_flow_skips_other_bodies() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var service: WaterService = world["service"]

	# Two adjacent bodies: a river and a lake.
	for x in range(-2, 3):
		terrain.set_height(Vector2i(x, 0), -2)
	var river := service.create_body(WaterBody.Type.RIVER, 0)
	var lake := service.create_body(WaterBody.Type.LAKE, 0)
	service.paint([Vector2i(-2, 0), Vector2i(-1, 0)], river.id, 0)
	service.paint([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], lake.id, 0)

	# Set flow on the river — lake cells must be untouched.
	service.set_flow([Vector2i(-2, 0), Vector2i(0, 0)], river.id, SlopeCatalog.DIR_E, 2)
	assert(water.body(river.id).flow_strength_at(Vector2i(-2, 0)) == 2)
	# The lake cell (0,0) was not in the river body, so it has no flow.
	assert(water.body(lake.id).flow_strength_at(Vector2i(0, 0)) == 0)


static func _test_set_flow_clamps_strength() -> void:
	var world := _make()
	var water: WaterGrid = world["water"]
	var service: WaterService = world["service"]
	var body_id := _make_river(world)
	var body := water.body(body_id)

	# Strength above the max is clamped.
	service.set_flow([Vector2i(0, 0)], body_id, SlopeCatalog.DIR_E, 99)
	assert(body.flow_strength_at(Vector2i(0, 0)) == WaterBody.MAX_FLOW_STRENGTH)


static func _test_set_flow_nothing_to_do() -> void:
	var world := _make()
	var service: WaterService = world["service"]
	var body_id := _make_river(world)

	# Setting the same flow value that already exists is a no-op.
	service.set_flow([Vector2i(0, 0)], body_id, SlopeCatalog.DIR_E, 3)
	assert(not service.set_flow([Vector2i(0, 0)], body_id, SlopeCatalog.DIR_E, 3))


static func _test_set_flow_emits_committed() -> void:
	var world := _make()
	var service: WaterService = world["service"]
	var body_id := _make_river(world)

	var emitted := [false]
	service.edit_committed.connect(func(_delta: WaterDelta) -> void: emitted[0] = true)

	service.set_flow([Vector2i(0, 0)], body_id, SlopeCatalog.DIR_E, 3)
	assert(emitted[0])


static func _test_flow_blocks_ford_after_set() -> void:
	var world := _make()
	var terrain: TerrainGrid = world["terrain"]
	var water: WaterGrid = world["water"]
	var service: WaterService = world["service"]
	var body_id := _make_river(world)

	# At depth 2 and no flow, the cell is open water (too deep for a ford).
	# But at depth 1 with flow >= FLOW_STRENGTH_BLOCKS_FORD, a ford is blocked.
	# Make a shallow cell.
	terrain.set_height(Vector2i(0, 0), -1)
	service.paint([Vector2i(0, 0)], body_id, 0)

	# Without flow, the shallow cell is a ford.
	assert(water.is_ford(terrain, Vector2i(0, 0)))

	# With strong flow, the ford is blocked.
	service.set_flow([Vector2i(0, 0)], body_id, SlopeCatalog.DIR_E, WaterBody.FLOW_STRENGTH_BLOCKS_FORD)
	assert(not water.is_ford(terrain, Vector2i(0, 0)))


## Current belongs to the painted cells, not the liquid appearance.  An author
## may turn a river into lava and back while tuning a map without repainting all
## its directions and strengths.
static func _test_retype_keeps_authored_flow() -> void:
	var world := _make()
	var water: WaterGrid = world["water"]
	var service: WaterService = world["service"]
	var body_id := _make_river(world)
	var cell := Vector2i(0, 0)
	assert(service.set_flow([cell], body_id, SlopeCatalog.DIR_S, 2))
	assert(service.retype_body(body_id, WaterBody.Type.LAVA))
	assert(water.body(body_id).flow_direction_at(cell) == SlopeCatalog.DIR_S)
	assert(water.body(body_id).flow_strength_at(cell) == 2)
	assert(service.retype_body(body_id, WaterBody.Type.RIVER))
	assert(water.body(body_id).flow_direction_at(cell) == SlopeCatalog.DIR_S)
	assert(water.body(body_id).flow_strength_at(cell) == 2)
