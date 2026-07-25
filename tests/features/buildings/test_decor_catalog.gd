extends SceneTree

const FurnishingAssetCatalogScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_catalog.gd")
const FurnishingAssetDefScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_def.gd")
const DecorObjectRecordScript = preload("res://game/features/buildings/domain/editor/decor_object_record.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")


func _init() -> void:
	print("--- Running test_decor_catalog.gd ---")
	_test_catalog_assets()
	_test_catalog_taxonomy()
	_test_asset_scenes_exist()
	_test_bindings_resolve_in_scenes()
	_test_blueprint_decor_objects()
	_test_colors_survive_json_round_trip()
	_test_validation_rejects_broken_objects()
	_test_v1_to_v2_migration()
	_test_v2_round_trip()
	_test_non_empty_fixtures_rejected()
	_test_owner_zone_validation()
	_test_catalog_filtering()
	print("--- test_decor_catalog.gd PASSED ---")
	quit(0)


func _test_catalog_assets() -> void:
	var assets := FurnishingAssetCatalogScript.get_all_assets()
	assert(assets.size() >= 4, "Catalog should contain at least 4 assets")

	var campfire := FurnishingAssetCatalogScript.get_asset(&"campfire")
	assert(campfire != null, "Campfire asset should exist")
	assert(campfire.name == "Костёр", "Campfire name check")
	assert(campfire.category == &"fires_stoves", "Campfire category check")
	assert(campfire.appearance_controls.size() >= 2, "Campfire should have controllable appearance controls")

	assert(FurnishingAssetCatalogScript.get_asset(&"cooking_campfire") != null, "Cooking campfire asset should exist")
	assert(FurnishingAssetCatalogScript.get_asset(&"entrance_sign") != null, "Entrance sign asset should exist")

	var flag := FurnishingAssetCatalogScript.get_asset(&"flag")
	assert(flag != null, "Flag asset should exist")
	assert(flag.category == &"town", "Flag belongs to the town category")
	assert(flag.get_control("banner_color").has("bind"), "Flag banner colour must be bound to a node")
	# New metadata fields
	assert(flag.tags.has(&"town"), "Flag must have town tag")
	assert(flag.available_from_era == &"tent", "Flag must be available from tent era")
	assert(flag.placement_surface == FurnishingAssetDefScript.SURFACE_FLOOR, "Flag must be floor-placed")
	assert(flag.scale_mode == FurnishingAssetDefScript.SCALE_UNIFORM_STEPS, "Flag must use uniform_steps scale mode")
	assert(flag.collision_policy == FurnishingAssetDefScript.COLLISION_BOX, "Flag must use box collision")
	assert(flag.blocking_navigation == true, "Flag must block navigation")
	# Campfire capabilities stub
	assert(campfire.supported_capabilities.has(&"fire_source"), "Campfire must support fire_source capability")


func _test_catalog_taxonomy() -> void:
	var counts := FurnishingAssetCatalogScript.category_counts()
	assert(counts.size() == FurnishingAssetCatalogScript.CATEGORIES.size(), "Every category must be counted")
	assert(int(counts[&"fires_stoves"]) >= 2, "Fires & stoves holds the two campfires")
	assert(int(counts[&"town"]) >= 2, "Town holds the sign and the flag")
	# Equipment categories exist but are empty in phase 1.
	assert(int(counts[&"workbenches"]) == 0, "Workbenches is still empty")
	assert(int(counts[&"industrial"]) == 0, "Industrial is still empty")

	# The editor opens on a populated category so it never shows a blank list.
	assert(int(counts[FurnishingAssetCatalogScript.first_populated_category(&"workbenches")]) > 0,
		"first_populated_category must skip empty categories")

	for category_id in FurnishingAssetCatalogScript.categories_in_group(&"outdoor"):
		assert(FurnishingAssetCatalogScript.group_of_category(category_id) == &"outdoor",
			"categories_in_group must only return that group's categories")

	# Equipment group has the expected categories.
	var equip_cats := FurnishingAssetCatalogScript.categories_in_group(&"equipment")
	assert(equip_cats.size() == 7, "Equipment group must have 7 categories")
	assert(equip_cats.has(&"industrial"), "Equipment must include industrial")
	assert(equip_cats.has(&"workbenches"), "Equipment must include workbenches")
	assert(equip_cats.has(&"kitchen_equipment"), "Equipment must include kitchen_equipment")
	assert(equip_cats.has(&"storage_logistics"), "Equipment must include storage_logistics")
	assert(equip_cats.has(&"trade_service"), "Equipment must include trade_service")
	assert(equip_cats.has(&"utility_sanitary"), "Equipment must include utility_sanitary")
	assert(equip_cats.has(&"tools"), "Equipment must include tools")


