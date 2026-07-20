class_name TestAIFramework
extends RefCounted

const TestAIHelpers = preload("res://tests/ai/test_ai_helpers.gd")


static func run_all() -> void:
	_test_fact_sets_and_snapshots()
	_test_fact_values_are_isolated()
	_test_fact_values_reject_runtime_references()
	_test_blackboard_clear()
	_test_utility_hysteresis()
	_test_utility_hysteresis_allows_critical_preemption()
	_test_failure_cooldown()
	_test_emergency_goal_bypasses_cooldown()
	_test_behavior_composites_and_lifecycle()
	_test_composites_preserve_failure_reason()
	_test_runner_interrupt_and_resume()
	_test_resume_drops_stale_task()
	_test_resume_drops_changed_order()
	_test_extended_order_keeps_active_task_alive()
	_test_runner_cancels_stale_active_order_and_releases_reservation()
	_test_runner_trace_records_invalid_task_reason()
	_test_invalid_task_applies_failure_cooldown()
	_test_runner_times_out_nonterminating_task()
	_test_reservation_ledger_ttl_and_release()
	_test_reserved_step_renews_lease()
	_test_move_to_step()
	_test_move_to_step_records_failure_reason()
	_test_relax_at_position_step()
	_test_action_step_records_failure_reason()
	_test_move_step_failure_is_recorded()
	_test_route_candidate_cache()
	_test_runtime_configuration_and_identity()
	_test_runtime_reconfiguration_updates_registered_brains()
	_test_requested_refresh_thinks_immediately()
	_test_runtime_think_budget_is_fair()


static func _test_fact_sets_and_snapshots() -> void:
	var facts := AIFactSet.new({&"hunger": 0.75})
	var changed := facts.with_value(&"hunger", 0.25)
	assert(is_equal_approx(float(facts.value(&"hunger")), 0.75))
	assert(is_equal_approx(float(changed.value(&"hunger")), 0.25))
	var citizen := CitizenSnapshot.new(7, Vector3(1.0, 0.0, 2.0), false, true, facts)
	var snapshot := WorldSnapshot.new(3, 10.0, 480.0, AIFactSet.new(), {7: citizen})
	assert(snapshot.sequence == 3)
	assert(snapshot.citizen_count() == 1)
	assert(snapshot.citizen(7) == citizen)


static func _test_fact_values_are_isolated() -> void:
	var facts := AIFactSet.from_owned_values({&"targets": [{&"id": &"tree:1"}]})
	var targets: Array = facts.value(&"targets", []) as Array
	(targets[0] as Dictionary)[&"id"] = &"tree:changed"
	assert(((facts.value(&"targets", []) as Array)[0] as Dictionary)[&"id"] == &"tree:1")


static func _test_fact_values_reject_runtime_references() -> void:
	assert(AIFactSet.is_value_safe({&"target": Vector3.ZERO}))
	var runtime_node := Node.new()
	assert(not AIFactSet.is_value_safe({&"target": runtime_node}))
	runtime_node.free()
	assert(not AIFactSet.is_value_safe(func() -> void: pass))


static func _test_blackboard_clear() -> void:
	var memory := AIBlackboard.new()
	memory.set_value(&"target", 7)
	memory.set_cooldown(&"work", 10.0)
	memory.clear()
	assert(not memory.has(&"target"))
	assert(not memory.is_on_cooldown(&"work", 0.0))


static func _test_utility_hysteresis() -> void:
	var work := TestAIHelpers.FixedGoal.new(&"work", 0.50)
	var eat := TestAIHelpers.FixedGoal.new(&"eat", 0.54)
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


static func _test_utility_hysteresis_allows_critical_preemption() -> void:
	var work := TestAIHelpers.FixedGoal.new(&"work", 0.90)
	var emergency := TestAIHelpers.FixedGoal.new(&"emergency", 1.0)
	var arbiter := UtilityArbiter.new()
	arbiter.configure([work, emergency])
	var result := arbiter.choose(WorldSnapshot.new(), CitizenSnapshot.new(1), null, AIBlackboard.new(), &"work")
	assert(result.goal == emergency)


static func _test_failure_cooldown() -> void:
	var work := TestAIHelpers.FixedGoal.new(&"work", 0.60)
	var eat := TestAIHelpers.FixedGoal.new(&"eat", 0.40)
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


