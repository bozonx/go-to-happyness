class_name SettlementCitizenActuator
extends CitizenActuator

## Production actuator for migrated personal-need actions. It exposes abilities,
## never the Citizen FSM itself.

var citizen: Citizen
var _active_action: StringName


func _init(next_citizen: Citizen = null) -> void:
	super(next_citizen.ai_id if is_instance_valid(next_citizen) else 0)
	citizen = next_citizen


func is_valid() -> bool:
	return (
		is_instance_valid(citizen)
		and citizen.ai_id == citizen_id
		and not citizen.is_player_controlled
	)


func begin_action(
	action: StringName,
	_target_entity_id: int = -1,
	_payload: AIFactSet = null
) -> bool:
	if not is_valid():
		return false
	match action:
		&"sleep":
			citizen.go_home()
			_active_action = action if citizen.state in [Citizen.State.TO_HOME, Citizen.State.RESTING] else &""
			return _active_action == action
		&"eat":
			var destination: Variant = _payload.value(&"target.position", Vector3.INF) if _payload != null else Vector3.INF
			if not (destination is Vector3) or destination == Vector3.INF:
				return false
			citizen.go_to_canteen(destination)
			_active_action = action if citizen.state in [Citizen.State.TO_CANTEEN, Citizen.State.EATING] else &""
			return _active_action == action
		&"relieve":
			var relief_position: Variant = _payload.value(&"target.position", Vector3.INF) if _payload != null else Vector3.INF
			var relief_kind: Variant = _payload.value(&"target.kind", &"") if _payload != null else &""
			if not (relief_position is Vector3) or relief_position == Vector3.INF or not (relief_kind is StringName):
				return false
			citizen.go_to_relief(relief_position, relief_kind)
			_active_action = action if citizen.state in [Citizen.State.TO_TOILET, Citizen.State.USING_TOILET, Citizen.State.WAITING_FOR_TOILET, Citizen.State.TO_BUSH, Citizen.State.USING_BUSH] else &""
			return _active_action == action
		&"rest":
			var rest_position: Variant = _payload.value(&"target.position", Vector3.INF) if _payload != null else Vector3.INF
			var rest_duration := float(_payload.value(&"action.duration", 4.0)) if _payload != null else 4.0
			if not (rest_position is Vector3) or rest_position == Vector3.INF:
				return false
			citizen.go_to_park(rest_position, 0, rest_duration)
			_active_action = action if citizen.state in [Citizen.State.TO_PARK, Citizen.State.RELAXING] else &""
			return _active_action == action
		&"forestry":
			var tree_position: Variant = _payload.value(&"target.position", Vector3.INF) if _payload != null else Vector3.INF
			var access_position: Variant = _payload.value(&"target.access_position", Vector3.INF) if _payload != null else Vector3.INF
			var sawmill_position: Variant = _payload.value(&"workplace.position", Vector3.INF) if _payload != null else Vector3.INF
			var warehouse_position: Variant = _payload.value(&"warehouse.position", Vector3.INF) if _payload != null else Vector3.INF
			if not (tree_position is Vector3) or tree_position == Vector3.INF or not (access_position is Vector3) or access_position == Vector3.INF or not (sawmill_position is Vector3) or sawmill_position == Vector3.INF or not (warehouse_position is Vector3) or warehouse_position == Vector3.INF:
				return false
			citizen.assign_work("wood", tree_position, sawmill_position, warehouse_position, false, access_position)
			_active_action = action if citizen.state in [Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL] else &""
			return _active_action == action
		&"farming":
			var farm_position: Variant = _payload.value(&"workplace.position", Vector3.INF) if _payload != null else Vector3.INF
			var farm_warehouse_position: Variant = _payload.value(&"warehouse.position", Vector3.INF) if _payload != null else Vector3.INF
			if not (farm_position is Vector3) or farm_position == Vector3.INF or not (farm_warehouse_position is Vector3) or farm_warehouse_position == Vector3.INF:
				return false
			citizen.assign_work("food", farm_position, farm_position, farm_warehouse_position, true)
			_active_action = action if citizen.state in [Citizen.State.TO_TREE, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER] else &""
			return _active_action == action
		&"construction", &"demolition":
			var target := instance_from_id(_target_entity_id) as Node3D
			if not is_instance_valid(target):
				return false
			if action == &"construction":
				citizen.assign_construction(target)
			else:
				citizen.assign_demolition(target)
			_active_action = action if citizen.state == Citizen.State.CONSTRUCTING else &""
			return _active_action == action
		&"gathering":
			var resource_type: Variant = _payload.value(&"resource.type", "") if _payload != null else ""
			var source_position: Variant = _payload.value(&"target.position", Vector3.INF) if _payload != null else Vector3.INF
			var access_position: Variant = _payload.value(&"target.access_position", Vector3.INF) if _payload != null else Vector3.INF
			var gathering_warehouse_position: Variant = _payload.value(&"warehouse.position", Vector3.INF) if _payload != null else Vector3.INF
			if not (resource_type is String) or resource_type.is_empty() or not (source_position is Vector3) or source_position == Vector3.INF or not (access_position is Vector3) or access_position == Vector3.INF or not (gathering_warehouse_position is Vector3) or gathering_warehouse_position == Vector3.INF:
				return false
			citizen.assign_gathering(resource_type, source_position, gathering_warehouse_position, access_position)
			_active_action = action if citizen.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE] else &""
			return _active_action == action
		&"excavation":
			var dig_site := instance_from_id(_target_entity_id) as Node3D
			if not is_instance_valid(dig_site):
				return false
			citizen.assign_excavation(dig_site)
			_active_action = action if citizen.state == Citizen.State.EXCAVATING else &""
			return _active_action == action
		&"cook", &"teacher", &"seller", &"official", &"craftsman":
			var service_position: Variant = _payload.value(&"workplace.position", Vector3.INF) if _payload != null else Vector3.INF
			if not (service_position is Vector3) or service_position == Vector3.INF:
				return false
			match action:
				&"cook": citizen.assign_canteen_work(service_position)
				&"teacher": citizen.assign_teacher_work(service_position)
				&"seller": citizen.assign_seller_work(service_position)
				&"official": citizen.assign_official_work(service_position)
				&"craftsman": citizen.assign_craft_work(service_position, _craft_speed_multiplier())
			_active_action = action if citizen.state in _service_states_for(action) else &""
			return _active_action == action
		&"factory_work":
			var factory := instance_from_id(_target_entity_id) as Node3D
			var factory_role: Variant = _payload.value(&"factory.role", &"") if _payload != null else &""
			if not is_instance_valid(factory) or not (factory_role is StringName) or factory_role == &"":
				return false
			citizen.assign_factory_work(factory, String(factory_role))
			_active_action = action if citizen.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK] else &""
			return _active_action == action
	return false


