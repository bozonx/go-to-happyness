extends SceneTree

## Tests for zone requirements (Phase 2B).
##
## Verifies:
## 1. ZoneRequirements.required_capabilities_for_zone returns correct caps.
## 2. BuildingBlueprint.validation_errors flags missing requirements.
## 3. BuildingBlueprint.zone_requirements_checklist reports satisfied/unsatisfied.
## 4. Procedural campfire blueprints include fire_source fixtures.
## 5. Building-wide fixtures satisfy zone requirements.

const ZoneRequirementsScript = preload("res://game/features/buildings/domain/editor/zone_requirements.gd")
const PlaceZoneRecordScript = preload("res://game/features/buildings/domain/editor/place_zone_record.gd")
const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const BuildingBlueprintLibraryScript = preload("res://game/features/buildings/presentation/building_blueprint_library.gd")
const BuildingBlueprintsScript = preload("res://game/features/buildings/presentation/building_blueprints.gd")
const DecorObjectRecordScript = preload("res://game/features/buildings/domain/editor/decor_object_record.gd")


func _init() -> void:
	print("--- Running test_zone_requirements.gd ---")
	_test_required_capabilities_for_zone()
	_test_validation_missing_fire_source()
	_test_validation_satisfied_by_zone_fixture()
	_test_validation_satisfied_by_building_wide_fixture()
	_test_checklist_reports_satisfied_and_unsatisfied()
	_test_procedural_campfire_has_fixtures()
	_test_housing_requires_bed_placeholder()
	_test_storage_requires_input_output()
	print("--- test_zone_requirements.gd PASSED ---")
	quit(0)


## ZoneRequirements must return the correct capabilities for each zone kind.
func _test_required_capabilities_for_zone() -> void:
	# Kitchen: workplace + profession=cook → fire_source.
	var kitchen := PlaceZoneRecordScript.new()
	kitchen.kind = PlaceZoneRecordScript.KIND_WORKPLACE
	kitchen.profession = &"cook"
	var kitchen_caps := ZoneRequirementsScript.required_capabilities_for_zone(kitchen)
	assert(kitchen_caps.size() == 1, "kitchen should require 1 capability")
	assert(kitchen_caps[0] == FixtureDefinitionScript.CAP_FIRE_SOURCE, "kitchen should require fire_source")

	# Workplace with non-cook profession → no requirements.
	var workshop := PlaceZoneRecordScript.new()
	workshop.kind = PlaceZoneRecordScript.KIND_WORKPLACE
	workshop.profession = &"craftsman"
	var workshop_caps := ZoneRequirementsScript.required_capabilities_for_zone(workshop)
	assert(workshop_caps.is_empty(), "non-cook workplace should have no requirements")

	# Housing → bed.
	var housing := PlaceZoneRecordScript.new()
	housing.kind = PlaceZoneRecordScript.KIND_HOUSING
	var housing_caps := ZoneRequirementsScript.required_capabilities_for_zone(housing)
	assert(housing_caps.size() == 1, "housing should require 1 capability")
	assert(housing_caps[0] == ZoneRequirementsScript.CAP_BED, "housing should require bed")

	# Storage → storage_input + storage_output.
	var storage := PlaceZoneRecordScript.new()
	storage.kind = PlaceZoneRecordScript.KIND_STORAGE
	var storage_caps := ZoneRequirementsScript.required_capabilities_for_zone(storage)
	assert(storage_caps.size() == 2, "storage should require 2 capabilities")
	assert(ZoneRequirementsScript.CAP_STORAGE_INPUT in storage_caps, "storage should require storage_input")
	assert(ZoneRequirementsScript.CAP_STORAGE_OUTPUT in storage_caps, "storage should require storage_output")

	# Null zone → empty.
	assert(ZoneRequirementsScript.required_capabilities_for_zone(null).is_empty(), "null zone should return empty")

	print("  required_capabilities_for_zone ok")


## BuildingBlueprint.validation_errors must flag a kitchen zone without fire_source.
func _test_validation_missing_fire_source() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_missing_fire"

	var zone := PlaceZoneRecordScript.new()
	zone.zone_id = &"kitchen_1"
	zone.zone_name = "Kitchen"
	zone.kind = PlaceZoneRecordScript.KIND_WORKPLACE
	zone.profession = &"cook"
	bp.place_zones.append(zone)

	var errors := bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("fire_source") and e.contains("kitchen_1")),
		"Validation must flag missing fire_source for kitchen zone")

	print("  validation missing fire_source ok")


## A fire_source fixture assigned to the kitchen zone must satisfy the requirement.
func _test_validation_satisfied_by_zone_fixture() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_satisfied_zone"

	var zone := PlaceZoneRecordScript.new()
	zone.zone_id = &"kitchen_1"
	zone.zone_name = "Kitchen"
	zone.kind = PlaceZoneRecordScript.KIND_WORKPLACE
	zone.profession = &"cook"
	bp.place_zones.append(zone)

	var fixture := FixtureDefinitionScript.new()
	fixture.id = &"fire_1"
	fixture.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fixture.owner_zone_id = &"kitchen_1"
	fixture.runtime_defaults = {"lit": true, "fuel": 4, "fuel_capacity": 8}
	bp.fixtures.append(fixture)

	var errors := bp.validation_errors()
	var zone_errors := errors.filter(func(e: String): return e.contains("fire_source") and e.contains("kitchen_1"))
	assert(zone_errors.is_empty(), "Zone-assigned fire_source must satisfy requirement: " + str(zone_errors))

	print("  validation satisfied by zone fixture ok")


