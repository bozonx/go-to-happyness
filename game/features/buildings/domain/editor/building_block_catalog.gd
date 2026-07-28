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
## Some blocks expose a `variants` list: fixed size options for one conceptual
## block. A placed block stores the chosen size id (empty = the first/default
## size). This keeps the palette compact and the save format explicit without a
## free-form parametric size that would break grid snapping and cost accounting.

enum Category {
	STRUCTURE,   ## cube and slab (size is selected separately)
	FOUNDATION,  ## foundation blocks that auto-extend down to the ground
	ROOF,        ## roof pitches and corners at 45° and 22.5°
	CIRCULATION, ## stairs, half stairs, quarter stairs, corner stairs
	RAILING,     ## fences and railings
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
const SHAPE_STAIRS_CORNER_HALF := &"stairs_corner_half"
const SHAPE_STAIRS_CORNER_QUARTER := &"stairs_corner_quarter"
const SHAPE_WINDOW_WALL := &"window_wall"
const SHAPE_DOOR_WALL := &"door_wall"
const SHAPE_ARCH := &"arch"
const SHAPE_ARCH_TOP := &"arch_top"
const SHAPE_HALF_ARCH := &"half_arch"
const SHAPE_RAILING := &"railing"
const SHAPE_FENCE := &"fence"

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
		"rotatable": true,
		"variants": [
			{"id": &"1", "name": "1 м", "size": Vector3(1.0, 1.0, 1.0)},
			{"id": &"0.5", "name": "0.5 м", "size": Vector3(0.5, 0.5, 0.5)},
			{"id": &"0.25", "name": "0.25 м", "size": Vector3(0.25, 0.25, 0.25)},
		],
	},
	{
		"id": &"slab",
		"name": "Плита",
		"category": Category.STRUCTURE,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
		"variants": [
			{"id": &"0.5", "name": "0.5 м", "size": Vector3(1.0, 0.5, 1.0)},
			{"id": &"0.25", "name": "0.25 м", "size": Vector3(1.0, 0.25, 1.0)},
		],
	},
	{
		"id": &"arch",
		"name": "Арка",
		"category": Category.STRUCTURE,
		# A 1 m half-column laid on the floor is cut out of a 0.5 m slab.
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_ARCH,
		"rotatable": true,
		"variants": [
			{"id": &"bottom", "name": "Нижний", "mesh_shape": SHAPE_ARCH},
			{"id": &"top", "name": "Верхний", "mesh_shape": SHAPE_ARCH_TOP},
		],
	},
	{"id": &"half_arch", "name": "Полуарка", "category": Category.STRUCTURE, "size": Vector3(1.0, 1.0, 1.0), "mesh_shape": SHAPE_HALF_ARCH, "rotatable": true},
	# --- Фундамент ---------------------------------------------------------
	{
		"id": &"foundation",
		"name": "Фундамент",
		"category": Category.FOUNDATION,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
		"extends_down": true,
	},
	# --- Колонны -----------------------------------------------------------
	{
		"id": &"column_square",
		"name": "Квадратная колонна",
		"category": Category.STRUCTURE,
		"size": Vector3(0.5, 1.0, 0.5),
		"mesh_shape": SHAPE_BOX,
		"rotatable": true,
		"overlap_policy": &"structural_joint",
		"variants": [
			{"id": &"0.5", "name": "0.5 м · Полная", "section": &"0.5", "section_name": "0.5 м", "length": &"full", "length_name": "Полная", "size": Vector3(0.5, 1.0, 0.5)},
			{"id": &"0.25", "name": "0.25 м · Полная", "section": &"0.25", "section_name": "0.25 м", "length": &"full", "length_name": "Полная", "size": Vector3(0.25, 1.0, 0.25)},
			{"id": &"0.25_half", "name": "0.25 м · 1/2", "section": &"0.25", "section_name": "0.25 м", "length": &"half", "length_name": "1/2", "size": Vector3(0.25, 0.5, 0.25)},
		],
	},
	{
		"id": &"column_round",
		"name": "Круглая колонна",
		"category": Category.STRUCTURE,
		"size": Vector3(0.5, 1.0, 0.5),
		"mesh_shape": SHAPE_CYLINDER,
		"rotatable": true,
		"overlap_policy": &"structural_joint",
		"variants": [
			{"id": &"1", "name": "1 м · Полная", "section": &"1", "section_name": "1 м", "length": &"full", "length_name": "Полная", "size": Vector3(1.0, 1.0, 1.0)},
			{"id": &"0.5", "name": "0.5 м · Полная", "section": &"0.5", "section_name": "0.5 м", "length": &"full", "length_name": "Полная", "size": Vector3(0.5, 1.0, 0.5)},
			{"id": &"0.25", "name": "0.25 м · Полная", "section": &"0.25", "section_name": "0.25 м", "length": &"full", "length_name": "Полная", "size": Vector3(0.25, 1.0, 0.25)},
			{"id": &"1_half", "name": "1 м · 1/2", "section": &"1", "section_name": "1 м", "length": &"half", "length_name": "1/2", "size": Vector3(1.0, 0.5, 1.0)},
			{"id": &"0.5_half", "name": "0.5 м · 1/2", "section": &"0.5", "section_name": "0.5 м", "length": &"half", "length_name": "1/2", "size": Vector3(0.5, 0.5, 0.5)},
			{"id": &"0.25_half", "name": "0.25 м · 1/2", "section": &"0.25", "section_name": "0.25 м", "length": &"half", "length_name": "1/2", "size": Vector3(0.25, 0.5, 0.25)},
			{"id": &"1_quarter", "name": "1 м · 1/4", "section": &"1", "section_name": "1 м", "length": &"quarter", "length_name": "1/4", "size": Vector3(1.0, 0.25, 1.0)},
			{"id": &"0.5_quarter", "name": "0.5 м · 1/4", "section": &"0.5", "section_name": "0.5 м", "length": &"quarter", "length_name": "1/4", "size": Vector3(0.5, 0.25, 0.5)},
			{"id": &"0.25_quarter", "name": "0.25 м · 1/4", "section": &"0.25", "section_name": "0.25 м", "length": &"quarter", "length_name": "1/4", "size": Vector3(0.25, 0.25, 0.25)},
		],
	},
	{
		"id": &"column_half",
		"name": "Полуколонна",
		"category": Category.STRUCTURE,
		"size": Vector3(0.5, 1.0, 0.25),
		"mesh_shape": SHAPE_HALF_CYLINDER,
		"rotatable": true,
		"overlap_policy": &"structural_joint",
		"variants": [
			{"id": &"1", "name": "1 м · Полная", "section": &"1", "section_name": "1 м", "length": &"full", "length_name": "Полная", "size": Vector3(1.0, 1.0, 0.5)},
			{"id": &"0.5", "name": "0.5 м · Полная", "section": &"0.5", "section_name": "0.5 м", "length": &"full", "length_name": "Полная", "size": Vector3(0.5, 1.0, 0.25)},
			{"id": &"0.25", "name": "0.25 м · Полная", "section": &"0.25", "section_name": "0.25 м", "length": &"full", "length_name": "Полная", "size": Vector3(0.25, 1.0, 0.125)},
			{"id": &"1_half", "name": "1 м · 1/2", "section": &"1", "section_name": "1 м", "length": &"half", "length_name": "1/2", "size": Vector3(1.0, 0.5, 0.5)},
			{"id": &"0.5_half", "name": "0.5 м · 1/2", "section": &"0.5", "section_name": "0.5 м", "length": &"half", "length_name": "1/2", "size": Vector3(0.5, 0.5, 0.25)},
			{"id": &"0.25_half", "name": "0.25 м · 1/2", "section": &"0.25", "section_name": "0.25 м", "length": &"half", "length_name": "1/2", "size": Vector3(0.25, 0.5, 0.125)},
			{"id": &"1_quarter", "name": "1 м · 1/4", "section": &"1", "section_name": "1 м", "length": &"quarter", "length_name": "1/4", "size": Vector3(1.0, 0.25, 0.5)},
			{"id": &"0.5_quarter", "name": "0.5 м · 1/4", "section": &"0.5", "section_name": "0.5 м", "length": &"quarter", "length_name": "1/4", "size": Vector3(0.5, 0.25, 0.25)},
			{"id": &"0.25_quarter", "name": "0.25 м · 1/4", "section": &"0.25", "section_name": "0.25 м", "length": &"quarter", "length_name": "1/4", "size": Vector3(0.25, 0.25, 0.125)},
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
		"variants": [{"id": &"lower", "name": "Нижний", "size": Vector3(1.0, 0.5, 1.0)}, {"id": &"upper", "name": "Верхний", "size": Vector3(1.0, 0.5, 1.0), "vertical_offset": 0.5}],
	},
	{
		"id": &"roof_corner_in_low",
		"name": "Внутренний угол 22.5°",
		"category": Category.ROOF,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_SLOPE_CORNER_IN,
		"rotatable": true,
		"variants": [{"id": &"lower", "name": "Нижний", "size": Vector3(1.0, 0.5, 1.0)}, {"id": &"upper", "name": "Верхний", "size": Vector3(1.0, 0.5, 1.0), "vertical_offset": 0.5}],
	},
	{
		"id": &"roof_corner_out_low",
		"name": "Внешний угол 22.5°",
		"category": Category.ROOF,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_SLOPE_CORNER_OUT,
		"rotatable": true,
		"variants": [{"id": &"lower", "name": "Нижний", "size": Vector3(1.0, 0.5, 1.0)}, {"id": &"upper", "name": "Верхний", "size": Vector3(1.0, 0.5, 1.0), "vertical_offset": 0.5}],
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
		"name": "Угловая лестница (8 ступеней)",
		"category": Category.CIRCULATION,
		"size": Vector3(1.0, 1.0, 1.0),
		"mesh_shape": SHAPE_STAIRS_CORNER_45,
		"rotatable": true,
	},
	{
		"id": &"stairs_corner_half",
		"name": "Угловая лестница (4 ступени)",
		"category": Category.CIRCULATION,
		"size": Vector3(1.0, 0.5, 1.0),
		"mesh_shape": SHAPE_STAIRS_CORNER_HALF,
		"rotatable": true,
	},
	{
		"id": &"stairs_corner_quarter",
		"name": "Угловая лестница (2 ступени)",
		"category": Category.CIRCULATION,
		"size": Vector3(1.0, 0.25, 1.0),
		"mesh_shape": SHAPE_STAIRS_CORNER_QUARTER,
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
		"variants": [{"id": &"full", "name": "1", "size": Vector3(1.0, 1.0, 0.12)}, {"id": &"half", "name": "0.5", "size": Vector3(1.0, 0.5, 0.12)}],
	},
	{
		"id": &"fence",
		"name": "Забор",
		"category": Category.RAILING,
		"size": Vector3(1.0, 0.5, 0.12),
		"mesh_shape": SHAPE_FENCE,
		"rotatable": true,
		"variants": [{"id": &"full", "name": "1", "size": Vector3(1.0, 1.0, 0.12)}, {"id": &"half", "name": "0.5", "size": Vector3(1.0, 0.5, 0.12)}],
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


static func variant_option(block_id: StringName, variant_id: StringName, option: StringName) -> StringName:
	var def := get_block(block_id)
	var variant := _resolve_variant(def, block_id, variant_id)
	return variant.get(option, &"")


static func variant_for_options(block_id: StringName, section: StringName, length: StringName) -> StringName:
	for variant in variants(block_id):
		if variant.get("section", &"") == section and variant.get("length", &"") == length:
			return variant["id"]
	return default_variant(block_id)


## First variant id matching a given length, ignoring section.
static func variant_for_length(block_id: StringName, length: StringName) -> StringName:
	for variant in variants(block_id):
		if variant.get("length", &"") == length:
			return variant["id"]
	return default_variant(block_id)


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


static func vertical_offset_of(block_id: StringName, variant_id: StringName = &"") -> float:
	var def := get_block(block_id)
	var v := _resolve_variant(def, block_id, variant_id)
	return float(v.get("vertical_offset", def.get("vertical_offset", 0.0)))


## Explicit opt-in for compatible construction joints. It is deliberately a
## block-definition rule: material or a merely different size must never make
## two solids overlap by accident.
static func allows_structural_joint(block_id: StringName) -> bool:
	return get_block(block_id).get("overlap_policy", &"") == &"structural_joint"


## Conservative world-space AABB occupied by a block in its anchor cell. The
## frame editor only permits quarter turns, so this is an exact box for boxes
## and a safe broad-phase volume for curved procedural meshes.
static func occupied_aabb(
	cell: Vector3i,
	block_id: StringName,
	variant_id: StringName,
	rot: int,
	anchor_kind: int,
	rot_x: int = 0,
	rot_z: int = 0
) -> AABB:
	var size := size_of(block_id, variant_id)
	var base := anchor_base_offset(block_id, variant_id, anchor_kind)
	var basis := Basis.from_euler(Vector3(
		deg_to_rad(90.0 * float(rot_x)),
		deg_to_rad(90.0 * float(rot)),
		deg_to_rad(90.0 * float(rot_z))))
	var local_center := basis * Vector3(base.x, size.y * 0.5 - 0.5, base.y)
	var center := Vector3(cell) + Vector3(0.5, 0.5, 0.5) + local_center + Vector3.UP * vertical_offset_of(block_id, variant_id)
	var half := size * 0.5
	var extent := Vector3(
		absf(basis.x.x) * half.x + absf(basis.y.x) * half.y + absf(basis.z.x) * half.z,
		absf(basis.x.y) * half.x + absf(basis.y.y) * half.y + absf(basis.z.y) * half.z,
		absf(basis.x.z) * half.x + absf(basis.y.z) * half.y + absf(basis.z.z) * half.z)
	return AABB(center - extent, extent * 2.0)


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
	if block_id == &"column_half":
		var half_free := _free_extents(block_id, variant_id)
		return [ANCHOR_EDGE, ANCHOR_CORNER] if half_free.x > 0.001 else [ANCHOR_EDGE]
	var f := _free_extents(block_id, variant_id)
	var out: Array = [ANCHOR_CENTER]
	if f.x > 0.001 or f.y > 0.001:
		out.append(ANCHOR_EDGE)
	if f.x > 0.001 and f.y > 0.001:
		out.append(ANCHOR_CORNER)
	return out


static func normalize_anchor(block_id: StringName, variant_id: StringName, anchor_kind: int) -> int:
	var anchors := available_anchors(block_id, variant_id)
	return anchor_kind if anchor_kind in anchors else anchors[0]


## Public accessor for the rot=0 in-cell anchor offset (see `_anchor_base_offset`),
## used by presentation to build the full 3D placement offset.
static func anchor_base_offset(block_id: StringName, variant_id: StringName, anchor_kind: int) -> Vector2:
	return _anchor_base_offset(block_id, variant_id, anchor_kind)


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
		Category.ROOF: return "Скат"
		Category.CIRCULATION: return "Проходы"
		Category.RAILING: return "Ограждения"
		_: return "Прочее"
