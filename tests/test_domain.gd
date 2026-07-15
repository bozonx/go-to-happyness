extends SceneTree

const SettlementRulesScript = preload("res://game/features/settlement/domain/settlement_rules.gd")
const TentEraSurvivalRulesScript = preload("res://game/features/settlement/domain/tent_era_survival_rules.gd")
const GridRouteServiceScript = preload("res://game/features/routing/application/grid_route_service.gd")
const RouteRequestScript = preload("res://game/features/routing/application/route_request.gd")
const BuildingQueueServiceScript = preload("res://game/features/citizens/application/building_queue_service.gd")
const BuildingAvailabilityServiceScript = preload("res://game/features/buildings/application/building_availability_service.gd")
const BuildingResearchServiceScript = preload("res://game/features/buildings/application/building_research_service.gd")
const CitizenLivingStatusServiceScript = preload("res://game/features/citizens/application/citizen_living_status_service.gd")
const CanteenServiceScript = preload("res://game/features/logistics/application/canteen_service.gd")
const StorageDeliveryServiceScript = preload("res://game/features/logistics/application/storage_delivery_service.gd")
const TradeServiceScript = preload("res://game/features/logistics/application/trade_service.gd")
const TradeOrderScript = preload("res://game/features/logistics/domain/trade_order.gd")
const WaterCollectorServiceScript = preload("res://game/features/logistics/application/water_collector_service.gd")
const FireSourceStateScript = preload("res://game/features/settlement/domain/fire_source_state.gd")
const CitizenStatusEffectScript = preload("res://game/features/citizens/domain/citizen_status_effect.gd")
const TrailFieldServiceScript = preload("res://game/features/roads/application/trail_field_service.gd")


class FakeCanteenSimulation extends Node:
	var canteen: Node3D
	var citizens: Array[Citizen] = []
	var canteen_food := 2
	var last_interface_message := ""
	var workers_updated := false

	func _is_fire_lit(_canteen: Node3D) -> bool:
		return true

	func _has_cook() -> bool:
		return true

	func _update_interface(message: String) -> void:
		last_interface_message = message

	func _is_work_time() -> bool:
		return true

	func _update_workers() -> void:
		workers_updated = true


class FakeCourierDispatcher extends RefCounted:
	var completed := 0

	func complete_for(_worker: Citizen) -> void:
		completed += 1


class FakeStorageSimulation extends Node:
	var settlement := SettlementState.new()
	var warehouse_positions: Array[Vector3] = []
	var courier_dispatcher := FakeCourierDispatcher.new()
	var last_interface_message := ""
	var dispatch_requested := false
	var leisure_worker: Citizen
	var dropped_piles: Array[Dictionary] = []

	func _update_interface(message: String) -> void:
		last_interface_message = message

	func _request_courier_dispatch() -> void:
		dispatch_requested = true

	func _send_citizen_to_leisure(worker: Citizen) -> void:
		leisure_worker = worker

	func _drop_resource_pile(position: Vector3, resource_type: String, amount: int) -> void:
		dropped_piles.append({"position": position, "resource_type": resource_type, "amount": amount})


class FakeTradeSimulation extends Node:
	var queued_trades: Array = []
	var pending_trades: Dictionary = {}
	var total_minutes := 0.0
	var last_interface_message := ""

	func _total_game_minutes() -> float:
		return total_minutes

	func _update_interface(message: String) -> void:
		last_interface_message = message


class FakeWaterCollectorSimulation extends Node:
	var water_collectors: Array[Dictionary] = []


func _init() -> void:
	_test_settlement_economy()
	_test_tent_start_config()
	_test_virtual_stockpile_migration()
	_test_progression_and_volunteers()
	_test_work_schedule_wellbeing()
	_test_tent_survival_rules()
	_test_clock_wraps_and_reports_elapsed_minutes()
	_test_day_cycle_schedule()
	_test_sawmill_rules()
	_test_workforce_policy()
	_test_citizen_task_state()
	_test_citizen_state_display_queue()
	_test_grid_routing()
	_test_weighted_grid_routing()
	_test_navigation_grid_revision()
	_test_navigation_recovery_guards()
	_test_trail_field()
	_test_citizen_replans_on_navigation_revision()
	_test_citizen_route_failure_marks_action_failed()
	_test_building_queue_routing()
	_test_canteen_meal_requests()
	_test_construction_progress()
	_test_construction_service_cancellation()
	_test_completed_construction_cleans_temporary_ui()
	_test_demolition_service_completion()
	_test_building_registry()
	_test_school_and_seller_rules()
	_test_courier_metadata()
	_test_construction_delivery_stays_scheduled()
	_test_daily_order_construction_skill_cap()
	_test_daily_order_role_recheck_cooldown()
	_test_courier_equipment_capacity()
	_test_research_mechanics()
	_test_trade_order_model()
	_test_trade_service_entrance_expedition_walks_to_sign_before_departure()
	_test_fire_source_state()
	_test_citizen_status_effects()
	_test_storage_delivery_service()
	_test_building_availability_service()
	_test_citizen_living_status_service()
	_test_building_research_service()
	_test_cheer_up_mechanic()
	_test_water_collector_service()
	quit(0)


func _test_settlement_economy() -> void:
	var state := SettlementState.new()
	state.warehouse_ever_built = true
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

	# Verify Brick house costs bricks and boards
	state.era = SettlementState.Era.BRICK
	state.bricks = 22
	state.boards = 10
	assert(state.can_afford_building("brick_house"))
	assert(state.pay_for_building("brick_house"))
	assert(state.bricks == 0 and state.boards == 0)


