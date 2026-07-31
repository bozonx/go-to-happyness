class_name MapFlagDef
extends RefCounted

## One named piece of scenario state (map_editor.md §10.2).
##
## Flags are declared, not invented on first write. Without a declaration the
## editor could not offer a rule the list of flags to test, the validator could
## not catch a typo in `{"flag": "has_kye"}`, and every misspelling would read as
## "false" forever — which is the failure mode that makes rule tables in other
## engines untrustworthy.
##
## Two types and no more. A boolean answers "did it happen", a counter answers
## "how many times"; anything richer (a string, a reference, a timer) is a
## request for a scripting language, and that is deliberately out of scope
## (`ideas.md`).

const TYPE_BOOL := &"bool"
const TYPE_INT := &"int"
const TYPES: Array[StringName] = [TYPE_BOOL, TYPE_INT]

var id: StringName = &""
## Author-facing name. Optional: an unnamed flag shows its id, which is what a
## scenario written by hand will have.
var label := ""
var type: StringName = TYPE_BOOL
## Starting value of the flag at session start, coerced to `type`.
var default_value: Variant = false


static func create(flag_id: StringName, flag_type := TYPE_BOOL, value: Variant = null) -> MapFlagDef:
	var flag := MapFlagDef.new()
	flag.id = flag_id
	flag.type = flag_type if flag_type in TYPES else TYPE_BOOL
	flag.default_value = flag.coerce(value) if value != null else flag.zero()
	return flag


static func from_dict(flag_id: StringName, source: Dictionary) -> MapFlagDef:
	var flag := MapFlagDef.new()
	flag.id = flag_id
	flag.label = String(source.get("label", ""))
	flag.type = StringName(source.get("type", TYPE_BOOL))
	if flag.type not in TYPES:
		flag.type = TYPE_BOOL
	flag.default_value = flag.coerce(source.get("default", flag.zero()))
	return flag


func to_dict() -> Dictionary:
	var result := {"type": String(type), "default": default_value}
	if not label.is_empty():
		result["label"] = label
	return result


func display_name() -> String:
	return label if not label.is_empty() else String(id)


func zero() -> Variant:
	return 0 if type == TYPE_INT else false


## JSON has one number type and an author has a text field, so every value that
## reaches a flag passes through here. A counter that stored `true` would make
## `>=` compare a bool against an int, which GDScript answers without erroring —
## the wrong answer is the reason this is centralised.
func coerce(value: Variant) -> Variant:
	if type == TYPE_INT:
		if value is bool:
			return 1 if value else 0
		return int(value) if (value is int or value is float or value is String) else 0
	if value is String:
		return String(value).to_lower() in ["true", "1", "да"]
	return bool(value) if (value is bool or value is int or value is float) else false
