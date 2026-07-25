class_name BuildingBlockCatalog
extends RefCounted

## One source of truth for modular construction block definitions used by the
## building editor (frame-construction level). Data only: dimensions, category,
## and mesh archetype. Mesh generation lives in presentation.
##
## Most blocks occupy a single 1m x 1m x 1m grid cell (`Vector3i`). A block may
## declare a `footprint` (in cells) larger than one — e.g. a door / window
## opening spans a 3×3 face — in which case it occupies several cells around its
## anchor cell (see `footprint_of` / grid-model occupancy). The `size` field
## describes the mesh footprint in metres, while `mesh_shape` tells presentation
## which procedural mesh to build.
##
## Some blocks expose a `variants` list: prepared size/profile options for the
## same conceptual block (e.g. a column that can be several thicknesses). A
## variant may override `size` and/or `mesh_shape`; a placed block stores the
## chosen variant id (empty = the first/default variant). This keeps the palette
## compact and the save format explicit without a free-form parametric size that
## would break grid snapping and cost accounting.

enum Category {
	STRUCTURE,   ## cubes, small cubes, rectangles, slabs, half-slab
	FOUNDATION,  ## foundation blocks that auto-extend down to the ground
	COLUMNS,     ## square / round / half columns (thickness as variants)
	ROOF,        ## roof pitches and corners at 45° and 22.5°
	CIRCULATION, ## stairs, half stairs, quarter stairs, corner stairs
	OPENINGS,    ## door / window openings (3×3), arch
	RAILING,     ## railings with balusters, balustrade
}

## Procedural mesh archetypes handled by the presentation mesh library.
const SHAPE_BOX := &"box"
const SHAPE_WEDGE := &"wedge"
const SHAPE_WEDGE_LOW := &"wedge_low"
const SHAPE_SLOPE_CORNER_IN := &"slope_corner_in"
const SHAPE_SLOPE_CORNER_OUT := &"slope_corner_out"
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
const SHAPE_BALUSTRADE := &"balustrade"

