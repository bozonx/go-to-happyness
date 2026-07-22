class_name CitizenActuatorBridge
extends RefCounted

const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")


func execute_action(actor: Citizen, action: StringName, target: Node3D, payload: AIFactSet) -> bool:
	if actor == null or actor.is_player_controlled:
		return false
	match action:
		&"sleep", &"eat", &"relieve", &"rest", &"relax":
			return execute_personal_need_action(actor, action, payload)
		&"forestry", &"farming", &"gathering", &"cleaning", &"excavation", &"factory_work":
			return execute_production_action(actor, action, target, payload)
		&"construction", &"demolition", &"cook", &"teacher", &"seller", &"official", &"craftsman", &"researcher", &"register":
			return execute_workforce_action(actor, action, target, payload)
		&"courier_delivery":
			return execute_logistics_action(actor, action, target, payload)
	return false


func execute_personal_need_action(actor: Citizen, action: StringName, payload: AIFactSet) -> bool:
	match action:
		&"sleep":
			if not is_instance_valid(actor.home):
				return false
			actor._reset_assignment_navigation()
			actor.factory = null
			var home_entrance: Vector3 = actor.home.position
			if actor.home.is_inside_tree():
				home_entrance = actor.home.get_meta("entrance_position", actor.home.global_position)
			if actor.is_inside_tree() and actor.global_position.distance_to(home_entrance) <= 0.5:
				actor.state = Citizen.State.RESTING
			else:
				actor.state = Citizen.State.TO_HOME
			return actor.state in [Citizen.State.TO_HOME, Citizen.State.RESTING]
		&"eat":
			var destination: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			if not (destination is Vector3) or destination == Vector3.INF:
				return false
			actor._reset_assignment_navigation()
			actor.canteen_position = destination
			actor.active_role = ""
			actor.factory = null
			if actor.is_inside_tree() and actor.global_position.distance_to(destination) <= 0.5:
				actor.state = Citizen.State.EATING
				actor._start_task(1.1)
			else:
				actor.state = Citizen.State.TO_CANTEEN
			return actor.state in [Citizen.State.TO_CANTEEN, Citizen.State.EATING]
		&"relieve":
			var relief_position: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			var relief_kind: Variant = payload.value(&"target.kind", &"") if payload != null else &""
			if not (relief_position is Vector3) or relief_position == Vector3.INF or not (relief_kind is StringName):
				return false
			actor.go_to_relief(relief_position, relief_kind)
			return actor.state in [Citizen.State.TO_TOILET, Citizen.State.USING_TOILET, Citizen.State.WAITING_FOR_TOILET, Citizen.State.TO_BUSH, Citizen.State.USING_BUSH]
		&"rest":
			var rest_position: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			var rest_duration := float(payload.value(&"action.duration", 4.0)) if payload != null else 4.0
			if not (rest_position is Vector3) or rest_position == Vector3.INF:
				return false
			actor.go_to_park(rest_position, 0, rest_duration)
			return actor.state in [Citizen.State.TO_PARK, Citizen.State.RELAXING]
		&"relax":
			var relax_duration := float(payload.value(&"action.duration", 4.0)) if payload != null else 4.0
			actor.state = Citizen.State.RELAXING
			actor._start_task(relax_duration)
			return true
	return false


