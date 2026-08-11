class_name TestDomainEconomy
extends RefCounted

const SettlementRulesScript = preload("res://game/features/settlement/domain/settlement_rules.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")


static func run_all() -> void:
	_test_settlement_economy()
	_test_tent_start_config()
	_test_starter_stash_is_not_teleported()
	_test_progression_and_volunteers()
	_test_work_schedule_wellbeing()
	_test_tent_survival_rules()
	_test_clock_wraps_and_reports_elapsed_minutes()
	_test_day_cycle_schedule()
	_test_workforce_policy()
	_test_overtime_sources_are_independent()
	_test_cheer_up_mechanic()
	_test_resource_pile_decay_rates()
	_test_party_stash_invariants()


static func _test_settlement_economy() -> void:
	var state := SettlementState.new()
	assert(state.money == 20 and state.wood == 0 and state.food == 0)
	state.branches = 12
	state.grass = 4
	assert(state.can_afford_building("warehouse"))
	assert(state.pay_for_building("warehouse"))
	assert(state.warehouse_ever_built)
	assert(state.storage_capacity(1) == 24)
	assert(not state.reserve_storage_room_for("grass", 1, 0))
	assert(state.reserve_storage_room_for("grass", 1, 1))
	state.add("grass", 1)
	assert(state.grass == 1 and state.wood == 0)

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

	# Verify Brick house costs bricks and boards
	state.era = SettlementState.Era.BRICK
	state.bricks = 22
	state.boards = 10
	assert(state.can_afford_building("brick_house"))
	assert(state.pay_for_building("brick_house"))
	assert(state.bricks == 0 and state.boards == 0)


static func _test_tent_start_config() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	assert(state.era == SettlementState.Era.TENT)
	assert(state.money == SettlementState.TENT_STARTING_MONEY)
	# Food and water now come from an authored party-stash entity, not from launch config.
	assert(state.amount("food") == 0)
	assert(state.amount("water") == 0)
	assert(state.branches == 0 and state.grass == 0)
	# Equipment is now empty by default — everything comes from the map.
	assert(state.equipment.is_empty())
	assert(state.is_building_unlocked("warehouse"))
	assert(state.is_building_unlocked("campfire"))
	assert(state.is_building_unlocked("tent"))
	assert(state.is_building_unlocked("cook_campfire"))
	assert(state.is_building_unlocked("dew_collector"))
	# Tarp now comes from an authored party-stash entity; add it manually for this test.
	state.add(ResourceIds.TARP, 1)
	assert(state.tarp == 1)
	assert(state.can_cover_warehouse_with_tarp())
	assert(state.cover_warehouse_with_tarp())
	assert(state.tarp == 0 and state.warehouse_tarp_covered)
	assert(not state.is_building_unlocked("straw_tent"))
	assert(not state.can_afford_building("campfire"))
	state.add_warehouse("warehouse")
	state.branches = 6
	assert(state.is_building_unlocked("campfire"))
	assert(state.can_afford_building("campfire"))
	assert(BuildingCatalog.is_landmark("campfire"))
	assert(not BuildingCatalog.is_demolishable("campfire"))
	assert(BuildingCatalog.is_upgrade_only("campfire_lvl2"))
	assert(BuildingCatalog.upgrades_from("campfire_lvl2") == "campfire")
	assert(BuildingCatalog.next_upgrade_for("campfire") == "campfire_lvl2")
	state.buildings["campfire"] = 1
	assert(not state.can_upgrade_building("campfire"))
	state.unlocked_building_levels["campfire_lvl2"] = true
	state.branches = 15
	state.grass = 10
	assert(state.can_upgrade_building("campfire"))
	assert(state.pay_for_building_upgrade("campfire") == "campfire_lvl2")
	assert(int(state.buildings.get("campfire", 0)) == 0)
	assert(int(state.buildings.get("campfire_lvl2", 0)) == 1)
	var tent_refund := BuildingCatalog.demolition_refund("tent")
	assert(int(tent_refund.get("branches", 0)) == 1)
	assert(int(tent_refund.get("grass", 0)) == 1)
	var storage_state := SettlementState.new()
	assert(storage_state.storage_availability_for("grass", 1, 0) == SettlementState.StorageAvailability.NO_WAREHOUSE)
	storage_state.add_warehouse("warehouse")
	storage_state.warehouse_ever_built = true
	storage_state.branches = 24
	assert(storage_state.storage_availability_for("grass", 1, 1) == SettlementState.StorageAvailability.NO_ROOM)
	storage_state.add_warehouse("warehouse")
	assert(storage_state.storage_availability_for("grass", 1, 1) == SettlementState.StorageAvailability.OK)
	var debug_storage_state := SettlementState.new()
	debug_storage_state.apply_tent_start()
	debug_storage_state.add_warehouse("warehouse")
	assert(debug_storage_state.storage_capacity(1) == 24)
	assert(debug_storage_state.reserve_warehouse_room(0, "branches", 3))
	var decay := SettlementRulesScript.open_air_storage_decay_losses({"food": 16, "grass": 10}, 26.0, 0.0)
	assert(int(decay.food) == 2 and int(decay.grass) == 1)


