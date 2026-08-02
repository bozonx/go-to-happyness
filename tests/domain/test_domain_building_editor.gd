class_name TestDomainBuildingEditor
extends RefCounted

## Domain unit tests for the modular building editor (frame level):
## block catalog, grid placement rules, and blueprint JSON round-trip.

const BuildingBlockCatalogScript = preload("res://game/features/buildings/domain/editor/building_block_catalog.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")
const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingGridModelScript = preload("res://game/features/buildings/domain/editor/building_grid_model.gd")
const ZoneAnchorRecordScript = preload("res://game/features/buildings/domain/editor/zone_anchor_record.gd")
const BuildingZoneServiceScript = preload("res://game/features/buildings/application/building_zone_service.gd")
const ContentIndexScript = preload("res://game/features/content/application/content_index.gd")
const ContentEntryScript = preload("res://game/features/content/domain/content_entry.gd")
const ContentIdScript = preload("res://game/features/content/domain/content_id.gd")
const StyleResolverScript = preload("res://game/features/content/application/style_resolver.gd")
const ContentPackIOScript = preload("res://game/features/content/presentation/content_pack_io.gd")


const BlockMeshLibraryScript = preload("res://game/features/buildings/presentation/editor/block_mesh_library.gd")


static func run_all() -> void:
	_test_catalog()
	_test_mesh_library()
	_test_material_catalog_and_costs()
	_test_zone_function_round_trip()
	_test_zone_invariants()
	_test_grid_place_erase()
	_test_grid_shared_cell()
	_test_grid_rotation_rules()
	_test_grid_bounds()
	_test_blueprint_round_trip()
	_test_grid_blueprint_sync()
	_test_zones_and_metadata_round_trip()
	_test_authored_building_access_points()
	_test_runtime_zone_assignment()
	_test_runtime_zone_function_survives()
	_test_zone_session_state_round_trip()
	_test_runtime_zone_falls_back_to_centre()
	_test_invalid_blueprints_are_rejected()
	_test_style_resolver_fallback_chain()
	_test_content_packs_and_exchange()