func execute_production_action(actor: Citizen, action: StringName, target: Node3D, payload: AIFactSet) -> bool:
	match action:
		&"forestry":
			var tree_position: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			var access_position: Variant = payload.value(&"target.access_position", Vector3.INF) if payload != null else Vector3.INF
			var sawmill_position: Variant = payload.value(&"workplace.position", Vector3.INF) if payload != null else Vector3.INF
			var warehouse_position: Variant = payload.value(&"warehouse.position", Vector3.INF) if payload != null else Vector3.INF
			if not (tree_position is Vector3) or tree_position == Vector3.INF or not (access_position is Vector3) or access_position == Vector3.INF or not (sawmill_position is Vector3) or sawmill_position == Vector3.INF or not (warehouse_position is Vector3) or warehouse_position == Vector3.INF:
				return false
			actor.start_production_cycle(ResourceIds.WOOD, tree_position, sawmill_position, warehouse_position, false, access_position)
			return actor.state in [Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL]
		&"farming":
			var farm_position: Variant = payload.value(&"workplace.position", Vector3.INF) if payload != null else Vector3.INF
			var farm_warehouse_position: Variant = payload.value(&"warehouse.position", Vector3.INF) if payload != null else Vector3.INF
			if not (farm_position is Vector3) or farm_position == Vector3.INF or not (farm_warehouse_position is Vector3) or farm_warehouse_position == Vector3.INF:
				return false
			actor.start_production_cycle(ResourceIds.FOOD, farm_position, farm_position, farm_warehouse_position, true)
			return actor.state in [Citizen.State.TO_TREE, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER]
		&"gathering":
			var resource_type: Variant = payload.value(&"resource.type", "") if payload != null else ""
			var source_position: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			var access_position: Variant = payload.value(&"target.access_position", Vector3.INF) if payload != null else Vector3.INF
			var gathering_warehouse_position: Variant = payload.value(&"warehouse.position", Vector3.INF) if payload != null else Vector3.INF
			if not (resource_type is String) or resource_type.is_empty() or not (source_position is Vector3) or source_position == Vector3.INF or not (access_position is Vector3) or access_position == Vector3.INF or not (gathering_warehouse_position is Vector3) or gathering_warehouse_position == Vector3.INF:
				return false
			actor.assign_gathering(resource_type, source_position, gathering_warehouse_position, access_position)
			return actor.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE]
		&"cleaning":
			var cleaning_resource_type: Variant = payload.value(&"resource.type", "") if payload != null else ""
			var pile_position: Variant = payload.value(&"target.position", Vector3.INF) if payload != null else Vector3.INF
			var pile_access_position: Variant = payload.value(&"target.access_position", Vector3.INF) if payload != null else Vector3.INF
			var cleaning_warehouse_position: Variant = payload.value(&"warehouse.position", Vector3.INF) if payload != null else Vector3.INF
			if not (cleaning_resource_type is String) or cleaning_resource_type.is_empty() or not (pile_position is Vector3) or pile_position == Vector3.INF or not (pile_access_position is Vector3) or pile_access_position == Vector3.INF or not (cleaning_warehouse_position is Vector3) or cleaning_warehouse_position == Vector3.INF:
				return false
			actor.assign_cleaning(cleaning_resource_type, pile_position, pile_access_position, cleaning_warehouse_position)
			return actor.state in [Citizen.State.TO_CLEANING_PILE, Citizen.State.CLEANING_PILE, Citizen.State.TO_WAREHOUSE]
		&"excavation":
			if not is_instance_valid(target):
				return false
			actor.assign_excavation(target)
			return actor.state == Citizen.State.EXCAVATING
		&"factory_work":
			var factory_role: Variant = payload.value(&"factory.role", &"") if payload != null else &""
			if not is_instance_valid(target) or not (factory_role is StringName) or factory_role == &"":
				return false
			actor.assign_factory_work(target, String(factory_role))
			return actor.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]
	return false


func execute_workforce_action(actor: Citizen, action: StringName, target: Node3D, payload: AIFactSet) -> bool:
	match action:
		&"construction", &"demolition":
			if not is_instance_valid(target):
				return false
			if action == &"construction":
				actor.assign_construction(target)
			else:
				actor.assign_demolition(target)
			return actor.state == Citizen.State.CONSTRUCTING
		&"cook", &"teacher", &"seller", &"official", &"craftsman", &"researcher":
			var service_position: Variant = payload.value(&"workplace.position", Vector3.INF) if payload != null else Vector3.INF
			if not (service_position is Vector3) or service_position == Vector3.INF:
				return false
			match action:
				&"cook": actor.assign_canteen_work(service_position)
				&"teacher": actor.assign_teacher_work(service_position)
				&"seller": actor.assign_seller_work(service_position)
				&"official": actor.assign_official_work(service_position)
				&"craftsman": actor.assign_craft_work(service_position, actor._craft_speed_multiplier_internal())
				&"researcher": actor.assign_research_work(service_position)
			return actor.state in actor._service_states_for_internal(action)
		&"register":
			var center_position: Variant = payload.value(&"center.position", Vector3.INF) if payload != null else Vector3.INF
			var pending_role: Variant = payload.value(&"workplace.role", "") if payload != null else ""
			if not (center_position is Vector3) or center_position == Vector3.INF or not (pending_role is String) or pending_role.is_empty():
				return false
			actor.begin_employment_processing(center_position, pending_role, target)
			return actor.state in [Citizen.State.TO_EMPLOYMENT_CENTER, Citizen.State.EMPLOYMENT_PROCESSING]
	return false


