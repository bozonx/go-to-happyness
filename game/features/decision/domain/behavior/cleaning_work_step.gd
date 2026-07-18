class_name CleaningWorkStep
extends BehaviorStep

const RESERVATION_TTL := 90.0

var _started := false
var _reservation_key: Array


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null or context.snapshot == null or context.order == null:
		return
	var source_id := context.order.payload.value(&"work.source_id", &"") as StringName
	var resource_type := context.order.payload.value(&"resource.type", "") as String
	var source_position: Variant = context.order.target_position
	var access_position: Variant = context.order.payload.value(&"target.access_position", Vector3.INF)
	var warehouse_position: Variant = context.order.payload.value(&"warehouse.position", Vector3.INF)
	if source_id == &"" or resource_type.is_empty() or not (source_position is Vector3) or source_position == Vector3.INF or not (access_position is Vector3) or access_position == Vector3.INF or not (warehouse_position is Vector3) or warehouse_position == Vector3.INF:
		return
	_reservation_key = [&"cleaning.pile", source_id]
	if not context.snapshot.reservations.claim(_reservation_key, context.citizen.id, context.snapshot.simulation_seconds, RESERVATION_TTL):
		_reservation_key.clear()
		return
	_started = context.actuator.begin_action(&"cleaning", &"", AIFactSet.new({
		&"resource.type": resource_type,
		&"target.position": source_position,
		&"target.access_position": access_position,
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
