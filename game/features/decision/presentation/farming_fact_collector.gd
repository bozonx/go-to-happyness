## Scene fact collector for farming.
class_name FarmingFactCollector
extends RefCounted

const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")

## Collects farming work facts for one citizen.

func collect(ctx: FacadeContext) -> Dictionary:
	var actor := ctx.actor
	var actor_work_time := ctx.actor_work_time

	var farming_worker := actor.permanent_role == "farming" and actor.is_employed() and not actor.is_player_controlled
	var farming_in_progress := farming_worker and actor.active_role == "farming" and actor.state in [Citizen.State.TO_TREE, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER]
	var farming_position := Vector3.INF
	var farming_warehouse_position := Vector3.INF
	if farming_in_progress:
		farming_position = actor.workplace_position
		farming_warehouse_position = actor.warehouse_position
	elif farming_worker and not ctx.simulation.farm_positions.is_empty() and not ctx.simulation.warehouse_positions.is_empty():
		farming_position = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else ctx.simulation.farm_positions[0]
		farming_warehouse_position = ctx.helpers.storage_position_for(actor.global_position, ResourceIds.FOOD)
	var farming_can_start: bool = farming_worker and actor_work_time and ctx.simulation.storage_routing_service.has_storage_room_for_role("farming") and farming_position != Vector3.INF and farming_warehouse_position != Vector3.INF and ctx.simulation._is_route_reachable(actor.global_position, farming_position) and ctx.simulation._is_route_reachable(farming_position, farming_warehouse_position)

	return {
		&"work.farming.worker": farming_worker,
		&"work.farming.in_progress": farming_in_progress,
		&"work.farming.can_start": farming_can_start,
		&"work.farming.position": farming_position,
		&"work.farming.warehouse_position": farming_warehouse_position,
	}
