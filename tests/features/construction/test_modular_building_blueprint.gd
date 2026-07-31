extends SceneTree

## End-to-end content test for a player-authored modular building.

const BlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BlueprintBlockScript = preload("res://game/features/buildings/domain/editor/blueprint_block.gd")
const RepositoryScript = preload("res://game/features/buildings/presentation/editor/blueprint_repository.gd")
const LibraryScript = preload("res://game/features/buildings/presentation/building_blueprint_library.gd")
const BuildingBlueprintsScript = preload("res://game/features/buildings/presentation/building_blueprints.gd")
const BuildingCatalogScript = preload("res://game/features/buildings/domain/building_catalog.gd")
const FillObjectRecordScript = preload("res://game/features/buildings/domain/editor/fill_object_record.gd")

const TEST_ID := &"_test_modular_pipeline"
const TEST_PROJECT_ROOT := "user://content/projects/test_author.test_buildings"
const TEST_SOURCE := &"pack:test_author.test_buildings"


func _init() -> void:
	_setup_project()
	var blueprint := BlueprintScript.new()
	blueprint.id = TEST_ID
	blueprint.name = "Test modular workshop"
	blueprint.footprint = Vector2i(2, 1)
	blueprint.grid_bounds = Vector3i(2, 1, 1)
	blueprint.blocks = [
		BlueprintBlockScript.new(Vector3i(0, 0, 0), &"cube", 0, &"earth"),
		BlueprintBlockScript.new(Vector3i(1, 0, 0), &"slab", 1, &"branches", &"0.5"),
	]
	var room := ZoneAreaRecord.new()
	room.id = &"craft_1"
	room.area_name = "Craft bench"
	room.function = &"core:workshop"
	room.properties = {"profession": "craftsman", "max_workers": 1}
	room.add_rect(Rect2i(0, 0, 1, 1))
	blueprint.areas.append(room)
	var slot := ZoneAnchorRecord.new()
	slot.id = &"bench"
	slot.owner_id = &"craft_1"
	slot.role = ZoneAnchorRecord.ROLE_SLOT
	slot.pos = Vector3(0.5, 0.0, 0.5)
	blueprint.anchors.append(slot)
	var door := ZoneAnchorRecord.new()
	door.id = &"door"
	door.owner_id = &"craft_1"
	door.role = ZoneAnchorRecord.ROLE_DOOR
	door.pos = Vector3(0.5, 0.0, 0.0)
	blueprint.anchors.append(door)

	var repository := RepositoryScript.new(false, TEST_PROJECT_ROOT, TEST_SOURCE)
	var save_result: Dictionary = repository.save(blueprint)
	assert(bool(save_result.get("ok", false)), str(save_result.get("error", "")))
	# Re-saving verifies atomic replacement of an existing file.
	assert(bool(repository.save(blueprint).get("ok", false)))

	LibraryScript.refresh()
	var runtime_key := LibraryScript.runtime_key(TEST_SOURCE, TEST_ID)
	assert(runtime_key == "pack:test_author.test_buildings/_test_modular_pipeline")
	assert(LibraryScript.has(runtime_key))
	var loaded = LibraryScript.get_blueprint(runtime_key)
	assert(loaded != null)
	assert(loaded.construction_cost == {"soil": 1, "branches": 1})
	assert(BuildingCatalogScript.definition_for(String(TEST_ID)).get("category") == "custom")

	var game_blueprint: Dictionary = BuildingBlueprintsScript.get_blueprint(runtime_key)
	assert(game_blueprint.get("modules", []).size() == 2)
	assert(game_blueprint.get("zones", []).size() == 1)
	assert(game_blueprint.get("blueprint_ref", {}).get("source") == String(TEST_SOURCE))
	assert(game_blueprint.get("blueprint_ref", {}).get("role") == String(TEST_ID))

	var remove_error := DirAccess.remove_absolute(repository.file_path_for(TEST_ID))
	assert(remove_error == OK)
	LibraryScript.refresh()
	assert(not LibraryScript.has(runtime_key))

	_test_builtin_tent()
	_test_fill_only_blueprint_uses_footprint_pivot()
	_test_id_alphabet_is_refused_not_mangled()
	_test_save_writes_back_to_the_same_file()
	_test_read_only_source_is_not_writable()
	_test_fill_survives_a_round_trip()
	MapDocumentService._remove_directory(TEST_PROJECT_ROOT)
	quit(0)


