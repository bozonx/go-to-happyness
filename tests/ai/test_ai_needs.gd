class_name TestAINeeds
extends RefCounted

const TestAIHelpers = preload("res://tests/ai/test_ai_helpers.gd")


static func run_all() -> void:
	_test_citizen_brain_cancels_for_player_control()
	_test_citizen_brain_interrupts_active_work_immediately()
	_test_citizen_brain_failure_cooldown()
	_test_citizen_brain_cancels_when_winning_goal_has_no_task()
	_test_native_sleep_goal()
	_test_overtime_without_order_allows_sleep()
	_test_permanent_worker_returns_home_without_live_work_order()
	_test_stale_permanent_work_order_switches_to_return_home()
	_test_native_meal_goal()
	_test_native_toilet_goal()
	_test_toilet_goal_blocked_while_working()
	_test_toilet_goal_blocked_for_player_controlled()
	_test_personal_need_preempts_work_trip()
	_test_personal_need_ignores_changed_work_order()
	_test_changed_work_order_cancels_captured_trip()
	_test_moved_target_rebuilds_captured_trip()
	_test_completed_order_waits_for_fresh_publication()
	_test_active_personal_need_blocks_work()
	_test_personal_need_blocks_other_personal_need()
	_test_native_rest_goal()
	_test_work_refusal_when_wellbeing_low()


static func _test_citizen_brain_cancels_for_player_control() -> void:
	var goal := TestAIHelpers.ScriptedGoal.new(&"work", 0.5, [BehaviorStep.Status.RUNNING])
	var brain := CitizenBrain.new(1, TestAIHelpers.FakeActuator.new(1), [goal])
	var active := TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(1, Vector3.ZERO, false, true))
	brain.think(active, null)
	brain.tick(active, null, 0.1)
	assert(goal.last_step.ticks == 1)
	var player_controlled := TestAIHelpers.snapshot(0.1, CitizenSnapshot.new(1, Vector3.ZERO, true, true))
	brain.tick(player_controlled, null, 0.1)
	assert(goal.last_step.cancels == 1)
	assert(brain.runner.active_task == null)
	var unavailable_goal := TestAIHelpers.ScriptedGoal.new(&"work", 0.5, [BehaviorStep.Status.RUNNING])
	var unavailable_brain := CitizenBrain.new(1, TestAIHelpers.FakeActuator.new(1), [unavailable_goal])
	unavailable_brain.think(active, null)
	unavailable_brain.tick(active, null, 0.1)
	var unavailable := TestAIHelpers.snapshot(0.1, CitizenSnapshot.new(1, Vector3.ZERO, false, false))
	unavailable_brain.tick(unavailable, null, 0.1)
	assert(unavailable_goal.last_step.cancels == 1)


static func _test_citizen_brain_interrupts_active_work_immediately() -> void:
	var work := TestAIHelpers.ScriptedGoal.new(&"work", 0.90, [
		BehaviorStep.Status.RUNNING,
		BehaviorStep.Status.SUCCESS,
	])
	var urgent := TestAIHelpers.ScriptedGoal.new(&"urgent", 0.40, [BehaviorStep.Status.RUNNING])
	work.resumable = false
	var brain := CitizenBrain.new(1, TestAIHelpers.FakeActuator.new(1), [work, urgent])
	var snapshot := TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(1))
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


static func _test_citizen_brain_failure_cooldown() -> void:
	var goal := TestAIHelpers.ScriptedGoal.new(&"work", 0.60, [BehaviorStep.Status.FAILURE])
	var brain := CitizenBrain.new(1, TestAIHelpers.FakeActuator.new(1), [goal])
	var fresh := TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(1))
	brain.think(fresh, null)
	brain.tick(fresh, null, 0.1)
	assert(goal.build_count == 1 and goal.last_step.finishes == 1)
	brain.think(fresh, null)
	assert(goal.build_count == 1 and brain.runner.active_task == null)
	var later := TestAIHelpers.snapshot(6.0, CitizenSnapshot.new(1))
	brain.think(later, null)
	assert(goal.build_count == 2)


static func _test_citizen_brain_cancels_when_winning_goal_has_no_task() -> void:
	var work := TestAIHelpers.ScriptedGoal.new(&"work", 0.5, [BehaviorStep.Status.RUNNING])
	var blocked := TestAIHelpers.NullTaskGoal.new(&"blocked", 0.8)
	var brain := CitizenBrain.new(1, TestAIHelpers.FakeActuator.new(1), [work, blocked])
	var snapshot := TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(1))
	work.utility = 0.9
	brain.think(snapshot, null)
	brain.tick(snapshot, null, 0.1)
	assert(work.last_step.ticks == 1)
	work.utility = 0.5
	brain.think(snapshot, null)
	assert(work.last_step.cancels == 0 and brain.runner.active_goal_id() == &"work")
	assert(brain.blackboard.is_on_cooldown(&"blocked", 0.0))


