extends SceneTree


class ScriptedStep extends BehaviorStep:
	var statuses: Array[BehaviorStep.Status]
	var ticks := 0
	var suspends := 0
	var resumes := 0

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


func _init() -> void:
	_test_fact_sets_and_snapshots()
	_test_utility_hysteresis()
	_test_failure_cooldown()
	_test_behavior_composites()
	_test_runner_interrupt_and_resume()
	_test_resume_drops_stale_task()
	_test_order_reconciliation()
	_test_reservations()
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
	# Work loses right after failing, even though its raw utility is higher.
	memory.set_cooldown(&"work", 6.0)
	var fresh := WorldSnapshot.new(0, 0.0, 0.0)
	assert(arbiter.choose(fresh, citizen, null, memory).goal == eat)
	# Once the cooldown window elapses, work is preferred again.
	var later := WorldSnapshot.new(0, 6.0, 0.0)
	assert(arbiter.choose(later, citizen, null, memory).goal == work)


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
	# The interrupt completes; the stale work task fails its guard and is dropped.
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(runner.active_task == null and runner.suspended_count() == 0)


func _test_reservations() -> void:
	var ledger := ReservationLedger.new()
	assert(ledger.claim(&"tree_7", 1, 0.0, 5.0))
	assert(not ledger.claim(&"tree_7", 2, 0.0, 5.0))
	assert(ledger.claim(&"tree_7", 1, 1.0, 5.0)) # owner re-affirms
	assert(ledger.owner_of(&"tree_7", 1.0) == 1)
	assert(ledger.is_available_for(&"tree_7", 1, 1.0))
	assert(not ledger.is_available_for(&"tree_7", 2, 1.0))
	# A release from the wrong citizen is ignored; the rightful owner can release.
	ledger.release(&"tree_7", 2)
	assert(ledger.owner_of(&"tree_7", 1.0) == 1)
	ledger.release(&"tree_7", 1)
	assert(ledger.claim(&"tree_7", 2, 2.0, 5.0))
	# Expiry frees an abandoned claim.
	ledger.expire(100.0)
	assert(ledger.active_count() == 0)


func _test_behavior_composites() -> void:
	var context := _context()
	var first := ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var second := ScriptedStep.new([BehaviorStep.Status.RUNNING, BehaviorStep.Status.SUCCESS])
	var sequence := SequenceStep.new([first, second])
	assert(sequence.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(first.ticks == 1 and second.ticks == 1)
	assert(sequence.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(first.ticks == 1 and second.ticks == 2)

	var failure := ScriptedStep.new([BehaviorStep.Status.FAILURE])
	var fallback := ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var selector := SelectorStep.new([failure, fallback])
	assert(selector.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(failure.ticks == 1 and fallback.ticks == 1)

	var slow := ScriptedStep.new([BehaviorStep.Status.RUNNING])
	var fast := ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var parallel := ParallelStep.new([slow, fast], ParallelStep.SuccessPolicy.ANY)
	assert(parallel.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(not slow._entered)


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


func _context() -> BehaviorContext:
	var actuator := ShadowCitizenActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(WorldSnapshot.new(0, 0.0, 0.0, AIFactSet.new(), {
		1: CitizenSnapshot.new(1),
	}), null)
	return context
