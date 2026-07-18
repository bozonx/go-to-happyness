class_name RelaxAtPositionStep
extends BehaviorStep

## Leaf step that starts and monitors the stationary relax action. The citizen
## must already be at the rest spot (typically after a MoveToStep).

var _started := false


func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not _started or context.citizen == null:
		return Status.FAILURE
	if not bool(context.citizen.facts.value(&"needs.rest_requested", false)):
		return Status.SUCCESS
	var status := context.actuator.action_status()
	if status == CitizenActuator.ActionStatus.SUCCEEDED:
		return Status.SUCCESS
	if status == CitizenActuator.ActionStatus.FAILED:
		return fail(context.actuator.action_failure_reason())
	return Status.RUNNING


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null:
		return
	var duration := float(context.citizen.facts.value(&"needs.rest_duration", 4.0))
	_started = context.actuator.begin_action(
		&"relax",
		&"",
		AIFactSet.new({&"action.duration": maxf(duration, 0.1)})
	)


func _cancel(context: BehaviorContext) -> void:
	context.actuator.cancel_action()


func _finish(context: BehaviorContext, _status: Status) -> void:
	context.actuator.cancel_action()
