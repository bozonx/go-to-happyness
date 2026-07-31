class_name MapRule
extends RefCounted

## One `when / if / then` row of a scenario (map_editor.md §10).
##
## Pure data. It does not know what fired it, what a flag is worth or who reads
## the message it produces — `MapScenarioRuntime` owns all of that. Keeping the
## row inert is what lets the editor list, edit and validate scenarios without
## starting a session.

var id: StringName = &""
var enabled := true
## Fires at most once per session when true — the usual case for an ambush, a
## briefing or an objective.
var once := true
var trigger: MapRuleTrigger = MapRuleTrigger.new()
var conditions: Array[MapRuleCondition] = []
var actions: Array[MapRuleAction] = []
## Keys a newer build wrote that this one does not model, so editing an old rule
## in a new editor (or the reverse) never truncates it.
var extra: Dictionary = {}

const _KNOWN_KEYS: Array[String] = ["id", "enabled", "once", "when", "if", "then"]


static func create(rule_id: StringName, rule_trigger: MapRuleTrigger) -> MapRule:
	var rule := MapRule.new()
	rule.id = rule_id
	rule.trigger = rule_trigger
	return rule


static func from_dict(source: Dictionary) -> MapRule:
	var rule := MapRule.new()
	rule.id = StringName(source.get("id", ""))
	rule.enabled = bool(source.get("enabled", true))
	rule.once = bool(source.get("once", true))
	var raw_when: Variant = source.get("when", {})
	rule.trigger = MapRuleTrigger.from_dict(raw_when if raw_when is Dictionary else {})
	for entry: Variant in source.get("if", []):
		if entry is Dictionary:
			rule.conditions.append(MapRuleCondition.from_dict(entry as Dictionary))
	for entry: Variant in source.get("then", []):
		if entry is Dictionary:
			rule.actions.append(MapRuleAction.from_dict(entry as Dictionary))
	for key: String in source:
		if key not in _KNOWN_KEYS:
			rule.extra[key] = source[key]
	return rule


func to_dict() -> Dictionary:
	var conditions_json: Array = []
	for condition: MapRuleCondition in conditions:
		conditions_json.append(condition.to_dict())
	var actions_json: Array = []
	for action: MapRuleAction in actions:
		actions_json.append(action.to_dict())
	var result := {
		"id": String(id),
		"enabled": enabled,
		"once": once,
		"when": trigger.to_dict(),
		"if": conditions_json,
		"then": actions_json,
	}
	for key: String in extra:
		if not result.has(key):
			result[key] = extra[key]
	return result


## Whether every `if` holds for the given flag values. An empty list is
## unconditional — the rule is its trigger.
func conditions_hold(flags: Dictionary) -> bool:
	for condition: MapRuleCondition in conditions:
		if not condition.is_satisfied(flags):
			return false
	return true


func referenced_flags() -> Array[StringName]:
	var names: Array[StringName] = []
	if trigger.flag != &"":
		names.append(trigger.flag)
	for condition: MapRuleCondition in conditions:
		names.append_array(condition.referenced_flags())
	for action: MapRuleAction in actions:
		if action.writes_flag() and action.flag != &"":
			names.append(action.flag)
	return names


func describe() -> String:
	var parts: Array[String] = [trigger.describe()]
	if not conditions.is_empty():
		parts.append("если %d усл." % conditions.size())
	parts.append("→ %d действ." % actions.size())
	return " · ".join(parts)
