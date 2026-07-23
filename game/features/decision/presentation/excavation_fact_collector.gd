## Scene fact collector for excavation.
class_name ExcavationFactCollector
extends RefCounted

## Collects excavation work facts for one citizen.

func collect(ctx: FacadeContext) -> Dictionary:
	var actor := ctx.actor
	var actor_work_time := ctx.actor_work_time

	var excavation_worker := actor.permanent_role == "excavation" and actor.is_employed() and not actor.is_player_controlled
	var excavation_in_progress := excavation_worker and actor.active_role == "excavation" and actor.state in [Citizen.State.EXCAVATING, Citizen.State.WAITING_COURIER]
	var excavation_candidates: Array[Dictionary] = []
	if excavation_worker and actor_work_time:
		for dig_site in ctx.simulation.dig_sites:
			if not is_instance_valid(dig_site.node) or not ctx.simulation._can_work_at_dig_site(dig_site):
				continue
			if not ctx.simulation._is_route_reachable(actor.global_position, dig_site.node.global_position):
				continue
			excavation_candidates.append({
				&"id": ctx.helpers.target_key(&"dig", dig_site.node.global_position),
				&"target_key": ctx.helpers.target_key(&"dig", dig_site.node.global_position),
				&"position": dig_site.node.global_position,
			})

	return {
		&"work.excavation.worker": excavation_worker,
		&"work.excavation.in_progress": excavation_in_progress,
		&"work.excavation.candidates": excavation_candidates,
	}