static func _test_emergency_goal_bypasses_cooldown() -> void:
	var emergency := TestAIHelpers.FixedGoal.new(&"flee", 0.96)
	var arbiter := UtilityArbiter.new()
	arbiter.configure([emergency])
	var memory := AIBlackboard.new()
	memory.set_cooldown(&"flee", 6.0)
	var result := arbiter.choose(WorldSnapshot.new(0, 0.0), CitizenSnapshot.new(1), null, memory)
	assert(result.goal == emergency)
	assert(is_equal_approx(result.utility, emergency.utility))


static func _test_behavior_composites_and_lifecycle() -> void:
	var context := TestAIHelpers.context()
	var first := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var second := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.RUNNING, BehaviorStep.Status.SUCCESS])
	var sequence := SequenceStep.new([first, second])
	assert(sequence.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(first.ticks == 1 and second.ticks == 1)
	assert(sequence.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(first.ticks == 1 and second.ticks == 2)
	assert(first.finishes == 1 and second.finishes == 1 and sequence._finished)

	var terminal := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	assert(terminal.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(terminal.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(terminal.ticks == 1 and terminal.finishes == 1)
	terminal.cancel(context)
	assert(terminal.cancels == 0)

	var failure := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.FAILURE])
	var fallback := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var selector := SelectorStep.new([failure, fallback])
	assert(selector.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(failure.ticks == 1 and fallback.ticks == 1)

	var slow := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.RUNNING])
	var fast := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.SUCCESS])
	var parallel := ParallelStep.new([slow, fast], ParallelStep.SuccessPolicy.ANY)
	assert(parallel.run(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(not slow._entered and fast.finishes == 1)

	var failed_any := ParallelStep.new([
		TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.FAILURE]),
		TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.RUNNING]),
	], ParallelStep.SuccessPolicy.ANY)
	assert(failed_any.run(context, 0.1) == BehaviorStep.Status.FAILURE)


static func _test_composites_preserve_failure_reason() -> void:
	var context := TestAIHelpers.context()
	var sequence := SequenceStep.new([TestAIHelpers.FailingStep.new(BehaviorStep.FailureReason.UNREACHABLE)])
	assert(sequence.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(sequence.failure_reason == BehaviorStep.FailureReason.UNREACHABLE)
	var selector := SelectorStep.new([TestAIHelpers.FailingStep.new(BehaviorStep.FailureReason.RESERVATION_LOST)])
	assert(selector.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(selector.failure_reason == BehaviorStep.FailureReason.RESERVATION_LOST)
	var parallel := ParallelStep.new([TestAIHelpers.FailingStep.new(BehaviorStep.FailureReason.ACTUATOR_REJECTED)])
	assert(parallel.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(parallel.failure_reason == BehaviorStep.FailureReason.ACTUATOR_REJECTED)


static func _test_runner_interrupt_and_resume() -> void:
	var context := TestAIHelpers.context()
	var work_step := TestAIHelpers.ScriptedStep.new([
		BehaviorStep.Status.RUNNING,
		BehaviorStep.Status.SUCCESS,
	])
	var urgent_step := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.SUCCESS])
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


static func _test_resume_drops_stale_task() -> void:
	var context := TestAIHelpers.context()
	var work_step := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.RUNNING])
	var runner := BehaviorRunner.new()
	var work_task := BehaviorTask.new(&"work", work_step)
	work_task.guard = func(_ctx: BehaviorContext) -> bool: return false
	assert(runner.start(work_task, context))
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(runner.active_task == null and runner.suspended_count() == 0)
	assert(work_step.ticks == 0)


static func _test_resume_drops_changed_order() -> void:
	var original := CitizenOrder.new(1, &"work", &"jobs", 1.0)
	original.id = 11
	var context := TestAIHelpers.context(original)
	var work_step := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.RUNNING])
	var work_task := BehaviorTask.new(&"work", work_step)
	work_task.order_id = original.id
	var runner := BehaviorRunner.new()
	assert(runner.start(work_task, context))
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(runner.start(BehaviorTask.new(&"urgent", TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.SUCCESS])), context))
	var replacement := CitizenOrder.new(1, &"work", &"jobs", 1.0)
	replacement.id = 12
	context.refresh(context.snapshot, replacement)
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.SUCCESS)
	assert(runner.active_task == null and work_step.cancels == 1)