## Ordered list of block definitions. Kept as a plain array of dictionaries so
## the catalog stays free of engine node/resource types (domain rule).
const BLOCKS: Array = [
	# --- Конструкция -------------------------------------------------------
	{
		"id": &"cube",
		"name": "Куб",
		"category": Category.STRUCTURE,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": false,
	},
	{
		"id": &"small_cube",
		"name": "Малый куб",
		"category": Category.STRUCTURE,
		"size": Vector3(0.5, 0.5, 0.5),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
	{
		"id": &"rectangle",
		"name": "Прямоугольник",
		"category": Category.STRUCTURE,
		"size": Vector3(1.0, 0.5, 0.5),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
	{
		"id": &"slab",
		"name": "Плита 0.5",
		"category": Category.STRUCTURE,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": false,
	},
	{
		"id": &"thin_slab",
		"name": "Плита 0.25",
		"category": Category.STRUCTURE,
		"size": Vector3(1.0, 0.25, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": false,
	},
	{
		"id": &"half_slab",
		"name": "Полуплита",
		"category": Category.STRUCTURE,
		"size": Vector3(1.0, 0.5, 0.15),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
	},
	# --- Фундамент ---------------------------------------------------------
	{
		"id": &"foundation",
		"name": "Фундамент",
		"category": Category.FOUNDATION,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": false,
		"extends_down": true,
	},
	# --- Колонны -----------------------------------------------------------
	{
		"id": &"column_square",
		"name": "Квадратная колонна",
		"category": Category.COLUMNS,
		"size": Vector3(0.5, 1.0, 0.5),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
		"variants": [
			{"id": &"thick", "name": "0.8м", "size": Vector3(0.8, 1.0, 0.8)},
			{"id": &"med", "name": "0.5м", "size": Vector3(0.5, 1.0, 0.5)},
			{"id": &"thin", "name": "0.25м", "size": Vector3(0.25, 1.0, 0.25)},
		],
	},
	{
		"id": &"column_round",
		"name": "Круглая колонна",
		"category": Category.COLUMNS,
		"size": Vector3(0.5, 1.0, 0.5),
		"mesh_shape": SHAPE_CYLINDER,
		"rotatable": true,
		"variants": [
			{"id": &"thick", "name": "0.8м", "size": Vector3(0.8, 1.0, 0.8)},
			{"id": &"med", "name": "0.5м", "size": Vector3(0.5, 1.0, 0.5)},
			{"id": &"thin", "name": "0.25м", "size": Vector3(0.25, 1.0, 0.25)},
		],
	},
	{
		"id": &"column_half",
		"name": "Полуколонна",
		"category": Category.COLUMNS,
		"size": Vector3(0.5, 1.0, 0.25),
		"mesh_shape": SHAPE_HALF_CYLINDER,
		"rotatable": true,
		"variants": [
			{"id": &"med", "name": "0.5м", "size": Vector3(0.5, 1.0, 0.25)},
			{"id": &"thin", "name": "0.25м", "size": Vector3(0.25, 1.0, 0.15)},
		],
	},
	# --- Крыша -------------------------------------------------------------
	{
		"id": &"roof_pitch",
		"name": "Скат 45°",
		"category": Category.ROOF,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_WEDGE,
		"rotatable": true,
	},
	{
		"id": &"roof_corner_in",
		"name": "Внутренний угол 45°",
		"category": Category.ROOF,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_SLOPE_CORNER_IN,
		"rotatable": true,
	},
	{
		"id": &"roof_corner_out",
		"name": "Внешний угол 45°",
		"category": Category.ROOF,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_SLOPE_CORNER_OUT,
		"rotatable": true,
	},
	{
		"id": &"roof_pitch_low",
		"name": "Скат 22.5°",
		"category": Category.ROOF,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_WEDGE_LOW,
		"rotatable": true,
	},
	{
		"id": &"roof_corner_in_low",
		"name": "Внутренний угол 22.5°",
		"category": Category.ROOF,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_SLOPE_CORNER_IN,
		"rotatable": true,
	},
	{
		"id": &"roof_corner_out_low",
		"name": "Внешний угол 22.5°",
		"category": Category.ROOF,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_SLOPE_CORNER_OUT,
		"rotatable": true,
	},
	# --- Проходы -----------------------------------------------------------
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
		"name": "Угловая лестница",
		"category": Category.CIRCULATION,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_STAIRS_CORNER_45,
		"rotatable": true,
	},
	# --- Проёмы ------------------------------------------------------------
	{
		"id": &"door_wall",
		"name": "Дверной проём (3×3)",
		"category": Category.OPENINGS,
		"size": Vector3(3.0, 3.0, 0.15),
		"footprint": Vector3i(3, 3, 1),
		"mesh_shape": SHAPE_DOOR_WALL,
		"rotatable": true,
	},
	{
		"id": &"window_wall",
		"name": "Оконный проём (3×3)",
		"category": Category.OPENINGS,
		"size": Vector3(3.0, 3.0, 0.15),
		"footprint": Vector3i(3, 3, 1),
		"mesh_shape": SHAPE_WINDOW_WALL,
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
	# --- Ограждения --------------------------------------------------------
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
		"id": &"balustrade",
		"name": "Балюстрада 0.5м",
		"category": Category.RAILING,
		"size": Vector3(1.0, 0.5, 0.2),
		"mesh_shape": SHAPE_BALUSTRADE,
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
# Footprint (multi-cell blocks)
# ---------------------------------------------------------------------------

## Cell footprint of a block (in whole grid cells), before rotation. Single-cell
## blocks return Vector3i.ONE; a 3×3 opening returns Vector3i(3, 3, 1).
static func footprint_of(block_id: StringName, _variant_id: StringName = &"") -> Vector3i:
	var def := get_block(block_id)
	if def.is_empty():
		return Vector3i.ONE
	return def.get("footprint", Vector3i.ONE)


static func is_multicell(block_id: StringName, variant_id: StringName = &"") -> bool:
	return footprint_of(block_id, variant_id) != Vector3i.ONE


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


# ---------------------------------------------------------------------------
# In-cell anchoring
# ---------------------------------------------------------------------------
#
# A sub-cell block (thinner than 1m on an axis) can be snapped inside its 1×1
# cell instead of always centring. Under 90° rotation symmetry the nine grid
# points collapse to just three distinct kinds — the other corners/edges are
# reached by rotating the block, which pivots it around the cell centre:
#   ANCHOR_CENTER — middle of the cell;
#   ANCHOR_EDGE   — flush against one cell side (its thinner axis);
#   ANCHOR_CORNER — tucked into one cell corner (needs slack on both axes).
# The stored `anchor` is one of these kinds; the concrete side/corner is picked
# by the block's rotation. A block with slack on only one axis (e.g. a railing
# panel, full-width and thin) offers only CENTER + EDGE — a corner degenerates
# into the same edge.

const ANCHOR_CENTER := 0
const ANCHOR_EDGE := 1
const ANCHOR_CORNER := 2


## Free space (in cell units) between the block face and the cell side on each
## axis, at rot=0. Zero means the block spans the whole cell on that axis.
static func _free_extents(block_id: StringName, variant_id: StringName) -> Vector2:
	var size := size_of(block_id, variant_id)
	return Vector2(maxf(0.0, 0.5 - size.x * 0.5), maxf(0.0, 0.5 - size.z * 0.5))


## Anchor kinds that make sense for this block/variant (always contains CENTER).
## Multi-cell blocks anchor only at their centre (their span fills whole cells).
static func available_anchors(block_id: StringName, variant_id: StringName) -> Array:
	if is_multicell(block_id, variant_id):
		return [ANCHOR_CENTER]
	var f := _free_extents(block_id, variant_id)
	var out: Array = [ANCHOR_CENTER]
	if f.x > 0.001 or f.y > 0.001:
		out.append(ANCHOR_EDGE)
	if f.x > 0.001 and f.y > 0.001:
		out.append(ANCHOR_CORNER)
	return out


static func normalize_anchor(block_id: StringName, variant_id: StringName, anchor_kind: int) -> int:
	return anchor_kind if anchor_kind in available_anchors(block_id, variant_id) else ANCHOR_CENTER


## Offset from the cell centre (rot=0 frame) that realises an anchor kind. Edge
## pushes toward the block's thinner axis so it actually reaches a side.
static func _anchor_base_offset(block_id: StringName, variant_id: StringName, anchor_kind: int) -> Vector2:
	var f := _free_extents(block_id, variant_id)
	match anchor_kind:
		ANCHOR_EDGE:
			return Vector2(0.0, -f.y) if f.y >= f.x else Vector2(-f.x, 0.0)
		ANCHOR_CORNER:
			return Vector2(-f.x, -f.y)
		_:
			return Vector2.ZERO


## Horizontal position (X, Z in [0,1]) of the block's mesh origin inside its
## cell for the given variant, anchor kind and rotation. Rotation pivots the
## anchored offset around the cell centre (same turn the mesh gets), so a corner
## anchor cycles through all four corners as the block is rotated.
static func cell_offset(block_id: StringName, variant_id: StringName, anchor_kind: int, rot: int) -> Vector2:
	var base := _anchor_base_offset(block_id, variant_id, anchor_kind)
	var rotated := Basis(Vector3.UP, deg_to_rad(90.0 * float(rot))) * Vector3(base.x, 0.0, base.y)
	return Vector2(0.5 + rotated.x, 0.5 + rotated.z)


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
		Category.COLUMNS: return "Колонны"
		Category.ROOF: return "Крыша"
		Category.CIRCULATION: return "Проходы"
		Category.OPENINGS: return "Проёмы"
		Category.RAILING: return "Ограждения"
		_: return "Прочее"