func execute_logistics_action(actor: Citizen, action: StringName, target: Node3D, payload: AIFactSet) -> bool:
	if action == &"courier_delivery":
		var task_id: Variant = payload.value(&"courier.task_id", &"") if payload != null else &""
		if not (task_id is StringName) or task_id == &"" or actor.simulation == null or actor.simulation.courier_dispatcher == null:
			return false
		if not actor.simulation.courier_dispatcher.start_task(actor, task_id):
			return false
		return actor.has_active_delivery()
	return false


func get_action_status(actor: Citizen, action: StringName) -> int:
	if actor == null:
		return 3 # FAILED
	if actor.navigation_failed:
		return 3 # FAILED
	match action:
		&"sleep":
			if actor.state in [Citizen.State.TO_HOME, Citizen.State.RESTING]:
				return 1 # RUNNING
		&"eat":
			if actor.state in [Citizen.State.TO_CANTEEN, Citizen.State.EATING]:
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"relieve":
			if actor.state in [Citizen.State.TO_TOILET, Citizen.State.USING_TOILET, Citizen.State.WAITING_FOR_TOILET, Citizen.State.TO_BUSH, Citizen.State.USING_BUSH]:
				return 1 # RUNNING
			if actor.simulation != null and actor.simulation.citizen_needs_service != null and not actor.simulation.citizen_needs_service.has_toilet_request(actor.ai_id):
				return 2 # SUCCEEDED
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"rest":
			if actor.state in [Citizen.State.TO_PARK, Citizen.State.RELAXING]:
				return 1 # RUNNING
			if actor.simulation != null and actor.simulation.citizen_needs_service != null and not actor.simulation.citizen_needs_service.has_rest_request(actor.ai_id):
				return 2 # SUCCEEDED
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"relax":
			if actor.state == Citizen.State.RELAXING:
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"forestry":
			if actor.state in [Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL]:
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"farming":
			if actor.state in [Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER]:
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"construction", &"demolition":
			if actor.state == Citizen.State.CONSTRUCTING and actor.active_role == str(action):
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"gathering":
			if actor.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE, Citizen.State.WAITING_COURIER]:
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"cleaning":
			if actor.state in [Citizen.State.TO_CLEANING_PILE, Citizen.State.CLEANING_PILE, Citizen.State.TO_WAREHOUSE]:
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"excavation":
			if actor.state in [Citizen.State.EXCAVATING, Citizen.State.WAITING_COURIER]:
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"cook", &"teacher", &"seller", &"official", &"craftsman", &"researcher":
			if actor.state in actor._service_states_for_internal(action):
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"factory_work":
			if actor.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]:
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"courier_delivery":
			if actor.has_active_delivery():
				return 1 # RUNNING
			if actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
		&"register":
			if actor.state in [Citizen.State.TO_EMPLOYMENT_CENTER, Citizen.State.EMPLOYMENT_PROCESSING]:
				return 1 # RUNNING
			if actor.employment_state == Citizen.EmploymentState.EMPLOYED or actor.state == Citizen.State.IDLE:
				return 2 # SUCCEEDED
	return 3 # FAILED


