class_name ScenarioModeController
extends MapEditorMode

## The scenario mode of the territory editor (map_editor.md §5.6): declared flags,
## the rule table, and the conditions that win or lose the map.
##
## It is the one mode with no brush. Everything it edits is a list, so it uses the
## generic editor surfaces — the palette picks which of the four sections is
## open, the central workspace displays its rows, and the side inspector edits
## the selected row through `EntityPropertyDef`, exactly like an entity's
## properties. This controller remains the only behaviour and write owner; the
## workspace is only another view over its list API.
##
## **The start of a session is not edited here.** Day of year, weather, latitude
## and the game definition are properties of the map file with one owner already
## — the "Настройки старта" dialog — and a second surface writing the same fields
## is how two of them end up disagreeing.

const SECTION_RULES := &"rules"
const SECTION_FLAGS := &"flags"
const SECTION_VICTORY := &"victory"
const SECTION_DEFEAT := &"defeat"
const SECTIONS: Array[StringName] = [SECTION_RULES, SECTION_FLAGS, SECTION_VICTORY, SECTION_DEFEAT]

## What the selected list row is. A rule's conditions and actions are rows of the
## same list, indented under it, so one selection model covers all of them.
const PICK_NONE := &"none"
const PICK_RULE := &"rule"
const PICK_CONDITION := &"condition"
const PICK_ACTION := &"action"
const PICK_FLAG := &"flag"
## A condition of the victory/defeat expression, which has no owning rule.
const PICK_OUTCOME := &"outcome"

var _section: StringName = SECTION_RULES
var _selected := -1
## Row index → what it points at, rebuilt with the list.
var _rows: Array[Dictionary] = []


func _init() -> void:
	id = &"scenario"
	title = "Сценарий"
	icon = "📜"


func activate() -> void:
	_selected = -1
	_rebuild_rows()


func document_changed() -> void:
	_rebuild_rows()


func _scenario() -> MapScenario:
	return context.document.scenario if context != null and context.document != null else MapScenario.new()


# --- Palette: the four sections -----------------------------------------------

func palette_entries() -> Array:
	return [
		PaletteEntry.of(SECTION_RULES, "Правила"),
		PaletteEntry.of(SECTION_FLAGS, "Флаги"),
		PaletteEntry.of(SECTION_VICTORY, "Победа"),
		PaletteEntry.of(SECTION_DEFEAT, "Поражение"),
	]


func selected_palette_entry() -> StringName:
	return _section


func select_palette_entry(entry_id: StringName) -> void:
	if entry_id in SECTIONS and entry_id != _section:
		_section = entry_id
		_selected = -1
		_rebuild_rows()
		notify_ui_changed()


func tool_options() -> Array:
	var options: Array = []
	match _section:
		SECTION_RULES:
			options.append(ToolOption.of(&"add_rule", "＋ Правило", &"add"))
			options.append(ToolOption.of(&"add_condition", "＋ Условие", &"add", false, _picked_rule() == null))
			options.append(ToolOption.of(&"add_action", "＋ Действие", &"add", false, _picked_rule() == null))
		SECTION_FLAGS:
			options.append(ToolOption.of(&"add_flag_bool", "＋ Флаг", &"add"))
			options.append(ToolOption.of(&"add_flag_int", "＋ Счётчик", &"add"))
		SECTION_VICTORY, SECTION_DEFEAT:
			options.append(ToolOption.of(&"add_outcome", "＋ Условие", &"add", false, _scenario().flags.is_empty()))
	options.append(ToolOption.of(&"delete", "🗑 Удалить", &"edit", false, _selected < 0))
	return options


func activate_option(option_id: StringName) -> void:
	match option_id:
		&"add_rule": _add_rule()
		&"add_condition": _add_condition()
		&"add_action": _add_action()
		&"add_flag_bool": _add_flag(MapFlagDef.TYPE_BOOL)
		&"add_flag_int": _add_flag(MapFlagDef.TYPE_INT)
		&"add_outcome": _add_outcome_condition()
		&"delete": _delete_selected()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_DELETE:
		if _selected < 0:
			return false
		_delete_selected()
		return true
	return false


# --- The list -----------------------------------------------------------------

func list_title() -> String:
	match _section:
		SECTION_FLAGS: return "Флаги сценария"
		SECTION_VICTORY: return "Условия победы"
		SECTION_DEFEAT: return "Условия поражения"
	return "Правила"


