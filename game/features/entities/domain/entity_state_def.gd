class_name EntityStateDef
extends RefCounted

## One state an archetype can be in (design_docs/engine/map_fill_mode.md §6.1).
##
## The visual is one of exactly three things — another scene, a variant inside the
## same scene, or a material override — because those are the three the existing
## `WorldAssetDef.appearance_controls` binding mechanism already performs. A state
## is therefore a *named set of values* for machinery that exists, not a fourth
## way to change how something looks.
##
## Intermediate stages (a half-bare tree, a dying fire) are states in the same
## list. There is no separate "transition stage" mechanic: smoothness is a
## rendering concern (a material crossfade), not a data one.

const VISUAL_SCENE := &"scene"
const VISUAL_VARIANT := &"variant"
const VISUAL_MATERIAL := &"material"

const VISUAL_KINDS: Array[StringName] = [VISUAL_SCENE, VISUAL_VARIANT, VISUAL_MATERIAL]

## Flags a state can raise for the modules that read it. They are data, not
## behaviour: the module that owns the mechanic decides what `harvested` means.
const FLAG_HARVESTED := &"harvested"
const FLAG_NO_COLLISION := &"no_collision"
const FLAG_DEAD := &"dead"

var id: StringName = &""
var name: String = ""
var visual_kind: StringName = VISUAL_VARIANT
var visual_value: String = ""
var flags: Array[StringName] = []


static func of_variant(p_id: StringName, p_name: String, variant: String) -> EntityStateDef:
	var state := EntityStateDef.new()
	state.id = p_id
	state.name = p_name
	state.visual_kind = VISUAL_VARIANT
	state.visual_value = variant
	return state


func has_flag(flag: StringName) -> bool:
	return flag in flags


func to_dict() -> Dictionary:
	var result: Dictionary = {"id": String(id), "name": name}
	if not visual_value.is_empty():
		result["visual"] = {String(visual_kind): visual_value}
	if not flags.is_empty():
		var flag_ids: Array = []
		for flag: StringName in flags:
			flag_ids.append(String(flag))
		result["flags"] = flag_ids
	return result


static func from_dict(source: Dictionary) -> EntityStateDef:
	var state := EntityStateDef.new()
	state.id = StringName(source.get("id", ""))
	state.name = String(source.get("name", String(state.id)))
	var raw_visual: Variant = source.get("visual", null)
	if raw_visual is Dictionary:
		for kind: StringName in VISUAL_KINDS:
			if (raw_visual as Dictionary).has(String(kind)):
				state.visual_kind = kind
				state.visual_value = String((raw_visual as Dictionary)[String(kind)])
				break
	var raw_flags: Variant = source.get("flags", null)
	if raw_flags is Array:
		for flag: Variant in raw_flags as Array:
			state.flags.append(StringName(flag))
	return state
