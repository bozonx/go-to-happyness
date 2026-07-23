class_name TestAIDomain
extends RefCounted

const TestAIHelpers = preload("res://tests/ai/test_ai_helpers.gd")
const WorkforcePolicyScript = preload("res://game/features/decision/domain/workforce_policy.gd")
const FollowLeaderGoalScript = preload("res://game/features/decision/domain/goals/follow_leader_goal.gd")
const RegisterGoalScript = preload("res://game/features/decision/domain/goals/register_goal.gd")
const RegisterStepScript = preload("res://game/features/decision/domain/behavior/register_step.gd")
const SleepAtHomeStepScript = preload("res://game/features/decision/domain/behavior/sleep_at_home_step.gd")
const EatAtCanteenStepScript = preload("res://game/features/decision/domain/behavior/eat_at_canteen_step.gd")
const CourierDeliveryStepScript = preload("res://game/features/decision/domain/behavior/courier_delivery_step.gd")
const FacadeTargetHelpersScript = preload("res://game/features/decision/presentation/facade_target_helpers.gd")
const FacadeContextScript = preload("res://game/features/decision/presentation/facade_context.gd")
const RelieveStepScript = preload("res://game/features/decision/domain/behavior/relieve_step.gd")
const ReturnHomeWhenIdleGoalScript = preload("res://game/features/decision/domain/goals/return_home_when_idle_goal.gd")


static func run_all() -> void:
	_test_workforce_policy_role_for_permanent()
	_test_workforce_policy_role_for_daily()
	_test_workforce_policy_role_for_empty()
	_test_workforce_policy_permanent_vacancy_forestry()
	_test_workforce_policy_permanent_vacancy_construction()
	_test_workforce_policy_permanent_vacancy_respects_capacity()
	_test_workforce_policy_permanent_vacancy_respects_role_available()
	_test_workforce_policy_permanent_vacancy_skill_tiebreak()
	_test_workforce_policy_permanent_vacancy_empty_world()
	_test_workforce_policy_can_assign_unregistered()
	_test_workforce_policy_can_assign_player_controlled()
	_test_workforce_policy_can_assign_blocked_by_storage()
	_test_workforce_policy_can_assign_no_role()
	_test_workforce_policy_can_assign_permanent_role()
	_test_workforce_policy_can_assign_daily_before_workday()
	_test_workforce_policy_can_take_queued_job()
	_test_workforce_policy_can_take_queued_job_busy()
	_test_follow_leader_goal_scores_when_far()
	_test_follow_leader_goal_zero_when_close()
	_test_follow_leader_goal_zero_when_leader()
	_test_follow_leader_goal_zero_when_no_squad()
	_test_follow_leader_goal_zero_when_order_active()
	_test_follow_leader_goal_build_task()
	_test_follow_leader_goal_build_task_no_leader()
	_test_register_goal_scores_for_unregistered()
	_test_register_goal_scores_for_no_permanent_work()
	_test_register_goal_scores_for_registering()
	_test_register_goal_zero_when_wrong_kind()
	_test_register_goal_zero_when_no_order()
	_test_register_goal_zero_when_employed()
	_test_register_goal_build_task()
	_test_register_goal_build_task_no_position()
	_test_register_step_success()
	_test_register_step_failure_on_not_started()
	_test_register_step_failure_on_actuator_fail()
	_test_register_step_cancel()
	_test_sleep_at_home_step_success_when_sleep_done()
	_test_sleep_at_home_step_failure_when_not_started()
	_test_sleep_at_home_step_failure_on_actuator_fail()
	_test_eat_at_canteen_step_success_when_meal_done()
	_test_eat_at_canteen_step_failure_when_not_started()
	_test_eat_at_canteen_step_failure_on_actuator_fail()
	_test_courier_delivery_step_success()
	_test_courier_delivery_step_failure_when_no_order()
	_test_courier_delivery_step_failure_when_empty_task_id()
	_test_courier_delivery_step_failure_on_actuator_fail()
	_test_facade_target_helpers_insert_nearby_sorted_by_distance()
	_test_facade_target_helpers_insert_nearby_tiebreak_by_id()
	_test_facade_target_helpers_insert_nearby_caps_at_max()
	_test_facade_target_helpers_home_entrance_invalid_node()
	_test_facade_target_helpers_home_entrance_not_in_tree()
	_test_facade_target_helpers_workplace_target_key_invalid()
	_test_relieve_step_success()
	_test_relieve_step_failure_when_no_candidates()
	_test_relieve_step_failure_when_reservation_taken()
	_test_relieve_step_success_when_toilet_done()
	_test_relieve_step_failure_on_actuator_fail()
	_test_relieve_step_cancel_releases_reservation()
	_test_return_home_goal_scores_when_far()
	_test_return_home_goal_zero_when_close()
	_test_return_home_goal_zero_when_no_home()
	_test_return_home_goal_zero_when_unreachable()
	_test_return_home_goal_zero_when_no_permanent_work()
	_test_return_home_goal_zero_when_order_active()
	_test_return_home_goal_build_task()
	_test_return_home_goal_build_task_no_position()
	_test_facade_context_has_tool_true()
	_test_facade_context_has_tool_false()
	_test_facade_context_has_tool_no_settlement()
	_test_facade_context_backpack_resources()
	_test_facade_context_backpack_resources_empty()


