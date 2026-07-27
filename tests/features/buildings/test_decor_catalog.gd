extends SceneTree

const FurnishingAssetCatalogScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_catalog.gd")
const FurnishingAssetDefScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_def.gd")
const DecorObjectRecordScript = preload("res://game/features/buildings/domain/editor/decor_object_record.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")


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
	_test_builtin_blueprints_are_current()
	_test_asset_validation_with_known_asset()
	_test_is_lit_migration_to_visual_flame_visible()
	_test_era_cumulative_progression()
	_test_category_migration()
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

	var tags := FurnishingAssetCatalogScript.all_tags()
	assert(tags.has(&"fire"), "Catalog tag index must include fire")
	assert(tags.has(&"town"), "Catalog tag index must include town")
	for index in range(1, tags.size()):
		assert(String(tags[index - 1]).naturalnocasecmp_to(String(tags[index])) <= 0,
			"Catalog tags must have a stable display order")


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
	record.appearance = {"visual_flame_visible": true, "light_energy": 2.0}
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
			"properties": {"visual_flame_visible": true, "light_color": "ffaa44"},
		}],
	}
	var bp := BuildingBlueprintScript.from_dict(v1_dict)
	assert(bp != null, "v1 blueprint must load")
	assert(bp.version == BuildingBlueprintScript.FORMAT_VERSION, "Loaded blueprint must be upgraded to the current format")
	assert(bp.objects.size() == 1, "v1 migration must preserve objects")
	var obj: DecorObjectRecordScript = bp.objects[0]
	assert(obj.pos.is_equal_approx(Vector3(4.5, 0.0, 5.5)), "v1 local pos must be converted to the blueprint pivot space")
	assert(obj.appearance["visual_flame_visible"] == true, "v1 properties must migrate to appearance")
	assert(obj.appearance["light_color"] == "ffaa44", "v1 colour must migrate to appearance")
	assert(obj.owner_zone_id == &"", "v1 migration must add empty owner_zone")
	# Saving as v2 and reloading must preserve all data.
	var v2_json := bp.to_json()
	var reloaded := BuildingBlueprintScript.from_json(v2_json)
	assert(reloaded != null, "v2 reloaded blueprint must be valid")
	assert(reloaded.objects.size() == 1, "v2 round-trip must preserve objects")
	assert(reloaded.objects[0].appearance["visual_flame_visible"] == true, "v2 appearance must survive round-trip")
	assert(reloaded.objects[0].pos.is_equal_approx(Vector3(4.5, 0.0, 5.5)), "migrated position must survive round-trip")
	print("  v1→v2 migration ok")


## A v2 blueprint must survive a full JSON round-trip without any data loss.
func _test_v2_round_trip() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_v2_roundtrip"
	var record := DecorObjectRecordScript.make(&"campfire", Vector3(1.0, 0.0, 2.0), 1)
	record.rot = Vector3(0.0, 180.0, 0.0)
	record.scale = Vector3(1.0, 1.0, 1.0)
	record.owner_zone_id = &""
	record.appearance = {"visual_flame_visible": false, "light_color": "aabbcc"}
	bp.objects.append(record)
	var json := bp.to_json()
	assert(json.contains("\"version\": %d" % BuildingBlueprintScript.FORMAT_VERSION), "JSON must contain the current format version")
	assert(json.contains("\"appearance\""), "v2 json must use appearance key")
	assert(not json.contains("\"properties\""), "v2 json must not contain old properties key")
	assert(not json.contains("\"anchor\""), "v2 json must not contain old anchor key in objects")
	var reloaded := BuildingBlueprintScript.from_json(json)
	assert(reloaded != null, "v2 round-trip must produce a valid blueprint")
	assert(reloaded.objects[0].appearance["light_color"] == "aabbcc", "v2 appearance must survive JSON round-trip")
	assert(reloaded.objects[0].scale.is_equal_approx(Vector3(1.0, 1.0, 1.0)), "v2 scale must survive JSON round-trip")
	print("  v2 round-trip ok")


