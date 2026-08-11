class_name BuildingPlacementService
extends RefCounted

## The single owner of "put a blueprint on the ground"
## (design_docs/engine/building_placement.md §2, §15).
##
## The map editor's tool and player construction call **this** class. What differs
## between them is a `PlacementPolicy`, never the algorithm: two placement paths
## would mean the same spot answering differently to the author and to the player,
## and the map would come out impassable in exactly the scenario it was made for.
##
## It knows nothing about the editor or about a session. It takes a blueprint, a
## cell, an orientation and a policy, and returns a `PlacementPlan` — the terrain
## transaction, the warnings and the refusal reason. Nothing is written until
## `commit`, so a refused placement leaves the document byte-identical.
##
## Two invariants it never lets a policy relax: **footprints do not overlap, and
## the ground under a placed building never moves.** The second one is the anchor
## flag, and this class is the writer of it on a map — an anchor written outside a
## transaction is one undo silently drops (`grid_terrain_system.md` §14).

var _terrain: TerrainGrid = null
var _water: WaterGrid = null
var _terrain_service: TerrainService = null
var _layer: MapPlacementLayer = null
## Optional: only used to warn that a pad swallowed authored objects (§9).
var _entities: MapEntityLayer = null


func configure(
	terrain: TerrainGrid, water: WaterGrid, terrain_service: TerrainService,
	layer: MapPlacementLayer, entities: MapEntityLayer = null,
) -> void:
	_terrain = terrain
	_water = water
	_terrain_service = terrain_service
	_layer = layer
	_entities = entities


# --- Reading placements --------------------------------------------------------

## The blueprint a record references, or null when it is not installed. A missing
## blueprint never stops a map from opening (§12); everything that reads a
## footprint has to cope with the placeholder this produces.
static func blueprint_of(record: MapPlacementRecord) -> BuildingBlueprint:
	if record == null:
		return null
	var key := BuildingBlueprintLibrary.resolve_reference(record.blueprint_ref)
	if key.is_empty():
		# The exact file is gone; the game looks for a current variant of the same
		# role, which is what keeps a map alive across a content update.
		key = BuildingBlueprintLibrary.resolve_role(record.blueprint_role())
	return BuildingBlueprintLibrary.get_blueprint(key) if not key.is_empty() else null


static func footprint_of(record: MapPlacementRecord) -> BuildingFootprint:
	var blueprint := blueprint_of(record)
	if blueprint == null:
		return BuildingFootprint.placeholder(record.cell)
	return BuildingFootprint.of(blueprint, record.cell, record.orientation)


func placement_at(cell: Vector2i) -> MapPlacementRecord:
	if _layer == null:
		return null
	for index in range(_layer.placements.size() - 1, -1, -1):
		var record: MapPlacementRecord = _layer.placements[index]
		if footprint_of(record).contains(cell):
			return record
	return null


# --- Dry run --------------------------------------------------------------------

