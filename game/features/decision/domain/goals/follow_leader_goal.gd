class_name FollowLeaderGoal
extends AICitizenGoal

## Squad members follow their leader (e.g. Hero) when they have no active work order.

const MoveToStepScript = preload("res://game/features/decision/domain/behavior/move_to_step.gd")

const FOLLOW_DISTANCE := 3.0


func _init() -> void:
	super(&"follow_leader")
	resumable = false


func score(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	order: CitizenOrder,
	_blackboard: AIBlackboard
) -> float:
	if citizen == null or order != null:
		return 0.0
	if not bool(citizen.facts.value(&"squad.in_squad", false)):
		return 0.0
	if bool(citizen.facts.value(&"squad.is_leader", false)):
		return 0.0
	var leader_position: Variant = citizen.facts.value(&"squad.leader_position", Vector3.INF)
	if not (leader_position is Vector3) or leader_position == Vector3.INF:
		return 0.0
	if citizen.position.distance_to(leader_position as Vector3) <= FOLLOW_DISTANCE:
		return 0.0
	return 0.28


func build_task(
	_snapshot: WorldSnapshot,
	citizen: CitizenSnapshot,
	_order: CitizenOrder,
	_blackboard: AIBlackboard
) -> BehaviorTask:
	if citizen == null:
		return null
	var leader_position: Variant = citizen.facts.value(&"squad.leader_position", Vector3.INF)
	if not (leader_position is Vector3) or leader_position == Vector3.INF:
		return null
	return BehaviorTask.new(id, MoveToStepScript.new(leader_position as Vector3, FOLLOW_DISTANCE), false, "Follow squad leader")
