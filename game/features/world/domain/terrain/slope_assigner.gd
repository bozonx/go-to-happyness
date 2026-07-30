class_name SlopeAssigner
extends RefCounted

## Automatic slope selection on a boundary (design_docs/engine/grid_terrain_system.md
## §3.2), which is also the auto-skirt that finishes a levelling operation (§4.5).
##
## The player's height tool never picks a slope class. After the cascade has
## settled the columns, this pass walks every boundary it disturbed and lays the
## gentlest ramp from the catalog that actually fits on the low side. Where none
## fits, the boundary stays a `cliff` — a bare vertical face is a normal outcome,
## not a failure, and it never cancels the operation.
##
## Two rules keep the result predictable, and both are deliberate refinements of
## the prose in §3.2:
##
## 1. **The ramp may cost no more ground than the cascade already spent.** The
##    budget for one boundary is `ceil(drop / repose_steps_per_cell)` cells — the
##    exact footprint the material's own angle of repose (§4.2) would have taken
##    for that drop. Without it, one `+1` brush stroke on open grass would fan out
##    into four eight-cell `shallow` ramps, because `shallow` is the gentlest class
##    and open ground always has room. With it, grass decorates its boundary with
##    one 45° cell, sand terraces over two cells, and rock stays a face — which is
##    what the cascade shaped the columns into in the first place.
## 2. **A drop steeper than one catalog step becomes a chain of ramps of one
##    class**, not a mixture: `rise` must divide the drop exactly (§3.2 step 3),
##    and the segments stack from the high column downwards. `MAX_CHAIN_CELLS`
##    bounds it regardless of material so a single boundary can never eat an
##    unbounded strip of a neighbour's land.
##
## The pass writes into a `TerrainWorkingRegion`, so everything it does is part of
## the same transaction and the same undo record as the cascade that preceded it.

## Hard cap on the cells one boundary may claim, whatever the material says.
const MAX_CHAIN_CELLS := 64


## Assigns slopes around `seed_cells` (the columns an operation moved). Returns
## the number of boundaries that got a ramp; the rest stay cliffs.
static func assign_slopes(
	region: TerrainWorkingRegion, seed_cells: Array[Vector2i],
	requested_class: int = RampConnectionPlan.AUTO_CLASS,
) -> int:
	var assigner := SlopeAssigner.new()
	return assigner._assign(region, seed_cells, requested_class)


var _region: TerrainWorkingRegion = null
## Cells already claimed by a ramp during this pass, so two boundaries cannot
## both reshape the same ground.
var _claimed: Dictionary = {}
var _requested_class := RampConnectionPlan.AUTO_CLASS


func _assign(region: TerrainWorkingRegion, seed_cells: Array[Vector2i], requested_class: int) -> int:
	_region = region
	_claimed = {}
	_requested_class = requested_class if SlopeCatalog.is_ramp_class(requested_class) else RampConnectionPlan.AUTO_CLASS
	var placed := 0
	for cell: Vector2i in _candidates(seed_cells):
		for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
			if _try_boundary(cell, direction):
				placed += 1
				# The cell now carries a slope descriptor, and a column can only
				# carry one — the remaining directions are settled as cliffs.
				break
	return placed


## Every cell that could be the LOW side of a disturbed boundary: the moved
## columns themselves plus one ring around them, because levelling a plateau
## moves only the plateau and the skirt has to be laid on the untouched ground
## outside it (§4.5).
func _candidates(seed_cells: Array[Vector2i]) -> Array[Vector2i]:
	var seen: Dictionary = {}
	for cell: Vector2i in seed_cells:
		seen[cell] = true
		for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
			seen[cell + SlopeCatalog.direction_offset(direction)] = true
	var cells: Array[Vector2i] = []
	for cell: Vector2i in seen:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return cells


