extends SceneTree

const SleepGoalScript = preload("res://game/features/decision/domain/goals/sleep_goal.gd")
const MealGoalScript = preload("res://game/features/decision/domain/goals/meal_goal.gd")
const ToiletGoalScript = preload("res://game/features/decision/domain/goals/toilet_goal.gd")
const RestGoalScript = preload("res://game/features/decision/domain/goals/rest_goal.gd")
const ForestryGoalScript = preload("res://game/features/decision/domain/goals/forestry_goal.gd")
const ForestryOrderProviderScript = preload("res://game/features/decision/application/forestry_order_provider.gd")
const ForestryWorkStepScript = preload("res://game/features/decision/domain/behavior/forestry_work_step.gd")
const FarmingGoalScript = preload("res://game/features/decision/domain/goals/farming_goal.gd")
const FarmingOrderProviderScript = preload("res://game/features/decision/application/farming_order_provider.gd")
const ConstructionGoalScript = preload("res://game/features/decision/domain/goals/construction_goal.gd")
const ConstructionOrderProviderScript = preload("res://game/features/decision/application/construction_order_provider.gd")
const GatheringGoalScript = preload("res://game/features/decision/domain/goals/gathering_goal.gd")
const GatheringOrderProviderScript = preload("res://game/features/decision/application/gathering_order_provider.gd")
const CleaningGoalScript = preload("res://game/features/decision/domain/goals/cleaning_goal.gd")
const ExcavationGoalScript = preload("res://game/features/decision/domain/goals/excavation_goal.gd")
const ExcavationOrderProviderScript = preload("res://game/features/decision/application/excavation_order_provider.gd")
const ServiceWorkGoalScript = preload("res://game/features/decision/domain/goals/service_work_goal.gd")
const ServiceWorkOrderProviderScript = preload("res://game/features/decision/application/service_work_order_provider.gd")
const FactoryWorkGoalScript = preload("res://game/features/decision/domain/goals/factory_work_goal.gd")
const FactoryWorkOrderProviderScript = preload("res://game/features/decision/application/factory_work_order_provider.gd")
const CourierDeliveryGoalScript = preload("res://game/features/decision/domain/goals/courier_delivery_goal.gd")
const CourierDeliveryOrderProviderScript = preload("res://game/features/decision/application/courier_delivery_order_provider.gd")
const SettlementCitizenActuatorScript = preload("res://game/features/decision/application/settlement_citizen_actuator.gd")
const WorkforceOrderProviderScript = preload("res://game/features/decision/application/workforce_order_provider.gd")
const DailyPlayerOrderProviderScript = preload("res://game/features/decision/application/daily_player_order_provider.gd")


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
		_target_key: StringName = &"",
		_payload: AIFactSet = null
	) -> bool:
		action_start_count += 1
		return action in [&"sleep", &"eat", &"relieve", &"rest", &"register", &"forestry", &"farming", &"construction", &"demolition", &"gathering", &"cleaning", &"excavation", &"cook", &"teacher", &"seller", &"official", &"craftsman", &"factory_work", &"courier_delivery"]

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


class FakeSettlement extends RefCounted:
	func construction_gloves_available() -> bool:
		return false


class FakeGatheringSimulation extends Node:
	var settlement := FakeSettlement.new()
	var grass_sources: Dictionary = {}
	var consumed_count := 0

	func fire_smoke_work_multiplier(_position_on_board: Vector3) -> float:
		return 1.0

	func _cell_from_position(position: Vector3) -> Vector2i:
		return Vector2i(floori(position.x), floori(position.z))

	func _consume_grass_source(position: Vector3) -> int:
		var cell := _cell_from_position(position)
		if not grass_sources.has(cell):
			return 0
		var source: Dictionary = grass_sources[cell]
		if int(source.get("remaining", 0)) <= 0:
			return 0
		consumed_count += 1
		source.remaining = int(source.remaining) - 1
		if int(source.remaining) == 0:
			grass_sources.erase(cell)
		else:
			grass_sources[cell] = source
		return 1


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
	_test_citizen_brain_interrupts_active_work_immediately()
	_test_citizen_brain_failure_cooldown()
	_test_citizen_brain_cancels_when_winning_goal_has_no_task()
	_test_native_sleep_goal()
	_test_native_meal_goal()
	_test_native_toilet_goal()
	_test_native_rest_goal()
	_test_register_provider_keeps_order_while_registering()
	_test_register_provider_distributes_workplaces_by_capacity()
	_test_daily_player_order_provider_keeps_gathering_assignment()
	_test_daily_player_order_provider_publishes_construction_order()
	_test_daily_player_order_provider_publishes_cleaning_order()
	_test_native_cleaning_goal()
	_test_runner_cancels_stale_active_order_and_releases_reservation()
	_test_reserved_step_renews_lease()
	_test_forestry_provider_assigns_unique_stable_targets()
	_test_native_forestry_goal()
	_test_farming_provider_keeps_active_cycle()
	_test_native_farming_goal()
	_test_farming_actuator_completes_after_courier_pickup()
	_test_construction_provider_keeps_active_cycle()
	_test_native_construction_goal()
	_test_construction_actuator()
	_test_gathering_provider_assigns_unique_stable_sources()
	_test_gathering_provider_prefers_access_position()
	_test_native_gathering_goal()
	_test_excavation_provider_assigns_unique_stable_sites()
	_test_native_excavation_goal()
	_test_excavation_actuator_completes_after_courier_pickup()
	_test_service_provider_keeps_active_workplace()
	_test_native_service_goal()
	_test_service_actuator()
	_test_factory_provider_keeps_active_station()
	_test_native_factory_goal()
	_test_factory_actuator()
	_test_courier_provider_assigns_unique_tasks()
	_test_courier_provider_uses_shared_snapshot_tasks()
	_test_courier_provider_keeps_active_task_order()
	_test_courier_provider_more_couriers_than_tasks()
	_test_courier_provider_equal_couriers_and_tasks()
	_test_courier_provider_fewer_couriers_than_tasks()
	_test_courier_provider_active_courier_excluded_from_new_tasks()
	_test_courier_provider_same_site_different_resources()
	_test_courier_provider_two_couriers_same_task_not_duplicated()
	_test_courier_dispatcher_start_task_prevents_double_assignment()
	_test_courier_dispatcher_complete_for_clears_task()
	_test_courier_dispatcher_cleanup_removes_invalid_tasks()
	_test_courier_dispatcher_cleanup_unassigns_dead_courier()
	_test_courier_dispatcher_publish_does_not_duplicate()
	_test_native_courier_goal()
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
	var runner := BehaviorRunner.new()
	var work_task := BehaviorTask.new(&"work", work_step)
	work_task.guard = func(_ctx: BehaviorContext) -> bool: return false
	assert(runner.start(work_task, context))
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(runner.active_task == null and runner.suspended_count() == 0)
	assert(work_step.ticks == 0)


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


