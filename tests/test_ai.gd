extends SceneTree

const SleepGoalScript = preload("res://game/features/decision/domain/goals/sleep_goal.gd")
const SettlementCitizenActuatorScript = preload("res://game/features/decision/application/settlement_citizen_actuator.gd")


class ScriptedStep extends BehaviorStep:
	var statuses: Array[BehaviorStep.Status]
	var ticks := 0
	var suspends := 0
	var resumes := 0
	var cancels := 0
	var finishes := 0
	var final_status := Status.RUNNING

	func _init(next_statuses: Array[BehaviorStep.Status]) -> void:
		statuses = next_statuses.duplicate()

	func _tick(_context: BehaviorContext, _delta: float) -> Status:
		var index := mini(ticks, statuses.size() - 1)
		ticks += 1
		return statuses[index]

	func _suspend(_context: BehaviorContext) -> void:
		suspends += 1

	func _resume(_context: BehaviorContext) -> void:
		resumes += 1

	func _cancel(_context: BehaviorContext) -> void:
		cancels += 1

	func _finish(_context: BehaviorContext, status: Status) -> void:
		finishes += 1
		final_status = status


class FixedGoal extends AICitizenGoal:
	var utility: float

	func _init(next_id: StringName, next_utility: float) -> void:
		super(next_id)
		utility = next_utility

	func score(
		_snapshot: WorldSnapshot,
		_citizen: CitizenSnapshot,
		_order: CitizenOrder,
		_blackboard: AIBlackboard
	) -> float:
		return utility


class ScriptedGoal extends FixedGoal:
	var statuses: Array[BehaviorStep.Status]
	var build_count := 0
	var last_step: ScriptedStep

	func _init(
		next_id: StringName,
		next_utility: float,
		next_statuses: Array[BehaviorStep.Status]
	) -> void:
		super(next_id, next_utility)
		statuses = next_statuses.duplicate()

	func build_task(
		_snapshot: WorldSnapshot,
		_citizen: CitizenSnapshot,
		_order: CitizenOrder,
		_blackboard: AIBlackboard
	) -> BehaviorTask:
		build_count += 1
		last_step = ScriptedStep.new(statuses)
		return BehaviorTask.new(id, last_step)


class NullTaskGoal extends FixedGoal:
	func build_task(
		_snapshot: WorldSnapshot,
		_citizen: CitizenSnapshot,
		_order: CitizenOrder,
		_blackboard: AIBlackboard
	) -> BehaviorTask:
		return null


class FakeActuator extends CitizenActuator:
	var stop_count := 0
	var cancel_action_count := 0
	var action_start_count := 0
	var next_action_status := ActionStatus.RUNNING

	func stop() -> void:
		stop_count += 1

	func cancel_action() -> void:
		cancel_action_count += 1

	func begin_action(
		action: StringName,
		_target_entity_id: int = -1,
		_payload: AIFactSet = null
	) -> bool:
		action_start_count += 1
		return action == &"sleep"

	func action_status() -> ActionStatus:
		return next_action_status


class FakeFacade extends AIWorldFacade:
	var citizens: Dictionary
	var simulation_seconds := 0.0
	var game_minutes := 0.0

	func _init(next_citizens: Dictionary) -> void:
		citizens = next_citizens

	func capture(sequence: int) -> WorldSnapshot:
		return WorldSnapshot.new(
			sequence,
			simulation_seconds,
			game_minutes,
			AIFactSet.new(),
			citizens
		)


class NullFacade extends AIWorldFacade:
	func capture(_sequence: int) -> WorldSnapshot:
		return null


func _init() -> void:
	_test_fact_sets_and_snapshots()
	_test_blackboard_clear()
	_test_utility_hysteresis()
	_test_failure_cooldown()
	_test_emergency_goal_bypasses_cooldown()
	_test_behavior_composites_and_lifecycle()
	_test_runner_interrupt_and_resume()
	_test_resume_drops_stale_task()
	_test_resume_drops_changed_order()
	_test_citizen_brain_cancels_for_player_control()
	_test_citizen_brain_failure_cooldown()
	_test_citizen_brain_cancels_when_winning_goal_has_no_task()
	_test_native_sleep_goal()
	_test_production_sleep_actuator()
	_test_order_reconciliation()
	_test_order_board_deduplicates_provider_output()
	_test_director_reconfiguration_clears_orders()
	_test_reservations()
	_test_runtime_configuration_and_identity()
	_test_runtime_reconfiguration_updates_registered_brains()
	_test_runtime_think_budget_is_fair()
	quit(0)


