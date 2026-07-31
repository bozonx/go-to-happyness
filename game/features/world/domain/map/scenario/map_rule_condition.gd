class_name MapRuleCondition
extends RefCounted

## One `if` test of a rule, and the same expression victory and defeat are built
## from (map_editor.md §10.3).
##
## Every condition in this phase is a test over a declared flag. That is not a
## placeholder for a richer expression language — it is the boundary that keeps
## the rule engine game-neutral: the moment a condition reads `resource >= 10`,
## the map format knows what a resource is, and a shooter map carries a field
## about grain. Anything a game wants to test is published into a flag by that
## game, through the extension seam in `MapScenarioRuntime`.
##
## Groups are `all` / `any` over nested conditions, so victory can say
## "boss dead AND extraction reached" without a parser.

const OP_EQ := &"eq"
const OP_NE := &"ne"
const OP_GE := &"ge"
const OP_LE := &"le"
const OP_GT := &"gt"
const OP_LT := &"lt"
const OPS: Array[StringName] = [OP_EQ, OP_NE, OP_GE, OP_LE, OP_GT, OP_LT]

const GROUP_ALL := &"all"
const GROUP_ANY := &"any"

var flag: StringName = &""
var op: StringName = OP_EQ
var value: Variant = true
## `all` / `any` when this node is a group; empty for a leaf test.
var group: StringName = &""
var children: Array[MapRuleCondition] = []
## Kept verbatim so a condition this build does not understand survives a
## round-trip through the editor instead of being silently dropped.
var raw: Dictionary = {}


static func flag_is(flag_id: StringName, expected: Variant = true, operator := OP_EQ) -> MapRuleCondition:
	var condition := MapRuleCondition.new()
	condition.flag = flag_id
	condition.op = operator
	condition.value = expected
	return condition


static func all_of(nested: Array[MapRuleCondition]) -> MapRuleCondition:
	return _group(GROUP_ALL, nested)


static func any_of(nested: Array[MapRuleCondition]) -> MapRuleCondition:
	return _group(GROUP_ANY, nested)


static func _group(kind: StringName, nested: Array[MapRuleCondition]) -> MapRuleCondition:
	var condition := MapRuleCondition.new()
	condition.group = kind
	condition.children = nested.duplicate()
	return condition


static func from_dict(source: Dictionary) -> MapRuleCondition:
	var condition := MapRuleCondition.new()
	condition.raw = source.duplicate(true)
	for kind: StringName in [GROUP_ALL, GROUP_ANY]:
		if source.has(kind) and source[kind] is Array:
			condition.group = kind
			for entry: Variant in source[kind] as Array:
				if entry is Dictionary:
					condition.children.append(from_dict(entry as Dictionary))
			return condition
	condition.flag = StringName(source.get("flag", ""))
	condition.op = StringName(source.get("op", OP_EQ))
	if condition.op not in OPS:
		condition.op = OP_EQ
	condition.value = source.get("value", true)
	return condition


func to_dict() -> Dictionary:
	if not is_known():
		return raw.duplicate(true)
	if is_group():
		var nested: Array = []
		for child: MapRuleCondition in children:
			nested.append(child.to_dict())
		return {String(group): nested}
	return {"flag": String(flag), "op": String(op), "value": value}


func is_group() -> bool:
	return group == GROUP_ALL or group == GROUP_ANY


## A leaf that names no flag is a condition from a future build (or a typo in a
## hand-written file). It round-trips, and it never blocks: refusing to satisfy
## it would silently disable every rule that carries it.
func is_known() -> bool:
	return is_group() or flag != &""


## Evaluates against the current flag values. An unknown condition answers true
## so an old build running a newer map degrades to "the rule fires" rather than
## "nothing in this scenario ever happens".
func is_satisfied(flags: Dictionary) -> bool:
	if is_group():
		for child: MapRuleCondition in children:
			var child_ok := child.is_satisfied(flags)
			if group == GROUP_ALL and not child_ok:
				return false
			if group == GROUP_ANY and child_ok:
				return true
		return group == GROUP_ALL
	if not is_known():
		return true
	var current: Variant = flags.get(flag, false)
	match op:
		OP_EQ: return _as_number(current) == _as_number(value)
		OP_NE: return _as_number(current) != _as_number(value)
		OP_GE: return _as_number(current) >= _as_number(value)
		OP_LE: return _as_number(current) <= _as_number(value)
		OP_GT: return _as_number(current) > _as_number(value)
		OP_LT: return _as_number(current) < _as_number(value)
	return false


## Comparing through numbers makes `flag: alarm, op: eq, value: true` work whether
## `alarm` is a boolean or a counter that reached 1. Ordered operators on a
## boolean then mean what an author would expect rather than erroring.
static func _as_number(value: Variant) -> float:
	if value is bool:
		return 1.0 if value else 0.0
	if value is int or value is float:
		return float(value)
	if value is String:
		var text := String(value).to_lower()
		if text in ["true", "да"]:
			return 1.0
		if text in ["false", "нет"]:
			return 0.0
		return float(text) if text.is_valid_float() else 0.0
	return 0.0


## Flags this condition reads, for the validator. Includes nested groups.
func referenced_flags() -> Array[StringName]:
	var names: Array[StringName] = []
	if is_group():
		for child: MapRuleCondition in children:
			names.append_array(child.referenced_flags())
	elif flag != &"":
		names.append(flag)
	return names