func _test_citizen_brain_interrupts_active_work_immediately() -> void:
	var work := ScriptedGoal.new(&"work", 0.90, [
		BehaviorStep.Status.RUNNING,
		BehaviorStep.Status.SUCCESS,
	])
	var urgent := ScriptedGoal.new(&"urgent", 0.40, [BehaviorStep.Status.RUNNING])
	work.resumable = false
	var brain := CitizenBrain.new(1, FakeActuator.new(1), [work, urgent])
	var snapshot := _snapshot(0.0, CitizenSnapshot.new(1))
	brain.think(snapshot, null)
	brain.tick(snapshot, null, 0.1)
	assert(brain.runner.active_goal_id() == &"work")
	assert(work.last_step.ticks == 1)
	work.utility = 0.50
	urgent.utility = 0.95
	brain.think(snapshot, null)
	assert(brain.runner.active_goal_id() == &"urgent")
	assert(work.last_step.cancels == 1)
	assert(urgent.build_count == 1 and urgent.last_step.ticks == 0)
	assert(urgent.last_step.ticks == 0)
	brain.tick(snapshot, null, 0.1)
	assert(urgent.last_step.ticks == 1)


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
	assert(work.last_step.cancels == 0 and brain.runner.active_goal_id() == &"work")
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


func _test_native_meal_goal() -> void:
	var goal := MealGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var meal_snapshot := _meal_snapshot(true)
	brain.think(meal_snapshot, null)
	brain.tick(meal_snapshot, null, 0.1)
	assert(actuator.action_start_count == 1)
	assert(brain.runner.active_goal_id() == &"meal")
	var completed_snapshot := _meal_snapshot(false)
	brain.tick(completed_snapshot, null, 0.1)
	assert(actuator.cancel_action_count == 1)
	assert(brain.runner.active_task == null)
	var blocked := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.meal_requested": true,
		&"needs.can_start_meal": false,
		&"needs.canteen_position": Vector3.ZERO,
	}))
	assert(is_zero_approx(goal.score(_snapshot(0.0, blocked), blocked, null, AIBlackboard.new())))


func _test_native_toilet_goal() -> void:
	var goal := ToiletGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var requested := _toilet_snapshot(true)
	brain.think(requested, null)
	brain.tick(requested, null, 0.1)
	assert(actuator.action_start_count == 1)
	assert(brain.runner.active_goal_id() == &"toilet")
	assert(requested.reservations.owner_of([&"needs.relief", &"tree:0:0:0"], 0.0) == 1)
	var completed := _toilet_snapshot(false)
	completed.reservations = requested.reservations
	brain.tick(completed, null, 0.1)
	assert(actuator.cancel_action_count == 1)
	assert(brain.runner.active_task == null)
	assert(completed.reservations.owner_of([&"needs.relief", &"tree:0:0:0"], 0.0) == 0)
	var blocked := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.toilet_requested": true,
		&"needs.can_start_toilet": false,
		&"needs.relief_candidates": [{&"id": &"tree:0:0:0", &"position": Vector3.ZERO, &"kind": &"tree"}],
	}))
	assert(is_zero_approx(goal.score(_snapshot(0.0, blocked), blocked, null, AIBlackboard.new())))


func _test_native_rest_goal() -> void:
	var goal := RestGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var requested := _rest_snapshot(true)
	brain.think(requested, null)
	brain.tick(requested, null, 0.1)
	assert(actuator.action_start_count == 1)
	assert(brain.runner.active_goal_id() == &"rest")
	var completed := _rest_snapshot(false)
	brain.tick(completed, null, 0.1)
	assert(actuator.cancel_action_count == 1)
	assert(brain.runner.active_task == null)


func _test_forestry_provider_assigns_unique_stable_targets() -> void:
	var provider := ForestryOrderProviderScript.new()
	var first := _forestry_citizen(1, false)
	var second := _forestry_citizen(2, false)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: first, 2: second})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 2)
	assert(orders[0].target_position != orders[1].target_position)
	var first_target := orders[0].target_position
	var second_target := orders[1].target_position
	var active_snapshot := WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {
		1: _forestry_citizen(1, true),
		2: _forestry_citizen(2, true),
	})
	var active_orders := provider.collect_orders(active_snapshot)
	assert(active_orders.size() == 2)
	assert(active_orders[0].target_position == first_target)
	assert(active_orders[1].target_position == second_target)
	var mixed_snapshot := WorldSnapshot.new(3, 2.0, 0.0, AIFactSet.new(), {
		1: _forestry_citizen(1, false),
		2: _forestry_citizen(2, true),
	})
	var mixed_orders := provider.collect_orders(mixed_snapshot)
	assert(mixed_orders.size() == 2)
	assert(mixed_orders[0].target_position != mixed_orders[1].target_position)


func _test_native_forestry_goal() -> void:
	var goal := ForestryGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := _forestry_citizen(1, false)
	var snapshot := _snapshot(0.0, citizen)
	var order := _forestry_order(1, Vector3(3.0, 0.0, 0.0), &"tree:3:0")
	order.id = 17
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.action_start_count == 1)
	assert(brain.runner.active_goal_id() == &"forestry")
	assert(snapshot.reservations.owner_of([&"forestry.tree", &"tree:3:0"], 0.0) == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)
	assert(snapshot.reservations.owner_of([&"forestry.tree", &"tree:3:0"], 0.0) == 0)


func _test_farming_provider_keeps_active_cycle() -> void:
	var provider := FarmingOrderProviderScript.new()
	var ready := _farming_citizen(1, false, true)
	var inactive := _farming_citizen(2, false, false)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: ready, 2: inactive})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	assert(orders[0].citizen_id == 1 and orders[0].kind == &"farming")
	var active := _farming_citizen(1, true, false)
	var active_orders := provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: active}))
	assert(active_orders.size() == 1)
	assert(active_orders[0].target_position == orders[0].target_position)


func _test_native_farming_goal() -> void:
	var goal := FarmingGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := _farming_citizen(1, false, true)
	var snapshot := _snapshot(0.0, citizen)
	var order := _farming_order(1, Vector3(4.0, 0.0, 0.0))
	order.id = 18
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.action_start_count == 1)
	assert(brain.runner.active_goal_id() == &"farming")
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)


func _test_farming_actuator_completes_after_courier_pickup() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 18
	citizen.permanent_role = "farming"
	var actuator := SettlementCitizenActuatorScript.new(citizen)
	assert(actuator.begin_action(&"farming", &"", AIFactSet.new({
		&"workplace.position": Vector3.ZERO,
		&"warehouse.position": Vector3(2.0, 0.0, 0.0),
	})))
	assert(citizen.state == Citizen.State.TO_TREE)
	citizen.state = Citizen.State.WAITING_COURIER
	citizen.register_pending_resource("food", 1)
	citizen.task_timer.start(0.0)
	citizen._process_courier_wait(0.1)
	assert(citizen.state == Citizen.State.WAITING_COURIER)
	assert(citizen.take_pending_resource()["amount"] == 1)
	assert(citizen.state == Citizen.State.IDLE)
	assert(citizen.active_role.is_empty())
	assert(actuator.action_status() == CitizenActuator.ActionStatus.SUCCEEDED)
	citizen.free()