func _test_fact_sets_and_snapshots() -> void:
	var facts := AIFactSet.new({&"hunger": 0.75})
	var changed := facts.with_value(&"hunger", 0.25)
	assert(is_equal_approx(float(facts.value(&"hunger")), 0.75))
	assert(is_equal_approx(float(changed.value(&"hunger")), 0.25))
	var citizen := CitizenSnapshot.new(7, Vector3(1.0, 0.0, 2.0), false, true, facts)
	var snapshot := WorldSnapshot.new(3, 10.0, 480.0, AIFactSet.new(), {7: citizen})
	assert(snapshot.sequence == 3)
	assert(snapshot.citizen_count() == 1)
	assert(snapshot.citizen(7) == citizen)


func _test_blackboard_clear() -> void:
	var memory := AIBlackboard.new()
	memory.set_value(&"target", 7)
	memory.set_cooldown(&"work", 10.0)
	memory.clear()
	assert(not memory.has(&"target"))
	assert(not memory.is_on_cooldown(&"work", 0.0))


func _test_utility_hysteresis() -> void:
	var work := FixedGoal.new(&"work", 0.50)
	var eat := FixedGoal.new(&"eat", 0.54)
	var arbiter := UtilityArbiter.new()
	arbiter.configure([work, eat])
	var snapshot := WorldSnapshot.new()
	var citizen := CitizenSnapshot.new(1)
	var memory := AIBlackboard.new()
	assert(arbiter.choose(snapshot, citizen, null, memory).goal == eat)
	assert(arbiter.choose(snapshot, citizen, null, memory, &"work").goal == work)
	eat.utility = 0.70
	assert(arbiter.choose(snapshot, citizen, null, memory, &"work").goal == eat)
	work.utility = 0.0
	eat.utility = 0.02
	assert(arbiter.choose(snapshot, citizen, null, memory, &"work").goal == eat)


func _test_failure_cooldown() -> void:
	var work := FixedGoal.new(&"work", 0.60)
	var eat := FixedGoal.new(&"eat", 0.40)
	var arbiter := UtilityArbiter.new()
	arbiter.configure([work, eat])
	var citizen := CitizenSnapshot.new(1)
	var memory := AIBlackboard.new()
	memory.set_cooldown(&"work", 6.0)
	var fresh := WorldSnapshot.new(0, 0.0, 0.0)
	assert(arbiter.choose(fresh, citizen, null, memory).goal == eat)
	var only_work := UtilityArbiter.new()
	only_work.configure([work])
	assert(only_work.choose(fresh, citizen, null, memory).goal == null)
	var later := WorldSnapshot.new(0, 6.0, 0.0)
	assert(arbiter.choose(later, citizen, null, memory).goal == work)


func _test_emergency_goal_bypasses_cooldown() -> void:
	var emergency := FixedGoal.new(&"flee", 0.96)
	var arbiter := UtilityArbiter.new()
	arbiter.configure([emergency])
	var memory := AIBlackboard.new()
	memory.set_cooldown(&"flee", 6.0)
	var result := arbiter.choose(WorldSnapshot.new(0, 0.0), CitizenSnapshot.new(1), null, memory)
	assert(result.goal == emergency)
	assert(is_equal_approx(result.utility, emergency.utility))


