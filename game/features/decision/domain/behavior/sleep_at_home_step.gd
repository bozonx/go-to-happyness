class_name SleepAtHomeStep
extends BehaviorStep

var _started := false


func _enter(context: BehaviorContext) -> void:
	_started = context.actuator.begin_action(&"sleep")


func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not _started:
		return Status.FAILURE
	if context.citizen == null:
		return Status.FAILURE
	if not bool(context.citizen.facts.value(&"needs.should_sleep", false)):
		return Status.SUCCESS
	if context.actuator.action_status() == CitizenActuator.ActionStatus.FAILED:
		return Status.FAILURE
	return Status.RUNNING


func _cancel(context: BehaviorContext) -> void:
	context.actuator.cancel_action()


func _finish(context: BehaviorContext, _status: Status) -> void:
	context.actuator.cancel_action()
