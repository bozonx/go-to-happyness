class_name BehaviorContext
extends RefCounted

## Runtime dependencies available to Steps. The context contains ports and data,
## never the settlement scene itself.

var snapshot: WorldSnapshot
var citizen: CitizenSnapshot
var order: CitizenOrder
var actuator: CitizenActuator
var blackboard: AIBlackboard


func _init(
	next_actuator: CitizenActuator,
	next_blackboard: AIBlackboard
) -> void:
	actuator = next_actuator
	blackboard = next_blackboard


func refresh(next_snapshot: WorldSnapshot, next_order: CitizenOrder) -> void:
	snapshot = next_snapshot
	citizen = snapshot.citizen(actuator.citizen_id) if snapshot != null else null
	order = next_order