func list_entries() -> Array[String]:
	var entries: Array[String] = []
	for row: Dictionary in _rows:
		entries.append(String(row["label"]))
	return entries


func empty_list_hint() -> String:
	match _section:
		SECTION_FLAGS: return "Флаг — состояние сценария. Объявите его, прежде чем на него ссылаться"
		SECTION_VICTORY: return "Победа — выражение над флагами. Сначала объявите флаг"
		SECTION_DEFEAT: return "Поражение — выражение над флагами. Сначала объявите флаг"
	return "Правило — «когда → если → тогда». Добавьте первое"


func selected_list_index() -> int:
	return _selected


func workspace_summary() -> String:
	var scenario := _scenario()
	return "%d правил · %d флагов · победа %d · поражение %d" % [
		scenario.rules.size(), scenario.flags.size(), scenario.victory.size(), scenario.defeat.size()]


func selected_zone_id() -> StringName:
	var rule := _picked_rule()
	if rule != null and rule.trigger.addresses_zone():
		return rule.trigger.zone
	return &""


func select_list_entry(index: int) -> void:
	_selected = index if index >= 0 and index < _rows.size() else -1
	notify_ui_changed()


## One row per editable object of the open section, flattened with the rule's own
## conditions and actions indented under it. Rebuilt whenever the layer changes,
## because every index in `_selected` points into this array.
func _rebuild_rows() -> void:
	_rows.clear()
	var scenario := _scenario()
	match _section:
		SECTION_RULES:
			for rule_index in scenario.rules.size():
				var rule := scenario.rules[rule_index]
				var mark := "" if rule.enabled else " (выкл)"
				_rows.append({
					"pick": PICK_RULE, "rule": rule_index, "child": -1,
					"label": "▶ %s%s · %s" % [rule.id, mark, rule.trigger.describe()],
				})
				for condition_index in rule.conditions.size():
					_rows.append({
						"pick": PICK_CONDITION, "rule": rule_index, "child": condition_index,
						"label": "      ? %s" % _condition_label(rule.conditions[condition_index]),
					})
				for action_index in rule.actions.size():
					_rows.append({
						"pick": PICK_ACTION, "rule": rule_index, "child": action_index,
						"label": "      → %s" % rule.actions[action_index].describe(),
					})
		SECTION_FLAGS:
			for flag_index in scenario.flags.size():
				var flag := scenario.flags[flag_index]
				_rows.append({
					"pick": PICK_FLAG, "rule": -1, "child": flag_index,
					"label": "%s %s = %s" % ["#" if flag.type == MapFlagDef.TYPE_INT else "•",
						flag.display_name(), flag.default_value],
				})
		SECTION_VICTORY, SECTION_DEFEAT:
			for condition_index in _outcome_conditions().size():
				_rows.append({
					"pick": PICK_OUTCOME, "rule": -1, "child": condition_index,
					"label": "? %s" % _condition_label(_outcome_conditions()[condition_index]),
				})
	if _selected >= _rows.size():
		_selected = _rows.size() - 1


func _outcome_conditions() -> Array[MapRuleCondition]:
	return _scenario().defeat if _section == SECTION_DEFEAT else _scenario().victory


static func _condition_label(condition: MapRuleCondition) -> String:
	if condition.is_group():
		return "группа %s (%d)" % [condition.group, condition.children.size()]
	if not condition.is_known():
		return "условие из другой версии"
	return "%s %s %s" % [condition.flag, condition.op, condition.value]


func _picked() -> Dictionary:
	return _rows[_selected] if _selected >= 0 and _selected < _rows.size() else {}


## The rule the selection belongs to, whether the selected row is the rule itself
## or one of its conditions and actions. This is what makes "＋ Условие" work
## while a condition is selected, rather than only while its rule is.
func _picked_rule() -> MapRule:
	var row := _picked()
	if row.is_empty() or int(row.get("rule", -1)) < 0:
		return null
	var index := int(row["rule"])
	return _scenario().rules[index] if index < _scenario().rules.size() else null


# --- Inspector ----------------------------------------------------------------