## Computes what placing `blueprint` at `origin_cell` would do, without touching
## anything. `ignored_placement` is the record being moved, so a move does not
## refuse itself for overlapping its own old footprint (§11.4).
func plan(
	blueprint: BuildingBlueprint, origin_cell: Vector2i, orientation: int,
	level_mode: StringName, manual_level: int,
	policy: PlacementPolicy = null, ignored_placement: StringName = &"",
) -> PlacementPlan:
	if policy == null:
		policy = PlacementPolicy.editor()
	if blueprint == null or _terrain == null:
		return PlacementPlan.refused(PlacementPlan.REASON_NO_BLUEPRINT)
	var footprint := BuildingFootprint.of(blueprint, origin_cell, orientation)

	var pad_cells: Array[Vector2i] = []
	var cut_out_cells: Array[Vector2i] = []
	var ground: PackedInt32Array = PackedInt32Array()
	for cell: Vector2i in footprint.cells():
		if not _terrain.is_inside(cell):
			return PlacementPlan.refused(PlacementPlan.REASON_OUT_OF_BOARD, footprint)
		if footprint.is_cut_out(cell):
			# A cell the blueprint leaves open may land on a cell the map already
			# cut out: both want the same nothing there.
			cut_out_cells.append(cell)
			continue
		if _terrain.is_hole(cell):
			return PlacementPlan.refused(PlacementPlan.REASON_MAP_HOLE, footprint)
		pad_cells.append(cell)
		ground.append(_terrain.height_of(cell))
	if pad_cells.is_empty():
		return PlacementPlan.refused(PlacementPlan.REASON_NO_BLUEPRINT, footprint)
	if _overlaps_another_placement(footprint, ignored_placement):
		return PlacementPlan.refused(PlacementPlan.REASON_OVERLAP, footprint)

	# The underground part takes no part in choosing the anchor level (§10), which
	# is why the cut-out cells were left out of `ground` above.
	var level := PlacementLevel.resolve(ground, level_mode, manual_level)

	var targets := PackedInt32Array()
	for cell: Vector2i in pad_cells:
		targets.append(level + footprint.relative_height(cell))

	# The level is carried even by a refused plan: §8.5 asks the status line to say
	# what the placement WOULD have been and why it cannot be, and a refusal that
	# reports level 0 answers the second half by lying about the first.
	var result := PlacementPlan.new()
	result.footprint = footprint
	result.level = level
	result.level_mode = level_mode

	var drop_refusal := _border_drop_refusal(footprint, pad_cells, targets, policy)
	if drop_refusal != PlacementPlan.REASON_NONE:
		result.reason = drop_refusal
		return result

	var operation := TerrainEditOperation.placement(pad_cells, targets, cut_out_cells)
	var solver := CascadeSolver.new()
	var delta := solver.solve(_terrain, operation)
	if delta == null and solver.rejection_reason != CascadeSolver.REASON_NOTHING_TO_DO:
		# An anchor is the one border case that refuses: nobody, ever, moves the
		# ground under a building that is already standing (§5).
		result.reason = PlacementPlan.REASON_FOREIGN_ANCHOR \
			if solver.rejection_reason == CascadeSolver.REASON_ANCHOR else PlacementPlan.REASON_TERRAIN
		return result

	result.ok = true
	result.delta = delta
	result.operation = operation
	result.cut_out_cells = cut_out_cells
	_measure_earthworks(result)
	_collect_cliff_edges(result, pad_cells, targets)
	_collect_water(result, blueprint, pad_cells, targets)
	_collect_neighbourhood_warnings(result, policy, ignored_placement)
	if policy.enforce_surface_expectation and _surface_expectation_mismatch(result, blueprint):
		result.ok = false
		result.reason = PlacementPlan.REASON_SURFACE
		return result
	if policy.enforce_min_building_gap and _violates_min_gap(result.footprint, policy, ignored_placement):
		result.ok = false
		result.reason = PlacementPlan.REASON_MIN_GAP
		return result
	if policy.refusal_check.is_valid():
		var refusal: Variant = policy.refusal_check.call(result)
		if refusal is Dictionary and not (refusal as Dictionary).is_empty():
			result.ok = false
			result.reason = StringName((refusal as Dictionary).get("reason", PlacementPlan.REASON_POLICY))
			result.custom_reason_text = str((refusal as Dictionary).get("message", ""))
	return result


func _surface_expectation_mismatch(plan_result: PlacementPlan, blueprint: BuildingBlueprint) -> bool:
	if blueprint.expects_surface == BuildingBlueprint.SURFACE_ANY:
		return false
	var is_wet := not plan_result.submerged_cells.is_empty()
	return is_wet != (blueprint.expects_surface == BuildingBlueprint.SURFACE_WATER)


func _violates_min_gap(footprint: BuildingFootprint, policy: PlacementPolicy, ignored: StringName) -> bool:
	if _layer == null or footprint == null or policy.min_building_gap <= 0:
		return false
	var grown := footprint.rect().grow(policy.min_building_gap)
	for record: MapPlacementRecord in _layer.placements:
		if record.id != ignored and footprint_of(record).rect().intersects(grown):
			return true
	return false


## §6: the pad may sit far above or below its surroundings, but only so far. Past
## the limit what would be left is not a building on a slope, it is a tower on a
## plinth nobody authored — and the auto-skirt has no class that spans it.
func _border_drop_refusal(
	footprint: BuildingFootprint, pad_cells: Array[Vector2i], targets: PackedInt32Array,
	policy: PlacementPolicy,
) -> StringName:
	for index in pad_cells.size():
		var cell: Vector2i = pad_cells[index]
		for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
			var neighbour := cell + SlopeCatalog.direction_offset(direction)
			if footprint.contains(neighbour):
				continue
			if not _terrain.is_inside(neighbour) or _terrain.is_hole(neighbour):
				continue
			if absi(targets[index] - _terrain.height_of(neighbour)) > policy.max_border_drop:
				return PlacementPlan.REASON_BORDER_DROP
	return PlacementPlan.REASON_NONE


