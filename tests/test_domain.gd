extends SceneTree

const SettlementRulesScript = preload("res://game/features/settlement/domain/settlement_rules.gd")
const GridRouteServiceScript = preload("res://game/features/world/application/grid_route_service.gd")


func _init() -> void:
	_test_settlement_economy()
	_test_progression_and_volunteers()
	_test_work_schedule_wellbeing()
	_test_clock_wraps_and_reports_elapsed_minutes()
	_test_day_cycle_schedule()
	_test_sawmill_rules()
	_test_workforce_policy()
	_test_citizen_task_state()
	_test_grid_routing()
	_test_citizen_decision_context()
	_test_construction_progress()
	_test_construction_service_cancellation()
	_test_completed_construction_cleans_temporary_ui()
	_test_demolition_service_completion()
	_test_building_registry()
	_test_school_and_seller_rules()
	_test_courier_metadata()
	_test_construction_delivery_stays_scheduled()
	_test_freelance_construction_skill_cap()
	_test_courier_equipment_capacity()
	_test_research_mechanics()
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
	state.buildings = {"campfire": 1, "trade_tent": 1, "craft_tent_lvl3": 1, "living_tent_lvl3": 1, "toilet_tent_lvl3": 1}
	state.food = 4
	state.water = 4
	state.trade_sales = 1
	for tool_id in state.tools:
		state.tools[tool_id] = true
	assert(state.can_advance_to(SettlementState.Era.EARTH, 4, 4))
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


func _test_day_cycle_schedule() -> void:
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
	assert(cycle.current_day == 2)
	cycle.clock.set_time(0)
	assert(not cycle.is_work_time(8, false) and cycle.is_work_time(8, true))


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
	assert(WorkforcePolicy.role_for(forester, world) == "forestry")
	assert(WorkforcePolicy.can_assign(forester, world))
	world.assigned_roles = {"forestry": 1}
	world.farms = 1
	world.food = 0
	assert(WorkforcePolicy.role_for(forester, world) == "farming")
	world.water = 20
	world.food = 20
	world.assigned_roles = {"farming": 1}
	world.dig_sites = 1
	assert(WorkforcePolicy.role_for(forester, world) == "excavation")
	world.assigned_roles = {"excavation": 1}
	world.sawmills = 1
	world.trees = 1
	assert(WorkforcePolicy.permanent_vacancy_for(forester, world) == "forestry")
	forester.permanent_role = "farming"
	assert(WorkforcePolicy.role_for(forester, world) == "farming")
	var early_builder := {"specialization": "builder", "manual_role": "", "player_controlled": false, "blocked_by_storage": false}
	var early_world := {"era": SettlementState.Era.WOOD, "construction_sites": 1, "assigned_roles": {}, "population": 2}
	assert(WorkforcePolicy.role_for(early_builder, early_world) == "construction")
	assert(WorkforcePolicy.permanent_vacancy_for(early_builder, early_world) == "construction")
	early_world.builder_jobs = 0
	assert(WorkforcePolicy.permanent_vacancy_for(early_builder, early_world) == "construction")
	early_world.assigned_roles = {"construction": 1}
	assert(WorkforcePolicy.role_for(early_builder, early_world) != "construction")
	var guild_world := {"era": SettlementState.Era.STONE, "construction_sites": 1, "builder_jobs": 1, "assigned_roles": {}, "population": 2}
	assert(WorkforcePolicy.permanent_vacancy_for(early_builder, guild_world) == "construction")
	var employed_cook := {"specialization": "cook", "permanent_role": "farming", "manual_role": "", "player_controlled": false, "blocked_by_storage": false}
	var cook_world := {"hour": 9, "farms": 1, "warehouses": 1, "trees": 0, "construction_sites": 0, "cooking_jobs": 1}
	assert(WorkforcePolicy.can_assign(employed_cook, cook_world))
	var field_officer := {"specialization": "official", "permanent_role": "official", "manual_role": "", "player_controlled": false, "blocked_by_storage": false}
	assert(WorkforcePolicy.can_assign(field_officer, {"official_jobs": 0}))
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


func _test_grid_routing() -> void:
	var blocked: Dictionary = {
		Vector2i(1, 0): true,
		Vector2i(1, 1): true,
		Vector2i(1, 2): true
	}
	var router = GridRouteServiceScript.new()
	router.configure(
		func(position: Vector3) -> Vector2i: return Vector2i(floori(position.x), floori(position.z)),
		func(cell: Vector2i) -> Vector3: return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5),
		func(cell: Vector2i) -> bool: return cell.x >= 0 and cell.x < 3 and cell.y >= 0 and cell.y < 3,
		func(cell: Vector2i) -> bool: return blocked.has(cell)
	)
	var unreachable: RouteResult = router.find_route(Vector3(0.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5))
	assert(not unreachable.reachable and unreachable.waypoints.is_empty())

	blocked.erase(Vector2i(1, 2))
	var route: RouteResult = router.find_route(Vector3(0.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5))
	assert(route.reachable and route.arrival_position == Vector3(2.5, 0.0, 0.5))
	for waypoint in route.waypoints:
		assert(not blocked.has(Vector2i(floori(waypoint.x), floori(waypoint.z))))