## Fixtures are now validated per FixtureDefinition schema (phase 2A).
func _test_non_empty_fixtures_rejected() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_fixtures_validation"
	# A fixture with missing capabilities must fail.
	var bad_fixture := FixtureDefinitionScript.new()
	bad_fixture.id = &"bad_fixture_1"
	bad_fixture.capabilities = []
	bp.fixtures.append(bad_fixture)
	var errors := bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("no capabilities")),
		"Fixture without capabilities must be rejected")
	# A fire_source fixture with bad runtime_defaults must fail.
	var bad_fire := FixtureDefinitionScript.new()
	bad_fire.id = &"bad_fire_1"
	bad_fire.capabilities = [&"fire_source"]
	bad_fire.runtime_defaults = {"unknown_key": 42}
	bp.fixtures.clear()
	bp.fixtures.append(bad_fire)
	errors = bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("unknown key")),
		"Fixture with unknown runtime_defaults key must be rejected")
	# Empty fixtures must pass.
	bp.fixtures = []
	errors = bp.validation_errors()
	assert(not errors.any(func(e: String): return e.contains("fixture")),
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


## Catalog must support filtering by tag, era and combined criteria.
func _test_catalog_filtering() -> void:
	# Filter by tag: "fire" should return campfire and cooking_campfire.
	var fire_assets := FurnishingAssetCatalogScript.get_assets_by_tag(&"fire")
	assert(fire_assets.size() >= 2, "Tag 'fire' must return at least 2 assets")
	for asset in fire_assets:
		assert(asset.tags.has(&"fire"), "Filtered assets must have the fire tag")

	# Filter by era: "tent" should return all current assets.
	var tent_assets := FurnishingAssetCatalogScript.get_assets_by_era(&"tent")
	assert(tent_assets.size() >= 4, "Era 'tent' must return at least 4 assets")

	# Filter by era with cumulative progression: tent-era assets are available
	# in later eras (wood, stone) because rank(tent) <= rank(stone).
	var stone_assets := FurnishingAssetCatalogScript.get_assets_by_era(&"stone")
	assert(stone_assets.size() >= 4, "Era 'stone' must return tent-era assets (cumulative progression)")

	# Combined filter: category + tag.
	var combined := FurnishingAssetCatalogScript.filter_assets(
		&"fires_stoves", &"fire", &"tent")
	assert(combined.size() >= 2, "Combined filter must return at least 2 assets")
	for asset in combined:
		assert(asset.category == &"fires_stoves", "Combined filter must respect category")
		assert(asset.tags.has(&"fire"), "Combined filter must respect tag")

	# Combined filter with mismatched tag returns empty.
	var mismatched := FurnishingAssetCatalogScript.filter_assets(
		&"town", &"fire", &"")
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

	# Rotation axis validation.
	assert(campfire.is_rotation_axis_allowed("y"), "Campfire must allow Y rotation")
	assert(campfire.is_rotation_axis_allowed("x"), "Campfire must allow X rotation")
	assert(campfire.is_rotation_axis_allowed("z"), "Campfire must allow Z rotation")

	print("  catalog filtering ok")


## Every built-in .gdbuilding.json must be v2 — no v1 data should remain in
## the repository after the format migration.
func _test_builtin_blueprints_are_current() -> void:
	var dir_path := "res://game/content/core/buildings"
	var dir := DirAccess.open(dir_path)
	assert(dir != null, "Blueprints directory must exist")
	var found_count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".gdbuilding.json"):
			found_count += 1
			var full_path := dir_path.path_join(file_name)
			var text := FileAccess.get_file_as_string(full_path)
			assert(not text.is_empty(), "Blueprint file %s must be readable" % file_name)
			var json := JSON.new()
			assert(json.parse(text) == OK, "Blueprint %s must be valid JSON" % file_name)
			var data: Dictionary = json.data
			assert(int(data.get("version", 0)) == BuildingBlueprintScript.FORMAT_VERSION,
				"Built-in blueprint %s must be current v%d, got version %d" % [
					file_name, BuildingBlueprintScript.FORMAT_VERSION, int(data.get("version", 0))])
			# Entrances are `door` anchors now; the standalone fields are gone.
			assert(not data.has("entrance") and not data.has("worker_entrances"),
				"Built-in blueprint %s must not carry legacy entrance fields" % file_name)
			assert(not data.has("place_zones") and not data.has("zone_anchors"),
				"Built-in blueprint %s must not carry legacy zone arrays" % file_name)
			# Objects must use appearance, not properties.
			var objects: Array = data.get("objects", [])
			for obj in objects:
				assert(not obj.has("properties"),
					"Blueprint %s object %s must not have legacy 'properties' key" % [file_name, obj.get("id", "")])
				assert(not obj.has("anchor"),
					"Blueprint %s object %s must not have legacy 'anchor' key" % [file_name, obj.get("id", "")])
				assert(obj.has("appearance"),
					"Blueprint %s object %s must have 'appearance' key" % [file_name, obj.get("id", "")])
			assert(data.has("fixtures"), "v2 blueprint %s must have 'fixtures' key" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	assert(found_count >= 6, "Expected at least 6 built-in blueprints, found %d" % found_count)
	print("  builtin blueprints format ok (%d files)" % found_count)


## A decor object with a known asset must be validated against the asset's
## scale, rotation and collision policy constraints.
func _test_asset_validation_with_known_asset() -> void:
	var campfire := FurnishingAssetCatalogScript.get_asset(&"campfire")
	assert(campfire != null, "Campfire asset must exist")

	# Locked scale: scale 2.0 must be rejected.
	var bad_scale := DecorObjectRecordScript.make(&"campfire", Vector3.ZERO, 1)
	bad_scale.scale = Vector3(2.0, 2.0, 2.0)
	var errors := bad_scale.validation_errors_with_asset(campfire)
	assert(errors.any(func(e: String): return e.contains("scale") and e.contains("not allowed")),
		"Scale 2.0 on locked campfire must be rejected")

	# Non-uniform scale must be rejected.
	var bad_nonuniform := DecorObjectRecordScript.make(&"campfire", Vector3.ZERO, 2)
	bad_nonuniform.scale = Vector3(1.0, 2.0, 1.0)
	errors = bad_nonuniform.validation_errors_with_asset(campfire)
	assert(errors.any(func(e: String): return e.contains("non-uniform scale")),
		"Non-uniform scale must be rejected")

	# All axes are authorable for furnishing unless an asset explicitly restricts one.
	var bad_rot := DecorObjectRecordScript.make(&"campfire", Vector3.ZERO, 3)
	bad_rot.rot = Vector3(45.0, 0.0, 0.0)
	errors = bad_rot.validation_errors_with_asset(campfire)
	assert(errors.is_empty(), "X-axis rotation must be allowed by the default furnishing policy")

	# Valid object: scale 1.0, arbitrary rotation.
	var good := DecorObjectRecordScript.make(&"campfire", Vector3.ZERO, 4)
	good.scale = Vector3.ONE
	good.rot = Vector3(0.0, 90.0, 0.0)
	errors = good.validation_errors_with_asset(campfire)
	assert(errors.is_empty(), "Valid campfire object must have no errors, got: " + str(errors))

	# Unknown asset: must not produce asset-specific errors.
	var unknown := DecorObjectRecordScript.make(&"not_installed", Vector3.ZERO, 5)
	errors = unknown.validation_errors_with_asset(null)
	assert(errors.is_empty(), "Unknown asset must not produce asset-specific errors")
	print("  asset validation ok")


## Legacy is_lit appearance key must migrate to visual_flame_visible on load.
func _test_is_lit_migration_to_visual_flame_visible() -> void:
	var data := {
		"id": "decor_test_lit_migration",
		"asset_id": "campfire",
		"owner_zone": "",
		"pos": [0.0, 0.0, 0.0],
		"rot": [0.0, 0.0, 0.0],
		"scale": [1.0, 1.0, 1.0],
		"appearance": {"is_lit": false, "light_color": "ffaa44"},
	}
	var record := DecorObjectRecordScript.from_dict(data)
	assert(not record.appearance.has("is_lit"), "is_lit must be migrated away")
	assert(record.appearance.has("visual_flame_visible"), "visual_flame_visible must be present")
	assert(record.appearance["visual_flame_visible"] == false, "is_lit value must be preserved")
	assert(record.appearance["light_color"] == "ffaa44", "other appearance keys must be preserved")
	print("  is_lit migration ok")


## Era filter must use cumulative progression: a tent-era asset must appear in
## wood and stone era filters, not only in tent.
func _test_era_cumulative_progression() -> void:
	var tent_assets := FurnishingAssetCatalogScript.get_assets_by_era(&"tent")
	var wood_assets := FurnishingAssetCatalogScript.get_assets_by_era(&"wood")
	var stone_assets := FurnishingAssetCatalogScript.get_assets_by_era(&"stone")
	assert(tent_assets.size() >= 4, "Tent era must have at least 4 assets")
	assert(wood_assets.size() >= tent_assets.size(),
		"Wood era must include all tent-era assets (cumulative), got %d vs %d" % [wood_assets.size(), tent_assets.size()])
	assert(stone_assets.size() >= tent_assets.size(),
		"Stone era must include all tent-era assets (cumulative), got %d vs %d" % [stone_assets.size(), tent_assets.size()])
	# filter_assets must also use cumulative progression.
	var stone_filtered := FurnishingAssetCatalogScript.filter_assets(&"", &"", &"stone")
	assert(stone_filtered.size() >= tent_assets.size(),
		"filter_assets with stone era must include tent-era assets")
	print("  era cumulative progression ok")


## Legacy category names must be migrated by migrate_category.
func _test_category_migration() -> void:
	assert(FurnishingAssetCatalogScript.migrate_category(&"furniture") == &"tables_seating",
		"Legacy 'furniture' must migrate to 'tables_seating'")
	assert(FurnishingAssetCatalogScript.migrate_category(&"lighting") == &"lighting",
		"'lighting' maps to itself")
	assert(FurnishingAssetCatalogScript.migrate_category(&"camping") == &"camping",
		"Unknown legacy category returns itself")
	print("  category migration ok")
