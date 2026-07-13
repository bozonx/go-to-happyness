class_name SettlementCitizenActuator
extends CitizenActuator

## First production actuator slice. It owns only the sleep command; later
## mechanics add their own verbs without exposing Citizen's FSM to goals.

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
	return ActionStatus.FAILED


func cancel_action() -> void:
	if not is_valid():
		return
	if citizen.state in [Citizen.State.TO_HOME, Citizen.State.RESTING, Citizen.State.TO_CANTEEN, Citizen.State.EATING]:
		citizen.idle()
	_active_action = &""
