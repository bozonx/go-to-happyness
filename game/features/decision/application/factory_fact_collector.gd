class_name FactoryFactCollector
extends RefCounted

## Collects factory work facts (factory_worker, engineer, builder at materials
## factory) for one citizen.

func collect(ctx: FacadeContext) -> Dictionary:
	var actor := ctx.actor
	var actor_work_time := ctx.actor_work_time

	var factory_worker := actor.permanent_role in ["factory_worker", "engineer"] and actor.is_employed() and not actor.is_player_controlled
	var factory_role: StringName = &""
	var factory_node: Node3D
	if actor.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK] and is_instance_valid(actor.factory):
		if factory_worker:
			factory_role = &"factory_work" if actor.permanent_role == "factory_worker" else &"engineering"
			factory_node = actor.factory
		elif actor.permanent_role == "construction" and actor.specialization == "builder":
			factory_role = &"construction"
			factory_node = actor.factory
	elif factory_worker and actor_work_time and is_instance_valid(actor.employment_workplace):
		factory_role = &"factory_work" if actor.permanent_role == "factory_worker" else &"engineering"
		factory_node = actor.employment_workplace as Node3D
	elif actor.permanent_role == "construction" and actor.specialization == "builder" and actor_work_time and ctx.simulation.construction_sites.is_empty() and ctx.simulation.demolition_sites.is_empty():
		for factory_value in ctx.simulation.factories:
			var candidate_factory := factory_value as Node3D
			if is_instance_valid(candidate_factory) and candidate_factory.get_meta("building_type", "") == "materials_factory":
				factory_node = candidate_factory
				factory_role = &"construction"
				break
	var factory_in_progress: bool = factory_role != &"" and actor.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]
	var factory_can_start: bool = factory_role != &"" and is_instance_valid(factory_node)
	var factory_position: Vector3 = Vector3.INF
	if is_instance_valid(factory_node):
		var factory_position_value: Variant = factory_node.get_meta("service_position", factory_node.global_position)
		if factory_position_value is Vector3:
			factory_position = factory_position_value
	factory_can_start = factory_can_start and factory_position != Vector3.INF and ctx.simulation._is_route_reachable(actor.global_position, factory_position)

	return {
		&"work.factory.worker": factory_worker or factory_role == &"construction",
		&"work.factory.in_progress": factory_in_progress,
		&"work.factory.can_start": factory_can_start,
		&"work.factory.role": factory_role,
		&"work.factory.target_key": ctx.helpers.target_key(&"factory", factory_node.global_position) if is_instance_valid(factory_node) else &"",
		&"work.factory.position": factory_position,
	}
