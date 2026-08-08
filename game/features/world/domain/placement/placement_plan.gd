class_name PlacementPlan
extends RefCounted

## The answer of one dry run: what putting this blueprint here would do
## (design_docs/engine/building_placement.md §15).
##
## Pure data. The service computes it on a copy of the region and hands it back;
## the editor draws it as a ghost, the status line reads its reason, and the
## commit applies exactly the delta it carries. Nothing here has touched the
## document — that is what makes a refused placement leave no trace and a
## confirmed one apply as a single transaction.
##
## Refusal is a normal answer, not an error (§6): in the editor it tells the
## author to move the building or level the ground by hand, and in a session it is
## an ordinary "no" to an attempt to build.

const REASON_NONE := &""
const REASON_NO_BLUEPRINT := &"no_blueprint"
const REASON_OUT_OF_BOARD := &"out_of_board"
const REASON_MAP_HOLE := &"map_hole"
const REASON_OVERLAP := &"overlap"
const REASON_FOREIGN_ANCHOR := &"foreign_anchor"
const REASON_BORDER_DROP := &"border_drop"
const REASON_TERRAIN := &"terrain"

const REASON_TEXTS := {
	REASON_NO_BLUEPRINT: "чертёж не найден",
	REASON_OUT_OF_BOARD: "пятно выходит за доску",
	REASON_MAP_HOLE: "пятно пересекает вырез карты",
	REASON_OVERLAP: "пятно пересекает другое здание",
	REASON_FOREIGN_ANCHOR: "каскад задевает землю под чужим зданием",
	REASON_BORDER_DROP: "перепад по границе больше допустимого",
	REASON_TERRAIN: "рельеф не принял площадку",
}

var ok := false
var reason: StringName = REASON_NONE
## Non-blocking findings (§6): the placement happens, the author is told.
var warnings: Array[String] = []

var footprint: BuildingFootprint = null
var level := 0
var level_mode: StringName = PlacementLevel.MODE_MEDIAN

## The one transaction this plan turns into. Held, not applied.
var delta: TerrainDelta = null
## The request that produced `delta`. The commit re-runs it rather than replaying
## the delta: the dry run proves the ground accepts the pad, and the commit is
## what validates it against the grid as it is at that instant.
var operation: TerrainEditOperation = null
## Footprint cells the merge cuts out instead of levelling (§10).
var cut_out_cells: Array[Vector2i] = []
## Board cells whose ground the merge lowers / raises — the honest price of the
## chosen reference, shown before the author confirms (§8.2).
var cut_cells := 0
var fill_cells := 0
## Edges of the pad that got a retaining wall instead of a ramp (§5). Not a
## failure: a wall between levels in a town is more honest than a ramp with
## nowhere to go — but it means no way out, so the author has to see it.
var cliff_edges: Array[Vector2i] = []
## Pad cells that end up under the water or lava surface (§3).
var submerged_cells: Array[Vector2i] = []


static func refused(refusal: StringName, plan_footprint: BuildingFootprint = null) -> PlacementPlan:
	var plan := PlacementPlan.new()
	plan.ok = false
	plan.reason = refusal
	plan.footprint = plan_footprint
	return plan


func reason_text() -> String:
	return String(REASON_TEXTS.get(reason, String(reason)))


func warn(message: String) -> void:
	if message not in warnings:
		warnings.append(message)


func earthworks() -> int:
	return cut_cells + fill_cells


## True when the pad ends up wholly or partly below a water or lava surface. Not a
## refusal anywhere: the only support of a building is the terrain under it, and a
## pad below the water line is a pier, a flooded ruin or a castle in a lava lake.
func is_submerged() -> bool:
	return not submerged_cells.is_empty()
