class_name StartParameterResolution
extends RefCounted

## The answer to "what is this parameter worth, and who decided that"
## (design_docs/engine/map_start.md §2.5, §12).
##
## Provenance is not decoration on the launch screen. Without it, "the slider
## stops at eight" is indistinguishable from a broken menu, and the author of the
## map that narrowed the range has no way to see that their `restrict` is the one
## doing it. It is computed once, here, because both the menu and the editor's
## «Ограничения» table show the same chain.

const LEVEL_MODULE := 1
const LEVEL_DEFINITION := 2
const LEVEL_MAP := 3
const LEVEL_START_OPTION := 4
const LEVEL_PLAYER := 5

## `module_id -> {parameter: value}`, ready to hand to a module.
var values: Dictionary = {}
## `module_id -> {parameter: Entry}`.
var provenance: Dictionary = {}
## Ranges narrowed to nothing and other §13 blockers found while resolving.
var errors: Array[String] = []


## One parameter's chain. Every level that had something to say is recorded, even
## when a later one replaced it — that is exactly what the player needs to read.
class Entry:
	extends RefCounted

	var parameter: StringName = &""
	var label := ""
	## Level that set the final value.
	var level := LEVEL_MODULE
	var value: Variant = null
	## Value each level proposed, keyed by level; absent when the level was silent.
	var proposals: Dictionary = {}
	## Level that last narrowed the range, or 0 when nobody did.
	var restricted_by := 0
	var minimum: Variant = null
	var maximum: Variant = null
	var options: Array = []
	## Level that locked the parameter away from the player, or 0.
	var locked_by := 0
	var offered_to_player := false

	func is_player_choice() -> bool:
		return offered_to_player and locked_by == 0

	## Human-readable chain for the launch screen and the editor table (§12).
	func explain() -> Array[String]:
		var lines: Array[String] = []
		for chain_level: int in [LEVEL_MODULE, LEVEL_DEFINITION, LEVEL_MAP, LEVEL_START_OPTION, LEVEL_PLAYER]:
			if proposals.has(chain_level):
				lines.append("%s  %s" % [
					StartParameterResolution.level_name(chain_level), proposals[chain_level]])
		if restricted_by != 0:
			lines.append("%s  диапазон %s…%s" % [
				StartParameterResolution.level_name(restricted_by),
				minimum if minimum != null else "—",
				maximum if maximum != null else "—",
			])
		if locked_by != 0:
			lines.append("%s  значение закреплено" % StartParameterResolution.level_name(locked_by))
		return lines


static func level_name(level: int) -> String:
	match level:
		LEVEL_MODULE: return "модуль"
		LEVEL_DEFINITION: return "игра"
		LEVEL_MAP: return "карта"
		LEVEL_START_OPTION: return "вариант старта"
		LEVEL_PLAYER: return "выбор игрока"
	return "уровень %d" % level


func parameters_for(module_id: StringName) -> Dictionary:
	var value: Variant = values.get(module_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func entry(module_id: StringName, parameter: StringName) -> Entry:
	var module_entries: Variant = provenance.get(module_id, {})
	if module_entries is Dictionary:
		return (module_entries as Dictionary).get(parameter, null)
	return null


## Every entry of one module, in declaration order.
func entries_for(module_id: StringName) -> Array[Entry]:
	var result: Array[Entry] = []
	var module_entries: Variant = provenance.get(module_id, {})
	if module_entries is Dictionary:
		for parameter: Variant in module_entries as Dictionary:
			result.append((module_entries as Dictionary)[parameter])
	return result


func module_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for module_id: Variant in provenance:
		ids.append(StringName(module_id))
	return ids
