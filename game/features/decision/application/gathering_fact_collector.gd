class_name GatheringFactCollector
extends RefCounted

const ResourcePileScript = preload("res://game/features/logistics/domain/resource_pile.gd")

## Collects permanent gathering, daily gathering, and daily cleaning facts for
## one citizen.

func collect(ctx: FacadeContext) -> Dictionary:
	var actor := ctx.actor
	var actor_work_time := ctx.actor_work_time
	var daily_order_active := ctx.daily_order_active
	var daily_order_role := ctx.daily_order_role

	var gathering_worker: bool = actor.permanent_role in ["gather_branches", "gather_food"] and actor.is_employed() and not actor.is_player_controlled
	var gathering_in_progress: bool = gathering_worker and actor.active_role.begins_with("gather_") and actor.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE]
	var gathering_candidates: Array[Dictionary] = []
	if gathering_worker and actor_work_time and not gathering_in_progress and ctx.simulation._has_storage_room_for_role(actor.permanent_role):
		if actor.permanent_role == "gather_food":
			gathering_candidates = _cached_food_gathering_targets(ctx, actor)
		elif actor.permanent_role == "gather_branches":
			gathering_candidates = _cached_daily_gathering_targets(ctx, actor, "gather_branches")
	var daily_gathering_in_progress := daily_order_active and daily_order_role.begins_with("gather_") and actor.active_role.begins_with("gather_") and actor.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE]
	var daily_gathering_candidates: Array[Dictionary] = []
	if daily_order_role.begins_with("gather_"):
		daily_gathering_candidates = _cached_daily_gathering_targets(ctx, actor, daily_order_role)
	var daily_gathering_can_start := daily_order_active and daily_order_role.begins_with("gather_") and not daily_gathering_candidates.is_empty()
	var daily_cleaning_in_progress := daily_order_active and daily_order_role == "cleaning" and actor.active_role == "cleaning" and actor.state in [Citizen.State.TO_CLEANING_PILE, Citizen.State.CLEANING_PILE, Citizen.State.TO_WAREHOUSE]
	var daily_cleaning_candidates: Array[Dictionary] = []
	if daily_order_role == "cleaning" and daily_order_active and actor_work_time:
		daily_cleaning_candidates = _cleaning_targets(ctx, actor)
	var daily_cleaning_can_start: bool = daily_order_active and daily_order_role == "cleaning" and actor_work_time and not daily_cleaning_candidates.is_empty()

	return {
		&"work.gathering.worker": gathering_worker,
		&"work.gathering.in_progress": gathering_in_progress,
		&"work.gathering.can_start": gathering_worker and actor_work_time and not gathering_candidates.is_empty() and _gathering_warehouse_position(ctx, actor, gathering_candidates, actor.permanent_role) != Vector3.INF,
		&"work.gathering.role": StringName(actor.permanent_role) if gathering_worker else &"",
		&"work.gathering.candidates": gathering_candidates,
		&"work.gathering.warehouse_position": _gathering_warehouse_position(ctx, actor, gathering_candidates, actor.permanent_role) if gathering_worker else Vector3.INF,
		&"daily.gathering.in_progress": daily_gathering_in_progress,
		&"daily.gathering.can_start": daily_gathering_can_start,
		&"daily.gathering.role": StringName(daily_order_role) if daily_order_role.begins_with("gather_") else &"",
		&"daily.gathering.candidates": daily_gathering_candidates,
		&"daily.gathering.warehouse_position": _gathering_warehouse_position(ctx, actor, daily_gathering_candidates, daily_order_role) if daily_order_role.begins_with("gather_") else Vector3.INF,
		&"daily.cleaning.in_progress": daily_cleaning_in_progress,
		&"daily.cleaning.can_start": daily_cleaning_can_start,
		&"daily.cleaning.candidates": daily_cleaning_candidates,
		&"daily.cleaning.warehouse_position": _cleaning_warehouse_position(ctx, actor, daily_cleaning_candidates) if daily_order_role == "cleaning" else Vector3.INF,
	}