func _overlaps_another_placement(footprint: BuildingFootprint, ignored: StringName) -> bool:
	if _layer == null:
		return false
	var rect := footprint.rect()
	for record: MapPlacementRecord in _layer.placements:
		if record.id == ignored:
			continue
		if footprint_of(record).rect().intersects(rect):
			return true
	return false


## The honest price of the chosen reference, counted in columns rather than in
## cubic metres: the author is choosing between "по верху" and "по низу", and what
## they need to compare is how much ground each one moves.
func _measure_earthworks(plan_result: PlacementPlan) -> void:
	if plan_result.delta == null:
		return
	for index in plan_result.delta.cells.size():
		var before := plan_result.delta.old_state_at(index)[TerrainDelta.STATE_HEIGHT]
		var after := plan_result.delta.new_state_at(index)[TerrainDelta.STATE_HEIGHT]
		if after < before:
			plan_result.cut_cells += 1
		elif after > before:
			plan_result.fill_cells += 1


## Every pad edge the auto-skirt could not ramp (§5). Not a refusal — dense
## building on a slope is a normal scene, and a retaining wall between two levels
## in a town is more honest than a ramp with nowhere to go. But a sheer face is
## the absence of a way out, and the author has to be able to see which edge it is.
func _collect_cliff_edges(
	plan_result: PlacementPlan, pad_cells: Array[Vector2i], targets: PackedInt32Array,
) -> void:
	var after := _states_after(plan_result.delta)
	for index in pad_cells.size():
		var cell: Vector2i = pad_cells[index]
		for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
			var neighbour := cell + SlopeCatalog.direction_offset(direction)
			if plan_result.footprint.contains(neighbour) or not _terrain.is_inside(neighbour):
				continue
			if _terrain.is_hole(neighbour):
				continue
			var neighbour_state: PackedInt32Array = after.get(neighbour, TerrainDelta.state_of(_terrain, neighbour))
			if targets[index] <= neighbour_state[TerrainDelta.STATE_HEIGHT]:
				continue
			# The skirt writes its chain on the LOW side, pointing at the high
			# column: a ramp whose direction is the way back to the pad is the
			# ramp that serves this edge.
			var slope_class := neighbour_state[TerrainDelta.STATE_SLOPE_CLASS]
			var climbs_here := SlopeCatalog.is_ramp_class(slope_class) \
				and neighbour_state[TerrainDelta.STATE_SLOPE_DIR] == SlopeCatalog.opposite_direction(direction)
			if not climbs_here and cell not in plan_result.cliff_edges:
				plan_result.cliff_edges.append(cell)
	if not plan_result.cliff_edges.is_empty():
		plan_result.warn("часть границы получит подпорную стенку вместо пандуса — выезда там не будет")


func _states_after(delta: TerrainDelta) -> Dictionary:
	var states: Dictionary = {}
	if delta == null:
		return states
	for index in delta.cells.size():
		states[delta.cells[index]] = delta.new_state_at(index)
	return states


## Water does not refuse a placement and placement does not edit water (§3): the
## layer has its own owner, and depth is ground subtracted from the surface. What
## this does is tell the author which way it will go — raising a pad above the
## surface drains its cells, lowering it floods them — and warn when the blueprint
## did not expect to end up wet.
func _collect_water(
	plan_result: PlacementPlan, blueprint: BuildingBlueprint,
	pad_cells: Array[Vector2i], targets: PackedInt32Array,
) -> void:
	if _water == null:
		return
	var lava := false
	for index in pad_cells.size():
		var cell: Vector2i = pad_cells[index]
		if not _water.has_water(cell):
			continue
		if _water.height_of(cell) <= targets[index]:
			continue
		plan_result.submerged_cells.append(cell)
		lava = lava or _water.is_lava(cell)
	if plan_result.submerged_cells.is_empty():
		if blueprint.expects_surface == BuildingBlueprint.SURFACE_WATER:
			plan_result.warn("чертёж рассчитан на воду, а площадка окажется на суше")
		return
	if blueprint.expects_surface == BuildingBlueprint.SURFACE_GROUND:
		plan_result.warn("чертёж рассчитан на сушу, а площадка окажется под %s" % ("лавой" if lava else "водой"))


