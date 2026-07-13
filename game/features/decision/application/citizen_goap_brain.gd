class_name CitizenGoapBrain
extends Node

const THINK_INTERVAL := 0.25

enum Intent { WORK }

var citizen: Citizen
var simulation: Node
var worker_index := 0
var _think_time := 0.0
var _agent: GoapAgent
var _goals := Node.new()
var _actions := Node.new()


class CitizenGoal extends GoapGoal:
	var brain: CitizenGoapBrain
	var intent: Intent

	func configure(next_brain: CitizenGoapBrain, next_intent: Intent, state_key: String) -> void:
		brain = next_brain
		intent = next_intent
		desired_state = {state_key: true}

	func is_valid() -> bool:
		return enabled and brain.is_goal_valid(intent)

	func get_priority() -> int:
		return brain.get_goal_priority(intent)


class CitizenAction extends GoapAction:
	var brain: CitizenGoapBrain
	var intent: Intent

	func configure(next_brain: CitizenGoapBrain, next_intent: Intent, state_key: String, action_cost: int) -> void:
		brain = next_brain
		intent = next_intent
		effects = {state_key: true}
		cost = action_cost

	func is_valid() -> bool:
		return enabled and brain.can_start(intent)

	func enter() -> void:
		brain.start_intent(intent)

	func perform(_delta: float) -> bool:
		return brain.is_intent_complete(intent)

	func exit() -> void:
		if not brain.is_intent_complete(intent):
			brain.cancel_intent(intent)


func setup(next_citizen: Citizen, next_simulation: Node, next_worker_index: int) -> void:
	citizen = next_citizen
	simulation = next_simulation
	worker_index = next_worker_index
	name = "GoapBrain"

	_goals.name = "Goals"
	_actions.name = "Actions"
	add_child(_goals)
	add_child(_actions)

	_add_goal("Work", Intent.WORK, "assigned")
	_add_action("PerformAssignedWork", Intent.WORK, "assigned", 2)

	_agent = GoapAgent.new()
	_agent.name = "Agent"
	_agent.goals_node = _goals
	_agent.actions_node = _actions
	add_child(_agent)
	_agent.init(citizen)
	_sync_world_state()


func tick(delta: float) -> void:
	if _agent == null or citizen.is_player_controlled or _uses_native_work_cycle():
		return
	if citizen.has_active_arrival_task() or citizen.has_active_delivery() or citizen.state in [Citizen.State.TO_TOILET, Citizen.State.USING_TOILET, Citizen.State.WAITING_FOR_TOILET, Citizen.State.TO_BUSH, Citizen.State.USING_BUSH]:
		return
	_think_time -= delta
	if _think_time > 0.0:
		return
	_think_time = THINK_INTERVAL
	_sync_world_state()
	_agent.process(THINK_INTERVAL)


func request_decision() -> void:
	if _agent != null and not _uses_native_work_cycle():
		_agent.get_world_state().set_state("assigned", false)
		_agent.process(0.0)
		_think_time = THINK_INTERVAL


func _uses_native_work_cycle() -> bool:
	return citizen.permanent_role in ["forestry", "farming", "construction", "gather_branches", "gather_food", "excavation"]


func is_goal_valid(intent: Intent) -> bool:
	return _decision_context().is_goal_valid(intent)


func get_goal_priority(intent: Intent) -> int:
	return _decision_context().priority_for(intent)


func _decision_context() -> CitizenDecisionContext:
	var context := CitizenDecisionContext.new()
	context.is_night = not (simulation._is_work_time() or citizen.overtime_mode)
	context.can_assign_work = simulation._can_assign_goap_work(citizen)
	return context


func can_start(intent: Intent) -> bool:
	return is_goal_valid(intent)


func start_intent(intent: Intent) -> void:
	match intent:
		Intent.WORK:
			simulation._assign_goap_work(citizen, worker_index)


func is_intent_complete(intent: Intent) -> bool:
	match intent:
		Intent.WORK:
			return citizen.state != Citizen.State.IDLE and citizen.state != Citizen.State.RESTING
	return false


func cancel_intent(intent: Intent) -> void:
	if intent == Intent.WORK and citizen.is_available_for_schedule():
		citizen.idle()


func _sync_world_state() -> void:
	var world := _agent.get_world_state()
	# A resting resident must not count as assigned, otherwise the work goal would
	# remain satisfied across the start of the next shift.
	world.set_state("assigned", citizen.state != Citizen.State.IDLE and citizen.state != Citizen.State.RESTING)


func _add_goal(goal_name: String, intent: Intent, state_key: String) -> void:
	var goal := CitizenGoal.new()
	goal.name = goal_name
	goal.configure(self, intent, state_key)
	_goals.add_child(goal)


func _add_action(action_name: String, intent: Intent, state_key: String, action_cost: int) -> void:
	var action := CitizenAction.new()
	action.name = action_name
	action.configure(self, intent, state_key, action_cost)
	_actions.add_child(action)
