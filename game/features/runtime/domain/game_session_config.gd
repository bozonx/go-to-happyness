class_name GameSessionConfig
extends RefCounted

## One launch request. Game-specific values live inside module_parameters; this
## record deliberately does not know eras, citizens, resources, or professions.

var definition: GameDefinition = null
var map_ref: StringName = &""
var map_document: MapDocument = null
var seed := 0
var module_parameters: Dictionary = {}


static func create(
	p_definition: GameDefinition,
	p_map_ref: StringName,
	p_map_document: MapDocument,
	p_module_parameters: Dictionary = {},
) -> GameSessionConfig:
	var session := GameSessionConfig.new()
	session.definition = p_definition
	session.map_ref = p_map_ref
	session.map_document = p_map_document
	session.module_parameters = _default_module_parameters(p_definition)
	if p_map_document != null:
		_merge_module_parameters(session.module_parameters, p_map_document.meta.start.module_settings)
	for module_id: Variant in p_module_parameters:
		var supplied: Variant = p_module_parameters[module_id]
		_merge_module_parameter(session.module_parameters, module_id, supplied)
	return session


static func _default_module_parameters(definition: GameDefinition) -> Dictionary:
	return definition.start_module_parameters.duplicate(true) if definition != null else {}


static func _merge_module_parameters(target: Dictionary, supplied: Dictionary) -> void:
	for module_id: Variant in supplied:
		_merge_module_parameter(target, module_id, supplied[module_id])


static func _merge_module_parameter(target: Dictionary, module_id: Variant, supplied: Variant) -> void:
	if supplied is Dictionary and target.get(module_id, {}) is Dictionary:
		var merged: Dictionary = (target.get(module_id, {}) as Dictionary).duplicate(true)
		_merge_dictionary(merged, supplied as Dictionary)
		target[module_id] = merged
	else:
		target[module_id] = supplied.duplicate(true) if supplied is Dictionary else supplied


static func _merge_dictionary(target: Dictionary, supplied: Dictionary) -> void:
	for key: Variant in supplied:
		var value: Variant = supplied[key]
		if value is Dictionary and target.get(key, {}) is Dictionary:
			var nested: Dictionary = (target.get(key, {}) as Dictionary).duplicate(true)
			_merge_dictionary(nested, value as Dictionary)
			target[key] = nested
		else:
			target[key] = value.duplicate(true) if value is Dictionary else value
