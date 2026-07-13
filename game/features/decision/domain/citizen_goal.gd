class_name AICitizenGoal
extends RefCounted

## Stateless goal definition. Concrete goals are added to a catalog; neither the
## arbiter nor CitizenBrain needs to change when a new goal is introduced.

var id: StringName
var resumable := true


func _init(next_id: StringName = &"") -> void:
	id = next_id


func score(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	return 0.0


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return null
