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
	_test_hero_mode_without_spawn_is_an_error()
	_test_settlement_mode_needs_no_spawn()
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


## A hero-mode map with no spawn anchor cannot place the hero — §11.
static func _test_hero_mode_without_spawn_is_an_error() -> void:
	var document := MapDocument.create(&"hero_map", "Hero", BOARD_CELLS)
	document.meta.start.mode_id = MapStart.MODE_HERO
	document.meta.start.systems = {"hero_control": "first_person"}
	var errors := MapValidator.validate(document, _flat_terrain(), WaterGrid.new(), null)
	assert(errors.any(func(m: String) -> bool: return m.find("hero_start") > 0 or m.find("spawn") > 0),
		"hero mode without spawn: %s" % "; ".join(errors))


## A settlement-mode map does not require a spawn — the entrance stone stands in.
static func _test_settlement_mode_needs_no_spawn() -> void:
	var document := MapDocument.create(&"settle", "Settle", BOARD_CELLS)
	# Default mode is settlement; no spawn anchor authored.
	var errors := MapValidator.validate(document, _flat_terrain(), WaterGrid.new(), null)
	assert(errors.is_empty(), "settlement mode needs no spawn: %s" % "; ".join(errors))


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
