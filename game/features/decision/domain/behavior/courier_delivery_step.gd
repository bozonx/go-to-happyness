class_name CourierDeliveryStep
extends BehaviorStep

var started := false

func _enter(context: BehaviorContext) -> void:
	if context.order == null:
		return
	var task_id := context.order.payload.value(&"courier.task_id", &"") as StringName
	if task_id != &"":
		started = context.actuator.begin_action(&"courier_delivery", &"", AIFactSet.new({&"courier.task_id": task_id}))

func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not started:
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
