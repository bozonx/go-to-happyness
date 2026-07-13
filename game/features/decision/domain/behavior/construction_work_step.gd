class_name ConstructionWorkStep
extends BehaviorStep

var _started := false


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null or context.order == null:
		return
	var mode := context.order.payload.value(&"work.construction.mode", &"") as StringName
	if mode not in [&"construction", &"demolition"] or context.order.target_key == &"":
		return
	_started = context.actuator.begin_action(mode, context.order.target_key)


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
