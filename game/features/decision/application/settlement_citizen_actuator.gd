class_name SettlementCitizenActuator
extends CitizenActuator

## Production actuator for migrated personal-need actions. It exposes abilities,
## never the Citizen FSM itself.

var citizen: Citizen
var target_resolver := Callable()
var _active_action: StringName


func _init(next_citizen: Citizen = null, next_target_resolver := Callable()) -> void:
	super(next_citizen.ai_id if is_instance_valid(next_citizen) else 0)
	citizen = next_citizen
	target_resolver = next_target_resolver


func is_valid() -> bool:
	return (
		is_instance_valid(citizen)
		and citizen.ai_id == citizen_id
		and not citizen.is_player_controlled
	)


func move_to(destination: Vector3, arrival_radius: float = 0.25) -> bool:
	if not is_valid():
		return false
	return citizen.move_to(destination, arrival_radius)


func has_arrived() -> bool:
	return is_valid() and citizen.has_arrived()


func stop() -> void:
	if _can_cancel():
		citizen.stop_movement()


func set_activity_label(label: String) -> void:
	if is_valid():
		citizen.ai_activity_label = label


func movement_failed() -> bool:
	return is_valid() and citizen.ai_move_failed


func movement_failure_reason() -> BehaviorStep.FailureReason:
	if not is_valid():
		return BehaviorStep.FailureReason.CONTEXT_INVALID
	return citizen.ai_move_failure_reason


func begin_action(
	action: StringName,
	target_key: StringName = &"",
	payload: AIFactSet = null
) -> bool:
	if not is_valid():
		return false
	var target := _resolve_target(target_key)
	_active_action = action
	var started := citizen.execute_action(action, target, payload)
	if not started:
		_active_action = &""
	return started


func action_status() -> ActionStatus:
	if not is_valid():
		return ActionStatus.FAILED
	var status_int := citizen.get_action_status(_active_action)
	return status_int as ActionStatus


func cancel_action() -> void:
	if not _can_cancel():
		return
	citizen.cancel_current_action()
	_active_action = &""


func _can_cancel() -> bool:
	return is_instance_valid(citizen) and citizen.ai_id == citizen_id


func _resolve_target(target_key: StringName) -> Node3D:
	if target_key == &"" or not target_resolver.is_valid():
		return null
	return target_resolver.call(target_key) as Node3D
