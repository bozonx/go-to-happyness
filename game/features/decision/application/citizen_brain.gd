class_name CitizenBrain
extends RefCounted

## How long (simulation seconds) a goal is dampened after its task fails.
const FAILURE_COOLDOWN := 6.0

const PERSONAL_NEED_GOALS: Array[StringName] = [
	&"sleep",
	&"meal",
	&"toilet",
	&"rest",
]

## Non-survival needs that yield once to a freshly assigned work order: the
## citizen starts the assignment before the need may interrupt it. Waiting for a
## whole construction or service task to finish can postpone relief until every
## worker reaches the same shift boundary.
const DEFERRABLE_NEED_GOALS: Array[StringName] = [
	&"toilet",
]

const ACTIVE_GOAL_BLACKBOARD_KEY := &"brain.active_goal_id"

var citizen_id: int
var blackboard := AIBlackboard.new()
var arbiter := UtilityArbiter.new()
var runner := BehaviorRunner.new()
var context: BehaviorContext
var _completed_order: CitizenOrder
var _completed_order_goal_id: StringName
var _assignment_key := ""
var _assigned_work_started := false


func _init(
	next_citizen_id: int,
	actuator: CitizenActuator,
	goals: Array[AICitizenGoal]
) -> void:
	citizen_id = next_citizen_id
	context = BehaviorContext.new(actuator, blackboard)
	arbiter.configure(goals)
	runner.task_finished.connect(_on_task_finished)
	runner.task_started.connect(_on_task_started)
	runner.task_resumed.connect(_on_task_started)


func think(snapshot: WorldSnapshot, order: CitizenOrder) -> void:
	context.refresh(snapshot, order)
	if context.citizen == null or context.citizen.is_player_controlled or not context.citizen.is_available:
		runner.cancel_all(context)
		context.actuator.set_activity_label("")
		return
	var active_goal_id := runner.active_goal_id()
	blackboard.set_value(ACTIVE_GOAL_BLACKBOARD_KEY, active_goal_id)
	# A personal need may preempt work. The runner cancels non-resumable work so the
	# next director publication can rebuild it from current facts.
	var excluded := _excluded_goal_ids(active_goal_id)
	# A completed action may remain on the board until the next director tick. Do
	# not immediately replay that exact proposal; a freshly published order object
	# (even with the same stable id) represents the next production cycle.
	if runner.active_task == null and order != null and order == _completed_order:
		excluded.append(_completed_order_goal_id)
	elif order != _completed_order:
		_completed_order = null
		_completed_order_goal_id = &""
	# Let a fresh assignment take control once before a deferrable need can
	# interrupt it. The stable assignment key also resets this gate when the
	# player changes role without an unassigned frame in between.
	var assignment_key := _current_assignment_key()
	if assignment_key != _assignment_key:
		_assignment_key = assignment_key
		_assigned_work_started = false
	if not assignment_key.is_empty() and not _assigned_work_started:
		for need_id in DEFERRABLE_NEED_GOALS:
			if need_id != active_goal_id and not need_id in excluded:
				excluded.append(need_id)
	var result := arbiter.choose(
		snapshot,
		context.citizen,
		order,
		blackboard,
		active_goal_id,
		excluded
	)
	if result.goal == null:
		runner.cancel_all(context)
		context.actuator.set_activity_label("")
		return
	var task_uses_order := not result.goal.id in PERSONAL_NEED_GOALS
	var next_order_id := order.id if task_uses_order and order != null else 0
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
	task.order = order if task_uses_order else null
	# Once a challenger wins arbitration it takes control immediately. Deferring it
	# behind an indefinite workplace action can starve a personal need for a shift.
	runner.start(task, context)
	blackboard.set_value(ACTIVE_GOAL_BLACKBOARD_KEY, runner.active_goal_id())


func tick(snapshot: WorldSnapshot, order: CitizenOrder, delta: float) -> void:
	context.refresh(snapshot, order)
	if context.citizen == null or context.citizen.is_player_controlled or not context.citizen.is_available:
		runner.cancel_all(context)
		return
	blackboard.set_value(ACTIVE_GOAL_BLACKBOARD_KEY, runner.active_goal_id())
	runner.tick(context, delta)
	blackboard.set_value(ACTIVE_GOAL_BLACKBOARD_KEY, runner.active_goal_id())


func shutdown() -> void:
	runner.cancel_all(context)
	context.actuator.set_activity_label("")


func cancel_current_task() -> void:
	runner.cancel_all(context)
	context.actuator.set_activity_label("")


func has_runnable_task() -> bool:
	return runner.active_task != null or runner.pending_task != null or runner.suspended_count() > 0


func configure_goals(goals: Array[AICitizenGoal]) -> void:
	runner.cancel_all(context)
	context.actuator.set_activity_label("")
	arbiter.configure(goals)


func _excluded_goal_ids(active_goal_id: StringName) -> Array[StringName]:
	if active_goal_id in PERSONAL_NEED_GOALS:
		# Personal needs do not interrupt other personal needs; they run to
		# completion (or external cancellation) before another need is chosen.
		var all_other_ids := _work_goal_ids()
		for id in PERSONAL_NEED_GOALS:
			if id != active_goal_id:
				all_other_ids.append(id)
		return all_other_ids
	return []


func _work_goal_ids() -> Array[StringName]:
	var ids := arbiter.goal_ids()
	var work_ids: Array[StringName] = []
	for id in ids:
		if not id in PERSONAL_NEED_GOALS:
			work_ids.append(id)
	return work_ids


func _on_task_finished(task: BehaviorTask, status: BehaviorStep.Status) -> void:
	if runner.active_task == null:
		context.actuator.set_activity_label("")
	if status == BehaviorStep.Status.SUCCESS and task.order != null and task.order_id != 0:
		_completed_order = task.order
		_completed_order_goal_id = task.goal_id
		return
	if status != BehaviorStep.Status.FAILURE or task.goal_id == &"":
		return
	var now := context.snapshot.simulation_seconds if context.snapshot != null else 0.0
	blackboard.set_cooldown(task.goal_id, now + FAILURE_COOLDOWN)


func _on_task_started(task: BehaviorTask) -> void:
	context.actuator.set_activity_label(task.label if task != null else "")
	if task != null and task.order != null and task.order_id != 0:
		_assigned_work_started = true


func _current_assignment_key() -> String:
	if context.citizen == null:
		return ""
	if bool(context.citizen.facts.value(&"daily.order.active", false)):
		return "daily:%s:%d" % [
			str(context.citizen.facts.value(&"daily.order.role", "")),
			int(context.citizen.facts.value(&"daily.order.workday_id", 0)),
		]
	if bool(context.citizen.facts.value(&"work.permanent.active", false)):
		var worker_data: Dictionary = context.citizen.facts.value(&"workforce.worker_data", {})
		return "permanent:%s" % str(worker_data.get("permanent_role", ""))
	return ""
