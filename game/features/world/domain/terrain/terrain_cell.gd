class_name TerrainCell
extends RefCounted

## Read/write view of a single terrain column (design_docs/core/grid_terrain_system.md §2.3).
##
## The grid does NOT store these objects — it stores parallel packed arrays. This
## record exists so callers can pass a whole column around by name instead of by
## five positional arguments; `TerrainGrid.cell_at()` builds one on demand.

## Cells under a building, a road, or a placed blueprint. The cascade refuses to
## move them, and an operation whose wave reaches one is rejected as a whole.
const FLAG_ANCHOR := 1 << 0
## Cut-out cell: the mesher emits no geometry and no collision here (§6).
const FLAG_HOLE := 1 << 1

var height: int = 0
var material_id: StringName = TerrainMaterialCatalog.DEFAULT_MATERIAL
var slope_id: StringName = SlopeCatalog.FLAT
## Direction the slope rises towards, 0..7 (see SlopeCatalog).
var slope_dir: int = SlopeCatalog.DIR_N
## Position of this cell inside a multi-cell ramp, 0..run-1.
var slope_index: int = 0
var flags: int = 0


func is_hole() -> bool:
	return (flags & FLAG_HOLE) != 0


func is_anchor() -> bool:
	return (flags & FLAG_ANCHOR) != 0


func is_flat() -> bool:
	return slope_id == SlopeCatalog.FLAT


func duplicate_cell() -> TerrainCell:
	var copy := TerrainCell.new()
	copy.height = height
	copy.material_id = material_id
	copy.slope_id = slope_id
	copy.slope_dir = slope_dir
	copy.slope_index = slope_index
	copy.flags = flags
	return copy