func inspector_lines() -> Array[String]:
	var scenario := _scenario()
	var lines: Array[String] = [
		"Флагов: %d · Правил: %d" % [scenario.flags.size(), scenario.rules.size()],
		"Победа: %d · Поражение: %d" % [scenario.victory.size(), scenario.defeat.size()],
	]
	if scenario.flags.is_empty() and _section != SECTION_FLAGS:
		lines.append("Условия читают флаги — объявите флаг во вкладке «Флаги»")
	var row := _picked()
	if not row.is_empty() and String(row["pick"]) == PICK_CONDITION and _picked_condition() != null \
			and not _picked_condition().is_known():
		lines.append("Это условие записано другой версией и правится только как есть")
	return lines


func inspector_properties() -> Array[EntityPropertyDef]:
	var row := _picked()
	if row.is_empty():
		return []
	match String(row["pick"]):
		PICK_RULE: return _rule_properties()
		PICK_FLAG: return _flag_properties()
		PICK_CONDITION, PICK_OUTCOME: return _condition_properties(_picked_condition())
		PICK_ACTION: return _action_properties(_picked_action())
	return []


func inspector_values() -> Dictionary:
	var row := _picked()
	if row.is_empty():
		return {}
	match String(row["pick"]):
		PICK_RULE:
			var rule := _picked_rule()
			if rule == null:
				return {}
			return {
				&"id": String(rule.id), &"enabled": rule.enabled, &"once": rule.once,
				&"trigger": String(rule.trigger.kind), &"zone": String(rule.trigger.zone),
				&"flag": String(rule.trigger.flag), &"seconds": rule.trigger.seconds,
			}
		PICK_FLAG:
			var flag := _picked_flag()
			if flag == null:
				return {}
			return {
				&"id": String(flag.id), &"label": flag.label, &"type": String(flag.type),
				&"default_bool": bool(flag.default_value) if flag.type == MapFlagDef.TYPE_BOOL else false,
				&"default_int": int(flag.default_value) if flag.type == MapFlagDef.TYPE_INT else 0,
			}
		PICK_CONDITION, PICK_OUTCOME:
			var condition := _picked_condition()
			if condition == null or not condition.is_known() or condition.is_group():
				return {}
			return {
				&"flag": String(condition.flag), &"op": String(condition.op),
				&"value_bool": bool(condition.value) if condition.value is bool else int(condition.value) != 0,
				&"value_int": int(condition.value) if not (condition.value is bool) else 0,
			}
		PICK_ACTION:
			var action := _picked_action()
			if action == null or not action.is_builtin():
				return {}
			return {
				&"action": String(action.kind), &"flag": String(action.flag),
				&"text": action.text,
				&"value_bool": bool(action.value) if action.value is bool else int(action.value) != 0,
				&"value_int": int(action.value) if not (action.value is bool) else 1,
			}
	return {}


func _rule_properties() -> Array[EntityPropertyDef]:
	var rule := _picked_rule()
	if rule == null:
		return []
	var properties: Array[EntityPropertyDef] = [
		_property(&"id", "Идентификатор", EntityPropertyDef.TYPE_STRING),
		_property(&"enabled", "Включено", EntityPropertyDef.TYPE_BOOL),
		_property(&"once", "Только один раз", EntityPropertyDef.TYPE_BOOL),
	]
	# A rule whose trigger came from another build keeps it: offering the
	# built-in list would silently retype `gth.settlement:era_reached` into
	# `session_started` the first time the author touched any other field.
	if not rule.trigger.is_builtin():
		properties.append(_property(&"trigger_readonly", "Триггер (другая версия)", EntityPropertyDef.TYPE_STRING))
		return properties
	var trigger := _property(&"trigger", "Когда", EntityPropertyDef.TYPE_ENUM)
	trigger.options = MapRuleTrigger.BUILTIN_KINDS.map(func(kind: StringName) -> String: return String(kind))
	properties.append(trigger)
	if rule.trigger.addresses_zone():
		var zone := _property(&"zone", "Область", EntityPropertyDef.TYPE_ENUM)
		zone.options = _area_options()
		properties.append(zone)
	if rule.trigger.kind == MapRuleTrigger.FLAG_CHANGED:
		var flag := _property(&"flag", "Флаг", EntityPropertyDef.TYPE_ENUM)
		flag.options = _flag_options()
		properties.append(flag)
	if rule.trigger.kind == MapRuleTrigger.ELAPSED:
		var seconds := _property(&"seconds", "Через, с", EntityPropertyDef.TYPE_FLOAT)
		seconds.minimum = 0.0
		properties.append(seconds)
	return properties


