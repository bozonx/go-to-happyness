class_name ServiceFactCollector
extends RefCounted

## Collects service work facts (cook, teacher, seller, official, craftsman,
## researcher) for one citizen.

func collect(ctx: FacadeContext) -> Dictionary:
	var actor := ctx.actor
	var actor_work_time := ctx.actor_work_time
	var daily_order_active := ctx.daily_order_active
	var daily_order_role := ctx.daily_order_role

	var service_role := ""
	if actor.permanent_role in ["cook", "teacher", "seller", "official", "craftsman"] and actor.is_employed() and not actor.is_player_controlled:
		service_role = actor.permanent_role
	elif daily_order_active and daily_order_role in ["cook", "researcher"] and not actor.is_player_controlled:
		service_role = daily_order_role
	var service_states := {
		"cook": [Citizen.State.TO_CANTEEN_WORK, Citizen.State.CANTEEN_WORK],
		"teacher": [Citizen.State.TO_SCHOOL_WORK, Citizen.State.SCHOOL_WORK],
		"seller": [Citizen.State.TO_MARKET_WORK, Citizen.State.MARKET_WORK],
		"official": [Citizen.State.TO_OFFICIAL_WORK, Citizen.State.OFFICIAL_WORK],
		"craftsman": [Citizen.State.TO_CRAFT_WORK, Citizen.State.CRAFT_WORK],
		"researcher": [Citizen.State.RESEARCHING],
	}
	var service_in_progress: bool = not service_role.is_empty() and actor.state in (service_states.get(service_role, []) as Array)
	var service_position: Vector3 = Vector3.INF
	if service_in_progress:
		match service_role:
			"cook": service_position = actor.canteen_position
			"teacher": service_position = actor.school_position
			"seller": service_position = actor.market_position
			"official": service_position = actor.official_position
			"craftsman": service_position = actor.craft_position
			"researcher": service_position = actor.research_position
	elif not service_role.is_empty() and actor_work_time:
		if service_role == "cook":
			service_position = ctx.simulation.canteen_position if is_instance_valid(ctx.simulation.canteen) else Vector3.INF
		elif service_role == "official":
			service_position = ctx.simulation._employment_center_position()
		elif service_role == "researcher":
			service_position = ctx.simulation._employment_center_position()
		else:
			service_position = actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position) if is_instance_valid(actor.employment_workplace) else Vector3.INF
	var service_can_start: bool = not service_role.is_empty() and service_position != Vector3.INF and ctx.simulation._is_route_reachable(actor.global_position, service_position)

	return {
		&"work.service.worker": not service_role.is_empty(),
		&"work.service.in_progress": service_in_progress,
		&"work.service.can_start": service_can_start,
		&"work.service.role": StringName(service_role),
		&"work.service.position": service_position,
	}