func action_status() -> ActionStatus:
	if not is_valid():
		return ActionStatus.FAILED
	match _active_action:
		&"sleep":
			if citizen.state in [Citizen.State.TO_HOME, Citizen.State.RESTING]:
				return ActionStatus.RUNNING
		&"eat":
			if citizen.state in [Citizen.State.TO_CANTEEN, Citizen.State.EATING]:
				return ActionStatus.RUNNING
			if citizen.state == Citizen.State.IDLE:
				return ActionStatus.SUCCEEDED
		&"relieve":
			if citizen.state in [Citizen.State.TO_TOILET, Citizen.State.USING_TOILET, Citizen.State.WAITING_FOR_TOILET, Citizen.State.TO_BUSH, Citizen.State.USING_BUSH]:
				return ActionStatus.RUNNING
			if citizen.simulation != null and citizen.simulation.citizen_needs_service != null and not citizen.simulation.citizen_needs_service.has_toilet_request(citizen_id):
				return ActionStatus.SUCCEEDED
			if citizen.state == Citizen.State.IDLE:
				return ActionStatus.SUCCEEDED
		&"rest":
			if citizen.state in [Citizen.State.TO_PARK, Citizen.State.RELAXING]:
				return ActionStatus.RUNNING
			if citizen.simulation != null and citizen.simulation.citizen_needs_service != null and not citizen.simulation.citizen_needs_service.has_rest_request(citizen_id):
				return ActionStatus.SUCCEEDED
			if citizen.state == Citizen.State.IDLE:
				return ActionStatus.SUCCEEDED
		&"forestry":
			if citizen.state in [Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL]:
				return ActionStatus.RUNNING
			if citizen.state == Citizen.State.IDLE:
				return ActionStatus.SUCCEEDED
		&"farming":
			if citizen.state in [Citizen.State.TO_TREE, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER]:
				return ActionStatus.RUNNING
			if citizen.state == Citizen.State.IDLE:
				return ActionStatus.SUCCEEDED
		&"construction", &"demolition":
			if citizen.state == Citizen.State.CONSTRUCTING and citizen.active_role == str(_active_action):
				return ActionStatus.RUNNING
			if citizen.state == Citizen.State.IDLE:
				return ActionStatus.SUCCEEDED
		&"gathering":
			if citizen.state in [Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE]:
				return ActionStatus.RUNNING
			if citizen.state == Citizen.State.IDLE:
				return ActionStatus.SUCCEEDED
		&"excavation":
			if citizen.state in [Citizen.State.EXCAVATING, Citizen.State.WAITING_COURIER]:
				return ActionStatus.RUNNING
			if citizen.state == Citizen.State.IDLE:
				return ActionStatus.SUCCEEDED
		&"cook", &"teacher", &"seller", &"official", &"craftsman":
			if citizen.state in _service_states_for(_active_action):
				return ActionStatus.RUNNING
			if citizen.state == Citizen.State.IDLE:
				return ActionStatus.SUCCEEDED
		&"factory_work":
			if citizen.state in [Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]:
				return ActionStatus.RUNNING
			if citizen.state == Citizen.State.IDLE:
				return ActionStatus.SUCCEEDED
	return ActionStatus.FAILED