func _flag_properties() -> Array[EntityPropertyDef]:
	var flag := _picked_flag()
	if flag == null:
		return []
	var type_property := _property(&"type", "Тип", EntityPropertyDef.TYPE_ENUM)
	type_property.options = ["bool", "int"]
	var properties: Array[EntityPropertyDef] = [
		_property(&"id", "Идентификатор", EntityPropertyDef.TYPE_STRING),
		_property(&"label", "Название", EntityPropertyDef.TYPE_STRING),
		type_property,
	]
	properties.append(
		_property(&"default_int", "Значение на старте", EntityPropertyDef.TYPE_INT)
		if flag.type == MapFlagDef.TYPE_INT
		else _property(&"default_bool", "Значение на старте", EntityPropertyDef.TYPE_BOOL))
	return properties


func _condition_properties(condition: MapRuleCondition) -> Array[EntityPropertyDef]:
	if condition == null or condition.is_group() or not condition.is_known():
		return []
	var flag_property := _property(&"flag", "Флаг", EntityPropertyDef.TYPE_ENUM)
	flag_property.options = _flag_options()
	var op_property := _property(&"op", "Сравнение", EntityPropertyDef.TYPE_ENUM)
	op_property.options = MapRuleCondition.OPS.map(func(op: StringName) -> String: return String(op))
	var properties: Array[EntityPropertyDef] = [flag_property, op_property]
	properties.append(
		_property(&"value_int", "Значение", EntityPropertyDef.TYPE_INT)
		if _is_counter(condition.flag)
		else _property(&"value_bool", "Значение", EntityPropertyDef.TYPE_BOOL))
	return properties


func _action_properties(action: MapRuleAction) -> Array[EntityPropertyDef]:
	if action == null:
		return []
	if not action.is_builtin():
		return [_property(&"action_readonly", "Действие модуля", EntityPropertyDef.TYPE_STRING)]
	var kind_property := _property(&"action", "Что делает", EntityPropertyDef.TYPE_ENUM)
	kind_property.options = MapRuleAction.BUILTIN_KINDS.map(func(kind: StringName) -> String: return String(kind))
	var properties: Array[EntityPropertyDef] = [kind_property]
	if action.kind == MapRuleAction.MESSAGE:
		properties.append(_property(&"text", "Текст", EntityPropertyDef.TYPE_TEXT))
		return properties
	var flag_property := _property(&"flag", "Флаг", EntityPropertyDef.TYPE_ENUM)
	flag_property.options = _flag_options()
	properties.append(flag_property)
	properties.append(
		_property(&"value_int", "Значение", EntityPropertyDef.TYPE_INT)
		if action.kind == MapRuleAction.ADD_FLAG or _is_counter(action.flag)
		else _property(&"value_bool", "Значение", EntityPropertyDef.TYPE_BOOL))
	return properties


static func _property(name: StringName, label: String, type: StringName) -> EntityPropertyDef:
	var property := EntityPropertyDef.new()
	property.name = name
	property.label = label
	property.type = type
	property.section = EntityPropertyDef.SECTION_MAIN
	return property


func _flag_options() -> Array:
	return _scenario().flags.map(func(flag: MapFlagDef) -> String: return String(flag.id))


func _area_options() -> Array:
	var options: Array = []
	for area: ZoneAreaRecord in context.document.zones.areas:
		options.append(String(area.id))
	return options


func _is_counter(flag_id: StringName) -> bool:
	var flag := _scenario().flag_by_id(flag_id)
	return flag != null and flag.type == MapFlagDef.TYPE_INT


func _picked_flag() -> MapFlagDef:
	var row := _picked()
	if row.is_empty() or String(row["pick"]) != PICK_FLAG:
		return null
	var index := int(row["child"])
	return _scenario().flags[index] if index >= 0 and index < _scenario().flags.size() else null


func _picked_condition() -> MapRuleCondition:
	var row := _picked()
	if row.is_empty():
		return null
	if String(row["pick"]) == PICK_OUTCOME:
		var outcome_index := int(row["child"])
		var outcomes := _outcome_conditions()
		return outcomes[outcome_index] if outcome_index >= 0 and outcome_index < outcomes.size() else null
	if String(row["pick"]) == PICK_CONDITION:
		var rule := _picked_rule()
		var condition_index := int(row["child"])
		return rule.conditions[condition_index] if rule != null and condition_index >= 0 and condition_index < rule.conditions.size() else null
	return null


