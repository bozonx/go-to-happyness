class_name ModuleSettingsSection
extends RefCounted

## One module's slice of a map's `start.module_settings`, or of a start option's
## `module_overrides` (design_docs/engine/map_start.md §2.5).
##
## The three verbs are not decoration. "The map said 200 coins" and "the map
## refuses more than 200" are different statements about the same number, and a
## bare `{"starting_money": 200}` cannot tell them apart — which is why the flat
## form is the one thing this class still reads but never writes.
##
## `version` belongs to the owning module, not to the map: raising the map's
## `format_version` because a settlement gained a parameter would demand a
## migration from every map that does not even load that module (§2.5).

const KEY_VERSION := "version"
const KEY_VALUES := "values"
const KEY_RESTRICT := "restrict"
const KEY_LOCK := "lock"

## Schema version of the owning module's section. 0 means the section predates
## versioning — the flat v7 form — and is handed to the module as version 1.
var version := 1
## Overrides: `{parameter: value}`.
var values: Dictionary = {}
## Range narrowing: `{parameter: {"min": x, "max": y}}` or `{parameter: {"options": [...]}}`.
var restrict: Dictionary = {}
## Parameters the player may no longer choose, whatever the definition offered.
var lock: Array[StringName] = []
## Keys of an unrecognised shape, kept so a round trip through an editor that
## does not model them writes them back out unchanged (`content_packaging.md`).
var extra: Dictionary = {}


static func from_dict(source: Variant) -> ModuleSettingsSection:
	var section := ModuleSettingsSection.new()
	if not (source is Dictionary):
		return section
	var raw := source as Dictionary
	# v7 wrote the parameters straight into the section. Reading that as `values`
	# is the whole of the §16 migration for this key: an old map keeps meaning
	# exactly what it meant, and gains the ability to say the other two things.
	if not raw.has(KEY_VALUES) and not raw.has(KEY_RESTRICT) and not raw.has(KEY_LOCK):
		section.values = raw.duplicate(true)
		section.values.erase(KEY_VERSION)
		section.version = maxi(int(raw.get(KEY_VERSION, 1)), 1)
		return section
	section.version = maxi(int(raw.get(KEY_VERSION, 1)), 1)
	if raw.get(KEY_VALUES) is Dictionary:
		section.values = (raw[KEY_VALUES] as Dictionary).duplicate(true)
	if raw.get(KEY_RESTRICT) is Dictionary:
		section.restrict = (raw[KEY_RESTRICT] as Dictionary).duplicate(true)
	for entry: Variant in raw.get(KEY_LOCK, []):
		section.lock.append(StringName(entry))
	for key: Variant in raw:
		if String(key) not in [KEY_VERSION, KEY_VALUES, KEY_RESTRICT, KEY_LOCK]:
			section.extra[key] = raw[key]
	return section


func to_dict() -> Dictionary:
	var result: Dictionary = {KEY_VERSION: version}
	if not values.is_empty():
		result[KEY_VALUES] = values.duplicate(true)
	if not restrict.is_empty():
		result[KEY_RESTRICT] = restrict.duplicate(true)
	if not lock.is_empty():
		result[KEY_LOCK] = lock.map(func(id: StringName) -> String: return String(id))
	for key: Variant in extra:
		if not result.has(key):
			result[key] = extra[key]
	return result


func is_empty() -> bool:
	return values.is_empty() and restrict.is_empty() and lock.is_empty() and extra.is_empty()


func locks(parameter: StringName) -> bool:
	return parameter in lock


## The narrowing this section declares for one parameter, or an empty dictionary.
func restriction_for(parameter: StringName) -> Dictionary:
	var value: Variant = restrict.get(String(parameter), restrict.get(parameter, {}))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func has_value(parameter: StringName) -> bool:
	return values.has(String(parameter)) or values.has(parameter)


func value_of(parameter: StringName) -> Variant:
	return values.get(String(parameter), values.get(parameter, null))


## Reads a whole `module_settings` / `module_overrides` object into typed sections.
static func map_from_dict(source: Variant) -> Dictionary:
	var sections: Dictionary = {}
	if not (source is Dictionary):
		return sections
	for module_id: Variant in source as Dictionary:
		sections[StringName(module_id)] = from_dict((source as Dictionary)[module_id])
	return sections


static func map_to_dict(sections: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for module_id: Variant in sections:
		var section: ModuleSettingsSection = sections[module_id]
		if not section.is_empty():
			result[String(module_id)] = section.to_dict()
	return result
