## Scene fact collector for forestry.
class_name ForestryFactCollector
extends RefCounted

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

## Collects forestry work facts for one citizen.

func collect(ctx: FacadeContext) -> Dictionary:
	var actor := ctx.actor
	var actor_work_time := ctx.actor_work_time

	var forestry_worker := actor.permanent_role == "forestry" and actor.is_employed() and not actor.is_player_controlled
	var sawmill_position := Vector3.INF
	var warehouse_position := Vector3.INF
	if forestry_worker and actor_work_time and not ctx.simulation.sawmill_positions.is_empty() and not ctx.simulation.warehouse_positions.is_empty() and ctx.simulation.storage_routing_service.has_storage_room_for_role("forestry"):
		sawmill_position = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else ctx.simulation.sawmill_positions[0]
		warehouse_position = ctx.helpers.storage_position_for(actor.global_position, ResourceIds.BOARDS)
	var forestry_in_progress := actor.state in [Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL]
	var forestry_candidates: Array[Dictionary] = []
	if forestry_worker and actor_work_time and not forestry_in_progress and sawmill_position != Vector3.INF and warehouse_position != Vector3.INF:
		forestry_candidates = _cached_forestry_targets(ctx, actor, sawmill_position, warehouse_position)

	return {
		&"work.forestry.worker": forestry_worker,
		&"work.forestry.in_progress": forestry_in_progress,
		&"work.forestry.can_start": sawmill_position != Vector3.INF and warehouse_position != Vector3.INF,
		&"work.forestry.sawmill_position": sawmill_position,
		&"work.forestry.warehouse_position": warehouse_position,
		&"work.forestry.candidates": forestry_candidates,
	}


func _cached_forestry_targets(ctx: FacadeContext, actor: Citizen, sawmill_position: Vector3, warehouse_position: Vector3) -> Array[Dictionary]:
	var key := StringName("forestry:%d" % actor.ai_id)
	return ctx.helpers.cached_route_candidates(key, actor.global_position, func() -> Array[Dictionary]:
		return _forestry_targets(ctx, actor.global_position, sawmill_position, warehouse_position)
	)


func _forestry_targets(ctx: FacadeContext, from: Vector3, sawmill_position: Vector3, warehouse_position: Vector3) -> Array[Dictionary]:
	var nearby: Array[Dictionary] = []
	for tree_position: Vector3 in ctx.simulation.tree_positions:
		var cell: Vector2i = ctx.simulation._cell_from_position(tree_position)
		var tree: Node3D = ctx.simulation.tree_nodes.get(cell) as Node3D
		if not is_instance_valid(tree) or bool(tree.get_meta("felled", false)):
			continue
		var access := ctx.helpers.resource_access_position(tree_position, from)
		if access == Vector3.INF:
			continue
		ctx.helpers.insert_nearby_gathering_candidate(nearby, {
			&"id": StringName("tree:%d:%d" % [cell.x, cell.y]),
			&"position": tree_position,
			&"access": access,
			&"direct_distance": from.distance_squared_to(access) if from != Vector3.INF else 0.0,
		})
	var targets: Array[Dictionary] = []
	for candidate in nearby:
		var access: Vector3 = candidate[&"access"]
		if sawmill_position != Vector3.INF and not ctx.simulation._is_route_reachable(access, sawmill_position):
			continue
		if warehouse_position != Vector3.INF and not ctx.simulation._is_route_reachable(sawmill_position, warehouse_position):
			continue
		var cost := ctx.helpers.route_cost(from, access)
		if cost >= INF:
			continue
		candidate[&"route_cost"] = cost
		candidate.erase(&"direct_distance")
		targets.append(candidate)
	return targets