func _test_construction_provider_keeps_active_cycle() -> void:
	var provider := ConstructionOrderProviderScript.new()
	var ready := _construction_citizen(1, false, true, &"construction", 41)
	var inactive := _construction_citizen(2, false, false, &"construction", 42)
	var orders := provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: ready, 2: inactive}))
	assert(orders.size() == 1)
	assert(orders[0].kind == &"construction" and orders[0].target_key == &"construction:41")
	var active := _construction_citizen(1, true, false, &"demolition", 43)
	var active_orders := provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: active}))
	assert(active_orders.size() == 1)
	assert(active_orders[0].kind == &"demolition" and active_orders[0].target_key == &"demolition:43")


func _test_native_construction_goal() -> void:
	var goal := ConstructionGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := _construction_citizen(1, false, true, &"construction", 41)
	var snapshot := _snapshot(0.0, citizen)
	var order := _construction_order(1, &"construction", 41)
	order.id = 19
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.action_start_count == 1)
	assert(brain.runner.active_goal_id() == &"construction")
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)


func _test_construction_actuator() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 19
	var target := Node3D.new()
	root.add_child(citizen)
	root.add_child(target)
	var actuator := SettlementCitizenActuatorScript.new(citizen, func(_key: StringName) -> Node3D: return target)
	assert(actuator.begin_action(&"construction", &"construction:5"))
	assert(citizen.state == Citizen.State.CONSTRUCTING and citizen.active_role == "construction")
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	assert(actuator.begin_action(&"demolition", &"demolition:5"))
	assert(citizen.state == Citizen.State.CONSTRUCTING and citizen.active_role == "demolition")
	root.remove_child(target)
	root.remove_child(citizen)
	target.free()
	citizen.free()


func _test_gathering_provider_assigns_unique_stable_sources() -> void:
	var provider := GatheringOrderProviderScript.new()
	var first := _gathering_citizen(1, false)
	var second := _gathering_citizen(2, false)
	var orders := provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: first, 2: second}))
	assert(orders.size() == 2)
	assert(orders[0].target_position != orders[1].target_position)
	var active_orders := provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {
		1: _gathering_citizen(1, true),
		2: _gathering_citizen(2, true),
	}))
	assert(active_orders.size() == 2)
	assert(active_orders[0].target_position == orders[0].target_position)
	assert(active_orders[1].target_position == orders[1].target_position)


func _test_native_gathering_goal() -> void:
	var goal := GatheringGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := _gathering_citizen(1, false)
	var snapshot := _snapshot(0.0, citizen)
	var order := _gathering_order(1, Vector3(3.0, 0.0, 0.0), &"branch:3:0")
	order.id = 20
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.action_start_count == 1)
	assert(snapshot.reservations.owner_of([&"gathering.source", &"branch:3:0"], 0.0) == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(snapshot.reservations.owner_of([&"gathering.source", &"branch:3:0"], 0.0) == 0)


func _test_gathering_provider_prefers_access_position() -> void:
	var provider := GatheringOrderProviderScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"work.gathering.worker": true,
		&"work.gathering.in_progress": false,
		&"work.gathering.role": &"gather_branches",
		&"work.gathering.warehouse_position": Vector3(8.0, 0.0, 0.0),
		&"work.gathering.candidates": [
			{&"id": &"branch:10:0", &"resource_type": "branches", &"position": Vector3(10.0, 0.0, 0.0), &"access": Vector3(9.5, 0.0, 0.0)},
			{&"id": &"branch:2:0", &"resource_type": "branches", &"position": Vector3(2.0, 0.0, 0.0), &"access": Vector3(50.0, 0.0, 0.0)},
		],
	}))
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.gathering.targets": []}), {1: citizen})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	assert(orders[0].payload.value(&"work.source_id", &"") == &"branch:10:0")


func _test_excavation_provider_assigns_unique_stable_sites() -> void:
	var provider := ExcavationOrderProviderScript.new()
	var first := _excavation_citizen(1, false)
	var second := _excavation_citizen(2, false)
	var orders := provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: first, 2: second}))
	assert(orders.size() == 2)
	assert(orders[0].target_key != orders[1].target_key)
	var active_orders := provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {
		1: _excavation_citizen(1, true),
		2: _excavation_citizen(2, true),
	}))
	assert(active_orders.size() == 2)
	assert(active_orders[0].target_key == orders[0].target_key)
	assert(active_orders[1].target_key == orders[1].target_key)


func _test_native_excavation_goal() -> void:
	var goal := ExcavationGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := _excavation_citizen(1, false)
	var snapshot := _snapshot(0.0, citizen)
	var order := _excavation_order(1, 61, &"dig:61")
	order.id = 21
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.action_start_count == 1)
	assert(snapshot.reservations.owner_of([&"excavation.site", &"dig:61"], 0.0) == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(snapshot.reservations.owner_of([&"excavation.site", &"dig:61"], 0.0) == 0)


func _test_excavation_actuator_completes_after_courier_pickup() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 21
	citizen.permanent_role = "excavation"
	var target := Node3D.new()
	root.add_child(citizen)
	root.add_child(target)
	var actuator := SettlementCitizenActuatorScript.new(citizen, func(_key: StringName) -> Node3D: return target)
	assert(actuator.begin_action(&"excavation", &"dig:3:0"))
	citizen.state = Citizen.State.WAITING_COURIER
	citizen.register_pending_resource("soil", 1)
	citizen.task_timer.start(0.0)
	citizen._process_courier_wait(0.1)
	assert(citizen.state == Citizen.State.WAITING_COURIER)
	assert(citizen.take_pending_resource()["amount"] == 1)
	assert(citizen.state == Citizen.State.IDLE and citizen.active_role.is_empty())
	assert(citizen.assigned_dig_site == null)
	assert(actuator.action_status() == CitizenActuator.ActionStatus.SUCCEEDED)
	root.remove_child(target)
	root.remove_child(citizen)
	target.free()
	citizen.free()


func _test_service_provider_keeps_active_workplace() -> void:
	var provider := ServiceWorkOrderProviderScript.new()
	var ready := _service_citizen(1, false, true, &"cook")
	var inactive := _service_citizen(2, false, false, &"teacher")
	var orders := provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: ready, 2: inactive}))
	assert(orders.size() == 1)
	assert(orders[0].kind == &"service_work")
	assert(orders[0].payload.value(&"work.service.role") == &"cook")
	var active := _service_citizen(1, true, false, &"cook")
	var active_orders := provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: active}))
	assert(active_orders.size() == 1)
	assert(active_orders[0].target_position == Vector3(5.0, 0.0, 0.0))