func cancel_current_action(actor: Citizen) -> void:
	if actor == null:
		return
	var was_relief_action := actor.state in [Citizen.State.TO_TOILET, Citizen.State.USING_TOILET, Citizen.State.WAITING_FOR_TOILET, Citizen.State.TO_BUSH, Citizen.State.USING_BUSH]
	var was_construction_delivery := actor.state in [Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE]
	if (actor.active_role.begins_with("gather_") or actor.active_role == "cleaning") and actor.carried_amount > 0 and not actor.resource_type.is_empty():
		actor.resource_dropped.emit(actor, actor.resource_type, actor.carried_amount)
		actor.carried_amount = 0
	if actor.is_registering():
		actor.pending_employment_role = ""
		actor.pending_employment_workplace = null
		actor.registration_queue_order = -1
		actor.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
	if actor.state in [Citizen.State.TO_HOME, Citizen.State.RESTING, Citizen.State.TO_CANTEEN, Citizen.State.EATING, Citizen.State.TO_TOILET, Citizen.State.USING_TOILET, Citizen.State.WAITING_FOR_TOILET, Citizen.State.TO_BUSH, Citizen.State.USING_BUSH, Citizen.State.AI_MOVING, Citizen.State.TO_PARK, Citizen.State.RELAXING, Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER, Citizen.State.CONSTRUCTING, Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_CLEANING_PILE, Citizen.State.CLEANING_PILE, Citizen.State.TO_WAREHOUSE, Citizen.State.EXCAVATING, Citizen.State.TO_CANTEEN_WORK, Citizen.State.CANTEEN_WORK, Citizen.State.TO_SCHOOL_WORK, Citizen.State.SCHOOL_WORK, Citizen.State.TO_MARKET_WORK, Citizen.State.MARKET_WORK, Citizen.State.TO_OFFICIAL_WORK, Citizen.State.OFFICIAL_WORK, Citizen.State.TO_CRAFT_WORK, Citizen.State.CRAFT_WORK, Citizen.State.RESEARCHING, Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK, Citizen.State.COURIER_TO_WORKER, Citizen.State.COURIER_TO_WAREHOUSE, Citizen.State.COURIER_TO_SAWMILL, Citizen.State.TO_FOOD_PICKUP, Citizen.State.TO_CANTEEN_DELIVERY, Citizen.State.TO_CONSTRUCTION_PICKUP, Citizen.State.TO_CONSTRUCTION_SITE, Citizen.State.TO_TRADE_PICKUP, Citizen.State.TO_TRADE_DESTINATION, Citizen.State.TO_EMPLOYMENT_CENTER, Citizen.State.EMPLOYMENT_PROCESSING]:
		actor.idle()
	if was_construction_delivery:
		actor.carried_amount = 0
		actor.construction_delivery_resource = ""
		actor.building_supply_kind = "construction"
	if was_relief_action:
		actor.current_toilet_target = null
		actor.toilet_relief_position = Vector3.INF
		actor.toilet_relief_type = ""
		actor.has_toilet_resume_state = false
		actor.toilet_resume_state = Citizen.State.IDLE
		actor.toilet_resume_idle_wander_anchor = Vector3.INF
		actor.toilet_resume_idle_wander_target = Vector3.INF
		actor.toilet_resume_idle_wander_pause = 0.0


func end_work_shift(actor: Citizen) -> void:
	if actor == null or actor.is_player_controlled:
		return
	if actor.state in [Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER, Citizen.State.CONSTRUCTING, Citizen.State.EXCAVATING, Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_CLEANING_PILE, Citizen.State.CLEANING_PILE, Citizen.State.TO_WAREHOUSE, Citizen.State.TO_CANTEEN_WORK, Citizen.State.CANTEEN_WORK, Citizen.State.TO_SCHOOL_WORK, Citizen.State.SCHOOL_WORK, Citizen.State.TO_MARKET_WORK, Citizen.State.MARKET_WORK, Citizen.State.TO_OFFICIAL_WORK, Citizen.State.OFFICIAL_WORK, Citizen.State.TO_CRAFT_WORK, Citizen.State.CRAFT_WORK, Citizen.State.RESEARCHING, Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]:
		cancel_current_action(actor)