static func _test_catalog() -> void:
	assert(BuildingBlockCatalogScript.all().size() == 23)
	assert(BuildingBlockCatalogScript.has_block(&"cube"))
	assert(BuildingBlockCatalogScript.has_block(&"stairs_corner_45"))
	assert(BuildingBlockCatalogScript.has_block(&"stairs_corner_half"))
	assert(BuildingBlockCatalogScript.has_block(&"stairs_corner_quarter"))
	assert(BuildingBlockCatalogScript.has_block(&"foundation"))
	assert(BuildingBlockCatalogScript.has_block(&"roof_angle_large"))
	assert(BuildingBlockCatalogScript.has_block(&"roof_angle_small"))
	assert(not BuildingBlockCatalogScript.has_block(&"nonexistent"))
	# The WALL category was removed; its panels duplicated other blocks.
	assert(not BuildingBlockCatalogScript.has_block(&"wall_panel"))
	assert(not BuildingBlockCatalogScript.has_block(&"parapet"))
	# Crossings are compositions of basic columns, not their own palette entries.
	assert(BuildingBlockCatalogScript.has_block(&"column_square"))
	assert(BuildingBlockCatalogScript.has_block(&"column_round"))
	assert(BuildingBlockCatalogScript.has_block(&"column_half"))
	assert(not BuildingBlockCatalogScript.has_block(&"column_square_cross_2"))
	assert(not BuildingBlockCatalogScript.has_block(&"rectangle"))
	assert(BuildingBlockCatalogScript.default_block_id() == &"cube")
	var cube := BuildingBlockCatalogScript.get_block(&"cube")
	assert(cube["size"] == Vector3(1.0, 1.0, 1.0))
	# The foundation block is flagged so presentation extends it down to terrain.
	assert(BuildingBlockCatalogScript.extends_down(&"foundation"))
	assert(not BuildingBlockCatalogScript.extends_down(&"cube"))
	# Parametric blocks expose prepared size/profile variants; the first is the
	# default and an unknown request normalizes back to it.
	assert(BuildingBlockCatalogScript.has_variants(&"column_square"))
	assert(BuildingBlockCatalogScript.has_variants(&"cube"))
	assert(BuildingBlockCatalogScript.default_variant(&"column_square") == &"0.5")
	assert(BuildingBlockCatalogScript.normalize_variant(&"column_square", &"bogus") == &"0.5")
	assert(BuildingBlockCatalogScript.size_of(&"column_round", &"0.5") == Vector3(0.5, 1.0, 0.5))
	assert(BuildingBlockCatalogScript.size_of(&"column_square", &"0.25_half") == Vector3(0.25, 0.5, 0.25))
	assert(BuildingBlockCatalogScript.size_of(&"column_round", &"0.5_quarter") == Vector3(0.5, 0.25, 0.5))
	assert(BuildingBlockCatalogScript.size_of(&"column_half", &"0.5_quarter") == Vector3(0.5, 0.25, 0.25))
	assert(BuildingBlockCatalogScript.variant_for_options(&"column_round", &"0.5", &"quarter") == &"0.5_quarter")
	assert(BuildingBlockCatalogScript.mesh_shape_of(&"column_round", &"0.5") == BuildingBlockCatalogScript.SHAPE_CYLINDER)
	assert(BuildingBlockCatalogScript.size_of(&"arch") == Vector3(1.0, 1.0, 1.0))
	assert(BuildingBlockCatalogScript.has_variants(&"arch"))
	assert(BuildingBlockCatalogScript.default_variant(&"arch") == &"1")
	assert(BuildingBlockCatalogScript.mesh_shape_of(&"arch", &"1") == BuildingBlockCatalogScript.SHAPE_HALF_ARCH)
	assert(BuildingBlockCatalogScript.mesh_shape_of(&"arch", &"1_2") == BuildingBlockCatalogScript.SHAPE_ARCH_RING)
	assert(BuildingBlockCatalogScript.size_of(&"arch", &"1_2") == Vector3(1.0, 0.5, 1.0))
	assert(BuildingBlockCatalogScript.mesh_shape_of(&"arch", &"1_4") == BuildingBlockCatalogScript.SHAPE_HALF_ARCH)
	assert(BuildingBlockCatalogScript.size_of(&"arch", &"1_4") == Vector3(0.5, 0.5, 1.0))
	assert(not BuildingBlockCatalogScript.has_block(&"half_arch"))
	assert(not BuildingBlockCatalogScript.has_variants(&"roof_pitch_low"))
	assert(not BuildingBlockCatalogScript.has_variants(&"roof_corner_in_low"))
	assert(not BuildingBlockCatalogScript.has_variants(&"roof_corner_out_low"))
	assert(BuildingBlockCatalogScript.size_of(&"roof_angle_large") == Vector3(1.0, 1.0, 1.0))
	assert(BuildingBlockCatalogScript.size_of(&"roof_angle_small") == Vector3(1.0, 0.5, 1.0))
	assert(BuildingBlockCatalogScript.mesh_shape_of(&"roof_angle_large") == BuildingBlockCatalogScript.SHAPE_ROOF_ANGLE)
	assert(BuildingBlockCatalogScript.get_block(&"roof_angle_large")["name"] == "Большой угол")
	assert(BuildingBlockCatalogScript.get_block(&"roof_angle_small")["name"] == "Малый угол")
	assert(BuildingBlockCatalogScript.get_block(&"roof_angle_large")["category"] == BuildingBlockCatalogScript.Category.ROOF)
	assert(BuildingBlockCatalogScript.get_block(&"column_square")["category"] == BuildingBlockCatalogScript.Category.STRUCTURE)
	# Single-cell blocks report a unit footprint.
	assert(BuildingBlockCatalogScript.footprint_of(&"arch") == Vector3i(1, 1, 1))
	assert(not BuildingBlockCatalogScript.is_multicell(&"arch"))
	assert(not BuildingBlockCatalogScript.is_multicell(&"cube"))
	_test_anchoring()


static func _test_anchoring() -> void:
	var C := BuildingBlockCatalogScript
	# 3D Subgrid anchor packing / unpacking
	var packed_slot1 := C.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.35, 0.25, -0.35))
	var offset1 := C.anchor_base_offset_3d(&"cube", &"0.25", packed_slot1)
	assert(_approx3(offset1, Vector3(-0.375, 0.25, -0.375)))

	var packed_slot2 := C.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.10, 0.50, 0.10))
	var offset2 := C.anchor_base_offset_3d(&"cube", &"0.25", packed_slot2)
	assert(_approx3(offset2, Vector3(-0.125, 0.50, 0.125)))

	# Stacking 4 quarter-cubes in one cell at different Y sub-levels
	var grid := BuildingGridModelScript.new()
	var cell := Vector3i(1, 0, 1)
	var anc0 := C.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.375, 0.00, -0.375))
	var anc1 := C.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.375, 0.25, -0.375))
	var anc2 := C.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.375, 0.50, -0.375))
	var anc3 := C.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.375, 0.75, -0.375))

	assert(grid.place(cell, &"cube", 0, &"stone", &"0.25", anc0))
	assert(grid.place(cell, &"cube", 0, &"stone", &"0.25", anc1))
	assert(grid.place(cell, &"cube", 0, &"stone", &"0.25", anc2))
	assert(grid.place(cell, &"cube", 0, &"stone", &"0.25", anc3))
	assert(grid.blocks_anchored_at(cell).size() == 4)

	# Legacy anchor compatibility (ANCHOR_CORNER / ANCHOR_EDGE)
	assert(C.cell_offset(&"column_square", &"0.5", C.ANCHOR_CENTER, 0) == Vector2(0.5, 0.5))
	assert(_approx(C.cell_offset(&"column_square", &"0.5", C.ANCHOR_CORNER, 0), Vector2(0.25, 0.25)))
	assert(_approx(C.cell_offset(&"column_square", &"0.5", C.ANCHOR_CORNER, 2), Vector2(0.75, 0.75)))