func _test_asset_scenes_exist() -> void:
	for asset in FurnishingAssetCatalogScript.get_all_assets():
		assert(ResourceLoader.exists(asset.scene_path), "Missing decor scene: %s" % asset.scene_path)
		assert(load(asset.scene_path) is PackedScene, "Decor scene failed to load: %s" % asset.scene_path)


## Every declared binding must point at a node that actually exists, otherwise
## the control silently does nothing in the editor.
func _test_bindings_resolve_in_scenes() -> void:
	for asset in FurnishingAssetCatalogScript.get_all_assets():
		var instance := (load(asset.scene_path) as PackedScene).instantiate()
		assert(instance.get("asset_id") == asset.id,
			"Scene %s must declare asset_id %s" % [asset.scene_path, asset.id])
		var bindings := asset.bindings()
		for property_name in bindings.keys():
			for bind in bindings[property_name]:
				var node_path := String(bind["node"])
				assert(instance.get_node_or_null(NodePath(node_path)) != null,
					"Asset %s binds '%s' to missing node '%s'" % [asset.id, property_name, node_path])
		instance.free()


func _test_blueprint_decor_objects() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_decor_house"
	var record := DecorObjectRecordScript.make(&"campfire", Vector3(1.5, 0.0, 1.5), 1)
	record.rot = Vector3(0.0, 90.0, 0.0)
	record.scale = Vector3(1.5, 1.5, 1.5)
	record.appearance = {"is_lit": true, "light_energy": 2.0}
	bp.objects.append(record)

	var dict := bp.to_dict()
	assert(dict.has("objects"), "Dictionary should contain objects array")
	var objects: Array = dict["objects"]
	assert(objects.size() == 1, "Objects array size should be 1")
	assert(objects[0]["id"] == record.id, "Object ID check")
	assert(objects[0]["appearance"]["light_energy"] == 2.0, "Object appearance check")

	var loaded_bp := BuildingBlueprintScript.from_dict(dict)
	assert(loaded_bp.objects.size() == 1, "Loaded blueprint objects size check")
	var loaded: DecorObjectRecordScript = loaded_bp.objects[0]
	assert(loaded.asset_id == &"campfire", "Loaded blueprint object asset check")
	assert(loaded.rot.y == 90.0, "Rotation must survive the round trip")
	# `scale` used to be written and then ignored on load.
	assert(loaded.scale.is_equal_approx(Vector3(1.5, 1.5, 1.5)), "Scale must survive the round trip")


## Control defaults hand out `Color`, which `JSON.stringify` cannot encode —
## storing them raw broke both saving and `content_revision()`.
func _test_colors_survive_json_round_trip() -> void:
	var campfire := FurnishingAssetCatalogScript.get_asset(&"campfire")
	var defaults := campfire.default_appearance()
	assert(defaults["light_color"] is String, "Colour defaults must be stored as html strings")

	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_decor_colors"
	var record := DecorObjectRecordScript.make(&"campfire", Vector3.ZERO, 1)
	record.appearance = defaults
	bp.objects.append(record)

	assert(not bp.content_revision().is_empty(), "content_revision must not choke on decor appearance")

	var reloaded := BuildingBlueprintScript.from_json(bp.to_json())
	assert(reloaded != null, "Blueprint with decor must round-trip through JSON")
	assert(reloaded.objects.size() == 1, "Decor object must survive a JSON round trip")
	assert(reloaded.objects[0].appearance["light_color"] == defaults["light_color"], "Colour value must be preserved")


func _test_validation_rejects_broken_objects() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_decor_validation"
	bp.objects.append(DecorObjectRecordScript.make(&"campfire", Vector3.ZERO, 7))
	bp.objects.append(DecorObjectRecordScript.make(&"campfire", Vector3.ONE, 7))
	var errors := bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("Duplicate decor object id")),
		"Duplicate decor ids must be reported")

	var unknown_bp := BuildingBlueprintScript.new()
	unknown_bp.id = &"test_decor_unknown_asset"
	unknown_bp.objects.append(DecorObjectRecordScript.make(&"not_installed_asset", Vector3.ZERO, 1))
	# A file may reference a custom asset that is not installed here; it must
	# still load rather than being rejected outright.
	assert(unknown_bp.validation_errors().is_empty(), "An unknown asset id must not fail validation")