static func _test_native_sleep_goal() -> void:
	var goal: RefCounted = TestAIHelpers.SleepGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var sleep_snapshot := TestAIHelpers.sleep_snapshot(true)
	brain.think(sleep_snapshot, null)
	brain.tick(sleep_snapshot, null, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.move_to_destination == Vector3.ZERO)
	assert(actuator.action_start_count == 0)
	assert(brain.runner.active_goal_id() == &"sleep")
	actuator.arrived_flag = true
	brain.tick(sleep_snapshot, null, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	var morning_snapshot := TestAIHelpers.sleep_snapshot(false)
	brain.tick(morning_snapshot, null, 0.1)
	assert(actuator.cancel_action_count == 1)
	assert(brain.runner.active_task == null)
	var no_home := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.should_sleep": true,
		&"needs.has_home": false,
		&"needs.can_start_sleep": true,
	}))
	assert(is_zero_approx(goal.score(TestAIHelpers.snapshot(0.0, no_home), no_home, null, AIBlackboard.new())))


static func _test_overtime_without_order_allows_sleep() -> void:
	var goal: RefCounted = TestAIHelpers.SleepGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.should_sleep": false,
		&"needs.has_home": true,
		&"needs.home_position": Vector3.ZERO,
		&"needs.can_start_sleep": true,
		&"work.overtime.active": true,
	}))
	assert(is_equal_approx(goal.score(TestAIHelpers.snapshot(0.0, citizen), citizen, null, AIBlackboard.new()), 1.0))
	var order := CitizenOrder.new(1, &"gathering", &"test", 0.5)
	assert(is_zero_approx(goal.score(TestAIHelpers.snapshot(0.0, citizen), citizen, order, AIBlackboard.new())))


static func _test_permanent_worker_returns_home_without_live_work_order() -> void:
	var goal: RefCounted = TestAIHelpers.ReturnHomeWhenIdleGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.permanent.active": true,
		&"needs.has_home": true,
		&"needs.home_position": Vector3(4.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	brain.think(snapshot, null)
	brain.tick(snapshot, null, 0.1)
	assert(brain.runner.active_goal_id() == &"return_home_when_idle")
	assert(actuator.move_to_count == 1)
	assert(actuator.move_to_destination == Vector3(4.0, 0.0, 0.0))
	var active_order := CitizenOrder.new(1, &"construction", &"test", 0.6)
	assert(is_zero_approx(goal.score(snapshot, citizen, active_order, AIBlackboard.new())))
	var no_home := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.permanent.active": true,
		&"needs.has_home": false,
	}))
	assert(is_zero_approx(goal.score(TestAIHelpers.snapshot(0.0, no_home), no_home, null, AIBlackboard.new())))


static func _test_stale_permanent_work_order_switches_to_return_home() -> void:
	var return_home: RefCounted = TestAIHelpers.ReturnHomeWhenIdleGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [TestAIHelpers.ConstructionGoalScript.new(), return_home])
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.construction.worker": true,
		&"needs.has_home": true,
		&"needs.home_position": Vector3(4.0, 0.0, 0.0),
		&"work.permanent.active": true,
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var construction_order := TestAIHelpers.construction_order(1, &"construction", 41)
	construction_order.id = 19
	brain.think(snapshot, construction_order)
	brain.tick(snapshot, construction_order, 0.1)
	assert(brain.runner.active_goal_id() == &"construction")
	brain.think(snapshot, null)
	brain.tick(snapshot, null, 0.1)
	assert(brain.runner.active_goal_id() == &"return_home_when_idle")
	assert(actuator.move_to_destination == Vector3(4.0, 0.0, 0.0))


static func _test_native_meal_goal() -> void:
	var goal: RefCounted = TestAIHelpers.MealGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var meal_snapshot := TestAIHelpers.meal_snapshot(true)
	brain.think(meal_snapshot, null)
	brain.tick(meal_snapshot, null, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.move_to_destination == Vector3.ZERO)
	assert(actuator.action_start_count == 0)
	assert(brain.runner.active_goal_id() == &"meal")
	actuator.arrived_flag = true
	brain.tick(meal_snapshot, null, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	var completed_snapshot := TestAIHelpers.meal_snapshot(false)
	brain.tick(completed_snapshot, null, 0.1)
	assert(actuator.cancel_action_count == 1)
	assert(brain.runner.active_task == null)
	var blocked := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.meal_requested": true,
		&"needs.can_start_meal": false,
		&"needs.canteen_position": Vector3.ZERO,
	}))
	assert(is_zero_approx(goal.score(TestAIHelpers.snapshot(0.0, blocked), blocked, null, AIBlackboard.new())))


