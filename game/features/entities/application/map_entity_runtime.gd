class_name MapEntityRuntime
extends RefCounted

## Session-side records created from a map's named entities.  This is the sole
## bridge from authored placement to gameplay modules; neither presenter nor map
## editor owns live state.

signal entity_changed(entity_id: StringName, change: StringName)

class RuntimeEntity:
	extends RefCounted
	var id: StringName = &""
	var archetype: EntityArchetype = null
	var position := Vector3.ZERO
	var rotation_degrees := Vector3.ZERO
	var scale := 1.0
	var state: StringName = EntityStateSet.FOLLOW_SEASON
	var props: Dictionary = {}
	var appearance: Dictionary = {}
	var active := true
	var initial_state: StringName = EntityStateSet.FOLLOW_SEASON
	var initial_props: Dictionary = {}
	var initial_appearance: Dictionary = {}

var _entities: Dictionary = {}


## `start_option` is the entrance the session began at. An entity bound to a
## different one is not created at all (`map_start.md` §3.2) — that binding is
## what makes the cart at the north gate and the backpack at the south gate two
## real entrances rather than two copies of the map.
func load_map(document: MapDocument, terrain: TerrainGrid = null, start_option: StringName = &"") -> void:
	_entities.clear()
	if document == null:
		return
	for placed: MapEntityRecord in document.entities.entities:
		if not placed.belongs_to_start(start_option):
			continue
		var archetype := EntityArchetypeCatalog.get_archetype(placed.archetype_id)
		if archetype == null:
			continue
		var entity := RuntimeEntity.new()
		entity.id = placed.id
		entity.archetype = archetype
		entity.position = placed.position
		# Map transforms store a local vertical offset above the terrain, not an
		# absolute world Y. This keeps authored objects attached when the terrain
		# under them is edited and makes launch independent of mesh/physics timing.
		if terrain != null:
			entity.position.y = terrain.height_at(placed.position) + placed.position.y
		entity.rotation_degrees = Vector3(placed.pitch_degrees, placed.yaw_degrees, placed.roll_degrees)
		entity.scale = placed.scale
		entity.state = placed.initial_state
		entity.props = archetype.resolved_properties(placed.props)
		entity.appearance = placed.appearance.duplicate(true)
		entity.initial_state = entity.state
		entity.initial_props = entity.props.duplicate(true)
		entity.initial_appearance = entity.appearance.duplicate(true)
		_entities[entity.id] = entity


func all() -> Array[RuntimeEntity]:
	var result: Array[RuntimeEntity] = []
	for entity: RuntimeEntity in _entities.values():
		result.append(entity)
	result.sort_custom(func(left: RuntimeEntity, right: RuntimeEntity) -> bool: return String(left.id) < String(right.id))
	return result


func by_id(entity_id: StringName) -> RuntimeEntity:
	return _entities.get(entity_id, null)


## Navigation obstacles are derived from the same asset footprint the editors
## validate. Physical CollisionShape3D nodes are deliberately irrelevant here:
## routing and physics are separate contracts.
func navigation_blocked_cells(terrain: TerrainGrid) -> Dictionary:
	var blocked: Dictionary = {}
	if terrain == null:
		return blocked
	for entity: RuntimeEntity in _entities.values():
		if not entity.active:
			continue
		var asset := EntityArchetypeCatalog.asset_of(entity.archetype.id)
		if asset == null or not asset.blocking_navigation:
			continue
		var span := asset.placement_cell_span(entity.scale, entity.rotation_degrees.y)
		var anchor_cell := terrain.cell_from_position(entity.position)
		var first := anchor_cell - Vector2i(span.x / 2, span.y / 2)
		for x in range(first.x, first.x + span.x):
			for z in range(first.y, first.y + span.y):
				var cell := Vector2i(x, z)
				if terrain.is_inside(cell):
					blocked[cell] = true
	return blocked


func deactivate(entity_id: StringName) -> bool:
	var entity := by_id(entity_id)
	if entity == null or not entity.active:
		return false
	entity.active = false
	entity_changed.emit(entity_id, &"active")
	return true


func activate(entity_id: StringName) -> bool:
	var entity := by_id(entity_id)
	if entity == null or entity.active:
		return false
	entity.active = true
	entity_changed.emit(entity_id, &"active")
	return true


func set_state(entity_id: StringName, next_state: StringName) -> bool:
	var entity := by_id(entity_id)
	if entity == null or not entity.archetype.states.allows_initial_state(next_state) or entity.state == next_state:
		return false
	entity.state = next_state
	entity_changed.emit(entity_id, &"state")
	return true


func set_property(entity_id: StringName, property_name: StringName, value: Variant) -> bool:
	var entity := by_id(entity_id)
	var definition := entity.archetype.get_property(property_name) if entity != null else null
	if definition == null:
		return false
	var next: Variant = definition.clamp_value(value)
	if entity.props.get(property_name, null) == next:
		return false
	entity.props[property_name] = next
	entity_changed.emit(entity_id, &"props")
	return true


func set_appearance(entity_id: StringName, property_name: StringName, value: Variant) -> bool:
	var entity := by_id(entity_id)
	var asset := EntityArchetypeCatalog.asset_of(entity.archetype.id) if entity != null else null
	var control := asset.get_control(String(property_name)) if asset != null else {}
	if control.is_empty():
		return false
	var definition := EntityPropertyDef.from_dict(control)
	var next: Variant = definition.clamp_value(value)
	if entity.appearance.get(property_name, control.get("default", null)) == next:
		return false
	entity.appearance[property_name] = next
	entity_changed.emit(entity_id, &"appearance")
	return true


func lifecycle_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for entity: RuntimeEntity in all():
		var entry: Dictionary = {}
		if not entity.active:
			entry["active"] = false
		if entity.state != entity.initial_state:
			entry["state"] = String(entity.state)
		if entity.props != entity.initial_props:
			entry["props"] = MapEntityRecord.json_safe(entity.props)
		if entity.appearance != entity.initial_appearance:
			entry["appearance"] = MapEntityRecord.json_safe(entity.appearance)
		if not entry.is_empty():
			result[entity.id] = entry
	return result


func restore_lifecycle(snapshot: Dictionary) -> void:
	for raw_id: Variant in snapshot:
		var entity := by_id(StringName(raw_id))
		var saved: Variant = snapshot[raw_id]
		if entity == null or not saved is Dictionary:
			continue
		entity.active = bool((saved as Dictionary).get("active", true))
		entity.state = StringName((saved as Dictionary).get("state", entity.state))
		var props: Variant = (saved as Dictionary).get("props", null)
		if props is Dictionary:
			entity.props = entity.archetype.resolved_properties(props as Dictionary)
		var appearance: Variant = (saved as Dictionary).get("appearance", null)
		if appearance is Dictionary:
			entity.appearance = (appearance as Dictionary).duplicate(true)
		entity_changed.emit(entity.id, &"props")
		entity_changed.emit(entity.id, &"state")
		entity_changed.emit(entity.id, &"appearance")
		entity_changed.emit(entity.id, &"active")