func _gathering_warehouse_position(ctx: FacadeContext, actor: Citizen, candidates: Array[Dictionary], role: String) -> Vector3:
	if role == "gather_food" and is_instance_valid(actor.employment_workplace):
		return actor.employment_workplace.get_meta("service_position", actor.employment_workplace.global_position)
	if not candidates.is_empty():
		var first_position: Variant = candidates[0].get(&"position", actor.global_position)
		var resource_type := str(candidates[0].get(&"resource_type", ""))
		if first_position is Vector3:
			var storage_position := ctx.helpers.storage_position_for(first_position as Vector3, resource_type)
			if storage_position != Vector3.INF:
				return storage_position
		# Manual gathering remains useful before a warehouse exists or when all
		# storage is full. Deliver at the walkable source access point and let the
		# storage service leave the cargo in a ground pile.
		var access_position: Variant = candidates[0].get(&"access", Vector3.INF)
		if access_position is Vector3:
			return access_position
	return Vector3.INF


func _cleaning_warehouse_position(ctx: FacadeContext, actor: Citizen, candidates: Array[Dictionary]) -> Vector3:
	if not candidates.is_empty():
		var resource_type := str(candidates[0].get(&"resource_type", ""))
		return ctx.helpers.storage_position_for(actor.global_position, resource_type)
	return Vector3.INF


func _cached_food_gathering_targets(ctx: FacadeContext, actor: Citizen) -> Array[Dictionary]:
	var key := StringName("gather_food:%d" % actor.ai_id)
	return ctx.helpers.cached_route_candidates(key, actor.global_position, func() -> Array[Dictionary]:
		return _food_gathering_targets(ctx, actor)
	)


func _cached_daily_gathering_targets(ctx: FacadeContext, actor: Citizen, role: String) -> Array[Dictionary]:
	var key := StringName("%s:%d" % [role, actor.ai_id])
	return ctx.helpers.cached_route_candidates(key, actor.global_position, func() -> Array[Dictionary]:
		return _daily_gathering_targets_for(ctx, actor, role)
	)


func _food_gathering_targets(ctx: FacadeContext, actor: Citizen) -> Array[Dictionary]:
	var nearby: Array[Dictionary] = []
	if not is_instance_valid(actor) or ctx.simulation.forager_positions.is_empty() or ctx.simulation.warehouse_positions.is_empty():
		return nearby
	for cell_value in ctx.simulation.forage_sources:
		var cell := cell_value as Vector2i
		var node := (ctx.simulation.forage_sources[cell] as Dictionary).get("node") as Node3D
		if is_instance_valid(node):
			ctx.helpers.insert_nearby_gathering_candidate(nearby, {&"id": StringName("plant:%d:%d" % [cell.x, cell.y]), &"resource_type": "food", &"position": node.global_position, &"access": node.global_position, &"direct_distance": actor.global_position.distance_squared_to(node.global_position)})
	for cell_value in ctx.simulation.rabbit_sources:
		var cell := cell_value as Vector2i
		var node := (ctx.simulation.rabbit_sources[cell] as Dictionary).get("node") as Node3D
		if is_instance_valid(node):
			ctx.helpers.insert_nearby_gathering_candidate(nearby, {&"id": StringName("rabbit:%d:%d" % [cell.x, cell.y]), &"resource_type": "food", &"position": node.global_position, &"access": node.global_position, &"direct_distance": actor.global_position.distance_squared_to(node.global_position)})
	var targets: Array[Dictionary] = []
	for candidate in nearby:
		var route_cost := ctx.helpers.route_cost(actor.global_position, candidate[&"access"] as Vector3)
		if route_cost >= INF:
			continue
		candidate[&"route_cost"] = route_cost
		candidate.erase(&"direct_distance")
		targets.append(candidate)
	return targets


