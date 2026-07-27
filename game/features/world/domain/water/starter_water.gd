class_name StarterWater
extends RefCounted

## Turns a biome's authored pond cells into real water (grid_terrain_system.md §9).
##
## A session started without a map still needs somewhere to fill a bucket. It used
## to get one from a decorative `pond.tscn` plus a hand-written blot in
## `terrain_blocked_cells`; this digs an actual basin in the `TerrainGrid` and
## fills it from the `WaterGrid`, so the pond a citizen sees, the pond routing
## refuses to walk through and the pond `WaterAccessService` finds are one object.
##
## It writes to the grids directly and not through `TerrainService` / `WaterService`
## on purpose: this is world construction, before the first frame and before
## navigation has been published, not an edit anyone can undo. That is also why it
## must run BEFORE the terrain is meshed — the chunks it dirties are rebuilt by the
## caller in the same breath.
##
## An authored map never comes through here. Its water is what its author painted,
## and adding biome ponds to it would put lakes on a map that does not have them.

## Cells from the seed that get dug out, in each direction. Two gives a 5×5 pond:
## a 3×3 core deep enough to be impassable and a rim one step down, which is a
## ford — you can wade the edge of a pond and not its middle.
const RADIUS_CELLS := 2
## Depth of the core and of the rim, in Δh steps below the water surface.
const CORE_DEPTH_STEPS := 2
const RIM_DEPTH_STEPS := 1
## Standing water over silt. The bed material is an ordinary land material doing
## its ordinary job (§9.3) — it is what feet slap through in the shallows.
const BED_MATERIAL: StringName = &"mud"


## Digs and fills every seed. Returns the id of the body they share, or
## `WaterBody.NO_BODY` when there was nothing to make.
##
## One body for all of a biome's ponds, not one each: they have the same water,
## the same fish and the same name, and 255 ids is a budget worth not spending on
## scenery.
static func carve(terrain: TerrainGrid, water: WaterGrid, seeds: Array, surface_level := 0) -> int:
	if terrain == null or water == null or seeds.is_empty():
		return WaterBody.NO_BODY
	var body := water.create_body(WaterBody.Type.LAKE, surface_level)
	if body == null:
		return WaterBody.NO_BODY
	body.name = "пруд"
	var dug := false
	for seed: Variant in seeds:
		if seed is Vector2i and _carve_one(terrain, water, seed as Vector2i, body.id, surface_level):
			dug = true
	if not dug:
		water.remove_body(body.id)
		return WaterBody.NO_BODY
	return body.id


static func _carve_one(terrain: TerrainGrid, water: WaterGrid, seed: Vector2i, body_id: int, surface_level: int) -> bool:
	var dug := false
	for offset_z in range(-RADIUS_CELLS, RADIUS_CELLS + 1):
		for offset_x in range(-RADIUS_CELLS, RADIUS_CELLS + 1):
			var cell := seed + Vector2i(offset_x, offset_z)
			if not terrain.is_inside(cell) or terrain.is_hole(cell) or terrain.is_anchor(cell):
				continue
			var edge := maxi(absi(offset_x), absi(offset_z)) >= RADIUS_CELLS
			var depth := RIM_DEPTH_STEPS if edge else CORE_DEPTH_STEPS
			# A ramp reaching into the pond would climb to a column that is about to
			# move, and §3.3.1 says the write that moves it dissolves it.
			terrain.dissolve_ramps_touching(cell)
			terrain.set_height(cell, surface_level - depth)
			terrain.set_material(cell, BED_MATERIAL)
			water.set_cell(cell, body_id, surface_level)
			dug = true
	return dug
