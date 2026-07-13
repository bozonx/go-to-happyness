class_name CitizenActuator
extends RefCounted

## Write port used by behavior leaves. It deliberately exposes capabilities,
## not Citizen FSM states. Concrete adapters will be added as tasks are migrated.

enum ActionStatus { IDLE, RUNNING, SUCCEEDED, FAILED }

var citizen_id: int


func _init(next_citizen_id: int = 0) -> void:
	citizen_id = next_citizen_id


func is_valid() -> bool:
	return citizen_id != 0


func move_to(_destination: Vector3, _arrival_radius: float = 0.25) -> bool:
	return false


func has_arrived() -> bool:
	return false


func stop() -> void:
	pass


func begin_action(
	_action: StringName,
	_target_key: StringName = &"",
	_payload: AIFactSet = null
) -> bool:
	return false


func action_status() -> ActionStatus:
	return ActionStatus.IDLE


func cancel_action() -> void:
	pass
