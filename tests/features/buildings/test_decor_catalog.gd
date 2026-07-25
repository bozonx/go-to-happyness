extends SceneTree

const DecorAssetCatalogScript = preload("res://game/features/buildings/domain/editor/decor_asset_catalog.gd")
const DecorAssetDefScript = preload("res://game/features/buildings/domain/editor/decor_asset_def.gd")
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
	print("--- test_decor_catalog.gd PASSED ---")
	quit(0)


func _test_catalog_assets() -> void:
	var assets := DecorAssetCatalogScript.get_all_assets()
	assert(assets.size() >= 4, "Catalog should contain at least 4 assets")

	var campfire := DecorAssetCatalogScript.get_asset(&"campfire")
	assert(campfire != null, "Campfire asset should exist")
	assert(campfire.name == "Костёр", "Campfire name check")
	assert(campfire.category == &"camping", "Campfire category check")
	assert(campfire.controls.size() >= 2, "Campfire should have controllable properties")

	assert(DecorAssetCatalogScript.get_asset(&"cooking_campfire") != null, "Cooking campfire asset should exist")
	assert(DecorAssetCatalogScript.get_asset(&"entrance_sign") != null, "Entrance sign asset should exist")

	var flag := DecorAssetCatalogScript.get_asset(&"flag")
	assert(flag != null, "Flag asset should exist")
	assert(flag.category == &"town", "Flag belongs to the town category")
	assert(flag.get_control("banner_color").has("bind"), "Flag banner colour must be bound to a node")


func _test_catalog_taxonomy() -> void:
	var counts := DecorAssetCatalogScript.category_counts()
	assert(counts.size() == DecorAssetCatalogScript.CATEGORIES.size(), "Every category must be counted")
	assert(int(counts[&"camping"]) >= 2, "Camping holds the two campfires")
	assert(int(counts[&"town"]) >= 2, "Town holds the sign and the flag")
	assert(int(counts[&"furniture"]) == 0, "Furniture is still empty and must report zero")

	# The editor opens on a populated category so it never shows a blank list.
	assert(int(counts[DecorAssetCatalogScript.first_populated_category(&"furniture")]) > 0,
		"first_populated_category must skip empty categories")

	for category_id in DecorAssetCatalogScript.categories_in_group(&"outdoor"):
		assert(DecorAssetCatalogScript.group_of_category(category_id) == &"outdoor",
			"categories_in_group must only return that group's categories")


func _test_asset_scenes_exist() -> void:
	for asset in DecorAssetCatalogScript.get_all_assets():
		assert(ResourceLoader.exists(asset.scene_path), "Missing decor scene: %s" % asset.scene_path)
		assert(load(asset.scene_path) is PackedScene, "Decor scene failed to load: %s" % asset.scene_path)


## Every declared binding must point at a node that actually exists, otherwise
## the control silently does nothing in the editor.
func _test_bindings_resolve_in_scenes() -> void:
	for asset in DecorAssetCatalogScript.get_all_assets():
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
	record.properties = {"is_lit": true, "light_energy": 2.0}
	bp.objects.append(record)

	var dict := bp.to_dict()
	assert(dict.has("objects"), "Dictionary should contain objects array")
	var objects: Array = dict["objects"]
	assert(objects.size() == 1, "Objects array size should be 1")
	assert(objects[0]["id"] == record.id, "Object ID check")
	assert(objects[0]["properties"]["light_energy"] == 2.0, "Object property check")

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
	var campfire := DecorAssetCatalogScript.get_asset(&"campfire")
	var defaults := campfire.default_properties()
	assert(defaults["light_color"] is String, "Colour defaults must be stored as html strings")

	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_decor_colors"
	var record := DecorObjectRecordScript.make(&"campfire", Vector3.ZERO, 1)
	record.properties = defaults
	bp.objects.append(record)

	assert(not bp.content_revision().is_empty(), "content_revision must not choke on decor properties")

	var reloaded := BuildingBlueprintScript.from_json(bp.to_json())
	assert(reloaded != null, "Blueprint with decor must round-trip through JSON")
	assert(reloaded.objects.size() == 1, "Decor object must survive a JSON round trip")
	assert(reloaded.objects[0].properties["light_color"] == defaults["light_color"], "Colour value must be preserved")


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
