class_name MoveToStep
extends BehaviorStep

## Leaf step that moves the citizen to a fixed world position using the
## actuator's generic movement primitive. The step succeeds on arrival and
## fails when the route becomes unreachable.

var _destination: Vector3
var _arrival_radius: float
var _started := false


func _init(destination: Vector3, arrival_radius: float = 0.25) -> void:
	_destination = destination
	_arrival_radius = maxf(arrival_radius, 0.01)


func _enter(context: BehaviorContext) -> void:
	_started = context.actuator.move_to(_destination, _arrival_radius)


func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not _started:
		return Status.FAILURE
	if context.actuator.movement_failed():
		return Status.FAILURE
	if context.actuator.has_arrived():
		return Status.SUCCESS
	return Status.RUNNING


func _cancel(context: BehaviorContext) -> void:
	context.actuator.stop()


func _finish(context: BehaviorContext, _status: Status) -> void:
	context.actuator.stop()
