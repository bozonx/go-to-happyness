class_name AICitizenGoal
extends RefCounted

## Stateless goal definition. Concrete goals are added to a catalog; neither the
## arbiter nor CitizenBrain needs to change when a new goal is introduced. Scores
## must be finite and normalized to [0, 1].

## Below this wellbeing threshold, residents refuse to perform any work. Personal
## needs (sleep, meal, toilet, rest) are unaffected.
const WORK_REFUSAL_WELLBEING := 30

var id: StringName
var resumable := true
## Work trips are atomic from assignment through completion. Personal needs wait
## for their terminal state, while external invalidation may still cancel them.
var blocks_personal_needs := false


func _init(next_id: StringName = &"") -> void:
	id = next_id


func score(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	return 0.0


## Returns true when settlement wellbeing is too low for work goals to score.
func wellbeing_too_low_for_work(snapshot: WorldSnapshot) -> bool:
	return snapshot != null and int(snapshot.settlement.value(&"settlement.wellbeing", 100)) < WORK_REFUSAL_WELLBEING


func build_task(
	_snapshot: WorldSnapshot,
	_citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	return null
