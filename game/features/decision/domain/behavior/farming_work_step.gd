class_name FarmingWorkStep
extends BehaviorStep

var _started := false


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null or context.order == null:
		return
	var farm_position: Variant = context.order.payload.value(&"work.farm_position", Vector3.INF)
	var warehouse_position: Variant = context.order.payload.value(&"work.warehouse_position", Vector3.INF)
	if not (farm_position is Vector3) or farm_position == Vector3.INF or not (warehouse_position is Vector3) or warehouse_position == Vector3.INF:
		return
	_started = context.actuator.begin_action(&"farming", -1, AIFactSet.new({
		&"workplace.position": farm_position,
		&"warehouse.position": warehouse_position,
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