static func _approx3(a: Vector3, b: Vector3) -> bool:
	return is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y) and is_equal_approx(a.z, b.z)


static func _approx(a: Vector2, b: Vector2) -> bool:
	return is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y)


static func _test_style_resolver_fallback_chain() -> void:
	var index := ContentIndexScript.new()
	for data in [
		[&"premium", &"roman"], [&"premium", &"generic"],
		[&"default", &"roman"], [&"default", &"generic"],
	]:
		var entry := ContentEntryScript.new(&"core", StringName("bakery_%s_%s" % data), &"blueprint", "")
		entry.runtime_key = entry.id
		entry.kind = &"building"
		entry.role = &"bakery"
		entry.variant = data[0]
		entry.style = data[1]
		index.entries[entry.runtime_key] = entry
	var resolver := StyleResolverScript.new(index)
	assert(resolver.resolve(&"bakery", &"premium", &"roman").style == &"roman")
	index.entries.erase(&"bakery_premium_roman")
	assert(resolver.resolve(&"bakery", &"premium", &"roman").style == &"generic")
	index.entries.erase(&"bakery_premium_generic")
	assert(resolver.resolve(&"bakery", &"premium", &"roman").variant == &"default")
	index.entries.erase(&"bakery_default_roman")
	assert(resolver.resolve(&"bakery", &"premium", &"roman").style == &"generic")
	assert(resolver.resolve(&"missing", &"premium", &"roman") == null)
	assert(ContentIdScript.runtime_key(ContentIdScript.split_runtime_key(&"pack:ivan.roman/bakery")["source"], ContentIdScript.split_runtime_key(&"pack:ivan.roman/bakery")["id"]) == &"pack:ivan.roman/bakery")


static func _test_content_packs_and_exchange() -> void:
	var index := ContentIndexScript.new()
	index.rebuild()
	assert(index.get_entry(&"core:tent") != null, "core pack must namespace built-in blueprints")
	assert(index.get_entry(&"core:green_valley") != null, "core pack must namespace built-in maps")
	assert(index.content_packs().any(func(pack) -> bool: return pack.id == &"core"))

	var io := ContentPackIOScript.new()
	var archive := "user://content_pack_test.gdpack"
	assert(io.export_pack("res://game/content/core", archive), io.last_error)
	var installed_path := io.import_pack(archive)
	assert(not installed_path.is_empty(), io.last_error)
	assert(FileAccess.file_exists(installed_path.path_join("pack.json")))
	assert(FileAccess.file_exists(installed_path.path_join("buildings/tent.gdbuilding.json")))
	ContentPackIOScript._remove_directory(installed_path)
	DirAccess.remove_absolute(archive)


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
	var bottom := BlockMeshLibraryScript.local_offset(&"slab", &"0.5")
	assert(is_equal_approx(bottom.y, 0.25))
	var top_x := BlockMeshLibraryScript.local_offset(&"slab", &"0.5", 0, 0, 0.0, 2, 0)
	var top_z := BlockMeshLibraryScript.local_offset(&"slab", &"0.5", 0, 0, 0.0, 0, 2)
	assert(is_equal_approx(top_x.y, 0.75), "X tilt must move the detail into the slot's upper half")
	assert(is_equal_approx(top_z.y, 0.75), "Z tilt must move the detail into the slot's upper half")


