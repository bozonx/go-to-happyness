extends SceneTree

const FillObjectRecordScript = preload("res://game/features/buildings/domain/editor/fill_object_record.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")


func _init() -> void:
	print("--- Running test_fill_catalog.gd ---")
	_test_catalog_assets()
	_test_catalog_taxonomy()
	_test_asset_scenes_exist()
	_test_bindings_resolve_in_scenes()
	_test_blueprint_fill_objects()
	_test_colors_survive_json_round_trip()
	_test_validation_rejects_broken_objects()
	_test_current_round_trip()
	_test_non_empty_fixtures_rejected()
	_test_owner_zone_validation()
	_test_catalog_filtering()
	_test_builtin_blueprints_are_current()
	_test_asset_validation_with_known_asset()
	print("--- test_fill_catalog.gd PASSED ---")
	quit(0)


func _test_catalog_assets() -> void:
	var assets := WorldAssetCatalog.get_all_assets()
	assert(assets.size() >= 4, "Catalog should contain at least 4 assets")

	var campfire := WorldAssetCatalog.get_asset(&"campfire")
	assert(campfire != null, "Campfire asset should exist")
	assert(campfire.name == "Костёр", "Campfire name check")
	assert(campfire.category == &"fires_stoves", "Campfire category check")
	assert(campfire.appearance_controls.size() >= 2, "Campfire should have controllable appearance controls")

	assert(WorldAssetCatalog.get_asset(&"cooking_campfire") != null, "Cooking campfire asset should exist")
	assert(WorldAssetCatalog.get_asset(&"entrance_sign") != null, "Entrance sign asset should exist")

	var flag := WorldAssetCatalog.get_asset(&"flag")
	assert(flag != null, "Flag asset should exist")
	assert(flag.category == &"town", "Flag belongs to the town category")
	assert(flag.get_control("banner_color").has("bind"), "Flag banner colour must be bound to a node")
	# New metadata fields
	assert(flag.tags.has(&"town"), "Flag must have town tag")
	assert(flag.scale_mode == WorldAssetDef.SCALE_UNIFORM_STEPS, "Flag must use uniform_steps scale mode")
	assert(flag.collision_policy == WorldAssetDef.COLLISION_SCENE, "Flag collision must be owned by its scene")
	assert(flag.blocking_navigation == true, "Flag must block navigation")
	# Campfire capabilities stub
	assert(campfire.supported_capabilities.has(&"fire_source"), "Campfire must support fire_source capability")


func _test_catalog_taxonomy() -> void:
	var counts := WorldAssetCatalog.category_counts()
	assert(counts.size() == WorldAssetCatalog.CATEGORIES.size(), "Every category must be counted")
	assert(int(counts[&"fires_stoves"]) >= 2, "Fires & stoves holds the two campfires")
	assert(int(counts[&"town"]) >= 2, "Town holds the sign and the flag")
	# Equipment categories exist but are empty in phase 1.
	assert(int(counts[&"workbenches"]) == 0, "Workbenches is still empty")
	assert(int(counts[&"industrial"]) == 0, "Industrial is still empty")

	# The editor opens on a populated category so it never shows a blank list.
	assert(int(counts[WorldAssetCatalog.first_populated_category(&"workbenches")]) > 0,
		"first_populated_category must skip empty categories")

	for category_id in WorldAssetCatalog.categories_in_group(&"outdoor"):
		assert(WorldAssetCatalog.group_of_category(category_id) == &"outdoor",
			"categories_in_group must only return that group's categories")

	# Equipment group has the expected categories.
	var equip_cats := WorldAssetCatalog.categories_in_group(&"equipment")
	assert(equip_cats.size() == 7, "Equipment group must have 7 categories")
	assert(equip_cats.has(&"industrial"), "Equipment must include industrial")
	assert(equip_cats.has(&"workbenches"), "Equipment must include workbenches")
	assert(equip_cats.has(&"kitchen_equipment"), "Equipment must include kitchen_equipment")
	assert(equip_cats.has(&"storage_logistics"), "Equipment must include storage_logistics")
	assert(equip_cats.has(&"trade_service"), "Equipment must include trade_service")
	assert(equip_cats.has(&"utility_sanitary"), "Equipment must include utility_sanitary")
	assert(equip_cats.has(&"tools"), "Equipment must include tools")

	var tags := WorldAssetCatalog.all_tags()
	assert(tags.has(&"fire"), "Catalog tag index must include fire")
	assert(tags.has(&"town"), "Catalog tag index must include town")
	for index in range(1, tags.size()):
		assert(String(tags[index - 1]).naturalnocasecmp_to(String(tags[index])) <= 0,
			"Catalog tags must have a stable display order")