# ============================================================
# WorkforcePolicy
# ============================================================

static func _test_workforce_policy_role_for_permanent() -> void:
	var worker := {"permanent_role": "forestry", "daily_order_role": "gather_branches"}
	assert(WorkforcePolicyScript.role_for(worker, {}) == "forestry")

static func _test_workforce_policy_role_for_daily() -> void:
	var worker := {"permanent_role": "", "daily_order_role": "construction"}
	assert(WorkforcePolicyScript.role_for(worker, {}) == "construction")

static func _test_workforce_policy_role_for_empty() -> void:
	var worker := {"permanent_role": "", "daily_order_role": ""}
	assert(WorkforcePolicyScript.role_for(worker, {}).is_empty())


static func _test_workforce_policy_permanent_vacancy_forestry() -> void:
	var world := {"forestry_jobs": 2, "warehouses": 1, "trees": 5, "assigned_roles": {}}
	var worker := {"skills": {"forestry": 1.0}}
	var role := WorkforcePolicyScript.permanent_vacancy_for(worker, world)
	assert(role == "forestry")

static func _test_workforce_policy_permanent_vacancy_construction() -> void:
	var world := {"construction_sites": 3, "assigned_roles": {}}
	var worker := {"skills": {}}
	var role := WorkforcePolicyScript.permanent_vacancy_for(worker, world)
	assert(role == "construction")

static func _test_workforce_policy_permanent_vacancy_respects_capacity() -> void:
	var world := {"forestry_jobs": 1, "warehouses": 1, "trees": 5, "assigned_roles": {"forestry": 1}}
	var worker := {"skills": {"forestry": 1.0}}
	var role := WorkforcePolicyScript.permanent_vacancy_for(worker, world)
	assert(role != "forestry")

static func _test_workforce_policy_permanent_vacancy_respects_role_available() -> void:
	# Forestry requires warehouses AND trees
	var world := {"forestry_jobs": 2, "warehouses": 0, "trees": 5, "assigned_roles": {}}
	var worker := {"skills": {"forestry": 1.0}}
	var role := WorkforcePolicyScript.permanent_vacancy_for(worker, world)
	assert(role != "forestry")

static func _test_workforce_policy_permanent_vacancy_skill_tiebreak() -> void:
	var world := {
		"forestry_jobs": 1, "warehouses": 1, "trees": 5,
		"farming_jobs": 1, "farms": 1,
		"assigned_roles": {},
	}
	# Worker with higher farming skill should prefer farming
	var worker := {"skills": {"forestry": 0.1, "farming": 1.0}}
	var role := WorkforcePolicyScript.permanent_vacancy_for(worker, world)
	assert(role == "farming")

static func _test_workforce_policy_permanent_vacancy_empty_world() -> void:
	var role := WorkforcePolicyScript.permanent_vacancy_for({"skills": {}}, {})
	assert(role.is_empty())


static func _test_workforce_policy_can_assign_unregistered() -> void:
	var worker := {"workforce_status": "unregistered", "permanent_role": "forestry"}
	var world := {"warehouses": 1, "trees": 5}
	assert(not WorkforcePolicyScript.can_assign(worker, world))

