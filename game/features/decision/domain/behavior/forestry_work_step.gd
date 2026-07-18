class_name ForestryWorkStep
extends BehaviorStep

const RESERVATION_TTL := 90.0

var _started := false
var _reservation_key: Array


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null or context.snapshot == null or context.order == null:
		return
	var tree_id := context.order.payload.value(&"work.tree_id", &"") as StringName
	var tree_position: Variant = context.order.target_position
	var tree_access: Variant = context.order.payload.value(&"work.tree_access", Vector3.INF)
	var sawmill_position: Variant = context.order.payload.value(&"work.sawmill_position", Vector3.INF)
	var warehouse_position: Variant = context.order.payload.value(&"work.warehouse_position", Vector3.INF)
	if tree_id == &"" or not (tree_position is Vector3) or tree_position == Vector3.INF or not (tree_access is Vector3) or tree_access == Vector3.INF or not (sawmill_position is Vector3) or sawmill_position == Vector3.INF or not (warehouse_position is Vector3) or warehouse_position == Vector3.INF:
		return
	_reservation_key = [&"forestry.tree", tree_id]
	if not context.snapshot.reservations.claim(_reservation_key, context.citizen.id, context.snapshot.simulation_seconds, RESERVATION_TTL):
		_reservation_key.clear()
		return
	_started = context.actuator.begin_action(&"forestry", &"", AIFactSet.new({
		&"target.position": tree_position,
		&"target.access_position": tree_access,
		&"workplace.position": sawmill_position,
		&"warehouse.position": warehouse_position,
	}))
	if not _started:
		_release(context)


func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not _started:
		return Status.FAILURE
	if not _renew(context):
		return Status.FAILURE
	var status := context.actuator.action_status()
	if status == CitizenActuator.ActionStatus.SUCCEEDED:
		return Status.SUCCESS
	if status == CitizenActuator.ActionStatus.FAILED:
		return fail(context.actuator.action_failure_reason())
	return Status.RUNNING


func _cancel(context: BehaviorContext) -> void:
	context.actuator.cancel_action()
	_release(context)


func _finish(context: BehaviorContext, _status: Status) -> void:
	context.actuator.cancel_action()
	_release(context)


func _release(context: BehaviorContext) -> void:
	if not _reservation_key.is_empty() and context.snapshot != null and context.citizen != null:
		context.snapshot.reservations.release(_reservation_key, context.citizen.id)
	_reservation_key.clear()


func _renew(context: BehaviorContext) -> bool:
	return (
		not _reservation_key.is_empty()
		and context.snapshot != null
		and context.citizen != null
		and context.snapshot.reservations.claim(_reservation_key, context.citizen.id, context.snapshot.simulation_seconds, RESERVATION_TTL)
	)
