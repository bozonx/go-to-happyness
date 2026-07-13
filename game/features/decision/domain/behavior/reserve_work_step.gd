class_name ReserveWorkStep
extends BehaviorStep

var _started := false


func _enter(context: BehaviorContext) -> void:
	if context.order == null:
		return
	_started = context.actuator.begin_action(&"reserve_work", context.order.target_key, context.order.payload)


func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not _started:
		return Status.FAILURE
	var status := context.actuator.action_status()
	if status == CitizenActuator.ActionStatus.SUCCEEDED:
		return Status.SUCCESS
	if status == CitizenActuator.ActionStatus.FAILED:
		return Status.FAILURE
	return Status.RUNNING


func _cancel(context: BehaviorContext) -> void:
	context.actuator.cancel_action()


func _finish(context: BehaviorContext, _status: Status) -> void:
	context.actuator.cancel_action()