static func _test_starter_stash_is_not_teleported() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	assert(state.uses_starter_stash_storage())
	var physical_inventory := {"branches": 3}
	state.bind_starter_stash_inventory(&"test_stash", physical_inventory)
	state.add_warehouse("warehouse")
	state.warehouse_ever_built = true
	assert(not state.uses_starter_stash_storage())
	assert(int(physical_inventory["branches"]) == 3,
		"building a warehouse must not teleport the authored stash")
	assert(state.warehouse_amount("branches", 0) == 0)


static func _test_progression_and_volunteers() -> void:
	var state := SettlementState.new()
	state.add_warehouse("warehouse")
	state.buildings = {"campfire": 1, "tarp_trade_tent": 1}
	state.food = 4
	state.water = 4
	state.trade_sales = 1
	for tool_id in state.tools:
		state.tools[tool_id] = true
	state.complete_research("earth_buildings")
	assert(state.can_advance_to(SettlementState.Era.EARTH, 4, 4))

	var no_market_state := SettlementState.new()
	no_market_state.add_warehouse("warehouse")
	no_market_state.buildings = {"campfire": 1}
	for tool_id in no_market_state.tools:
		no_market_state.tools[tool_id] = true
	no_market_state.complete_research("earth_buildings")
	assert(no_market_state.can_advance_to(SettlementState.Era.EARTH, 4, 4))

	assert(state.advance_era(SettlementState.Era.EARTH, 4, 4))

	state.buildings = {"earth_assembly": 1, "smithy": 1, "earth_market": 1, "toilet_earth_lvl3": 1}
	state.clay = 5
	state.money = 10
	state.trade_sales = 3
	state.tools["shovel"] = true
	state.tools["hoe"] = true
	assert(state.can_advance_to(SettlementState.Era.CLAY, 4, 4))
	assert(state.advance_era(SettlementState.Era.CLAY, 4, 4))
	
	state.buildings = {"clay_lodge": 1, "clay_market": 1, "toilet_clay_lvl3": 1}
	state.water = 4
	state.logs = 10
	state.money = 10
	assert(state.can_advance_to(SettlementState.Era.WOOD, 4, 4))
	assert(state.advance_era(SettlementState.Era.WOOD, 4, 4))

	state.buildings = {"wood_town_hall": 1, "wood_market": 1, "sawmill": 1, "house_lvl3": 1, "toilet_wood_lvl3": 1}
	state.money = 15
	state.tools["pickaxe"] = true
	assert(state.can_advance_to(SettlementState.Era.STONE, 4, 4))
	assert(state.advance_era(SettlementState.Era.STONE, 4, 4))

	state.buildings = {"stone_prefecture": 1, "stone_market": 1, "masonry_workshop": 1, "stone_house": 1, "toilet_stone_lvl3": 1}
	state.stone = 20
	state.money = 20
	assert(state.can_advance_to(SettlementState.Era.BRICK, 4, 4))

	assert(SettlementRulesScript.volunteer_can_arrive(1, 2, 60.0))
	assert(not SettlementRulesScript.volunteer_can_arrive(0, 2, 60.0))
	assert(SettlementRulesScript.should_citizen_leave(5.0))
	assert(not SettlementRulesScript.should_citizen_leave(15.0))
	assert(SettlementRulesScript.is_satisfaction_warning(20.0))
	assert(not SettlementRulesScript.is_satisfaction_warning(40.0))