func cancel_action() -> void:
	if not is_valid():
		return
	if citizen.state in [Citizen.State.TO_HOME, Citizen.State.RESTING, Citizen.State.TO_CANTEEN, Citizen.State.EATING, Citizen.State.TO_TOILET, Citizen.State.USING_TOILET, Citizen.State.WAITING_FOR_TOILET, Citizen.State.TO_BUSH, Citizen.State.USING_BUSH, Citizen.State.TO_PARK, Citizen.State.RELAXING, Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER, Citizen.State.CONSTRUCTING, Citizen.State.TO_GATHER, Citizen.State.GATHERING, Citizen.State.TO_WAREHOUSE, Citizen.State.EXCAVATING, Citizen.State.TO_CANTEEN_WORK, Citizen.State.CANTEEN_WORK, Citizen.State.TO_SCHOOL_WORK, Citizen.State.SCHOOL_WORK, Citizen.State.TO_MARKET_WORK, Citizen.State.MARKET_WORK, Citizen.State.TO_OFFICIAL_WORK, Citizen.State.OFFICIAL_WORK, Citizen.State.TO_CRAFT_WORK, Citizen.State.CRAFT_WORK, Citizen.State.TO_FACTORY, Citizen.State.FACTORY_WORK]:
		citizen.idle()
	_active_action = &""


func _service_states_for(action: StringName) -> Array:
	match action:
		&"cook": return [Citizen.State.TO_CANTEEN_WORK, Citizen.State.CANTEEN_WORK]
		&"teacher": return [Citizen.State.TO_SCHOOL_WORK, Citizen.State.SCHOOL_WORK]
		&"seller": return [Citizen.State.TO_MARKET_WORK, Citizen.State.MARKET_WORK]
		&"official": return [Citizen.State.TO_OFFICIAL_WORK, Citizen.State.OFFICIAL_WORK]
		&"craftsman": return [Citizen.State.TO_CRAFT_WORK, Citizen.State.CRAFT_WORK]
	return []


func _craft_speed_multiplier() -> float:
	if not is_instance_valid(citizen.employment_workplace):
		return 1.0
	match str(citizen.employment_workplace.get_meta("building_type", "")):
		"craft_tent_lvl2": return 1.3
		"craft_tent_lvl3": return 1.7
	return 1.0