func _test_native_service_goal() -> void:
	var goal := ServiceWorkGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := _service_citizen(1, false, true, &"cook")
	var snapshot := _snapshot(0.0, citizen)
	var order := _service_order(1, &"cook")
	order.id = 22
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.action_start_count == 1)
	assert(brain.runner.active_goal_id() == &"service_work")
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)


func _test_service_actuator() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 22
	root.add_child(citizen)
	var actuator := SettlementCitizenActuatorScript.new(citizen)
	assert(actuator.begin_action(&"cook", &"", AIFactSet.new({&"workplace.position": Vector3.ZERO})))
	assert(citizen.state == Citizen.State.TO_CANTEEN_WORK)
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	root.remove_child(citizen)
	citizen.free()


func _test_factory_provider_keeps_active_station() -> void:
	var provider := FactoryWorkOrderProviderScript.new()
	var ready := _factory_citizen(1, false, true, &"factory_work")
	var inactive := _factory_citizen(2, false, false, &"engineering")
	var orders := provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: ready, 2: inactive}))
	assert(orders.size() == 1)
	assert(orders[0].kind == &"factory_work" and orders[0].target_key == &"factory:7")
	var active := _factory_citizen(1, true, false, &"factory_work")
	var active_orders := provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: active}))
	assert(active_orders.size() == 1)
	assert(active_orders[0].payload.value(&"factory.role") == &"factory_work")


func _test_native_factory_goal() -> void:
	var goal := FactoryWorkGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := _factory_citizen(1, false, true, &"engineering")
	var snapshot := _snapshot(0.0, citizen)
	var order := _factory_order(1, &"engineering")
	order.id = 23
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.action_start_count == 1)
	assert(brain.runner.active_goal_id() == &"factory_work")
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)


func _test_factory_actuator() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 23
	var factory := Node3D.new()
	factory.set_meta("service_position", Vector3.ZERO)
	root.add_child(citizen)
	root.add_child(factory)
	var actuator := SettlementCitizenActuatorScript.new(citizen, func(_key: StringName) -> Node3D: return factory)
	assert(actuator.begin_action(&"factory_work", &"factory:7", AIFactSet.new({&"factory.role": &"engineering"})))
	assert(citizen.state == Citizen.State.TO_FACTORY and citizen.active_role == "engineering")
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	root.remove_child(factory)
	root.remove_child(citizen)
	factory.free()
	citizen.free()


func _test_courier_provider_assigns_unique_tasks() -> void:
	var provider := CourierDeliveryOrderProviderScript.new()
	var first := _courier_citizen(1)
	var second := _courier_citizen(2)
	var orders := provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: first, 2: second}))
	assert(orders.size() == 2)
	assert(orders[0].payload.value(&"courier.task_id") != orders[1].payload.value(&"courier.task_id"))


func _test_courier_provider_uses_shared_snapshot_tasks() -> void:
	var provider := CourierDeliveryOrderProviderScript.new()
	var first := _courier_citizen(1)
	var second := _courier_citizen(2)
	var tasks := [
		{&"id": &"shared_first", &"priority": 100, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"shared_second", &"priority": 90, &"pickup": Vector3(2.0, 0.0, 0.0)},
	]
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: first, 2: second})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 2)
	assert(orders[0].payload.value(&"courier.task_id") == &"shared_first")
	assert(orders[1].payload.value(&"courier.task_id") == &"shared_second")


func _test_courier_provider_keeps_active_task_order() -> void:
	var provider := CourierDeliveryOrderProviderScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.courier.worker": true,
		&"work.courier.in_progress": true,
		&"work.courier.can_start": false,
		&"work.courier.active_task_id": &"construction_42_branches",
		&"work.courier.active_pickup": Vector3(3.0, 0.0, 4.0),
		&"work.courier.active_priority": 70,
	}))
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": []}), {1: citizen})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	assert(orders[0].citizen_id == 1)
	assert(orders[0].payload.value(&"courier.task_id") == &"construction_42_branches")
	assert(orders[0].target_position == Vector3(3.0, 0.0, 4.0))


func _test_courier_provider_more_couriers_than_tasks() -> void:
	var provider := CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"task_a", &"priority": 100, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"task_b", &"priority": 90, &"pickup": Vector3(2.0, 0.0, 0.0)},
	]
	var c1 := _courier_citizen_with_tasks(1, tasks)
	var c2 := _courier_citizen_with_tasks(2, tasks)
	var c3 := _courier_citizen_with_tasks(3, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: c1, 2: c2, 3: c3})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 2, "Expected 2 orders for 2 tasks with 3 couriers, got %d" % orders.size())
	var assigned_ids: Array[StringName] = []
	for order in orders:
		assigned_ids.append(order.payload.value(&"courier.task_id") as StringName)
	assert(assigned_ids.has(&"task_a"))
	assert(assigned_ids.has(&"task_b"))
	assert(not assigned_ids.has(&"task_a") or assigned_ids.count(&"task_a") == 1)
	assert(not assigned_ids.has(&"task_b") or assigned_ids.count(&"task_b") == 1)


func _test_courier_provider_equal_couriers_and_tasks() -> void:
	var provider := CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"task_a", &"priority": 100, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"task_b", &"priority": 90, &"pickup": Vector3(2.0, 0.0, 0.0)},
	]
	var c1 := _courier_citizen_with_tasks(1, tasks)
	var c2 := _courier_citizen_with_tasks(2, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: c1, 2: c2})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 2, "Expected 2 orders for 2 tasks with 2 couriers, got %d" % orders.size())
	var task_ids: Array[StringName] = []
	for order in orders:
		task_ids.append(order.payload.value(&"courier.task_id") as StringName)
	assert(task_ids.has(&"task_a"))
	assert(task_ids.has(&"task_b"))
	assert(task_ids.count(&"task_a") == 1)
	assert(task_ids.count(&"task_b") == 1)


func _test_courier_provider_fewer_couriers_than_tasks() -> void:
	var provider := CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"task_high", &"priority": 100, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"task_mid", &"priority": 70, &"pickup": Vector3(2.0, 0.0, 0.0)},
		{&"id": &"task_low", &"priority": 40, &"pickup": Vector3(3.0, 0.0, 0.0)},
	]
	var c1 := _courier_citizen_with_tasks(1, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: c1})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 1, "Expected 1 order for 1 courier with 3 tasks, got %d" % orders.size())
	assert(orders[0].payload.value(&"courier.task_id") == &"task_high", "Single courier should get highest-priority task")