## A v1 blueprint dict (with `properties` and `anchor`) must load into v2 records
## without losing data or shifting positions.
func _test_v1_to_v2_migration() -> void:
	var v1_dict := {
		"version": 1,
		"id": "test_v1_migration",
		"name": "V1 Migration Test",
		"construction_style": "surface",
		"category": "tent",
		"grid_bounds": {"x": 4, "y": 4, "z": 4},
		"footprint": [4, 4],
		"entrance": [0, 0],
		"blocks": [],
		"objects": [{
			"id": "decor_campfire_1",
			"asset_id": "campfire",
			"pos": [2.5, 0.0, 3.5],
			"rot": [0, 45, 0],
			"scale": [1, 1, 1],
			"anchor": [1, 0],
			"properties": {"is_lit": true, "light_color": "ffaa44"},
		}],
	}
	var bp := BuildingBlueprintScript.from_dict(v1_dict)
	assert(bp != null, "v1 blueprint must load")
	assert(bp.version == BuildingBlueprintScript.FORMAT_VERSION, "Loaded bp must be upgraded to v2")
	assert(bp.objects.size() == 1, "v1 migration must preserve objects")
	var obj: DecorObjectRecordScript = bp.objects[0]
	assert(obj.pos.is_equal_approx(Vector3(2.5, 0.0, 3.5)), "v1 pos must not shift")
	assert(obj.appearance["is_lit"] == true, "v1 properties must migrate to appearance")
	assert(obj.appearance["light_color"] == "ffaa44", "v1 colour must migrate to appearance")
	assert(obj.owner_zone_id == &"", "v1 migration must add empty owner_zone")
	# Saving as v2 and reloading must preserve all data.
	var v2_json := bp.to_json()
	var reloaded := BuildingBlueprintScript.from_json(v2_json)
	assert(reloaded != null, "v2 reloaded blueprint must be valid")
	assert(reloaded.objects.size() == 1, "v2 round-trip must preserve objects")
	assert(reloaded.objects[0].appearance["is_lit"] == true, "v2 appearance must survive round-trip")
	assert(reloaded.objects[0].pos.is_equal_approx(Vector3(2.5, 0.0, 3.5)), "v2 pos must survive round-trip")
	print("  v1→v2 migration ok")


## A v2 blueprint must survive a full JSON round-trip without any data loss.
func _test_v2_round_trip() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_v2_roundtrip"
	var record := DecorObjectRecordScript.make(&"campfire", Vector3(1.0, 0.0, 2.0), 1)
	record.rot = Vector3(0.0, 180.0, 0.0)
	record.scale = Vector3(2.0, 2.0, 2.0)
	record.owner_zone_id = &""
	record.appearance = {"is_lit": false, "light_color": "aabbcc"}
	bp.objects.append(record)
	var json := bp.to_json()
	assert(json.contains("\"version\": 2"), "v2 json must contain version 2")
	assert(json.contains("\"appearance\""), "v2 json must use appearance key")
	assert(not json.contains("\"properties\""), "v2 json must not contain old properties key")
	assert(not json.contains("\"anchor\""), "v2 json must not contain old anchor key in objects")
	var reloaded := BuildingBlueprintScript.from_json(json)
	assert(reloaded != null, "v2 round-trip must produce a valid blueprint")
	assert(reloaded.objects[0].appearance["light_color"] == "aabbcc", "v2 appearance must survive JSON round-trip")
	assert(reloaded.objects[0].scale.is_equal_approx(Vector3(2.0, 2.0, 2.0)), "v2 scale must survive JSON round-trip")
	print("  v2 round-trip ok")


## Non-empty fixtures array must be rejected by the validator in phase 1.
func _test_non_empty_fixtures_rejected() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_fixtures_rejected"
	bp.fixtures = [{"id": "fire_source_1"}]
	var errors := bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("fixtures") and e.contains("phase 2")),
		"Non-empty fixtures must be rejected with a phase 2 message")
	# Empty fixtures must pass.
	bp.fixtures = []
	errors = bp.validation_errors()
	assert(not errors.any(func(e: String): return e.contains("fixtures")),
		"Empty fixtures must not produce a validation error")
	print("  fixtures validation ok")


## A decor object referencing a non-existent zone must be flagged by the validator.
func _test_owner_zone_validation() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_owner_zone_validation"
	var record := DecorObjectRecordScript.make(&"campfire", Vector3.ZERO, 1)
	record.owner_zone_id = &"nonexistent_zone"
	bp.objects.append(record)
	var errors := bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("unknown place zone") and e.contains("nonexistent_zone")),
		"Decor object with unknown owner_zone must be flagged")
	# Clearing the zone must remove the error.
	record.owner_zone_id = &""
	errors = bp.validation_errors()
	assert(not errors.any(func(e: String): return e.contains("unknown place zone")),
		"Decor object with empty owner_zone must not flag a zone error")
	print("  owner_zone validation ok")


