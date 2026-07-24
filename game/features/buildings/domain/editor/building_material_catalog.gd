class_name BuildingMaterialCatalog
extends RefCounted

## Construction materials available to modular frame blocks. Every material
## resolves to a real settlement resource and belongs to a building era.
##
## Materials are era-scoped: a blueprint of a given era may use any material
## whose era is that era or earlier (cumulative), so each era offers several
## materials. The editor chooses the era first; the material list is then
## derived from the era instead of being picked per block from the full set.

const DEFAULT_ID := &"branches"

## Era identifiers, ordered from earliest to latest. Index doubles as the era
## rank used for "material available in era" checks. Matches SettlementState.Era.
const ERA_ORDER: Array[String] = ["tent", "earth", "clay", "wood", "stone", "brick"]

const MATERIALS: Array[Dictionary] = [
	{"id": &"branches", "name": "Палки", "resource_id": &"branches", "units": 1, "category": "tent"},
	{"id": &"thatch", "name": "Солома", "resource_id": &"grass", "units": 1, "category": "tent"},
	{"id": &"tarp", "name": "Брезент", "resource_id": &"tarp", "units": 1, "category": "tent"},
	{"id": &"earth", "name": "Земляные блоки", "resource_id": &"soil", "units": 1, "category": "earth"},
	{"id": &"clay", "name": "Глиняные блоки", "resource_id": &"clay", "units": 1, "category": "clay"},
	{"id": &"logs", "name": "Брёвна", "resource_id": &"logs", "units": 1, "category": "wood"},
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


## Rank of an era name (0 = tent … 5 = brick). Unknown eras rank as tent.
static func era_rank(era_name: String) -> int:
	var rank := ERA_ORDER.find(era_name)
	return rank if rank >= 0 else 0


static func material_era_rank(material_id: StringName) -> int:
	return era_rank(category(material_id))


## True when a material may be used in a blueprint of the given era: its own era
## is at or before that era (cumulative availability).
static func is_available_in_era(material_id: StringName, era_name: String) -> bool:
	return material_era_rank(material_id) <= era_rank(era_name)


## Materials usable by a blueprint of `era_name`, ordered as declared. This is
## what the editor's material list shows once the era is chosen.
static func materials_for_era(era_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var limit := era_rank(era_name)
	for material in MATERIALS:
		if era_rank(str(material["category"])) <= limit:
			out.append(material)
	return out


## Default (most era-defining) material for an era: the last-declared material
## whose era equals `era_name`, falling back to the era's newest available one.
static func default_material_for_era(era_name: String) -> StringName:
	var era_match := &""
	var fallback := DEFAULT_ID
	for material in materials_for_era(era_name):
		fallback = material["id"]
		if str(material["category"]) == era_name:
			era_match = material["id"]
	return era_match if era_match != &"" else fallback
