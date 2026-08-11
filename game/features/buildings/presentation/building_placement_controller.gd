class_name BuildingPlacementController
extends Node

## Owns pure building placement validation and geometry helpers that were
## previously inline in the bootstrap. The bootstrap retains UI-mutating
## functions (move_selection, place_building, select_build_mode, etc.) because
## they are tightly coupled to scene nodes and UI state.

var simulation: Node
var placement_service: BuildingPlacementService
var session_layer: MapPlacementLayer
var session_policy: PlacementPolicy


func setup(p_simulation: Node) -> void:
	simulation = p_simulation
	if simulation.world_session != null:
		placement_service = simulation.world_session.building_placement_service
		session_layer = simulation.world_session.placement_layer
	session_policy = PlacementPolicy.session()
	session_policy.min_building_gap = 1
	session_policy.refusal_check = _game_policy_refusal


func can_hero_build() -> bool:
	return not simulation.is_first_person or simulation.player_citizen == simulation.hero_citizen


func building_cost() -> int:
	return BuildingCatalog.cost_for(simulation.build_mode)


func can_pay_building_cost(building_type: String) -> bool:
	return bool(simulation.building_availability_service.placement_state_with_inventory(building_type, simulation.pocket).allowed)


func pay_building_cost(building_type: String) -> void:
	simulation.settlement.pay_for_building(building_type)


func rotated_footprint(footprint: Vector2i, rotation_quarters := -1) -> Vector2i:
	var quarters := rotation_quarters if rotation_quarters >= 0 else (int(simulation.build_rotation_quarters) if simulation != null else 0)
	return Vector2i(footprint.y, footprint.x) if quarters % 2 != 0 else footprint


func placement_key(world_position: Vector3) -> Vector2i:
	var terrain := _terrain()
	return terrain.cell_from_position(world_position) if terrain != null else Vector2i(roundi(world_position.x), roundi(world_position.z))


func can_place(world_position: Vector3) -> bool:
	var plan := plan_placement(world_position)
	return plan != null and plan.ok


func plan_placement(world_position: Vector3) -> PlacementPlan:
	var blueprint := authored_blueprint(simulation.build_mode)
	var terrain := _terrain()
	if blueprint == null or terrain == null or placement_service == null:
		return PlacementPlan.refused(PlacementPlan.REASON_NO_BLUEPRINT)
	var orientation := BuildingFootprint.normalized_orientation(simulation.build_rotation_quarters)
	var span := Vector2i(blueprint.footprint.y, blueprint.footprint.x) if orientation % 2 == 1 else blueprint.footprint
	var origin := _origin_for_center(world_position, span, terrain.cell_size)
	return placement_service.plan(
		blueprint, origin, orientation, PlacementLevel.MODE_MEDIAN, 0, session_policy)


func commit_placement(plan: PlacementPlan) -> MapPlacementRecord:
	if plan == null or not plan.ok or placement_service == null:
		return null
	var blueprint := plan.footprint.blueprint if plan.footprint != null else null
	var record := placement_service.commit(plan, blueprint)
	if record != null:
		record.owner = &"session"
		record.state = &"construction_site"
	return record


func bind_placement(node: Node3D, record: MapPlacementRecord) -> void:
	if is_instance_valid(node) and record != null:
		node.set_meta("session_placement_id", record.id)


func mark_placement_ready(node: Node3D) -> void:
	var record := placement_for_node(node)
	if record != null:
		record.state = MapPlacementRecord.STATE_READY


func update_placement_blueprint(node: Node3D, building_type: String) -> bool:
	var record := placement_for_node(node)
	var blueprint := authored_blueprint(building_type)
	return placement_service != null and record != null \
		and placement_service.update_blueprint_reference(record, blueprint)


func placement_for_node(node: Node3D) -> MapPlacementRecord:
	if not is_instance_valid(node) or session_layer == null:
		return null
	return session_layer.by_id(StringName(node.get_meta("session_placement_id", "")))


func release_placement(node: Node3D) -> bool:
	var record := placement_for_node(node)
	if record == null or record.owner != &"session" or placement_service == null:
		return false
	var released := placement_service.release(record)
	if released and is_instance_valid(node) and node.has_meta("session_placement_id"):
		node.remove_meta("session_placement_id")
	return released


func reset_session_placements() -> void:
	if session_layer == null or placement_service == null:
		return
	for record: MapPlacementRecord in session_layer.placements.duplicate():
		if record.owner == &"session":
			placement_service.release(record)


