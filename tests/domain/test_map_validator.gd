class_name TestMapValidator
extends RefCounted

## Domain tests for the cross-cutting map validator (active_zones.md §8.1,
## map_editor.md §11): a spawn in a hole, under impassable water, or on lava is a
## launch error, as is a hero-mode map with no spawn anchor at all. Each check
## needs the published grids, so these complement the structural rules in
## `MapZoneLayer.validate` rather than duplicating them.

const BOARD_CELLS := 16


static func run_all() -> void:
	_test_spawn_in_hole_is_an_error()
	_test_spawn_under_deep_water_is_an_error()
	_test_spawn_on_lava_is_an_error()
	_test_spawn_on_dry_ground_is_clean()
	_test_frozen_water_is_walkable()
	_test_coverage_made_too_steep_after_paint_is_an_error()
	_test_settlement_map_without_spawns_is_clean()
	_test_party_spawns_are_required_at_launch()
	_test_warnings_skip_when_nav_grid_is_null()
	_test_anchor_on_blocked_cell_warns()
	_test_route_across_a_wall_warns()
	_test_connected_route_has_no_warnings()
	print("    [PASS] Map Validator Tests")


## A spawn anchor whose cell is a terrain hole cannot start the map.
static func _test_spawn_in_hole_is_an_error() -> void:
	var terrain := _flat_terrain()
	terrain.set_hole(Vector2i(4, 4), true)
	var document := _document_with_spawn_at(Vector2i(4, 4))
	var errors := MapValidator.validate(document, terrain, WaterGrid.new(), null)
	assert(errors.any(func(m: String) -> bool: return m.find("вырезе") > 0),
		"spawn in hole: %s" % "; ".join(errors))


## A spawn under water deeper than a ford is unreachable — ice would save it.
static func _test_spawn_under_deep_water_is_an_error() -> void:
	var terrain := _flat_terrain()
	var water := WaterGrid.new()
	water.configure(1.0, BOARD_CELLS)
	var lake := water.create_body(WaterBody.Type.LAKE, 0)
	# Ground at 0, water surface at 3 → depth 3 steps, well past the ford limit.
	terrain.set_height(Vector2i(5, 5), 0)
	water.set_cell(Vector2i(5, 5), lake.id, 3)
	var document := _document_with_spawn_at(Vector2i(5, 5))
	var errors := MapValidator.validate(document, terrain, water, null)
	assert(errors.any(func(m: String) -> bool: return m.find("водой") > 0),
		"spawn under deep water: %s" % "; ".join(errors))


## Lava never becomes walkable, frozen or not — a spawn on lava is always wrong.
static func _test_spawn_on_lava_is_an_error() -> void:
	var terrain := _flat_terrain()
	var water := WaterGrid.new()
	water.configure(1.0, BOARD_CELLS)
	var lava := water.create_body(WaterBody.Type.LAVA, 0)
	water.set_cell(Vector2i(6, 6), lava.id, 1)
	var document := _document_with_spawn_at(Vector2i(6, 6))
	var errors := MapValidator.validate(document, terrain, water, null)
	assert(errors.any(func(m: String) -> bool: return m.find("лаве") > 0),
		"spawn on lava: %s" % "; ".join(errors))


## A spawn on ordinary dry ground produces no cross-cutting errors.
static func _test_spawn_on_dry_ground_is_clean() -> void:
	var document := _document_with_spawn_at(Vector2i(2, 2))
	var errors := MapValidator.validate(document, _flat_terrain(), WaterGrid.new(), null)
	assert(errors.is_empty(), "dry-ground spawn should be clean: %s" % "; ".join(errors))


## Frozen water is walkable (ice) — a spawn on a frozen lake is not an error.
static func _test_frozen_water_is_walkable() -> void:
	var terrain := _flat_terrain()
	var water := WaterGrid.new()
	water.configure(1.0, BOARD_CELLS)
	var lake := water.create_body(WaterBody.Type.LAKE, 0)
	water.set_cell(Vector2i(7, 7), lake.id, 3)
	water.set_frozen(Vector2i(7, 7), true)
	var document := _document_with_spawn_at(Vector2i(7, 7))
	var errors := MapValidator.validate(document, terrain, water, null)
	assert(errors.is_empty(), "frozen water is walkable: %s" % "; ".join(errors))


static func _test_coverage_made_too_steep_after_paint_is_an_error() -> void:
	var document := MapDocument.create(&"steep_road", "Steep road", BOARD_CELLS)
	# Direct layer setup represents the real failure sequence after terrain edit:
	# the road was valid when painted, then the terrain beneath it changed.
	var cell := Vector2i(3, 0)
	document.coverage.set_cell(cell, CoverageCatalog.index_of_id(CoverageCatalog.STONE), 0)
	for z in range(-8, 8):
		for x in range(4, 8):
			document.terrain.set_height(Vector2i(x, z), 1)
	assert(document.terrain.place_ramp(Vector2i(2, 0), SlopeCatalog.MODERATE, SlopeCatalog.DIR_E))
	var errors := MapValidator.validate(document, document.terrain, document.water, null)
	assert(errors.any(func(message: String) -> bool:
		return message.contains("каменная") and message.contains("крутом уклоне")
	), "invalid road slope should be reported: %s" % "; ".join(errors))


## A settlement map with no spawn anchors is not a launch error on its own —
## `validate_party_spawns` is the gate that demands them at launch time.
static func _test_settlement_map_without_spawns_is_clean() -> void:
	var document := MapDocument.create(&"settle", "Settle", BOARD_CELLS)
	var errors := MapValidator.validate(document, _flat_terrain(), WaterGrid.new(), null)
	assert(errors.is_empty(), "settlement map needs no spawn at validate time: %s" % "; ".join(errors))


