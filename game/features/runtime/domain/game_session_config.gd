class_name GameSessionConfig
extends RefCounted

## One launch request. Game-specific values live inside module_parameters; this
## record deliberately does not know eras, citizens, resources, or professions.

var definition: GameDefinition = null
var map_ref: StringName = &""
var map_document: MapDocument = null
var seed := 0
var module_parameters: Dictionary = {}
## Transitional input only. It lets the existing settlement module retain its
## tested start rules while launch ownership moves to the generic runtime.
var legacy_settlement_launch: GameLaunchConfig = null


static func from_settlement_launch(config: GameLaunchConfig, definition: GameDefinition) -> GameSessionConfig:
	var session := GameSessionConfig.new()
	session.definition = definition
	session.map_ref = config.map_ref
	session.map_document = config.map_document
	session.legacy_settlement_launch = config
	session.module_parameters[&"gth.settlement"] = {
		"era": String(config.era_id),
		"starting_money": config.starting_money,
		"starting_wellbeing": config.starting_wellbeing,
		"starting_population": config.starting_population,
	}
	return session
