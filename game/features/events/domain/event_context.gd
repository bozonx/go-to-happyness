class_name EventContext
extends RefCounted

## Immutable snapshot of game state passed to conditions and outcomes.
## Built by application code before rolling or resolving events.

var era: int = 0
var day: int = 1
var weather: int = 0
var resources: Dictionary = {}
var wellbeing: int = 75
var population: int = 0
var flags: Dictionary = {}


static func create(
		p_era: int,
		p_day: int,
		p_weather: int,
		p_resources: Dictionary,
		p_wellbeing: int,
		p_population: int,
		p_flags: Dictionary,
) -> EventContext:
	var ctx := EventContext.new()
	ctx.era = p_era
	ctx.day = p_day
	ctx.weather = p_weather
	ctx.resources = p_resources.duplicate()
	ctx.wellbeing = p_wellbeing
	ctx.population = p_population
	ctx.flags = p_flags.duplicate()
	return ctx
