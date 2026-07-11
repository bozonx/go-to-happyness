class_name CitizenGoapBrain
extends Node

const THINK_INTERVAL := 0.25

enum Intent { SLEEP, EAT, WORK }

var citizen: Citizen
var simulation: Node
var worker_index := 0
var meal_requested := false
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

	_add_goal("Sleep", Intent.SLEEP, "resting")
	_add_goal("Eat", Intent.EAT, "fed")
	_add_goal("Work", Intent.WORK, "assigned")
	_add_action("GoHome", Intent.SLEEP, "resting", 1)
	_add_action("EatAtCanteen", Intent.EAT, "fed", 1)
	_add_action("PerformAssignedWork", Intent.WORK, "assigned", 2)

	_agent = GoapAgent.new()
	_agent.name = "Agent"
	_agent.goals_node = _goals
	_agent.actions_node = _actions
	add_child(_agent)
	_agent.init(citizen)
	_sync_world_state()


func tick(delta: float) -> void:
	if _agent == null or citizen.is_player_controlled:
		return
	_think_time -= delta
	if _think_time > 0.0:
		return
	_think_time = THINK_INTERVAL
	_sync_world_state()
	_agent.process(THINK_INTERVAL)


func request_meal() -> void:
	meal_requested = true
	if _agent != null:
		_agent.get_world_state().set_state("fed", false)
	_think_time = 0.0


func finish_meal_request() -> void:
	meal_requested = false
	_think_time = 0.0


func request_decision() -> void:
	if _agent != null:
		_agent.get_world_state().set_state("assigned", false)
	_think_time = 0.0


func is_goal_valid(intent: Intent) -> bool:
	return _decision_context().is_goal_valid(intent)


func get_goal_priority(intent: Intent) -> int:
	return _decision_context().priority_for(intent)


func _decision_context() -> CitizenDecisionContext:
	var context := CitizenDecisionContext.new()
	context.is_night = simulation._is_night()
	context.has_home = is_instance_valid(citizen.home)
	context.has_canteen = is_instance_valid(simulation.canteen)
	context.meal_requested = meal_requested
	context.can_assign_work = simulation._can_assign_goap_work(citizen)
	return context


func can_start(intent: Intent) -> bool:
	return is_goal_valid(intent)


func start_intent(intent: Intent) -> void:
	match intent:
		Intent.SLEEP:
			citizen.go_home()
		Intent.EAT:
			citizen.go_to_canteen(simulation.canteen_position)
		Intent.WORK:
			simulation._assign_goap_work(citizen, worker_index)


func is_intent_complete(intent: Intent) -> bool:
	match intent:
		Intent.SLEEP:
			return citizen.state == Citizen.State.RESTING
		Intent.EAT:
			return citizen.state == Citizen.State.IDLE and not meal_requested
		Intent.WORK:
			return citizen.state != Citizen.State.IDLE
	return false


func cancel_intent(intent: Intent) -> void:
	if intent == Intent.WORK and citizen.is_available_for_schedule():
		citizen.idle()


func _sync_world_state() -> void:
	var world := _agent.get_world_state()
	world.set_state("resting", citizen.state == Citizen.State.RESTING)
	world.set_state("fed", not meal_requested)
	world.set_state("assigned", citizen.state != Citizen.State.IDLE)


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
