class_name RegisterStep
extends BehaviorStep

var _started := false


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null or context.order == null:
		return
	
	var pending_role: Variant = context.order.payload.value(&"workplace.role", "")
	var center_position: Variant = context.order.payload.value(&"center.position", Vector3.INF)
	var target_key: Variant = context.order.payload.value(&"workplace.node_key", &"")
	
	if not (center_position is Vector3) or center_position == Vector3.INF or not (pending_role is String) or pending_role.is_empty():
		return
		
	var target_key_name := target_key as StringName if target_key is StringName else &""
	
	_started = context.actuator.begin_action(&"register", target_key_name, AIFactSet.new({
		&"workplace.role": pending_role,
		&"center.position": center_position,
	}))


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
