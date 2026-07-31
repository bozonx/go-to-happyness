extends SceneTree

## Tests for the fixture system (Phase 2A — fire_source vertical slice).
##
## Verifies:
## 1. Two independent fire_source fixtures in one building have isolated state.
## 2. FixtureRuntimeState serialization round-trip preserves fire state.
## 3. FixtureService correctly manages multiple buildings.
## 4. Migrated campfire/cook_campfire blueprints contain valid fixtures.

const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const FireSourceDefaultsScript = preload("res://game/features/buildings/domain/editor/fire_source_defaults.gd")
const FixtureRuntimeStateScript = preload("res://game/features/buildings/domain/editor/fixture_runtime_state.gd")
const FixtureServiceScript = preload("res://game/features/buildings/application/fixture_service.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")
const BuildingBlueprintLibraryScript = preload("res://game/features/buildings/presentation/building_blueprint_library.gd")
const FillObjectRecordScript = preload("res://game/features/buildings/domain/editor/fill_object_record.gd")


func _init() -> void:
	print("--- Running test_fixtures.gd ---")
	_test_two_independent_fires()
	_test_fixture_serialization_round_trip()
	_test_fixture_service_multi_building()
	_test_migrated_blueprints_have_fixtures()
	_test_fixture_validation_duplicate_visual_object()
	print("--- test_fixtures.gd PASSED ---")
	quit(0)


## Two fire_source fixtures in the same building must have completely
## independent FireSourceState — consuming fuel from one must not affect
## the other.
func _test_two_independent_fires() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_two_fires"

	# Create two fire_source fixtures referencing different visual objects.
	var fd1 := FixtureDefinitionScript.new()
	fd1.id = &"fire_north"
	fd1.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fd1.visual_object_id = "obj_north"
	fd1.runtime_defaults = {"lit": true, "fuel": 6, "fuel_capacity": 10}

	var fd2 := FixtureDefinitionScript.new()
	fd2.id = &"fire_south"
	fd2.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fd2.visual_object_id = "obj_south"
	fd2.runtime_defaults = {"lit": true, "fuel": 4, "fuel_capacity": 10}

	bp.fixtures.append(fd1)
	bp.fixtures.append(fd2)
	# Provide object IDs for validation.
	bp.objects.append(_make_dummy_object("obj_north"))
	bp.objects.append(_make_dummy_object("obj_south"))

	var errors := bp.validation_errors()
	assert(errors.is_empty(), "Two-fire blueprint must validate cleanly, got: " + str(errors))

	# Initialize runtime state.
	var service := FixtureServiceScript.new()
	service.initialize_for_building("building_1", bp, 0)

	var states := service.states_for_building("building_1")
	assert(states.size() == 2, "Must have 2 fixture states")

	var fire_north := states[0].fire_state
	var fire_south := states[1].fire_state

	# Consume all fuel from the north fire.
	fire_north.consume(6, 0)
	assert(fire_north.fuel == 0, "North fire fuel must be 0 after consuming 6")
	assert(not fire_north.lit, "North fire must be unlit after fuel exhausted")
	assert(fire_north.phase_at(0) == FireSourceStateScript.Phase.EMBERS, "North fire must be in embers")

	# South fire must be unaffected.
	assert(fire_south.fuel == 4, "South fire fuel must still be 4")
	assert(fire_south.lit, "South fire must still be lit")
	assert(fire_south.phase_at(0) == FireSourceStateScript.Phase.BURNING, "South fire must still be burning")

	print("  two independent fires ok")


## FixtureRuntimeState.to_dict / from_dict must preserve all fire state fields.
func _test_fixture_serialization_round_trip() -> void:
	var fd := FixtureDefinitionScript.new()
	fd.id = &"fire_serialize"
	fd.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fd.runtime_defaults = {"lit": true, "fuel": 8, "fuel_capacity": 12}

	var state := FixtureRuntimeStateScript.create_from_definition(fd, "bld_ser", 100)
	# Mutate the fire state to non-default values.
	state.fire_state.consume(3, 100)
	state.fire_state.reserve(2)

	var data := state.to_dict()
	assert(data["fixture_id"] == "fire_serialize", "fixture_id must survive serialization")
	assert(data["building_instance_id"] == "bld_ser", "building_instance_id must survive serialization")

	var restored := FixtureRuntimeStateScript.from_dict(data)
	assert(restored.fixture_id == &"fire_serialize", "fixture_id must survive round-trip")
	assert(restored.building_instance_id == "bld_ser", "building_instance_id must survive round-trip")
	assert(restored.fire_state != null, "fire_state must be restored")
	assert(restored.fire_state.fuel == 5, "fuel must be 5 after consume(3) from 8")
	assert(restored.fire_state.reserved_fuel == 2, "reserved_fuel must be 2")
	assert(restored.fire_state.lit, "fire must still be lit with fuel > 0")

	# Full FixtureService serialization.
	var service := FixtureServiceScript.new()
	var bp := BuildingBlueprintScript.new()
	bp.id = &"ser_test"
	bp.fixtures.append(fd)
	service.initialize_for_building("bld_ser", bp, 100)

	var svc_data := service.to_dict()
	var service2 := FixtureServiceScript.new()
	service2.from_dict(svc_data)
	var restored_states := service2.states_for_building("bld_ser")
	assert(restored_states.size() == 1, "Service must restore 1 building")
	assert(restored_states[0].fire_state.fuel == 8, "Fresh service fire fuel must be 8 (from defaults)")

	print("  fixture serialization round-trip ok")


