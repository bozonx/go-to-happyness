class_name MapZoneService
extends RefCounted

## Stateless facade over `MapZoneRegistry` (active_zones.md §13).
##
## The map-side peer of `BuildingZoneService`: where the building service bridges
## room state to the simulation, this one bridges map-region state to the rules a
## future phase will author. Everything delegates to the registry so there is one
## owner of session state; the service exists so callers never hold the registry
## directly, the same separation the building side keeps.
##
## Smaller than its building counterpart by design: a map region owns no slots,
## has no work positions and nothing to reconcile, so the whole staffing half of
## `BuildingZoneService` has no analogue here. What remains is owner and flags —
## capture a point, mark a region cleared, count waves left — exactly the
## vocabulary §13 promises a scenario needs on its first step.

var _registry: MapZoneRegistry = null


func configure(registry: MapZoneRegistry) -> void:
	_registry = registry


func owner_of(zone_id: StringName) -> StringName:
	return _registry.owner_of(zone_id)


func set_owner(zone_id: StringName, owner_tag: StringName) -> bool:
	return _registry.set_owner(zone_id, owner_tag)


func flag_of(zone_id: StringName, key: StringName, fallback: Variant = null) -> Variant:
	return _registry.flag_of(zone_id, key, fallback)


func set_flag(zone_id: StringName, key: StringName, value: Variant) -> bool:
	return _registry.set_flag(zone_id, key, value)


func is_owned_by(zone_id: StringName, agent_tags: Array) -> bool:
	return _registry.is_owned_by(zone_id, agent_tags)
