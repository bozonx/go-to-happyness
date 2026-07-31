class_name StartParameterDef
extends RefCounted

## One start parameter a module accepts, described well enough for the host to
## build a control for it without knowing what it means.
##
## This is what replaces hardcoded settlement widgets in the menu and the game
## editor. A module declares its parameters once (`GameModule.start_parameters`);
## the launch screen and the authoring UI both render from that declaration, so a
## new module gets both for free and neither host screen learns a module id.

const TYPE_INT: StringName = &"int"
const TYPE_BOOL: StringName = &"bool"
const TYPE_STRING: StringName = &"string"
const TYPE_ENUM: StringName = &"enum"

var id: StringName = &""
var label := ""
var type: StringName = TYPE_INT
var default_value: Variant = 0
var min_value := 0
var max_value := 0
## `[{"value": Variant, "label": String}]` for TYPE_ENUM, empty otherwise.
var options: Array[Dictionary] = []


static func integer(p_id: StringName, p_label: String, p_default: int, p_min: int, p_max: int) -> StartParameterDef:
	var parameter := StartParameterDef.new()
	parameter.id = p_id
	parameter.label = p_label
	parameter.type = TYPE_INT
	parameter.default_value = p_default
	parameter.min_value = p_min
	parameter.max_value = p_max
	return parameter


static func flag(p_id: StringName, p_label: String, p_default: bool) -> StartParameterDef:
	var parameter := StartParameterDef.new()
	parameter.id = p_id
	parameter.label = p_label
	parameter.type = TYPE_BOOL
	parameter.default_value = p_default
	return parameter


static func text(p_id: StringName, p_label: String, p_default: String) -> StartParameterDef:
	var parameter := StartParameterDef.new()
	parameter.id = p_id
	parameter.label = p_label
	parameter.type = TYPE_STRING
	parameter.default_value = p_default
	return parameter


static func choice(p_id: StringName, p_label: String, p_default: Variant, p_options: Array[Dictionary]) -> StartParameterDef:
	var parameter := StartParameterDef.new()
	parameter.id = p_id
	parameter.label = p_label
	parameter.type = TYPE_ENUM
	parameter.default_value = p_default
	parameter.options = p_options.duplicate(true)
	return parameter


## Brings an authored value into the declared type and range. Authored JSON is
## untyped, so this is the single place that decides what a bad value becomes.
func coerce(value: Variant) -> Variant:
	match type:
		TYPE_INT:
			var number := int(value) if value is float or value is int else int(default_value)
			return clampi(number, min_value, max_value) if max_value > min_value else number
		TYPE_BOOL:
			return bool(value)
		TYPE_STRING:
			return String(value)
		TYPE_ENUM:
			for option: Dictionary in options:
				if option.get("value") == value:
					return value
			return default_value
	return value


static func find(parameters: Array[StartParameterDef], parameter_id: StringName) -> StartParameterDef:
	for parameter: StartParameterDef in parameters:
		if parameter.id == parameter_id:
			return parameter
	return null