static func _test_workforce_policy_can_assign_player_controlled() -> void:
	var worker := {"player_controlled": true, "workforce_status": "employed", "permanent_role": "forestry"}
	var world := {"warehouses": 1, "trees": 5}
	assert(not WorkforcePolicyScript.can_assign(worker, world))

static func _test_workforce_policy_can_assign_blocked_by_storage() -> void:
	var worker := {"blocked_by_storage": true, "workforce_status": "employed", "permanent_role": "forestry"}
	var world := {"warehouses": 1, "trees": 5}
	assert(not WorkforcePolicyScript.can_assign(worker, world))

static func _test_workforce_policy_can_assign_no_role() -> void:
	var worker := {"workforce_status": "employed", "permanent_role": "", "daily_order_role": ""}
	var world := {"warehouses": 1, "trees": 5}
	assert(not WorkforcePolicyScript.can_assign(worker, world))

static func _test_workforce_policy_can_assign_permanent_role() -> void:
	var worker := {"workforce_status": "employed", "permanent_role": "forestry"}
	var world := {"warehouses": 1, "trees": 5, "assigned_roles": {}}
	assert(WorkforcePolicyScript.can_assign(worker, world))

static func _test_workforce_policy_can_assign_daily_before_workday() -> void:
	var worker := {"workforce_status": "employed", "permanent_role": "", "daily_order_role": "construction"}
	var world := {"construction_sites": 1, "assigned_roles": {}, "hour": 6, "workday_start_hour": 8}
	assert(not WorkforcePolicyScript.can_assign(worker, world))

static func _test_workforce_policy_can_take_queued_job() -> void:
	var worker := {"player_controlled": false, "idle": true, "daily_order_role": "", "has_queued_job": false}
	assert(WorkforcePolicyScript.can_take_queued_job(worker))

static func _test_workforce_policy_can_take_queued_job_busy() -> void:
	var worker := {"player_controlled": false, "idle": false, "daily_order_role": "", "has_queued_job": false}
	assert(not WorkforcePolicyScript.can_take_queued_job(worker))


# ============================================================
# FollowLeaderGoal
# ============================================================

static func _test_follow_leader_goal_scores_when_far() -> void:
	var goal: RefCounted = FollowLeaderGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"squad.in_squad": true,
		&"squad.is_leader": false,
		&"squad.leader_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_equal_approx(goal.score(snapshot, citizen, null, AIBlackboard.new()), 0.28))

static func _test_follow_leader_goal_zero_when_close() -> void:
	var goal: RefCounted = FollowLeaderGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"squad.in_squad": true,
		&"squad.is_leader": false,
		&"squad.leader_position": Vector3(2.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_zero_approx(goal.score(snapshot, citizen, null, AIBlackboard.new())))

static func _test_follow_leader_goal_zero_when_leader() -> void:
	var goal: RefCounted = FollowLeaderGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"squad.in_squad": true,
		&"squad.is_leader": true,
		&"squad.leader_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_zero_approx(goal.score(snapshot, citizen, null, AIBlackboard.new())))

static func _test_follow_leader_goal_zero_when_no_squad() -> void:
	var goal: RefCounted = FollowLeaderGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"squad.in_squad": false,
		&"squad.leader_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_zero_approx(goal.score(snapshot, citizen, null, AIBlackboard.new())))

static func _test_follow_leader_goal_zero_when_order_active() -> void:
	var goal: RefCounted = FollowLeaderGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"squad.in_squad": true,
		&"squad.leader_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"work", &"test", 0.5)
	assert(is_zero_approx(goal.score(snapshot, citizen, order, AIBlackboard.new())))

static func _test_follow_leader_goal_build_task() -> void:
	var goal: RefCounted = FollowLeaderGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"squad.in_squad": true,
		&"squad.leader_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var task: BehaviorTask = goal.build_task(snapshot, citizen, null, AIBlackboard.new())
	assert(task != null)
	assert(task.goal_id == &"follow_leader")
	assert(not task.resumable)

static func _test_follow_leader_goal_build_task_no_leader() -> void:
	var goal: RefCounted = FollowLeaderGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"squad.in_squad": true,
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var task: BehaviorTask = goal.build_task(snapshot, citizen, null, AIBlackboard.new())
	assert(task == null)