static func _test_party_spawns_are_required_at_launch() -> void:
	var document := MapDocument.create(&"party", "Party", BOARD_CELLS)
	var errors := MapValidator.validate_party_spawns(document, 4)
	assert(errors.size() == 2, "launch rejects missing hero and companions: %s" % "; ".join(errors))
	var hero := ZoneAnchorRecord.new()
	hero.id = &"hero_start"
	hero.role = ZoneAnchorRecord.ROLE_SPAWN
	hero.function = MapSpawnService.HERO_START
	hero.pos = Vector3(0.5, 0.0, 0.5)
	document.zones.anchors.append(hero)
	for index in 3:
		var companion := ZoneAnchorRecord.new()
		companion.id = StringName("companion_%d" % index)
		companion.role = ZoneAnchorRecord.ROLE_SPAWN
		companion.function = MapSpawnService.COMPANION_START
		companion.pos = Vector3(1.5 + index, 0.0, 0.5)
		document.zones.anchors.append(companion)
	errors = MapValidator.validate_party_spawns(document, 4)
	assert(errors.is_empty(), "complete authored party starts launch: %s" % "; ".join(errors))


static func _flat_terrain() -> TerrainGrid:
	var terrain := TerrainGrid.new()
	terrain.configure(1.0, BOARD_CELLS)
	return terrain


static func _document_with_spawn_at(cell: Vector2i) -> MapDocument:
	var document := MapDocument.create(&"spawn_map", "Spawn", BOARD_CELLS)
	var spawn := ZoneAnchorRecord.new()
	spawn.id = &"hero_start"
	spawn.role = ZoneAnchorRecord.ROLE_SPAWN
	spawn.pos = Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)
	document.zones.anchors.append(spawn)
	return document


# --- Reachability warnings (§11) ---------------------------------------------


## `warnings` is the editor's "Проверить" job, not the save path's: with no
## navigation field there is nothing to check, so it returns nothing rather than
## guessing. This is the property that lets save call `validate` with nav=null.
static func _test_warnings_skip_when_nav_grid_is_null() -> void:
	var document := _document_with_spawn_at(Vector2i(2, 2))
	assert(MapValidator.warnings(document, null).is_empty())


## A waypoint anchored on a navigation-blocked cell is reachable only by
## teleport — a warning the author wants before shipping.
static func _test_anchor_on_blocked_cell_warns() -> void:
	var nav := NavGrid.new()
	nav.configure(1.0, BOARD_CELLS)
	nav.set_blocked_cells({Vector2i(3, 3): true})
	var document := MapDocument.create(&"w", "W", BOARD_CELLS)
	var waypoint := ZoneAnchorRecord.new()
	waypoint.id = &"post"
	waypoint.role = ZoneAnchorRecord.ROLE_WAYPOINT
	waypoint.pos = Vector3(3.5, 0.0, 3.5)
	document.zones.anchors.append(waypoint)
	var warnings := MapValidator.warnings(document, nav)
	assert(warnings.any(func(m: String) -> bool: return m.find("непроходим") > 0),
		"anchor on blocked cell: %s" % "; ".join(warnings))


## A route whose consecutive stops sit in disconnected NavGrid components cannot
## be walked — the wall between them has no path through it.
static func _test_route_across_a_wall_warns() -> void:
	var nav := NavGrid.new()
	nav.configure(1.0, BOARD_CELLS)
	# Block a full column to split the board into left/right components.
	var wall: Dictionary = {}
	for y in BOARD_CELLS:
		wall[Vector2i(8, y)] = true
	nav.set_blocked_cells(wall)
	var document := MapDocument.create(&"r", "R", BOARD_CELLS)
	_add_waypoint(document, &"a", Vector2i(2, 2))
	_add_waypoint(document, &"b", Vector2i(12, 2)) # across the wall
	var route := ZoneRouteRecord.new()
	route.id = &"patrol"
	route.stops = [&"a", &"b"]
	document.zones.routes.append(route)
	var warnings := MapValidator.warnings(document, nav)
	assert(warnings.any(func(m: String) -> bool: return m.find("не связаны") > 0),
		"route across a wall: %s" % "; ".join(warnings))


## Two stops in the same connected component produce no route warning.
static func _test_connected_route_has_no_warnings() -> void:
	var nav := NavGrid.new()
	nav.configure(1.0, BOARD_CELLS)
	var document := MapDocument.create(&"rc", "RC", BOARD_CELLS)
	_add_waypoint(document, &"a", Vector2i(2, 2))
	_add_waypoint(document, &"b", Vector2i(3, 2)) # adjacent, same component
	var route := ZoneRouteRecord.new()
	route.id = &"patrol"
	route.stops = [&"a", &"b"]
	document.zones.routes.append(route)
	var warnings := MapValidator.warnings(document, nav)
	# The two waypoints are walkable and connected; no anchor warning either.
	for w in warnings:
		assert(false, "connected route should have no warnings: %s" % w)


static func _add_waypoint(document: MapDocument, id: StringName, cell: Vector2i) -> void:
	var waypoint := ZoneAnchorRecord.new()
	waypoint.id = id
	waypoint.role = ZoneAnchorRecord.ROLE_WAYPOINT
	waypoint.pos = Vector3(float(cell.x) + 0.5, 0.0, float(cell.y) + 0.5)
	document.zones.anchors.append(waypoint)