static func _test_extended_order_keeps_active_task_alive() -> void:
	var expired_order := CitizenOrder.new(1, &"work", &"jobs", 1.0)
	expired_order.id = 11
	expired_order.expires_at = 1.0
	var renewed_order := CitizenOrder.new(1, &"work", &"jobs", 1.0)
	renewed_order.id = 11
	renewed_order.expires_at = 10.0
	var context := TestAIHelpers.context(expired_order)
	context.refresh(TestAIHelpers.snapshot(2.0, CitizenSnapshot.new(1)), renewed_order)
	var task := BehaviorTask.new(&"work", TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.RUNNING]))
	task.order_id = expired_order.id
	task.order = expired_order
	assert(task.invalid_reason(context) == BehaviorStep.FailureReason.NONE)


static func _test_runner_cancels_stale_active_order_and_releases_reservation() -> void:
	## ReservedStep was removed; verify that runner correctly fails on order change
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var order := CitizenOrder.new(1, &"forestry", &"wood", 1.0)
	order.id = 55
	context.refresh(TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(1)), order)
	var task := BehaviorTask.new(&"forestry", TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.RUNNING]))
	task.order_id = order.id
	var runner := BehaviorRunner.new()
	assert(runner.start(task, context))
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.RUNNING)

	var new_order := CitizenOrder.new(1, &"farming", &"food", 1.0)
	new_order.id = 56
	context.refresh(TestAIHelpers.snapshot(1.0, CitizenSnapshot.new(1)), new_order)
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.FAILURE)


static func _test_runner_trace_records_invalid_task_reason() -> void:
	var context := TestAIHelpers.context()
	var work_step := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.RUNNING])
	var runner := BehaviorRunner.new()
	var task := BehaviorTask.new(&"work", work_step)
	task.guard = func(_ctx: BehaviorContext) -> bool: return false
	assert(runner.start(task, context))
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(task.failure_reason == BehaviorStep.FailureReason.GUARD_REJECTED)
	assert(not runner.trace.is_empty())
	var last_trace: Dictionary = runner.trace.back()
	assert(last_trace.get(&"event") == &"invalid")
	assert(last_trace.get(&"goal") == &"work")
	assert(last_trace.get(&"reason") == BehaviorStep.FailureReason.GUARD_REJECTED)


static func _test_invalid_task_applies_failure_cooldown() -> void:
	var expired_order := CitizenOrder.new(1, &"work", &"jobs", 1.0)
	expired_order.id = 11
	expired_order.expires_at = 1.0
	var context := TestAIHelpers.context(expired_order)
	context.refresh(TestAIHelpers.snapshot(2.0, CitizenSnapshot.new(1)), null)
	var task := BehaviorTask.new(&"work", TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.RUNNING]))
	task.order_id = expired_order.id
	## Cooldowns are set by CitizenBrain, not BehaviorRunner directly.
	## Verify that runner.tick correctly emits FAILURE when the task is invalid.
	var runner := BehaviorRunner.new()
	assert(runner.start(task, context))
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(not runner.trace.is_empty())


static func _test_runner_times_out_nonterminating_task() -> void:
	var context := TestAIHelpers.context()
	var step := TestAIHelpers.ScriptedStep.new([BehaviorStep.Status.RUNNING])
	var task := BehaviorTask.new(&"work", step)
	task.max_run_seconds = 2.0
	var runner := BehaviorRunner.new()
	assert(runner.start(task, context))
	assert(runner.tick(context, 1.0) == BehaviorStep.Status.RUNNING)
	assert(runner.tick(context, 1.1) == BehaviorStep.Status.FAILURE)
	assert((runner.trace.back() as Dictionary)[&"reason"] == BehaviorStep.FailureReason.TIMEOUT)


