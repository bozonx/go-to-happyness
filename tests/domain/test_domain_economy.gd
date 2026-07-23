class_name TestDomainEconomy
extends RefCounted

const SettlementRulesScript = preload("res://game/features/settlement/domain/settlement_rules.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const WeatherStateScript = preload("res://game/features/simulation/domain/weather_state.gd")


static func run_all() -> void:
	_test_settlement_economy()
	_test_tent_start_config()
	_test_virtual_stockpile_migration()
	_test_progression_and_volunteers()
	_test_work_schedule_wellbeing()
	_test_tent_survival_rules()
	_test_clock_wraps_and_reports_elapsed_minutes()
	_test_day_cycle_schedule()
	_test_weather_state()
	_test_workforce_policy()
	_test_overtime_sources_are_independent()
	_test_cheer_up_mechanic()
	_test_resource_pile_decay_rates()
	_test_backpack_invariants()


static func _test_settlement_economy() -> void:
	var state := SettlementState.new()
	assert(state.money == 20 and state.wood == 0 and state.food == 0)
	state.branches = 12
	state.grass = 4
	assert(state.can_afford_building("warehouse"))
	assert(state.pay_for_building("warehouse"))
	assert(state.warehouse_ever_built)
	state.migrate_virtual_to_warehouse(1)
	assert(state.branches == 12 and state.grass == 4)
	assert(state.storage_capacity(1) == 24)
	assert(not state.reserve_storage_room_for("grass", 1, 0))
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
	assert(state.amount("food") == SettlementState.TENT_STARTING_FOOD)
	assert(state.amount("water") == SettlementState.TENT_STARTING_WATER)
	assert(state.branches == 0 and state.grass == 0)
	assert(bool(state.equipment.flint_steel.owned))
	assert(int(state.equipment.construction_gloves.sets) == 1)
	assert(state.construction_gloves_available())
	assert(state.wear_construction_gloves(100.0) == false)
	state.add_construction_glove_set()
	assert(state.construction_gloves_available())
	assert(state.is_building_unlocked("warehouse"))
	assert(state.is_building_unlocked("campfire"))
	assert(state.is_building_unlocked("tent"))
	assert(state.is_building_unlocked("cook_campfire"))
	assert(state.is_building_unlocked("dew_collector"))
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


static func _test_virtual_stockpile_migration() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	assert(state.uses_virtual_storage())
	state.add("branches", 3)
	assert(state.amount("branches") == 3)
	state.add_warehouse("warehouse")
	var overflow := state.migrate_virtual_to_warehouse(1)
	assert(not state.uses_virtual_storage())
	assert(state.branches == 3)
	assert(overflow.is_empty())
	assert(state.virtual_stock.is_empty())

	var small_overflow_state := SettlementState.new()
	small_overflow_state.apply_tent_start()
	small_overflow_state.add("branches", 4)
	small_overflow_state.add_warehouse("warehouse")
	var small_overflow := small_overflow_state.migrate_virtual_to_warehouse(1)
	assert(small_overflow.has("tarp"))
	assert(small_overflow["tarp"] == 1)

	var overflow_state := SettlementState.new()
	overflow_state.apply_tent_start()
	overflow_state.add("branches", 200)
	overflow_state.add_warehouse("warehouse")
	var big_overflow := overflow_state.migrate_virtual_to_warehouse(1)
	assert(big_overflow.has("branches"))
	assert(big_overflow["branches"] == 176)
	assert(overflow_state.branches <= overflow_state.storage_capacity(1))

	var debug_state := SettlementState.new()
	debug_state.apply_tent_start()
	var debug_grants := {"branches": 36, "grass": 20, "water": 24, "food": 18, "hides": 8, "goods": 8, "logs": 16, "wood": 10, "soil": 28, "clay": 22, "boards": 18, "stone": 15, "bricks": 14}
	var starting_food := debug_state.amount("food")
	for resource_type in debug_grants:
		debug_state.add(resource_type, debug_grants[resource_type])
	for i in range(13):
		debug_state.add_warehouse("warehouse")
	var debug_overflow := debug_state.migrate_virtual_to_warehouse(13)
	assert(debug_overflow.is_empty())
	for resource_type in debug_grants:
		var expected: int = debug_grants[resource_type]
		if resource_type == "food":
			expected += starting_food
		assert(debug_state.amount(resource_type) >= expected)
	assert(debug_state.virtual_stock.is_empty())


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
	assert(TentEraSurvivalRulesScript.hourly_wellbeing_loss(false, true, TentEraSurvivalRulesScript.Weather.COOLING, true) == 6)
	assert(TentEraSurvivalRulesScript.hourly_wellbeing_loss(true, false, TentEraSurvivalRulesScript.Weather.WARMING, false) == 2)
	assert(TentEraSurvivalRulesScript.daily_food_consumption(4, TentEraSurvivalRulesScript.Weather.COOLING) == 5)
	var rain_loss: Dictionary = TentEraSurvivalRulesScript.rain_hourly_decay_losses({"food": 16, "branches": 1})
	assert(int(rain_loss.food) == 1 and int(rain_loss.branches) == 1)


static func _test_clock_wraps_and_reports_elapsed_minutes() -> void:
	var clock := SimulationClock.new()
	assert(clock.hour() == 8)
	clock.minutes = 1439.0
	assert(clock.advance(0.0, 1.0).is_empty())
	var elapsed := clock.advance(2.0, 1.0)
	assert(elapsed.size() == 2)
	assert(elapsed[0] == 0 and elapsed[1] == 1)
	assert(clock.hour() == 0 and clock.minute() == 1)


static func _test_day_cycle_schedule() -> void:
	var cycle := SimulationDayCycle.new()
	cycle.clock.set_time(8 * 60 + 59)
	var meal_events := cycle.advance(1.0, 1.0, 8)
	assert(meal_events.size() == 1)
	assert(meal_events[0].kind == SimulationDayEvent.Kind.MEAL and meal_events[0].hour == 9)
	assert(cycle.events_for_minute(9 * 60, 8).is_empty())

	var afternoon_events := cycle.events_for_minute(16 * 60, 8)
	assert(afternoon_events.size() == 2)
	assert(afternoon_events[0].kind == SimulationDayEvent.Kind.PARK_REST and afternoon_events[0].cooks_only)
	assert(afternoon_events[1].kind == SimulationDayEvent.Kind.WORKDAY_ENDED)

	var midnight_events := cycle.events_for_minute(0, 8)
	assert(midnight_events.size() == 1 and midnight_events[0].kind == SimulationDayEvent.Kind.DAY_STARTED)


static func _test_weather_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var clear: RefCounted = WeatherStateScript.new()
	clear.new_day(TentEraSurvivalRulesScript.Weather.WARMING, rng, 6 * 60)
	assert(clear.intensity_at(6 * 60) == 0.0)
	assert(clear.intensity_at(12 * 60) == 0.0)
	assert(clear.cloud_phase_at(12 * 60) in [WeatherStateScript.CloudPhase.CLEAR, WeatherStateScript.CloudPhase.FAIR, WeatherStateScript.CloudPhase.PARTLY_CLOUDY])
	assert(not clear.update(12 * 60.0))
	assert(not clear.is_raining)

	var rain: RefCounted = WeatherStateScript.new()
	rain.new_day(TentEraSurvivalRulesScript.Weather.RAIN, rng, 6 * 60)
	assert(rain.rain_start_minute >= 6 * 60)
	assert(rain.cloud_cover_at(rain.rain_start_minute) >= 0.9)
	assert(rain.cloud_phase_at(rain.rain_start_minute) == WeatherStateScript.CloudPhase.STORM)
	assert(rain.cloud_cover_at(maxf(0.0, rain.rain_start_minute - 180.0)) < rain.cloud_cover_at(rain.rain_start_minute))


static func _test_workforce_policy() -> void:
	var world := {"hour": 9, "warehouses": 1, "sawmills": 1, "trees": 1, "farms": 0, "dig_sites": 0, "schools": 0, "construction_sites": 0, "has_canteen": false, "has_factory_job": false, "has_engineer_job": false, "has_bucket": false, "ponds": 2, "water": 0, "population": 3}
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


static func _test_backpack_invariants() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	assert(state.amount("food") == SettlementState.TENT_STARTING_FOOD)
	assert(state.amount("water") == SettlementState.TENT_STARTING_WATER)
