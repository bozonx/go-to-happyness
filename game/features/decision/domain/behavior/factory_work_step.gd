class_name FactoryWorkStep
extends BehaviorStep

var _started := false


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null or context.order == null or context.order.target_key == &"":
		return
	var role := context.order.payload.value(&"factory.role", &"") as StringName
	if role not in [&"factory_work", &"engineering", &"construction"]:
		return
	_started = context.actuator.begin_action(&"factory_work", context.order.target_key, AIFactSet.new({&"factory.role": role}))


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
