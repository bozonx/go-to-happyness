class_name BuildingMaterialCatalog
extends RefCounted

## Construction materials available to modular frame blocks. A blueprint may
## use any registered material. Games decide availability through their own
## unlock/technology data; the reusable building format does not know eras.

const DEFAULT_ID := &"branches"

## `color` is an albedo hint the presentation mesh library uses to shade blocks
## of this material. It lives with the material data (single source of truth)
## rather than being duplicated in the renderer.
const MATERIALS: Array[Dictionary] = [
	{"id": &"branches", "name": "Палки", "resource_id": &"branches", "units": 1, "family": "tent", "composition": {"branches": 1.0}, "color": Color(0.43, 0.28, 0.15)},
	{"id": &"tarp", "name": "Брезент", "resource_id": &"tarp", "units": 1, "family": "tent", "composition": {"tarp": 1.0}, "color": Color(0.35, 0.40, 0.42)},
	{"id": &"thatch", "name": "Солома", "resource_id": &"grass", "units": 1, "family": "tent", "composition": {"grass": 1.0}, "color": Color(0.72, 0.60, 0.28)},
	{"id": &"earth_stone", "name": "Земля и камень", "resource_id": &"soil", "units": 1, "family": "earth", "composition": {"soil": 0.5, "stone": 0.5}, "color": Color(0.45, 0.38, 0.30)},
	{"id": &"earth", "name": "Земляные блоки", "resource_id": &"soil", "units": 1, "family": "earth", "composition": {"soil": 1.0}, "color": Color(0.43, 0.31, 0.20)},
	{"id": &"adobe", "name": "Саманные блоки", "resource_id": &"clay", "units": 1, "family": "clay", "composition": {"clay": 0.5, "grass": 0.5}, "color": Color(0.60, 0.45, 0.28)},
	{"id": &"clay", "name": "Глиняные блоки", "resource_id": &"clay", "units": 1, "family": "clay", "composition": {"clay": 1.0}, "color": Color(0.58, 0.32, 0.22)},
	{"id": &"logs", "name": "Брёвна", "resource_id": &"logs", "units": 1, "family": "wood", "composition": {"logs": 1.0}, "color": Color(0.48, 0.34, 0.19)},
	{"id": &"wood", "name": "Деревянные блоки", "resource_id": &"boards", "units": 1, "family": "wood", "composition": {"boards": 1.0}, "color": Color(0.55, 0.38, 0.20)},
	{"id": &"stone_mortar", "name": "Камень и раствор", "resource_id": &"stone", "units": 1, "family": "stone", "composition": {"stone": 0.8, "clay": 0.2}, "color": Color(0.50, 0.52, 0.48)},
	{"id": &"stone", "name": "Каменные блоки", "resource_id": &"stone", "units": 1, "family": "stone", "composition": {"stone": 1.0}, "color": Color(0.47, 0.49, 0.50)},
	{"id": &"brick_mortar", "name": "Кирпич и раствор", "resource_id": &"bricks", "units": 1, "family": "brick", "composition": {"bricks": 0.8, "clay": 0.2}, "color": Color(0.60, 0.28, 0.22)},
	{"id": &"brick", "name": "Кирпичные блоки", "resource_id": &"bricks", "units": 1, "family": "brick", "composition": {"bricks": 1.0}, "color": Color(0.58, 0.22, 0.16)},
]

const FALLBACK_COLOR := Color(0.7, 0.7, 0.7)


static func all() -> Array[Dictionary]:
	return MATERIALS


static func has_material(material_id: StringName) -> bool:
	return not get_material(material_id).is_empty()


static func get_material(material_id: StringName) -> Dictionary:
	for material in MATERIALS:
		if material["id"] == material_id:
			return material
	return {}


static func resource_id(material_id: StringName) -> StringName:
	return get_material(material_id).get("resource_id", &"")


## Albedo hint for shading blocks of this material (presentation reads this).
static func color(material_id: StringName) -> Color:
	return get_material(material_id).get("color", FALLBACK_COLOR)


static func cost_units(material_id: StringName) -> int:
	return maxi(0, int(get_material(material_id).get("units", 0)))


static func resource_composition(material_id: StringName) -> Dictionary:
	var mat := get_material(material_id)
	if mat.has("composition") and mat["composition"] is Dictionary:
		return (mat["composition"] as Dictionary).duplicate()
	var res_id := resource_id(material_id)
	if res_id != &"":
		return {String(res_id): float(cost_units(material_id))}
	return {}
