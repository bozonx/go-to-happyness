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
	for module_id: Variant in p_module_parameters:
		var supplied: Variant = p_module_parameters[module_id]
		if supplied is Dictionary and session.module_parameters.get(module_id, {}) is Dictionary:
			var merged: Dictionary = (session.module_parameters[module_id] as Dictionary).duplicate(true)
			merged.merge(supplied as Dictionary, true)
			session.module_parameters[module_id] = merged
		else:
			session.module_parameters[module_id] = supplied.duplicate(true) if supplied is Dictionary else supplied
	return session


## Phase-A definitions have one flat `start` object. It belongs to the gameplay
## module(s), never to `core.world`; every launch route must apply it identically.
static func _default_module_parameters(definition: GameDefinition) -> Dictionary:
	var result := {}
	if definition == null or definition.start_parameters.is_empty():
		return result
	for module_id: StringName in definition.module_ids:
		if module_id != &"core.world":
			result[module_id] = definition.start_parameters.duplicate(true)
	return result