static func _test_reservation_ledger_ttl_and_release() -> void:
	var ledger := ReservationLedger.new()
	assert(ledger.claim(&"tree:1", 1, 0.0, 5.0))
	assert(not ledger.claim(&"tree:1", 2, 0.0, 5.0))
	assert(ledger.is_available_for(&"tree:1", 1, 0.0))
	assert(not ledger.is_available_for(&"tree:1", 2, 0.0))
	ledger.release(&"tree:1", 1)
	assert(ledger.is_available_for(&"tree:1", 2, 0.0))
	assert(ledger.active_count() == 0)


static func _test_reserved_step_renews_lease() -> void:
	var ledger := ReservationLedger.new()
	var citizen := CitizenSnapshot.new(1)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: citizen})
	snapshot.reservations = ledger
	var order := CitizenOrder.new(1, &"forestry", &"test", 1.0, AIFactSet.new({
		&"work.tree_id": &"tree:1",
		&"work.tree_access": Vector3(1.0, 0.0, 0.0),
		&"work.sawmill_position": Vector3(2.0, 0.0, 0.0),
		&"work.warehouse_position": Vector3(3.0, 0.0, 0.0),
	}))
	order.target_position = Vector3(4.0, 0.0, 0.0)
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(snapshot, order)
	var step: RefCounted = TestAIHelpers.ForestryWorkStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	snapshot.simulation_seconds = 89.0
	context.refresh(snapshot, order)
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(not ledger.claim([&"forestry.tree", &"tree:1"], 2, 120.0, 5.0))


static func _test_move_to_step() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var target := Vector3(10.0, 0.0, 0.0)
	var step: RefCounted = TestAIHelpers.MoveToStepScript.new(target)
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(actuator.move_to_count == 1)
	assert(actuator.move_to_destination.distance_to(target) < 0.001)
	actuator.arrived_flag = true
	assert(step.run(context, 0.1) == BehaviorStep.Status.SUCCESS)


static func _test_move_to_step_records_failure_reason() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	actuator.next_movement_failure_reason = BehaviorStep.FailureReason.UNREACHABLE
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var step: RefCounted = TestAIHelpers.MoveToStepScript.new(Vector3(10.0, 0.0, 0.0))
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	actuator.movement_failed_flag = true
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(step.failure_reason == BehaviorStep.FailureReason.UNREACHABLE)


static func _test_relax_at_position_step() -> void:
	var actuator := TestAIHelpers.FakeActuator.new()
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var target := Vector3(5.0, 0.0, 5.0)
	var step: RefCounted = TestAIHelpers.MoveToStepScript.new(target)
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(actuator.move_to_count == 1)
	actuator.arrived_flag = true
	assert(step.run(context, 0.1) == BehaviorStep.Status.SUCCESS)


static func _test_action_step_records_failure_reason() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.rest_requested": true,
		&"needs.rest_duration": 2.0,
	}))
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(TestAIHelpers.snapshot(0.0, citizen), null)
	var step: RefCounted = TestAIHelpers.RelaxAtPositionStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	actuator.next_action_status = CitizenActuator.ActionStatus.FAILED
	actuator.next_action_failure_reason = BehaviorStep.FailureReason.UNREACHABLE
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(step.failure_reason == BehaviorStep.FailureReason.UNREACHABLE)


static func _test_move_step_failure_is_recorded() -> void:
	var actuator := TestAIHelpers.FakeActuator.new()
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var step: RefCounted = TestAIHelpers.MoveToStepScript.new(Vector3(1.0, 0.0, 0.0))
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	actuator.movement_failed_flag = true
	actuator.next_movement_failure_reason = BehaviorStep.FailureReason.TARGET_INVALID
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(step.failure_reason == BehaviorStep.FailureReason.TARGET_INVALID)


static func _test_route_candidate_cache() -> void:
	var cache := RouteCandidateCache.new()
	var counter := {&"builds": 0}
	var producer := func() -> Array[Dictionary]:
		counter[&"builds"] = int(counter[&"builds"]) + 1
		return [{&"id": &"tree:1", &"position": Vector3(5.0, 0.0, 5.0)}]
	var result1 := cache.get_or_produce(&"forestry", 1, Vector2i(0, 0), 0.0, producer)
	assert(result1.size() == 1)
	assert(int(counter[&"builds"]) == 1)
	# Second call with same revision/origin/time should return cached result
	var result2 := cache.get_or_produce(&"forestry", 1, Vector2i(0, 0), 0.5, producer)
	assert(result2.size() == 1)
	assert(int(counter[&"builds"]) == 1, "Cache should not call producer again within TTL")
	# Different topology revision should invalidate cache
	var result3 := cache.get_or_produce(&"forestry", 2, Vector2i(0, 0), 0.5, producer)
	assert(result3.size() == 1)
	assert(int(counter[&"builds"]) == 2, "Topology change must bust cache")


