class_name RelieveStep
extends BehaviorStep

const RESERVATION_TTL := 30.0

var _started := false
var _reservation_key: Array


func _enter(context: BehaviorContext) -> void:
	if context.citizen == null or context.snapshot == null:
		return
	var candidates: Array = context.citizen.facts.value(&"needs.relief_candidates", []) as Array
	for candidate_value in candidates:
		var candidate := candidate_value as Dictionary
		var target_id := candidate.get(&"id", &"") as StringName
		var position: Variant = candidate.get(&"position", Vector3.INF)
		var kind := candidate.get(&"kind", &"") as StringName
		if target_id == &"" or not (position is Vector3) or position == Vector3.INF or kind == &"":
			continue
		var key: Array = [&"needs.relief", target_id]
		if not context.snapshot.reservations.claim(key, context.citizen.id, context.snapshot.simulation_seconds, RESERVATION_TTL):
			continue
		if context.actuator.begin_action(&"relieve", &"", AIFactSet.new({
			&"target.position": position,
			&"target.kind": kind,
		})):
			_reservation_key = key
			_started = true
			return
		context.snapshot.reservations.release(key, context.citizen.id)


func _tick(context: BehaviorContext, _delta: float) -> Status:
	if not _started or context.citizen == null:
		return Status.FAILURE
	if not bool(context.citizen.facts.value(&"needs.toilet_requested", false)):
		return Status.SUCCESS
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
