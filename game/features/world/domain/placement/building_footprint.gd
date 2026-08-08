class_name BuildingFootprint
extends RefCounted

## Where a blueprint's cells land on the board once it is oriented
## (design_docs/engine/building_placement.md §9).
##
## Pure geometry: it converts between the blueprint's own cell space
## `[0…footprint)` and board cells, and it answers which columns the building
## stands on. It reads a blueprint and writes nothing.
##
## **Orientation is not rotation.** Only the Y axis, only multiples of 90°, stored
## as `0|1|2|3` (N/E/S/W). The reason is technical rather than stylistic: the
## footprint is whole cells and the `Terrain Base` layer is per-cell relative
## heights, and a 45° turn has a representation in neither — it would mean either
## re-rasterising the footprint (and getting a different building from the one in
## the blueprint) or interpolating heights (and getting a grid the slope catalogue
## cannot hold). Free rotation stays with fill objects, which do not touch the
## ground and pay nothing for it.

const ORIENTATIONS: Array[int] = [0, 1, 2, 3]
## North is already defined by the engine: `SlopeCatalog.DIR_N` is `-Z`, i.e. `-Y`
## in cells. A second definition of north — in a compass, a minimap or the weather
## — is exactly the sort of duplication §9 forbids.
const ORIENTATION_DIRECTIONS: Array[int] = [
	SlopeCatalog.DIR_N, SlopeCatalog.DIR_E, SlopeCatalog.DIR_S, SlopeCatalog.DIR_W,
]
const ORIENTATION_LABELS: Array[String] = ["С", "В", "Ю", "З"]

var blueprint: BuildingBlueprint = null
## North-west (minimum) board cell of the oriented rectangle.
var origin: Vector2i = Vector2i.ZERO
var orientation: int = 0
## The blueprint's own footprint, before orientation.
var local_size: Vector2i = Vector2i.ONE


static func of(source: BuildingBlueprint, origin_cell: Vector2i, cell_orientation: int) -> BuildingFootprint:
	var footprint := BuildingFootprint.new()
	footprint.blueprint = source
	footprint.origin = origin_cell
	footprint.orientation = normalized_orientation(cell_orientation)
	footprint.local_size = Vector2i(maxi(source.footprint.x, 1), maxi(source.footprint.y, 1)) \
		if source != null else Vector2i.ONE
	return footprint


## A footprint for a placement whose blueprint is missing (§12): one cell, so the
## record still occupies a place on the board an author can see and move.
static func placeholder(origin_cell: Vector2i) -> BuildingFootprint:
	var footprint := BuildingFootprint.new()
	footprint.origin = origin_cell
	footprint.local_size = Vector2i.ONE
	return footprint


static func normalized_orientation(value: int) -> int:
	return posmod(value, ORIENTATIONS.size())


static func orientation_label(value: int) -> String:
	return ORIENTATION_LABELS[normalized_orientation(value)]


## How many cells the building takes on the board. A quarter turn swaps the axes;
## nothing else changes, which is the whole point of restricting orientation.
func span() -> Vector2i:
	return Vector2i(local_size.y, local_size.x) if orientation % 2 == 1 else local_size


func rect() -> Rect2i:
	return Rect2i(origin, span())


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size := span()
	for offset_z in size.y:
		for offset_x in size.x:
			result.append(origin + Vector2i(offset_x, offset_z))
	return result


func contains(cell: Vector2i) -> bool:
	return rect().has_point(cell)


## Blueprint-local cell → board cell. The mapping is affine, so it stays correct
## for coordinates just outside the footprint — which is what a door anchor
## sitting one cell beyond the rim needs (`active_zones.md` §5.2).
func board_cell(local: Vector2i) -> Vector2i:
	return origin + rotated_offset(local, local_size, orientation)


func local_cell(cell: Vector2i) -> Vector2i:
	var offset := cell - origin
	return unrotated_offset(offset, local_size, orientation)


static func rotated_offset(local: Vector2i, size: Vector2i, cell_orientation: int) -> Vector2i:
	match normalized_orientation(cell_orientation):
		1: return Vector2i(size.y - 1 - local.y, local.x)
		2: return Vector2i(size.x - 1 - local.x, size.y - 1 - local.y)
		3: return Vector2i(local.y, size.x - 1 - local.x)
		_: return local


static func unrotated_offset(offset: Vector2i, size: Vector2i, cell_orientation: int) -> Vector2i:
	match normalized_orientation(cell_orientation):
		1: return Vector2i(offset.y, size.y - 1 - offset.x)
		2: return Vector2i(size.x - 1 - offset.x, size.y - 1 - offset.y)
		3: return Vector2i(size.x - 1 - offset.y, offset.x)
		_: return offset


## Compass direction of a blueprint-local direction once the building is turned.
static func rotated_direction(direction: int, cell_orientation: int) -> int:
	if not SlopeCatalog.is_orthogonal(direction):
		return direction
	return (direction + normalized_orientation(cell_orientation) * 2) % 8


# --- Terrain Base -------------------------------------------------------------

## Offset from the pad level for one board cell of the footprint.
func relative_height(cell: Vector2i) -> int:
	if blueprint == null:
		return 0
	return blueprint.terrain_base.height_at(local_cell(cell))


## Cells the merge cuts out rather than levels (§10). An underground entrance is a
## `is_hole` column: levelling it would fill the opening the blueprint exists to
## leave.
func is_cut_out(cell: Vector2i) -> bool:
	return blueprint != null and blueprint.terrain_base.is_hole(local_cell(cell))


func has_cut_outs() -> bool:
	return blueprint != null and blueprint.terrain_base.has_holes()


# --- Entrances ----------------------------------------------------------------

## The cell in front of every declared door, in board coordinates.
##
## An entrance is not "a side of the model": it is a `door` anchor, and the zone
## layer is the one authority on entrances (`active_zones.md` §5.2). A door anchor
## may sit on the rim or one cell outside it, so the cell an agent has to reach is
## the first one beyond the footprint on the side the door touches.
func door_approach_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if blueprint == null:
		return result
	for anchor: ZoneAnchorRecord in blueprint.doors():
		var approach := board_cell(_local_approach_of(anchor.cell()))
		if approach not in result:
			result.append(approach)
	return result


## The local cell an agent stands on to use a door at `local`. A door already
## outside the footprint is its own approach; one on the rim steps outwards on the
## nearest side.
func _local_approach_of(local: Vector2i) -> Vector2i:
	var inside_x := local.x >= 0 and local.x < local_size.x
	var inside_z := local.y >= 0 and local.y < local_size.y
	if not (inside_x and inside_z):
		return local
	var to_west := local.x
	var to_east := local_size.x - 1 - local.x
	var to_north := local.y
	var to_south := local_size.y - 1 - local.y
	var nearest := mini(mini(to_west, to_east), mini(to_north, to_south))
	if nearest == to_north:
		return Vector2i(local.x, -1)
	if nearest == to_south:
		return Vector2i(local.x, local_size.y)
	if nearest == to_west:
		return Vector2i(-1, local.y)
	return Vector2i(local_size.x, local.y)
