class_name StyleResolver
extends RefCounted

const ContentEntryScript = preload("res://game/features/content/domain/content_entry.gd")
var index: ContentIndex

func _init(p_index: ContentIndex) -> void:
	index = p_index

func resolve(role: StringName, variant: StringName, style: StringName) -> ContentEntryScript:
	var candidates := index.blueprint_entries().filter(func(entry: ContentEntryScript) -> bool: return entry.kind == &"building" and entry.role == role)
	for wanted_style in [style, &"generic"]:
		var exact := _best(candidates, variant, wanted_style)
		if exact != null: return exact
	if variant != &"default":
		for wanted_style in [style, &"generic"]:
			var fallback := _best(candidates, &"default", wanted_style)
			if fallback != null: return fallback
	return null


func _best(candidates: Array, requested_variant: StringName, wanted_style: StringName) -> ContentEntryScript:
	var best: ContentEntryScript = null
	for entry: ContentEntryScript in candidates:
		if entry.style != wanted_style or entry.variant != requested_variant:
			continue
		if best == null or _priority(entry) > _priority(best):
			best = entry
	return best


static func _priority(entry: ContentEntryScript) -> int:
	# Author-owned local files are the explicit override layer. Installed packs
	# follow, then shipped content. Other pack ids are installed packs too.
	if entry.path.begins_with(ContentIndex.PROJECTS_ROOT + "/"):
		return 3
	if entry.source == &"core":
		return 1
	return 2