## A building-wide fire_source fixture (owner_zone_id empty) must satisfy zone requirements.
func _test_validation_satisfied_by_building_wide_fixture() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_satisfied_wide"

	var zone := PlaceZoneRecordScript.new()
	zone.zone_id = &"kitchen_1"
	zone.zone_name = "Kitchen"
	zone.kind = PlaceZoneRecordScript.KIND_WORKPLACE
	zone.profession = &"cook"
	bp.place_zones.append(zone)

	var fixture := FixtureDefinitionScript.new()
	fixture.id = &"fire_1"
	fixture.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fixture.owner_zone_id = &""
	fixture.runtime_defaults = {"lit": true, "fuel": 4, "fuel_capacity": 8}
	bp.fixtures.append(fixture)

	var errors := bp.validation_errors()
	var zone_errors := errors.filter(func(e: String): return e.contains("fire_source") and e.contains("kitchen_1"))
	assert(zone_errors.is_empty(), "Building-wide fire_source must satisfy zone requirement: " + str(zone_errors))

	print("  validation satisfied by building-wide fixture ok")


## zone_requirements_checklist must report both satisfied and unsatisfied entries.
func _test_checklist_reports_satisfied_and_unsatisfied() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_checklist"

	# Kitchen with a fire_source fixture → satisfied.
	var zone1 := PlaceZoneRecordScript.new()
	zone1.zone_id = &"kitchen_1"
	zone1.zone_name = "Kitchen"
	zone1.kind = PlaceZoneRecordScript.KIND_WORKPLACE
	zone1.profession = &"cook"
	bp.place_zones.append(zone1)

	var fixture := FixtureDefinitionScript.new()
	fixture.id = &"fire_1"
	fixture.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fixture.owner_zone_id = &"kitchen_1"
	fixture.runtime_defaults = {"lit": true, "fuel": 4, "fuel_capacity": 8}
	bp.fixtures.append(fixture)

	# Housing without a bed fixture → unsatisfied.
	var zone2 := PlaceZoneRecordScript.new()
	zone2.zone_id = &"housing_1"
	zone2.zone_name = "Dormitory"
	zone2.kind = PlaceZoneRecordScript.KIND_HOUSING
	bp.place_zones.append(zone2)

	var checklist := bp.zone_requirements_checklist()
	assert(checklist.size() == 2, "checklist should have 2 entries (kitchen fire + housing bed)")

	# Find the kitchen entry — should be satisfied.
	var kitchen_entry: Dictionary = {}
	var housing_entry: Dictionary = {}
	for entry in checklist:
		if entry.zone_id == "kitchen_1":
			kitchen_entry = entry
		elif entry.zone_id == "housing_1":
			housing_entry = entry

	assert(not kitchen_entry.is_empty(), "kitchen entry must exist in checklist")
	assert(kitchen_entry.satisfied, "kitchen fire_source must be satisfied")
	assert(kitchen_entry.is_runtime, "fire_source is a runtime capability")

	assert(not housing_entry.is_empty(), "housing entry must exist in checklist")
	assert(not housing_entry.satisfied, "housing bed must be unsatisfied (no fixture)")
	assert(not housing_entry.is_runtime, "bed is not yet a runtime capability")

	print("  checklist reports satisfied and unsatisfied ok")


## Procedural campfire blueprints (lvl2/lvl3) must include fire_source fixtures.
func _test_procedural_campfire_has_fixtures() -> void:
	for bt in ["campfire_lvl2", "campfire_lvl3", "cook_campfire_lvl2", "cook_campfire_lvl3"]:
		var bp_dict := BuildingBlueprintsScript.get_blueprint(bt)
		assert(bp_dict.has("fixtures"), "%s blueprint must have fixtures key" % bt)
		var fixtures: Array = bp_dict["fixtures"]
		assert(not fixtures.is_empty(), "%s blueprint must have at least 1 fixture" % bt)
		var has_fire := false
		for fd_data in fixtures:
			var fd := FixtureDefinitionScript.from_dict(fd_data)
			if fd.has_capability(FixtureDefinitionScript.CAP_FIRE_SOURCE):
				has_fire = true
		assert(has_fire, "%s blueprint must have a fire_source fixture" % bt)

	print("  procedural campfire has fixtures ok")


## Housing zones must require bed (a placeholder non-runtime capability).
func _test_housing_requires_bed_placeholder() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_housing"

	var zone := PlaceZoneRecordScript.new()
	zone.zone_id = &"housing_1"
	zone.zone_name = "Home"
	zone.kind = PlaceZoneRecordScript.KIND_HOUSING
	bp.place_zones.append(zone)

	var errors := bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("bed") and e.contains("housing_1")),
		"Validation must flag missing bed for housing zone")

	# Verify bed is not a runtime capability.
	assert(not ZoneRequirementsScript.is_runtime_capability(ZoneRequirementsScript.CAP_BED),
		"bed must not be a runtime capability yet")

	print("  housing requires bed placeholder ok")


## Storage zones must require both storage_input and storage_output.
func _test_storage_requires_input_output() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_storage"

	var zone := PlaceZoneRecordScript.new()
	zone.zone_id = &"storage_1"
	zone.zone_name = "Warehouse"
	zone.kind = PlaceZoneRecordScript.KIND_STORAGE
	bp.place_zones.append(zone)

	var errors := bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("storage_input") and e.contains("storage_1")),
		"Validation must flag missing storage_input")
	assert(errors.any(func(e: String): return e.contains("storage_output") and e.contains("storage_1")),
		"Validation must flag missing storage_output")

	print("  storage requires input/output ok")