func _test_courier_provider_active_courier_excluded_from_new_tasks() -> void:
	var provider := CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"task_a", &"priority": 100, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"task_b", &"priority": 90, &"pickup": Vector3(2.0, 0.0, 0.0)},
	]
	var active := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.courier.worker": true,
		&"work.courier.in_progress": true,
		&"work.courier.can_start": false,
		&"work.courier.active_task_id": &"construction_42_branches",
		&"work.courier.active_pickup": Vector3(5.0, 0.0, 0.0),
		&"work.courier.active_priority": 70,
	}))
	var idle := _courier_citizen_with_tasks(2, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: active, 2: idle})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 2, "Expected 2 orders (1 active + 1 idle), got %d" % orders.size())
	var active_orders := orders.filter(func(o: CitizenOrder) -> bool: return o.citizen_id == 1)
	var idle_orders := orders.filter(func(o: CitizenOrder) -> bool: return o.citizen_id == 2)
	assert(active_orders.size() == 1)
	assert(active_orders[0].payload.value(&"courier.task_id") == &"construction_42_branches")
	assert(idle_orders.size() == 1)
	assert(idle_orders[0].payload.value(&"courier.task_id") == &"task_a", "Idle courier should get highest available task")


func _test_courier_provider_same_site_different_resources() -> void:
	var provider := CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"construction_1_branches_storage", &"priority": 70, &"pickup": Vector3(1.0, 0.0, 0.0)},
		{&"id": &"construction_1_grass_storage", &"priority": 70, &"pickup": Vector3(1.0, 0.0, 0.0)},
	]
	var c1 := _courier_citizen_with_tasks(1, tasks)
	var c2 := _courier_citizen_with_tasks(2, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: c1, 2: c2})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 2, "Expected 2 orders for same site different resources, got %d" % orders.size())
	assert(orders[0].payload.value(&"courier.task_id") != orders[1].payload.value(&"courier.task_id"))


func _test_courier_provider_two_couriers_same_task_not_duplicated() -> void:
	var provider := CourierDeliveryOrderProviderScript.new()
	var tasks := [
		{&"id": &"construction_1_branches_storage", &"priority": 70, &"pickup": Vector3(1.0, 0.0, 0.0)},
	]
	var c1 := _courier_citizen_with_tasks(1, tasks)
	var c2 := _courier_citizen_with_tasks(2, tasks)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new({&"work.courier.tasks": tasks}), {1: c1, 2: c2})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 1, "Expected only 1 order for 1 task with 2 couriers, got %d" % orders.size())
	assert(orders[0].payload.value(&"courier.task_id") == &"construction_1_branches_storage")


func _test_courier_dispatcher_start_task_prevents_double_assignment() -> void:
	var sim := FakeCourierSimulation.new()
	root.add_child(sim)
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	var courier_a := Citizen.new()
	courier_a.ai_id = 1
	root.add_child(courier_a)
	var courier_b := Citizen.new()
	courier_b.ai_id = 2
	root.add_child(courier_b)
	assert(dispatcher.start_task(courier_a, &"task_1"), "First courier should start task")
	assert(not dispatcher.start_task(courier_b, &"task_1"), "Second courier must not start same task")
	var task := dispatcher.tasks[&"task_1"] as CourierTask
	assert(task.assigned_courier_id == courier_a.get_instance_id())
	root.remove_child(courier_a)
	root.remove_child(courier_b)
	courier_a.free()
	courier_b.free()
	root.remove_child(sim)
	sim.free()


func _test_courier_dispatcher_complete_for_clears_task() -> void:
	var sim := FakeCourierSimulation.new()
	root.add_child(sim)
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	var courier := Citizen.new()
	courier.ai_id = 1
	root.add_child(courier)
	assert(dispatcher.start_task(courier, &"task_1"))
	assert(dispatcher.tasks.has(&"task_1"))
	dispatcher.complete_for(courier)
	assert(not dispatcher.tasks.has(&"task_1"), "Task should be removed after complete_for")
	root.remove_child(courier)
	courier.free()
	root.remove_child(sim)
	sim.free()


func _test_courier_dispatcher_cleanup_removes_invalid_tasks() -> void:
	var sim := FakeCourierSimulation.new()
	sim.valid_result = false
	root.add_child(sim)
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"task_invalid", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	assert(dispatcher.tasks.has(&"task_invalid"))
	dispatcher.dispatch()
	assert(not dispatcher.tasks.has(&"task_invalid"), "Invalid task should be cleaned up by dispatch")
	root.remove_child(sim)
	sim.free()


func _test_courier_dispatcher_cleanup_unassigns_dead_courier() -> void:
	var sim := FakeCourierSimulation.new()
	root.add_child(sim)
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	var courier := Citizen.new()
	courier.ai_id = 1
	root.add_child(courier)
	assert(dispatcher.start_task(courier, &"task_1"))
	courier.state = Citizen.State.IDLE
	dispatcher.dispatch()
	var task := dispatcher.tasks.get(&"task_1") as CourierTask
	assert(task != null, "Valid task should still exist after cleanup")
	assert(task.assigned_courier_id == -1, "Task should be unassigned when courier has no active delivery")
	root.remove_child(courier)
	courier.free()
	root.remove_child(sim)
	sim.free()


func _test_courier_dispatcher_publish_does_not_duplicate() -> void:
	var sim := FakeCourierSimulation.new()
	root.add_child(sim)
	var dispatcher := CourierDispatcher.new()
	dispatcher.configure(sim)
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 50, Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	dispatcher.publish(&"task_1", CourierTask.Kind.SAWMILL_PICKUP, 99, Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), {})
	assert(dispatcher.tasks.size() == 1, "Duplicate publish should not create a second task")
	var task := dispatcher.tasks[&"task_1"] as CourierTask
	assert(task.priority == 50, "Original task priority should be preserved on duplicate publish")
	root.remove_child(sim)
	sim.free()