func _test_asset_scenes_exist() -> void:
	for asset in WorldAssetCatalog.get_all_assets():
		assert(ResourceLoader.exists(asset.scene_path), "Missing fill scene: %s" % asset.scene_path)
		assert(load(asset.scene_path) is PackedScene, "Fill scene failed to load: %s" % asset.scene_path)
		if asset.collision_policy == WorldAssetDef.COLLISION_SCENE:
			var instance := (load(asset.scene_path) as PackedScene).instantiate()
			var shapes := instance.find_children("*", "CollisionShape3D", true, false)
			assert(shapes.any(func(node: Node) -> bool:
				return node is CollisionShape3D and (node as CollisionShape3D).shape != null),
				"Scene-collision asset %s must contain an authored shape" % asset.id)
			instance.free()


## Every declared binding must point at a node that actually exists, otherwise
## the control silently does nothing in the editor.
##
## Natural assets are covered here too, now that trees, bushes and rocks carry
## `appearance_controls` of their own: a renamed node inside `tree.tscn` has to
## fail here rather than in a forest that quietly stopped varying. Assets with no
## bindings at all (fireflies, whose shape comes from entity props) are skipped —
## `_test_asset_scenes_exist` already asserts their scene loads.
func _test_bindings_resolve_in_scenes() -> void:
	for asset in WorldAssetCatalog.get_all_assets():
		var bindings := asset.bindings()
		if bindings.is_empty():
			continue
		var instance := (load(asset.scene_path) as PackedScene).instantiate()
		assert(instance.get("asset_id") == asset.id,
			"Scene %s must declare asset_id %s" % [asset.scene_path, asset.id])
		for property_name in bindings.keys():
			for bind in bindings[property_name]:
				var node_path := String(bind["node"])
				assert(instance.get_node_or_null(NodePath(node_path)) != null,
					"Asset %s binds '%s' to missing node '%s'" % [asset.id, property_name, node_path])
		instance.free()


func _test_blueprint_fill_objects() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_fill_house"
	var record := FillObjectRecordScript.make(&"campfire", Vector3(1.5, 0.0, 1.5), 1)
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
	var loaded: FillObjectRecordScript = loaded_bp.objects[0]
	assert(loaded.asset_id == &"campfire", "Loaded blueprint object asset check")
	assert(loaded.rot.y == 90.0, "Rotation must survive the round trip")
	# `scale` used to be written and then ignored on load.
	assert(loaded.scale.is_equal_approx(Vector3(1.5, 1.5, 1.5)), "Scale must survive the round trip")


## Control defaults hand out `Color`, which `JSON.stringify` cannot encode —
## storing them raw broke both saving and `content_revision()`.
func _test_colors_survive_json_round_trip() -> void:
	var campfire := WorldAssetCatalog.get_asset(&"campfire")
	var defaults := campfire.default_appearance()
	assert(defaults["light_color"] is String, "Colour defaults must be stored as html strings")

	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_fill_colors"
	var record := FillObjectRecordScript.make(&"campfire", Vector3.ZERO, 1)
	record.appearance = defaults
	bp.objects.append(record)

	assert(not bp.content_revision().is_empty(), "content_revision must not choke on fill appearance")

	var reloaded := BuildingBlueprintScript.from_json(bp.to_json())
	assert(reloaded != null, "Blueprint with fill must round-trip through JSON")
	assert(reloaded.objects.size() == 1, "Fill object must survive a JSON round trip")
	assert(reloaded.objects[0].appearance["light_color"] == defaults["light_color"], "Colour value must be preserved")