func restore_placement(
		building_type: String, saved_placement: Dictionary, fallback_position: Vector3,
		fallback_orientation: int, fallback_state: StringName,
) -> Dictionary:
	var blueprint := authored_blueprint(building_type)
	var terrain := _terrain()
	if blueprint == null or terrain == null or placement_service == null:
		return {}
	var origin: Vector2i
	var orientation := BuildingFootprint.normalized_orientation(fallback_orientation)
	var level_mode := PlacementLevel.MODE_MEDIAN
	var level_value := 0
	var placement_id := &""
	if not saved_placement.is_empty():
		var saved_record := MapPlacementRecord.from_dict(saved_placement)
		origin = saved_record.cell
		orientation = saved_record.orientation
		level_mode = PlacementLevel.MODE_MANUAL
		level_value = saved_record.level_value
		placement_id = saved_record.id
	else:
		var span := Vector2i(blueprint.footprint.y, blueprint.footprint.x) if orientation % 2 == 1 else blueprint.footprint
		origin = _origin_for_center(fallback_position, span, terrain.cell_size)
		level_value = roundi(fallback_position.y / TerrainGrid.HEIGHT_STEP)
	var restore_policy := PlacementPolicy.editor()
	var plan := placement_service.plan(blueprint, origin, orientation, level_mode, level_value, restore_policy)
	if not plan.ok:
		return {}
	var record := placement_service.commit(plan, blueprint, placement_id)
	if record == null:
		return {}
	record.owner = &"session"
	record.state = fallback_state
	return {
		"record": record,
		"position": world_position_for_plan(plan),
		"cell": registry_cell_for_plan(plan),
		"footprint": plan.footprint.span(),
		"orientation": plan.footprint.orientation,
	}


func authored_blueprint(building_type: String) -> BuildingBlueprint:
	if building_type.is_empty():
		return null
	var key := BuildingBlueprintLibrary.resolve_role(StringName(building_type))
	return BuildingBlueprintLibrary.get_blueprint(key) if not key.is_empty() else null


func world_position_for_plan(plan: PlacementPlan) -> Vector3:
	if plan == null or plan.footprint == null:
		return Vector3.INF
	var cell_size := _terrain().cell_size
	var span := plan.footprint.span()
	return Vector3(
		(float(plan.footprint.origin.x) + float(span.x) * 0.5) * cell_size,
		float(plan.level) * TerrainGrid.HEIGHT_STEP,
		(float(plan.footprint.origin.y) + float(span.y) * 0.5) * cell_size)


func registry_cell_for_plan(plan: PlacementPlan) -> Vector2i:
	var span := plan.footprint.span()
	return plan.footprint.origin + Vector2i((span.x - 1) >> 1, (span.y - 1) >> 1)


func placement_message(plan: PlacementPlan) -> String:
	return plan.reason_text() if plan != null else "Construction is not allowed at this point."


func snapped_build_position(world_position: Vector3) -> Vector3:
	if not simulation.build_mode.is_empty():
		var plan := plan_placement(world_position)
		if plan != null and plan.footprint != null:
			return world_position_for_plan(plan)
	var snapped := Vector3(roundf(world_position.x), world_position.y, roundf(world_position.z))
	var ground_height: float = simulation.terrain_height_at(snapped.x, snapped.z, world_position.y)
	if not is_nan(ground_height):
		snapped.y = ground_height
	return snapped


func _origin_for_center(world_position: Vector3, span: Vector2i, cell_size: float) -> Vector2i:
	return Vector2i(
		roundi(world_position.x / cell_size - float(span.x) * 0.5),
		roundi(world_position.z / cell_size - float(span.y) * 0.5))


func _terrain() -> TerrainGrid:
	return simulation.world_setup.terrain_grid if simulation != null and simulation.world_setup != null else null


func _game_policy_refusal(plan: PlacementPlan) -> Dictionary:
	if plan == null or plan.footprint == null:
		return {"message": "Construction plan is incomplete."}
	var rect := plan.footprint.rect().grow(1)
	for site in simulation.dig_sites:
		if is_instance_valid(site.node) and rect.has_point(_terrain().cell_from_position(site.node.global_position)):
			return {"message": "Construction overlaps an excavation site."}
	var blocked: Dictionary = simulation.terrain_blocked_cells.duplicate()
	if simulation.world_session != null:
		blocked.merge(simulation.world_session.base_navigation_blocked_cells(), true)
	for cell: Vector2i in plan.footprint.cells():
		if blocked.has(cell):
			return {"message": "Construction overlaps a blocking map object."}
	var center_cell := registry_cell_for_plan(plan)
	var territory_reason: StringName = simulation.village_territory_service.placement_reason(
		simulation.build_mode, center_cell, plan.footprint.span())
	if territory_reason != simulation.village_territory_service.REASON_OK:
		return {
			"reason": territory_reason,
			"message": simulation.village_territory_service.placement_message(territory_reason),
		}
	return {}