func _collect_neighbourhood_warnings(
	plan_result: PlacementPlan, policy: PlacementPolicy, ignored: StringName,
) -> void:
	if _layer != null and policy.min_building_gap > 0:
		var grown := plan_result.footprint.rect().grow(policy.min_building_gap)
		for record: MapPlacementRecord in _layer.placements:
			if record.id == ignored:
				continue
			if footprint_of(record).rect().intersects(grown):
				plan_result.warn("до соседнего здания меньше %d клеток" % policy.min_building_gap)
				break
	if _entities == null:
		return
	var changed: Dictionary = {}
	if plan_result.delta != null:
		for changed_cell: Vector2i in plan_result.delta.cells:
			changed[changed_cell] = true
	var submerged: Dictionary = {}
	for wet_cell: Vector2i in plan_result.submerged_cells:
		submerged[wet_cell] = true
	for entity: MapEntityRecord in _entities.entities:
		var cell := entity.cell(_terrain)
		if not changed.has(cell) and not plan_result.footprint.contains(cell):
			continue
		if submerged.has(cell):
			plan_result.warn("размещённый объект окажется под водой или лавой")
		elif plan_result.footprint.contains(cell):
			plan_result.warn("под пятном остаются размещённые объекты")
		else:
			plan_result.warn("размещённый объект попадёт в зону откоса")


# --- Commit ---------------------------------------------------------------------

## Applies the plan and records the building. Everything here is one author
## action: the heights and the cut-outs go through `TerrainService` as one delta,
## the anchors as a second, and the caller folds both plus the record into one
## entry of the editor's history (§15). A partial commit is impossible by
## construction — the plan was computed on a copy and either applies whole or was
## refused before this was called.
func commit(
	plan_result: PlacementPlan, blueprint: BuildingBlueprint, placement_id: StringName = &"",
) -> MapPlacementRecord:
	if plan_result == null or not plan_result.ok or _layer == null or blueprint == null \
			or _terrain_service == null or plan_result.footprint == null \
			or plan_result.footprint.blueprint != blueprint:
		return null
	if placement_id != &"" and _layer.has_id(placement_id):
		return null
	if plan_result.operation != null and _terrain_service != null:
		# Re-solved rather than replayed from the plan's delta: the dry run proves
		# the ground accepts the pad, and the commit is what actually validates it
		# against the grid as it is at this instant.
		if not _terrain_service.apply_operation(plan_result.operation) \
				and _terrain_service.last_rejection() != CascadeSolver.REASON_NOTHING_TO_DO:
			return null
	_claim_anchors(plan_result.footprint)

	var record := MapPlacementRecord.new()
	record.id = placement_id if placement_id != &"" else _layer.next_id("building")
	record.blueprint_ref = _reference_to(blueprint)
	record.cell = plan_result.footprint.origin
	record.orientation = plan_result.footprint.orientation
	record.level_mode = plan_result.level_mode
	record.level_value = plan_result.level
	_layer.placements.append(record)
	return record


## Removes a building. **The ground stays planned** (§11.4): the pad has already
## been graded, and rolling it back would mean storing a per-building terrain
## delta in the map forever. Undo restores it, demolition does not — the
## difference is explicit and explainable.
func release(record: MapPlacementRecord) -> bool:
	if record == null or _layer == null:
		return false
	var footprint := footprint_of(record)
	if not _layer.remove(record.id):
		return false
	_release_anchors(footprint)
	return true


## An in-place upgrade keeps the placement identity, level and anchors but must
## not leave the runtime layer pointing at the superseded blueprint. Footprint-
## changing upgrades are rebuilds and are refused here as a guardrail.
func update_blueprint_reference(record: MapPlacementRecord, blueprint: BuildingBlueprint) -> bool:
	if record == null or blueprint == null or _layer == null or not _layer.has_id(record.id):
		return false
	var old_footprint := footprint_of(record)
	var new_footprint := BuildingFootprint.of(blueprint, record.cell, record.orientation)
	if old_footprint.span() != new_footprint.span():
		return false
	record.blueprint_ref = _reference_to(blueprint)
	return true


## Pins the pad against the cascade. From here on no brush and no neighbouring
## placement may move these columns — otherwise the next building down the slope
## would pull the ground out from under this one and leave its floor in the air.
func _claim_anchors(footprint: BuildingFootprint) -> void:
	if _terrain_service == null:
		return
	_terrain_service.set_anchor(footprint.cells(), true)


## Anchors are released only where no OTHER placement still stands. Two buildings
## whose footprints touch the same column must both go before it moves again.
func _release_anchors(footprint: BuildingFootprint) -> void:
	if _terrain_service == null:
		return
	var freed: Array[Vector2i] = []
	for cell: Vector2i in footprint.cells():
		if _cell_claimed_by_placement(cell):
			continue
		freed.append(cell)
	if not freed.is_empty():
		_terrain_service.set_anchor(freed, false)


