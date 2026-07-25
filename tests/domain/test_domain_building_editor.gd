class_name TestDomainBuildingEditor
extends RefCounted

## Domain unit tests for the modular building editor (frame level):
## block catalog, grid placement rules, and blueprint JSON round-trip.

const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")
const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingGridModelScript = preload("res://game/features/buildings/domain/editor/building_grid_model.gd")
const PlaceZoneRecordScript = preload("res://game/features/buildings/domain/editor/place_zone_record.gd")
const ZoneAnchorRecordScript = preload("res://game/features/buildings/domain/editor/zone_anchor_record.gd")
const BuildingZoneServiceScript = preload("res://game/features/buildings/application/building_zone_service.gd")


const BlockMeshLibraryScript = preload("res://game/features/buildings/presentation/editor/block_mesh_library.gd")


static func run_all() -> void:
	_test_catalog()
	_test_mesh_library()
	_test_material_catalog_and_costs()
	_test_material_era_filtering()
	_test_underground_requires_earth_era()
	_test_zone_subtype_round_trip()
	_test_grid_place_erase()
	_test_grid_rotation_rules()
	_test_grid_bounds()
	_test_blueprint_round_trip()
	_test_grid_blueprint_sync()
	_test_zones_and_metadata_round_trip()
	_test_runtime_zone_assignment()
	_test_runtime_zone_subtype_survives()
	_test_invalid_blueprints_are_rejected()
	_test_era_material_replacement()


static func _test_catalog() -> void:
	assert(BuildingBlockCatalogScript.all().size() == 25)
	assert(BuildingBlockCatalogScript.has_block(&"cube"))
	assert(BuildingBlockCatalogScript.has_block(&"stairs_corner_45"))
	assert(BuildingBlockCatalogScript.has_block(&"foundation"))
	assert(not BuildingBlockCatalogScript.has_block(&"nonexistent"))
	# The WALL category was removed; its panels duplicated other blocks.
	assert(not BuildingBlockCatalogScript.has_block(&"wall_panel"))
	assert(not BuildingBlockCatalogScript.has_block(&"parapet"))
	# Columns are now three distinct blocks (square / round / half).
	assert(BuildingBlockCatalogScript.has_block(&"column_square"))
	assert(BuildingBlockCatalogScript.has_block(&"column_round"))
	assert(BuildingBlockCatalogScript.has_block(&"column_half"))
	assert(BuildingBlockCatalogScript.default_block_id() == &"cube")
	var cube := BuildingBlockCatalogScript.get_block(&"cube")
	assert(cube["size"] == Vector3(1.0, 1.0, 1.0))
	# The foundation block is flagged so presentation extends it down to terrain.
	assert(BuildingBlockCatalogScript.extends_down(&"foundation"))
	assert(not BuildingBlockCatalogScript.extends_down(&"cube"))
	# Parametric blocks expose prepared size/profile variants; the first is the
	# default and an unknown request normalizes back to it.
	assert(BuildingBlockCatalogScript.has_variants(&"column_square"))
	assert(not BuildingBlockCatalogScript.has_variants(&"cube"))
	assert(BuildingBlockCatalogScript.default_variant(&"column_square") == &"thick")
	assert(BuildingBlockCatalogScript.normalize_variant(&"column_square", &"bogus") == &"thick")
	assert(BuildingBlockCatalogScript.size_of(&"column_round", &"med") == Vector3(0.5, 1.0, 0.5))
	assert(BuildingBlockCatalogScript.mesh_shape_of(&"column_round", &"med") == BuildingBlockCatalogScript.SHAPE_CYLINDER)
	# Openings occupy a 3×3 face; single-cell blocks report a unit footprint.
	assert(BuildingBlockCatalogScript.footprint_of(&"door_wall") == Vector3i(3, 3, 1))
	assert(BuildingBlockCatalogScript.is_multicell(&"door_wall"))
	assert(not BuildingBlockCatalogScript.is_multicell(&"cube"))
	_test_anchoring()


