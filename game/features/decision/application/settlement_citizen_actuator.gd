class_name SettlementCitizenActuator
extends CitizenActuator

## First production actuator slice. It owns only the sleep command; later
## mechanics add their own verbs without exposing Citizen's FSM to goals.

var citizen: Citizen


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
	if action != &"sleep" or not is_valid():
		return false
	citizen.go_home()
	return citizen.state in [Citizen.State.TO_HOME, Citizen.State.RESTING]


func action_status() -> ActionStatus:
	if not is_valid():
		return ActionStatus.FAILED
	if citizen.state in [Citizen.State.TO_HOME, Citizen.State.RESTING]:
		return ActionStatus.RUNNING
	return ActionStatus.FAILED


func cancel_action() -> void:
	if not is_valid():
		return
	if citizen.state in [Citizen.State.TO_HOME, Citizen.State.RESTING]:
		citizen.idle()