static func _test_material_catalog_and_costs() -> void:
	assert(BuildingMaterialCatalogScript.all().size() == 13)
	assert(BuildingMaterialCatalogScript.resource_id(&"earth") == &"soil")
	assert(BuildingMaterialCatalogScript.resource_id(&"wood") == &"boards")
	var bp := BuildingBlueprintScript.new()
	bp.id = &"mixed_frame"
	var grid := BuildingGridModelScript.new()
	assert(grid.place(Vector3i.ZERO, &"cube", 0, &"earth"))
	assert(grid.place(Vector3i(1, 0, 0), &"slab", 1, &"stone", &"0.5"))
	# A parametric block records its chosen variant and in-cell anchor kind.
	assert(grid.place(Vector3i(2, 0, 0), &"column_round", 0, &"stone", &"0.5", BuildingBlockCatalogScript.ANCHOR_CORNER))
	assert(grid.get_block_at(Vector3i(2, 0, 0)).variant == &"0.5")
	assert(grid.get_block_at(Vector3i(2, 0, 0)).anchor == BuildingBlockCatalogScript.ANCHOR_CORNER)
	grid.write_to_blueprint(bp)
	bp.manual_costs = {"soil": 3, "stone": 5}
	bp.recalculate_construction_cost()
	assert(bp.construction_cost == {"soil": 3, "stone": 5})
	assert(bp.block_counts_by_material() == {&"earth": 1, &"stone": 2})
	var restored := BuildingBlueprintScript.from_json(bp.to_json())
	assert(restored != null)
	assert(restored.blocks[0].material_id == &"earth")
	assert(restored.blocks[1].material_id == &"stone")
	# Size + anchor survive the JSON round-trip; the default cube size is explicit.
	assert(restored.blocks[0].variant == &"1")
	assert(restored.blocks[0].anchor == BuildingBlockCatalogScript.ANCHOR_CENTER)
	var col := restored.blocks[2] if restored.blocks[2].block_id == &"column_round" else restored.blocks[1]
	assert(col.variant == &"0.5")
	assert(BuildingBlockCatalogScript.anchor_base_offset_3d(&"column_round", &"0.5", col.anchor) \
		.is_equal_approx(Vector3(-0.25, 0.0, -0.25)))

	# Readable three-dimensional offsets must survive serialization and replace
	# the implementation-specific packed integer in newly written JSON.
	var sub_bp := BuildingBlueprintScript.new()
	var sub_grid := BuildingGridModelScript.new()
	var sub_cell := Vector3i(1, 0, 1)
	for y in [0.0, 0.25, 0.5, 0.75]:
		var anchor := BuildingBlockCatalogScript.snap_subgrid_anchor_3d(&"cube", &"0.25", Vector3(-0.375, y, -0.375))
		assert(sub_grid.place(sub_cell, &"cube", 0, &"stone", &"0.25", anchor))
	sub_grid.write_to_blueprint(sub_bp)
	var sub_restored := BuildingBlueprintScript.from_json(sub_bp.to_json())
	assert(sub_bp.to_json().contains("\"offset\""))
	assert(not sub_bp.to_json().contains("\"anchor\""))
	assert(sub_restored != null and sub_restored.blocks.size() == 4, "all packed subgrid anchors survive JSON")
	var reloaded_grid := BuildingGridModelScript.new()
	reloaded_grid.load_from_blueprint(sub_restored)
	assert(reloaded_grid.blocks_anchored_at(sub_cell).size() == 4, "loading retains every subcube in the anchor cell")


static func _test_zone_function_round_trip() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"town_park"
	var leisure := ZoneAreaRecord.new()
	leisure.id = &"z_park"
	leisure.function = &"core:leisure"
	leisure.properties = {"flavour": "cinema", "visitors": 12}
	leisure.add_rect(Rect2i(0, 0, 2, 2))
	bp.areas.append(leisure)
	var restored := BuildingBlueprintScript.from_dict(bp.to_dict())
	assert(restored.areas.size() == 1)
	assert(restored.areas[0].function == &"core:leisure")
	assert(restored.areas[0].properties["flavour"] == "cinema")
	assert(restored.areas[0].properties["visitors"] == 12)
	# The pack really is the source of the vocabulary.
	assert(ZoneFunctionCatalog.has_function(&"core:leisure"))
	assert(ZoneFunctionCatalog.pack_of(&"core:leisure") == &"core")


static func _test_grid_place_erase() -> void:
	var grid := BuildingGridModelScript.new()
	assert(grid.is_empty())
	assert(grid.place(Vector3i(0, 0, 0), &"cube"))
	assert(grid.count() == 1)
	assert(grid.has_block_at(Vector3i(0, 0, 0)))
	# A full cube intersects a slab in the same cell and is not replaced.
	assert(not grid.place(Vector3i(0, 0, 0), &"slab", 0, &"branches", &"0.5"))
	assert(grid.count() == 1)
	assert(grid.get_block_at(Vector3i(0, 0, 0)).block_id == &"cube")
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
	assert(grid.is_empty())
	assert(grid.place(Vector3i(0, 0, 0), &"cube"))
	assert(grid.count() == 1)
	assert(grid.has_block_at(Vector3i(0, 0, 0)))


