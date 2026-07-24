class_name BuildingBlockCatalog
extends RefCounted

## One source of truth for modular construction block definitions used by the
## building editor (frame-construction level). Data only: dimensions, category,
## and colour hints. Mesh generation lives in presentation.
##
## Each block occupies a single 1m x 1m x 1m grid cell (`Vector3i`). The `size`
## field describes the mesh footprint in metres inside/around the anchor cell,
## while `mesh_shape` tells presentation which procedural mesh to build.

enum Category {
	STRUCTURE,  ## cube, slab — massive foundation / floors
	WALL,       ## wall panel, double span, corner
	ROOF,       ## roof pitch
	CIRCULATION,## stairs
	RAILING,    ## balustrade / fence
}

## Procedural mesh archetypes handled by the presentation mesh library.
const SHAPE_BOX := &"box"
const SHAPE_WEDGE := &"wedge"
const SHAPE_STAIRS := &"stairs"

## Ordered list of block definitions. Kept as a plain array of dictionaries so
## the catalog stays free of engine node/resource types (domain rule).
const BLOCKS: Array = [
	{
		"id": &"cube",
		"name": "Полный куб",
		"category": Category.STRUCTURE,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": false,
	},
	{
		"id": &"slab",
		"name": "Плита (пол/перекрытие)",
		"category": Category.STRUCTURE,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": false,
	},
	{
		"id": &"wall_panel",
		"name": "Стеновая панель",
		"category": Category.WALL,
		"size": Vector3(1.0, 1.0, 0.15),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
	{
		"id": &"double_span",
		"name": "Сдвоенный проём",
		"category": Category.WALL,
		"size": Vector3(1.0, 2.0, 0.15),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
	{
		"id": &"corner_panel",
		"name": "Уголок стены",
		"category": Category.WALL,
		"size": Vector3(0.15, 1.0, 0.15),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
	{
		"id": &"roof_pitch",
		"name": "Крышный скат",
		"category": Category.ROOF,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_WEDGE,
		"rotatable": true,
	},
	{
		"id": &"stairs",
		"name": "Лестница",
		"category": Category.CIRCULATION,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_STAIRS,
		"rotatable": true,
	},
	{
		"id": &"balustrade",
		"name": "Балюстрада / забор",
		"category": Category.RAILING,
		"size": Vector3(1.0, 0.5, 0.1),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
]


static func all() -> Array:
	return BLOCKS


static func ids() -> Array:
	var out: Array = []
	for block in BLOCKS:
		out.append(block["id"])
	return out


static func has_block(block_id: StringName) -> bool:
	for block in BLOCKS:
		if block["id"] == block_id:
			return true
	return false


static func get_block(block_id: StringName) -> Dictionary:
	for block in BLOCKS:
		if block["id"] == block_id:
			return block
	return {}


static func default_block_id() -> StringName:
	return BLOCKS[0]["id"]


static func category_name(category: int) -> String:
	match category:
		Category.STRUCTURE: return "Конструкция"
		Category.WALL: return "Стены"
		Category.ROOF: return "Крыша"
		Category.CIRCULATION: return "Проходы"
		Category.RAILING: return "Ограждения"
		_: return "Прочее"