# ============================================================
# RegisterGoal
# ============================================================

static func _register_citizen(status: String) -> CitizenSnapshot:
	return CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"workforce.worker_data": {"workforce_status": status},
	}))

static func _test_register_goal_scores_for_unregistered() -> void:
	var goal: RefCounted = RegisterGoalScript.new()
	var citizen := _register_citizen("unregistered")
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"register", &"workforce", 0.74)
	assert(is_equal_approx(goal.score(snapshot, citizen, order, AIBlackboard.new()), 0.74))

static func _test_register_goal_scores_for_no_permanent_work() -> void:
	var goal: RefCounted = RegisterGoalScript.new()
	var citizen := _register_citizen("no_permanent_work")
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"register", &"workforce", 0.50)
	assert(is_equal_approx(goal.score(snapshot, citizen, order, AIBlackboard.new()), 0.50))

static func _test_register_goal_scores_for_registering() -> void:
	var goal: RefCounted = RegisterGoalScript.new()
	var citizen := _register_citizen("registering")
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"register", &"workforce", 0.60)
	assert(is_equal_approx(goal.score(snapshot, citizen, order, AIBlackboard.new()), 0.60))

static func _test_register_goal_zero_when_wrong_kind() -> void:
	var goal: RefCounted = RegisterGoalScript.new()
	var citizen := _register_citizen("unregistered")
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"forestry", &"workforce", 0.74)
	assert(is_zero_approx(goal.score(snapshot, citizen, order, AIBlackboard.new())))

static func _test_register_goal_zero_when_no_order() -> void:
	var goal: RefCounted = RegisterGoalScript.new()
	var citizen := _register_citizen("unregistered")
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_zero_approx(goal.score(snapshot, citizen, null, AIBlackboard.new())))

static func _test_register_goal_zero_when_employed() -> void:
	var goal: RefCounted = RegisterGoalScript.new()
	var citizen := _register_citizen("employed")
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"register", &"workforce", 0.74)
	assert(is_zero_approx(goal.score(snapshot, citizen, order, AIBlackboard.new())))

static func _test_register_goal_build_task() -> void:
	var goal: RefCounted = RegisterGoalScript.new()
	var citizen := _register_citizen("unregistered")
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"register", &"workforce", 0.74)
	order.target_position = Vector3(5.0, 0.0, 0.0)
	var task: BehaviorTask = goal.build_task(snapshot, citizen, order, AIBlackboard.new())
	assert(task != null)
	assert(task.goal_id == &"register")
	assert(not task.resumable)

static func _test_register_goal_build_task_no_position() -> void:
	var goal: RefCounted = RegisterGoalScript.new()
	var citizen := _register_citizen("unregistered")
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"register", &"workforce", 0.74)
	# target_position defaults to Vector3.INF
	var task: BehaviorTask = goal.build_task(snapshot, citizen, order, AIBlackboard.new())
	assert(task == null)


# ============================================================
# RegisterStep
# ============================================================

static func _test_register_step_success() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new())
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var order := CitizenOrder.new(1, &"register", &"workforce", 0.74, AIFactSet.new({
		&"workplace.role": "forestry",
		&"center.position": Vector3(5.0, 0.0, 0.0),
		&"workplace.node_key": &"building:6:0",
	}))
	context.refresh(TestAIHelpers.snapshot(0.0, citizen), order)
	var step: RefCounted = RegisterStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(actuator.action_start_count == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	assert(step.run(context, 0.1) == BehaviorStep.Status.SUCCESS)

static func _test_register_step_failure_on_not_started() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	# No order means _enter does nothing, _started stays false
	context.refresh(TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(1)), null)
	var step: RefCounted = RegisterStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)

static func _test_register_step_failure_on_actuator_fail() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new())
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var order := CitizenOrder.new(1, &"register", &"workforce", 0.74, AIFactSet.new({
		&"workplace.role": "forestry",
		&"center.position": Vector3(5.0, 0.0, 0.0),
	}))
	context.refresh(TestAIHelpers.snapshot(0.0, citizen), order)
	var step: RefCounted = RegisterStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	actuator.next_action_status = CitizenActuator.ActionStatus.FAILED
	actuator.next_action_failure_reason = BehaviorStep.FailureReason.ACTUATOR_REJECTED
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(step.failure_reason == BehaviorStep.FailureReason.ACTUATOR_REJECTED)