static func _test_work_schedule_wellbeing() -> void:
	var short_day: int = SettlementRulesScript.daily_wellbeing_change(true, 1.0, 1.0, 6)
	var long_day: int = SettlementRulesScript.daily_wellbeing_change(true, 1.0, 1.0, 10)
	assert(short_day > long_day)
	assert(SettlementRulesScript.production_multiplier(10) > SettlementRulesScript.production_multiplier(6))


static func _test_tent_survival_rules() -> void:
	assert(TentEraSurvivalRulesScript.weather_for_day(1) == TentEraSurvivalRulesScript.Weather.WARMING)
	assert(TentEraSurvivalRulesScript.weather_for_day(2) == TentEraSurvivalRulesScript.Weather.COOLING)
	assert(TentEraSurvivalRulesScript.hourly_wellbeing_loss(false, true, 2.0, true) == 6)
	assert(TentEraSurvivalRulesScript.hourly_wellbeing_loss(true, false, 12.0, false) == 2)
	assert(TentEraSurvivalRulesScript.daily_food_consumption(4, 2.0) == 5)
	assert(TentEraSurvivalRulesScript.daily_food_consumption(4, 12.0) == 4)
	var rain_loss: Dictionary = TentEraSurvivalRulesScript.rain_hourly_decay_losses({"food": 16, "branches": 1})
	assert(int(rain_loss.food) == 1 and int(rain_loss.branches) == 1)


static func _test_clock_wraps_and_reports_elapsed_minutes() -> void:
	# The clock no longer moves time — the calendar does (`world_environment.md`
	# §4). What it still owns is reporting which whole minutes went by, across
	# midnight and across a jump alike.
	var clock := SimulationClock.new()
	assert(clock.hour() == 8)
	clock.minutes = 1439.0
	assert(clock.elapsed_minutes().is_empty())
	clock.calendar.advance(2.0, 1.0)
	var elapsed := clock.elapsed_minutes()
	assert(elapsed.size() == 2)
	assert(elapsed[0] == 0 and elapsed[1] == 1)
	assert(clock.hour() == 0 and clock.minute() == 1)


static func _test_day_cycle_schedule() -> void:
	var cycle := SimulationDayCycle.new()
	cycle.clock.set_time(8 * 60 + 59)
	cycle.clock.calendar.advance(1.0, 1.0)
	var meal_events := cycle.collect_events(8)
	assert(meal_events.size() == 1)
	assert(meal_events[0].kind == SimulationDayEvent.Kind.MEAL and meal_events[0].hour == 9)
	assert(cycle.events_for_minute(9 * 60, 8).is_empty())

	var afternoon_events := cycle.events_for_minute(16 * 60, 8)
	assert(afternoon_events.size() == 2)
	assert(afternoon_events[0].kind == SimulationDayEvent.Kind.PARK_REST and afternoon_events[0].cooks_only)
	assert(afternoon_events[1].kind == SimulationDayEvent.Kind.WORKDAY_ENDED)

	var midnight_events := cycle.events_for_minute(0, 8)
	assert(midnight_events.size() == 1 and midnight_events[0].kind == SimulationDayEvent.Kind.DAY_STARTED)