func _test_tent_start_config() -> void:
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
	state.buildings["warehouse"] = 1
	state.warehouse_ever_built = true
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
	state.warehouse_ever_built = true
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
	storage_state.branches = 24
	storage_state.buildings["warehouse"] = 1
	storage_state.warehouse_ever_built = true
	storage_state.ensure_storage_defaults(1)
	assert(storage_state.storage_availability_for("grass", 1, 1) == SettlementState.StorageAvailability.NO_ROOM)
	storage_state.buildings["warehouse"] = 2
	storage_state.adjust_storage_limit("grass", 1.0, 2)
	assert(storage_state.storage_availability_for("grass", 1, 1) == SettlementState.StorageAvailability.OK)
	var debug_storage_state := SettlementState.new()
	debug_storage_state.apply_tent_start()
	debug_storage_state.ensure_storage_defaults(0)
	debug_storage_state.debug_storage_capacity_bonus = 100
	debug_storage_state.buildings["warehouse"] = 1
	debug_storage_state.ensure_storage_defaults(1)
	assert(debug_storage_state.storage_capacity(1) == 124)
	assert(debug_storage_state.reserve_storage_room_for("branches", 3, 1))
	var decay := SettlementRulesScript.open_air_storage_decay_losses({"food": 16, "grass": 10}, 26.0, 0.0)
	assert(int(decay.food) == 2 and int(decay.grass) == 1)


func _test_virtual_stockpile_migration() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	assert(state.uses_virtual_storage())
	# A small amount that fits into the first open-air warehouse (24 units).
	# Starting food is 16 and water is 4 units, leaving room for 4 branches.
	state.add("branches", 4)
	assert(state.amount("branches") == 4)
	assert(state.branches == 0) # not yet in warehouse
	state.buildings["warehouse"] = 1
	var overflow := state.migrate_virtual_to_warehouse(1)
	assert(not state.uses_virtual_storage())
	assert(state.branches == 4)
	assert(overflow.is_empty())
	assert(state.virtual_stock.is_empty())

	# Overflow scenario: more virtual resources than the first warehouse can hold.
	var overflow_state := SettlementState.new()
	overflow_state.apply_tent_start()
	overflow_state.add("branches", 200)
	overflow_state.buildings["warehouse"] = 1
	var big_overflow := overflow_state.migrate_virtual_to_warehouse(1)
	assert(not big_overflow.is_empty())
	assert(big_overflow.get("branches", 0) > 0)
	assert(overflow_state.branches <= overflow_state.storage_capacity(1))

	# Debug-grant scenario: a large pre-warehouse grant must not become ground piles
	# once the first warehouse is built. A matching capacity bonus lets the migration
	# absorb the whole virtual stock.
	var debug_state := SettlementState.new()
	debug_state.apply_tent_start()
	var debug_grants := {"branches": 36, "grass": 20, "water": 24, "food": 18, "hides": 8, "goods": 8, "logs": 16, "wood": 10, "soil": 28, "clay": 22, "boards": 18, "stone": 15, "bricks": 14}
	var starting_food := debug_state.amount("food")
	var grant_units := 0.0
	for resource_type in debug_grants:
		debug_state.add(resource_type, debug_grants[resource_type])
		grant_units += debug_grants[resource_type] * debug_state.storage_weight(resource_type)
	grant_units += debug_state.amount("food") * debug_state.storage_weight("food")
	debug_state.debug_storage_capacity_bonus = ceili(grant_units)
	debug_state.buildings["warehouse"] = 1
	var debug_overflow := debug_state.migrate_virtual_to_warehouse(1)
	assert(debug_overflow.is_empty())
	for resource_type in debug_grants:
		var expected: int = debug_grants[resource_type]
		if resource_type == "food":
			expected += starting_food
		assert(debug_state.amount(resource_type) >= expected)
	assert(debug_state.virtual_stock.is_empty())


func _test_trade_order_model() -> void:
	var order := TradeOrderScript.entrance_purchase(
		{"kind": "buy_resource", "resource": "food", "quantity": 4, "price": 2},
		Vector3(1.0, 0.0, 0.0),
		Vector3(5.0, 0.0, 0.0)
	)
	assert(order.source_endpoint == TradeOrderScript.ENDPOINT_ENTRANCE_STONE)
	assert(order.destination_endpoint == TradeOrderScript.ENDPOINT_STORAGE)
	assert(order.outside_duration_minutes == 120.0)
	assert(order.reserved_money() == 8)
	assert(order.incoming_resource("food") == 4)
	assert(order.incoming_resource("grass") == 0)


