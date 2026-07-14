class_name AIFactSet
extends RefCounted

## Immutable, namespaced facts used at domain boundaries. Systems should expose
## stable facts here instead of handing scene nodes to goals and order providers.

var _values: Dictionary


func _init(values: Dictionary = {}) -> void:
	_values = values.duplicate(true)


func has(key: StringName) -> bool:
	return _values.has(key)


func value(key: StringName, default_value: Variant = null) -> Variant:
	return _values.get(key, default_value)


func with_value(key: StringName, next_value: Variant) -> AIFactSet:
	var next := _values.duplicate(true)
	next[key] = next_value
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
