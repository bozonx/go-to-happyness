class_name BuildingMaterialCatalog
extends RefCounted

## Construction materials available to modular frame blocks. Every material
## resolves to a real settlement resource and a minimum era.

const DEFAULT_ID := &"branches"

const MATERIALS: Array[Dictionary] = [
	{"id": &"branches", "name": "Палки", "resource_id": &"branches", "units": 1, "category": "tent"},
	{"id": &"earth", "name": "Земляные блоки", "resource_id": &"soil", "units": 1, "category": "earth"},
	{"id": &"clay", "name": "Глиняные блоки", "resource_id": &"clay", "units": 1, "category": "clay"},
	{"id": &"wood", "name": "Деревянные блоки", "resource_id": &"boards", "units": 1, "category": "wood"},
	{"id": &"stone", "name": "Каменные блоки", "resource_id": &"stone", "units": 1, "category": "stone"},
	{"id": &"brick", "name": "Кирпичные блоки", "resource_id": &"bricks", "units": 1, "category": "brick"},
]


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


static func cost_units(material_id: StringName) -> int:
	return maxi(0, int(get_material(material_id).get("units", 0)))


static func category(material_id: StringName) -> String:
	return str(get_material(material_id).get("category", "tent"))
