class_name MapValidator
extends RefCounted

## Cross-cutting map validation that needs the runtime grids
## (design_docs/engine/active_zones.md §8.1, map_editor.md §11).
##
## `MapZoneLayer.validate` already enforces the structural rules — duplicate
## ids, the role gate, bounds, route references, the owner y-range. Those need
## nothing but the layer itself. The rules here need the terrain, water and
## navigation grids: a spawn point sitting in a hole, under impassable water, or
## a hero-mode map with no `hero_start`. They are kept separate because they
## cannot run at authoring time without the published grids, and folding them
## into the layer would couple pure data to the world.
##
## What is deliberately not here yet: slot/door reachability (§8.1 "слот
## недостижим от двери") needs the building registry to resolve a door's cell,
## and map slots are rare; route-edge passability needs a per-segment walk. Both
## land when the building-side runtime is unified with the map one.

## Runs every cross-cutting check and returns the launch-blocking errors.
## `nav_grid` may be null — reachability checks are skipped then, which is how
## the map editor validates before the navigation field is published.
static func validate(document: MapDocument, terrain: TerrainGrid, water: WaterGrid, nav_grid: NavGrid) -> Array[String]:
	var errors: Array[String] = []
	var board_cells := document.board_cells()
	for anchor in document.zones.anchors:
		_validate_anchor_place(anchor, terrain, water, board_cells, errors)
	_validate_hero_start(document, errors)
	return errors


## An anchor must stand on real, dry, passable ground — a spawn in a hole, under
## deep water, or on lava is a map that cannot start (§8.1, §11).
static func _validate_anchor_place(anchor: ZoneAnchorRecord, terrain: TerrainGrid, water: WaterGrid, board_cells: int, errors: Array[String]) -> void:
	# `MapZoneLayer.validate` already covers out-of-board; this is the part that
	# needs the grids, so it runs only for in-board cells.
	var cell := anchor.cell()
	if cell.x < 0 or cell.y < 0 or cell.x >= board_cells or cell.y >= board_cells:
		return
	if terrain != null and terrain.is_hole(cell):
		errors.append("точка %s стоит в вырезе террейна" % anchor.id)
		return
	if water != null and terrain != null:
		if water.is_lava(cell):
			errors.append("точка %s стоит в лаве" % anchor.id)
			return
		# Frozen water is walkable (ice); open water deeper than a ford is not.
		if water.has_water(cell) and not water.is_frozen(cell) and water.depth_steps_at(terrain, cell) > WaterGrid.FORD_MAX_DEPTH_STEPS:
			errors.append("точка %s стоит под непроходимой водой" % anchor.id)


## A hero-mode map must name where the hero appears (map_editor.md §11). The
## gate is `mode_id == hero`, not `hero_control != none`: `hero_control` defaults
## to third-person for every mode, so the looser check would demand a spawn on
## every settlement map too. In hero mode without a `hero_start` anchor the
## launch would drop the hero on the entrance stone fallback, which is not what
## the map promised.
static func _validate_hero_start(document: MapDocument, errors: Array[String]) -> void:
	if document.meta.start.mode_id != MapStart.MODE_HERO:
		return
	if document.meta.start.hero_control() == MapStart.HERO_CONTROL_NONE:
		return
	for anchor in document.zones.anchors:
		# A `spawn` anchor is the hero's start when its function names it; the
		# engine does not read `function`, so any spawn stands in for one until a
		# tag-based selector exists (§15).
		if anchor.role == ZoneAnchorRecord.ROLE_SPAWN:
			return
	errors.append("hero-режим карты требует хотя бы одну spawn-точку (hero_start)")