static func _test_anchoring() -> void:
	var C := BuildingBlockCatalogScript
	# A 0.5m column is thin on both axes: centre + edge + corner. A full cube has
	# only centre. A railing/half-slab is thin on one axis: centre + edge, no corner.
	assert(C.available_anchors(&"column_square", &"med") == [C.ANCHOR_CENTER, C.ANCHOR_EDGE, C.ANCHOR_CORNER])
	assert(C.available_anchors(&"cube", &"") == [C.ANCHOR_CENTER])
	assert(C.available_anchors(&"railing", &"full") == [C.ANCHOR_CENTER, C.ANCHOR_EDGE])
	assert(C.available_anchors(&"half_slab", &"") == [C.ANCHOR_CENTER, C.ANCHOR_EDGE])
	# A multi-cell opening anchors only at its centre.
	assert(C.available_anchors(&"door_wall", &"") == [C.ANCHOR_CENTER])
	# Centre stays centred; corner snaps the 0.5m block flush to a corner and
	# rotation pivots it around the cell centre to the opposite corner.
	assert(C.cell_offset(&"column_square", &"med", C.ANCHOR_CENTER, 0) == Vector2(0.5, 0.5))
	assert(_approx(C.cell_offset(&"column_square", &"med", C.ANCHOR_CORNER, 0), Vector2(0.25, 0.25)))
	assert(_approx(C.cell_offset(&"column_square", &"med", C.ANCHOR_CORNER, 2), Vector2(0.75, 0.75)))
	# A half-slab edge-anchors flush to its thin (-Z) side; a 90° turn moves that
	# flush face onto the X axis (Z re-centres) — the other edges via rotation.
	var wall0 := C.cell_offset(&"half_slab", &"", C.ANCHOR_EDGE, 0)
	assert(is_equal_approx(wall0.x, 0.5) and wall0.y < 0.2)
	var wall1 := C.cell_offset(&"half_slab", &"", C.ANCHOR_EDGE, 1)
	assert(wall1.x < 0.2 and is_equal_approx(wall1.y, 0.5))


static func _approx(a: Vector2, b: Vector2) -> bool:
	return is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y)


static func _test_mesh_library() -> void:
	var lib := BlockMeshLibraryScript.new()
	for block_id in BuildingBlockCatalogScript.ids():
		var mesh := lib.mesh_for(block_id)
		assert(mesh != null, "Mesh generation failed for block: " + String(block_id))
		var offset := BlockMeshLibraryScript.local_offset(block_id, &"", 0, 0, 0.5)
		assert(offset.y > 0.0)
		# Every declared variant must also build a mesh.
		for v in BuildingBlockCatalogScript.variants(block_id):
			assert(lib.mesh_for(block_id, v["id"]) != null, "Variant mesh failed: %s/%s" % [block_id, v["id"]])
	var wood_mat := lib.material_for(&"wood")
	assert(wood_mat != null)
	assert(wood_mat.uv1_triplanar == true)
	_test_tilt_rotates_detail_about_cell_centre()


## A sub-cell detail must orbit the fixed 1×1×1 slot with the mesh, rather
## than being re-grounded after each tilt. A 180° X or Z turn therefore moves
## the half-height rectangle from the bottom to the top half of its slot.
static func _test_tilt_rotates_detail_about_cell_centre() -> void:
	var bottom := BlockMeshLibraryScript.local_offset(&"rectangle")
	assert(is_equal_approx(bottom.y, 0.25))
	var top_x := BlockMeshLibraryScript.local_offset(&"rectangle", &"", 0, 0, 0.0, 2, 0)
	var top_z := BlockMeshLibraryScript.local_offset(&"rectangle", &"", 0, 0, 0.0, 0, 2)
	assert(is_equal_approx(top_x.y, 0.75), "X tilt must move the detail into the slot's upper half")
	assert(is_equal_approx(top_z.y, 0.75), "Z tilt must move the detail into the slot's upper half")


static func _test_material_catalog_and_costs() -> void:
	assert(BuildingMaterialCatalogScript.all().size() == 13)
	assert(BuildingMaterialCatalogScript.resource_id(&"earth") == &"soil")
	assert(BuildingMaterialCatalogScript.resource_id(&"wood") == &"boards")
	var bp := BuildingBlueprintScript.new()
	bp.id = &"mixed_frame"
	bp.category = &"stone"
	var grid := BuildingGridModelScript.new()
	assert(grid.place(Vector3i.ZERO, &"cube", 0, &"earth"))
	assert(grid.place(Vector3i(1, 0, 0), &"half_slab", 1, &"stone"))
	# A parametric block records its chosen variant and in-cell anchor kind.
	assert(grid.place(Vector3i(2, 0, 0), &"column_round", 0, &"stone", &"med", BuildingBlockCatalogScript.ANCHOR_CORNER))
	assert(grid.get_block_at(Vector3i(2, 0, 0)).variant == &"med")
	assert(grid.get_block_at(Vector3i(2, 0, 0)).anchor == BuildingBlockCatalogScript.ANCHOR_CORNER)
	grid.write_to_blueprint(bp)
	bp.recalculate_construction_cost()
	assert(bp.construction_cost == {"soil": 1, "stone": 2})
	var restored := BuildingBlueprintScript.from_json(bp.to_json())
	assert(restored != null)
	assert(restored.blocks[0].material_id == &"earth")
	assert(restored.blocks[1].material_id == &"stone")
	# Variant + anchor survive the JSON round-trip; single-size blocks stay
	# variant-less and centred.
	assert(restored.blocks[0].variant == &"")
	assert(restored.blocks[0].anchor == BuildingBlockCatalogScript.ANCHOR_CENTER)
	var col := restored.blocks[2] if restored.blocks[2].block_id == &"column_round" else restored.blocks[1]
	assert(col.variant == &"med")
	assert(col.anchor == BuildingBlockCatalogScript.ANCHOR_CORNER)