static func _test_native_toilet_goal() -> void:
	var goal: RefCounted = TestAIHelpers.ToiletGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var requested := TestAIHelpers.toilet_snapshot(true)
	brain.think(requested, null)
	brain.tick(requested, null, 0.1)
	assert(actuator.action_start_count == 1)
	assert(brain.runner.active_goal_id() == &"toilet")
	assert(requested.reservations.owner_of([&"needs.relief", &"tree:0:0:0"], 0.0) == 1)
	var completed := TestAIHelpers.toilet_snapshot(false)
	completed.reservations = requested.reservations
	brain.tick(completed, null, 0.1)
	assert(actuator.cancel_action_count == 1)
	assert(brain.runner.active_task == null)
	assert(completed.reservations.owner_of([&"needs.relief", &"tree:0:0:0"], 0.0) == 0)
	var blocked := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.toilet_requested": true,
		&"needs.can_start_toilet": false,
		&"needs.relief_candidates": [{
			&"id": &"tree:0:0:0",
			&"position": Vector3.ZERO,
			&"kind": &"tree",
		}],
	}))
	assert(is_zero_approx(goal.score(TestAIHelpers.snapshot(0.0, blocked), blocked, null, AIBlackboard.new())))


static func _test_toilet_goal_blocked_while_working() -> void:
	var goal: RefCounted = TestAIHelpers.ToiletGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.toilet_requested": true,
		&"needs.can_start_toilet": false,  # can_start_toilet=false because in_progress
		&"needs.relief_candidates": [{&"id": &"tree:0:0:0", &"position": Vector3.ZERO, &"kind": &"tree"}],
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_zero_approx(goal.score(snapshot, citizen, null, AIBlackboard.new())))


static func _test_toilet_goal_blocked_for_player_controlled() -> void:
	var goal: RefCounted = TestAIHelpers.ToiletGoalScript.new()
	# Player-controlled citizens have can_start_toilet=false
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, true, true, AIFactSet.new({
		&"needs.toilet_requested": true,
		&"needs.can_start_toilet": false,  # can_start_toilet=false for player-controlled
		&"needs.relief_candidates": [{&"id": &"tree:0:0:0", &"position": Vector3.ZERO, &"kind": &"tree"}],
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_zero_approx(goal.score(snapshot, citizen, null, AIBlackboard.new())))


static func _test_personal_need_preempts_work_trip() -> void:
	var forestry: RefCounted = TestAIHelpers.ForestryGoalScript.new()
	var meal: RefCounted = TestAIHelpers.MealGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [forestry, meal])
	var citizen := TestAIHelpers.forestry_citizen(1, false)
	var order := TestAIHelpers.forestry_order(1, Vector3(3.0, 0.0, 0.0), &"tree:3:0")
	order.id = 1001
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(brain.runner.active_goal_id() == &"forestry")
	assert(actuator.move_to_count == 1)
	assert(actuator.action_start_count == 0)
	var hungry_facts := citizen.facts.to_dictionary()
	hungry_facts[&"needs.meal_requested"] = true
	hungry_facts[&"needs.can_start_meal"] = true
	hungry_facts[&"needs.canteen_position"] = Vector3.ZERO
	var hungry_citizen := CitizenSnapshot.new(1, Vector3(1.0, 0.0, 0.0), false, true, AIFactSet.new(hungry_facts))
	var hungry_snapshot := TestAIHelpers.snapshot(1.0, hungry_citizen)
	brain.think(hungry_snapshot, order)
	assert(brain.runner.active_goal_id() == &"meal")
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 0)


static func _test_personal_need_ignores_changed_work_order() -> void:
	var meal: RefCounted = TestAIHelpers.MealGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [meal])
	var snapshot := TestAIHelpers.meal_snapshot(true)
	var original := CitizenOrder.new(1, &"forestry", &"workforce.forestry", 0.55)
	original.id = 1201
	brain.think(snapshot, original)
	assert(brain.runner.active_goal_id() == &"meal")
	assert(brain.runner.active_task.order == null)
	assert(brain.runner.active_task.order_id == 0)
	brain.tick(snapshot, null, 0.1)
	assert(brain.runner.active_goal_id() == &"meal")
	assert(not brain.blackboard.is_on_cooldown(&"meal", snapshot.simulation_seconds))