static func _test_grid_shared_cell() -> void:
	var grid := BuildingGridModelScript.new()
	# Full solids cannot occupy the same physical space.
	assert(grid.place(Vector3i.ZERO, &"cube", 0, &"branches", &"1"))
	assert(not grid.place(Vector3i.ZERO, &"column_square", 0, &"branches", &"0.25"))
	assert(grid.erase(Vector3i.ZERO))
	# Only columns of the same type may intersect to form a joint.
	assert(grid.place(Vector3i.ZERO, &"column_square", 0, &"branches", &"0.5"))
	assert(not grid.place(Vector3i.ZERO, &"column_half", 1, &"branches", &"0.5"))
	assert(grid.erase(Vector3i.ZERO))
	assert(grid.place(Vector3i.ZERO, &"column_half", 0, &"branches", &"0.5"))
	assert(grid.place(Vector3i.ZERO, &"column_half", 1, &"branches", &"0.5"))
	assert(grid.count() == 2)
	assert(grid.has_block_at(Vector3i.ZERO))
	# A composite brush copies the whole anchored assembly, not only the newest
	# sub-block returned by get_block_at().
	assert(grid.blocks_anchored_at(Vector3i.ZERO).size() == 2)
	var blueprint := BuildingBlueprintScript.new()
	blueprint.id = &"joined_columns"
	grid.write_to_blueprint(blueprint)
	var restored := BuildingBlueprintScript.from_json(blueprint.to_json())
	assert(restored != null and restored.block_count() == 2)


static func _test_grid_rotation_rules() -> void:
	var grid := BuildingGridModelScript.new()
	# Rotatable block keeps and wraps rotation (cubes and slabs are rotatable).
	grid.place(Vector3i(0, 0, 0), &"cube", 3)
	assert(grid.get_block_at(Vector3i(0, 0, 0)).rot == 3)
	grid.place(Vector3i(1, 0, 0), &"slab", 2, &"branches", &"0.5")
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
	bp.construction_style = &"surface"
	var grid := BuildingGridModelScript.new()
	grid.place(Vector3i(0, 0, 0), &"cube")
	grid.place(Vector3i(1, 0, 0), &"slab", 1, &"branches", &"0.5")
	grid.write_to_blueprint(bp)

	var json := bp.to_json()
	var restored := BuildingBlueprintScript.from_json(json)
	assert(restored.id == &"test_house")
	assert(restored.name == "Тестовый дом")
	assert(restored.block_count() == 2)

	var restored_grid := BuildingGridModelScript.new()
	restored_grid.load_from_blueprint(restored)
	assert(restored_grid.count() == 2)
	assert(restored_grid.get_block_at(Vector3i(1, 0, 0)).block_id == &"slab")
	assert(restored_grid.get_block_at(Vector3i(1, 0, 0)).rot == 1)


static func _test_zones_and_metadata_round_trip() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"trade_post"
	bp.footprint = Vector2i(4, 4)

	var room := ZoneAreaRecord.new()
	room.id = &"z_trade"
	room.area_name = "Торговый пост"
	room.function = &"core:trade"
	room.properties = {"profession": "seller", "max_workers": 2}
	room.add_rect(Rect2i(1, 1, 2, 1))
	bp.areas.append(room)

	var counter := ZoneAnchorRecord.new()
	counter.id = &"counter"
	counter.owner_id = &"z_trade"
	counter.role = ZoneAnchorRecord.ROLE_SLOT
	counter.activity = &"core:serve"
	counter.facing = 90.0
	counter.arc = 120.0
	counter.pos = Vector3(1.5, 0.0, 1.5)
	bp.anchors.append(counter)
	var line := ZoneAnchorRecord.new()
	line.id = &"q1"
	line.owner_id = &"z_trade"
	line.role = ZoneAnchorRecord.ROLE_QUEUE
	line.target_id = &"counter"
	line.pos = Vector3(1.5, 0.0, 0.5)
	bp.anchors.append(line)
	var tray := ZoneAnchorRecord.new()
	tray.id = &"out"
	tray.owner_id = &"z_trade"
	tray.role = ZoneAnchorRecord.ROLE_STORAGE
	tray.direction = ZoneAnchorRecord.DIRECTION_OUT
	tray.pos = Vector3(2.5, 0.0, 1.5)
	tray.capacity = 80
	bp.anchors.append(tray)
	# Two doors: one public, one staff-only. Entrance offsets are derived from
	# them — the format has no separate entrance fields any more.
	var front := ZoneAnchorRecord.new()
	front.id = &"front"
	front.owner_id = &"z_trade"
	front.role = ZoneAnchorRecord.ROLE_DOOR
	front.pos = Vector3(2.0, 0.0, 0.0)
	bp.anchors.append(front)
	var back := ZoneAnchorRecord.new()
	back.id = &"back"
	back.owner_id = &"z_trade"
	back.role = ZoneAnchorRecord.ROLE_DOOR
	back.deny = [ZoneAccess.AUDIENCE_VISITOR]
	back.pos = Vector3(2.0, 0.0, 4.0)
	bp.anchors.append(back)
	var route := ZoneRouteRecord.new()
	route.id = &"service_route"
	route.stops = [&"front", &"counter", &"back"]
	route.cycle = ZoneRouteRecord.CYCLE_PINGPONG
	route.wait_minutes = 2.5
	bp.routes.append(route)

	var restored := BuildingBlueprintScript.from_dict(bp.to_dict())
	assert(restored.footprint == Vector2i(4, 4))
	assert(restored.areas.size() == 1)
	assert(restored.anchors.size() == 5)
	assert(restored.routes.size() == 1)
	assert(restored.routes[0].stops == [&"front", &"counter", &"back"])
	assert(restored.routes[0].cycle == ZoneRouteRecord.CYCLE_PINGPONG)
	var room_back: ZoneAreaRecord = restored.areas[0]
	assert(room_back.id == &"z_trade")
	assert(room_back.function == &"core:trade")
	assert(room_back.properties["profession"] == "seller")
	assert(room_back.contains_cell(Vector2i(2, 1)))

	# Entrances derive from authored doors.
	assert(restored.entrance_offset() == Vector2i(0, -2))

	# Denormalization groups points under their owner; doors go to routing.
	var runtime_defs := restored.runtime_zone_definitions()
	assert(runtime_defs.size() == 1)
	var def: Dictionary = runtime_defs[0]
	assert(def["slots"].size() == 1)
	assert(def["slots"][0]["activity"] == "core:serve")
	assert(def["slots"][0]["arc"] == 120.0)
	assert(def["queue"].size() == 1)
	assert(def["storage"].size() == 1 and def["storage"][0]["capacity"] == 80)
	assert(restored.routing_anchor_definitions().size() == 2)

	# The runtime reads employment out of pack properties, not engine fields.
	var state := ZoneRuntimeState.from_definition(def)
	assert(state.supports_role(&"seller"))
	assert(state.max_workers() == 2)
	assert(state.capacity() == 1, "one authored slot means one occupant")
	assert(state.assign(7))
	assert(state.position_for(7) == Vector3(-0.5, 0.0, -0.5),
		"board coordinates must cross into pivot-local space once")