func _test_behavior_composites_and_lifecycle() -> void:
	var context := _context()
	var first := ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var second := ScriptedStep.new([BehaviorStep.Status.RUNNING, BehaviorStep.Status.SUCCESS])
	var sequence := SequenceStep.new([first, second])
	assert(sequence.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(first.ticks == 1 and second.ticks == 1)
	assert(sequence.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(first.ticks == 1 and second.ticks == 2)
	assert(first.finishes == 1 and second.finishes == 1 and sequence._finished)

	var terminal := ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	assert(terminal.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(terminal.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(terminal.ticks == 1 and terminal.finishes == 1)
	terminal.cancel(context)
	assert(terminal.cancels == 0)

	var failure := ScriptedStep.new([BehaviorStep.Status.FAILURE])
	var fallback := ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var selector := SelectorStep.new([failure, fallback])
	assert(selector.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(failure.ticks == 1 and fallback.ticks == 1)

	var slow := ScriptedStep.new([BehaviorStep.Status.RUNNING])
	var fast := ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var parallel := ParallelStep.new([slow, fast], ParallelStep.SuccessPolicy.ANY)
	assert(parallel.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(not slow._entered and fast.finishes == 1)

	var failed_any := ParallelStep.new([
		ScriptedStep.new([BehaviorStep.Status.FAILURE]),
		ScriptedStep.new([BehaviorStep.Status.RUNNING]),
	], ParallelStep.SuccessPolicy.ANY)
	assert(failed_any.run(context, 0.1) == BehaviorStep.Status.FAILURE)


func _test_runner_interrupt_and_resume() -> void:
	var context := _context()
	var work_step := ScriptedStep.new([
		BehaviorStep.Status.RUNNING,
		BehaviorStep.Status.SUCCESS,
	])
	var urgent_step := ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var runner := BehaviorRunner.new()
	assert(runner.start(BehaviorTask.new(&"work", work_step), context))
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(runner.start(BehaviorTask.new(&"urgent", urgent_step), context))
	assert(work_step.suspends == 1 and runner.suspended_count() == 1)
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(runner.active_goal_id() == &"work")
	assert(work_step.resumes == 1)
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(runner.active_task == null)


func _test_resume_drops_stale_task() -> void:
	var context := _context()
	var work_step := ScriptedStep.new([BehaviorStep.Status.RUNNING])
	var urgent_step := ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var runner := BehaviorRunner.new()
	var work_task := BehaviorTask.new(&"work", work_step)
	work_task.guard = func(_ctx: BehaviorContext) -> bool: return false
	assert(runner.start(work_task, context))
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(runner.start(BehaviorTask.new(&"urgent", urgent_step), context))
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(runner.active_task == null and runner.suspended_count() == 0)
	assert(work_step.cancels == 1)


func _test_resume_drops_changed_order() -> void:
	var original := CitizenOrder.new(1, &"work", &"jobs", 1.0)
	original.id = 11
	var context := _context(original)
	var work_step := ScriptedStep.new([BehaviorStep.Status.RUNNING])
	var work_task := BehaviorTask.new(&"work", work_step)
	work_task.order_id = original.id
	var runner := BehaviorRunner.new()
	assert(runner.start(work_task, context))
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(runner.start(BehaviorTask.new(&"urgent", ScriptedStep.new([BehaviorStep.Status.SUCCESS])), context))
	var replacement := CitizenOrder.new(1, &"work", &"jobs", 1.0)
	replacement.id = 12
	context.refresh(context.snapshot, replacement)
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(runner.active_task == null and work_step.cancels == 1)


func _test_citizen_brain_cancels_for_player_control() -> void:
	var goal := ScriptedGoal.new(&"work", 0.5, [BehaviorStep.Status.RUNNING])
	var brain := CitizenBrain.new(1, FakeActuator.new(1), [goal])
	var active := _snapshot(0.0, CitizenSnapshot.new(1, Vector3.ZERO, false, true))
	brain.think(active, null)
	brain.tick(active, null, 0.1)
	assert(goal.last_step.ticks == 1)
	var player_controlled := _snapshot(0.1, CitizenSnapshot.new(1, Vector3.ZERO, true, true))
	brain.tick(player_controlled, null, 0.1)
	assert(goal.last_step.cancels == 1)
	assert(brain.runner.active_task == null)
	var unavailable_goal := ScriptedGoal.new(&"work", 0.5, [BehaviorStep.Status.RUNNING])
	var unavailable_brain := CitizenBrain.new(1, FakeActuator.new(1), [unavailable_goal])
	unavailable_brain.think(active, null)
	unavailable_brain.tick(active, null, 0.1)
	var unavailable := _snapshot(0.1, CitizenSnapshot.new(1, Vector3.ZERO, false, false))
	unavailable_brain.tick(unavailable, null, 0.1)
	assert(unavailable_goal.last_step.cancels == 1)


func _test_citizen_brain_failure_cooldown() -> void:
	var goal := ScriptedGoal.new(&"work", 0.60, [BehaviorStep.Status.FAILURE])
	var brain := CitizenBrain.new(1, FakeActuator.new(1), [goal])
	var fresh := _snapshot(0.0, CitizenSnapshot.new(1))
	brain.think(fresh, null)
	brain.tick(fresh, null, 0.1)
	assert(goal.build_count == 1 and goal.last_step.finishes == 1)
	brain.think(fresh, null)
	assert(goal.build_count == 1 and brain.runner.active_task == null)
	var later := _snapshot(6.0, CitizenSnapshot.new(1))
	brain.think(later, null)
	assert(goal.build_count == 2)


func _test_citizen_brain_cancels_when_winning_goal_has_no_task() -> void:
	var work := ScriptedGoal.new(&"work", 0.5, [BehaviorStep.Status.RUNNING])
	var blocked := NullTaskGoal.new(&"blocked", 0.8)
	var brain := CitizenBrain.new(1, FakeActuator.new(1), [work, blocked])
	var snapshot := _snapshot(0.0, CitizenSnapshot.new(1))
	work.utility = 0.9
	brain.think(snapshot, null)
	brain.tick(snapshot, null, 0.1)
	assert(work.last_step.ticks == 1)
	work.utility = 0.5
	brain.think(snapshot, null)
	assert(work.last_step.cancels == 1 and brain.runner.active_task == null)
	assert(brain.blackboard.is_on_cooldown(&"blocked", 0.0))


func _test_native_sleep_goal() -> void:
	var goal := SleepGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var sleep_snapshot := _sleep_snapshot(true)
	brain.think(sleep_snapshot, null)
	brain.tick(sleep_snapshot, null, 0.1)
	assert(actuator.action_start_count == 1)
	assert(brain.runner.active_goal_id() == &"sleep")
	var morning_snapshot := _sleep_snapshot(false)
	brain.tick(morning_snapshot, null, 0.1)
	assert(actuator.cancel_action_count == 1)
	assert(brain.runner.active_task == null)
	var no_home := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.should_sleep": true,
		&"needs.has_home": false,
		&"needs.can_start_sleep": true,
	}))
	assert(is_zero_approx(goal.score(_snapshot(0.0, no_home), no_home, null, AIBlackboard.new())))


func _test_production_sleep_actuator() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 17
	var home := Node3D.new()
	citizen.assign_home(home)
	var actuator := SettlementCitizenActuatorScript.new(citizen)
	assert(actuator.is_valid())
	assert(actuator.begin_action(&"sleep"))
	assert(citizen.state == Citizen.State.TO_HOME)
	assert(actuator.action_status() == CitizenActuator.ActionStatus.RUNNING)
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	home.free()
	citizen.free()


func _test_order_reconciliation() -> void:
	var board := OrderBoard.new()
	var low := CitizenOrder.new(5, &"haul", &"logistics", 0.4)
	var high := CitizenOrder.new(5, &"build", &"construction", 0.8)
	board.replace_issuer_orders(&"logistics", [low], 0.0)
	board.replace_issuer_orders(&"construction", [high], 0.0)
	assert(board.candidate_count() == 2)
	assert(board.order_for(5, 0.0) == high)
	board.replace_issuer_orders(&"construction", [], 1.0)
	assert(board.order_for(5, 1.0) == low)
	var replacement := CitizenOrder.new(5, &"haul", &"logistics", 0.4)
	board.replace_issuer_orders(&"logistics", [replacement], 2.0)
	assert(replacement.id == low.id)


func _test_order_board_deduplicates_provider_output() -> void:
	var board := OrderBoard.new()
	var first := CitizenOrder.new(5, &"haul", &"logistics", 0.4)
	var duplicate := CitizenOrder.new(5, &"haul", &"logistics", 0.4)
	board.replace_issuer_orders(&"logistics", [first, duplicate], 0.0)
	assert(board.candidate_count() == 1)
	assert(board.order_for(5, 0.0).id == first.id)
	var competing := CitizenOrder.new(5, &"haul", &"construction", 0.8)
	board.replace_issuer_orders(&"construction", [competing], 0.0)
	assert(board.candidate_count() == 2)
	assert(board.order_for(5, 0.0) == competing)


func _test_director_reconfiguration_clears_orders() -> void:
	var director := SettlementDirector.new()
	director.order_board.replace_issuer_orders(&"jobs", [CitizenOrder.new(1, &"work", &"jobs", 1.0)], 0.0)
	assert(director.order_board.candidate_count() == 1)
	director.configure([])
	assert(director.order_board.candidate_count() == 0)


func _test_reservations() -> void:
	var ledger := ReservationLedger.new()
	assert(ledger.claim(&"tree_7", 1, 0.0, 5.0))
	assert(not ledger.claim(&"tree_7", 2, 0.0, 5.0))
	assert(ledger.claim(&"tree_7", 1, 1.0, 5.0))
	assert(ledger.owner_of(&"tree_7", 1.0) == 1)
	assert(ledger.is_available_for(&"tree_7", 1, 1.0))
	assert(not ledger.is_available_for(&"tree_7", 2, 1.0))
	ledger.release(&"tree_7", 2)
	assert(ledger.owner_of(&"tree_7", 1.0) == 1)
	ledger.release(&"tree_7", 1)
	assert(ledger.claim(&"tree_7", 2, 2.0, 5.0))
	assert(ledger.owner_of(&"tree_7", 7.0) == 0)
	assert(ledger.active_count() == 0)


func _test_runtime_configuration_and_identity() -> void:
	var no_facade := CitizenAISystem.new()
	assert(not no_facade.configure(null))
	assert(no_facade.facade == null and no_facade.latest_snapshot == null)
	no_facade.free()
	var null_snapshot := CitizenAISystem.new()
	assert(not null_snapshot.configure(NullFacade.new()))
	assert(null_snapshot.facade == null and null_snapshot.latest_snapshot == null)
	null_snapshot.free()
	var system := CitizenAISystem.new()
	system.snapshot_interval = 0.0
	system.director_interval = -1.0
	system.think_interval = 0.0
	system.max_thinks_per_frame = -5
	system.configure(FakeFacade.new({}))
	assert(system.snapshot_interval > 0.0)
	assert(system.director_interval > 0.0)
	assert(system.think_interval > 0.0)
	assert(system.max_thinks_per_frame == 0)
	system.register_citizen(1, FakeActuator.new(2))
	assert(system.brain_count() == 0)
	system.register_citizen(1, FakeActuator.new(1))
	assert(system.brain_count() == 1)
	assert(system.reservations.claim(&"tree", 1, 0.0))
	system.unregister_citizen(1)
	assert(system.reservations.active_count() == 0)
	system.free()


func _test_runtime_reconfiguration_updates_registered_brains() -> void:
	var citizens := {1: CitizenSnapshot.new(1)}
	var facade := FakeFacade.new(citizens)
	var system := CitizenAISystem.new()
	system.configure(facade)
	var original_snapshot := system.latest_snapshot
	assert(not system.configure(NullFacade.new()))
	assert(system.facade == facade and system.latest_snapshot == original_snapshot)
	system.register_citizen(1, FakeActuator.new(1))
	var goal := ScriptedGoal.new(&"idle", 0.5, [BehaviorStep.Status.RUNNING])
	system.configure(facade, [goal])
	system._physics_process(0.1)
	assert(goal.build_count == 1)
	system.unregister_citizen(1)
	system.free()


func _test_runtime_think_budget_is_fair() -> void:
	var citizens := {
		1: CitizenSnapshot.new(1),
		2: CitizenSnapshot.new(2),
		3: CitizenSnapshot.new(3),
	}
	var goal := ScriptedGoal.new(&"idle", 0.5, [BehaviorStep.Status.RUNNING])
	var system := CitizenAISystem.new()
	system.max_thinks_per_frame = 1
	system.think_interval = 100.0
	system.configure(FakeFacade.new(citizens), [goal])
	for citizen_id in citizens:
		system.register_citizen(citizen_id, FakeActuator.new(citizen_id))
	system._physics_process(0.1)
	system._physics_process(0.1)
	system._physics_process(0.1)
	assert(goal.build_count == 3)
	for citizen_id in citizens:
		system.unregister_citizen(citizen_id)
	system.free()


func _context(order: CitizenOrder = null) -> BehaviorContext:
	var actuator := ShadowCitizenActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(_snapshot(0.0, CitizenSnapshot.new(1)), order)
	return context


func _snapshot(simulation_seconds: float, citizen: CitizenSnapshot) -> WorldSnapshot:
	return WorldSnapshot.new(simulation_seconds as int, simulation_seconds, 0.0, AIFactSet.new(), {
		citizen.id: citizen,
	})


func _sleep_snapshot(should_sleep: bool) -> WorldSnapshot:
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.should_sleep": should_sleep,
		&"needs.has_home": true,
		&"needs.can_start_sleep": true,
	}))
	return _snapshot(0.0, citizen)
