class_name ConstructionWorkStep
extends BehaviorStep

const MAX_STEP_SECONDS := 300.0

var _started := false
var _elapsed := 0.0


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null or context.order == null:
		return
	var mode := context.order.payload.value(&"work.construction.mode", &"") as StringName
	if mode not in [&"construction", &"demolition"] or context.order.target_key == &"":
		return
	_started = context.actuator.begin_action(mode, context.order.target_key)
	_elapsed = 0.0


func _tick(context: BehaviorContext, delta: float) -> Status:
	if not _started:
		return Status.FAILURE
	var status := context.actuator.action_status()
	if status == CitizenActuator.ActionStatus.SUCCEEDED:
		return Status.SUCCESS
	if status == CitizenActuator.ActionStatus.FAILED:
		return fail(context.actuator.action_failure_reason())
	_elapsed += delta
	if _elapsed >= MAX_STEP_SECONDS:
		context.actuator.cancel_action()
		return Status.FAILURE
	return Status.RUNNING


func _cancel(context: BehaviorContext) -> void:
	context.actuator.cancel_action()


func _finish(context: BehaviorContext, _status: Status) -> void:
	context.actuator.cancel_action()
