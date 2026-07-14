class_name ReserveWorkStep
extends BehaviorStep

var _started := false
var _reservation_key: Array


func _enter(context: BehaviorContext) -> void:
	if context.order == null:
		return
	var claim_kind := context.order.payload.value(&"reserve.claim_kind", &"") as StringName
	var claim_id := context.order.payload.value(&"reserve.claim_id", &"") as StringName
	if claim_kind != &"" and claim_id != &"":
		if context.snapshot == null or context.citizen == null:
			return
		_reservation_key = [claim_kind, claim_id]
		if not context.snapshot.reservations.claim(_reservation_key, context.citizen.id, context.snapshot.simulation_seconds, 90.0):
			_reservation_key.clear()
			return
	_started = context.actuator.begin_action(&"reserve_work", context.order.target_key, context.order.payload)
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
		return Status.FAILURE
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
	if _reservation_key.is_empty():
		return true
	return (
		context.snapshot != null
		and context.citizen != null
		and context.snapshot.reservations.claim(_reservation_key, context.citizen.id, context.snapshot.simulation_seconds, 90.0)
	)
