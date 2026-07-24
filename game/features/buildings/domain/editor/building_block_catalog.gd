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
	STRUCTURE,   ## cube, slab, quarter slab — massive body / floors
	FOUNDATION,  ## foundation blocks that auto-extend down to the ground
	WALL,        ## wall panel, double span, corner, half-wall
	COLUMNS,     ## square, round, half-round columns
	ROOF,        ## roof pitch, low slope, roof corners, gable
	CIRCULATION, ## stairs, half stairs, quarter stairs, 45° corner stairs
	OPENINGS,    ## window wall, door wall
	RAILING,     ## balustrade / fence
	SPECIAL,     ## arch, custom modules
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
		"id": &"quarter_block",
		"name": "Четверть куба",
		"category": Category.STRUCTURE,
		"size": Vector3(0.5, 1.0, 0.5),
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
		"id": &"column_square_thick",
		"name": "Колонна квадратная (0.8м)",
		"category": Category.COLUMNS,
		"size": Vector3(0.8, 1.0, 0.8),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
	{
		"id": &"column_square_med",
		"name": "Колонна квадратная (0.5м)",
		"category": Category.COLUMNS,
		"size": Vector3(0.5, 1.0, 0.5),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
	{
		"id": &"column_square_thin",
		"name": "Колонна квадратная (0.25м)",
		"category": Category.COLUMNS,
		"size": Vector3(0.25, 1.0, 0.25),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
	{
		"id": &"column_round_thick",
		"name": "Колонна круглая (0.8м)",
		"category": Category.COLUMNS,
		"size": Vector3(0.8, 1.0, 0.8),
		"mesh_shape": SHAPE_CYLINDER,
		"rotatable": true,
	},
	{
		"id": &"column_round_med",
		"name": "Колонна круглая (0.5м)",
		"category": Category.COLUMNS,
		"size": Vector3(0.5, 1.0, 0.5),
		"mesh_shape": SHAPE_CYLINDER,
		"rotatable": true,
	},
	{
		"id": &"column_round_thin",
		"name": "Колонна круглая (0.25м)",
		"category": Category.COLUMNS,
		"size": Vector3(0.25, 1.0, 0.25),
		"mesh_shape": SHAPE_CYLINDER,
		"rotatable": true,
	},
	{
		"id": &"column_half_round",
		"name": "Полуколонна круглая (0.5м)",
		"category": Category.COLUMNS,
		"size": Vector3(0.5, 1.0, 0.25),
		"mesh_shape": SHAPE_HALF_CYLINDER,
		"rotatable": true,
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
		"name": "Арка",
		"category": Category.SPECIAL,
		"size": Vector3(1.0, 1.0, 0.5),
		"mesh_shape": SHAPE_ARCH,
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


## True for blocks that presentation should extend down to meet the terrain.
static func extends_down(block_id: StringName) -> bool:
	return bool(get_block(block_id).get("extends_down", false))


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
		Category.SPECIAL: return "Спецблоки"
		_: return "Прочее"