func _test_validation_rejects_broken_objects() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_fill_validation"
	bp.objects.append(FillObjectRecordScript.make(&"campfire", Vector3.ZERO, 7))
	bp.objects.append(FillObjectRecordScript.make(&"campfire", Vector3.ONE, 7))
	var errors := bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("Duplicate fill object id")),
		"Duplicate fill ids must be reported")

	var unknown_bp := BuildingBlueprintScript.new()
	unknown_bp.id = &"test_fill_unknown_asset"
	unknown_bp.objects.append(FillObjectRecordScript.make(&"not_installed_asset", Vector3.ZERO, 1))
	# A file may reference a custom asset that is not installed here; it must
	# still load rather than being rejected outright.
	assert(unknown_bp.validation_errors().is_empty(), "An unknown asset id must not fail validation")


## A current blueprint must survive a full JSON round-trip without data loss.
func _test_current_round_trip() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_current_roundtrip"
	var record := FillObjectRecordScript.make(&"campfire", Vector3(1.0, 0.0, 2.0), 1)
	record.rot = Vector3(0.0, 180.0, 0.0)
	record.scale = Vector3(1.0, 1.0, 1.0)
	record.owner_zone_id = &""
	record.appearance = {"visual_flame_visible": false, "light_color": "aabbcc"}
	bp.objects.append(record)
	var json := bp.to_json()
	assert(json.contains("\"version\": %d" % BuildingBlueprintScript.FORMAT_VERSION), "JSON must contain the current format version")
	assert(json.contains("\"appearance\""), "current json must use appearance key")
	assert(not json.contains("\"properties\""), "current json must not contain old properties key")
	assert(not json.contains("\"anchor\""), "current json must not contain old anchor key in objects")
	var reloaded := BuildingBlueprintScript.from_json(json)
	assert(reloaded != null, "current round-trip must produce a valid blueprint")
	assert(reloaded.objects[0].appearance["light_color"] == "aabbcc", "current appearance must survive JSON round-trip")
	assert(reloaded.objects[0].scale.is_equal_approx(Vector3(1.0, 1.0, 1.0)), "current scale must survive JSON round-trip")
	print("  current round-trip ok")


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


## A fill object referencing a non-existent zone must be flagged by the validator.
func _test_owner_zone_validation() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_owner_zone_validation"
	var record := FillObjectRecordScript.make(&"campfire", Vector3.ZERO, 1)
	record.owner_zone_id = &"nonexistent_zone"
	bp.objects.append(record)
	var errors := bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("unknown place zone") and e.contains("nonexistent_zone")),
		"Fill object with unknown owner_zone must be flagged")
	# Clearing the zone must remove the error.
	record.owner_zone_id = &""
	errors = bp.validation_errors()
	assert(not errors.any(func(e: String): return e.contains("unknown place zone")),
		"Fill object with empty owner_zone must not flag a zone error")
	print("  owner_zone validation ok")


