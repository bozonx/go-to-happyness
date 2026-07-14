class_name CitizenBrain
extends RefCounted

## How long (simulation seconds) a goal is dampened after its task fails.
const FAILURE_COOLDOWN := 6.0

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
	runner.task_finished.connect(_on_task_finished)


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
	var next_order_id := order.id if order != null else 0
	if result.goal.id == runner.active_goal_id():
		var active_order_id := runner.active_task.order_id if runner.active_task != null else 0
		if active_order_id == next_order_id:
			runner.clear_pending(context)
			return
	elif runner.active_task != null and runner.has_pending(result.goal.id, next_order_id):
		return
	var task := result.goal.build_task(snapshot, context.citizen, order, blackboard)
	if task == null:
		var now := snapshot.simulation_seconds if snapshot != null else 0.0
		blackboard.set_cooldown(result.goal.id, now + FAILURE_COOLDOWN)
		runner.clear_pending(context)
		if runner.active_task == null:
			runner.cancel_all(context)
		return
	task.goal_id = result.goal.id
	task.resumable = result.goal.resumable
	task.order_id = next_order_id
	if runner.active_task != null and result.goal.id != runner.active_goal_id():
		runner.start_after_active(task, context)
	else:
		runner.start(task, context)


func tick(snapshot: WorldSnapshot, order: CitizenOrder, delta: float) -> void:
	context.refresh(snapshot, order)
	if context.citizen == null or context.citizen.is_player_controlled or not context.citizen.is_available:
		runner.cancel_all(context)
		return
	runner.tick(context, delta)


func shutdown() -> void:
	runner.cancel_all(context)


func cancel_current_task() -> void:
	runner.cancel_all(context)


func configure_goals(goals: Array[AICitizenGoal]) -> void:
	runner.cancel_all(context)
	arbiter.configure(goals)


func _on_task_finished(task: BehaviorTask, status: BehaviorStep.Status) -> void:
	if status != BehaviorStep.Status.FAILURE or task.goal_id == &"":
		return
	var now := context.snapshot.simulation_seconds if context.snapshot != null else 0.0
	blackboard.set_cooldown(task.goal_id, now + FAILURE_COOLDOWN)