func _test_construction_progress() -> void:
	assert(is_equal_approx(ConstructionProgress.advance(0.25, 2.0, 4.0, 1.0), 0.75))
	assert(ConstructionProgress.advance(0.9, 4.0, 4.0, 1.0) == 1.0)


func _test_construction_service_cancellation() -> void:
	var scene_root := Node3D.new()
	var runtime := ConstructionRuntime.new()
	runtime.scene_root = scene_root
	runtime.settlement = SettlementState.new()
	runtime.building_registry = BuildingRegistry.new()
	runtime.citizens = []
	runtime.workers_changed = func() -> void: pass
	runtime.navigation_changed = func() -> void: pass
	var service := ConstructionService.new()
	service.configure(runtime)

	var cell := Vector2i(2, 3)
	runtime.building_registry.reserve(cell, Vector3(2.0, 0.0, 3.0), Vector2i(5, 5))
	var site := service.start_site(cell, "warehouse", Vector3(2.0, 0.0, 3.0))
	assert(service.has_site(site.node))
	assert(service.accept_delivery(site.node, "boards", 1))
	assert(site.delivered_materials.boards == 1)
	assert(service.cancel_site(site.node))
	assert(service.sites.is_empty() and runtime.building_registry.record_at_cell(cell) == null)
	scene_root.free()


func _test_completed_construction_cleans_temporary_ui() -> void:
	var scene_root := Node3D.new()
	var runtime := ConstructionRuntime.new()
	runtime.scene_root = scene_root
	runtime.settlement = SettlementState.new()
	runtime.building_registry = BuildingRegistry.new()
	runtime.citizens = []
	runtime.duration = 1.0
	runtime.builder_power = func(_site: Node3D) -> float: return 1.0
	runtime.builder_count = func(_site: Node3D) -> int: return 1
	runtime.set_status = func(_text: String) -> void: pass
	runtime.workers_changed = func() -> void: pass
	runtime.building_completed = func(_cell: Vector2i, _type: String, _position: Vector3, _building: Node3D, _blueprint: Dictionary) -> void: pass
	var service := ConstructionService.new()
	service.configure(runtime)
	var site := service.start_site(Vector2i.ZERO, "warehouse", Vector3.ZERO)
	site.delivered_materials = site.required_materials.duplicate(true)
	service.tick(1.0)
	assert(site.node.get_node("SupplyLabel").is_queued_for_deletion())
	assert(site.node.get_node("ConstructionSelector").is_queued_for_deletion())
	scene_root.free()


func _test_demolition_service_completion() -> void:
	var completed: Array[DemolitionSite] = []
	var runtime := DemolitionRuntime.new()
	runtime.duration = 3.0
	runtime.building_power = func(_building: Node3D) -> float: return 1.0
	runtime.is_ready = func(_site: DemolitionSite) -> bool: return true
	runtime.completed = func(site: DemolitionSite) -> void: completed.append(site)
	var service := DemolitionService.new()
	service.configure(runtime)
	var building := Node3D.new()
	assert(service.mark(building, "warehouse"))
	service.tick(3.0)
	assert(service.sites.is_empty() and completed.size() == 1 and completed[0].building_type == "warehouse")
	building.free()


func _test_building_registry() -> void:
	var registry := BuildingRegistry.new()
	var first := registry.reserve(Vector2i(0, 0), Vector3.ZERO, Vector2i(2, 2))
	assert(first.cell == Vector2i(0, 0) and first.node == null)
	assert(not registry.is_footprint_clear(Vector3(1.0, 0.0, 0.0), Vector2i(2, 2), 0.0))
	assert(registry.is_footprint_clear(Vector3(4.0, 0.0, 0.0), Vector2i(2, 2), 0.0))

	var building := Node3D.new()
	building.set_meta("housing_capacity", 4)
	building.set_meta("service_position", Vector3(0.5, 0.0, 0.5))
	assert(registry.attach_node(Vector2i(0, 0), building) == first)
	assert(registry.housing_capacity() == 4)
	assert(registry.building_at_service_position(Vector3(0.5, 0.0, 0.5)) == building)

	registry.reserve(Vector2i(4, 0), Vector3(4.0, 0.0, 0.0), Vector2i(2, 2))
	assert(registry.cancel_reservation(Vector2i(4, 0)) != null)
	assert(registry.remove_node(building) == first and registry.records().is_empty())
	building.free()


