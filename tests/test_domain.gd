extends SceneTree

const SettlementRulesScript = preload("res://scripts/domain/settlement_rules.gd")


func _init() -> void:
	_test_settlement_economy()
	_test_progression_and_volunteers()
	_test_work_schedule_wellbeing()
	_test_clock_wraps_and_reports_elapsed_minutes()
	_test_sawmill_rules()
	_test_workforce_policy()
	_test_citizen_task_state()
	_test_citizen_decision_context()
	_test_construction_progress()
	quit(0)


func _test_settlement_economy() -> void:
	var state := SettlementState.new()
	assert(state.money == 20 and state.wood == 0 and state.food == 0)
	state.branches = 12
	state.grass = 4
	assert(state.can_afford_building("warehouse"))
	assert(state.pay_for_building("warehouse"))
	assert(state.branches == 12 and state.grass == 4)
	state.ensure_storage_defaults(0)
	assert(state.storage_capacity(0) == 0)
	assert(not state.reserve_storage_room_for("grass", 1, 0))
	state.ensure_storage_defaults(1)
	assert(state.reserve_storage_room_for("grass", 1, 1))
	state.add("grass", 1)
	assert(state.grass == 5 and state.wood == 0)
	
	# Verify Clay house costs grass instead of soil
	state.era = SettlementState.Era.CLAY
	state.clay = 12
	state.grass = 10
	state.branches = 8
	assert(state.can_afford_building("clay_house"))
	assert(state.pay_for_building("clay_house"))
	assert(state.grass == 0 and state.clay == 0)
	
	# Verify Stone house costs stone and clay
	state.stone = 15
	state.clay = 8
	state.era = SettlementState.Era.STONE
	assert(state.can_afford_building("stone_house"))
	assert(state.pay_for_building("stone_house"))
	assert(state.stone == 0 and state.clay == 0)

	state.bricks = 15
	state.boards = 10
	assert(state.can_afford_research("brick_construction"))
	assert(state.pay_for_research("brick_construction"))
	assert(state.bricks == 0 and state.boards == 0)

	# Verify Brick house costs bricks and boards
	state.era = SettlementState.Era.BRICK
	state.bricks = 22
	state.boards = 10
	assert(state.can_afford_building("brick_house"))
	assert(state.pay_for_building("brick_house"))
	assert(state.bricks == 0 and state.boards == 0)


func _test_progression_and_volunteers() -> void:
	var state := SettlementState.new()
	state.buildings = {"campfire": 1, "trade_tent": 1, "craft_tent": 1}
	state.food = 4
	state.water = 4
	state.trade_sales = 1
	for tool_id in state.tools:
		state.tools[tool_id] = true
	assert(state.can_advance_to(SettlementState.Era.EARTH, 4, 4))
	assert(state.advance_era(SettlementState.Era.EARTH, 4, 4))

	state.buildings = {"earth_assembly": 1, "smithy": 1, "earth_market": 1}
	state.clay = 5
	state.money = 10
	state.trade_sales = 3
	state.tools["shovel"] = true
	state.tools["hoe"] = true
	assert(state.can_advance_to(SettlementState.Era.CLAY, 4, 4))
	assert(state.advance_era(SettlementState.Era.CLAY, 4, 4))
	
	state.buildings = {"clay_lodge": 1, "clay_market": 1}
	state.water = 4
	state.logs = 10
	state.money = 10
	assert(state.can_advance_to(SettlementState.Era.WOOD, 4, 4))
	assert(state.advance_era(SettlementState.Era.WOOD, 4, 4))

	state.buildings = {"wood_town_hall": 1, "wood_market": 1, "sawmill": 1}
	state.money = 15
	state.tools["pickaxe"] = true
	assert(state.can_advance_to(SettlementState.Era.STONE, 4, 4))
	assert(state.advance_era(SettlementState.Era.STONE, 4, 4))

	state.buildings = {"stone_prefecture": 1, "stone_market": 1, "masonry_workshop": 1, "stone_house": 1}
	state.stone = 20
	state.money = 20
	assert(state.can_advance_to(SettlementState.Era.BRICK, 4, 4))

	assert(SettlementRulesScript.volunteer_can_arrive(1, 2, 60.0))
	assert(not SettlementRulesScript.volunteer_can_arrive(0, 2, 60.0))
	assert(SettlementRulesScript.should_volunteer_leave(3))


func _test_work_schedule_wellbeing() -> void:
	var short_day: int = SettlementRulesScript.daily_wellbeing_change(true, 1.0, 1.0, 6, false)
	var long_night_day: int = SettlementRulesScript.daily_wellbeing_change(true, 1.0, 1.0, 10, true)
	assert(short_day > long_night_day)
	assert(SettlementRulesScript.production_multiplier(10, true) > SettlementRulesScript.production_multiplier(6, false))


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
	var world := {"hour": 9, "warehouses": 1, "sawmills": 1, "trees": 1, "farms": 0, "dig_sites": 0, "schools": 0, "construction_sites": 0, "has_canteen": false, "has_factory_job": false, "has_engineer_job": false, "has_bucket": false, "ponds": 2, "water": 0, "population": 3}
	var forester := {"specialization": "forestry", "manual_role": "", "player_controlled": false, "blocked_by_storage": false, "training_role": "", "training_days_completed": 0}
	assert(WorkforcePolicy.role_for(forester, world) == "forestry")
	assert(WorkforcePolicy.can_assign(forester, world))
	world.sawmills = 0
	world.era = SettlementState.Era.TENT
	assert(WorkforcePolicy.role_for(forester, world) == "gather_branches")
	world.era = SettlementState.Era.EARTH
	assert(WorkforcePolicy.role_for(forester, world) == "forestry")
	world.hour = 7
	assert(not WorkforcePolicy.can_assign(forester, world))
	world.hour = 9
	world.has_bucket = true
	world.has_filter = true
	assert(WorkforcePolicy.role_for(forester, world) == "gather_water")
	assert(WorkforcePolicy.can_assign(forester, world))
	world.assigned_roles = {"gather_water": 1}
	world.farms = 1
	world.food = 0
	assert(WorkforcePolicy.role_for(forester, world) == "farming")
	world.water = 20
	world.food = 20
	world.assigned_roles = {"farming": 1}
	world.dig_sites = 1
	assert(WorkforcePolicy.role_for(forester, world) == "excavation")
	assert(WorkforcePolicy.can_take_queued_job({"idle": true, "manual_role": "", "player_controlled": false}))
	assert(not WorkforcePolicy.can_take_queued_job({"idle": true, "manual_role": "farming", "player_controlled": false}))
	assert(not WorkforcePolicy.can_take_queued_job({"idle": true, "manual_role": "unassigned", "player_controlled": false}))


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