## Catalog must support filtering by tag, era, surface and combined criteria.
func _test_catalog_filtering() -> void:
	# Filter by tag: "fire" should return campfire and cooking_campfire.
	var fire_assets := FurnishingAssetCatalogScript.get_assets_by_tag(&"fire")
	assert(fire_assets.size() >= 2, "Tag 'fire' must return at least 2 assets")
	for asset in fire_assets:
		assert(asset.tags.has(&"fire"), "Filtered assets must have the fire tag")

	# Filter by era: "tent" should return all current assets.
	var tent_assets := FurnishingAssetCatalogScript.get_assets_by_era(&"tent")
	assert(tent_assets.size() >= 4, "Era 'tent' must return at least 4 assets")

	# Filter by era with no matches: assets with a different era.
	var stone_assets := FurnishingAssetCatalogScript.get_assets_by_era(&"stone")
	# All current assets have available_from_era == "tent", so they don't match "stone".
	# But assets with empty era pass through (available for all eras).
	# Our built-in assets all have era "tent", so stone should return 0.
	assert(stone_assets.size() == 0, "Era 'stone' must return 0 assets (all are tent-era)")

	# Filter by surface: "floor" should return all current assets.
	var floor_assets := FurnishingAssetCatalogScript.get_assets_by_surface(FurnishingAssetDefScript.SURFACE_FLOOR)
	assert(floor_assets.size() >= 4, "Surface 'floor' must return at least 4 assets")

	# Filter by surface: "wall" should return 0 (none are wall-only).
	var wall_assets := FurnishingAssetCatalogScript.get_assets_by_surface(FurnishingAssetDefScript.SURFACE_WALL)
	assert(wall_assets.size() == 0, "Surface 'wall' must return 0 assets")

	# Combined filter: category + tag.
	var combined := FurnishingAssetCatalogScript.filter_assets(
		&"fires_stoves", &"fire", &"tent", FurnishingAssetDefScript.SURFACE_FLOOR)
	assert(combined.size() >= 2, "Combined filter must return at least 2 assets")
	for asset in combined:
		assert(asset.category == &"fires_stoves", "Combined filter must respect category")
		assert(asset.tags.has(&"fire"), "Combined filter must respect tag")

	# Combined filter with mismatched tag returns empty.
	var mismatched := FurnishingAssetCatalogScript.filter_assets(
		&"town", &"fire", &"", "")
	assert(mismatched.size() == 0, "Mismatched tag filter must return 0 assets")

	# Empty filters return all assets.
	var all := FurnishingAssetCatalogScript.filter_assets()
	assert(all.size() >= 4, "Empty filter must return all assets")

	# Scale policy validation.
	var campfire := FurnishingAssetCatalogScript.get_asset(&"campfire")
	assert(campfire.scale_mode == FurnishingAssetDefScript.SCALE_LOCKED, "Campfire must have locked scale")
	assert(not campfire.is_scale_allowed(2.0), "Locked scale must reject 2.0")
	assert(campfire.is_scale_allowed(1.0), "Locked scale must allow 1.0")

	var flag := FurnishingAssetCatalogScript.get_asset(&"flag")
	assert(flag.scale_mode == FurnishingAssetDefScript.SCALE_UNIFORM_STEPS, "Flag must have uniform_steps scale")
	assert(flag.is_scale_allowed(1.0), "Flag must allow scale 1.0")
	assert(flag.is_scale_allowed(0.5), "Flag must allow scale 0.5")
	assert(not flag.is_scale_allowed(1.5), "Flag must reject scale 1.5 (not in allowed_scales)")

	# Placement surface validation.
	assert(campfire.can_place_on(FurnishingAssetDefScript.SURFACE_FLOOR), "Campfire can place on floor")
	assert(not campfire.can_place_on(FurnishingAssetDefScript.SURFACE_WALL), "Campfire cannot place on wall")
	assert(campfire.can_place_on(FurnishingAssetDefScript.SURFACE_ANY), "Campfire can place on any (surface is floor, any matches)")

	# Rotation axis validation.
	assert(campfire.is_rotation_axis_allowed("y"), "Campfire must allow Y rotation")
	assert(not campfire.is_rotation_axis_allowed("x"), "Campfire must reject X rotation")

	print("  catalog filtering ok")