static func _test_material_era_filtering() -> void:
	# Materials are cumulative: an era offers its own plus every earlier era's.
	var tent := BuildingMaterialCatalogScript.materials_for_era(&"tent")
	var tent_ids := tent.map(func(m): return m["id"])
	assert(&"branches" in tent_ids and &"thatch" in tent_ids)
	assert(&"earth" not in tent_ids and &"stone" not in tent_ids)
	# Earth era adds soil but still allows the tent materials.
	assert(BuildingMaterialCatalogScript.is_available_in_era(&"branches", &"earth"))
	assert(BuildingMaterialCatalogScript.is_available_in_era(&"earth", &"earth"))
	assert(not BuildingMaterialCatalogScript.is_available_in_era(&"stone", &"earth"))
	# Each era resolves to a defining default material.
	assert(BuildingMaterialCatalogScript.default_material_for_era(&"earth") == &"earth")
	assert(BuildingMaterialCatalogScript.default_material_for_era(&"brick") == &"brick")


static func _test_underground_requires_earth_era() -> void:
	var tent_underground := BuildingBlueprintScript.new()
	tent_underground.id = &"tent_bunker"
	tent_underground.category = &"tent"
	tent_underground.construction_style = &"underground"
	assert(not tent_underground.validation_errors().is_empty())
	# The same building becomes valid once it is an earth-era structure.
	tent_underground.category = &"earth"
	assert(tent_underground.validation_errors().is_empty())


static func _test_zone_subtype_round_trip() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"town_park"
	var leisure := PlaceZoneRecordScript.new()
	leisure.zone_id = &"z_park"
	leisure.kind = PlaceZoneRecordScript.KIND_LEISURE
	leisure.subtype = &"cinema"
	bp.place_zones.append(leisure)
	var gate := PlaceZoneRecordScript.new()
	gate.zone_id = &"z_gate"
	gate.kind = PlaceZoneRecordScript.KIND_SPECIAL
	gate.subtype = &"entrance_sign"
	bp.place_zones.append(gate)
	var restored := BuildingBlueprintScript.from_json(bp.to_json())
	assert(restored != null)
	assert(restored.place_zones[0].kind == PlaceZoneRecordScript.KIND_LEISURE)
	assert(restored.place_zones[0].subtype == &"cinema")
	assert(restored.place_zones[1].kind == PlaceZoneRecordScript.KIND_SPECIAL)
	assert(restored.place_zones[1].subtype == &"entrance_sign")
	assert(&"cinema" in PlaceZoneRecordScript.subtypes_for_kind(PlaceZoneRecordScript.KIND_LEISURE))
	assert(&"entrance_sign" in PlaceZoneRecordScript.subtypes_for_kind(PlaceZoneRecordScript.KIND_SPECIAL))


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
	_test_grid_multicell()


static func _test_grid_multicell() -> void:
	var grid := BuildingGridModelScript.new()
	# A 3×3 opening occupies nine cells: the anchor plus a ring around/above it.
	assert(grid.place(Vector3i(5, 0, 5), &"door_wall"))
	assert(grid.count() == 1)
	assert(grid.has_block_at(Vector3i(5, 0, 5)))    # anchor
	assert(grid.has_block_at(Vector3i(4, 0, 5)))    # left of anchor
	assert(grid.has_block_at(Vector3i(6, 2, 5)))    # top-right of the face
	# Any covered cell resolves back to the single anchor block.
	assert(grid.anchor_at(Vector3i(6, 2, 5)) == Vector3i(5, 0, 5))
	assert(grid.get_block_at(Vector3i(4, 0, 5)).block_id == &"door_wall")
	# Erasing from a non-anchor cell removes the whole block.
	assert(grid.erase(Vector3i(6, 2, 5)))
	assert(grid.is_empty())
	assert(not grid.has_block_at(Vector3i(5, 0, 5)))
	# A new block placed overlapping an opening evicts it.
	assert(grid.place(Vector3i(0, 0, 0), &"window_wall"))
	assert(grid.count() == 1)
	assert(grid.place(Vector3i(0, 0, 0), &"cube"))   # overlaps the window's centre
	assert(grid.count() == 1)
	assert(grid.get_block_at(Vector3i(0, 0, 0)).block_id == &"cube")
	assert(not grid.has_block_at(Vector3i(1, 0, 0)))  # window's ring is gone


