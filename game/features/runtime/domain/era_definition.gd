class_name EraDefinition
extends RefCounted

## One authored progression stage of a game. The host and generic world treat
## the id as opaque data; the gameplay module interprets tags, technology roots
## and transition rules.

var id: StringName = &""
var names: Dictionary = {}
var descriptions: Dictionary = {}
var icon: StringName = &""
var tags: Array[StringName] = []
var technology_roots: Array[StringName] = []
var next_eras: Array[StringName] = []
var transition: Dictionary = {}


static func from_dict(source: Dictionary) -> EraDefinition:
	var definition := EraDefinition.new()
	definition.id = StringName(source.get("id", ""))
	definition.names = _localized_dict(source.get("name", {}))
	definition.descriptions = _localized_dict(source.get("description", {}))
	definition.icon = StringName(source.get("icon", ""))
	for value: Variant in source.get("tags", []):
		definition.tags.append(StringName(value))
	for value: Variant in source.get("technology_roots", []):
		definition.technology_roots.append(StringName(value))
	for value: Variant in source.get("next", []):
		definition.next_eras.append(StringName(value))
	var authored_transition: Variant = source.get("transition", {})
	if authored_transition is Dictionary:
		definition.transition = (authored_transition as Dictionary).duplicate(true)
	return definition if not definition.id.is_empty() else null


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": names.duplicate(true),
		"description": descriptions.duplicate(true),
		"icon": String(icon),
		"tags": tags.map(func(value: StringName) -> String: return String(value)),
		"technology_roots": technology_roots.map(func(value: StringName) -> String: return String(value)),
		"next": next_eras.map(func(value: StringName) -> String: return String(value)),
		"transition": transition.duplicate(true),
	}


func display_name(locale := "") -> String:
	return _localized_value(names, locale, String(id))


func display_description(locale := "") -> String:
	return _localized_value(descriptions, locale, "")


static func _localized_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is String and not (value as String).is_empty():
		return {"en": value}
	return {}


static func _localized_value(values: Dictionary, locale: String, fallback: String) -> String:
	var requested := locale if not locale.is_empty() else TranslationServer.get_locale()
	if values.has(requested):
		return String(values[requested])
	var language := requested.get_slice("_", 0)
	if values.has(language):
		return String(values[language])
	if values.has("en"):
		return String(values["en"])
	if not values.is_empty():
		return String(values[values.keys()[0]])
	return fallback