func _picked_action() -> MapRuleAction:
	var row := _picked()
	if row.is_empty() or String(row["pick"]) != PICK_ACTION:
		return null
	var rule := _picked_rule()
	var index := int(row["child"])
	return rule.actions[index] if rule != null and index >= 0 and index < rule.actions.size() else null


# --- Edits --------------------------------------------------------------------

func apply_inspector_value(property_name: StringName, value: Variant) -> bool:
	var row := _picked()
	if row.is_empty():
		return false
	var before := _scenario().to_json()
	var changed := false
	match String(row["pick"]):
		PICK_RULE: changed = _apply_to_rule(_picked_rule(), property_name, value)
		PICK_FLAG: changed = _apply_to_flag(_picked_flag(), property_name, value)
		PICK_CONDITION, PICK_OUTCOME: changed = _apply_to_condition(_picked_condition(), property_name, value)
		PICK_ACTION: changed = _apply_to_action(_picked_action(), property_name, value)
	if not changed:
		return false
	_commit(before, "правка сценария")
	return true


func _apply_to_rule(rule: MapRule, property_name: StringName, value: Variant) -> bool:
	match property_name:
		&"id":
			var next := StringName(String(value).strip_edges())
			if next == &"" or (next != rule.id and _scenario().has_rule(next)):
				return false
			rule.id = next
		&"enabled": rule.enabled = bool(value)
		&"once": rule.once = bool(value)
		&"trigger":
			var kind := StringName(value)
			if kind not in MapRuleTrigger.BUILTIN_KINDS:
				return false
			rule.trigger.kind = kind
		&"zone": rule.trigger.zone = StringName(value)
		&"flag": rule.trigger.flag = StringName(value)
		&"seconds": rule.trigger.seconds = maxf(float(value), 0.0)
		_: return false
	return true


func _apply_to_flag(flag: MapFlagDef, property_name: StringName, value: Variant) -> bool:
	match property_name:
		&"id":
			var next := StringName(String(value).strip_edges())
			if next == &"" or (next != flag.id and _scenario().has_flag(next)):
				return false
			_rename_flag(flag.id, next)
			flag.id = next
		&"label": flag.label = String(value)
		&"type":
			var next_type := StringName(value)
			if next_type not in MapFlagDef.TYPES:
				return false
			flag.type = next_type
			flag.default_value = flag.coerce(flag.default_value)
		&"default_bool", &"default_int": flag.default_value = flag.coerce(value)
		_: return false
	return true


## Renaming a flag rewrites every reference to it. Leaving them behind would turn
## one working scenario into a table of dangling names the author has to hunt
## down in the validator, which is exactly the failure declared flags exist to
## prevent.
func _rename_flag(from: StringName, to: StringName) -> void:
	var scenario := _scenario()
	for rule: MapRule in scenario.rules:
		if rule.trigger.flag == from:
			rule.trigger.flag = to
		for action: MapRuleAction in rule.actions:
			if action.writes_flag() and action.flag == from:
				action.flag = to
		for condition: MapRuleCondition in rule.conditions:
			_rename_in_condition(condition, from, to)
	for condition: MapRuleCondition in scenario.victory + scenario.defeat:
		_rename_in_condition(condition, from, to)


static func _rename_in_condition(condition: MapRuleCondition, from: StringName, to: StringName) -> void:
	if condition.is_group():
		for child: MapRuleCondition in condition.children:
			_rename_in_condition(child, from, to)
	elif condition.flag == from:
		condition.flag = to


func _apply_to_condition(condition: MapRuleCondition, property_name: StringName, value: Variant) -> bool:
	if condition == null:
		return false
	match property_name:
		&"flag":
			condition.flag = StringName(value)
			# Retyping the flag retypes the comparison with it: a counter compared
			# against `true` reads as `>= 1` to the runtime, which is not what the
			# author sees in the field.
			condition.value = 0 if _is_counter(condition.flag) else true
		&"op":
			var op := StringName(value)
			if op not in MapRuleCondition.OPS:
				return false
			condition.op = op
		&"value_bool": condition.value = bool(value)
		&"value_int": condition.value = int(value)
		_: return false
	return true


