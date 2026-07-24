class_name BuildingBlockCatalog
extends RefCounted

## One source of truth for modular construction block definitions used by the
## building editor (frame-construction level). Data only: dimensions, category,
## and mesh archetype. Mesh generation lives in presentation.
##
## Each block occupies a single 1m x 1m x 1m grid cell (`Vector3i`). The `size`
## field describes the mesh footprint in metres inside/around the anchor cell,
## while `mesh_shape` tells presentation which procedural mesh to build.
##
## Some blocks expose a `variants` list: prepared size/profile options for the
## same conceptual block (e.g. a column that can be square/round at several
## thicknesses). A variant may override `size` and/or `mesh_shape`; a placed
## block stores the chosen variant id (empty = the first/default variant). This
## keeps the palette compact and the save format explicit without a free-form
## parametric size that would break grid snapping and cost accounting.

enum Category {
	STRUCTURE,   ## cube, slab, thin slab — massive body / floors
	FOUNDATION,  ## foundation blocks that auto-extend down to the ground
	WALL,        ## wall panel, double span, corner, half-wall
	COLUMNS,     ## square / round / half-round columns (sizes as variants)
	ROOF,        ## roof pitch, low slope, roof corners, gable
	CIRCULATION, ## stairs, half stairs, quarter stairs, 45° corner stairs
	OPENINGS,    ## window wall, door wall, arch
	RAILING,     ## railings with balusters, solid parapet
}