## Rooms partition a building; overlays may overlap anything (§7.3, §7.4).
static func _test_zone_invariants() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"overlap_house"
	bp.footprint = Vector2i(4, 4)
	var first := ZoneAreaRecord.new()
	first.id = &"room_a"
	first.add_rect(Rect2i(0, 0, 2, 2))
	bp.areas.append(first)
	var second := ZoneAreaRecord.new()
	second.id = &"room_b"
	second.add_rect(Rect2i(1, 1, 2, 2))
	bp.areas.append(second)
	var door := ZoneAnchorRecord.new()
	door.id = &"d"
	door.role = ZoneAnchorRecord.ROLE_DOOR
	door.pos = Vector3(0.5, 0.0, 0.0)
	bp.anchors.append(door)
	var errors := bp.validation_errors()
	assert(_has_error(errors, "пересекаются"), str(errors))

	second.rects.clear()
	second.add_rect(Rect2i(2, 2, 2, 2))
	assert(not _has_error(bp.validation_errors(), "пересекаются"))

	# An overlay on top of a room is fine, and a slot behind a staff denial is not.
	var overlay := ZoneAreaRecord.new()
	overlay.id = &"private"
	overlay.role = ZoneAreaRecord.ROLE_OVERLAY
	overlay.deny = [ZoneAccess.AUDIENCE_STAFF]
	overlay.effects = {ZoneEffects.KEY_COST: 2.0, ZoneEffects.KEY_CONCEAL: 0.6}
	overlay.add_rect(Rect2i(0, 0, 2, 2))
	bp.areas.append(overlay)
	assert(not _has_error(bp.validation_errors(), "пересекаются"))
	var overlay_back := ZoneAreaRecord.from_dict(overlay.to_dict())
	assert(overlay_back.is_overlay())
	assert(overlay_back.effects[ZoneEffects.KEY_COST] == 2.0)
	var slot := ZoneAnchorRecord.new()
	slot.id = &"s"
	slot.owner_id = &"room_a"
	slot.role = ZoneAnchorRecord.ROLE_SLOT
	slot.pos = Vector3(0.5, 0.0, 0.5)
	bp.anchors.append(slot)
	assert(_has_error(bp.validation_errors(), "персоналу вход запрещён"), str(bp.validation_errors()))

	# Areas and points share one namespace.
	var duplicate := ZoneAnchorRecord.new()
	duplicate.id = first.id
	duplicate.role = ZoneAnchorRecord.ROLE_POI
	bp.anchors.append(duplicate)
	assert(_has_error(bp.validation_errors(), "занят дважды"), str(bp.validation_errors()))
	bp.anchors.erase(duplicate)

	# A room nobody can enter is an error; a building-wide door covers every room.
	bp.anchors.erase(slot)
	assert(not _has_error(bp.validation_errors(), "нет двери"))
	door.owner_id = &"room_a"
	assert(_has_error(bp.validation_errors(), "room_b нет двери"), str(bp.validation_errors()))


