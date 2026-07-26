class_name ContentPack
extends RefCounted

## Metadata for one authored content package.  The index owns discovery; this
## record deliberately knows nothing about buildings or maps.
const FORMAT_VERSION := 1

var id: StringName = &""
var name := ""
var author := ""
var version := ""
var revision := ""
var styles: Array[StringName] = []
var requires: Array[Dictionary] = []
var root_path := ""
var source: StringName = &""


func read_from_dict(data: Dictionary, path: String = "", p_source: StringName = &"") -> bool:
	if int(data.get("format_version", 0)) != FORMAT_VERSION:
		return false
	id = StringName(data.get("id", ""))
	if String(id).is_empty():
		return false
	name = String(data.get("name", id))
	author = String(data.get("author", ""))
	version = String(data.get("version", ""))
	revision = String(data.get("revision", ""))
	root_path = path
	source = p_source
	var provides: Variant = data.get("provides", {})
	if provides is Dictionary:
		for style: Variant in (provides as Dictionary).get("styles", []):
			styles.append(StringName(style))
	for requirement: Variant in data.get("requires", []):
		if requirement is Dictionary:
			requires.append((requirement as Dictionary).duplicate(true))
	return true


func to_dict() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"id": String(id), "name": name, "author": author,
		"version": version, "revision": revision,
		"provides": {"styles": styles.map(func(style: StringName) -> String: return String(style))},
		"requires": requires.duplicate(true),
	}
