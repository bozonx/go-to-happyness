class_name FixtureRuntimeState
extends RefCounted

## Per-instance state of a fixture in a constructed building
## (design_docs/content/building_furnishing.md §2.3, §11).
##
## Created from FixtureDefinition.runtime_defaults when a building is
## completed. Stored in the game save, not in the blueprint.
##
## The stable address is `(building_instance_id, fixture_id)`. Feature services
## read and write only through this typed state — never through visual nodes.
##
## Phase 2A supports only `fire_source` capability, which delegates to the
## existing FireSourceState owned by FireManagementService.

const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")
const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const FireSourceDefaultsScript = preload("res://game/features/buildings/domain/editor/fire_source_defaults.gd")

## Matches FixtureDefinition.id in the blueprint.
var fixture_id: StringName = &""

## Stable building identifier (cell-based or save-id).
var building_instance_id: String = ""

## Capabilities copied from the definition at creation time.
var capabilities: Array[StringName] = []

## Fire state for fire_source fixtures. Null if no fire_source capability.
var fire_state: RefCounted = null


static func create_from_definition(
	fixture: FixtureDefinition,
	building_id: String,
	current_minute: int
) -> FixtureRuntimeState:
	var state := FixtureRuntimeState.new()
	state.fixture_id = fixture.id
	state.building_instance_id = building_id
	state.capabilities = fixture.capabilities.duplicate()
	if fixture.has_capability(FixtureDefinitionScript.CAP_FIRE_SOURCE):
		var defaults := FireSourceDefaultsScript.from_dict(fixture.runtime_defaults)
		state.fire_state = FireSourceStateScript.from_values(
			defaults.fuel,
			0,
			defaults.lit,
			-1
		)
	return state


func has_capability(cap: StringName) -> bool:
	return cap in capabilities


func to_dict() -> Dictionary:
	var data: Dictionary = {
		"fixture_id": String(fixture_id),
		"building_instance_id": building_instance_id,
		"capabilities": capabilities.map(func(c: StringName) -> String: return String(c)),
	}
	if fire_state != null:
		data["fire_state"] = {
			"fuel": fire_state.fuel,
			"reserved_fuel": fire_state.reserved_fuel,
			"lit": fire_state.lit,
			"embers_until_minute": fire_state.embers_until_minute,
		}
	return data


static func from_dict(data: Dictionary) -> FixtureRuntimeState:
	var state := FixtureRuntimeState.new()
	state.fixture_id = StringName(data.get("fixture_id", ""))
	state.building_instance_id = String(data.get("building_instance_id", ""))
	var raw_caps: Variant = data.get("capabilities", [])
	if raw_caps is Array:
		for cap in raw_caps:
			state.capabilities.append(StringName(cap))
	var raw_fire: Variant = data.get("fire_state", null)
	if raw_fire is Dictionary:
		var fs: Dictionary = raw_fire
		state.fire_state = FireSourceStateScript.from_values(
			int(fs.get("fuel", 0)),
			int(fs.get("reserved_fuel", 0)),
			bool(fs.get("lit", true)),
			int(fs.get("embers_until_minute", -1))
		)
	return state