func _daily_gathering_targets_for(ctx: FacadeContext, actor: Citizen, role: String) -> Array[Dictionary]:
	var nearby: Array[Dictionary] = []
	if not is_instance_valid(actor):
		return nearby
	match role:
		"gather_branches":
			for tree_position: Vector3 in ctx.simulation.tree_positions:
				var tree_cell: Vector2i = ctx.simulation._cell_from_position(tree_position)
				var tree := ctx.simulation.tree_nodes.get(tree_cell) as Node3D
				if not is_instance_valid(tree) or bool(tree.get_meta("felled", false)) or int(tree.get_meta("remaining_branches", 0)) <= 0:
					continue
				if not ctx.has_tool("axe"):
					var initial_branches := int(tree.get_meta("initial_branches", tree.get_meta("remaining_branches", 0)))
					var hand_limit := ceili(float(initial_branches) * 0.3)
					if int(tree.get_meta("hand_branches", 0)) >= hand_limit:
						continue
				var access := ctx.helpers.resource_access_position(tree_position)
				if access != Vector3.INF:
					ctx.helpers.insert_nearby_gathering_candidate(nearby, {
						&"id": StringName("branch:%d:%d" % [tree_cell.x, tree_cell.y]),
						&"resource_type": "branches",
						&"position": tree_position,
						&"access": access,
						&"direct_distance": actor.global_position.distance_squared_to(access),
					})
		"gather_grass":
			for grass_cell_value in ctx.simulation.grass_sources.keys():
				var grass_cell := grass_cell_value as Vector2i
				var grass_source := ctx.simulation.grass_sources.get(grass_cell, {}) as Dictionary
				var grass_node := grass_source.get(&"node") as Node3D
				if int(grass_source.get(&"remaining", 0)) > 0 and is_instance_valid(grass_node):
					var access := ctx.helpers.resource_access_position(grass_node.global_position)
					if access != Vector3.INF:
						ctx.helpers.insert_nearby_gathering_candidate(nearby, {
							&"id": StringName("grass:%d:%d" % [grass_cell.x, grass_cell.y]),
							&"resource_type": "grass",
							&"position": grass_node.global_position,
							&"access": access,
							&"direct_distance": actor.global_position.distance_squared_to(access),
						})
		"gather_water":
			for pond_position: Vector3 in ctx.simulation.pond_positions:
				var access: Vector3 = ctx.simulation._pond_access_position(actor.global_position, pond_position)
				if access != Vector3.INF:
					ctx.helpers.insert_nearby_gathering_candidate(nearby, {
						&"id": ctx.helpers.target_key(&"water", access),
						&"resource_type": "water",
						&"position": access,
						&"access": access,
						&"direct_distance": actor.global_position.distance_squared_to(access),
					})
	var targets: Array[Dictionary] = []
	for candidate in nearby:
		var route_cost := ctx.helpers.route_cost(actor.global_position, candidate[&"access"] as Vector3)
		if route_cost >= INF:
			continue
		candidate[&"route_cost"] = route_cost
		candidate.erase(&"direct_distance")
		targets.append(candidate)
	return targets


func _cleaning_targets(ctx: FacadeContext, actor: Citizen) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if not is_instance_valid(actor) or ctx.simulation.warehouse_positions.is_empty():
		return targets
	for pile: ResourcePileScript in ctx.simulation.resource_piles:
		var pile_node := pile.node
		if not is_instance_valid(pile_node) or not ctx.simulation._is_route_reachable(actor.global_position, pile_node.global_position):
			continue
		var pile_cell: Vector2i = ctx.simulation._cell_from_position(pile_node.global_position)
		for resource_type in pile.resources:
			var available := int(pile.resources[resource_type]) - int(pile.reserved.get(resource_type, 0))
			if available <= 0 or not ctx.simulation.settlement.can_make_room_for(str(resource_type), 1, ctx.simulation.warehouse_positions.size()):
				continue
			targets.append({
				&"id": StringName("pile:%d:%d:%s" % [pile_cell.x, pile_cell.y, str(resource_type)]),
				&"pile_id": StringName("pile:%d:%d" % [pile_cell.x, pile_cell.y]),
				&"resource_type": str(resource_type),
				&"position": pile_node.global_position,
				&"access": pile_node.global_position,
			})
	# The starter backpack is a non-decaying pile that couriers can empty into warehouses.
	if ctx.simulation.backpack_position != Vector3.ZERO and ctx.simulation._is_route_reachable(actor.global_position, ctx.simulation.backpack_position):
		var backpack_cell: Vector2i = ctx.simulation._cell_from_position(ctx.simulation.backpack_position)
		var backpack: Dictionary = ctx.backpack_resources()
		for resource_type in backpack:
			var available := int(backpack.get(resource_type, 0))
			if available <= 0 or not ctx.simulation.settlement.can_make_room_for(str(resource_type), 1, ctx.simulation.warehouse_positions.size()):
				continue
			targets.append({
				&"id": StringName("backpack:%d:%d:%s" % [backpack_cell.x, backpack_cell.y, str(resource_type)]),
				&"pile_id": StringName("backpack:%d:%d" % [backpack_cell.x, backpack_cell.y]),
				&"resource_type": str(resource_type),
				&"position": ctx.simulation.backpack_position,
				&"access": ctx.simulation.backpack_position,
			})
	return targets