## Tries to turn the boundary between `low_cell` and its neighbour in `direction`
## into a ramp. Returns false when the neighbour is not higher, or when no class
## fits — the caller leaves it a cliff.
func _try_boundary(low_cell: Vector2i, direction: int) -> bool:
	if not _is_free_ground(low_cell):
		return false
	var high_cell := low_cell + SlopeCatalog.direction_offset(direction)
	if not _region.is_inside(high_cell) or _region.is_hole(high_cell):
		return false
	# The high column may already be a slope — a hillside is a chain of them, and
	# the inside corner of a hill is two slopes meeting at right angles. Both work
	# out: the drop is measured between stored bases, and §3.4 lifts the corner
	# the two slopes share so no wedge is left across the diagonal.
	var low_height := _region.height_of(low_cell)
	var drop := _region.height_of(high_cell) - low_height
	if drop <= 0:
		return false

	var budget := _budget_for(low_cell, drop)
	var classes: Array[int] = []
	if SlopeCatalog.is_ramp_class(_requested_class):
		classes.append(_requested_class)
	else:
		classes.append_array(SlopeCatalog.RAMP_CLASSES)
	for slope_class: int in classes:
		var rise := SlopeCatalog.rise_of_class(slope_class)
		if drop % rise != 0:
			continue
		var segments := drop / rise
		var total_cells := segments * SlopeCatalog.run_of_class(slope_class)
		if total_cells > budget:
			continue
		var chain := _chain_cells(high_cell, direction, slope_class, segments, low_height, _region.height_of(high_cell))
		if chain.is_empty():
			continue
		_write_chain(chain, _region.height_of(high_cell), direction, slope_class)
		return true
	return false


## How much ground this boundary may claim: what the material's own angle of
## repose would have spent on the same drop, never more than `MAX_CHAIN_CELLS`.
func _budget_for(low_cell: Vector2i, drop: int) -> int:
	if SlopeCatalog.is_ramp_class(_requested_class):
		var rise := SlopeCatalog.rise_of_class(_requested_class)
		if drop % rise != 0:
			return 0
		return mini((drop / rise) * SlopeCatalog.run_of_class(_requested_class), MAX_CHAIN_CELLS)
	var repose := TerrainMaterialCatalog.repose_steps_per_cell_of_index(_region.material_index_at(low_cell))
	if is_inf(repose) or repose <= 0.0:
		return 1
	return mini(maxi(ceili(float(drop) / repose), 1), MAX_CHAIN_CELLS)


## The cells a chain of `segments` ramps would occupy, ordered from the one
## nearest the high column outwards. Empty when the ground does not allow it.
func _chain_cells(high_cell: Vector2i, direction: int, slope_class: int, segments: int, low_height: int, high_height: int) -> Array[Vector2i]:
	var offset := SlopeCatalog.direction_offset(direction)
	var run := SlopeCatalog.run_of_class(slope_class)
	var rise := SlopeCatalog.rise_of_class(slope_class)
	var cells: Array[Vector2i] = []
	for step in segments * run:
		var cell := high_cell - offset * (step + 1)
		if not _is_free_ground(cell) or _region.height_of(cell) != low_height:
			return [] as Array[Vector2i]
		# Only the segments nearest the high column are lifted; the far one lands
		# on the ground as it already is. Lifting a column breaks any ramp that
		# climbs to it, and a decorative pass has no business dissolving authored
		# geometry — it gives up on the boundary instead.
		var base := high_height - (step / run + 1) * rise
		if base != low_height and _region.has_ramp_climbing_to(cell):
			return [] as Array[Vector2i]
		cells.append(cell)
	return cells


## Ground this pass is allowed to reshape: inside the board, not carved out, not
## under a building, not already part of a ramp, and not already claimed.
func _is_free_ground(cell: Vector2i) -> bool:
	if not _region.is_inside(cell) or _region.is_hole(cell) or _region.is_anchor(cell):
		return false
	return not (_region.is_ramp_cell(cell) or _claimed.has(cell))


## Writes the chain. `chain` runs outwards from the high column, so the segment a
## cell belongs to is its position divided by `run`: segment 0 sits right under
## the high column, and each further segment starts one `rise` lower, which lands
## the far end exactly on the original low ground.
func _write_chain(chain: Array[Vector2i], high_height: int, direction: int, slope_class: int) -> void:
	var run := SlopeCatalog.run_of_class(slope_class)
	var rise := SlopeCatalog.rise_of_class(slope_class)
	for step in chain.size():
		var cell: Vector2i = chain[step]
		var segment := step / run
		_region.set_height(cell, high_height - (segment + 1) * rise)
		# Ramp indices count from the low end of the segment, and `chain` walks
		# the other way.
		_region.set_slope(cell, slope_class, direction, run - 1 - (step % run))
		_claimed[cell] = true