func _setup_project() -> void:
	MapDocumentService._remove_directory(TEST_PROJECT_ROOT)
	var projects := ContentProjectRepository.new(false)
	var created := projects.create_project(&"test_author", &"test_buildings", "Test Buildings", "Test Author")
	assert(not created.is_empty())


## A non-ASCII id used to be stripped character by character down to
## `untitled_building`, so every such attempt collided in one file. It is now
## refused with a message the author can act on (content_packaging.md §3.3).
func _test_id_alphabet_is_refused_not_mangled() -> void:
	var repository := RepositoryScript.new(false, TEST_PROJECT_ROOT, TEST_SOURCE)
	var blueprint := BlueprintScript.new()
	blueprint.id = &"Пекарня"
	blueprint.role = &"bakery"
	blueprint.name = "Пекарня"
	var result: Dictionary = repository.save(blueprint)
	assert(not bool(result.get("ok", true)), "a cyrillic id must not be saved")
	assert(String(result.get("error", "")).contains("ID"), "and must say so in the UI language")
	assert(not FileAccess.file_exists(repository.base_dir() + "/untitled_building.gdbuilding.json"),
		"and must not fall back to a shared placeholder file")

	# The same rule as a pure function, which is what the editor's live field uses.
	# Two words of Cyrillic leave only the digit — which is exactly why nothing is
	# auto-filled from `name`: the result is not a slug.
	assert(ContentId.normalize_id("Моя Пекарня 2") == "2", "non-ASCII is dropped, stray separators trimmed")
	assert(ContentId.normalize_id("Проба-Map 7") == "map_7", "a leading dash is an artefact, not a name")
	assert(ContentId.normalize_id("My Bakery") == "my_bakery")
	# The live form keeps separators where they fall, or the field could not be
	# typed in: `my_` is what `my_bakery` looks like half-way through.
	assert(ContentId.sanitize_id("my_") == "my_", "typing an underscore must survive")
	assert(ContentId.normalize_id("my_") == "my", "committing one drops it")
	assert(not ContentId.is_valid_id(""), "empty is not a name")


## Saving honours the path a blueprint was opened from, so a file in a subfolder
## stays there instead of being duplicated at the source root — where the copy
## would then be reported as a duplicate id and one of the two would stop opening.
func _test_save_writes_back_to_the_same_file() -> void:
	var repository := RepositoryScript.new(false, TEST_PROJECT_ROOT, TEST_SOURCE)
	var nested_dir := repository.base_dir() + "/_test_nested"
	DirAccess.make_dir_recursive_absolute(nested_dir)
	var nested_path := nested_dir + "/_test_nested_bp.gdbuilding.json"

	var blueprint := BlueprintScript.new()
	blueprint.id = &"_test_nested_bp"
	blueprint.role = &"_test_nested_bp"
	blueprint.name = "Вложенный"
	assert(bool(repository.save(blueprint, nested_path).get("ok", false)))
	assert(FileAccess.file_exists(nested_path), "written where it was asked")

	blueprint.name = "Вложенный, изменённый"
	var again: Dictionary = repository.save(blueprint, nested_path)
	assert(bool(again.get("ok", false)))
	assert(again["path"] == nested_path, "a resave stays put")
	assert(not FileAccess.file_exists(repository.base_dir() + "/_test_nested_bp.gdbuilding.json"),
		"and never mints a second file at the source root")

	var reread = repository.load_blueprint(nested_path)
	assert(reread != null and reread.name == "Вложенный, изменённый")

	DirAccess.remove_absolute(nested_path)
	DirAccess.remove_absolute(nested_dir)


