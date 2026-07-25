class_name ZoneRequirements
extends RefCounted

## Static rules that define which fixture capabilities a zone kind requires
## (design_docs/content/building_furnishing.md §4 — zone requirements).
##
## This is a pure domain lookup: given a zone kind (and optional subtype),
## it returns the list of capabilities that must be present in at least one
## fixture assigned to that zone. The blueprint validator checks this;
## the editor checklist displays it.
##
## Phase 2B rules:
##   kitchen (workplace + profession=cook) → fire_source
##   housing → bed (not yet a fixture capability — placeholder)
##   storage → storage_input, storage_output (placeholders)
##
## Capabilities not yet backed by a fixture runtime (bed, storage_input,
## storage_output) are declared here so the editor can show them in the
## checklist. They will be enforced once their fixture types are implemented.

const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const PlaceZoneRecordScript = preload("res://game/features/buildings/domain/editor/place_zone_record.gd")

## Capabilities that are known but not yet implemented as runtime fixtures.
## They appear in the checklist and validation but have no runtime_defaults schema.
const CAP_BED := &"bed"
const CAP_STORAGE_INPUT := &"storage_input"
const CAP_STORAGE_OUTPUT := &"storage_output"

## All capabilities known to the requirements system (superset of
## FixtureDefinition.KNOWN_CAPABILITIES, including future ones).
const ALL_CAPABILITIES: Array[StringName] = [
	FixtureDefinitionScript.CAP_FIRE_SOURCE,
	FixtureDefinitionScript.CAP_COOKING_STATION,
	FixtureDefinitionScript.CAP_LIGHT_SOURCE,
	CAP_BED,
	CAP_STORAGE_INPUT,
	CAP_STORAGE_OUTPUT,
]


## Returns the list of required capabilities for a zone, or an empty array
## if the zone kind has no fixture requirements.
static func required_capabilities_for_zone(zone: PlaceZoneRecordScript) -> Array[StringName]:
	if zone == null:
		return []
	# Kitchen: workplace with profession=cook requires fire_source.
	if zone.kind == PlaceZoneRecordScript.KIND_WORKPLACE and zone.profession == &"cook":
		return [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	# Housing requires a bed.
	if zone.kind == PlaceZoneRecordScript.KIND_HOUSING:
		return [CAP_BED]
	# Storage requires input and output.
	if zone.kind == PlaceZoneRecordScript.KIND_STORAGE:
		return [CAP_STORAGE_INPUT, CAP_STORAGE_OUTPUT]
	return []


## Returns a human-readable label for a capability.
static func capability_label(cap: StringName) -> String:
	match cap:
		FixtureDefinitionScript.CAP_FIRE_SOURCE:
			return "Источник огня"
		FixtureDefinitionScript.CAP_COOKING_STATION:
			return "Станция готовки"
		FixtureDefinitionScript.CAP_LIGHT_SOURCE:
			return "Источник света"
		CAP_BED:
			return "Кровать"
		CAP_STORAGE_INPUT:
			return "Приёмка (вход)"
		CAP_STORAGE_OUTPUT:
			return "Выдача (выход)"
		_:
			return String(cap)


## Returns true if a capability is backed by a runtime fixture (has a
## defaults schema and can be created in the editor). Future capabilities
## (bed, storage_input, storage_output) return false until implemented.
static func is_runtime_capability(cap: StringName) -> bool:
	return cap in FixtureDefinitionScript.KNOWN_CAPABILITIES
