class_name TestDomainBuildingEditor
extends RefCounted

## Domain unit tests for the modular building editor (frame level):
## block catalog, grid placement rules, and blueprint JSON round-trip.

const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingGridModelScript = preload("res://game/features/buildings/domain/editor/building_grid_model.gd")
const ActiveWorkZoneRecordScript = preload("res://game/features/buildings/domain/editor/active_work_zone_record.gd")


static func run_all() -> void:
	_test_catalog()
	_test_grid_place_erase()
	_test_grid_rotation_rules()
	_test_grid_bounds()
	_test_blueprint_round_trip()
	_test_grid_blueprint_sync()
	_test_zones_and_metadata_round_trip()


static func _test_catalog() -> void:
	assert(BuildingBlockCatalogScript.all().size() == 8)
	assert(BuildingBlockCatalogScript.has_block(&"cube"))
	assert(not BuildingBlockCatalogScript.has_block(&"nonexistent"))
	assert(BuildingBlockCatalogScript.default_block_id() == &"cube")
	var cube := BuildingBlockCatalogScript.get_block(&"cube")
	assert(cube["size"] == Vector3(1.0, 1.0, 1.0))


static func _test_grid_place_erase() -> void:
	var grid := BuildingGridModelScript.new()
	assert(grid.is_empty())
	assert(grid.place(Vector3i(0, 0, 0), &"cube"))
	assert(grid.count() == 1)
	assert(grid.has_block_at(Vector3i(0, 0, 0)))
	# Placing on the same cell replaces, not duplicates.
	assert(grid.place(Vector3i(0, 0, 0), &"slab"))
	assert(grid.count() == 1)
	assert(grid.get_block_at(Vector3i(0, 0, 0)).block_id == &"slab")
	# Unknown block id is rejected.
	assert(not grid.place(Vector3i(1, 0, 0), &"bogus"))
	assert(grid.count() == 1)
	# Erase.
	assert(grid.erase(Vector3i(0, 0, 0)))
	assert(grid.is_empty())
	assert(not grid.erase(Vector3i(0, 0, 0)))


static func _test_grid_rotation_rules() -> void:
	var grid := BuildingGridModelScript.new()
	# Non-rotatable block clamps rotation to 0.
	grid.place(Vector3i(0, 0, 0), &"cube", 3)
	assert(grid.get_block_at(Vector3i(0, 0, 0)).rot == 0)
	# Rotatable block keeps and wraps rotation.
	grid.place(Vector3i(1, 0, 0), &"wall_panel", 2)
	assert(grid.get_block_at(Vector3i(1, 0, 0)).rot == 2)
	grid.rotate_at(Vector3i(1, 0, 0), 3)
	assert(grid.get_block_at(Vector3i(1, 0, 0)).rot == 1)  # (2 + 3) % 4


static func _test_grid_bounds() -> void:
	var grid := BuildingGridModelScript.new()
	grid.place(Vector3i(2, 0, 3), &"cube")
	grid.place(Vector3i(4, 1, 3), &"cube")
	var b := grid.bounds()
	assert(b.position == Vector3(2, 0, 3))
	assert(b.size == Vector3(3, 2, 1))


static func _test_blueprint_round_trip() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_house"
	bp.name = "Тестовый дом"
	bp.building_type = "surface"
	var grid := BuildingGridModelScript.new()
	grid.place(Vector3i(0, 0, 0), &"cube")
	grid.place(Vector3i(1, 0, 0), &"wall_panel", 1)
	grid.write_to_blueprint(bp)

	var json := bp.to_json()
	var restored := BuildingBlueprintScript.from_json(json)
	assert(restored.id == &"test_house")
	assert(restored.name == "Тестовый дом")
	assert(restored.block_count() == 2)

	var restored_grid := BuildingGridModelScript.new()
	restored_grid.load_from_blueprint(restored)
	assert(restored_grid.count() == 2)
	assert(restored_grid.get_block_at(Vector3i(1, 0, 0)).block_id == &"wall_panel")
	assert(restored_grid.get_block_at(Vector3i(1, 0, 0)).rot == 1)


static func _test_zones_and_metadata_round_trip() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"trade_post"
	bp.footprint = Vector2i(4, 4)
	bp.entrance = Vector2i(0, -2)
	bp.worker_entrances = [Vector2i(0, -2), Vector2i(0, 2)]

	var zone := ActiveWorkZoneRecordScript.new()
	zone.zone_id = &"z_trade"
	zone.zone_name = "Торговый пост"
	zone.kind = ActiveWorkZoneRecordScript.KIND_TRADE
	zone.profession = &"seller"
	zone.max_workers = 2
	zone.add_anchor(Vector3(1.5, 0.0, 1.5), Vector3.ZERO, "trade")
	zone.set_tray(&"output", Vector3(3.5, 0.0, 1.5), 80)
	bp.work_zones.append(zone)

	var restored := BuildingBlueprintScript.from_json(bp.to_json())
	assert(restored.footprint == Vector2i(4, 4))
	assert(restored.entrance == Vector2i(0, -2))
	assert(restored.worker_entrances.size() == 2 and restored.worker_entrances[1] == Vector2i(0, 2))
	assert(restored.work_zones.size() == 1)
	var rz: ActiveWorkZoneRecord = restored.work_zones[0]
	assert(rz.zone_id == &"z_trade")
	assert(rz.kind == ActiveWorkZoneRecordScript.KIND_TRADE)
	assert(rz.profession == &"seller")
	assert(rz.max_workers == 2)
	assert(rz.work_anchors.size() == 1)
	assert(rz.work_anchors[0]["pos"] == Vector3(1.5, 0.0, 1.5))
	assert(rz.work_anchors[0]["action"] == "trade")
	assert(rz.storage_trays.has("output"))
	assert(rz.storage_trays["output"]["capacity"] == 80)
	assert(rz.storage_trays["output"]["pos"] == Vector3(3.5, 0.0, 1.5))


static func _test_grid_blueprint_sync() -> void:
	var bp := BuildingBlueprintScript.new()
	var grid := BuildingGridModelScript.new()
	grid.place(Vector3i(0, 0, 0), &"cube")
	grid.place(Vector3i(0, 1, 0), &"cube")
	grid.write_to_blueprint(bp)
	# grid_bounds reflects the placed extent.
	assert(bp.grid_bounds == Vector3i(1, 2, 1))
	# Blocks are written in a deterministic (y, x, z) order.
	assert(bp.blocks[0].pos == Vector3i(0, 0, 0))
	assert(bp.blocks[1].pos == Vector3i(0, 1, 0))