## Player mode may read the shipped pack and may not write it. This is what lets a
## player start from `core:tent` without being able to damage the game.
func _test_read_only_source_is_not_writable() -> void:
	var player := RepositoryScript.new(false, TEST_PROJECT_ROOT, TEST_SOURCE)
	assert(player.base_dir() == TEST_PROJECT_ROOT.path_join("buildings"))
	assert(player.can_write(TEST_PROJECT_ROOT.path_join("buildings/mine.gdbuilding.json")))
	assert(not player.can_write(RepositoryScript.DEV_DIR + "/tent.gdbuilding.json"))

	var blueprint := BlueprintScript.new()
	blueprint.id = &"_test_readonly"
	blueprint.role = &"_test_readonly"
	var refused: Dictionary = player.save(blueprint, RepositoryScript.DEV_DIR + "/_test_readonly.gdbuilding.json")
	assert(not bool(refused.get("ok", true)), "player mode cannot write the shipped pack")
	assert(not FileAccess.file_exists(RepositoryScript.DEV_DIR + "/_test_readonly.gdbuilding.json"))

	# The open list still shows it, because starting from shipped content is the
	# point of the asymmetry.
	var listed: Array = player.list_blueprints()
	var shipped := listed.filter(func(entry: Dictionary) -> bool: return not entry["writable"])
	assert(not shipped.is_empty(), "shipped blueprints are listed for opening")


## Fill is part of the blueprint, not a layer on top of it: one file, one save.
## The invariant is asserted rather than assumed because nothing in the save path
## mentions `objects` — it works only as long as the whole document is written.
func _test_fill_survives_a_round_trip() -> void:
	var repository := RepositoryScript.new(false, TEST_PROJECT_ROOT, TEST_SOURCE)
	var blueprint := BlueprintScript.new()
	blueprint.id = &"_test_fill_round_trip"
	blueprint.role = &"_test_fill_round_trip"
	blueprint.name = "С наполнением"
	blueprint.footprint = Vector2i(4, 4)
	blueprint.grid_bounds = Vector3i(4, 2, 4)

	var record = FillObjectRecordScript.new()
	record.id = &"campfire_1"
	record.asset_id = &"campfire"
	record.pos = Vector3(2.5, 0.0, 1.5)
	record.rot = Vector3(0.0, 90.0, 0.0)
	blueprint.objects.append(record)

	var saved: Dictionary = repository.save(blueprint)
	assert(bool(saved.get("ok", false)), str(saved.get("error", "")))

	var reread = repository.load_blueprint(saved["path"])
	assert(reread != null, "reopened")
	assert(reread.objects.size() == 1, "the fill object came back")
	assert(reread.objects[0].id == &"campfire_1")
	assert(reread.objects[0].asset_id == &"campfire")
	# Positions cross the pivot conversion on the way out and back (§7.1), so an
	# exact match here also proves the two directions agree.
	assert(reread.objects[0].pos.is_equal_approx(record.pos),
		"fill position survived the pivot conversion: %s vs %s" % [reread.objects[0].pos, record.pos])
	assert(is_equal_approx(reread.objects[0].rot.y, 90.0), "rotation survived")

	DirAccess.remove_absolute(saved["path"])


## The shipped tent blueprint must render from blocks yet keep the tent's static
## gameplay definition (costs, housing) — a builtin blueprint supplies visuals,
## never overrides functionality keyed by building_type.
func _test_builtin_tent() -> void:
	LibraryScript.refresh()
	assert(LibraryScript.has("tent"), "tent.gdbuilding.json must be indexed")
	var tent = LibraryScript.get_blueprint("tent")
	assert(tent != null)
	assert(tent.footprint == Vector2i(4, 4))
	var game_blueprint: Dictionary = BuildingBlueprintsScript.get_blueprint("tent")
	assert(game_blueprint.get("modules", []).size() == 16, "tent should render 16 block modules")
	# Static catalog definition stays authoritative: cost is not recomputed from
	# the 16 thatch blocks, and the tent stays a housing type.
	var costs: Dictionary = BuildingCatalogScript.definition_for("tent").get("costs", {})
	assert(costs == {"branches": 4, "grass": 4}, "tent cost must stay the static one, got %s" % costs)


## A building with only authored fill still uses the footprint pivot. Otherwise
## its objects are offset by half the footprint when placed in the world.
func _test_fill_only_blueprint_uses_footprint_pivot() -> void:
	var campfire: Dictionary = BuildingBlueprintsScript.get_blueprint("campfire")
	var modules: Array = campfire.get("modules", [])
	assert(modules.size() == 1, "campfire must contain its authored fill module")
	var local_position: Vector3 = modules[0].get("position", Vector3.INF)
	assert(local_position.is_zero_approx(),
		"fill-only campfire must be centred on its placement cell")