func _test_native_courier_goal() -> void:
	var goal := CourierDeliveryGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := _courier_citizen(1)
	var snapshot := _snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"courier_delivery", &"logistics.courier", 0.8, AIFactSet.new({&"courier.task_id": &"canteen_food"}))
	order.id = 24
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.action_start_count == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_task == null)


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
	assert(actuator.begin_action(&"eat", &"", AIFactSet.new({&"target.position": Vector3.ZERO})))
	assert(citizen.state == Citizen.State.TO_CANTEEN)
	citizen.state = Citizen.State.IDLE
	assert(actuator.action_status() == CitizenActuator.ActionStatus.SUCCEEDED)
	actuator.cancel_action()
	assert(actuator.begin_action(&"relieve", &"", AIFactSet.new({
		&"target.position": Vector3.ZERO,
		&"target.kind": &"tree",
	})))
	assert(citizen.state == Citizen.State.TO_BUSH)
	actuator.cancel_action()
	assert(citizen.state == Citizen.State.IDLE)
	assert(not citizen.has_toilet_resume_state)
	var queue_release_calls := [0]
	citizen.queue_release_notifier = func(_actor: Citizen) -> void: queue_release_calls[0] += 1
	citizen.state = Citizen.State.TO_TREE
	citizen.go_to_relief(Vector3.ONE, &"tree")
	citizen._resume_after_toilet()
	assert(citizen.state == Citizen.State.TO_TREE)
	assert(queue_release_calls[0] == 1)
	citizen.state = Citizen.State.TO_TREE
	citizen.go_to_relief(Vector3.ONE, &"tree")
	citizen.set_player_controlled(true)
	assert(citizen.state == Citizen.State.IDLE and not citizen.has_toilet_resume_state)
	citizen.set_player_controlled(false)
	assert(actuator.begin_action(&"rest", &"", AIFactSet.new({
		&"target.position": Vector3.ZERO,
		&"action.duration": 2.0,
	})))
	assert(citizen.state == Citizen.State.TO_PARK)
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
	system.think_interval = 0.1
	system.configure(FakeFacade.new(citizens), [goal])
	for citizen_id in citizens:
		system.register_citizen(citizen_id, FakeActuator.new(citizen_id))
	system._physics_process(0.02)
	system._physics_process(0.02)
	system._physics_process(0.02)
	assert(goal.build_count == 3)
	for citizen_id in citizens:
		system.unregister_citizen(citizen_id)
	system.free()


func _test_daily_player_order_provider_keeps_gathering_assignment() -> void:
	var provider := DailyPlayerOrderProviderScript.new()
	var source := {
		&"id": &"branch:4:0",
		&"resource_type": "branches",
		&"position": Vector3(4.0, 0.0, 0.0),
		&"access": Vector3(3.5, 0.0, 0.0),
	}
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"daily.order.active": true,
		&"daily.order.role": "gather_branches",
		&"daily.order.workday_id": 3,
		&"daily.order.expires_at": 42.0,
		&"daily.gathering.can_start": true,
		&"daily.gathering.in_progress": false,
		&"daily.gathering.candidates": [source],
		&"daily.gathering.warehouse_position": Vector3(8.0, 0.0, 0.0),
	}))
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: citizen})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	var order: CitizenOrder = orders[0]
	assert(order.kind == &"gathering")
	assert(order.issuer == &"player")
	assert(order.workday_id == 3)
	assert(is_equal_approx(order.expires_at, 42.0))
	assert(order.payload.value(&"work.source_id") == &"branch:4:0")
	assert(order.payload.value(&"resource.type") == "branches")
	assert(order.target_position == Vector3(4.0, 0.0, 0.0))

	var running := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"daily.order.active": true,
		&"daily.order.role": "gather_branches",
		&"daily.order.workday_id": 3,
		&"daily.order.expires_at": 42.0,
		&"daily.gathering.in_progress": true,
		&"daily.gathering.can_start": false,
	}))
	var continued := provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: running}))
	assert(continued.size() == 1)
	assert(continued[0].payload.to_dictionary() == order.payload.to_dictionary())

	var inactive := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"daily.order.active": false,
		&"daily.order.role": "gather_branches",
	}))
	assert(provider.collect_orders(WorldSnapshot.new(3, 2.0, 0.0, AIFactSet.new(), {1: inactive})).is_empty())


func _test_daily_player_order_provider_publishes_construction_order() -> void:
	var provider := DailyPlayerOrderProviderScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"daily.order.active": true,
		&"daily.order.role": "construction",
		&"daily.order.workday_id": 5,
		&"daily.order.expires_at": 99.0,
		&"daily.construction.can_start": true,
		&"daily.construction.mode": &"construction",
		&"daily.construction.target_key": &"construction:1:2",
		&"daily.construction.position": Vector3(1.0, 0.0, 2.0),
	}))
	var orders := provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: citizen}))
	assert(orders.size() == 1)
	assert(orders[0].kind == &"construction")
	assert(orders[0].issuer == &"player")
	assert(orders[0].workday_id == 5)
	assert(orders[0].target_key == &"construction:1:2")
	assert(orders[0].target_position == Vector3(1.0, 0.0, 2.0))


func _test_daily_player_order_provider_publishes_cleaning_order() -> void:
	var provider := DailyPlayerOrderProviderScript.new()
	var citizen := _cleaning_citizen(1, false)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: citizen})
	var orders := provider.collect_orders(snapshot)
	assert(orders.size() == 1)
	var order: CitizenOrder = orders[0]
	assert(order.kind == &"cleaning")
	assert(order.issuer == &"player")
	assert(order.workday_id == 3)
	assert(is_equal_approx(order.expires_at, 42.0))
	assert(order.payload.value(&"work.source_id") == &"pile:3:0:branches")
	assert(order.payload.value(&"resource.type") == "branches")
	assert(order.target_position == Vector3(3.0, 0.0, 0.0))

	var running := _cleaning_citizen(1, true)
	var continued := provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, AIFactSet.new(), {1: running}))
	assert(continued.size() == 1)
	assert(continued[0].payload.to_dictionary() == order.payload.to_dictionary())

	var inactive := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"daily.order.active": false,
		&"daily.order.role": "cleaning",
	}))
	assert(provider.collect_orders(WorldSnapshot.new(3, 2.0, 0.0, AIFactSet.new(), {1: inactive})).is_empty())


func _test_native_cleaning_goal() -> void:
	var goal := CleaningGoalScript.new()
	var actuator := FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := _cleaning_citizen(1, false)
	var snapshot := _snapshot(0.0, citizen)
	var order := _cleaning_order(1, Vector3(3.0, 0.0, 0.0), &"pile:3:0:branches")
	order.id = 30
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(actuator.action_start_count == 1)
	assert(snapshot.reservations.owner_of([&"cleaning.pile", &"pile:3:0:branches"], 0.0) == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	brain.tick(snapshot, order, 0.1)
	assert(snapshot.reservations.owner_of([&"cleaning.pile", &"pile:3:0:branches"], 0.0) == 0)


func _test_register_provider_keeps_order_while_registering() -> void:
	var provider := WorkforceOrderProviderScript.new()
	var settlement := AIFactSet.new({
		&"workforce.world_data": {"officer_available": true, "assigned_roles": {}, "forestry_jobs": 1, "warehouses": 1, "trees": 1},
		&"workforce.employment_center_position": Vector3(2.0, 0.0, 0.0),
		&"workforce.role_employers": {
			"forestry": {"position": Vector3(6.0, 0.0, 0.0), "target_key": &"building:6:0"},
		},
	})
	var unregistered := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"workforce.worker_data": {"workforce_status": "unregistered", "skills": {"forestry": 1.0}},
	}))
	var initial_orders := provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, settlement, {1: unregistered}))
	assert(initial_orders.size() == 1)
	assert(initial_orders[0].kind == &"register")
	assert(is_equal_approx(initial_orders[0].priority, 0.74))

	var registering := CitizenSnapshot.new(1, Vector3(1.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"workforce.worker_data": {"workforce_status": "registering", "pending_employment_role": "forestry"},
		&"workforce.pending_workplace_key": &"building:6:0",
		&"workforce.pending_workplace_position": Vector3(6.0, 0.0, 0.0),
	}))
	var continued_orders := provider.collect_orders(WorldSnapshot.new(2, 1.0, 0.0, settlement, {1: registering}))
	assert(continued_orders.size() == 1)
	assert(continued_orders[0].kind == &"register")
	assert(continued_orders[0].payload.value(&"workplace.role") == "forestry")
	assert(continued_orders[0].target_position == initial_orders[0].target_position)