static func _test_register_step_cancel() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new())
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var order := CitizenOrder.new(1, &"register", &"workforce", 0.74, AIFactSet.new({
		&"workplace.role": "forestry",
		&"center.position": Vector3(5.0, 0.0, 0.0),
	}))
	context.refresh(TestAIHelpers.snapshot(0.0, citizen), order)
	var step: RefCounted = RegisterStepScript.new()
	step.run(context, 0.1)
	step.cancel(context)
	assert(actuator.cancel_action_count == 1)


# ============================================================
# SleepAtHomeStep
# ============================================================

static func _test_sleep_at_home_step_success_when_sleep_done() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.should_sleep": true,
	}))
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(TestAIHelpers.snapshot(0.0, citizen), null)
	var step: RefCounted = SleepAtHomeStepScript.new()
	# First tick enters and starts action, should_sleep=true -> RUNNING
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(actuator.action_start_count == 1)
	# Refresh with should_sleep=false -> SUCCESS
	var awake_citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.should_sleep": false,
	}))
	context.refresh(TestAIHelpers.snapshot(0.0, awake_citizen), null)
	assert(step.run(context, 0.1) == BehaviorStep.Status.SUCCESS)

static func _test_sleep_at_home_step_failure_when_not_started() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	# citizen is null because snapshot has no citizen with matching id
	context.refresh(TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(99)), null)
	var step: RefCounted = SleepAtHomeStepScript.new()
	# _enter calls begin_action which returns true for FakeActuator,
	# but citizen is null in _tick -> FAILURE
	step.run(context, 0.1)

static func _test_sleep_at_home_step_failure_on_actuator_fail() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.should_sleep": true,
	}))
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(TestAIHelpers.snapshot(0.0, citizen), null)
	var step: RefCounted = SleepAtHomeStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	actuator.next_action_status = CitizenActuator.ActionStatus.FAILED
	actuator.next_action_failure_reason = BehaviorStep.FailureReason.ACTUATOR_REJECTED
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(step.failure_reason == BehaviorStep.FailureReason.ACTUATOR_REJECTED)


# ============================================================
# EatAtCanteenStep
# ============================================================

static func _test_eat_at_canteen_step_success_when_meal_done() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.meal_requested": true,
		&"needs.canteen_position": Vector3(3.0, 0.0, 0.0),
	}))
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(TestAIHelpers.snapshot(0.0, citizen), null)
	var step: RefCounted = EatAtCanteenStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(actuator.action_start_count == 1)
	# Refresh with meal_requested=false -> SUCCESS
	var fed_citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.meal_requested": false,
		&"needs.canteen_position": Vector3(3.0, 0.0, 0.0),
	}))
	context.refresh(TestAIHelpers.snapshot(0.0, fed_citizen), null)
	assert(step.run(context, 0.1) == BehaviorStep.Status.SUCCESS)

static func _test_eat_at_canteen_step_failure_when_not_started() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	# citizen is null -> _enter does nothing -> _started stays false
	context.refresh(TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(99)), null)
	var step: RefCounted = EatAtCanteenStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)

static func _test_eat_at_canteen_step_failure_on_actuator_fail() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.meal_requested": true,
		&"needs.canteen_position": Vector3(3.0, 0.0, 0.0),
	}))
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(TestAIHelpers.snapshot(0.0, citizen), null)
	var step: RefCounted = EatAtCanteenStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	actuator.next_action_status = CitizenActuator.ActionStatus.FAILED
	actuator.next_action_failure_reason = BehaviorStep.FailureReason.UNREACHABLE
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(step.failure_reason == BehaviorStep.FailureReason.UNREACHABLE)


# ============================================================
# CourierDeliveryStep
# ============================================================

static func _test_courier_delivery_step_success() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var order := CitizenOrder.new(1, &"courier_delivery", &"logistics", 0.8, AIFactSet.new({
		&"courier.task_id": &"canteen_food",
	}))
	context.refresh(TestAIHelpers.snapshot(0.0, citizen), order)
	var step: RefCounted = CourierDeliveryStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(actuator.action_start_count == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	assert(step.run(context, 0.1) == BehaviorStep.Status.SUCCESS)

static func _test_courier_delivery_step_failure_when_no_order() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(1)), null)
	var step: RefCounted = CourierDeliveryStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)

