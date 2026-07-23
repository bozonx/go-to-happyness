## Scene fact collector that projects needs state into AI facts.
class_name NeedsFactCollector
extends RefCounted

## Collects personal needs facts (sleep, meal, toilet, rest) for one citizen.

func collect(ctx: FacadeContext, canteen_service: CanteenService) -> Dictionary:
	var actor := ctx.actor
	var citizen_id := ctx.citizen_id
	var actor_work_time := ctx.actor_work_time

	var can_start_personal_need := not actor.is_player_controlled and actor.state in [Citizen.State.IDLE, Citizen.State.WAITING]
	var critically_hungry := actor.hunger <= 15.0
	var dangerously_tired := actor.is_dangerously_tired()
	var needs_service: CitizenNeedsService = ctx.simulation.citizen_needs_service
	var rest_request := needs_service.rest_request(citizen_id) if needs_service != null else {}
	var home_position := ctx.helpers.home_entrance_position(actor.home)
	var can_reach_home: bool = home_position != Vector3.INF and bool(ctx.simulation._is_route_reachable(actor.global_position, home_position))
	var can_reach_canteen: bool = is_instance_valid(ctx.simulation.canteen) and bool(ctx.simulation._is_route_reachable(actor.global_position, ctx.simulation.canteen_position))
	var rest_position: Variant = rest_request.get(&"position", Vector3.INF)
	var can_reach_rest: bool = rest_position is Vector3 and rest_position != Vector3.INF and bool(ctx.simulation._is_route_reachable(actor.global_position, rest_position))
	var relief_candidates: Array[Dictionary] = []
	if needs_service != null and needs_service.has_toilet_request(citizen_id):
		relief_candidates = needs_service.relief_candidates_for(actor)

	return {
		&"hero": actor.is_hero,
		&"needs.should_sleep": not actor_work_time,
		&"work.overtime.active": actor.has_active_overtime(ctx.simulation.day_cycle.current_day),
		&"needs.fatigue_level": actor.fatigue,
		&"needs.hunger_level": actor.hunger,
		&"needs.dangerously_tired": dangerously_tired,
		&"needs.recovering": actor.is_recovering(ctx.simulation.day_cycle.current_day),
		&"needs.has_home": is_instance_valid(actor.home),
		&"needs.home_reachable": can_reach_home,
		&"needs.home_position": home_position,
		# Survival overrides may interrupt work. Ordinary needs wait until the
		# actor is idle, preserving stable work cycles.
		&"needs.can_start_sleep": (can_start_personal_need or dangerously_tired) and can_reach_home,
		&"needs.meal_requested": canteen_service != null and canteen_service.is_meal_requested(citizen_id),
		&"needs.can_start_meal": canteen_service != null and (can_start_personal_need or critically_hungry) and can_reach_canteen,
		&"needs.canteen_position": ctx.simulation.canteen_position,
		&"needs.toilet_requested": needs_service != null and needs_service.has_toilet_request(citizen_id),
		&"needs.can_start_toilet": can_start_personal_need,
		&"needs.relief_candidates": relief_candidates,
		&"needs.rest_requested": needs_service != null and needs_service.has_rest_request(citizen_id),
		&"needs.can_start_rest": can_start_personal_need and can_reach_rest,
		&"needs.rest_position": rest_position,
		&"needs.rest_duration": rest_request.get(&"duration", 4.0),
	}
