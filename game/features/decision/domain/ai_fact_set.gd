class_name AIFactSet
extends RefCounted

## Immutable, namespaced facts used at domain boundaries. Systems should expose
## stable facts here instead of handing scene nodes to goals and order providers.

var _values: Dictionary


func _init(values: Dictionary = {}) -> void:
	_values = _validated_values(values)


## Validates and copies a freshly built dictionary at the feature boundary.
## Snapshot construction may use this when it has already assembled all facts.
static func from_owned_values(values: Dictionary) -> AIFactSet:
	return _from_owned_values(_validated_values(values))


func has(key: StringName) -> bool:
	return _values.has(key)


func value(key: StringName, default_value: Variant = null) -> Variant:
	return _copy_value(_values.get(key, default_value))


func with_value(key: StringName, next_value: Variant) -> AIFactSet:
	var next := _values.duplicate(true)
	if not is_value_safe(next_value):
		push_error("AIFactSet only accepts value-only facts")
		return _from_owned_values(next)
	next[key] = _copy_value(next_value)
	return _from_owned_values(next)


func merged(other: AIFactSet) -> AIFactSet:
	var next := _values.duplicate(true)
	if other != null:
		next.merge(other._values, true)
	return _from_owned_values(next)


func to_dictionary() -> Dictionary:
	return _values.duplicate(true)


func is_equal_to(other: AIFactSet) -> bool:
	return other != null and _values == other._values


static func _from_owned_values(values: Dictionary) -> AIFactSet:
	var facts := AIFactSet.new()
	facts._values = values
	return facts


## Facts cross a deterministic, saveable boundary. Keep mutable engine objects,
## callbacks and opaque runtime handles out of snapshots and order payloads.
static func is_value_safe(value: Variant) -> bool:
	if value is Object or value is Callable or value is Signal or value is RID:
		return false
	if value is Array:
		for item in value:
			if not is_value_safe(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not is_value_safe(key) or not is_value_safe(value[key]):
				return false
		return true
	return true


static func _validated_values(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in values:
		if not key is StringName or not is_value_safe(values[key]):
			push_error("AIFactSet facts require StringName keys and value-only data")
			continue
		result[key] = _copy_value(values[key])
	return result


static func _copy_value(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