static func _test_changed_work_order_cancels_captured_trip() -> void:
	var forestry: RefCounted = TestAIHelpers.ForestryGoalScript.new()
	var meal: RefCounted = TestAIHelpers.MealGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [forestry, meal])
	var citizen := TestAIHelpers.forestry_citizen(1, false)
	var original := TestAIHelpers.forestry_order(1, Vector3(3.0, 0.0, 0.0), &"tree:3:0")
	original.id = 1101
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	brain.think(snapshot, original)
	brain.tick(snapshot, original, 0.1)
	var replacement := TestAIHelpers.forestry_order(1, Vector3(9.0, 0.0, 0.0), &"tree:9:0")
	replacement.id = 1102
	brain.think(snapshot, replacement)
	brain.tick(snapshot, replacement, 0.1)
	assert(brain.runner.active_goal_id() == &"forestry")
	assert(actuator.stop_count == 1)
	assert(actuator.move_to_destination == Vector3(8.5, 0.0, 0.0))
	assert(snapshot.reservations.owner_of([&"forestry.tree", &"tree:3:0"], 0.0) == 0)


static func _test_moved_target_rebuilds_captured_trip() -> void:
	var board := OrderBoard.new()
	var provider: RefCounted = TestAIHelpers.GatheringOrderProviderScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [TestAIHelpers.GatheringGoalScript.new()])
	var initial_citizen := TestAIHelpers.gathering_citizen_with_candidates(1, [
		{&"id": &"rabbit:2:0", &"resource_type": "food", &"position": Vector3(2.0, 0.0, 0.0), &"access": Vector3(2.0, 0.0, 0.0)},
	])
	var initial_snapshot := TestAIHelpers.snapshot(0.0, initial_citizen)
	board.replace_issuer_orders(provider.id, provider.collect_orders(initial_snapshot), 0.0)
	var initial_order := board.order_for(1, 0.0)
	brain.think(initial_snapshot, initial_order)
	brain.tick(initial_snapshot, initial_order, 0.1)
	assert(actuator.move_to_destination == Vector3(2.0, 0.0, 0.0))

	var moved_citizen := TestAIHelpers.gathering_citizen_with_candidates(1, [
		{&"id": &"rabbit:2:0", &"resource_type": "food", &"position": Vector3(5.0, 0.0, 0.0), &"access": Vector3(5.0, 0.0, 0.0)},
	])
	var moved_snapshot := TestAIHelpers.snapshot(1.0, moved_citizen)
	board.replace_issuer_orders(provider.id, provider.collect_orders(moved_snapshot), 1.0)
	var moved_order := board.order_for(1, 1.0)
	assert(moved_order.id != initial_order.id)
	brain.think(moved_snapshot, moved_order)
	brain.tick(moved_snapshot, moved_order, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.move_to_destination == Vector3(5.0, 0.0, 0.0))


static func _test_completed_order_waits_for_fresh_publication() -> void:
	var goal := TestAIHelpers.ScriptedGoal.new(&"work", 0.8, [BehaviorStep.Status.SUCCESS])
	var brain := CitizenBrain.new(1, TestAIHelpers.FakeActuator.new(1), [goal])
	var snapshot := TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(1))
	var order := CitizenOrder.new(1, &"work", &"test", 0.8)
	order.id = 41
	brain.think(snapshot, order)
	brain.tick(snapshot, order, 0.1)
	assert(goal.build_count == 1)

	brain.think(snapshot, order)
	assert(goal.build_count == 1)
	var republished := CitizenOrder.new(1, &"work", &"test", 0.8)
	republished.id = order.id
	brain.think(snapshot, republished)
	assert(goal.build_count == 2)


static func _test_active_personal_need_blocks_work() -> void:
	var work := TestAIHelpers.FixedGoal.new(&"work", 0.89)
	var meal: RefCounted = TestAIHelpers.MealGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [work, meal])
	var snapshot := TestAIHelpers.meal_snapshot(true)
	brain.think(snapshot, null)
	brain.tick(snapshot, null, 0.1)
	assert(brain.runner.active_goal_id() == &"meal")
	assert(actuator.move_to_count == 1)
	assert(actuator.action_start_count == 0)
	actuator.arrived_flag = true
	brain.tick(snapshot, null, 0.1)
	assert(actuator.action_start_count == 1)

	var still_eating := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.meal_requested": true,
		&"needs.can_start_meal": true,
		&"needs.canteen_position": Vector3.ZERO,
	}))
	var work_snapshot := TestAIHelpers.snapshot(1.0, still_eating)
	brain.think(work_snapshot, null)
	assert(brain.runner.active_goal_id() == &"meal")
	assert(actuator.cancel_action_count == 0)