func _test_trade_service_entrance_expedition_walks_to_sign_before_departure() -> void:
	var simulation := FakeTradeSimulation.new()
	var service := TradeServiceScript.new()
	service.configure(simulation)
	var worker := Citizen.new()
	worker.position = Vector3(12.0, 0.0, 0.0)
	var entrance := Vector3(-22.5, 0.0, 1.5)
	var storage := Vector3(2.5, 0.0, 0.5)
	var order := TradeOrderScript.entrance_purchase(
		{"kind": "buy_resource", "resource": "food", "quantity": 4, "price": 2},
		entrance,
		storage
	)

	service.assign_order_to_worker(worker, order)
	assert(simulation.pending_trades.has(worker.get_instance_id()))
	assert(worker.position == Vector3(12.0, 0.0, 0.0))
	assert(worker.state == Citizen.State.TO_TRADE_PICKUP)
	assert(worker.trade_source_position == entrance)
	assert(worker.trade_destination_position == entrance)

	service.on_trade_delivery_finished(worker)
	assert(simulation.pending_trades.has(worker.get_instance_id()))
	assert(service.entrance_expeditions.has(worker.get_instance_id()))
	assert(not worker.visible)
	assert(worker.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(order.return_at_minutes == order.outside_duration_minutes)
	worker.free()
	simulation.free()


func _test_fire_source_state() -> void:
	var fire := FireSourceStateScript.from_values(1, 0, true)
	assert(fire.total_committed_fuel() == 1)
	assert(fire.needs_supply(4))
	fire.reserve(2)
	assert(fire.total_committed_fuel() == 3)
	fire.add_delivered(2)
	assert(fire.fuel == 3 and fire.reserved_fuel == 0 and fire.lit)
	fire.consume(3)
	assert(fire.fuel == 0 and not fire.lit)


func _test_citizen_status_effects() -> void:
	var citizen := Citizen.new()
	citizen.carried_amount = 1
	citizen.storage_delivery_result(false, CitizenStatusEffectScript.STORAGE_NO_WAREHOUSE)
	assert(citizen.carried_amount == 0)
	assert(citizen.blocked_by_storage)
	assert(citizen.has_status_effect(CitizenStatusEffectScript.STORAGE_NO_WAREHOUSE))
	assert(citizen.status_effect_labels().has("No warehouse"))
	citizen.storage_delivery_result(true)
	assert(not citizen.blocked_by_storage)
	assert(not citizen.has_status_effect(CitizenStatusEffectScript.STORAGE_NO_WAREHOUSE))

	citizen.set_status_effect(CitizenStatusEffectScript.SMOKY_EYES, "Smoky eyes", 1.0)
	assert(citizen.has_status_effect(CitizenStatusEffectScript.SMOKY_EYES))
	assert(citizen.status_effect_labels().has("Smoky eyes"))
	citizen.clear_status_effect(CitizenStatusEffectScript.SMOKY_EYES)
	assert(not citizen.has_status_effect(CitizenStatusEffectScript.SMOKY_EYES))
	citizen.free()


func _test_storage_delivery_service() -> void:
	var simulation := FakeStorageSimulation.new()
	var service := StorageDeliveryServiceScript.new()
	service.configure(simulation)
	var worker := Citizen.new()
	simulation.settlement.buildings["warehouse"] = 1
	simulation.settlement.warehouse_ever_built = true
	simulation.warehouse_positions = [Vector3.ZERO]
	simulation.settlement.ensure_storage_defaults(1)
	service.on_resource_delivered(worker, "grass", 1)
	assert(simulation.settlement.grass == 1)
	assert(not worker.blocked_by_storage)
	assert(simulation.dispatch_requested)
	assert(simulation.courier_dispatcher.completed == 1)
	assert(simulation.last_interface_message == "Workers delivered 1 grass to the warehouse.")

	var full_storage_simulation := FakeStorageSimulation.new()
	var full_storage_service := StorageDeliveryServiceScript.new()
	full_storage_service.configure(full_storage_simulation)
	full_storage_simulation.settlement.buildings["warehouse"] = 1
	full_storage_simulation.settlement.warehouse_ever_built = true
	full_storage_simulation.warehouse_positions = [Vector3.ZERO]
	full_storage_simulation.settlement.ensure_storage_defaults(1)
	full_storage_simulation.settlement.grass = int(full_storage_simulation.settlement.storage_limit("grass"))
	var full_storage_worker := Citizen.new()
	full_storage_worker.carried_amount = 1
	full_storage_service.on_resource_delivered(full_storage_worker, "grass", 1)
	assert(full_storage_simulation.settlement.grass == int(full_storage_simulation.settlement.storage_limit("grass")))
	assert(full_storage_simulation.dropped_piles.size() == 1)
	assert(full_storage_simulation.dropped_piles[0].resource_type == "grass")
	assert(not full_storage_worker.blocked_by_storage)

	var no_storage_simulation := FakeStorageSimulation.new()
	var no_storage_service := StorageDeliveryServiceScript.new()
	no_storage_service.configure(no_storage_simulation)
	var blocked_worker := Citizen.new()
	blocked_worker.carried_amount = 1
	no_storage_service.on_resource_delivered(blocked_worker, "grass", 1)
	assert(no_storage_simulation.settlement.grass == 0)
	assert(no_storage_simulation.dropped_piles.size() == 1)
	assert(no_storage_simulation.dropped_piles[0].resource_type == "grass")
	assert(no_storage_simulation.dropped_piles[0].amount == 1)
	assert(not blocked_worker.blocked_by_storage)
	assert(no_storage_simulation.last_interface_message == "No warehouse for 1 grass; the worker left it in a ground pile.")
	worker.free()
	full_storage_worker.free()
	blocked_worker.free()
	simulation.free()
	full_storage_simulation.free()
	no_storage_simulation.free()


func _test_building_availability_service() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	var service := BuildingAvailabilityServiceScript.new()
	service.configure(state)
	assert(service.is_category_available("tent"))
	assert(not service.is_category_available("earth"))
	var warehouse_menu: Dictionary = service.menu_state("warehouse")
	assert(bool(warehouse_menu.visible))
	assert(bool(warehouse_menu.enabled))
	assert(str(warehouse_menu.cost_text) == "free")
	var campfire_menu: Dictionary = service.menu_state("campfire")
	assert(bool(campfire_menu.visible))
	assert(not bool(campfire_menu.enabled))
	var upgrade_menu: Dictionary = service.menu_state("campfire_lvl2")
	assert(not bool(upgrade_menu.visible))
	assert(upgrade_menu.reason == BuildingAvailabilityServiceScript.REASON_UPGRADE_ONLY)
	state.buildings["warehouse"] = 1
	state.warehouse_ever_built = true
	state.branches = 6
	var campfire_placement: Dictionary = service.placement_state("campfire")
	assert(bool(campfire_placement.allowed))
	assert(service.cost_text("campfire") == "4 branches")
	state.branches = 8
	state.grass = 6
	var temporary_tent_placement: Dictionary = service.placement_state("tent")
	assert(bool(temporary_tent_placement.allowed))
	var cooking_campfire_placement: Dictionary = service.placement_state("cook_campfire")
	assert(bool(cooking_campfire_placement.allowed))


func _test_citizen_living_status_service() -> void:
	var service := CitizenLivingStatusServiceScript.new()
	var citizen := Citizen.new()
	service.refresh_citizen(citizen, true, false)
	assert(citizen.has_status_effect(CitizenStatusEffectScript.NO_HOME))
	assert(not citizen.has_status_effect(CitizenStatusEffectScript.NO_LIT_COMMUNAL_FIRE))
	var tent_home := Node3D.new()
	tent_home.set_meta("is_tent", true)
	citizen.assign_home(tent_home)
	service.refresh_citizen(citizen, true, false)
	assert(not citizen.has_status_effect(CitizenStatusEffectScript.NO_HOME))
	assert(citizen.has_status_effect(CitizenStatusEffectScript.TENT_SHELTER))
	service.refresh_citizen(citizen, false, true)
	assert(citizen.has_status_effect(CitizenStatusEffectScript.NO_LIT_COMMUNAL_FIRE))
	service.refresh_citizen(citizen, true, false)
	assert(not citizen.has_status_effect(CitizenStatusEffectScript.NO_LIT_COMMUNAL_FIRE))
	citizen.free()
	tent_home.free()


func _test_building_research_service() -> void:
	var state := SettlementState.new()
	state.apply_tent_start()
	state.warehouse_ever_built = true
	state.buildings["campfire"] = 1
	state.branches = 8
	state.grass = 8
	var service := BuildingResearchServiceScript.new()
	service.configure(state)
	assert(service.visible_tech_ids().has("official"))
	var menu_state: Dictionary = service.menu_state("official", false)
	assert(bool(menu_state.visible))
	assert(not bool(menu_state.can_start))
	assert(menu_state.reason == BuildingResearchServiceScript.REASON_NO_WORKER)
	assert(service.start_research("official", 77))
	assert(state.active_research_tech_id == "official")
	assert(state.active_research_worker_id == 77)
	assert(state.branches == 4 and state.grass == 4)
	service.cancel_active(true)
	assert(state.active_research_tech_id.is_empty())
	assert(state.branches == 8 and state.grass == 8)
	assert(service.start_research("official", 77))
	service.advance_active(30.0, 1.0)
	assert(service.is_active_complete())
	var completion: Dictionary = service.complete_active()
	assert(completion.unlocked_target == "official")
	assert(completion.reward_skill == "official")
	assert(state.unlocked_systems.official)
	assert(state.active_research_tech_id.is_empty())

	# Outside-work earnings upgrade unlocks the bonus system and doubles the reward multiplier.
	assert(state.outside_work_reward_multiplier() == 1)
	state.branches = 6
	state.grass = 4
	state.money = 25
	assert(service.visible_tech_ids().has("outside_work_earnings"))
	assert(service.start_research("outside_work_earnings", 77))
	service.advance_active(25.0, 1.0)
	var earnings_completion: Dictionary = service.complete_active()
	assert(earnings_completion.unlocked_target == "outside_work_bonus")
	assert(state.unlocked_systems.outside_work_bonus)
	assert(state.outside_work_reward_multiplier() == 2)


func _test_progression_and_volunteers() -> void:
	var state := SettlementState.new()
	state.warehouse_ever_built = true
	state.buildings = {"campfire": 1, "tarp_trade_tent": 1}
	state.food = 4
	state.water = 4
	state.trade_sales = 1
	for tool_id in state.tools:
		state.tools[tool_id] = true
	state.complete_research("earth_buildings")
	assert(state.can_advance_to(SettlementState.Era.EARTH, 4, 4))

	var no_market_state := SettlementState.new()
	no_market_state.warehouse_ever_built = true
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
	assert(SettlementRulesScript.should_volunteer_leave(3))


func _test_work_schedule_wellbeing() -> void:
	var short_day: int = SettlementRulesScript.daily_wellbeing_change(true, 1.0, 1.0, 6, false)
	var long_night_day: int = SettlementRulesScript.daily_wellbeing_change(true, 1.0, 1.0, 10, true)
	assert(short_day > long_night_day)
	assert(SettlementRulesScript.production_multiplier(10, true) > SettlementRulesScript.production_multiplier(6, false))


func _test_tent_survival_rules() -> void:
	assert(TentEraSurvivalRulesScript.weather_for_day(1) == TentEraSurvivalRulesScript.Weather.WARMING)
	assert(TentEraSurvivalRulesScript.weather_for_day(2) == TentEraSurvivalRulesScript.Weather.COOLING)
	assert(TentEraSurvivalRulesScript.hourly_wellbeing_loss(false, true, TentEraSurvivalRulesScript.Weather.COOLING, true) == 6)
	assert(TentEraSurvivalRulesScript.hourly_wellbeing_loss(true, false, TentEraSurvivalRulesScript.Weather.WARMING, false) == 2)
	assert(TentEraSurvivalRulesScript.daily_food_consumption(4, TentEraSurvivalRulesScript.Weather.COOLING) == 5)
	var rain_loss := TentEraSurvivalRulesScript.rain_hourly_decay_losses({"food": 16, "branches": 1})
	assert(int(rain_loss.food) == 1 and int(rain_loss.branches) == 1)


func _test_clock_wraps_and_reports_elapsed_minutes() -> void:
	var clock := SimulationClock.new()
	assert(clock.hour() == 8)
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
	var early_builder := {"specialization": "builder", "player_controlled": false, "blocked_by_storage": false}
	var early_world := {"era": SettlementState.Era.WOOD, "construction_sites": 1, "assigned_roles": {}, "population": 2}
	assert(WorkforcePolicy.role_for(early_builder, early_world) == "")
	assert(WorkforcePolicy.permanent_vacancy_for(early_builder, early_world) == "construction")
	early_world.builder_jobs = 0
	assert(WorkforcePolicy.permanent_vacancy_for(early_builder, early_world) == "construction")
	early_world.assigned_roles = {"construction": 1}
	assert(WorkforcePolicy.role_for(early_builder, early_world) == "")
	early_world.construction_sites = 2
	assert(WorkforcePolicy.role_for(early_builder, early_world) == "")
	var guild_world := {"era": SettlementState.Era.STONE, "construction_sites": 1, "builder_jobs": 1, "assigned_roles": {}, "population": 2}
	assert(WorkforcePolicy.permanent_vacancy_for(early_builder, guild_world) == "construction")
	var employed_cook := {"specialization": "cook", "permanent_role": "farming", "player_controlled": false, "blocked_by_storage": false}
	var cook_world := {"hour": 9, "farms": 1, "warehouses": 1, "trees": 0, "construction_sites": 0, "cooking_jobs": 1}
	assert(WorkforcePolicy.can_assign(employed_cook, cook_world))
	var field_officer := {"specialization": "official", "permanent_role": "official", "player_controlled": false, "blocked_by_storage": false}
	assert(WorkforcePolicy.can_assign(field_officer, {"official_jobs": 0}))
	assert(WorkforcePolicy.can_take_queued_job({"idle": true, "daily_order_role": "", "player_controlled": false}))
	assert(not WorkforcePolicy.can_take_queued_job({"idle": true, "daily_order_role": "gather_branches", "player_controlled": false}))
	var employed := {"specialization": "cook", "permanent_role": "cook", "player_controlled": false, "blocked_by_storage": false}
	assert(WorkforcePolicy.can_assign(employed, {"cooking_jobs": 1, "has_canteen": true, "officer_available": false}))

	# Materials yard: an empty gather_branches vacancy is offered as a permanent job
	# when a yard exists and there are trees; a permanently-employed branch gatherer
	# stays assignable while trees remain.
	var yard_hand := {"specialization": "unassigned", "player_controlled": false, "blocked_by_storage": false}
	var yard_world := {"hour": 9, "trees": 2, "warehouses": 1, "population": 2, "materials_yard_jobs": 2, "assigned_roles": {}, "officer_available": true}
	assert(WorkforcePolicy.permanent_vacancy_for(yard_hand, yard_world) == "gather_branches")
	var branch_worker := {"specialization": "unassigned", "permanent_role": "gather_branches", "player_controlled": false, "blocked_by_storage": false}
	assert(WorkforcePolicy.can_assign(branch_worker, yard_world))
	yard_world.trees = 0
	assert(not WorkforcePolicy.can_assign(branch_worker, yard_world))

	var craft_world := {"hour": 9, "craftsman_jobs": 3, "assigned_roles": {}, "officer_available": true}
	var craft_worker := {"specialization": "craftsman", "permanent_role": "craftsman", "player_controlled": false, "blocked_by_storage": false}
	assert(WorkforcePolicy.permanent_vacancy_for(craft_worker, craft_world) == "craftsman")
	assert(WorkforcePolicy.can_assign(craft_worker, craft_world))
	var artisan := Citizen.new()
	artisan.assign_craft_work(Vector3.ZERO, 1.7)
	assert(is_equal_approx(artisan.craft_speed_multiplier, 1.7))
	artisan.free()

	# Foraging is a permanent job tied to forager tents; collecting dew is not a job.
	var forager_world := {"hour": 9, "warehouses": 1, "forager_tents": 1, "assigned_roles": {}, "officer_available": true}
	assert(WorkforcePolicy.permanent_vacancy_for({"specialization": "unassigned"}, forager_world) == "gather_food")
	assert(not WorkforcePolicy._role_available("gather_dew", {"has_collected_dew": true, "warehouses": 1}))
	var forager := {"specialization": "unassigned", "permanent_role": "gather_food", "player_controlled": false, "blocked_by_storage": false}
	assert(WorkforcePolicy.can_assign(forager, forager_world))
	forager_world.forager_tents = 0
	assert(not WorkforcePolicy.can_assign(forager, forager_world))

func _test_citizen_task_state() -> void:
	var task := CitizenTaskState.new()
	task.start(1.0)
	assert(not task.advance(0.4))
	assert(task.advance(0.6))


func _test_citizen_state_display_queue() -> void:
	var citizen := Citizen.new()
	citizen.state = Citizen.State.TO_TREE
	citizen.state = Citizen.State.CHOPPING
	assert(citizen._displayed_state == Citizen.State.IDLE)
	citizen._advance_state_display(1.0)
	assert(citizen._displayed_state == Citizen.State.CHOPPING)
	citizen._advance_state_display(0.99)
	assert(citizen._displayed_state == Citizen.State.CHOPPING)
	citizen.state = Citizen.State.TO_SAWMILL
	citizen._advance_state_display(0.01)
	assert(citizen._displayed_state == Citizen.State.TO_SAWMILL)
	citizen.free()


func _test_canteen_meal_requests() -> void:
	var simulation := FakeCanteenSimulation.new()
	simulation.canteen = Node3D.new()
	var citizen := Citizen.new()
	citizen.ai_id = 42
	simulation.citizens.append(citizen)
	var service := CanteenServiceScript.new()
	service.configure(simulation)

	service.start_meal(13)
	assert(service.is_meal_requested(citizen.ai_id))
	assert(simulation.last_interface_message.contains("meal service started"))

	service.on_meal_finished(citizen)
	assert(not service.is_meal_requested(citizen.ai_id))
	assert(simulation.canteen_food == 1)
	assert(simulation.workers_updated)

	service.start_meal(13)
	assert(service.is_meal_requested(citizen.ai_id))
	service.remove_citizen(citizen.ai_id)
	assert(not service.is_meal_requested(citizen.ai_id))
	citizen.free()
	simulation.canteen.free()
	simulation.free()


func _test_grid_routing() -> void:
	var blocked: Dictionary = {}
	for y in range(-3, 3):
		blocked[Vector2i(1, y)] = true
	var grid := NavGrid.new()
	grid.configure(1.0, 6)
	grid.set_blocked_cells(blocked)
	var router = GridRouteServiceScript.new()
	router.configure(grid)
	var unreachable: RouteResult = router.find_route(Vector3(0.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5))
	assert(not unreachable.reachable and unreachable.waypoints.is_empty())

	blocked.erase(Vector2i(1, 2))
	grid.set_blocked_cells(blocked)
	var route: RouteResult = router.find_route(Vector3(0.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5))
	assert(route.reachable and route.arrival_position == Vector3(2.5, 0.0, 0.5))
	for waypoint in route.waypoints:
		assert(not blocked.has(Vector2i(floori(waypoint.x), floori(waypoint.z))))


func _test_weighted_grid_routing() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router := GridRouteServiceScript.new()
	router.configure(grid)

	# Eight-way A* collapses an unobstructed diagonal to the requested endpoint.
	var diagonal_destination := Vector3(3.5, 0.0, 3.5)
	var diagonal_route := router.find_route(Vector3(0.5, 0.0, 0.5), diagonal_destination)
	assert(diagonal_route.reachable and diagonal_route.waypoints == [diagonal_destination])

	# A diagonal cannot pass between two orthogonally adjacent blocked cells.
	grid.set_blocked_cells({Vector2i(1, 0): true, Vector2i(0, 1): true, Vector2i(-1, 0): true, Vector2i(0, -1): true})
	var corner_route := router.find_route(Vector3(0.5, 0.0, 0.5), Vector3(1.5, 0.0, 1.5))
	assert(not corner_route.reachable)
	grid.set_blocked_cells({})

	# A cheaper corridor wins over the shorter strip of expensive terrain. The
	# weighted smoother must keep the detour instead of cutting through that strip.
	var weights: Dictionary = {}
	for x in range(-2, 3):
		weights[Vector2i(x, 0)] = 10.0
	for x in range(-2, 3):
		weights[Vector2i(x, 1)] = 0.5
	grid.set_cell_weights(weights)
	var start := Vector3(-2.5, 0.0, 0.5)
	var destination := Vector3(3.5, 0.0, 0.5)
	var weighted_route := router.find_route(start, destination)
	assert(weighted_route.reachable)
	var uses_cheap_corridor := false
	for waypoint in weighted_route.waypoints:
		uses_cheap_corridor = uses_cheap_corridor or waypoint.z > 1.0
	assert(uses_cheap_corridor)
	assert(grid.segment_cost(start, destination) > 1.08 * _route_polyline_cost(grid, start, weighted_route.waypoints))

	grid.set_blocked_cells({Vector2i(3, 0): true})
	var blocked_destination := router.find_route(start, destination)
	assert(not blocked_destination.reachable)
	var allowed_request := RouteRequestScript.new()
	allowed_request.from = start
	allowed_request.destination = destination
	allowed_request.allow_destination_cell = true
	assert(router.find_route_request(allowed_request).reachable)


func _test_navigation_grid_revision() -> void:
	var grid := NavGrid.new()
	grid.configure(1.0, 10)
	var router := GridRouteServiceScript.new()
	router.configure(grid)
	var initial_revision := grid.revision()
	grid.set_blocked_cells({})
	grid.set_cell_weights({})
	assert(grid.revision() == initial_revision)

	var route: RouteResult = router.find_route(Vector3(-2.5, 0.0, 0.5), Vector3(2.5, 0.0, 0.5))
	assert(route.reachable and route.grid_revision == initial_revision)
	grid.set_cell_weights({Vector2i(0, 1): 0.5})
	assert(grid.revision() == initial_revision + 1)
	assert(grid.minimum_cell_weight() == 0.5)
	assert(route.grid_revision != grid.revision())
	assert(is_equal_approx(grid.get_cell_weight(Vector2i(4, 4)), NavGrid.DEFAULT_CELL_WEIGHT))
	grid.set_cell_weights({Vector2i(0, 1): 0.5})
	assert(grid.revision() == initial_revision + 1)
	grid.set_blocked_cells({Vector2i(0, 0): true})
	assert(grid.revision() == initial_revision + 2)
	assert(grid.topology_revision() == route.grid_revision + 1)


func _test_navigation_recovery_guards() -> void:
	var citizen := Citizen.new()
	var revisions := [5]
	citizen.navigation_revision_query = func() -> int: return revisions[0]
	citizen.active_route = RouteResult.unreachable(4)
	citizen.navigation_failed = true
	citizen._invalidate_route_for_navigation_change()
	assert(not citizen.navigation_failed)
	assert(citizen.active_route == null)
	citizen._force_repath()
	var attempts := citizen.route_recovery_attempt
	citizen._force_repath()
	assert(citizen.route_recovery_attempt == attempts)
	citizen.free()


func _test_trail_field() -> void:
	var normal := TrailFieldServiceScript.new()
	normal.configure(12.0)
	normal.record_walker_position(1, Vector3.ZERO, false)
	normal.record_walker_position(1, Vector3(0.2, 0.0, 0.0), false)
	assert(normal.total_strength() == 0)
	normal.record_walker_position(1, Vector3(0.6, 0.0, 0.0), false)
	var normal_strength := normal.total_strength()
	assert(normal_strength > 0)
	var ordered := TrailFieldServiceScript.new()
	ordered.configure(12.0)
	ordered.record_walker_position(1, Vector3.ZERO, true)
	ordered.record_walker_position(1, Vector3(0.6, 0.0, 0.0), true)
	assert(ordered.total_strength() > normal_strength)
	for _day in range(40):
		normal.apply_daily_decay()
	assert(normal.total_strength() == 0)

	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	var trails := TrailFieldServiceScript.new()
	trails.configure(12.0, 1.0, grid)
	var initial_revision := grid.revision()
	var path_cell := Vector2i(1, 0)
	trails.record_walker_position(2, Vector3(0.1, 0.0, 0.1), false)
	for _entry in range(3):
		trails.record_walker_position(2, Vector3(1.1, 0.0, 0.1), false)
		trails.record_walker_position(2, Vector3(0.1, 0.0, 0.1), false)
	assert(trails.cell_state(path_cell) == TrailFieldService.TrailState.NONE)
	assert(is_equal_approx(grid.get_cell_weight(path_cell), NavGrid.DEFAULT_CELL_WEIGHT))
	trails.record_walker_position(2, Vector3(1.1, 0.0, 0.1), false)
	assert(trails.cell_state(path_cell) == TrailFieldService.TrailState.YOUNG)
	assert(is_equal_approx(grid.get_cell_weight(path_cell), TrailFieldService.YOUNG_PATH_WEIGHT))
	assert(is_equal_approx(grid.get_cell_weight(path_cell, &"cart"), NavGrid.DEFAULT_CELL_WEIGHT))
	assert(grid.revision() > initial_revision)
	var young_revision := grid.revision()
	for _entry in range(5):
		trails.record_walker_position(2, Vector3(0.1, 0.0, 0.1), false)
		trails.record_walker_position(2, Vector3(1.1, 0.0, 0.1), false)
	assert(trails.cell_state(path_cell) == TrailFieldService.TrailState.MATURE)
	assert(is_equal_approx(grid.get_cell_weight(path_cell), TrailFieldService.MATURE_PATH_WEIGHT))
	assert(grid.revision() > young_revision)

	var ordered_grid := NavGrid.new()
	ordered_grid.configure(1.0, 12)
	var ordered_trails := TrailFieldServiceScript.new()
	ordered_trails.configure(12.0, 1.0, ordered_grid)
	ordered_trails.record_walker_position(3, Vector3(0.1, 0.0, 0.1), true)
	ordered_trails.record_walker_position(3, Vector3(1.1, 0.0, 0.1), true)
	ordered_trails.record_walker_position(3, Vector3(0.1, 0.0, 0.1), true)
	ordered_trails.record_walker_position(3, Vector3(1.1, 0.0, 0.1), true)
	assert(ordered_trails.cell_state(path_cell) == TrailFieldService.TrailState.YOUNG)

	for _day in range(20):
		trails.apply_daily_decay()
	assert(trails.cell_state(path_cell) == TrailFieldService.TrailState.NONE)
	assert(not trails.active_weight_overrides().has(path_cell))
	assert(is_equal_approx(grid.get_cell_weight(path_cell), NavGrid.DEFAULT_CELL_WEIGHT))


func _test_citizen_replans_on_navigation_revision() -> void:
	var citizen := Citizen.new()
	var navigation_revisions := [3]
	citizen.navigation_revision_query = func() -> int: return navigation_revisions[0]
	citizen.active_route = RouteResult.success([Vector3(1.0, 0.0, 0.0)], Vector3(1.0, 0.0, 0.0), navigation_revisions[0])
	assert(not citizen._route_uses_stale_navigation())
	navigation_revisions[0] += 1
	assert(citizen._route_uses_stale_navigation())
	citizen._invalidate_route_for_navigation_change()
	assert(citizen.active_route == null)
	assert(citizen.route_retry_timer >= 0.0 and citizen.route_retry_timer <= Citizen.STALE_NAVIGATION_REPLAN_JITTER)
	citizen.free()


func _test_citizen_route_failure_marks_action_failed() -> void:
	var citizen := Citizen.new()
	citizen.ai_id = 11
	citizen.navigation_revision_query = func() -> int:
		return 4
	citizen.start_production_cycle("wood", Vector3(3.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0), false, Vector3(1.0, 0.0, 0.0))
	citizen.path_destination = Vector3(1.0, 0.0, 0.0)
	citizen.active_route = RouteResult.unreachable(4)
	citizen.route_retry_timer = Citizen.ROUTE_UNREACHABLE_FAILURE_TIME * 2.0
	for _i in range(ceili(Citizen.ROUTE_UNREACHABLE_FAILURE_TIME / 0.5) + 1):
		citizen._process_to_source(0.5)
	assert(citizen.get_action_status(&"forestry") == CitizenActuator.ActionStatus.FAILED)
	citizen.free()


func _route_polyline_cost(grid: NavGrid, start: Vector3, waypoints: Array[Vector3]) -> float:
	var total := 0.0
	var previous := start
	for waypoint in waypoints:
		total += grid.segment_cost(previous, waypoint)
		previous = waypoint
	return total


func _test_building_queue_routing() -> void:
	var registry := BuildingRegistry.new()
	var building := Node3D.new()
	building.position = Vector3(1.5, 0.0, 1.5)
	root.add_child(building)
	building.set_meta("service_position", Vector3(2.5, 0.0, 1.5))
	registry.reserve(Vector2i(1, 1), building.position, Vector2i.ONE)
	registry.attach_node(Vector2i(1, 1), building)
	var blocked := {Vector2i(3, 1): true}
	var grid := NavGrid.new()
	grid.configure(1.0, 12)
	grid.set_blocked_cells(blocked)
	var queues = BuildingQueueServiceScript.new()
	queues.configure(registry, grid)
	var first := Node3D.new()
	var second := Node3D.new()
	var third := Node3D.new()
	root.add_child(first)
	root.add_child(second)
	root.add_child(third)
	var service_position: Vector3 = building.get_meta("service_position")
	var head: Dictionary = queues.resolve(first, service_position)
	var middle: Dictionary = queues.resolve(second, service_position)
	var tail: Dictionary = queues.resolve(third, service_position)
	assert(head.is_head and head.position == service_position)
	assert(not middle.is_head and not blocked.has(Vector2i(floori(middle.position.x), floori(middle.position.z))))
	assert(not tail.is_head and tail.position != middle.position)
	queues.complete_arrival(first, service_position)
	assert(not queues.resolve(second, service_position).is_head)
	queues._last_admitted_frame[building.get_instance_id()][0] = Engine.get_physics_frames() - 1
	assert(not queues.resolve(second, service_position).is_head)
	queues.release(first)
	assert(queues.resolve(second, service_position).is_head)
	queues.release(second)
	assert(queues.resolve(third, service_position).is_head)
	var overflow_positions: Dictionary = {}
	var overflow_nodes: Array[Node3D] = []
	for index in range(24):
		var queued := Node3D.new()
		queued.position = Vector3(-5.0 + index * 0.1, 0.0, -5.0)
		root.add_child(queued)
		overflow_nodes.append(queued)
		var result: Dictionary = queues.resolve(queued, service_position)
		var key := "%0.3f:%0.3f" % [result.position.x, result.position.z]
		assert(not overflow_positions.has(key))
		overflow_positions[key] = true
	for queued in overflow_nodes:
		queues.release(queued)
		root.remove_child(queued)
		queued.free()
	root.remove_child(first)
	root.remove_child(second)
	root.remove_child(third)
	first.free()
	second.free()
	third.free()
	root.remove_child(building)
	building.free()


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
	var site := service.start_site(cell, "campfire", Vector3(2.0, 0.0, 3.0))
	assert(service.has_site(site.node))
	var resource_type := str(site.required_materials.keys()[0])
	assert(service.accept_delivery(site.node, resource_type, 1))
	assert(int(site.delivered_materials[resource_type]) == 1)
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
	var seller := {"specialization": "seller", "permanent_role": "seller", "player_controlled": false, "blocked_by_storage": false}
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
	var home := Node3D.new()
	courier.home = home
	courier.go_home()
	assert(courier.state == Citizen.State.TO_CONSTRUCTION_SITE)
	courier.go_to_canteen(Vector3.ZERO)
	assert(courier.state == Citizen.State.TO_CONSTRUCTION_SITE)
	courier.construction_delivery_resource = "branches"
	courier.cancel_current_action()
	assert(courier.state == Citizen.State.IDLE)
	assert(courier.carried_amount == 0)
	assert(courier.construction_delivery_resource.is_empty())
	assert(not courier.has_active_delivery())
	home.free()
	courier.free()


func _test_daily_order_construction_skill_cap() -> void:
	var worker := Citizen.new()
	worker.assign_daily_order("construction", 1, 100.0)
	worker.skills = {"construction": Citizen.DAILY_CONSTRUCTION_SKILL_CAP - 0.00001}
	worker.active_role = "construction"
	worker.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
	worker.satisfaction_tick = 10.0
	worker._update_satisfaction(0.0)
	assert(float(worker.skills.construction) <= Citizen.DAILY_CONSTRUCTION_SKILL_CAP)
	worker.clear_daily_order()
	worker.employment_state = Citizen.EmploymentState.EMPLOYED
	worker.active_role = "construction"
	worker.satisfaction_tick = 10.0
	worker._update_satisfaction(0.0)
	assert(float(worker.skills.construction) > Citizen.DAILY_CONSTRUCTION_SKILL_CAP)
	worker.free()


func _test_daily_order_role_recheck_cooldown() -> void:
	var worker := Citizen.new()
	worker.employment_state = Citizen.EmploymentState.NO_PERMANENT_WORK
	worker.begin_role_recheck_cooldown()
	assert(worker.role_recheck_remaining >= Citizen.ROLE_RECHECK_MIN_DELAY)
	assert(worker.role_recheck_remaining <= Citizen.ROLE_RECHECK_MAX_DELAY)
	assert(not worker.can_recheck_idle_work())
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
	state.warehouse_ever_built = true
	assert(not state.unlocked_building_levels.get("straw_tent", false))
	assert(not state.unlocked_building_levels.get("tarp_tent", false))
	assert(not state.unlocked_building_levels.get("straw_craft_tent", false))

	state.branches = 8
	state.grass = 6
	assert(not state.can_start_building_research("straw_tents"))
	state.buildings["campfire"] = 1
	assert(state.can_afford_research("straw_tents"))
	assert(state.can_start_building_research("straw_tents"))
	assert(not state.can_start_building_research("tarp_tents"))
	assert(state.pay_for_research("straw_tents"))
	assert(state.branches == 0 and state.grass == 0)
	assert(state.complete_research("straw_tents") == "straw_tent")
	assert(state.is_building_unlocked("straw_tent"))
	assert(state.is_building_unlocked("straw_forager_tent"))
	assert(state.is_building_unlocked("straw_warehouse"))

	assert(not state.can_afford_building("dugout_kitchen"))
	state.era = SettlementState.Era.EARTH
	state.soil = 8
	state.branches = 4
	state.buildings["cook_campfire"] = 1
	state.unlocked_building_levels["cook_campfire_lvl2"] = true
	state.unlocked_building_levels["cook_campfire_lvl3"] = true
	assert(state.can_start_building_research("dugout_kitchen"))
	assert(BuildingCatalog.kitchen_food_capacity("cook_campfire") == 4)
	assert(BuildingCatalog.kitchen_food_capacity("cook_campfire_lvl2") == 6)
	assert(BuildingCatalog.kitchen_food_capacity("cook_campfire_lvl3") == 8)
	assert(BuildingCatalog.kitchen_food_capacity("brick_restaurant") == 20)

	# Campfire level tech gating tests:
	var test_state := SettlementState.new()
	test_state.warehouse_ever_built = true
	test_state.era = SettlementState.Era.TENT
	test_state.branches = 100
	test_state.grass = 100
	assert(not test_state.can_start_building_research("campfire_lvl2"))
	test_state.buildings["campfire"] = 1
	assert(test_state.can_start_building_research("campfire_lvl2"))
	assert(test_state.can_start_building_research("official"))
	assert(test_state.pay_for_research("official"))
	assert(test_state.complete_research("official") == "official")
	assert(test_state.is_research_completed("official"))
	test_state.unlocked_building_levels["campfire_lvl2"] = true
	assert(not test_state.can_start_building_research("campfire_lvl3"))
	test_state.buildings["campfire_lvl2"] = 1
	assert(test_state.can_start_building_research("campfire_lvl3"))
	assert(test_state.can_start_building_research("gathering_place"))
	assert(test_state.complete_research("gathering_place") == "gathering_place")
	assert(test_state.is_building_unlocked("gathering_place"))
	test_state.unlocked_building_levels["dew_collector"] = true
	test_state.buildings["dew_collector"] = 1
	assert(test_state.can_start_building_research("advanced_dew_collector"))
	test_state.complete_research("advanced_dew_collector")
	assert(test_state.is_building_unlocked("advanced_dew_collector"))

	# Tarp tents require straw tents and campfire level 2.
	var forager_state := SettlementState.new()
	forager_state.warehouse_ever_built = true
	forager_state.branches = 100
	forager_state.grass = 100
	forager_state.tarp = 1
	forager_state.buildings["campfire"] = 1
	assert(not forager_state.can_start_building_research("tarp_tents"))
	forager_state.complete_research("straw_tents")
	forager_state.unlocked_building_levels["campfire_lvl2"] = true
	forager_state.buildings["campfire_lvl2"] = 1
	assert(forager_state.can_start_building_research("tarp_tents"))

	# Heap and warehouse capacity tests:
	test_state.buildings.clear()
	test_state.buildings["warehouse"] = 1
	assert(test_state.storage_capacity(1) == 24)
	test_state.buildings["straw_warehouse"] = 1
	assert(test_state.storage_capacity(2) == 72)
	
	var citizen := Citizen.new()
	citizen._ready()
	citizen.state = Citizen.State.RESEARCHING
	assert(not citizen.is_available_for_schedule())
	citizen.free()


func _test_cheer_up_mechanic() -> void:
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

func _test_water_collector_service() -> void:
	var simulation := FakeWaterCollectorSimulation.new()
	var service := WaterCollectorServiceScript.new()
	service.configure(simulation)

	var collector := Node3D.new()
	collector.position = Vector3(2.0, 0.0, 3.0)
	collector.set_meta("service_position", collector.position)
	simulation.water_collectors = [{
		"node": collector,
		"rate": 1.0,
		"accum": 0.0,
		"stored": 0,
		"capacity": 10,
	}]

	service.tick(2.5)
	assert(service.stored_at(collector.position) == 2)
	assert(service.collect_water(collector.position, 5) == 2)
	assert(service.stored_at(collector.position) == 0)
	assert(service.collect_water(collector.position, 1) == 0)

	collector.free()
	simulation.free()
