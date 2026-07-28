class_name MapEntityRuntime
extends RefCounted

## Session-side records created from a map's named entities.  This is the sole
## bridge from authored placement to gameplay modules; neither presenter nor map
## editor owns live state.

class RuntimeEntity:
	extends RefCounted
	var id: StringName = &""
	var archetype: EntityArchetype = null
	var position := Vector3.ZERO
	var yaw_degrees := 0.0
	var scale := 1.0
	var state: StringName = EntityStateSet.FOLLOW_SEASON
	var props: Dictionary = {}

var _entities: Dictionary = {}


func load_map(document: MapDocument) -> void:
	_entities.clear()
	if document == null:
		return
	for placed: MapEntityRecord in document.entities.entities:
		var archetype := EntityArchetypeCatalog.get_archetype(placed.archetype_id)
		if archetype == null:
			continue
		var entity := RuntimeEntity.new()
		entity.id = placed.id
		entity.archetype = archetype
		entity.position = placed.position
		entity.yaw_degrees = placed.yaw_degrees
		entity.scale = placed.scale
		entity.state = placed.initial_state
		entity.props = archetype.resolved_properties(placed.props)
		_entities[entity.id] = entity


func all() -> Array[RuntimeEntity]:
	var result: Array[RuntimeEntity] = []
	for entity: RuntimeEntity in _entities.values():
		result.append(entity)
	result.sort_custom(func(left: RuntimeEntity, right: RuntimeEntity) -> bool: return String(left.id) < String(right.id))
	return result


func by_id(entity_id: StringName) -> RuntimeEntity:
	return _entities.get(entity_id, null)
