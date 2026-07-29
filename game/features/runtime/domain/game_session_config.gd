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
	session.module_parameters = p_module_parameters.duplicate(true)
	return session
