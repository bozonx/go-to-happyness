class_name RestAtLeisureStep
extends BehaviorStep

var _started := false


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null:
		return
	var position: Variant = context.citizen.facts.value(&"needs.rest_position", Vector3.INF)
	var duration := float(context.citizen.facts.value(&"needs.rest_duration", 4.0))
	if position is Vector3 and position != Vector3.INF:
		_started = context.actuator.begin_action(&"rest", -1, AIFactSet.new({
			&"target.position": position,
			&"action.duration": maxf(duration, 0.1),
		}))


func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not _started or context.citizen == null:
		return Status.FAILURE
	if not bool(context.citizen.facts.value(&"needs.rest_requested", false)):
		return Status.SUCCESS
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