## Catalog supports reusable tag/category filtering; progression belongs to games.
func _test_catalog_filtering() -> void:
	# Filter by tag: "fire" should return campfire and cooking_campfire.
	var fire_assets := WorldAssetCatalog.get_assets_by_tag(&"fire")
	assert(fire_assets.size() >= 2, "Tag 'fire' must return at least 2 assets")
	for asset in fire_assets:
		assert(asset.tags.has(&"fire"), "Filtered assets must have the fire tag")

	# Combined filter: category + tag.
	var combined := WorldAssetCatalog.filter_assets(&"fires_stoves", &"fire")
	assert(combined.size() >= 2, "Combined filter must return at least 2 assets")
	for asset in combined:
		assert(asset.category == &"fires_stoves", "Combined filter must respect category")
		assert(asset.tags.has(&"fire"), "Combined filter must respect tag")

	# Combined filter with mismatched tag returns empty.
	var mismatched := WorldAssetCatalog.filter_assets(&"town", &"fire")
	assert(mismatched.size() == 0, "Mismatched tag filter must return 0 assets")

	# Empty filters return all assets.
	var all := WorldAssetCatalog.filter_assets()
	assert(all.size() >= 4, "Empty filter must return all assets")

	# Scale policy validation.
	var campfire := WorldAssetCatalog.get_asset(&"campfire")
	assert(campfire.scale_mode == WorldAssetDef.SCALE_LOCKED, "Campfire must have locked scale")
	assert(not campfire.is_scale_allowed(2.0), "Locked scale must reject 2.0")
	assert(campfire.is_scale_allowed(1.0), "Locked scale must allow 1.0")

	var flag := WorldAssetCatalog.get_asset(&"flag")
	assert(flag.scale_mode == WorldAssetDef.SCALE_UNIFORM_STEPS, "Flag must have uniform_steps scale")
	assert(flag.is_scale_allowed(1.0), "Flag must allow scale 1.0")
	assert(flag.is_scale_allowed(0.5), "Flag must allow scale 0.5")
	assert(not flag.is_scale_allowed(1.5), "Flag must reject scale 1.5 (not in allowed_scales)")

	# Rotation axis validation.
	assert(campfire.is_rotation_axis_allowed("y"), "Campfire must allow Y rotation")
	assert(campfire.is_rotation_axis_allowed("x"), "Campfire must allow X rotation")
	assert(campfire.is_rotation_axis_allowed("z"), "Campfire must allow Z rotation")

	print("  catalog filtering ok")


## Every built-in .gdbuilding.json must use the current format.
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
			assert(data.has("fixtures"), "Current blueprint %s must have 'fixtures' key" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	assert(found_count >= 6, "Expected at least 6 built-in blueprints, found %d" % found_count)
	print("  builtin blueprints format ok (%d files)" % found_count)


## A fill object with a known asset must be validated against the asset's
## scale, rotation and collision policy constraints.
func _test_asset_validation_with_known_asset() -> void:
	var campfire := WorldAssetCatalog.get_asset(&"campfire")
	assert(campfire != null, "Campfire asset must exist")

	# Locked scale: scale 2.0 must be rejected.
	var bad_scale := FillObjectRecordScript.make(&"campfire", Vector3.ZERO, 1)
	bad_scale.scale = Vector3(2.0, 2.0, 2.0)
	var errors := bad_scale.validation_errors_with_asset(campfire)
	assert(errors.any(func(e: String): return e.contains("scale") and e.contains("not allowed")),
		"Scale 2.0 on locked campfire must be rejected")

	# Non-uniform scale must be rejected.
	var bad_nonuniform := FillObjectRecordScript.make(&"campfire", Vector3.ZERO, 2)
	bad_nonuniform.scale = Vector3(1.0, 2.0, 1.0)
	errors = bad_nonuniform.validation_errors_with_asset(campfire)
	assert(errors.any(func(e: String): return e.contains("non-uniform scale")),
		"Non-uniform scale must be rejected")

	# All axes are authorable for furnishing unless an asset explicitly restricts one.
	var bad_rot := FillObjectRecordScript.make(&"campfire", Vector3.ZERO, 3)
	bad_rot.rot = Vector3(45.0, 0.0, 0.0)
	errors = bad_rot.validation_errors_with_asset(campfire)
	assert(errors.is_empty(), "X-axis rotation must be allowed by the default furnishing policy")

	# Valid object: scale 1.0, arbitrary rotation.
	var good := FillObjectRecordScript.make(&"campfire", Vector3.ZERO, 4)
	good.scale = Vector3.ONE
	good.rot = Vector3(0.0, 90.0, 0.0)
	errors = good.validation_errors_with_asset(campfire)
	assert(errors.is_empty(), "Valid campfire object must have no errors, got: " + str(errors))

	# Unknown asset: must not produce asset-specific errors.
	var unknown := FillObjectRecordScript.make(&"not_installed", Vector3.ZERO, 5)
	errors = unknown.validation_errors_with_asset(null)
	assert(errors.is_empty(), "Unknown asset must not produce asset-specific errors")
	print("  asset validation ok")
