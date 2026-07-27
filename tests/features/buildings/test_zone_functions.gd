extends SceneTree

## Tests for pack-declared zone functions (design_docs/engine/active_zones.md §2, §8.3).
##
## The point of these tests is that the engine holds no vocabulary of its own:
## professions, room kinds and capability requirements all arrive from a content
## pack's `zone_functions.json`, and validation reads them back out.
##
## Verifies:
## 1. The catalog loads the core pack and namespaces its ids.
## 2. Requirements come from the function, not from a hardcoded rule.
## 3. validation_errors flags a zone whose required capability is missing.
## 4. A zone fixture and a building-wide fixture both satisfy a requirement.
## 5. zone_requirements_checklist reports satisfied and unsatisfied entries.
## 6. Procedural campfire blueprints still ship fire_source fixtures.

const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingBlueprintsScript = preload("res://game/features/buildings/presentation/building_blueprints.gd")

const KITCHEN := &"core:kitchen"


func _init() -> void:
	print("--- Running test_zone_functions.gd ---")
	_test_catalog_loads_from_pack()
	_test_requirements_come_from_the_pack()
	_test_validation_missing_fire_source()
	_test_validation_satisfied_by_zone_fixture()
	_test_validation_satisfied_by_building_wide_fixture()
	_test_checklist_reports_satisfied_and_unsatisfied()
	_test_procedural_campfire_has_fixtures()
	print("--- test_zone_functions.gd PASSED ---")
	quit(0)


## Functions are content, so ids are namespaced by the pack that shipped them and
## two packs may both define a "kitchen" without colliding.
func _test_catalog_loads_from_pack() -> void:
	ZoneFunctionCatalog.reload()
	assert(ZoneFunctionCatalog.load_errors.is_empty(), str(ZoneFunctionCatalog.load_errors))
	assert(ZoneFunctionCatalog.has_function(KITCHEN), "core pack must declare a kitchen")
	assert(ZoneFunctionCatalog.pack_of(KITCHEN) == &"core")
	assert(not ZoneFunctionCatalog.has_function(&"kitchen"), "ids must be namespaced")
	# Room functions are offered for rooms; activities are a separate scope.
	var room_functions := ZoneFunctionCatalog.for_area_role(ZoneAreaRecord.ROLE_ROOM)
	assert(room_functions.any(func(e: Dictionary) -> bool: return e["id"] == KITCHEN))
	assert(ZoneFunctionCatalog.activities().any(func(e: Dictionary) -> bool:
		return e["id"] == &"core:cook"))
	print("  catalog loads from pack ok")


func _test_requirements_come_from_the_pack() -> void:
	var kitchen_caps := ZoneFunctionCatalog.required_capabilities(KITCHEN)
	assert(kitchen_caps.size() == 1 and kitchen_caps[0] == FixtureDefinitionScript.CAP_FIRE_SOURCE)
	# A function with no `requires` demands nothing, and so does an unknown one.
	assert(ZoneFunctionCatalog.required_capabilities(&"core:housing").is_empty())
	assert(ZoneFunctionCatalog.required_capabilities(&"nosuch:function").is_empty())
	# Properties and their defaults are declared by the pack too.
	var defaults := ZoneFunctionCatalog.default_properties(KITCHEN)
	assert(defaults.get("profession") == "cook")
	assert(int(defaults.get("max_workers", 0)) == 1)
	print("  requirements come from the pack ok")


func _test_validation_missing_fire_source() -> void:
	var bp := _blueprint_with_kitchen()
	var errors := bp.validation_errors()
	assert(errors.any(func(e: String) -> bool:
		return e.contains("fire_source") and e.contains("kitchen_1")),
		"Validation must flag a kitchen without a fire source")
	print("  validation missing fire_source ok")


func _test_validation_satisfied_by_zone_fixture() -> void:
	var bp := _blueprint_with_kitchen()
	bp.fixtures.append(_fire_fixture(&"hearth", &"kitchen_1"))
	assert(not _has_capability_error(bp), str(bp.validation_errors()))
	print("  requirement satisfied by zone fixture ok")


## A building-wide fixture (empty owner) serves every zone in the building.
func _test_validation_satisfied_by_building_wide_fixture() -> void:
	var bp := _blueprint_with_kitchen()
	bp.fixtures.append(_fire_fixture(&"hearth", &""))
	assert(not _has_capability_error(bp), str(bp.validation_errors()))
	print("  requirement satisfied by building-wide fixture ok")


func _test_checklist_reports_satisfied_and_unsatisfied() -> void:
	var bp := _blueprint_with_kitchen()
	var second := ZoneAreaRecord.new()
	second.id = &"kitchen_2"
	second.area_name = "Вторая кухня"
	second.function = KITCHEN
	second.add_rect(Rect2i(2, 0, 1, 1))
	bp.areas.append(second)
	bp.fixtures.append(_fire_fixture(&"hearth", &"kitchen_1"))

	var checklist := bp.zone_requirements_checklist()
	assert(checklist.size() == 2, str(checklist))
	for entry in checklist:
		if entry["area_id"] == "kitchen_1":
			assert(entry["satisfied"], "kitchen_1 has its own fire source")
		else:
			assert(not entry["satisfied"], "kitchen_2 has none")
	print("  checklist reports satisfied and unsatisfied ok")


func _test_procedural_campfire_has_fixtures() -> void:
	for building_type in ["campfire_lvl2", "campfire_lvl3", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
		var bp_dict := BuildingBlueprintsScript.get_blueprint(building_type)
		assert(bp_dict.has("fixtures"), "%s blueprint must have fixtures key" % building_type)
		var fixtures: Array = bp_dict["fixtures"]
		assert(not fixtures.is_empty(), "%s blueprint must have at least 1 fixture" % building_type)
		var has_fire := false
		for fd_data in fixtures:
			if FixtureDefinitionScript.from_dict(fd_data).has_capability(
					FixtureDefinitionScript.CAP_FIRE_SOURCE):
				has_fire = true
		assert(has_fire, "%s blueprint must have a fire_source fixture" % building_type)
	print("  procedural campfire has fixtures ok")


func _blueprint_with_kitchen() -> BuildingBlueprint:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_kitchen"
	bp.footprint = Vector2i(4, 4)
	var kitchen := ZoneAreaRecord.new()
	kitchen.id = &"kitchen_1"
	kitchen.area_name = "Кухня"
	kitchen.function = KITCHEN
	kitchen.properties = ZoneFunctionCatalog.default_properties(KITCHEN)
	kitchen.add_rect(Rect2i(0, 0, 2, 2))
	bp.areas.append(kitchen)
	var door := ZoneAnchorRecord.new()
	door.id = &"door"
	door.role = ZoneAnchorRecord.ROLE_DOOR
	door.pos = Vector3(0.5, 0.0, 0.0)
	bp.anchors.append(door)
	return bp


func _fire_fixture(fixture_id: StringName, owner_zone: StringName) -> FixtureDefinition:
	var fixture := FixtureDefinitionScript.new()
	fixture.id = fixture_id
	fixture.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fixture.owner_zone_id = owner_zone
	fixture.runtime_defaults = {"fuel": 0.0, "max_fuel": 100.0, "burn_rate": 1.0}
	return fixture


func _has_capability_error(bp: BuildingBlueprint) -> bool:
	return bp.validation_errors().any(func(e: String) -> bool: return e.contains("requires capability"))