func _test_school_and_seller_rules() -> void:
	var seller := {"specialization": "seller", "manual_role": "", "player_controlled": false, "blocked_by_storage": false}
	var world := {"hour": 9, "markets": 0}
	assert(not WorkforcePolicy.can_assign(seller, world))
	world.markets = 1
	assert(WorkforcePolicy.can_assign(seller, world))

	var citizen := Citizen.new()
	citizen.skills["farming"] = 0.5
	citizen.training_role = "farming"
	# State.STUDYING is index 20
	citizen.state = 20
	
	# Test studying without teacher
	citizen.finish_school_day(false)
	assert(citizen.skills["farming"] == 0.5) # no increase
	assert(citizen.state == 0) # State.IDLE
	
	# Test studying with teacher
	citizen.training_role = "farming"
	citizen.state = 20
	citizen.finish_school_day(true)
	assert(citizen.skills["farming"] > 0.5) # increase!
	citizen.free()

func _test_courier_metadata() -> void:
	var citizen := Citizen.new()
	var courier_target := Citizen.new()
	citizen.courier_target = courier_target
	
	# Initially metadata is not set
	assert(not courier_target.has_meta("last_courier_pickup"))
	
	# Simulate pickup
	var cargo := courier_target.take_pending_resource()
	courier_target.set_meta("last_courier_pickup", 100.0)
	
	assert(courier_target.get_meta("last_courier_pickup") == 100.0)
	
	citizen.free()
	courier_target.free()


func _test_construction_delivery_stays_scheduled() -> void:
	var courier := Citizen.new()
	courier.state = Citizen.State.TO_CONSTRUCTION_PICKUP
	courier.carried_amount = 1
	assert(courier.has_active_delivery())
	assert(not courier.is_available_for_schedule())
	courier.state = Citizen.State.TO_CONSTRUCTION_SITE
	assert(courier.has_active_delivery())
	assert(not courier.is_available_for_schedule())
	courier.free()


func _test_freelance_construction_skill_cap() -> void:
	var worker := Citizen.new()
	worker.skills = {"construction": Citizen.FREELANCE_CONSTRUCTION_SKILL_CAP - 0.00001}
	worker.active_role = "construction"
	worker.employment_state = Citizen.EmploymentState.FREELANCE
	worker.satisfaction_tick = 10.0
	worker._update_satisfaction(0.0)
	assert(float(worker.skills.construction) <= Citizen.FREELANCE_CONSTRUCTION_SKILL_CAP)
	worker.employment_state = Citizen.EmploymentState.EMPLOYED
	worker.satisfaction_tick = 10.0
	worker._update_satisfaction(0.0)
	assert(float(worker.skills.construction) > Citizen.FREELANCE_CONSTRUCTION_SKILL_CAP)
	worker.free()


func _test_courier_equipment_capacity() -> void:
	var courier := Citizen.new()
	courier.set_courier_equipment("reinforced_backpack")
	assert(courier.courier_capacity() == 4)
	courier.register_pending_resource("boards", 6)
	var cargo := courier.take_pending_resource(courier.courier_capacity())
	assert(int(cargo.amount) == 4)
	assert(int(courier.pending_resources.boards) == 2)
	courier.free()


func _test_research_mechanics() -> void:
	var state := SettlementState.new()
	assert(state.unlocked_building_levels.get("living_tent", false))
	assert(not state.unlocked_building_levels.get("living_tent_lvl2", false))
	assert(not state.unlocked_building_levels.get("craft_tent", false))
	
	state.branches = 5
	state.grass = 5
	assert(state.can_afford_research("craft_tent"))
	assert(state.can_start_building_research("craft_tent"))
	assert(not state.can_start_building_research("craft_tent_lvl2"))
	assert(state.pay_for_research("craft_tent"))
	assert(state.branches == 0 and state.grass == 0)
	state.unlocked_building_levels["craft_tent"] = true
	state.branches = 10
	state.grass = 8
	assert(state.can_start_building_research("craft_tent_lvl2"))
	assert(not state.can_afford_building("dugout_kitchen"))
	state.era = SettlementState.Era.EARTH
	state.soil = 8
	state.branches = 4
	assert(state.can_start_building_research("dugout_kitchen"))
	assert(BuildingCatalog.kitchen_food_capacity("cook_campfire") == 4)
	assert(BuildingCatalog.kitchen_food_capacity("brick_restaurant") == 20)
	
	var citizen := Citizen.new()
	citizen._ready()
	citizen.state = Citizen.State.RESEARCHING
	assert(not citizen.is_available_for_schedule())
	citizen.free()