## FixtureService must manage multiple buildings independently.
func _test_fixture_service_multi_building() -> void:
	var service := FixtureServiceScript.new()

	var bp := BuildingBlueprintScript.new()
	bp.id = &"multi_bld"
	var fd := FixtureDefinitionScript.new()
	fd.id = &"fire_1"
	fd.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fd.runtime_defaults = {"lit": true, "fuel": 3, "fuel_capacity": 10}
	bp.fixtures.append(fd)

	service.initialize_for_building("bld_a", bp, 0)
	service.initialize_for_building("bld_b", bp, 0)

	# Consume fuel in building A.
	var a_states := service.states_for_building("bld_a")
	a_states[0].fire_state.consume(3, 0)
	assert(a_states[0].fire_state.fuel == 0, "Building A fire must be exhausted")

	# Building B must be unaffected.
	var b_states := service.states_for_building("bld_b")
	assert(b_states[0].fire_state.fuel == 3, "Building B fire must still have 3 fuel")

	# Remove building A.
	service.remove_building("bld_a")
	assert(service.states_for_building("bld_a").is_empty(), "Building A states must be removed after removal")
	assert(service.states_for_building("bld_b").size() == 1, "Building B must still have its states")

	# Capability query.
	var b_fires := service.fixtures_with_capability("bld_b", FixtureDefinitionScript.CAP_FIRE_SOURCE)
	assert(b_fires.size() == 1, "Building B must have 1 fire_source fixture")

	print("  fixture service multi-building ok")


## Migrated campfire and cook_campfire blueprints must contain valid
## fire_source fixtures referencing their visual objects.
func _test_migrated_blueprints_have_fixtures() -> void:
	BuildingBlueprintLibraryScript._ensure_index()

	var campfire := BuildingBlueprintLibraryScript.get_blueprint("campfire")
	assert(campfire != null, "campfire blueprint must load")
	assert(campfire.fixtures.size() == 1, "campfire must have 1 fixture")
	var cf_fixture := campfire.fixtures[0]
	assert(cf_fixture.has_capability(FixtureDefinitionScript.CAP_FIRE_SOURCE), "campfire fixture must be fire_source")
	assert(cf_fixture.visual_object_id == "decor_campfire_1", "campfire fixture must reference decor_campfire_1")
	# Validate the fixture.
	var obj_ids := {}
	for obj in campfire.objects:
		obj_ids[obj.id] = true
	var cf_errors := cf_fixture.validation_errors(obj_ids, {})
	assert(cf_errors.is_empty(), "campfire fixture must validate cleanly: " + str(cf_errors))

	var cook := BuildingBlueprintLibraryScript.get_blueprint("cook_campfire")
	assert(cook != null, "cook_campfire blueprint must load")
	assert(cook.fixtures.size() == 1, "cook_campfire must have 1 fixture")
	var cook_fixture := cook.fixtures[0]
	assert(cook_fixture.has_capability(FixtureDefinitionScript.CAP_FIRE_SOURCE), "cook_campfire fixture must be fire_source")
	assert(cook_fixture.visual_object_id == "decor_cooking_campfire_1", "cook_campfire fixture must reference decor_cooking_campfire_1")

	# Verify runtime_defaults have expected fire values.
	var defaults := FireSourceDefaultsScript.from_dict(cf_fixture.runtime_defaults)
	assert(defaults.lit, "campfire fixture must default to lit")
	assert(defaults.fuel == 4, "campfire fixture must default to 4 fuel")

	print("  migrated blueprints have fixtures ok")


## Two fixtures referencing the same visual_object_id must be rejected
## by the blueprint validator.
func _test_fixture_validation_duplicate_visual_object() -> void:
	var bp := BuildingBlueprintScript.new()
	bp.id = &"test_dup_visual"
	bp.objects.append(_make_dummy_object("shared_obj"))

	var fd1 := FixtureDefinitionScript.new()
	fd1.id = &"fire_a"
	fd1.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fd1.visual_object_id = "shared_obj"
	fd1.runtime_defaults = {"lit": true, "fuel": 4, "fuel_capacity": 10}

	var fd2 := FixtureDefinitionScript.new()
	fd2.id = &"fire_b"
	fd2.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fd2.visual_object_id = "shared_obj"
	fd2.runtime_defaults = {"lit": true, "fuel": 4, "fuel_capacity": 10}

	bp.fixtures.append(fd1)
	bp.fixtures.append(fd2)

	var errors := bp.validation_errors()
	assert(errors.any(func(e: String): return e.contains("same visual object")),
		"Two fixtures referencing the same visual object must be rejected")

	print("  duplicate visual object validation ok")


func _make_dummy_object(object_id: String) -> RefCounted:
	var obj := FillObjectRecordScript.new()
	obj.id = object_id
	obj.asset_id = &"campfire"
	obj.pos = Vector3.ZERO
	obj.rot = Vector3.ZERO
	obj.scale = Vector3.ONE
	obj.appearance = {}
	return obj
