class_name PlacementLevel
extends RefCounted

## How the one height knob of a placement is resolved
## (design_docs/engine/building_placement.md §4).
##
## A building has no free Y, no offset and no "nudge it up a bit". It has one
## parameter — the **target level of its pad** — and changing it moves the ground,
## not the building. That is not a simplification: height has exactly one owner,
## the terrain grid (`grid_terrain_system.md` §13), and a building carrying its own
## Y would come off the ground the first time the author edited the landscape,
## with its doors, collision and navigation drifting away from the surface in
## silence.

const MODE_MEDIAN := &"median"
const MODE_TOP := &"top"
const MODE_BOTTOM := &"bottom"
const MODE_MANUAL := &"manual"

const MODES: Array[StringName] = [MODE_MEDIAN, MODE_TOP, MODE_BOTTOM, MODE_MANUAL]

## The height quantum of the world (`grid_terrain_system.md` §3). There are no
## intermediate levels in the grid, so there are none to offer an author either.
const TERRACE_STEP := 2

const MODE_LABELS := {
	MODE_MEDIAN: "Медиана",
	MODE_TOP: "По верху",
	MODE_BOTTOM: "По низу",
	MODE_MANUAL: "Вручную",
}


static func is_valid_mode(mode: StringName) -> bool:
	return mode in MODES


static func label_of(mode: StringName) -> String:
	return String(MODE_LABELS.get(mode, String(mode)))


## Snaps a height to the terrace step. `round`, not `floor`: the level nearest to
## what the ground actually is means the least earthwork, and a floor would bias
## every placement half a terrace into the hill.
static func quantize(height: int) -> int:
	return int(round(float(height) / float(TERRACE_STEP))) * TERRACE_STEP


## The pad level for a set of column heights under the footprint.
##
## Median is the default and not a matter of taste: "по верху" leaves an
## embankment and a drop on every low side, "по низу" digs a pit that fills with
## water in a hollow, and the median balances the two (§4.2).
static func resolve(heights: PackedInt32Array, mode: StringName, manual_level: int) -> int:
	if mode == MODE_MANUAL or heights.is_empty():
		return quantize(manual_level)
	var sorted := heights.duplicate()
	sorted.sort()
	match mode:
		MODE_TOP:
			return quantize(sorted[sorted.size() - 1])
		MODE_BOTTOM:
			return quantize(sorted[0])
		_:
			return quantize(sorted[sorted.size() / 2])