func _apply_to_action(action: MapRuleAction, property_name: StringName, value: Variant) -> bool:
	if action == null:
		return false
	match property_name:
		&"action":
			var kind := StringName(value)
			if kind not in MapRuleAction.BUILTIN_KINDS:
				return false
			action.kind = kind
			if kind == MapRuleAction.ADD_FLAG:
				action.value = int(action.value) if action.value is int else 1
		&"flag": action.flag = StringName(value)
		&"text": action.text = String(value)
		&"value_bool": action.value = bool(value)
		&"value_int": action.value = int(value)
		_: return false
	return true


func _add_rule() -> void:
	var before := _scenario().to_json()
	var rule := MapRule.create(_next_id("rule", func(id: StringName) -> bool: return _scenario().has_rule(id)),
		MapRuleTrigger.of(MapRuleTrigger.SESSION_STARTED))
	_scenario().rules.append(rule)
	_commit(before, "правило")
	_select_row(PICK_RULE, _scenario().rules.size() - 1, -1)


func _add_condition() -> void:
	var rule := _picked_rule()
	if rule == null or _scenario().flags.is_empty():
		return
	var before := _scenario().to_json()
	rule.conditions.append(_new_condition())
	_commit(before, "условие")


func _add_action() -> void:
	var rule := _picked_rule()
	if rule == null:
		return
	var before := _scenario().to_json()
	# A new action defaults to the one action that needs nothing declared to be
	# meaningful, so adding one to a scenario without flags is still useful.
	rule.actions.append(
		MapRuleAction.say("")
		if _scenario().flags.is_empty()
		else MapRuleAction.set_flag_to(_scenario().flags[0].id, not _is_counter(_scenario().flags[0].id)))
	_commit(before, "действие")


func _add_flag(type: StringName) -> void:
	var before := _scenario().to_json()
	var flag := MapFlagDef.create(
		_next_id("flag", func(id: StringName) -> bool: return _scenario().has_flag(id)), type)
	_scenario().flags.append(flag)
	_commit(before, "флаг")
	_select_row(PICK_FLAG, -1, _scenario().flags.size() - 1)


func _add_outcome_condition() -> void:
	if _scenario().flags.is_empty():
		return
	var before := _scenario().to_json()
	_outcome_conditions().append(_new_condition())
	_commit(before, "условие исхода")


func _new_condition() -> MapRuleCondition:
	var flag := _scenario().flags[0]
	return MapRuleCondition.flag_is(flag.id, 1 if flag.type == MapFlagDef.TYPE_INT else true,
		MapRuleCondition.OP_GE if flag.type == MapFlagDef.TYPE_INT else MapRuleCondition.OP_EQ)


func _delete_selected() -> void:
	var row := _picked()
	if row.is_empty():
		return
	var before := _scenario().to_json()
	match String(row["pick"]):
		PICK_RULE: _scenario().rules.remove_at(int(row["rule"]))
		PICK_CONDITION: _picked_rule().conditions.remove_at(int(row["child"]))
		PICK_ACTION: _picked_rule().actions.remove_at(int(row["child"]))
		PICK_OUTCOME: _outcome_conditions().remove_at(int(row["child"]))
		PICK_FLAG:
			# The flag goes, its references stay and the validator reports them.
			# Rewriting the rules that read it would be a silent second edit the
			# author did not ask for and cannot see in one undo step.
			_scenario().flags.remove_at(int(row["child"]))
		_: return
	_selected = -1
	_commit(before, "удаление")


func _select_row(pick: StringName, rule_index: int, child_index: int) -> void:
	for index in _rows.size():
		var row := _rows[index]
		if String(row["pick"]) == pick and int(row["rule"]) == rule_index and int(row["child"]) == child_index:
			_selected = index
			notify_ui_changed()
			return


func _next_id(prefix: String, taken: Callable) -> StringName:
	var number := 1
	while bool(taken.call(StringName("%s_%d" % [prefix, number]))):
		number += 1
	return StringName("%s_%d" % [prefix, number])


func _commit(before: Dictionary, command_label: String) -> void:
	context.history.push(MapScenarioCommand.of(
		context.document, before, _scenario().to_json(), command_label))
	context.document.mark_dirty()
	_rebuild_rows()
	notify_ui_changed()


func status_text() -> String:
	if _scenario().is_empty():
		return "Сценарий пуст · карта запускается как песочница"
	return "Сценарий: %d правил, %d флагов" % [_scenario().rules.size(), _scenario().flags.size()]
