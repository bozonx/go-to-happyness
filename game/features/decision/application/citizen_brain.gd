class_name CitizenBrain
extends RefCounted

var citizen_id: int
var blackboard := AIBlackboard.new()
var arbiter := UtilityArbiter.new()
var runner := BehaviorRunner.new()
var context: BehaviorContext


func _init(
	next_citizen_id: int,
	actuator: CitizenActuator,
	goals: Array[AICitizenGoal]
) -> void:
	citizen_id = next_citizen_id
	context = BehaviorContext.new(actuator, blackboard)
	arbiter.configure(goals)


func think(snapshot: WorldSnapshot, order: CitizenOrder) -> void:
	context.refresh(snapshot, order)
	if context.citizen == null or context.citizen.is_player_controlled or not context.citizen.is_available:
		runner.cancel_all(context)
		return
	var result := arbiter.choose(
		snapshot,
		context.citizen,
		order,
		blackboard,
		runner.active_goal_id()
	)
	if result.goal == null:
		runner.cancel_all(context)
		return
	if result.goal.id == runner.active_goal_id():
		var active_order_id := runner.active_task.order_id if runner.active_task != null else 0
		var next_order_id := order.id if order != null else 0
		if active_order_id == next_order_id:
			return
	var task := result.goal.build_task(snapshot, context.citizen, order, blackboard)
	if task == null:
		return
	task.goal_id = result.goal.id
	task.resumable = result.goal.resumable
	task.order_id = order.id if order != null else 0
	runner.start(task, context)


func tick(snapshot: WorldSnapshot, order: CitizenOrder, delta: float) -> void:
	context.refresh(snapshot, order)
	if context.citizen == null:
		return
	runner.tick(context, delta)


func shutdown() -> void:
	runner.cancel_all(context)
