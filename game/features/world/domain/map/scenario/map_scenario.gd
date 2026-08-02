class_name MapScenario
extends RefCounted

## The authored scenario layer of a map: declared flags, the rule table, and the
## conditions that end the session (map_editor.md §10).
##
## This class replaces the passthrough that `MapDocument` used to give
## `flags` / `rules` / `victory` / `defeat`. It owns the four sections together
## because they are one thing an author edits as one thing: a rule sets a flag,
## victory reads it, and the validator has to see both to say the reference is
## live.
##
## Nothing here is game-specific and nothing here executes. `MapScenarioRuntime`
## runs it; the editor's scenario mode edits it; `MapValidator` checks it.

var flags: Array[MapFlagDef] = []
var rules: Array[MapRule] = []
## Ways to win. Each entry is a condition; the session is won when any of them
## holds — "any" rather than "all" because a map with two objectives usually
## offers a choice, and an author who means "both" writes one `all` group.
var victory: Array[MapRuleCondition] = []
var defeat: Array[MapRuleCondition] = []

const SECTION_FLAGS := "flags"
const SECTION_RULES := "rules"
const SECTION_VICTORY := "victory"
const SECTION_DEFEAT := "defeat"
const SECTIONS: Array[String] = [SECTION_FLAGS, SECTION_RULES, SECTION_VICTORY, SECTION_DEFEAT]


func is_empty() -> bool:
	return flags.is_empty() and rules.is_empty() and victory.is_empty() and defeat.is_empty()


func clear() -> void:
	flags.clear()
	rules.clear()
	victory.clear()
	defeat.clear()


# --- Lookups ------------------------------------------------------------------

func flag_by_id(flag_id: StringName) -> MapFlagDef:
	for flag: MapFlagDef in flags:
		if flag.id == flag_id:
			return flag
	return null


func has_flag(flag_id: StringName) -> bool:
	return flag_by_id(flag_id) != null


func rule_by_id(rule_id: StringName) -> MapRule:
	for rule: MapRule in rules:
		if rule.id == rule_id:
			return rule
	return null


func has_rule(rule_id: StringName) -> bool:
	return rule_by_id(rule_id) != null


## Starting values of every declared flag — what a session's flag table begins
## as, and what the editor shows as the scenario's initial state.
func default_flag_values() -> Dictionary:
	var values: Dictionary = {}
	for flag: MapFlagDef in flags:
		values[flag.id] = flag.default_value
	return values


## Every flag id any rule, victory or defeat expression mentions. The validator
## subtracts the declared ones from this to find the typos.
func referenced_flags() -> Array[StringName]:
	var names: Array[StringName] = []
	for rule: MapRule in rules:
		names.append_array(rule.referenced_flags())
	for condition: MapRuleCondition in victory + defeat:
		names.append_array(condition.referenced_flags())
	return names


## Follows a zone through a rename in the zones mode. An id is what a rule
## addresses a zone by (`active_zones.md` §6), so renaming an area without this
## turns every rule pointing at it into a rule that never fires — the one failure
## an author cannot see from inside the game. Returns how many rules moved.
func rename_zone(from_id: StringName, to_id: StringName) -> int:
	var moved := 0
	for rule: MapRule in rules:
		if rule.trigger.addresses_zone() and rule.trigger.zone == from_id:
			rule.trigger.zone = to_id
			moved += 1
	return moved


## Zone ids the rule table addresses, so the validator can check they still
## exist after an author deletes an area.
func referenced_zones() -> Array[StringName]:
	var names: Array[StringName] = []
	for rule: MapRule in rules:
		if rule.trigger.addresses_zone() and rule.trigger.zone != &"":
			names.append(rule.trigger.zone)
	return names


# --- JSON ---------------------------------------------------------------------

## Reads the four sections out of `map.json`. Any of them may be absent: a map
## authored before scenarios existed simply has none, and that is a valid map.
static func from_json(source: Dictionary) -> MapScenario:
	var scenario := MapScenario.new()
	var raw_flags: Variant = source.get(SECTION_FLAGS, {})
	if raw_flags is Dictionary:
		for key: Variant in raw_flags as Dictionary:
			var entry: Variant = (raw_flags as Dictionary)[key]
			scenario.flags.append(MapFlagDef.from_dict(
				StringName(key), entry if entry is Dictionary else {}))
	for entry: Variant in _as_array(source.get(SECTION_RULES, [])):
		if entry is Dictionary:
			scenario.rules.append(MapRule.from_dict(entry as Dictionary))
	for entry: Variant in _as_array(source.get(SECTION_VICTORY, [])):
		if entry is Dictionary:
			scenario.victory.append(MapRuleCondition.from_dict(entry as Dictionary))
	for entry: Variant in _as_array(source.get(SECTION_DEFEAT, [])):
		if entry is Dictionary:
			scenario.defeat.append(MapRuleCondition.from_dict(entry as Dictionary))
	return scenario


## The four sections, always written even when empty — the same promise the rest
## of the format makes, so a map file reads the same whether or not its author
## ever opened the scenario mode.
func to_json() -> Dictionary:
	var flags_json: Dictionary = {}
	for flag: MapFlagDef in flags:
		flags_json[String(flag.id)] = flag.to_dict()
	var rules_json: Array = []
	for rule: MapRule in rules:
		rules_json.append(rule.to_dict())
	return {
		SECTION_FLAGS: flags_json,
		SECTION_RULES: rules_json,
		SECTION_VICTORY: _conditions_json(victory),
		SECTION_DEFEAT: _conditions_json(defeat),
	}


static func _conditions_json(conditions: Array[MapRuleCondition]) -> Array:
	var result: Array = []
	for condition: MapRuleCondition in conditions:
		result.append(condition.to_dict())
	return result


static func _as_array(value: Variant) -> Array:
	return value as Array if value is Array else []


# --- Structural validation ----------------------------------------------------

## Rules that need nothing but the scenario itself: duplicate and empty ids, and
## references to flags nobody declared. Reference checks that need the zone layer
## live in `MapValidator`, which has the whole document.
func validate() -> Array[String]:
	var errors: Array[String] = []
	var seen_flags: Dictionary = {}
	for flag: MapFlagDef in flags:
		if flag.id == &"":
			errors.append("флаг без имени")
		elif seen_flags.has(flag.id):
			errors.append("дубликат флага %s" % flag.id)
		seen_flags[flag.id] = true
	var seen_rules: Dictionary = {}
	for rule: MapRule in rules:
		if rule.id == &"":
			errors.append("правило без id")
		elif seen_rules.has(rule.id):
			errors.append("дубликат правила %s" % rule.id)
		seen_rules[rule.id] = true
	var reported: Dictionary = {}
	for flag_id: StringName in referenced_flags():
		if not seen_flags.has(flag_id) and not reported.has(flag_id):
			reported[flag_id] = true
			errors.append("правило ссылается на необъявленный флаг %s" % flag_id)
	return errors
