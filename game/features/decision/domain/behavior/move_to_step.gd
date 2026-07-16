class_name MoveToStep
extends BehaviorStep

## Leaf step that moves the citizen to a fixed world position using the
## actuator's generic movement primitive. The step succeeds on arrival and
## fails when the route becomes unreachable.

var _destination: Vector3
var _arrival_radius: float
var _reservation_key: Array
var _reservation_ttl: float
var _started := false


func _init(
	destination: Vector3,
	arrival_radius: float = 0.25,
	reservation_key: Array = [],
	reservation_ttl: float = 90.0
) -> void:
	_destination = destination
	_arrival_radius = maxf(arrival_radius, 0.01)
	_reservation_key = reservation_key.duplicate(true)
	_reservation_ttl = maxf(reservation_ttl, 0.1)


func _enter(context: BehaviorContext) -> void:
	if not _claim(context):
		set_failure_reason(FailureReason.RESERVATION_LOST)
		return
	_started = context.actuator.move_to(_destination, _arrival_radius)
	if not _started:
		set_failure_reason(FailureReason.ACTUATOR_REJECTED)
		_release(context)


func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not _started:
		return fail(failure_reason if failure_reason != FailureReason.NONE else FailureReason.ACTUATOR_REJECTED)
	if not _claim(context):
		return fail(FailureReason.RESERVATION_LOST)
	if context.actuator.movement_failed():
		return fail(context.actuator.movement_failure_reason())
	if context.actuator.has_arrived():
		return Status.SUCCESS
	return Status.RUNNING


func _cancel(context: BehaviorContext) -> void:
	context.actuator.stop()
	_release(context)


func _finish(context: BehaviorContext, _status: Status) -> void:
	context.actuator.stop()
	if _status == Status.FAILURE:
		_release(context)


func _claim(context: BehaviorContext) -> bool:
	if _reservation_key.is_empty():
		return true
	return (
		context.snapshot != null
		and context.citizen != null
		and context.snapshot.reservations.claim(
			_reservation_key,
			context.citizen.id,
			context.snapshot.simulation_seconds,
			_reservation_ttl
		)
	)


func _release(context: BehaviorContext) -> void:
	if not _reservation_key.is_empty() and context.snapshot != null and context.citizen != null:
		context.snapshot.reservations.release(_reservation_key, context.citizen.id)