static func _test_workforce_policy() -> void:
	var world := {"hour": 9, "warehouses": 1, "sawmills": 1, "trees": 1, "farms": 0, "dig_sites": 0, "schools": 0, "construction_sites": 0, "has_canteen": false, "has_factory_job": false, "has_engineer_job": false, "has_bucket": false, "water_sources": 2, "water": 0, "population": 3}
	var forester := {"specialization": "forestry", "permanent_role": "forestry", "player_controlled": false, "blocked_by_storage": false, "training_role": "", "training_days_completed": 0}
	assert(WorkforcePolicy.role_for(forester, world) == "forestry")
	assert(WorkforcePolicy.can_assign(forester, world))
	var no_job := {"specialization": "forestry", "player_controlled": false, "blocked_by_storage": false}
	assert(WorkforcePolicy.role_for(no_job, world) == "")
	assert(not WorkforcePolicy.can_assign(no_job, world))
	var daily_ordered := {"specialization": "unassigned", "daily_order_role": "gather_branches", "player_controlled": false, "blocked_by_storage": false}
	assert(WorkforcePolicy.role_for(daily_ordered, world) == "gather_branches")
	assert(WorkforcePolicy.can_assign(daily_ordered, world))
	world.hour = 7
	assert(not WorkforcePolicy.can_assign(daily_ordered, world))
	world.hour = 9
	world.sawmills = 1
	world.trees = 1
	assert(WorkforcePolicy.permanent_vacancy_for(forester, world) == "forestry")
	forester.permanent_role = "farming"
	assert(WorkforcePolicy.role_for(forester, world) == "farming")


static func _test_overtime_sources_are_independent() -> void:
	var citizen := Citizen.new()
	assert(citizen.activate_overtime(2, "settlement", 1))
	assert(citizen.activate_overtime(2, "workplace", 1))
	assert(citizen.has_overtime_source("settlement", 1))
	assert(citizen.has_overtime_source("workplace", 1))
	citizen.deactivate_overtime("workplace")
	assert(citizen.has_overtime_source("settlement", 1))
	assert(not citizen.activate_overtime(2, "settlement", 1))
	assert(citizen.activate_overtime(3, "settlement", 2))
	citizen.free()


static func _test_cheer_up_mechanic() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	assert(not state.cheer_up_used_today)
	state.wellbeing = 70
	assert(state.apply_cheer_up())
	assert(state.wellbeing == 75)
	assert(state.cheer_up_used_today)
	assert(not state.apply_cheer_up())
	assert(state.wellbeing == 75)
	state.wellbeing = 98
	state.cheer_up_used_today = false
	assert(state.apply_cheer_up())
	assert(state.wellbeing == 100)
	state.apply_tent_start()
	assert(not state.cheer_up_used_today)


static func _test_resource_pile_decay_rates() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	var loss := SettlementRulesScript.open_air_storage_decay_losses({"food": 10, "grass": 10, "water": 10}, 20.0, 0.0)
	assert(loss.has("food"))


static func _test_party_stash_invariants() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	# The party stash starts empty; its physical authored entity fills it at runtime.
	assert(state.amount("food") == 0)
	assert(state.amount("water") == 0)
	var physical_inventory := {"food": 3}
	state.bind_starter_stash_inventory(&"test_stash", physical_inventory)
	var second_inventory := {"food": 4, "water": 2}
	state.bind_starter_stash_inventory(&"test_cart", second_inventory)
	assert(state.starter_stash_amount("food") == 7,
		"starter-stash queries must aggregate independent physical containers")
	state.add("food", 2)
	assert(state.starter_stash_amount("food") == 9)
	assert(int(physical_inventory["food"]) + int(second_inventory["food"]) == 9,
		"settlement and physical starter stashes must share their inventories")
	state.add("food", -6)
	assert(state.starter_stash_amount("food") == 3,
		"consumption must drain physical containers rather than an aggregate copy")
	physical_inventory["water"] = 4
	assert(state.starter_stash_amount("water") == 6,
		"physical inventory mutations must be visible without a sync pass")
	state.unbind_starter_stash_inventory(&"test_cart")
	assert(state.starter_stash_amount("water") == 4,
		"a consumed or removed container must leave the aggregate")
