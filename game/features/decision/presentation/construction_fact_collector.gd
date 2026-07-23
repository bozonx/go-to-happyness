## Scene fact collector for construction.
class_name ConstructionFactCollector
extends RefCounted

## Collects construction and daily-construction facts for one citizen.

func collect(ctx: FacadeContext) -> Dictionary:
	var actor := ctx.actor
	var citizen_id := ctx.citizen_id
	var actor_work_time := ctx.actor_work_time
	var daily_order_active := ctx.daily_order_active
	var daily_order_role := ctx.daily_order_role

	var construction_worker := actor.permanent_role == "construction" and actor.is_employed() and not actor.is_player_controlled
	var construction_in_progress := construction_worker and actor.active_role in ["construction", "demolition"] and actor.state == Citizen.State.CONSTRUCTING and is_instance_valid(actor.construction_site)
	var construction_can_start := false
	var construction_mode: StringName = &""
	var construction_target_key: StringName = &""
	var construction_position := Vector3.INF
	if construction_in_progress:
		construction_mode = StringName(actor.active_role)
		construction_target_key = ctx.helpers.target_key(construction_mode, actor.construction_site.global_position)
		construction_position = actor._reachable_construction_approach(actor.construction_site)
	elif construction_worker and actor_work_time:
		if not ctx.simulation.demolition_sites.is_empty():
			var demolition_site: DemolitionSite = ctx.simulation.demolition_sites[(citizen_id - 1) % ctx.simulation.demolition_sites.size()]
			if is_instance_valid(demolition_site.building):
				construction_mode = &"demolition"
				construction_target_key = ctx.helpers.target_key(&"demolition", demolition_site.building.global_position)
				construction_position = actor._reachable_construction_approach(demolition_site.building)
		else:
			var construction_site := _construction_site_for(ctx, actor)
			if construction_site != null and is_instance_valid(construction_site.node):
				construction_mode = &"construction"
				construction_target_key = ctx.helpers.target_key(&"construction", construction_site.node.global_position)
				construction_position = actor._reachable_construction_approach(construction_site.node)
		construction_can_start = construction_target_key != &"" and construction_position != Vector3.INF

	var daily_construction_in_progress := daily_order_active and daily_order_role == "construction" and actor.active_role in ["construction", "demolition"] and actor.state == Citizen.State.CONSTRUCTING and is_instance_valid(actor.construction_site)
	var daily_construction_can_start := false
	var daily_construction_mode: StringName = &""
	var daily_construction_target_key: StringName = &""
	var daily_construction_position := Vector3.INF
	if daily_construction_in_progress:
		daily_construction_mode = StringName(actor.active_role)
		daily_construction_target_key = ctx.helpers.target_key(daily_construction_mode, actor.construction_site.global_position)
		daily_construction_position = actor._reachable_construction_approach(actor.construction_site)
	elif daily_order_role == "construction":
		if not ctx.simulation.demolition_sites.is_empty():
			var daily_demolition_site: DemolitionSite = ctx.simulation.demolition_sites[(citizen_id - 1) % ctx.simulation.demolition_sites.size()]
			if is_instance_valid(daily_demolition_site.building):
				daily_construction_mode = &"demolition"
				daily_construction_target_key = ctx.helpers.target_key(&"demolition", daily_demolition_site.building.global_position)
				daily_construction_position = actor._reachable_construction_approach(daily_demolition_site.building)
		else:
			var daily_construction_site := _construction_site_for(ctx, actor)
			if daily_construction_site != null and is_instance_valid(daily_construction_site.node):
				daily_construction_mode = &"construction"
				daily_construction_target_key = ctx.helpers.target_key(&"construction", daily_construction_site.node.global_position)
				daily_construction_position = actor._reachable_construction_approach(daily_construction_site.node)
		daily_construction_can_start = daily_construction_target_key != &"" and daily_construction_position != Vector3.INF

	return {
		&"work.construction.worker": construction_worker,
		&"work.construction.in_progress": construction_in_progress,
		&"work.construction.can_start": construction_can_start,
		&"work.construction.mode": construction_mode,
		&"work.construction.target_key": construction_target_key,
		&"work.construction.position": construction_position,
		&"daily.construction.in_progress": daily_construction_in_progress,
		&"daily.construction.can_start": daily_construction_can_start,
		&"daily.construction.mode": daily_construction_mode,
		&"daily.construction.target_key": daily_construction_target_key,
		&"daily.construction.position": daily_construction_position,
	}


func _construction_site_for(ctx: FacadeContext, actor: Citizen) -> ConstructionSite:
	if not is_instance_valid(actor):
		return null
	var preferred: ConstructionSite = ctx.simulation._preferred_construction_site()
	if preferred != null and is_instance_valid(preferred.node) and actor._reachable_construction_approach(preferred.node) != Vector3.INF:
		return preferred
	var best: ConstructionSite = null
	var best_score := -INF
	for candidate: ConstructionSite in ctx.simulation.construction_sites:
		if candidate == null or not is_instance_valid(candidate.node) or candidate.node.is_queued_for_deletion():
			continue
		if actor._reachable_construction_approach(candidate.node) == Vector3.INF:
			continue
		var score: float = ctx.simulation.construction_priority_service.development_priority(candidate) if ctx.simulation.construction_priority_service != null else 0.0
		if score > best_score:
			best = candidate
			best_score = score
	return best