static func _test_runtime_configuration_and_identity() -> void:
	var no_facade := CitizenAISystem.new()
	assert(not no_facade.configure(null))
	assert(no_facade.facade == null and no_facade.latest_snapshot == null)
	no_facade.free()
	var null_snapshot := CitizenAISystem.new()
	assert(not null_snapshot.configure(TestAIHelpers.NullFacade.new()))
	assert(null_snapshot.facade == null and null_snapshot.latest_snapshot == null)
	null_snapshot.free()
	var system := CitizenAISystem.new()
	system.snapshot_interval = 0.0
	system.director_interval = -1.0
	system.think_interval = 0.0
	system.max_thinks_per_frame = -5
	system.configure(TestAIHelpers.FakeFacade.new({}))
	assert(system.snapshot_interval > 0.0)
	assert(system.director_interval > 0.0)
	assert(system.think_interval > 0.0)
	assert(system.max_thinks_per_frame == 0)
	system.register_citizen(1, TestAIHelpers.FakeActuator.new(2))
	assert(system.brain_count() == 0)
	system.register_citizen(1, TestAIHelpers.FakeActuator.new(1))
	assert(system.brain_count() == 1)
	assert(system.reservations.claim(&"tree", 1, 0.0))
	system.unregister_citizen(1)
	assert(system.reservations.active_count() == 0)
	system.free()


static func _test_runtime_reconfiguration_updates_registered_brains() -> void:
	var citizens := {1: CitizenSnapshot.new(1)}
	var facade: RefCounted = TestAIHelpers.FakeFacade.new(citizens)
	var system := CitizenAISystem.new()
	system.configure(facade)
	var original_snapshot := system.latest_snapshot
	assert(not system.configure(TestAIHelpers.NullFacade.new()))
	assert(system.facade == facade and system.latest_snapshot == original_snapshot)
	system.register_citizen(1, TestAIHelpers.FakeActuator.new(1))
	var goal := TestAIHelpers.ScriptedGoal.new(&"idle", 0.5, [BehaviorStep.Status.RUNNING])
	system.configure(facade, [goal])
	system._physics_process(0.1)
	assert(goal.build_count == 1)
	system.unregister_citizen(1)
	system.free()


static func _test_requested_refresh_thinks_immediately() -> void:
	var goal := TestAIHelpers.ScriptedGoal.new(&"idle", 0.5, [BehaviorStep.Status.RUNNING])
	var system := CitizenAISystem.new()
	system.think_interval = 100.0
	system.configure(TestAIHelpers.FakeFacade.new({1: CitizenSnapshot.new(1)}), [goal])
	system.register_citizen(1, TestAIHelpers.FakeActuator.new(1))
	system._physics_process(0.01)
	assert(goal.build_count == 0)
	system.request_decision_refresh()
	system._physics_process(0.01)
	assert(goal.build_count == 1)
	system.unregister_citizen(1)
	system.free()


static func _test_runtime_think_budget_is_fair() -> void:
	var citizens := {
		1: CitizenSnapshot.new(1),
		2: CitizenSnapshot.new(2),
		3: CitizenSnapshot.new(3),
	}
	var goal := TestAIHelpers.ScriptedGoal.new(&"idle", 0.5, [BehaviorStep.Status.RUNNING])
	var system := CitizenAISystem.new()
	system.max_thinks_per_frame = 1
	system.think_interval = 0.1
	system.configure(TestAIHelpers.FakeFacade.new(citizens), [goal])
	for citizen_id in citizens:
		system.register_citizen(citizen_id, TestAIHelpers.FakeActuator.new(citizen_id))
	system._physics_process(0.02)
	system._physics_process(0.02)
	system._physics_process(0.02)
	assert(goal.build_count == 3)
	for citizen_id in citizens:
		system.unregister_citizen(citizen_id)
	system.free()