func _cell_claimed_by_placement(cell: Vector2i) -> bool:
	if _layer == null:
		return false
	for record: MapPlacementRecord in _layer.placements:
		if footprint_of(record).contains(cell):
			return true
	return false


## The reference names the **exact file the author picked**, not whatever the
## style resolver would pick for its role: an author who chose one of three
## variants of a bakery chose that one. The role travels along so that a map whose
## blueprint is later removed can still find a current variant of the same role
## (§12).
static func _reference_to(blueprint: BuildingBlueprint) -> Dictionary:
	return {
		"source": String(BuildingBlueprintLibrary.source_of(blueprint)),
		"id": String(blueprint.id),
		"role": String(blueprint.role),
		"revision": blueprint.revision_id(),
	}


# --- What the placement contributes to the world ------------------------------------

## The blueprint's zones and points, in map coordinates (§11.2).
##
## Nothing new happens here: the conversion is the one `active_zones.md` §18
## already defines, and the blueprint stays the owner of its own zones. What the
## placement adds is where they landed — the pivot, the orientation and the pad
## level — so a consumer never has to reconstruct that from the record.
##
## They are deliberately NOT copied into the map's zone layer: the layer holds
## what the AUTHOR drew on the map, and a copy would go stale the moment the
## blueprint was edited.
static func zones_of(record: MapPlacementRecord, cell_size := 1.0) -> Dictionary:
	var blueprint := blueprint_of(record)
	if blueprint == null:
		return {}
	var footprint := footprint_of(record)
	var span := footprint.span()
	var pivot := Vector3(
		(float(footprint.origin.x) + float(span.x) * 0.5) * cell_size,
		float(record.level_value) * TerrainGrid.HEIGHT_STEP,
		(float(footprint.origin.y) + float(span.y) * 0.5) * cell_size)
	var turn := Basis(Vector3.UP, deg_to_rad(-90.0 * float(record.orientation)))
	return {
		"pivot": pivot,
		"basis": turn,
		"zones": blueprint.runtime_zone_definitions(),
		"routing_anchors": blueprint.routing_anchor_definitions(),
		"routes": blueprint.route_definitions(),
		"overlays": blueprint.overlay_definitions(),
	}


# --- Entrances -------------------------------------------------------------------

## Whether every declared entrance can still be reached from outside (§7).
##
## A blocked entrance is the one placement fault that is invisible: the building
## looks placed and works as scenery. The check therefore runs over the same
## passability field a normal route uses (`NavGrid`), never over a heuristic of
## its own — a second answer to "can anyone walk here" would disagree with the
## first. A retaining wall blocks a door exactly the way a neighbour's wall does,
## so there is no separate "check the terrace" rule.
static func entrance_warnings(
	footprint: BuildingFootprint, nav_grid: NavGrid, label := "здание",
	blocked_cells: Dictionary = {},
) -> Array[String]:
	var warnings: Array[String] = []
	if footprint == null or nav_grid == null:
		return warnings
	for approach: Vector2i in footprint.door_approach_cells():
		if not nav_grid.is_board_cell(approach):
			warnings.append("%s: вход выходит за пределы доски" % label)
			continue
		if blocked_cells.has(approach) or not nav_grid.is_walkable(approach):
			warnings.append("%s: перед входом непроходимая клетка %s" % [label, approach])
			continue
		if not _has_way_out(footprint, nav_grid, approach, blocked_cells):
			warnings.append("%s: от входа %s некуда выйти" % [label, approach])
	return warnings


## A door needs somewhere to go: at least one step off the approach cell that
## leads away from the building and that the routing field allows.
static func _has_way_out(
	footprint: BuildingFootprint, nav_grid: NavGrid, approach: Vector2i,
	blocked_cells: Dictionary = {},
) -> bool:
	# Reaching one adjacent cell is not enough: a two-cell-deep retaining wall
	# would otherwise pass validation.  Leave the building's immediate apron and
	# prove that the approach belongs to the surrounding navigation component.
	var apron := footprint.rect().grow(1)
	var frontier: Array[Vector2i] = [approach]
	var visited := {approach: true}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if not apron.has_point(current):
			return true
		for direction: int in SlopeCatalog.ORTHOGONAL_DIRECTIONS:
			var neighbour := current + SlopeCatalog.direction_offset(direction)
			if visited.has(neighbour) or footprint.contains(neighbour) or blocked_cells.has(neighbour) \
					or not nav_grid.is_board_cell(neighbour):
				continue
			if nav_grid.is_step_passable(current, neighbour):
				visited[neighbour] = true
				frontier.append(neighbour)
	return false
