class_name StyleResolver
extends RefCounted

const ContentEntryScript = preload("res://game/features/content/domain/content_entry.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")

var index: ContentIndex

func _init(p_index: ContentIndex) -> void:
	index = p_index

func resolve(role: StringName, era: StringName, style: StringName) -> ContentEntryScript:
	var candidates := index.blueprint_entries().filter(func(entry: ContentEntryScript) -> bool: return entry.kind == &"building" and entry.role == role)
	for wanted_style in [style, &"generic"]:
		var exact := _best(candidates, era, wanted_style, true)
		if exact != null: return exact
	for wanted_style in [style, &"generic"]:
		var older := _best(candidates, era, wanted_style, false)
		if older != null: return older
	return null

func _best(candidates: Array, requested_era: StringName, wanted_style: StringName, exact_only: bool) -> ContentEntryScript:
	var requested_rank := BuildingMaterialCatalogScript.era_rank(requested_era)
	var best: ContentEntryScript = null
	for entry: ContentEntryScript in candidates:
		var rank := BuildingMaterialCatalogScript.era_rank(entry.era)
		if entry.style != wanted_style or rank > requested_rank or (exact_only and entry.era != requested_era): continue
		if best == null or rank > BuildingMaterialCatalogScript.era_rank(best.era): best = entry
	return best