static func _has_error(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


static func _test_grid_blueprint_sync() -> void:
	var bp := BuildingBlueprintScript.new()
	var grid := BuildingGridModelScript.new()
	grid.place(Vector3i(0, 0, 0), &"cube")
	grid.place(Vector3i(0, 1, 0), &"cube")
	grid.write_to_blueprint(bp)
	# grid_bounds is authored board capacity and is not shrunk to occupied extent.
	assert(bp.grid_bounds == Vector3i(8, 4, 8))
	# Blocks are written in a deterministic (y, x, z) order.
	assert(bp.blocks[0].pos == Vector3i(0, 0, 0))
	assert(bp.blocks[1].pos == Vector3i(0, 1, 0))


static func _test_runtime_zone_assignment() -> void:
	var building := Node3D.new()
	var zone_service := BuildingZoneServiceScript.new()
	zone_service.configure_building(building, [{
		"id": "cook_1",
		"name": "Kitchen",
		"role": "room",
		"function": "core:kitchen",
		"properties": {"profession": "cook", "max_workers": 2},
		"slots": [{"id": "oven", "role": "slot", "pos": [1.0, 0.0, 2.0]}],
		"fallback_pos": [0.5, 0.0, 0.5],
	}])
	assert(zone_service.supports_role(building, &"cook"))
	assert(zone_service.role_capacity(building, &"cook") == 1)
	assert(zone_service.work_position(building, &"cook", 10) == Vector3(1.0, 0.0, 2.0))
	var state := BuildingRuntimeState.from_node(building)
	assert(state.zones[0].slot_holder(&"oven") == 10, "work position reserves the slot")
	assert(not state.zones[0].assign(11), "a second citizen cannot share one slot")
	building.free()


## Authored doors are authoritative for every building.
static func _test_authored_building_access_points() -> void:
	var authored := {
		"type": "sawmill",
		"footprint": Vector2i(8, 6),
		"blueprint_ref": {"source": "core", "id": "authored_sawmill"},
		"routing_anchors": [
			{"id": "front_door", "role": "door", "pos": [0.0, 0.0, -3.0]},
			{"id": "staff_door", "role": "door", "pos": [4.0, 0.0, 0.0], "deny": ["visitor"]},
			{"id": "visitor_only", "role": "door", "pos": [-4.0, 0.0, 0.0], "deny": ["staff", "builder"]},
		]
	}
	assert(BuildingAccessPoints.authored_door_count(authored) == 3)
	assert(BuildingAccessPoints.visitor_local_positions(authored) == [
		Vector3(0.0, 0.0, -3.0), Vector3(-4.0, 0.0, 0.0)])
	assert(BuildingAccessPoints.worker_local_positions(authored) == [
		Vector3(0.0, 0.0, -3.0), Vector3(4.0, 0.0, 0.0)])
	assert(BuildingAccessPoints.construction_local_positions(authored) == [
		Vector3(0.0, 0.0, -3.0), Vector3(4.0, 0.0, 0.0)])
	assert(BuildingAccessPoints.access_errors(authored).is_empty())

	var building := Node3D.new()
	building.position = Vector3(10.0, 2.0, 20.0)
	building.rotation.y = PI * 0.5
	assert(BuildingAccessPoints.visitor_positions(building, authored)[0].is_equal_approx(
		Vector3(7.0, 2.0, 20.0)))
	building.free()

	var missing_door := authored.duplicate(true)
	missing_door["routing_anchors"] = []
	assert(BuildingAccessPoints.worker_local_positions(missing_door).is_empty(),
		"authored content without a door must not fall back to the hard-coded sawmill entrances")
	assert(BuildingAccessPoints.access_errors(missing_door).size() == 1)


## Pack-defined meaning must survive definition -> runtime state -> meta ->
## definition, or the game loses what the zone actually is.
static func _test_runtime_zone_function_survives() -> void:
	var building := Node3D.new()
	var zone_service := BuildingZoneServiceScript.new()
	zone_service.configure_building(building, [{
		"id": "cinema_1",
		"name": "Cinema",
		"role": "room",
		"function": "core:leisure",
		"properties": {"flavour": "cinema", "visitors": 20},
		"fallback_pos": [0.5, 0.0, 0.5],
	}])
	var snapshot: Array = BuildingRuntimeState.from_node(building).zones_to_dict()
	assert(snapshot.size() == 1)
	assert(snapshot[0].get("function", "") == "core:leisure", "function must survive")
	assert(snapshot[0]["properties"]["flavour"] == "cinema", "pack properties must survive")
	building.free()


static func _test_zone_session_state_round_trip() -> void:
	var building := Node3D.new()
	var zone_service := BuildingZoneServiceScript.new()
	var definitions := [{
		"id": "house",
		"role": "room",
		"function": "core:civic",
		"properties": {"profession": "official", "max_workers": 1},
		"slots": [{"id": "desk", "role": "slot", "pos": [0.0, 0.0, 0.0]}],
		"fallback_pos": [0.0, 0.0, 0.0],
	}]
	zone_service.configure_building(building, definitions)
	assert(zone_service.assign_to_zone(building, &"house", &"official", 17))
	assert(zone_service.work_position(building, &"official", 17) == Vector3.ZERO)
	assert(zone_service.set_zone_owner(building, &"house", &"faction:red"))
	assert(zone_service.set_zone_flag(building, &"house", &"cleared", true))
	var saved := zone_service.zone_state_snapshot(building)
	assert(saved[0].has("owner") and not saved[0].has("function"),
		"save stores session state, not authored definition")
	zone_service.configure_building(building, definitions, saved)
	assert(zone_service.zone_owner(building, &"house") == &"faction:red")
	assert(zone_service.zone_flag(building, &"house", &"cleared") == true)
	assert(BuildingRuntimeState.from_node(building).zones[0].slot_holder(&"desk") == 17)
	var private_overlay := ZoneAreaRecord.new()
	private_overlay.id = &"private"
	private_overlay.role = ZoneAreaRecord.ROLE_OVERLAY
	private_overlay.deny = [ZoneAccess.AUDIENCE_OWNER]
	private_overlay.effects = {ZoneEffects.KEY_COST: 2.0, ZoneEffects.KEY_VISION: 0.4}
	private_overlay.add_rect(Rect2i(0, 0, 1, 1))
	building.set_meta("zone_overlays", [private_overlay.to_dict()])
	var runtime := BuildingRuntimeState.from_node(building)
	assert(not runtime.permits(Vector2i.ZERO, [&"faction:red"], &"faction:red"),
		"owner audience resolves against the current owner tag")
	assert(runtime.permits(Vector2i.ZERO, [&"faction:blue"], &"faction:red"))
	assert(runtime.effects_at(Vector2i.ZERO)[ZoneEffects.KEY_COST] == 2.0)
	building.free()


## A room with no authored slots still gives citizens somewhere to stand (§5.2).
static func _test_runtime_zone_falls_back_to_centre() -> void:
	var building := Node3D.new()
	var zone_service := BuildingZoneServiceScript.new()
	zone_service.configure_building(building, [{
		"id": "hall",
		"role": "room",
		"function": "core:civic",
		"properties": {"profession": "official", "max_workers": 1},
		"fallback_pos": [2.5, 0.0, 3.5],
	}])
	assert(zone_service.assign_to_zone(building, &"hall", &"official", 4))
	assert(zone_service.work_position(building, &"official", 4) == Vector3(2.5, 0.0, 3.5))
	building.free()


static func _test_invalid_blueprints_are_rejected() -> void:
	# to_dict() always writes FORMAT_VERSION, so test unsupported version via a raw dict.
	var unsupported_dict := {"version": 999, "id": "unsupported", "name": "Unsupported", "footprint": [4, 4], "blocks": []}
	assert(BuildingBlueprintScript.from_dict(unsupported_dict) == null, "Version 999 must be rejected")
	var invalid_material := BuildingBlueprintScript.new()
	invalid_material.id = &"invalid_material"
	invalid_material.blocks.append(BlueprintBlockScript.new(Vector3i.ZERO, &"cube", 0, &"unobtainium"))
	assert(BuildingBlueprintScript.from_json(invalid_material.to_json()) == null)

	var outside := BuildingBlueprintScript.new()
	outside.id = &"outside"
	outside.grid_bounds = Vector3i(2, 2, 2)
	outside.footprint = Vector2i(2, 2)
	outside.blocks.append(BlueprintBlockScript.new(Vector3i(-1, 0, 0), &"cube"))
	assert(_has_error(outside.validation_errors(), "outside grid_bounds"))
	outside.blocks[0].pos = Vector3i(0, 2, 0)
	assert(_has_error(outside.validation_errors(), "outside grid_bounds"))

	var mixed_columns := BuildingBlueprintScript.new()
	mixed_columns.id = &"mixed_columns"
	mixed_columns.blocks = [
		BlueprintBlockScript.new(Vector3i.ZERO, &"column_square", 0, &"branches", &"0.5"),
		BlueprintBlockScript.new(Vector3i.ZERO, &"column_half", 1, &"branches", &"0.5"),
	]
	assert(_has_error(mixed_columns.validation_errors(), "Overlapping block volumes"))