static func _test_grid_rotation_rules() -> void:
	var grid := BuildingGridModelScript.new()
	# Non-rotatable block clamps rotation to 0.
	grid.place(Vector3i(0, 0, 0), &"cube", 3)
	assert(grid.get_block_at(Vector3i(0, 0, 0)).rot == 0)
	# Rotatable block keeps and wraps rotation.
	grid.place(Vector3i(1, 0, 0), &"half_slab", 2)
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
	grid.place(Vector3i(1, 0, 0), &"half_slab", 1)
	grid.write_to_blueprint(bp)

	var json := bp.to_json()
	var restored := BuildingBlueprintScript.from_json(json)
	assert(restored.id == &"test_house")
	assert(restored.name == "Тестовый дом")
	assert(restored.block_count() == 2)

	var restored_grid := BuildingGridModelScript.new()
	restored_grid.load_from_blueprint(restored)
	assert(restored_grid.count() == 2)
	assert(restored_grid.get_block_at(Vector3i(1, 0, 0)).block_id == &"half_slab")
	assert(restored_grid.get_block_at(Vector3i(1, 0, 0)).rot == 1)


static func _test_zones_and_metadata_round_trip() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"trade_post"
	bp.footprint = Vector2i(4, 4)
	bp.entrance = Vector2i(0, -2)
	bp.worker_entrances = [Vector2i(0, -2), Vector2i(0, 2)]

	var place := PlaceZoneRecordScript.new()
	place.zone_id = &"z_trade"
	place.zone_name = "Торговый пост"
	place.kind = PlaceZoneRecordScript.KIND_TRADE
	place.profession = &"seller"
	place.max_workers = 2
	place.cells = [Vector3i(1, 0, 1), Vector3i(2, 0, 1)]
	bp.place_zones.append(place)
	# Tier-2 slot (counter) and tier-2 tray, plus a tier-3 routing door.
	var counter := ZoneAnchorRecordScript.new()
	counter.anchor_id = &"counter"
	counter.owner_zone_id = &"z_trade"
	counter.role = ZoneAnchorRecordScript.ROLE_COUNTER
	counter.pos = Vector3(1.5, 0.0, 1.5)
	bp.zone_anchors.append(counter)
	var tray := ZoneAnchorRecordScript.new()
	tray.anchor_id = &"out"
	tray.owner_zone_id = &"z_trade"
	tray.role = ZoneAnchorRecordScript.ROLE_OUTPUT_TRAY
	tray.pos = Vector3(3.5, 0.0, 1.5)
	tray.capacity = 80
	bp.zone_anchors.append(tray)
	var door := ZoneAnchorRecordScript.new()
	door.anchor_id = &"vdoor"
	door.owner_zone_id = &"z_trade"
	door.role = ZoneAnchorRecordScript.ROLE_VISITOR_DOOR
	door.pos = Vector3(1.5, 0.0, 0.0)
	bp.zone_anchors.append(door)

	var restored := BuildingBlueprintScript.from_json(bp.to_json())
	assert(restored.footprint == Vector2i(4, 4))
	assert(restored.entrance == Vector2i(0, -2))
	assert(restored.worker_entrances.size() == 2 and restored.worker_entrances[1] == Vector2i(0, 2))
	assert(restored.place_zones.size() == 1)
	assert(restored.zone_anchors.size() == 3)
	var rp: PlaceZoneRecord = restored.place_zones[0]
	assert(rp.zone_id == &"z_trade")
	assert(rp.kind == PlaceZoneRecordScript.KIND_TRADE)
	assert(rp.profession == &"seller")
	assert(rp.max_workers == 2)
	assert(rp.cells == [Vector3i(1, 0, 1), Vector3i(2, 0, 1)])

	# Denormalization groups the anchors back under the place; the routing door
	# is excluded from work zones and surfaces via routing_anchor_definitions.
	var runtime_defs := restored.runtime_zone_definitions()
	assert(runtime_defs.size() == 1)
	var def: Dictionary = runtime_defs[0]
	assert(def["work_anchors"].size() == 1)
	assert(def["work_anchors"][0]["action"] == "counter")
	assert(def["storage_trays"].has("output"))
	assert(def["storage_trays"]["output"]["capacity"] == 80)
	assert(restored.routing_anchor_definitions().size() == 1)
	assert(restored.routing_anchor_definitions()[0]["role"] == "visitor_door")

	# Legacy `work_zones[]` files still load via built-in migration.
	var legacy := {
		"version": 1, "id": "legacy_post", "name": "Legacy", "category": "tent",
		"footprint": [4, 4], "blocks": [],
		"work_zones": [{
			"id": "z_old", "kind": "workplace", "profession_type": "cook", "max_workers": 1,
			"cells": [[0, 0, 0]],
			"work_anchors": [{"id": "oven", "pos": [0.5, 0.0, 0.5], "rot": [0, 0, 0], "action": "work"}],
			"storage_trays": {"input": {"pos": [1.5, 0.0, 0.5], "capacity": 40}},
		}],
	}
	var migrated := BuildingBlueprintScript.from_dict(legacy)
	assert(migrated.place_zones.size() == 1 and migrated.place_zones[0].zone_id == &"z_old")
	assert(migrated.zone_anchors.size() == 2)
	assert(migrated.runtime_zone_definitions()[0]["storage_trays"]["input"]["capacity"] == 40)


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