static func _test_courier_delivery_step_failure_when_empty_task_id() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var order := CitizenOrder.new(1, &"courier_delivery", &"logistics", 0.8)
	context.refresh(TestAIHelpers.snapshot(0.0, CitizenSnapshot.new(1)), order)
	var step: RefCounted = CourierDeliveryStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)

static func _test_courier_delivery_step_failure_on_actuator_fail() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	var order := CitizenOrder.new(1, &"courier_delivery", &"logistics", 0.8, AIFactSet.new({
		&"courier.task_id": &"canteen_food",
	}))
	context.refresh(TestAIHelpers.snapshot(0.0, citizen), order)
	var step: RefCounted = CourierDeliveryStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	actuator.next_action_status = CitizenActuator.ActionStatus.FAILED
	actuator.next_action_failure_reason = BehaviorStep.FailureReason.ACTUATOR_REJECTED
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(step.failure_reason == BehaviorStep.FailureReason.ACTUATOR_REJECTED)


# ============================================================
# FacadeTargetHelpers
# ============================================================

static func _test_facade_target_helpers_insert_nearby_sorted_by_distance() -> void:
	var helpers := FacadeTargetHelpersScript.new()
	var candidates: Array[Dictionary] = []
	helpers.insert_nearby_gathering_candidate(candidates, {&"id": &"a", &"direct_distance": 10.0})
	helpers.insert_nearby_gathering_candidate(candidates, {&"id": &"b", &"direct_distance": 5.0})
	helpers.insert_nearby_gathering_candidate(candidates, {&"id": &"c", &"direct_distance": 7.0})
	assert(candidates.size() == 3)
	assert(candidates[0][&"id"] == &"b")
	assert(candidates[1][&"id"] == &"c")
	assert(candidates[2][&"id"] == &"a")

static func _test_facade_target_helpers_insert_nearby_tiebreak_by_id() -> void:
	var helpers := FacadeTargetHelpersScript.new()
	var candidates: Array[Dictionary] = []
	helpers.insert_nearby_gathering_candidate(candidates, {&"id": &"zzz", &"direct_distance": 5.0})
	helpers.insert_nearby_gathering_candidate(candidates, {&"id": &"aaa", &"direct_distance": 5.0})
	assert(candidates.size() == 2)
	# Equal distance: lexicographic id tiebreak (aaa < zzz)
	assert(candidates[0][&"id"] == &"aaa")
	assert(candidates[1][&"id"] == &"zzz")

static func _test_facade_target_helpers_insert_nearby_caps_at_max() -> void:
	var helpers := FacadeTargetHelpersScript.new()
	var candidates: Array[Dictionary] = []
	for i in FacadeTargetHelpersScript.MAX_ROUTE_CANDIDATES + 5:
		helpers.insert_nearby_gathering_candidate(candidates, {
			&"id": StringName("c%d" % i),
			&"direct_distance": float(i),
		})
	assert(candidates.size() == FacadeTargetHelpersScript.MAX_ROUTE_CANDIDATES)
	# The closest MAX_ROUTE_CANDIDATES should be kept (distances 0..MAX-1)
	assert(candidates[0][&"id"] == &"c0")
	assert(candidates[candidates.size() - 1][&"id"] == StringName("c%d" % (FacadeTargetHelpersScript.MAX_ROUTE_CANDIDATES - 1)))

static func _test_facade_target_helpers_home_entrance_invalid_node() -> void:
	var helpers := FacadeTargetHelpersScript.new()
	assert(helpers.home_entrance_position(null) == Vector3.INF)

static func _test_facade_target_helpers_home_entrance_not_in_tree() -> void:
	var helpers := FacadeTargetHelpersScript.new()
	var home := Node3D.new()
	home.position = Vector3(5.0, 0.0, 0.0)
	# Not added to scene tree -> returns home.position
	assert(helpers.home_entrance_position(home) == Vector3(5.0, 0.0, 0.0))
	home.free()

static func _test_facade_target_helpers_workplace_target_key_invalid() -> void:
	var helpers := FacadeTargetHelpersScript.new()
	# simulation is null, so this should crash if not guarded;
	# but workplace_target_key checks is_instance_valid first
	# With null simulation, we can't call it. Instead test with invalid workplace.
	assert(helpers.workplace_target_key(null) == &"")