func _test_register_provider_distributes_workplaces_by_capacity() -> void:
	var provider := WorkforceOrderProviderScript.new()
	var settlement := AIFactSet.new({
		&"workforce.world_data": {
			"officer_available": true, "assigned_roles": {}, "forestry_jobs": 2,
			"warehouses": 1, "trees": 2,
		},
		&"workforce.employment_center_position": Vector3(2.0, 0.0, 0.0),
		&"workforce.role_employers": {
			"forestry": [
				{"position": Vector3(6.0, 0.0, 0.0), "target_key": &"building:6:0", "available_slots": 1},
				{"position": Vector3(10.0, 0.0, 0.0), "target_key": &"building:10:0", "available_slots": 1},
			],
		},
	})
	var first := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"workforce.worker_data": {"workforce_status": "unregistered", "skills": {"forestry": 1.0}},
	}))
	var second := CitizenSnapshot.new(2, Vector3.ZERO, false, true, AIFactSet.new({
		&"workforce.worker_data": {"workforce_status": "unregistered", "skills": {"forestry": 1.0}},
	}))
	var orders := provider.collect_orders(WorldSnapshot.new(1, 0.0, 0.0, settlement, {1: first, 2: second}))
	assert(orders.size() == 2)
	assert(orders[0].payload.value(&"workplace.node_key") != orders[1].payload.value(&"workplace.node_key"))


func _test_runner_cancels_stale_active_order_and_releases_reservation() -> void:
	var command := AIFactSet.new({
		&"work.tree_id": &"tree:3:0",
		&"work.tree_access": Vector3(3.0, 0.0, 0.0),
		&"work.sawmill_position": Vector3(4.0, 0.0, 0.0),
		&"work.warehouse_position": Vector3(5.0, 0.0, 0.0),
	})
	var citizen := CitizenSnapshot.new(1)
	var snapshot := WorldSnapshot.new(1, 0.0, 0.0, AIFactSet.new(), {1: citizen})
	var order := CitizenOrder.new(1, &"forestry", &"forestry", 0.4, command)
	order.target_position = Vector3(3.0, 0.0, 0.0)
	order.id = 7
	var actuator := FakeActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(snapshot, order)
	var task := BehaviorTask.new(&"forestry", ForestryWorkStepScript.new(), false)
	task.order_id = order.id
	var runner := BehaviorRunner.new()
	runner.start(task, context)
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(snapshot.reservations.owner_of([&"forestry.tree", &"tree:3:0"], 0.0) == 1)
	context.refresh(snapshot, null)
	assert(runner.tick(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(actuator.cancel_action_count == 1)
	assert(snapshot.reservations.owner_of([&"forestry.tree", &"tree:3:0"], 0.0) == 0)


func _test_reserved_step_renews_lease() -> void:
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
	var actuator := FakeActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(snapshot, order)
	var step := ForestryWorkStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	snapshot.simulation_seconds = 89.0
	context.refresh(snapshot, order)
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(not ledger.claim([&"forestry.tree", &"tree:1"], 2, 120.0, 5.0))


func _context(order: CitizenOrder = null) -> BehaviorContext:
	var actuator := FakeActuator.new(1)
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


func _meal_snapshot(meal_requested: bool) -> WorldSnapshot:
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.meal_requested": meal_requested,
		&"needs.can_start_meal": true,
		&"needs.canteen_position": Vector3.ZERO,
	}))
	return _snapshot(0.0, citizen)


func _toilet_snapshot(toilet_requested: bool) -> WorldSnapshot:
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.toilet_requested": toilet_requested,
		&"needs.can_start_toilet": true,
		&"needs.relief_candidates": [{
			&"id": &"tree:0:0:0",
			&"position": Vector3.ZERO,
			&"kind": &"tree",
		}],
	}))
	return _snapshot(0.0, citizen)


func _rest_snapshot(rest_requested: bool) -> WorldSnapshot:
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.rest_requested": rest_requested,
		&"needs.can_start_rest": true,
		&"needs.rest_position": Vector3.ZERO,
		&"needs.rest_duration": 4.0,
	}))
	return _snapshot(0.0, citizen)


func _forestry_citizen(citizen_id: int, in_progress: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.forestry.worker": true,
		&"work.forestry.in_progress": in_progress,
		&"work.forestry.candidates": [
			{
				&"id": &"tree:3:0",
				&"position": Vector3(3.0, 0.0, 0.0),
				&"access": Vector3(2.5, 0.0, 0.0),
				&"sawmill_position": Vector3(6.0, 0.0, 0.0),
				&"warehouse_position": Vector3(8.0, 0.0, 0.0),
			},
			{
				&"id": &"tree:9:0",
				&"position": Vector3(9.0, 0.0, 0.0),
				&"access": Vector3(8.5, 0.0, 0.0),
				&"sawmill_position": Vector3(6.0, 0.0, 0.0),
				&"warehouse_position": Vector3(8.0, 0.0, 0.0),
			},
		],
	}))


func _forestry_order(citizen_id: int, tree_position: Vector3, tree_id: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"forestry", &"workforce.forestry", 0.55, AIFactSet.new({
		&"work.tree_id": tree_id,
		&"work.tree_access": tree_position + Vector3(-0.5, 0.0, 0.0),
		&"work.sawmill_position": Vector3(6.0, 0.0, 0.0),
		&"work.warehouse_position": Vector3(8.0, 0.0, 0.0),
	}))
	order.target_position = tree_position
	return order


func _farming_citizen(citizen_id: int, in_progress: bool, can_start: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.farming.worker": true,
		&"work.farming.in_progress": in_progress,
		&"work.farming.can_start": can_start,
		&"work.farming.position": Vector3(4.0, 0.0, 0.0),
		&"work.farming.warehouse_position": Vector3(8.0, 0.0, 0.0),
	}))


func _farming_order(citizen_id: int, farm_position: Vector3) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"farming", &"workforce.farming", 0.50, AIFactSet.new({
		&"work.farm_position": farm_position,
		&"work.warehouse_position": Vector3(8.0, 0.0, 0.0),
	}))
	order.target_position = farm_position
	return order