static func _test_runtime_zone_assignment() -> void:
	var building := Node3D.new()
	var zone_service := BuildingZoneServiceScript.new()
	zone_service.configure_building(building, [{
		"id": "cook_1",
		"name": "Kitchen",
		"kind": "workplace",
		"profession_type": "cook",
		"max_workers": 2,
		"cells": [[0, 0, 0]],
		"work_anchors": [{"id": "oven", "pos": [1.0, 0.0, 2.0], "rot": [0, 0, 0], "action": "work"}],
		"storage_trays": {},
	}])
	assert(zone_service.supports_role(building, &"cook"))
	assert(zone_service.role_capacity(building, &"cook") == 2)
	assert(zone_service.work_position(building, &"cook", 10) == Vector3(1.0, 0.0, 2.0))
	building.free()


## A leisure zone's subtype must survive the definition -> runtime-state ->
## meta -> definition round trip so the game knows which need it satisfies.
static func _test_runtime_zone_subtype_survives() -> void:
	var building := Node3D.new()
	var zone_service := BuildingZoneServiceScript.new()
	zone_service.configure_building(building, [{
		"id": "cinema_1",
		"name": "Cinema",
		"kind": "leisure",
		"subtype": "cinema",
		"max_workers": 0,
		"cells": [[0, 0, 0]],
	}])
	var snapshot := zone_service.zone_snapshot(building)
	assert(snapshot.size() == 1)
	assert(snapshot[0].get("subtype", "") == "cinema", "subtype must be preserved at runtime")
	building.free()


static func _test_invalid_blueprints_are_rejected() -> void:
	var unsupported := BuildingBlueprintScript.new()
	unsupported.version = 999
	assert(BuildingBlueprintScript.from_json(unsupported.to_json()) == null)
	var invalid_material := BuildingBlueprintScript.new()
	invalid_material.id = &"invalid_material"
	invalid_material.blocks.append(BlueprintBlockScript.new(Vector3i.ZERO, &"cube", 0, &"unobtainium"))
	assert(BuildingBlueprintScript.from_json(invalid_material.to_json()) == null)


static func _test_era_material_replacement() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"stone_house"
	bp.category = &"stone"

	var grid := BuildingGridModelScript.new()
	assert(grid.place(Vector3i.ZERO, &"cube", 0, &"branches"))
	assert(grid.place(Vector3i(1, 0, 0), &"half_slab", 0, &"stone"))
	assert(grid.place(Vector3i(2, 0, 0), &"cube", 0, &"wood"))

	var target_era: StringName = &"tent"
	var offending_blocks: Array[BlueprintBlockScript] = []
	for block in grid.all_blocks():
		if not BuildingMaterialCatalogScript.is_available_in_era(block.material_id, target_era):
			offending_blocks.append(block)

	assert(offending_blocks.size() == 2, "Stone and wood blocks are unavailable in tent era")
	var default_mat := BuildingMaterialCatalogScript.default_material_for_era(target_era)
	assert(BuildingMaterialCatalogScript.is_available_in_era(default_mat, target_era))

	for block in offending_blocks:
		block.material_id = default_mat

	grid.write_to_blueprint(bp)
	bp.category = target_era
	bp.recalculate_construction_cost()

	for block in bp.blocks:
		assert(BuildingMaterialCatalogScript.is_available_in_era(block.material_id, bp.category))
	assert(not bp.construction_cost.is_empty())
