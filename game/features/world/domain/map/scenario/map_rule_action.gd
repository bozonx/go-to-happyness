class_name MapRuleAction
extends RefCounted

## One `then` effect of a rule (map_editor.md §10.4).
##
## Three built-in actions, and they all write scenario state or text: set a flag,
## add to a counter, say something. Nothing here touches the world, and that is
## the design, not an unfinished list — an action that spawned a squad or paid a
## resource would put a game's vocabulary inside the map format.
##
## Everything else is an **extension**: an unrecognised `action` is handed to the
## handler a module registered under that name in `MapScenarioRuntime`. So
## `gth.settlement:add_resource` is written by the settlement module, validated by
## it, and carried untouched by an editor that has never heard of it.

const SET_FLAG := &"set_flag"
const ADD_FLAG := &"add_flag"
const MESSAGE := &"message"

const BUILTIN_KINDS: Array[StringName] = [SET_FLAG, ADD_FLAG, MESSAGE]

var kind: StringName = SET_FLAG
var flag: StringName = &""
var value: Variant = true
var text := ""
## Everything a module's action carries, kept verbatim and handed to its handler.
var raw: Dictionary = {}


static func set_flag_to(flag_id: StringName, next_value: Variant = true) -> MapRuleAction:
	var action := MapRuleAction.new()
	action.kind = SET_FLAG
	action.flag = flag_id
	action.value = next_value
	return action


static func add_to_flag(flag_id: StringName, delta: int = 1) -> MapRuleAction:
	var action := MapRuleAction.new()
	action.kind = ADD_FLAG
	action.flag = flag_id
	action.value = delta
	return action


static func say(message_text: String) -> MapRuleAction:
	var action := MapRuleAction.new()
	action.kind = MESSAGE
	action.text = message_text
	return action


static func from_dict(source: Dictionary) -> MapRuleAction:
	var action := MapRuleAction.new()
	action.raw = source.duplicate(true)
	action.kind = StringName(source.get("action", SET_FLAG))
	action.flag = StringName(source.get("flag", ""))
	action.value = source.get("value", true)
	action.text = String(source.get("text", ""))
	return action


func to_dict() -> Dictionary:
	if not is_builtin():
		return raw.duplicate(true)
	var result := {"action": String(kind)}
	match kind:
		SET_FLAG:
			result["flag"] = String(flag)
			result["value"] = value
		ADD_FLAG:
			result["flag"] = String(flag)
			result["value"] = int(value) if (value is int or value is float) else 1
		MESSAGE:
			result["text"] = text
	return result


func is_builtin() -> bool:
	return kind in BUILTIN_KINDS


func writes_flag() -> bool:
	return kind == SET_FLAG or kind == ADD_FLAG


func describe() -> String:
	match kind:
		SET_FLAG: return "%s := %s" % [flag, value]
		ADD_FLAG: return "%s += %s" % [flag, value]
		MESSAGE: return "сообщение «%s»" % text
	return String(kind)
