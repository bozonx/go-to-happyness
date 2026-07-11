extends SceneTree


func _init() -> void:
	_test_settlement_economy()
	_test_clock_wraps_and_reports_elapsed_minutes()
	_test_sawmill_rules()
	_test_workforce_policy()
	_test_citizen_task_state()
	_test_citizen_decision_context()
	_test_construction_progress()
	quit(0)


func _test_settlement_economy() -> void:
	var state := SettlementState.new()
	assert(state.can_afford_building("warehouse"))
	assert(state.pay_for_building("warehouse"))
	assert(state.wood == 20)
	assert(not state.can_afford_building("city_hall"))
	state.bricks = 35
	assert(state.pay_for_building("city_hall"))
	assert(state.bricks == 0)
	state.bricks = 15
	state.boards = 10
	assert(state.can_afford_research("brick_construction"))
	assert(state.pay_for_research("brick_construction"))
	assert(state.bricks == 0 and state.boards == 0)


func _test_clock_wraps_and_reports_elapsed_minutes() -> void:
	var clock := SimulationClock.new()
	clock.minutes = 1439.0
	assert(clock.advance(0.0, 1.0).is_empty())
	var elapsed := clock.advance(2.0, 1.0)
	assert(elapsed.size() == 2)
	assert(elapsed[0] == 0 and elapsed[1] == 1)
	assert(clock.hour() == 0 and clock.minute() == 1)


func _test_sawmill_rules() -> void:
	var stock := SawmillRules.new_stock(5.0)
	stock.logs = 2
	stock = SawmillRules.advance(stock, 4.0, 4.0)
	assert(stock.logs == 1 and stock.boards == 1 and stock.process_time == 4.0)
	assert(not SawmillRules.should_worker_deliver(stock, true, 10.0, 4, 12.0))
	stock.boards = 4
	assert(SawmillRules.should_worker_deliver(stock, true, 17.0, 4, 12.0))
	assert(SawmillRules.should_worker_deliver(stock, false, 6.0, 4, 12.0))


func _test_workforce_policy() -> void:
	var world := {"hour": 9, "warehouses": 1, "sawmills": 1, "trees": 1, "farms": 0, "dig_sites": 0, "schools": 0, "construction_sites": 0, "has_canteen": false, "has_factory_job": false, "has_engineer_job": false}
	var forester := {"specialization": "forestry", "manual_role": "", "player_controlled": false, "blocked_by_storage": false, "training_role": "", "training_days_completed": 0}
	assert(WorkforcePolicy.role_for(forester, world) == "forestry")
	assert(WorkforcePolicy.can_assign(forester, world))
	world.hour = 7
	assert(not WorkforcePolicy.can_assign(forester, world))


func _test_citizen_task_state() -> void:
	var task := CitizenTaskState.new()
	task.start(1.0)
	assert(not task.advance(0.4))
	assert(task.advance(0.6))


func _test_citizen_decision_context() -> void:
	var context := CitizenDecisionContext.new()
	context.is_night = true
	context.has_home = true
	assert(context.is_goal_valid(CitizenDecisionContext.Intent.SLEEP))
	assert(context.priority_for(CitizenDecisionContext.Intent.SLEEP) > context.priority_for(CitizenDecisionContext.Intent.WORK))
	context.is_night = false
	context.meal_requested = true
	context.has_canteen = true
	assert(context.is_goal_valid(CitizenDecisionContext.Intent.EAT))


func _test_construction_progress() -> void:
	assert(is_equal_approx(ConstructionProgress.advance(0.25, 2.0, 4.0, 1.0), 0.75))
	assert(ConstructionProgress.advance(0.9, 4.0, 4.0, 1.0) == 1.0)