func _construction_citizen(citizen_id: int, in_progress: bool, can_start: bool, mode: StringName, target_id: int) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.construction.worker": true,
		&"work.construction.in_progress": in_progress,
		&"work.construction.can_start": can_start,
		&"work.construction.mode": mode,
		&"work.construction.target_key": StringName("%s:%d" % [mode, target_id]),
		&"work.construction.position": Vector3(5.0, 0.0, 0.0),
	}))


func _construction_order(citizen_id: int, mode: StringName, target_id: int) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, mode, &"workforce.construction", 0.60, AIFactSet.new({
		&"work.construction.mode": mode,
	}))
	order.target_key = StringName("%s:%d" % [mode, target_id])
	order.target_position = Vector3(5.0, 0.0, 0.0)
	return order


func _gathering_citizen(citizen_id: int, in_progress: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.gathering.worker": true,
		&"work.gathering.in_progress": in_progress,
		&"work.gathering.candidates": [
			{&"id": &"branch:3:0", &"resource_type": "branches", &"position": Vector3(3.0, 0.0, 0.0), &"access": Vector3(2.5, 0.0, 0.0), &"warehouse_position": Vector3(8.0, 0.0, 0.0)},
			{&"id": &"branch:9:0", &"resource_type": "branches", &"position": Vector3(9.0, 0.0, 0.0), &"access": Vector3(8.5, 0.0, 0.0), &"warehouse_position": Vector3(8.0, 0.0, 0.0)},
		],
	}))


func _gathering_order(citizen_id: int, source_position: Vector3, source_id: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"gathering", &"workforce.gathering", 0.50, AIFactSet.new({
		&"work.source_id": source_id,
		&"resource.type": "branches",
		&"target.access_position": source_position + Vector3(-0.5, 0.0, 0.0),
		&"warehouse.position": Vector3(8.0, 0.0, 0.0),
	}))
	order.target_position = source_position
	return order


func _cleaning_citizen(citizen_id: int, in_progress: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"daily.order.active": true,
		&"daily.order.role": "cleaning",
		&"daily.order.workday_id": 3,
		&"daily.order.expires_at": 42.0,
		&"daily.cleaning.in_progress": in_progress,
		&"daily.cleaning.can_start": true,
		&"daily.cleaning.candidates": [
			{&"id": &"pile:3:0:branches", &"pile_id": &"pile:3:0", &"resource_type": "branches", &"position": Vector3(3.0, 0.0, 0.0), &"access": Vector3(3.0, 0.0, 0.0)},
			{&"id": &"pile:9:0:branches", &"pile_id": &"pile:9:0", &"resource_type": "branches", &"position": Vector3(9.0, 0.0, 0.0), &"access": Vector3(9.0, 0.0, 0.0)},
		],
		&"daily.cleaning.warehouse_position": Vector3(8.0, 0.0, 0.0),
	}))


func _cleaning_order(citizen_id: int, source_position: Vector3, source_id: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"cleaning", &"player", 0.82, AIFactSet.new({
		&"work.source_id": source_id,
		&"resource.type": "branches",
		&"target.access_position": source_position,
		&"warehouse.position": Vector3(8.0, 0.0, 0.0),
		&"daily.role": "cleaning",
		&"daily.workday_id": 3,
	}))
	order.workday_id = 3
	order.expires_at = 42.0
	order.target_position = source_position
	return order


func _excavation_citizen(citizen_id: int, in_progress: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.excavation.worker": true,
		&"work.excavation.in_progress": in_progress,
		&"work.excavation.candidates": [
			{&"id": &"dig:61", &"target_key": &"dig:61", &"position": Vector3(3.0, 0.0, 0.0)},
			{&"id": &"dig:62", &"target_key": &"dig:62", &"position": Vector3(9.0, 0.0, 0.0)},
		],
	}))


func _excavation_order(citizen_id: int, target_id: int, site_id: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"excavation", &"workforce.excavation", 0.50, AIFactSet.new({&"work.site_id": site_id}))
	order.target_key = site_id
	order.target_position = Vector3(3.0, 0.0, 0.0)
	return order


func _service_citizen(citizen_id: int, in_progress: bool, can_start: bool, role: StringName) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.service.worker": true,
		&"work.service.in_progress": in_progress,
		&"work.service.can_start": can_start,
		&"work.service.role": role,
		&"work.service.position": Vector3(5.0, 0.0, 0.0),
	}))


func _service_order(citizen_id: int, role: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"service_work", &"workforce.service", 0.45, AIFactSet.new({
		&"work.service.role": role,
		&"workplace.position": Vector3(5.0, 0.0, 0.0),
	}))
	order.target_position = Vector3(5.0, 0.0, 0.0)
	return order


func _factory_citizen(citizen_id: int, in_progress: bool, can_start: bool, role: StringName) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.factory.worker": true,
		&"work.factory.in_progress": in_progress,
		&"work.factory.can_start": can_start,
		&"work.factory.role": role,
		&"work.factory.target_key": &"factory:7",
		&"work.factory.position": Vector3(7.0, 0.0, 0.0),
	}))


func _factory_order(citizen_id: int, role: StringName) -> CitizenOrder:
	var order := CitizenOrder.new(citizen_id, &"factory_work", &"workforce.factory", 0.46, AIFactSet.new({&"factory.role": role}))
	order.target_key = &"factory:7"
	order.target_position = Vector3(7.0, 0.0, 0.0)
	return order


func _courier_citizen(citizen_id: int) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.courier.worker": true,
		&"work.courier.can_start": true,
		&"work.courier.tasks": [
			{&"id": &"canteen_food", &"priority": 100, &"pickup": Vector3.ZERO},
			{&"id": &"worker:2", &"priority": 45, &"pickup": Vector3(4.0, 0.0, 0.0)},
		],
	}))


func _courier_citizen_with_tasks(citizen_id: int, tasks: Array) -> CitizenSnapshot:
	return CitizenSnapshot.new(citizen_id, Vector3(float(citizen_id), 0.0, 0.0), false, true, AIFactSet.new({
		&"work.courier.worker": true,
		&"work.courier.can_start": true,
		&"work.courier.tasks": tasks,
	}))


class FakeCourierSimulation extends Node:
	var citizens: Array[Citizen] = []
	var warehouse_positions: Array[Vector3] = [Vector3.ZERO]
	var runtime_seconds := 0.0
	var valid_result := true

	func _is_work_time() -> bool:
		return true

	func _publish_courier_tasks(_dispatcher: RefCounted) -> void:
		pass

	func _is_courier_task_valid(_task: RefCounted) -> bool:
		return valid_result

	func _start_courier_task(_courier: Citizen, _task: RefCounted) -> bool:
		return true
