class_name ServiceWorkStep
extends BehaviorStep

var _started := false


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null or context.order == null:
		return
	var role := context.order.payload.value(&"work.service.role", &"") as StringName
	var position: Variant = context.order.payload.value(&"workplace.position", context.order.target_position)
	if role not in [&"cook", &"teacher", &"seller", &"official", &"craftsman"] or not (position is Vector3) or position == Vector3.INF:
		return
	_started = context.actuator.begin_action(role, &"", AIFactSet.new({&"workplace.position": position}))


func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not _started:
		return Status.FAILURE
	var status := context.actuator.action_status()
	if status == CitizenActuator.ActionStatus.SUCCEEDED:
		return Status.SUCCESS
	if status == CitizenActuator.ActionStatus.FAILED:
		return fail(context.actuator.action_failure_reason())
	return Status.RUNNING


func _cancel(context: BehaviorContext) -> void:
	context.actuator.cancel_action()


func _finish(context: BehaviorContext, _status: Status) -> void:
	context.actuator.cancel_action()
