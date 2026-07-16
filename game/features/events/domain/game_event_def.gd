class_name GameEventDef
extends RefCounted

## Data-driven definition of a random event. Pure data — no logic, no nodes.
## The EventService filters, selects, and applies events based on these defs.

var id: StringName = &""
var title: String = ""
var description: String = ""
var era: int = 0
var weight: float = 1.0
var cooldown_days: int = 2
var conditions: Array[EventCondition] = []
var choices: Array[EventChoiceDef] = []
var chain_flag: StringName = &""
var sets_flag: StringName = &""


static func create(
		p_id: StringName,
		p_title: String,
		p_description: String,
		p_era: int,
		p_choices: Array[EventChoiceDef],
		p_conditions: Array[EventCondition] = [],
		p_weight: float = 1.0,
		p_cooldown_days: int = 2,
		p_chain_flag: StringName = &"",
		p_sets_flag: StringName = &"",
) -> GameEventDef:
	var d := GameEventDef.new()
	d.id = p_id
	d.title = p_title
	d.description = p_description
	d.era = p_era
	d.choices = p_choices.duplicate()
	d.conditions = p_conditions.duplicate()
	d.weight = p_weight
	d.cooldown_days = p_cooldown_days
	d.chain_flag = p_chain_flag
	d.sets_flag = p_sets_flag
	return d


func is_eligible(context: EventContext, log: EventLog) -> bool:
	if context.era != era:
		return false
	if chain_flag != &"" and not log.has_flag(chain_flag):
		return false
	if log.is_on_cooldown(id, context.day, cooldown_days):
		return false
	for condition in conditions:
		if not condition.is_satisfied(context):
			return false
	return true