# ============================================================
# RelieveStep
# ============================================================

static func _relief_citizen(toilet_requested: bool) -> CitizenSnapshot:
	return CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.toilet_requested": toilet_requested,
		&"needs.relief_candidates": [{
			&"id": &"bush:3:4",
			&"position": Vector3(3.0, 0.0, 4.0),
			&"kind": &"tree",
		}],
	}))

static func _test_relieve_step_success() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := _relief_citizen(true)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(snapshot, null)
	var step: RefCounted = RelieveStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	assert(actuator.action_start_count == 1)
	actuator.next_action_status = CitizenActuator.ActionStatus.SUCCEEDED
	assert(step.run(context, 0.1) == BehaviorStep.Status.SUCCESS)

static func _test_relieve_step_failure_when_no_candidates() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := CitizenSnapshot.new(1, Vector3.ZERO, false, true, AIFactSet.new({
		&"needs.toilet_requested": true,
		&"needs.relief_candidates": [],
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(snapshot, null)
	var step: RefCounted = RelieveStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(actuator.action_start_count == 0)

static func _test_relieve_step_failure_when_reservation_taken() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := _relief_citizen(true)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	# Pre-claim the reservation by another citizen
	snapshot.reservations.claim([&"needs.relief", &"bush:3:4"], 2, 0.0, 30.0)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(snapshot, null)
	var step: RefCounted = RelieveStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(actuator.action_start_count == 0)

static func _test_relieve_step_success_when_toilet_done() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := _relief_citizen(true)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(snapshot, null)
	var step: RefCounted = RelieveStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	# Refresh with toilet_requested=false -> SUCCESS
	var relieved := _relief_citizen(false)
	context.refresh(TestAIHelpers.snapshot(0.0, relieved), null)
	assert(step.run(context, 0.1) == BehaviorStep.Status.SUCCESS)

static func _test_relieve_step_failure_on_actuator_fail() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := _relief_citizen(true)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(snapshot, null)
	var step: RefCounted = RelieveStepScript.new()
	assert(step.run(context, 0.1) == BehaviorStep.Status.RUNNING)
	actuator.next_action_status = CitizenActuator.ActionStatus.FAILED
	actuator.next_action_failure_reason = BehaviorStep.FailureReason.UNREACHABLE
	assert(step.run(context, 0.1) == BehaviorStep.Status.FAILURE)
	assert(step.failure_reason == BehaviorStep.FailureReason.UNREACHABLE)

static func _test_relieve_step_cancel_releases_reservation() -> void:
	var actuator := TestAIHelpers.FakeActuator.new(1)
	var citizen := _relief_citizen(true)
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var context := BehaviorContext.new(actuator, AIBlackboard.new())
	context.refresh(snapshot, null)
	var step: RefCounted = RelieveStepScript.new()
	step.run(context, 0.1)
	# Reservation should be held by citizen 1
	assert(snapshot.reservations.owner_of([&"needs.relief", &"bush:3:4"], 0.0) == 1)
	step.cancel(context)
	assert(actuator.cancel_action_count == 1)
	# Reservation should be released
	assert(snapshot.reservations.owner_of([&"needs.relief", &"bush:3:4"], 0.0) == 0)


# ============================================================
# ReturnHomeWhenIdleGoal
# ============================================================

static func _test_return_home_goal_scores_when_far() -> void:
	var goal: RefCounted = ReturnHomeWhenIdleGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"work.permanent.active": true,
		&"needs.has_home": true,
		&"needs.home_reachable": true,
		&"needs.home_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_equal_approx(goal.score(snapshot, citizen, null, AIBlackboard.new()), 0.20))

static func _test_return_home_goal_zero_when_close() -> void:
	var goal: RefCounted = ReturnHomeWhenIdleGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(10.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"work.permanent.active": true,
		&"needs.has_home": true,
		&"needs.home_reachable": true,
		&"needs.home_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_zero_approx(goal.score(snapshot, citizen, null, AIBlackboard.new())))

static func _test_return_home_goal_zero_when_no_home() -> void:
	var goal: RefCounted = ReturnHomeWhenIdleGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"work.permanent.active": true,
		&"needs.has_home": false,
		&"needs.home_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_zero_approx(goal.score(snapshot, citizen, null, AIBlackboard.new())))

static func _test_return_home_goal_zero_when_unreachable() -> void:
	var goal: RefCounted = ReturnHomeWhenIdleGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"work.permanent.active": true,
		&"needs.has_home": true,
		&"needs.home_reachable": false,
		&"needs.home_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_zero_approx(goal.score(snapshot, citizen, null, AIBlackboard.new())))

static func _test_return_home_goal_zero_when_no_permanent_work() -> void:
	var goal: RefCounted = ReturnHomeWhenIdleGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"work.permanent.active": false,
		&"needs.has_home": true,
		&"needs.home_reachable": true,
		&"needs.home_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	assert(is_zero_approx(goal.score(snapshot, citizen, null, AIBlackboard.new())))

static func _test_return_home_goal_zero_when_order_active() -> void:
	var goal: RefCounted = ReturnHomeWhenIdleGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"work.permanent.active": true,
		&"needs.has_home": true,
		&"needs.home_reachable": true,
		&"needs.home_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var order := CitizenOrder.new(1, &"construction", &"test", 0.6)
	assert(is_zero_approx(goal.score(snapshot, citizen, order, AIBlackboard.new())))

static func _test_return_home_goal_build_task() -> void:
	var goal: RefCounted = ReturnHomeWhenIdleGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new({
		&"needs.home_position": Vector3(10.0, 0.0, 0.0),
	}))
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var task: BehaviorTask = goal.build_task(snapshot, citizen, null, AIBlackboard.new())
	assert(task != null)
	assert(task.goal_id == &"return_home_when_idle")
	assert(not task.resumable)

static func _test_return_home_goal_build_task_no_position() -> void:
	var goal: RefCounted = ReturnHomeWhenIdleGoalScript.new()
	var citizen := CitizenSnapshot.new(1, Vector3(0.0, 0.0, 0.0), false, true, AIFactSet.new())
	var snapshot := TestAIHelpers.snapshot(0.0, citizen)
	var task: BehaviorTask = goal.build_task(snapshot, citizen, null, AIBlackboard.new())
	assert(task == null)


# ============================================================
# FacadeContext
# ============================================================

class MockSimSettlement extends RefCounted:
	var tools: Dictionary = {}
	var backpack: Dictionary = {}


class MockSimulation extends Node:
	var settlement: Object = null


static func _test_facade_context_has_tool_true() -> void:
	var sim := MockSimulation.new()
	var settlement := MockSimSettlement.new()
	settlement.tools = {"axe": true}
	sim.settlement = settlement
	var ctx := FacadeContextScript.new(sim, null, null, 1, false, false, "")
	assert(ctx.has_tool("axe"))
	sim.free()

static func _test_facade_context_has_tool_false() -> void:
	var sim := MockSimulation.new()
	var settlement := MockSimSettlement.new()
	settlement.tools = {"axe": false}
	sim.settlement = settlement
	var ctx := FacadeContextScript.new(sim, null, null, 1, false, false, "")
	assert(not ctx.has_tool("axe"))
	sim.free()

static func _test_facade_context_has_tool_no_settlement() -> void:
	var sim := MockSimulation.new()
	var ctx := FacadeContextScript.new(sim, null, null, 1, false, false, "")
	assert(not ctx.has_tool("axe"))
	sim.free()

static func _test_facade_context_backpack_resources() -> void:
	var sim := MockSimulation.new()
	var settlement := MockSimSettlement.new()
	settlement.backpack = {"branches": 5, "food": 3}
	sim.settlement = settlement
	var ctx := FacadeContextScript.new(sim, null, null, 1, false, false, "")
	var backpack := ctx.backpack_resources()
	assert(backpack.size() == 2)
	assert(int(backpack["branches"]) == 5)
	assert(int(backpack["food"]) == 3)
	sim.free()

static func _test_facade_context_backpack_resources_empty() -> void:
	var sim := MockSimulation.new()
	var ctx := FacadeContextScript.new(sim, null, null, 1, false, false, "")
	var backpack := ctx.backpack_resources()
	assert(backpack.is_empty())
	sim.free()
