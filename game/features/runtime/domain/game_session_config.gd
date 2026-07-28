class_name GameSessionConfig
extends RefCounted

## One launch request. Game-specific values live inside module_parameters; this
## record deliberately does not know eras, citizens, resources, or professions.

var definition: GameDefinition = null
var map_ref: StringName = &""
var map_document: MapDocument = null
var seed := 0
var module_parameters: Dictionary = {}


static func from_settlement_launch(config: GameLaunchConfig, definition: GameDefinition) -> GameSessionConfig:
	var session := GameSessionConfig.new()
	session.definition = definition
	session.map_ref = config.map_ref
	session.map_document = config.map_document
	session.module_parameters[&"gth.settlement"] = settlement_parameters_from(config)
	return session


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


static func settlement_parameters_from(config: GameLaunchConfig) -> Dictionary:
	if config == null:
		return {}
	return {
		"era": String(config.era_id),
		"era_type": config.era_type,
		"biome": String(config.biome_id),
		"world_style": String(config.world_style),
		"starting_money": config.starting_money,
		"starting_wellbeing": config.starting_wellbeing,
		"starting_population": config.starting_population,
		"starting_resources": config.starting_resources.duplicate(true),
		"starting_equipment": config.starting_equipment.duplicate(true),
		"custom_parameters": config.custom_parameters.duplicate(true),
	}
