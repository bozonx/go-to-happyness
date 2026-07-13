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
	return ActionStatus.FAILED


func cancel_action() -> void:
	if not is_valid():
		return
	if citizen.state in [Citizen.State.TO_HOME, Citizen.State.RESTING, Citizen.State.TO_CANTEEN, Citizen.State.EATING, Citizen.State.TO_TOILET, Citizen.State.USING_TOILET, Citizen.State.WAITING_FOR_TOILET, Citizen.State.TO_BUSH, Citizen.State.USING_BUSH, Citizen.State.TO_PARK, Citizen.State.RELAXING, Citizen.State.TO_TREE, Citizen.State.CHOPPING, Citizen.State.TO_SAWMILL, Citizen.State.SAWING, Citizen.State.WAITING_COURIER]:
		citizen.idle()
	_active_action = &""
