class_name FixtureDefinition
extends RefCounted

## Stable description of a functional element inside a BuildingBlueprint
## (design_docs/content/building_furnishing.md §3.2).
##
## A fixture tells the game **what** is at a position and which systems can use
## it. It is not a visual object — it references one via `visual_object_id`.
## Runtime state for a built instance is stored separately in
## FixtureRuntimeState, created from `runtime_defaults` on construction
## completion.
##
## Phase 2A supports only `fire_source` capability. The schema for
## `runtime_defaults` is validated by the matching typed defaults class
## (e.g. FireSourceDefaults).

const FireSourceDefaultsScript = preload("res://game/features/buildings/domain/editor/fire_source_defaults.gd")

const CAP_FIRE_SOURCE := &"fire_source"
const CAP_COOKING_STATION := &"cooking_station"
const CAP_LIGHT_SOURCE := &"light_source"

const KNOWN_CAPABILITIES: Array[StringName] = [
	CAP_FIRE_SOURCE,
	CAP_COOKING_STATION,
	CAP_LIGHT_SOURCE,
]

## Stable, unique id within the blueprint. Used to restore runtime state.
var id: StringName = &""

## Capabilities determine which game systems can interact with this fixture.
var capabilities: Array[StringName] = []

## Zone this fixture belongs to. Empty means building-wide.
var owner_zone_id: StringName = &""

## References `objects[].id` of the visual object that represents this fixture.
## May be empty for an invisible fixture (migration / service scenarios).
var visual_object_id: String = ""

## Typed initial state for a newly constructed building instance.
## Schema is validated per capability by the matching defaults class.
var runtime_defaults: Dictionary = {}


static func from_dict(data: Dictionary) -> FixtureDefinition:
	var fd := FixtureDefinition.new()
	fd.id = StringName(data.get("id", ""))
	var raw_caps: Variant = data.get("capabilities", [])
	if raw_caps is Array:
		for cap in raw_caps:
			fd.capabilities.append(StringName(cap))
	fd.owner_zone_id = StringName(data.get("owner_zone", ""))
	fd.visual_object_id = String(data.get("visual_object", ""))
	var raw_defaults: Variant = data.get("runtime_defaults", {})
	fd.runtime_defaults = raw_defaults.duplicate(true) if raw_defaults is Dictionary else {}
	return fd


func to_dict() -> Dictionary:
	var caps: Array = []
	for cap in capabilities:
		caps.append(String(cap))
	return {
		"id": String(id),
		"capabilities": caps,
		"owner_zone": String(owner_zone_id),
		"visual_object": visual_object_id,
		"runtime_defaults": runtime_defaults.duplicate(true),
	}


func has_capability(cap: StringName) -> bool:
	return cap in capabilities


func validation_errors(object_ids: Dictionary, zone_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("Fixture has an empty id")
	# Capabilities must be known.
	for cap in capabilities:
		if not (cap in KNOWN_CAPABILITIES):
			errors.append("Fixture %s has unknown capability: %s" % [id, cap])
	if capabilities.is_empty():
		errors.append("Fixture %s has no capabilities" % id)
	# visual_object must reference an existing object, if non-empty.
	if visual_object_id != "" and not object_ids.has(visual_object_id):
		errors.append("Fixture %s references unknown visual object: %s" % [id, visual_object_id])
	# owner_zone must reference an existing zone, if non-empty.
	if owner_zone_id != &"" and not zone_ids.has(owner_zone_id):
		errors.append("Fixture %s references unknown place zone: %s" % [id, owner_zone_id])
	# Validate runtime_defaults schema per capability.
	if has_capability(CAP_FIRE_SOURCE):
		var fire_errors := FireSourceDefaultsScript.validate(runtime_defaults)
		for e in fire_errors:
			errors.append("Fixture %s: %s" % [id, e])
	return errors
