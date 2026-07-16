class_name EventCondition
extends RefCounted

## A precondition that must be satisfied for an event to be eligible.
## Pure data — evaluated against an EventContext snapshot.

enum ConditionKind {
	ERA_IS,
	WEATHER_IS,
	RESOURCE_AT_LEAST,
	RESOURCE_AT_MOST,
	FLAG_SET,
	FLAG_NOT_SET,
	DAY_AT_LEAST,
	POPULATION_AT_LEAST,
}

var kind: int = ConditionKind.ERA_IS
var resource: String = ""
var value: int = 0
var era: int = 0
var weather: int = 0
var flag: StringName = &""
var min_day: int = 0
var min_population: int = 0


const _script = preload("res://game/features/events/domain/event_condition.gd")


static func era_is(p_era: int) -> RefCounted:
	var c: RefCounted = _script.new()
	c.kind = ConditionKind.ERA_IS
	c.era = p_era
	return c


static func weather_is(p_weather: int) -> RefCounted:
	var c: RefCounted = _script.new()
	c.kind = ConditionKind.WEATHER_IS
	c.weather = p_weather
	return c


static func resource_at_least(res: String, amount: int) -> RefCounted:
	var c: RefCounted = _script.new()
	c.kind = ConditionKind.RESOURCE_AT_LEAST
	c.resource = res
	c.value = amount
	return c


static func resource_at_most(res: String, amount: int) -> RefCounted:
	var c: RefCounted = _script.new()
	c.kind = ConditionKind.RESOURCE_AT_MOST
	c.resource = res
	c.value = amount
	return c


static func flag_set(flag_name: StringName) -> RefCounted:
	var c: RefCounted = _script.new()
	c.kind = ConditionKind.FLAG_SET
	c.flag = flag_name
	return c


static func flag_not_set(flag_name: StringName) -> RefCounted:
	var c: RefCounted = _script.new()
	c.kind = ConditionKind.FLAG_NOT_SET
	c.flag = flag_name
	return c


static func day_at_least(day: int) -> RefCounted:
	var c: RefCounted = _script.new()
	c.kind = ConditionKind.DAY_AT_LEAST
	c.min_day = day
	return c


static func population_at_least(pop: int) -> RefCounted:
	var c: RefCounted = _script.new()
	c.kind = ConditionKind.POPULATION_AT_LEAST
	c.min_population = pop
	return c


func is_satisfied(context: EventContext) -> bool:
	match kind:
		ConditionKind.ERA_IS:
			return context.era == era
		ConditionKind.WEATHER_IS:
			return context.weather == weather
		ConditionKind.RESOURCE_AT_LEAST:
			return int(context.resources.get(resource, 0)) >= value
		ConditionKind.RESOURCE_AT_MOST:
			return int(context.resources.get(resource, 0)) <= value
		ConditionKind.FLAG_SET:
			return context.flags.has(flag)
		ConditionKind.FLAG_NOT_SET:
			return not context.flags.has(flag)
		ConditionKind.DAY_AT_LEAST:
			return context.day >= min_day
		ConditionKind.POPULATION_AT_LEAST:
			return context.population >= min_population
	return false
