extends SceneTree

## End-to-end content test for a player-authored modular building:
## repository -> player resolver -> runtime key -> legacy-compatible view model.

const BlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const ZoneScript = preload("res://game/features/buildings/domain/editor/active_work_zone_record.gd")
const RepositoryScript = preload("res://game/features/buildings/presentation/editor/blueprint_repository.gd")
const LibraryScript = preload("res://game/features/buildings/presentation/building_blueprint_library.gd")
const BuildingBlueprintsScript = preload("res://game/features/buildings/presentation/building_blueprints.gd")
const BuildingCatalogScript = preload("res://game/features/buildings/domain/building_catalog.gd")

const TEST_ID := &"_test_modular_pipeline"


func _init() -> void:
	var blueprint := BlueprintScript.new()
	blueprint.id = TEST_ID
	blueprint.name = "Test modular workshop"
	blueprint.category = "earth"
	blueprint.fallback_building_id = &"earth_house"
	blueprint.footprint = Vector2i(2, 1)
	blueprint.grid_bounds = Vector3i(2, 1, 1)
	blueprint.blocks = [
		BlueprintBlockScript.new(Vector3i(0, 0, 0), &"cube", 0, &"earth"),
		BlueprintBlockScript.new(Vector3i(1, 0, 0), &"wall_panel", 1, &"branches"),
	]
	var zone := ZoneScript.new()
	zone.zone_id = &"craft_1"
	zone.zone_name = "Craft bench"
	zone.profession = &"craftsman"
	zone.max_workers = 1
	zone.cells = [Vector3i.ZERO]
	zone.add_anchor(Vector3(0.5, 0.0, 0.5))
	blueprint.work_zones.append(zone)

	var repository := RepositoryScript.new(false)
	var save_result: Dictionary = repository.save(blueprint)
	assert(bool(save_result.get("ok", false)), str(save_result.get("error", "")))
	# Re-saving verifies atomic replacement of an existing file.
	assert(bool(repository.save(blueprint).get("ok", false)))

	LibraryScript.refresh()
	var runtime_key := LibraryScript.runtime_key(LibraryScript.SOURCE_PLAYER, TEST_ID)
	assert(runtime_key == "user:_test_modular_pipeline")
	assert(LibraryScript.has(runtime_key))
	var loaded = LibraryScript.get_blueprint(runtime_key)
	assert(loaded != null)
	assert(loaded.construction_cost == {"soil": 1, "branches": 1})
	assert(BuildingCatalogScript.definition_for(runtime_key).get("category") == "earth")

	var game_blueprint: Dictionary = BuildingBlueprintsScript.get_blueprint(runtime_key)
	assert(game_blueprint.get("modules", []).size() == 2)
	assert(game_blueprint.get("work_zones", []).size() == 1)
	assert(game_blueprint.get("blueprint_ref", {}).get("source") == "player")
	assert(game_blueprint.get("blueprint_ref", {}).get("fallback_building_id") == "earth_house")

	var remove_error := DirAccess.remove_absolute(repository.file_path_for(TEST_ID))
	assert(remove_error == OK)
	LibraryScript.refresh()
	assert(not LibraryScript.has(runtime_key))
	quit(0)
