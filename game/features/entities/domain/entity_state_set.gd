class_name EntityStateSet
extends RefCounted

## The state dictionary of an archetype (design_docs/engine/map_fill_mode.md §6.1).
##
## **The runtime owns the transitions, not the author.** The author picks a
## starting state, and by default that pick is "follow the season": a map built in
## summer would otherwise still be green in January and force the author to
## replace the forest by hand. A state pinned explicitly is the exception, and the
## inspector marks it as pinned so it is obvious why one spruce stayed green.

## The default that means "the runtime decides from the season". It is a value of
## `default_state`, not a state of its own — nothing can be *in* it.
const FOLLOW_SEASON := &"seasonal"

var default_state: StringName = FOLLOW_SEASON
var states: Array[EntityStateDef] = []
## `{"season": {"winter": "snowy", ...}}` — which state each value of a runtime
## axis maps to. Authors read it; only the runtime acts on it.
var transitions: Dictionary = {}


func is_empty() -> bool:
	return states.is_empty()


func has_state(state_id: StringName) -> bool:
	for state: EntityStateDef in states:
		if state.id == state_id:
			return true
	return false


func get_state(state_id: StringName) -> EntityStateDef:
	for state: EntityStateDef in states:
		if state.id == state_id:
			return state
	return null


func state_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for state: EntityStateDef in states:
		ids.append(state.id)
	return ids


## Whether a record may declare this as its starting state. `seasonal` is always
## allowed — an archetype with no states at all still follows the season, it just
## has nothing to show for it.
func allows_initial_state(state_id: StringName) -> bool:
	return state_id == FOLLOW_SEASON or has_state(state_id)


## The state a given value of an axis resolves to, or `&""` when the archetype
## declares no mapping for it. Reading it here rather than in the runtime keeps
## the season rule in the data where the author can see it.
func state_for(axis: StringName, value: StringName) -> StringName:
	var raw_axis: Variant = transitions.get(String(axis), null)
	if not (raw_axis is Dictionary):
		return &""
	var resolved := StringName((raw_axis as Dictionary).get(String(value), ""))
	return resolved if has_state(resolved) else &""


func to_dict() -> Dictionary:
	var list: Array = []
	for state: EntityStateDef in states:
		list.append(state.to_dict())
	var result: Dictionary = {"default": String(default_state), "list": list}
	if not transitions.is_empty():
		result["transitions"] = transitions.duplicate(true)
	return result


static func from_dict(source: Dictionary) -> EntityStateSet:
	var set := EntityStateSet.new()
	var raw_list: Variant = source.get("list", null)
	if raw_list is Array:
		for raw_state: Variant in raw_list as Array:
			if not (raw_state is Dictionary):
				continue
			var state := EntityStateDef.from_dict(raw_state as Dictionary)
			if state.id != &"" and not set.has_state(state.id):
				set.states.append(state)
	var raw_transitions: Variant = source.get("transitions", null)
	if raw_transitions is Dictionary:
		set.transitions = (raw_transitions as Dictionary).duplicate(true)
	# A default naming a state this archetype does not declare would silently pin
	# every placed object to nothing. Falling back to the season keeps the map
	# alive instead.
	var declared := StringName(source.get("default", FOLLOW_SEASON))
	set.default_state = declared if set.allows_initial_state(declared) else FOLLOW_SEASON
	return set
