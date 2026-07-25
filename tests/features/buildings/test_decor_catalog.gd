extends SceneTree

const DecorAssetCatalogScript = preload("res://game/features/buildings/domain/editor/decor_asset_catalog.gd")
const DecorAssetDefScript = preload("res://game/features/buildings/domain/editor/decor_asset_def.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")


func _init() -> void:
	print("--- Running test_decor_catalog.gd ---")
	_test_catalog_assets()
	_test_blueprint_decor_objects()
	print("--- test_decor_catalog.gd PASSED ---")
	quit(0)


func _test_catalog_assets() -> void:
	var assets := DecorAssetCatalogScript.get_all_assets()
	assert(assets.size() >= 3, "Catalog should contain at least 3 initial assets")

	var campfire := DecorAssetCatalogScript.get_asset(&"campfire")
	assert(campfire != null, "Campfire asset should exist")
	assert(campfire.name == "Костёр", "Campfire name check")
	assert(campfire.category == &"camping", "Campfire category check")
	assert(campfire.controls.size() >= 2, "Campfire should have controllable properties")

	var cooking := DecorAssetCatalogScript.get_asset(&"cooking_campfire")
	assert(cooking != null, "Cooking campfire asset should exist")

	var sign_asset := DecorAssetCatalogScript.get_asset(&"entrance_sign")
	assert(sign_asset != null, "Entrance sign asset should exist")


func _test_blueprint_decor_objects() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_decor_house"
	bp.objects.append({
		"id": "decor_1",
		"asset_id": "campfire",
		"pos": [1.5, 0.0, 1.5],
		"rot": [0, 90, 0],
		"scale": [1, 1, 1],
		"anchor": [0, 0],
		"properties": {
			"is_lit": true,
			"light_energy": 2.0
		}
	})

	var dict := bp.to_dict()
	assert(dict.has("objects"), "Dictionary should contain objects array")
	var objects: Array = dict["objects"]
	assert(objects.size() == 1, "Objects array size should be 1")
	assert(objects[0]["id"] == "decor_1", "Object ID check")
	assert(objects[0]["properties"]["light_energy"] == 2.0, "Object property check")

	var loaded_bp := BuildingBlueprintScript.from_dict(dict)
	assert(loaded_bp.objects.size() == 1, "Loaded blueprint objects size check")
	assert(loaded_bp.objects[0]["asset_id"] == "campfire", "Loaded blueprint object asset check")
