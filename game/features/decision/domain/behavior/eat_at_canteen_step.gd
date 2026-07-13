class_name EatAtCanteenStep
extends BehaviorStep

var _started := false


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null:
		return
	var destination: Variant = context.citizen.facts.value(&"needs.canteen_position", Vector3.INF)
	if destination is Vector3 and destination != Vector3.INF:
		_started = context.actuator.begin_action(
			&"eat",
			&"",
			AIFactSet.new({&"target.position": destination})
		)


func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not _started or context.citizen == null:
		return Status.FAILURE
	if not bool(context.citizen.facts.value(&"needs.meal_requested", false)):
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
