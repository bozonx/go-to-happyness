class_name FixtureService
extends RefCounted

## Application service that manages FixtureRuntimeState for constructed
## building instances (design_docs/engine/building_furnishing.md §11).
##
## Created on building completion from the blueprint's fixtures[]. Each fixture
## gets a stable address (building_instance_id, fixture_id). Feature services
## query this registry to find fixtures by capability.
##
## Phase 2A: only fire_source capability is supported. The fire state itself
## is owned by FireManagementService — FixtureService provides the address and
## placement data, FireManagementService reads/writes the actual fuel/lit state.

const FixtureRuntimeStateScript = preload("res://game/features/buildings/domain/editor/fixture_runtime_state.gd")
const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")

## Maps building_instance_id -> Array[FixtureRuntimeState]
var _states: Dictionary = {}


func initialize_for_building(building_instance_id: String, blueprint: BuildingBlueprint, current_minute: int) -> void:
	if _states.has(building_instance_id):
		return
	var list: Array[FixtureRuntimeState] = []
	for fixture in blueprint.fixtures:
		var state := FixtureRuntimeStateScript.create_from_definition(fixture, building_instance_id, current_minute)
		list.append(state)
	_states[building_instance_id] = list


func states_for_building(building_instance_id: String) -> Array[FixtureRuntimeState]:
	if not _states.has(building_instance_id):
		return []
	return _states[building_instance_id]


func fixtures_with_capability(building_instance_id: String, cap: StringName) -> Array[FixtureRuntimeState]:
	var result: Array[FixtureRuntimeState] = []
	for state in states_for_building(building_instance_id):
		if state.has_capability(cap):
			result.append(state)
	return result


func fixture_by_id(building_instance_id: String, fixture_id: StringName) -> FixtureRuntimeState:
	for state in states_for_building(building_instance_id):
		if state.fixture_id == fixture_id:
			return state
	return null


func remove_building(building_instance_id: String) -> void:
	_states.erase(building_instance_id)


func has_fixtures(building_instance_id: String) -> bool:
	return _states.has(building_instance_id) and not _states[building_instance_id].is_empty()


func to_dict() -> Dictionary:
	var data: Dictionary = {}
	for building_id in _states.keys():
		var list: Array[FixtureRuntimeState] = _states[building_id]
		var arr: Array = []
		for state in list:
			arr.append(state.to_dict())
		data[building_id] = arr
	return data


func from_dict(data: Dictionary) -> void:
	_states.clear()
	for building_id in data.keys():
		var arr: Array = data[building_id]
		var list: Array[FixtureRuntimeState] = []
		for state_data in arr:
			if state_data is Dictionary:
				list.append(FixtureRuntimeStateScript.from_dict(state_data))
		_states[building_id] = list