## Procedural mesh archetypes handled by the presentation mesh library.
const SHAPE_BOX := &"box"
const SHAPE_WEDGE := &"wedge"
const SHAPE_WEDGE_LOW := &"wedge_low"
const SHAPE_SLOPE_CORNER_IN := &"slope_corner_in"
const SHAPE_SLOPE_CORNER_OUT := &"slope_corner_out"
const SHAPE_GABLE := &"gable"
const SHAPE_CYLINDER := &"cylinder"
const SHAPE_HALF_CYLINDER := &"half_cylinder"
const SHAPE_STAIRS := &"stairs"
const SHAPE_STAIRS_HALF := &"stairs_half"
const SHAPE_STAIRS_QUARTER := &"stairs_quarter"
const SHAPE_STAIRS_CORNER_45 := &"stairs_corner_45"
const SHAPE_WINDOW_WALL := &"window_wall"
const SHAPE_DOOR_WALL := &"door_wall"
const SHAPE_ARCH := &"arch"
const SHAPE_RAILING := &"railing"

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
		"name": "Плита 0.5м (пол/перекрытие)",
		"category": Category.STRUCTURE,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": false,
	},
	{
		"id": &"thin_slab",
		"name": "Плита 0.25м (тонкая)",
		"category": Category.STRUCTURE,
		"size": Vector3(1.0, 0.25, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": false,
	},
	{
		"id": &"foundation",
		"name": "Фундамент",
		"category": Category.FOUNDATION,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": false,
		"extends_down": true,
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
		"id": &"half_wall",
		"name": "Полустена 0.5м",
		"category": Category.WALL,
		"size": Vector3(1.0, 0.5, 0.15),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
	{
		"id": &"quarter_wall",
		"name": "Узкая стенка 0.5м",
		"category": Category.WALL,
		"size": Vector3(0.5, 1.0, 0.15),
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
		"id": &"column",
		"name": "Колонна",
		"category": Category.COLUMNS,
		"size": Vector3(0.8, 1.0, 0.8),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
		"variants": [
			{"id": &"square_thick", "name": "Квадрат 0.8м", "size": Vector3(0.8, 1.0, 0.8), "mesh_shape": SHAPE_BOX},
			{"id": &"square_med", "name": "Квадрат 0.5м", "size": Vector3(0.5, 1.0, 0.5), "mesh_shape": SHAPE_BOX},
			{"id": &"square_thin", "name": "Квадрат 0.25м", "size": Vector3(0.25, 1.0, 0.25), "mesh_shape": SHAPE_BOX},
			{"id": &"round_thick", "name": "Круг 0.8м", "size": Vector3(0.8, 1.0, 0.8), "mesh_shape": SHAPE_CYLINDER},
			{"id": &"round_med", "name": "Круг 0.5м", "size": Vector3(0.5, 1.0, 0.5), "mesh_shape": SHAPE_CYLINDER},
			{"id": &"round_thin", "name": "Круг 0.25м", "size": Vector3(0.25, 1.0, 0.25), "mesh_shape": SHAPE_CYLINDER},
			{"id": &"half_round", "name": "Полукруг 0.5м", "size": Vector3(0.5, 1.0, 0.25), "mesh_shape": SHAPE_HALF_CYLINDER},
		],
	},
	{
		"id": &"roof_pitch",
		"name": "Крышный скат (45°)",
		"category": Category.ROOF,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_WEDGE,
		"rotatable": true,
	},
	{
		"id": &"roof_pitch_low",
		"name": "Низкий скат (22.5°)",
		"category": Category.ROOF,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_WEDGE_LOW,
		"rotatable": true,
	},
	{
		"id": &"roof_corner_in",
		"name": "Внутренний угол крыши",
		"category": Category.ROOF,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_SLOPE_CORNER_IN,
		"rotatable": true,
	},
	{
		"id": &"roof_corner_out",
		"name": "Внешний угол крыши",
		"category": Category.ROOF,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_SLOPE_CORNER_OUT,
		"rotatable": true,
	},
	{
		"id": &"gable_end",
		"name": "Фронтон (треугольная стена)",
		"category": Category.ROOF,
		"size": Vector3(1.0, 1.0, 0.15),
		"mesh_shape": SHAPE_GABLE,
		"rotatable": true,
	},
	{
		"id": &"stairs",
		"name": "Лестница (8 ступеней)",
		"category": Category.CIRCULATION,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_STAIRS,
		"rotatable": true,
	},
	{
		"id": &"stairs_half",
		"name": "Лестница (4 ступени)",
		"category": Category.CIRCULATION,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_STAIRS_HALF,
		"rotatable": true,
	},
	{
		"id": &"stairs_quarter",
		"name": "Лестница (2 ступени)",
		"category": Category.CIRCULATION,
		"size": Vector3(1.0, 0.25, 1.0),
		"mesh_shape": SHAPE_STAIRS_QUARTER,
		"rotatable": true,
	},
	{
		"id": &"stairs_corner_45",
		"name": "Угловая лестница (45° крыльцо)",
		"category": Category.CIRCULATION,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_STAIRS_CORNER_45,
		"rotatable": true,
	},
	{
		"id": &"window_wall",
		"name": "Стена с окном",
		"category": Category.OPENINGS,
		"size": Vector3(1.0, 1.0, 0.15),
		"mesh_shape": SHAPE_WINDOW_WALL,
		"rotatable": true,
	},
	{
		"id": &"door_wall",
		"name": "Стена с дверным проёмом",
		"category": Category.OPENINGS,
		"size": Vector3(1.0, 1.0, 0.15),
		"mesh_shape": SHAPE_DOOR_WALL,
		"rotatable": true,
	},
	{
		"id": &"arch",
		"name": "Арка (проём)",
		"category": Category.OPENINGS,
		"size": Vector3(1.0, 1.0, 0.15),
		"mesh_shape": SHAPE_ARCH,
		"rotatable": true,
	},
	{
		"id": &"railing",
		"name": "Перила с балясинами",
		"category": Category.RAILING,
		"size": Vector3(1.0, 1.0, 0.12),
		"mesh_shape": SHAPE_RAILING,
		"rotatable": true,
		"variants": [
			{"id": &"full", "name": "В полный блок", "size": Vector3(1.0, 1.0, 0.12)},
			{"id": &"half", "name": "В полблока", "size": Vector3(1.0, 0.5, 0.12)},
		],
	},
	{
		"id": &"parapet",
		"name": "Парапет 0.25м (панель)",
		"category": Category.RAILING,
		"size": Vector3(1.0, 0.5, 0.25),
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


## True for blocks that presentation should extend down to meet the terrain.
static func extends_down(block_id: StringName) -> bool:
	return bool(get_block(block_id).get("extends_down", false))


# ---------------------------------------------------------------------------
# Variants
# ---------------------------------------------------------------------------

## Prepared size/profile options for a block (empty when the block is single-size).
static func variants(block_id: StringName) -> Array:
	return get_block(block_id).get("variants", [])


static func has_variants(block_id: StringName) -> bool:
	return not variants(block_id).is_empty()


## First declared variant id, or empty for a single-size block.
static func default_variant(block_id: StringName) -> StringName:
	var vs := variants(block_id)
	return vs[0]["id"] if not vs.is_empty() else &""


## Resolves a requested variant to a valid one: unknown/empty falls back to the
## first declared variant; single-size blocks always resolve to empty.
static func normalize_variant(block_id: StringName, variant_id: StringName) -> StringName:
	var vs := variants(block_id)
	if vs.is_empty():
		return &""
	for v in vs:
		if v["id"] == variant_id:
			return variant_id
	return vs[0]["id"]


## Effective mesh footprint of a block for the given variant.
static func size_of(block_id: StringName, variant_id: StringName = &"") -> Vector3:
	var def := get_block(block_id)
	if def.is_empty():
		return Vector3.ONE
	var v := _resolve_variant(def, block_id, variant_id)
	if not v.is_empty() and v.has("size"):
		return v["size"]
	return def.get("size", Vector3.ONE)


## Effective mesh archetype of a block for the given variant.
static func mesh_shape_of(block_id: StringName, variant_id: StringName = &"") -> StringName:
	var def := get_block(block_id)
	if def.is_empty():
		return SHAPE_BOX
	var v := _resolve_variant(def, block_id, variant_id)
	if not v.is_empty() and v.has("mesh_shape"):
		return v["mesh_shape"]
	return def.get("mesh_shape", SHAPE_BOX)


static func _resolve_variant(def: Dictionary, block_id: StringName, variant_id: StringName) -> Dictionary:
	var vs: Array = def.get("variants", [])
	if vs.is_empty():
		return {}
	for v in vs:
		if v["id"] == variant_id:
			return v
	return vs[0]


static func category_name(category: int) -> String:
	match category:
		Category.STRUCTURE: return "Конструкция"
		Category.FOUNDATION: return "Фундамент"
		Category.WALL: return "Стены"
		Category.COLUMNS: return "Колонны"
		Category.ROOF: return "Крыша"
		Category.CIRCULATION: return "Проходы"
		Category.OPENINGS: return "Проёмы"
		Category.RAILING: return "Ограждения"
		_: return "Прочее"