static func _test_personal_need_blocks_other_personal_need() -> void:
	var meal: RefCounted = TestAIHelpers.MealGoalScript.new()
	var sleep: RefCounted = TestAIHelpers.SleepGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [meal, sleep])
	var meal_snapshot := TestAIHelpers.meal_snapshot(true)
	brain.think(meal_snapshot, null)
	brain.tick(meal_snapshot, null, 0.1)
	assert(brain.runner.active_goal_id() == &"meal")
	assert(actuator.move_to_count == 1)
	assert(actuator.action_start_count == 0)
	actuator.arrived_flag = true
	brain.tick(meal_snapshot, null, 0.1)
	assert(actuator.action_start_count == 1)

	var sleepy_facts := meal_snapshot.citizen(1).facts.to_dictionary()
	sleepy_facts[&"needs.should_sleep"] = true
	sleepy_facts[&"needs.has_home"] = true
	sleepy_facts[&"needs.can_start_sleep"] = true
	sleepy_facts[&"needs.home_position"] = Vector3.ZERO
	var sleepy_citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new(sleepy_facts))
	var sleep_snapshot := TestAIHelpers.snapshot(1.0, sleepy_citizen)
	brain.think(sleep_snapshot, null)
	assert(brain.runner.active_goal_id() == &"meal")
	assert(actuator.cancel_action_count == 0)


static func _test_native_rest_goal() -> void:
	var goal: RefCounted = TestAIHelpers.RestGoalScript.new()
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var brain := CitizenBrain.new(1, actuator, [goal])
	var requested := TestAIHelpers.rest_snapshot(true)
	brain.think(requested, null)
	brain.tick(requested, null, 0.1)
	assert(actuator.move_to_count == 1)
	assert(actuator.move_to_destination == Vector3.ZERO)
	assert(actuator.action_start_count == 0)
	assert(brain.runner.active_goal_id() == &"rest")
	actuator.arrived_flag = true
	brain.tick(requested, null, 0.1)
	assert(actuator.stop_count == 1)
	assert(actuator.action_start_count == 1)
	var completed := TestAIHelpers.rest_snapshot(false)
	brain.tick(completed, null, 0.1)
	assert(actuator.cancel_action_count == 1)
	assert(brain.runner.active_task == null)


static func _test_work_refusal_when_wellbeing_low() -> void:
	# Work goals must NOT refuse work at any wellbeing level. Speed penalties
	# are applied via efficiency, not via goal scoring. Only personal needs
	# (sleep, meal, toilet, rest) may preempt work.
	var forestry_goal: RefCounted = TestAIHelpers.ForestryGoalScript.new()
	var courier_goal: RefCounted = TestAIHelpers.CourierDeliveryGoalScript.new()

	var forestry_citizen := TestAIHelpers.forestry_citizen(1, false)
	var forestry_order := TestAIHelpers.forestry_order(1, Vector3(3.0, 0.0, 0.0), &"tree:3:0")

	var low_snapshot := TestAIHelpers.snapshot_with_wellbeing(25, forestry_citizen)
	assert(not is_zero_approx(forestry_goal.score(low_snapshot, forestry_citizen, forestry_order, AIBlackboard.new())), "Forestry must not refuse work at low wellbeing")

	var active_courier := CitizenSnapshot.new(2, Vector3.ZERO, false, true, AIFactSet.new({
		&"work.courier.worker": true,
		&"work.courier.in_progress": true,
	}))
	var delivery_order := CitizenOrder.new(2, &"courier_delivery", &"logistics.courier", 0.7)
	assert(is_equal_approx(courier_goal.score(TestAIHelpers.snapshot_with_wellbeing(25, active_courier), active_courier, delivery_order, AIBlackboard.new()), 1.0), "An in-progress delivery must finish even when wellbeing drops")

	var ok_snapshot := TestAIHelpers.snapshot_with_wellbeing(30, forestry_citizen)
	assert(not is_zero_approx(forestry_goal.score(ok_snapshot, forestry_citizen, forestry_order, AIBlackboard.new())))

	var high_snapshot := TestAIHelpers.snapshot_with_wellbeing(75, forestry_citizen)
	assert(not is_zero_approx(forestry_goal.score(high_snapshot, forestry_citizen, forestry_order, AIBlackboard.new())))
